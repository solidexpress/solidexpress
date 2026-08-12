#!/usr/bin/env bash
# Build a drag-to-Applications DMG with Finder chrome (background + icon layout).
# Run on macOS after scripts/release/export-macos.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
APP="$ROOT/dist/releases/SolidExpress-${VER}-macos/SolidExpress.app"
DMG="$ROOT/dist/releases/SolidExpress-${VER}-macos.dmg"
STAGE="$ROOT/dist/releases/dmg-stage"
RW_DMG="$ROOT/dist/releases/dmg-rw.dmg"
BG_SRC="$ROOT/packaging/macos/dmg-background.png"
VOLNAME="SolidExpress"

[[ -d "$APP" ]] || { echo "Missing $APP" >&2; exit 1; }
[[ -f "$BG_SRC" ]] || { echo "Missing $BG_SRC" >&2; exit 1; }

rm -rf "$STAGE" "$DMG" "$RW_DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Hidden background folder (Finder reads this via AppleScript).
mkdir -p "$STAGE/.background"
cp "$BG_SRC" "$STAGE/.background/background.png"

# RW image so we can set Finder view options, then compress to UDZO.
SIZE_MB="$(du -sm "$STAGE" | awk '{print $1}')"
SIZE_MB=$((SIZE_MB + 40))
hdiutil create \
  -srcfolder "$STAGE" \
  -volname "$VOLNAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size "${SIZE_MB}m" \
  "$RW_DMG"

ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(echo "$ATTACH_OUT" | awk '/^\/dev\// {print $1; exit}')"
MOUNT="$(echo "$ATTACH_OUT" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
if [[ -z "$DEVICE" || -z "$MOUNT" || ! -d "$MOUNT" ]]; then
  echo "Failed to mount RW DMG" >&2
  echo "$ATTACH_OUT" >&2
  exit 1
fi

# Bless + layout: app left, Applications right, branded background.
# Retries help on CI where Finder can lag after attach.
layout_ok=0
for attempt in 1 2 3 4 5; do
  if osascript <<EOF
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:background.png"
    set position of item "SolidExpress.app" of container window to {158, 180}
    set position of item "Applications" of container window to {482, 180}
    update without registering applications
    delay 1
    close
    open
    delay 1
    set the bounds of container window to {200, 120, 840, 520}
    close
  end tell
end tell
EOF
  then
    layout_ok=1
    break
  fi
  echo "Finder layout attempt $attempt failed; retrying…" >&2
  sleep 2
done

if [[ "$layout_ok" -ne 1 ]]; then
  echo "warning: could not apply Finder chrome; shipping plain Applications symlink DMG" >&2
fi

sync || true
# Eject cleanly (retry if Finder still holds the volume).
for _ in 1 2 3 4 5; do
  if hdiutil detach "$DEVICE" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
# Force if still mounted.
if mount | grep -q "$MOUNT"; then
  hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
fi

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW_DMG"
rm -rf "$STAGE"

shasum -a 256 "$DMG" > "${DMG}.sha256"
echo "OK $DMG"
cat "${DMG}.sha256"
