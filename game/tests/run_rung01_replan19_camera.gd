# re-PLAN 19 WP7 — the first wheel notch during a view change keeps the
# point under the pointer, and Frame / F / Shift+F report the right fit.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_camera.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan19 camera")
	FilmUI.reset_fail_count()
	await _case_wheel()
	await _case_frame()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case_wheel() -> void:
	print("- wheel during and after Top view")
	var ctx := await _boot()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 24, 12))
	await _frames(2)
	ctx.view.select_entity(body, "")
	await process_frame
	var cam: OrbitCamera = ctx.main.camera
	_push_key(ctx.main.get_viewport(), KEY_3, false)
	check(str(ctx.main.status_label.text).contains("Top view"),
			"key 3 status is Top view (got '%s')" % str(ctx.main.status_label.text))
	# Same frame as key 3: no process_frame between the view and the notch.
	var world := _offset_point(cam)
	var screen: Vector2 = cam.unproject_position(world)
	check(_on_screen(screen), "pointer starts on screen %s" % screen)
	var dist_before := cam.distance
	for notch in 3:
		var before: Vector2 = cam.unproject_position(world)
		_wheel(ctx.main.get_viewport(), before, true)
		var after: Vector2 = cam.unproject_position(world)
		var delta := before.distance_to(after)
		check(delta <= 2.0, "same-frame notch %d moves the point %.2f px" % [notch + 1, delta])
	check(cam.distance < dist_before - 0.01,
			"three notches zoom in (%.2f -> %.2f)" % [dist_before, cam.distance])
	await create_timer(2.0).timeout
	for notch in 3:
		var before: Vector2 = cam.unproject_position(world)
		_wheel(ctx.main.get_viewport(), before, true)
		var after: Vector2 = cam.unproject_position(world)
		var delta := before.distance_to(after)
		check(delta <= 2.0, "after 2s notch %d moves the point %.2f px" % [notch + 1, delta])
	var origin: Vector2 = cam.unproject_position(world)
	for notch in 3:
		var at: Vector2 = cam.unproject_position(world)
		_wheel(ctx.main.get_viewport(), at, false)
		var out_after: Vector2 = cam.unproject_position(world)
		check(origin.distance_to(out_after) <= 2.0,
				"wheel-out notch %d keeps the point (%.2f px)" % [notch + 1, origin.distance_to(out_after)])
	# A real view tween: the wheel snaps to the target pose, then holds the
	# point that sits under the pointer on that pose.
	var start_pose := cam.capture_pose()
	cam.apply_standard_view_id("front", true)
	var end_pose: Dictionary = cam._tween_end_pose.duplicate(true)
	cam.apply_pose(end_pose)
	var tween_world := _offset_point(cam)
	var tween_screen: Vector2 = cam.unproject_position(tween_world)
	cam.apply_pose(start_pose)
	cam.apply_standard_view_id("front", true)
	check(cam._view_tween != null and cam._view_tween.is_valid(), "Front view tween is running")
	_wheel(ctx.main.get_viewport(), tween_screen, true)
	var tween_after: Vector2 = cam.unproject_position(tween_world)
	check(cam._view_tween == null or not cam._view_tween.is_valid(),
			"wheel finishes the view tween")
	check(tween_screen.distance_to(tween_after) <= 2.0,
			"wheel during a view tween keeps the point (%.2f px)" % tween_screen.distance_to(tween_after))
	await _shutdown(ctx)


func _case_frame() -> void:
	print("- F, Shift+F, HUD Frame")
	var ctx := await _boot()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 24, 12))
	await _frames(2)
	ctx.view.select_entity(body, "")
	await process_frame
	_status_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_F, false)
	await process_frame
	check(_saw("Framed selection"), "F with a body is Framed selection (got '%s')" % _status_blob())
	ctx.view.clear_selection()
	await process_frame
	_status_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_F, false)
	await process_frame
	check(_saw("Framed all"), "F with nothing selected is Framed all (got '%s')" % _status_blob())
	ctx.view.select_entity(body, "")
	await process_frame
	var cam: OrbitCamera = ctx.main.camera
	_status_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_F, true)
	await process_frame
	check(_saw("Framed all"), "Shift+F is Framed all (got '%s')" % _status_blob())
	ctx.view.clear_selection()
	await process_frame
	var pose_before := cam.capture_pose()
	_push_key(ctx.main.get_viewport(), KEY_F, true)
	await process_frame
	var shift_pose := cam.capture_pose()
	cam.apply_pose(pose_before)
	await process_frame
	_status_log.clear()
	var frame_btn := ctx.main.view_hud.find_child("Frame", true, false) as Button
	check(frame_btn != null and frame_btn.is_visible_in_tree(), "HUD Frame button is visible")
	check(frame_btn != null and frame_btn.text == "Frame", "HUD button text is Frame")
	if frame_btn != null:
		await FilmUI.click_control(ctx, frame_btn, FilmUICues.alert("Frame", "HUD Frame"))
		await process_frame
	check(_saw("Framed all"), "HUD Frame with nothing selected is Framed all (got '%s')" % _status_blob())
	var hud_pose := cam.capture_pose()
	check(_pose_close(shift_pose, hud_pose),
			"HUD Frame matches Shift+F (dist %.2f vs %.2f)" % [
				float(hud_pose.get("distance", -1)), float(shift_pose.get("distance", -1))])
	await _shutdown(ctx)


func _offset_point(cam: OrbitCamera) -> Vector3:
	# Off the pivot so a wrong zoom anchor cannot hide at the screen centre.
	return cam.pivot + cam.global_transform.basis.x * 18.0


func _on_screen(screen: Vector2) -> bool:
	return screen.x >= 0.0 and screen.y >= 0.0 \
			and screen.x <= float(ROOT_SIZE.x) and screen.y <= float(ROOT_SIZE.y)


func _pose_close(a: Dictionary, b: Dictionary) -> bool:
	var pa: Vector3 = a.get("pivot", Vector3.ZERO)
	var pb: Vector3 = b.get("pivot", Vector3.ZERO)
	return absf(float(a.get("distance", 0.0)) - float(b.get("distance", 0.0))) < 0.05 \
			and pa.distance_to(pb) < 0.05


func _wheel(vp: Viewport, pos: Vector2, zoom_in: bool) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	down.factor = 1.0
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = down.button_index
	up.pressed = false
	up.factor = 1.0
	up.position = pos
	up.global_position = pos
	vp.push_input(up)


func _push_key(vp: Viewport, code: Key, shift: bool) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = code
	down.physical_keycode = code
	down.shift_pressed = shift
	vp.push_input(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = code
	up.physical_keycode = code
	up.shift_pressed = shift
	vp.push_input(up)


func _frames(n: int) -> void:
	for _i in n:
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
	check(root.size == ROOT_SIZE, "root is %s (got %s)" % [ROOT_SIZE, root.size])
	_status_log.clear()
	if main.camera != null and main.camera.has_signal("framed"):
		main.camera.framed.connect(func(text: String) -> void:
			_status_log.append(text))
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	await _frames(2)
	if ctx.main != null:
		ctx.main.queue_free()
	await process_frame


func _saw(fragment: String) -> bool:
	return _status_blob().contains(fragment)


func _status_blob() -> String:
	return " | ".join(_status_log)
