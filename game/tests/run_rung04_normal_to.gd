# Rung 4 WP6 — Ctrl+8 faces the active sketch. Key 8 stays Bottom.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_normal_to.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")


func _init() -> void:
	print("rung04 normal to")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	var popup: PopupMenu = ctx.main._view_popup
	var has_item := false
	for i in popup.item_count:
		if popup.get_item_text(i) == "Normal To":
			has_item = true
	check(has_item, "View menu has Normal To")
	ctx.view.new_document()
	await process_frame
	ctx.main.camera.apply_standard_view_id("right")
	await process_frame
	ctx.main.interaction.arm_pick_sketch_host()
	var pt: Vector3 = OriginPlanes.pick_point("Right")
	await _click_world(ctx, pt, "Right")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Right sketch is active")
	var cam: OrbitCamera = ctx.main.camera
	var want_look := _look(cam)
	var want_up := _up(cam)
	cam.yaw = 0.4
	cam.pitch = -0.3
	cam._update_transform()
	_key(ctx, KEY_8, true)
	await process_frame
	check(_look(cam).dot(want_look) > 0.99, "Ctrl+8 looks along the sketch normal")
	check(_up(cam).dot(want_up) > 0.99, "Ctrl+8 up is the sketch plane Y")
	await _exit(ctx)
	check(not sm.active, "sketch exited before key 8")
	_key(ctx, KEY_8, false)
	await process_frame
	check(absf(cam.pitch - deg_to_rad(-90.0)) < 0.05, "key 8 alone is Bottom (pitch %.3f)" % cam.pitch)
	check(str(ctx.main.status_label.text) == "Bottom view" or absf(cam.yaw) < 0.05,
			"key 8 keeps the bottom view id")


func _click_world(ctx: FilmContext, pt: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, pt)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))


func _exit(ctx: FilmContext) -> void:
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	if exit_btn != null:
		await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
		await process_frame
	var dlg: ConfirmationDialog = ctx.main._empty_sketch_dialog
	if dlg != null and dlg.visible:
		await FilmUI.click_control(ctx, dlg.get_ok_button(), FilmUICues.alert("OK", "Discard empty sketch"))
		await process_frame
		await process_frame


func _key(ctx: FilmContext, code: Key, ctrl: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	key.ctrl_pressed = ctrl
	key.meta_pressed = false
	if ctrl:
		ctx.main.interaction._input(key)
	else:
		ctx.main.camera.handle_input(key)
		ctx.main.interaction._emit_view_key_status(key)


func _look(cam: OrbitCamera) -> Vector3:
	return (-cam.global_transform.basis.z).normalized()


func _up(cam: OrbitCamera) -> Vector3:
	return cam.global_transform.basis.y.normalized()
