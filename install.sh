#!/usr/bin/env bash

set -euo pipefail

if (( BASH_VERSINFO[0] < 5 )); then
    printf 'Lightpanda installer requires Bash 5 or newer.\n' >&2
    exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
build_dir=${script_dir}/build
checksums_file=${build_dir}/SHA256SUMS

platform=$(uname -s)
architecture=$(uname -m)

case "${platform}/${architecture}" in
    Darwin/arm64)
        binary_name=lightpanda-aarch64-macos
        checksum_command=(shasum -a 256)
        ;;
    Linux/x86_64 | Linux/amd64)
        binary_name=lightpanda-x86_64-linux
        checksum_command=(sha256sum)
        ;;
    *)
        printf 'Unsupported platform: %s/%s.\n' "${platform}" "${architecture}" >&2
        exit 1
        ;;
esac

source_binary=${build_dir}/${binary_name}

if [[ ! -f "${source_binary}" ]]; then
    printf 'Release binary not found: %s\n' "${source_binary}" >&2
    exit 1
fi

if [[ ! -f "${checksums_file}" ]]; then
    printf 'Checksum manifest not found: %s\n' "${checksums_file}" >&2
    exit 1
fi

expected_checksum=""

while read -r checksum filename; do
    if [[ ${filename} == "${binary_name}" ]]; then
        expected_checksum=${checksum}
        break
    fi

done <"${checksums_file}"

if [[ ! "${expected_checksum}" =~ ^[[:xdigit:]]{64}$ ]]; then
    printf 'Valid SHA-256 entry not found for %s.\n' "${binary_name}" >&2
    exit 1
fi

install_dir=${HOME:?HOME is not set}/.local/bin
destination=${install_dir}/lightpanda
mkdir -p "${install_dir}"

temporary_file=$(mktemp "${install_dir}/.lightpanda.XXXXXX")
function cleanup() {
    if [[ -n ${temporary_file} ]]; then
        rm -f -- "${temporary_file}"
    fi
}
trap cleanup EXIT HUP INT TERM

install -m 0755 "${source_binary}" "${temporary_file}"
actual_checksum=$("${checksum_command[@]}" "${temporary_file}")
actual_checksum=${actual_checksum%%[[:space:]]*}

if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
    printf 'SHA-256 verification failed for %s.\n' "${binary_name}" >&2
    exit 1
fi

mv -f -- "${temporary_file}" "${destination}"
temporary_file=""
trap - EXIT HUP INT TERM

printf 'Installed Lightpanda to %s\n' "${destination}"
