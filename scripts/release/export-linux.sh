#!/usr/bin/env bash
# Build SolidExpress Linux desktop export + zip + sha256. Run from repo root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
GODOT="${GODOT:-tools/godot/godot}"
PRESET="${EXPORT_PRESET:-Linux}"
OUT_DIR="$ROOT/dist/releases/SolidExpress-${VERSION}-linux-x86_64"
ARCHIVE="$ROOT/dist/releases/SolidExpress-${VERSION}-linux-x86_64.tar.gz"

if [[ ! -x "$GODOT" ]]; then
  echo "Missing Godot at $GODOT — run: ./scripts/release/fetch-godot-templates.sh" >&2
  exit 1
fi

echo "==> cmake build (Release)"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j "$(nproc)"

echo "==> bundle libplanegcs next to GDExtension"
mkdir -p game/bin
if [[ -f build/libplanegcs.so ]]; then
  cp -f build/libplanegcs.so game/bin/
elif [[ -f build/thirdparty/planegcs/libplanegcs.so ]]; then
  cp -f build/thirdparty/planegcs/libplanegcs.so game/bin/
else
  PLANEGCS="$(find build -name 'libplanegcs.so' -print -quit)"
  if [[ -n "$PLANEGCS" ]]; then
    cp -f "$PLANEGCS" game/bin/
  else
    echo "warning: libplanegcs.so not found under build/" >&2
  fi
fi

echo "==> Godot import"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$ROOT/dist/releases"
EXPORT_BIN="$OUT_DIR/SolidExpress.x86_64"

echo "==> Godot export-release preset=${PRESET}"
"$GODOT" --headless --path game --export-release "$PRESET" "$EXPORT_BIN"

if [[ ! -f "$EXPORT_BIN" ]]; then
  echo "Export failed: $EXPORT_BIN not found" >&2
  exit 1
fi

# Ensure GDExtension + PlaneGCS are beside the game binary for $ORIGIN loading.
if [[ -f game/bin/libsxcore.so ]]; then
  cp -f game/bin/libsxcore.so "$OUT_DIR/"
fi
if [[ -f game/bin/libplanegcs.so ]]; then
  cp -f game/bin/libplanegcs.so "$OUT_DIR/"
fi
if [[ ! -f "$OUT_DIR/libsxcore.so" ]]; then
  echo "error: $OUT_DIR/libsxcore.so missing after export" >&2
  exit 1
fi

echo "==> bundle non-system shared libs (OCCT, TBB, …) + RUNPATH=\$ORIGIN"
chmod +x "$ROOT/packaging/linux/bundle-shared-libs.sh"
"$ROOT/packaging/linux/bundle-shared-libs.sh" "$OUT_DIR"

cp -f "$ROOT/NOTICE" "$OUT_DIR/NOTICE"
if [[ -f "$ROOT/THIRD_PARTY.md" ]]; then
  cp -f "$ROOT/THIRD_PARTY.md" "$OUT_DIR/THIRD_PARTY.md"
fi
if [[ -f "$ROOT/LICENSE" ]]; then
  cp -f "$ROOT/LICENSE" "$OUT_DIR/LICENSE"
fi

echo "==> archive"
tar -czf "$ARCHIVE" -C "$ROOT/dist/releases" "SolidExpress-${VERSION}-linux-x86_64"
sha256sum "$ARCHIVE" > "${ARCHIVE}.sha256"

echo "OK: $ARCHIVE"
cat "${ARCHIVE}.sha256"
