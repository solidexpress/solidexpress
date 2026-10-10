# Rung 1 replan WP2 — polygon AF, tangent snaps, angle dims, extrude guards.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan_sketch.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const TOL := 0.2

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan WP2 sketch")
	FilmUI.reset_fail_count()
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
	await FilmUI.ensure_test_viewport(ctx)
	main.sketch_mode.status.connect(func(text: String) -> void:
		_status_log.append(text)
		print("  status: " + text))

	await test_polygon_af_and_circle(ctx)
	await test_tangent_blank(ctx)
	await test_centre_rect_dims(ctx)
	await test_single_line_angle(ctx)
	await test_to_face_needs_a_face(ctx)
	await test_thin_wall_status(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_polygon_af_and_circle(ctx: FilmContext) -> void:
	print("- polygon defaults to across flats; type 20; circle type 5")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats without a chip click (got %s)" % sm.tool_variant)
	await _click_uv_local(ctx, Vector2.ZERO, "Hex centre")
	await _hover_uv(ctx, Vector2(8, 0))
	await _type_into_spin(ctx.main.sketch_chrome._dim_spin, "20")
	await process_frame
	await process_frame
	_assert_hex_flats(sm)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv_local(ctx, Vector2.ZERO, "Circle centre")
	await _hover_uv(ctx, Vector2(4, 0))
	await _type_into_spin(ctx.main.sketch_chrome._dim_spin, "5")
	await process_frame
	await process_frame
	var circ := _first_of(sm, "circle")
	check(circ != "", "circle created")
	if circ != "":
		var r := float(sm.sketch.entity_info(circ)["radius"])
		check(absf(r - 5.0) <= 0.05, "typed 5 is radius 5 (got %.4f)" % r)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	check(sm.tool_variant == "corner", "rect tool resets its own variant")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	check(sm.tool_variant == "across_flats",
			"polygon restores across_flats after circle and rect (got %s)" % sm.tool_variant)
	var vertex := FilmUI.find_button(ctx.main.sketch_chrome, "Vertex")
	await FilmUI.click_control(ctx, vertex, FilmUICues.alert("Vertex", "Polygon vertex variant"))
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool_variant == "vertex",
			"polygon remembers vertex across a circle re-arm (got %s)" % sm.tool_variant)
	var af := FilmUI.find_button(ctx.main.sketch_chrome, "Across Flats")
	await FilmUI.click_control(ctx, af, FilmUICues.alert("Across Flats", "Restore across flats"))
	await process_frame
	check(sm.tool_variant == "across_flats", "across flats chip sticks again")


func test_tangent_blank(ctx: FilmContext) -> void:
	print("- near-tangent shaft, extrude thin 0, bbox 232.5 x 45 x 10")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10")
	await _draw_circle_typed(ctx, Vector2(200, 0), "22.5")
	var circs: Array = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			circs.append(info)
	circs.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	check(circs.size() == 2, "two circles before the shaft")
	if circs.size() != 2:
		return
	var c1: Vector2 = circs[0]["center"]
	var c2: Vector2 = circs[1]["center"]
	var r1 := float(circs[0]["radius"])
	var r2 := float(circs[1]["radius"])
	var tangents := _external_tangents(c1, r1, c2, r2)
	check(tangents.size() == 2, "two external tangents")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	for pair in tangents:
		var a: Vector2 = pair["a"]
		var b: Vector2 = pair["b"]
		var a_off := a + (a - c1).normalized() * 0.3
		var b_off := b + (b - c2).normalized() * 1.1
		await _zoom_uv(ctx, a_off, 90.0)
		await _click_uv_local(ctx, a_off, "Tangent start near circle")
		await _zoom_uv(ctx, b_off, 90.0)
		await _click_uv_local(ctx, b_off, "Tangent end near circle")
		await _right_click_uv(ctx, b_off)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _type_into_spin(chrome._extrude_spin, "10")
	check(absf(chrome._extrude_spin.value - 10.0) < 0.05, "distance spin is 10")
	check(absf(chrome._thin_spin.value) < 0.01, "thin stays 0")
	var before := _count_type(ctx, "extrude")
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Extrude tangent blank"))
	await process_frame
	await process_frame
	await process_frame
	var st := _latest_status(ctx)
	check(not st.contains("open profile") and not st.contains("open loop"),
			"blank status is not an open profile (%s)" % st)
	check(_count_type(ctx, "extrude") == before + 1, "blank extrude added")
	var body := _only_body(ctx)
	check(body != "", "blank body exists")
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.x - 232.5) <= TOL, "blank bbox X %.3f" % ext.x)
	check(absf(ext.y - 45.0) <= TOL, "blank bbox Y %.3f" % ext.y)
	check(absf(ext.z - 10.0) <= TOL, "blank bbox Z %.3f" % ext.z)


func test_centre_rect_dims(ctx: FilmContext) -> void:
	print("- centre rect width 20 and angle 45 from the labels")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center Three Point", "Centre rectangle"))
	var along := Vector2(cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)))
	var across := Vector2(-along.y, along.x)
	await _click_uv_local(ctx, Vector2.ZERO, "Rect centre")
	await _click_uv_local(ctx, along * 30.0, "Rect long side")
	await _click_uv_local(ctx, across * 8.0, "Rect half width")
	await process_frame
	var built := _real_lines(sm)
	check(built.size() == 4, "centre rect has 4 profile lines (got %d)" % built.size())
	var cons := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			cons += 1
	check(cons >= 1, "angle reference stays construction")
	check(SketchMode.profile_is_closed(sm.sketch), "construction line is outside the profile")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var width_i := _dim_index_near(sm, "distance", 16.0)
	check(width_i >= 0, "width dimension exists before the edit")
	if width_i >= 0:
		await _edit_dim_label(ctx, width_i, "20")
	var ang_i := _dim_index(sm, "angle")
	check(ang_i >= 0, "angle-to-horizontal dimension exists")
	if ang_i >= 0:
		await _edit_dim_label(ctx, ang_i, "45")
	width_i = _dim_index_near(sm, "distance", 20.0)
	ang_i = _dim_index(sm, "angle")
	var width_shown := -1.0
	var ang_shown := -1.0
	if width_i >= 0:
		width_shown = float(sm._dimension_display_value(sm.dimensions[width_i]))
	if ang_i >= 0:
		ang_shown = float(sm._dimension_display_value(sm.dimensions[ang_i]))
	check(absf(width_shown - 20.0) <= TOL, "width label value %.3f" % width_shown)
	check(absf(absf(ang_shown) - 45.0) <= TOL, "angle label %.3f degrees" % ang_shown)
	var wtext := _label_text_for(sm, width_i)
	var atext := _label_text_for(sm, ang_i)
	check(wtext.contains("20"), "width label text contains 20 (got %s)" % wtext)
	check(atext.contains("45") and atext.contains("°"),
			"angle label shows degrees (got %s)" % atext)
	var short_len := _shortest_real_line(sm)
	check(absf(short_len - 20.0) <= TOL, "short side is 20 (got %.3f)" % short_len)
	var orient := _long_side_angle_deg(sm)
	check(absf(orient - 45.0) <= TOL, "long side is 45° to horizontal (got %.3f)" % orient)


func test_single_line_angle(ctx: FilmContext) -> void:
	print("- smart dimension on one line adds angle to horizontal")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3(10, 5, 0), 60.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv_local(ctx, Vector2.ZERO, "Line start")
	await _click_uv_local(ctx, Vector2(20, 10), "Line end")
	await _right_click_uv(ctx, Vector2(20, 10))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv_local(ctx, Vector2(10, 5), "Dimension the line")
	await process_frame
	check(_dim_index(sm, "angle") >= 0, "single line grew an angle dimension")
	var cons_line := false
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		if absf(d.y) < 0.05 and absf(d.x) > 1.0:
			cons_line = true
	check(cons_line, "angle reference is a construction +X line")
	var shown := -1.0
	var ai := _dim_index(sm, "angle")
	if ai >= 0:
		shown = sm._dimension_display_value(sm.dimensions[ai])
	check(absf(absf(shown) - rad_to_deg(atan2(10.0, 20.0))) < 1.0,
			"angle label is degrees (got %.3f)" % shown)


func test_to_face_needs_a_face(ctx: FilmContext) -> void:
	print("- to_face with an empty face id does not extrude")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3.ZERO, 40.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "5")
	ctx.view.select_entity("", "")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome._finish_end.select(3)
	chrome._finish_end.item_selected.emit(3)
	await process_frame
	check(str(chrome.up_to_face_id).strip_edges() == "",
			"up_to_face_id stayed empty (got %s)" % chrome.up_to_face_id)
	var before := _count_type(ctx, "extrude")
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Extrude without a face"))
	await process_frame
	await process_frame
	var st := _latest_status(ctx)
	check(st.contains("needs a face"), "status contains needs a face (%s)" % st)
	check(_count_type(ctx, "extrude") == before, "faceless to_face added no extrude")
	check(sm.active, "sketch session stays up")


func test_thin_wall_status(ctx: FilmContext) -> void:
	print("- thin wall status has no closed-profile prefix")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3.ZERO, 40.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "5")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome._finish_end.select(0)
	chrome._finish_end.item_selected.emit(0)
	var thin_feature: CheckButton = chrome.find_child("ThinFeature", true, false)
	check(thin_feature != null and not thin_feature.button_pressed, "Thin feature defaults off")
	if thin_feature == null:
		return
	thin_feature.button_pressed = true
	await process_frame
	check(chrome._thin_spin.is_visible_in_tree(), "thin spin shows with Thin feature on")
	chrome._thin_spin.value = 1.0
	check(chrome._thin_spin.value > 0.5, "thin spin is on (got %.3f)" % chrome._thin_spin.value)
	# Thin feature reveals the spin, type, and Flip, which push Extrude past
	# the 1280-wide test window.
	ctx.tree.root.size = Vector2i(1760, 720)
	await process_frame
	var before := _count_type(ctx, "extrude")
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Extrude circle with thin on"))
	await process_frame
	await process_frame
	var err := ""
	if ctx.view.doc.has_method("last_graph_error"):
		err = str(ctx.view.doc.last_graph_error())
	var st := _latest_status(ctx)
	print("  graph error: " + err)
	check(sm.active, "thin failure leaves the sketch session up")
	check(_count_type(ctx, "extrude") == before, "thin circle did not add an extrude")
	if err.contains("Thin wall") or st.contains("Thin wall"):
		check(st.contains("Thin wall"), "status is the thin-wall sentence (%s)" % st)
		check(not st.contains("is the profile closed"),
				"thin-wall status has no closed-profile prefix (%s)" % st)
		check(not st.begins_with("Extrude failed"),
				"thin-wall status is that sentence alone (%s)" % st)
	else:
		check(not (st.contains("Thin wall") and st.contains("is the profile closed")),
				"a Thin wall sentence is never prefixed (%s)" % st)


func _assert_hex_flats(sm: SketchMode) -> void:
	var ys: Array[float] = []
	var xs: Array[float] = []
	var on_x := false
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for p in [info["start"], info["end"]]:
			var v: Vector2 = p
			xs.append(v.x)
			ys.append(v.y)
			if absf(v.y) <= 0.2 and absf(absf(v.x) - 20.0 / sqrt(3.0)) <= 0.2:
				on_x = true
	if xs.is_empty():
		check(false, "hex vertices")
		return
	xs.sort()
	ys.sort()
	check(absf(ys[0] + 10.0) <= 0.15 and absf(ys[ys.size() - 1] - 10.0) <= 0.15,
			"flats at y=±10 (%.3f .. %.3f)" % [ys[0], ys[ys.size() - 1]])
	check(on_x, "vertices on ±X")


func _external_tangents(c1: Vector2, r1: float, c2: Vector2, r2: float) -> Array:
	var d := c2 - c1
	var dist := d.length()
	var along := (r2 - r1) / dist
	var perp := sqrt(maxf(0.0, 1.0 - along * along))
	var u := d / dist
	var side := Vector2(-u.y, u.x)
	var out: Array = []
	for sign in [1.0, -1.0]:
		var s := float(sign)
		var n: Vector2 = u * along + side * (perp * s)
		out.append({"a": c1 - n * r1, "b": c2 - n * r2})
	return out


func _file_new(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
		if exit_btn != null and exit_btn.is_visible_in_tree():
			await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
		await process_frame
	ctx.main._file_popup.id_pressed.emit(0)
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible:
		dlg.confirmed.emit()
		await process_frame
	await process_frame


func _ground_sketch(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "sketch session is open")


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, sm.to_model(uv), size_mm)


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, uv, desc)


func _right_click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = screen
	ctx.main.interaction._input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = screen
	ctx.main.interaction._input(up)
	await process_frame


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await process_frame


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv_local(ctx, center, "Circle centre")
	await _hover_uv(ctx, center + Vector2(6, 0))
	await _type_into_spin(ctx.main.sketch_chrome._dim_spin, radius_text)
	await process_frame
	await process_frame


func _type_into_spin(spin: SpinBox, text: String) -> void:
	var edit: LineEdit = spin.get_line_edit()
	edit.grab_focus()
	await process_frame
	if not edit.is_editing():
		edit.edit()
		await process_frame
	edit.select_all()
	await process_frame
	await _push_text(edit, text)
	await _push_key_local(edit, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _edit_dim_label(ctx: FilmContext, index: int, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[index])
	check(lp != null, "dimension label has a position")
	if lp == null:
		return
	await _zoom_uv(ctx, lp as Vector2, 40.0)
	await _click_uv_local(ctx, lp as Vector2, "Edit dimension label")
	await process_frame
	await process_frame
	var ix = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension editor opened")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	var edit: LineEdit = ix._dim_edit_line
	edit.grab_focus()
	await process_frame
	edit.select_all()
	await _push_text(edit, text)
	await _push_key_local(edit, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _push_text(edit: LineEdit, text: String) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		var key := KEY_PERIOD if code == 46 else KEY_0 + (code - 48)
		await _push_key_local(edit, key, code)


func _push_key_local(edit: LineEdit, keycode: int, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	ev.physical_keycode = keycode as Key
	ev.unicode = unicode
	ev.pressed = true
	edit.get_viewport().push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode as Key
	rel.physical_keycode = keycode as Key
	rel.pressed = false
	edit.get_viewport().push_input(rel)
	await process_frame


func _latest_status(ctx: FilmContext) -> String:
	if not _status_log.is_empty():
		return _status_log[_status_log.size() - 1]
	if ctx.main.status_label != null:
		return str(ctx.main.status_label.text)
	return ""


func _count_type(ctx: FilmContext, type_name: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == type_name:
			n += 1
	return n


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[0]


func _first_of(sm: SketchMode, kind: String) -> String:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			return id
	return ""


func _real_lines(sm: SketchMode) -> Array:
	var out: Array = []
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "line":
			out.append(info)
	return out


func _dim_index(sm: SketchMode, type_name: String) -> int:
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type_name:
			return i
	return -1


func _dim_index_near(sm: SketchMode, type_name: String, value: float) -> int:
	var best := -1
	var best_d := 1.5
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != type_name:
			continue
		var d := absf(sm._dimension_display_value(dim) - value)
		if d < best_d:
			best_d = d
			best = i
	return best


func _label_text_for(sm: SketchMode, index: int) -> String:
	if index < 0 or sm._dimension_labels == null:
		return ""
	var want: Variant = sm._dimension_label_pos2(sm.dimensions[index])
	if want == null:
		return ""
	var target: Vector3 = sm._to3(want)
	var best := ""
	var best_d := 0.75
	for child in sm._dimension_labels.get_children():
		if not (child is Label3D):
			continue
		var d: float = (child as Label3D).position.distance_to(target)
		if d < best_d:
			best_d = d
			best = (child as Label3D).text
	return best


func _shortest_real_line(sm: SketchMode) -> float:
	var best := INF
	for info in _real_lines(sm):
		var d: Vector2 = info["end"] - info["start"]
		best = minf(best, d.length())
	return best


func _long_side_angle_deg(sm: SketchMode) -> float:
	var best_len := -1.0
	var best_deg := -1.0
	for info in _real_lines(sm):
		var d: Vector2 = info["end"] - info["start"]
		if d.length() > best_len:
			best_len = d.length()
			var deg := absf(rad_to_deg(d.angle()))
			deg = fmod(deg, 180.0)
			if deg > 90.0:
				deg = 180.0 - deg
			best_deg = deg
	return best_deg
