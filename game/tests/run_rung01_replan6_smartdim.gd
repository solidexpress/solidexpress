# Rung 1 replan 6 WP1 — second Smart Dimension centre click opens the popup.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan6_smartdim.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(201.5, 0)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan6 WP1 smartdim")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_second_centre_opens_popup()
	await test_right_half_head_stays_plus_x()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


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


func test_right_half_head_stays_plus_x() -> void:
	print("- right-half ground-sketch click, inexact tangents, Extrude 10")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open for right-half click")
	await _select_tool(ctx, "Circle")
	var ix: ViewportInteraction = ctx.main.interaction
	var canvas := ix.get_global_rect()
	var screen := Vector2(maxf(641.0, canvas.position.x + canvas.size.x * 0.72), 400.0)
	if screen.x > canvas.end.x - 8.0:
		screen.x = canvas.position.x + canvas.size.x * 0.65
	check(screen.x > 640.0, "right-half click has screen x > 640 (got %.1f)" % screen.x)
	check(FilmUI.require_on_screen(ctx, screen, "right-half head"),
			"right-half click is on screen")
	var aim := InputEventMouseMotion.new()
	aim.position = screen
	aim.global_position = screen
	ctx.main.get_viewport().push_input(aim)
	await process_frame
	var ray: Array = ix._model_ray(screen)
	var click_uv: Variant = sm.ray_to_sketch(ray[0], ray[1])
	check(click_uv is Vector2, "right-half screen ray hits the sketch plane")
	await _aim_then_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame
	check(sm._tool_points.size() >= 1, "right-half click stored a circle centre")
	var hover_uv: Vector2 = click_uv if click_uv is Vector2 else Vector2(6, 0)
	await _hover_uv(ctx, hover_uv + Vector2(6, 0))
	await _type_dim(ctx, "22.5")
	var head_id := _newest_circle(sm)
	check(head_id != "", "typed radius committed the right-half circle")
	var head_uv := Vector2.ZERO
	var head_model := Vector3.ZERO
	if head_id != "":
		head_uv = sm.sketch.entity_info(head_id)["center"]
		head_model = sm.to_model(head_uv)
		var hr := float(sm.sketch.entity_info(head_id).get("radius", 0.0))
		check(absf(hr - 22.5) <= 0.05, "typed radius 22.5 (got %.3f)" % hr)
	print("  measure: screen X=%.1f Y=%.1f → sketch UV (%.3f, %.3f) → model X=%.3f" % [
		screen.x, screen.y, head_uv.x, head_uv.y, head_model.x])
	check(head_model.x > 0.0,
			"right-half circle model X is positive (got %.3f)" % head_model.x)
	await _zoom_uv(ctx, Vector2.ZERO, 50.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10")
	# B1 then types 200 so the shaft is a real blank, not two overlapping bosses.
	var bosses := _boss_pair(sm)
	if bosses.size() >= 4 and float(bosses[2].x) < 180.0:
		await _smart_dim_centres_to(ctx, bosses[0], bosses[2], "200")
		bosses = _boss_pair(sm)
		if bosses.size() >= 4:
			head_uv = bosses[2]
			head_model = sm.to_model(head_uv)
			print("  after centre distance 200: origin (%.3f, %.3f) head (%.3f, %.3f) gap=%.3f model X=%.3f" % [
				bosses[0].x, bosses[0].y, head_uv.x, head_uv.y,
				head_uv.distance_to(bosses[0]), head_model.x])
	if bosses.size() < 4:
		bosses = _boss_pair(sm)
	check(bosses.size() >= 4, "shaft and head circles exist")
	await _select_tool(ctx, "Line")
	if bosses.size() >= 4:
		for y_sign in [1.0, -1.0]:
			await _draw_offset_shaft_line(ctx, bosses[0], float(bosses[1]),
					bosses[2], float(bosses[3]), float(y_sign), 3.0)
	await _type_distance(ctx, "10")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _x11_click(chrome.extrude_button())
	await process_frame
	await process_frame
	await process_frame
	var extrude_status := str(ctx.main.status_label.text)
	# Inexact tangents leave an open profile. Extrude refuses it and stays in the sketch.
	check(extrude_status.contains("open profile"),
			"inexact tangents are an open profile (got '%s')" % extrude_status)
	check(ctx.main.sketch_mode.active, "open profile keeps the sketch")
	check(ctx.view.doc.body_ids().is_empty(), "open profile does not create a body")
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


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
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


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	await _select_tool(ctx, "Circle")
	await _click_uv_local(ctx, center, "Circle centre")
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


func _newest_circle(sm: SketchMode) -> String:
	var last := ""
	if sm == null or sm.sketch == null:
		return last
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			last = id
	return last


func _smart_dim_centres_to(ctx: FilmContext, a: Vector2, b: Vector2, text: String) -> void:
	await _select_tool(ctx, "Smart Dimension")
	await _zoom_uv(ctx, a, 40.0)
	await _click_uv_local(ctx, a, "Smart Dim first centre")
	await _zoom_uv(ctx, b, 40.0)
	await _click_uv_local(ctx, b, "Smart Dim second centre")
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible and ix._dim_edit_line != null:
		await _x11_click(ix._dim_edit_line)
		await _x11_type(ix._dim_edit_line.get_viewport(), text)
		await _x11_enter(ix._dim_edit_line.get_viewport())
		await process_frame
		await process_frame


func _boss_pair(sm: SketchMode) -> Array:
	var circs := _circle_infos(sm)
	if circs.size() < 2:
		return []
	var left: Dictionary = circs[0]
	var right: Dictionary = circs[circs.size() - 1]
	return [left["center"], float(left["radius"]), right["center"], float(right["radius"])]


func _draw_offset_shaft_line(ctx: FilmContext, c0: Vector2, r0: float,
		c1: Vector2, r1: float, sign: float, miss: float) -> void:
	# 2–4 mm off the exact horizontal contact (the walk's far_x / y=±r0).
	# Zoom wide enough that snap (≥ span×0.02) can still catch the rim.
	var far := sqrt(maxf(r1 * r1 - r0 * r0, 0.0))
	var a_exact := c0 + Vector2(0.0, r0 * sign)
	var b_exact := Vector2(c1.x - far, c0.y + r0 * sign)
	# 2–4 mm off the exact contact, perpendicular to the shaft. First click
	# snaps to the Ø20 rim; second click H/V-snaps back onto y = ±r0 at far_x.
	var a := a_exact + Vector2(0.0, miss * sign)
	var b := b_exact + Vector2(0.0, miss * sign)
	await _zoom_uv(ctx, a, 200.0)
	await _click_uv_local(ctx, a, "Offset tangent start")
	await _zoom_uv(ctx, b, 200.0)
	await _click_uv_local(ctx, b, "Offset tangent end")
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(b))
	await _x11_right_click_screen(ctx.main.get_viewport(), screen)


func _x11_right_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
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


func _load_mesh(doc: SxDocument, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if ii.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	return [verts, idx]


func _head_centre_from_mesh(mesh: Array) -> Vector3:
	var verts: PackedVector3Array = mesh[0]
	if verts.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	var n := 0
	for v in verts:
		if absf(v.y) > 15.0:
			acc += v
			n += 1
	if n > 0:
		return acc / float(n)
	var mn := verts[0]
	var mx := verts[0]
	for v in verts:
		mn = Vector3(minf(mn.x, v.x), minf(mn.y, v.y), minf(mn.z, v.z))
		mx = Vector3(maxf(mx.x, v.x), maxf(mx.y, v.y), maxf(mx.z, v.z))
	return Vector3(mx.x - 22.5, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5)
