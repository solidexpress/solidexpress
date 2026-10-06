#!/usr/bin/env bash
# Copy export-linux.sh's VERSION-named tarball into linux-test-build asset names
# and write BUILDINFO.txt. Run from repo root after export-linux.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DIST="$ROOT/dist/releases"

FULLSHA="${GIT_COMMIT:-$(git rev-parse HEAD)}"
SHORTSHA="$(git rev-parse --short "$FULLSHA")"

if [[ ! -d "$DIST" ]]; then
  echo "Missing $DIST — run scripts/release/export-linux.sh first" >&2
  exit 1
fi

# Prefer the VERSION-named archive from export-linux.sh, never our staged copies.
mapfile -t candidates < <(
  find "$DIST" -maxdepth 1 -type f -name 'SolidExpress-*-linux-x86_64.tar.gz' \
    ! -name 'SolidExpress-linux-test-latest-x86_64.tar.gz' \
    ! -name "SolidExpress-${SHORTSHA}-linux-x86_64.tar.gz" \
    | sort
)
if [[ "${#candidates[@]}" -eq 0 ]]; then
  echo "No export-linux.sh tarball in $DIST" >&2
  exit 1
fi
SRC="${candidates[-1]}"

SHA_NAME="SolidExpress-${SHORTSHA}-linux-x86_64.tar.gz"
LATEST_NAME="SolidExpress-linux-test-latest-x86_64.tar.gz"

cp -f "$SRC" "$DIST/$SHA_NAME"
cp -f "$SRC" "$DIST/$LATEST_NAME"
(
  cd "$DIST"
  sha256sum "$SHA_NAME" > "${SHA_NAME}.sha256"
  sha256sum "$LATEST_NAME" > "${LATEST_NAME}.sha256"
)

OCCT="${OCCT_VERSION:-}"
if [[ -z "$OCCT" && -f "$ROOT/packaging/occt.version" ]]; then
  OCCT="$(awk -F= '/^OCCT_VERSION=/{print $2; exit}' "$ROOT/packaging/occt.version")"
fi
OCCT="${OCCT:-unknown}"

GODOT_BIN="${GODOT:-$ROOT/tools/godot/godot}"
GODOT_VER=""
if [[ -x "$GODOT_BIN" ]]; then
  GODOT_VER="$("$GODOT_BIN" --version 2>/dev/null | tr -d '\r\n' || true)"
fi
GODOT_VER="${GODOT_VER:-4.7-stable}"
BUILT_AT="${BUILT_AT_UTC:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

cat > "$DIST/BUILDINFO.txt" <<EOF
commit=${FULLSHA}
occt=${OCCT}
godot=${GODOT_VER}
built_at_utc=${BUILT_AT}
EOF

echo "Staged linux-test-build assets from $(basename "$SRC"):"
ls -l "$DIST/$SHA_NAME" "$DIST/$LATEST_NAME" "$DIST/BUILDINFO.txt"
cat "$DIST/BUILDINFO.txt"
