# Rung 1 replan WP6 — property panel select-all, opaque docks, Pick face row.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan_panel.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")



func _init() -> void:
	print("rung01 replan panel (WP6)")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)
	await _file_new(ctx)
	await _build_to_face_extrude(ctx)
	await _edit_distance_from_timeline(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _file_new(ctx: FilmContext) -> void:
	var popup: PopupMenu = ctx.main._file_popup
	popup.id_pressed.emit(0)
	await process_frame
	await process_frame


func _build_to_face_extrude(ctx: FilmContext) -> void:
	print("- box, then a circle extruded Up To Surface")
	# A faceless Up To Surface is refused (WP2). Place a box, sketch on the
	# top face, and click the bottom face before Extrude.
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(not ids.is_empty(), "box body exists")
	if ids.is_empty():
		return
	var body := str(ids[0])
	var top := _face_along(ctx, body, 1)
	var bottom := _face_along(ctx, body, -1)
	check(top != "" and bottom != "" and top != bottom, "top and bottom faces differ")
	if top == "" or bottom == "":
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "sketch session is open")
	if not sm.active:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Circle centre")
	await FilmUI.click_sketch(ctx, sm, Vector2(10, 0), "Circle radius")
	await process_frame
	var n := 0
	if sm.sketch != null:
		n = sm.sketch.entity_ids().size()
	check(n >= 1, "circle is on the sketch (%d entities)" % n)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var end_opt := chrome.find_child("FinishEnd", true, false) as OptionButton
	check(end_opt != null and end_opt.is_visible_in_tree(), "finish End option is visible")
	if end_opt != null:
		await FilmUI.click_control(ctx, end_opt, FilmUICues.alert("End", "Open extrude end"))
		# Menu pick: select the Up To Surface item and emit item_selected.
		# PopupMenu.id_pressed does not reach OptionButton unless the popup
		# itself handles the click, so drive the same signal the menu emits.
		end_opt.select(3)
		end_opt.item_selected.emit(3)
		await process_frame
		check(end_opt.selected == 3, "End is Up To Surface")
	check(chrome.wants_face_pick(), "Up To Surface arms a face pick")
	chrome.arm_face_pick()
	await _click_bottom_face(ctx, bottom)
	check(str(chrome.up_to_face_id) == bottom, "viewport click set the bottom face")
	var ex_btn := chrome.extrude_button()
	await FilmUI.click_control(ctx, ex_btn, FilmUICues.alert("Extrude", "Extrude circle"))
	await process_frame
	await process_frame
	check(not sm.active, "extrude left the sketch")
	var feat := _base_extrude(ctx)
	check(not feat.is_empty(), "base extrude is on the timeline")
	if not feat.is_empty():
		var params = JSON.parse_string(str(feat.get("params", "{}")))
		var end := str(params.get("end", "")) if params is Dictionary else ""
		check(end == "to_face", "extrude end is to_face (got %s)" % end)


func _edit_distance_from_timeline(ctx: FilmContext) -> void:
	print("- double-click extrude row, type 14, Pick face")
	var feat := _base_extrude(ctx)
	if feat.is_empty():
		check(false, "no extrude to edit")
		return
	var fid := str(feat.get("id", ""))
	ctx.main._view_popup.id_pressed.emit(4)
	await process_frame
	await process_frame
	check(ctx.main.show_timeline and ctx.main.timeline.visible, "View menu shows the timeline")
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	await process_frame
	var btn := _row_name_button(tl, fid)
	check(btn != null and btn.is_visible_in_tree(), "extrude row name is visible")
	if btn == null:
		return
	await _double_click_control(ctx, btn)
	await process_frame
	await process_frame
	var panel: PropertyPanel = tl.property_panel
	check(panel != null and panel.visible, "double-click opens the property panel")
	if panel == null or not panel.visible:
		return
	var spin := _first_spin(panel)
	check(spin != null, "distance spin exists")
	if spin == null:
		return
	var edit: LineEdit = spin.get_line_edit()
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == edit, "distance LineEdit is focused (got %s)" % (owner.name if owner != null else "none"))
	var selected := edit.get_selected_text() if edit != null else ""
	check(edit != null and selected != "" and selected == edit.text,
			"distance text is selected ('%s' of '%s')" % [selected, edit.text if edit != null else ""])
	await _type_digits(ctx, "14")
	await _tap_key(ctx, KEY_ENTER, 0)
	await process_frame
	await process_frame
	var dist := _feature_distance(ctx, fid)
	check(absf(dist - 14.0) < 0.05, "feature distance is 14 (got %.4f)" % dist)
	var body := ""
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) == fid:
			body = str(f.get("output_body", ""))
	if body != "":
		ctx.view.select_entity(body, "")
	await process_frame
	var before := _selection_sig(ctx.view)
	owner = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == edit or (owner != null and spin.is_ancestor_of(owner)),
			"distance spin still focused before Ctrl+A (got %s)" % (owner.name if owner != null else "none"))
	check(ctx.view.selected_body == body and body != "", "a body is selected before Ctrl+A")
	await _tap_key(ctx, KEY_A, 97, true)
	await process_frame
	var after := _selection_sig(ctx.view)
	check(after == before, "Ctrl+A does not change body selection (%s -> %s)" % [before, after])
	if edit != null and edit.has_focus():
		check(edit.get_selected_text() == edit.text,
				"Ctrl+A keeps the distance digits selected")
	_check_opaque(tl, "timeline")
	_check_opaque(panel, "property panel")
	var pick := _find_button(panel, "Pick face")
	check(pick != null and pick.is_visible_in_tree(), "Pick face is visible for to_face")
	if pick == null:
		return
	var chrome: Node = ctx.main.find_child("SketchContextChrome", true, false)
	await FilmUI.click_control(ctx, pick, FilmUICues.alert("Pick face", "Re-pick Up To Surface face"))
	if chrome == null or not chrome.has_method("arm_face_pick") or not chrome.has_method("wants_face_pick"):
		check(false, "WP1 arm_face_pick / wants_face_pick is missing")
		return
	check(bool(chrome.call("wants_face_pick")), "Pick face pressed leaves wants_face_pick true")


func _check_opaque(panel: PanelContainer, label: String) -> void:
	check(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "%s mouse_filter is STOP" % label)
	var style := panel.get_theme_stylebox("panel")
	var alpha := -1.0
	if style is StyleBoxFlat:
		alpha = (style as StyleBoxFlat).bg_color.a
	check(is_equal_approx(alpha, 1.0), "%s background alpha is 1 (got %.3f)" % [label, alpha])


func _double_click_control(ctx: FilmContext, ctrl: Control) -> void:
	var center := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	center = ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, false)
	await process_frame
	center = ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, true)
	await process_frame


func _pointer_click(ctx: FilmContext, pos: Vector2, double_click: bool) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _type_digits(ctx: FilmContext, digits: String) -> void:
	for i in digits.length():
		var ch := digits.unicode_at(i)
		var key := KEY_0 + (ch - 48)
		await _tap_key(ctx, key, ch)


func _tap_key(ctx: FilmContext, keycode: Key, unicode: int, ctrl := false) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	rel.ctrl_pressed = ctrl
	vp.push_input(rel)
	await process_frame


func _click_bottom_face(ctx: FilmContext, bottom: String) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.sketch_orientation_locked = false
	var mid: Vector3 = ctx.view.doc.face_midpoint(bottom)
	cam.pivot = mid
	cam.distance = 180.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.set_view(cam.yaw, deg_to_rad(-75.0), false)
	await process_frame
	await process_frame
	var screen: Vector2 = ctx.main.interaction._model_to_screen(mid)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Bottom face"))
	await process_frame


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var bb: Dictionary = ctx.view.doc.measure_bbox(f)
		if bb.is_empty():
			continue
		var fext: Vector3 = bb["max"] - bb["min"]
		var span := maxf(fext.x, fext.y)
		if fext.z > 0.5 and fext.z > span * 0.05:
			continue
		var z: float = bb["max"].z if z_sign > 0 else bb["min"].z
		var area := fext.x * fext.y
		var better := false
		if z_sign > 0:
			better = z > best_z + 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		else:
			better = z < best_z - 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		if better:
			best_z = z
			best_area = area
			best = f
	return best


func _base_extrude(ctx: FilmContext) -> Dictionary:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			return f
	return {}


func _feature_distance(ctx: FilmContext, fid: String) -> float:
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if parsed is Dictionary:
			return float(parsed.get("distance", -1.0))
	return -1.0


func _selection_sig(view: DocumentView) -> String:
	return "%s bodies=%d faces=%d n=%d" % [
		view.selected_body, view.selected_bodies.size(), view.selected_faces.size(), view.selection_size()]


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null


func _first_spin(node: Node) -> SpinBox:
	if node is SpinBox:
		return node
	for child in node.get_children():
		var found := _first_spin(child)
		if found != null:
			return found
	return null


func _find_button(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
