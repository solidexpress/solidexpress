#!/usr/bin/env bash
# Download Godot 4.7 editor + export templates into tools/godot (repo-local).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.7.stable}"
GODOT_BUILD="${GODOT_BUILD:-4.7.1}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_BUILD}-stable"
TOOLS="$ROOT/tools/godot"
TEMPLATES="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}"

mkdir -p "$TOOLS" "$TEMPLATES"
cd "$TOOLS"

if [[ ! -x "$TOOLS/godot" ]]; then
  echo "Fetching Godot editor ${GODOT_BUILD}..."
  curl -fsSL -o godot.zip "${BASE}/Godot_v${GODOT_BUILD}-stable_linux.x86_64.zip"
  unzip -o godot.zip
  mv "Godot_v${GODOT_BUILD}-stable_linux.x86_64" godot
  chmod +x godot
  rm -f godot.zip
fi

if [[ ! -f "$TEMPLATES/linux_release.x86_64" ]]; then
  echo "Fetching Linux export templates..."
  curl -fsSL -o templates.zip "${BASE}/Godot_v${GODOT_BUILD}-stable_export_templates.tpz"
  unzip -o templates.zip -d /tmp/godot-templates-unpack
  cp -a /tmp/godot-templates-unpack/templates/* "$TEMPLATES/"
  rm -rf /tmp/godot-templates-unpack templates.zip
fi

echo "Godot: $TOOLS/godot"
echo "Templates: $TEMPLATES"
