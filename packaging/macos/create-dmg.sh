#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
APP="$ROOT/dist/releases/SolidExpress-${VER}-macos/SolidExpress.app"
DMG="$ROOT/dist/releases/SolidExpress-${VER}-macos.dmg"
STAGE="$ROOT/dist/releases/dmg-stage"
[[ -d "$APP" ]] || { echo "Missing $APP" >&2; exit 1; }
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "SolidExpress" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
shasum -a 256 "$DMG" > "${DMG}.sha256"
echo "OK $DMG"
cat "${DMG}.sha256"
