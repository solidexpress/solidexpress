# Rung 1 replan 9 WP2 — Smart Dim keeps its first pick through a miss, says so, and Esc drops it without leaving the sketch.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dim.gd
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
	print("rung01 replan9 WP2 smart dim second pick")
	FilmUI.reset_fail_count()
	await test_centre_then_centre()
	await test_centre_then_edge()
	await test_esc_drops_pick()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _two_circles(ctx: FilmContext) -> Array[String]:
	var sm: SketchMode = ctx.main.sketch_mode
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	return [a, b]


func test_centre_then_centre() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var ids := await _two_circles(ctx)
	var edits: Array[int] = []
	sm.dimension_edit_requested.connect(func(i: int) -> void: edits.append(i))

	_status_log.clear()
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "the first centre click sets a pending pick")
	check(sm.selected.size() == 1 and sm.selected[0] == ids[0], "the first circle is selected")
	check(_status_has("Smart Dim: first pick set"), "the first pick says what to click next (log: %s)" % str(_status_log))

	_status_log.clear()
	await _click_uv(ctx, vp, Vector2(100.0, 80.0))
	check(_pending(sm), "a click on empty canvas keeps the first pick")
	check(sm.selected.size() == 1 and sm.selected[0] == ids[0], "the first circle stays selected after the miss")
	check(_status_has("first pick kept"), "the miss is named in the status (log: %s)" % str(_status_log))

	_status_log.clear()
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "a second click on the same circle keeps the first pick")
	check(_status_has("pick a different circle"), "the same-circle click is named (log: %s)" % str(_status_log))
	check(_distance_near(sm, 0.0, 0.5) < 0, "no zero-length distance dimension was made")

	await _click_uv(ctx, vp, Vector2(200.0, 0.0))
	await process_frame
	await process_frame
	check(not _pending(sm), "the second centre click completes the pick")
	check(sm.selected.size() == 2, "both circles are selected after the dimension (got %d)" % sm.selected.size())
	check(_distance_near(sm, 200.0, 0.5) >= 0, "a centre distance of 200 was dimensioned")
	check(not edits.is_empty(), "the dimension editor was requested")
	await _shutdown(ctx)


func test_centre_then_edge() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var ids := await _two_circles(ctx)
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "first centre pick is pending")
	await _click_uv(ctx, vp, Vector2(200.0, 22.5))
	await process_frame
	await process_frame
	check(not _pending(sm), "an edge click on the second circle completes the pick")
	check(sm.selected.size() == 2 and sm.selected.has(ids[0]) and sm.selected.has(ids[1]), "both circles are selected")
	check(_distance_near(sm, 200.0, 0.5) >= 0, "the edge pick dimensions the centre distance, 200")
	await _shutdown(ctx)


func test_esc_drops_pick() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _two_circles(ctx)
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "first centre pick is pending before Esc")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with a pending Smart Dim pick keeps the sketch open")
	check(not _pending(sm), "Esc drops the pending pick")
	check(sm.selected.is_empty(), "Esc clears the first-pick selection")
	check(_status_has("Smart Dim pick dropped"), "Esc says the pick was dropped (log: %s)" % str(_status_log))
	check(sm.sketch.entity_ids().size() == 2, "both circles are still in the sketch")
	for _i in 3:
		if not sm.active:
			break
		await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing pending still exits the sketch (after the selection and tool rungs)")
	await _shutdown(ctx)


func _pending(sm: SketchMode) -> bool:
	return sm.has_method("has_pending_dim_pick") and bool(sm.call("has_pending_dim_pick"))


func _distance_near(sm: SketchMode, value: float, tol: float) -> int:
	for i in sm.dimensions.size():
		var d: Dictionary = sm.dimensions[i]
		if str(d.get("type", "")) == "distance" and absf(float(d.get("value", -1.0)) - value) <= tol:
			return i
	return -1


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
