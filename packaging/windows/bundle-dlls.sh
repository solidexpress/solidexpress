#!/usr/bin/env bash
# Bundle non-system DLL deps of libsxcore.dll into the Windows release folder.
# Prefer vcpkg z-applocal; fall back to copying OCCT/TBB DLLs from the vcpkg bin dir.
# Run from repo root on Windows (Git Bash) after Godot export.
set -euo pipefail

OUT_DIR="${1:-}"
if [[ -z "$OUT_DIR" || ! -d "$OUT_DIR" ]]; then
  echo "usage: $0 /path/to/SolidExpress-<ver>-windows-x86_64" >&2
  exit 1
fi

SXCORE=""
for cand in "$OUT_DIR/libsxcore.dll" "$OUT_DIR/sxcore.dll"; do
  if [[ -f "$cand" ]]; then SXCORE="$cand"; break; fi
done
[[ -n "$SXCORE" ]] || { echo "error: libsxcore.dll not found in $OUT_DIR" >&2; exit 1; }

if [[ -f game/bin/libplanegcs.dll && ! -f "$OUT_DIR/libplanegcs.dll" ]]; then
  cp -f game/bin/libplanegcs.dll "$OUT_DIR/"
fi

INSTALLED_BIN=""
if [[ -n "${VCPKG_ROOT:-}" ]]; then
  for cand in \
    "$VCPKG_ROOT/installed/x64-windows/bin" \
    "$VCPKG_ROOT/installed/x64-windows-release/bin"; do
    if [[ -d "$cand" ]]; then INSTALLED_BIN="$cand"; break; fi
  done
fi

applocal_one() {
  local target="$1"
  [[ -f "$target" ]] || return 0
  if [[ -z "${VCPKG_ROOT:-}" || ! -f "$VCPKG_ROOT/vcpkg.exe" || -z "$INSTALLED_BIN" ]]; then
    return 1
  fi
  echo "  z-applocal $(basename "$target")"
  "$VCPKG_ROOT/vcpkg.exe" z-applocal \
    --target-binary "$target" \
    --installed-bin-dir "$INSTALLED_BIN"
}

echo "==> bundling DLL deps into $OUT_DIR"
if [[ -n "$INSTALLED_BIN" && -f "${VCPKG_ROOT:-}/vcpkg.exe" ]]; then
  # Seed + iterate: each newly copied DLL may pull more deps.
  applocal_one "$SXCORE" || true
  [[ -f "$OUT_DIR/libplanegcs.dll" ]] && applocal_one "$OUT_DIR/libplanegcs.dll" || true
  changed=1
  pass=0
  while [[ "$changed" -eq 1 && "$pass" -lt 8 ]]; do
    changed=0
    pass=$((pass + 1))
    before="$(ls -1 "$OUT_DIR"/*.dll 2>/dev/null | wc -l | tr -d ' ')"
    for dll in "$OUT_DIR"/*.dll; do
      [[ -f "$dll" ]] || continue
      applocal_one "$dll" || true
    done
    after="$(ls -1 "$OUT_DIR"/*.dll 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$after" -gt "$before" ]]; then changed=1; fi
  done
else
  echo "warning: VCPKG_ROOT/installed bin not available; trying pattern copy" >&2
fi

# Always pull OCCT + TBB runtime DLLs from vcpkg if present (covers z-applocal gaps).
if [[ -n "$INSTALLED_BIN" ]]; then
  echo "==> ensuring OCCT/TBB DLLs from $INSTALLED_BIN"
  shopt -s nullglob
  for dll in \
    "$INSTALLED_BIN"/TK*.dll \
    "$INSTALLED_BIN"/tbb*.dll \
    "$INSTALLED_BIN"/tbbmalloc*.dll \
    "$INSTALLED_BIN"/freetype*.dll \
    "$INSTALLED_BIN"/freeimage*.dll \
    "$INSTALLED_BIN"/zlib*.dll \
    "$INSTALLED_BIN"/bz2*.dll \
    "$INSTALLED_BIN"/libpng*.dll \
    "$INSTALLED_BIN"/brotli*.dll \
    "$INSTALLED_BIN"/jpeg*.dll \
    "$INSTALLED_BIN"/openjp2*.dll \
    "$INSTALLED_BIN"/lcms*.dll \
    "$INSTALLED_BIN"/raw*.dll \
    "$INSTALLED_BIN"/Imath*.dll \
    "$INSTALLED_BIN"/OpenEXR*.dll \
    "$INSTALLED_BIN"/tiff*.dll \
    "$INSTALLED_BIN"/webp*.dll \
    "$INSTALLED_BIN"/LibRaw*.dll \
    "$INSTALLED_BIN"/jxr*.dll \
    "$INSTALLED_BIN"/OpenCASCADE*.dll; do
    base="$(basename "$dll")"
    if [[ ! -f "$OUT_DIR/$base" ]]; then
      echo "  + $base"
      cp -f "$dll" "$OUT_DIR/"
    fi
  done
  shopt -u nullglob
fi

# Fail if we still have essentially no OCCT runtime (only sxcore + planegcs).
tk_count="$(ls -1 "$OUT_DIR"/TK*.dll 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${tk_count:-0}" -lt 1 ]]; then
  echo "error: no TK*.dll (OpenCASCADE) bundled beside libsxcore.dll" >&2
  echo "       Set VCPKG_ROOT and install opencascade:x64-windows" >&2
  ls -la "$OUT_DIR"/*.dll 2>/dev/null | head -30 >&2 || true
  exit 1
fi

dll_count="$(ls -1 "$OUT_DIR"/*.dll 2>/dev/null | wc -l | tr -d ' ')"
echo "OK: bundled $dll_count DLLs ($tk_count OCCT TK*) in $OUT_DIR"
