# sx-037 A7 / A7b / A8 — opening a sketch on the blank's top face frames the
# whole body inside the chrome canvas. An empty face sketch used to fit a
# 25 mm window on the part origin, so the Ø45 head at x=200 sat off the right
# edge and F / Frame / wheel zoom-out could not bring it back.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_sx037_faceframe.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const WHEEL_NOTCHES := 8

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
	print("rung01 sx037 face-sketch frame")
	FilmUI.reset_fail_count()
	await test_face_sketch_frames_blank()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_face_sketch_frames_blank() -> void:
	print("- blank face sketch: entry, F, Shift+F, HUD Frame, wheel zoom-out")
	var ctx := await _boot()
	await _build_blank(ctx)
	var body := _sole_body(ctx)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body) if body != "" else {}
	check(not bb.is_empty(), "blank body has a bbox")
	if not bb.is_empty():
		var ext: Vector3 = bb["max"] - bb["min"]
		print("  blank bbox min=%s max=%s size=%s" % [str(bb["min"]), str(bb["max"]), str(ext)])
		check(absf(ext.x - 232.5) < 2.0 and absf(ext.y - 45.0) < 2.0 and absf(ext.z - 10.0) < 1.0,
				"blank is 232.5 x 45 x 10 (got %s)" % str(ext))
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "top +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: OrbitCamera = ctx.main.camera
	check(sm != null and sm.active, "face sketch is open")
	check(sm != null and sm.sketch != null and sm.sketch.entity_ids().is_empty(),
			"face sketch starts empty")
	var status := str(ctx.main.status_label.text)
	check(status.contains("Sketch on face") and status.contains("+Z"),
			"status is the top-face sketch (got `%s`)" % status)
	_assert_body_in_canvas(ctx, body, "entry")

	_park_on_origin(ctx)
	await process_frame
	check(not _body_in_canvas(ctx, body),
			"parked view hides part of the blank (the sx-037 failure)")
	await _push_key(ctx.main.get_viewport(), KEY_F)
	_assert_body_in_canvas(ctx, body, "F")

	_park_on_origin(ctx)
	await process_frame
	await _push_key(ctx.main.get_viewport(), KEY_F, true)
	_assert_body_in_canvas(ctx, body, "Shift+F")

	_park_on_origin(ctx)
	await process_frame
	var fit_btn := _find_labeled_button(ctx.main.view_hud, "Frame")
	check(fit_btn != null and fit_btn.is_visible_in_tree(), "View HUD has a visible Frame button")
	if fit_btn != null:
		await FilmUI.click_control(ctx, fit_btn, FilmUICues.alert("F", "View HUD Frame"))
		await process_frame
		await process_frame
	_assert_body_in_canvas(ctx, body, "HUD Frame")

	_park_on_origin(ctx)
	await process_frame
	check(not _body_in_canvas(ctx, body), "wheel setup still hides the head")
	var cursor := _wheel_cursor(ctx)
	var revealed := false
	for i in WHEEL_NOTCHES:
		await _wheel_at(ctx.main.get_viewport(), cursor, false)
		if _body_in_canvas(ctx, body):
			revealed = true
			print("  wheel zoom-out framed the blank on notch %d" % (i + 1))
			break
	check(revealed,
			"wheel zoom-out frames the blank within %d notches" % WHEEL_NOTCHES)
	check(cam.sketch_orientation_locked, "wheel zoom-out stays in the face sketch")
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"wheel zoom-out stays on the sketch plane")
	await _shutdown(ctx)


func _build_blank(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open for the blank")
	if sm == null or sm.sketch == null:
		return
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	check(a != "" and b != "", "blank circles exist")
	sm._set_selected([a, b])
	var lines := sm.shaft_lines_selected()
	check(lines == 2, "shaft lines added (got %d)" % lines)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	check(not sm.active, "blank extrude left the sketch")


func _sole_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[ids.size() - 1]


func _park_on_origin(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: OrbitCamera = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	var origin: Vector3 = sm.plane_origin if sm != null else Vector3.ZERO
	cam.pivot = ms.to_global(origin) if ms != null else origin
	# The old empty-sketch fit: ~25 mm half-extent, ortho height around 80 mm.
	cam.distance = 80.0 / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam._update_transform()


func _wheel_cursor(ctx: FilmContext) -> Vector2:
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	# Near the right edge, over the visible left end — the cursor anchor that
	# used to keep the head off-screen no matter how far the wheel went.
	return canvas.position + Vector2(canvas.size.x * 0.82, canvas.size.y * 0.5)


func _assert_body_in_canvas(ctx: FilmContext, body: String, via: String) -> void:
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	var inside := _body_in_canvas(ctx, body)
	print("  %s canvas=%s inside=%s size=%.2f pivot=%s" % [
		via, str(canvas), str(inside), cam.size, str(cam.pivot)])
	check(inside, "%s: blank bbox projects inside the chrome canvas %s" % [via, str(canvas)])
	check(cam.sketch_orientation_locked, "%s: still in the locked face-sketch view" % via)


func _body_in_canvas(ctx: FilmContext, body: String) -> bool:
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	var vp: Rect2 = ctx.main.get_viewport().get_visible_rect()
	var rail := _rail_right_px(ctx)
	for c in _body_world_corners(ctx, body):
		if cam.is_position_behind(c):
			print("  measure: corner %s behind camera" % str(c))
			return false
		var px: Vector2 = cam.unproject_position(c)
		if not vp.has_point(px) or not canvas.has_point(px) or px.x < rail:
			print("  measure: corner px=%s OUT (canvas %s rail %.1f)" % [str(px), str(canvas), rail])
			return false
	return true


func _body_world_corners(ctx: FilmContext, body: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		return out
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var ms: Node3D = ctx.main.model_space
	for i in 8:
		var local := Vector3(
			mx.x if (i & 1) != 0 else mn.x,
			mx.y if (i & 2) != 0 else mn.y,
			mx.z if (i & 4) != 0 else mn.z)
		out.append(ms.to_global(local) if ms != null else local)
	return out


func _rail_right_px(ctx: FilmContext) -> float:
	var stack: Control = ctx.main.left_stack
	if stack != null and stack.is_visible_in_tree():
		return stack.get_global_rect().end.x
	return ChromeDock.rail_right


func _last_status() -> String:
	return "" if _status_log.is_empty() else _status_log[_status_log.size() - 1]


func _find_labeled_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _push_key(vp: Viewport, keycode: Key, shift := false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


func _wheel_at(vp: Viewport, pos: Vector2, zoom_in: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = 1.0
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)
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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame
