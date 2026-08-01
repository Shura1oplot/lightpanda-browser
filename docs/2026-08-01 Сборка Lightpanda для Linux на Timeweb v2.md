# Сборка Lightpanda для Linux на временном сервере Timeweb

Дата актуализации: 1 августа 2026 года.

## 1. Назначение и статус

1. Эта инструкция предназначена для сборки ветки Lightpanda, которая статически связывается с локально собранной библиотекой curl-impersonate.

2. Целевая среда для `linux/amd64` – Ubuntu 24.04 на сервере с нативной архитектурой `x86_64`.

3. Программное применение профиля Chrome 146 после слияния с исходными репозиториями проверено только на macOS arm64. Приведенный ниже путь Linux основан на ранее успешной нативной сборке проекта и действующем рецепте Linux из системы непрерывной интеграции curl-impersonate. Текущая интеграция на Linux еще не проверена. После каждого изменения исходников путь нужно заново выполнить на нативном сервере. Не называйте Linux-сборку проверенной, пока все критерии раздела 10 не выполнены в текущем запуске.

4. Профиль `chrome146` в curl-impersonate содержит заголовки macOS. На Linux Lightpanda заменяет `User-Agent` и `Sec-Ch-Ua`, но сохраняет `Sec-Ch-Ua-Platform: "macOS"` из профиля. До отдельной адаптации набор заголовков Linux может оставаться смешанным. Учитывайте это ограничение при оценке сетевого отпечатка.

## 2. Почему нельзя собирать `linux/amd64` на компьютере Apple Silicon

1. В проверенном окружении Apple M4 Pro с OrbStack 2.2.1 сборка контейнера `linux/amd64` через Rosetta завершалась ошибкой `rosetta error: bss_size overflow`.

2. Ошибка воспроизводилась в отдельных процессах Zig `translate-c` при обработке Curl, SQLite и Isocline. Отдельный сборщик BuildKit не устранил проблему.

3. Не выполняйте сборку `linux/amd64` на Apple Silicon через Docker, OrbStack, Rosetta, QEMU или другую эмуляцию процессора. Используйте нативный сервер Timeweb с архитектурой `x86_64`; команда `uname -m` должна вернуть `x86_64`. Для `linux/arm64` она должна вернуть `aarch64`; наличие подходящих серверов Timeweb нужно проверять отдельно.

## 3. Обязательные ограничения

1. До создания платного сервера покажите пользователю регион, образ, параметры, цену и предполагаемое время работы. Получите прямое разрешение на создание ресурса.

2. Не закрепляйте в инструкции идентификаторы образа, тарифа, проекта, сервера или адреса. Получайте их заново перед каждым запуском.

3. Не читайте токены из `.env` автоматически, не включайте трассировку команд и не передавайте секреты на сервер. Для утилиты `twc` используется переменная `TWC_TOKEN` или ее защищенный профиль.

4. Передавайте только содержимое зафиксированных коммитов. Не передавайте `.git`, `.env`, локальные сборочные каталоги, токены и закрытые ключи.

5. После получения и проверки результата удалите сервер и связанный публичный адрес. Не используйте параметр `--keep-public-ip`. Задача не завершена, пока удаление не подтверждено повторной проверкой.

## 4. Подготовка и создание сервера

1. Выполняйте разделы 4, 5 и 11 в одном выделенном сеансе Bash на macOS. Не запускайте команды создания и удаления сервера в отдельных непостоянных оболочках. Агент должен открыть один сеанс терминала и использовать его до удаления ресурсов.

   ```bash
   set -euo pipefail
   ```

2. На компьютере macOS установите и проверьте текущую принятую проектом версию командной утилиты:

   ```bash
   uv tool install 'twc-cli==2.15.2'
   twc --version
   twc whoami
   ```

3. Получите актуальные варианты Ubuntu и тарифы московского региона. Ранее рабочий маршрут находился в регионе `ru-3`. Санкт-Петербург возвращал `409 no_free_node`, поэтому не меняйте регион автоматически после ошибки:

   ```bash
   twc server list-os-images -f name:ubuntu
   twc server list-presets --region ru-3
   ```

4. Покажите выбранные значения и цену пользователю. Только после разрешения создайте сервер Ubuntu 24.04 с нативной архитектурой `x86_64` и входом по открытому ключу. Сразу после получения идентификатора установите обязательный обработчик завершения. Он удаляет сервер при любой последующей ошибке и сохраняет исходный код выхода:

   ```bash
   server_name="lightpanda-linux-amd64-$(date -u +%Y%m%dT%H%M%SZ)"
   server_json="$(twc server create \
     --name "$server_name" \
     --image '<АКТУАЛЬНЫЙ_ОБРАЗ_UBUNTU_24_04>' \
     --preset-id '<АКТУАЛЬНЫЙ_ТАРИФ_RU_3>' \
     --region ru-3 \
     --ssh-key "$HOME/.ssh/id_ed25519.pub" \
     --disable-ssh-password-auth \
     --output json)"
   server_id="$(jq -er '.server.id' <<<"$server_json")"
   unset server_json
   printf 'Идентификатор сервера: %s\n' "$server_id"

   cleanup_timeweb() {
     local original_code="$1"
     local cleanup_failed=0
     local server_ids ip_json
     trap - EXIT

     if [[ -n "${server_id:-}" ]]; then
       if ! twc server remove --yes "$server_id"; then
         cleanup_failed=1
       fi
       if server_ids="$(twc server list --ids)"; then
         if grep -Fxq "$server_id" <<<"$server_ids"; then
           cleanup_failed=1
         fi
       else
         cleanup_failed=1
       fi
     fi

     if [[ -n "${server_ip:-}" ]]; then
       if ip_json="$(twc ip list --output json)"; then
         if jq -e --arg ip "$server_ip" \
           '.. | strings | select(. == $ip or startswith($ip + "/"))' \
           <<<"$ip_json" >/dev/null; then
           cleanup_failed=1
         fi
       else
         cleanup_failed=1
       fi
     fi

     if [[ -n "${known_hosts_file:-}" && -e "$known_hosts_file" ]]; then
       if ! unlink "$known_hosts_file"; then
         cleanup_failed=1
       fi
     fi
     unset TWC_TOKEN

     if ((cleanup_failed != 0)); then
       printf 'Удаление ресурсов Timeweb не подтверждено\n' >&2
       if ((original_code == 0)); then
         original_code=1
       fi
     fi
     exit "$original_code"
   }
   trap 'cleanup_timeweb $?' EXIT
   ```

5. Ожидайте состояние `on` не более 20 минут:

   ```bash
   deadline=$((SECONDS + 1200))
   until twc server get "$server_id" --status >/dev/null 2>&1; do
     if ((SECONDS >= deadline)); then
       printf 'Сервер не запустился за 20 минут\n' >&2
       exit 1
     fi
     sleep 10
   done
   twc server get "$server_id" --networks
   ```

6. Запишите публичный IPv4 в переменную `server_ip`. Получите ключ узла через `ssh-keyscan`, затем сравните его отпечаток с ключом, показанным через консоль сервера Timeweb. Не отключайте проверку ключа узла:

   ```bash
   server_ip='<ПУБЛИЧНЫЙ_IPV4>'
   known_hosts_file="$(mktemp)"
   ssh-keyscan -H "$server_ip" >"$known_hosts_file"
   ssh-keygen -lf "$known_hosts_file"
   ssh_options=(-o "UserKnownHostsFile=$known_hosts_file" -o StrictHostKeyChecking=yes)
   ssh "${ssh_options[@]}" "root@$server_ip" 'uname -m && . /etc/os-release && printf "%s\n" "$PRETTY_NAME"'
   ```

7. Немедленно остановитесь, если архитектура отличается от `x86_64` или система отличается от Ubuntu 24.04. Обработчик завершения должен удалить созданные ресурсы.

## 5. Передача исходников

1. Определите точные коммиты обоих локальных репозиториев:

   ```bash
   lightpanda_repo='/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/lightpanda'
   curl_repo='/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/curl-impersonate'
   lightpanda_sha="$(git -C "$lightpanda_repo" rev-parse HEAD)"
   curl_sha="$(git -C "$curl_repo" rev-parse HEAD)"
   printf 'Lightpanda: %s\ncurl-impersonate: %s\n' "$lightpanda_sha" "$curl_sha"
   ```

2. Если коммиты опубликованы, клонируйте открытые форки по HTTPS и перейдите на точные полные SHA. Если они еще не опубликованы, передайте только зафиксированные деревья через `git archive`:

   ```bash
   ssh "${ssh_options[@]}" "root@$server_ip" 'install -d /opt/src/lightpanda /opt/src/curl-impersonate'
   git -C "$lightpanda_repo" archive "$lightpanda_sha" | \
     ssh "${ssh_options[@]}" "root@$server_ip" 'tar -xf - -C /opt/src/lightpanda'
   git -C "$curl_repo" archive "$curl_sha" | \
     ssh "${ssh_options[@]}" "root@$server_ip" 'tar -xf - -C /opt/src/curl-impersonate'
   ```

3. Сохраните оба SHA в журнале результата. Не используйте `scp -r` для передачи рабочих каталогов.

## 6. Подготовка Ubuntu

1. Подключитесь к серверу и выполняйте дальнейшие команды в Bash с остановкой при первой ошибке:

   ```bash
   set -euo pipefail
   apt-get update
   DEBIAN_FRONTEND=noninteractive apt-get install -y \
     autoconf automake binutils build-essential bzip2 ca-certificates cmake curl file \
     git gperf jq libtool make ninja-build patch pkg-config python3 unzip xz-utils \
     golang-go
   ```

2. Установите Zig 0.14.0 для действующего рецепта curl-impersonate и минимальную версию Zig из `build.zig.zon` для Lightpanda, сейчас это 0.16.0. Получайте адрес и контрольную сумму из официального индекса Zig:

   ```bash
   install_zig() {
     local version="$1"
     local metadata tarball shasum archive install_dir
     metadata="$(curl -fsSL https://ziglang.org/download/index.json | \
       jq -ce --arg version "$version" '.[$version]["x86_64-linux"] | {tarball, shasum}')"
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
   ```

3. Установите стабильную цепочку Rust, которую использует действие установки Lightpanda, и запишите фактическую версию:

   ```bash
   curl --proto '=https' --tlsv1.2 -fsSLo /tmp/rustup-init.sh https://sh.rustup.rs
   sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain stable
   unlink /tmp/rustup-init.sh
   export PATH="$HOME/.cargo/bin:$PATH"
   rustc --version
   cargo --version
   ```

## 7. Сборка полного статического архива curl-impersonate

1. Выполните официальный рецепт Linux для `x86_64-linux-gnu` из системы непрерывной интеграции curl-impersonate:

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
   cmake_args="-G Ninja -DCMAKE_INSTALL_PREFIX=$install_dir \
   -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
   -DCURL_IMPERSONATE_CXX_RUNTIME_LIBRARY=c++ \
   -DCURL_IMPERSONATE_ENV_HOOK=OFF \
   -DCURL_CA_PATH=/etc/ssl/certs \
   -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt"

   make prepare-libidn2 BUILD_DIR=build
   make configure BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
   make build BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
   make checkbuild BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
   make install-strip BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$cmake_args"
   ```

2. Объедините curl-impersonate, зависимости и целевые библиотеки среды C++ Zig в один архив. Этот блок повторяет логику действующего Linux-задания исходного репозитория, но сохраняет обычный архив и записывает результат как `libcurl-impersonate-complete.a`:

   ```bash
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
   libcxx="$(printf '%s\n' "$cxx_link" | grep -oE '/[^[:space:]]+/libc\+\+\.a' | head -n 1)"
   libcxxabi="$(printf '%s\n' "$cxx_link" | grep -oE '/[^[:space:]]+/libc\+\+abi\.a' | head -n 1)"
   libunwind="$(printf '%s\n' "$cxx_link" | grep -oE '/[^[:space:]]+/libunwind\.a' | head -n 1)"
   test -f "$libcxx"
   test -f "$libcxxabi"
   test -f "$libunwind"

   "$CC" -r -o libcurl-impersonate.full.o \
     -Wl,--whole-archive "${link_archives[@]}" -Wl,--no-whole-archive \
     -Wl,--start-group "$libcxx" "$libcxxabi" "$libunwind" -Wl,--end-group
   "$AR" rcs libcurl-impersonate-complete.a libcurl-impersonate.full.o
   unlink libcurl-impersonate.full.o
   ```

3. Проверьте архив до сборки Lightpanda:

   ```bash
   curl_archive="$install_lib_dir/libcurl-impersonate-complete.a"
   curl_include="$install_dir/include"
   file "$curl_archive"
   nm -g --defined-only "$curl_archive" | grep -E 'curl_easy_impersonate$'
   if nm -u "$curl_archive" | grep -E '[[:space:]]U (_Z|__cxa|__gxx|_Unwind)'; then
     printf 'В архиве остались неразрешенные символы среды C++\n' >&2
     exit 1
   fi
   sha256sum "$curl_archive"
   ```

## 8. Сборка Lightpanda

1. Переключитесь на Zig, версия которого указана в `build.zig.zon`, загрузите соответствующий готовый архив V8 и определите его путь тем же способом, что использует Makefile:

   ```bash
   export PATH="/opt/zig/0.16.0:$base_path"
   unset CC CXX AR ZIG_FLAGS
   export PATH="$HOME/.cargo/bin:$PATH"
   cd /opt/src/lightpanda
   test "$(uname -m)" = x86_64
   test "$(zig version)" = 0.16.0
   mkdir -p "${ZIG_GLOBAL_CACHE_DIR:-$HOME/.cache/zig}/tmp"
   make download-v8

   v8_archive="$(make -s --no-print-directory \
     --eval "print-v8-cache:;@printf '%s\n' '\$(V8_CACHE)'" \
     print-v8-cache)"
   test -f "$v8_archive"
   ```

2. Проверьте форматирование и граф сборки, создайте снимок V8, затем соберите итоговый файл:

   ```bash
   build_flags=(
     "-Dcpu=x86_64"
     "-Dprebuilt_v8_path=$v8_archive"
     "-Dcurl_impersonate_archive=$curl_archive"
     "-Dcurl_impersonate_include=$curl_include"
   )

   zig fmt --check ./*.zig ./**/*.zig
   zig build "${build_flags[@]}" check
   zig build "${build_flags[@]}" test -freference-trace
   zig build "${build_flags[@]}" -Doptimize=ReleaseFast \
     snapshot_creator -- src/snapshot.bin
   zig build "${build_flags[@]}" -Doptimize=ReleaseFast \
     -Dsnapshot_path=../../snapshot.bin
   ```

## 9. Проверка результата

1. Выполните проверки архитектуры, версии, статического связывания curl-impersonate и контрольной суммы:

   ```bash
   lightpanda=zig-out/bin/lightpanda
   file "$lightpanda"
   readelf -h "$lightpanda" | grep -E 'Class:.*ELF64'
   readelf -h "$lightpanda" | grep -E 'Machine:.*X86-64'
   "$lightpanda" version
   nm "$lightpanda" | grep -E 'curl_easy_impersonate$'
   if ldd "$lightpanda" | grep -E 'lib(curl|ssl|crypto)'; then
     printf 'Найдена запрещенная динамическая зависимость\n' >&2
     exit 1
   fi
   sha256sum "$lightpanda"
   ```

2. Сначала докажите, что библиотека игнорирует встроенный обработчик переменных среды. Заведомо неверный профиль не должен мешать `curl_easy_init`; обе команды должны завершиться с кодом 0 без сетевого запроса:

   ```bash
   CURL_IMPERSONATE=lightpanda-invalid-profile \
   CURL_IMPERSONATE_HEADERS=no \
     "$install_dir/bin/curl-impersonate" \
     --silent --show-error --output /dev/null file:///dev/null

   CURL_IMPERSONATE=lightpanda-invalid-profile \
   CURL_IMPERSONATE_HEADERS=no \
     "$install_dir/bin/curl-impersonate" \
     --impersonate chrome146 \
     --silent --show-error --output /dev/null file:///dev/null
   ```

3. Проверьте реальный сетевой запрос без переменных среды curl-impersonate. Lightpanda программно применяет профиль Chrome 146 с заголовками браузера после каждого `curl_easy_reset`. Ошибка `curl_easy_impersonate` прекращает подготовку соединения. Обычные параметры libcurl после такой ошибки не применяются. Команда должна завершиться с кодом 0, поле `http_status` должно быть равно 200, а содержимое страницы должно включать `Example Domain`:

   ```bash
   env -u CURL_IMPERSONATE -u CURL_IMPERSONATE_HEADERS \
     "$lightpanda" fetch \
     --json \
     --wait-until 'done' \
     --dump html \
     https://example.com \
     > /tmp/lightpanda-example.json
   jq -e '.http_status == 200 and (.content | contains("Example Domain"))' \
     /tmp/lightpanda-example.json
   ```

4. Обязательно проверьте отклонение недоверенного сертификата. Ожидаются поле `http_status` со значением 0 и ошибка `PeerFailedVerification`; HTTP 200 означает ошибку сборки или проверки:

   ```bash
   env -u CURL_IMPERSONATE -u CURL_IMPERSONATE_HEADERS \
     "$lightpanda" fetch \
     --json \
     --wait-until 'done' \
     --terminate-ms 15000 \
     https://self-signed.badssl.com/ \
     > /tmp/lightpanda-self-signed.json \
     2> /tmp/lightpanda-self-signed.log
   jq -e '.http_status == 0' /tmp/lightpanda-self-signed.json
   grep -F 'PeerFailedVerification' /tmp/lightpanda-self-signed.log
   ```

## 10. Критерии приемки

01. Исходники соответствуют записанным полным SHA обоих репозиториев.

02. Сервер возвращает `x86_64`, а итоговый файл является ELF64 для x86-64.

03. Форматирование, `zig build check`, тесты, создание снимка V8 и сборка `ReleaseFast` завершились с кодом 0.

04. В исполняемом файле присутствует `curl_easy_impersonate`, а `ldd` не показывает динамические `libcurl`, `libssl` и `libcrypto`.

05. Неверное значение `CURL_IMPERSONATE` не влияет на инициализацию библиотеки, а явный профиль Chrome 146 продолжает применяться.

06. Профиль Chrome 146 без переменных `CURL_IMPERSONATE` и `CURL_IMPERSONATE_HEADERS` получил HTTP 200, а недоверенный сертификат отклонен с `PeerFailedVerification`.

07. Записаны версии Zig, Rust и Lightpanda, архитектура, размер и SHA-256 итогового файла и архива curl-impersonate.

08. Полученный файл скопирован на macOS, и его SHA-256 совпал на сервере и локально.

09. Сборка curl-impersonate выполнена с `CURL_IMPERSONATE_ENV_HOOK=OFF`.

10. Сервер и публичный адрес удалены и отсутствуют в повторных списках Timeweb.

## 11. Получение файла и обязательное удаление сервера

1. Вернитесь из SSH в выделенный сеанс Bash на macOS. Скопируйте итоговый файл в новый локальный путь и машинно сравните контрольные суммы на сервере и macOS:

   ```bash
   remote_binary='/opt/src/lightpanda/zig-out/bin/lightpanda'
   artifact_dir='/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/artifacts'
   local_binary="$artifact_dir/lightpanda-linux-x86_64-$lightpanda_sha"
   install -d "$artifact_dir"
   test ! -e "$local_binary"

   remote_sha="$(ssh "${ssh_options[@]}" "root@$server_ip" \
     'sha256sum /opt/src/lightpanda/zig-out/bin/lightpanda' | awk '{print $1}')"
   scp "${ssh_options[@]}" "root@$server_ip:$remote_binary" "$local_binary"
   local_sha="$(shasum -a 256 "$local_binary" | awk '{print $1}')"
   test "$remote_sha" = "$local_sha"
   file "$local_binary"
   printf 'SHA-256: %s\n' "$local_sha"
   ```

2. Вызовите обработчик завершения явно. Он удалит сервер, проверит отсутствие его идентификатора и ранее записанного публичного адреса, удалит временный файл ключей узла и завершит выделенный сеанс. Команда удаления может запросить код проверки аккаунта:

   ```bash
   cleanup_timeweb 0
   ```

3. Если обработчик завершился с ошибкой, платные ресурсы считаются существующими до ручной проверки и удаления. Не закрывайте задачу и не оставляйте сервер работающим для последующей диагностики без нового прямого указания пользователя.

## 12. Источники рецепта

1. Объединение статических архивов и проверка среды C++ взяты из [действующего задания Linux curl-impersonate](https://github.com/lexiforest/curl-impersonate/blob/ec41b71ce888806bfec56ada7a7258d333eb3d19/.github/workflows/build.yml).

2. Версию Zig нужно брать из `build.zig.zon` текущего коммита Lightpanda. Версию и готовый архив V8 определяет `Makefile`; не закрепляйте их отдельно.

3. Порядок создания и удаления сервера сверяйте с [документацией Timeweb по созданию серверов](https://timeweb.cloud/docs/cloud-servers/manage-servers/create-server), [документацией по удалению](https://timeweb.cloud/docs/cloud-servers/manage-servers/delete-server) и [справочником TWC CLI](https://github.com/timeweb-cloud/twc/blob/master/docs/ru/CLI_REFERENCE.md).
