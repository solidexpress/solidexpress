#!/usr/bin/env bash
# macOS desktop export + zip + sha256. Run from repo root on macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
GODOT="${GODOT:-tools/godot/godot}"
PRESET="${EXPORT_PRESET:-macOS}"
OUT_APP="$ROOT/dist/releases/SolidExpress-${VERSION}-macos/SolidExpress.app"
ARCHIVE="$ROOT/dist/releases/SolidExpress-${VERSION}-macos.zip"

if [[ ! -x "$GODOT" ]]; then
  echo "Missing Godot at $GODOT — run: ./scripts/release/fetch-godot-templates.sh" >&2
  exit 1
fi

echo "==> cmake build (Release)"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j "$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

mkdir -p game/bin
for candidate in build/libplanegcs.dylib build/thirdparty/planegcs/libplanegcs.dylib; do
  if [[ -f "$candidate" ]]; then cp -f "$candidate" game/bin/; break; fi
done
PLANEGCS="$(find build -name 'libplanegcs.dylib' -print -quit 2>/dev/null || true)"
if [[ -n "$PLANEGCS" && ! -f game/bin/libplanegcs.dylib ]]; then cp -f "$PLANEGCS" game/bin/; fi

"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
rm -rf "$ROOT/dist/releases/SolidExpress-${VERSION}-macos"
mkdir -p "$ROOT/dist/releases"

echo "==> Godot export-release preset=${PRESET}"
"$GODOT" --headless --path game --export-release "$PRESET" "$OUT_APP"
if [[ ! -d "$OUT_APP" ]]; then echo "Export failed: $OUT_APP" >&2; exit 1; fi

if [[ -f game/bin/libplanegcs.dylib ]]; then
  mkdir -p "$OUT_APP/Contents/MacOS"
  cp -f game/bin/libplanegcs.dylib "$OUT_APP/Contents/MacOS/" || true
fi

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$OUT_APP" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "${ARCHIVE}.sha256"
echo "OK: $ARCHIVE"
cat "${ARCHIVE}.sha256"
