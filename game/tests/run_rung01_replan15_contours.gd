# Rung 1 replan 15 WP2 — Contours chips highlight their region and name it.
# Real pointer events on the Contours chips. Setup may use the sketch API.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan15_contours.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan15 WP2 contour highlight")
	FilmUI.reset_fail_count()
	await _rows_a_and_c2()
	await _rows_b()
	await _row_c1()
	await _row_d1()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _rows_a_and_c2() -> void:
	print("-- A rect + circle, chips highlight the region")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.sketch.add_circle(80, 10, 6)
	sm._redraw()
	await process_frame
	await process_frame
	var chips := _chips(chrome)
	check(chrome._contour_bar.visible and chips.size() == 2, "A1 bar visible with 2 chips (n=%d vis=%s)" % [
			chips.size(), chrome._contour_bar.visible])
	check(chips.size() == 2 and chips[0].button_pressed and chips[1].button_pressed,
			"A1 both chips on after refresh")
	var has_outlines: bool = sm.sketch.has_method("contour_outlines")
	check(has_outlines, "A1 sketch.has_method(contour_outlines)")
	var outlines: Array = sm.sketch.contour_outlines() if has_outlines else []
	check(outlines.size() == 2, "A1 contour_outlines size == 2 (got %d)" % outlines.size())
	if outlines.size() >= 1:
		var sz0: Vector2 = outlines[0]["size"]
		check(absf(sz0.x - 40.0) < 0.1 and absf(sz0.y - 20.0) < 0.1,
				"A1 outline 0 size ≈ (40, 20) (got %s)" % str(sz0))
	var has_state: bool = sm.has_method("contour_highlight_state")
	check(has_state, "A1 contour_highlight_state exists")
	var node: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	check(node != null, "A1 _contour_node present")
	if has_state:
		var st: Dictionary = sm.contour_highlight_state()
		check(int(st.get("count", -1)) == 2, "A1 highlight count == 2 (got %s)" % str(st.get("count")))
		var fills: Array = st.get("fills", [])
		check(fills.size() >= 2 and float(fills[0]) > 0.0 and float(fills[1]) > 0.0,
				"A1 both fills > 0 (got %s)" % str(fills))
	else:
		check(false, "A1 highlight count == 2")
		check(false, "A1 both fills > 0")
	if chips.size() < 2:
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	print("-- A2 hover chip 2")
	await _hover_screen(vp, chips[1].get_global_rect().get_center())
	if has_state:
		var st2: Dictionary = sm.contour_highlight_state()
		var fills2: Array = st2.get("fills", [])
		check(int(st2.get("focus", -99)) == 1, "A2 focus == 1 (got %s)" % str(st2.get("focus")))
		check(fills2.size() >= 2 and absf(float(fills2[1]) - 0.70) < 0.02 and absf(float(fills2[0]) - 0.20) < 0.02,
				"A2 fills ≈ 0.20 / 0.70 (got %s)" % str(fills2))
		check(str(st2.get("tag", "")) == "2", "A2 tag == 2 (got %s)" % str(st2.get("tag")))
	else:
		check(false, "A2 focus == 1")
		check(false, "A2 fills")
		check(false, "A2 tag")
	var node2: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	check(node2 != null and node2.mesh != null, "A2 _contour_node.mesh != null")
	var tag := _tag_label(sm)
	var center1 := Vector2.ZERO
	if outlines.size() >= 2:
		center1 = outlines[1]["center"]
	elif has_outlines:
		var again: Array = sm.sketch.contour_outlines()
		if again.size() >= 2:
			center1 = again[1]["center"]
	if tag != null and outlines.size() >= 2:
		var want: Vector3 = sm._to3(center1)
		check(tag.position.distance_to(want) <= 0.01,
				"A2 tag at region 2 centre (got %s want %s)" % [str(tag.position), str(want)])
	else:
		check(false, "A2 tag Label3D at region 2 centre (tag=%s)" % str(tag))
	print("-- A3 move off the chip")
	await _hover_screen(vp, Vector2(640, 500))
	if has_state:
		var st3: Dictionary = sm.contour_highlight_state()
		check(int(st3.get("focus", 99)) == -1, "A3 focus == -1 (got %s)" % str(st3.get("focus")))
		check(str(st3.get("tag", "x")) == "", "A3 no tag (got %s)" % str(st3.get("tag")))
	else:
		check(false, "A3 focus == -1")
		check(false, "A3 no tag")
	print("-- A4 click chip 1 off")
	var ids_before: int = sm.sketch.entity_ids().size()
	_status_log.clear()
	await _x11_click_screen(vp, chips[0].get_global_rect().get_center())
	await process_frame
	check(sm.sketch.entity_ids().size() == ids_before, "A4 sketch entities unchanged")
	check(_same_ints(chrome._selected_contours, [1]),
			"A4 chrome._selected_contours == [1] (got %s)" % str(chrome._selected_contours))
	if has_state:
		var st4: Dictionary = sm.contour_highlight_state()
		var fills4: Array = st4.get("fills", [])
		check(fills4.size() >= 1 and float(fills4[0]) == 0.0, "A4 fills[0] == 0 (got %s)" % str(fills4))
	else:
		check(false, "A4 fills[0] == 0")
	check(_region_has_outline(sm, 0), "A4 outline still drawn for region 0")
	var last := _status_log[_status_log.size() - 1] if not _status_log.is_empty() else ""
	check(last.begins_with("Contour 1 of 2 — 40.0 × 20.0 mm at (20.0, 10.0)") and last.ends_with("— skipped"),
			"A4 status names region 1 skipped (got `%s`)" % last)
	print("-- A5 click chip 1 on")
	_status_log.clear()
	chips = _chips(chrome)
	await _x11_click_screen(vp, chips[0].get_global_rect().get_center())
	await process_frame
	if has_state:
		var st5: Dictionary = sm.contour_highlight_state()
		var fills5: Array = st5.get("fills", [])
		check(fills5.size() >= 1 and float(fills5[0]) > 0.0, "A5 fills[0] > 0 (got %s)" % str(fills5))
	else:
		check(false, "A5 fills[0] > 0")
	var last5 := _status_log[_status_log.size() - 1] if not _status_log.is_empty() else ""
	check(last5.ends_with("— included"), "A5 status ends — included (got `%s`)" % last5)
	print("-- A6 overlay mesh aabb")
	check(_aabb_matches_outlines(sm), "A6 mesh aabb matches outline union within 0.1 mm")
	print("-- A7 region order matches chips")
	var ord: Array = sm.sketch.contour_outlines() if sm.sketch.has_method("contour_outlines") else []
	if ord.size() >= 2:
		check(float(ord[0]["area"]) >= float(ord[1]["area"]),
				"A7 chip 1 is the larger region (%.2f vs %.2f)" % [float(ord[0]["area"]), float(ord[1]["area"])])
	else:
		check(false, "A7 outlines for ordering")
	if sm.has_method("contour_label"):
		var lab: String = sm.contour_label(0)
		check(lab.contains("40.0 × 20.0"), "A7 contour_label(0) shows the larger size (got `%s`)" % lab)
	else:
		check(false, "A7 contour_label exists")
	print("-- C2 Chamfer / Sketch do not recolour the sketch")
	var colors_on := _line_colors(sm)
	var selected_on: Array = sm.selected.duplicate()
	var overlay: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	if overlay != null:
		overlay.mesh = null
	sm._redraw()
	var colors_cleared := _line_colors(sm)
	check(_colors_equal(colors_on, colors_cleared), "C2 entity colours match a cleared overlay")
	if sm.has_method("set_contour_highlight"):
		sm.set_contour_highlight(chrome._selected_contours, -1)
	# Palette Sketch and Modify Chamfer are hidden for the whole sketch session
	# (the Contours bar only exists then). Click them when they are on screen.
	var chamfer := _visible_button(ctx.main, "Chamfer")
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	if chamfer != null and chamfer.is_visible_in_tree():
		await _x11_click_screen(vp, chamfer.get_global_rect().get_center())
		await process_frame
	if sketch_btn != null and sketch_btn.is_visible_in_tree():
		await _x11_click_screen(vp, sketch_btn.get_global_rect().get_center())
		await process_frame
	var rail := _visible_button(ctx.main, "Select")
	if rail != null:
		await _x11_click_screen(vp, rail.get_global_rect().get_center())
		await process_frame
	check(_same_strs(sm.selected, selected_on), "C2 selected unchanged (got %s)" % str(sm.selected))
	check(_colors_equal(colors_on, _line_colors(sm)), "C2 entity line colours unchanged after Chamfer / Sketch")
	await _shutdown(ctx)


func _rows_b() -> void:
	print("-- B hole in the rect, then one region")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.sketch.add_circle(80, 10, 6)
	sm.sketch.add_circle(20, 10, 5)
	sm._redraw()
	await process_frame
	await process_frame
	var chips := _chips(chrome)
	check(chrome._contour_bar.visible and chips.size() == 2, "B1 bar still 2 chips (n=%d)" % chips.size())
	var outlines: Array = sm.sketch.contour_outlines() if sm.sketch.has_method("contour_outlines") else []
	var holes: Array = outlines[0]["holes"] if outlines.size() >= 1 else []
	check(holes.size() == 1, "B1 region 0 holes.size() == 1 (got %d)" % holes.size())
	var tri := _fill_area_in_rect(sm)
	var expect := 800.0 - PI * 25.0
	check(tri > 0.0 and absf(tri - expect) / expect < 0.01,
			"B1 fill area in the rect ≈ 800−25π (got %.3f expect %.3f)" % [tri, expect])
	print("-- B2 delete the outer circle")
	var drop := ""
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle" and absf(float(info.get("radius", 0.0)) - 6.0) < 0.1:
			drop = str(id)
			break
	check(drop != "", "B2 found the outer circle")
	if drop != "":
		sm.sketch.remove_entity(drop)
	sm._redraw()
	await process_frame
	await process_frame
	check(not chrome._contour_bar.visible, "B2 bar hides when one region remains")
	if sm.has_method("contour_highlight_state"):
		var st: Dictionary = sm.contour_highlight_state()
		check(int(st.get("count", -1)) == 0, "B2 highlight count == 0 (got %s)" % str(st.get("count")))
	else:
		check(false, "B2 contour_highlight_state")
	var node: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	check(node == null or node.mesh == null, "B2 _contour_node.mesh == null")
	await _shutdown(ctx)


func _row_c1() -> void:
	print("-- C1 extrude honours the chip that stays on")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.sketch.add_circle(80, 10, 6)
	sm._redraw()
	await process_frame
	await process_frame
	var vp: Viewport = ctx.main.get_viewport()
	var chips := _chips(chrome)
	check(chips.size() == 2, "C1 two chips before extrude")
	if chips.size() >= 1:
		await _x11_click_screen(vp, chips[0].get_global_rect().get_center())
		await process_frame
	check(_same_ints(chrome._selected_contours, [1]),
			"C1 chip 1 off leaves contours [1] (got %s)" % str(chrome._selected_contours))
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	check(dist != null, "C1 DistanceSpin exists")
	if dist != null:
		var edit := dist.get_line_edit()
		await _x11_click_screen(vp, edit.get_global_rect().get_center())
		await process_frame
		await process_frame
		await _push_key(vp, KEY_1, 49)
		await _push_key(vp, KEY_0, 48)
		await process_frame
		check(edit.text.contains("10"), "C1 Distance field reads 10 (got `%s`)" % edit.text)
	var ex := chrome.extrude_button()
	check(ex != null and ex.is_visible_in_tree(), "C1 Extrude button visible")
	if ex != null:
		await _x11_click_screen(vp, ex.get_global_rect().get_center())
		await process_frame
		await process_frame
		await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(ids.size() == 1, "C1 one new body (n=%d)" % ids.size())
	if ids.size() == 1:
		var bb: Dictionary = ctx.view.doc.measure_bbox(ids[0])
		var sz: Vector3 = bb["max"] - bb["min"]
		var cxy := Vector2((bb["min"].x + bb["max"].x) * 0.5, (bb["min"].y + bb["max"].y) * 0.5)
		check(absf(sz.x - 12.0) < 0.4 and absf(sz.y - 12.0) < 0.4 and absf(sz.z - 10.0) < 0.4,
				"C1 body bbox ≈ 12 × 12 × 10 (got %s)" % str(sz))
		check(cxy.distance_to(Vector2(80, 10)) < 0.5, "C1 body is region 2 (centre %s)" % str(cxy))
	check(not sm.active, "C1 sketch session closed")
	var node: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	check(node == null or node.mesh == null, "C1 show_for_session(false) left the overlay mesh null")
	await _shutdown(ctx)


func _row_d1() -> void:
	print("-- D1 circle split by a chord, chips pick different halves")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	sm.sketch.add_circle(0, 0, 10)
	sm.sketch.add_line(-10, 0, 10, 0)
	sm._redraw()
	await process_frame
	await process_frame
	var chips := _chips(chrome)
	check(chips.size() == 2, "D1 two chips for the chorded circle (n=%d)" % chips.size())
	var vp: Viewport = ctx.main.get_viewport()
	var c0 := Vector3.ZERO
	var c1 := Vector3.ZERO
	if chips.size() >= 2 and sm.has_method("contour_highlight_state"):
		await _hover_screen(vp, chips[0].get_global_rect().get_center())
		var t0 := _tag_label(sm)
		if t0 != null:
			c0 = t0.position
		await _hover_screen(vp, chips[1].get_global_rect().get_center())
		var t1 := _tag_label(sm)
		if t1 != null:
			c1 = t1.position
		check(c0.distance_to(c1) > 8.0, "D1 chip centres differ by > 8 mm (%.2f)" % c0.distance_to(c1))
	else:
		check(false, "D1 hover both halves")
	await _shutdown(ctx)


func _chips(chrome: SketchContextChrome) -> Array:
	var out: Array = []
	if chrome == null or chrome._contour_bar == null:
		return out
	for c in chrome._contour_bar.get_children():
		if c is CheckButton:
			out.append(c)
	return out


func _tag_label(sm: SketchMode) -> Label3D:
	var host: Node = sm.get("_contour_tags") as Node
	if host == null:
		return null
	for c in host.get_children():
		if c is Label3D and (c as Label3D).visible:
			return c as Label3D
	return null


func _region_has_outline(sm: SketchMode, _index: int) -> bool:
	var node: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	if node == null or node.mesh == null:
		return false
	var mesh: Mesh = node.mesh
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_LINES:
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		for p in verts:
			var uv := Vector2(p.dot(sm.plane_x), p.dot(sm.plane_y))
			if uv.x >= -0.5 and uv.x <= 40.5 and uv.y >= -0.5 and uv.y <= 20.5:
				return true
	return false


func _aabb_matches_outlines(sm: SketchMode) -> bool:
	if not sm.sketch.has_method("contour_outlines"):
		return false
	var node: MeshInstance3D = sm.get("_contour_node") as MeshInstance3D
	if node == null or node.mesh == null:
		return false
	var bb: AABB = node.mesh.get_aabb()
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for region in sm.sketch.contour_outlines():
		var loops: Array = [region["outer"]]
		for h in region["holes"]:
			loops.append(h)
		for loop in loops:
			for p in loop:
				var q: Vector3 = sm._to3(p)
				mn = mn.min(q)
				mx = mx.max(q)
	var bmin := bb.position
	var bmax := bb.position + bb.size
	return _aabb_close(bmin, bmax, mn, mx)


func _aabb_close(bmin: Vector3, bmax: Vector3, mn: Vector3, mx: Vector3) -> bool:
	return absf(bmin.x - mn.x) <= 0.1 and absf(bmin.y - mn.y) <= 0.1 and absf(bmin.z - mn.z) <= 0.1 \
			and absf(bmax.x - mx.x) <= 0.1 and absf(bmax.y - mx.y) <= 0.1 and absf(bmax.z - mx.z) <= 0.1


func _fill_area_in_rect(sm: SketchMode) -> float:
	if sm.get("_contour_node") == null or sm._contour_node.mesh == null:
		return 0.0
	var mesh: Mesh = sm._contour_node.mesh
	var area := 0.0
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size(), 3):
			var a := Vector2(verts[i].dot(sm.plane_x), verts[i].dot(sm.plane_y))
			var b := Vector2(verts[i + 1].dot(sm.plane_x), verts[i + 1].dot(sm.plane_y))
			var c := Vector2(verts[i + 2].dot(sm.plane_x), verts[i + 2].dot(sm.plane_y))
			var mid := (a + b + c) / 3.0
			if mid.x < -0.1 or mid.x > 40.1 or mid.y < -0.1 or mid.y > 20.1:
				continue
			area += absf((b - a).cross(c - a)) * 0.5
	return area


func _line_colors(sm: SketchMode) -> PackedColorArray:
	if sm._draw_node == null or sm._draw_node.mesh == null:
		return PackedColorArray()
	var mesh: Mesh = sm._draw_node.mesh
	if mesh.get_surface_count() < 1:
		return PackedColorArray()
	var arrays: Array = mesh.surface_get_arrays(0)
	var cols = arrays[Mesh.ARRAY_COLOR]
	if cols is PackedColorArray:
		return cols
	return PackedColorArray()


func _colors_equal(a: PackedColorArray, b: PackedColorArray) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _visible_button(root: Node, text: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.is_visible_in_tree() and str(b.text) == text:
			return b
	return null


func _same_ints(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		if int(got[i]) != int(want[i]):
			return false
	return true


func _same_strs(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		if str(got[i]) != str(want[i]):
			return false
	return true


func _hover_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await process_frame


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


func _push_key(vp: Viewport, code: int, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode if pressed else 0
		ev.pressed = pressed
		ev.echo = false
		vp.push_input(ev)
		await process_frame
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
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame
