# Rung 1 replan WP3 — viewport face pick, dim-focus release, Esc, Ctrl+A.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan_input.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")



func _init() -> void:
	print("rung01 replan input (WP3)")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)
	main._file_popup.id_pressed.emit(0)
	await process_frame
	await process_frame

	await test_esc_focus_and_ctrl_a(main)
	await test_face_pick_and_dim_focus(main)
	test_dim_popup_fits_angle(main)

	finish()


func _click(ix: ViewportInteraction, pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	ix._input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	ix._input(up)


func _key(vp: Viewport, code: Key, pressed: bool, ctrl := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.ctrl_pressed = ctrl
	ev.echo = false
	vp.push_input(ev)


func _esc(vp: Viewport) -> void:
	_key(vp, KEY_ESCAPE, true)
	_key(vp, KEY_ESCAPE, false)


func _face_by_z(doc: SxDocument, body: String, want_max: bool) -> String:
	var best := ""
	var best_z: float = -1.0e30 if want_max else 1.0e30
	for fid in doc.get_face_ids(body):
		var mid: Vector3 = doc.face_midpoint(fid)
		if want_max and mid.z > best_z:
			best_z = mid.z
			best = fid
		elif not want_max and mid.z < best_z:
			best_z = mid.z
			best = fid
	return best


func _click_until_face(ix: ViewportInteraction, view: DocumentView, face_id: String) -> void:
	var screen := ix._model_to_screen(view.doc.face_midpoint(face_id))
	for _i in range(2):
		if view.selected_face == face_id:
			return
		_click(ix, screen)
		await process_frame


func test_esc_focus_and_ctrl_a(main) -> void:
	print("- Esc clears TriBall and selection; Ctrl+A stays in the spin")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 40, 10))
	check(id != "", "box blank exists")
	main.camera.frame_contents()
	await process_frame
	await process_frame
	var bb: Dictionary = view.doc.measure_bbox(id)
	var center := ix._model_to_screen((bb["min"] + bb["max"]) * 0.5)
	_click(ix, center)
	await process_frame
	check(view.selected_body == id, "viewport click selected the box")
	check(ix.triball == null or not ix.triball.active, "body click did not arm TriBall")

	var strip: Button = ix._strip_triball
	check(strip != null and strip.visible, "selection strip TriBall button is visible")
	strip.pressed.emit()
	strip.grab_focus()
	await process_frame
	check(ix.triball != null and ix.triball.active and ix.triball.visible, "strip button armed TriBall")
	check(ix.get_viewport().gui_get_focus_owner() == strip, "focus stayed on the TriBall button")
	_esc(ix.get_viewport())
	await process_frame
	check(not ix.triball.active and not ix.triball.visible, "one Esc cleared the gizmo")
	check(view.selected_body == "", "one Esc cleared the selection")
	check(not ix._selection_strip.visible, "selection strip hidden after Esc")
	_esc(ix.get_viewport())
	await process_frame
	check(view.selected_body == "" and not ix.triball.active, "second Esc is a no-op")

	_click(ix, center)
	await process_frame
	check(view.selected_body == id, "body click selected again")
	check(not ix.triball.active, "body click still does not arm TriBall")
	strip.pressed.emit()
	await process_frame
	check(ix.triball.active, "TriBall armed again for the spin Esc")
	var spin: SpinBox = ix.transform_hud._size_h
	var edit: LineEdit = spin.get_line_edit()
	edit.grab_focus()
	await process_frame
	check(ix.get_viewport().gui_get_focus_owner() == edit, "spin LineEdit has focus")
	var faces_before := view.selected_faces.size()
	var body_before := view.selected_body
	_esc(ix.get_viewport())
	await process_frame
	check(ix.get_viewport().gui_get_focus_owner() != edit, "Esc released the spin")
	check(not ix.triball.active and not ix.triball.visible, "Esc cleared TriBall while the spin was focused")
	check(view.selected_body == "", "Esc cleared the selection while the spin was focused")

	_click(ix, center)
	await process_frame
	check(view.selected_body == id, "body selected for Ctrl+A")
	edit = ix.transform_hud._size_h.get_line_edit()
	edit.grab_focus()
	await process_frame
	faces_before = view.selected_faces.size()
	body_before = view.selected_body
	var bodies_before := view.selected_bodies.size()
	_key(ix.get_viewport(), KEY_A, true, true)
	_key(ix.get_viewport(), KEY_A, false, true)
	await process_frame
	check(view.selected_body == body_before, "Ctrl+A in the spin did not change the body")
	check(view.selected_faces.size() == faces_before, "Ctrl+A in the spin did not scene-select faces")
	check(view.selected_bodies.size() == bodies_before, "Ctrl+A in the spin did not scene-select bodies")


func test_face_pick_and_dim_focus(main) -> void:
	print("- Up To Surface face click and dim-blank focus release")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	var chrome = main.sketch_chrome
	var ids: PackedStringArray = view.doc.body_ids()
	check(not ids.is_empty(), "blank still in the document")
	if ids.is_empty():
		return
	var body := str(ids[0])
	var top := _face_by_z(view.doc, body, true)
	var bottom := _face_by_z(view.doc, body, false)
	check(top != "" and bottom != "" and top != bottom, "top and bottom faces differ")
	main.camera.frame_contents()
	await process_frame
	view.clear_selection()
	await _click_until_face(ix, view, top)
	check(view.selected_face == top, "top face selected for the sketch")
	ix._strip_sketch.pressed.emit()
	await process_frame
	await process_frame
	check(sm.active, "sketch is active on the top face")
	check(absf(sm.plane_origin.z - view.doc.face_midpoint(top).z) < 0.5,
			"sketch plane is the host top face")

	var n0 := sm.sketch.entity_ids().size()
	var pts0 := sm._tool_points.size()
	if chrome == null or not chrome.has_method("arm_face_pick"):
		check(false, "WP1 arm_face_pick is missing on SketchContextChrome — cannot arm the face pick")
	else:
		chrome.arm_face_pick()
		var armed: bool = chrome.has_method("wants_face_pick") and bool(chrome.wants_face_pick())
		check(armed, "arm_face_pick left wants_face_pick true")
		if armed:
			# Sketch view looks down on the host. Swing under the blank so the
			# ray meets the bottom face first.
			main.camera.set_view(main.camera.yaw, deg_to_rad(-75.0), false)
			await process_frame
			var screen := ix._model_to_screen(view.doc.face_midpoint(bottom))
			_click(ix, screen)
			await process_frame
			check(str(chrome.up_to_face_id) == bottom, "picked face is the bottom, not the host")
			check(str(chrome.up_to_face_id) != top, "picked face is not the sketch host")
			check(sm.active, "face pick did not exit the sketch")
			check(sm.sketch.entity_ids().size() == n0, "face pick added no sketch entity")
			check(sm._tool_points.size() == pts0, "face pick added no sketch point")
			check(view.selected_face == bottom, "picked face is highlighted")

	var dim_edit: LineEdit = chrome._dim_spin.get_line_edit()
	dim_edit.grab_focus()
	await process_frame
	check(ix.get_viewport().gui_get_focus_owner() == dim_edit, "dim blank focused")
	var canvas := ix._screen_center()
	_click(ix, canvas)
	await process_frame
	check(ix.get_viewport().gui_get_focus_owner() != dim_edit,
			"canvas click moved focus off the dim blank")


func test_dim_popup_fits_angle(main) -> void:
	print("- dimension popup is wide enough for 45.0")
	var line: LineEdit = main.interaction._dim_edit_line
	check(line != null, "dim edit line exists")
	if line == null:
		return
	var font := line.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_px := line.get_theme_font_size("font_size")
	if font_px <= 0:
		font_px = 16
	var text_w := font.get_string_size("45.0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	check(line.custom_minimum_size.x >= text_w + 12.0,
			"dim edit line fits 45.0 (need %.0f, have %.0f)" % [
				text_w + 12.0, line.custom_minimum_size.x])
