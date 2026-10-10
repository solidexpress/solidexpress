# re-PLAN 20 WP4 — contour tags stay 4 px clear of every outline, or sit
# outside the region with a leader.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_tag.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmJaw = preload("res://tests/lib/film_jaw.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const CLEAR_PX := 4.0

var _log: Array[String] = []


func _init() -> void:
	print("rung01 replan20 tag")
	FilmUI.reset_fail_count()
	await _story()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _story() -> void:
	var ctx := await _boot()
	await _disjoint(ctx)
	await _fresh_sketch(ctx)
	await _concentric(ctx)
	await _fresh_sketch(ctx)
	await _with_hole(ctx)
	await _fresh_sketch(ctx)
	await _thin_and_small(ctx)
	await _fresh_sketch(ctx)
	await _chip_status(ctx)


func _boot() -> FilmContext:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	main.sketch_mode.status.connect(func(t: String) -> void: _log.append(t))
	return ctx


func _disjoint(ctx: FilmContext) -> void:
	print("- disjoint r10 + r5")
	await FilmUI.enter_sketch(ctx)
	await _zoom_local(ctx, Vector2(100, 0), 2.857)
	await _draw_circle(ctx, Vector2.ZERO, "10")
	await _draw_circle(ctx, Vector2(200, 0), "5")
	check(_circle_count(ctx) == 2, "P10 scene has two circles (got %d)" % _circle_count(ctx))
	for ppm in [1.4, 2.857, 6.0]:
		await _zoom_local(ctx, Vector2(100, 0), ppm)
		var measured := float(ctx.main.camera.pixels_per_mm_at_pivot())
		check(absf(measured - ppm) / ppm < 0.08,
				"zoom %.3f px/mm (got %.3f)" % [ppm, measured])
		await _assert_every_tag(ctx, "disjoint %.3f" % ppm)


func _concentric(ctx: FilmContext) -> void:
	print("- concentric r5 inside the head")
	# A nested circle is a hole of the head, so a second profile is what
	# makes the contour chips appear.
	await _zoom_local(ctx, Vector2(40, 0), 2.857)
	await _draw_circle(ctx, Vector2.ZERO, "22.5")
	await _draw_circle(ctx, Vector2.ZERO, "5")
	await _draw_circle(ctx, Vector2(80, 0), "6")
	check(_circle_count(ctx) == 3, "head, concentric r5 and a neighbour (got %d)" % _circle_count(ctx))
	var holed := _holed_index(ctx)
	check(holed >= 0, "head region has the r5 hole (idx %d)" % holed)
	await _zoom_local(ctx, Vector2(40, 0), 2.857)
	await _assert_every_tag(ctx, "concentric")
	await _zoom_local(ctx, Vector2(40, 0), 6.0)
	if holed >= 0:
		await _hover_chip(ctx, holed)
		_assert_tag_rule(ctx, holed, "concentric 6px hole")


func _with_hole(ctx: FilmContext) -> void:
	print("- region with a hole")
	await _zoom_local(ctx, Vector2(40, 0), 2.0)
	await _draw_circle(ctx, Vector2.ZERO, "40")
	await _draw_circle(ctx, Vector2(90, 0), "18")
	await _draw_circle(ctx, Vector2(90, 0), "6")
	check(_circle_count(ctx) == 3, "hole scene has three circles (got %d)" % _circle_count(ctx))
	var outlines: Array = ctx.main.sketch_mode.sketch.contour_outlines()
	var holed := 0
	for region in outlines:
		if typeof(region) == TYPE_DICTIONARY and (region.get("holes", []) as Array).size() >= 1:
			holed += 1
	check(holed >= 1, "one region carries a hole (got %d)" % holed)
	await _zoom_local(ctx, Vector2(40, 0), 2.0)
	await _assert_every_tag(ctx, "hole")


func _thin_and_small(ctx: FilmContext) -> void:
	print("- thin rectangle and a region smaller than the tag")
	# Zoom in until the snap magnet is finer than the 2 mm height.
	await _zoom_local(ctx, Vector2(20, 10), 16.0)
	await _draw_rect(ctx, Vector2(0, 0), Vector2(40, 2))
	await _draw_circle(ctx, Vector2(20, 16), "3")
	await _zoom_local(ctx, Vector2(20, 10), 8.0)
	var thin := _region_index_matching(ctx, 40.0, 2.0)
	check(thin >= 0, "thin 2×40 region exists (idx %d)" % thin)
	if thin >= 0:
		await _hover_chip(ctx, thin)
		_assert_outside_leader(ctx, thin, "thin 2×40")
	var other := 1 - thin if thin == 0 or thin == 1 else 0
	if _chips(ctx).size() >= 2:
		await _hover_chip(ctx, other)
		_assert_tag_rule(ctx, other, "thin neighbour")
	await _fresh_sketch(ctx)
	await _zoom_local(ctx, Vector2(20, 0), 4.0)
	await _draw_circle(ctx, Vector2.ZERO, "1")
	await _draw_circle(ctx, Vector2(40, 0), "12")
	await _zoom_local(ctx, Vector2(20, 0), 4.0)
	var small := _region_index_near(ctx, Vector2.ZERO)
	check(small >= 0, "r1 region exists (idx %d)" % small)
	if small >= 0:
		await _hover_chip(ctx, small)
		_assert_outside_leader(ctx, small, "smaller than the tag")


func _chip_status(ctx: FilmContext) -> void:
	print("- chip hover and include / skip")
	await _zoom_local(ctx, Vector2(30, 0), 2.857)
	await _draw_circle(ctx, Vector2.ZERO, "16")
	await _draw_circle(ctx, Vector2(60, 0), "8")
	await _zoom_local(ctx, Vector2(30, 0), 2.857)
	var chips := _chips(ctx)
	check(chips.size() == 2, "two contour chips (got %d)" % chips.size())
	if chips.size() < 2:
		return
	_motion(ctx, Vector2(640, 400))
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var idle := _line_segments(sm)
	await _hover_chip(ctx, 1)
	var tag := sm.get("_contour_tag") as Label3D
	check(tag != null and tag.visible and str(tag.text) == "2",
			"hover chip 2 shows tag 2 (got '%s')" % (str(tag.text) if tag != null else ""))
	if tag != null and tag.visible:
		var rect := _tag_rect(ctx, tag)
		var canvas: Rect2 = ctx.main.camera.sketch_fit_canvas_rect()
		var inset := canvas.grow(-CLEAR_PX)
		check(inset.encloses(rect),
				"tag 2 is ≥ 4 px inside the canvas %s vs %s" % [rect, canvas])
	var hot := _line_segments(sm)
	check(hot >= idle + 2, "double outline is drawn (idle %d hot %d)" % [idle, hot])
	_log.clear()
	FilmJaw.push_click(ctx.main.get_viewport(), chips[0].get_global_rect().get_center())
	await process_frame
	await process_frame
	var skipped := sm.contour_label(0) + " — skipped"
	check(_saw(skipped) or str(ctx.main.status_label.text) == skipped,
			"chip 1 skips (`%s`, got '%s')" % [skipped, ctx.main.status_label.text])
	_log.clear()
	FilmJaw.push_click(ctx.main.get_viewport(), chips[0].get_global_rect().get_center())
	await process_frame
	await process_frame
	var included := sm.contour_label(0) + " — included"
	check(_saw(included) or str(ctx.main.status_label.text) == included,
			"chip 1 includes (`%s`, got '%s')" % [included, ctx.main.status_label.text])


func _assert_every_tag(ctx: FilmContext, label: String) -> void:
	var chips := _chips(ctx)
	check(chips.size() >= 2, "%s has ≥ 2 chips (got %d)" % [label, chips.size()])
	var n := mini(chips.size(), 2)
	for i in n:
		await _hover_chip(ctx, i)
		_assert_tag_rule(ctx, i, "%s region %d" % [label, i + 1])


func _assert_tag_rule(ctx: FilmContext, index: int, label: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var tag := sm.get("_contour_tag") as Label3D
	var showing := tag != null and tag.visible and str(tag.text) == str(index + 1)
	check(showing, "%s tag %d is showing (got '%s')" % [label, index + 1, str(tag.text) if tag != null else ""])
	if not showing:
		check(false, "%s clearance ≥ 4 px")
		check(false, "%s inside, or outside with a leader")
		return
	var rect := _tag_rect(ctx, tag)
	var clear := _all_outline_clearance(ctx, rect)
	check(clear + 0.01 >= CLEAR_PX, "%s clearance %.2f px ≥ 4" % [label, clear])
	var outside := _tag_outside_region(ctx, index, tag)
	var leader := bool(tag.get_meta("leader", false))
	var legal := (not outside and not leader) or (outside and leader)
	check(legal, "%s %s leader=%s" % [label, "outside" if outside else "inside", leader])


func _assert_outside_leader(ctx: FilmContext, index: int, label: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var tag := sm.get("_contour_tag") as Label3D
	var showing := tag != null and tag.visible
	check(showing, "%s tag is showing" % label)
	if not showing:
		check(false, "%s is outside")
		check(false, "%s leader is drawn")
		check(false, "%s clearance ≥ 4 px")
		return
	var outside := _tag_outside_region(ctx, index, tag)
	var leader := bool(tag.get_meta("leader", false))
	var clear := _all_outline_clearance(ctx, _tag_rect(ctx, tag))
	check(outside, "%s tag sits outside the region" % label)
	check(leader, "%s leader == true" % label)
	check(clear + 0.01 >= CLEAR_PX, "%s clearance %.2f px ≥ 4" % [label, clear])


func _tag_outside_region(ctx: FilmContext, index: int, tag: Label3D) -> bool:
	var outlines: Array = ctx.main.sketch_mode.sketch.contour_outlines()
	if index < 0 or index >= outlines.size():
		return true
	var region: Dictionary = outlines[index]
	var outer: PackedVector2Array = region.get("outer", PackedVector2Array())
	var uv := _uv_of_tag(ctx.main.sketch_mode, tag)
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(uv, outer):
		return true
	for hole in region.get("holes", []):
		var loop: PackedVector2Array = hole
		if loop.size() >= 3 and Geometry2D.is_point_in_polygon(uv, loop):
			return true
	return false


func _all_outline_clearance(ctx: FilmContext, rect: Rect2) -> float:
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: Camera3D = ctx.main.camera
	var best := 1e9
	for region in sm.sketch.contour_outlines():
		if typeof(region) != TYPE_DICTIONARY:
			continue
		best = minf(best, _loop_clearance(sm, cam, region.get("outer", PackedVector2Array()), rect))
		for hole in region.get("holes", []):
			best = minf(best, _loop_clearance(sm, cam, hole, rect))
	return best


func _loop_clearance(sm: SketchMode, cam: Camera3D, loop: PackedVector2Array, rect: Rect2) -> float:
	if loop.size() < 2:
		return 1e9
	var best := 1e9
	for j in loop.size():
		var a := cam.unproject_position(sm.to_global(sm._to3(loop[j])))
		var b := cam.unproject_position(sm.to_global(sm._to3(loop[(j + 1) % loop.size()])))
		best = minf(best, _seg_rect(a, b, rect))
	return best


func _tag_rect(ctx: FilmContext, tag: Label3D) -> Rect2:
	var cam: Camera3D = ctx.main.camera
	var sp := cam.unproject_position(tag.global_position)
	var font: Font = ThemeDB.fallback_font
	var font_px := Vector2(
			font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size).x,
			font.get_height(tag.font_size))
	var h := cam.get_viewport().get_visible_rect().size.y
	var k := tag.pixel_size * h * 0.5
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		k /= tan(deg_to_rad(cam.fov) * 0.5)
	var size := font_px * k
	return Rect2(sp - size * 0.5, size)


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
		best = minf(best, _point_segment(c, a, b))
	return best


func _point_rect(p: Vector2, rect: Rect2) -> float:
	var c := Vector2(
			clampf(p.x, rect.position.x, rect.end.x),
			clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(c)


func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _holed_index(ctx: FilmContext) -> int:
	var outlines: Array = ctx.main.sketch_mode.sketch.contour_outlines()
	for i in outlines.size():
		var region: Dictionary = outlines[i]
		if (region.get("holes", []) as Array).size() >= 1:
			return i
	return -1


func _line_segments(sm: SketchMode) -> int:
	var node := sm.get("_contour_node") as MeshInstance3D
	if node == null or node.mesh == null:
		return 0
	var mesh := node.mesh as ArrayMesh
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_LINES:
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		n += verts.size() / 2
	return n


func _region_index_matching(ctx: FilmContext, w: float, h: float) -> int:
	var outlines: Array = ctx.main.sketch_mode.sketch.contour_outlines()
	for i in outlines.size():
		var region: Dictionary = outlines[i]
		var sz: Vector2 = region.get("size", Vector2.ZERO)
		if absf(sz.x - w) < 1.0 and absf(sz.y - h) < 1.0:
			return i
		if absf(sz.x - h) < 1.0 and absf(sz.y - w) < 1.0:
			return i
	return -1


func _region_index_near(ctx: FilmContext, uv: Vector2) -> int:
	var outlines: Array = ctx.main.sketch_mode.sketch.contour_outlines()
	var best := -1
	var best_d := 1e9
	for i in outlines.size():
		var region: Dictionary = outlines[i]
		var c: Vector2 = region.get("center", Vector2.ZERO)
		var d := c.distance_to(uv)
		if d < best_d:
			best_d = d
			best = i
	return best


func _chips(ctx: FilmContext) -> Array[CheckButton]:
	var out: Array[CheckButton] = []
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null or chrome._contour_bar == null or not chrome._contour_bar.visible:
		return out
	for child in chrome._contour_bar.get_children():
		if child is CheckButton:
			out.append(child)
	return out


func _hover_chip(ctx: FilmContext, index: int) -> void:
	var chips := _chips(ctx)
	if index < 0 or index >= chips.size():
		check(false, "chip %d exists" % (index + 1))
		return
	_motion(ctx, chips[index].get_global_rect().get_center())
	await process_frame
	await process_frame
	await process_frame


func _draw_circle(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, center, "circle centre")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var hover := center + Vector2(6, 0)
	if sm._tool_points.size() >= 1:
		hover = sm._tool_points[0] + Vector2(6, 0)
	_motion(ctx, FilmUI.sketch_uv_to_screen(ctx, hover))
	await process_frame
	var edit: LineEdit = ctx.main.sketch_chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null:
		check(false, "DimLineEdit for r%s" % radius_text)
		return
	FilmJaw.push_click(ctx.main.get_viewport(), edit.get_global_rect().get_center())
	await process_frame
	await _type_chars(ctx.main.get_viewport(), radius_text)
	await _key(ctx, KEY_ENTER)
	await process_frame
	await process_frame


func _draw_rect(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.RECT)
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, a, "rect corner")
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, b, "rect opposite")
	await process_frame
	await process_frame


func _fresh_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		sm.cancel()
		await process_frame
		await process_frame
	await _click_menu(ctx, "File", 0)
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		if ok != null:
			await FilmUI.click_control(ctx, ok, FilmUICues.alert("Click", "New"))
		await process_frame
	await FilmUI.enter_sketch(ctx)


func _zoom_local(ctx: FilmContext, uv: Vector2, ppm: float) -> void:
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var model_pivot: Vector3 = sm.to_model(uv) if sm != null else Vector3(uv.x, uv.y, 0)
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var size_mm := 800.0 / ppm
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _circle_count(ctx: FilmContext) -> int:
	var n := 0
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			n += 1
	return n


func _click_menu(ctx: FilmContext, title: String, id: int) -> void:
	var btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		var mb := c as MenuButton
		if mb != null and str(mb.text).begins_with(title):
			btn = mb
			break
	if btn == null:
		check(false, "%s menu is visible" % title)
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Click", title))
	btn.show_popup()
	await process_frame
	await process_frame
	var popup := btn.get_popup()
	if popup == null or not popup.visible:
		return
	var idx := popup.get_item_index(id)
	if idx < 0:
		idx = 0
	FilmJaw.push_click(ctx.main.get_viewport(), _popup_item_pos(popup, idx))
	await process_frame


func _popup_item_pos(popup: PopupMenu, index: int) -> Vector2:
	popup.reset_size()
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h := fs
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
		y += float(font_h + v_sep)
	y += float(font_h + v_sep) * 0.5
	return Vector2(popup.position) + Vector2(popup.size.x * 0.5, y)


func _type_chars(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		await _key_vp(vp, code, ch)


func _key(ctx: FilmContext, code: Key) -> void:
	await _key_vp(ctx.main.get_viewport(), code, 0)


func _key_vp(vp: Viewport, code: Key, unicode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.unicode = unicode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	vp.push_input(up)
	await process_frame


func _motion(ctx: FilmContext, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	ctx.main.get_viewport().push_input(motion)


func _saw(needle: String) -> bool:
	for s in _log:
		if s.contains(needle):
			return true
	return false
