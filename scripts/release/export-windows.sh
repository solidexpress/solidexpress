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
  ${CMAKE_TOOLCHAIN_FILE:+-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE}
cmake --build build -j "${NUMBER_OF_PROCESSORS:-4}" --target sxcore

mkdir -p game/bin
PLANEGCS="$(find build -name 'libplanegcs.dll' -o -name 'planegcs.dll' 2>/dev/null | head -1 || true)"
if [[ -n "$PLANEGCS" ]]; then cp -f "$PLANEGCS" game/bin/libplanegcs.dll; fi

"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$ROOT/dist/releases"
EXPORT_BIN="$OUT_DIR/SolidExpress.exe"

echo "==> Godot export-release preset=${PRESET}"
"$GODOT" --headless --path game --export-release "$PRESET" "$EXPORT_BIN"
if [[ ! -f "$EXPORT_BIN" ]]; then echo "Export failed" >&2; exit 1; fi

if [[ -f game/bin/libplanegcs.dll ]]; then cp -f game/bin/libplanegcs.dll "$OUT_DIR/"; fi

rm -f "$ARCHIVE"
powershell.exe -NoProfile -Command "Compress-Archive -Path '$OUT_DIR/*' -DestinationPath '$ARCHIVE' -Force"
sha256sum "$ARCHIVE" > "${ARCHIVE}.sha256" 2>/dev/null || certutil -hashfile "$ARCHIVE" SHA256 > "${ARCHIVE}.sha256"
echo "OK: $ARCHIVE"
