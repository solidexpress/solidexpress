# WP-V8: ellipse/arc and the 12-point box-end star use rung-6 colour grammar.
# Blue (COLOR_ENTITY) → near-white “black” (COLOR_CONSTRAINED) when DOF=0.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_color_grammar_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("sketch colour grammar (VS #1 / 12-point)")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	test_ellipse_arc_underdefined(main)
	test_twelve_point_star_blue_to_black(main)
	finish()


func test_ellipse_arc_underdefined(main) -> void:
	print("- ellipse and arc draw COLOR_ENTITY when under-defined")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	var eid: String = sm.sketch.add_ellipse(0.0, 0.0, 16.5, 10.0, 0.0)
	var aid: String = sm.sketch.add_arc(40.0, 0.0, 8.0, 0.0, PI)
	sm.run_solve()
	var einfo: Dictionary = sm.sketch.entity_info(eid)
	var ainfo: Dictionary = sm.sketch.entity_info(aid)
	check(str(einfo.get("type", "")) == "ellipse", "ellipse entity type")
	check(str(ainfo.get("type", "")) == "arc", "arc entity type")
	check(sm._entity_draw_color(einfo, eid) == sm.COLOR_ENTITY,
			"under-defined ellipse is COLOR_ENTITY blue")
	check(sm._entity_draw_color(ainfo, aid) == sm.COLOR_ENTITY,
			"under-defined arc is COLOR_ENTITY blue")
	sm.exit_sketch()


func test_twelve_point_star_blue_to_black(main) -> void:
	print("- 12-point star blue → black when fully defined")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	var ids: Array[String] = []
	var outer := 25.0 / sqrt(3.0)
	var inner := (25.0 * 0.5) / cos(deg_to_rad(15.0))
	var pts: Array[Vector2] = []
	for k in 24:
		var ang := deg_to_rad(float(k) * 15.0)
		var radius := outer if (k % 2) == 0 else inner
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	for i in 24:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 24]
		ids.append(sm.sketch.add_line(a.x, a.y, b.x, b.y))
	var ellipse_id: String = sm.sketch.add_ellipse(0.0, 0.0, 16.5, 10.0, 0.0)
	var arc_id: String = sm.sketch.add_arc(0.0, 0.0, inner, 0.0, TAU)
	sm.run_solve()
	check(sm.last_dofs != 0, "star starts under-defined (dofs=%d)" % sm.last_dofs)
	check(sm._entity_draw_color(sm.sketch.entity_info(ids[0]), ids[0]) == sm.COLOR_ENTITY,
			"under-defined star edge is blue")
	check(sm._entity_draw_color(sm.sketch.entity_info(ellipse_id), ellipse_id) == sm.COLOR_ENTITY,
			"under-defined ellipse on the star sketch is blue")
	check(sm._entity_draw_color(sm.sketch.entity_info(arc_id), arc_id) == sm.COLOR_ENTITY,
			"under-defined arc on the star sketch is blue")
	# Whole-sketch grammar: DOF 0 flips every entity type, including the star.
	sm.last_dofs = 0
	sm.last_solve_status = "success"
	check(sm._entity_draw_color(sm.sketch.entity_info(ids[0]), ids[0]) == sm.COLOR_CONSTRAINED,
			"fully defined star edge is COLOR_CONSTRAINED (near-white black)")
	check(sm._entity_draw_color(sm.sketch.entity_info(ellipse_id), ellipse_id) == sm.COLOR_CONSTRAINED,
			"fully defined ellipse is COLOR_CONSTRAINED")
	check(sm._entity_draw_color(sm.sketch.entity_info(arc_id), arc_id) == sm.COLOR_CONSTRAINED,
			"fully defined arc is COLOR_CONSTRAINED")
	sm.exit_sketch()
	_test_box_end_fully_defined(main)


func _test_box_end_fully_defined(main) -> void:
	print("- box-end square fully_define is black")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	var pb: String = sm.sketch.add_line(0, 0, 25, 0)
	var pr: String = sm.sketch.add_line(25, 0, 25, 25)
	var pt: String = sm.sketch.add_line(25, 25, 0, 25)
	var pl: String = sm.sketch.add_line(0, 25, 0, 0)
	sm.sketch.add_constraint("coincident", [
		{"entity": pb, "role": "end"}, {"entity": pr, "role": "start"}], 0.0)
	sm.sketch.add_constraint("coincident", [
		{"entity": pr, "role": "end"}, {"entity": pt, "role": "start"}], 0.0)
	sm.sketch.add_constraint("coincident", [
		{"entity": pt, "role": "end"}, {"entity": pl, "role": "start"}], 0.0)
	sm.sketch.add_constraint("coincident", [
		{"entity": pl, "role": "end"}, {"entity": pb, "role": "start"}], 0.0)
	sm.sketch.add_constraint("horizontal", [{"entity": pb, "role": "self"}], 0.0)
	sm.sketch.add_constraint("horizontal", [{"entity": pt, "role": "self"}], 0.0)
	sm.sketch.add_constraint("vertical", [{"entity": pr, "role": "self"}], 0.0)
	sm.sketch.add_constraint("vertical", [{"entity": pl, "role": "self"}], 0.0)
	sm.sketch.add_constraint("distance", [
		{"entity": pb, "role": "start"}, {"entity": pb, "role": "end"}], 25.0)
	sm.sketch.add_constraint("distance", [
		{"entity": pl, "role": "start"}, {"entity": pl, "role": "end"}], 25.0)
	var o: String = sm.sketch.add_point(0, 0)
	sm.sketch.set_construction(o, true)
	sm.sketch.add_constraint("fix", [{"entity": o, "role": "self"}], 0.0)
	sm.sketch.add_constraint("coincident", [
		{"entity": o, "role": "self"}, {"entity": pb, "role": "start"}], 0.0)
	sm.run_solve()
	check(sm.last_dofs == 0, "box-end square DOF=0 (got %d %s)" % [
			sm.last_dofs, sm.last_solve_status])
	check(sm._entity_draw_color(sm.sketch.entity_info(pb), pb) == sm.COLOR_CONSTRAINED,
			"fully defined box-end edge is near-white black")
	sm.exit_sketch()
