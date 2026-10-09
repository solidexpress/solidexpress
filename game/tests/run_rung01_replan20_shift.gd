# re-PLAN 20 WP5 — Shift-add is observable, and a real Shift key keeps the wall.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_shift.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _log: Array[String] = []
var _wall := ""
var _circle := ""
var _sm: SketchMode


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan20 shift")
	FilmUI.reset_fail_count()
	SxUi.trace_enabled_override = true
	await _story()
	SxUi.trace_enabled_override = false
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _story() -> void:
	var ctx := await _boot()
	await _scene(ctx)
	await _case_plain(ctx)
	await _case_shift_held(ctx)
	await _case_modifier_lag(ctx)
	await _case_shift_tapped(ctx)
	await _case_ctrl_meta_and_directions(ctx)
	await _case_key_trace(ctx)


func _boot() -> FilmContext:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	_sm = main.sketch_mode
	main.sketch_mode.status.connect(func(t: String) -> void: _log.append(t))
	if main.interaction != null:
		main.interaction.status.connect(func(t: String) -> void: _log.append(t))
	return ctx


func _scene(ctx: FilmContext) -> void:
	print("- wall and throwaway circle")
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector2(40, 20), 4.0)
	await _draw_line(ctx, Vector2(0, 0), Vector2(80, 0))
	await _draw_circle(ctx, Vector2(40, 36), "6")
	var sm: SketchMode = ctx.main.sketch_mode
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind == "line":
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			if a.distance_to(Vector2.ZERO) < 1.0 and b.distance_to(Vector2(80, 0)) < 1.0:
				_wall = str(id)
			elif b.distance_to(Vector2.ZERO) < 1.0 and a.distance_to(Vector2(80, 0)) < 1.0:
				_wall = str(id)
		elif kind == "circle" and _circle == "":
			_circle = str(id)
	check(_wall != "" and _circle != "", "wall and circle exist")
	var wall_s := FilmUI.sketch_uv_to_screen(ctx, Vector2(32, 0))
	var circ_s := FilmUI.sketch_uv_to_screen(ctx, Vector2(40, 36))
	check(wall_s.distance_to(circ_s) >= 60.0,
			"wall at 40%% and circle are %.0f px apart" % wall_s.distance_to(circ_s))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	ctx.main.interaction.grab_focus()
	await process_frame


func _case_plain(ctx: FilmContext) -> void:
	print("- no Shift replaces")
	await _select_wall(ctx)
	_clear_press_log(ctx)
	var box := _circle_box(ctx)
	_drag(ctx.main.get_viewport(), box[0], box[1], false, false, false)
	await process_frame
	await process_frame
	check(_saw("Selected 1 sketch entity"), "plain window → Selected 1 sketch entity")
	check(not _has(_wall) and _has(_circle), "plain window drops the wall and keeps the circle")
	var line := _last_box_press(ctx)
	check(line.contains("shift=0"), "plain press shift=0 (got '%s')" % line)
	check(line.contains("additive=0"), "plain press additive=0 (got '%s')" % line)


func _case_shift_held(ctx: FilmContext) -> void:
	print("- Shift held through the drag")
	await _select_wall(ctx)
	_clear_press_log(ctx)
	SxUi.key_trace_log = PackedStringArray()
	var vp: Viewport = ctx.main.get_viewport()
	_key(vp, KEY_SHIFT, true, true, false, false)
	var box := _circle_box(ctx)
	_drag(vp, box[0], box[1], true, false, false)
	_key(vp, KEY_SHIFT, false, false, false, false)
	await process_frame
	await process_frame
	check(_saw("Selected 2 sketch entities"), "Shift window → Selected 2 sketch entities")
	check(_has(_wall) and _has(_circle), "Shift window keeps the wall and the circle")
	var line := _last_box_press(ctx)
	check(line.contains("shift=1"), "Shift press shift=1 (got '%s')" % line)
	check(line.contains("additive=1"), "Shift press additive=1 (got '%s')" % line)
	check(_log_has_pressed(SxUi.key_trace_log, "Shift", 1),
			"Shift press prints pressed=1 (got %s)" % str(SxUi.key_trace_log))


func _case_modifier_lag(ctx: FilmContext) -> void:
	print("- Shift held in Input, mouse events omit it")
	await _select_wall(ctx)
	_clear_press_log(ctx)
	var down := InputEventKey.new()
	down.keycode = KEY_SHIFT
	down.physical_keycode = KEY_SHIFT
	down.pressed = true
	down.shift_pressed = true
	Input.parse_input_event(down)
	await process_frame
	var box := _circle_box(ctx)
	_drag(ctx.main.get_viewport(), box[0], box[1], false, false, false)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_SHIFT
	up.physical_keycode = KEY_SHIFT
	up.pressed = false
	up.shift_pressed = false
	Input.parse_input_event(up)
	await process_frame
	check(_saw("Selected 2 sketch entities"), "lag window → Selected 2 sketch entities")
	check(_has(_wall), "lag window keeps the wall")
	var line := _last_box_press(ctx)
	check(line.contains("additive=1"), "lag press additive=1 (got '%s')" % line)
	check(line.contains("sketch-box:SELECT"), "lag press is sketch-box:SELECT (got '%s')" % line)


func _case_shift_tapped(ctx: FilmContext) -> void:
	print("- Shift tapped then released")
	await _select_wall(ctx)
	_clear_press_log(ctx)
	var vp: Viewport = ctx.main.get_viewport()
	_key(vp, KEY_SHIFT, true, true, false, false)
	_key(vp, KEY_SHIFT, false, false, false, false)
	await process_frame
	var box := _circle_box(ctx)
	_drag(vp, box[0], box[1], false, false, false)
	await process_frame
	await process_frame
	check(_saw("Selected 1 sketch entity"), "tapped Shift → Selected 1 sketch entity")
	check(not _has(_wall), "tapped Shift drops the wall")
	var line := _last_box_press(ctx)
	check(line.contains("shift=0"), "tapped press shift=0 (got '%s')" % line)
	check(line.contains("additive=0"), "tapped press additive=0 (got '%s')" % line)


func _case_ctrl_meta_and_directions(ctx: FilmContext) -> void:
	print("- Ctrl, Meta, crossing and window")
	await _select_wall(ctx)
	_clear_press_log(ctx)
	var box := _circle_box(ctx)
	var vp: Viewport = ctx.main.get_viewport()
	_drag(vp, box[0], box[1], false, true, false)
	await process_frame
	await process_frame
	check(_saw("Selected 2 sketch entities"), "Ctrl window → Selected 2 sketch entities")
	check(_last_box_press(ctx).contains("additive=1"), "Ctrl press additive=1")
	await _clear_then_wall(ctx)
	_clear_press_log(ctx)
	_drag(vp, box[0], box[1], false, false, true)
	await process_frame
	await process_frame
	check(_saw("Selected 2 sketch entities"), "Meta window → Selected 2 sketch entities")
	check(_last_box_press(ctx).contains("additive=1"), "Meta press additive=1")
	await _clear_then_wall(ctx)
	_clear_press_log(ctx)
	_key(vp, KEY_SHIFT, true, true, false, false)
	_drag(vp, box[1], box[0], true, false, false)
	_key(vp, KEY_SHIFT, false, false, false, false)
	await process_frame
	await process_frame
	check(_saw("Selected 2 sketch entities") and _has(_wall),
			"crossing Shift box keeps the wall")
	await _clear_then_wall(ctx)
	_clear_press_log(ctx)
	_key(vp, KEY_SHIFT, true, true, false, false)
	_drag(vp, box[0], box[1], true, false, false)
	_key(vp, KEY_SHIFT, false, false, false, false)
	await process_frame
	await process_frame
	check(_saw("Selected 2 sketch entities") and _has(_wall),
			"window Shift box keeps the wall")


func _case_key_trace(ctx: FilmContext) -> void:
	print("- key-trace pressed and t=")
	SxUi.key_trace_log = PackedStringArray()
	_clear_press_log(ctx)
	ctx.main._clock_override_msec = 1000000
	var vp: Viewport = ctx.main.get_viewport()
	_key(vp, KEY_SHIFT, true, true, false, false)
	ctx.main._clock_override_msec = 1000500
	var box := _circle_box(ctx)
	_drag(vp, box[0], box[1], true, false, false)
	ctx.main._clock_override_msec = 1001000
	_key(vp, KEY_SHIFT, false, false, false, false)
	await process_frame
	check(_log_has_pressed(SxUi.key_trace_log, "Shift", 1),
			"[key-trace] pressed=1 (got %s)" % str(SxUi.key_trace_log))
	check(_log_has_pressed(SxUi.key_trace_log, "Shift", 0),
			"[key-trace] pressed=0 (got %s)" % str(SxUi.key_trace_log))
	var presses: Array[String] = []
	var raw = ctx.main.interaction.get("press_trace_log")
	if raw != null:
		for entry in raw:
			if str(entry).contains("sketch-box:SELECT"):
				presses.append(str(entry))
	check(presses.size() >= 1 and presses[0].contains("t=") and _t_of(presses[0]) >= 0.0,
			"press line carries t= (got %s)" % str(presses))
	var second := _t_of(presses[presses.size() - 1]) if presses.size() >= 1 else -1.0
	var first := _t_of(presses[0]) if presses.size() >= 1 else 0.0
	# A second gesture is the drag above; monotonic against the key lines' clock
	# is the press t itself sitting on the override.
	check(second + 0.0001 >= first and first >= 1000.0 - 0.001,
			"t= is monotonic (%.3f then %.3f)" % [first, second])
	ctx.main._clock_override_msec = -1


func _select_wall(ctx: FilmContext) -> void:
	_log.clear()
	await _click_uv(ctx, Vector2(-10, -25))
	await _click_uv(ctx, Vector2(32, 0))
	await process_frame
	var label := str(ctx.main.status_label.text)
	check((label == "Selected 1 sketch entity" or _saw("Selected 1 sketch entity"))
			and _has(_wall) and not _has(_circle),
			"wall at 40% is the only selection (got '%s')" % label)


func _clear_then_wall(ctx: FilmContext) -> void:
	_log.clear()
	await _click_uv(ctx, Vector2(-10, -25))
	await _click_uv(ctx, Vector2(32, 0))
	await process_frame


func _circle_box(ctx: FilmContext) -> Array:
	var centre := FilmUI.sketch_uv_to_screen(ctx, Vector2(40, 36))
	var rim := FilmUI.sketch_uv_to_screen(ctx, Vector2(46, 36))
	var rad := maxf(centre.distance_to(rim), 8.0) + 14.0
	return [centre + Vector2(-rad, -rad), centre + Vector2(rad, rad)]


func _has(id: String) -> bool:
	return id != "" and _sm != null and _sm.selected.has(id)


func _last_box_press(ctx: FilmContext) -> String:
	var raw = ctx.main.interaction.get("press_trace_log")
	if raw == null:
		return ""
	var last := ""
	for entry in raw:
		if str(entry).contains("sketch-box:SELECT"):
			last = str(entry)
	return last


func _clear_press_log(ctx: FilmContext) -> void:
	if ctx.main.interaction.get("press_trace_log") != null:
		ctx.main.interaction.press_trace_log = PackedStringArray()


func _log_has_pressed(log: PackedStringArray, key_name: String, pressed: int) -> bool:
	var needle := "key=%s" % key_name
	var flag := "pressed=%d" % pressed
	for line in log:
		if str(line).contains(needle) and str(line).contains(flag):
			return true
	return false


func _t_of(line: String) -> float:
	var at := line.find("t=")
	if at < 0:
		return -1.0
	var rest := line.substr(at + 2)
	var end := rest.find(" ")
	if end < 0:
		end = rest.length()
	return float(rest.substr(0, end))


func _drag(vp: Viewport, a: Vector2, b: Vector2, shift: bool, ctrl: bool, meta: bool) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = a
	hover.global_position = a
	vp.push_input(hover)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	down.shift_pressed = shift
	down.ctrl_pressed = ctrl
	down.meta_pressed = meta
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	var steps := 4
	var prev := a
	for i in range(1, steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		mv.relative = p - prev
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.shift_pressed = shift
		mv.ctrl_pressed = ctrl
		mv.meta_pressed = meta
		vp.push_input(mv)
		prev = p
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	up.shift_pressed = shift
	up.ctrl_pressed = ctrl
	up.meta_pressed = meta
	vp.push_input(up)


func _key(vp: Viewport, code: Key, pressed: bool, shift: bool, ctrl: bool, meta: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	ev.meta_pressed = meta
	vp.push_input(ev)


func _draw_line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, a, "line start")
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, b, "line end")
	await process_frame


func _draw_circle(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, center, "circle centre")
	await process_frame
	var edit: LineEdit = ctx.main.sketch_chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null:
		check(false, "DimLineEdit for r%s" % radius_text)
		return
	var pos := edit.get_global_rect().get_center()
	var vp: Viewport = ctx.main.get_viewport()
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
	for i in radius_text.length():
		var ch := radius_text.unicode_at(i)
		var code := (KEY_0 + (ch - 48)) as Key
		_key(vp, code, true, false, false, false)
		_key(vp, code, false, false, false, false)
		await process_frame
	_key(vp, KEY_ENTER, true, false, false, false)
	_key(vp, KEY_ENTER, false, false, false, false)
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2) -> void:
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, uv, "sketch point")


func _zoom(ctx: FilmContext, uv: Vector2, ppm: float) -> void:
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var model_pivot: Vector3 = sm.to_model(uv) if sm != null else Vector3(uv.x, uv.y, 0)
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var size_mm := 800.0 / ppm
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _saw(needle: String) -> bool:
	for s in _log:
		if s.contains(needle):
			return true
	return false
