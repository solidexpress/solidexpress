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

TIER_ARG="full"
LIST=0
ONLY=""
RUN=0
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

# Parse one manifest. Sets SCRIPT, TIER, TIMEOUT, REASON. Echoes errors and returns 2.
parse_manifest() {
  local file="$1"
  local line key val
  SCRIPT=""
  TIER=""
  TIMEOUT="900"
  REASON=""
  local seen_script=0 seen_tier=0 seen_timeout=0 seen_reason=0
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
for f in "${files_sorted[@]}"; do
  SCRIPT=""
  TIER=""
  TIMEOUT=""
  REASON=""
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
if [[ ${#selected_scripts[@]} -gt 0 ]]; then
  for i in "${!selected_scripts[@]}"; do
    script="${selected_scripts[$i]}"
    secs="${selected_timeouts[$i]}"
    set +e
    timeout --foreground "${secs}" "${GODOT_BIN}" --headless --path "${ROOT_DIR}/game" --script "${script}"
    rc=$?
    set -e
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
      if [[ "${KEEP_GOING}" != 1 ]]; then
        break
      fi
    fi
  done
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
