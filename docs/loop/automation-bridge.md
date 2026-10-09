# Driving a checklist walk without screenshots

The sx-041 walk (`docs/loop/rung-01-replan-20.md`) used to be a vision agent: mouse clicks from screenshots, four hours, and mis-clicks whenever the left rail moved. The app now exposes a test-only automation bridge so a script can click a control by identity and read the same state the screen was standing in for.

## Turn the bridge on

The socket is closed unless the environment asks for it. A release build does not listen.

```bash
SX_AUTOMATION=1 SX_INPUT_TRACE=1 SX_AUTOMATION_PORT=47321 \
  tools/godot/godot --path game --resolution 1280x800
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

`tools/walk_rung01.py` launches the app with `SX_AUTOMATION=1` and `SX_INPUT_TRACE=1`, walks the sx-041 rows in order, and judges each row from `state` and the trace log. It writes `WALK_LOG.md` plus `walk_report.json`, saves and exports into `--out`, and runs `tools/check_rung01.py` on those files. A clause that is only a colour or a tint is computed from drawn rects and style fills when that is enough; otherwise it is marked `needs-visual` and one screenshot is taken for it.

```bash
python3 tools/walk_rung01.py --out /tmp/sx-041
python3 tools/walk_rung01.py --rows A8,L4 --out /tmp/sx-041
python3 tools/walk_rung01.py --from N21b --out /tmp/sx-041
python3 tools/walk_rung01.py --from A16 --checkpoint --out /tmp/sx-041
```

`--rows` and `--from` rerun a subset. A full walk reloads the checklist file when the previous chunk did not end in the expected state, and prints `checkpoint-reload <file>`. The files are `blank.sxp` (chunk 2, and the live jaw rebuilt from it for chunk 3), `cut.sxp` (chunk 4), and `wrench-wip.sxp` (chunks 5 and 6). A missing `cut.sxp` or `wrench-wip.sxp` is built through the bridge from the last file that does exist, so a failed save does not skip the slot, fillet, and export rows. `--checkpoint` forces that reload on a `--from` run. `dialog_commit` sets the file dialog's directory and name, presses its OK button, then presses the overwrite confirm's OK button, and waits until the dialog is gone. A row that leaves a file dialog or confirm up fails and the runner cancels it before the next row. Each row checks mode, sketch, body bbox and the finish bar first; a miss is `BLOCKED-by-<row>` instead of a cascade of failures. The runner reports product failures; it does not change them. After the 75 rows, a full walk replays the screenshot-walk sequences as `A8b-variant-walk` and `A9-variant-walk` and records whether part Ctrl+Z leaves `sketch 3` and whether that trim draws `-135°`.

The headless proof that the bridge is real input, not a private API, is `game/tests/run_automation_bridge_tests.gd` (`automation_bridge_tests` in the CI tier): a second Extrude click is `drop:shield`, Enter leaves the Distance field, and the jaw angle label is clicked on its drawn rect and edited to 45.
