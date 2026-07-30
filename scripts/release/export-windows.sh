#!/usr/bin/env bash
# Windows desktop export + zip + sha256. Run from repo root (Git Bash on windows-latest).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
GODOT="${GODOT:-tools/godot/godot.exe}"
PRESET="${EXPORT_PRESET:-Windows Desktop}"
OUT_DIR="$ROOT/dist/releases/SolidExpress-${VERSION}-windows-x86_64"
ARCHIVE="$ROOT/dist/releases/SolidExpress-${VERSION}-windows-x86_64.zip"

if [[ ! -x "$GODOT" && ! -f "$GODOT" ]]; then
  if [[ -x tools/godot/godot.exe ]]; then GODOT=tools/godot/godot.exe; fi
fi
if [[ ! -f "$GODOT" ]]; then
  echo "Missing Godot — run fetch-godot-templates.sh" >&2
  exit 1
fi

echo "==> cmake build (Release, sxcore only)"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DSX_BUILD_TESTS=OFF \
  -DGODOTCPP_TARGET=template_release \
  -DGODOTCPP_USE_STATIC_CPP=OFF \
  ${CMAKE_TOOLCHAIN_FILE:+-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE}
cmake --build build -j "${NUMBER_OF_PROCESSORS:-4}" --target planegcs
cmake --build build -j "${NUMBER_OF_PROCESSORS:-4}" --target sxcore

mkdir -p game/bin
PLANEGCS_DLL="$(find build -name 'planegcs.dll' -print -quit 2>/dev/null || true)"
PLANEGCS_LIB="$(find build -name 'planegcs.lib' -print -quit 2>/dev/null || true)"
if [[ -z "$PLANEGCS_DLL" ]]; then
  PLANEGCS_DLL="$(find build -name 'libplanegcs.dll' -print -quit 2>/dev/null || true)"
fi
if [[ -n "$PLANEGCS_DLL" ]]; then cp -f "$PLANEGCS_DLL" game/bin/libplanegcs.dll; fi
if [[ -z "$PLANEGCS_LIB" ]]; then
  echo "error: planegcs.lib missing after build (sxcore link will fail)" >&2
  find build -name '*.lib' 2>/dev/null | head -20 >&2 || true
  exit 1
fi

# Godot expects game/bin/libsxcore.dll (see sxcore.gdextension).
# CMake RUNTIME_OUTPUT_DIRECTORY writes there directly; also accept build/ fallbacks.
mkdir -p game/bin
if [[ -f game/bin/libsxcore.dll ]]; then
  SXCORE_DLL="game/bin/libsxcore.dll"
elif [[ -f game/bin/sxcore.dll ]]; then
  SXCORE_DLL="game/bin/sxcore.dll"
else
  SXCORE_DLL="$(find game/bin build -name 'libsxcore.dll' -print -quit 2>/dev/null || true)"
  if [[ -z "$SXCORE_DLL" ]]; then
    SXCORE_DLL="$(find game/bin build -name 'sxcore.dll' -print -quit 2>/dev/null || true)"
  fi
fi
if [[ -z "$SXCORE_DLL" || ! -f "$SXCORE_DLL" ]]; then
  echo "error: libsxcore.dll/sxcore.dll missing after sxcore build" >&2
  find game/bin build -name '*sxcore*.dll' 2>/dev/null | head -20 >&2 || true
  exit 1
fi
# Git Bash `cp` fails when source and dest are the same file (e.g. already game/bin/libsxcore.dll).
SXCORE_DEST="game/bin/libsxcore.dll"
src_resolved="$(cd "$(dirname "$SXCORE_DLL")" && pwd)/$(basename "$SXCORE_DLL")"
dest_resolved="$(cd "$(dirname "$SXCORE_DEST")" && pwd)/$(basename "$SXCORE_DEST")"
if [[ "$src_resolved" != "$dest_resolved" ]]; then
  cp -f "$SXCORE_DLL" "$SXCORE_DEST"
fi

"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$ROOT/dist/releases"
EXPORT_BIN="$OUT_DIR/SolidExpress.exe"

echo "==> Godot export-release preset=${PRESET}"
"$GODOT" --headless --path game --export-release "$PRESET" "$EXPORT_BIN"
if [[ ! -f "$EXPORT_BIN" ]]; then echo "Export failed" >&2; exit 1; fi

if [[ -f game/bin/libplanegcs.dll ]]; then cp -f game/bin/libplanegcs.dll "$OUT_DIR/"; fi
# Bundle vcpkg runtime DLLs next to the game binary (OCCT, etc.)
# Newer vcpkg uses --installed-bin-dir (not --installed-root).
if [[ -n "${VCPKG_ROOT:-}" && -f "$VCPKG_ROOT/vcpkg.exe" ]]; then
  INSTALLED_BIN="$VCPKG_ROOT/installed/x64-windows/bin"
  if [[ -d "$INSTALLED_BIN" ]]; then
    "$VCPKG_ROOT/vcpkg.exe" z-applocal \
      --target-binary "$EXPORT_BIN" \
      --installed-bin-dir "$INSTALLED_BIN" || true
  fi
fi
if [[ -f game/bin/libsxcore.dll ]]; then cp -f game/bin/libsxcore.dll "$OUT_DIR/"; fi


[[ -f "$ROOT/NOTICE" ]] && cp -f "$ROOT/NOTICE" "$OUT_DIR/NOTICE"
[[ -f "$ROOT/THIRD_PARTY.md" ]] && cp -f "$ROOT/THIRD_PARTY.md" "$OUT_DIR/THIRD_PARTY.md"
[[ -f "$ROOT/LICENSE" ]] && cp -f "$ROOT/LICENSE" "$OUT_DIR/LICENSE"

rm -f "$ARCHIVE"
# PowerShell needs Windows paths; Git Bash $ROOT is /d/a/... which Compress-Archive rejects.
to_win_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    local p="$1"
    if [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
      local drive="${BASH_REMATCH[1]}"
      local rest="${BASH_REMATCH[2]//\//\\}"
      echo "${drive^^}:\\${rest}"
    else
      echo "$p"
    fi
  fi
}
OUT_WIN="$(to_win_path "$OUT_DIR")"
ARCHIVE_WIN="$(to_win_path "$ARCHIVE")"
powershell.exe -NoProfile -Command "Compress-Archive -Path '$OUT_WIN\\*' -DestinationPath '$ARCHIVE_WIN' -Force"
sha256sum "$ARCHIVE" > "${ARCHIVE}.sha256" 2>/dev/null || certutil -hashfile "$ARCHIVE" SHA256 > "${ARCHIVE}.sha256"
echo "OK: $ARCHIVE"
