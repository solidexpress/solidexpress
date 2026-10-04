# Rung 1 replan 3 WP3 — inference-on wrench blank and jaw angle at 1280×800.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan3_blank.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const TOL := 0.2
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan3 WP3 blank")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan3_blank.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	await test_tangent_blank_and_open_vertex()
	await test_jaw_angle_held()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


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


func _latest_status(ctx: FilmContext) -> String:
	if not _status_log.is_empty():
		return _status_log[_status_log.size() - 1]
	if ctx.main != null and ctx.main.status_label != null:
		return str(ctx.main.status_label.text)
	return ""


func test_tangent_blank_and_open_vertex() -> void:
	print("- one tangent names the open vertex; two tangents extrude 232.5×45×10")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	check(sm.infer_enabled, "inference stays on")
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10")
	await _zoom_uv(ctx, Vector2(200, 0), 80.0)
	await _draw_circle_typed(ctx, Vector2(200, 0), "22.5")
	var circs := _circles(sm)
	check(circs.size() == 2, "blank has two circles")
	if circs.size() != 2:
		await _shutdown(ctx)
		return
	circs.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	var c1: Vector2 = circs[0]["center"]
	var c2: Vector2 = circs[1]["center"]
	var r1 := float(circs[0]["radius"])
	var r2 := float(circs[1]["radius"])
	var tangents := _external_tangents(c1, r1, c2, r2)
	check(tangents.size() == 2, "two external tangents")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	check(sm.infer_enabled, "inference stays on for the shaft lines")
	if tangents.size() >= 1:
		await _draw_tangent_segment(ctx, tangents[0], c1, c2)
	await _release_gui_focus(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _type_distance(ctx, "10")
	var thin: CheckButton = chrome.find_child("ThinFeature", true, false)
	check(thin == null or not thin.button_pressed, "Thin wall stays off")
	var before := _count_type(ctx, "extrude")
	await _press_extrude(ctx, "Extrude with one tangent missing")
	await process_frame
	await process_frame
	var st := _latest_status(ctx)
	check(st.contains("open profile at"), "open status contains open profile at (%s)" % st)
	check(st.contains("(") and st.contains(","), "open status names a coordinate (%s)" % st)
	check(not st.contains("Thin wall"), "open status does not mention Thin wall (%s)" % st)
	check(not st.contains("Insert Box"), "open status does not mention Insert Box (%s)" % st)
	check(sm.active, "open profile leaves the sketch session up")
	check(_count_type(ctx, "extrude") == before, "one tangent added no extrude")
	if tangents.size() >= 2:
		await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
		await _draw_tangent_segment(ctx, tangents[1], c1, c2)
	circs = _circles(sm)
	circs.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	if circs.size() == 2:
		check(absf(float(circs[0]["radius"]) - 10.0) <= 0.05, "Ø20 radius still 10")
		check(absf(float(circs[1]["radius"]) - 22.5) <= 0.05, "Ø45 radius still 22.5")
		var small: Vector2 = circs[0]["center"]
		check(small.length() <= 0.2, "small centre stays at origin (got %s)" % small)
	await _assert_thin_off(ctx)
	await _type_distance(ctx, "10")
	before = _count_type(ctx, "extrude")
	await _press_extrude(ctx, "Extrude closed wrench blank 10")
	await process_frame
	await process_frame
	st = _latest_status(ctx)
	check(not st.contains("open profile"), "closed blank status is not an open profile (%s)" % st)
	check(_count_type(ctx, "extrude") == before + 1, "blank extrude added")
	check(_count_type(ctx, "primitive") == 0, "blank is not a primitive")
	var body := _only_body(ctx)
	check(body != "", "wrench body exists")
	if body != "":
		var bb: Dictionary = ctx.view.doc.measure_bbox(body)
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		var ext: Vector3 = mx - mn
		check(absf(ext.x - 232.5) <= TOL, "blank bbox X %.3f" % ext.x)
		check(absf(ext.y - 45.0) <= TOL, "blank bbox Y %.3f" % ext.y)
		check(absf(ext.z - 10.0) <= TOL, "blank bbox Z %.3f" % ext.z)
		check(absf(mn.x + 10.0) <= TOL, "blank min X %.3f (want -10)" % mn.x)
		check(absf(mx.x - 222.5) <= TOL, "blank max X %.3f (want 222.5)" % mx.x)
	check(ctx.view.doc.body_ids().size() == 1, "one body, no extra insert")
	await _shutdown(ctx)


func test_jaw_angle_held() -> void:
	print("- centre rect width 20→21 keeps the long side at 45°")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "jaw sketch session is open")
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center Three Point", "Centre rectangle"))
	var along := Vector2(cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)))
	var across := Vector2(-along.y, along.x)
	await _click_uv(ctx, Vector2.ZERO, "Rect centre")
	await _click_uv(ctx, along * 30.0, "Rect long side")
	await _click_uv(ctx, across * 8.0, "Rect half width")
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var width_i := _dim_index_near(sm, "distance", 16.0)
	check(width_i >= 0, "width dimension exists before the edit")
	if width_i >= 0:
		await _edit_label(ctx, width_i, "20")
	var ang_i := _dim_index(sm, "angle")
	check(ang_i >= 0, "angle-to-horizontal dimension exists")
	if ang_i >= 0:
		await _edit_label(ctx, ang_i, "45")
	width_i = _dim_index_near(sm, "distance", 20.0)
	if width_i >= 0:
		await _edit_label(ctx, width_i, "21")
	await process_frame
	width_i = _dim_index_near(sm, "distance", 21.0)
	ang_i = _dim_index(sm, "angle")
	var width_shown := -1.0
	var ang_shown := -1.0
	if width_i >= 0:
		width_shown = float(sm._dimension_display_value(sm.dimensions[width_i]))
	if ang_i >= 0:
		ang_shown = absf(float(sm._dimension_display_value(sm.dimensions[ang_i])))
	check(absf(width_shown - 21.0) <= TOL, "width is 21 (got %.3f)" % width_shown)
	check(absf(ang_shown - 45.0) <= TOL, "angle label stays 45° (got %.3f)" % ang_shown)
	var short_len := _shortest_real_line(sm)
	check(absf(short_len - 21.0) <= TOL, "short side is 21 (got %.3f)" % short_len)
	var orient := _long_side_angle_deg(sm)
	check(absf(orient - 45.0) <= TOL, "long side is 45° ± 0.2 (got %.3f)" % orient)
	await _shutdown(ctx)


func _draw_tangent_segment(ctx: FilmContext, pair: Dictionary, c1: Vector2, c2: Vector2) -> void:
	var a: Vector2 = pair["a"]
	var b: Vector2 = pair["b"]
	var a_off := a + (a - c1).normalized() * 0.3
	var b_off := b + (b - c2).normalized() * 0.3
	await _zoom_uv(ctx, a_off, 90.0)
	await _click_uv(ctx, a_off, "Tangent start near circle")
	await _zoom_uv(ctx, b_off, 90.0)
	await _click_uv(ctx, b_off, "Tangent end near circle")
	await _right_click_uv(ctx, b_off)


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, center, "Circle centre")
	await _hover_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text)


func _type_dim(ctx: FilmContext, text: String) -> void:
	var edit: LineEdit = ctx.main.sketch_chrome._dim_spin.get_line_edit()
	await _click_control(edit)
	await _click_control(edit)
	await _type_text(edit.get_viewport(), text)
	await _push_key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame


func _type_distance(ctx: FilmContext, text: String) -> void:
	var edit: LineEdit = ctx.main.sketch_chrome._extrude_spin.get_line_edit()
	await _click_control(edit)
	await _click_control(edit)
	await _type_text(edit.get_viewport(), text)
	await process_frame
	await process_frame


func _press_extrude(ctx: FilmContext, desc: String) -> void:
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Extrude", desc))
	await process_frame
	await process_frame


func _assert_thin_off(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var thin: CheckButton = chrome.find_child("ThinFeature", true, false)
	check(thin == null or not thin.button_pressed, "Thin feature stays off")
	if chrome._thin_spin != null:
		check(absf(chrome._thin_spin.value) < 0.01, "thin thickness stays 0")


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
	var ix = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension editor opened")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	await _type_popup(ctx, ix._dim_edit_line, text)


func _type_popup(ctx: FilmContext, edit: LineEdit, text: String) -> void:
	edit.grab_focus()
	await process_frame
	var sel := edit.get_selected_text()
	check(sel == edit.text and sel != "", "dimension popup text is selected ('%s')" % sel)
	await _type_text(edit.get_viewport(), text)
	await _push_key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		await _push_key(vp, _keycode_for_char(ch), ch.unicode_at(0))


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
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
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _keycode_for_char(ch: String) -> Key:
	var c := ch.unicode_at(0)
	if ch == ".":
		return KEY_PERIOD
	if c >= 48 and c <= 57:
		return (KEY_0 + (c - 48)) as Key
	return KEY_NONE


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _pointer_click(ctx, screen)


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


func _right_click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _push_mouse(ctx.main.get_viewport(), screen, MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(ctx.main.get_viewport(), screen, MOUSE_BUTTON_RIGHT, false)


func _pointer_click(ctx: FilmContext, pos: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	await _push_mouse(vp, pos, MOUSE_BUTTON_LEFT, true)
	await _push_mouse(vp, pos, MOUSE_BUTTON_LEFT, false)


func _push_mouse(vp: Viewport, pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	if pressed and button == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(ev)
	await process_frame


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _push_mouse(vp, pos, MOUSE_BUTTON_LEFT, true)
	await _push_mouse(vp, pos, MOUSE_BUTTON_LEFT, false)


func _release_gui_focus(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var focus: Control = vp.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _external_tangents(c1: Vector2, r1: float, c2: Vector2, r2: float) -> Array:
	var d := c2 - c1
	var dist := d.length()
	var along := (r2 - r1) / dist
	var perp := sqrt(maxf(0.0, 1.0 - along * along))
	var u := d / dist
	var side := Vector2(-u.y, u.x)
	var out: Array = []
	for sign in [1.0, -1.0]:
		var s := float(sign)
		var n: Vector2 = u * along + side * (perp * s)
		out.append({"a": c1 - n * r1, "b": c2 - n * r2})
	return out


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	return out


func _count_type(ctx: FilmContext, type: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == type:
			n += 1
	return n


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[0]


func _dim_index(sm: SketchMode, type_name: String) -> int:
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type_name:
			return i
	return -1


func _dim_index_near(sm: SketchMode, type_name: String, value: float) -> int:
	var best := -1
	var best_d := 1.5
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != type_name:
			continue
		var d := absf(sm._dimension_display_value(dim) - value)
		if d < best_d:
			best_d = d
			best = i
	return best


func _shortest_real_line(sm: SketchMode) -> float:
	var best := INF
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		best = minf(best, d.length())
	return best


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
