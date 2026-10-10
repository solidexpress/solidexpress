# Rung 1 WP2 — sketch tools the UBC nut / wrench tutorial names.
# Click-driven: Sketch tool + viewport clicks. Kernel asserts are checks only.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sketch_tests.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const TOL := 0.2

var _bad_status: Array[String] = []


func _init() -> void:
	print("rung01 sketch tests (WP2)")
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
	main.sketch_mode.status.connect(_on_sketch_status)

	await test_two_click_and_drag(ctx)
	await test_angle_dimension(ctx)
	await test_nut(ctx)
	await test_wrench(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _on_sketch_status(text: String) -> void:
	if text.contains("Failed to add") or text.contains("Failed to save") \
			or text.contains("Failed to update") or text.contains("Extrude failed") \
			or text.contains("Trim failed"):
		_bad_status.append(text)
		printerr("  status: " + text)


func _take_bad_status() -> String:
	if _bad_status.is_empty():
		return ""
	var s := "; ".join(_bad_status)
	_bad_status.clear()
	return s


func test_two_click_and_drag(ctx: FilmContext) -> void:
	print("- two clicks place one line; drag places one line")
	await _empty_doc(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv_local(ctx, Vector2(0, 0), "Line start")
	await _click_uv_local(ctx, Vector2(15, 0), "Line end")
	check(_count_real(sm, "line") == 1, "two clicks → one line (got %d)" % _count_real(sm, "line"))
	sm.cancel()
	await process_frame
	await _ground_sketch(ctx)
	sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _drag_uv(ctx, Vector2(0, 0), Vector2(18, 4))
	check(_count_real(sm, "line") == 1, "drag → one line, not two (got %d)" % _count_real(sm, "line"))
	sm.cancel()
	await process_frame


func test_angle_dimension(ctx: FilmContext) -> void:
	print("- two lines: smart dimension edits the angle to 45°")
	await _empty_doc(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv_local(ctx, Vector2(0, 0), "Angle line A start")
	await _click_uv_local(ctx, Vector2(30, 0), "Angle line A end")
	# Right-click ends the chain so line B is not the reverse of line A.
	await _right_click_uv(ctx, Vector2(30, 0))
	await _click_uv_local(ctx, Vector2(0, 0), "Angle line B start")
	await _click_uv_local(ctx, Vector2(26, 15), "Angle line B end")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv_local(ctx, Vector2(15, 0), "Dimension first line")
	await _click_uv_local(ctx, Vector2(13, 7.5), "Dimension second line")
	var ang_i := _dim_index(sm, "angle")
	check(ang_i >= 0, "angle dimension recorded")
	if ang_i >= 0:
		var st: String = sm.set_dimension_value(ang_i, 45.0)
		check(st != "failed" and st != "", "angle 45° solves (%s)" % st)
		var lines := _real_lines(sm)
		if lines.size() >= 2:
			var d0: Vector2 = lines[0]["end"] - lines[0]["start"]
			var d1: Vector2 = lines[1]["end"] - lines[1]["start"]
			var deg := rad_to_deg(absf(d0.angle_to(d1)))
			check(absf(deg - 45.0) < 1.0, "solved angle is 45° (got %.2f)" % deg)
	sm.cancel()
	await process_frame


func test_nut(ctx: FilmContext) -> void:
	print("- hex AF 20 flats top/bottom, Ø10, extrude 7.5")
	await _empty_doc(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv_local(ctx, Vector2.ZERO, "Circle centre")
	await _hover_uv(ctx, Vector2(1, 0))
	await _commit_dim(ctx, 5.0)
	check(_count_real(sm, "circle") == 1, "circle created")
	var circ := _first_of(sm, "circle")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv_local(ctx, Vector2(5, 0.4), "Diameter on the rim")
	if not circ.is_empty():
		var r := float(sm.sketch.entity_info(circ)["radius"])
		check(absf(r - 5.0) < 0.05, "solved radius 5 (got %.4f)" % r)
	check(_dim_index(sm, "diameter") >= 0, "smart dimension used diameter")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	sm.set_tool_variant("across_flats")
	sm.polygon_sides = 6
	await _click_uv_local(ctx, Vector2.ZERO, "Hex centre")
	await _hover_uv(ctx, Vector2(1, 0))
	await _commit_dim(ctx, 20.0)
	check(_count_real(sm, "line") >= 6, "hex has 6 edges")
	_assert_hex_flats(sm)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_finish_op("new")
	chrome.set_finish_end("blind")
	chrome.set_extrude_distance(7.5)
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Extrude nut 7.5"))
	await process_frame
	await process_frame
	var err := _take_bad_status()
	check(err == "", "nut extrude status clean" if err == "" else err)
	check(not sm.active, "sketch session ended after extrude")
	var body := _only_body(ctx)
	check(body != "", "nut body exists")
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	var xy: Array[float] = [ext.x, ext.y]
	xy.sort()
	check(absf(xy[0] - 20.0) <= TOL, "nut AF min XY %.3f" % xy[0])
	check(absf(xy[1] - 23.094) <= TOL, "nut AC max XY %.3f" % xy[1])
	check(absf(ext.z - 7.5) <= TOL, "nut thickness %.3f" % ext.z)
	var mesh := _load_mesh(ctx.view.doc, body)
	var ctr: Vector3 = (bb["min"] + bb["max"]) * 0.5
	var bore_open := true
	for z in [0.3, 3.75, 7.2]:
		if _inside(mesh, Vector3(ctr.x, ctr.y, bb["min"].z + z)):
			bore_open = false
	check(bore_open, "bore open through the nut")
	var hx := _first_hit(mesh, Vector3(ctr.x, ctr.y, ctr.z), Vector3(1, 0, 0))
	var hy := _first_hit(mesh, Vector3(ctr.x, ctr.y, ctr.z), Vector3(-1, 0, 0))
	var dia := hx + hy if hx >= 0.0 and hy >= 0.0 else -1.0
	check(dia > 0.0 and absf(dia - 10.0) <= TOL, "bore Ø %.3f" % dia)
	var solid := _inside(mesh, Vector3(ctr.x, ctr.y + 8.0, ctr.z)) \
			or _inside(mesh, Vector3(ctr.x + 8.0, ctr.y, ctr.z))
	check(solid, "nut body solid at r=8")


func test_wrench(ctx: FilmContext) -> void:
	print("- wrench blank, jaw through-all, slot, jaw edit 20→21")
	await _empty_doc(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3(100, 0, 0), 400.0)
	await _draw_circle(ctx, Vector2.ZERO, 10.0)
	await _draw_circle(ctx, Vector2(200, 0), 22.5)
	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv_local(ctx, Vector2(0, 10), "Upper tangent start")
	await _click_uv_local(ctx, Vector2(far_x, 10), "Upper tangent end")
	await _right_click_uv(ctx, Vector2(far_x, 10))
	await _click_uv_local(ctx, Vector2(0, -10), "Lower tangent start")
	await _click_uv_local(ctx, Vector2(far_x, -10), "Lower tangent end")
	await _right_click_uv(ctx, Vector2(far_x, -10))
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_finish_op("new")
	chrome.set_finish_end("blind")
	chrome.set_extrude_distance(10.0)
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Extrude wrench blank 10"))
	await process_frame
	await process_frame
	var err := _take_bad_status()
	check(err == "", "blank extrude status clean" if err == "" else err)
	var body := _only_body(ctx)
	check(body != "", "wrench body exists")
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.x - 232.5) <= TOL, "blank bbox X %.3f" % ext.x)
	check(absf(ext.y - 45.0) <= TOL, "blank bbox Y %.3f" % ext.y)
	check(absf(ext.z - 10.0) <= TOL, "blank bbox Z %.3f" % ext.z)

	var top := _face_along(ctx, body, 1)
	var bottom := _face_along(ctx, body, -1)
	check(top != "" and bottom != "", "top and bottom faces")
	if top == "":
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	sm = ctx.main.sketch_mode
	check(sm.active, "face sketch started")
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _draw_circle(ctx, Vector2.ZERO, 5.0)
	await _zoom_uv(ctx, Vector2(200, 0), 90.0)
	await _draw_circle(ctx, Vector2(200, 0), 22.5)
	await _draw_centre_rect(ctx, Vector2(200, 0))
	await _draw_centreline(ctx, Vector2(200, 0))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	var s2 := sqrt(2.0) / 2.0
	var ax := Vector2(s2, s2)
	await _click_uv_local(ctx, Vector2(200, 0) + ax * -12.0, "Trim inner jaw half")
	await process_frame
	err = _take_bad_status()
	check(err == "", "jaw trim status clean" if err == "" else err)
	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile closed")
	chrome = ctx.main.sketch_chrome
	chrome.set_up_to_face(bottom)
	chrome.set_finish_op("cut")
	chrome.set_finish_end("through_all")
	chrome.set_extrude_distance(10.0)
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Cut jaw Through All"))
	await process_frame
	await process_frame
	err = _take_bad_status()
	check(err == "", "jaw cut status clean" if err == "" else err)
	var cut := _extrude_with_end(ctx, "through_all")
	check(not cut.is_empty(), "through-all cut stored")
	if not cut.is_empty():
		check(str(cut.get("to_face", "")) == bottom, "to_face param stored")
		check(str(cut.get("end", "")) == "through_all", "jaw end is through_all")
	var jaw_sketch := str(cut.get("sketch", "")) if not cut.is_empty() else ""
	var mesh := _load_mesh(ctx.view.doc, body)
	_assert_jaw(mesh, 20.0)
	_assert_pivot(mesh)

	print("- grip slot R5, centres 150 apart, blind 2.5")
	# A click on the shaft hits the blank's yellow pad and reopens that ground
	# sketch (pad pick ignores visibility). Leave it, then Sketch the top face
	# from the selection strip.
	top = _face_along(ctx, body, 1)
	var host_pt := Vector3(100, 0, 10)
	if top != "":
		var picked := FilmUI.face_pick_point(ctx.view, body, top)
		if picked != Vector3.INF:
			host_pt = picked
	await _zoom(ctx, host_pt, 500.0)
	var host_screen := FilmUI.model_to_screen(ctx, host_pt)
	if FilmUI.is_on_screen(ctx, host_screen):
		await FilmUI.viewport_click(ctx, host_screen,
				FilmUICues.alert("Click", "Select top face for the grip slot"))
		await process_frame
	sm = ctx.main.sketch_mode
	var on_top := sm.active and sm.plane_normal().dot(Vector3(0, 0, 1)) > 0.9 \
			and absf(sm.plane_origin.z - 10.0) < 0.5
	if sm.active and not on_top:
		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
		await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
		await process_frame
		sm = ctx.main.sketch_mode
		on_top = false
	if not on_top:
		if top != "":
			ctx.view.select_entity(body, top)
		ctx.main.interaction._refresh_selection_strip()
		var sketch_btn: Button = ctx.main.interaction._strip_sketch
		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
		await process_frame
		await process_frame
		sm = ctx.main.sketch_mode
	check(sm.active and sm.plane_normal().dot(Vector3(0, 0, 1)) > 0.9
			and absf(sm.plane_origin.z - 10.0) < 0.5, "slot sketch on the top face")
	await _zoom_uv(ctx, Vector2(90, 0), 260.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SLOT)
	ctx.main.sketch_chrome.focus_dim_for_typing("5")
	ctx.main.sketch_chrome.release_dim_focus()
	check(absf(sm.slot_radius - 5.0) < 1e-3, "slot radius from dim blank")
	await _click_uv_local(ctx, Vector2(18.5, 0), "Slot first centre")
	await _hover_uv(ctx, Vector2(19.5, 0))
	await _commit_dim(ctx, 150.0)
	var centres := _arc_centres(sm)
	check(centres.size() == 2, "slot has two real arcs")
	if centres.size() == 2:
		centres.sort_custom(func(a, b): return a.x < b.x)
		check(absf(centres[0].x - 18.5) < 0.5, "slot centre A x %.2f" % centres[0].x)
		check(absf(centres[1].x - 168.5) < 0.5, "slot centre B x %.2f" % centres[1].x)
	chrome = ctx.main.sketch_chrome
	chrome.set_up_to_face("")
	chrome.set_finish_op("cut")
	chrome.set_finish_end("blind")
	chrome.set_extrude_distance(2.5)
	await FilmUI.click_control(ctx, chrome.extrude_button(),
			FilmUICues.alert("Extrude", "Cut slot blind 2.5"))
	await process_frame
	await process_frame
	err = _take_bad_status()
	check(err == "", "slot cut status clean" if err == "" else err)
	mesh = _load_mesh(ctx.view.doc, body)
	_assert_slot(mesh)

	print("- double-click jaw width 20 → 21")
	if jaw_sketch == "":
		check(false, "jaw sketch id missing")
		return
	check(sm.begin_edit(jaw_sketch) if false else ctx.main.sketch_mode.begin_edit(jaw_sketch),
			"reopen jaw sketch")
	sm = ctx.main.sketch_mode
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var di := _dim_index_near(sm, "distance", 20.0)
	check(di >= 0, "jaw width dimension restored")
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	check(lp != null, "jaw width label has a position")
	if lp == null:
		return
	await _zoom_uv(ctx, lp as Vector2, 40.0)
	await _click_uv_local(ctx, lp as Vector2, "Edit jaw width")
	await process_frame
	var ix = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension editor opened")
	ix._dim_edit_line.text = "21"
	ix._dim_edit_line.text_submitted.emit("21")
	await process_frame
	await process_frame
	err = _take_bad_status()
	check(err == "", "dimension edit status clean" if err == "" else err)
	mesh = _load_mesh(ctx.view.doc, body)
	_assert_jaw(mesh, 21.0)


func _assert_hex_flats(sm: SketchMode) -> void:
	var ys: Array[float] = []
	var xs: Array[float] = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for p in [info["start"], info["end"]]:
			var v: Vector2 = p
			xs.append(v.x)
			ys.append(v.y)
	if xs.is_empty():
		check(false, "hex vertices")
		return
	xs.sort()
	ys.sort()
	check(absf(ys[0] + 10.0) <= 0.15 and absf(ys[ys.size() - 1] - 10.0) <= 0.15,
			"flats at y=±10 (%.3f .. %.3f)" % [ys[0], ys[ys.size() - 1]])
	check(absf(xs[0] + 20.0 / sqrt(3.0)) <= 0.2 and absf(xs[xs.size() - 1] - 20.0 / sqrt(3.0)) <= 0.2,
			"vertices on ±X")


func _assert_pivot(mesh: Array) -> void:
	var open := true
	for z in [0.5, 5.0, 9.5]:
		if _inside(mesh, Vector3(0, 0, z)):
			open = false
	check(open, "pivot hole open at z=0.5/5/9.5")
	var a := _first_hit(mesh, Vector3(0, 0, 5), Vector3(1, 0, 0))
	var b := _first_hit(mesh, Vector3(0, 0, 5), Vector3(-1, 0, 0))
	var dia := a + b if a >= 0.0 and b >= 0.0 else -1.0
	check(dia > 0.0 and absf(dia - 10.0) <= TOL, "pivot hole Ø %.3f" % dia)
	check(_inside(mesh, Vector3(7.5, 0, 5)), "pivot boss ring solid")


func _assert_jaw(mesh: Array, af: float) -> void:
	var s2 := sqrt(2.0) / 2.0
	var ax := Vector3(s2, s2, 0)
	var pv := Vector3(-s2, s2, 0)
	var h := Vector3(200, 0, 0)
	var open := true
	for u in [3.0, 11.0, 18.0]:
		for z in [0.5, 5.0, 9.5]:
			if _inside(mesh, h + ax * u + Vector3(0, 0, z)):
				open = false
	check(open, "jaw open at u=3/11/18 through the depth (AF %.0f)" % af)
	check(_inside(mesh, h + ax * -1.0 + Vector3(0, 0, 5)), "jaw floor side u=-1 is solid")
	var fl := _first_hit(mesh, h + ax * 10.0 + Vector3(0, 0, 5), -ax)
	check(fl >= 0.0 and absf(fl - 10.0) <= TOL, "jaw floor %.3f mm from u=10" % fl)
	for z in [2.0, 5.0, 8.0]:
		var pa := _first_hit(mesh, h + ax * 10.0 + Vector3(0, 0, z), pv)
		var pb := _first_hit(mesh, h + ax * 10.0 + Vector3(0, 0, z), -pv)
		var g := pa + pb if pa >= 0.0 and pb >= 0.0 else -1.0
		check(g > 0.0 and absf(g - af) <= TOL, "jaw AF at z=%.0f is %.3f (want %.1f)" % [z, g, af])


func _assert_slot(mesh: Array) -> void:
	var xs: Array[float] = []
	for i in range(60, 130):
		if not _inside(mesh, Vector3(float(i), 0, 8.75)):
			xs.append(float(i))
	check(xs.size() > 0, "grip slot present")
	if xs.is_empty():
		return
	var xm: float = xs[xs.size() / 2]
	var t := _first_hit(mesh, Vector3(xm, 0, 30), Vector3(0, 0, -1))
	var floor := 30.0 - t if t >= 0.0 else -1.0
	check(floor > 0.0 and absf(floor - 7.5) <= TOL, "slot floor z %.3f" % floor)
	var a := _first_hit(mesh, Vector3(xm, 0, 8.75), Vector3(0, 1, 0))
	var b := _first_hit(mesh, Vector3(xm, 0, 8.75), Vector3(0, -1, 0))
	var w := a + b if a >= 0.0 and b >= 0.0 else -1.0
	check(w > 0.0 and absf(w - 10.0) <= TOL, "slot width %.3f" % w)
	a = _first_hit(mesh, Vector3(xm, 0, 8.75), Vector3(1, 0, 0))
	b = _first_hit(mesh, Vector3(xm, 0, 8.75), Vector3(-1, 0, 0))
	var length := a + b if a >= 0.0 and b >= 0.0 else -1.0
	check(length > 0.0 and absf(length - 160.0) <= TOL, "slot length %.3f" % length)
	check(_inside(mesh, Vector3(xm, 0, 6.5)), "below slot is solid")


func _empty_doc(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		sm.cancel()
		await process_frame
	ctx.view.new_document()
	ctx.view.refresh()
	await process_frame


func _ground_sketch(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "sketch session is open")


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	# Look-at starts a yaw/pitch tween that keeps writing the camera after the
	# sketch view locks. Kill it so the next click lands on the framed point.
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
	else:
		# Top view of the Z-up model so a face click hits the plate.
		cam.sketch_orientation_locked = true
		cam.yaw = 0.0
		cam.pitch = deg_to_rad(89.0)
		cam._look_at_content = true
		if ms != null:
			var up_w: Vector3 = ms.global_transform.basis * Vector3(0, 1, 0)
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


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


func _commit_dim(ctx: FilmContext, value: float) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.focus_dim_for_typing(str(value))
	var edit: LineEdit = chrome._dim_spin.get_line_edit()
	edit.text = str(value)
	edit.text_submitted.emit(str(value))
	await process_frame
	await process_frame
	chrome.release_dim_focus()


func _drag_uv(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var sa := FilmUI.model_to_screen(ctx, sm.to_model(a))
	var sb := FilmUI.model_to_screen(ctx, sm.to_model(b))
	var ix = ctx.main.interaction
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = sa
	ix._input(down)
	await process_frame
	for i in 4:
		var motion := InputEventMouseMotion.new()
		motion.position = sa.lerp(sb, float(i + 1) / 4.0)
		motion.relative = sb - sa
		ix._input(motion)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = sb
	ix._input(up)
	await process_frame
	await process_frame


func _draw_circle(ctx: FilmContext, center: Vector2, radius: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv_local(ctx, center, "Circle centre")
	await _hover_uv(ctx, center + Vector2(1, 0))
	await _commit_dim(ctx, radius)


func _draw_centre_rect(ctx: FilmContext, center: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Centre three-point rectangle"))
	var s2 := sqrt(2.0) / 2.0
	var along := Vector2(s2, s2)
	var across := Vector2(-s2, s2)
	await _click_uv_local(ctx, center, "Rect centre")
	await _click_uv_local(ctx, center + along * 30.0, "Rect long side")
	await _click_uv_local(ctx, center + across * 10.0, "Rect half width")


func _draw_centreline(ctx: FilmContext, center: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Centerline")
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Construction centreline"))
	var across := Vector2(-sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)
	await _click_uv_local(ctx, center - across * 25.0, "Centreline start")
	await _click_uv_local(ctx, center + across * 25.0, "Centreline end")


func _count_real(sm: SketchMode, kind: String) -> int:
	var n := 0
	if sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n


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


func _arc_centres(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "arc":
			out.append(info["center"])
	return out


func _dim_index(sm: SketchMode, type_name: String) -> int:
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type_name:
			return i
	return -1


func _dim_index_near(sm: SketchMode, type_name: String, value: float) -> int:
	var best := -1
	var best_d := 1.0
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != type_name:
			continue
		var shown := sm._dimension_display_value(dim)
		var d := absf(shown - value)
		if d < best_d:
			best_d = d
			best = i
	return best


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[0]


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	# Bbox, not face_normal: after a cut the first triangle of the top plate
	# can point sideways, so a normal test misses the face the ray should hit.
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var bb: Dictionary = ctx.view.doc.measure_bbox(f)
		if bb.is_empty():
			continue
		var ext: Vector3 = bb["max"] - bb["min"]
		var span := maxf(ext.x, ext.y)
		if ext.z > 0.5 and ext.z > span * 0.05:
			continue
		var z: float = bb["max"].z if z_sign > 0 else bb["min"].z
		var area := ext.x * ext.y
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


func _extrude_with_end(ctx: FilmContext, end_name: String) -> Dictionary:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("end", "")) == end_name and str(parsed.get("op", "")) == "cut":
			return parsed
	return {}


func _load_mesh(doc: SxDocument, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()
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
		var p := d.cross(e2)
		var det := e1.dot(p)
		if absf(det) < 1e-12:
			continue
		var inv := 1.0 / det
		var s := origin - a
		var u := s.dot(p) * inv
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


func _first_hit(mesh: Array, origin: Vector3, dir: Vector3) -> float:
	var hits := _ray_hits(mesh, origin, dir)
	if hits.is_empty():
		return -1.0
	return hits[0]
