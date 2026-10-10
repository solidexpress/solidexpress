# sx-038 A13 — Timeline double-click must focus Distance before the next keys.
# A real InputEventMouseButton double-click (press, release, press, release
# through the viewport, not gui_input.emit) is followed by InputEventKey
# 1, 4, Enter. The row button must not keep the keys: 1/4 edit Distance,
# they do not switch to Front / Back. Esc and a second double-click do the
# same. An empty-viewport click closes the panel and hides
# "Params (JSON, advanced)".
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx038_a13.gd
extends "res://tests/lib/sx_suite.gd"
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 sx038 A13 timeline distance focus")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# --headless starts at 64×64. Set the walk size after Main's fit pass.
	root.size = ROOT_SIZE
	DisplayServer.window_set_size(ROOT_SIZE)
	await process_frame
	await process_frame
	await _distance_keys_edit_the_field(main)
	finish()


func _distance_keys_edit_the_field(main) -> void:
	print("- double-click extrude, type 14, no view change")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var sk := SxSketch.new()
	sk.add_line(-10, -8, 10, -8)
	sk.add_line(10, -8, 10, 8)
	sk.add_line(10, 8, -10, 8)
	sk.add_line(-10, 8, -10, -8)
	var sk_fid: String = doc.graph_add_sketch(sk)
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	check(ex_fid != "", "base extrude exists")
	if ex_fid == "":
		return
	view.graph_changed()
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	var tl: TimelinePanel = main.timeline
	tl.refresh()
	await process_frame
	await process_frame
	var btn := _row_name_button(tl, ex_fid)
	check(btn != null and btn.is_visible_in_tree(), "extrude row is on screen")
	if btn == null:
		return
	var edit := await _open_distance(main, btn)
	if edit == null:
		return
	await _assert_keys_set_distance(main, edit, ex_fid, "first open")
	print("- Esc, reopen, type 14 again")
	await _key(main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	check(not tl.property_panel.visible, "Esc closes the Distance panel")
	check(absf(_feature_distance(doc, ex_fid) - 10.0) < 0.05,
			"Esc rolls distance back to 10 (got %.4f)" % _feature_distance(doc, ex_fid))
	tl.refresh()
	await process_frame
	btn = _row_name_button(tl, ex_fid)
	check(btn != null, "extrude row still exists after Esc")
	if btn == null:
		return
	edit = await _open_distance(main, btn)
	if edit == null:
		return
	await _assert_keys_set_distance(main, edit, ex_fid, "reopen")
	print("- empty viewport click hides Params (JSON, advanced)")
	check(_params_row_visible(tl), "JSON row is drawn while Distance is open")
	# Pull back so the click is empty canvas, not a hit on the solid.
	main.camera.distance = 4000.0
	main.camera._update_transform()
	await process_frame
	var yaw: float = main.camera.yaw
	var pitch: float = main.camera.pitch
	await _click_empty(main)
	await process_frame
	await process_frame
	check(not tl.property_panel.visible, "empty click closes the Distance panel")
	check(not _params_row_visible(tl),
			"Params (JSON, advanced) hides with the panel")
	check(absf(_feature_distance(doc, ex_fid) - 14.0) < 0.05,
			"empty click keeps distance 14 (got %.4f)" % _feature_distance(doc, ex_fid))
	check(is_equal_approx(main.camera.yaw, yaw) and is_equal_approx(main.camera.pitch, pitch),
			"empty click does not orbit")


func _open_distance(main, btn: Button) -> LineEdit:
	var tl: TimelinePanel = main.timeline
	await _real_double_click(btn)
	var panel: PropertyPanel = tl.property_panel
	check(panel != null and panel.visible, "double-click opens the property panel")
	if panel == null or not panel.visible:
		return null
	var spin := panel.find_child("Param_distance", true, false) as SpinBox
	check(spin != null and spin.is_visible_in_tree(), "Distance spin is visible")
	if spin == null:
		return null
	var edit := spin.get_line_edit()
	var owner: Control = main.get_viewport().gui_get_focus_owner()
	check(owner == edit, "Distance line has keyboard focus (got %s)" % _who(owner))
	if edit == null:
		return null
	var selected := edit.get_selected_text()
	check(selected != "" and selected == edit.text,
			"Distance text is selected ('%s' of '%s')" % [selected, edit.text])
	return edit


func _assert_keys_set_distance(main, edit: LineEdit, fid: String, label: String) -> void:
	var cam: OrbitCamera = main.camera
	var yaw: float = cam.yaw
	var pitch: float = cam.pitch
	var dist: float = cam.distance
	var vp: Viewport = main.get_viewport()
	_status_log.clear()
	_note(main)
	await _key(vp, KEY_1)
	_note(main)
	check(not _saw_view(), "%s: key 1 did not switch to Front view (%s)" % [label, _status_text()])
	check(is_equal_approx(cam.yaw, yaw) and is_equal_approx(cam.pitch, pitch),
			"%s: key 1 left the camera (yaw %.4f pitch %.4f)" % [label, cam.yaw, cam.pitch])
	var after_1 := _line_number(edit)
	check(is_equal_approx(after_1, 1.0),
			"%s: field is 1 after the first digit (got '%s')" % [label, edit.text])
	await _key(vp, KEY_4)
	_note(main)
	check(not _saw_view(), "%s: key 4 did not switch to Back view (%s)" % [label, _status_text()])
	check(is_equal_approx(cam.yaw, yaw) and is_equal_approx(cam.pitch, pitch) \
			and is_equal_approx(cam.distance, dist),
			"%s: camera unchanged after 14" % label)
	var after_14 := _line_number(edit)
	check(is_equal_approx(after_14, 14.0),
			"%s: field is 14 before Enter (got '%s')" % [label, edit.text])
	await _key(vp, KEY_ENTER)
	for _i in 4:
		await process_frame
	_note(main)
	check(is_equal_approx(_line_number(edit), 14.0) or absf(_feature_distance(main.view.doc, fid) - 14.0) < 0.05,
			"%s: field or feature is 14 after Enter (text '%s')" % [label, edit.text])
	check(absf(_feature_distance(main.view.doc, fid) - 14.0) < 0.05,
			"%s: feature distance is 14 (got %.4f)" % [label, _feature_distance(main.view.doc, fid)])
	var status := _status_text()
	check(status.contains("Preview: distance = 14.0") or str(main.status_label.text).contains("Preview: distance = 14.0"),
			"%s: status previews distance 14 (%s)" % [label, str(main.status_label.text)])
	check(not _saw_view(), "%s: no Front/Back view status (%s)" % [label, status])


func _real_double_click(ctrl: Control) -> void:
	var vp := ctrl.get_viewport()
	var pos := ctrl.get_global_rect().get_center()
	await _motion(vp, pos)
	await _button(vp, pos, true, false)
	await process_frame
	await _button(vp, pos, false, false)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
	await _motion(vp, pos)
	await _button(vp, pos, true, true)
	await process_frame
	await _button(vp, pos, false, false)
	for _i in 4:
		await process_frame


func _click_empty(main) -> void:
	var vp: Viewport = main.get_viewport()
	var tl: TimelinePanel = main.timeline
	var spots: Array[Vector2] = [
		Vector2(1000, 160), Vector2(1100, 420), Vector2(900, 640), Vector2(1240, 220),
	]
	for spot in spots:
		if tl.property_panel == null or not tl.property_panel.visible:
			return
		await _motion(vp, spot)
		await _button(vp, spot, true, false)
		await process_frame
		await _button(vp, spot, false, false)
		await process_frame
		await process_frame


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _button(vp: Viewport, pos: Vector2, pressed: bool, double_click: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.double_click = double_click
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)


func _key(vp: Viewport, keycode: Key) -> void:
	var unicode := 0
	if keycode == KEY_1:
		unicode = 49
	elif keycode == KEY_4:
		unicode = 52
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.unicode = 0
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _note(main) -> void:
	var text := str(main.status_label.text)
	if text != "" and (_status_log.is_empty() or _status_log[-1] != text):
		_status_log.append(text)


func _status_text() -> String:
	return " | ".join(_status_log)


func _saw_view() -> bool:
	var blob := _status_text()
	return blob.contains("Front view") or blob.contains("Back view")


func _who(owner: Control) -> String:
	if owner == null:
		return "none"
	return "%s:%s" % [owner.get_class(), owner.name]


func _line_number(edit: LineEdit) -> float:
	if edit == null:
		return NAN
	var text := edit.text.strip_edges().replace(",", ".")
	var space := text.find(" ")
	if space > 0:
		text = text.substr(0, space)
	if text.is_valid_float():
		return float(text)
	return NAN


func _feature_distance(doc: SxDocument, fid: String) -> float:
	for f in doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if parsed is Dictionary:
			return float((parsed as Dictionary).get("distance", -1.0))
	return -1.0


func _params_row_visible(tl: TimelinePanel) -> bool:
	var buttons := tl.find_children("*", "CheckButton", true, false)
	for node in buttons:
		var toggle := node as CheckButton
		if toggle != null and str(toggle.text).begins_with("Params (JSON"):
			return toggle.is_visible_in_tree()
	return false


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and not (child is CheckBox):
			return child as Button
	return null
