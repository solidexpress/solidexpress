# Rung 6 WP5 — real ellipse, 3-click, 35×10, Horizontal on major ends.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_ellipse.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SPAN := 80.0


func _init() -> void:
	print("rung06 ellipse")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("right")
	await process_frame
	OriginPlanes.begin(ctx.main, "Right")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Right sketch is active")
	await _zoom(ctx, Vector3.ZERO, SPAN)
	var rail := FilmUI.find_sketch_tool_button(ctx.main, "Ellipse")
	check(rail != null, "rail label is Ellipse")
	if rail != null:
		check(not str(rail.text).contains("approx"), "rail dropped (approx)")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	await FilmSteps.click_uv(ctx, Vector2(0, 0), "Centre", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(17.5, 0), "Major", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(0, 5), "Minor", SPAN)
	await process_frame
	var ellipses := _ellipses(sm)
	check(ellipses.size() == 1, "one ellipse entity (got %d)" % ellipses.size())
	check(_line_count(sm) == 0, "no 32-gon lines (got %d)" % _line_count(sm))
	var eid := ellipses[0] if ellipses.size() > 0 else ""
	if eid == "":
		return
	var info: Dictionary = sm.sketch.entity_info(eid)
	check(absf(float(info.get("rx", 0.0)) * 2.0 - 35.0) <= 0.3, "major 35 (rx=%.3f)" % float(info.get("rx", 0.0)))
	check(absf(float(info.get("ry", 0.0)) * 2.0 - 10.0) <= 0.3, "minor 10 (ry=%.3f)" % float(info.get("ry", 0.0)))
	await _dim_axis(ctx, info.get("major_start", Vector2(17.5, 0)), 35.0)
	await _dim_axis(ctx, info.get("minor_start", Vector2(0, 5)), 10.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, info.get("major_start", Vector2(17.5, 0)), "Major start")
	var end_screen := FilmUI.sketch_uv_to_screen(ctx, info.get("major_end", Vector2(-17.5, 0)))
	if end_screen != Vector2.ZERO:
		await FilmUI.viewport_click(ctx, end_screen, FilmUICues.alert("Click", "Major end"), true)
	await _click_horizontal(ctx)
	sm.run_solve()
	await process_frame
	info = sm.sketch.entity_info(eid)
	var a: Vector2 = info.get("major_start", Vector2.ZERO)
	var b: Vector2 = info.get("major_end", Vector2.ZERO)
	check(absf(a.y - b.y) <= 0.2, "major ends share Y")
	var pin := sm.sketch.add_point(0.0, 0.0)
	sm.sketch.add_constraint("fix", [{"entity": pin, "role": "self"}], 0.0)
	sm.sketch.add_constraint("coincident", [
		{"entity": eid, "role": "center"},
		{"entity": pin, "role": "self"}], 0.0)
	sm.run_solve()
	await process_frame
	info = sm.sketch.entity_info(eid)
	var c: Vector2 = info.get("center", Vector2.ZERO)
	check(c.distance_to(Vector2.ZERO) <= 0.2, "centre coincident with the pin (got %s)" % str(c))
	check(sm.last_solve_status != "failed",
			"ellipse still solves after coincident (%s)" % sm.last_solve_status)
	check(sm.last_dofs == 0,
			"DOF 0 after coincident-to-a-point (got %d %s)" % [sm.last_dofs, sm.last_solve_status])


func _ellipses(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "ellipse":
			out.append(str(id))
	return out


func _line_count(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _dim_axis(ctx: FilmContext, at: Vector2, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, at, "Axis dim", SPAN)
	await process_frame
	var di := sm.dimensions.size() - 1
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	if lp == null:
		return
	await FilmSteps.click_uv(ctx, lp as Vector2, "Edit axis", SPAN)
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await process_frame
		await process_frame


func _click_horizontal(ctx: FilmContext) -> void:
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := FilmUI.find_button(chrome, "Horizontal")
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Horizontal", "Horizontal relation"))
	await process_frame
