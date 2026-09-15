# AGENTS.md

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to open a pull request (CLA, dev setup, pre-PR checks).

## Build and tests

Run `make download-v8` once first: it fetches the prebuilt V8 archive into `.lp-cache/`, which `build.zig` picks up automatically. Without it every build compiles V8 from source (10+ minutes).

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

В Zemlekop используйте `scripts/build-lightpanda.sh` для нативной сборки на текущей системе, включая Ubuntu arm64. Для Ubuntu amd64 с компьютера macOS используйте `scripts/build-lightpanda-linux-amd64.sh` с Docker. Пользователь разрешил этот способ сборки 2026-09-14. Результаты сохраняются в `tools/bin` по платформам.

[Инструкция по временному серверу Timeweb](docs/2026-08-01%20%D0%A1%D0%B1%D0%BE%D1%80%D0%BA%D0%B0%20Lightpanda%20%D0%B4%D0%BB%D1%8F%20Linux%20%D0%BD%D0%B0%20Timeweb%20v3.md) описывает прежний способ сборки. Создание платного сервера остается отдельной операцией с прямым разрешением пользователя.

## Conventions

Mirror the patterns in neighboring files. For example:

- `@import` alias case follows the imported file's basename (`const Frame = @import("Frame.zig")`, `const ast = @import("ast.zig")`).
- Prefer struct-init type inference (`.{ ... }`) where the expected type is known from the function signature or variable annotation.
