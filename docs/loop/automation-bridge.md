# Driving a checklist walk without screenshots

The sx-041 walk (`docs/loop/rung-01-replan-20.md`) used to be a vision agent: mouse clicks from screenshots, four hours, and mis-clicks whenever the left rail moved. The app now exposes a test-only automation bridge so a script can click a control by identity and read the same state the screen was standing in for.

## Turn the bridge on

The socket is closed unless the environment asks for it. The bridge is in the editor build and in release exports. Neither listens unless `SX_AUTOMATION=1`. The listener is **127.0.0.1 only**, so a shipped binary does not accept connections from another machine. That is the gate: an export can be walked when the variable is set, and it stays silent otherwise.

```bash
SX_AUTOMATION=1 SX_INPUT_TRACE=1 SX_AUTOMATION_PORT=47321 \
  tools/godot/godot --path game --resolution 1280x800

# The same variable opens the bridge in a Linux export:
SX_AUTOMATION=1 SX_INPUT_TRACE=1 \
  ./SolidExpress.x86_64 --resolution 1280x800
```

`SX_AUTOMATION_PORT` defaults to **47321**. The listener is **127.0.0.1 only**. Each command is one line of JSON; the reply is one line, and it is sent only after the UI has settled (`wait_idle`: a few rendered frames and no camera tween still running).

Pointer and key commands are real `InputEvent`s. The main window gets `Viewport.push_input` of `InputEventMouseButton`, `InputEventMouseMotion`, and `InputEventKey`. An embedded popup (File, finish-bar menus, dialogs) is clicked by pushing that same event through the parent viewport at the popup's position, which is the path Godot uses to call `Window._input_from_window` before `push_input`. A native popup uses `Input.parse_input_event` with that window's id. Nothing calls menu handlers directly, so focus, the Extrude shield, popups, hover, and `drop:shield` behave as they do for a person.

Stable ids (node meta `sx_auto`) cover the sketch rail (`rail:Circle`, `rail:Jaw`, …), finish-bar fields (`finish:Distance`, `finish:Op`, `finish:Extrude`), the HUD (`hud:Frame`, `hud:View`), menu buttons (`menu:File`), timeline rows and pencils (`timeline:row:sketch 1`, `timeline:pencil:sketch 1`), contour chips, and the file / discard dialogs (`dialog:Name`, `dialog:Ok`, `dialog:DiscardOk`). A click can also name a node path, a sketch-plane millimetre point, a kernel 3D point, an edge or face id, or a drawn dimension label (`dim` text or `dim_id`).

`state` returns one JSON snapshot: status text, focus, armed tool, which rail buttons are lit, visible controls (path, rect, text, disabled), open popups, finish-bar fields, the DOF chip, sketch mode, timeline rows, undo/redo labels, selection, drawn dimension labels (text, rect, visible, occluded), constraint badges, contour tags, camera, and body bounding boxes plus the feature list. `trace` returns `[input-trace]`, `[key-trace]`, `[status-trace]`, `[popup-trace]`, and `[hover-trace]` lines since a cursor. `screenshot` writes a PNG only when a check is visual and the rects cannot answer it.

## Client

`tools/sxdrive.py` is the library and the CLI. It times out, prints the bridge error, and reconnects if the socket drops before the command is sent.

```bash
python3 tools/sxdrive.py click rail:Circle
python3 tools/sxdrive.py state --filter status,dims
python3 tools/sxdrive.py key ctrl+shift+z
python3 tools/sxdrive.py type 22.5 --delay 10
```

## sx-041 runner

`tools/walk_rung01.py` launches the app with `SX_AUTOMATION=1` and `SX_INPUT_TRACE=1`, walks the sx-041 rows in order, and judges each row from `state` and the trace log. `--app path/to/SolidExpress.x86_64` launches that export instead of the Godot editor (working directory is the binary's folder). `--resolution 1920x1200` is the window size passed through; the default is `1280x800`. It writes `WALK_LOG.md` plus `walk_report.json`, saves and exports into `--out`, and runs `tools/check_rung01.py` on those files. A clause that is only a colour or a tint is computed from drawn rects and style fills when that is enough; otherwise it is marked `needs-visual` and one screenshot is taken for it.

```bash
python3 tools/walk_rung01.py --out /tmp/sx-041
python3 tools/walk_rung01.py --rows A8,L4 --out /tmp/sx-041
python3 tools/walk_rung01.py --from N21b --out /tmp/sx-041
python3 tools/walk_rung01.py --from A16 --checkpoint --out /tmp/sx-041
```

`--rows` and `--from` rerun a subset. A full walk reloads the checklist file when the previous chunk did not end in the expected state, and prints `checkpoint-reload <file>`. The files are `blank.sxp` (chunk 2, and the live jaw rebuilt from it for chunk 3), `cut.sxp` (chunk 4), and `wrench-wip.sxp` (chunks 5 and 6). A missing `cut.sxp` or `wrench-wip.sxp` is built through the bridge from the last file that does exist, so a failed save does not skip the slot, fillet, and export rows. `--checkpoint` forces that reload on a `--from` run. `dialog_commit` sets the file dialog's directory and name, presses its OK button, then presses the overwrite confirm's OK button, and waits until the dialog is gone. A row that leaves a file dialog or confirm up fails and the runner cancels it before the next row. Each row checks mode, sketch, body bbox and the finish bar first; a miss is `BLOCKED-by-<row>` instead of a cascade of failures. The runner reports product failures; it does not change them. After the 75 rows, a full walk replays the screenshot-walk sequences as `A8b-variant-walk` and `A9-variant-walk` and records whether part Ctrl+Z leaves `sketch 3` and whether that trim draws `-135°`.

The headless proof that the bridge is real input, not a private API, is `game/tests/run_automation_bridge_tests.gd` (`automation_bridge_tests` in the CI tier): a second Extrude click is `drop:shield`, Enter leaves the Distance field, and the jaw angle label is clicked on its drawn rect and edited to 45.

## sx-042 runner rules (re-PLAN 21)

Statuses that a row judges are the `[status-trace] … kind=result text=…` lines since that row's mark (`Walk.status_since`). The live status label is only for hover hints. Every `click(screen=[x, y])` uses a bridge selector (`target=`, `model=`, `sketch=`, `edge=`, `face=`) or a position taken from `bodies[i].screen` / `project`. The only fixed offsets that remain are inside `jaw_px`, which is derived from the measured head.

**S0** is not a row. It is a clause on every export (A5, A12, N11, A13c, A14), read from bridge `bodies` before the file is written. It requires exactly one body. Wrench exports (A5, A12, N11, A13c) also require a name starting with `extrude` and a bbox of `232.5 ± 0.3` × `45 ± 0.1` × `T ± 0.01` (`T` is 10, or 14 after A13 commits). The nut export (A14) asserts only the body count. A miss is `FAIL runner-gap: stray body <name> (<volume>)`, naming the body and the row that left it, and the checker does not run. Each body record includes `volume` (mm³) from `body_volume`. N4 and N16 assert `bodies` and `timeline` are unchanged by the row.

A clause marked `headless-only` (the 2.5 s hold edge owned by `rung01_replan19_hint`) is listed in the row evidence and is not a PASS. A clause that can only pass is a runner defect.

## Runner rules R1–R10

These replace the screenshot-walker rules for sx-042. `tools/walk_rung01.py` is the walker.

1. **One command, one verdict.** The verdict is `walk_report.json` plus `WALK_LOG.md` plus the `check-*.txt` files in `--out`. A row the runner marks `PASS` is PASS.
2. **`--rows` is a diagnostic.** Verdicts come from the full run, or from `--from <row> --checkpoint`, which reloads `blank.sxp`, `cut.sxp`, `wrench-wip.sxp`, or `wrench-t14.sxp`.
3. **Statuses come from traces.** A clause that reads a status takes the `kind=result` line since the row's mark. The live label is only for a hover hint.
4. **Body guard.** Every export row (A5, A12, N11, A13c, A14) asserts one body of the right size before it writes the file. A miss is `runner-gap`, and the checker does not run.
5. **FAIL / PARTIAL / BLOCKED / runner-gap.** FAIL means a clause failed on a valid state. PARTIAL means a clause could not be evaluated. BLOCKED-by-<row> means the row's starting state is missing. BLOCKED-by-flag means A15 was asked to run the headless tier and `--a15` was not passed. runner-gap means the runner could not do what the row says.
6. **No vacuous clause.** A clause that can only pass is a defect of the runner.
7. **`headless-only` clauses** (the 2.5 s hold in N16 and N8b) are listed as `headless-only` with the suite that owns them. They are not PASS.
8. **Timing.** Waits use the bridge (`wait_idle`, `trace(since=…)`). The only sleeps a row owns are N16's 2.0–4.0 s window and A13d's 0.4 s.
9. **Engine noise.** `already connected`, `nonexistent connection`, `tree_exited`, Vulkan startup, and `status < 0 ERR_CANT_OPEN` are counted and never judged. Every other `[ERROR]` must be absent except the three intended fillet refusals (`limit 1.250`, `regenerate stopped`, `edit sketch: … open loop`).
10. **A15.** With `--a15`, the row runs `lint_rung01_e2e.py`, `lint_suites.py`, and `KEEP_GOING=1 make test-godot`, and asserts `suites: <n> run, 0 failed` with `n ≥ 204` plus the suite floors. Without `--a15` the row is `BLOCKED-by-flag`.
