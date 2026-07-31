#!/usr/bin/env bash
# Bundle non-system dylib deps of libsxcore into SolidExpress.app/Contents/Frameworks
# and rewrite install names to @rpath so the app runs without Homebrew OCCT.
# Run on macOS after Godot export. Requires otool + install_name_tool.
# Compatible with macOS /bin/bash 3.2 (no associative arrays).
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP/Contents" ]]; then
  echo "usage: $0 /path/to/SolidExpress.app" >&2
  exit 1
fi

FW="$APP/Contents/Frameworks"
MACOS="$APP/Contents/MacOS"
mkdir -p "$FW"
SEEN_FILE="$(mktemp)"
QUEUE_FILE="$(mktemp)"
trap 'rm -f "$SEEN_FILE" "$QUEUE_FILE"' EXIT

SXCORE="$FW/libsxcore.dylib"
if [[ ! -f "$SXCORE" ]]; then
  for cand in "$MACOS/libsxcore.dylib" "$APP/Contents/Resources/libsxcore.dylib"; do
    if [[ -f "$cand" ]]; then
      mv -f "$cand" "$SXCORE"
      break
    fi
  done
fi
[[ -f "$SXCORE" ]] || { echo "error: libsxcore.dylib not found in $APP" >&2; exit 1; }

# PlaneGCS must live next to libsxcore for @rpath resolution.
if [[ -f "$MACOS/libplanegcs.dylib" && ! -f "$FW/libplanegcs.dylib" ]]; then
  cp -f "$MACOS/libplanegcs.dylib" "$FW/libplanegcs.dylib"
fi
if [[ -f "$FW/libplanegcs.dylib" && -f "$MACOS/libplanegcs.dylib" ]]; then
  rm -f "$MACOS/libplanegcs.dylib"
fi

is_system_lib() {
  case "$1" in
    /usr/lib/*|/System/*|/Library/Apple/*) return 0 ;;
    *) return 1 ;;
  esac
}

already_seen() {
  grep -Fxq "$1" "$SEEN_FILE" 2>/dev/null
}

mark_seen() {
  echo "$1" >> "$SEEN_FILE"
}

enqueue() {
  echo "$1" >> "$QUEUE_FILE"
}

rpaths_of() {
  otool -l "$1" 2>/dev/null | awk '
    /cmd LC_RPATH/ { want=1; next }
    want && /path / {
      sub(/^[[:space:]]*path /, "");
      sub(/ \(offset.*$/, "");
      print;
      want=0
    }
  '
}

resolve_dep() {
  local dep="$1"
  local loader="$2"
  local base rpath try
  if [[ "$dep" == /* && -f "$dep" ]]; then
    echo "$dep"
    return 0
  fi
  base="$(basename "$dep")"
  if [[ -f "$FW/$base" ]]; then
    echo "$FW/$base"
    return 0
  fi
  while IFS= read -r rpath; do
    [[ -z "$rpath" ]] && continue
    case "$rpath" in
      @loader_path*)
        try="$(dirname "$loader")/${rpath#@loader_path}/$base"
        try="$(cd "$(dirname "$try")" 2>/dev/null && pwd)/$(basename "$try")" || try=""
        ;;
      @executable_path*)
        try="$MACOS/${rpath#@executable_path}/$base"
        try="$(cd "$(dirname "$try")" 2>/dev/null && pwd)/$(basename "$try")" || try=""
        ;;
      *)
        try="$rpath/$base"
        ;;
    esac
    if [[ -n "$try" && -f "$try" ]]; then
      echo "$try"
      return 0
    fi
  done < <(rpaths_of "$loader")
  for try in \
    "/opt/homebrew/lib/$base" \
    "/opt/homebrew/opt/opencascade/lib/$base" \
    "/usr/local/lib/$base" \
    "/usr/local/opt/opencascade/lib/$base"; do
    if [[ -f "$try" ]]; then
      echo "$try"
      return 0
    fi
  done
  return 1
}

deps_of() {
  # Skip the first line (the library itself).
  otool -L "$1" | awk 'NR>1 {
    sub(/^[[:space:]]+/, "");
    sub(/ \(compatibility.*$/, "");
    print
  }'
}

enqueue "$SXCORE"
if [[ -f "$FW/libplanegcs.dylib" ]]; then
  enqueue "$FW/libplanegcs.dylib"
fi

echo "==> collecting dylib dependencies into $FW"
while [[ -s "$QUEUE_FILE" ]]; do
  lib="$(head -n 1 "$QUEUE_FILE")"
  tail -n +2 "$QUEUE_FILE" > "${QUEUE_FILE}.rest"
  mv "${QUEUE_FILE}.rest" "$QUEUE_FILE"
  already_seen "$lib" && continue
  mark_seen "$lib"

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    is_system_lib "$dep" && continue
    base="$(basename "$dep")"
    if [[ "$dep" == @rpath/* || "$dep" == @loader_path/* || "$dep" == @executable_path/* ]]; then
      [[ -f "$FW/$base" ]] && continue
    fi
    resolved="$(resolve_dep "$dep" "$lib" || true)"
    if [[ -z "$resolved" || ! -f "$resolved" ]]; then
      if [[ "$dep" == /* ]]; then
        echo "warning: missing dependency $dep (from $(basename "$lib"))" >&2
      fi
      continue
    fi
    dest="$FW/$base"
    if [[ ! -f "$dest" ]]; then
      echo "  + $base  <- $resolved"
      cp -f "$resolved" "$dest"
      chmod u+w "$dest"
    fi
    enqueue "$dest"
  done < <(deps_of "$lib")
done

rewrite_lib() {
  local lib="$1"
  local id base dep new rpath
  chmod u+w "$lib"
  id="@rpath/$(basename "$lib")"
  install_name_tool -id "$id" "$lib"

  while IFS= read -r rpath; do
    [[ -z "$rpath" || "$rpath" == @loader_path ]] && continue
    install_name_tool -delete_rpath "$rpath" "$lib" 2>/dev/null || true
  done < <(rpaths_of "$lib")
  install_name_tool -add_rpath "@loader_path" "$lib" 2>/dev/null || true

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    is_system_lib "$dep" && continue
    base="$(basename "$dep")"
    [[ -f "$FW/$base" ]] || continue
    new="@rpath/$base"
    [[ "$dep" == "$new" ]] && continue
    install_name_tool -change "$dep" "$new" "$lib" 2>/dev/null || true
  done < <(deps_of "$lib")
}

echo "==> rewriting install names to @rpath"
for lib in "$FW"/*.dylib; do
  [[ -f "$lib" ]] || continue
  rewrite_lib "$lib"
done

echo "==> verifying libsxcore has no host absolute deps"
bad=0
while IFS= read -r dep; do
  [[ "$dep" == /* ]] || continue
  is_system_lib "$dep" && continue
  echo "error: still linked to host library: $dep" >&2
  bad=1
done < <(deps_of "$SXCORE")
if [[ "$bad" -ne 0 ]]; then
  exit 1
fi

if command -v codesign >/dev/null 2>&1; then
  echo "==> ad-hoc codesign"
  codesign --force --deep -s - "$APP" 2>/dev/null || \
    codesign --force -s - "$APP" || true
fi

count="$(ls -1 "$FW"/*.dylib 2>/dev/null | wc -l | tr -d ' ')"
echo "OK: bundled $count dylibs in $FW"
