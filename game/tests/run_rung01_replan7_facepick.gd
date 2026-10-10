# Rung 1 replan 7 WP1 — a click on a solid face selects the face; a pad wins only on its ink.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan7_facepick.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan7 WP1 facepick")
	FilmUI.reset_fail_count()
	await test_face_click_beats_hidden_pad()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _sketch_feature_ids(ctx: FilmContext) -> Array:
	var out: Array = []
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			out.append(str(f.get("id", "")))
	return out


func _open_sketch_id(ctx: FilmContext) -> String:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return ""
	return str(ctx.main.get_active_sketch_feature_id()) if ctx.main.has_method("get_active_sketch_feature_id") else "open"


func test_face_click_beats_hidden_pad() -> void:
	print("- face click, hidden pad, ink click")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(20, 15, 0), 90.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await _click_uv(ctx, Vector2.ZERO, "Rect corner A")
	await _click_uv(ctx, Vector2(40, 30), "Rect corner B")
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	await _x11_click(dist)
	await _x11_type(dist.get_viewport(), "10")
	await process_frame
	await _x11_click(chrome.extrude_button())
	for i in 3:
		await process_frame
	var body := _first_body(ctx)
	check(body != "", "10 mm blank exists")
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	var sketches_before := _sketch_feature_ids(ctx).size()
	check(sketches_before == 1, "one sketch feature before the face click (got %d)" % sketches_before)

	await _zoom_top(ctx, Vector3(20, 15, 10), 90.0)
	var ix: ViewportInteraction = ctx.main.interaction
	var vp: Viewport = ctx.main.get_viewport()
	var face_pt := FilmUI.model_to_screen(ctx, Vector3(30, 8, 10))
	check(FilmUI.require_on_screen(ctx, face_pt, "top face click"), "top face click is on screen")
	await _x11_key(vp, KEY_ESCAPE)
	await _x11_click_screen(vp, face_pt)
	await process_frame
	sm = ctx.main.sketch_mode
	check(not sm.active, "first click on the top face does not reopen Sketch 1")
	check(ctx.view.selected_body == body, "first click on the top face selects the body")
	await _x11_click_screen(vp, face_pt)
	await process_frame
	sm = ctx.main.sketch_mode
	check(not sm.active, "second click on the top face does not reopen Sketch 1")
	check(ctx.view.selected_face == top, "second click on the top face selects the top face")
	check(ix._strip_sketch.visible, "the selection strip offers Sketch")

	await _x11_click(ix._strip_sketch)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5 and sm.plane_normal().z > 0.9,
			"Sketch from the strip opens on the top face")
	await _zoom_uv(ctx, Vector2(20, 15), 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2(20, 15), "Hole centre")
	await _click_uv(ctx, Vector2(25, 15), "Hole radius")
	await process_frame
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	await _x11_click(exit_btn)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(not sm.active, "Exit Sketch leaves the top sketch")
	var sketches_mid := _sketch_feature_ids(ctx).size()
	check(sketches_mid == 2, "two sketch features after the top sketch (got %d)" % sketches_mid)

	await _zoom_top(ctx, Vector3(20, 15, 10), 90.0)
	await _x11_key(vp, KEY_ESCAPE)
	check(ctx.view.selected_face == "", "a click on empty space clears the face selection")
	var off_ink := FilmUI.model_to_screen(ctx, Vector3(32, 6, 10))
	await _x11_click_screen(vp, off_ink)
	await process_frame
	check(not ctx.main.sketch_mode.active, "a face click away from the sketch ink does not reopen that sketch")
	check(ctx.view.selected_body == body, "a face click away from the ink selects the body")
	await _x11_click_screen(vp, off_ink)
	await process_frame
	check(not ctx.main.sketch_mode.active, "a second click away from the ink does not reopen that sketch")
	check(ctx.view.selected_face == top, "a second click away from the ink selects the top face")

	await _x11_key(vp, KEY_ESCAPE)
	var palette_sketch := FilmUI.find_palette_sketch_button(ctx.main)
	check(palette_sketch != null, "palette Sketch button exists")
	await _x11_click(palette_sketch)
	await process_frame
	check(ctx.main.interaction._picking_sketch_host, "Sketch with nothing selected arms the host pick")
	await _x11_click_screen(vp, off_ink)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and sm.editing_fid == "", "host pick on the top face starts a new sketch, not an edit")
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5 and sm.plane_normal().z > 0.9,
			"host pick on the top face puts the new sketch on z = 10")
	check(_sketch_feature_ids(ctx).size() == 2, "host pick adds no sketch feature before drawing")
	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch"))
	await process_frame
	await process_frame
	await _zoom_top(ctx, Vector3(20, 15, 10), 90.0)
	await _x11_key(vp, KEY_ESCAPE)

	var on_ink := FilmUI.model_to_screen(ctx, Vector3(30, 15, 10))
	await _x11_click_screen(vp, on_ink)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "a click on the circle ink reopens the top sketch")
	check(_sketch_feature_ids(ctx).size() == 2, "reopening adds no sketch feature")
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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
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


func _first_body(ctx: FilmContext) -> String:
	if ctx.view == null or ctx.view.doc == null:
		return ""
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return str(ids[0])


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var fbb: Dictionary = ctx.view.doc.measure_bbox(f)
		if fbb.is_empty():
			continue
		var fext: Vector3 = fbb["max"] - fbb["min"]
		var span := maxf(fext.x, fext.y)
		if fext.z > 0.5 and fext.z > span * 0.05:
			continue
		var z: float = fbb["max"].z if z_sign > 0 else fbb["min"].z
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


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


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


func _x11_key(vp: Viewport, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _zoom_top(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.yaw = PI
	cam.pitch = deg_to_rad(89.0)
	await _zoom(ctx, model_pivot, size_mm)


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


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


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
