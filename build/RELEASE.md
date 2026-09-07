# Выпуск Lightpanda от 7 сентября 2026 года

macOS arm64 обновлена на официальный стабильный выпуск Lightpanda `0.4.0` с сохранением изменений владельца репозитория. Файлы Linux сохраняют выпуск от 1 сентября 2026 года. Проверки новой сборки относятся только к macOS arm64.

## Состав

| Файл                       | Версия                     | Размер, байт | SHA-256                                                            |
| -------------------------- | -------------------------- | -----------: | ------------------------------------------------------------------ |
| `lightpanda-aarch64-macos` | `0.4.0+d957d15dc`          |     83734296 | `a0bc53a40ec52e6ee63552c71ab1ad4abfd5ada7fa73545ee296edff4e766a8e` |
| `lightpanda-aarch64-linux` | `1.0.0-dev.8694+5e43d40f6` |    179804152 | `e7771e8be76afb8075345487dc3a35eae8b25b427cbd4d2b915927ee17dd83d1` |
| `lightpanda-x86_64-linux`  | `1.0.0-dev.8694+5e43d40f6` |    176049168 | `af8a6754fb967a92c46ca40fafa98d86fca3b86ee24e463548f984c8dd33ab2e` |

Предыдущий документ выпуска и файл macOS сохранены в `previous-2026-09-01`. Файлы `LICENSE` и `LICENSING.md` содержат условия лицензирования. `SHA256SUMS` проверяет состав текущего выпуска.

## Исходный код macOS

- Официальный выпуск [Lightpanda 0.4.0](https://github.com/lightpanda-io/browser/releases/tag/0.4.0) соответствует фиксации `3bab59c6a4ec45e3fecc237ba7b440e19cb1ea2b`.
- Фиксация с изменениями владельца составляет `d957d15dc579eb1a870ae97169e7d72746c23f08`. Исходное дерево при сборке было чистым.
- curl-impersonate `8.22.0` собран из фиксации `ba3ad317bef27fd75aac4f3585cbd0f1beb6574c`.
- Полный статический архив curl-impersonate имеет SHA-256 `2748e172ced3935b16c1c15dc07063ce4d426878605300511cbe03cf712c0adb`. Параметры `CURL_IMPERSONATE_ENV_HOOK` и `USE_APPLE_SECTRUST` отключены.
- V8 `14.9.207.35` из zig-v8 `v0.5.4` имеет SHA-256 `bf430343bf3ee3702bed284ad6e631ef8b251b593d9f6539912b976e7a3ab1e9`. Сумма совпала с данными официального выпуска.

Сборка выполнена непосредственно на macOS `26.6.2`, arm64, с Zig `0.16.0`, Rust и Cargo `1.97.1` и SDK macOS `26.5`. Минимальная версия macOS в исполняемом файле составляет `12.0`.

## Сохраненные изменения

- Профиль Chrome 146 применяется после каждого повторного сброса соединения libcurl. Заголовки HTTP и данные Navigator сохраняют ту же версию Chrome.
- Официальный `Russian Trusted Root CA` добавляется к стандартному хранилищу внутри Lightpanda. Явные `--ca-cert` и `--ca-path` заменяют стандартное хранилище без добавления этого корня.
- Полученная ошибка WebSocket обрабатывается до общего завершения соединения. Проверка сохраняет коды закрытия `1002` для ошибки протокола и `1001` для обычного завершения.
- Сохранение файла cookies в режиме сервера остается доступным.

## Проверки macOS

- `zig fmt --check` и `zig build ... check` завершились успешно.
- Полный запуск тестов завершился результатом `1385 of 1385 tests passed` с заведомо неверными значениями `CURL_IMPERSONATE` и `CURL_IMPERSONATE_HEADERS`.
- Снимок V8 и исполняемый файл собраны в режиме `ReleaseFast`.
- Файл имеет формат Mach-O arm64, содержит `_curl_easy_impersonate` и не зависит от внешних `libcurl`, `libssl` или `libcrypto`. Проверка специальной подписи macOS завершилась успешно.
- `example.com` и `rzd.ru` вернули HTTP `200`. Недоверенный сертификат `self-signed.badssl.com` отклонен с `PeerFailedVerification` и кодом завершения `1`.
- Испытание через `tls.peet.ws/api/all` без `CURL_IMPERSONATE` показало совпадение Lightpanda с эталонным запросом curl-impersonate Chrome 146. Значение JA4 составило `t13d1516h2_8daaf6152771_d8a2da3f94cd`, отпечаток HTTP/2 составил `1:65536;2:0;4:6291456;6:262144|15663105|0|m,a,s,p`. Значения User-Agent также совпали.

Журналы проверок находятся в `acceptance-2026-09-07`. Предупреждения JavaScript страницы `rzd.ru` сохранены отдельно; они не помешали получению HTTP `200` и не связаны с проверкой сертификатов.

## Повторение сборки macOS

Команды выполняются из корня репозитория Lightpanda после сборки статического curl-impersonate в соседнем репозитории:

```bash
make download-v8

CURL_IMPERSONATE=lightpanda-invalid-profile \
CURL_IMPERSONATE_HEADERS=no \
make test CURL_IMPERSONATE_PREFIX=../curl-impersonate/build-static-lightpanda/install

make build \
  CURL_IMPERSONATE_PREFIX=../curl-impersonate/build-static-lightpanda/install \
  ZIGFLAGS='-Dtarget=aarch64-macos.12.0 -Dversion=0.4.0+d957d15dc'
```

Сборка выполнена один раз. Побайтовое воспроизведение двух независимых сборок этого обновления не проверялось. Linux в рамках этого обновления не собирался и не проверялся; его прежние свидетельства находятся в `previous-2026-09-01/RELEASE.md`. Платные серверы не создавались.
