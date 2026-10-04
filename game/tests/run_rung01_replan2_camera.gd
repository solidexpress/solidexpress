# Rung 1 replan 2 WP6 — standard-view keys stay out of a sketch.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan2_camera.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

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
	print("rung01 replan2 camera (WP6)")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)
	main._file_popup.id_pressed.emit(0)
	await process_frame
	await process_frame

	await test_sketch_view_keys_not_nav(main, ctx)
	await test_outside_sketch_key_1_frames_front(main, ctx)

	check(FilmUI.fail_count == 0, "FilmUI reported no missing controls")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = code if pressed else 0
	ev.pressed = pressed
	ev.echo = false
	return ev


func _push_key(vp: Viewport, code: Key) -> void:
	vp.push_input(_key_event(code, true))
	vp.push_input(_key_event(code, false))


func test_sketch_view_keys_not_nav(main, ctx: FilmContext) -> void:
	print("- sketch lock: 1/2/3/5/7 are not nav keys")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var cam: OrbitCamera = main.camera
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	check(cam.sketch_orientation_locked, "sketch_orientation_locked is true")

	var sketch_w := _key_event(KEY_W, true)
	check(not cam._is_nav_key(sketch_w), "plain W is still not a nav key while sketch-locked")

	var view_keys: Array = [KEY_1, KEY_2, KEY_3, KEY_5, KEY_7]
	var names := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_5: "5", KEY_7: "7"}
	var vp: Viewport = main.interaction.get_viewport()
	var proj0 := cam.projection
	var basis_locked: Basis = cam.global_transform.basis
	var yaw_locked := cam.yaw
	var pitch_locked := cam.pitch
	for code in view_keys:
		var label: String = names[code]
		var ev := _key_event(code, true)
		check(not cam._is_nav_key(ev), "KEY_%s is not a nav key while sketch-locked" % label)
		check(not cam.handle_input(ev, true), "KEY_%s handle_input does not consume a view" % label)
		check(not cam._handle_nav_key(ev), "KEY_%s is not handled as a view while sketch-locked" % label)
		check(cam.global_transform.basis.is_equal_approx(basis_locked),
				"KEY_%s handle_input leaves camera basis unchanged" % label)
		_push_key(vp, code)
		await process_frame
		check(cam.global_transform.basis.is_equal_approx(basis_locked),
				"KEY_%s push_input leaves camera basis unchanged" % label)
		check(is_equal_approx(cam.yaw, yaw_locked) and is_equal_approx(cam.pitch, pitch_locked),
				"KEY_%s push_input leaves yaw/pitch unchanged" % label)
		check(cam.projection == proj0, "KEY_%s does not change projection" % label)
	check(cam.projection == proj0, "KEY_5 does not toggle projection while sketch-locked")
	check(cam.sketch_orientation_locked, "lock stays on after view-key presses")


func test_outside_sketch_key_1_frames_front(main, ctx: FilmContext) -> void:
	print("- leave sketch: KEY_1 frames front")
	var cam: OrbitCamera = main.camera
	var sm: SketchMode = main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
		await process_frame
		await process_frame
	check(sm == null or not sm.active, "sketch session is closed")
	check(not cam.sketch_orientation_locked, "sketch_orientation_locked is false")

	var one := _key_event(KEY_1, true)
	check(cam._is_nav_key(one), "KEY_1 is a nav key outside a sketch")
	var vp: Viewport = main.interaction.get_viewport()
	_push_key(vp, KEY_1)
	await process_frame
	await process_frame
	check(is_equal_approx(cam.yaw, 0.0), "KEY_1 frames front (yaw 0)")
	check(is_equal_approx(cam.pitch, 0.0), "KEY_1 frames front (pitch 0)")
	check(absf(cam.global_position.y - cam.pivot.y) < 1.0, "front view is level")

	_push_key(vp, KEY_2)
	await process_frame
	check(is_equal_approx(cam.yaw, deg_to_rad(90.0)), "KEY_2 frames right (yaw 90)")
	check(is_equal_approx(cam.pitch, 0.0), "KEY_2 frames right (pitch 0)")

	var proj := cam.projection
	_push_key(vp, KEY_5)
	await process_frame
	check(cam.projection != proj, "KEY_5 toggles projection outside a sketch")
