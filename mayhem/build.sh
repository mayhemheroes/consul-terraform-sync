#!/usr/bin/env bash
#
# mayhem/build.sh — build this repo's go-fuzz harness(es) as sanitized libFuzzer
# binaries (OSS-Fuzz Go path: go-fuzz-build -libfuzzer + clang link). EDIT per repo.
#
# Runs inside the commit image (GO mayhem/Dockerfile) as `mayhem` in /mayhem.
# GOROOT/GOPATH/GOMODCACHE are pinned by the Dockerfile ENV (under /opt/toolchains —
# absolute, $HOME-independent).
#
# AIR-GAPPED CONTRACT (SPEC §6.5): the PATCH tier re-runs THIS script OFFLINE.
#   - This FIRST build (in CI, online) populates the module cache under $GOMODCACHE.
#   - The module cache doubles as a FILE PROXY at $GOMODCACHE/cache/download. We set
#     GOPROXY to that file proxy FIRST, network LAST: the offline re-run resolves
#     entirely from the cache, and the network fallback only fills cache-misses on
#     this first online build. -mod=mod lets go-fuzz-build's `go get` of go-fuzz-dep
#     update go.mod from the cache. (GOPROXY=off is NOT enough — it blocks reading
#     the version list from the cache, which `go get` needs.)
#   - For a FULLY self-contained tree instead: `go mod vendor` and build -mod=vendor.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
# OSS-Fuzz Go path is ASan-only for the libFuzzer link (keep ASan regardless of base default).
: "${SANITIZER_FLAGS=-fsanitize=address}"
# DWARF <4 (SPEC §6.2 item 10) — clang's plain -g emits DWARF-5; Mayhem's triage needs <=3.
: "${GO_DEBUG_FLAGS:=-g -gdwarf-3}"
: "${MAYHEM_JOBS:=$(nproc)}"
export CC CXX LIB_FUZZING_ENGINE SANITIZER_FLAGS GO_DEBUG_FLAGS MAYHEM_JOBS

# Resolve modules offline-first from the in-image cache; network only as a fallback.
# $(go env GOMODCACHE) reads the pinned ENV, so it is correct under ANY $HOME.
export GOFLAGS="${GOFLAGS:--mod=mod}"
export GOPROXY="${GOPROXY:-file://$(go env GOMODCACHE)/cache/download,https://proxy.golang.org,direct}"

cd "$SRC"
go version

# go-fuzz-build needs the go-fuzz-dep package on the module graph. With -mod=mod +
# the file-proxy GOPROXY this resolves from the cache offline (no-op if already present).
go get github.com/dvyukov/go-fuzz/go-fuzz-dep

# The package dir holding the legacy `func Fuzz(data []byte) int` harness, and the
# output binary name (preserve the old Mayhemfile `target:` for corpus continuity).
HARNESS_DIR="mayhem/harness"
TARGET="consul-terraform-sync"

mkdir -p "$SRC/mayhem-build"
echo "=== building $TARGET (go-fuzz-build -libfuzzer) ==="
(
  cd "$SRC/$HARNESS_DIR"
  go-fuzz-build -libfuzzer -o "$SRC/mayhem-build/$TARGET.a"
)

# DWARF-3 anchor (SPEC §6.2 item 10): the go-fuzz-build archive is Go-compiler
# object code, which always emits DWARF-5 CUs regardless of $GO_DEBUG_FLAGS (that
# flag only affects clang-compiled TUs — there are none in the .a). Mayhem's triage
# reads the FIRST CU at `.debug_info` offset 0, so compile a tiny DWARF-3 anchor
# object and link it FIRST — its CU lands at offset 0, satisfying the DWARF<4 check.
cat > "$SRC/mayhem-build/anchor.c" <<'C'
int mayhem_dwarf3_anchor(void) { return 0; }
C
$CC -g -gdwarf-3 -c "$SRC/mayhem-build/anchor.c" -o "$SRC/mayhem-build/anchor.o"

# Link the anchor + go-fuzz archive into a libFuzzer binary with clang (ASan).
$CXX $SANITIZER_FLAGS $GO_DEBUG_FLAGS $LIB_FUZZING_ENGINE \
  "$SRC/mayhem-build/anchor.o" "$SRC/mayhem-build/$TARGET.a" -o "/mayhem/$TARGET"
echo "built /mayhem/$TARGET"

# Warm the module cache for the FULL module graph (go.sum), not just the harness's
# transitive deps — mayhem/test.sh runs `go test ./...` afterward (offline at the
# PATCH tier), so every test-only dependency must already be in $GOMODCACHE now,
# while we still have network. A no-op if already cached.
echo "=== priming module cache (go mod download) ==="
go mod download

# Pre-build the unit test suite's compiled objects too (NORMAL flags, no sanitizer)
# by running the test binaries' build step now; mayhem/test.sh only RUNS `go test`
# afterward (Go compiles test binaries on demand from this already-warmed cache).
echo "=== pre-compiling unit test suite ==="
go build ./...
go vet ./... || true

echo "build.sh complete"
