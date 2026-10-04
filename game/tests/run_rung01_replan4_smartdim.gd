# Rung 1 replan 4 WP3 — Smart Dimension first-key replace at 1280×800.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan4_smartdim.gd
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
	print("rung01 replan4 WP3 smartdim")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_smart_dim_first_key_replace()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan4_smartdim.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("set_dimension" + "_value"), "test source has no dimension setter")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("focus_dim" + "_for_typing"), "test source has no dim typing helper")
	check(not src.contains("focus_distance" + "_for_typing"), "test source has no distance typing helper")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	check(not src.contains("set_up_to" + "_face"), "test source has no face-id setter")
	check(not src.contains("set_finish" + "_op"), "test source has no finish-op setter")
	check(not src.contains("set_finish" + "_end"), "test source has no finish-end setter")
	check(not src.contains("export_3mf" + "("), "test source has no export_3mf call")
	check(not src.contains("infer_enabled" + " = false"), "test source does not disable inference")


func test_smart_dim_first_key_replace() -> void:
	print("- two centres, Smart Dimension, type 200 replaces the old distance")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	await _zoom(ctx, Vector3(90, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "First circle centre")
	await _click_uv(ctx, Vector2(15, 0), "First circle rim")
	await process_frame
	await _zoom_uv(ctx, Vector2(180, 0), 80.0)
	await _click_uv(ctx, Vector2(180, 0), "Second circle centre")
	await _click_uv(ctx, Vector2(195, 0), "Second circle rim")
	await process_frame
	var circs := _circles(sm)
	check(circs.size() == 2, "two circles via viewport clicks (got %d)" % circs.size())
	if circs.size() != 2:
		await _shutdown(ctx)
		return
	circs.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	var c1: Vector2 = circs[0]["center"]
	var c2: Vector2 = circs[1]["center"]
	var gap0 := c1.distance_to(c2)
	check(absf(gap0 - 200.0) > 5.0, "centres are not already 200 (got %.3f)" % gap0)
	check(absf(gap0 - 180.0) <= 8.0, "centres about 180 mm apart (got %.3f)" % gap0)
	await _zoom(ctx, Vector3(90, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _zoom_uv(ctx, c1, 50.0)
	await _click_uv(ctx, c1, "Smart Dimension first centre")
	await _zoom_uv(ctx, c2, 50.0)
	await _click_uv(ctx, c2, "Smart Dimension second centre")
	await process_frame
	await process_frame
	var di := _distance_dim_index(sm)
	check(di >= 0, "distance dimension exists after two centres")
	var n_dims := sm.dimensions.size()
	check(n_dims >= 1, "at least one dimension is recorded")
	var miss := Vector2(90, 80)
	await _zoom_uv(ctx, miss, 80.0)
	await _click_uv(ctx, miss, "Miss the dimension label")
	await process_frame
	check(sm.active, "miss click does not exit the sketch")
	check(sm.dimensions.size() == n_dims,
			"miss click does not create a second dimension (got %d want %d)" % [
				sm.dimensions.size(), n_dims])
	di = _distance_dim_index(sm)
	check(di >= 0, "distance dimension still exists after the miss")
	if di < 0:
		await _shutdown(ctx)
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	check(lp != null, "dimension label has a position")
	if lp == null:
		await _shutdown(ctx)
		return
	await _zoom_uv(ctx, lp as Vector2, 50.0)
	await _click_uv(ctx, lp as Vector2, "Click dimension label")
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"dimension popup is visible after the label click")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		await _shutdown(ctx)
		return
	var line: LineEdit = ix._dim_edit_line
	check(line != null, "popup line edit exists")
	await _x11_click(line)
	check(ix._dim_edit_popup.visible, "popup stays visible after clicking the line")
	var old := str(line.text)
	print("  popup before type: '%s'" % old)
	check(old.strip_edges() != "" and old.strip_edges() != "200",
			"popup holds the current distance, not 200 ('%s')" % old)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dim_blank := _dim_blank(chrome)
	var dist_blank := _distance_blank(chrome)
	var dim_before := "" if dim_blank == null else str(dim_blank.text)
	var dist_before := "" if dist_blank == null else str(dist_blank.text)
	var vp: Viewport = line.get_viewport()
	await _x11_type(vp, "2")
	var after_first := str(line.text)
	print("  popup after first char: '%s'" % after_first)
	check(after_first.strip_edges() == "2",
			"first key replaced the old distance (got '%s' old '%s')" % [after_first, old])
	check(not after_first.contains(old.strip_edges() + "2"),
			"first key did not append 2 onto the old text")
	check(not after_first.contains("200"),
			"after first character the line is not old text with 200 appended")
	await _x11_type(vp, "00")
	var typed := str(line.text)
	print("  popup after 200: '%s'" % typed)
	check(typed.strip_edges().begins_with("200"),
			"popup line is 200 after typing (got '%s')" % typed)
	check(not typed.contains(old.strip_edges() + "200"),
			"typed 200 did not glue onto the old distance")
	await _x11_enter(vp)
	await process_frame
	await process_frame
	check(ix._dim_edit_popup == null or not ix._dim_edit_popup.visible,
			"Enter closed the popup")
	di = _distance_dim_index(sm)
	var shown := -1.0
	if di >= 0:
		shown = float(sm._dimension_display_value(sm.dimensions[di]))
	check(absf(shown - 200.0) <= TOL, "constraint value is 200 ± 0.2 (got %.3f)" % shown)
	circs = _circles(sm)
	circs.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	if circs.size() == 2:
		var gap := (circs[0]["center"] as Vector2).distance_to(circs[1]["center"] as Vector2)
		check(absf(gap - 200.0) <= TOL, "centre distance is 200 ± 0.2 (got %.3f)" % gap)
	else:
		check(false, "two circles remain after the edit")
	check(sm.active, "sketch stays open after the dimension edit")
	if dim_blank != null:
		var dim_after := str(dim_blank.text)
		check(not dim_after.contains("200"),
				"popup keys did not land in the dim blank ('%s' before '%s')" % [
					dim_after, dim_before])
	if dist_blank != null:
		var dist_after := str(dist_blank.text)
		check(not dist_after.contains("200"),
				"popup keys did not land in Distance ('%s' before '%s')" % [
					dist_after, dist_before])
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


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	vp.push_input(up)
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	return out


func _distance_dim_index(sm: SketchMode) -> int:
	for i in sm.dimensions.size():
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != "distance":
			continue
		var ids: Array = dim.get("ids", [])
		if ids.size() >= 2:
			return i
	return -1


func _dim_blank(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null or chrome._dim_spin == null:
		return null
	return chrome._dim_spin.get_line_edit()


func _distance_blank(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null or chrome._extrude_spin == null:
		return null
	return chrome._extrude_spin.get_line_edit()
