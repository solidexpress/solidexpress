# Rung 1 replan 5 — leave a failed sketch, open the jaw, keep Smart Dimension safe

Status: plan only. No product code in this change.

Baseline: `main` at `09fb9b2215e05ce6ad7f7e151a70f33659181ac8` (merge of #80). Replan 4 is [`rung-01-replan-4.md`](rung-01-replan-4.md) (WP1–WP4, PRs #76–#80, all merged). The sx-025 critique of local build sha256 `33f20902dae0578089a513c2f6bc232c63f1304247e72fe2c4e9fbb3e8181608` scored **5/10** and failed rung 1. Symptom list: [`rung-01-leftovers-sx025.md`](rung-01-leftovers-sx025.md). This replan names the root cause of each leftover at `09fb9b22`, the fix, and an acceptance check a person can perform with the mouse and the keyboard at 1280×800.

BUILD agents execute one WP each, on grok-4.6 with effort high and fast off. WP1, WP2, and WP3 do not edit the same files and merge in any order. WP4 merges last.

The critique binary logged Godot 4.7.1. This repo pins Godot 4.7-stable at `tools/godot/godot`. BUILD and the e2e use that binary. Do not switch the pin to 4.7.1. The failures below are in SolidExpress scripts, and they reproduce on the pinned binary.

## Goal

A person using only the GUI, at **1280×800**, finishes UBC ELEC391 Exercise 1 (hex nut) and Exercise 2 (wrench). Replan 4 already states the nut, the wrench blank, typed Distance 7.5, and the dialog that stays open. Those stay true. This replan makes the rest of the handout reachable:

- After a sketch edit whose regenerate fails (`profile has an open loop` on a downstream extrude), Exit Sketch, Edit → Undo, and File → New each leave a usable document. The status does not stay `Failed to update sketch`. A new ground sketch accepts a circle. The process is the same process.
- Power Trim on the top-face jaw (Center Three Point rectangle, construction centreline across the opening, click on the shaft side) reports `Trimmed open jaw`. The profile is closed. The cut can be started.
- Smart Dimension on the nut places a centre-to-flat distance and a bore diameter. The solve does not stay `failed`. Centres 200 on the blank still works. Neither gesture leaves a document that New cannot clear.
- Up To Surface can be the bottom face without the pick being cancelled by the orbit that reveals it.
- A bare export name is written in the folder the dialog is showing.

Checker commands are unchanged. Do not edit `tools/check_rung01.py`. Do not pass `--allow-mirror`. On this tip the pass lines are:

```
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Wrench is 28 rows when every conditional slot row runs (mesh, three bbox rows, orientation, and `wrench_tests` including the info-only slot centre). Exit code 0 is the pass.

Rung 1 is done when one GUI critique (sx-026) follows the checklist below, the three checker commands pass on files the export dialog wrote, `run_rung01_wrench.gd` prints 0 failures on this OCCT 8.0.1 build, and the score is at least 9.

## Situation

sx-025, desktop 1280×800, Godot on llvmpipe, tip `09fb9b22`, real mouse and keyboard. Overall **5/10**, rung 1 **FAIL**. The nut and the wrench blank are makeable. The open jaw is not. Slot, fillets, and the thickness edit were not reached.

| What replan 4 fixed in the GUI | What sx-025 still got |
|---|---|
| Second radius replaces. B1.3 `Circle r=22.5000 (Ø45.0000)`. | Power Trim on the jaw rectangle: `Trim failed`. Expected `Trimmed open jaw`. |
| Finish-bar Distance 7.5. A6 `Extrude Blind 7.5000 mm`. Nut checker **7/7**. | After that trim and the cut attempt, `Failed to update sketch` survives Undo, Exit Sketch, and File → New. Kernel: `regenerate stopped at feature extrude 2` / `edit sketch: extrude 2: profile: profile has an open loop`. The process had to be killed. |
| Export Cancel and Escape leave the process running. | Bare name `nut.3mf` saved to `HOME` (`/tmp/sx-025-home/nut.3mf`). A full absolute path saved in the requested folder. |
| Smart Dimension 200 between blank centres. B1.4 `Dimension updated`. | Nut A5: intermediate `centre-to-flat 10.0000`, then `coincident: failed`, then `Measure cleared`. Fresh-app R2: Smart Dimension led back to `Failed to update sketch`. |
| Headless walk reported **307/0**. | The real GUI stops in B2. B3–B5 not reached. Blank checker also reports orientation `flipX` (mirror). |

Do not re-open the rows in "Out of scope" unless a new GUI walk shows they regressed. Do not recritique hash `09fb9b22` / `33f20902`. The next critique is a build that contains WP4.

## Why a failed regenerate sticks

`SxDocument::apply_graph_edit` (`sxcore/src/sx_document.cpp`) snapshots the graph, runs the edit, and regenerates. On failure it logs `label + ": " + err`, restores the snapshot, regenerates that snapshot, and returns false. The label for `graph_update_sketch` is `edit sketch`. sx-025's log line `edit sketch: extrude 2: profile: profile has an open loop` is that path: the in-memory sketch was written onto a sketch feature, downstream `extrude 2` rejected an open profile, and the graph was put back.

The GDScript session is not put back.

`SketchMode.exit_sketch` (`game/scripts/sketch_mode.gd`), when `editing_fid != ""`, calls `graph_update_sketch`. On false it emits `Failed to update sketch` and **returns while `active` is still true**. `set_dimension_value` does the same push whenever `editing_fid != ""`, then redraws the rejected sketch. `_ensure_sketch_feature` sets `editing_fid` as soon as the sketch feature has been added, including when a later extrude rolls back. The session now holds a sketch the graph refused, and every Exit or dimension edit pushes it again. Each push fails, rolls back, and emits the same status. The committed document is still the last good snapshot. The screen is not.

`Main.edit_undo` only calls `view.undo()` and sets the status to `Undo`. It does not reload the session from `graph_get_sketch`. The bad sketch stays in memory. The next update pushes it again. Undo of a failed update also steps the undo stack, because the failed edit never became a command; the click undoes the previous successful command and still leaves the session live.

`Main._do_new` calls `exit_sketch()` and then **always** calls `view.new_document()`. The new document is empty, so the status becomes `New — empty part, Top plane (XY). View ▸ Timeline to edit features` and the grid is empty (B2r.2, B2r.7). `sketch_mode.active` is still true, and `editing_fid` still names a feature the new document does not have. `_start_sketch` returns immediately when `active` is true, so the ground click does nothing. The next Exit calls `graph_update_sketch` on a missing id, gets false, and the status is `Failed to update sketch` on an empty part (B2r.7). Esc can reach `cancel()`, which does clear `active`, but the walker used Exit, Undo, and New.

File → New therefore looks like it worked for one status line and then the same failure returns. That is the poison: the session outlives the document it was editing.

The fix is local. After `graph_update_sketch` returns false the graph is already the last good snapshot, so `graph_get_sketch(editing_fid)` is the sketch the extrude accepted. Reload that into the session. Exit and New must end the session (`active == false`) even when the update returns false. Undo must reload from the feature that still exists, or end the session when the feature is gone. The final status of those three gestures is not `Failed to update sketch`.

Do not change `apply_graph_edit`'s rollback. Committing the open profile would keep a solid that does not regenerate. Do not loosen the 1e-6 profile check in `sxkernel/src/sketch.cpp`.

`editing_fid` becomes non-empty inside a face sketch once `_ensure_sketch_feature` has saved it. That is the B2r path, and the kernel log proves it (app.log lines 139–224, repeated). R2 was a new process; the captured log for that process does not contain a second `edit sketch:` line (it ends in the focus-signal spam). Treat R2 as the same trap if a dimension edit or Exit runs while `editing_fid` is set, and cover it with the Smart Dimension acceptance below. Reproduce both on 4.7-stable before closing the bug.

## Why Power Trim says Trim failed

`SketchMode.trim_at` tries `_trim_open_jaw` first. That function returns true and emits a bare `Trim failed` in two cases: no circle within 1.0 mm of the cutter (`best_cd` starts at `1.0`, `cr < 1e-6`), or `walls.size() != 2`. Both returns happen before any entity is deleted. A miss that returns false falls through to `sketch.trim_entity`, which ignores construction geometry and can open a closed rectangle. The jaw path's failure returns do not fall through. Keep that.

B2.11's recorded centreline is not the perpendicular the critique sentence describes. The walk measured `Δu 80.18, Δv 80.94` on a 184 mm centreline, which is about 45.3°. The rectangle was at 45.617°. Those directions are almost parallel. The walk parent called the first centreline an operator error and started a perpendicular retry. That retry never issued a trim: B2r was already stuck on `Failed to update sketch`. The only live Power Trim click is B2.11.

A cutter a fraction of a degree off the rectangle's axis crosses all four sides, so `walls.size()` is 4 and the status is `Trim failed`. A cutter exactly on the axis crosses the two short ends only. The 1° class of miss is the difference between those two counts. The handout cutter is the other axis: through the head centre, perpendicular to the long sides, click on the shaft side (toward the pivot).

The headless walk does not make that click. `run_rung01_wrench.gd` builds the rectangle at 30°, drives the angle label to 45°, draws a perfectly perpendicular centreline with `_click_uv`, and does not redraw the Ø45 (B2.8 did). `_click_uv` goes through `_pointer_click`, which **awaits a frame between mouse-down and mouse-up**. The profile circle is a model-edge fallback (`_model_circles`), not the sketch circle the walker drew. A green trim check on that path can coexist with `Trim failed` on the GUI click.

Center Three Point (`_click_rect`, variant `center_three_point`) adds a construction diagonal and a construction +X through the centre. Both are stored in `_angle_datum_lines`, and `_nearest_construction_line` skips those ids, so they are not the cutter. They must stay construction. A solve that clears the construction flag would make the datum line compete with the user's centreline inside the 40 mm search.

The fix, in `_trim_open_jaw`:

- A side whose direction is within about 2° of the cutter is a cap, not a wall, even if a skew makes its endpoints land on opposite sides. Caps on the discard side are deleted. The keep-side cap is replaced by the head arc, as today.
- Walls are the sides the cutter actually crosses. The handout click has two of them (the long sides of a perpendicular cut, or the short ends of a cut along the jaw). More than two crossings after the cap rule is `Trim failed — centreline does not cross two jaw sides`, and the sketch is unchanged.
- The head circle is the sketch circle the cutter meets: the cutter's line passes within 15% of the radius of the centre, and the segment overlaps the circle. The 1.0 mm `best_cd` gate rejects a centreline that misses the centre by 2 mm even when the Ø45 is the obvious cap. Keep the model-edge fallback when no sketch circle qualifies.
- Success still emits `Trimmed open jaw`, welds the floor and the arc (`_weld_jaw_profile`), and leaves `profile_is_closed` true so the cut is not blocked by `Open-profile cut needs a line chain`.
- The click that opens the jaw is on the shaft side of the cutter (toward the pivot at the origin). The opening then faces the handle, which is the side `check_rung01.py` measures along +u from the head.

The recorded near-parallel centreline must not be required to invent a perpendicular jaw. It must leave the rectangle closed and must leave the session exitable. Status names the mismatch (`Trim failed — draw the centreline across the jaw`) rather than a bare `Trim failed`. The handout perpendicular click is the one whose status is `Trimmed open jaw`.

## Why Smart Dimension reports coincident: failed

`centre-to-flat 10.0000` is `_smart_dim_between` in `sketch_mode.gd`: one reference is a circle centre, the other is a line, and the distance constraint is the flat distance. That part of A5 ran.

`coincident: failed` is only produced by `Main._apply_constraint` (`"%s: %s" % [type, result]`). The relation chips call it (`main.gd` sketch actions include `coincident`). `SketchMode.constrain` adds the constraint and then `run_solve()`. A failed solve leaves the new constraint in the sketch and sets `last_solve_status` to `failed`. The nut polygon is already defined by Across Flats. An extra coincident on the wrong endpoints fails, and the failure stays. `Measure cleared` is Escape while the measure overlay has an anchor (`viewport_interaction.gd`). It does not remove the constraint.

`constrain` must treat a failed solve the way `end_drag` treats a failed drag: remove the constraint just added and solve again. The status may say the relation did not stick. `last_solve_status` after that revert is not `failed`, and the polygon and the bore circle are unchanged. Centre-to-flat (centre, then a hex edge) still records a distance near 10. A Smart Dimension click on the bore circle still records a diameter of 10. Centres 200 stays the replan-4 popup path and must keep passing `run_rung01_replan4_smartdim.gd`.

A dimension edit that does call `set_dimension_value` while `editing_fid` is set uses the same `graph_update_sketch` push as Exit. The session revert in WP1 is what stops that push from becoming the R2 trap. WP1 owns both.

## Why the bottom face is easy to lose, and why a bare name saves to HOME

Up To Surface arms a one-shot in `ViewportInteraction._input_up_to_face_pick`. Left click commits. Right click and Escape call `_disarm_up_to_face_pick` and emit `Up To Surface face pick cancelled`. A click that misses emits `Click a model face for Up To Surface` and, on the commit path that finds nothing, does not by itself re-arm. From the top view the bottom face is hidden behind the sketch host. The walker orbited to see it and the pick was gone (B2.12). Orbit (middle button, Alt+left) must not disarm the pick and must not set `_up_to_face_pick_consumed`. A miss stays armed.

The finish bar also grows a button, `Opposite face`, on the Up To Surface panel in `sketch_context_chrome.gd`. It sets `up_to_face_id` to the face of the sketch's target body whose midpoint is farthest along the negative sketch normal (the bottom face of a top-face sketch) and enables Extrude. The viewport click remains for a person who can see the face, including a Front or Right view click. The button is the path that does not need that orbit.

Export: `_resolve_export_3mf_path` returns the `file_selected` path when the typed text is not absolute. The dialog opens in `_export_3mf_start_dir()`, which is `HOME` until the part has been saved or a previous export set `_last_export_dir`. sx-025 typed the bare name `nut.3mf` while the dialog was showing another folder and the file landed in `HOME`. At OK, a typed string that contains no directory is joined onto `file_dialog.current_dir` as it is at that moment (the folder the dialog is showing after a browse), not onto the directory from process start. An absolute typed path still wins, including the glued-absolute tail the resolver already keeps. The builder reproduces this by clicking into a non-HOME folder in the dialog and then typing the bare name. If the folder the dialog shows and `current_dir` disagree, join onto the directory the dialog is actually displaying and add the assertion that failed on today's resolver.

## Why 307/0 is not B2

`run_rung01_wrench.gd` drives trim and the bottom face with helpers that are not the sx-025 click. `_pointer_click` yields between button-down and button-up. The jaw sketch omits the redrawn Ø45. The centreline is constructed from exact unit vectors. The recovery sequence (Undo, Exit, New after an open-loop error) is absent. Lint already rejects several cheats and still lets this pass. WP4 adds the real click and the recovery scene to that walk.

## Work packages

Four packages. File owners are exclusive. WP1, WP2, and WP3 merge in any order.

| WP | Owns | Leftover |
|---|---|---|
| WP1 | `game/scripts/sketch_mode.gd`, `game/tests/run_rung01_replan5_session.gd`, `game/tests/run_rung01_replan5_trim.gd`, `game/tests/run_rung01_replan5_smartdim.gd` | P0.1 session revert, P0.2 Power Trim, P0.3 Smart Dimension |
| WP2 | `game/scripts/main.gd`, `game/tests/run_rung01_replan5_shell.gd` | P0.1 New / Undo / Exit, P1.5 bare export name |
| WP3 | `game/scripts/viewport_interaction.gd`, `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan5_face.gd` | P1.4 Up To Surface, P2.7 focus-signal spam |
| WP4 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | Honest walk, including trim click and recovery. Last |

WP1 is the largest package because the three sketch bugs live in one file. One agent, three commits on that branch, in the order session, then trim, then Smart Dimension. Do not split WP1 across agents.

Shared rules:

- Window for every new script is `Vector2i(1280, 800)` via `FilmUI.ensure_test_viewport`. The same steps must be doable by a person with the mouse and the keyboard at that size.
- Viewport and chrome clicks that stand in for the GUI walk use `_x11_click` below. Do not `await` between button-down and button-up. Keys use `_x11_type`. Copy both helpers into the test file.
- Godot is `tools/godot/godot` (4.7-stable). Until WP4, run a new script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`.
- `user://` paths passed into `SxDocument` are `ProjectSettings.globalize_path` first.
- Do not edit `tools/check_rung01.py`, `orbit_camera.gd`, `property_panel.gd`, `timeline_panel.gd`, `sxkernel/src/sketch.cpp`, or the replan-2 / replan-3 / replan-4 test scripts.
- Do not change the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (`nav_preset` defaults to `FUSION`), or the known single failures in `run_infer_tests` and `run_icon_tests`.
- Leave `run_rung01_wrench.gd` unchanged until WP4. WP1–WP3 must keep it compiling and must keep `run_rung01_replan4_numeric.gd`, `run_rung01_replan4_dialog.gd`, and `run_rung01_replan4_smartdim.gd` passing.
- Do not loosen sketch chain tolerances (1e-6) or the 3MF manifold gate.
- Forbidden in every new replan-5 script, and still forbidden in the WP4 walk: `interaction._input`, `id_pressed.emit`, `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text`, assigning `SpinBox.value`, `text_submitted.emit`, `focus_dim_for_typing`, `focus_distance_for_typing`, `doc.export_3mf()`, `infer_enabled = false`, `dlg.current_path =`, `sketch_mode.cancel(`, `sketch_mode.exit_sketch(`, `sketch_mode.trim_at(`, `new_document(`, and `graph_update_sketch(`. The product code calls those. The tests click.

`_x11_click` / `_x11_type` (the sequence a real click and a real key use). Callers `await` both helpers.

```gdscript
func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
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

### WP1 — Revert a rejected sketch, open the jaw, revert a failed relation

P0.1 (session half), P0.2, and P0.3. One file owns all three. Three commits, in this order.

**Scope.** `sketch_mode.gd` only. `sxcore/src/sx_document.cpp` only if a test shows `graph_get_sketch(editing_fid)` after a failed `graph_update_sketch` still returns the open profile. On `09fb9b22` the C++ rollback restores the snapshot before returning false, so the reload should see the last good sketch. Do not change the rollback policy otherwise.

**Commit 1 — session revert.**

- `exit_sketch`: when `graph_update_sketch` returns false, reload `sketch` from `graph_get_sketch(editing_fid)` when that feature still exists, then leave the session with the same cleanup a successful exit uses (`active = false`, clear `editing_fid`, tools, meshes, camera, `view.refresh`, `finished`). Status is `Sketch edit discarded — ` plus `last_graph_error` when that string is non-empty. Do not return while `active` is true. Do not emit `Failed to update sketch` as the final status.
- `set_dimension_value`: on the same false return, reload from the feature and redraw. The in-memory sketch no longer contains the rejected edit. A following Exit uses the reloaded sketch and succeeds. If the feature cannot be reloaded, leave the session as in `exit_sketch` and emit the discard status.
- `_ensure_sketch_feature`: on update failure, reload from the feature before returning `""`. The session stays active so the person can keep drawing, and Exit can still leave.
- A successful Exit still emits `Sketch saved` and still returns the feature id.

**Headless acceptance** (`run_rung01_replan5_session.gd`). Clicks are `_x11_click` / `_x11_click_screen`. The test does not call `exit_sketch`, `cancel`, `new_document`, or `graph_update_sketch`.

- Sketch a rectangle on the ground with viewport clicks, type a distance if needed, finish-bar Extrude so a sketch feature and an extrude exist. Double-click the sketch row in the timeline (the visible row control) so `editing_fid` is that sketch and `active` is true.
- Select one rectangle edge and press Delete. The profile is open.
- Click the Exit Sketch button. `sketch_mode.active` is false. The status label does not contain `Failed to update sketch`. It contains `Sketch edit discarded`. The extrude's body is still present (the open edit was not committed). `last_graph_error` may still describe the open loop; the status the person reads does not stay on the failure.
- File → New is WP2's button path. This script, after Exit, starts a ground sketch from the Sketch control and draws a circle. Status contains `Circle`. `active` was false before that sketch started.

**GUI acceptance.** At 1280×800, the same rectangle, Extrude, reopen, delete one edge, Exit Sketch. The status is the discard sentence. Sketch on the ground and draw a circle. No process restart.

**Commit 2 — Power Trim.**

**Scope.** `trim_at`, `_trim_open_jaw`, and the helpers they already use (`_nearest_construction_line`, `_weld_jaw_profile`, `_model_circles`). Do not change session exit in this commit.

**Behaviour.** The classifier and the statuses in "Why Power Trim says Trim failed". Datum lines in `_angle_datum_lines` stay excluded and stay construction. A failure return does not call `trim_entity` and does not delete entities.

**Headless acceptance** (`run_rung01_replan5_trim.gd`) at 1280×800. Build a closed blank the way the wrench walk does only as far as a top face (Ø20 at the origin, Ø45 at sketch (200, 0), two tangents, Extrude Blind 10) with viewport clicks and the dim blank. Then, on the top face:

- Circle radius 5 at the origin (the hole).
- Circle radius 22.5 at the head (the redraw B2.8 did; the current wrench walk skips it).
- Rectangle tool, chip `Center Three Point`, centre at the head, long side along 45°, half-width 10. Edit the width and angle labels to 20 and 45 if the clicks are only approximate. Long-side angle is 45° ± 1°.
- Centerline tool: construction line through the head centre, perpendicular to the long sides, longer than the jaw width (about 50 mm is enough).
- Power Trim. `_x11_click_screen` once, no yield between down and up, at the screen position of the point 12 mm from the head centre toward the origin, on the shaft side of the centreline. Status contains `Trimmed open jaw`. `profile_is_closed` is true. The Ø10 circle is still in the sketch.
- Second sketch, same rectangle and a centreline along the long side (the B2.11 direction, about 45°). The same style of click. Status contains `Trim failed — draw the centreline across the jaw`. The four rectangle edges still exist. `active` is true. Exit Sketch then leaves the session (commit 1). Status does not stay `Failed to update sketch`.

**GUI acceptance.** The perpendicular sequence at 1280×800 with the mouse. Status `Trimmed open jaw`. The jaw outline is open toward the pivot and closed by the head arc.

**Commit 3 — Smart Dimension does not keep a failed relation.**

**Scope.** `constrain`, and `_click_smart_dim` / `_smart_dim_between` only if the nut clicks do not create the two dimensions. Do not change the 200 mm popup in `viewport_interaction.gd` (WP3 must leave it alone; this commit does not own that file).

**Behaviour.** As in "Why Smart Dimension reports coincident: failed". Centre-to-flat and diameter stay. A failed `constrain` removes `cid` and solves again.

**Headless acceptance** (`run_rung01_replan5_smartdim.gd`) at 1280×800.

- Polygon Across Flats, type `20`, circle radius `5` at the origin, same sketch. Smart Dimension, click the origin (circle centre), click a hex edge (a point on the flat, not a vertex). A distance dimension exists and its value is 10 ± 0.5. Status contains `centre-to-flat`. `last_solve_status` is not `failed`.
- Smart Dimension, click the bore circle on its circumference. A diameter dimension exists and its value is 10 ± 0.2.
- With those two entities selected, click the Coincident relation control if it is visible; otherwise invoke the coincident action through the same chip path the GUI uses (the button that calls `_apply_constraint("coincident", …)`). After the click, `last_solve_status` is not `failed`, the coincident constraint is not in `constraint_ids`, and the bore radius is still 5 ± 0.05.
- Exit Sketch works (`active` is false). Status does not contain `Failed to update sketch`.
- The script also runs the existing centres-200 gesture only as a call to the replan-4 script's assertions if that can be done without importing private state. Simpler and required: `run_rung01_replan4_smartdim.gd` still prints 0 failures. This package runs it.

**GUI acceptance.** Nut polygon AF 20, bore radius 5, Smart Dimension centre-to-flat and diameter. No `coincident: failed` left on screen. Exit, then File → New (WP2), and the new part accepts a sketch.

**Depends on.** Nothing to compile. Merge any time relative to WP2 and WP3.

### WP2 — New, Undo, and Exit recover; a bare export name uses the folder on screen

P0.1 (shell half) and P1.5.

**Scope.** `main.gd` only. Do not change the first-key numeric path, the dialog-quit guards from replan 4, or `_export_3mf_start_dir` / `_export_3mf_filename` except where the accept path joins a bare name.

**Behaviour — session shell.**

- `_on_exit_sketch_pressed`: call `exit_sketch()`. If `sketch_mode.active` is still true, call `cancel()` and set the status to `Sketch edit discarded — last saved profile kept`. If Exit already cleared `active`, leave the status WP1 set (`Sketch edit discarded — …` or `Sketch saved`).
- `_do_new`: if the session is still active after `exit_sketch()`, call `cancel()` before `new_document()`. The final status is the existing New sentence. `sketch_mode.active` is false. A ground sketch can start.
- `edit_undo`: after `view.undo()`, if the session is active and `editing_fid` is non-empty, call `begin_edit(editing_fid)`. If that returns false, call `cancel()`. Do not call `graph_update_sketch` from undo. The final status is `Undo`. It does not contain `Failed to update sketch`.
- These three use methods that already exist (`exit_sketch`, `cancel`, `begin_edit`), so WP2 does not wait for WP1. When both have merged, Exit discards inside `exit_sketch` and the `active` branch in main does not run.

**Behaviour — bare export name.**

- In the EXPORT_3MF accept path, when the typed text has no directory separator and is not absolute, the written path is `current_dir` at OK time joined with that filename. `current_dir` is whatever the dialog shows after the user has opened a folder. HOME is used only when HOME is that directory.
- Absolute typed paths, including the glued `.3mf` + absolute tail, stay on `_resolve_export_3mf_path`.
- Cancel, Escape, and a window close while the dialog is up still do not quit (replan 4). Do not enable `use_native_dialog`.

**Headless acceptance** (`run_rung01_replan5_shell.gd`) at 1280×800.

- Build a rectangle, Extrude, reopen the sketch from the timeline, delete one edge, click Exit Sketch. `active` is false. Status does not contain `Failed to update sketch`. The body is still there.
- Repeat the open-profile edit. Click Edit → Undo, then Exit Sketch. Final status does not contain `Failed to update sketch`. `active` is false.
- With a session left active on an open profile (delete the edge, do not exit), click File → New. Status is the New sentence and does not contain `Failed to update sketch`. `active` is false. `view.doc.graph_features()` is empty. Click Sketch on the ground and draw a circle. Status contains `Circle`.
- The test clicks the menu rows and the Exit button with `_x11_click`. It does not call `cancel`, `exit_sketch`, or `new_document`.
- Export: create a directory under `/tmp` that is not `HOME`. Open File → Export 3MF by clicking the menu row. Click into that directory in the dialog (a real row click, not an assignment to `current_dir` or `current_path`). `_x11_click` the name line, `_x11_type` `nut.3mf`, click OK. The file exists in that directory. Status starts with `Exported 3MF → ` and the path is that directory plus `nut.3mf`. The process is still running. A second export with an absolute path still writes that absolute path.

**GUI acceptance.** At 1280×800, force the open profile, Exit, and the status is clear. File → New, sketch a circle. Export a bare `nut.3mf` into a folder that was opened in the dialog and is not HOME. The process id is unchanged.

**Depends on.** Nothing. Merge any time.

### WP3 — Opposite face, and the focus signals fire once

P1.4 and P2.7.

**Scope.** `viewport_interaction.gd` and `sketch_context_chrome.gd`. The dim-blank and Distance first-key replace (replan 4) stays. Do not change `_distance_replace_next`, `_dim_replace_next`, or the generation counters except to stop a re-entrant `select_all` / `grab_focus` inside `focus_entered`.

**Behaviour — face.**

- Middle-button drag and Alt+left orbit, while Up To Surface is armed, do not emit `Up To Surface face pick cancelled`, do not call `_disarm_up_to_face_pick`, and do not set `_up_to_face_pick_consumed`.
- A left click that hits no face leaves the pick armed. Status may be `Click a model face for Up To Surface`. The next left click can still hit.
- Right click and Escape still cancel, with the existing sentence.
- `Opposite face` is a visible button on the Up To Surface panel. It chooses the target-body face farthest along the negative sketch normal, assigns it through the same `set_up_to_face` the viewport pick uses, and enables Extrude. The stored extrude param `to_face` is that face id. A top-face sketch of a 10 mm solid gets the face at z ≈ 0.
- A Front or Right view click on the visible bottom face still sets the same id. Standard views are the view buttons, not a scripted camera pitch.

**Behaviour — log spam.**

- `select_all` and `grab_focus` do not run inside the `focus_entered` handler. One deferred select remains, and the existing generation counter cancels it once typing has started, so the second digit still appends.
- After a dim-blank click and after opening the Smart Dimension popup, Godot's log does not contain `Attempt to disconnect a nonexistent connection` or `Signal 'focus_entered' is already connected` for the root `Window`. The same for `tree_exited`.

**Headless acceptance** (`run_rung01_replan5_face.gd`) at 1280×800.

- Closed blank, sketch on the top face, Finish op Cut, Finish end Up To Surface. Extrude is disabled. Click `Opposite face` with `_x11_click`. Extrude is enabled. `up_to_face_id` equals the bottom face. Press Extrude. The new feature's `to_face` is that face. The test does not call `set_up_to_face`.
- Fresh arm: choose Up To Surface, middle-drag on the viewport (orbit), then click the bottom face in Front view (click the Front view control, then `_x11_click_screen` on the face). Status does not contain `cancelled`. `up_to_face_id` is the bottom face.
- Right click while armed. Status contains `Up To Surface face pick cancelled`.
- `run_rung01_replan4_numeric.gd` and `run_rung01_replan4_smartdim.gd` still pass. A captured Godot log from the face script has no root-window `focus_entered` / `tree_exited` connect or disconnect error.

**GUI acceptance.** At 1280×800, Cut, Up To Surface, click `Opposite face`, Extrude. The jaw or hole cut uses the bottom face. Orbit while the pick is armed does not cancel it. The Godot log during a dim click is free of those window signal errors.

**Depends on.** Nothing. Merge any time. The jaw cut this button serves is WP1's trim; the button is testable on a plain top-face circle.

### WP4 — The walk fails when the GUI path fails

Last. This is the only package that edits `run_rung01_wrench.gd`.

**Scope.** Extend the walk. Extend `tools/lint_rung01_e2e.py`. Append the `run_rung01_replan5_*.gd` scripts to the `test-godot` recipe after the `run_rung01_replan4_*.gd` lines. `tools/check_rung01.py` stays as it is.

If the walk fails on a bug in a file another package owns, and that package has already merged, WP4 may edit that file so the walk passes. It does not take the file over for anything else. Slot, fillets, and Timeline Distance 10→14 are this carve-out: the walk already contains those checks. If they fail once the jaw trim and the face pick work, fix the owning file. If they pass, do not edit them.

P2.6 is a measurement, not a checker edit. After the blank extrude, read the head centre from the mesh. Print it. If `check_rung01.py wrench` would fail orientation, the walk fails too. Do not add `--allow-mirror`. If the head centre X is negative, the ground sketch's +X is the wrong model direction; fix that plane so a circle placed at sketch (200, 0) lands at model +X. If the head centre X is near +200 and the checker still reports `flipX`, the jaw opens on the mirror side; fix the trim keep-side so the shaft-side click opens the jaw toward the pivot. Both fixes are the carve-out above.

**Click path.** Power Trim and the recovery clicks use `_x11_click_screen` with no frame between mouse-down and mouse-up. Numeric line edits keep the replan-4 `_x11_click` / `_x11_type` path.

**Changes to the walk** (keep every check that already describes the handout):

1. **Recovery, before the nut.** New document. Rectangle on the ground, Extrude, reopen from the timeline, delete one edge, click Exit Sketch. Assert `active` is false and the status does not contain `Failed to update sketch`. File → New. Assert the New sentence, `active` is false, and a ground circle can be drawn. Then File → New again and start the existing nut. A stuck session fails here, before any checker credit.
2. **Jaw sketch matches the GUI.** On the top face, after the Ø10 hole, draw the Ø45 at the head as a sketch circle (B2.8). Center Three Point rectangle, angle 45°, width 20. Construction centreline perpendicular to the long sides through the head centre. Power Trim with one `_x11_click_screen` on the shaft side (toward the origin). Status contains `Trimmed open jaw`. Profile closed. The existing Up To Surface cut, slot, and fillet checks stay, and they run on this jaw.
3. **Opposite face.** The walk may click `Opposite face` or click the bottom face in Front view. It does not call `set_up_to_face`. It does not assign a camera pitch as the only way to see the bottom. Extrude stays disabled until the face is chosen.
4. **Bare name, once.** One export types a bare filename after the dialog has been browsed to the output directory. The file is in that directory. Absolute-path exports used by the checker may stay. Cancel-once and the window-close check from replan 4 stay.
5. **Checker invocations** stay `nut`, `wrench`, and `thick` with `14`. Exit code 0. Do not add `--allow-mirror`. Do not delete a failing check to shrink the failure count.

**Lint.** Extend `tools/lint_rung01_e2e.py`:

- The walk and `game/tests/run_rung01_replan5_*.gd` fail the lint if they contain `sketch_mode.cancel(`, `sketch_mode.exit_sketch(`, `sketch_mode.trim_at(`, `new_document(`, `graph_update_sketch(`, `set_up_to_face`, `focus_dim_for_typing`, `focus_distance_for_typing`, an assignment to `.text`, or `set_extrude_distance`.
- The walk's Power Trim click and its recovery click fail the lint if the source awaits between `pressed = true` and the matching `pressed = false`.
- Existing walk forbiddens stay (`infer_enabled`, `text_submitted.emit`, `.value` assignment, `interaction._input`, `id_pressed.emit`, `item_selected.emit` outside `_pick_end`, `current_path` assignment, root size other than 1280×800).
- `make test` runs the lint before the Godot suites. The walk still `quit(1)` when `failures > 0`.

**Depends on.** WP1, WP2, and WP3 merged.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | Exit after an open-loop edit discards the edit, ends the session, and a new circle can be drawn. Perpendicular Power Trim on a Center Three Point jaw with a redrawn Ø45 reports `Trimmed open jaw` and a closed profile. A near-parallel centreline does not open the rectangle and does not trap Exit. Nut centre-to-flat and bore diameter exist; a failed coincident is reverted; centres 200 still passes. |
| WP2 | Exit, Undo, and File → New each end on a status that is not `Failed to update sketch`, and New accepts a ground circle. A bare `nut.3mf` is written in the folder the dialog was browsed to. |
| WP3 | `Opposite face` stores the bottom face and enables Extrude. Orbit does not cancel an armed pick. A dim click does not log root-window `focus_entered` / `tree_exited` connect errors. Replan-4 numeric and Smart Dimension scripts still pass. |
| WP4 | Recovery, the GUI jaw click, and the rest of the handout inside `run_rung01_wrench.gd`. nut 7/7, wrench 28/28, thick 4/4. Lint clean. 0 walk failures. |

## Merge order

```
WP1 ──┐
WP2 ──┼── WP4
WP3 ──┘
```

WP1, WP2, and WP3 merge in any order. They do not share files. WP4 is last. sx-026 runs on the build that contains WP4.

## sx-026 GUI critique checklist

One session. Desktop **1280×800**. Mouse and keyboard only. No property JSON, no Box, no Timeline edit on the nut. Record status text after each step. Export only through File → Export 3MF. Note the process id at launch and again after the dialog steps and after the recovery steps. If the status becomes `Failed to update sketch`, try Exit, Undo, and New before killing the process, and record whether each one cleared it.

Pass bar: every row below is WORKS, the three checker commands exit 0, `run_rung01_wrench.gd` prints 0 failures on this OCCT 8.0.1 build, score ≥ 9. A trim whose status is `Trim failed` fails B2. A document that needs a process restart fails R0.

| # | Do this | Pass |
|---|---|---|
| R0 | Rectangle, Extrude, reopen the sketch, delete one edge, Exit Sketch. Then File → New | Status is the discard sentence, then the New sentence. It does not stay `Failed to update sketch`. A ground circle can be drawn. Process id unchanged |
| A1 | File → New | `New — empty part` and no body |
| A2 | Sketch on the ground plane | `Sketch on ground (XY)` |
| A3 | Polygon, type `20` | Status contains `Polygon AF 20`. Flats at ±10 |
| A4 | Circle, type `5` | Status contains `Circle r=5` and `Ø10` |
| A5 | Smart Dimension, centre to a flat, then the bore circle | Centre-to-flat near 10. Bore diameter 10. Solve is not left `failed`. No sticky `Failed to update sketch` |
| A6 | Click Distance, type `7.5`, do not press Enter, Extrude | Status contains `Extrude Blind 7.5000 mm`. Thickness 7.5. No Timeline edit |
| D1 | Export. Browse to a folder that is not HOME. Type the bare name `nut.3mf`. Save. Also Cancel once | File is in that folder. Status `Exported 3MF → <path>`. Process id unchanged. Checker nut 7/7 |
| B1 | New. Circle radius `10` at the origin, then radius `22.5` at (200, 0). Smart Dimension `200`. Upper and lower tangents. Extrude Blind 10. Thin off | Ø20 and Ø45. Centres 200 apart. No `open profile`. No Box. Bbox 232.5 × 45 × 10. Head centre at +X |
| B2 | Top face: Ø10 hole, redraw Ø45 at the head, Center Three Point jaw AF 20 at 45°, centreline across the jaw through the head, Power Trim on the shaft side. Cut, Up To Surface, Opposite face or a Front-view click on the bottom, Extrude | Status `Trimmed open jaw`. Extrude disabled until the face is chosen. Jaw open at z = 0.5 and z = 9.5 |
| B3 | Slot 160 × 10 × 2.5 blind | Slot floor at z = 7.5 |
| B4 | Fillet R10 at the neck, R1 on top, bottom, and slot floor. Then R1.5 on the slot floor | R1 commits. R1.5 status contains `1.25` and the solid does not change |
| B5 | Timeline, base extrude Distance `14`, Enter, click away, export `wrench-t14.3mf`. Then jaw width 20 → 21 | Thick 4/4 (Z = 14). Angle still 45°. Wrench checker 28/28 |
| H | `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` | `0 failures`. Lint clean. The log shows the recovery Exit, the shaft-side Power Trim click with no yield between down and up, and `Trimmed open jaw` |

Score recovery, the jaw trim, and the headless count separately. A wrench that never shows `Trimmed open jaw` stays under 9.

## Out of scope

- Typed numeric replace, finish-bar Distance 7.5, and dialog Cancel / Escape / window-close survival (replan 4). WP3 only stops the focus-signal spam around that replace. The replace itself stays.
- Smart Dimension centres 200 (replan 4 WP3). WP1 must keep that script green.
- Camera number keys versus sketch digits (replan 2). Standard views outside a sketch stay.
- Variant chips versus the finish bar at 1280×800 (replan 2).
- Empty-sketch Exit confirm (replan 2).
- Nut AF 20, AC 23.094, bore Ø10, and the nut's closed mesh, once A6 has set the thickness.
- Insert Box as the wrench blank.
- A kernel change to chain tolerance, a new constraint type, `use_native_dialog`, or committing an open profile so the failed extrude stays in the timeline.
- Editing `tools/check_rung01.py` or passing `--allow-mirror`. Orientation is fixed in the model when the checker reports a mirror.
- Rungs 2–8, threads, and a datum tree beyond Top = XY.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `09fb9b22` / `33f20902`.
