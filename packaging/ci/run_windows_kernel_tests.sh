#!/usr/bin/env bash
# Build (if needed) and run sxkernel_tests.exe on Windows Git Bash with the
# runtime DLLs that live outside build/sxkernel (planegcs → game/bin, OCCT →
# vcpkg installed/bin). Exit 127 with no output usually means a missing DLL.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TEST_DIR="$ROOT/build/sxkernel"
TEST_EXE="$TEST_DIR/sxkernel_tests.exe"

if [[ ! -f "$TEST_EXE" ]]; then
  echo "error: $TEST_EXE missing — build target sxkernel_tests first" >&2
  exit 1
fi

to_unix_path() {
  local p="$1"
  [[ -n "$p" ]] || { echo ""; return 0; }
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p"
    return 0
  fi
  if [[ "$p" =~ ^([a-zA-Z]):[\\/](.*)$ ]]; then
    local drive rest
    drive="$(echo "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z')"
    rest="${BASH_REMATCH[2]//\\//}"
    echo "/${drive}/${rest}"
    return 0
  fi
  echo "$p"
}

# planegcs is a SHARED lib with RUNTIME_OUTPUT_DIRECTORY=game/bin.
stage_planegcs() {
  local src=""
  for cand in \
    "$ROOT/game/bin/planegcs.dll" \
    "$ROOT/game/bin/libplanegcs.dll" \
    "$ROOT/build/planegcs.dll" \
    "$ROOT/build/libplanegcs.dll"; do
    if [[ -f "$cand" ]]; then src="$cand"; break; fi
  done
  if [[ -z "$src" ]]; then
    src="$(find "$ROOT/build" "$ROOT/game/bin" -name 'planegcs.dll' -o -name 'libplanegcs.dll' 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$src" || ! -f "$src" ]]; then
    echo "error: planegcs.dll not found (needed beside sxkernel_tests.exe)" >&2
    exit 1
  fi
  cp -f "$src" "$TEST_DIR/planegcs.dll"
  echo "staged planegcs.dll <- $src"
}

# Prefer manifest-mode build/vcpkg_installed, then classic $VCPKG_ROOT/installed.
find_vcpkg_bin() {
  local cand
  for cand in \
    "$ROOT/build/vcpkg_installed/x64-windows/bin" \
    "$(to_unix_path "${SX_VCPKG_ROOT:-}")/installed/x64-windows/bin" \
    "$(to_unix_path "${VCPKG_ROOT:-}")/installed/x64-windows/bin" \
    "$(to_unix_path "${RUNNER_TEMP:-}")/vcpkg/installed/x64-windows/bin"; do
    [[ -n "$cand" && -d "$cand" ]] || continue
    if [[ -f "$cand/TKernel.dll" || -f "$cand/tbb12.dll" || -f "$cand/tbb.dll" ]]; then
      echo "$cand"
      return 0
    fi
  done
  return 1
}

stage_planegcs

VCPKG_BIN="$(find_vcpkg_bin || true)"
if [[ -n "$VCPKG_BIN" ]]; then
  echo "vcpkg runtime bin: $VCPKG_BIN"
  # Copy OCCT/TBB/transitives next to the exe (z-applocal already did most of
  # this at link time; re-seed anything still missing).
  shopt -s nullglob
  for dll in \
    "$VCPKG_BIN"/TK*.dll \
    "$VCPKG_BIN"/tbb*.dll \
    "$VCPKG_BIN"/tbbmalloc*.dll \
    "$VCPKG_BIN"/hwloc*.dll \
    "$VCPKG_BIN"/freetype*.dll \
    "$VCPKG_BIN"/openvr*.dll \
    "$VCPKG_BIN"/z.dll \
    "$VCPKG_BIN"/zlib*.dll \
    "$VCPKG_BIN"/bz2*.dll \
    "$VCPKG_BIN"/libpng*.dll \
    "$VCPKG_BIN"/brotli*.dll \
    "$VCPKG_BIN"/jpeg*.dll \
    "$VCPKG_BIN"/tiff*.dll \
    "$VCPKG_BIN"/webp*.dll; do
    base="$(basename "$dll")"
    if [[ ! -f "$TEST_DIR/$base" ]]; then
      cp -f "$dll" "$TEST_DIR/"
    fi
  done
  shopt -u nullglob
  export PATH="$TEST_DIR:$VCPKG_BIN:$PATH"
else
  echo "warning: vcpkg x64-windows/bin not found; relying on applocal copies only" >&2
  export PATH="$TEST_DIR:$PATH"
fi

# Optional dependency dump for CI diagnosis (dumpbin from MSVC env).
# Git Bash rewrites leading /flags as filesystem paths — use -dependents or
# MSYS_NO_PATHCONV=1 when calling dumpbin.
if command -v dumpbin >/dev/null 2>&1; then
  echo "==> dumpbin -dependents sxkernel_tests.exe"
  WIN_EXE="$TEST_EXE"
  if command -v cygpath >/dev/null 2>&1; then
    WIN_EXE="$(cygpath -w "$TEST_EXE")"
  fi
  MSYS_NO_PATHCONV=1 dumpbin -dependents "$WIN_EXE" || true
fi

echo "==> DLLs staged beside test exe:"
ls -1 "$TEST_DIR"/*.dll 2>/dev/null | xargs -n1 basename | sort | head -80 || true

# planegcs + OCCT/TBB are already beside the exe; run from that directory so the
# Windows loader finds them. Prefer the .exe path explicitly (Git Bash).
echo "==> running $TEST_EXE"
(
  cd "$TEST_DIR"
  if [[ -f ./sxkernel_tests.exe ]]; then
    ./sxkernel_tests.exe
  else
    ./sxkernel_tests
  fi
)
