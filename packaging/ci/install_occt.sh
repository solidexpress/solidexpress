#!/usr/bin/env bash
# Build and install the pinned Open CASCADE Technology release from source.
# Used by Linux and macOS CI/release so every platform matches Windows vcpkg.
#
# Env:
#   OCCT_PREFIX   install root (default: /opt/occt-$OCCT_VERSION)
#   OCCT_JOBS     parallel build jobs (default: nproc / sysctl)
#   OCCT_VERSION / OCCT_TAG / OCCT_TARBALL_SHA256 — override packaging/occt.version
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/packaging/occt.version"

OCCT_VERSION="${OCCT_VERSION:?}"
OCCT_TAG="${OCCT_TAG:?}"
OCCT_TARBALL_SHA256="${OCCT_TARBALL_SHA256:?}"
OCCT_PREFIX="${OCCT_PREFIX:-/opt/occt-${OCCT_VERSION}}"

if [[ -f "${OCCT_PREFIX}/lib/cmake/opencascade/OpenCASCADEConfig.cmake" ]] || \
   [[ -f "${OCCT_PREFIX}/lib/cmake/opencascade/OpenCASCADEConfig-release.cmake" ]]; then
  echo "OCCT ${OCCT_VERSION} already installed at ${OCCT_PREFIX}"
  echo "CMAKE_PREFIX_PATH=${OCCT_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
  exit 0
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  OCCT_JOBS="${OCCT_JOBS:-$(sysctl -n hw.ncpu)}"
else
  OCCT_JOBS="${OCCT_JOBS:-$(nproc)}"
fi

WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/occt-src-${OCCT_VERSION}"
TARBALL="${WORKDIR}/occt-${OCCT_VERSION}.tar.gz"
SRC="${WORKDIR}/OCCT-${OCCT_TAG}"
BUILD="${WORKDIR}/build"

mkdir -p "${WORKDIR}"
echo "==> downloading OCCT ${OCCT_TAG}"
curl -fsSL --retry 5 --retry-all-errors \
  -o "${TARBALL}" \
  "https://github.com/Open-Cascade-SAS/OCCT/archive/refs/tags/${OCCT_TAG}.tar.gz"

if command -v sha256sum >/dev/null 2>&1; then
  echo "${OCCT_TARBALL_SHA256}  ${TARBALL}" | sha256sum -c -
else
  echo "${OCCT_TARBALL_SHA256}  ${TARBALL}" | shasum -a 256 -c -
fi

rm -rf "${SRC}" "${BUILD}"
tar -xzf "${TARBALL}" -C "${WORKDIR}"
# GitHub archive extracts as OCCT-<tag with underscores or dots>
if [[ ! -d "${SRC}" ]]; then
  SRC="$(find "${WORKDIR}" -maxdepth 1 -type d -name 'OCCT-*' | head -1)"
fi
[[ -d "${SRC}" ]] || { echo "error: extracted OCCT source not found" >&2; exit 1; }

mkdir -p "${BUILD}"
# Args as an array so a mid-run edit of this file cannot break line continuations.
cmake_args=(
  -S "${SRC}"
  -B "${BUILD}"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="${OCCT_PREFIX}"
  -DBUILD_LIBRARY_TYPE=Shared
  -DBUILD_MODULE_Draw=OFF
  -DBUILD_DOC_Overview=OFF
  -DINSTALL_DIR_LAYOUT=Unix
  -DINSTALL_TEST_CASES=OFF
  -DUSE_TBB=ON
  -DUSE_FREETYPE=ON
  -DUSE_RAPIDJSON=ON
  -DUSE_TK=OFF
  -DUSE_FREEIMAGE=OFF
  -DUSE_VTK=OFF
)
cmake "${cmake_args[@]}"

cmake --build "${BUILD}" -j "${OCCT_JOBS}"
cmake --install "${BUILD}"

# Make the install discoverable for subsequent steps in the same job.
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "OCCT_PREFIX=${OCCT_PREFIX}"
    echo "CMAKE_PREFIX_PATH=${OCCT_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
    echo "LD_LIBRARY_PATH=${OCCT_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    echo "DYLD_LIBRARY_PATH=${OCCT_PREFIX}/lib${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"
  } >> "${GITHUB_ENV}"
fi

echo "Installed OCCT ${OCCT_VERSION} → ${OCCT_PREFIX}"
ls "${OCCT_PREFIX}/lib/cmake/opencascade" || true
