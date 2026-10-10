# Rung 1 replan 5 WP1 — discarded open-profile Exit leaves a usable session.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan5_session.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan5 WP1 session")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_discard_open_profile_then_circle()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan5_session.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("set_up_to" + "_face"), "test source has no face-id setter")
	check(not src.contains("set_finish" + "_op"), "test source has no finish-op setter")
	check(not src.contains("set_finish" + "_end"), "test source has no finish-end setter")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("focus_dim" + "_for_typing"), "test source has no dim typing helper")
	check(not src.contains("focus_distance" + "_for_typing"), "test source has no distance typing helper")
	check(not src.contains("export_3mf" + "("), "test source has no export_3mf call")
	check(not src.contains("infer_enabled" + " = false"), "test source does not disable inference")
	check(not src.contains("current_path" + " ="), "test source does not assign dialog path")
	check(not src.contains("sketch_mode.cancel" + "("), "test source does not call cancel")
	check(not src.contains("sketch_mode.exit_sketch" + "("), "test source does not call exit_sketch")
	check(not src.contains("sketch_mode.trim_at" + "("), "test source does not call trim_at")
	check(not src.contains("new_document" + "("), "test source does not call new_document")
	check(not src.contains("graph_update_sketch" + "("), "test source does not call graph_update_sketch")
	check(src.contains("func _x11_" + "click(ctrl"), "test source copies the X11 click helper")
	check(src.contains("func _x11_" + "click_screen(vp"), "test source copies the X11 screen click helper")
	check(src.contains("func _x11_" + "type(vp"), "test source copies the X11 type helper")


func test_discard_open_profile_then_circle() -> void:
	print("- rectangle, Extrude, reopen, delete an edge, Exit Sketch, then a ground circle")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch session is open")
	await _zoom(ctx, Vector3(20, 15, 0), 80.0)
	await _select_tool(ctx, "Rectangle")
	await _click_uv_local(ctx, Vector2(0, 0), "Rect corner A")
	await _click_uv_local(ctx, Vector2(40, 30), "Rect corner B")
	await process_frame
	var n_lines := _count_profile_lines(sm)
	check(n_lines >= 4, "rectangle has four edges (got %d)" % n_lines)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(chrome != null and chrome.visible, "finish bar is visible")
	var ex_btn: Button = chrome.extrude_button()
	check(ex_btn != null and ex_btn.is_visible_in_tree(), "Extrude is visible")
	await _x11_click(ex_btn)
	await process_frame
	await process_frame
	await process_frame
	check(not sm.active, "Extrude left sketch mode")
	check(ctx.view.doc.body_ids().size() >= 1, "extrude created a body")
	var body := ""
	if not ctx.view.doc.body_ids().is_empty():
		body = str(ctx.view.doc.body_ids()[0])
	var sketch_fid := _first_feature(ctx, "sketch")
	check(sketch_fid != "", "sketch feature is on the timeline")
	await _show_timeline(ctx)
	var row := _row_name_button(ctx.main.timeline, sketch_fid)
	check(row != null and row.is_visible_in_tree(), "sketch row is visible")
	if row != null:
		await _x11_double_click(row)
		await process_frame
		await process_frame
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "timeline double-click reopened the sketch")
	check(sm.editing_fid == sketch_fid, "editing_fid is the reopened sketch")
	await _zoom(ctx, Vector3(20, 15, 0), 80.0)
	await _select_tool(ctx, "Select")
	var edge_mids: Array[Vector2] = _line_mids(sm)
	check(not edge_mids.is_empty(), "reopened sketch still has a rectangle edge")
	for mid in edge_mids:
		await _zoom(ctx, sm.to_model(mid), 50.0)
		await _click_uv_local(ctx, mid, "Select rectangle edge")
		await process_frame
		if sm.selected.size() >= 1:
			break
	if sm.selected.is_empty() and not edge_mids.is_empty():
		await _click_uv_local(ctx, edge_mids[0], "Select rectangle edge again")
		await process_frame
	check(sm.selected.size() >= 1, "one rectangle edge is selected (got %d)" % sm.selected.size())
	var before_ids := sm.sketch.entity_ids() if sm.sketch != null else PackedStringArray()
	await _press_delete(ctx)
	await process_frame
	var after_ids := sm.sketch.entity_ids() if sm.sketch != null else PackedStringArray()
	check(after_ids.size() < before_ids.size(), "Delete removed the selected edge")
	check(not SketchMode.profile_is_closed(sm.sketch), "profile is open after Delete")
	_status_log.clear()
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	check(exit_btn != null and exit_btn.is_visible_in_tree(), "Exit Sketch is visible")
	# Finish-bar DimLineEdit can sit on the Exit label at 1280×800. Click the
	# icon (left) side so the press hits Exit Sketch.
	var r: Rect2 = exit_btn.get_global_rect()
	var pos := Vector2(r.position.x + 16.0, r.get_center().y)
	await _x11_click_screen(ctx.main.get_viewport(), pos)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	var status_text := str(ctx.main.status_label.text)
	check(not sm.active, "Exit Sketch left the session (active is false)")
	check(not status_text.contains("Failed to update sketch"),
			"status is not Failed to update sketch (got '%s')" % status_text)
	check(status_text.contains("Sketch edit discarded") or _status_has("Sketch edit discarded"),
			"status contains Sketch edit discarded (got '%s')" % status_text)
	check(ctx.view.doc.body_ids().size() >= 1, "extrude body is still present")
	if body != "":
		check(body in ctx.view.doc.body_ids(), "the same body id remains")
	check(not sm.active, "session is inactive before the next ground sketch")
	await _start_ground_sketch(ctx, Vector3(-40, 40, 0))
	sm = ctx.main.sketch_mode
	check(sm.active, "ground sketch started after the discard")
	var origin3: Vector3 = sm.to_model(Vector2.ZERO)
	await _zoom(ctx, origin3, 80.0)
	var origin_screen := FilmUI.model_to_screen(ctx, origin3)
	if not FilmUI.is_on_screen(ctx, origin_screen):
		await _zoom(ctx, sm.plane_origin, 120.0)
	await _select_tool(ctx, "Circle")
	_status_log.clear()
	await _click_uv_local(ctx, Vector2(0, 0), "Circle centre")
	await _click_uv_local(ctx, Vector2(8, 0), "Circle rim")
	await process_frame
	status_text = str(ctx.main.status_label.text)
	check(status_text.contains("Circle") or _status_has("Circle"),
			"status contains Circle (got '%s')" % status_text)
	await _shutdown(ctx)


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
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	if not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


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


func _x11_double_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	for pass_i in 2:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.double_click = pass_i == 1
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


func _press_delete(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = KEY_DELETE
	ev.physical_keycode = KEY_DELETE
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.selected.size() > 0:
		var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Delete")
		if chip != null and chip.is_visible_in_tree():
			await _x11_click(chip)


func _start_ground_sketch(ctx: FilmContext, ground := Vector3(22, 18, 0)) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		return
	if ctx.view != null:
		ctx.view.select_entity("", "")
	await process_frame
	await _zoom(ctx, ground, 80.0)
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "Sketch control is visible")
	await _x11_click(sketch_btn)
	await process_frame
	sm = ctx.main.sketch_mode
	if sm != null and sm.active:
		return
	var screen := FilmUI.model_to_screen(ctx, ground)
	check(FilmUI.require_on_screen(ctx, screen, "ground pick"), "ground pick is on screen")
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame


func _select_tool(ctx: FilmContext, label: String) -> void:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(b != null and b.is_visible_in_tree(), "%s tool is visible" % label)
	if b != null:
		await _aim_then_click(b)
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and not _tool_is(sm, label):
		var key := _tool_hotkey(label)
		if key != KEY_NONE:
			await _press_key(ctx.main.get_viewport(), key)
			await process_frame
	if sm != null and not _tool_is(sm, label):
		await FilmUI.select_sketch_tool(ctx, sm, _tool_enum(label))
		await process_frame
	check(sm == null or _tool_is(sm, label), "%s tool is active" % label)


func _aim_then_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await _x11_click_screen(vp, pos)


func _tool_hotkey(label: String) -> Key:
	match label:
		"Select":
			return KEY_S
		"Line":
			return KEY_L
		"Rectangle":
			return KEY_R
		"Circle":
			return KEY_C
		"Power Trim", "Trim":
			return KEY_T
		"Smart Dimension":
			return KEY_D
	return KEY_NONE


func _tool_enum(label: String) -> int:
	match label:
		"Select":
			return SketchMode.Tool.SELECT
		"Line":
			return SketchMode.Tool.LINE
		"Rectangle":
			return SketchMode.Tool.RECT
		"Circle":
			return SketchMode.Tool.CIRCLE
		"Power Trim", "Trim":
			return SketchMode.Tool.TRIM
		"Smart Dimension":
			return SketchMode.Tool.SMART_DIM
		"Polygon":
			return SketchMode.Tool.POLYGON
	return SketchMode.Tool.NONE


func _tool_is(sm: SketchMode, label: String) -> bool:
	return sm.tool == _tool_enum(label)


func _press_key(vp: Viewport, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _line_mids(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		out.append(((info["start"] as Vector2) + (info["end"] as Vector2)) * 0.5)
	return out


func _show_timeline(ctx: FilmContext) -> void:
	if ctx.main.show_timeline:
		ctx.main._update_panel_visibility()
		await process_frame
		return
	var btn := _menu_button(ctx.main, "View")
	check(btn != null and btn.is_visible_in_tree(), "View menu is visible")
	if btn == null:
		return
	await _x11_click(btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	check(popup != null and popup.visible, "View popup is visible")
	if popup == null:
		return
	var idx := popup.get_item_index(4)
	if popup.has_method("scroll_to_item") and idx >= 0:
		popup.scroll_to_item(idx)
	popup.reset_size()
	await process_frame
	var screen := _item_screen_center(popup, idx)
	await _x11_click_screen(root.get_viewport(), screen)
	await process_frame
	await process_frame
	check(ctx.main.show_timeline, "View → Timeline opened")
	if ctx.main.timeline != null:
		ctx.main.timeline.refresh()
		await process_frame


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _item_screen_center(popup: PopupMenu, index: int) -> Vector2:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		var h := float(font_h) + float(v_sep)
		if popup.is_item_separator(i):
			h = float(v_sep)
		y += h
	y += (float(font_h) + float(v_sep)) * 0.5
	return Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	if tl == null:
		return null
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null


func _first_feature(ctx: FilmContext, kind: String) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == kind:
			return str(f.get("id", ""))
	return ""


func _count_profile_lines(sm: SketchMode) -> int:
	var n := 0
	if sm == null or sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	var vp: Viewport = ctx.main.get_viewport()
	await _x11_click_screen(vp, screen)
	await process_frame


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	else:
		cam.sketch_orientation_locked = true
		cam.yaw = 0.0
		cam.pitch = deg_to_rad(89.0)
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame

func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)


func _x11_click_screen(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
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


