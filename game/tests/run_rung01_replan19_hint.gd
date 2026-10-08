# WP5 — a result holds 2.5 s, then the hover hint returns with a still pointer.
# The clock is main._clock_override_msec. Run:
# LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_hint.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const BOX_SIZE := Vector3(8, 6, 3)
const NO_VIEW := "No view for key 0 — use 1 2 3 4 6 7 8"
const FACE := "Face — click selects body first, click again for face · then Pull arrow"

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan19 hint")
	SxUi.trace_enabled_override = true
	await _still_pointer()
	await _hint_during_hold()
	await _leave_during_hold()
	await _leave_after_hint()
	await _opened_path()
	SxUi.trace_enabled_override = false
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _still_pointer() -> void:
	print("- still pointer restores the face hint")
	var ctx := await _boot()
	var px := await _face_point(ctx)
	await _motion(ctx.main.get_viewport(), px)
	check(_label(ctx) == FACE, "pointer on a face shows the face hint (got `%s`)" % _label(ctx))
	_release_focus(ctx.main.get_viewport())
	ctx.main.status_trace_log.clear()
	var t0 := _stamp(ctx, 100000)
	await _push_key(ctx.main.get_viewport(), KEY_0)
	check(_label(ctx) == NO_VIEW, "key 0 result (got `%s`)" % _label(ctx))
	_stamp(ctx, t0 + 2400)
	ctx.main._hint_tick()
	check(_label(ctx) == NO_VIEW, "at +2.4 s the result still holds (got `%s`)" % _label(ctx))
	_stamp(ctx, t0 + 2600)
	ctx.main._hint_tick()
	check(_label(ctx) == FACE, "at +2.6 s the hint is back with no pointer event (got `%s`)" % _label(ctx))
	_trace_gap(ctx)
	await _shutdown(ctx)


func _hint_during_hold() -> void:
	print("- hint arriving during the hold is written at the end")
	var ctx := await _boot()
	var px := await _face_point(ctx)
	_release_focus(ctx.main.get_viewport())
	var t0 := _stamp(ctx, 200000)
	await _push_key(ctx.main.get_viewport(), KEY_0)
	check(_label(ctx) == NO_VIEW, "result is showing before the pointer moves")
	await _motion(ctx.main.get_viewport(), px)
	_stamp(ctx, t0 + 2400)
	ctx.main._hint_tick()
	check(_label(ctx) == NO_VIEW, "at +2.4 s the label is still the result (got `%s`)" % _label(ctx))
	_stamp(ctx, t0 + 2600)
	ctx.main._hint_tick()
	check(_label(ctx) == FACE, "at +2.6 s the hint is written (got `%s`)" % _label(ctx))
	await _shutdown(ctx)


func _leave_during_hold() -> void:
	print("- leaving the body during the hold drops the hint")
	var ctx := await _boot()
	var px := await _face_point(ctx)
	var ground := _empty_ground(ctx, px)
	_release_focus(ctx.main.get_viewport())
	var t0 := _stamp(ctx, 300000)
	await _push_key(ctx.main.get_viewport(), KEY_0)
	await _motion(ctx.main.get_viewport(), px)
	await _motion(ctx.main.get_viewport(), ground)
	_stamp(ctx, t0 + 3000)
	ctx.main._hint_tick()
	var text := _label(ctx)
	check(text == NO_VIEW or text == ctx.main.IDLE_STATUS,
			"at +3 s the label is the result or idle (got `%s`)" % text)
	check(text != FACE, "at +3 s the face hint is not showing")
	await _shutdown(ctx)


func _leave_after_hint() -> void:
	print("- leaving after the hint returns to idle")
	var ctx := await _boot()
	var px := await _face_point(ctx)
	var ground := _empty_ground(ctx, px)
	await _motion(ctx.main.get_viewport(), px)
	check(_label(ctx) == FACE, "hint is showing before the pointer leaves")
	ctx.main.status_trace_log.clear()
	await _motion(ctx.main.get_viewport(), ground)
	check(_label(ctx) == ctx.main.IDLE_STATUS, "leaving the part returns to idle (got `%s`)" % _label(ctx))
	check(_trace_has(ctx, "kind=idle"), "leave prints kind=idle")
	await _shutdown(ctx)


func _opened_path() -> void:
	print("- Opened status uses the same hold")
	var ctx := await _boot()
	var px := await _face_point(ctx)
	var t0 := _stamp(ctx, 400000)
	ctx.main._on_status("Opened /x/blank.sxp")
	check(_label(ctx) == "Opened /x/blank.sxp", "opened result is on the label")
	await _motion(ctx.main.get_viewport(), px)
	_stamp(ctx, t0 + 2400)
	ctx.main._hint_tick()
	check(_label(ctx) == "Opened /x/blank.sxp", "opened result holds at +2.4 s")
	_stamp(ctx, t0 + 2600)
	ctx.main._hint_tick()
	check(_label(ctx) == FACE, "opened result yields to the face hint (got `%s`)" % _label(ctx))
	await _shutdown(ctx)


func _trace_gap(ctx: FilmContext) -> void:
	var result_t := -1.0
	var hint_t := -1.0
	for line in ctx.main.status_trace_log:
		check(str(line).begins_with("[status-trace] t="), "trace line `%s`" % str(line))
		if str(line).contains("kind=result") and result_t < 0.0:
			result_t = _trace_t(str(line))
		if str(line).contains("kind=restore") or str(line).contains("kind=hint"):
			hint_t = _trace_t(str(line))
	check(_trace_has(ctx, NO_VIEW), "trace text includes the key 0 result")
	check(result_t >= 0.0 and hint_t >= 0.0, "trace has a result and a later hint")
	check(hint_t - result_t >= 2.5, "result to hint gap is ≥ 2.5 s (%.3f)" % (hint_t - result_t))


func _trace_has(ctx: FilmContext, fragment: String) -> bool:
	for line in ctx.main.status_trace_log:
		if str(line).contains(fragment):
			return true
	return false


func _trace_t(line: String) -> float:
	var at := line.find("t=")
	if at < 0:
		return -1.0
	var rest := line.substr(at + 2)
	var sp := rest.find(" ")
	if sp > 0:
		rest = rest.substr(0, sp)
	return float(rest)


func _stamp(ctx: FilmContext, ms: int) -> int:
	ctx.main._clock_override_msec = ms
	return ms


func _face_point(ctx: FilmContext) -> Vector2:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, BOX_SIZE)
	await process_frame
	await process_frame
	check(body != "", "box exists")
	if ctx.view.selected_body != "":
		_release_focus(ctx.main.get_viewport())
		await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		ctx.main._clock_override_msec = Time.get_ticks_msec() + 3000
		ctx.main._hint_tick()
		ctx.main._clock_override_msec = -1
	var px := _body_screen_center(ctx, body)
	check(not _pick(ctx, px).is_empty(), "face point hits the box")
	return px


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
	main.status_trace_log.clear()
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	ctx.main._clock_override_msec = -1
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
	await process_frame


func _label(ctx: FilmContext) -> String:
	return str(ctx.main.status_label.text)


func _body_screen_center(ctx: FilmContext, body: String) -> Vector2:
	var node := ctx.view.body_node(body)
	if node == null:
		return Vector2.INF
	var aabb: AABB = node.get_aabb()
	var world: Vector3 = node.global_transform * aabb.get_center()
	return ctx.main.camera.unproject_position(world)


func _pick(ctx: FilmContext, screen: Vector2) -> Dictionary:
	var cam: Camera3D = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	var inv: Transform3D = ms.global_transform.affine_inverse()
	var origin: Vector3 = inv * cam.project_ray_origin(screen)
	var direction: Vector3 = inv.basis * cam.project_ray_normal(screen)
	return ctx.view.pick_info(origin, direction)


func _empty_ground(ctx: FilmContext, avoid: Vector2) -> Vector2:
	var y := 160.0
	while y < 700.0:
		var x := 240.0
		while x < 1100.0:
			var pt := Vector2(x, y)
			if pt.distance_to(avoid) >= 80.0 and _pick(ctx, pt).is_empty():
				return pt
			x += 60.0
		y += 60.0
	return Vector2(240, 180)


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _push_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)
	await process_frame


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
