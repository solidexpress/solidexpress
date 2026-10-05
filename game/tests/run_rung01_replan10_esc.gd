# Rung 1 replan 10 WP3 — Esc clears a selection, then drops the tool, before it ever discards a sketch that has geometry.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_esc.gd
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
	print("rung01 replan10 WP3 Esc keeps a sketch that has geometry")
	FilmUI.reset_fail_count()
	await test_jaw_esc_ladder()
	await test_empty_sketch_esc_exits()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func test_jaw_esc_ladder() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point", "Jaw is the active tool")
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(30.0, 0.0))
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	check(_profile_lines(sm) == 4, "the Jaw rectangle has four lines (got %d)" % _profile_lines(sm))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	check(sm.selected.size() == 1, "one Jaw line is selected (got %d)" % sm.selected.size())

	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "the first Esc after selecting a Jaw line keeps the sketch open")
	check(_status_has("Measure cleared"), "the first Esc clears the measure pair (log: %s)" % str(_status_log))
	check(_profile_lines(sm) == 4, "the Jaw lines are all still there (got %d)" % _profile_lines(sm))

	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "the second Esc keeps the sketch open")
	check(sm.selected.is_empty(), "the second Esc clears the selection")
	check(_profile_lines(sm) == 4, "the Jaw lines survive the selection clear (got %d)" % _profile_lines(sm))
	check(_status_has("Selection cleared — Esc again exits the sketch"),
			"Esc names what it dropped (log: %s)" % str(_status_log))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT, "Jaw is the active tool again")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with the Jaw tool active and geometry drawn keeps the sketch open")
	check(sm.tool == SketchMode.Tool.SELECT, "Esc drops the Jaw tool back to Select")
	check(_profile_lines(sm) == 4, "the Jaw lines survive the tool drop (got %d)" % _profile_lines(sm))
	check(_status_has("Tool dropped — Esc again exits the sketch"),
			"the tool drop is named (log: %s)" % str(_status_log))

	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing selected and the Select tool still exits the sketch")
	await _shutdown(ctx)


func test_empty_sketch_esc_exits() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	check(sm.sketch.entity_ids().is_empty(), "the sketch is empty")
	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc in an empty sketch with a tool active exits at once")
	await _shutdown(ctx)

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
