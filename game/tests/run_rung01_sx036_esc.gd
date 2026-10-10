# sx-036 A8b — Esc keeps a committed sketch, part-mode redo, no measure on
# Select / while a dimension editor is open, Up To Surface does not eat a
# Circle click, and Save As keeps sketch undo.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx036_esc.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const SELECT_HINT := "Select — click geometry, or a dimension label to edit it"

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 sx-036 Esc keep, redo, measure, Up To Surface, Save As undo")
	FilmUI.reset_fail_count()
	await test_jaw_esc_keeps()
	await test_empty_sketch_still_cancels()
	await test_part_mode_redo()
	await test_dim_editor_clears_measure()
	await test_up_to_surface_does_not_eat_circle()
	await test_save_as_keeps_undo()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_jaw_esc_keeps() -> void:
	print("- A8b Esc ladder keeps a committed Jaw")
	var ctx := await _boot()
	var body := await _box_body(ctx)
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	if top == "":
		await _shutdown(ctx)
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm.active, "face sketch is open")
	await _zoom(ctx, sm.to_model(Vector2(15, 5)), 80.0)
	var before := _count_type(ctx, "sketch")
	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
			"Jaw is armed")
	await _click_uv(ctx, vp, Vector2(15, 5))
	await _click_uv(ctx, vp, Vector2(45, 5))
	await _click_uv(ctx, vp, Vector2(15, 15))
	await process_frame
	var lines := _profile_lines(sm)
	check(lines == 4, "Jaw committed four lines (got %d)" % lines)
	_status_log.clear()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await process_frame
	check(_status_has(SELECT_HINT) or str(ctx.main.status_label.text) == SELECT_HINT,
			"Select reads the geometry hint (got `%s`)" % ctx.main.status_label.text)
	await _click_uv(ctx, vp, Vector2(15, 15))
	await process_frame
	check(sm.selected.size() == 1, "one Jaw line is selected (got %d)" % sm.selected.size())
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	check(mo != null and not mo.has_anchor() and mo.marks.is_empty(),
			"Select line click creates no measure (anchor=%s marks=%d)" % [
				str(mo.has_anchor() if mo != null else false),
				mo.marks.size() if mo != null else -1])
	_status_log.clear()
	await _push_key_local(vp, KEY_ESCAPE, false, false)
	check(sm.active, "first Esc keeps the sketch open")
	check(sm.selected.is_empty(), "first Esc clears the selection")
	check(_status_has("Selection cleared — Esc again exits the sketch"),
			"first Esc is the selection rung (log: %s)" % str(_status_log))
	check(not _status_has("Measure cleared"),
			"selection Esc is not Measure cleared (log: %s)" % str(_status_log))
	check(_profile_lines(sm) == 4, "lines survive the selection clear")
	_status_log.clear()
	await _push_key_local(vp, KEY_ESCAPE, false, false)
	await process_frame
	check(not sm.active, "second Esc leaves the sketch")
	check(_status_has("Sketch saved"), "second Esc saves (log: %s)" % str(_status_log))
	check(not _status_has("Sketch cancelled"),
			"second Esc does not cancel (log: %s)" % str(_status_log))
	check(_count_type(ctx, "sketch") == before + 1,
			"timeline sketch count +1 (before %d)" % before)
	var fid := _last_feature_id(ctx, "sketch")
	var loaded: SxSketch = ctx.view.doc.graph_get_sketch(fid)
	var kept := 0
	if loaded != null:
		for id in loaded.entity_ids():
			var info: Dictionary = loaded.entity_info(id)
			if str(info.get("type", "")) == "line" and not loaded.is_construction(id):
				kept += 1
	check(kept == 4, "saved Jaw still has four lines (got %d)" % kept)
	await _shutdown(ctx)


func test_empty_sketch_still_cancels() -> void:
	print("- empty sketch with a dropped point still cancels")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3.ZERO, 80.0)
	var before := _count_type(ctx, "sketch")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(sm.has_pending_draw_point(), "circle centre is pending")
	await _push_key_local(vp, KEY_ESCAPE, false, false)
	check(sm.active and not sm.has_pending_draw_point(), "first Esc drops the point")
	await _push_key_local(vp, KEY_ESCAPE, false, false)
	check(not sm.active, "second Esc cancels the empty sketch")
	check(_count_type(ctx, "sketch") == before, "empty cancel adds no sketch feature")
	await _shutdown(ctx)


func test_part_mode_redo() -> void:
	print("- part-mode Ctrl+Shift+Z and Ctrl+Y redo")
	var ctx := await _boot()
	await FilmUI.place_primitive(ctx, "box")
	await FilmUI.place_primitive(ctx, "cylinder")
	await process_frame
	var n := ctx.view.doc.body_ids().size()
	check(n >= 2, "two bodies placed (got %d)" % n)
	var vp: Viewport = ctx.main.get_viewport()
	_release_focus(vp)
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	await process_frame
	check(ctx.view.doc.body_ids().size() == n - 1, "Ctrl+Z undoes the last body")
	check(str(ctx.main.status_label.text) == "Undo" or _status_has("Undo"),
			"Ctrl+Z status is Undo (got `%s`)" % ctx.main.status_label.text)
	_release_focus(vp)
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, true)
	await process_frame
	check(ctx.view.doc.body_ids().size() == n, "Ctrl+Shift+Z restores the last body")
	check(str(ctx.main.status_label.text) == "Redo",
			"Ctrl+Shift+Z status is Redo (got `%s`)" % ctx.main.status_label.text)
	_release_focus(vp)
	await _push_key_local(vp, KEY_Z, true, false)
	await process_frame
	check(ctx.view.doc.body_ids().size() == n - 1, "Ctrl+Z undoes again")
	_release_focus(vp)
	_status_log.clear()
	await _push_key_local(vp, KEY_Y, true, false)
	await process_frame
	check(ctx.view.doc.body_ids().size() == n, "Ctrl+Y restores the last body")
	check(str(ctx.main.status_label.text) == "Redo",
			"Ctrl+Y status is Redo (got `%s`)" % ctx.main.status_label.text)
	await _shutdown(ctx)


func test_dim_editor_clears_measure() -> void:
	print("- dimension editor never starts a measure; Esc and Enter clear it")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var ix: ViewportInteraction = ctx.main.interaction
	await _zoom(ctx, Vector3.ZERO, 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(10, 0))
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv(ctx, vp, Vector2(10, 0))
	await process_frame
	check(sm.dimensions.size() >= 1, "Smart Dim created a label (n=%d)" % sm.dimensions.size())
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var rects: Array = sm.dimension_label_screen_rects() if sm.has_method("dimension_label_screen_rects") else []
	check(not rects.is_empty(), "dimension label has a screen rect")
	if rects.is_empty():
		await _shutdown(ctx)
		return
	var hit: Vector2 = (rects[0]["rect"] as Rect2).get_center()
	check(FilmUI.require_on_screen(ctx, hit, "dimension label"), "label click is on screen")
	await _click_screen(vp, hit)
	await process_frame
	await process_frame
	var mo: MeasureOverlay = ix.measure_overlay
	check(ix._dim_edit_owns_keys(), "label click opens the dimension editor")
	check(not mo.has_anchor() and mo.marks.is_empty(),
			"opening the editor leaves no ✕ (anchor=%s marks=%d)" % [
				str(mo.has_anchor()), mo.marks.size()])
	await _motion(vp, hit)
	await _motion(vp, FilmUI.model_to_screen(ctx, sm.to_model(Vector2(0, 10))))
	await process_frame
	check(ix._dim_edit_owns_keys(), "editor stays open while the pointer moves")
	check(not mo.has_anchor() and mo.marks.is_empty() and not _overlay_has_delta(mo),
			"motion while the editor is open starts no measure (marks=%d labels=%s)" % [
				mo.marks.size(), _overlay_texts(mo)])
	await _push_key_local(vp, KEY_ESCAPE, false, false)
	await process_frame
	await process_frame
	check(not ix._dim_edit_owns_keys(), "Esc closes the editor")
	check(not mo.has_anchor() and mo.marks.is_empty(),
			"Esc clears any ✕ the editor left (anchor=%s marks=%d)" % [
				str(mo.has_anchor()), mo.marks.size()])
	await _click_screen(vp, hit)
	await process_frame
	await process_frame
	check(ix._dim_edit_owns_keys(), "second label click reopens the editor")
	var edit: LineEdit = ix._dim_edit_line
	if edit != null and not edit.has_focus():
		edit.grab_focus()
		await process_frame
	await _push_key_local(vp, KEY_ENTER, false, false)
	await process_frame
	await process_frame
	check(not ix._dim_edit_owns_keys(), "Enter closes the editor")
	check(not mo.has_anchor() and mo.marks.is_empty(),
			"Enter clears any ✕ the editor left (anchor=%s marks=%d)" % [
				str(mo.has_anchor()), mo.marks.size()])
	await _shutdown(ctx)


func test_up_to_surface_does_not_eat_circle() -> void:
	print("- Up To Surface does not eat a Circle centre click")
	var ctx := await _boot()
	var body := await _box_body(ctx)
	var top := _face_along(ctx, body, 1)
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(sm.active, "face sketch is open for the circle")
	await _zoom(ctx, sm.to_model(Vector2(8, 8)), 80.0)
	var op: OptionButton = chrome.find_child("FinishOp", true, false)
	var end: OptionButton = chrome.find_child("FinishEnd", true, false)
	check(op != null and end != null, "finish Op and End exist")
	if op != null:
		op.select(1)
		op.item_selected.emit(1)
	if end != null:
		end.select(3)
		end.item_selected.emit(3)
	await process_frame
	check(chrome.get_finish_end() == "to_face", "End is Up To Surface")
	check(chrome.wants_face_pick() and not chrome.face_pick_explicit(),
			"Up To Surface arms the row without an explicit face pick")
	check(str(chrome.up_to_face_id).strip_edges() == "", "no face stored yet")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var n0 := sm.sketch.entity_ids().size()
	await _click_uv(ctx, vp, Vector2(8, 8))
	await process_frame
	check(sm.has_pending_draw_point(), "Circle centre click placed the centre")
	check(str(chrome.up_to_face_id).strip_edges() == "",
			"Circle centre click did not pick a face (id=%s)" % chrome.up_to_face_id)
	var face_label := ""
	var face_node: Label = chrome.find_child("UpToFaceLabel", true, false)
	if face_node != null:
		face_label = str(face_node.text)
	check(not face_label.contains("z 0"),
			"face label is not a picked face (got `%s`)" % face_label)
	check(sm.sketch.entity_ids().size() == n0, "centre click added no entity yet")
	await _shutdown(ctx)


func test_save_as_keeps_undo() -> void:
	print("- Save As keeps sketch undo")
	var ctx := await _boot()
	var body := await _box_body(ctx)
	var top := _face_along(ctx, body, 1)
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm.active, "face sketch is open for Save As")
	await _zoom(ctx, sm.to_model(Vector2(12, 4)), 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv(ctx, vp, Vector2(4, 4))
	await _click_uv(ctx, vp, Vector2(20, 4))
	await process_frame
	var n_ent := sm.sketch.entity_ids().size()
	check(n_ent >= 1, "line is in the sketch (entities=%d)" % n_ent)
	check(sm.can_undo(), "line is on the undo stack before Save As")
	var path := "/tmp/sx036-pre-cut.sxp"
	DirAccess.remove_absolute(path)
	ctx.main.current_path = path
	ctx.main._save_current()
	await process_frame
	await process_frame
	check(FileAccess.file_exists(path), "Save As wrote %s" % path)
	check(sm.active, "sketch stays open after Save As")
	var saved := str(ctx.main.status_label.text)
	check(saved.begins_with("Saved "), "status is Saved … (got `%s`)" % saved)
	_release_focus(vp)
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	await process_frame
	var st := str(ctx.main.status_label.text)
	check(st.begins_with("Undo:"), "Ctrl+Z after Save As undoes (got `%s`)" % st)
	check(sm.sketch.entity_ids().size() < n_ent,
			"undo removed the line (entities %d → %d)" % [n_ent, sm.sketch.entity_ids().size()])
	DirAccess.remove_absolute(path)
	await _shutdown(ctx)


func _overlay_has_delta(overlay: MeasureOverlay) -> bool:
	if overlay == null:
		return false
	for lab in overlay.labels:
		if typeof(lab) == TYPE_DICTIONARY and str(lab.get("text", "")).contains("Δ"):
			return true
	return false


func _overlay_texts(overlay: MeasureOverlay) -> String:
	if overlay == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for lab in overlay.labels:
		if typeof(lab) == TYPE_DICTIONARY:
			parts.append(str(lab.get("text", "")))
	return ", ".join(parts)


func _box_body(ctx: FilmContext) -> String:
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		check(false, "box body exists")
		return ""
	return str(ids[0])


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	if body == "" or ctx.view == null:
		return ""
	for f in ctx.view.doc.get_face_ids(body):
		var mid: Variant = ctx.view.doc.face_midpoint(str(f))
		if not (mid is Vector3):
			continue
		var z := (mid as Vector3).z
		if (z_sign > 0 and z > best_z) or (z_sign < 0 and z < best_z):
			best_z = z
			best = str(f)
	return best


func _count_type(ctx: FilmContext, kind: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("type", "")) == kind:
			n += 1
	return n


func _last_feature_id(ctx: FilmContext, kind: String) -> String:
	var last := ""
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("type", "")) == kind:
			last = str(f.get("id", ""))
	return last


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	if sm == null or sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _status_has(needle: String) -> bool:
	if needle == "":
		return false
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	if main.status_label != null and not main.status_label.has_meta("_sx036"):
		main.status_label.set_meta("_sx036", true)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _click_screen(vp, screen)


func _click_screen(vp: Viewport, pos: Vector2) -> void:
	await _motion(vp, pos)
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


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		check(false, "control to click exists")
		return
	await _click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


func _push_key_local(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	vp.push_input(up)
	await process_frame


