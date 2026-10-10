# re-PLAN 20 WP7 — popup, hover, and press timestamps.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_traces.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const FACE := "Face — click selects body first, click again for face · then Pull arrow"
const NO_VIEW := "No view for key 0 — use 1 2 3 4 6 7 8"
const CLOCK := 500000



func _init() -> void:
	print("rung01 replan20 traces")
	FilmUI.reset_fail_count()
	OS.set_environment("SX_INPUT_TRACE", "1")
	SxUi.trace_enabled_override = true
	await _story()
	SxUi.trace_enabled_override = false
	OS.set_environment("SX_INPUT_TRACE", "0")
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _story() -> void:
	var ctx := await _boot()
	ctx.main._clock_override_msec = CLOCK
	await _case_finish_popups(ctx)
	await _case_hud_and_file(ctx)
	await _case_hover(ctx)
	await _case_press_times(ctx)
	await _case_n16(ctx)
	await _case_tracing_off(ctx)
	ctx.main._clock_override_msec = -1
	ctx.main.queue_free()
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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	return ctx


func _case_finish_popups(ctx: FilmContext) -> void:
	print("- finish-bar Op, End, Thin")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(chrome != null and chrome.visible, "sketch finish chrome is visible")
	if chrome == null:
		return
	await _option_round(ctx, chrome.find_child("FinishOp", true, false) as OptionButton, "FinishOp", 1)
	await _option_round(ctx, chrome.find_child("FinishEnd", true, false) as OptionButton, "FinishEnd", 1)
	var thin := chrome.find_child("ThinFeature", true, false) as CheckButton
	check(thin != null and thin.is_visible_in_tree(), "Thin feature checkbox is visible")
	if thin != null:
		_click_at(thin.get_global_rect().get_center(), ctx)
		await process_frame
		await process_frame
	var thin_type := chrome.find_child("ThinType", true, false) as OptionButton
	check(thin_type != null and thin_type.is_visible_in_tree(), "Thin type dropdown is visible")
	await _option_round(ctx, thin_type, "FinishThin", 1)
	await _key(ctx, KEY_ESCAPE)
	await process_frame


func _option_round(ctx: FilmContext, opt: OptionButton, trace_name: String, index: int) -> void:
	if opt == null or not opt.is_visible_in_tree():
		check(false, "%s button is visible" % trace_name)
		return
	var before := opt.selected
	ctx.main.popup_trace_log = PackedStringArray()
	_click_at(opt.get_global_rect().get_center(), ctx)
	await process_frame
	await process_frame
	var popup := opt.get_popup()
	if popup == null or not popup.visible:
		opt.show_popup()
		await process_frame
	check(popup != null and popup.visible, "%s popup is open" % trace_name)
	var show_line := "[popup-trace] t=%.3f show %s" % [float(CLOCK) / 1000.0, trace_name]
	check(_log_has(ctx.main.popup_trace_log, show_line),
			"show %s (got %s)" % [show_line, str(ctx.main.popup_trace_log)])
	check(not _log_contains(ctx.main.popup_trace_log, "hide %s" % trace_name),
			"no hide %s before the choice" % trace_name)
	if popup == null:
		return
	popup.reset_size()
	var y := popup.size.y * (float(index) + 0.5) / maxf(float(popup.item_count), 1.0)
	_click_at(Vector2(popup.position) + Vector2(popup.size.x * 0.5, y), ctx)
	await process_frame
	await process_frame
	check(opt.selected == index and opt.selected != before,
			"%s choice is item %d (got %d)" % [trace_name, index, opt.selected])
	var hide_line := "[popup-trace] t=%.3f hide %s" % [float(CLOCK) / 1000.0, trace_name]
	var show_at := _log_index(ctx.main.popup_trace_log, show_line)
	var hide_at := _log_index(ctx.main.popup_trace_log, hide_line)
	check(show_at >= 0 and hide_at > show_at,
			"hide %s follows show (show %d hide %d, log %s)" % [
				trace_name, show_at, hide_at, str(ctx.main.popup_trace_log)])


func _case_hud_and_file(ctx: FilmContext) -> void:
	print("- HUD View and File menu")
	var drop := ctx.main.view_hud.find_child("ViewsDrop", true, false) as Button
	check(drop != null and drop.is_visible_in_tree(), "HUD View ▼ is visible")
	var yaw_before: float = ctx.main.camera.yaw
	ctx.main.popup_trace_log = PackedStringArray()
	if drop != null:
		_click_at(drop.get_global_rect().get_center(), ctx)
		await process_frame
		await process_frame
	var show_line := "[popup-trace] t=%.3f show HudView" % (float(CLOCK) / 1000.0)
	check(_log_has(ctx.main.popup_trace_log, show_line),
			"show HudView (got %s)" % str(ctx.main.popup_trace_log))
	check(not _log_contains(ctx.main.popup_trace_log, "hide HudView"),
			"no hide HudView before Esc")
	await _key(ctx, KEY_ESCAPE)
	await process_frame
	await process_frame
	var hide_line := "[popup-trace] t=%.3f hide HudView" % (float(CLOCK) / 1000.0)
	check(_log_has(ctx.main.popup_trace_log, hide_line),
			"Esc hides HudView (got %s)" % str(ctx.main.popup_trace_log))
	check(is_equal_approx(ctx.main.camera.yaw, yaw_before),
			"Esc keeps the current view")
	ctx.main.popup_trace_log = PackedStringArray()
	var file_btn := _menu_button(ctx.main, "File")
	check(file_btn != null, "File menu button exists")
	if file_btn != null:
		_click_at(file_btn.get_global_rect().get_center(), ctx)
		await process_frame
		await process_frame
		if file_btn.get_popup() != null and not file_btn.get_popup().visible:
			file_btn.show_popup()
			await process_frame
	check(_log_contains(ctx.main.popup_trace_log, "show File"),
			"File menu show (got %s)" % str(ctx.main.popup_trace_log))
	await _key(ctx, KEY_ESCAPE)
	await process_frame
	await process_frame
	check(_log_contains(ctx.main.popup_trace_log, "hide File"),
			"File menu hide (got %s)" % str(ctx.main.popup_trace_log))


func _case_hover(ctx: FilmContext) -> void:
	print("- hover-trace change only")
	await FilmUI.exit_sketch(ctx)
	await process_frame
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(8, 6, 3))
	await process_frame
	await process_frame
	_release_focus(ctx)
	await _key(ctx, KEY_F)
	await process_frame
	ctx.view.select_entity("", "")
	_release_focus(ctx)
	ctx.main._clock_override_msec = CLOCK + 4000
	ctx.main._hint_tick()
	var face := _body_center(ctx, body)
	var ground := _empty_ground(ctx, face)
	check(not _pick(ctx, face).is_empty(), "face point hits the box")
	ctx.main._clock_override_msec = CLOCK
	_clear_hover(ctx)
	_motion(ctx, face)
	await process_frame
	await process_frame
	var face_line := "[hover-trace] t=%.3f target=%s" % [float(CLOCK) / 1000.0, FACE]
	var hover_log := _hover_log(ctx)
	check(_log_has(hover_log, face_line), "hover face (got %s)" % str(hover_log))
	var n_face := _log_count(hover_log, "target=%s" % FACE)
	_motion(ctx, face)
	await process_frame
	hover_log = _hover_log(ctx)
	check(_log_count(hover_log, "target=%s" % FACE) == n_face,
			"same face does not trace again (got %s)" % str(hover_log))
	_motion(ctx, ground)
	await process_frame
	await process_frame
	hover_log = _hover_log(ctx)
	var none_line := "[hover-trace] t=%.3f target=none" % (float(CLOCK) / 1000.0)
	check(_log_has(hover_log, none_line),
			"hover ground is target=none (got %s)" % str(hover_log))
	check(_log_count(hover_log, "target=%s" % FACE) == 1, "face hover was traced once")


func _case_press_times(ctx: FilmContext) -> void:
	print("- input-trace t=")
	ctx.main.interaction.press_trace_log = PackedStringArray()
	ctx.main._clock_override_msec = 600000
	var a := _empty_ground(ctx, Vector2.ZERO)
	_click_at(a, ctx)
	await process_frame
	ctx.main._clock_override_msec = 600400
	_click_at(a + Vector2(30, 20), ctx)
	await process_frame
	ctx.main._clock_override_msec = CLOCK
	var log: PackedStringArray = ctx.main.interaction.press_trace_log
	check(log.size() >= 2, "two presses were traced (got %d)" % log.size())
	var times: Array[float] = []
	var shaped := true
	for line in log:
		var text := str(line)
		if not text.begins_with("[input-trace] t=") or text.find(" press (") < 0:
			shaped = false
		times.append(_trace_t(text))
	check(shaped, "press lines are t=<unix> press (x,y) (got %s)" % str(log))
	check(times.size() >= 2 and is_equal_approx(times[0], 600.0),
			"first press t=600.000 (got %s)" % str(times))
	check(times.size() >= 2 and times[1] > times[0],
			"press timestamps are monotonic (got %s)" % str(times))


func _case_n16(ctx: FilmContext) -> void:
	print("- N16 hover does not interrupt the hold")
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	var body := ids[0] if not ids.is_empty() else ""
	var face := _body_center(ctx, body)
	var ground := _empty_ground(ctx, face)
	ctx.view.select_entity("", "")
	ctx.main._clock_override_msec = CLOCK + 4000
	ctx.main._hint_tick()
	_motion(ctx, face)
	await process_frame
	await process_frame
	check(str(ctx.main.status_label.text) == FACE,
			"pointer is on a face before key 0 (got '%s')" % ctx.main.status_label.text)
	_clear_hover(ctx)
	ctx.main.status_trace_log = PackedStringArray()
	var t0 := 700000
	ctx.main._clock_override_msec = t0
	_release_focus(ctx)
	await _key(ctx, KEY_0)
	check(str(ctx.main.status_label.text) == NO_VIEW, "key 0 result (got '%s')" % ctx.main.status_label.text)
	ctx.main._clock_override_msec = t0 + 2400
	ctx.main._hint_tick()
	check(str(ctx.main.status_label.text) == NO_VIEW, "at +2.4 s the result still holds")
	var hover_mid := _hover_log(ctx).size()
	ctx.main._clock_override_msec = t0 + 2600
	ctx.main._hint_tick()
	check(str(ctx.main.status_label.text) == FACE,
			"at +2.6 s the face hint returns (got '%s')" % ctx.main.status_label.text)
	check(_hover_log(ctx).size() == hover_mid,
			"no hover-trace between the result and the restore")
	var result_t := _status_t(ctx, "kind=result")
	var restore_t := _status_t(ctx, "kind=restore")
	check(result_t >= 0.0 and restore_t - result_t >= 2.4 and restore_t - result_t <= 3.6,
			"restore is 2.4–3.6 s after the result (%.3f → %.3f)" % [result_t, restore_t])
	_clear_hover(ctx)
	ctx.main.status_trace_log = PackedStringArray()
	ctx.main._clock_override_msec = 800000
	_release_focus(ctx)
	await _key(ctx, KEY_0)
	_motion(ctx, ground)
	await process_frame
	check(_log_contains(_hover_log(ctx), "target=none"),
			"leaving during the hold traces target=none (got %s)" % str(_hover_log(ctx)))
	ctx.main._clock_override_msec = 804000
	ctx.main._hint_tick()
	check(not _status_has_face_restore(ctx),
			"no face hint restore after leaving (got %s)" % str(ctx.main.status_trace_log))
	ctx.main._clock_override_msec = CLOCK


func _case_tracing_off(ctx: FilmContext) -> void:
	print("- tracing off")
	OS.set_environment("SX_INPUT_TRACE", "0")
	SxUi.trace_enabled_override = false
	ctx.main.popup_trace_log = PackedStringArray()
	_clear_hover(ctx)
	var file_btn := _menu_button(ctx.main, "File")
	if file_btn != null:
		_click_at(file_btn.get_global_rect().get_center(), ctx)
		await process_frame
		if file_btn.get_popup() != null and file_btn.get_popup().visible:
			file_btn.get_popup().hide()
			await process_frame
	var ground := _empty_ground(ctx, Vector2(400, 400))
	_motion(ctx, ground)
	await process_frame
	check(ctx.main.popup_trace_log.is_empty(),
			"tracing off prints no popup-trace (got %s)" % str(ctx.main.popup_trace_log))
	check(_hover_log(ctx).is_empty(),
			"tracing off prints no hover-trace (got %s)" % str(_hover_log(ctx)))
	OS.set_environment("SX_INPUT_TRACE", "1")
	SxUi.trace_enabled_override = true


func _hover_log(ctx: FilmContext) -> PackedStringArray:
	var v: Variant = ctx.main.get("hover_trace_log")
	if v is PackedStringArray:
		return v
	return PackedStringArray()


func _clear_hover(ctx: FilmContext) -> void:
	if ctx.main.get("hover_trace_log") is PackedStringArray:
		ctx.main.hover_trace_log = PackedStringArray()


func _menu_button(main, title: String) -> MenuButton:
	for c in main.find_children("*", "MenuButton", true, false):
		var mb := c as MenuButton
		if mb != null and str(mb.text).begins_with(title):
			return mb
	return null


func _log_has(log: PackedStringArray, line: String) -> bool:
	for entry in log:
		if str(entry) == line:
			return true
	return false


func _log_contains(log: PackedStringArray, fragment: String) -> bool:
	for entry in log:
		if str(entry).contains(fragment):
			return true
	return false


func _log_index(log: PackedStringArray, line: String) -> int:
	for i in log.size():
		if str(log[i]) == line:
			return i
	return -1


func _log_count(log: PackedStringArray, fragment: String) -> int:
	var n := 0
	for entry in log:
		if str(entry).contains(fragment):
			n += 1
	return n


func _trace_t(line: String) -> float:
	var at := line.find("t=")
	if at < 0:
		return -1.0
	var rest := line.substr(at + 2)
	var sp := rest.find(" ")
	if sp > 0:
		rest = rest.substr(0, sp)
	return float(rest)


func _status_t(ctx: FilmContext, kind: String) -> float:
	for line in ctx.main.status_trace_log:
		if str(line).contains(kind):
			return _trace_t(str(line))
	return -1.0


func _status_has_face_restore(ctx: FilmContext) -> bool:
	for line in ctx.main.status_trace_log:
		var text := str(line)
		if (text.contains("kind=hint") or text.contains("kind=restore")) and text.contains(FACE):
			return true
	return false


func _body_center(ctx: FilmContext, body: String) -> Vector2:
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


func _motion(ctx: FilmContext, pos: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)


func _click_at(pos: Vector2, ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	_motion(ctx, pos)
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


func _release_focus(ctx: FilmContext) -> void:
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _key(ctx: FilmContext, code: Key) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	vp.push_input(up)
	await process_frame
