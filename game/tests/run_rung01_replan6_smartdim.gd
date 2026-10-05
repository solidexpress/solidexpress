# Rung 1 replan 6 WP1 — second Smart Dimension centre click opens the popup.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan6_smartdim.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(201.5, 0)

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
	print("rung01 replan6 WP1 smartdim")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_second_centre_opens_popup()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan6_smartdim.gd")
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
	check(not src.contains("current_dir" + " ="), "test source does not assign dialog dir")
	check(not src.contains("sketch_mode.cancel" + "("), "test source does not call cancel")
	check(not src.contains("sketch_mode.exit_sketch" + "("), "test source does not call exit_sketch")
	check(not src.contains("sketch_mode.trim_at" + "("), "test source does not call trim_at")
	check(not src.contains("new_document" + "("), "test source does not call new_document")
	check(not src.contains("graph_update_sketch" + "("), "test source does not call graph_update_sketch")
	check(not src.contains("dimension_edit_requested" + ".emit"),
			"test source does not emit dimension_edit_requested")
	check(not src.contains("_dimension_label" + "_pos2"),
			"test source does not click a computed dimension label")
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


func test_second_centre_opens_popup() -> void:
	print("- two circles, Smart Dimension centres, popup on the second click")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10")
	await _zoom_uv(ctx, HEAD, 80.0)
	await _draw_circle_typed(ctx, HEAD, "22.5")
	var circs := _circle_infos(sm)
	check(circs.size() >= 2, "two circles exist (got %d)" % circs.size())
	var gap0 := 0.0
	if circs.size() >= 2:
		gap0 = (circs[0]["center"] as Vector2).distance_to(circs[1]["center"])
		check(gap0 >= 180.0 and gap0 <= 220.0,
				"centres are 180–220 mm apart (got %.3f)" % gap0)
	await _select_tool(ctx, "Smart Dimension")
	await _zoom_uv(ctx, Vector2.ZERO, 40.0)
	var s0 := FilmUI.model_to_screen(ctx, sm.to_model(Vector2.ZERO))
	check(FilmUI.require_on_screen(ctx, s0, "first centre"), "first centre is on screen")
	await _x11_click_screen(ctx.main.get_viewport(), s0)
	await process_frame
	await _zoom_uv(ctx, HEAD, 40.0)
	var s1 := FilmUI.model_to_screen(ctx, sm.to_model(HEAD))
	check(FilmUI.require_on_screen(ctx, s1, "second centre"), "second centre is on screen")
	_status_log.clear()
	await _x11_click_screen(ctx.main.get_viewport(), s1)
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"popup is visible after the second centre click, before any label click")
	var status_text := str(ctx.main.status_label.text)
	print("  status after second centre: %s" % status_text)
	check(ix._dim_edit_line != null, "popup line edit exists")
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible and ix._dim_edit_line != null:
		await _x11_click(ix._dim_edit_line)
		await _x11_type(ix._dim_edit_line.get_viewport(), "200")
		await _x11_enter(ix._dim_edit_line.get_viewport())
		await process_frame
		await process_frame
	circs = _circle_infos(sm)
	var gap1 := gap0
	if circs.size() >= 2:
		gap1 = (circs[0]["center"] as Vector2).distance_to(circs[1]["center"])
	check(absf(gap1 - 200.0) <= 0.2, "centre distance is 200 ± 0.2 (got %.3f)" % gap1)
	check(absf(gap1 - gap0) > 0.05 or absf(gap0 - 200.0) <= 0.2,
			"blank is not left at the original click gap (%.3f → %.3f)" % [gap0, gap1])
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
	await _aim_then_click_screen(ctx.main.get_viewport(), screen)
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


func _circle_infos(sm: SketchMode) -> Array:
	var out: Array = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	out.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	return out
