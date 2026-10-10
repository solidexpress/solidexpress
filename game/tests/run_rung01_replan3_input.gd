# Rung 1 replan 3 WP2 — unfocused Distance 7.5, Up To Surface face pick.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan3_input.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")



func _init() -> void:
	print("rung01 replan3 WP2 input")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	var vp_size: Vector2i = root.size
	check(vp_size.x == 1280 and vp_size.y == 800,
			"test viewport is 1280x800 (got %s)" % str(vp_size))

	await test_unfocused_distance_75(ctx)
	await test_preview_digits_go_to_dim(ctx)
	await test_key1_frames_front_outside_sketch(ctx)
	await test_up_to_surface_face_pick(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan3_input.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input call")
	check(not src.contains("set_" + "up_to_face"), "test source has no face-id setter")
	check(not src.contains("set_" + "finish_end"), "test source has no finish-end setter")
	check(not src.contains("set_" + "extrude_distance"), "test source has no distance setter")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("item_selected" + ".emit"), "test source has no item_selected emit")
	check(not src.contains("export_3mf" + "("), "test source has no export_3mf call")


func test_unfocused_distance_75(ctx: FilmContext) -> void:
	print("- unfocused 7.5 reaches Distance; camera stays put")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var cam: OrbitCamera = ctx.main.camera
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Hex centre")
	await _click_uv(ctx, Vector2(8, 0), "Hex size")
	await process_frame
	check(sm.active, "sketch stays active after the polygon")
	check(not sm.has_single_dof_preview(),
			"polygon is committed (preview off, points=%d)" % sm._tool_points.size())
	await _release_gui_focus(ctx)
	var dist := _distance_edit(chrome)
	check(dist != null, "Distance LineEdit exists")
	check(dist == null or not dist.has_focus(), "Distance is not focused before 7.5")
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == null or not (owner is LineEdit or owner is SpinBox),
			"no LineEdit/SpinBox focused before 7.5 (got %s)" % (
				owner.name if owner != null else "none"))
	var basis0: Basis = cam.global_transform.basis
	var yaw0 := cam.yaw
	var pitch0 := cam.pitch
	await _push_length_keys(ctx, "7.5")
	await process_frame
	if chrome == null or not chrome.has_method("focus_distance_for_typing"):
		check(false,
				"focus_distance_for_typing is missing on SketchContextChrome — WP1 has not landed; unfocused 7.5 cannot fill Distance")
	else:
		var parsed: Variant = _parse_distance_text(chrome)
		check(parsed != null and is_equal_approx(float(parsed), 7.5),
				"Distance LineEdit parses as 7.5 (got %s from '%s')" % [
					str(parsed), _distance_raw(chrome)])
		var readout := _readout_text(chrome)
		check(readout.contains("7.5"), "readout contains 7.5 (%s)" % readout)
	check(cam.global_transform.basis.is_equal_approx(basis0),
			"camera basis unchanged after unfocused 7.5")
	check(is_equal_approx(cam.yaw, yaw0) and is_equal_approx(cam.pitch, pitch0),
			"camera yaw/pitch unchanged after unfocused 7.5")


func test_preview_digits_go_to_dim(ctx: FilmContext) -> void:
	print("- preview KEY_2 KEY_0 go to the dim blank, not Distance")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var cam: OrbitCamera = ctx.main.camera
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Preview hex centre")
	await process_frame
	check(sm.has_single_dof_preview(), "preview is active before typing 20")
	await _release_gui_focus(ctx)
	var dist := _distance_edit(chrome)
	check(dist == null or not dist.has_focus(), "Distance is not focused before 20")
	var dim := _dim_edit(chrome)
	check(dim != null, "dim LineEdit exists")
	var basis0: Basis = cam.global_transform.basis
	await _push_length_keys(ctx, "20")
	await process_frame
	var dim_text := "" if dim == null else str(dim.text)
	check(dim_text.contains("20"), "dim blank contains 20 (got '%s')" % dim_text)
	var parsed: Variant = _parse_distance_text(chrome)
	check(parsed != null and is_equal_approx(float(parsed), 20.0),
			"Distance still parses as the default 20 (got %s from '%s')" % [
				str(parsed), _distance_raw(chrome)])
	check(cam.global_transform.basis.is_equal_approx(basis0),
			"camera basis unchanged after preview 20")


func test_key1_frames_front_outside_sketch(ctx: FilmContext) -> void:
	print("- leave sketch: KEY_1 frames the front view")
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await _exit_sketch(ctx)
	var cam: OrbitCamera = ctx.main.camera
	check(sm == null or not sm.active, "sketch session is closed")
	check(not cam.sketch_orientation_locked, "sketch lock is off outside a sketch")
	await _push_key(ctx.main.get_viewport(), KEY_1, 0)
	await process_frame
	await process_frame
	check(is_equal_approx(cam.yaw, 0.0), "KEY_1 frames front (yaw 0, got %.4f)" % cam.yaw)
	check(is_equal_approx(cam.pitch, 0.0), "KEY_1 frames front (pitch 0, got %.4f)" % cam.pitch)


func test_up_to_surface_face_pick(ctx: FilmContext) -> void:
	print("- 40x30 Blind 10, Cut Up To Surface, bottom-face pick, through hole")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	await _zoom_uv(ctx, Vector2(20, 15), 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Rect corner A")
	await _click_uv(ctx, Vector2(40, 30), "Rect corner B")
	await process_frame
	check(not sm.has_single_dof_preview(), "rectangle is committed")
	await _type_distance_click_path(ctx, "10")
	await _click_extrude(ctx)
	await process_frame
	await process_frame
	check(not sm.active, "Blind 10 left the sketch")
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(not ids.is_empty(), "rectangular solid exists")
	if ids.is_empty():
		return
	var body := str(ids[0])
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.z - 10.0) <= 0.2, "Blind 10 thickness is 10 (got %.3f)" % ext.z)
	var top := _face_along(ctx, body, 1)
	var bottom := _face_along(ctx, body, -1)
	check(top != "" and bottom != "" and top != bottom, "top and bottom faces differ")
	if top == "" or bottom == "":
		return

	await _sketch_on_top(ctx, body, top, float(bb["max"].z))
	sm = ctx.main.sketch_mode
	check(sm.active, "sketch is open on the top face")
	chrome = ctx.main.sketch_chrome
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _zoom_uv(ctx, Vector2(20, 15), 80.0)
	await _click_uv(ctx, Vector2(20, 15), "Hole centre")
	await _click_uv(ctx, Vector2(25, 15), "Hole radius")
	await process_frame
	var n_geo := sm.sketch.entity_ids().size() if sm.sketch != null else 0
	var pts0: int = sm._tool_points.size()
	await _pick_option(ctx, _finish_op(chrome), 1, "Cut")
	await _pick_option(ctx, _finish_end(chrome), 3, "Up To Surface")
	var ex_btn := chrome.extrude_button()
	check(chrome.get_finish_end() == "to_face", "End is Up To Surface after the popup click")
	check(str(chrome.up_to_face_id).strip_edges() == "",
			"up_to_face_id is empty before the face click")
	check(ex_btn != null and ex_btn.disabled, "Extrude is disabled until a face is picked")
	check(chrome.wants_face_pick(), "Up To Surface arms a face pick")
	# End = Up To Surface does not steal Circle clicks. Pick face does.
	chrome.arm_face_pick()

	await _click_bottom_face(ctx, bottom)
	await process_frame
	check(str(chrome.up_to_face_id) == bottom, "viewport click set the bottom face")
	check(sm.active, "face pick did not exit the sketch")
	check(sm.sketch == null or sm.sketch.entity_ids().size() == n_geo,
			"face pick added no sketch entity")
	check(sm._tool_points.size() == pts0, "face pick added no sketch point")
	var face_label := _face_label_text(chrome)
	check(face_label.contains("z 0"), "face label contains z 0 (%s)" % face_label)
	check(ex_btn != null and not ex_btn.disabled, "Extrude enables after the face click")

	await _pick_option(ctx, _finish_op(chrome), 1, "Cut after face")
	check(chrome.get_finish_end() == "to_face",
			"choosing Cut after the face is set leaves End on Up To Surface")
	check(str(chrome.up_to_face_id) == bottom, "Cut after the face keeps the face id")

	await _click_extrude(ctx)
	await process_frame
	await process_frame
	check(not sm.active, "through-hole Extrude left the sketch")
	var mesh := _load_mesh(ctx.view.doc, body)
	var hole := Vector3(20, 15, 0)
	check(not _inside(mesh, hole + Vector3(0, 0, 0.5)),
			"circle centre is outside the solid at z=0.5")
	check(not _inside(mesh, hole + Vector3(0, 0, 9.5)),
			"circle centre is outside the solid at z=9.5")
	check(_inside(mesh, Vector3(5, 5, 5)), "solid still has material away from the hole")

	print("- no face click does not create a cut")
	top = _face_along(ctx, body, 1)
	await _sketch_on_top(ctx, body, top, float(ctx.view.doc.measure_bbox(body)["max"].z))
	sm = ctx.main.sketch_mode
	chrome = ctx.main.sketch_chrome
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _zoom_uv(ctx, Vector2(8, 8), 80.0)
	await _click_uv(ctx, Vector2(8, 8), "Uncut circle centre")
	await _click_uv(ctx, Vector2(11, 8), "Uncut circle radius")
	await _pick_option(ctx, _finish_op(chrome), 1, "Cut no-face")
	await _pick_option(ctx, _finish_end(chrome), 0, "Blind before Up To Surface")
	await _pick_option(ctx, _finish_end(chrome), 3, "Up To Surface no-face")
	ex_btn = chrome.extrude_button()
	check(str(chrome.up_to_face_id).strip_edges() == "", "no-face run starts with empty id")
	check(ex_btn != null and ex_btn.disabled, "Extrude stays disabled with no face")
	var n_ex1 := _count_extrudes(ctx)
	await _click_extrude(ctx)
	await process_frame
	await process_frame
	check(sm.active, "no-face Extrude leaves the sketch open")
	check(_count_extrudes(ctx) == n_ex1, "no-face Extrude does not add a cut")


func _file_new(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await _exit_sketch(ctx)
	var btn := _menu_button(ctx.main, "File")
	check(btn != null and btn.is_visible_in_tree(), "File menu button is visible")
	if btn == null:
		return
	await _click_control(btn)
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	var t0 := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t0 < 450:
		await process_frame
	check(popup != null and popup.visible, "File popup is visible after click")
	if popup == null or not popup.visible:
		return
	var opened: bool = await _click_popup_item(popup, 0, "New")
	check(opened, "File → New item was clicked at its popup rect")
	await process_frame
	await process_frame


func _ground_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		return
	if ctx.view != null:
		ctx.view.select_entity("", "")
	await process_frame
	var b := FilmUI.find_palette_sketch_button(ctx.main)
	check(b != null and b.is_visible_in_tree(), "palette Sketch is visible")
	if b == null:
		return
	await _click_control(b)
	await process_frame
	await process_frame
	if sm != null and sm.active:
		check(true, "sketch session started")
		return
	await _zoom_model(ctx, Vector3(20, 16, 0), 80.0)
	var ground := FilmUI.model_to_screen(ctx, Vector3(20, 16, 0))
	await _click_at(ctx.main.get_viewport(), ground)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "sketch session is open after Sketch + ground click")


func _exit_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return
	var fid: String = await FilmUI.exit_sketch(ctx)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	if sm != null and sm.active:
		check(false, "sketch is closed (Exit Sketch left it active, fid=%s)" % fid)


func _sketch_on_top(ctx: FilmContext, body: String, top: String, z_top: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await _exit_sketch(ctx)
	if top != "":
		ctx.view.select_entity(body, top)
		await process_frame
	ctx.main.interaction._refresh_selection_strip()
	await process_frame
	var sketch_btn: Button = ctx.main.interaction._strip_sketch
	if sketch_btn == null or not sketch_btn.is_visible_in_tree():
		var host := Vector3(20, 15, z_top)
		var picked := FilmUI.face_pick_point(ctx.view, body, top)
		if picked != Vector3.INF:
			host = picked
		await _zoom_model(ctx, host, 90.0)
		var host_screen := FilmUI.model_to_screen(ctx, host)
		if FilmUI.is_on_screen(ctx, host_screen):
			await _click_at(ctx.main.get_viewport(), host_screen)
			await process_frame
		ctx.view.select_entity(body, top)
		ctx.main.interaction._refresh_selection_strip()
		await process_frame
		sketch_btn = ctx.main.interaction._strip_sketch
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(),
			"selection-strip Sketch is visible")
	if sketch_btn != null and sketch_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, sketch_btn, {"keys": "Sketch", "desc": "Sketch on top face"})
		await process_frame
		await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "top-face sketch is active")
	if sm.active:
		check(sm.plane_normal().dot(Vector3(0, 0, 1)) > 0.9,
				"sketch plane normal is +Z (got %s)" % str(sm.plane_normal()))
		check(absf(sm.plane_origin.z - z_top) < 0.5,
				"sketch plane z is the top (got %.3f want %.3f)" % [sm.plane_origin.z, z_top])


func _click_bottom_face(ctx: FilmContext, bottom: String) -> void:
	var cam = ctx.main.camera
	var ix: ViewportInteraction = ctx.main.interaction
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.sketch_orientation_locked = false
	var mid: Vector3 = ctx.view.doc.face_midpoint(bottom)
	cam.pivot = mid
	cam.distance = 180.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.set_view(cam.yaw, deg_to_rad(-75.0), false)
	await process_frame
	await process_frame
	var screen: Vector2 = ix._model_to_screen(mid)
	var ray: Array = ix._model_ray(screen)
	var hit: Dictionary = ctx.view.pick_info(ray[0], ray[1])
	if str(hit.get("face", "")) != bottom:
		cam.set_view(deg_to_rad(180.0), deg_to_rad(-80.0), false)
		await process_frame
		await process_frame
		screen = ix._model_to_screen(mid)
		ray = ix._model_ray(screen)
		hit = ctx.view.pick_info(ray[0], ray[1])
	check(str(hit.get("face", "")) != "",
			"bottom-face ray hits a model face (got %s)" % str(hit.get("face", "")))
	await _click_at(ctx.main.get_viewport(), screen)
	await process_frame


func _type_distance_click_path(ctx: FilmContext, digits: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	check(dist != null, "Distance LineEdit exists for typed %s" % digits)
	if dist == null:
		return
	await _click_control(dist)
	await _click_control(dist)
	await _push_length_keys(ctx, digits)
	await process_frame


func _click_extrude(ctx: FilmContext) -> void:
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	check(btn != null and btn.is_visible_in_tree(), "finish-bar Extrude is visible")
	if btn == null:
		return
	await _click_control(btn)
	await process_frame
	await process_frame


func _pick_option(ctx: FilmContext, opt: OptionButton, index: int, desc: String) -> void:
	check(opt != null and opt.is_visible_in_tree(), "%s option is visible" % desc)
	if opt == null:
		return
	await _click_control(opt)
	await process_frame
	await process_frame
	var popup: PopupMenu = opt.get_popup()
	var t0 := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t0 < 450:
		await process_frame
	check(popup != null and popup.visible, "%s popup is visible" % desc)
	if popup == null or not popup.visible:
		return
	var id := popup.get_item_id(index)
	var clicked: bool = await _click_popup_item(popup, id, desc)
	check(clicked, "%s item %d was clicked at its popup rect" % [desc, index])
	await process_frame


func _click_popup_item(popup: PopupMenu, id: int, desc: String) -> bool:
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "popup has item id %d (%s)" % [id, desc])
		return false
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(idx)
	popup.reset_size()
	await process_frame
	var screen: Vector2 = _item_screen_center(popup, idx)
	var got: Array = [-1]
	var cb := func(pressed_id: int) -> void:
		got[0] = pressed_id
	popup.id_pressed.connect(cb)
	await _click_at(root.get_viewport(), screen)
	await process_frame
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	return got[0] == id


func _item_screen_center(popup: PopupMenu, index: int) -> Vector2:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		y += float(font_h) + float(v_sep)
	y += (float(font_h) + float(v_sep)) * 0.5
	return Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _finish_end(chrome: SketchContextChrome) -> OptionButton:
	return chrome.find_child("FinishEnd", true, false) as OptionButton


func _finish_op(chrome: SketchContextChrome) -> OptionButton:
	return chrome.find_child("FinishOp", true, false) as OptionButton


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	var spin: SpinBox = chrome.find_child("DimSpin", true, false) as SpinBox
	if spin == null:
		return null
	return spin.get_line_edit()


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	var spin: SpinBox = chrome.find_child("DistanceSpin", true, false) as SpinBox
	if spin == null:
		return null
	return spin.get_line_edit()


func _distance_raw(chrome: SketchContextChrome) -> String:
	var edit := _distance_edit(chrome)
	return "" if edit == null else str(edit.text)


func _parse_distance_text(chrome: SketchContextChrome) -> Variant:
	var spin: SpinBox = null if chrome == null else chrome.find_child("DistanceSpin", true, false) as SpinBox
	var edit := _distance_edit(chrome)
	if spin == null or edit == null:
		return null
	var text := str(edit.text).strip_edges()
	var suffix := str(spin.suffix)
	if suffix != "":
		var spaced := " " + suffix
		if text.ends_with(spaced):
			text = text.substr(0, text.length() - spaced.length())
		elif text.ends_with(suffix):
			text = text.substr(0, text.length() - suffix.length())
	text = text.strip_edges().replace(",", ".")
	if not text.is_valid_float():
		return null
	return float(text)


func _readout_text(chrome: SketchContextChrome) -> String:
	if chrome == null:
		return ""
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false) as Label
	return "" if readout == null else str(readout.text)


func _face_label_text(chrome: SketchContextChrome) -> String:
	if chrome == null:
		return ""
	var lab: Label = chrome.find_child("UpToFaceLabel", true, false) as Label
	return "" if lab == null else str(lab.text)


func _release_gui_focus(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null and chrome.has_method("release_dim_focus"):
		chrome.release_dim_focus()
	var vp: Viewport = ctx.main.get_viewport()
	var focus: Control = vp.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	await process_frame


func _push_length_keys(ctx: FilmContext, text: String) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_PERIOD if ch == 46 else ((KEY_0 + (ch - 48)) as Key)
		await _push_key(vp, code, ch)


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
	await _click_at(ctrl.get_viewport(), pos)


func _click_at(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _click_at(ctx.main.get_viewport(), screen)


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom_model(ctx, sm.to_model(uv), size_mm)


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


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var fbb: Dictionary = ctx.view.doc.measure_bbox(f)
		if fbb.is_empty():
			continue
		var fext: Vector3 = fbb["max"] - fbb["min"]
		var span := maxf(fext.x, fext.y)
		if fext.z > 0.5 and fext.z > span * 0.05:
			continue
		var z: float = fbb["max"].z if z_sign > 0 else fbb["min"].z
		var area := fext.x * fext.y
		var better := false
		if z_sign > 0:
			better = z > best_z + 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		else:
			better = z < best_z - 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		if better:
			best_z = z
			best_area = area
			best = f
	return best


func _count_extrudes(ctx: FilmContext) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _load_mesh(doc: SxDocument, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	if mesh == null:
		return [verts, idx]
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if ii.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	return [verts, idx]


func _ray_hits(mesh: Array, origin: Vector3, dir: Vector3) -> Array[float]:
	var verts: PackedVector3Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	var d := dir.normalized()
	var hits: Array[float] = []
	var ntri := idx.size() / 3
	for t in ntri:
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var e1 := b - a
		var e2 := c - a
		var pvec := d.cross(e2)
		var det := e1.dot(pvec)
		if absf(det) < 1e-12:
			continue
		var inv := 1.0 / det
		var s := origin - a
		var u := s.dot(pvec) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := s.cross(e1)
		var v := d.dot(q) * inv
		if v < 0.0 or u + v > 1.0:
			continue
		var dist := e2.dot(q) * inv
		if dist > 1e-6:
			hits.append(dist)
	hits.sort()
	return hits


func _inside(mesh: Array, pt: Vector3) -> bool:
	var votes := 0
	for d in [Vector3(1, 0.0123, 0.0071), Vector3(0.0091, 1, 0.0137), Vector3(0.0113, 0.0067, 1)]:
		if _ray_hits(mesh, pt, d).size() % 2 == 1:
			votes += 1
	return votes >= 2
