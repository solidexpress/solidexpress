#!/usr/bin/env bash
# Download Godot 4.7 editor + export templates (all platforms in template pack).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BUILD="${GODOT_BUILD:-4.7.1}"
GODOT_VERSION="${GODOT_VERSION:-${GODOT_BUILD}.stable}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_BUILD}-stable"
TOOLS="$ROOT/tools/godot"

os="$(uname -s)"
case "$os" in
  Linux)
    TEMPLATES_DEFAULT="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}"
    ;;
  Darwin)
    TEMPLATES_DEFAULT="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows*)
    TEMPLATES_DEFAULT="${APPDATA:-$HOME/AppData/Roaming}/Godot/export_templates/${GODOT_VERSION}"
    ;;
  *)
    echo "Unsupported OS for fetch-godot-templates: $os" >&2
    exit 1
    ;;
esac
TEMPLATES="${GODOT_TEMPLATES_DIR:-$TEMPLATES_DEFAULT}"

mkdir -p "$TOOLS" "$TEMPLATES"
cd "$TOOLS"

case "$os" in
  Linux)
    editor_zip="Godot_v${GODOT_BUILD}-stable_linux.x86_64.zip"
    editor_path="$TOOLS/godot"
    if [[ ! -x "$editor_path" ]]; then
      echo "Fetching Godot editor ${GODOT_BUILD} (Linux)..."
      curl -fsSL -o godot.zip "${BASE}/${editor_zip}"
      unzip -o godot.zip
      mv "Godot_v${GODOT_BUILD}-stable_linux.x86_64" godot
      chmod +x godot
      rm -f godot.zip
    fi
    ;;
  Darwin)
    editor_path="$TOOLS/godot"
    if [[ ! -x "$editor_path" ]]; then
      echo "Fetching Godot editor ${GODOT_BUILD} (macOS)..."
      curl -fsSL -o godot.zip "${BASE}/Godot_v${GODOT_BUILD}-stable_macos.universal.zip"
      unzip -o godot.zip
      app="Godot.app"
      if [[ ! -d "$app" ]]; then
        app="$(find . -maxdepth 1 -name 'Godot*.app' -print -quit)"
      fi
      if [[ -z "$app" || ! -d "$app" ]]; then
        echo "Godot.app not found in macOS editor zip" >&2
        exit 1
      fi
      cp -f "$app/Contents/MacOS/Godot" godot
      chmod +x godot
      rm -rf "$app" godot.zip
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows*)
    editor_path="$TOOLS/godot.exe"
    rm -f "$TOOLS/godot"
    if [[ ! -f "$editor_path" ]]; then
      echo "Fetching Godot editor ${GODOT_BUILD} (Windows)..."
      curl -fsSL -o godot.zip "${BASE}/Godot_v${GODOT_BUILD}-stable_win64.exe.zip"
      unzip -o godot.zip
      if [[ -f "Godot_v${GODOT_BUILD}-stable_win64.exe" ]]; then
        mv "Godot_v${GODOT_BUILD}-stable_win64.exe" godot.exe
      elif [[ -f Godot_win64.exe ]]; then
        mv Godot_win64.exe godot.exe
      else
        exe="$(find . -maxdepth 1 -name '*.exe' -print -quit)"
        [[ -n "$exe" ]] && mv "$exe" godot.exe
      fi
      rm -f godot.zip
    fi
    if [[ ! -f "$editor_path" ]]; then
      echo "Godot.exe not found after Windows editor download" >&2
      exit 1
    fi
    ;;
esac

if [[ ! -f "$TEMPLATES/version.txt" && ! -f "$TEMPLATES/linux_release.x86_64" && ! -f "$TEMPLATES/macos.zip" ]]; then
  echo "Fetching export templates (all platforms)..."
  curl -fsSL -o templates.zip "${BASE}/Godot_v${GODOT_BUILD}-stable_export_templates.tpz"
  rm -rf /tmp/godot-templates-unpack
  mkdir -p /tmp/godot-templates-unpack
  unzip -o templates.zip -d /tmp/godot-templates-unpack
  cp -a /tmp/godot-templates-unpack/templates/* "$TEMPLATES/"
  rm -rf /tmp/godot-templates-unpack templates.zip
fi

echo "Godot editor: ${editor_path:-$TOOLS/godot}"
echo "Templates: $TEMPLATES"
