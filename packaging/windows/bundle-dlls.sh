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

to_unix_path() {
  local p="$1"
  [[ -n "$p" ]] || { echo ""; return 0; }
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p"
    return 0
  fi
  # D:\foo\bar or D:/foo/bar → /d/foo/bar
  if [[ "$p" =~ ^([a-zA-Z]):[\\/](.*)$ ]]; then
    local drive rest
    drive="$(echo "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z')"
    rest="${BASH_REMATCH[2]//\\//}"
    echo "/${drive}/${rest}"
    return 0
  fi
  echo "$p"
}

SXCORE=""
for cand in "$OUT_DIR/libsxcore.dll" "$OUT_DIR/sxcore.dll"; do
  if [[ -f "$cand" ]]; then SXCORE="$cand"; break; fi
done
[[ -n "$SXCORE" ]] || { echo "error: libsxcore.dll not found in $OUT_DIR" >&2; exit 1; }

# MSVC/cmake often already copies OCCT deps into game/bin — harvest those first.
if [[ -d game/bin ]]; then
  shopt -s nullglob
  for dll in game/bin/*.dll; do
    base="$(basename "$dll")"
    if [[ ! -f "$OUT_DIR/$base" ]]; then
      echo "  + $base  <- game/bin"
      cp -f "$dll" "$OUT_DIR/"
    fi
  done
  shopt -u nullglob
fi

# Resolve the *project* vcpkg tree. ilammy/msvc-dev-cmd overwrites VCPKG_ROOT with
# Visual Studio's bundled vcpkg, so prefer SX_VCPKG_ROOT / CMAKE_TOOLCHAIN_FILE.
resolve_vcpkg_root() {
  local root=""
  for cand in "${SX_VCPKG_ROOT:-}" "${VCPKG_ROOT:-}"; do
    [[ -n "$cand" ]] || continue
    root="$(to_unix_path "$cand")"
    if [[ -f "$root/vcpkg.exe" || -d "$root/installed" ]]; then
      echo "$root"
      return 0
    fi
  done
  if [[ -n "${CMAKE_TOOLCHAIN_FILE:-}" ]]; then
    local tc
    tc="$(to_unix_path "$CMAKE_TOOLCHAIN_FILE")"
    # .../scripts/buildsystems/vcpkg.cmake → vcpkg root
    if [[ "$tc" == */scripts/buildsystems/vcpkg.cmake ]]; then
      root="${tc%/scripts/buildsystems/vcpkg.cmake}"
      if [[ -f "$root/vcpkg.exe" || -d "$root/installed" ]]; then
        echo "$root"
        return 0
      fi
    fi
  fi
  return 1
}

VCPKG_ROOT_U="$(resolve_vcpkg_root || true)"
INSTALLED_BIN=""
if [[ -n "$VCPKG_ROOT_U" ]]; then
  for cand in \
    "$VCPKG_ROOT_U/installed/x64-windows/bin" \
    "$VCPKG_ROOT_U/installed/x64-windows-release/bin"; do
    if [[ -d "$cand" ]]; then INSTALLED_BIN="$cand"; break; fi
  done
fi
if [[ -z "$INSTALLED_BIN" ]]; then
  # Last-ditch: locate TKernel.dll under any vcpkg installed tree we can see.
  for cand in \
    "$(to_unix_path "${SX_VCPKG_ROOT:-}")/installed/x64-windows/bin" \
    "$(to_unix_path "${RUNNER_TEMP:-}")/vcpkg/installed/x64-windows/bin" \
    /d/a/_temp/vcpkg/installed/x64-windows/bin; do
    if [[ -d "$cand" && -f "$cand/TKernel.dll" ]]; then
      INSTALLED_BIN="$cand"
      # bin → x64-windows → installed → <vcpkg root>
      VCPKG_ROOT_U="$(cd "$cand/../../.." && pwd)"
      break
    fi
  done
fi

applocal_one() {
  local target="$1"
  local vcpkg_exe=""
  [[ -f "$target" ]] || return 0
  if [[ -z "$INSTALLED_BIN" ]]; then
    return 1
  fi
  if [[ -n "$VCPKG_ROOT_U" && -f "$VCPKG_ROOT_U/vcpkg.exe" ]]; then
    vcpkg_exe="$VCPKG_ROOT_U/vcpkg.exe"
  elif [[ -n "${VCPKG_ROOT:-}" && -f "$(to_unix_path "${VCPKG_ROOT}")/vcpkg.exe" ]]; then
    vcpkg_exe="$(to_unix_path "${VCPKG_ROOT}")/vcpkg.exe"
  else
    return 1
  fi
  echo "  z-applocal $(basename "$target")"
  # z-applocal wants Windows paths on this host.
  local target_w bin_w
  if command -v cygpath >/dev/null 2>&1; then
    target_w="$(cygpath -w "$target")"
    bin_w="$(cygpath -w "$INSTALLED_BIN")"
  else
    target_w="$target"
    bin_w="$INSTALLED_BIN"
  fi
  "$vcpkg_exe" z-applocal \
    --target-binary "$target_w" \
    --installed-bin-dir "$bin_w"
}

echo "==> bundling DLL deps into $OUT_DIR"
if [[ -n "$INSTALLED_BIN" ]]; then
  echo "    vcpkg root: ${VCPKG_ROOT_U:-unknown}"
  echo "    installed bin: $INSTALLED_BIN"
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
  echo "warning: vcpkg installed/bin not found (VCPKG_ROOT='${VCPKG_ROOT:-}' SX_VCPKG_ROOT='${SX_VCPKG_ROOT:-}')" >&2
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
