# Rung 1 replan 9 WP3 — the 60 s autosave must not mark the document saved: File > New still asks before it discards.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dirty.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan9 WP3 autosave keeps the document dirty")
	FilmUI.reset_fail_count()
	await test_autosave_dirty()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_autosave_dirty() -> void:
	var ctx := await _boot()
	var main = ctx.main
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	check(doc.body_ids().size() == 1, "one body exists")
	check(main._document_is_dirty(), "a fresh extrude makes the document dirty")

	var autosave_path := ProjectSettings.globalize_path("user://autosave.sxp")
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)
	main._autosave()
	check(FileAccess.file_exists(autosave_path), "the autosave wrote user://autosave.sxp")
	check(main._document_is_dirty(), "the autosave does not mark the document saved")
	main._autosave()
	check(main._document_is_dirty(), "a second autosave still does not mark the document saved")

	main._on_file_menu(0)
	await process_frame
	await process_frame
	check(main.confirm_dialog.visible, "File > New after an autosave asks to discard unsaved changes")
	check(doc.body_ids().size() == 1, "the body is still there while the prompt is up")
	main.confirm_dialog.hide()
	await process_frame
	check(doc.body_ids().size() == 1, "Cancel keeps the document")

	var save_path := "/tmp/replan9_dirty.sxp"
	main.current_path = save_path
	main._save_current()
	await process_frame
	check(not main._document_is_dirty(), "a real Save marks the document clean")
	main._on_file_menu(0)
	await process_frame
	await process_frame
	check(not main.confirm_dialog.visible, "File > New after a real Save does not ask")
	check(ctx.view.doc.body_ids().size() == 0, "File > New after a real Save gives an empty part")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
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
