# Сборка Lightpanda для Linux x86_64 на Timeweb

Дата актуализации: 10 августа 2026 года. Редакция 5.

## 1. Назначение

1. Инструкция собирает Lightpanda со статическим curl-impersonate и постоянным профилем Chrome 146.

2. Целевая система – Ubuntu 24.04 с нативной архитектурой x86_64.

3. На компьютере Apple Silicon нельзя использовать Docker, OrbStack, Rosetta, QEMU и другую эмуляцию x86_64. Проверенная попытка завершалась ошибкой `rosetta error: bss_size overflow` в процессах Zig `translate-c`.

4. Для сборки создается временный платный сервер Timeweb. Весь цикл от создания до проверки удаления выполняется в одном сеансе Bash.

5. Linux-бинарник намеренно представляет профиль Chrome 146 на macOS Tahoe.

6. Один разрешенный цикл использует один сервер и его автоматически назначенный адрес. Сбой отдельного сетевого запроса не является основанием для создания нового сервера.

## 2. Опыт запуска 10 августа 2026 года

### 2.1 Причины повторных попыток

1. Две подготовительные попытки завершились до компиляции. Проверка Ubuntu начиналась, пока `cloud-init` продолжал применять параметры SSH и выполнял перезапуск службы. В следующем цикле сначала дождитесь `cloud-init status --wait` и синхронизации времени, затем проверяйте систему и передавайте исходники.

2. Первая полная сборка прошла 1 156 тестов, но приемка остановилась из-за записи `--wait-until=done`, которую команда не поддерживает. Рабочая запись имеет вид `--wait-until done`. Выполняйте ее локально для всех трех сетевых сценариев до создания сервера.

3. Локальная сборка macOS без явной цели получила минимальную версию текущего SDK macOS 26.5.2. Для файла предварительной проверки и выпуска всегда передавайте `-Dtarget=aarch64-macos.12.0` и проверяйте поле `minos` через `otool`.

4. `rzd.ru` может записывать предупреждения об интерфейсах документа, которые браузер не поддерживает, при успешном получении страницы. Приемка опирается на HTTP 200, маркер РЖД в HTML и отдельное отклонение недоверенного сертификата. Отсутствие предупреждений не является условием приемки.

### 2.2 Порядок быстрого повторения

01. Обновите удаленные ссылки Git и сравните фиксации исходного кода с `RELEASE.md`. При совпадении фиксаций, версии и `SHA256SUMS` новая сборка не нужна.

02. Зафиксируйте SHA Lightpanda и curl-impersonate до создания ресурсов. Передавайте на сервер деревья этих фиксаций через `git archive`.

03. Проверьте локальный файл macOS, минимальную версию 12.0 и три точные сетевые команды из раздела 5.

04. Проверьте через API профиль, баланс, регион, образ, тариф, ключ SSH и отсутствие незавершенного сервера с префиксом `lightpanda-linux-amd64-`.

05. Установите обработчик очистки с восстановлением идентификаторов сервера и адреса до команды `twc server create`.

06. Создайте один сервер с автоматически назначенным адресом. Не создавайте отдельный плавающий адрес.

07. Дождитесь окончания `cloud-init` и синхронизации времени. После этого проверьте Ubuntu 24.04, архитектуру x86_64 и отпечаток ключа узла.

08. Соберите curl-impersonate и Lightpanda в одном удаленном сеансе. Сохраните исполняемый файл в `/opt/out` до обращения к внешним сайтам.

09. Повторите каждый сетевой сценарий не более трех раз на том же сервере. Сохраните протокол результата независимо от исхода.

10. Получите исполняемый файл и протокол, сравните удаленную и локальную контрольные суммы, затем удалите сервер и адрес. Завершайте цикл только после повторных запросов API с пустым результатом.

### 2.3 Решение по адресу

Текущий порядок использует автоматически назначенный адрес одного временного сервера. Этот порядок прошел полный цикл без отдельного плавающего адреса.

Перед переходом к повторно используемому плавающему адресу отдельно проверьте дневной лимит создания адресов, плату за адрес без привязки и операции привязки и отвязки в текущей версии API. До такой проверки плавающий адрес не создавайте.

Если на созданном сервере возникла ошибка, продолжайте диагностику на нем в пределах разрешенного цикла. Второй сервер можно создавать только после удаления первого, определения причины и нового разрешения пользователя.

## 3. Условия безопасности

01. Перед созданием сервера покажите пользователю регион, образ, параметры, цену, расчетное время и получите прямое разрешение.

02. Не читайте `.env`. Используйте ранее настроенный профиль `twc`.

03. Передавайте только деревья зафиксированных коммитов через `git archive`. Не передавайте `.git`, рабочие каталоги, ключи, токены и локальные файлы среды.

04. Не изменяйте другие серверы и адреса. Имя временного сервера должно отличаться от имен существующих ресурсов.

05. Не создавайте отдельный плавающий адрес. Используйте только адрес, автоматически назначенный одному временному серверу. Плавающий адрес допустим только по отдельному решению для многократных запусков после проверки тарификации и порядка привязки.

06. До создания платного ресурса локально выполните точные команды трех сетевых проверок на готовом файле macOS. Это исключает потерю цикла из-за ошибки в параметрах командной строки.

07. Каждый сетевой запрос можно повторить не более трех раз на том же сервере. Между попытками выдерживайте пять секунд. Не создавайте второй сервер из-за временной ошибки внешнего сайта.

08. Сохраните исполняемый файл в `/opt/out` до сетевых проверок. Получите файл и протокол даже при отрицательном сетевом результате, затем удалите тот же сервер.

09. После получения бинарного файла удалите временный сервер и автоматически назначенный публичный адрес. Задача не завершена, пока API повторно не подтвердит отсутствие обоих ресурсов.

10. При потере сеанса, недоступности API или неподтвержденном удалении немедленно проверьте ресурсы вручную. Не оставляйте сервер для последующей диагностики без нового разрешения пользователя.

## 4. Проверенная конфигурация

На 10 августа 2026 года использовались следующие параметры:

1. Учетная запись имеет идентификатор `cg76969`.

2. Используется регион `ru-3`.

3. Образ `99` соответствует Ubuntu 24.04 Noble.

4. Тариф `4805` предоставляет 8 виртуальных процессоров, 12 гигабайт памяти, 100 гигабайт на твердотельном накопителе и сетевой канал со скоростью один миллиард бит в секунду за 2900 рублей в месяц.

5. Ключ `shura`, идентификатор `570909`, локальный закрытый ключ `~/.ssh/id_ed25519`.

6. SSH использует порт `443`, потому что среда запуска агента блокирует исходящие соединения к порту `22`. Параметры передаются через файл `docs/timeweb-cloud-init-ssh-443.yaml`; проверка по ключу и запрет пароля сохраняются.

Перед каждым запуском повторно проверьте параметры через API. Не создавайте ресурс, если они изменились.

## 5. Один локальный сеанс

Откройте один отдельный сеанс и не закрывайте его до удаления ресурсов:

```bash
/opt/homebrew/bin/bash --noprofile --norc
set -Eeuo pipefail

workspace=/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents
lightpanda_repo="$workspace/lightpanda"
curl_repo="$workspace/curl-impersonate"
release_dir="$lightpanda_repo/build"
local_binary="$release_dir/lightpanda-x86_64-linux"
preflight_binary="$release_dir/lightpanda-aarch64-macos"
ssh_port=443
user_data_file="$lightpanda_repo/docs/timeweb-cloud-init-ssh-443.yaml"

lightpanda_release_sha=a0e1a2906d1e46edfaeeb1ad97303114625e114e
curl_release_sha=266cd9ffce634930e7b236fe340016718ac29dba
git -C "$lightpanda_repo" merge-base --is-ancestor \
  "$lightpanda_release_sha" HEAD
git -C "$lightpanda_repo" diff --quiet "$lightpanda_release_sha" -- . \
  ':(exclude)docs'
test "$(git -C "$curl_repo" rev-parse HEAD)" = "$curl_release_sha"

lightpanda_sha="$lightpanda_release_sha"
curl_sha="$curl_release_sha"
base_version="$(
  git -C "$lightpanda_repo" show "$lightpanda_sha:build.zig.zon" |
    awk -F '"' '/\.version =/ { print $2; exit }'
)"
commit_count="$(git -C "$lightpanda_repo" rev-list --count "$lightpanda_sha")"
short_sha="$(git -C "$lightpanda_repo" rev-parse --short "$lightpanda_sha")"
lightpanda_version="$base_version.$commit_count+$short_sha"

test -z "$(git -C "$lightpanda_repo" status --short)"
test -z "$(git -C "$curl_repo" status --short --untracked-files=no)"
test -s "$user_data_file"
test "$(twc --version)" = v2.15.2
twc whoami

twc server list-os-images --output json |
  jq -e '.servers_os | any(.id == 99 and .name == "ubuntu" and .version == "24.04")'

twc server list-presets --region ru-3 --output json |
  jq -e '.server_presets | any(.id == 4805 and .location == "ru-3")'

ssh_key_json="$(twc ssh-key list --output json)"
test "$(jq '[.ssh_keys[] | select(.name == "shura")] | length' <<<"$ssh_key_json")" = 1
test "$(jq -r '.ssh_keys[] | select(.name == "shura") | .id' <<<"$ssh_key_json")" = 570909
test "$(tr -d '\r\n' <"$HOME/.ssh/id_ed25519.pub")" = "$(jq -r '.ssh_keys[] | select(.name == "shura") | .body' <<<"$ssh_key_json")"
unset ssh_key_json
```

До установки обработчика очистки и создания сервера проверьте точный синтаксис сетевых команд:

```bash
test -x "$preflight_binary"
preflight_dir="$(mktemp -d)"

"$preflight_binary" fetch --json --wait-until done --terminate-ms 30000 \
  --dump html https://example.com >"$preflight_dir/example.json"
jq -e '.http_status == 200 and (.content | contains("Example Domain"))' \
  "$preflight_dir/example.json" >/dev/null

"$preflight_binary" fetch --json --wait-until done --terminate-ms 30000 \
  --dump html https://rzd.ru/ >"$preflight_dir/rzd.json"
jq -e '.http_status == 200 and (.content | contains("РЖД"))' \
  "$preflight_dir/rzd.json" >/dev/null

"$preflight_binary" fetch --json --wait-until done --terminate-ms 15000 \
  https://self-signed.badssl.com/ >"$preflight_dir/self-signed.json" \
  2>"$preflight_dir/self-signed.log"
jq -e '.http_status == 0' "$preflight_dir/self-signed.json" >/dev/null
rg -F 'PeerFailedVerification' "$preflight_dir/self-signed.log" >/dev/null

unlink "$preflight_dir/example.json"
unlink "$preflight_dir/rzd.json"
unlink "$preflight_dir/self-signed.json"
unlink "$preflight_dir/self-signed.log"
rmdir "$preflight_dir"
```

Установите обработчик очистки до команды создания:

```bash
server_name="lightpanda-linux-amd64-$(date -u +%Y%m%dT%H%M%SZ)"
server_id=
server_ip=
server_ip_id=
known_hosts_file=

recover_timeweb_ids() {
  local payload count

  if [[ -z "$server_id" ]]; then
    payload="$(twc server list --output json)"
    count="$(jq --arg name "$server_name" '[.servers[] | select(.name == $name)] | length' <<<"$payload")"
    ((count <= 1))
    if ((count == 1)); then
      server_id="$(jq -r --arg name "$server_name" '.servers[] | select(.name == $name) | .id' <<<"$payload")"
    fi
  fi

  if [[ -n "$server_id" && -z "$server_ip" ]]; then
    payload="$(twc server get "$server_id" --output json)"
    server_ip="$(
      jq -r '
        [.server.networks[]? |
         select(.type == "public") |
         .ips[]? |
         select(.type == "ipv4" and .is_main) |
         .ip][0] // empty
      ' <<<"$payload"
    )"
    server_ip_id="$(
      jq -r '
        [.server.networks[]? |
         select(.type == "public") |
         .ips[]? |
         select(.type == "ipv4" and .is_main) |
         .id][0] // empty
      ' <<<"$payload"
    )"
  fi
}

server_absent() {
  twc server list --output json | jq -e --arg id "$server_id" 'all(.servers[]; (.id | tostring) != $id)' >/dev/null
}

ip_absent() {
  twc ip list --output json | jq -e --arg id "$server_ip_id" --arg ip "$server_ip" 'all(.ips[]; ((.id | tostring) != $id and .ip != $ip))' >/dev/null
}

cleanup_timeweb() {
  local original_code="$1"
  local cleanup_failed=0
  local verified=0
  local attempt

  trap - EXIT HUP INT TERM
  set +e

  if recover_timeweb_ids; then
    if [[ -z "$server_id" ]]; then
      verified=1
    else
      server_absent || twc server remove -y "$server_id"

      for attempt in {1..60}; do
        if server_absent; then
          if [[ -z "$server_ip_id" || -z "$server_ip" ]]; then
            cleanup_failed=1
            break
          fi
          if ip_absent; then
            verified=1
            break
          fi
          twc ip remove -y "$server_ip_id"
        fi
        sleep 5
      done
    fi
  else
    cleanup_failed=1
  fi

  ((verified == 1)) || cleanup_failed=1
  if [[ -n "$known_hosts_file" && -e "$known_hosts_file" ]]; then
    unlink "$known_hosts_file" || cleanup_failed=1
  fi
  unset TWC_TOKEN

  if ((cleanup_failed != 0)); then
    printf 'Удаление сервера и публичного адреса не подтверждено\n' >&2
    ((original_code != 0)) || original_code=1
  else
    printf 'Сервер и публичный адрес удалены и повторно проверены\n'
  fi
  exit "$original_code"
}

trap 'cleanup_timeweb "$?"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
```

## 6. Создание и проверка сервера

После прямого разрешения пользователя выполните:

```bash
server_json="$(twc server create --name "$server_name" --image 99 --preset-id 4805 --region ru-3 --ssh-key shura --user-data "$user_data_file" --disable-ssh-password-auth --output json)"
server_id="$(jq -er '.server.id' <<<"$server_json")"
unset server_json

deadline=$((SECONDS + 1200))
until twc server get "$server_id" --output json |
  jq -e '.server.status == "on"' >/dev/null; do
  ((SECONDS < deadline))
  sleep 10
done

recover_timeweb_ids
test -n "$server_ip"
test -n "$server_ip_id"

known_hosts_file="$(mktemp)"
ssh-keyscan -p "$ssh_port" -H "$server_ip" >"$known_hosts_file"
ssh-keygen -lf "$known_hosts_file"

ssh_options=(
  -i "$HOME/.ssh/id_ed25519"
  -o IdentitiesOnly=yes
  -p "$ssh_port"
  -o "UserKnownHostsFile=$known_hosts_file"
  -o StrictHostKeyChecking=yes
)

scp_options=(
  -i "$HOME/.ssh/id_ed25519"
  -o IdentitiesOnly=yes
  -P "$ssh_port"
  -o "UserKnownHostsFile=$known_hosts_file"
  -o StrictHostKeyChecking=yes
)

ssh "${ssh_options[@]}" "root@$server_ip" '
  cloud-init status --wait
  timedatectl set-ntp true
  systemctl restart systemd-timesyncd
  for attempt in {1..60}; do
    if [[ "$(timedatectl show -p NTPSynchronized --value)" = yes ]]; then
      date -u
      exit 0
    fi
    sleep 2
  done
  exit 1
'
ssh "${ssh_options[@]}" "root@$server_ip" 'test "$(uname -m)" = x86_64; . /etc/os-release; test "$VERSION_ID" = 24.04'
```

Зафиксируйте показанный отпечаток ключа узла. Если возможно, сравните его с консолью Timeweb до передачи исходников. Передача исходников начинается только после завершения `cloud-init` и синхронизации времени.

## 7. Передача зафиксированных деревьев

```bash
ssh "${ssh_options[@]}" "root@$server_ip" 'install -d /opt/src/lightpanda /opt/src/curl-impersonate'

git -C "$lightpanda_repo" archive --format=tar "$lightpanda_sha" |
  ssh "${ssh_options[@]}" "root@$server_ip" 'tar -xpf - -C /opt/src/lightpanda'

git -C "$curl_repo" archive --format=tar "$curl_sha" |
  ssh "${ssh_options[@]}" "root@$server_ip" 'tar -xpf - -C /opt/src/curl-impersonate'

ssh "${ssh_options[@]}" "root@$server_ip" 'test ! -e /opt/src/lightpanda/.git; test ! -e /opt/src/curl-impersonate/.git'
```

## 8. Подготовка Ubuntu

Выполните на сервере:

```bash
set -Eeuo pipefail

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf automake binutils build-essential bzip2 ca-certificates cmake curl file git golang-go gperf jq libtool make ninja-build patch pkg-config python3 ripgrep unzip xz-utils

install_zig() {
  local version="$1"
  local metadata tarball shasum archive install_dir

  metadata="$(
    curl -fsSL https://ziglang.org/download/index.json | jq -ce --arg version "$version" '.[$version]["x86_64-linux"] | {tarball, shasum}'
  )"
  tarball="$(jq -er '.tarball' <<<"$metadata")"
  shasum="$(jq -er '.shasum' <<<"$metadata")"
  archive="/tmp/zig-$version.tar.xz"
  install_dir="/opt/zig/$version"
  curl -fsSL "$tarball" -o "$archive"
  printf '%s  %s\n' "$shasum" "$archive" | sha256sum -c -
  install -d "$install_dir"
  tar -xJf "$archive" --strip-components=1 -C "$install_dir"
  unlink "$archive"
  "$install_dir/zig" version
}

install_zig 0.14.0
install_zig 0.16.0

curl --proto '=https' --tlsv1.2 -fsSLo /tmp/rustup-init.sh https://sh.rustup.rs
sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain stable
unlink /tmp/rustup-init.sh
export PATH="$HOME/.cargo/bin:$PATH"
rustc --version
cargo --version
```

## 9. Сборка curl-impersonate

```bash
base_path="$PATH"
export PATH="/opt/zig/0.14.0:$base_path"
cd /opt/src/curl-impersonate
export CC="$PWD/zigshim/cc"
export CXX="$PWD/zigshim/cxx"
export AR="$PWD/zigshim/ar"
export ZIG_FLAGS='-target x86_64-linux-gnu.2.17'

install_dir=/opt/out/curl-impersonate
install -d "$install_dir"
cmake_args="-G Ninja -DCMAKE_INSTALL_PREFIX=$install_dir -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 -DCURL_IMPERSONATE_CXX_RUNTIME_LIBRARY=c++ -DCURL_IMPERSONATE_ENV_HOOK=OFF -DCURL_CA_PATH=/etc/ssl/certs -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt"

make prepare-libidn2 BUILD_DIR=build
make configure BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
make build BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
make checkbuild BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
make install-strip BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"

install_lib_dir="$install_dir/lib"
deps_lib_dir="$PWD/build/deps/install/lib"
dependency_archives=(
  libz.a libzstd.a libbrotlidec.a libbrotlicommon.a libbrotlienc.a
  libnghttp2.a libnghttp3.a libngtcp2.a libngtcp2_crypto_boringssl.a
  libssl.a libcrypto.a
)
for archive_name in "${dependency_archives[@]}"; do
  cp "$deps_lib_dir/$archive_name" "$install_lib_dir/"
done
if [[ -f "$deps_lib_dir/libidn2.a" ]]; then
  cp "$deps_lib_dir/libidn2.a" "$install_lib_dir/"
fi

cd "$install_lib_dir"
cp libcurl-impersonate.a libcurl-impersonate.orig.a
link_archives=(
  libcurl-impersonate.orig.a libz.a libzstd.a libbrotlidec.a
  libbrotlicommon.a libbrotlienc.a libnghttp2.a libnghttp3.a
  libngtcp2.a libngtcp2_crypto_boringssl.a libssl.a libcrypto.a
)
if [[ -f libidn2.a ]]; then
  link_archives+=(libidn2.a)
fi

cxx_link="$("$CXX" -### -shared -o runtime-probe.so libcurl-impersonate.orig.a 2>&1)"
libcxx="$(printf '%s\n' "$cxx_link" |
  rg -o '/[^[:space:]]+/libc\+\+\.a' | head -n 1)"
libcxxabi="$(printf '%s\n' "$cxx_link" |
  rg -o '/[^[:space:]]+/libc\+\+abi\.a' | head -n 1)"
libunwind="$(printf '%s\n' "$cxx_link" |
  rg -o '/[^[:space:]]+/libunwind\.a' | head -n 1)"
test -f "$libcxx"
test -f "$libcxxabi"
test -f "$libunwind"

"$CC" -r -o libcurl-impersonate.full.o -Wl,--whole-archive "${link_archives[@]}" -Wl,--no-whole-archive -Wl,--start-group "$libcxx" "$libcxxabi" "$libunwind" -Wl,--end-group
"$AR" rcs libcurl-impersonate-complete.a libcurl-impersonate.full.o
unlink libcurl-impersonate.full.o

curl_archive="$install_lib_dir/libcurl-impersonate-complete.a"
curl_include="$install_dir/include"
readelf -h "$curl_archive" | rg 'Machine:.*X86-64' >/dev/null
nm -g --defined-only "$curl_archive" | rg 'curl_easy_impersonate$'
if nm -u "$curl_archive" |
  rg '[[:space:]]U (_Z|__cxa|__gxx|_Unwind)'; then
  exit 1
fi
sha256sum "$curl_archive"

CURL_IMPERSONATE=lightpanda-invalid-profile CURL_IMPERSONATE_HEADERS=no "$install_dir/bin/curl-impersonate" --silent --show-error --output /dev/null file:///dev/null
```

## 10. Сборка и проверка Lightpanda

Передайте вычисленную локально версию в удаленный сеанс как `LINUX_VERSION`. Затем выполните:

```bash
export PATH="/opt/zig/0.16.0:$base_path"
unset CC CXX AR ZIG_FLAGS
export PATH="$HOME/.cargo/bin:$PATH"
cd /opt/src/lightpanda
test "$(uname -m)" = x86_64
test "$(zig version)" = 0.16.0
mkdir -p "${ZIG_GLOBAL_CACHE_DIR:-$HOME/.cache/zig}/tmp"
make download-v8

v8_archive="$(
  make -s --no-print-directory --eval "print-v8-cache:;@printf '%s\n' '\$(V8_CACHE)'" print-v8-cache
)"
test -f "$v8_archive"

build_flags=(
  -Dcpu=x86_64
  "-Dversion=$LINUX_VERSION"
  "-Dprebuilt_v8_path=$v8_archive"
  "-Dcurl_impersonate_archive=$curl_archive"
  "-Dcurl_impersonate_include=$curl_include"
)

export CURL_IMPERSONATE=lightpanda-invalid-profile
export CURL_IMPERSONATE_HEADERS=lightpanda-invalid-headers

zig fmt --check ./*.zig ./**/*.zig
zig build "${build_flags[@]}" check
test_log="$(mktemp)"
zig build "${build_flags[@]}" test -freference-trace 2>&1 |
  tee "$test_log"
rg -F '1156 of 1156 tests passed' "$test_log"

zig build "${build_flags[@]}" -Doptimize=ReleaseFast snapshot_creator -- src/snapshot.bin
test -s src/snapshot.bin
zig build "${build_flags[@]}" -Doptimize=ReleaseFast -Dsnapshot_path=../../snapshot.bin

lightpanda=/opt/src/lightpanda/zig-out/bin/lightpanda
file "$lightpanda" | rg 'ELF 64-bit.*x86-64'
test "$("$lightpanda" version)" = "$LINUX_VERSION"
readelf -h "$lightpanda" | rg 'Machine:.*X86-64'
nm "$lightpanda" | rg 'curl_easy_impersonate$'
if ldd "$lightpanda" | rg 'lib(curl|ssl|crypto)'; then
  exit 1
fi

install -D -m 0755 "$lightpanda" /opt/out/lightpanda

retry_check() {
  local label="$1"
  local command_name="$2"
  local attempt

  for attempt in 1 2 3; do
    if "$command_name"; then
      printf '%s: успешно, попытка %s\n' "$label" "$attempt"
      return 0
    fi
    sleep 5
  done
  return 1
}

check_example() {
  "$lightpanda" fetch --json --wait-until done --terminate-ms 30000 \
    --dump html https://example.com >/tmp/example.json &&
    jq -e '.http_status == 200 and (.content | contains("Example Domain"))' \
      /tmp/example.json >/dev/null
}

check_rzd() {
  "$lightpanda" fetch --json --wait-until done --terminate-ms 30000 \
    --dump html https://rzd.ru/ >/tmp/rzd.json &&
    jq -e '.http_status == 200 and (.content | contains("РЖД"))' \
      /tmp/rzd.json >/dev/null
}

check_self_signed() {
  "$lightpanda" fetch --json --wait-until done --terminate-ms 15000 \
    https://self-signed.badssl.com/ >/tmp/self-signed.json \
    2>/tmp/self-signed.log &&
    jq -e '.http_status == 0' /tmp/self-signed.json >/dev/null &&
    rg -F PeerFailedVerification /tmp/self-signed.log >/dev/null
}

network_example=fail
network_rzd=fail
network_self_signed=fail
retry_check example.com check_example && network_example=pass
retry_check rzd.ru check_rzd && network_rzd=pass
retry_check self-signed.badssl.com check_self_signed && \
  network_self_signed=pass

printf 'NETWORK_EXAMPLE=%s\nNETWORK_RZD=%s\nNETWORK_SELF_SIGNED=%s\n' \
  "$network_example" "$network_rzd" "$network_self_signed" \
  >/opt/out/network-status.txt

stat -c '%s' "$lightpanda"
sha256sum "$lightpanda"
```

## 11. Получение результата

Вернитесь в тот же локальный сеанс:

```bash
install -d "$release_dir"
test ! -e "$local_binary"
local_partial="$release_dir/.lightpanda-x86_64-linux.partial"
test ! -e "$local_partial"

remote_sha="$(
  ssh "${ssh_options[@]}" "root@$server_ip" 'sha256sum /opt/out/lightpanda' |
    awk '{print $1}'
)"
scp "${scp_options[@]}" "root@$server_ip:/opt/out/lightpanda" "$local_partial"
scp "${scp_options[@]}" "root@$server_ip:/opt/out/network-status.txt" \
  "$release_dir/.lightpanda-x86_64-linux-network-status.txt"

local_sha="$(shasum -a 256 "$local_partial" | awk '{print $1}')"
test "$remote_sha" = "$local_sha"
rg -F 'NETWORK_EXAMPLE=pass' \
  "$release_dir/.lightpanda-x86_64-linux-network-status.txt"
rg -F 'NETWORK_RZD=pass' \
  "$release_dir/.lightpanda-x86_64-linux-network-status.txt"
rg -F 'NETWORK_SELF_SIGNED=pass' \
  "$release_dir/.lightpanda-x86_64-linux-network-status.txt"
unlink "$release_dir/.lightpanda-x86_64-linux-network-status.txt"

chmod 0755 "$local_partial"
mv "$local_partial" "$local_binary"

file "$local_binary" | rg 'ELF 64-bit.*x86-64'
shasum -a 256 "$local_binary"
```

Последней командой сеанса удалите временные ресурсы:

```bash
cleanup_timeweb 0
```

Успешным результатом считается только сообщение о повторной проверке удаления сервера и публичного адреса.

## 12. Критерии приемки

01. Записаны полные SHA Lightpanda и curl-impersonate.

02. Переданы только деревья этих коммитов, без `.git`.

03. Сервер вернул `x86_64` и Ubuntu 24.04.

04. curl-impersonate собран с `CURL_IMPERSONATE_ENV_HOOK=OFF`.

05. В архиве и бинарном файле присутствует `curl_easy_impersonate`.

06. `ldd` не показывает динамические `libcurl`, `libssl` и `libcrypto`.

07. Форматирование, проверка графа и 1 156 тестов прошли с враждебными переменными среды.

08. Итоговый файл имеет формат ELF64 x86-64 и точную заданную версию.

09. `example.com` и `rzd.ru` вернули HTTP 200, недоверенный сертификат отклонен.

10. Контрольные суммы удаленного и локального файлов совпали.

11. Использован один сервер с одним автоматически назначенным адресом; отдельный плавающий адрес не создавался.

12. Сервер и публичный адрес отсутствуют в повторных списках Timeweb.

## 13. Источники

1. Рецепт статического архива основан на [задании Linux curl-impersonate](https://github.com/lexiforest/curl-impersonate/blob/ec41b71ce888806bfec56ada7a7258d333eb3d19/.github/workflows/build.yml).

2. Управление сервером сверяйте с [документацией Timeweb](https://timeweb.cloud/docs/cloud-servers/manage-servers/create-server) и [справочником TWC CLI](https://github.com/timeweb-cloud/twc/blob/master/docs/ru/CLI_REFERENCE.md).
