# Rung 1 replan 5 WP1 — Power Trim opens a perpendicular jaw; near-parallel fails.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan5_trim.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL := 1.0
const HEAD := Vector2(200, 0)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan5 WP1 trim")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_perpendicular_then_parallel_trim()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan5_trim.gd")
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
	check(not _x11_click_awaits_between_down_up(src),
			"X11 click helper has no await between mouse-down and mouse-up")


func _x11_click_awaits_between_down_up(src: String) -> bool:
	var start := src.find("func _x11_" + "click_screen(vp")
	if start < 0:
		return true
	var nxt := src.find("\nfunc ", start + 1)
	var body := src.substr(start, nxt - start if nxt > start else src.length() - start)
	var down := body.find("pressed = true")
	var up := body.find("pressed = false")
	if down < 0 or up < 0 or up <= down:
		return true
	return body.find("await ", down) >= 0 and body.find("await ", down) < up


func test_perpendicular_then_parallel_trim() -> void:
	print("- blank Ø20/Ø45, Extrude 10, jaw sketch, perpendicular Power Trim")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10")
	await _zoom_uv(ctx, HEAD, 80.0)
	await _draw_circle_typed(ctx, HEAD, "22.5")
	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	await _select_tool(ctx, "Line")
	for y_sign in [1.0, -1.0]:
		await _draw_shaft_line(ctx, far_x, float(y_sign))
	await _type_distance(ctx, "10")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var ex_btn: Button = chrome.extrude_button()
	await _x11_click(ex_btn)
	await process_frame
	await process_frame
	await process_frame
	check(not sm.active, "blank Extrude left sketch mode")
	var body := _only_body(ctx)
	check(body != "", "blank body exists")
	if body == "":
		await _shutdown(ctx)
		return
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	await _sketch_on_top(ctx, body, top, 10.0)
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5, "jaw sketch is on the top face")
	await _zoom_uv(ctx, Vector2.ZERO, 40.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "5")
	await _zoom_uv(ctx, HEAD, 120.0)
	await _draw_circle_typed(ctx, HEAD, "22.5")
	await _draw_centre_rect(ctx, HEAD, 45.0, 10.0)
	await _edit_rect_labels(ctx)
	var orient := _long_side_angle_deg(sm)
	check(absf(orient - 45.0) <= TOL, "jaw long side is 45° ± 1 (got %.3f)" % orient)
	await _draw_centreline(ctx, HEAD, Vector2(-sqrt(2.0) / 2.0, sqrt(2.0) / 2.0))
	await _select_tool(ctx, "Power Trim")
	var click_uv := HEAD + Vector2(-12.0, 0.0)
	await _zoom_uv(ctx, click_uv, 90.0)
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(click_uv))
	check(FilmUI.require_on_screen(ctx, screen, "shaft-side trim"),
			"shaft-side trim click is on screen")
	_status_log.clear()
	await _aim_then_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame
	var status_text := str(ctx.main.status_label.text)
	check(status_text.contains("Trimmed open jaw") or _status_has("Trimmed open jaw"),
			"status contains Trimmed open jaw (got '%s')" % status_text)
	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile is closed")
	check(_hole_circle_present(sm), "Ø10 circle is still in the sketch")

	print("- second sketch: near-parallel centreline fails and Exit leaves")
	await _exit_sketch(ctx)
	check(not ctx.main.sketch_mode.active, "Exit after the open jaw left the session")
	await _sketch_on_top(ctx, body, top, 10.0)
	sm = ctx.main.sketch_mode
	check(sm.active, "second jaw sketch is open")
	await _zoom_uv(ctx, HEAD, 120.0)
	await _draw_circle_typed(ctx, HEAD, "22.5")
	await _draw_centre_rect(ctx, HEAD, 45.0, 10.0)
	await _edit_rect_labels(ctx)
	var edges_before := _count_profile_lines(sm)
	check(edges_before >= 4, "second rectangle has four edges (got %d)" % edges_before)
	await _draw_centreline(ctx, HEAD, Vector2(sqrt(2.0) / 2.0, sqrt(2.0) / 2.0))
	await _select_tool(ctx, "Power Trim")
	await _zoom_uv(ctx, click_uv, 90.0)
	screen = FilmUI.model_to_screen(ctx, sm.to_model(click_uv))
	check(FilmUI.require_on_screen(ctx, screen, "parallel trim"),
			"near-parallel trim click is on screen")
	_status_log.clear()
	await _aim_then_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame
	status_text = str(ctx.main.status_label.text)
	check(status_text.contains("draw a centreline across the jaw")
			or _status_has("draw a centreline across the jaw"),
			"status names the across-the-jaw mismatch (got '%s')" % status_text)
	check(_count_profile_lines(sm) >= 4, "four rectangle edges remain after the failed trim")
	check(sm.active, "failed trim leaves the session active")
	await _exit_sketch(ctx)
	status_text = str(ctx.main.status_label.text)
	check(not ctx.main.sketch_mode.active, "Exit after the failed trim left the session")
	check(not status_text.contains("Failed to update sketch"),
			"status is not Failed to update sketch (got '%s')" % status_text)
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


func _x11_enter(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
	await process_frame


func _start_ground_sketch(ctx: FilmContext, ground := Vector3(22, 18, 0)) -> void:
	if ctx.view != null:
		ctx.view.select_entity("", "")
	await process_frame
	await _zoom(ctx, ground, 80.0)
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "Sketch control is visible")
	await _x11_click(sketch_btn)
	await process_frame
	if ctx.main.sketch_mode.active:
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


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	var vp: Viewport = ctx.main.get_viewport()
	await _aim_then_click_screen(vp, screen)
	await process_frame


func _aim_then_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await _x11_click_screen(vp, pos)


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	await process_frame


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	await _select_tool(ctx, "Circle")
	await _click_uv(ctx, center, "Circle centre")
	await _hover_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text)


func _type_dim(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	check(edit != null, "DimLineEdit exists for typing %s" % text)
	if edit == null:
		return
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	await _x11_enter(edit.get_viewport())
	await process_frame
	await process_frame


func _type_distance(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	if edit == null and chrome._extrude_spin != null:
		edit = chrome._extrude_spin.get_line_edit()
	check(edit != null, "DistanceLineEdit exists for typing %s" % text)
	if edit == null:
		return
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	await process_frame
	await process_frame


func _draw_shaft_line(ctx: FilmContext, far_x: float, sign: float) -> void:
	var a := Vector2(0.0, 10.0 * sign) + Vector2(0.0, 0.3 * sign)
	var c2 := HEAD
	var b := Vector2(far_x, 10.0 * sign)
	var b_dir := b - c2
	var b_off := b + (b_dir.normalized() if b_dir.length_squared() > 1e-8 else Vector2(0, sign)) * 0.3
	await _zoom_uv(ctx, a, 90.0)
	await _click_uv(ctx, a, "Tangent start")
	await _zoom_uv(ctx, b_off, 90.0)
	await _click_uv(ctx, b_off, "Tangent end")
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(b_off))
	var vp: Viewport = ctx.main.get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	vp.push_input(up)
	await process_frame


func _draw_centre_rect(ctx: FilmContext, center: Vector2, angle_deg: float, half_w: float) -> void:
	await _select_tool(ctx, "Rectangle")
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	check(chip != null and chip.is_visible_in_tree(), "Center Three Point chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, {"keys": "Click", "desc": "Center Three Point"})
		await process_frame
	var along := Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg)))
	var across := Vector2(-along.y, along.x)
	await _click_uv(ctx, center, "Rect centre")
	await _click_uv(ctx, center + along * 30.0, "Rect long side")
	await _click_uv(ctx, center + across * half_w, "Rect half width")


func _draw_centreline(ctx: FilmContext, center: Vector2, along: Vector2) -> void:
	await _select_tool(ctx, "Line")
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Centerline")
	check(chip != null and chip.is_visible_in_tree(), "Centerline chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, {"keys": "Click", "desc": "Centerline"})
		await process_frame
	var dir := along.normalized()
	await _zoom_uv(ctx, center - dir * 25.0, 70.0)
	await _click_uv(ctx, center - dir * 25.0, "Centreline start")
	await _zoom_uv(ctx, center + dir * 25.0, 70.0)
	await _click_uv(ctx, center + dir * 25.0, "Centreline end")


func _edit_rect_labels(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _select_tool(ctx, "Select")
	var width_i := _dim_index_near(sm, "distance", 20.0)
	if width_i < 0:
		width_i = _dim_index_near(sm, "distance", 16.0)
	if width_i >= 0:
		await _edit_label(ctx, width_i, "20")
	var ang_i := _dim_index(sm, "angle")
	if ang_i >= 0:
		await _edit_label(ctx, ang_i, "45")
	if absf(_long_side_angle_deg(sm) - 45.0) > TOL and ang_i >= 0:
		await _edit_label(ctx, ang_i, "45")


func _edit_label(ctx: FilmContext, index: int, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[index])
	check(lp != null, "dimension label has a position")
	if lp == null:
		return
	await _zoom_uv(ctx, lp as Vector2, 50.0)
	await _click_uv(ctx, lp as Vector2, "Edit dimension label")
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension editor opened")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	var line: LineEdit = ix._dim_edit_line
	await _x11_click(line)
	await _x11_type(line.get_viewport(), text)
	await _x11_enter(line.get_viewport())
	await process_frame
	await process_frame


func _sketch_on_top(ctx: FilmContext, body: String, top: String, z_top: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await _exit_sketch(ctx)
	if top != "":
		ctx.view.select_entity(body, top)
		await process_frame
	ctx.main.interaction._refresh_selection_strip()
	await process_frame
	var sketch_btn: Button = ctx.main.interaction._strip_sketch
	if sketch_btn == null or not sketch_btn.is_visible_in_tree():
		var host := Vector3(100, 0, z_top)
		var picked := FilmUI.face_pick_point(ctx.view, body, top)
		if picked != Vector3.INF:
			host = picked
		await _zoom(ctx, host, 500.0)
		var host_screen := FilmUI.model_to_screen(ctx, host)
		if FilmUI.is_on_screen(ctx, host_screen):
			await _aim_then_click_screen(ctx.main.get_viewport(), host_screen)
			await process_frame
		ctx.view.select_entity(body, top)
		ctx.main.interaction._refresh_selection_strip()
		await process_frame
		sketch_btn = ctx.main.interaction._strip_sketch
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(),
			"selection-strip Sketch is visible")
	if sketch_btn != null and sketch_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, sketch_btn, {"keys": "Sketch", "desc": "Sketch on top face"})
		await process_frame
		await process_frame
	sm = ctx.main.sketch_mode
	if sm != null and sm.active and ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame


func _exit_sketch(ctx: FilmContext) -> void:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	check(exit_btn != null and exit_btn.is_visible_in_tree(), "Exit Sketch is visible")
	if exit_btn != null:
		await FilmUI.click_control(ctx, exit_btn, {"keys": "Exit Sketch", "desc": "Exit Sketch"})
		await process_frame
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


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[0]


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
			best = f
			best_z = z
			best_area = area
	return best


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


func _hole_circle_present(sm: SketchMode) -> bool:
	if sm == null or sm.sketch == null:
		return false
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if (info["center"] as Vector2).length() <= 1.0 \
				and absf(float(info.get("radius", 0.0)) - 5.0) <= 0.2:
			return true
	return false


func _long_side_angle_deg(sm: SketchMode) -> float:
	var best_len := -1.0
	var best_deg := -1.0
	if sm.sketch == null:
		return best_deg
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		if d.length() > best_len:
			best_len = d.length()
			var deg := absf(rad_to_deg(d.angle()))
			deg = fmod(deg, 180.0)
			if deg > 90.0:
				deg = 180.0 - deg
			best_deg = deg
	return best_deg


func _dim_index(sm: SketchMode, type_name: String) -> int:
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type_name:
			return i
	return -1


func _dim_index_near(sm: SketchMode, type_name: String, value: float) -> int:
	var best := -1
	var best_d := 4.0
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != type_name:
			continue
		var shown := sm._dimension_display_value(dim)
		var d := absf(shown - value)
		if d < best_d:
			best_d = d
			best = i
	return best
