# Rung 8 WP-S2 — interpolating spline edit (fit/pole, tangent, comb, undo).
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung08_spline_edit.suite
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("rung08 spline edit")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm.active, "sketch session")
	var fit := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 8), Vector2(20, -4), Vector2(30, 6), Vector2(40, 0)])
	var sid: String = sm.sketch.add_spline(fit)
	sm._set_selected([sid])
	sm._redraw()
	await process_frame
	var info: Dictionary = sm.sketch.entity_info(sid)
	check(str(info.get("type", "")) == "spline", "kernel spline")
	check(int(info.get("point_count", 0)) == 5, "property point count 5")
	check(sm.spline_property_label().find("5") >= 0, "property label has 5")
	check(sm.spline_handle_mode() == "fit", "default fit-point mode")
	sm.set_spline_handle_mode("pole")
	check(sm.spline_handle_mode() == "pole", "toggle to poles")
	sm.set_spline_handle_mode("fit")
	check(sm.spline_handle_mode() == "fit", "toggle back to fit")
	check(sm.toggle_spline_comb(), "comb on")
	check(sm.sketch.spline_comb(sid).size() >= 8, "comb teeth")
	sm.toggle_spline_comb()
	var before: Array = sm.sketch.entity_info(sid).get("fit_points", [])
	sm.sketch.set_spline_fit_point(sid, 2, 20, 12)
	sm._redraw()
	await process_frame
	var mid: Vector2 = sm.sketch.entity_info(sid).get("fit_points")[2]
	check(mid.distance_to(Vector2(20, 12)) <= 1e-4, "fit-point drag applied")
	check(sm.can_undo(), "undo available after drag")
	sm.undo()
	await process_frame
	var after: Array = sm.sketch.entity_info(sid).get("fit_points", [])
	check(after.size() == before.size(), "undo fit count")
	if after.size() == before.size() and before.size() > 2:
		check((after[2] as Vector2).distance_to(before[2] as Vector2) <= 1e-9,
				"undo restores fit points")
	var snap: String = sm.sketch.snapshot()
	sm.sketch.set_spline_fit_point(sid, 1, 11, 9)
	check(sm.sketch.restore(snap), "restore snapshot")
	var loaded: Array = sm.sketch.entity_info(sid).get("fit_points", [])
	check((loaded[1] as Vector2).distance_to(Vector2(10, 8)) <= 1e-9, "save/load fit points")
	var lid: String = sm.sketch.add_line(40, 0, 50, 10)
	sm.sketch.add_constraint("coincident", [
		{"entity": sid, "role": "end"}, {"entity": lid, "role": "start"}], 0.0)
	sm.sketch.add_constraint("tangent", [
		{"entity": sid, "role": "end"}, {"entity": lid, "role": "self"}], 0.0)
	sm.sketch.solve()
	var der: Vector2 = sm.sketch.spline_end_derivative(sid, false)
	var cross := absf(der.x * 10.0 - der.y * 10.0)
	var denom := der.length() * Vector2(10, 10).length()
	check(denom > 1e-9 and cross / denom <= 1e-5, "tangent handle / end derivative")
	sm.exit_sketch()
	finish()
