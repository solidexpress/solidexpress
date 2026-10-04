# Rung 1 replan 4 — replace the number, extrude 7.5, stay alive in the file dialog

Status: plan only. No product code in this change.

Baseline: `main` at `f2770220` (merge of #75). Replan 3 is [`rung-01-replan-3.md`](rung-01-replan-3.md) (WP1–WP7, PRs #68–#75, all merged). The sx-024 critique of local OCCT 8.0.1 build sha256 `52d337f47db6c0ab9c71f36d3f51af06969ecc3634d6f8fc6c52c68e9be068e5` scored **4/10** and failed rung 1. Symptom list: [`rung-01-leftovers-sx024.md`](rung-01-leftovers-sx024.md). This replan names the root cause of each leftover at `f2770220`, the fix, and an acceptance check a person can perform with the mouse and the keyboard at 1280×800.

BUILD agents execute one WP each, on grok-4.6 with effort high and fast off. Packages do not edit the same files. WP1, WP2, and WP3 merge in any order. WP4 merges last.

## Goal

A person using only the GUI, at **1280×800**, follows the UBC ELEC391 handout. Replan 3 already states the nut, the wrench, and the three checker commands. Those commands are unchanged. Do not edit `tools/check_rung01.py`.

What sx-024 still blocks, and what this replan has to make true on a real mouse and keyboard:

- Second numeric entry in one sketch replaces the previous text. Circle radius `10` then `22.5` produces Ø20 and Ø45. The dim blank does not become `2.522.5` or `2.522.522.5`.
- Typing `7.5` in the finish-bar Distance field, then Extrude, builds Blind 7.5 on that first Extrude. No Timeline edit. Nut checker 7/7, Z = 7.5 ± 0.2.
- File → Export 3MF and File → Save As: type a path, Cancel, and Save. The process stays running. A successful export still writes the 3MF and the status still starts with `Exported 3MF → `.
- Headless coverage drives that same click-then-type sequence. A green `280/0` that never clicks the field the way X11 does is not a pass.

Rung 1 is done when one GUI critique (sx-025) follows the checklist below, the three checker commands pass on files the export dialog wrote, `run_rung01_wrench.gd` prints 0 failures on this OCCT 8.0.1 build, and the score is at least 9.

## Situation

sx-024, desktop 1280×800, Godot on llvmpipe, tip `f2770220`, three real mouse-and-keyboard walks. Overall **4/10**, rung 1 **FAIL**. The nut is makeable. The wrench cannot get past its first sketch.

| What replan 3 fixed in the GUI | What sx-024 still got |
|---|---|
| Nut polygon AF 20, bore Ø10, closed mesh, export `nut.3mf`. Checker **7/7** (23.094 × 20 × 7.5 after a Timeline rescue). | Finish-bar Distance typed `7.5` still extruded **Blind 20.0000 mm**. Z became 7.5 only after a Timeline Distance edit. WP1/#72 did not stick for a real key. |
| Chips under the finish bar. Empty-sketch Exit confirms. Camera keys do not eat sketch digits. | After the first dim entry, the next keystrokes appended. The blank showed `2.522.522.5` / `2.522.5`. Second circle refused 22.5 and landed **r=2.0000 (Ø4)**. Reproduced on two walks. Wrench B1.4–B5 never started. |
| Headless walk `run_rung01_wrench.gd` reports **280/0**. | The real GUI fails on the second dim entry and on typed Distance. The 280/0 run is not that GUI. |
| Export of the nut returned and the checker passed. | On the retry walk, SolidExpress **exited** (PID gone) during Export/Save dialog interaction. No `wrench.3mf`. |

Do not re-open the rows in "Out of scope" unless a new GUI walk shows they regressed. Do not recritique hash `f2770220` / `52d337f4`. The next critique is a build that contains WP4.

## Why the second radius appends

The dim blank and the Distance blank are both `SpinBox` line edits in `SketchContextChrome._build_finish_bar` (`DimLineEdit`, `DistanceLineEdit`). `select_all_on_focus` runs when focus is gained. A real left click then places a caret and clears that selection. The code tries to win the race with a deferred `select_all`.

Distance schedules a second select on the next frame and cancels it with `_distance_select_gen` when `text_changed` fires, so a late select cannot eat the second digit (`_on_distance_edit_gui_input`, `_select_distance_all_next_frame`, `_on_distance_text_changed`). The dim blank does not. `_on_dim_edit_gui_input` only does `call_deferred("select_all")`. `_on_dim_focus_entered` skips `select_all` while the mouse button is down.

`run_rung01_wrench.gd` `_click_control` pushes mouse-down, **awaits a frame**, then pushes mouse-up. That yield lets the deferred `select_all` land before the caret. The test's second click then sees a full selection, types through `push_input`, and passes. An X11 click delivers press and release in one burst, the caret wins, and the next character inserts into the text that is already there.

That existing text is the rubber-band. `set_dim_value` writes `preview_distance_changed` into the spin whenever `_dim_editing` is false. After the first circle commits, `release_dim_focus` clears `_dim_editing`, the next circle's pointer writes a short distance (the walks showed a leading `2.5`), and typing `22.5` into an unselected field appends. The blank becomes `2.522.5`, and a second try becomes `2.522.522.5`.

`_parse_dim_text` requires `is_valid_float` after prefix/suffix stripping, so `2.522.5` emits `dim_rejected` and does not emit `dim_submitted`. The circle that appears is whatever the pointer or the last parsed prefix committed. sx-024 recorded `Circle r=2.0000 (Ø4.0000)`.

`focus_dim_for_typing` is the unfocused-seed path. It writes the seed and then `deselect()` plus `deselect.call_deferred()`, caret at the end. The wrench walk does not use it for the second circle: `_type_dim` clicks the blank first, so `_preview_length_typed` stays empty and the LineEdit takes the keys. Fixing only the unfocused seed leaves the clicked field appending.

The same insert happens on any later focused numeric line that only select-alls on a deferred frame. The in-sketch dimension popup (`ViewportInteraction._dim_edit_line`, `_on_dim_edit_line_gui_input`) is that pattern. Smart Dimension was not reached (A5 skipped, B1.4 blocked), so it has to grow the same first-key replace before the wrench walk types `200`.

## Why typed 7.5 still extrudes 20

`extrude_distance`, `_commit_distance_text`, and `_emit_finish_requested` already parse the Distance line and send that number. `_on_sketch_finish` prints `Extrude Blind %.4f mm` from the number it was given. sx-024's status was `Extrude Blind 20.0000 mm`, so the line that Extrude parsed was 20. The feature was created at 20. The Timeline Distance edit is a different line edit (`property_panel.gd`) and did change the param to 7.5. The finish bar never sent 7.5.

Distance is constructed at `value = 20`, `step = 0.5`, suffix `mm`. A same-burst click leaves the caret in the formatted default (`20` / `20.0`). Typing `7.5` inserts and produces a string such as `20.07.5`. `_parse_spin_text` rejects it (`is_valid_float` is false), so `_on_distance_text_changed` leaves `.value` at 20. On focus exit, Godot's SpinBox `apply` uses `to_float`, which reads the leading `20.07` and snaps to step 0.5, which is **20**. `_restore_rejected_distance` also writes `_distance_origin`, captured as 20 in `_on_distance_focus_entered`. The Extrude button then parses a line that says 20 and the success sentence prints 20.0000. A Timeline edit is the only way the solid becomes 7.5.

The headless nut does not take this click. `_type_unfocused_distance` releases focus and `push_input`s `7`, `.`, `5` with no line edit focused. `_try_consume_distance_length_key` calls `focus_distance_for_typing`, which assigns the whole seed. That passes while a click on Distance followed by the same keys does not. `_type_distance` does click, but it awaits a frame between press and release, so its select-all sticks.

`_rail_finish_extrude` already refuses a line that fails `distance_line_parses`. Do not change that gate. The finish-bar button and the rail button both have to send 7.5 once the line actually contains 7.5. `main.gd` does not need a second parser.

## Why the process dies in the file dialog

`file_dialog` is a `FileDialog` (`Window`) created in `Main._ready` and shown with `popup_centered()` from `_show_file_dialog`. The project never sets `gui/embed_subwindows` and never sets `use_native_dialog`. On X11 this dialog is a child window.

`Main._ready` calls `set_auto_accept_quit(false)`. `Main._notification` still handles `NOTIFICATION_WM_CLOSE_REQUEST` by `_confirm_discard(func() -> void: get_tree().quit())`. When the document is not dirty, `_confirm_discard` runs that quit immediately.

A dialog close, Escape, or a window-manager close that is delivered to the main window while the file dialog is up therefore ends the process. The first walk's nut export returned (A7). The retry walk's Export/Save interaction removed the PID. Export logic can succeed. The process must also survive Cancel, the dialog's close, and typing in the name field.

Deferred export-name work can touch the line edit after the dialog is already going away (`_focus_export_3mf_filename`, `_select_export_3mf_name_next_frame`, the `text_changed` connection). A use-after-free there is the crash form of the same bug. WP2 reproduces both forms and leaves the process running either way.

## Why 280/0 is not the GUI

`tools/lint_rung01_e2e.py` already rejects `infer_enabled`, `text_submitted.emit`, `.value` assignment, `interaction._input`, `id_pressed.emit`, `current_path` assignment, and a root size other than 1280×800. The walk can obey that lint and still miss the bug, because `_click_control` yields between mouse-down and mouse-up, and the nut's 7.5 is typed with no Distance click.

The honest event is one X11 click: motion, button down, button up, with no frame yield between down and up, then one frame, then key down/up events that carry `keycode`, `physical_keycode`, and `unicode`. After that click the selection may already be gone. The first typed character still has to replace the previous number. The second character appends.

## Work packages

Four packages. File owners are exclusive.

| WP | Owns | Leftover |
|---|---|---|
| WP1 | `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan4_numeric.gd` | P0.1 dim/radius replace, P0.2 Distance 7.5 |
| WP2 | `game/scripts/main.gd`, `game/tests/run_rung01_replan4_dialog.gd` | P0.3 dialog must not quit |
| WP3 | `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan4_smartdim.gd`. `game/scripts/sketch_mode.gd` only if the dimension label never opens the editor | P1.5 Smart Dimension |
| WP4 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | P0.4 honest walk, P1.6 carry-forward. Last |

Shared rules:

- Window for every new script is `Vector2i(1280, 800)` via `FilmUI.ensure_test_viewport`. The same steps must be doable by a person with the mouse and the keyboard at that size.
- Numeric fields are clicked with `_x11_click` and typed with `_x11_type` below. Copy the helpers into the test file. Do not `await` between button-down and button-up.
- Godot is `tools/godot/godot` (4.7-stable). Do not switch to 4.7.1. Until WP4, run a new script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`.
- `user://` paths passed into `SxDocument` are `ProjectSettings.globalize_path` first.
- Do not edit `tools/check_rung01.py`, `orbit_camera.gd`, `property_panel.gd`, `timeline_panel.gd`, or the replan-2 / replan-3 test scripts.
- Do not change the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (`nav_preset` defaults to `FUSION`), or the known single failures in `run_infer_tests` and `run_icon_tests`.
- Leave `run_rung01_wrench.gd` unchanged until WP4. WP1–WP3 must keep it compiling. Its current Enter-then-commit dim path and its unfocused `7.5` path must keep passing.
- Do not loosen sketch chain tolerances (1e-6) or the 3MF manifold gate.
- Forbidden in every new replan-4 script, and still forbidden in the WP4 walk: `interaction._input`, `id_pressed.emit`, `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text`, assigning `SpinBox.value`, `text_submitted.emit`, `focus_dim_for_typing`, `focus_distance_for_typing`, `doc.export_3mf()`, `infer_enabled = false`, and `dlg.current_path =`.

`_x11_click` / `_x11_type` (the sequence a real click and a real key use):

```gdscript
func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 47:
			code = KEY_SLASH
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame
```

Callers `await` both helpers. Paths typed in WP2 stay within digits, lowercase letters, `.`, `-`, and `/` (for example `/tmp/sx024-nut-dialog.3mf`).

On `f2770220`, before WP1, a test that `_x11_click`s the dim blank and types `22.5` over an existing `2.5` or `10` must fail. Do not insert an `await` between mouse-down and mouse-up so that it passes.

### WP1 — First key replaces the dim blank and the Distance blank

P0.1 and P0.2. One file owns both spins.

**Scope.** `sketch_context_chrome.gd` only.

**Behaviour.**

- `DimLineEdit` and `DistanceLineEdit` each remember that the next printable length key replaces the whole value. Set that flag on focus and on every left click, including a click that finds the field already focused. The flag survives the caret placement that clears `select_all`.
- On the next pressed key that is a digit, a keypad digit, `.`, or (Distance only) `-`, the line edit selects all before the character is inserted, then clears the flag. The character replaces the previous text. The following keys in that same session append, so `7` then `.` then `5` becomes `7.5`, and `2` then `2` then `.` then `5` becomes `22.5`.
- A pending deferred or next-frame `select_all` must not run after that first character. Distance already bumps `_distance_select_gen` from `text_changed`. Keep that. The dim blank needs the same generation, or the same "do not select again once typing has started" rule. A late `select_all` that re-selects `2` and lets the next key replace it is the other failure; the walks' garbage strings are the append failure. Both have to be closed.
- Enter on the dim blank still commits through `_on_dim_text_submitted` only when `_parse_dim_text` returns one float. `22.5` emits `dim_submitted` with 22.5. `2.522.5` emits `dim_rejected`, does not emit `dim_submitted`, and does not leave a length override taken from a truncated `to_float`.
- Distance: after the replace, the line parses as 7.5, `_extrude_spin.value` is 7.5, and `ExtrudeReadout` reads `Extrude 7.5 mm` before Extrude is pressed. No Enter. `_emit_finish_requested` sends 7.5. Focus leaving the field for the Extrude button must not snap the line back to 20.
- If the line is not one float (`20.07.5`, `2.522.5`), Extrude does not run and the spin does not become the `to_float` prefix snapped to step 0.5. SpinBox `apply` on focus exit must not be the writer that turns that junk into 20 and then lets the button succeed. `distance_rejected` still fires. The previous good value stays the spin's value only as a display rollback; it is not a successful extrude.
- `focus_distance_for_typing` and `focus_dim_for_typing` stay for the unfocused burst. They are not the path this package's acceptance uses.
- Polygon AF, the `r` cue, chip placement, Thin, and Up To Surface are unchanged. Do not put a `Ø` prefix on the dim blank. Do not bring back Cut → Through All.

**Headless acceptance.** `run_rung01_replan4_numeric.gd` at 1280×800. Clicks are `_x11_click`. Keys are `_x11_type`. The test source does not call `focus_dim_for_typing`, `focus_distance_for_typing`, or `set_extrude_distance`, and does not assign `.text` or `.value`.

- Sketch, circle, click the origin, `_x11_click` the dim blank, type `10`, Enter. Radius is 10 ± 0.05. Status contains `Circle r=10` and `Ø20`.
- Same sketch, second circle at a different centre, `_x11_click` the dim blank again (it already holds the previous number or the rubber-band), type `22.5`, Enter. The line edit's text, suffix stripped, parses as 22.5 and does not contain `2.522`. Radius is 22.5 ± 0.05. Status contains `Circle r=22.5` and `Ø45`.
- Fresh sketch, one closed profile (a rectangle or the circle above). `_x11_click` Distance, type `7.5`, do not press Enter. Readout contains `7.5`. `extrude_distance()` is 7.5. Press the finish-bar Extrude button with `_x11_click`. Bbox Z is 7.5 ± 0.2. Status contains `Extrude Blind 7.5000 mm`.
- On a fresh sketch with a closed profile, `_x11_click` Distance and type `20.07.5`. The first character replaces the default, so the line is exactly that string. Press the finish-bar Extrude button. No new body. Status contains `Cannot read distance`. The solid is not 20 mm thick from that click.
- Readout global rect stays inside 1280×800 and does not intersect the variant chips. Extrude's global rect stays inside the viewport.

**GUI acceptance.** At 1280×800, mouse and keys, no Timeline. Circle, type `10`, Enter, second circle, type `22.5`, Enter. Ø20 and Ø45, blank never shows `2.522`. Then type `7.5` in Distance and press Extrude without Enter. The solid is 7.5 ± 0.2 thick and the status contains `Extrude Blind 7.5000 mm`.

**Depends on.** Nothing. Merge any time.

### WP2 — File, Export, and Save dialogs do not quit the app

P0.3.

**Scope.** `main.gd` only. Do not change `_export_3mf_start_dir`, `_export_3mf_filename`, or the absolute-path resolver except to null-check a line edit that may already be gone.

**Behaviour.**

- While `file_dialog` is visible, `NOTIFICATION_WM_CLOSE_REQUEST` hides the dialog and does not call `get_tree().quit()`. The same is true for `confirm_dialog` and any other `Window` this file is showing: hide that window, leave the process running. A close of the main window with no dialog up still goes through `_confirm_discard` and can quit.
- `file_dialog.close_requested` and Cancel hide the dialog only. Escape while the dialog is visible hides it, is marked handled, and does not reach the quit path or `cancel_stack` in a way that exits.
- Deferred focus and `select_all` on the export name (`_focus_export_3mf_filename`, `_select_export_3mf_name_next_frame`, `_on_export_3mf_name_changed`) return when the dialog is not visible or the line edit is not inside the tree. They must not touch a freed edit. That is the crash form of this bug. Reproduce it; if the PID dies with a signal rather than `quit()`, the backtrace decides the guard. Do not enable `use_native_dialog`.
- Save As uses the same dialog instance (`FileAction.SAVE_AS`). It gets the same close rule.
- OK / Save still writes the file. Export 3MF success status stays `Exported 3MF → ` plus the path that was written. A dialog that the user Cancels leaves the document and the window as they were.

**Headless acceptance.** `run_rung01_replan4_dialog.gd` at 1280×800.

- Build any closed solid so there is something to export (sketch UI, typed radius, finish-bar Extrude). Open File → Export 3MF by clicking the menu row. The dialog is visible. `_x11_click` the name line, `_x11_type` `/tmp/sx024-nut-dialog.3mf`. Click Cancel (`get_cancel_button`) with `_x11_click`. The dialog is hidden. `main` is inside the tree. The script is still running.
- With the dialog open again, send `NOTIFICATION_WM_CLOSE_REQUEST` to the main node. The dialog hides. `main` is still inside the tree. `get_tree().quit` has not run (the script continues and prints the check).
- Open Export again, `_x11_click` the name line, type `/tmp/sx024-nut-dialog.3mf`, click OK. That file exists. Status starts with `Exported 3MF → `. `main` is inside the tree.
- File → Save As, type `/tmp/sx024-save.sxp`, click Cancel. `main` is inside the tree. Repeat and click OK. The `.sxp` exists. `main` is inside the tree.
- The test does not assign `current_path` and does not call `export_3mf(`.

**GUI acceptance.** At 1280×800, open Export, type a path, Cancel, type a path, Save. Then Save As, Cancel, Save. The window is still SolidExpress after each of those. The 3MF from Save is the file the status names. Kill nothing; the process id from launch is the process id at the end.

**Depends on.** Nothing. The numeric replace is WP1. This package can type a path even if the name field appends; survival is the gate. A written file is still required on OK.

### WP3 — Smart Dimension types a replacement value

P1.5. A5 was skipped and B1.4 was never reached. The tool exists (`SketchMode._click_smart_dim`, `dimension_edit_requested` → `ViewportInteraction._show_dim_edit`). The popup line edit select-alls only with `call_deferred`, the same race as the dim blank.

**Scope.** `viewport_interaction.gd` only. Edit `sketch_mode.gd` only if a viewport click on the dimension label does not open `_show_dim_edit`. No other edit in that file. Do not change tangent inference, fillet, or extrude.

**Behaviour.**

- `_dim_edit_line` uses the same first-key rule as WP1: focus or left click arms replace; the next digit or `.` selects all before insert; later keys append. Enter still runs `_apply_dim_edit`.
- Two circle centres, Smart Dimension, then a click on the dimension label, opens the popup with the current distance selected for replacement. Typing `200` and Enter stores 200. The centres are 200 ± 0.2 apart. Appending onto the old text (`200200`, or the old distance with `200` glued on) does not.
- A click that misses the label does not create a second dimension and does not exit the sketch.
- Keys typed into this popup are not delivered to the dim blank or to Distance.

**Headless acceptance.** `run_rung01_replan4_smartdim.gd` at 1280×800.

- Two circles drawn with viewport clicks (centre, then a rim point). Radii may be the pointer distance. Place the centres about 180 mm apart so the distance is not already 200. This package does not depend on the dim-blank replace.
- Smart Dimension tool, click the first centre, click the second centre. A distance dimension exists.
- `_x11_click` the dimension label (or the popup line once it is open). The popup is visible. Type `200`, Enter. The constraint value is 200 ± 0.2 and the centre distance is 200 ± 0.2. The popup line after the first character is not the old text with `200` appended.
- The test does not call `set_dimension_value` and does not assign the line's `.text`.

**GUI acceptance.** Same clicks and the same typed `200` at 1280×800. The label reads 200. The Ø45 centre sits 200 mm from the origin.

**Depends on.** Nothing to compile. A full wrench that uses this dimension is WP4, after WP1 so the two radii exist.

### WP4 — The walk fails when the GUI path fails

P0.4, and the P1.6 steps that sx-024 never reached. This is the only package that edits `run_rung01_wrench.gd`.

**Scope.** Extend the walk. Extend `tools/lint_rung01_e2e.py`. Append the three `run_rung01_replan4_*.gd` scripts to the `test-godot` recipe after the `run_rung01_replan3_*.gd` lines. `tools/check_rung01.py` stays as it is.

If the walk fails on a bug in a file another package owns, and that package has already merged, WP4 may edit that file so the walk passes. It does not take the file over for anything else. P1.6 (closed blank, Up To Surface, Timeline Distance 10→14) is this carve-out: the walk already contains those checks from replan 3. If they fail on this build once `10` and `22.5` can be typed, fix the owning file. If they pass, do not edit `sketch_mode.gd`, `property_panel.gd`, or the fillet kernel.

**Click path.** Replace `_click_control` for numeric line edits (dim blank, Distance, dimension popup, export name) with `_x11_click`. `_type_dim` and `_type_distance` type with `_x11_type` after that click. Do not await a frame between mouse-down and mouse-up. Keep a frame between keys.

**Changes to the walk** (keep every check that already describes the handout):

1. **Second radius, same sketch.** After the Ø20 circle (typed `10`), the Ø45 circle is `_x11_click` on the dim blank and `_x11_type` of `22.5`, then Enter. Assert the line does not contain `2.522` and the radius is 22.5 ± 0.05. Status contains `Ø45`. This is the check that is green today only because `_click_control` yields. It must fail if replace regresses.
2. **Distance click, then 7.5, then Extrude.** The nut's 7.5 is `_x11_click` on `DistanceLineEdit`, `_x11_type` `7.5`, no Enter, finish-bar Extrude. Readout contains `7.5` before the click. Bbox Z is 7.5 ± 0.2. Status contains `Extrude Blind 7.5000 mm`. Do not use `_type_unfocused_distance` as the only 7.5. The unfocused burst may stay as an extra check. It must not be able to pass the nut while the click path still extrudes 20.
3. **File dialog.** On the nut export, Cancel once (`get_cancel_button`, `_x11_click`) and assert `main` is inside the tree and the script continues. Open the dialog again and save. Also send `NOTIFICATION_WM_CLOSE_REQUEST` while the dialog is visible and assert the script continues. Checker nut still exits 0 on the file OK wrote.
4. **Smart Dimension 200** between the two wrench centres, typed in the popup with `_x11_click` / `_x11_type`, before the tangent lines. Centre distance 200 ± 0.2. Then the existing tangent and Extrude Blind 10 checks.
5. **P1.6, unchanged expectations.** Inference stays on. Blank bbox 232.5 × 45 × 10 ± 0.2, no `open profile`, no Box. Jaw Cut, Up To Surface, bottom-face click, hole open at z = 0.5 and z = 9.5. Timeline base extrude `14`, Enter, thick checker 4/4. Jaw width 20 → 21 keeps 45°. Fillets stay typed. Do not delete a failing check to shrink the failure count.
6. Checker invocations stay `nut`, `wrench`, and `thick` with `14`. Exit code 0. Do not add `--allow-mirror`.

**Lint.** Extend `tools/lint_rung01_e2e.py`:

- The walk and `game/tests/run_rung01_replan4_*.gd` fail the lint if they contain `focus_dim_for_typing`, `focus_distance_for_typing`, an assignment to `.text`, or `set_extrude_distance`.
- The walk's numeric click helper fails the lint if its source awaits between `pressed = true` and the matching `pressed = false`.
- Existing walk forbiddens stay (`infer_enabled`, `text_submitted.emit`, `.value` assignment, `interaction._input`, `id_pressed.emit`, `item_selected.emit` outside `_pick_end`, `current_path` assignment, root size other than 1280×800).
- Scan `run_rung01_replan4_*.gd` for the same replan-3 forbidden list (`interaction._input`, `id_pressed.emit`, `set_extrude_distance`, `set_up_to_face`, `export_3mf(`, `text_submitted.emit`).
- `make test` runs the lint before the Godot suites. The walk still `quit(1)` when `failures > 0`. Do not swallow that exit.

**Depends on.** WP1, WP2, and WP3 merged.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | Same-burst click, type `10` then `22.5` in one sketch: Ø20 and Ø45, line is not `2.522.5`. Same-burst click, type `7.5`, Extrude: Z = 7.5, status `Extrude Blind 7.5000 mm`. Junk distance does not extrude at 20. |
| WP2 | Export and Save As: type a path, Cancel, window-close, and OK. Process stays up. OK writes the file. |
| WP3 | Smart Dimension between two centres, type `200` in the popup, centres are 200 apart. |
| WP4 | Those three gestures inside `run_rung01_wrench.gd`, plus the existing blank, jaw, fillet, and thick checks. nut 7/7, wrench exit 0, thick 4/4. Lint clean. 0 walk failures. |

## Merge order

```
WP1 ──┐
WP2 ──┼── WP4
WP3 ──┘
```

WP1, WP2, and WP3 merge in any order. They do not share files. WP3's radius setup is easier after WP1; the dimension assertion stands on its own once the circles exist. WP4 is last. sx-025 runs on the build that contains WP4.

## sx-025 GUI critique checklist

One session. Desktop **1280×800**. Mouse and keyboard only. No property JSON, no Box, no Timeline edit on the nut. Record status text after each step. Export only through File → Export 3MF. Note the process id at launch and again after the dialog steps.

Pass bar: every row below is WORKS, the three checker commands exit 0, `run_rung01_wrench.gd` prints 0 failures on this OCCT 8.0.1 build, score ≥ 9. A nut that is 7.5 only after a Timeline edit fails A6. A second circle whose blank contains `2.522` fails B1. A vanished PID fails D1.

| # | Do this | Pass |
|---|---|---|
| A1 | File → New | `New — empty part` and no body |
| A2 | Sketch on the ground plane | `Sketch on ground (XY)` |
| A3 | Polygon, type `20` with no blank click | Status contains `Polygon AF 20`. Flats at ±10 |
| A4 | Circle, type `5` | Status contains `Circle r=5` and `Ø10` |
| A6 | Click Distance, type `7.5`, do not press Enter, Extrude | Readout `Extrude 7.5 mm` before the click. Status contains `Extrude Blind 7.5000 mm`. Thickness 7.5, not 20. No Timeline edit |
| D1 | File → Export. Type a path. Cancel. Open Export again. Type a path. Save. Then Save As, Cancel, and Save | Process id unchanged. Status `Exported 3MF → <path>` on the save. Checker nut 7/7 |
| B1 | New. Circle radius `10` at the origin, then radius `22.5` at (200, 0), same sketch. Smart Dimension `200` between centres. Upper and lower tangents. Extrude Blind 10. Thin off | Blank shows `22.5`, not `2.522.5`. Ø20 and Ø45. Centres 200 apart. No `open profile`. No Box. Bbox 232.5 × 45 × 10 |
| B2 | Top face: Ø10 hole, jaw AF 20 at 45°, Cut, Up To Surface, click the bottom face, Extrude | Extrude disabled until the click. Label contains `z 0`. Jaw open at z = 0.5 and z = 9.5 |
| B3 | Slot 160 × 10 × 2.5 blind | Slot floor at z = 7.5 |
| B4 | Fillet R10 at the neck, R1 on top, bottom, and slot floor. Then R1.5 on the slot floor | R1 commits. R1.5 status contains `1.25` and the solid does not change |
| B5 | Timeline, base extrude Distance `14`, Enter, click away, export `wrench-t14.3mf`. Then jaw width 20 → 21 | Thick 4/4 (Z = 14). Angle still 45° |
| H | `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` | `0 failures`. Lint clean. The log shows the second radius and the Distance click, not only an unfocused `7.5` |

Score the second radius, the 7.5 extrude, the dialog survival, and the headless count separately. A wrench that never gets a Ø45 circle stays under 9.

## Out of scope

- Camera number keys versus sketch digits (replan 2). Standard views outside a sketch stay.
- Variant chips versus the finish bar at 1280×800 (replan 2). WP1 only keeps the readout from covering that row.
- Empty-sketch Exit confirm (replan 2).
- Nut AF 20, AC 23.094, bore Ø10, and the nut's closed mesh. Those passed at sx-024 once thickness was edited. Thickness on the first Extrude is the nut work here.
- Replan 3's closed-blank inference, Up To Surface pick, R1 fillet recovery, and Timeline Distance commit. They stay in the walk and in the checklist. A WP4 edit there is only a regression found after `10` and `22.5` can be typed.
- Export status prefix `Exported 3MF → <path>` and the absolute-path resolver. A7 already exported. WP2 keeps that status and stops the quit.
- Insert Box as the wrench blank.
- A kernel change to chain tolerance, a new constraint type, or `use_native_dialog`.
- Rungs 2–8, threads, and a datum tree beyond Top = XY.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `f2770220` / `52d337f4`.
