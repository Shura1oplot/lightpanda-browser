#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
platform=$("$repo_dir/scripts/platform.sh")
source_binary=$repo_dir/tools/bin/$platform/lightpanda
[[ -x $source_binary ]] || {
    printf 'Build Lightpanda first: %s/scripts/build-lightpanda.sh\n' "$repo_dir" >&2
    exit 1
}

install_dir=${HOME:?HOME is not set}/.local/bin
mkdir -p -- "$install_dir"
temporary_file=$(mktemp "$install_dir/.lightpanda.XXXXXX")
trap 'rm -f -- "$temporary_file"' EXIT
install -m 0755 "$source_binary" "$temporary_file"
mv -f -- "$temporary_file" "$install_dir/lightpanda"
printf 'Installed Lightpanda for %s to %s/lightpanda\n' "$platform" "$install_dir"
