#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIR="$ROOT/packaging/flatpak"
BUILD="$ROOT/dist/flatpak-build"
OUT="$ROOT/dist/releases/SolidExpress-${VER}-linux-x86_64.flatpak"
TARBALL="$ROOT/dist/releases/SolidExpress-${VER}-linux-x86_64.tar.gz"
EXTRACTED="$ROOT/dist/releases/SolidExpress-${VER}-linux-x86_64"
[[ -f "$TARBALL" ]] || { echo "Need Linux tarball first" >&2; exit 1; }
tar -xzf "$TARBALL" -C "$ROOT/dist/releases"
[[ -d "$EXTRACTED" ]] || { echo "Tarball did not unpack to $EXTRACTED" >&2; exit 1; }
cp -f "$ROOT/docs/branding/logo.png" "$DIR/icon.png" 2>/dev/null || cp "$ROOT/game/icon.png" "$DIR/icon.png"
MANIFEST="$DIR/com.solidexpress.SolidExpress.yml"
CI_MANIFEST="$DIR/com.solidexpress.SolidExpress.ci.yml"
sed -E "s|SolidExpress-[0-9.]+-linux-x86_64|SolidExpress-${VER}-linux-x86_64|g" "$MANIFEST" > "$CI_MANIFEST"
rm -rf "$BUILD"
flatpak-builder --force-clean --repo="$ROOT/dist/flatpak-repo" "$BUILD" "$CI_MANIFEST"
flatpak build-bundle "$ROOT/dist/flatpak-repo" "$OUT" com.solidexpress.SolidExpress
rm -f "$CI_MANIFEST"
echo "OK $OUT"
