# Выпуск Lightpanda для трех платформ

Дата выпуска: 1 сентября 2026 года.

Версия всех исполняемых файлов: `1.0.0-dev.8694+5e43d40f6`.

## Состав выпуска

| Файл                       | Платформа    | Размер, байт | SHA-256                                                            |
| -------------------------- | ------------ | -----------: | ------------------------------------------------------------------ |
| `lightpanda-aarch64-macos` | macOS arm64  |   75 048 472 | `a93a5447c638f5217ee399f05b94008cb9b695527a0d86184de63e8f2164b2c9` |
| `lightpanda-aarch64-linux` | Linux arm64  |  179 804 152 | `e7771e8be76afb8075345487dc3a35eae8b25b427cbd4d2b915927ee17dd83d1` |
| `lightpanda-x86_64-linux`  | Linux x86_64 |  176 049 168 | `af8a6754fb967a92c46ca40fafa98d86fca3b86ee24e463548f984c8dd33ab2e` |

Файлы `LICENSE` и `LICENSING.md` содержат условия лицензирования. Файл `SHA256SUMS` содержит контрольные суммы всех файлов выпуска, кроме самого `SHA256SUMS`.

## Исходный код и зависимости

- Lightpanda собрана из фиксации `5e43d40f6a9bab7fa6be881dad0a157fb4540fc9` ветки `main`.

- curl-impersonate собран из фиксации `266cd9ffce634930e7b236fe340016718ac29dba` ветки `main`.

- Во всех сборках использованы Zig `0.16.0`, V8 `14.9.207.35` и архивы zig-v8 `v0.5.3`. Для сборки curl-impersonate в Linux также использован Zig `0.14.0`.

- SHA-256 архива V8 составляет `2f909581f4422e277ee45d3a87dbc82cb1a6287c907febb13342d6a5608ee8ac` для macOS arm64, `f4f1cffa7db4b4edd0049931f64d3771d8c0f2db6a0bc57de205d841b5b69887` для Linux arm64 и `c226f71561aa242f278821cebe57c8321e980fd1e491285bde05b70d126f2dac` для Linux x86_64.

- SHA-256 полного статического архива curl-impersonate составляет `4e39efbc110fac5e1fbce2533afad1bba6f921b7b50cdfed5262f2a42b2af00e` для macOS arm64 и `0da47440c02999f16094c87b05f504874999dc8c6a69b58c9239b4dbaac35337` для Linux x86_64. Промежуточная сумма архива Linux arm64 отдельно не сохранялась. Итоговый файл Linux arm64 собран дважды с одинаковой суммой.

- Параметр `CURL_IMPERSONATE_ENV_HOOK` отключен. Переменные `CURL_IMPERSONATE` и `CURL_IMPERSONATE_HEADERS` не могут сменить встроенный профиль.

## Исправление WebSocket

Фиксация `5e43d40f6a9bab7fa6be881dad0a157fb4540fc9` меняет порядок обработки остановки соединения CDP:

- уже доставленная ошибка кадра WebSocket или отключение обрабатывается до запроса общей остановки;

- ошибка кадра закрывает WebSocket кодом `1002`;

- явная остановка без доставленной ошибки закрывает WebSocket кодом `1001`;

- зависший сетевой исполнитель по-прежнему получает запрос остановки.

Узкий тест `cdp: tick prioritizes terminal inbox over pending terminate` проверяет коды `1002` и `1001`. Сквозной тест `Client: read invalid websocket message` дополнительно выполнен 100 раз без сбоя.

## Матрица проверок

| Платформа сборки                                     | Проверка исходников                      | Полные тесты                | Сборки ReleaseFast                                       | Проверка совпадения        |
| ---------------------------------------------------- | ---------------------------------------- | --------------------------- | -------------------------------------------------------- | -------------------------- |
| macOS `26.6.2`, arm64, нативно                       | `zig fmt --check`, `zig build ... check` | два запуска, по `1184/1184` | две очищенные сборки                                     | `cmp` и одинаковый SHA-256 |
| Ubuntu `24.04`, arm64, нативный Docker `linux/arm64` | `zig fmt --check`, `zig build ... check` | два запуска, по `1184/1184` | первая сборка после тестов, вторая после очистки выходов | одинаковый SHA-256         |
| Ubuntu `24.04`, x86_64, KVM на `zemlekop`            | `zig fmt --check`, `zig build ... check` | два запуска, по `1184/1184` | две сборки после отдельной очистки выходов               | `cmp` и одинаковый SHA-256 |

Проверка фактических файлов дала следующие результаты:

- файл macOS имеет формат Mach-O arm64, минимальную версию macOS `12.0`, действительную специальную подпись, символ `_curl_easy_impersonate` и не имеет динамических зависимостей от `libcurl`, `libssl` или `libcrypto`;

- файл Linux arm64 имеет формат ELF AArch64, загрузчик `/lib/ld-linux-aarch64.so.1` и наибольшую найденную версию символа `GLIBC_2.38`;

- файл Linux x86_64 имеет формат ELF x86-64, загрузчик `/lib64/ld-linux-x86-64.so.2` и наибольшую найденную версию символа `GLIBC_2.36`;

- оба файла Linux содержат символ `curl_easy_impersonate` и не имеют динамических зависимостей от `libcurl`, `libssl` или `libcrypto`;

- каждый файл возвращает версию `1.0.0-dev.8694+5e43d40f6` при запуске;

- файл macOS вернул HTTP `200` для `example.com` и `rzd.ru`, а сертификат `self-signed.badssl.com` отклонил с `PeerFailedVerification`.

## Журналы проверок

### macOS arm64

- Полные тесты записаны в `/tmp/lightpanda-macos-5e43d40f6-test-1.log` и `/tmp/lightpanda-macos-5e43d40f6-test-2.log`.

- Две воспроизводимые сборки записаны в `/tmp/lightpanda-macos-5e43d40f6-strip-repro.log`.

- Сетевые проверки записаны в каталог `/tmp/lightpanda-macos-network.UEhqHA`.

### Linux arm64

- Два полных теста и две сборки записаны в `/tmp/lightpanda-arm64-5e43d40f6.log`.

- Строки `5346` и `5359` содержат результаты `1184 of 1184 tests passed`. Строка `5506` содержит итоговую воспроизводимую сумму.

### Linux x86_64

- Полный журнал находится в `/Users/alexandergordeev/Documents/GitHub/peacemaker/.state/lightpanda-x86-release/remote-logs/full.log`.

- Результаты тестов находятся в файлах `test-1.log` и `test-2.log` того же каталога. Каждый файл содержит одну строку `1184 of 1184 tests passed`.

- Результаты сборок находятся в файлах `release-1-sha256.txt` и `release-2-sha256.txt`. Файлы `release-*-file.txt`, `release-*-readelf.txt`, `release-*-ldd.txt`, `release-*-version.txt` и `release-*-curl-symbol.txt` содержат дополнительные проверки.

- Файл `summary.env` связывает фиксации, версию, результаты тестов, две суммы сборок и размер итогового файла.

## Воспроизводимая сборка macOS arm64

Сборка выполнена на macOS `26.6.2` arm64 с Zig `0.16.0`, Rust и Cargo `1.97.1`, CMake `4.4.3`, Ninja `1.13.2`, GNU Make `4.4.1`, Apple Clang `21.0.0` и SDK macOS `26.5`.

Zig `0.16.0` не передает произвольный параметр `-reproducible` системному компоновщику из `zig build`. Без удаления отладочных символов Mach-O содержит записи `N_OSO` с временем изменения входных файлов. Эти байты меняют вычисляемый по содержимому `LC_UUID` и специальную подпись. Для выпуска применялось временное изменение только процедуры сборки. Оптимизация `ReleaseFast` не менялась.

В чистой фиксации применено следующее изменение `build.zig`:

```diff
diff --git a/build.zig b/build.zig
index 41edbb10a..bfa7cea0c 100644
--- a/build.zig
+++ b/build.zig
@@ -47,6 +47,7 @@ pub fn build(b: *Build) !void {
     const enable_tsan = b.option(bool, "tsan", "Enable Thread Sanitizer") orelse false;
     const enable_asan = b.option(bool, "asan", "Enable Address Sanitizer") orelse false;
     const enable_csan = b.option(std.zig.SanitizeC, "csan", "Enable C Sanitizers");
+    const strip = b.option(bool, "strip", "Omit debug symbols from release artifacts") orelse false;

     const prebuilt_v8_path_option = b.option([]const u8, "prebuilt_v8_path", "Path to a prebuilt libc_v8.a or libc_v8.so");

@@ -158,6 +159,7 @@ pub fn build(b: *Build) !void {
                 .root_source_file = b.path("src/main.zig"),
                 .target = target,
                 .optimize = optimize,
+                .strip = strip,
                 .sanitize_c = enable_csan,
                 .sanitize_thread = enable_tsan,
                 .imports = &.{
@@ -195,6 +197,7 @@ pub fn build(b: *Build) !void {
                 .root_source_file = b.path("src/main_snapshot_creator.zig"),
                 .target = target,
                 .optimize = optimize,
+                .strip = strip,
                 .imports = &.{
                     .{ .name = "lightpanda", .module = lightpanda_module },
                 },
```

SHA-256 вывода команды `git diff --binary -- build.zig` после применения изменения равна `b134d3ab82603b9e13fd1c44919b5f6817cac50793186fe619cd503cab71e22c`.

Для обоих запусков использовались одинаковые параметры:

```bash
release_version='1.0.0-dev.8694+5e43d40f6'
source_date_epoch=1788225987
fixed_root=/tmp/lightpanda-macos-5e43d40f6-strip-repro

build_flags=(
  -Dtarget=aarch64-macos.12.0
  "-Dversion=$release_version"
  "-Dmacos_sdk_path=$(xcrun --sdk macosx --show-sdk-path)"
  "-Dprebuilt_v8_path=$PWD/.lp-cache/prebuilt-v8/v0.5.3/libc_v8_14.9.207.35_macos_aarch64.a"
  "-Dcurl_impersonate_archive=/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/curl-impersonate/build/install/lib/libcurl-impersonate-complete.a"
  "-Dcurl_impersonate_include=/Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/curl-impersonate/build/install/include"
  -Dstrip=true
)

SOURCE_DATE_EPOCH=$source_date_epoch ZERO_AR_DATE=1 \
zig build --seed 0 \
  --cache-dir "$fixed_root/local-cache" \
  --global-cache-dir "$fixed_root/global-cache" \
  --prefix "$fixed_root/prefix" \
  "${build_flags[@]}" -Doptimize=ReleaseFast \
  snapshot_creator -- "$PWD/src/snapshot.bin"

SOURCE_DATE_EPOCH=$source_date_epoch ZERO_AR_DATE=1 \
zig build --seed 0 \
  --cache-dir "$fixed_root/local-cache" \
  --global-cache-dir "$fixed_root/global-cache" \
  --prefix "$fixed_root/prefix" \
  "${build_flags[@]}" -Doptimize=ReleaseFast \
  -Dsnapshot_path=../../snapshot.bin
```

После первого запуска весь каталог `$fixed_root` перемещен в каталог свидетельств. Затем исходный путь создан заново с пустыми локальным и общим кешами. Второй запуск выполнен по тому же абсолютному пути. Обе копии `snapshot.bin` получили SHA-256 `a084aca8bed7b14f55a5bac2fca6e79dbc02a94659e6061a99f00a1756780188`. Два исполняемых файла совпали побайтово. После установки итогового файла временное изменение `build.zig` отменено. Команды `git diff --exit-code` и `git status --short` подтвердили отсутствие изменений исходного кода.

## Воспроизводимая сборка Linux arm64

Сборка выполнена нативным Docker Engine `linux/arm64` в образе `ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90`. Использованы Zig `0.14.0` для curl-impersonate, Zig `0.16.0` для Lightpanda, Rust `1.97.1`, CMake `3.28.3`, Ninja `1.11.1`, GNU Make `4.3`, GCC `13.3.0`, GNU libtool `2.4.7` и Go `1.22.2`.

Процедура находится в файле `/Users/alexandergordeev/Documents/GitHub/peacemaker/docker/build-lightpanda-linux-arm64.sh`. Во время запуска два значения заменены во входном направлении без изменения файла процедуры:

```bash
lightpanda_revision=5e43d40f6a9bab7fa6be881dad0a157fb4540fc9
lightpanda_version=1.0.0-dev.8694+5e43d40f6

awk \
  -v revision="$lightpanda_revision" \
  -v version="$lightpanda_version" '
    /^readonly lightpanda_revision=/ {
      print "readonly lightpanda_revision=" revision
      next
    }
    /^readonly lightpanda_version=/ {
      print "readonly lightpanda_version=" version
      next
    }
    { print }
  ' \
  /Users/alexandergordeev/Documents/GitHub/peacemaker/docker/build-lightpanda-linux-arm64.sh \
| bash -s -- \
  /Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/lightpanda \
  /Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/curl-impersonate \
  /Users/alexandergordeev/Documents/GitHub/web-tools-for-agents/lightpanda/build
```

Процедура создает чистые деревья через `git archive`, проверяет суммы всех загруженных файлов, собирает полный статический curl-impersonate, выполняет форматирование, проверку графа сборки и два полных теста. Lightpanda собирается с параметрами `-Dtarget=aarch64-linux-gnu.2.39`, явными путями к V8 и curl-impersonate и режимом `ReleaseFast`. Перед второй сборкой удаляются `.zig-cache`, `zig-out` и `src/snapshot.bin`. Две суммы совпали.

## Воспроизводимая сборка Linux x86_64

Сборка выполнена нативно на Ubuntu `24.04` x86_64 под KVM. Использованы Zig `0.14.0` для curl-impersonate, Zig `0.16.0` для Lightpanda, Rust и Cargo `1.91.1`, CMake `3.28.3`, Ninja `1.11.1`, GNU Make `4.3`, GCC `13.3.0`, GNU libtool `2.4.7` и Go `1.27.0`.

Точная процедура сохранена в `/Users/alexandergordeev/Documents/GitHub/peacemaker/.state/lightpanda-x86-release/run-build.sh`. Lightpanda собирается со следующими параметрами:

```bash
build_flags=(
  -Dcpu=x86_64
  -Dversion=1.0.0-dev.8694+5e43d40f6
  -Dprebuilt_v8_path=/home/tedo/lightpanda-browser/.lp-cache/prebuilt-v8/v0.5.3/libc_v8_14.9.207.35_linux_x86_64.a
  -Dcurl_impersonate_archive=/home/tedo/lightpanda-x86-release/curl-install/lib/libcurl-impersonate-complete.a
  -Dcurl_impersonate_include=/home/tedo/lightpanda-x86-release/curl-install/include
)

zig build "${build_flags[@]}" check
zig build "${build_flags[@]}" test -freference-trace
zig build "${build_flags[@]}" test -freference-trace
```

Перед каждой сборкой `ReleaseFast` процедура очищает `.zig-cache`, `zig-out` и `src/snapshot.bin`, затем выполняет:

```bash
zig build "${build_flags[@]}" -Doptimize=ReleaseFast \
  snapshot_creator -- src/snapshot.bin
zig build "${build_flags[@]}" -Doptimize=ReleaseFast \
  -Dsnapshot_path=../../snapshot.bin
```

Каждая копия проверена командами `file`, `readelf`, `ldd`, `nm` и `lightpanda version`. Два файла сравнены командой `cmp` и имеют одинаковую сумму.

## Сертификат Минцифры

Официальный `Russian Trusted Root CA` добавлен только во внутреннее хранилище трех исполняемых файлов Lightpanda. SHA-256 сертификата в форме DER равна `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31`. Системные хранилища macOS и Linux не изменялись.

## Ограничения

- Файл macOS предназначен для macOS `12.0` или новее. Файл имеет специальную подпись без удостоверения разработчика и не проходил нотариальное заверение Apple.

- Файл Linux arm64 собран для ABI Ubuntu `24.04`. Найденные символы glibc ограничены версией `GLIBC_2.38`.

- Файл Linux x86_64 проверен на Ubuntu `24.04`. Найденные символы glibc ограничены версией `GLIBC_2.36`.

- Скрипт `install.sh` выбирает файл macOS arm64 или Linux x86_64. Файл Linux arm64 предназначен для интеграции Peacemaker и пока не выбирается этим скриптом.

- Каталог `build` исключен из Git. Этот локальный выпуск не оформлен как метка или выпуск GitHub.
