# sx-035 A9 — Power Trim opens the UBC wrench jaw when the cutter is a regular
# Line (not Centerline / construction) and the pointer drags across the jaw.
# Template: run_rung01_replan10_trim.gd (viewport drag) + run_rung01_replan13_trim.gd (Jaw path).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan14_trim.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0
const OUTER_SHORT := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 30.0
const LONG_DISCARD := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 10.0
const CUTTER_MID := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 12.0

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
	print("rung01 replan14 A9 Power Trim with a profile Line cutter")
	FilmUI.reset_fail_count()
	await test_drag_outer_short_opens_jaw()
	await test_drag_long_side_opens_jaw()
	await test_drag_across_cutter_opens_jaw()
	await test_horizontal_line_through_head()
	await test_second_stroke_already_open()
	await test_rectangle_without_circle_is_not_jaw_trim()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_drag_outer_short_opens_jaw() -> void:
	print("-- drag across the outer short side (profile Line cutter)")
	var ctx := await _open_line_cutter_scene("perp")
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _drag_between(ctx, OUTER_SHORT + JAW_DIR * 4.0, OUTER_SHORT - JAW_DIR * 4.0)
	_assert_opened(sm, "outer-short drag")
	await _shutdown(ctx)


func test_drag_long_side_opens_jaw() -> void:
	print("-- drag across a long jaw side outside the cutter")
	var ctx := await _open_line_cutter_scene("perp")
	var sm: SketchMode = ctx.main.sketch_mode
	var before := _entity_span(sm)
	_status_log.clear()
	await _drag_between(ctx, LONG_DISCARD + JAW_ACROSS * 4.0, LONG_DISCARD - JAW_ACROSS * 4.0)
	_assert_opened(sm, "long-side drag")
	check(_entity_span(sm) > 20.0, "long-side drag does not collapse the jaw (span %.2f, was %.2f)" % [
			_entity_span(sm), before])
	await _shutdown(ctx)


func test_drag_across_cutter_opens_jaw() -> void:
	print("-- drag across the cutter Line itself")
	var ctx := await _open_line_cutter_scene("perp")
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _drag_between(ctx, CUTTER_MID - JAW_DIR * 6.0, CUTTER_MID + JAW_DIR * 6.0)
	_assert_opened(sm, "cutter-line drag")
	await _shutdown(ctx)


func test_horizontal_line_through_head() -> void:
	print("-- a long horizontal profile Line through the head (screenshot topology)")
	var ctx := await _open_line_cutter_scene("horiz")
	var sm: SketchMode = ctx.main.sketch_mode
	var sides := sm._jaw_long_sides()
	check(sides.size() == 2, "jaw long sides stay the rectangle walls, not the horizontal Line (n=%d)" % sides.size())
	if sides.size() == 2:
		var d: Vector2 = (sides[0]["b"] as Vector2) - (sides[0]["a"] as Vector2)
		check(sm._dirs_within_deg(d, JAW_DIR, 2.0), "long-side dir is the 45° jaw, not +X")
	_status_log.clear()
	await _drag_between(ctx, OUTER_SHORT + JAW_DIR * 4.0, OUTER_SHORT - JAW_DIR * 4.0)
	_assert_opened(sm, "horizontal-cutter drag")
	await _shutdown(ctx)


func test_second_stroke_already_open() -> void:
	print("-- a second trim stroke says the jaw is already open")
	var ctx := await _open_line_cutter_scene("perp")
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _drag_between(ctx, SHAFT_SIDE, HEAD + Vector2(0.0, 18.0))
	check(_status_has("Trimmed open jaw"), "first stroke opens the jaw (log=%s)" % str(_status_log))
	var n := sm.sketch.entity_ids().size()
	_status_log.clear()
	await _drag_between(ctx, SHAFT_SIDE + Vector2(-2.0, -2.0), HEAD + Vector2(0.0, 16.0))
	check(_status_has("Jaw is already open"), "second stroke: Jaw is already open (log=%s)" % str(_status_log))
	check(not _status_has("Trim failed"), "second stroke is not a failure (log=%s)" % str(_status_log))
	check(sm.sketch.entity_ids().size() == n, "second stroke changes no entity")
	await _shutdown(ctx)


func test_rectangle_without_circle_is_not_jaw_trim() -> void:
	print("-- a rectangle + crossing Line with no head circle still kernel-trims")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.sketch.add_line(10, -10, 10, 30)
	sm.run_solve()
	await _zoom_model(ctx, sm.to_model(Vector2(20, 10)), 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	_status_log.clear()
	await _click_uv(ctx, Vector2(30, 0), "kernel trim on a rectangle side")
	check(not _status_has("Trimmed open jaw"), "no circle: not an open-jaw trim (log=%s)" % str(_status_log))
	check(not _status_has("no head circle"), "no circle: does not consume the click as a jaw refusal (log=%s)" % str(_status_log))
	await _shutdown(ctx)


func _assert_opened(sm: SketchMode, tag: String) -> void:
	check(_status_has("Trimmed open jaw"), "%s status is Trimmed open jaw (log=%s)" % [tag, str(_status_log)])
	check(not _status_has("no crossing to trim at"), "%s is not a kernel miss (log=%s)" % [tag, str(_status_log)])
	check(SketchMode.profile_is_closed(sm.sketch), "%s trimmed profile is closed" % tag)
	check(absf(_arc_radius_near(sm, HEAD) - 22.5) <= 0.3,
			"%s head cap arc is Ø45 (radius %.2f)" % [tag, _arc_radius_near(sm, HEAD)])
	check(_entity_span(sm) > 20.0, "%s jaw did not collapse (span %.2f)" % [tag, _entity_span(sm)])
	check(sm.last_conflicting.is_empty(), "%s last_conflicting empty" % tag)


func _open_line_cutter_scene(kind: String) -> FilmContext:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	var prev_snap := sm.snap_enabled
	sm.snap_enabled = false
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_DIR * 30.0)
	sm.click(HEAD + JAW_ACROSS * 10.0)
	sm.snap_enabled = prev_snap
	for i in sm.dimensions.size():
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) == "distance":
			sm.set_dimension_value(i, 20.0)
		elif str(dim.get("type", "")) == "angle":
			sm.set_dimension_value(i, 45.0)
	var cutter_id := _add_profile_cutter(sm, kind)
	check(cutter_id != "" and not sm.sketch.is_construction(cutter_id),
			"cutter %s is a profile Line (construction=%s)" % [kind, sm.sketch.is_construction(cutter_id)])
	sm.run_solve()
	await _zoom_model(ctx, sm.to_model(HEAD), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	check(sm.tool == SketchMode.Tool.TRIM, "Power Trim is the active tool")
	return ctx


func _add_profile_cutter(sm: SketchMode, kind: String) -> String:
	var c0: Vector2
	var c1: Vector2
	if kind == "horiz":
		c0 = Vector2(HEAD.x - 40.0, HEAD.y)
		c1 = Vector2(HEAD.x + 40.0, HEAD.y)
	else:
		var cc := HEAD + JAW_DIR * 12.0
		c0 = cc - JAW_ACROSS * 25.0
		c1 = cc + JAW_ACROSS * 25.0
	var id: String = sm.sketch.add_line(c0.x, c0.y, c1.x, c1.y)
	return id


func _entity_span(sm: SketchMode) -> float:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		match str(info.get("type", "")):
			"line":
				mn = mn.min(info["start"]).min(info["end"])
				mx = mx.max(info["start"]).max(info["end"])
			"arc", "circle":
				var c: Vector2 = info["center"]
				var r := float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
	if mn.x > mx.x:
		return 0.0
	return mn.distance_to(mx)


func _arc_radius_near(sm: SketchMode, centre: Vector2) -> float:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "arc" and (info["center"] as Vector2).distance_to(centre) <= 0.5:
			return float(info.get("radius", 0.0))
	return -1.0


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


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame


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


func _zoom_model(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
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


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame
