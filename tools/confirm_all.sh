#!/usr/bin/env bash
# One pass: build, kernel, python checks, headless Godot suites, three walks.
# Each headless command is written once under SX_CONFIRM_DIR. The walks read
# those logs (A15 / A25 / A26) instead of launching the suite again.
#
# Prints a compact summary on stdout. Command noise stays in the log dir.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# shellcheck source=/dev/null
source "${ROOT}/packaging/occt.version"
OCCT_PREFIX="${OCCT_PREFIX:-/opt/occt-${OCCT_VERSION}}"
export OCCT_PREFIX
export CMAKE_PREFIX_PATH="${OCCT_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export LD_LIBRARY_PATH="${OCCT_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

OUT="${SX_CONFIRM_DIR:-${ROOT}/build/confirm}"
mkdir -p "${OUT}"
export SX_CONFIRM_DIR="${OUT}"

JOBS="${SX_JOBS:-$(nproc)}"
GODOT="${ROOT}/tools/godot/godot"

record() {
  local name="$1"
  shift
  set +e
  "$@" >"${OUT}/${name}.log" 2>"${OUT}/${name}.err"
  local rc=$?
  set -e
  if [[ -s "${OUT}/${name}.err" ]]; then
    printf '\n' >>"${OUT}/${name}.log"
    cat "${OUT}/${name}.err" >>"${OUT}/${name}.log"
  fi
  rm -f "${OUT}/${name}.err"
  printf '%s\n' "${rc}" >"${OUT}/${name}.rc"
}

echo "confirm: build" >&2
record build make build
if [[ "$(cat "${OUT}/build.rc")" != "0" ]]; then
  echo "BUILD FAIL (see ${OUT}/build.log)"
  exit 1
fi

echo "confirm: import" >&2
record import "${GODOT}" --headless --path game --import

echo "confirm: kernel, lints, godot suites" >&2
record kernel python3 -c '
import sys
from pathlib import Path
sys.path.insert(0, "tools")
from walk.gates import run_kernel
r = run_kernel(Path("."))
sys.stdout.write(r.stdout or "")
sys.stderr.write(r.stderr or "")
raise SystemExit(r.returncode)
' &
record lint_suites python3 tools/lint_suites.py &
record lint_e2e python3 tools/lint_rung01_e2e.py &
record unit_rung02 python3 tools/test_check_rung02.py &
record unit_rung03 python3 tools/test_check_rung03.py &
record registry python3 tools/test_walk_registry.py &
record godot env GODOT_BIN="${GODOT}" packaging/ci/run_suites.sh --tier full --keep-going --jobs "${JOBS}" &
wait

start_xvfb() {
  local display="$1"
  local n="${display#:}"
  if [[ -S "/tmp/.X11-unix/X${n}" ]]; then
    return 0
  fi
  Xvfb "${display}" -screen 0 1280x800x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
  echo $! >"${OUT}/xvfb-${n}.pid"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S "/tmp/.X11-unix/X${n}" ]] && return 0
    sleep 0.2
  done
  echo "Xvfb ${display} did not start" >&2
  return 1
}

echo "confirm: walks" >&2
start_xvfb :21
start_xvfb :22
start_xvfb :23

SX_AUTOMATION=1 python3 tools/walk_rung01.py --a15 --port 47321 --display :21 \
  --resolution 1280x800 --out "${OUT}/walk1" >"${OUT}/walk1.stdout" 2>&1 &
p1=$!
SX_AUTOMATION=1 python3 tools/walk_rung02.py --a15 --port 47322 --display :22 \
  --resolution 1280x800 --out "${OUT}/walk2" >"${OUT}/walk2.stdout" 2>&1 &
p2=$!
SX_AUTOMATION=1 python3 tools/walk_rung03.py --a15 --port 47323 --display :23 \
  --resolution 1280x800 --out "${OUT}/walk3" >"${OUT}/walk3.stdout" 2>&1 &
p3=$!
set +e
wait "${p1}"; echo $? >"${OUT}/walk1.rc"
wait "${p2}"; echo $? >"${OUT}/walk2.rc"
wait "${p3}"; echo $? >"${OUT}/walk3.rc"
set -e

if [[ -f "${OUT}/xvfb-21.pid" ]]; then kill "$(cat "${OUT}/xvfb-21.pid")" 2>/dev/null || true; fi
if [[ -f "${OUT}/xvfb-22.pid" ]]; then kill "$(cat "${OUT}/xvfb-22.pid")" 2>/dev/null || true; fi
if [[ -f "${OUT}/xvfb-23.pid" ]]; then kill "$(cat "${OUT}/xvfb-23.pid")" 2>/dev/null || true; fi

python3 - "${OUT}" <<'PY'
import sys
from pathlib import Path

out = Path(sys.argv[1])

def rc(name):
    p = out / f"{name}.rc"
    if not p.is_file():
        return "missing"
    return p.read_text().strip() or "missing"

def last_match(name, needle):
    p = out / f"{name}.log"
    if not p.is_file():
        return "missing"
    hit = ""
    for line in p.read_text(errors="replace").splitlines():
        if needle in line:
            hit = line.strip()
    return hit or "missing"

def tail_line(name):
    p = out / f"{name}.log"
    if not p.is_file():
        return "missing"
    lines = [ln.strip() for ln in p.read_text(errors="replace").splitlines() if ln.strip()]
    return lines[-1] if lines else "empty"

def summary(walk):
    p = out / walk / "SUMMARY.txt"
    if not p.is_file():
        return "missing"
    line = p.read_text(errors="replace").splitlines()
    return line[0] if line else "empty"

def check_tail(walk, name):
    p = out / walk / name
    if not p.is_file():
        return f"{name}: missing"
    lines = [ln.strip() for ln in p.read_text(errors="replace").splitlines() if ln.strip()]
    return f"{name}: {lines[-1] if lines else 'empty'}"

rows = [
    f"build {rc('build')}",
    f"kernel {rc('kernel')} {tail_line('kernel')}",
    f"lint_suites {rc('lint_suites')} {last_match('lint_suites', 'lint_suites:')}",
    f"lint_e2e {rc('lint_e2e')} {last_match('lint_e2e', 'clean')}",
    f"unit_rung02 {rc('unit_rung02')}",
    f"unit_rung03 {rc('unit_rung03')}",
    f"registry {rc('registry')}",
    f"godot {rc('godot')} {last_match('godot', 'suites:')}",
    f"rung1 {summary('walk1')}",
    check_tail("walk1", "check-blank-blank.txt"),
    check_tail("walk1", "check-wrench-wrench.txt"),
    check_tail("walk1", "check-wrench-wrench-noext.txt"),
    check_tail("walk1", "check-thick-wrench-t14.txt"),
    check_tail("walk1", "check-wrench-wrench-t14.txt"),
    check_tail("walk1", "check-nut-nut.txt"),
    f"rung2 {summary('walk2')}",
    check_tail("walk2", "check-final-final-60.txt"),
    check_tail("walk2", "check-final-final-65.txt"),
    f"rung3 {summary('walk3')}",
    check_tail("walk3", "check-base-base.txt"),
    check_tail("walk3", "check-boss-boss.txt"),
    check_tail("walk3", "check-cut-cut.txt"),
    check_tail("walk3", "check-r5-r5.txt"),
    check_tail("walk3", "check-rounded-rounded.txt"),
    check_tail("walk3", "check-final-final.txt"),
    check_tail("walk3", "check-final-final-reopen.txt"),
]
print("\n".join(rows))
PY
