#!/usr/bin/env bash
# Real-window click probe for rung-1 replan 17 WP3 (Decision 2).
# Launches the app with SX_INPUT_TRACE=1 and tallies dead first clicks.
# Two passes per sequence: xdotool click with no sleep, then mousemove,
# 80 ms, click. 20 trials each. DISPLAY=:1.
#
# A trial is dead when that click produces no [input-trace] line, or the
# line is a drop:* / model-click on a rail coordinate / a canvas click that
# is not sketch-click, sketch-drag, or sketch-box.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${ROOT}/tools/godot/godot"
LOG="${TMPDIR:-/tmp}/sx-input-trace.log"
DISPLAY="${DISPLAY:-:1}"
export DISPLAY
export SX_INPUT_TRACE=1
export LD_LIBRARY_PATH="/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [[ ! -x "$GODOT" ]]; then
  echo "missing $GODOT" >&2
  exit 1
fi

: > "$LOG"
"$GODOT" --path "$ROOT/game" >"$LOG" 2>&1 &
GPID=$!
cleanup() {
  if kill -0 "$GPID" 2>/dev/null; then
    kill "$GPID" 2>/dev/null || true
    wait "$GPID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "probe log $LOG pid $GPID"
WID=""
for _ in $(seq 1 80); do
  WID="$(xdotool search --name SolidExpress 2>/dev/null | head -1 || true)"
  if [[ -n "$WID" ]]; then
    break
  fi
  sleep 0.25
done
if [[ -z "$WID" ]]; then
  echo "no SolidExpress window" >&2
  tail -40 "$LOG" >&2
  exit 1
fi
# Let the first frame map before measuring.
sleep 1.5
eval "$(xdotool getwindowgeometry --shell "$WID")"
echo "window id=$WID pos=${X},${Y} size=${WIDTH}x${HEIGHT}"

# 1280x800 layout (checklist chunk 1 / main.gd left stack).
# Palette Sketch is the first rail button under the menu.
# Sketch-rail rows are 30 px: Exit, Select, Line, Arc, Circle, Rect, Jaw.
# UI is pixel-anchored in the client, not stretched from 1280×800.
# Arguments are client pixels; the window origin maps them onto the screen.
scale_x() { echo $(( X + $1 )); }
scale_y() { echo $(( Y + $1 )); }

# Content origin inside the window frame. Title-bar offset is applied when
# the measured height is the frame (larger than the viewport request).
# Measured on the 1600×900 client (left stack under the menu, 30 px rows).
# Palette Sketch centre, then canvas clear of the rail and the finish bar.
SX=$(scale_x 60)
SY=$(scale_y 36)
CANVAS_X=$(scale_x 900)
CANVAS_Y=$(scale_y 500)
# Sketch rail after Exit + separator: Select, Line, Arc, Circle, Rect, Jaw.
JAW_X=$(scale_x 70)
JAW_Y=$(scale_y 216)
CIRCLE_X=$(scale_x 70)
CIRCLE_Y=$(scale_y 154)
SELECT_X=$(scale_x 70)
SELECT_Y=$(scale_y 62)
LINE_X=$(scale_x 70)
LINE_Y=$(scale_y 92)

miss() {
  echo "coordinate miss: $1 at $2,$3 — stopping" >&2
  echo "last trace lines:" >&2
  grep '\[input-trace\]' "$LOG" | tail -8 >&2 || true
  exit 2
}

# Newest trace line at or after byte offset, or empty.
trace_since() {
  local off="$1"
  tail -c +"$((off + 1))" "$LOG" | grep '\[input-trace\]' | tail -1 || true
}

log_size() { wc -c < "$LOG" | tr -d ' '; }

# One click. mode=fast (no sleep) or slow (80 ms between move and click).
do_click() {
  local mode="$1" cx="$2" cy="$3"
  local off line
  off="$(log_size)"
  if [[ "$mode" == "fast" ]]; then
    xdotool mousemove "$cx" "$cy" click 1
  else
    xdotool mousemove "$cx" "$cy"
    sleep 0.08
    xdotool click 1
  fi
  # low_processor_mode may flush the print a frame later
  sleep 0.15
  line="$(trace_since "$off")"
  if [[ -z "$line" ]]; then
    echo ""
  else
    # [input-trace] press (x,y) <disposition>
    echo "$line" | sed -n 's/.*press ([0-9]*,[0-9]*) //p'
  fi
}

key_escape() {
  xdotool key Escape
  sleep 0.12
}

# Dead when the disposition is missing, a drop, or not a sketch gesture
# for a canvas click. Rail clicks are dead when stolen as model-click or
# sketch-click (the button never saw them) or when the line is missing
# on the fast pass only if the slow pass also misses — counted per trial
# by the caller via is_dead.
is_dead() {
  local kind="$1" disp="$2"
  if [[ -z "$disp" ]]; then
    echo 1
    return
  fi
  case "$kind" in
    rail)
      case "$disp" in
        drop:*) echo 0 ;;
        model-click|sketch-click:*|sketch-drag:*|sketch-box:*) echo 1 ;;
        *) echo 1 ;;
      esac
      ;;
    canvas)
      case "$disp" in
        sketch-click:*|sketch-drag:*|sketch-box:*) echo 0 ;;
        *) echo 1 ;;
      esac
      ;;
    *)
      echo 1
      ;;
  esac
}

run_pass() {
  local mode="$1"
  local seq dead disp i
  echo "=== pass $mode ==="
  # Focus the window once (not a trial).
  xdotool windowactivate "$WID" || true
  sleep 0.3

  # Sequence 1 — rail Sketch, then Escape. Part mode.
  seq="sketch"
  dead=0
  for i in $(seq 1 20); do
    disp="$(do_click "$mode" "$SX" "$SY")"
    echo "trial $i: ${disp:-<none>}"
    if [[ "$(is_dead rail "$disp")" == 1 ]]; then
      dead=$((dead + 1))
    fi
    key_escape
  done
  echo "$seq $dead/20"
  echo "TALLY $mode $seq $dead/20"

  # Enter a sketch so Jaw / Circle / Select exist. One ground click.
  disp="$(do_click "$mode" "$SX" "$SY")"
  echo "setup sketch-arm: ${disp:-<none>}"
  if [[ "$disp" == model-click* || "$disp" == sketch-click* ]]; then
    miss "rail Sketch" "$SX" "$SY"
  fi
  disp="$(do_click "$mode" "$CANVAS_X" "$CANVAS_Y")"
  echo "setup ground: ${disp:-<none>}"
  sleep 0.4

  # Sequence 2 — rail Jaw, canvas click.
  seq="jaw"
  dead=0
  for i in $(seq 1 20); do
    disp="$(do_click "$mode" "$JAW_X" "$JAW_Y")"
    local_rail="$disp"
    cdisp="$(do_click "$mode" "$CANVAS_X" "$CANVAS_Y")"
    echo "trial $i: rail=${local_rail:-<none>} canvas=${cdisp:-<none>}"
    if [[ "$(is_dead rail "$local_rail")" == 1 || "$(is_dead canvas "$cdisp")" == 1 ]]; then
      # A traced model-click on the rail pixel means the coordinate missed the button.
      if [[ "$i" == 1 && "$local_rail" == model-click ]]; then
        miss "rail Jaw" "$JAW_X" "$JAW_Y"
      fi
      dead=$((dead + 1))
    fi
    key_escape
    key_escape
  done
  echo "$seq $dead/20"
  echo "TALLY $mode $seq $dead/20"

  # Re-enter if Esc Esc left the sketch.
  disp="$(do_click "$mode" "$SX" "$SY")"
  echo "setup rearm: ${disp:-<none>}"
  disp="$(do_click "$mode" "$CANVAS_X" "$CANVAS_Y")"
  echo "setup reground: ${disp:-<none>}"
  sleep 0.3

  # Sequence 3 — rail Circle, canvas click.
  seq="circle"
  dead=0
  for i in $(seq 1 20); do
    disp="$(do_click "$mode" "$CIRCLE_X" "$CIRCLE_Y")"
    local_rail="$disp"
    cdisp="$(do_click "$mode" "$CANVAS_X" "$CANVAS_Y")"
    echo "trial $i: rail=${local_rail:-<none>} canvas=${cdisp:-<none>}"
    if [[ "$(is_dead rail "$local_rail")" == 1 || "$(is_dead canvas "$cdisp")" == 1 ]]; then
      if [[ "$i" == 1 && "$local_rail" == model-click ]]; then
        miss "rail Circle" "$CIRCLE_X" "$CIRCLE_Y"
      fi
      dead=$((dead + 1))
    fi
    key_escape
  done
  echo "$seq $dead/20"
  echo "TALLY $mode $seq $dead/20"

  # A line for sequence 4: Line tool, two canvas clicks.
  do_click "$mode" "$LINE_X" "$LINE_Y" >/dev/null
  do_click "$mode" "$(scale_x 500)" "$(scale_y 450)" >/dev/null
  do_click "$mode" "$(scale_x 900)" "$(scale_y 450)" >/dev/null
  sleep 0.2

  # Sequence 4 — rail Select, click on the line (its screen centre).
  seq="select"
  dead=0
  local line_x line_y
  line_x="$(scale_x 700)"
  line_y="$(scale_y 450)"
  for i in $(seq 1 20); do
    disp="$(do_click "$mode" "$SELECT_X" "$SELECT_Y")"
    local_rail="$disp"
    cdisp="$(do_click "$mode" "$line_x" "$line_y")"
    echo "trial $i: rail=${local_rail:-<none>} canvas=${cdisp:-<none>}"
    if [[ "$(is_dead rail "$local_rail")" == 1 || "$(is_dead canvas "$cdisp")" == 1 ]]; then
      if [[ "$i" == 1 && "$local_rail" == model-click ]]; then
        miss "rail Select" "$SELECT_X" "$SELECT_Y"
      fi
      dead=$((dead + 1))
    fi
    key_escape
  done
  echo "$seq $dead/20"
  echo "TALLY $mode $seq $dead/20"
}

echo "coords sketch=$SX,$SY canvas=$CANVAS_X,$CANVAS_Y jaw=$JAW_X,$JAW_Y circle=$CIRCLE_X,$CIRCLE_Y select=$SELECT_X,$SELECT_Y"
run_pass fast
# Second pass starts from whatever the first left behind. Esc a few times,
# then File is not required; the sequences re-arm Sketch themselves.
key_escape
key_escape
key_escape
run_pass slow
echo "probe done"
