# Rung 6 WP2 — Tangent Arc adds Tangent + coincident; 3-point on a line.
# Click-built. Empty-space two clicks stay a free arc.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_tangent_arc.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SPAN := 280.0


func _init() -> void:
	print("rung06 tangent arc")
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
	await _profile_r10(ctx)
	await _three_point(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _profile_r10(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector3(20, 110, 0), SPAN)
	await _line(ctx, Vector2(0, 0), Vector2(0, 220))
	await _line(ctx, Vector2(0, 220), Vector2(20, 220))
	await _line(ctx, Vector2(0, 0), Vector2(90, 0))
	var before := _arc_count(sm)
	await _tangent_arc(ctx, Vector2(20, 220), Vector2(30, 210))
	check(_arc_count(sm) == before + 1, "tangent arc added")
	check(_tangent_count(sm) >= 1, "tangent constraint present (got %d)" % _tangent_count(sm))
	var arc := _last_arc(sm)
	check(arc != "", "R10 arc exists")
	if arc == "":
		return
	await _radius_dim(ctx, arc, 10.0)
	var info: Dictionary = sm.sketch.entity_info(arc)
	var r := float(info.get("radius", 0.0))
	check(absf(r - 10.0) <= 0.2, "radius 10 (got %.4f)" % r)
	var start: Vector2 = info["start"]
	var endp: Vector2 = info["end"]
	var host := start if start.distance_to(Vector2(20, 220)) < endp.distance_to(Vector2(20, 220)) else endp
	var tip := endp if host == start else start
	check(host.distance_to(Vector2(20, 220)) <= 0.3, "start on top-horizontal end")
	check(tip.distance_to(Vector2(30, 210)) <= 0.5, "end at (30, 210) got %s" % str(tip))
	var sweep := _ccw_sweep(float(info["start_angle"]), float(info["end_angle"]))
	var quarter := minf(sweep, TAU - sweep)
	check(absf(quarter - PI * 0.5) <= deg_to_rad(5.0),
			"quarter ~90° (got %.1f deg)" % rad_to_deg(quarter))


func _three_point(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var lines_before := _line_count(sm)
	await _line(ctx, Vector2(80, 40), Vector2(80, 0))
	check(_line_count(sm) == lines_before + 1, "vertical for 3-point remains")
	var arcs_before := _arc_count(sm)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ARC)
	await _variant(ctx, "Three Point")
	await FilmSteps.click_uv(ctx, Vector2(80, 40), "3-point start", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(100, 20), "3-point bulge", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(80, 0), "3-point end", SPAN)
	await process_frame
	check(_arc_count(sm) == arcs_before + 1, "3-point arc added")
	check(_line_count(sm) == lines_before + 1, "diameter span still there")
	var arc := _last_arc(sm)
	check(arc != "", "3-point arc exists")
	if arc == "":
		return
	var info: Dictionary = sm.sketch.entity_info(arc)
	check(absf(float(info["radius"]) - 20.0) <= 0.5, "R20 (got %.4f)" % float(info["radius"]))
	var c: Vector2 = info["center"]
	check(absf(c.x - 80.0) <= 0.5, "centre on the vertical (x=%.3f)" % c.x)
	check(_has_point_on_line(sm, arc), "centre/ends constrained to the line")
	var sa := float(info["start_angle"])
	var ea := float(info["end_angle"])
	var mid_ang := sa + _ccw_sweep(sa, ea) * 0.5
	var bulge: Vector2 = c + Vector2.from_angle(mid_ang) * float(info["radius"])
	check(bulge.x > c.x + 5.0, "bulge on the clicked +X side (got %s)" % str(bulge))


func _line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, a, "Line start", SPAN)
	await FilmSteps.click_uv(ctx, b, "Line end", SPAN)


func _tangent_arc(ctx: FilmContext, start: Vector2, endp: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ARC)
	await _variant(ctx, "Tangent")
	await FilmSteps.click_uv(ctx, start, "Tangent start", SPAN)
	await FilmSteps.click_uv(ctx, endp, "Tangent end", SPAN)
	await process_frame


func _variant(ctx: FilmContext, label: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var chip := FilmUI.find_button(chrome, label)
	if chip != null and chip.is_visible_in_tree():
		await FilmUI.click_control(ctx, chip, FilmUICues.alert(label, "%s variant" % label))
	await process_frame


func _radius_dim(ctx: FilmContext, arc_id: String, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var info: Dictionary = sm.sketch.entity_info(arc_id)
	var c: Vector2 = info["center"]
	var rim: Vector2 = info["end"]
	var mid := (c + rim) * 0.5
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, mid, "Arc radius", SPAN)
	await process_frame
	var di := _radius_index(sm)
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	if lp == null:
		return
	await FilmSteps.click_uv(ctx, lp as Vector2, "Edit radius", SPAN)
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await process_frame
		await process_frame


func _radius_index(sm: SketchMode) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "radius":
			return i
	return -1


func _arc_count(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "arc":
			n += 1
	return n


func _line_count(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _last_arc(sm: SketchMode) -> String:
	var last := ""
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "arc":
			last = str(id)
	return last


func _tangent_count(sm: SketchMode) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		if str(sm.sketch.constraint_info(cid).get("type", "")) == "tangent":
			n += 1
	return n


func _has_point_on_line(sm: SketchMode, arc_id: String) -> bool:
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		if str(info.get("type", "")) != "point_on_line":
			continue
		var refs: Array = info.get("refs", [])
		for ref in refs:
			if str(ref.get("entity", "")) == arc_id:
				return true
	return false


func _ccw_sweep(sa: float, ea: float) -> float:
	var s := ea - sa
	while s <= 0.0:
		s += TAU
	while s > TAU:
		s -= TAU
	return s
