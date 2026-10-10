extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func push_key(vp: Viewport, code: Key, unicode: int = 0, mods: int = 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	ev.ctrl_pressed = (mods & KEY_MASK_CTRL) != 0
	ev.shift_pressed = (mods & KEY_MASK_SHIFT) != 0
	ev.alt_pressed = (mods & KEY_MASK_ALT) != 0
	ev.meta_pressed = (mods & KEY_MASK_META) != 0
	vp.push_input(ev)
	await _tree().process_frame
	var rel := InputEventKey.new()
	rel.keycode = code
	rel.physical_keycode = code
	rel.unicode = unicode
	rel.pressed = false
	rel.echo = false
	rel.ctrl_pressed = ev.ctrl_pressed
	rel.shift_pressed = ev.shift_pressed
	rel.alt_pressed = ev.alt_pressed
	rel.meta_pressed = ev.meta_pressed
	vp.push_input(rel)
	await _tree().process_frame


static func push_mouse(vp: Viewport, pos: Vector2, pressed: bool) -> void:
	if vp == null:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await _tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)
	await _tree().process_frame


static func x11_click_screen(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await _tree().process_frame


static func x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await x11_click_screen(vp, pos)


static func keycode_for_char(ch: String) -> Key:
	var c := ch.unicode_at(0)
	if ch == "/":
		return KEY_SLASH
	if ch == "\\":
		return KEY_BACKSLASH
	if ch == "-":
		return KEY_MINUS
	if ch == "_":
		return KEY_UNDERSCORE
	if ch == ".":
		return KEY_PERIOD
	if c >= 48 and c <= 57:
		return (KEY_0 + (c - 48)) as Key
	if c >= 97 and c <= 122:
		return (KEY_A + (c - 97)) as Key
	if c >= 65 and c <= 90:
		return (KEY_A + (c - 65)) as Key
	return KEY_NONE


static func type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		await push_key(vp, keycode_for_char(ch), ch.unicode_at(0))


static func click_uv(suite: Object, ctx: FilmContext, vp: Viewport, uv: Vector2, label: String = "sketch click") -> void:
	var screen := FilmUI.sketch_uv_to_screen(ctx, uv)
	suite.check(FilmUI.require_on_screen(ctx, screen, label), "sketch click on screen at %s" % str(uv))
	await x11_click_screen(vp, screen)


static func hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var screen := FilmUI.sketch_uv_to_screen(ctx, uv)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	await _tree().process_frame


static func zoom(ctx: FilmContext, center: Vector3, span: float) -> void:
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
	cam.pivot = ms.to_global(center) if ms != null else center
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = span / (2.0 * half)
	cam._update_transform()
	await _tree().process_frame
	await _tree().process_frame


static func boot(root: Window, tree: SceneTree, size: Vector2i) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = tree
	await FilmUI.ensure_test_viewport(ctx, size)
	return ctx
