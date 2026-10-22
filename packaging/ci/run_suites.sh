#!/usr/bin/env bash
# Run Godot headless suites declared in packaging/ci/suites.d/*.suite.
#
#   --tier ci|full|known-red
#                    ci = tier ci only; full = tier ci and tier full (default);
#                    known-red = tier known-red only (listed, not run, unless
#                    --run)
#   --run            with --tier known-red, run those suites (exit 1 only if
#                    one is now green)
#   --keep-going     do not stop at the first failure (or KEEP_GOING=1)
#   --only <glob>    limit to suites whose script, script basename, or
#                    manifest filename matches the shell glob
#   --list           print the script paths that would run, one per line
#   --jobs <n>       run up to n suites at once (default: nproc, or SX_JOBS).
#                    Suites are headless with the dummy renderer. Pixel checks
#                    stay on the walk displays.
#
# Unknown keys, a missing script, or a bad tier exit 2.
# A failing suite exits 1 after: suites: <run> run, <failed> failed
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SUITES_DIR="${SX_SUITES_DIR:-${ROOT_DIR}/packaging/ci/suites.d}"
if [[ "${SUITES_DIR}" != /* ]]; then
  SUITES_DIR="${ROOT_DIR}/${SUITES_DIR}"
fi

GODOT_BIN="${GODOT_BIN:-tools/godot/godot}"
if [[ "${GODOT_BIN}" != /* ]]; then
  GODOT_BIN="${ROOT_DIR}/${GODOT_BIN}"
fi
GAME_DIR="${ROOT_DIR}/game"

TIER_ARG="full"
LIST=0
ONLY=""
RUN=0
JOBS="${SX_JOBS:-$(nproc)}"
case "${KEEP_GOING:-0}" in
  1|true|yes) KEEP_GOING=1 ;;
  *) KEEP_GOING=0 ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER_ARG="${2:-}"
      shift 2
      ;;
    --keep-going)
      KEEP_GOING=1
      shift
      ;;
    --only)
      ONLY="${2:-}"
      if [[ -z "${ONLY}" ]]; then
        echo "missing value for --only" >&2
        exit 2
      fi
      shift 2
      ;;
    --list)
      LIST=1
      shift
      ;;
    --run)
      RUN=1
      shift
      ;;
    --jobs)
      JOBS="${2:-}"
      if [[ -z "${JOBS}" ]] || ! [[ "${JOBS}" =~ ^[0-9]+$ ]] || [[ "${JOBS}" -lt 1 ]]; then
        echo "bad jobs: ${JOBS:-<empty>}" >&2
        exit 2
      fi
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "${TIER_ARG}" in
  ci|full|known-red) ;;
  *)
    echo "bad tier: ${TIER_ARG}" >&2
    exit 2
    ;;
esac

if [[ ! -d "${SUITES_DIR}" ]]; then
  echo "missing suites dir: ${SUITES_DIR}" >&2
  exit 2
fi

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

# Parse one manifest. Sets SCRIPT, TIER, TIMEOUT, REASON, RENDER. Echoes errors and returns 2.
parse_manifest() {
  local file="$1"
  local line key val
  SCRIPT=""
  TIER=""
  TIMEOUT="900"
  REASON=""
  RENDER="dummy"
  local seen_script=0 seen_tier=0 seen_timeout=0 seen_reason=0 seen_render=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    line="${line%%#*}"
    line="$(trim "${line}")"
    [[ -z "${line}" ]] && continue
    if [[ "${line}" != *=* ]]; then
      echo "bad line in $(basename "${file}"): ${line}" >&2
      return 2
    fi
    key="$(trim "${line%%=*}")"
    val="$(trim "${line#*=}")"
    case "${key}" in
      script)
        if [[ "${seen_script}" -eq 1 ]]; then
          echo "duplicate script key in $(basename "${file}")" >&2
          return 2
        fi
        seen_script=1
        SCRIPT="${val}"
        ;;
      tier)
        if [[ "${seen_tier}" -eq 1 ]]; then
          echo "duplicate tier key in $(basename "${file}")" >&2
          return 2
        fi
        seen_tier=1
        TIER="${val}"
        ;;
      timeout)
        if [[ "${seen_timeout}" -eq 1 ]]; then
          echo "duplicate timeout key in $(basename "${file}")" >&2
          return 2
        fi
        seen_timeout=1
        TIMEOUT="${val}"
        ;;
      reason)
        if [[ "${seen_reason}" -eq 1 ]]; then
          echo "duplicate reason key in $(basename "${file}")" >&2
          return 2
        fi
        seen_reason=1
        REASON="${val}"
        ;;
      render)
        if [[ "${seen_render}" -eq 1 ]]; then
          echo "duplicate render key in $(basename "${file}")" >&2
          return 2
        fi
        seen_render=1
        RENDER="${val}"
        ;;
      *)
        echo "unknown key ${key} in $(basename "${file}")" >&2
        return 2
        ;;
    esac
  done < "${file}"
  if [[ -z "${SCRIPT}" ]]; then
    echo "missing script in $(basename "${file}")" >&2
    return 2
  fi
  if [[ "${TIER}" != ci && "${TIER}" != full && "${TIER}" != known-red ]]; then
    echo "bad tier ${TIER:-<empty>} in $(basename "${file}")" >&2
    return 2
  fi
  if [[ "${TIER}" == known-red ]]; then
    if [[ -z "${REASON}" ]]; then
      echo "missing reason in $(basename "${file}")" >&2
      return 2
    fi
    if ! [[ "${REASON}" =~ ^(env|stale-feature|product):\ .+ ]]; then
      echo "bad reason class in $(basename "${file}")" >&2
      return 2
    fi
  elif [[ -n "${REASON}" ]]; then
    echo "reason only allowed on known-red in $(basename "${file}")" >&2
    return 2
  fi
  if ! [[ "${TIMEOUT}" =~ ^[0-9]+$ ]] || [[ "${TIMEOUT}" -lt 1 ]]; then
    echo "bad timeout ${TIMEOUT} in $(basename "${file}")" >&2
    return 2
  fi
  if [[ "${RENDER}" != dummy && "${RENDER}" != viewport ]]; then
    echo "bad render ${RENDER:-<empty>} in $(basename "${file}")" >&2
    return 2
  fi
  if [[ ! -f "${ROOT_DIR}/game/${SCRIPT}" ]]; then
    echo "missing script file ${SCRIPT}" >&2
    return 2
  fi
  return 0
}

files_sorted=()
while IFS= read -r base; do
  [[ -n "${base}" ]] || continue
  files_sorted+=("${SUITES_DIR}/${base}")
done < <(find "${SUITES_DIR}" -maxdepth 1 -name '*.suite' -printf '%f\n' | LC_ALL=C sort)

selected_scripts=()
selected_timeouts=()
selected_reasons=()
selected_renders=()
for f in "${files_sorted[@]}"; do
  SCRIPT=""
  TIER=""
  TIMEOUT=""
  REASON=""
  RENDER="dummy"
  parse_manifest "${f}" || exit 2
  if [[ "${TIER_ARG}" == ci && "${TIER}" != ci ]]; then
    continue
  fi
  if [[ "${TIER_ARG}" == full && "${TIER}" == known-red ]]; then
    continue
  fi
  if [[ "${TIER_ARG}" == known-red && "${TIER}" != known-red ]]; then
    continue
  fi
  if [[ -n "${ONLY}" ]]; then
    base_script="$(basename "${SCRIPT}")"
    base_file="$(basename "${f}")"
    if [[ "${SCRIPT}" != ${ONLY} && "${base_script}" != ${ONLY} && "${base_file}" != ${ONLY} ]]; then
      continue
    fi
  fi
  selected_scripts+=("${SCRIPT}")
  selected_timeouts+=("${TIMEOUT}")
  selected_reasons+=("${REASON}")
  selected_renders+=("${RENDER}")
done

if [[ "${LIST}" -eq 1 ]]; then
  if [[ ${#selected_scripts[@]} -gt 0 ]]; then
    printf '%s\n' "${selected_scripts[@]}"
  fi
  exit 0
fi

if [[ "${TIER_ARG}" == known-red && "${RUN}" -eq 0 ]]; then
  if [[ ${#selected_scripts[@]} -gt 0 ]]; then
    for i in "${!selected_scripts[@]}"; do
      printf '%s — %s\n' "${selected_scripts[$i]}" "${selected_reasons[$i]}"
    done
  fi
  echo "suites: ${#selected_scripts[@]} known-red"
  exit 0
fi

if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "Missing Godot binary at ${GODOT_BIN}. Run packaging/ci/fetch_godot.sh first." >&2
  exit 2
fi

run=0
failed=0
failed_names=()
# Headless object-model / bridge suites never open a window. The dummy
# renderer skips Vulkan. render=viewport (parked for pixel suites) drops
# --rendering-driver dummy and keeps --headless.
#
# Each suite gets its own copy of game/ (including .godot) plus HOME,
# XDG_* and TMPDIR. Sharing game/.godot leaked film_spanner C-pad state
# after film_hexkey even with a unique HOME; Mesa/Godot caches in the
# real ~/.cache were the leftover shared path.
godot_argv_for_render() {
  local mode="$1"
  local proj="$2"
  if [[ "${mode}" == viewport ]]; then
    printf '%s\n' --headless --path "${proj}"
  else
    printf '%s\n' --headless --rendering-driver dummy --path "${proj}"
  fi
}

clone_game_project() {
  local dest="$1"
  mkdir -p "$(dirname "${dest}")"
  if cp -a --reflink=auto "${GAME_DIR}" "${dest}" 2>/dev/null; then
    return 0
  fi
  cp -a "${GAME_DIR}" "${dest}"
}
# Each suite gets its own HOME (below), which would hide pip --user packages
# such as numpy from the python3 checkers. Pin the user site to the real one.
if [[ -z "${PYTHONUSERBASE:-}" ]]; then
  PYTHONUSERBASE="$(python3 -m site --user-base 2>/dev/null || true)"
fi
[[ -n "${PYTHONUSERBASE:-}" ]] && export PYTHONUSERBASE
if [[ ${#selected_scripts[@]} -gt 0 ]]; then
  work="$(mktemp -d)"
  slot=0
  pids=()
  for i in "${!selected_scripts[@]}"; do
    script="${selected_scripts[$i]}"
    secs="${selected_timeouts[$i]}"
    log="${work}/${i}.log"
    rcfile="${work}/${i}.rc"
    (
      set +e
      # user:// is per process so parallel suites do not share autosaves.
      # Clone game/ (with .godot) under a fake repo root and symlink tools/
      # so SxChecker can still reach tools/check_*.py (res:// parent + tools/).
      jobhome="${work}/home-${i}"
      jobroot="${work}/proj-${i}"
      jobproj="${jobroot}/game"
      mkdir -p "${jobhome}/.local/share" "${jobhome}/.config" "${jobhome}/.cache" \
        "${jobhome}/.local/state" "${jobroot}" "${work}/tmp-${i}"
      clone_game_project "${jobproj}"
      ln -sfn "${ROOT_DIR}/tools" "${jobroot}/tools"
      mapfile -t GODOT_RUN < <(godot_argv_for_render "${selected_renders[$i]}" "${jobproj}")
      HOME="${jobhome}" \
        XDG_DATA_HOME="${jobhome}/.local/share" \
        XDG_CONFIG_HOME="${jobhome}/.config" \
        XDG_CACHE_HOME="${jobhome}/.cache" \
        XDG_STATE_HOME="${jobhome}/.local/state" \
        TMPDIR="${work}/tmp-${i}" \
        MESA_SHADER_CACHE_DIR="${jobhome}/.cache/mesa" \
        timeout --foreground "${secs}" "${GODOT_BIN}" "${GODOT_RUN[@]}" --script "${script}" >"${log}" 2>&1
      echo $? >"${rcfile}"
      rm -rf "${jobproj}"
    ) &
    pids+=($!)
    slot=$((slot + 1))
    if [[ "${slot}" -ge "${JOBS}" ]]; then
      wait "${pids[0]}" || true
      if [[ "${#pids[@]}" -le 1 ]]; then
        pids=()
      else
        pids=("${pids[@]:1}")
      fi
      slot=$((slot - 1))
    fi
  done
  if [[ "${#pids[@]}" -gt 0 ]]; then
    for pid in "${pids[@]}"; do
      wait "${pid}" || true
    done
  fi
  stop_early=0
  for i in "${!selected_scripts[@]}"; do
    if [[ "${stop_early}" -eq 1 ]]; then
      break
    fi
    script="${selected_scripts[$i]}"
    secs="${selected_timeouts[$i]}"
    rcfile="${work}/${i}.rc"
    log="${work}/${i}.log"
    if [[ ! -f "${rcfile}" ]]; then
      continue
    fi
    rc="$(cat "${rcfile}")"
    # Full script output stays in order so walk floors can see each banner.
    if [[ -s "${log}" ]]; then
      cat "${log}"
    fi
    run=$((run + 1))
    if [[ "${TIER_ARG}" == known-red && "${RUN}" -eq 1 ]]; then
      if [[ "${rc}" -eq 0 ]]; then
        echo "NOW GREEN: ${script} (re-tier it)"
        failed=$((failed + 1))
      else
        if [[ "${rc}" -eq 124 ]]; then
          echo "timeout ${secs}s: ${script}" >&2
        fi
        echo "still red: ${script}"
      fi
    elif [[ "${rc}" -ne 0 ]]; then
      if [[ "${rc}" -eq 124 ]]; then
        echo "timeout ${secs}s: ${script}" >&2
      fi
      failed=$((failed + 1))
      failed_names+=("${script}")
      if [[ -s "${log}" ]]; then
        tail -n 20 "${log}" >&2
      fi
      if [[ "${KEEP_GOING}" != 1 ]]; then
        stop_early=1
      fi
    fi
  done
  rm -rf "${work}"
fi

if [[ ${#failed_names[@]} -gt 0 ]]; then
  printf '%s\n' "${failed_names[@]}"
fi
echo "suites: ${run} run, ${failed} failed"
if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
if [[ "${TIER_ARG}" == ci ]]; then
  echo "Gated suites completed."
fi
exit 0
