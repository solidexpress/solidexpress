# Rung 4 WP7 — perimeter circle tangent to two construction lines, then Ø30.
# Three points that miss lines stay a circumcircle. Diameter 0 adds nothing.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_tangent_circle.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")


func _init() -> void:
	print("rung04 tangent circle")
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
	await _tangent(ctx)
	await _circum(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _tangent(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await _line(ctx, Vector2(0, 0), Vector2(40, 0))
	await _line(ctx, Vector2(0, 0), Vector2(0, 40))
	await _make_construction(ctx, Vector2(20, 0))
	await _make_construction(ctx, Vector2(0, 20))
	_lock_lines(sm)
	var before := sm.sketch.entity_ids().size()
	await _perimeter(ctx, Vector2(20, 0), Vector2(0, 20), Vector2(10, 10))
	check(sm.sketch.entity_ids().size() == before + 1, "tangent circle added")
	check(_tangent_count(sm) == 2, "two tangent constraints (got %d)" % _tangent_count(sm))
	check(_lines_are_construction(sm), "lines still construction")
	await _diameter(ctx, Vector2(20, 10), 30.0)
	var circ := _profile_circle(sm)
	check(circ != "", "profile circle remains")
	if circ == "":
		return
	var info: Dictionary = sm.sketch.entity_info(circ)
	var center: Vector2 = info["center"]
	var radius := float(info["radius"])
	check(absf(radius - 15.0) <= 0.2, "radius 15 (got %.4f)" % radius)
	check(_inset(sm, center) <= 0.2, "centre inset 15 on both lines (err %.4f)" % _inset(sm, center))
	check(center.x > 1.0 and center.y > 1.0, "centre is on the clicked side (%.2f, %.2f)" % [center.x, center.y])
	var n := sm.sketch.entity_ids().size()
	await _diameter(ctx, center + Vector2(radius, 0), 0.0)
	var after: Dictionary = sm.sketch.entity_info(circ)
	check(sm.sketch.entity_ids().size() == n, "diameter 0 adds nothing")
	check(absf(float(after.get("radius", 0.0)) - 15.0) <= 0.2, "diameter 0 leaves the circle")
	check(str(ctx.main.status_label.text).contains("positive"),
			"diameter 0 refused (%s)" % ctx.main.status_label.text)


func _circum(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm.active:
		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
		if exit_btn != null:
			await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
			await process_frame
	ctx.view.new_document()
	await process_frame
	await FilmUI.enter_sketch(ctx)
	sm = ctx.main.sketch_mode
	await _perimeter(ctx, Vector2(0, 0), Vector2(10, 0), Vector2(0, 10))
	check(_tangent_count(sm) == 0, "circumcircle adds no tangents")
	var circ := _profile_circle(sm)
	check(circ != "", "circumcircle exists")
	if circ == "":
		return
	var info: Dictionary = sm.sketch.entity_info(circ)
	var center: Vector2 = info["center"]
	check(center.distance_to(Vector2(5, 5)) <= 0.3, "circumcentre (%.2f, %.2f)" % [center.x, center.y])
	check(absf(float(info["radius"]) - Vector2(5, 5).distance_to(Vector2.ZERO)) <= 0.3,
			"circumradius")


func _line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, a, "Line start")
	await FilmUI.click_sketch(ctx, sm, b, "Line end")


func _make_construction(ctx: FilmContext, on_line: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(25, 12), "Clear selection")
	await FilmUI.click_sketch(ctx, sm, on_line, "Select line")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Construction")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Construction", "Toggle construction"))
	await process_frame


func _lock_lines(sm: SketchMode) -> void:
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) != "line":
			continue
		sm.sketch.add_constraint("fix", [{"entity": str(id), "role": "self"}], 0.0)


func _perimeter(ctx: FilmContext, a: Vector2, b: Vector2, side: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Perimeter")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Perimeter", "Perimeter variant"))
	await FilmUI.click_sketch(ctx, sm, a, "First line")
	await FilmUI.click_sketch(ctx, sm, b, "Second line")
	await FilmUI.click_sketch(ctx, sm, side, "Side")
	await process_frame


func _diameter(ctx: FilmContext, on_rim: Vector2, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmUI.click_sketch(ctx, sm, on_rim, "Circle diameter")
	await process_frame
	var di := _diameter_index(sm)
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	if lp == null:
		return
	await FilmUI.click_sketch(ctx, sm, lp as Vector2, "Edit diameter")
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await process_frame
		await process_frame


func _diameter_index(sm: SketchMode) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "diameter":
			return i
	return -1


func _profile_circle(sm: SketchMode) -> String:
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle" and not bool(info.get("construction", false)):
			return str(id)
	return ""


func _lines_are_construction(sm: SketchMode) -> bool:
	var n := 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		if not bool(info.get("construction", false)):
			return false
		n += 1
	return n == 2


func _tangent_count(sm: SketchMode) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		if str(sm.sketch.constraint_info(cid).get("type", "")) == "tangent":
			n += 1
	return n


func _inset(sm: SketchMode, center: Vector2) -> float:
	var err := 0.0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		err = maxf(err, absf(SketchGeom.point_line_distance(center, info["start"], info["end"]) - 15.0))
	return err
