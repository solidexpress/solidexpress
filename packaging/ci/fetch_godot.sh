#!/usr/bin/env bash
#
# Fetches the pinned Godot editor binary for Linux and places it at tools/godot/godot.
# - Pin: 4.7-stable (must match the GDExtension API used by thirdparty/godot-cpp)
# - Source: GitHub releases (godotengine/godot)
# - Cache: In CI we cache tools/godot/godot via actions/cache keyed by the version string.
#
# Usage (idempotent):
#   packaging/ci/fetch_godot.sh
#   tools/godot/godot --version
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/tools"
GODOT_DIR="${TOOLS_DIR}/godot"
GODOT_BIN="${GODOT_DIR}/godot"

GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
GODOT_TAG="${GODOT_VERSION}"
ZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
RELEASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/${ZIP_NAME}"

mkdir -p "${GODOT_DIR}"

# If present and correct version, keep the cached binary.
if [[ -x "${GODOT_BIN}" ]]; then
  if "${GODOT_BIN}" --version 2>/dev/null | grep -q "v4.7.stable"; then
    echo "Godot binary already present at ${GODOT_BIN} (4.7-stable) — reusing."
    exit 0
  else
    echo "Existing Godot binary version mismatch — replacing with ${GODOT_VERSION}."
    rm -f "${GODOT_BIN}"
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

echo "Downloading ${RELEASE_URL}"
curl -fsSL --retry 5 --retry-all-errors -o "${tmpdir}/${ZIP_NAME}" "${RELEASE_URL}"
unzip -q "${tmpdir}/${ZIP_NAME}" -d "${tmpdir}"

# The zip contains a single executable named like Godot_v4.7-stable_linux.x86_64
exe="$(ls -1 "${tmpdir}" | grep -E '^Godot_v[0-9.]+-stable_linux\.x86_64$' | head -n1 || true)"
if [[ -z "${exe}" ]]; then
  # Fallback: find any executable file in the unzip directory
  exe="$(find "${tmpdir}" -maxdepth 1 -type f -executable -printf '%f\n' | head -n1 || true)"
fi

if [[ -z "${exe}" ]]; then
  echo "Error: could not locate Godot executable after unzip." >&2
  exit 1
fi

install -m 0755 "${tmpdir}/${exe}" "${GODOT_BIN}"
echo "Godot ${GODOT_VERSION} installed to ${GODOT_BIN}"

