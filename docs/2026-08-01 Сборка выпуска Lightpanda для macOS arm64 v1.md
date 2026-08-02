# Сборка выпуска Lightpanda для macOS arm64

Дата инструкции: 1 августа 2026 года.

## Периметр

Инструкция создает выпуск `Lightpanda` для компьютера с `Darwin arm64`. Итоговый файл содержит статически связанную библиотеку `curl-impersonate`, которая программно применяет профиль Chrome 146 к каждому соединению и не принимает профиль из переменных среды.

Сборка для Linux не входит в этот выпуск. Для нее действует [отдельная инструкция по нативной сборке на Timeweb](2026-08-01%20%D0%A1%D0%B1%D0%BE%D1%80%D0%BA%D0%B0%20Lightpanda%20%D0%B4%D0%BB%D1%8F%20Linux%20%D0%BD%D0%B0%20Timeweb%20v3.md).

## Обязательные фиксации

| Каталог            | Обязательная фиксация                        | Назначение                                                                              |
| ------------------ | -------------------------------------------- | --------------------------------------------------------------------------------------- |
| `lightpanda`       | Чистый `HEAD` после фиксации этого документа | Статическая библиотека `curl-impersonate` и программный профиль каждого запроса         |
| `curl-impersonate` | `126d1e43e83b55b7ccfbd618addd19eb43cc5e37`   | Отключение `SecTrust` из `242a4bc98172d5a90367c75de0b5014d40bf32cf` и обработчика среды |

Фиксация `lightpanda` должна содержать изменения `Link curl-impersonate as external static library` и `Apply Chrome impersonation to every HTTP connection`. Полный SHA используемого `HEAD` записывается в итоговый `RELEASE.md`.

## Подготовка

Используйте новый процесс оболочки `Bash 5+` и выполните команды одним сеансом:

```bash
set -euo pipefail

workspace=/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents
lightpanda_root="$workspace/lightpanda"
curl_root="$workspace/curl-impersonate"
release_dir="$lightpanda_root/build"
release_bin="$release_dir/lightpanda-aarch64-macos"

curl_required=126d1e43e83b55b7ccfbd618addd19eb43cc5e37

test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
test "$(zig version)" = 0.16.0
test "$(cmake --version | awk 'NR == 1 { print $3 }')" = 4.4.2
command -v cargo cmake cmp jq make ninja nm otool shasum xcrun >/dev/null
macos_sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
test -d "$macos_sdk_path/System/Library/Frameworks"
test -d "$macos_sdk_path/usr/lib"

rg -F 'curl_impersonate_archive' "$lightpanda_root/build.zig"
rg -F 'curl_easy_impersonate(self._easy, IMPERSONATION_TARGET, true)' \
  "$lightpanda_root/src/network/http.zig"
git -C "$curl_root" merge-base --is-ancestor "$curl_required" HEAD
test "$(git -C "$curl_root" rev-parse HEAD)" = "$curl_required"

test -z "$(git -C "$lightpanda_root" status --porcelain)"
test -z "$(git -C "$curl_root" status --porcelain)"
test ! -e "$release_bin"
test ! -e "$release_dir/LICENSE"
test ! -e "$release_dir/LICENSING.md"
test ! -e "$release_dir/RELEASE.md"
test ! -e "$release_dir/SHA256SUMS"

lightpanda_source_commit="$(git -C "$lightpanda_root" rev-parse HEAD)"
curl_source_commit="$(git -C "$curl_root" rev-parse HEAD)"
```

Для проверенного окружения использовались `Xcode 26.5`, `SDK macOS 26.5`, `CMake 4.4.2`, `Ninja 1.13.2`, `GNU Make 4.4.1`, `Zig 0.16.0` и `Rust 1.91.1`. Если версии отличаются, сохраните их в `RELEASE.md` и не заявляйте побайтовое совпадение с прежней сборкой.

## Сборка curl-impersonate

Создайте отдельный каталог сборки. Параметр `CURL_IMPERSONATE_ENV_HOOK=OFF` обязателен: профиль задает `Lightpanda`, поэтому переменные `CURL_IMPERSONATE` и `CURL_IMPERSONATE_HEADERS` не должны менять поведение библиотеки.

```bash
curl_build="$curl_root/build-release-macos-arm64"
curl_install="$curl_build/install"
curl_archive="$curl_install/lib/libcurl-impersonate-complete.a"
curl_include="$curl_install/include"

test ! -e "$curl_build"

curl_cmake_args=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  "-DCMAKE_INSTALL_PREFIX=$curl_install"
  -DCMAKE_OSX_ARCHITECTURES=arm64
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0
  -DUSE_APPLE_SECTRUST=OFF
  -DCURL_IMPERSONATE_ENV_HOOK=OFF
)

cmake -S "$curl_root" -B "$curl_build" "${curl_cmake_args[@]}"
cmake --build "$curl_build" --parallel
make -C "$curl_root" checkbuild BUILD_DIR="$curl_build"
cmake --build "$curl_build" --target curl-install --parallel
cmake --install "$curl_build" --strip

grep -Fx 'CURL_IMPERSONATE_ENV_HOOK:BOOL=OFF' "$curl_build/CMakeCache.txt"
grep -Fx 'CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0' \
  "$curl_build/CMakeCache.txt"
grep -Fx 'USE_APPLE_SECTRUST:BOOL=OFF' "$curl_build/CMakeCache.txt"
```

Объедините статическую библиотеку `curl-impersonate` и ее зависимости в один архив:

```bash
curl_static_inputs=(
  "$curl_install/lib/libcurl-impersonate.a"
  "$curl_build/deps/install/lib/libbrotlicommon.a"
  "$curl_build/deps/install/lib/libbrotlidec.a"
  "$curl_build/deps/install/lib/libbrotlienc.a"
  "$curl_build/deps/install/lib/libcrypto.a"
  "$curl_build/deps/install/lib/libnghttp2.a"
  "$curl_build/deps/install/lib/libnghttp3.a"
  "$curl_build/deps/install/lib/libngtcp2.a"
  "$curl_build/deps/install/lib/libngtcp2_crypto_boringssl.a"
  "$curl_build/deps/install/lib/libssl.a"
  "$curl_build/deps/install/lib/libz.a"
  "$curl_build/deps/install/lib/libzstd.a"
)

for curl_static_input in "${curl_static_inputs[@]}"; do
  test -f "$curl_static_input"
done

/usr/bin/libtool -static -o "$curl_archive" "${curl_static_inputs[@]}"
test "$(ar -t "$curl_archive" | wc -l | tr -d '[:space:]')" = 791
file "$curl_archive" | grep -F 'current ar archive'
nm -gU "$curl_archive" | grep -E ' T _curl_easy_impersonate$'

if nm -u "$curl_archive" | grep -E \
  '_(SecTrust|SecCertificate|SecPolicy|SecKeychain)'; then
  printf 'Найдена зависимость Apple SecTrust\n' >&2
  exit 1
fi

CURL_IMPERSONATE=lightpanda-invalid-profile \
CURL_IMPERSONATE_HEADERS=no \
  "$curl_install/bin/curl-impersonate" \
  --silent --show-error --output /dev/null file:///dev/null
```

Последняя команда должна завершиться с кодом 0. Ошибка неизвестного профиля означает, что обработчик переменных среды остался включен.

## Сборка Lightpanda

Загрузите архив V8, проверьте форматирование и граф сборки, затем выполните 1130 тестов:

```bash
cd "$lightpanda_root"
make download-v8

v8_archive="$(make -s --no-print-directory \
  --eval "print-v8-cache:;@printf '%s\n' '\$(V8_CACHE)'" \
  print-v8-cache)"
test -f "$v8_archive"

build_flags=(
  -Dtarget=aarch64-macos.12.0
  "-Dmacos_sdk_path=$macos_sdk_path"
  "-Dprebuilt_v8_path=$v8_archive"
  "-Dcurl_impersonate_archive=$curl_archive"
  "-Dcurl_impersonate_include=$curl_include"
)

zig fmt --check ./*.zig ./**/*.zig
zig build "${build_flags[@]}" check

test_log="$(mktemp)"
CURL_IMPERSONATE=lightpanda-invalid-profile \
CURL_IMPERSONATE_HEADERS=lightpanda-invalid-headers \
  zig build "${build_flags[@]}" test -freference-trace 2>&1 | tee "$test_log"
grep -F '1130 of 1130 tests passed' "$test_log"
```

Создайте `src/snapshot.bin`, затем соберите исполняемый файл в режиме `ReleaseFast` с теми же явными путями:

```bash
zig build "${build_flags[@]}" -Doptimize=ReleaseFast \
  snapshot_creator -- src/snapshot.bin
test -s src/snapshot.bin

zig build "${build_flags[@]}" -Doptimize=ReleaseFast \
  -Dsnapshot_path=../../snapshot.bin

lightpanda_bin="$lightpanda_root/zig-out/bin/lightpanda"
test -x "$lightpanda_bin"
```

## Проверка исполняемого файла

Проверьте архитектуру, встроенный символ и динамические зависимости:

```bash
file "$lightpanda_bin" | grep -F 'Mach-O 64-bit executable arm64'
"$lightpanda_bin" version
nm -gU "$lightpanda_bin" | grep -E ' T _curl_easy_impersonate$'

macos_minos="$(
  otool -l "$lightpanda_bin" |
    awk '$1 == "minos" { print $2; exit }'
)"
test "$macos_minos" = 12.0

if otool -L "$lightpanda_bin" | grep -E 'lib(curl|ssl|crypto)'; then
  printf 'Найдена динамическая зависимость curl или TLS\n' >&2
  exit 1
fi
```

Наличие `Security.framework` допустимо как зависимость V8. Запрещены динамические `libcurl`, `libssl` и `libcrypto`.

Проверьте доверенный и недоверенный сертификаты без переменных среды `curl-impersonate`:

```bash
network_tmp="$(mktemp -d)"

env -u CURL_IMPERSONATE -u CURL_IMPERSONATE_HEADERS \
  "$lightpanda_bin" fetch \
  --json \
  --wait-until done \
  --dump html \
  https://example.com \
  > "$network_tmp/example.json"

jq -e \
  '.http_status == 200 and (.content | contains("Example Domain"))' \
  "$network_tmp/example.json"

env -u CURL_IMPERSONATE -u CURL_IMPERSONATE_HEADERS \
  "$lightpanda_bin" fetch \
  --json \
  --wait-until done \
  --dump html \
  https://rzd.ru/ \
  > "$network_tmp/rzd.json"

jq -e \
  '.http_status == 200 and (.content | contains("РЖД"))' \
  "$network_tmp/rzd.json"

env -u CURL_IMPERSONATE -u CURL_IMPERSONATE_HEADERS \
  "$lightpanda_bin" fetch \
  --json \
  --wait-until done \
  --terminate-ms 15000 \
  https://self-signed.badssl.com/ \
  > "$network_tmp/self-signed.json" \
  2> "$network_tmp/self-signed.log"

jq -e '.http_status == 0' "$network_tmp/self-signed.json"
grep -F 'PeerFailedVerification' "$network_tmp/self-signed.log"
```

HTTP 200 для недоверенного сертификата означает ошибку выпуска.

## Формирование общего каталога выпуска

Скопируйте готовый исполняемый файл и документы о лицензировании прямо в общий каталог `build`. Снимок V8 уже включен в исполняемый файл параметром `snapshot_path`. Позже отдельная инструкция добавит в этот же каталог файл Linux и пересоздаст общие `SHA256SUMS` и `RELEASE.md`.

```bash
mkdir -p "$release_dir"
install -m 0755 "$lightpanda_bin" "$release_bin"
install -m 0644 "$lightpanda_root/LICENSE" "$release_dir/LICENSE"
install -m 0644 "$lightpanda_root/LICENSING.md" "$release_dir/LICENSING.md"

cmp -s "$lightpanda_root/LICENSE" "$release_dir/LICENSE"
cmp -s "$lightpanda_root/LICENSING.md" "$release_dir/LICENSING.md"

lightpanda_sha="$(shasum -a 256 "$release_bin" | cut -d ' ' -f 1)"
curl_archive_sha="$(shasum -a 256 "$curl_archive" | cut -d ' ' -f 1)"

cat > "$release_dir/RELEASE.md" <<EOF
# Выпуск Lightpanda

- Дата: 2026-08-01.
- Файл macOS arm64: \`lightpanda-aarch64-macos\`.
- Минимальная версия из заголовка Mach-O: macOS \`$macos_minos\`.
- Фиксация Lightpanda: \`$lightpanda_source_commit\`.
- Фиксация curl-impersonate: \`$curl_source_commit\`.
- SHA-256 Lightpanda: \`$lightpanda_sha\`.
- SHA-256 статического архива curl-impersonate: \`$curl_archive_sha\`.
- Параметр CURL_IMPERSONATE_ENV_HOOK: \`OFF\`.
- Параметр USE_APPLE_SECTRUST: \`OFF\`.
- Тесты: \`1130 of 1130 tests passed\`.
- Linux: отсутствует на этапе выпуска macOS.
- Распространение: только внутреннее использование без Developer ID и нотариального заверения Apple.
EOF

(
  cd "$release_dir"
  shasum -a 256 \
    lightpanda-aarch64-macos \
    LICENSE \
    LICENSING.md \
    RELEASE.md \
    > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)

test "$(find "$release_dir" -maxdepth 1 -type f | wc -l | tr -d '[:space:]')" = 5
```

Каталог [`../build`](../build) должен содержать `lightpanda-aarch64-macos`, `LICENSE`, `LICENSING.md`, `SHA256SUMS` и `RELEASE.md`. Вложенный каталог `lightpanda-aarch64-macos` создавать нельзя.

Без подписи удостоверением Developer ID и нотариального заверения Apple выпуск предназначен только для внутреннего использования. Не публикуйте его и не передавайте внешним пользователям. Выпуск также нельзя использовать, если хотя бы одна проверка завершилась ненулевым кодом.

## Linux

Этот выпуск предназначен только для macOS arm64. Файлы Linux, кросс-сборка и результаты под эмуляцией в каталог выпуска не входят.
