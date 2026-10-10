# Rung 1 replan 18 WP1 — polygon AF invariance (checklist rows L9 / A14).
# Across-flats polygon, flats horizontal, start angle 0. The pointer sits on
# the circumscribed circle. AF = √3 × |pointer − centre|, independent of the
# bearing. Real pointer moves at equal pixel distance. No product code.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan18_polyaf.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const BEARINGS: Array[float] = [20.0, 70.0, 110.0, 160.0, 200.0, 250.0, 290.0, 340.0]
const HOVER_PX := 150.0
const ZOOM_MM := 80.0

var _status_log: Array[String] = []
var _main = null


func _init() -> void:
	print("rung01 replan18 polygon AF invariance")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	await _run_case(ctx, true, Vector2.ZERO, true)
	await _run_case(ctx, false, Vector2.ZERO, false)
	await _run_case(ctx, true, Vector2(37.0, -21.0), true)
	await _run_case(ctx, false, Vector2(37.0, -21.0), false)
	await _typed_twenty(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	finish()


func _note(text: String) -> void:
	if text == "":
		return
	if _status_log.is_empty() or _status_log[_status_log.size() - 1] != text:
		_status_log.append(text)


func _grab() -> String:
	if _main == null or _main.status_label == null:
		return ""
	var t := str(_main.status_label.text)
	_note(t)
	return t


func _saw_log(needle: String) -> bool:
	_grab()
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _log_exact(line: String) -> bool:
	_grab()
	for s in _status_log:
		if s == line:
			return true
	return false


func _on_status(text: String) -> void:
	_note(text)


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
	_main = main
	if main.sketch_mode != null:
		main.sketch_mode.status.connect(_on_status)
	if main.ops_panel != null:
		main.ops_panel.status.connect(_on_status)
	if main.interaction != null:
		main.interaction.status.connect(_on_status)
	if main.timeline != null:
		main.timeline.status.connect(_on_status)
	return ctx


func _file_new(ctx: FilmContext, confirm_ok: bool) -> void:
	await _click_menu_item(ctx, "File", 0, "File → New")
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible and confirm_ok:
		var ok := dlg.get_ok_button()
		if ok != null:
			await _x11_click_embedded(ok)
			await process_frame
	await process_frame


func _ground_sketch(ctx: FilmContext) -> void:
	var b := FilmUI.find_palette_sketch_button(ctx.main)
	check(b != null, "Sketch button is visible")
	if b != null:
		await _x11_click(b)
		await process_frame
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		return
	for world in [Vector3(22, 18, 0), Vector3(12, 0, 0), Vector3(0, 12, 0)]:
		var screen := FilmUI.model_to_screen(ctx, world)
		if not FilmUI.is_on_screen(ctx, screen):
			continue
		await _click_screen(ctx.main.get_viewport(), screen)
		await process_frame
		await process_frame
		if ctx.main.sketch_mode.active:
			return


func _press_rail(ctx: FilmContext, label: String) -> Button:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null and btn.is_visible_in_tree(), "rail `%s` is visible" % label)
	if btn == null:
		return null
	await _x11_click(btn)
	await process_frame
	return btn


func _click_uv(ctx: FilmContext, uv: Vector2, _desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	if not FilmUI.is_on_screen(ctx, screen):
		await _zoom_model(ctx, sm.to_model(uv), 120.0)
		screen = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _click_screen(ctx.main.get_viewport(), screen)
	await process_frame


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _motion(ctx.main.get_viewport(), screen)


func _zoom_model(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
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


func _click_screen(vp: Viewport, pos: Vector2, double_click := false) -> void:
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
	await process_frame


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		return
	await _click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


func _x11_click_embedded(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	await _click_screen(root.get_viewport(), pos)


func _key(ctx: FilmContext, code: Key) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame
	_grab()


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		else:
			continue
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame


func _click_menu_item(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null:
		check(false, "%s menu is visible (%s)" % [title, desc])
		return false
	await _x11_click(btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	if popup == null or not popup.visible:
		check(false, "%s popup visible (%s)" % [title, desc])
		return false
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "%s has id %d" % [desc, id])
		return false
	popup.reset_size()
	await process_frame
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs if font == null else font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(idx):
		y += float(font_h + v_sep)
		if popup.is_item_separator(i):
			y += 4.0
	y += float(font_h) * 0.5
	var got := [-1]
	var cb := func(pressed_id: int) -> void:
		got[0] = pressed_id
	popup.id_pressed.connect(cb)
	await _click_screen(root.get_viewport(), Vector2(popup.position) + Vector2(popup.size.x * 0.5, y))
	await process_frame
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	if got[0] != id:
		popup.id_pressed.emit(id)
		await process_frame
	return true


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _case_tag(snap: bool, centre: Vector2) -> String:
	var where := "origin" if centre == Vector2.ZERO else "offset (%.1f, %.1f)" % [centre.x, centre.y]
	return "snap %s %s" % ["on" if snap else "off", where]


func _ppm(ctx: FilmContext, sm: SketchMode, centre: Vector2) -> Vector2:
	var c := FilmUI.model_to_screen(ctx, sm.to_model(centre))
	var ex := FilmUI.model_to_screen(ctx, sm.to_model(centre + Vector2(10.0, 0.0)))
	var ey := FilmUI.model_to_screen(ctx, sm.to_model(centre + Vector2(0.0, 10.0)))
	return Vector2(c.distance_to(ex) / 10.0, c.distance_to(ey) / 10.0)


func _screen_at_px(ctx: FilmContext, sm: SketchMode, centre: Vector2, deg: float, px: float) -> Vector2:
	var cs := FilmUI.model_to_screen(ctx, sm.to_model(centre))
	var aim := centre + Vector2.from_angle(deg_to_rad(deg))
	var ps := FilmUI.model_to_screen(ctx, sm.to_model(aim))
	var dir := ps - cs
	if dir.length_squared() < 1e-8:
		return cs
	return cs + dir.normalized() * px


## Same evaluation as SketchMode: AF = |centre + (hover−centre)·√3 − centre|.
## √3 × length and the scaled-tip length differ by 1 ulp at some bearings.
func _af_num(centre: Vector2, hover: Vector2) -> float:
	var tip := centre + (hover - centre) * sqrt(3.0)
	return centre.distance_to(tip)


func _af_text(centre: Vector2, hover: Vector2) -> String:
	return "%.4f" % _af_num(centre, hover)


func _hover_status(af_text: String) -> String:
	return "Polygon AF %s — flats horizontal — click to place (or type the size)" % af_text


func _printed_af(line: String) -> float:
	var head := "Polygon AF "
	if not line.begins_with(head):
		return -1.0
	var rest := line.substr(head.length())
	var num := rest.split(" ")[0]
	if not num.is_valid_float():
		return -1.0
	return float(num)


func _line_count(sm: SketchMode) -> int:
	if sm == null or sm.sketch == null:
		return 0
	var n := 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "line":
			n += 1
	return n


func _fresh_polygon(ctx: FilmContext, snap: bool, centre: Vector2, tag: String) -> SketchMode:
	await _file_new(ctx, true)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "%s ground sketch is open" % tag)
	if sm == null or not sm.active:
		return null
	await _press_rail(ctx, "Polygon")
	check(sm.tool == SketchMode.Tool.POLYGON and sm.tool_variant == "across_flats",
			"%s rail Polygon is across-flats" % tag)
	await _zoom_model(ctx, sm.to_model(centre), ZOOM_MM)
	var ppm := _ppm(ctx, sm, centre)
	var px_mm := 0.0 if ppm.x <= 1e-6 else HOVER_PX / ppm.x
	check(ppm.x > 1.0 and ppm.y > 1.0 and absf(ppm.x - ppm.y) / ppm.x <= 0.01,
			"%s zoom: 150 px = %.4f mm (ppm_x %.4f ppm_y %.4f)" % [tag, px_mm, ppm.x, ppm.y])
	sm.snap_enabled = snap
	check(sm.snap_enabled == snap, "%s snap_enabled is %s before the centre click" % [tag, snap])
	_status_log.clear()
	await _click_uv(ctx, centre, "polygon centre")
	check(sm._tool_points.size() == 1, "%s centre click armed one point (got %d)" % [tag, sm._tool_points.size()])
	if sm._tool_points.size() == 1:
		var got: Vector2 = sm._tool_points[0]
		check(got.distance_to(centre) <= 0.05,
				"%s centre landed on (%.4f, %.4f) (got %.4f, %.4f)" % [tag, centre.x, centre.y, got.x, got.y])
	return sm


func _assert_bearing(ctx: FilmContext, sm: SketchMode, centre: Vector2, tag: String, deg: float, px: float) -> float:
	var screen := _screen_at_px(ctx, sm, centre, deg, px)
	var cs := FilmUI.model_to_screen(ctx, sm.to_model(centre))
	check(absf(screen.distance_to(cs) - px) <= 0.01 and FilmUI.is_on_screen(ctx, screen),
			"%s %.0f° hover is %.1f px from the centre on screen (got %.3f at %s)" % [
				tag, deg, px, screen.distance_to(cs), str(screen)])
	await _motion(ctx.main.get_viewport(), screen)
	await process_frame
	var hover: Vector2 = sm._hover
	var radius := centre.distance_to(hover)
	# Status measures from the clicked centre. Snap-off leaves that point a
	# fraction of a micron off centre_model, which moves %.4f by 0.0001.
	var poly_c := centre
	if sm._tool_points.size() == 1:
		poly_c = sm._tool_points[0]
	var af_num := _af_num(poly_c, hover)
	var af_text := _af_text(poly_c, hover)
	var want := _hover_status(af_text)
	check(_grab() == want, "%s %.0f° %d px status `%s` (got `%s`)" % [tag, deg, int(px), want, _grab()])
	var verts: Array[Vector2] = sm.polygon_preview_vertices()
	check(verts.size() == 6, "%s %.0f° preview has 6 vertices (got %d)" % [tag, deg, verts.size()])
	for i in 6:
		var on := false
		if i < verts.size():
			on = absf(verts[i].distance_to(centre) - radius) <= 0.05
		check(on, "%s %.0f° vertex %d is |hover−centre| %.4f mm from the centre" % [tag, deg, i, radius])
	var min_y := INF
	var max_y := -INF
	for v in verts:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	var extent := max_y - min_y if verts.size() > 0 else -1.0
	check(absf(extent - af_num) <= 0.05,
			"%s %.0f° vertical extent %.4f equals AF %.4f (±0.05)" % [tag, deg, extent, af_num])
	return _printed_af(_grab())


func _run_case(ctx: FilmContext, snap: bool, centre: Vector2, commit: bool) -> void:
	var tag := _case_tag(snap, centre)
	print("-- %s" % tag)
	var sm := await _fresh_polygon(ctx, snap, centre, tag)
	if sm == null or not sm.active or sm._tool_points.size() != 1:
		check(false, "%s skipped bearings: polygon centre is not armed" % tag)
		return
	var printed: Array[float] = []
	var af70 := -1.0
	var screen340 := Vector2.ZERO
	var af340 := ""
	for deg in BEARINGS:
		var got := await _assert_bearing(ctx, sm, centre, tag, deg, HOVER_PX)
		printed.append(got)
		if is_equal_approx(deg, 70.0):
			af70 = got
		if is_equal_approx(deg, 340.0):
			screen340 = _screen_at_px(ctx, sm, centre, deg, HOVER_PX)
			af340 = "%.4f" % got
	var base := printed[0] if not printed.is_empty() else -1.0
	for i in printed.size():
		var spread := absf(printed[i] - base) / maxf(absf(base), 1e-9)
		check(printed[i] > 0.0 and spread <= 0.002,
				"%s printed AF %.4f at %.0f° within 0.2%% of %.4f" % [
					tag, printed[i], BEARINGS[i], base])
	var af100 := await _assert_bearing(ctx, sm, centre, tag, 70.0, 100.0)
	var af200 := await _assert_bearing(ctx, sm, centre, tag, 70.0, 200.0)
	var ratio100 := af100 / af70 if af70 > 0.0 else -1.0
	var ratio200 := af200 / af70 if af70 > 0.0 else -1.0
	check(af70 > 0.0 and absf(ratio100 - (100.0 / 150.0)) <= 0.01 * (100.0 / 150.0),
			"%s AF 100:150 is 1:1.5 within 1%% (%.4f : %.4f)" % [tag, af100, af70])
	check(af70 > 0.0 and absf(ratio200 - (200.0 / 150.0)) <= 0.01 * (200.0 / 150.0),
			"%s AF 150:200 is 1.5:2 within 1%% (%.4f : %.4f)" % [tag, af70, af200])
	if not commit:
		return
	var commit_line := "Polygon AF %s — flats horizontal" % af340
	await _click_screen(ctx.main.get_viewport(), screen340)
	await process_frame
	await process_frame
	_grab()
	check(_line_count(sm) == 6,
			"%s commit at 340° holds 6 lines (got %d)" % [tag, _line_count(sm)])
	check(_log_exact(commit_line),
			"%s commit status is `%s` (label `%s`)" % [tag, commit_line, _grab()])


func _typed_twenty(ctx: FilmContext) -> void:
	var tag := "case 1 typed 20"
	print("-- %s" % tag)
	var sm := await _fresh_polygon(ctx, true, Vector2.ZERO, tag)
	if sm == null or not sm.active or sm._tool_points.size() != 1:
		check(false, "%s centre click did not arm the polygon" % tag)
		return
	var want := "Polygon AF 20.0000 — flats horizontal"
	_status_log.clear()
	await _type_text(ctx.main.get_viewport(), "20")
	await _key(ctx, KEY_ENTER)
	await process_frame
	await process_frame
	_grab()
	check(_grab() == want or _log_exact(want),
			"%s status `%s` (label `%s`)" % [tag, want, _grab()])
