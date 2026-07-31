#!/usr/bin/env bash
# Bundle non-system shared-library deps next to libsxcore.so and set RUNPATH=$ORIGIN.
# Run after Godot Linux export. Requires ldd + patchelf.
set -euo pipefail

OUT_DIR="${1:-}"
if [[ -z "$OUT_DIR" || ! -d "$OUT_DIR" ]]; then
  echo "usage: $0 /path/to/SolidExpress-<ver>-linux-x86_64" >&2
  exit 1
fi

if ! command -v patchelf >/dev/null 2>&1; then
  echo "error: patchelf is required (apt install patchelf)" >&2
  exit 1
fi

SXCORE=""
for cand in "$OUT_DIR/libsxcore.so" "$OUT_DIR/lib/libsxcore.so"; do
  if [[ -f "$cand" ]]; then SXCORE="$cand"; break; fi
done
[[ -n "$SXCORE" ]] || { echo "error: libsxcore.so not found in $OUT_DIR" >&2; exit 1; }

# Ensure PlaneGCS sits beside libsxcore for $ORIGIN resolution.
if [[ -f "$OUT_DIR/libplanegcs.so" ]]; then
  :
elif [[ -f game/bin/libplanegcs.so ]]; then
  cp -f game/bin/libplanegcs.so "$OUT_DIR/"
fi

is_system_lib() {
  local base="$1"
  case "$base" in
    linux-vdso.so*|ld-linux*.so*|ld-linux-x86-64.so*)
      return 0 ;;
    libc.so*|libm.so*|libdl.so*|librt.so*|libpthread.so*|libresolv.so*|libutil.so*|libcrypt.so*)
      return 0 ;;
    libgcc_s.so*|libstdc++.so*|libgomp.so*)
      return 0 ;;
    # Desktop display stack — present on normal Linux workstations; Godot already needs these.
    libX*.so*|libxcb*.so*|libGL*.so*|libOpenGL.so*|libEGL.so*|libGLdispatch.so*|libGLX.so*|libdrm.so*|libwayland*.so*)
      return 0 ;;
    libfontconfig.so*|libfreetype.so*|libpng*.so*|libz.so*|libbz2.so*|libexpat.so*|libbrotli*.so*|libuuid.so*|libffi.so*|libmd.so*|libbsd.so*)
      return 0 ;;
    libasound.so*|libpulse*.so*|libdbus*.so*|libsystemd.so*|libselinux.so*|libpcre*.so*|libcap.so*|libgpg-error.so*|liblzma.so*|liblz4.so*|libzstd.so*|libgcrypt.so*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

SEEN_FILE="$(mktemp)"
QUEUE_FILE="$(mktemp)"
trap 'rm -f "$SEEN_FILE" "$QUEUE_FILE"' EXIT

enqueue() { echo "$1" >> "$QUEUE_FILE"; }
already_seen() { grep -Fxq "$1" "$SEEN_FILE" 2>/dev/null; }
mark_seen() { echo "$1" >> "$SEEN_FILE"; }

# Resolve "NEEDED => path" lines from ldd. Prefer the soname basename for the dest name.
collect_from() {
  local seed="$1"
  local line name path dest
  while IFS= read -r line; do
    [[ "$line" == *"=>"* ]] || continue
    name="$(echo "$line" | awk '{print $1}')"
    path="$(echo "$line" | awk '{print $3}')"
    [[ -z "$name" ]] && continue
    is_system_lib "$name" && continue
    if [[ "$path" == "not" || -z "$path" || "$path" == *"(" ]]; then
      # Try ldconfig / default search for a missing sibling we already bundled.
      if [[ -f "$OUT_DIR/$name" ]]; then
        continue
      fi
      echo "warning: unresolved dependency $name (from $(basename "$seed"))" >&2
      continue
    fi
    [[ -f "$path" ]] || continue
    dest="$OUT_DIR/$name"
    if [[ ! -e "$dest" ]]; then
      echo "  + $name  <- $path"
      cp -L "$path" "$dest"
      chmod u+w "$dest" 2>/dev/null || true
    fi
    enqueue "$dest"
  done < <(ldd "$seed" 2>/dev/null || true)
}

enqueue "$SXCORE"
[[ -f "$OUT_DIR/libplanegcs.so" ]] && enqueue "$OUT_DIR/libplanegcs.so"

echo "==> collecting shared libs into $OUT_DIR"
while [[ -s "$QUEUE_FILE" ]]; do
  lib="$(head -n 1 "$QUEUE_FILE")"
  tail -n +2 "$QUEUE_FILE" > "${QUEUE_FILE}.rest"
  mv "${QUEUE_FILE}.rest" "$QUEUE_FILE"
  already_seen "$lib" && continue
  mark_seen "$lib"
  [[ -f "$lib" ]] || continue
  collect_from "$lib"
done

echo "==> setting RUNPATH=\$ORIGIN on bundled libs"
for lib in "$OUT_DIR"/*.so "$OUT_DIR"/*.so.*; do
  [[ -f "$lib" ]] || continue
  [[ "$(basename "$lib")" == SolidExpress* ]] && continue
  # Skip the Godot binary if somehow matched.
  file "$lib" 2>/dev/null | grep -q 'ELF' || continue
  if patchelf --print-soname "$lib" >/dev/null 2>&1 || \
     patchelf --print-rpath "$lib" >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$lib" 2>/dev/null || true
  fi
done
# Always patch the GDExtension + PlaneGCS seeds.
patchelf --set-rpath '$ORIGIN' "$SXCORE"
[[ -f "$OUT_DIR/libplanegcs.so" ]] && patchelf --set-rpath '$ORIGIN' "$OUT_DIR/libplanegcs.so"

echo "==> verifying libsxcore resolves without host OCCT paths"
# Clear env that could hide missing bundles; keep only $ORIGIN via RPATH.
missing="$(
  env -u LD_LIBRARY_PATH -u LD_PRELOAD ldd "$SXCORE" 2>&1 | awk '/not found/ {print $1}' || true
)"
if [[ -n "$missing" ]]; then
  echo "error: still unresolved after bundling:" >&2
  echo "$missing" >&2
  env -u LD_LIBRARY_PATH ldd "$SXCORE" >&2 || true
  exit 1
fi

# Reject lingering absolute RUNPATHs pointing at the build machine.
rpath="$(patchelf --print-rpath "$SXCORE" 2>/dev/null || true)"
case "$rpath" in
  *"/home/"*|*"/Users/"*|*/runner/*)
    echo "error: libsxcore RUNPATH still contains host path: $rpath" >&2
    exit 1
    ;;
esac

count="$(find "$OUT_DIR" -maxdepth 1 \( -name '*.so' -o -name '*.so.*' \) | wc -l | tr -d ' ')"
echo "OK: bundled $count shared libs in $OUT_DIR (RUNPATH=\$ORIGIN)"
