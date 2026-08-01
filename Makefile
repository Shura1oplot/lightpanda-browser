# Variables
# ---------

ZIG := zig
BC := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
# option test filter make test F="server"
F=

# Extra flags forwarded to every `$(ZIG) build` invocation.
ZIGFLAGS ?=

# Lightpanda uses curl-impersonate instead of the system libcurl. The default
# expects the consolidated repository layout, while callers can point at any
# compatible installation prefix or override the archive and include paths.
CURL_IMPERSONATE_PREFIX ?= ../curl-impersonate/build/install
CURL_IMPERSONATE_ARCHIVE ?= $(CURL_IMPERSONATE_PREFIX)/lib/libcurl-impersonate-complete.a
CURL_IMPERSONATE_INCLUDE ?= $(CURL_IMPERSONATE_PREFIX)/include
CURL_IMPERSONATE_FLAGS := \
	-Dcurl_impersonate_archive=$(CURL_IMPERSONATE_ARCHIVE) \
	-Dcurl_impersonate_include=$(CURL_IMPERSONATE_INCLUDE)

# OS and ARCH
kernel = $(shell uname -ms)
ifeq ($(kernel), Darwin arm64)
	OS := macos
	ARCH := aarch64
else ifeq ($(kernel), Darwin x86_64)
	OS := macos
	ARCH := x86_64
else ifeq ($(kernel), Linux aarch64)
	OS := linux
	ARCH := aarch64
else ifeq ($(kernel), Linux arm64)
	OS := linux
	ARCH := aarch64
else ifeq ($(kernel), Linux x86_64)
	OS := linux
	ARCH := x86_64
else
	$(error "Unhandled kernel: $(kernel)")
endif

ifeq ($(OS),macos)
	MACOS_SDK_PATH ?= $(shell xcrun --sdk macosx --show-sdk-path)
	MACOS_SDK_FLAGS = -Dmacos_sdk_path=$(MACOS_SDK_PATH)
endif


# Prebuilt V8
# -----------
# Building V8 from source takes 10+ minutes. `make download-v8` fetches the
# matching prebuilt archive from the zig-v8-fork releases instead. The versions
# are read from the install action so they can't drift from CI.
#
# The cache path is keyed on ZIG_V8_TAG as well as the archive name: a
# zig-v8-fork release keeps the same asset filename across tags (the name
# encodes only the V8 version), so a tag bump that leaves V8_VERSION alone
# still ships different bytes. Keying the cache on the filename alone made
# download-v8's `test -f` guard skip that refresh and leave a stale archive
# in place, which then fails at link time on undefined v8__* symbols.
V8_ACTION := .github/actions/install/action.yml
V8_VERSION := $(shell awk -F\' '/^  v8:/{f=1} f&&/default:/{print $$2; exit}' $(V8_ACTION))
ZIG_V8_TAG := $(shell awk -F\' '/^  zig-v8:/{f=1} f&&/default:/{print $$2; exit}' $(V8_ACTION))
V8_ARCHIVE := libc_v8_$(V8_VERSION)_$(OS)_$(ARCH).a
V8_CACHE   := .lp-cache/prebuilt-v8/$(ZIG_V8_TAG)/$(V8_ARCHIVE)

# Use the cached archive even when callers pass unrelated ZIGFLAGS such as a
# release version. Override PREBUILT_V8_PATH to select a different archive.
PREBUILT_V8_PATH ?= $(wildcard $(V8_CACHE))
V8_FLAGS = $(if $(PREBUILT_V8_PATH),-Dprebuilt_v8_path=$(PREBUILT_V8_PATH),)
BUILD_FLAGS = $(V8_FLAGS) $(ZIGFLAGS) $(CURL_IMPERSONATE_FLAGS) $(MACOS_SDK_FLAGS)


# Infos
# -----
.PHONY: help

## Display this help screen
help:
	@printf "\033[36m%-35s %s\033[0m\n" "Command" "Usage"
	@sed -n -e '/^## /{'\
		-e 's/## //g;'\
		-e 'h;'\
		-e 'n;'\
		-e 's/:.*//g;'\
		-e 'G;'\
		-e 's/\n/ /g;'\
		-e 'p;}' Makefile | awk '{printf "\033[33m%-35s\033[0m%s\n", $$1, substr($$0,length($$1)+1)}'


# $(ZIG) commands
# ------------
.PHONY: build build-v8-snapshot build-dev check-curl-impersonate download-v8 run run-release test bench data end2end clean

check-curl-impersonate:
	@test -f "$(CURL_IMPERSONATE_ARCHIVE)" || (printf "\033[33mMissing curl-impersonate archive: %s\033[0m\n" "$(CURL_IMPERSONATE_ARCHIVE)"; exit 1)
	@test -f "$(CURL_IMPERSONATE_INCLUDE)/curl/curl.h" || (printf "\033[33mMissing curl-impersonate headers: %s\033[0m\n" "$(CURL_IMPERSONATE_INCLUDE)"; exit 1)

## Download the prebuilt V8 archive (skips the 10+ min source build)
download-v8:
	@mkdir -p $(dir $(V8_CACHE))
	@test -f $(V8_CACHE) || ( \
		printf "\033[36mDownloading prebuilt V8 $(V8_VERSION) ($(ZIG_V8_TAG))...\033[0m\n"; \
		curl -fL --progress-bar -o $(V8_CACHE) \
			https://github.com/lightpanda-io/zig-v8-fork/releases/download/$(ZIG_V8_TAG)/$(V8_ARCHIVE) \
		|| (rm -f $(V8_CACHE); printf "\033[33mDownload ERROR\033[0m\n"; exit 1) )
	@printf "\033[33mV8 ready: %s\033[0m\n" "$(V8_CACHE)"

## Build v8 snapshot
build-v8-snapshot: check-curl-impersonate
	@printf "\033[36mBuilding v8 snapshot (release safe)...\033[0m\n"
	@$(ZIG) build $(BUILD_FLAGS) -Doptimize=ReleaseFast snapshot_creator -- src/snapshot.bin || (printf "\033[33mBuild ERROR\033[0m\n"; exit 1;)
	@printf "\033[33mBuild OK\033[0m\n"

## Build in release-fast mode
build: build-v8-snapshot
	@printf "\033[36mBuilding (release fast)...\033[0m\n"
	@$(ZIG) build $(BUILD_FLAGS) -Doptimize=ReleaseFast -Dsnapshot_path=../../snapshot.bin || (printf "\033[33mBuild ERROR\033[0m\n"; exit 1;)
	@printf "\033[33mBuild OK\033[0m\n"

## Build in debug mode
build-dev: check-curl-impersonate
	@printf "\033[36mBuilding (debug)...\033[0m\n"
	@$(ZIG) build $(BUILD_FLAGS) || (printf "\033[33mBuild ERROR\033[0m\n"; exit 1;)
	@printf "\033[33mBuild OK\033[0m\n"

## Run the server in release mode
run: build
	@printf "\033[36mRunning...\033[0m\n"
	@./zig-out/bin/lightpanda || (printf "\033[33mRun ERROR\033[0m\n"; exit 1;)

## Run the server in debug mode
run-debug: build-dev
	@printf "\033[36mRunning...\033[0m\n"
	@./zig-out/bin/lightpanda || (printf "\033[33mRun ERROR\033[0m\n"; exit 1;)

test: check-curl-impersonate
	TEST_FILTER="${F}" $(ZIG) build $(BUILD_FLAGS) test -freference-trace

## Run demo/runner end to end tests
end2end:
	@test -d ../demo
	cd ../demo && go run runner/main.go

## Run the agent regression suite from ../demo (LAYER=deterministic|live|all,
## default all). The live layer needs GOOGLE_API_KEY or GEMINI_API_KEY;
## without one only the deterministic layer runs. See ../demo/agent/README.md.
test-agent:
	@test -d ../demo
	@test -x zig-out/bin/lightpanda || $(MAKE) build
	@cd ../demo && ./agent/run.sh $(LAYER)

## Remove build artifacts (keeps .lp-cache/ and zig-pkg/ — slow to re-fetch)
clean:
	rm -rf zig-out .zig-cache src/snapshot.bin
	cd src/html5ever && cargo clean

# Install and build required dependencies commands
# ------------
.PHONY: install

install: build

data:
	cd src/data && go run public_suffix_list_gen.go > public_suffix_list.zig
