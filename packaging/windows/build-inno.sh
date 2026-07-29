#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
SRC="$ROOT/dist/releases/SolidExpress-${VER}-windows-x86_64"
ISCC="${ISCC:-/c/Program Files (x86)/Inno Setup 6/ISCC.exe}"
if [[ ! -d "$SRC" ]]; then echo "Missing $SRC — run export-windows.sh first" >&2; exit 1; fi
"$ISCC" "/DMyAppVersion=$VER" "/DMySourceDir=$SRC" "$ROOT/packaging/windows/SolidExpress.iss"
