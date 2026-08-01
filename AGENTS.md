# AGENTS.md

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to open a pull request (CLA, dev setup, pre-PR checks).

## Tests

```bash
make test                                       # Run all tests
make test F="server"                            # Filter by substring
TEST_FILTER="WebApi: #selector_all" make test   # Filter main + subtest (separator: #)
TEST_VERBOSE=true make test
TEST_FAIL_FIRST=true make test
METRICS=true make test                          # Capture allocation/duration metrics as JSON
```

The custom test runner (`src/test_runner.zig`) detects memory leaks in debug builds. **A test that allocates without freeing fails** – not just lints.

## Formatting

```bash
zig fmt --check ./*.zig ./**/*.zig    # Exact command CI runs
```

`zig build` depends on the fmt step, so a local build catches drift too.

## Сборка для Linux

Перед сборкой для Linux обязательно прочитайте [инструкцию по нативной сборке на временном сервере Timeweb](docs/2026-08-01%20%D0%A1%D0%B1%D0%BE%D1%80%D0%BA%D0%B0%20Lightpanda%20%D0%B4%D0%BB%D1%8F%20Linux%20%D0%BD%D0%B0%20Timeweb%20v2.md).

Сборку `linux/amd64` нельзя выполнять на компьютере Apple Silicon через Docker, OrbStack, Rosetta, QEMU или другую эмуляцию процессора. Используйте временный сервер Ubuntu 24.04 с нативной архитектурой `x86_64`. До создания платного сервера получите прямое разрешение пользователя, а после получения результата обязательно удалите сервер и связанный публичный адрес.

## Conventions

Mirror the patterns in neighboring files. For example:

- `@import` alias case follows the imported file's basename (`const Frame = @import("Frame.zig")`, `const ast = @import("ast.zig")`).
- Prefer struct-init type inference (`.{ ... }`) where the expected type is known from the function signature or variable annotation.
