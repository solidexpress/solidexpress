#!/usr/bin/env bash
#
# Runs a subset of Godot headless test suites that must stay green.
# Gated suites: workflow, ui, sketch, print
#
# This expects:
#  - tools/godot/godot present (use packaging/ci/fetch_godot.sh beforehand)
#  - the build already completed (libsxcore.so built under build/)
#  - first-run import can be slow; we run an import warming step here for safety
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${ROOT_DIR}/tools/godot/godot"
GAME_DIR="${ROOT_DIR}/game"

if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "Missing Godot binary at ${GODOT_BIN}. Run packaging/ci/fetch_godot.sh first." >&2
  exit 1
fi

echo "Warming import cache..."
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --import > /dev/null 2>&1 || true

echo "Running gated Godot suites (workflow, ui, sketch, print)"
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_workflow_tests.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_ui_tests.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_sketch_tests.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_print_tests.gd

echo "Gated suites completed."

