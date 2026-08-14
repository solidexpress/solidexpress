#!/usr/bin/env bash
# macOS desktop export + zip + sha256. Run from repo root on macOS.
# Godot 4.7.1 templates only ship godot_macos_release.universal, so we export
# universal then lipo -thin arm64. The DMG is Apple Silicon only.
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

echo "==> cmake build (Release, sxcore only)"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DSX_BUILD_TESTS=OFF -DGODOTCPP_TARGET=template_release
cmake --build build -j "$(sysctl -n hw.ncpu 2>/dev/null || echo 4)" --target planegcs sxcore

mkdir -p game/bin
for candidate in build/libplanegcs.dylib build/thirdparty/planegcs/libplanegcs.dylib; do
  if [[ -f "$candidate" ]]; then cp -f "$candidate" game/bin/; break; fi
done
PLANEGCS="$(find build -name 'libplanegcs.dylib' -print -quit 2>/dev/null || true)"
if [[ -n "$PLANEGCS" && ! -f game/bin/libplanegcs.dylib ]]; then cp -f "$PLANEGCS" game/bin/; fi

if [[ ! -f game/bin/libsxcore.dylib ]]; then
  SXCORE="$(find build game/bin -name 'libsxcore.dylib' -print -quit 2>/dev/null || true)"
  if [[ -n "$SXCORE" ]]; then cp -f "$SXCORE" game/bin/libsxcore.dylib; fi
fi
if [[ ! -f game/bin/libsxcore.dylib ]]; then
  echo "error: game/bin/libsxcore.dylib missing after sxcore build" >&2
  exit 1
fi
if [[ ! -f game/bin/libplanegcs.dylib ]]; then
  echo "error: game/bin/libplanegcs.dylib missing after planegcs build" >&2
  exit 1
fi

echo "==> Godot import"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true

echo "==> pin ETC2 via ProjectSettings"
"$GODOT" --headless --path game -s "$ROOT/scripts/release/pin_vram.gd"
rm -f "$ROOT/game/project.binary"
echo "==> project.godot VRAM flags before export:"
grep -n "vram_compression" "$ROOT/game/project.godot" || true

rm -rf "$ROOT/dist/releases/SolidExpress-${VERSION}-macos"
mkdir -p "$ROOT/dist/releases/SolidExpress-${VERSION}-macos"

echo "==> Godot export-release preset=${PRESET} (universal template, then thin to arm64)"
"$GODOT" --headless --path game --export-release "$PRESET" "$OUT_APP"
if [[ ! -d "$OUT_APP" ]]; then echo "Export failed: $OUT_APP" >&2; exit 1; fi

mkdir -p "$OUT_APP/Contents/MacOS" "$OUT_APP/Contents/Frameworks"
cp -f game/bin/libplanegcs.dylib "$OUT_APP/Contents/MacOS/"
if [[ ! -f "$OUT_APP/Contents/Frameworks/libsxcore.dylib" ]]; then
  cp -f game/bin/libsxcore.dylib "$OUT_APP/Contents/Frameworks/"
fi

echo "==> bundle Homebrew OCCT / transitive dylibs into Frameworks"
chmod +x "$ROOT/packaging/macos/bundle-dylibs.sh"
"$ROOT/packaging/macos/bundle-dylibs.sh" "$OUT_APP"

thin_to_arm64() {
  local f="$1"
  local info
  info="$(lipo -info "$f" 2>/dev/null || true)"
  if echo "$info" | grep -q "Architectures in the fat file" && echo "$info" | grep -q arm64; then
    echo "thin $f"
    lipo -thin arm64 "$f" -output "$f.arm64"
    mv "$f.arm64" "$f"
  fi
}

echo "==> thin Mach-O binaries to arm64 (Apple Silicon only)"
while IFS= read -r f; do
  thin_to_arm64 "$f"
done < <(find "$OUT_APP" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' -o -name '*.framework' \) 2>/dev/null)
if [[ -f "$OUT_APP/Contents/MacOS/SolidExpress" ]]; then
  thin_to_arm64 "$OUT_APP/Contents/MacOS/SolidExpress"
  chmod +x "$OUT_APP/Contents/MacOS/SolidExpress"
  lipo -info "$OUT_APP/Contents/MacOS/SolidExpress" || true
fi

BUNDLE_DIR="$(dirname "$OUT_APP")"
[[ -f "$ROOT/NOTICE" ]] && cp -f "$ROOT/NOTICE" "$BUNDLE_DIR/NOTICE"
[[ -f "$ROOT/THIRD_PARTY.md" ]] && cp -f "$ROOT/THIRD_PARTY.md" "$BUNDLE_DIR/THIRD_PARTY.md"
[[ -f "$ROOT/LICENSE" ]] && cp -f "$ROOT/LICENSE" "$BUNDLE_DIR/LICENSE"
mkdir -p "$OUT_APP/Contents/Resources"
[[ -f "$ROOT/NOTICE" ]] && cp -f "$ROOT/NOTICE" "$OUT_APP/Contents/Resources/NOTICE"
[[ -f "$ROOT/THIRD_PARTY.md" ]] && cp -f "$ROOT/THIRD_PARTY.md" "$OUT_APP/Contents/Resources/THIRD_PARTY.md"
[[ -f "$ROOT/LICENSE" ]] && cp -f "$ROOT/LICENSE" "$OUT_APP/Contents/Resources/LICENSE"

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE_DIR" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "${ARCHIVE}.sha256"
echo "OK: $ARCHIVE"
cat "${ARCHIVE}.sha256"
