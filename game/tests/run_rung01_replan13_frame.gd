# Rung 1 replan 13 WP5 — F / Frame inside a sketch fits the whole sketch (both circles).
# Real events: Viewport.push_input for F / Shift+F; View HUD Frame and marking-menu
# items 20/21 via visible buttons. Geometry is placed through the sketch API.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan13_frame.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const MARGIN_PX := 4.0
const FRAME_SIZE_TOL := 0.01
const ORIGIN := Vector2(0, 0)
const HEAD := Vector2(200, 0)
const ORIGIN_R := 10.0
const HEAD_R := 22.5

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
	print("rung01 replan13 WP5 frame sketch")
	FilmUI.reset_fail_count()
	await test_blank_sketch_f_fits_both_circles()
	await test_face_sketch_and_exit_3d()
	await test_face_sketch_origin_clears_rail()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_blank_sketch_f_fits_both_circles() -> void:
	print("- blank sketch: F / Shift+F / Frame / marking 20+21 fit both circles")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: OrbitCamera = ctx.main.camera
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "blank sketch is open")
	sm.sketch.add_circle(ORIGIN.x, ORIGIN.y, ORIGIN_R)
	sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	sm.run_solve()
	await process_frame
	await process_frame
	check(sm.sketch.entity_ids().size() >= 2, "two circles exist")

	var locked0 := cam.sketch_orientation_locked
	await _push_key(vp, KEY_F)
	await _record_head_extremes(ctx, "after F")
	_assert_both_circles_framed(ctx, "F")
	_assert_sketch_plane(ctx, locked0)

	var size_f := cam.size
	await _push_key(vp, KEY_F, true)
	await _record_head_extremes(ctx, "after Shift+F")
	_assert_both_circles_framed(ctx, "Shift+F")
	_assert_sketch_plane(ctx, locked0)
	check(_size_near(cam.size, size_f),
			"Shift+F frame size within 1%% of F (F=%.4f Shift+F=%.4f)" % [size_f, cam.size])

	var fit_btn := _find_labeled_button(ctx.main.view_hud, "Frame")
	check(fit_btn != null and fit_btn.is_visible_in_tree(),
			"View HUD has a visible Frame button")
	if fit_btn != null:
		await FilmUI.click_control(ctx, fit_btn, FilmUICues.alert("F", "View HUD Frame"))
		await process_frame
		await process_frame
	await _record_head_extremes(ctx, "after View HUD Frame")
	_assert_both_circles_framed(ctx, "View HUD Frame")
	_assert_sketch_plane(ctx, locked0)
	check(_size_near(cam.size, size_f),
			"View HUD Frame size within 1%% of F (F=%.4f HUD=%.4f)" % [size_f, cam.size])

	await _click_orient_item(ctx, "Frame selection")
	await _record_head_extremes(ctx, "after marking-menu 20")
	_assert_both_circles_framed(ctx, "marking-menu item 20")
	_assert_sketch_plane(ctx, locked0)
	check(_size_near(cam.size, size_f),
			"marking-menu 20 frame size within 1%% of F (F=%.4f item20=%.4f)" % [size_f, cam.size])

	await _click_orient_item(ctx, "Frame all")
	await _record_head_extremes(ctx, "after marking-menu 21")
	_assert_both_circles_framed(ctx, "marking-menu item 21")
	_assert_sketch_plane(ctx, locked0)
	check(_size_near(cam.size, size_f),
			"marking-menu 21 frame size within 1%% of F (F=%.4f item21=%.4f)" % [size_f, cam.size])

	# Centres must be on screen to type the 200 dim; fit_view is the product
	# sketch fit (setup only — F after the dim is what this leftover tests).
	sm.fit_view()
	await process_frame
	await process_frame
	await _smart_dim_centres_200(ctx)
	await _push_key(vp, KEY_F)
	await _record_head_extremes(ctx, "after Smart Dim 200 then F")
	_assert_both_circles_framed(ctx, "F after Smart Dim 200")
	_assert_sketch_plane(ctx, locked0)
	await _shutdown(ctx)


func test_face_sketch_and_exit_3d() -> void:
	print("- face sketch: F fits entities or the support face; exit restores 3D F")
	var ctx := await _boot()
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	await process_frame
	var body: String = ctx.view.selected_body
	if body == "":
		var ids: PackedStringArray = ctx.view.doc.body_ids()
		if not ids.is_empty():
			body = ids[0]
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "box placed, +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: OrbitCamera = ctx.main.camera
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "face sketch is open")
	check(sm.sketch.entity_ids().is_empty(), "face sketch starts empty")
	var locked0 := cam.sketch_orientation_locked
	await _push_key(vp, KEY_F)
	_assert_sketch_plane(ctx, locked0)
	var origin_screen := _project_model(ctx, sm.plane_origin)
	check(_in_framed_canvas(ctx, origin_screen),
			"empty face-sketch F keeps the support-face origin on the canvas (px %s)" % str(origin_screen))
	var size_empty_f := cam.size
	sm.fit_view()
	await process_frame
	check(_size_near(cam.size, size_empty_f),
			"empty face-sketch F matches fit_view (F=%.4f fit_view=%.4f)" % [size_empty_f, cam.size])
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"empty face-sketch F never leaves the sketch plane view")

	sm.sketch.add_circle(ORIGIN.x, ORIGIN.y, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	sm.run_solve()
	await process_frame
	await _push_key(vp, KEY_F)
	await _record_head_extremes(ctx, "face sketch after F")
	_assert_both_circles_framed(ctx, "face-sketch F with entities", 5.0, HEAD_R)
	_assert_sketch_plane(ctx, locked0)

	await FilmUI.exit_sketch(ctx)
	await process_frame
	await process_frame
	check(sm == null or not sm.active, "sketch session closed after Exit Sketch")
	check(not cam.sketch_orientation_locked, "sketch lock is off after Exit Sketch")
	check(not _sketch_fit_valid(cam),
			"camera.sketch_fit is invalid after exit_sketch")
	await _push_key(vp, KEY_F)
	check(not _sketch_fit_valid(cam), "sketch_fit stays invalid after 3D F")
	check(not cam.sketch_orientation_locked, "3D F does not re-lock the sketch view")
	var dist0 := cam.distance
	var pivot0 := cam.pivot
	cam.frame_selection_or_all(false)
	check(is_equal_approx(cam.distance, dist0) and cam.pivot.is_equal_approx(pivot0),
			"3D F matches the pre-change body AABB framer (distance %.3f)" % dist0)
	await _shutdown(ctx)


func test_face_sketch_origin_clears_rail() -> void:
	# sx-034 A9: face sketch with geometry only at the head (jaw / Ø45). After
	# F the part origin (pivot Ø20 centre) must sit on the canvas to the right
	# of the left rail — not under Polygon.
	print("- face sketch: F leaves a canvas margin left of the part origin")
	var ctx := await _boot()
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	await process_frame
	var body: String = ctx.view.selected_body
	if body == "":
		var ids: PackedStringArray = ctx.view.doc.body_ids()
		if not ids.is_empty():
			body = ids[0]
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "box placed, +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: OrbitCamera = ctx.main.camera
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "face sketch is open for origin-rail fit")
	sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	sm.run_solve()
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame
	await process_frame
	await _push_key(vp, KEY_F)
	await process_frame
	var origin_screen := _project_uv(ctx, ORIGIN)
	var rail_right := _rail_right_px(ctx)
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	print("  origin px=%s rail_right=%.1f canvas=%s" % [
			str(origin_screen), rail_right, str(canvas)])
	check(_in_framed_canvas(ctx, origin_screen),
			"after F, origin is on the canvas right of the rail (px %s, rail %.1f)" % [
				str(origin_screen), rail_right])
	check(origin_screen.x >= rail_right + MARGIN_PX,
			"origin has a canvas margin left of it (x=%.1f rail=%.1f)" % [
				origin_screen.x, rail_right])
	check(canvas.has_point(origin_screen),
			"origin sits in the chrome-inset canvas %s (px %s)" % [
				str(canvas), str(origin_screen)])
	var head_ok := true
	for uv in _circle_extremes(HEAD, HEAD_R):
		if not _in_framed_canvas(ctx, _project_uv(ctx, uv)):
			head_ok = false
	check(head_ok, "Ø45 extremes stay in the canvas after origin-aware F")
	await _shutdown(ctx)


func _assert_both_circles_framed(ctx: FilmContext, via: String,
		origin_r: float = ORIGIN_R, head_r: float = HEAD_R) -> void:
	var origin_ok := true
	var head_ok := true
	for uv in _circle_extremes(ORIGIN, origin_r):
		var px := _project_uv(ctx, uv)
		if not _in_framed_canvas(ctx, px):
			origin_ok = false
			print("  measure: Ø20 extreme uv=%s px=%s via %s OUT" % [str(uv), str(px), via])
	for uv in _circle_extremes(HEAD, head_r):
		var px := _project_uv(ctx, uv)
		if not _in_framed_canvas(ctx, px):
			head_ok = false
	check(origin_ok, "Ø20 extremes are in the canvas (4 px margin, right of the rail) after %s" % via)
	check(head_ok, "Ø45 extremes are in the canvas (4 px margin, right of the rail) after %s" % via)


func _assert_sketch_plane(ctx: FilmContext, locked_before: bool) -> void:
	var cam: OrbitCamera = ctx.main.camera
	var sm: SketchMode = ctx.main.sketch_mode
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "camera.projection == ORTHOGONAL")
	check(cam.sketch_orientation_locked == locked_before,
			"camera.sketch_orientation_locked unchanged (%s)" % str(cam.sketch_orientation_locked))
	var n: Vector3 = sm.plane_normal().normalized()
	var ms: Node3D = ctx.main.model_space
	var n_world: Vector3 = (ms.global_transform.basis * n).normalized() if ms != null else n
	var fwd: Vector3 = -cam.global_transform.basis.z
	var align := absf(fwd.dot(n_world))
	check(align >= 0.9999,
			"camera forward is parallel to the sketch normal (dot %.6f)" % align)


func _record_head_extremes(ctx: FilmContext, when: String) -> void:
	print("  Ø45 extremes %s:" % when)
	for uv in _circle_extremes(HEAD, HEAD_R):
		var px := _project_uv(ctx, uv)
		var inside := _in_framed_canvas(ctx, px)
		print("    uv=%s → px=(%.1f, %.1f) %s" % [
			str(uv), px.x, px.y, "IN" if inside else "OUT"])


func _circle_extremes(center: Vector2, r: float) -> Array[Vector2]:
	return [
		center + Vector2(r, 0.0),
		center + Vector2(-r, 0.0),
		center + Vector2(0.0, r),
		center + Vector2(0.0, -r),
	]


func _project_uv(ctx: FilmContext, uv: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	return _project_model(ctx, sm.to_model(uv))


func _project_model(ctx: FilmContext, model_pt: Vector3) -> Vector2:
	var cam: Camera3D = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	var world: Vector3 = ms.to_global(model_pt) if ms != null else model_pt
	return cam.unproject_position(world)


func _in_framed_canvas(ctx: FilmContext, screen: Vector2) -> bool:
	var vp := ctx.tree.root.get_viewport().get_visible_rect().grow(-MARGIN_PX)
	if not vp.has_point(screen):
		return false
	var rail_right := _rail_right_px(ctx)
	if screen.x < rail_right + MARGIN_PX:
		return false
	return true


func _rail_right_px(ctx: FilmContext) -> float:
	var stack: Control = ctx.main.left_stack
	if stack != null and stack.is_visible_in_tree():
		return stack.get_global_rect().end.x
	return ChromeDock.rail_right


func _size_near(a: float, b: float) -> bool:
	var denom := maxf(maxf(absf(a), absf(b)), 1e-6)
	return absf(a - b) / denom <= FRAME_SIZE_TOL


func _sketch_fit_valid(cam: OrbitCamera) -> bool:
	if cam == null:
		return false
	if not ("sketch_fit" in cam):
		return false
	var hook: Variant = cam.get("sketch_fit")
	return hook is Callable and (hook as Callable).is_valid()


func _find_labeled_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _click_orient_item(ctx: FilmContext, label: String) -> void:
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix != null and ix.has_method("_show_orient_popup"),
			"interaction can open the orientation marking menu")
	if ix == null:
		return
	ix._show_orient_popup()
	await process_frame
	await process_frame
	var popup: PopupPanel = ix._orient_popup
	var btn := _find_labeled_button(popup, label)
	check(btn != null and btn.is_visible_in_tree(),
			"marking-menu has visible '%s'" % label)
	if btn == null:
		if popup != null:
			popup.hide()
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Space", label))
	await process_frame
	await process_frame
	if popup != null and popup.visible:
		popup.hide()


func _smart_dim_centres_200(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv(ctx, ORIGIN, "Smart Dim first centre")
	await _click_uv(ctx, HEAD, "Smart Dim second centre")
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible and ix._dim_edit_line != null:
		await _x11_click(ix._dim_edit_line)
		await _x11_type(ix._dim_edit_line.get_viewport(), "200")
		await _x11_enter(ix._dim_edit_line.get_viewport())
		await process_frame
		await process_frame
	var gap := _centre_gap(sm)
	check(absf(gap - 200.0) <= 0.2, "centre distance is 200 ± 0.2 after Smart Dim (got %.3f)" % gap)
	var saw_dim := false
	for s in _status_log:
		if s.contains("Dimension updated") or s.contains("dimension"):
			saw_dim = true
	print("  status after Smart Dim: %s" % str(ctx.main.status_label.text))
	check(gap > 0.0, "Smart Dim path produced a centre distance")
	if not saw_dim:
		print("  note: no 'Dimension updated' in status log (log: %s)" % str(_status_log))


func _centre_gap(sm: SketchMode) -> float:
	var centres: Array[Vector2] = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			centres.append(info["center"])
	if centres.size() < 2:
		return -1.0
	centres.sort_custom(func(a, b): return a.x < b.x)
	return centres[0].distance_to(centres[1])


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


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


func _x11_click(ctrl: Control) -> void:
	await _x11_click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


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


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame


func _x11_enter(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
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
