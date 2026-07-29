#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIR="$ROOT/packaging/flatpak"
BUILD="$ROOT/dist/flatpak-build"
OUT="$ROOT/dist/releases/SolidExpress-${VER}-linux-x86_64.flatpak"
TARBALL="$ROOT/dist/releases/SolidExpress-${VER}-linux-x86_64.tar.gz"
[[ -f "$TARBALL" ]] || { echo "Need Linux tarball first" >&2; exit 1; }
tar -xzf "$TARBALL" -C "$ROOT/dist/releases"
cp -f "$ROOT/docs/branding/logo.png" "$DIR/icon.png" 2>/dev/null || cp "$ROOT/game/icon.png" "$DIR/icon.png"
rm -rf "$BUILD"
flatpak-builder --force-clean --repo="$ROOT/dist/flatpak-repo" "$BUILD" "$DIR/com.solidexpress.SolidExpress.yml"
flatpak build-bundle "$ROOT/dist/flatpak-repo" "$OUT" com.solidexpress.SolidExpress
echo "OK $OUT"
