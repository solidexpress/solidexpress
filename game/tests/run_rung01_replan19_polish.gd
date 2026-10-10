# re-PLAN 19 WP9 — rail labels, polygon centre status, contour tag, hover tint,
# popup traces.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_polish.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const POLYGON_CENTRE := "Polygon — centre set, click a vertex or type the size"


func _init() -> void:
	print("rung01 replan19 polish")
	FilmUI.reset_fail_count()
	await _case_rail()
	await _case_contours()
	await _case_hover_and_popup()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case_rail() -> void:
	print("- rail labels, undo highlight, polygon centre")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var rail: Control = ctx.main.sketch_toolbar
	var width_before := rail.get_global_rect().size.x
	var snap := rail.find_child("SnapToggle", true, false) as CheckBox
	var infer := rail.find_child("InferToggle", true, false) as CheckBox
	check(snap != null and snap.text == "Snap", "Snap checkbox reads Snap")
	check(infer != null and infer.text == "Infer", "Infer checkbox reads Infer")
	await _frames(2)
	var width_after := rail.get_global_rect().size.x
	check(absf(width_after - width_before) <= 1.0,
			"rail width unchanged (%.1f -> %.1f)" % [width_before, width_after])
	check(absf(width_after - 125.0) <= 1.0, "rail width stays 125 (got %.1f)" % width_after)
	var window := Rect2(Vector2.ZERO, Vector2(ROOT_SIZE))
	var labels: Array[String] = []
	var rows := rail.find_child("SketchRailRows", true, false) as VBoxContainer
	check(rows != null, "sketch rail rows exist")
	if rows != null:
		for child in rows.get_children():
			if child is CheckBox or child is OptionButton:
				continue
			var btn := child as Button
			if btn == null or str(btn.text) == "":
				continue
			labels.append(str(btn.text))
			var rect := btn.get_global_rect()
			check(window.encloses(rect),
					"rail label `%s` is fully inside 1280×800 %s" % [btn.text, rect])
	check(labels.size() == 19, "19 rail labels (got %d: %s)" % [labels.size(), str(labels)])

	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, Vector2(0, 0), "line start")
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, Vector2(20, 0), "line end")
	var drawn := int(ctx.main.sketch_mode.sketch.entity_ids().size())
	check(drawn >= 1, "the line click committed an entity (got %d)" % drawn)
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.CIRCLE)
	ctx.main.get_viewport().gui_release_focus()
	await _frames(1)
	var before_undo := int(ctx.main.sketch_mode.sketch.entity_ids().size())
	_push_key(ctx.main.get_viewport(), KEY_Z, true, false)
	await _frames(3)
	var lit := _lit_tools(rows)
	check(lit.size() == 1, "exactly one rail button lit after Ctrl+Z (got %s)" % str(lit))
	check(lit.size() == 1 and lit[0] == "Circle",
			"the lit button after undo is Circle (got %s)" % str(lit))
	check(ctx.main.sketch_mode.tool == SketchMode.Tool.CIRCLE, "active tool stays Circle")
	check(ctx.main.sketch_mode.sketch.entity_ids().size() < before_undo, "Ctrl+Z removed the line")
	_push_key(ctx.main.get_viewport(), KEY_Z, true, true)
	await _frames(3)
	var lit_redo := _lit_tools(rows)
	check(lit_redo.size() == 1, "exactly one rail button lit after Ctrl+Shift+Z (got %s)" % str(lit_redo))
	check(lit_redo.size() == 1 and lit_redo[0] == "Circle",
			"the lit button after redo is Circle (got %s)" % str(lit_redo))

	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.POLYGON)
	var spin := ctx.main.sketch_chrome.find_child("DimSpin", true, false) as SpinBox
	var edit: LineEdit = spin.get_line_edit() if spin != null else null
	check(spin != null and str(spin.suffix) == " AF",
			"AF blank suffix is ' AF' (got '%s')" % (str(spin.suffix) if spin != null else ""))
	check(edit != null and not edit.text.is_valid_float(),
			"AF blank has no number (got '%s')" % (edit.text if edit != null else ""))
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, Vector2(0, 0), "polygon centre")
	await _frames(2)
	check(str(ctx.main.status_label.text) == POLYGON_CENTRE,
			"polygon centre status (got '%s')" % str(ctx.main.status_label.text))
	var centre_screen: Vector2 = FilmUI.sketch_uv_to_screen(ctx, Vector2(0, 0))
	var hover_screen: Vector2 = FilmUI.sketch_uv_to_screen(ctx, Vector2(12, 5))
	_motion(ctx.main.get_viewport(), hover_screen)
	await _frames(2)
	var hover_status := str(ctx.main.status_label.text)
	check(hover_status.begins_with("Polygon AF ") and hover_status.contains(
			" — flats horizontal — click to place (or type the size)"),
			"polygon hover status (got '%s')" % hover_status)
	check(hover_status != POLYGON_CENTRE, "hover replaced the centre sentence")
	# Pointer back on the centre: no size yet, the blank form keeps " AF".
	_motion(ctx.main.get_viewport(), centre_screen)
	await _frames(2)
	check(str(ctx.main.status_label.text) == POLYGON_CENTRE
			or str(ctx.main.status_label.text).contains(" AF"),
			"AF blank still names AF (got '%s')" % str(ctx.main.status_label.text))
	await _shutdown(ctx)


func _case_contours() -> void:
	print("- contour tag clear of the hole")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_circle(0, 0, 40)
	sm.sketch.add_circle(90, 0, 18)
	sm.sketch.add_circle(90, 0, 6)
	sm._redraw()
	await _frames(3)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var chips: Array[CheckButton] = []
	if chrome._contour_bar != null:
		for child in chrome._contour_bar.get_children():
			if child is CheckButton:
				chips.append(child)
	check(chips.size() == 2, "two contour chips (got %d)" % chips.size())
	var outlines: Array = sm.sketch.contour_outlines()
	check(outlines.size() == 2, "two contour outlines (got %d)" % outlines.size())
	if chips.size() < 2 or outlines.size() < 2:
		await _shutdown(ctx)
		return
	var holes: Array = outlines[1].get("holes", [])
	check(holes.size() >= 1, "region 2 has a hole (got %d)" % holes.size())
	_motion(ctx.main.get_viewport(), chips[1].get_global_rect().get_center())
	await _frames(3)
	var tag := sm.get("_contour_tag") as Label3D
	check(tag != null and tag.visible and tag.text == "2",
			"tag 2 is showing (got '%s')" % (tag.text if tag != null else ""))
	if tag != null and holes.size() >= 1:
		var rect := _tag_screen_rect(ctx.main.camera, tag)
		var clear := _hole_clearance(sm, ctx.main.camera, holes, rect)
		check(clear >= 4.0, "tag 2 is %.1f px clear of the hole outline" % clear)
		var centre: Vector2 = outlines[1]["center"]
		var local := _uv_of_tag(sm, tag)
		check(local.distance_to(centre) > 1.0,
				"tag 2 is off the hole centre (%.1f mm)" % local.distance_to(centre))
	await _shutdown(ctx)


func _case_hover_and_popup() -> void:
	print("- hover tint and popup trace")
	var ctx := await _boot()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 24, 12))
	await _frames(2)
	_push_key(ctx.main.get_viewport(), KEY_F, false, false)
	await _frames(2)
	var on_part := _face_screen_point(ctx)
	var menu := ctx.main.find_child("FileMenu", true, false) as Control
	check(menu != null, "File menu bar exists")
	var menu_at := menu.get_global_rect().get_center() if menu != null else Vector2(40, 16)
	var status_bar := ctx.main.find_child("StatusBar", true, false) as Control
	var panel_at := status_bar.get_global_rect().get_center() if status_bar != null else Vector2(640, 790)
	var ground := _miss_screen_point(ctx)
	await _hover_cycle(ctx, body, on_part, menu_at, panel_at, ground, false)
	ctx.view.select_entity(body, "")
	await _frames(2)
	await _hover_cycle(ctx, body, on_part, menu_at, panel_at, ground, true)

	OS.set_environment("SX_INPUT_TRACE", "1")
	ctx.main.popup_trace_log = PackedStringArray()
	var file_btn := _menu_button(ctx.main, "File")
	check(file_btn != null, "File menu button exists")
	if file_btn != null:
		await FilmUI.click_control(ctx, file_btn, {"what": "File menu"})
		await _frames(2)
		if ctx.main.popup_trace_log.is_empty():
			file_btn.show_popup()
		await _frames(2)
	var showed := false
	var hid := false
	for line in ctx.main.popup_trace_log:
		if str(line).begins_with("[popup-trace] t=") and str(line).contains(" show ") \
				and str(line).ends_with(" File"):
			showed = true
		if str(line).begins_with("[popup-trace] t=") and str(line).contains(" hide ") \
				and str(line).ends_with(" File"):
			hid = true
	check(showed, "popup-trace show File (got %s)" % str(ctx.main.popup_trace_log))
	_push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await _frames(3)
	for line in ctx.main.popup_trace_log:
		if str(line).begins_with("[popup-trace] t=") and str(line).contains(" hide ") \
				and str(line).ends_with(" File"):
			hid = true
	check(hid, "popup-trace hide File (got %s)" % str(ctx.main.popup_trace_log))
	OS.set_environment("SX_INPUT_TRACE", "0")
	await _shutdown(ctx)


func _hover_cycle(ctx: FilmContext, body: String, on_part: Vector2, menu_at: Vector2,
		panel_at: Vector2, ground: Vector2, selected: bool) -> void:
	var label := "selected" if selected else "nothing selected"
	_motion(ctx.main.get_viewport(), on_part)
	await _frames(2)
	check(ctx.view.hovered_face != "", "%s: pointer on the part tints a face" % label)
	check(_hover_material_state(ctx.view, body, true),
			"%s: face material is the hover tint" % label)
	for dest in [["menu", menu_at], ["panel", panel_at], ["ground", ground]]:
		_motion(ctx.main.get_viewport(), dest[1])
		await _frames(2)
		check(ctx.view.hovered_face == "",
				"%s: %s clears hovered_face" % [label, dest[0]])
		check(_hover_material_state(ctx.view, body, false),
				"%s: %s restores the untinted material" % [label, dest[0]])
		_motion(ctx.main.get_viewport(), on_part)
		await _frames(2)


func _face_screen_point(ctx: FilmContext) -> Vector2:
	var ix: ViewportInteraction = ctx.main.interaction
	var y := 120
	while y < 700:
		var x := 220
		while x < 1100:
			var pos := Vector2(x, y)
			if not ix._pointer_off_model(pos):
				var ray: Array = ix._model_ray(pos)
				var hit: Dictionary = ctx.view.pick_info(ray[0], ray[1])
				if not hit.is_empty() and str(hit.get("face", "")) != "":
					return pos
			x += 30
		y += 30
	return Vector2(640, 400)


func _miss_screen_point(ctx: FilmContext) -> Vector2:
	var ix: ViewportInteraction = ctx.main.interaction
	var y := 100
	while y < 720:
		var x := 200
		while x < 1200:
			var pos := Vector2(float(x), float(y))
			if not ix._pointer_off_model(pos):
				var ray: Array = ix._model_ray(pos)
				var hit: Dictionary = ctx.view.pick_info(ray[0], ray[1])
				if hit.is_empty():
					return pos
			x += 40
		y += 40
	return Vector2(1180, 200)


func _hover_material_state(view: DocumentView, body: String, want_hover: bool) -> bool:
	var hover_mat: Material = view.get("_hover_face_material")
	var nodes: Dictionary = view.get("_body_nodes")
	var node := nodes.get(body) as MeshInstance3D
	if node == null or node.mesh == null:
		return false
	var faces_map: Dictionary = view.get("_face_ids")
	var faces: PackedStringArray = faces_map.get(body, PackedStringArray())
	if want_hover:
		for i in faces.size():
			if str(faces[i]) == view.hovered_face:
				return node.get_surface_override_material(i) == hover_mat
		return false
	for i in node.mesh.get_surface_count():
		if node.get_surface_override_material(i) == hover_mat:
			return false
	return true


func _lit_tools(rows: VBoxContainer) -> Array[String]:
	var lit: Array[String] = []
	if rows == null:
		return lit
	for child in rows.get_children():
		var btn := child as Button
		if btn != null and btn.toggle_mode and not (btn is CheckBox) and btn.button_pressed:
			lit.append(str(btn.text))
	return lit


func _tag_screen_rect(cam: Camera3D, tag: Label3D) -> Rect2:
	var sp: Vector2 = cam.unproject_position(tag.global_position)
	var font: Font = ThemeDB.fallback_font
	var font_px := Vector2(font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size).x,
			font.get_height(tag.font_size))
	var h := cam.get_viewport().get_visible_rect().size.y
	var k := tag.pixel_size * h * 0.5
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		k /= tan(deg_to_rad(cam.fov) * 0.5)
	var size := font_px * k
	return Rect2(sp - size * 0.5, size)


func _hole_clearance(sm: SketchMode, cam: Camera3D, holes: Array, rect: Rect2) -> float:
	var best := 1e9
	for hole in holes:
		var loop: PackedVector2Array = hole
		if loop.size() < 2:
			continue
		for j in loop.size():
			var a := cam.unproject_position(sm.to_global(sm._to3(loop[j])))
			var b := cam.unproject_position(sm.to_global(sm._to3(loop[(j + 1) % loop.size()])))
			best = minf(best, _seg_rect(a, b, rect))
	return best


func _uv_of_tag(sm: SketchMode, tag: Label3D) -> Vector2:
	var p: Vector3 = tag.position
	return Vector2(p.dot(sm.plane_x), p.dot(sm.plane_y))


func _seg_rect(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for i in corners.size():
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % corners.size()]) != null:
			return 0.0
	var best := _point_rect(a, rect)
	best = minf(best, _point_rect(b, rect))
	for c in corners:
		var ab := b - a
		var t := 0.0 if ab.length_squared() < 1e-12 else clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, c.distance_to(a + ab * t))
	return best


func _point_rect(p: Vector2, rect: Rect2) -> float:
	var c := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(c)


func _menu_button(main: Node, text: String) -> MenuButton:
	for node in main.find_children("*", "MenuButton", true, false):
		var btn := node as MenuButton
		if btn != null and btn.text == text:
			return btn
	return null


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


func _push_key(vp: Viewport, code: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = code
	down.physical_keycode = code
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = code
	up.physical_keycode = code
	up.ctrl_pressed = ctrl
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
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	await _frames(2)
	if ctx.main != null:
		ctx.main.queue_free()
	await process_frame
