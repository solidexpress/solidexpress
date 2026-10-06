# Replan 12 WP3 — sketch clicks next to the left rail land; Save As keeps the sketch and suggests an `.sxp` name

You are a BUILD agent. Edit only `game/scripts/main.gd` (the four hunks below) and the save check of `game/tests/run_rung01_replan11_ux.gd`. Add `game/tests/run_rung01_replan12_rail.gd` and `game/tests/run_rung01_replan12_dialog.gd`.

`main.gd` hunks you own (search by name; line numbers are `2606160c`): `_build_ui`, the `left_stack` block (~476); `_reflow_left_stack` (~1861); `_show_file_dialog` (~3116); `_save_current` (~3141). Do **not** touch `open_feature_params` (~1889): WP6 owns it.

## The bugs

1. `left_stack` is a `VBoxContainer` with the default `MOUSE_FILTER_STOP`. It is sized by the tallest card, not by what is visible. On `2606160c` after a face sketch opens it measures **322 × 694 px** (`get_global_rect()`), while the sketch rail on top of it ends at x = 145. `Viewport.gui_get_hovered_control()` over the canvas next to the rail returns `LeftStack`, so `viewport_interaction._input` never sees the press. The sx-032 walker lost the first click on the pivot-circle centre (decision 3 in `rung-01-replan-12.md`). After the fix the stack is **141 × 560 px** and the hovered control is `Interaction`.
2. `_save_current` calls `sketch_mode.exit_sketch()` before saving. File → Save As (and Ctrl+S on a saved file) drops the open sketch session; the sketch becomes a feature and the user is thrown back to Model.
3. `_show_file_dialog` does not set `current_file` for `SAVE_AS`, so Godot keeps the previous dialog's file name (`blank.3mf`, `nut.3mf`) in a `*.sxp` dialog.

## Decisions (see `rung-01-replan-12.md` 3, 14 and 15)

- `left_stack.mouse_filter = MOUSE_FILTER_IGNORE`. Children (cards, rail) keep their own filters, so they still take clicks.
- `left_stack.minimum_size_changed` is connected (deferred) to `left_stack.reset_size`, and `_reflow_left_stack` ends with `left_stack.reset_size()`. A `VBoxContainer` grows to fit its children but never shrinks without this.
- Saving inside a sketch: capture the camera pose, `exit_sketch()` (it returns the sketch feature id), save, then `begin_edit(fid)`, `_on_sketch_session_started("Editing sketch")`, `view.refresh_sketch_pads(...)`, restore the pose, select the Select tool. The status stays `Saved <path>` or `Save FAILED: <path>`.
- Save As pre-fills `current_file` with the open document's file name, or `untitled.sxp`, and sets `current_dir` when the path is absolute.

## Diff (measured; apply by function name)

```diff
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
index 9af07ea..9516f49 100644
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -478,6 +478,8 @@ func _build_ui() -> void:
 	left_stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
 	left_stack.position = Vector2(_CHROME_PAD, 48.0)
 	left_stack.add_theme_constant_override("separation", int(_STACK_GAP))
+	left_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
+	left_stack.minimum_size_changed.connect(left_stack.reset_size, CONNECT_DEFERRED)
 	ui.add_child(left_stack)
 
 	# Mode overlays sit under chrome and stay hidden in Model (layout suite).
@@ -1879,6 +1881,7 @@ func _reflow_left_stack() -> void:
 			used += maxf(cc.size.y, cc.get_combined_minimum_size().y) + _STACK_GAP
 		var card_h := minf(_CARD_H, maxf(80.0, max_h - used))
 		card_box.custom_minimum_size = Vector2(_CARD_W, card_h)
+	left_stack.reset_size()
 	# Rail width may have changed (Modify ↔ Palette ↔ Sketch): re-dock the
 	# floating panels so they never land on top of the icons.
 	_sync_bottom_docks()
@@ -3117,6 +3121,10 @@ func _show_file_dialog(action: FileAction, mode: FileDialog.FileMode, filter: St
 	_file_action = action
 	file_dialog.file_mode = mode
 	file_dialog.filters = PackedStringArray([filter])
+	if action == FileAction.SAVE_AS:
+		file_dialog.current_file = current_path.get_file() if current_path != "" else "untitled.sxp"
+		if current_path.is_absolute_path():
+			file_dialog.current_dir = current_path.get_base_dir()
 	if action == FileAction.EXPORT_3MF:
 		var dir := _export_3mf_start_dir()
 		if dir != "":
@@ -3142,11 +3150,21 @@ func _save_current() -> void:
 	if current_path == "":
 		_show_file_dialog(FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
 		return
+	var reenter_fid := ""
+	var reenter_pose: Dictionary = {}
 	if sketch_mode != null and sketch_mode.active:
-		sketch_mode.exit_sketch()
-	if view.save(current_path):
+		reenter_pose = camera.capture_pose()
+		reenter_fid = sketch_mode.exit_sketch()
+	var saved := view.save(current_path)
+	if saved:
 		_last_saved_revision = view.doc.revision()
 		_push_recent(current_path)
+	if reenter_fid != "" and sketch_mode.begin_edit(reenter_fid):
+		_on_sketch_session_started("Editing sketch")
+		view.refresh_sketch_pads(sketch_mode.editing_fid)
+		camera.apply_pose(reenter_pose)
+		sketch_mode.set_tool(SketchMode.Tool.SELECT)
+	if saved:
 		_on_status("Saved " + current_path)
 	else:
 		_on_status("Save FAILED: " + current_path)
```

## Update `run_rung01_replan11_ux.gd`

The old check asserted that saving an open sketch **leaves** the session (the behaviour this WP removes). Replace it with the new expectation and close the session so the rest of the script is unchanged. The check count stays 12.

```diff
diff --git a/game/tests/run_rung01_replan11_ux.gd b/game/tests/run_rung01_replan11_ux.gd
index 9e6441b..f42b378 100644
--- a/game/tests/run_rung01_replan11_ux.gd
+++ b/game/tests/run_rung01_replan11_ux.gd
@@ -166,9 +166,12 @@ func _run() -> void:
 	main._save_current()
 	await process_frame
 	var saved := _sxp_text(save_path)
-	check((saved.contains("\"type\": \"sketch\"") or saved.contains("sketch")) and not sm.active,
-			"save of an open sketch writes a sketch feature and leaves the session (active=%s has_sketch=%s)" % [
+	check((saved.contains("\"type\": \"sketch\"") or saved.contains("sketch")) and sm.active,
+			"save of an open sketch writes a sketch feature and keeps the session (active=%s has_sketch=%s)" % [
 				str(sm.active), str(saved.contains("sketch"))])
+	if sm.active:
+		sm.cancel()
+		await process_frame
 	if FileAccess.file_exists(save_path):
 		DirAccess.remove_absolute(save_path)
 
```

## Tests (create both)

`run_rung01_replan12_rail.gd` places a box, opens a face sketch on `+Z`, arms Circle, then pushes real motion/press/release events 30 px right of the rail with `Viewport.push_input`, reads `gui_get_hovered_control()`, and checks the circle appears. It then runs File → Save As (`main._save_current` with `current_path` set) and checks the session is still active, the finish bar is visible, the circle is still there, the saved file contains a sketch feature and Extrude on the profile works.

`game/tests/run_rung01_replan12_rail.gd`

```gdscript
# Rung 1 replan 12 WP3 — a face sketch keeps the canvas next to the left rail clickable after a
# face selection, and Save As inside a sketch keeps the session.
# Real events: Viewport.push_input (motion, press, release), never ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_rail.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 WP3 rail clicks and Save As")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _entity_count(sm: SketchMode) -> int:
	return sm.sketch.entity_ids().size()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	await FilmUI.place_primitive(ctx, "box")
	var body: String = ctx.view.selected_body
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "box placed, +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	var sm: SketchMode = main.sketch_mode
	check(sm.active, "face sketch is active")

	var rail: Control = main.sketch_toolbar
	check(rail.visible, "sketch rail is visible")
	var stack: Control = main.left_stack
	var rail_right := rail.get_global_rect().end.x
	var stack_rect := stack.get_global_rect()
	print("  rail right edge %.1f, left_stack rect %s" % [rail_right, str(stack_rect)])
	check(stack_rect.end.x <= rail_right + 12.0,
			"left_stack is no wider than the visible rail (right edge %.1f vs rail %.1f)" % [
			stack_rect.end.x, rail_right])
	check(stack.mouse_filter == Control.MOUSE_FILTER_IGNORE, "left_stack ignores the mouse")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.wait_frames(self, 3)
	check(sm.tool == SketchMode.Tool.CIRCLE, "Circle tool is active")
	var vp_size := Vector2(ROOT_SIZE)
	var y := vp_size.y * 0.5
	var pos := Vector2(rail_right + 30.0, y)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	await process_frame
	var hovered := root.gui_get_hovered_control()
	print("  hovered at (%.0f, %.0f): %s" % [pos.x, pos.y, str(hovered)])
	check(hovered == main.interaction, "the control under the pointer is the viewport Interaction (got %s)" % str(hovered))
	var before := _entity_count(sm)
	await _push_click(pos)
	await _push_click(pos + Vector2(40.0, 0.0))
	check(_entity_count(sm) == before + 1,
			"Circle click 30 px right of the rail adds a circle (entities %d → %d)" % [before, _entity_count(sm)])

	# Save As inside the sketch keeps the session.
	sm.set_tool(SketchMode.Tool.SELECT)
	var fid_before := str(sm.editing_fid)
	var path := "/tmp/sx-replan12-saveas.sxp"
	DirAccess.remove_absolute(path)
	main.current_path = path
	main._save_current()
	await process_frame
	await process_frame
	check(FileAccess.file_exists(path), "Save As wrote %s" % path)
	check(sm.active, "sketch session is still active after Save As")
	check(sm.editing_fid != "", "session edits a saved sketch feature (%s, was '%s')" % [sm.editing_fid, fid_before])
	check(sm.tool == SketchMode.Tool.SELECT, "tool is Select after Save As")
	check(main.sketch_chrome != null and main.sketch_chrome.visible, "sketch finish bar is visible")
	check(_entity_count(sm) == before + 1, "the circle drawn before Save As is still in the sketch")
	var doc2 := SxDocument.new()
	check(doc2.load(path), "saved file loads")
	var has_sketch := false
	for f in doc2.graph_features():
		if str(f.get("type", "")) == "sketch":
			has_sketch = true
	check(has_sketch, "saved file contains the sketch")
	var feats_before: int = ctx.view.doc.graph_features().size()
	main._on_sketch_finish("new", 5.0)
	await process_frame
	await process_frame
	check(ctx.view.doc.graph_features().size() > feats_before,
			"Extrude on the profile works after Save As (%d → %d features)" % [
			feats_before, ctx.view.doc.graph_features().size()])
	DirAccess.remove_absolute(path)
	main.queue_free()
	await process_frame
	await process_frame
```

`run_rung01_replan12_dialog.gd` opens Save As on an unsaved and on a saved document and reads `file_dialog.current_file`.

`game/tests/run_rung01_replan12_dialog.gd`

```gdscript
# Rung 1 replan 12 WP3 — Save As pre-fills a .sxp name, not the last export name.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_dialog.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 WP7 Save As dialog")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.file_dialog.current_file = "blank.3mf"
	main.current_path = ""
	main._save_current()
	await process_frame
	check(main.file_dialog.visible, "Save As dialog opens for an unsaved document")
	check(main.file_dialog.current_file == "untitled.sxp",
			"unsaved document pre-fills untitled.sxp (got `%s`)" % main.file_dialog.current_file)
	main.file_dialog.hide()
	main.file_dialog.current_file = "blank.3mf"
	main.current_path = "/tmp/pre-cut.sxp"
	main._show_file_dialog(main.FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
	await process_frame
	check(main.file_dialog.current_file == "pre-cut.sxp",
			"a saved document pre-fills its own file name (got `%s`)" % main.file_dialog.current_file)
	main.file_dialog.hide()
	main.queue_free()
	await process_frame
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
```

## Commands and expected output

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_rail.gd
#   17 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_dialog.gd
#   3 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan11_ux.gd
#   12 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_layout_tests.gd
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan11_chrome.gd
```

The last two must print the same counts as on `2606160c` (see the whole-suite table in `rung-01-replan-12.md`). They guard the layout the stack change touches.

**Red on `2606160c`:** `run_rung01_replan12_rail.gd` `17 checks, 10 failures` (stack right edge 326 vs rail 145, `left_stack ignores the mouse`, hovered `LeftStack`, no circle added, session lost after Save As, finish bar gone, no sketch in the saved file, Extrude failing); `run_rung01_replan12_dialog.gd` `3 checks, 2 failures` (`got blank.3mf`).

## Do not

- Move, resize or restyle any card or the rail to make room. The fix is the mouse filter and the size reset only.
- Push a `ctx.main.interaction._input(event)` in a test: the bug is in the Control hit-test, so the test must go through `Viewport.push_input`.
- Change the `.sxp` writer or `view.save`.
