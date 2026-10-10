# Rung 1 replan 10 WP1 — Power Trim opens the jaw when the centreline is NOT dead-centre, when the click
# is re-sent, when the stroke drags, and names every refusal.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_trim.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
## The walk's Power Trim click: 3 mm along the jaw and 8 mm across it, on the shaft side of the cutter.
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan10 WP1 power trim")
	FilmUI.reset_fail_count()
	await test_offset_cutter_then_second_click()
	await test_drag_after_success_keeps_jaw()
	await test_cutter_too_far_is_named()
	await test_hole_at_head_still_caps_on_head()
	await test_nothing_under_pointer_is_named()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


## Ø10 hole at the origin (or at `hole_c`), Ø45 head at HEAD, the 20 mm wide Jaw rectangle at 45 degrees,
## and the perpendicular cutter centreline `offset` mm along the jaw from the head centre.
func _build_jaw(sm: SketchMode, offset: float, hole_c: Vector2) -> void:
	var sk = sm.sketch
	sk.add_circle(hole_c.x, hole_c.y, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p1 := HEAD + JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p2 := HEAD + JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	var p3 := HEAD - JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + JAW_DIR * offset
	var c0 := cc - JAW_ACROSS * 25.0
	var c1 := cc + JAW_ACROSS * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()


func _open_trim_scene(offset: float, hole_c: Vector2) -> FilmContext:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	_build_jaw(ctx.main.sketch_mode, offset, hole_c)
	await _zoom_uv(ctx, HEAD, 120.0)
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.TRIM)
	check(ctx.main.sketch_mode.tool == SketchMode.Tool.TRIM, "Power Trim is the active tool")
	return ctx


func _click_at(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "trim click"), "trim click on screen at %s" % str(uv))
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame


func _drag_between(ctx: FilmContext, from_uv: Vector2, to_uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var a := FilmUI.model_to_screen(ctx, sm.to_model(from_uv))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(to_uv))
	check(FilmUI.require_on_screen(ctx, a, "trim drag start"), "trim drag start on screen")
	check(FilmUI.require_on_screen(ctx, b, "trim drag end"), "trim drag end on screen")
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	for i in range(1, 13):
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / 12.0)
		m.global_position = m.position
		vp.push_input(m)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await process_frame


func _count_status(needle: String) -> int:
	var n := 0
	for s in _status_log:
		if s.contains(needle):
			n += 1
	return n


func _status_has(needle: String) -> bool:
	return _count_status(needle) > 0


func _jaw_arc_sweep(sm: SketchMode, centre: Vector2) -> float:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "arc":
			continue
		if (info["center"] as Vector2).distance_to(centre) > 0.5:
			continue
		return wrapf(float(info.get("end_angle", 0.0)) - float(info.get("start_angle", 0.0)), 0.0, TAU)
	return -1.0


func _arc_radius_near(sm: SketchMode, centre: Vector2) -> float:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "arc" and (info["center"] as Vector2).distance_to(centre) <= 0.5:
			return float(info.get("radius", 0.0))
	return -1.0


func test_offset_cutter_then_second_click() -> void:
	print("-- cutter 12 mm along the jaw")
	var ctx := await _open_trim_scene(12.0, Vector2.ZERO)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE)
	check(_status_has("Trimmed open jaw"), "an offset cutter opens the jaw (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed"), "no Trim failed on the first click (log: %s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "the trimmed Jaw profile is closed")
	check(absf(_arc_radius_near(sm, HEAD) - 22.5) <= 0.3,
			"the head cap arc is Ø45 (radius %.2f)" % _arc_radius_near(sm, HEAD))
	var sweep := _jaw_arc_sweep(sm, HEAD)
	check(sweep > 0.05 and sweep <= PI,
			"jaw cap is the minor bulge, not the long way around the head (sweep %.3f)" % sweep)
	var lines_after_first := sm.sketch.entity_ids().size()
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE + Vector2(-3.0, -2.0))
	check(_status_has("Jaw is already open"), "a second click says the jaw is already open (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed"), "a second click is not a failure (log: %s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "the profile is still closed after the second click")
	check(sm.sketch.entity_ids().size() == lines_after_first, "the second click changes no entity (%d vs %d)" % [
			sm.sketch.entity_ids().size(), lines_after_first])
	await _shutdown(ctx)


func test_drag_after_success_keeps_jaw() -> void:
	print("-- a stroke that crosses the cutter and keeps moving")
	var ctx := await _open_trim_scene(12.0, Vector2.ZERO)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _drag_between(ctx, SHAFT_SIDE, HEAD + Vector2(0.0, 18.0))
	check(_status_has("Trimmed open jaw"), "the drag trims the jaw (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed"), "the rest of the stroke does not report Trim failed (log: %s)" % str(_status_log))
	check(not _status_has("already open"), "the rest of the stroke does not re-trim (log: %s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "the profile is closed after the stroke")
	check(_count_status("Trimmed open jaw") == 1, "the jaw is trimmed exactly once (%d)" % _count_status("Trimmed open jaw"))
	await _shutdown(ctx)


func test_cutter_too_far_is_named() -> void:
	print("-- cutter 24 mm from the head centre")
	var ctx := await _open_trim_scene(24.0, Vector2.ZERO)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE)
	check(_status_has("Trim failed — the centreline is"), "the refusal names the centreline distance (log: %s)" % str(_status_log))
	check(_status_has("head centre"), "the refusal names the head centre (log: %s)" % str(_status_log))
	check(not SketchMode.profile_is_closed(sm.sketch) or _arc_radius_near(sm, HEAD) < 0.0,
			"a refused trim does not weld a cap arc")
	await _shutdown(ctx)


func test_hole_at_head_still_caps_on_head() -> void:
	print("-- a Ø10 hole at the head centre must not become the cap")
	var ctx := await _open_trim_scene(8.0, HEAD)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE)
	check(_status_has("Trimmed open jaw"), "the jaw opens with a Ø10 at the head centre (log: %s)" % str(_status_log))
	check(absf(_arc_radius_near(sm, HEAD) - 22.5) <= 0.3,
			"the cap is the Ø45 arc, not the Ø10 (radius %.2f)" % _arc_radius_near(sm, HEAD))
	await _shutdown(ctx)


func test_nothing_under_pointer_is_named() -> void:
	print("-- Trim on empty canvas")
	var ctx := await _open_trim_scene(12.0, Vector2.ZERO)
	_status_log.clear()
	await _zoom_uv(ctx, Vector2(100.0, 90.0), 60.0)
	await _click_at(ctx, Vector2(100.0, 90.0))
	check(_status_has("nothing under the pointer"), "empty-canvas Trim is named (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed") or _status_has("Trim failed —"), "the failure is never the bare sentence")
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
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


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