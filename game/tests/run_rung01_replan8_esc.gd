# Rung 1 replan 8 WP4 — Esc drops a pending first point without leaving the sketch; Esc after Extrude clears the body;
# the palette Sketch button plus ONE click on the top face starts a face sketch.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_esc.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
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
	print("rung01 replan8 WP4 Esc ladder and one-click face")
	FilmUI.reset_fail_count()
	await test_esc_ladder()
	await test_one_click_face()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_esc_ladder() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await process_frame
	check(sm.has_pending_draw_point(), "one Circle click leaves a pending first point")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with a pending first point keeps the sketch open")
	check(not sm.has_pending_draw_point(), "Esc drops the pending first point")
	check(_status_has("First point dropped"), "Esc says the first point was dropped (log: %s)" % str(_status_log))
	var entities := sm.sketch.entity_ids().size()
	check(entities == 0, "no circle was created by the dropped point (got %d entities)" % entities)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(10, 0))
	await process_frame
	var r := 0.0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			r = float(info.get("radius", 0.0))
	check(absf(r - 10.0) < 0.6, "after the dropped point a fresh two-click circle has r~10 (got %.2f)" % r)
	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing pending still exits the sketch")
	await _shutdown(ctx)


func test_one_click_face() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	_add_rect(sm, 40.0, 30.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	var body: String = doc.body_ids()[0]
	check(ctx.view.selected_body == body, "Extrude leaves the new body selected")
	await _x11_key(vp, KEY_ESCAPE)
	check(ctx.view.selected_body == "" and ctx.view.selection_size() == 0, "Esc after Extrude clears the body selection")
	await _top_zoom(ctx, Vector3(20, 15, 10), 90.0)
	var palette_sketch := FilmUI.find_palette_sketch_button(ctx.main)
	check(palette_sketch != null, "palette Sketch button exists")
	await _x11_click(palette_sketch)
	await process_frame
	check(ctx.main.interaction._picking_sketch_host, "Sketch with nothing selected arms the host pick")
	check(ctx.main.status_label.text.contains("Select a face"), "status asks for a face (got %s)" % ctx.main.status_label.text)
	var pt := FilmUI.model_to_screen(ctx, Vector3(30, 8, 10))
	check(FilmUI.require_on_screen(ctx, pt, "top face click"), "the top face click is on screen")
	await _x11_click_screen(vp, pt)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5 and sm.plane_normal().z > 0.9,
			"ONE click on the top face starts a sketch on z = 10")
	await _shutdown(ctx)


func _add_rect(sm: SketchMode, w: float, h: float) -> void:
	sm.sketch.add_line(0, 0, w, 0)
	sm.sketch.add_line(w, 0, w, h)
	sm.sketch.add_line(w, h, 0, h)
	sm.sketch.add_line(0, h, 0, 0)


func _top_zoom(ctx: FilmContext, pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	cam.sketch_orientation_locked = false
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.yaw = 0.0
	cam.pitch = deg_to_rad(89.0)
	cam.pivot = ctx.main.model_space.to_global(pivot)
	cam.distance = size_mm / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false

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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


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


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


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


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
