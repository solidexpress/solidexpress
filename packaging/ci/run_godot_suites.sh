#!/usr/bin/env bash
#
# Runs a subset of Godot headless test suites that must stay green.
# Gated suites: workflow, ui, sketch, sketch tools, print
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

echo "Running gated Godot suites (workflow, ui, sketch, sketch tools, print, rung01 e2e)"
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_workflow_tests.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_ui_tests.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_sketch_tests.gd
# Measured headless on this tree: ~2s, 141 checks. It was red on main and
# absent from this list, so make test-godot stopped here while CI stayed green.
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_sketch_tools_tests.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_print_tests.gd
# Headless wrench walk plus the two suites that regressed with it.
# Measured on lavapipe: the three together finish in under a minute
# (wrench ~35s, cut ~3s, status ~1s), well under the 5 minute CI budget.
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_wrench.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_sx036_esc.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_replan15_shaftbadges.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_replan6_cut.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_replan12_status.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_n12_extrude.gd
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --script tests/run_rung01_sx036_rail.gd

echo "Gated suites completed."

