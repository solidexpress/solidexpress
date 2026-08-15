#!/usr/bin/env bash
# Developer ID sign + notarytool notarize + staple for CI.
# Usage:
#   sign-and-notarize.sh app /path/to/SolidExpress.app
#   sign-and-notarize.sh dmg /path/to/SolidExpress.dmg
#
# Required env:
#   APPLE_CERTIFICATE            base64-encoded Developer ID Application .p12
#   APPLE_CERTIFICATE_PASSWORD   p12 password
#   APPLE_TEAM_ID                10-char team id
#   APPLE_API_KEY_ID             App Store Connect API key id
#   APPLE_API_ISSUER_ID          issuer UUID
#   APPLE_API_KEY                .p8 private key contents
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENTITLEMENTS="$ROOT/packaging/macos/SolidExpress.entitlements"
MODE="${1:-}"
TARGET="${2:-}"

need() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "error: missing env $name" >&2
    exit 1
  fi
}

need APPLE_CERTIFICATE
need APPLE_CERTIFICATE_PASSWORD
need APPLE_TEAM_ID
need APPLE_API_KEY_ID
need APPLE_API_ISSUER_ID
need APPLE_API_KEY

if [[ -z "$MODE" || -z "$TARGET" ]]; then
  echo "usage: $0 app|dmg <path>" >&2
  exit 1
fi

WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/sx-signing-$$"
mkdir -p "$WORKDIR"
KEYCHAIN="$WORKDIR/signing.keychain-db"
KEYCHAIN_PW="$(openssl rand -base64 24)"
P12="$WORKDIR/cert.p12"
P8="$WORKDIR/AuthKey.p8"
cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "$APPLE_CERTIFICATE" | base64 --decode > "$P12"
printf '%s\n' "$APPLE_API_KEY" > "$P8"
chmod 600 "$P12" "$P8"

security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security import "$P12" -P "$APPLE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PW" "$KEYCHAIN" >/dev/null

IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
if [[ -z "$IDENTITY" ]]; then
  echo "error: no Developer ID Application identity in certificate" >&2
  security find-identity -v -p codesigning "$KEYCHAIN" >&2 || true
  exit 1
fi
echo "==> signing identity: $IDENTITY"

sign_macho() {
  local path="$1"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --keychain "$KEYCHAIN" \
    --sign "$IDENTITY" \
    "$path"
}

case "$MODE" in
  app)
    APP="$TARGET"
    [[ -d "$APP/Contents" ]] || { echo "error: not an .app: $APP" >&2; exit 1; }
    echo "==> signing nested Mach-O in $APP"
    # Inside-out: dylibs/binaries first, then the bundle. Avoid --deep.
    while IFS= read -r -d '' f; do
      if file -b "$f" | grep -q 'Mach-O'; then
        echo "  sign $(echo "$f" | sed "s|^$APP/||")"
        sign_macho "$f"
      fi
    done < <(find "$APP/Contents" -type f -print0)
    echo "==> signing app bundle"
    sign_macho "$APP"
    codesign --verify --deep --strict --verbose=2 "$APP"
    echo "OK signed $APP"
    ;;
  dmg)
    DMG="$TARGET"
    [[ -f "$DMG" ]] || { echo "error: missing dmg: $DMG" >&2; exit 1; }
    echo "==> signing DMG"
    codesign --force --timestamp --keychain "$KEYCHAIN" --sign "$IDENTITY" "$DMG"
    echo "==> submitting to notarytool (team $APPLE_TEAM_ID)"
    xcrun notarytool submit "$DMG" \
      --key "$P8" \
      --key-id "$APPLE_API_KEY_ID" \
      --issuer "$APPLE_API_ISSUER_ID" \
      --wait
    echo "==> stapling"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    shasum -a 256 "$DMG" > "${DMG}.sha256"
    echo "OK notarized $DMG"
    cat "${DMG}.sha256"
    ;;
  *)
    echo "usage: $0 app|dmg <path>" >&2
    exit 1
    ;;
esac
