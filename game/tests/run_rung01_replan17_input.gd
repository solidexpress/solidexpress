# Rung 1 replan 17 WP3 — click ledger, sketch marquee, select-status wording.
# Setup may use the document / sketch API. Every press, key and motion under
# test is a real InputEvent pushed with Viewport.push_input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan17_input.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []
var _disp_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan17 WP3 input ledger, marquee, select wording")
	FilmUI.reset_fail_count()
	await test_k1_ledger()
	await test_k2_trials()
	await test_k3_dim_halo()
	await test_marquee()
	await test_w1_wording()
	await test_s1_smart_dim_points()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_k1_ledger() -> void:
	print("- K1 ledger")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var ix: ViewportInteraction = ctx.main.interaction
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "K1 sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	var circle := FilmUI.find_sketch_tool_button(ctx.main, "Circle")
	check(circle != null and circle.is_visible_in_tree(), "K1 rail Circle is visible")
	_disp_log.clear()
	_status_log.clear()
	await _x11_click(circle)
	await process_frame
	var rail_disp := _last_disp()
	check(rail_disp.begins_with("drop:over-chrome:"),
			"K1 rail press is drop:over-chrome (got `%s`)" % rail_disp)
	check(rail_disp.contains("Sketch") or rail_disp.contains("Tool") or rail_disp.contains("Circle"),
			"K1 rail disposition names the rail (got `%s`)" % rail_disp)
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(18.0, -12.0)))
	check(FilmUI.require_on_screen(ctx, screen, "K1 canvas"), "K1 canvas click is on screen")
	var mark := _status_log.size()
	await _x11_click_screen(vp, screen)
	await process_frame
	check(_last_disp() == "sketch-click:CIRCLE",
			"K1 canvas disposition sketch-click:CIRCLE (got `%s`)" % _last_disp())
	check(_saw_since(mark, "Circle — centre set, click the rim or type a radius"),
			"K1 status Circle — centre set (log %s)" % _tail())
	var extrude: Button = null
	if ctx.main.sketch_chrome != null:
		extrude = ctx.main.sketch_chrome.extrude_button()
	check(extrude != null and extrude.is_visible_in_tree(), "K1 Extrude button is visible")
	if extrude != null:
		await _x11_click_screen(vp, extrude.get_global_rect().get_center())
		await process_frame
		var ed := _last_disp()
		check(ed.begins_with("drop:over-chrome:") and ed.length() > "drop:over-chrome:".length(),
				"K1 Extrude press is drop:over-chrome:<name> (got `%s`)" % ed)
	await _shutdown(ctx)


func test_k2_trials() -> void:
	print("- K2 40 trials")
	var ctx := await _boot()
	var vp: Viewport = ctx.main.get_viewport()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	await process_frame
	check(body != "", "K2 body exists")
	ctx.view.clear_selection()
	await process_frame
	# A selected body hides the palette; with nothing selected the palette Sketch is the rail.
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "K2 rail Sketch is visible")
	var dead := 0
	if sketch_btn != null:
		var pos := sketch_btn.get_global_rect().get_center()
		for i in 10:
			var mark := _status_log.size()
			await _trial_click(vp, pos, i % 2 == 1)
			var ok := _saw_since(mark, "Select a face or existing sketch (Esc to cancel)")
			if not ok:
				dead += 1
				print("  dead sketch trial %d disp=%s status=%s" % [i + 1, _last_disp(), _tail()])
			await _x11_key(vp, KEY_ESCAPE)
	check(dead == 0, "K2 rail Sketch 0/10 dead (dead %d)" % dead)

	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "K2 sketch is active for Jaw")
	var jaw_dead := 0
	if sm != null and sm.active:
		var jaw := ctx.main.find_child("JawTool", true, false) as Button
		check(jaw != null and jaw.is_visible_in_tree(), "K2 rail Jaw is visible")
		var canvas := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(12.0, 8.0)))
		check(FilmUI.require_on_screen(ctx, canvas, "K2 jaw canvas"), "K2 jaw canvas is on screen")
		if jaw != null:
			for i in 10:
				if not sm.active:
					await FilmUI.enter_sketch(ctx)
					sm = ctx.main.sketch_mode
					jaw = ctx.main.find_child("JawTool", true, false) as Button
					canvas = FilmUI.model_to_screen(ctx, sm.to_model(Vector2(12.0, 8.0)))
				await _trial_click(vp, jaw.get_global_rect().get_center(), i % 2 == 1)
				var mark2 := _status_log.size()
				await _trial_click(vp, canvas, i % 2 == 1)
				var ok2 := _saw_since(mark2, "Jaw — centre set, click 2 end of the long side")
				if not ok2:
					jaw_dead += 1
					print("  dead jaw trial %d disp=%s status=%s" % [i + 1, _last_disp(), _tail()])
				await _x11_key(vp, KEY_ESCAPE)
				await _x11_key(vp, KEY_ESCAPE)
	check(jaw_dead == 0, "K2 rail Jaw 0/10 dead (dead %d)" % jaw_dead)

	if sm == null or not sm.active:
		await FilmUI.enter_sketch(ctx)
		sm = ctx.main.sketch_mode
	var circle_dead := 0
	if sm != null and sm.active:
		var circle := FilmUI.find_sketch_tool_button(ctx.main, "Circle")
		check(circle != null and circle.is_visible_in_tree(), "K2 rail Circle is visible")
		var cpos := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(6.0, -14.0)))
		check(FilmUI.require_on_screen(ctx, cpos, "K2 circle canvas"), "K2 circle canvas is on screen")
		if circle != null:
			for i in 10:
				if not sm.active:
					await FilmUI.enter_sketch(ctx)
					sm = ctx.main.sketch_mode
					circle = FilmUI.find_sketch_tool_button(ctx.main, "Circle")
					cpos = FilmUI.model_to_screen(ctx, sm.to_model(Vector2(6.0, -14.0)))
				await _trial_click(vp, circle.get_global_rect().get_center(), i % 2 == 1)
				var mark3 := _status_log.size()
				await _trial_click(vp, cpos, i % 2 == 1)
				var ok3 := _saw_since(mark3, "Circle — centre set, click the rim or type a radius")
				if not ok3:
					circle_dead += 1
					print("  dead circle trial %d disp=%s status=%s" % [i + 1, _last_disp(), _tail()])
				await _x11_key(vp, KEY_ESCAPE)
	check(circle_dead == 0, "K2 rail Circle 0/10 dead (dead %d)" % circle_dead)

	if sm == null or not sm.active:
		await FilmUI.enter_sketch(ctx)
		sm = ctx.main.sketch_mode
	var select_dead := 0
	if sm != null and sm.active:
		sm.sketch.add_line(-20.0, 0.0, 20.0, 0.0)
		sm._redraw()
		await _zoom(ctx, sm.to_model(Vector2.ZERO), 50.0, false)
		var centre := FilmUI.model_to_screen(ctx, sm.to_model(Vector2.ZERO))
		var off := centre + Vector2(0, 3)
		check(FilmUI.require_on_screen(ctx, off, "K2 thin line"), "K2 3 px off the line is on screen")
		var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
		check(sel != null and sel.is_visible_in_tree(), "K2 rail Select is visible")
		var clear_at := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(0.0, 30.0)))
		if sel != null:
			for i in 10:
				await _trial_click(vp, sel.get_global_rect().get_center(), i % 2 == 1)
				await _trial_click(vp, off, i % 2 == 1)
				var ok4 := sm.selected.size() == 1
				if not ok4:
					select_dead += 1
					print("  dead select trial %d selected=%d disp=%s" % [i + 1, sm.selected.size(), _last_disp()])
				# A second click on the same line toggles it off. Clear on empty canvas.
				await _x11_click_screen(vp, clear_at)
	check(select_dead == 0, "K2 rail Select thin line 0/10 dead (dead %d)" % select_dead)
	check(dead + jaw_dead + circle_dead + select_dead == 0, "K2 zero dead trials")
	await _shutdown(ctx)


func test_k3_dim_halo() -> void:
	print("- K3 dimension halo")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "K3 sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	var cid: String = sm.sketch.add_circle(0.0, 0.0, 15.0)
	var rcid: String = sm.sketch.add_constraint("radius", [{"entity": cid, "role": "self"}], 15.0)
	sm._record_dimension("radius", [cid], 15.0, rcid)
	sm._redraw()
	await _zoom(ctx, sm.to_model(Vector2.ZERO), 80.0, false)
	await process_frame
	var spot := _halo_outside_text(ctx, sm)
	check(spot != Vector2.INF, "K3 found a halo point outside the text rect")
	if spot == Vector2.INF:
		await _shutdown(ctx)
		return
	var circle := FilmUI.find_sketch_tool_button(ctx.main, "Circle")
	await _x11_click(circle)
	await process_frame
	var before := sm.sketch.entity_ids().size()
	await _x11_click_screen(vp, spot)
	await process_frame
	check(_last_disp() == "sketch-click:CIRCLE",
			"K3 halo click is sketch-click:CIRCLE (got `%s`)" % _last_disp())
	check(not _last_disp().begins_with("drop:dim-label"),
			"K3 halo click is not drop:dim-label (got `%s`)" % _last_disp())
	var placed := sm.has_pending_draw_point() or sm.sketch.entity_ids().size() > before
	check(placed, "K3 halo click places circle geometry (pending=%s entities %d->%d)" % [
			str(sm.has_pending_draw_point()), before, sm.sketch.entity_ids().size()])
	await _shutdown(ctx)


func test_marquee() -> void:
	print("- M1-M6 marquee")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var ix: ViewportInteraction = ctx.main.interaction
	check(sm != null and sm.active, "M sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	var q: Array[String] = [
		sm.sketch.add_line(0.0, 0.0, 40.0, 0.0),
		sm.sketch.add_line(40.0, 0.0, 40.0, 20.0),
		sm.sketch.add_line(40.0, 20.0, 0.0, 20.0),
		sm.sketch.add_line(0.0, 20.0, 0.0, 0.0),
	]
	var circ: String = sm.sketch.add_circle(90.0, 10.0, 8.0)
	sm._redraw()
	await _zoom(ctx, sm.to_model(Vector2(45.0, 10.0)), 140.0, false)
	var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	await _x11_click(sel)
	await process_frame
	check(sm.tool == SketchMode.Tool.SELECT, "M Select tool is armed")

	var quad_a := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(-6.0, -6.0)))
	var quad_b := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(46.0, 26.0)))
	check(FilmUI.require_on_screen(ctx, quad_a, "M1 start") and FilmUI.require_on_screen(ctx, quad_b, "M1 end"),
			"M1 window drag is on screen")
	var mark := _status_log.size()
	await _drag_screen(vp, quad_a, quad_b, false)
	var want := _window_ids(ctx, sm, Rect2(quad_a, quad_b - quad_a).abs())
	var got: Array[String] = []
	for id in sm.selected:
		got.append(str(id))
	got.sort()
	want.sort()
	check(got == want, "M1 window selection matches samples (got %s want %s)" % [str(got), str(want)])
	check(not sm.selected.has(circ), "M1 circle outside the window is not selected")
	var n_win := want.size()
	if n_win == 1:
		check(_saw_since(mark, "Selected 1 sketch entity"), "M1 status Selected 1 sketch entity")
	else:
		check(_saw_since(mark, "Selected %d sketch entities" % n_win),
				"M1 status Selected %d sketch entities (log %s)" % [n_win, _tail()])

	# M2 crossing: start clear of the circle's pick radius, across the right
	# wall (x=40) and the circle rim (centre 90, r=8).
	var cross_a := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(130.0, 8.0)))
	var cross_b := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(30.0, 12.0)))
	check(cross_a.x > cross_b.x, "M2 drag is right to left")
	mark = _status_log.size()
	await _drag_screen(vp, cross_a, cross_b, false)
	var rect2 := Rect2(cross_a, cross_b - cross_a).abs()
	check(sm.selected.has(q[1]) and sm.selected.has(circ),
			"M2 crossing selects the wall and the circle (selected %s)" % str(sm.selected))
	check(_saw_since(mark, "Selected "), "M2 status begins with Selected ")

	# M3 Shift+drag adds the quad to the circle. A click on an already
	# selected circle toggles it off, so clear first, then pick the centre.
	var empty_m3 := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(-30.0, 40.0)))
	await _x11_click_screen(vp, empty_m3)
	await process_frame
	var circ_pt := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(98.0, 10.0)))
	await _x11_click_screen(vp, circ_pt)
	await process_frame
	check(sm.selected.has(circ), "M3 prior click selects the circle")
	mark = _status_log.size()
	await _drag_screen(vp, quad_a, quad_b, true)
	var kept_circle := sm.selected.has(circ)
	var kept_quad := true
	for id in q:
		if not sm.selected.has(id):
			kept_quad = false
	check(kept_circle and kept_quad, "M3 Shift+window adds the quad and keeps the circle (selected %s)" % str(sm.selected))
	check(_saw_since(mark, "Selected "), "M3 status begins with Selected ")

	# M4 press-release on empty canvas clears.
	var empty := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(-30.0, 40.0)))
	check(FilmUI.require_on_screen(ctx, empty, "M4 empty"), "M4 empty canvas is on screen")
	await _x11_click_screen(vp, empty)
	await process_frame
	check(sm.selected.is_empty(), "M4 click on empty canvas clears the selection (got %s)" % str(sm.selected))

	# M5 press on a line and drag moves it; no marquee.
	var line_id: String = q[0]
	var before_info: Dictionary = sm.sketch.entity_info(line_id)
	var on_line := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(20.0, 0.0)))
	var dragged := on_line + Vector2(0, 40)
	await _drag_screen(vp, on_line, dragged, false)
	var after_info: Dictionary = sm.sketch.entity_info(line_id)
	var moved := false
	if before_info.has("start") and after_info.has("start"):
		moved = (after_info["start"] as Vector2).distance_to(before_info["start"]) > 0.5 \
				or (after_info["end"] as Vector2).distance_to(before_info["end"]) > 0.5
	check(moved, "M5 dragging a line moves it")
	check(_last_disp() == "sketch-drag:SELECT",
			"M5 press on a line is sketch-drag:SELECT (got `%s`)" % _last_disp())
	var box_live := false
	if "_sketch_box_active" in ix:
		box_live = bool(ix.get("_sketch_box_active"))
	check(ix._box_rect.size == Vector2.ZERO and not box_live, "M5 no selection box remains")

	# M6 window the (moved) quad lines that are fully inside, then Delete.
	# Rebuild a clean quad so M1's geometry is the delete target.
	await _shutdown(ctx)
	ctx = await _boot()
	await FilmUI.enter_sketch(ctx)
	sm = ctx.main.sketch_mode
	vp = ctx.main.get_viewport()
	q = [
		sm.sketch.add_line(0.0, 0.0, 40.0, 0.0),
		sm.sketch.add_line(40.0, 0.0, 40.0, 20.0),
		sm.sketch.add_line(40.0, 20.0, 0.0, 20.0),
		sm.sketch.add_line(0.0, 20.0, 0.0, 0.0),
	]
	circ = sm.sketch.add_circle(90.0, 10.0, 8.0)
	sm.dimensions.append({"type": "distance", "ids": [q[0]], "value": 40.0, "cid": ""})
	sm._redraw()
	await _zoom(ctx, sm.to_model(Vector2(45.0, 10.0)), 140.0, false)
	sel = FilmUI.find_sketch_tool_button(ctx.main, "Select")
	await _x11_click(sel)
	await process_frame
	quad_a = FilmUI.model_to_screen(ctx, sm.to_model(Vector2(-6.0, -6.0)))
	quad_b = FilmUI.model_to_screen(ctx, sm.to_model(Vector2(46.0, 26.0)))
	await _drag_screen(vp, quad_a, quad_b, false)
	var removed: Array[String] = []
	for id in sm.selected:
		removed.append(str(id))
	check(removed.size() >= 4, "M6 window selected the quad (got %d)" % removed.size())
	mark = _status_log.size()
	await _x11_key(vp, KEY_DELETE)
	var gone := true
	for id in removed:
		if sm.sketch.entity_ids().has(id):
			gone = false
	check(gone, "M6 Delete removes the windowed entities")
	var orphan := false
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		for eid in dim.get("ids", []):
			if removed.has(str(eid)):
				orphan = true
	check(not orphan, "M6 dimensions do not reference a removed entity")
	check(_saw_since(mark, "Deleted %d" % removed.size()),
			"M6 status Deleted %d (log %s)" % [removed.size(), _tail()])
	check(sm.sketch.entity_ids().has(circ), "M6 the circle outside the window remains")
	await _shutdown(ctx)


func test_w1_wording() -> void:
	print("- W1 body / face / edge / one entity")
	var ctx := await _boot()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	await process_frame
	ctx.view.clear_selection()
	await _zoom(ctx, Vector3(0, 0, 10), 80.0, true)
	var vp: Viewport = ctx.main.get_viewport()
	var face_pt := FilmUI.model_to_screen(ctx, Vector3(0, 0, 10))
	check(FilmUI.require_on_screen(ctx, face_pt, "W1 face"), "W1 face pick is on screen")
	await _x11_key(vp, KEY_ESCAPE)
	var mark := _status_log.size()
	await _x11_click_screen(vp, face_pt)
	await process_frame
	check(ctx.view.selected_body == body and ctx.view.selected_face == "" and ctx.view.selected_edge == "",
			"W1 first click selects the body")
	check(_saw_since(mark, "Selected body "), "W1 status Selected body  (log %s)" % _tail())
	mark = _status_log.size()
	await _x11_click_screen(vp, face_pt)
	await process_frame
	check(ctx.view.selected_face != "", "W1 second click selects a face")
	check(_saw_since(mark, "Selected face "), "W1 status Selected face  (log %s)" % _tail())
	var edge_pt := _top_edge_screen(ctx, face_pt)
	check(FilmUI.require_on_screen(ctx, edge_pt, "W1 edge"), "W1 edge pick is on screen")
	mark = _status_log.size()
	await _x11_click_screen(vp, edge_pt)
	await process_frame
	check(ctx.view.selected_edge != "", "W1 click near an edge selects an edge")
	check(_saw_since(mark, "Selected edge "), "W1 status Selected edge  (log %s)" % _tail())

	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "W1 sketch is active")
	if sm != null and sm.active:
		sm.sketch.add_line(0.0, 0.0, 10.0, 0.0)
		sm._redraw()
		await process_frame
		mark = _status_log.size()
		await _push_key(vp, KEY_A, true, false)
		check(sm.selected.size() == 1, "W1 Ctrl+A selects the one entity")
		check(_saw_since(mark, "Selected 1 sketch entity"),
				"W1 status Selected 1 sketch entity (log %s)" % _tail())
	await _shutdown(ctx)


func test_s1_smart_dim_points() -> void:
	print("- S1 Smart Dim adds no point")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "S1 sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(40.0, 0.0, 10.0)
	sm._redraw()
	await _zoom(ctx, sm.to_model(Vector2(20.0, 0.0)), 80.0, false)
	var before := _point_ids(sm)
	var dim_btn := FilmUI.find_sketch_tool_button(ctx.main, "Smart Dim")
	check(dim_btn != null and dim_btn.is_visible_in_tree(), "S1 rail Smart Dim is visible")
	await _x11_click(dim_btn)
	await process_frame
	var c1 := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(0.0, 0.0)))
	var c2 := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(40.0, 0.0)))
	check(FilmUI.require_on_screen(ctx, c1, "S1 c1") and FilmUI.require_on_screen(ctx, c2, "S1 c2"),
			"S1 centres are on screen")
	await _x11_click_screen(vp, c1)
	await process_frame
	await _x11_click_screen(vp, c2)
	await process_frame
	var after := _point_ids(sm)
	var fresh: Array[String] = []
	for id in after:
		if not before.has(id):
			fresh.append(id)
	check(fresh.is_empty(), "S1 Smart Dim adds no point entity (new %s)" % str(fresh))
	await _shutdown(ctx)


func _point_ids(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "point":
			out.append(str(id))
	return out


func _halo_outside_text(ctx: FilmContext, sm: SketchMode) -> Vector2:
	if sm.dimensions.is_empty():
		return Vector2.INF
	var ix: ViewportInteraction = ctx.main.interaction
	var cam: Camera3D = ctx.main.camera
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		var lp: Variant = dim.get("label_pos", null)
		if not (lp is Vector2) and sm.has_method("_dimension_label_pos2"):
			lp = sm._dimension_label_pos2(dim)
		if lp == null or not (lp is Vector2):
			continue
		var world: Vector3 = sm.to_global(sm.to_model(lp))
		if sm.has_method("_dimension_label_world"):
			world = sm._dimension_label_world(lp)
		var anchor := cam.unproject_position(world)
		# 22 px is the screen halo; 6 mm is the sketch halo. A zoomed label's
		# padded text rect can swallow the 22 px ring, so keep walking out.
		for radius in [16.0, 22.0, 30.0, 40.0, 52.0, 64.0]:
			for step in 36:
				var screen: Vector2 = anchor + Vector2.from_angle(float(step) / 24.0 * TAU) * radius
				if not FilmUI.is_on_screen(ctx, screen, 8.0):
					continue
				var ray: Array = ix._model_ray(screen)
				var uv: Variant = sm.ray_to_sketch(ray[0], ray[1])
				if uv == null:
					continue
				var p2: Vector2 = uv
				if sm.dimension_hit(p2, true) < 0 and sm.dimension_hit(p2, false) >= 0:
					return screen
	return Vector2.INF


## Screen point on the already-selected top face, within the edge pick tolerance.
func _top_edge_screen(ctx: FilmContext, face_pt: Vector2) -> Vector2:
	var view: DocumentView = ctx.view
	var ix: ViewportInteraction = ctx.main.interaction
	var cam: Camera3D = ctx.main.camera
	var face := view.selected_face
	# +Y of this top view lands on the status bar. Walk in from the -Y edge.
	for step in range(1, 18):
		var y := -10.0 + float(step) * 0.35
		var sp := FilmUI.model_to_screen(ctx, Vector3(0.0, y, 10.0))
		if not FilmUI.is_on_screen(ctx, sp, 12.0):
			continue
		if ix._over_chrome(sp):
			continue
		var ray: Array = ix._model_ray(sp)
		var hit: Dictionary = view.pick_info(ray[0], ray[1])
		if hit.is_empty():
			continue
		if str(hit.get("face", "")) != face:
			continue
		var edge := view.edge_near_point(str(hit.get("body", "")), hit.get("point", Vector3.ZERO), 2.5, cam)
		if edge != "":
			return sp
	return face_pt


func _window_ids(ctx: FilmContext, sm: SketchMode, rect: Rect2) -> Array[String]:
	var out: Array[String] = []
	var cam: Camera3D = ctx.main.camera
	for id in sm.sketch.entity_ids():
		var pts := _screen_samples(sm, cam, sm.sketch.entity_info(id))
		if pts.is_empty():
			continue
		var all_in := true
		for p in pts:
			if not rect.has_point(p):
				all_in = false
				break
		if all_in:
			out.append(str(id))
	return out


func _screen_samples(sm: SketchMode, cam: Camera3D, info: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if cam == null:
		return out
	match str(info.get("type", "")):
		"line":
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			var sa := cam.unproject_position(sm.to_global(sm.to_model(a)))
			var sb := cam.unproject_position(sm.to_global(sm.to_model(b)))
			out.append(sa)
			var dist := sa.distance_to(sb)
			var n := int(ceil(dist / 8.0))
			for i in range(1, n):
				out.append(sa.lerp(sb, float(i) / float(n)))
			out.append(sb)
		"circle":
			var c: Vector2 = info["center"]
			var r: float = info["radius"]
			for i in 48:
				var ang := TAU * float(i) / 48.0
				var p := c + Vector2.from_angle(ang) * r
				out.append(cam.unproject_position(sm.to_global(sm.to_model(p))))
		"arc":
			var c2: Vector2 = info["center"]
			var r2: float = info["radius"]
			var a0: float = info["start_angle"]
			var a1: float = info["end_angle"]
			if a1 < a0:
				a1 += TAU
			for i in 48:
				var ang2 := lerpf(a0, a1, float(i) / 47.0)
				var p2 := c2 + Vector2.from_angle(ang2) * r2
				out.append(cam.unproject_position(sm.to_global(sm.to_model(p2))))
		"point":
			var pt: Vector2 = info["position"]
			out.append(cam.unproject_position(sm.to_global(sm.to_model(pt))))
	return out


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
	_disp_log.clear()
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.interaction != null and main.interaction.has_signal("click_disposition"):
		main.interaction.click_disposition.connect(_on_disp)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)


func _on_disp(text: String) -> void:
	_disp_log.append(text)


func _last_disp() -> String:
	var ix_text := ""
	if not _disp_log.is_empty():
		ix_text = _disp_log[_disp_log.size() - 1]
	return ix_text


func _saw_since(mark: int, prefix: String) -> bool:
	for i in range(mark, _status_log.size()):
		if str(_status_log[i]).begins_with(prefix):
			return true
	return false


func _tail() -> String:
	if _status_log.is_empty():
		return "[]"
	var n := maxi(_status_log.size() - 4, 0)
	return str(_status_log.slice(n))


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float, top: bool) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if top:
		cam.yaw = PI
		cam.pitch = deg_to_rad(89.0)
	elif sm != null and sm.active:
		var nrm: Vector3 = sm.plane_normal()
		if nrm.length_squared() > 1e-8:
			cam.yaw = atan2(nrm.x, -nrm.y)
			cam.pitch = clampf(asin(clampf(nrm.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
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


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		check(false, "click target exists")
		return
	await _x11_click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	await _trial_click(vp, pos, false)


func _trial_click(vp: Viewport, pos: Vector2, split: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	if split:
		await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	if split:
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _drag_screen(vp: Viewport, a: Vector2, b: Vector2, shift: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	down.shift_pressed = shift
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	var steps := 6
	var prev := a
	for i in range(1, steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		mv.relative = p - prev
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.shift_pressed = shift
		vp.push_input(mv)
		prev = p
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	up.shift_pressed = shift
	vp.push_input(up)
	await process_frame


func _x11_key(vp: Viewport, code: Key) -> void:
	await _push_key(vp, code, false, false)


func _push_key(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame
