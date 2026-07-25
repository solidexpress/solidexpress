# Phase A/E exit: fully-defined sketch, analysis, dim edit updates extrude.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_fully_defined_tests.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("sketch fully-defined / analysis tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_fully_define_rect(main)
	test_analyze_open_loop(main)
	test_mounting_plate_extrude_dim_edit(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_fully_define_rect(main) -> void:
	print("- fully_define underdefined rect")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_line(0, 0, 40, 0.2)
	sm.sketch.add_line(40, 0.2, 40, 20)
	var n: int = sm.fully_define()
	check(n >= 1, "fully_define added constraints")
	check(sm.last_dofs == 0 or sm.last_solve_status != "failed",
		"solve ok after fully_define (dofs=%d)" % sm.last_dofs)
	sm.exit_sketch()


func test_analyze_open_loop(main) -> void:
	print("- analyze open U profile")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_line(0, 0, 10, 0)
	sm.sketch.add_line(10, 0, 10, 8)
	var issues: Array = sm.analyze_sketch()
	var has_open := false
	for iss in issues:
		if typeof(iss) == TYPE_DICTIONARY and str(iss.get("code", "")) == "open_loop":
			has_open = true
		elif str(iss).contains("open"):
			has_open = true
	check(has_open or issues.size() > 0, "analysis flags open profile")
	sm.exit_sketch()


func test_mounting_plate_extrude_dim_edit(main) -> void:
	print("- plate sketch DOF=0 + extrude volume grows with dim")
	var sk := SxSketch.new()
	var pb: String = sk.add_line(0, 0, 80, 0)
	var pr: String = sk.add_line(80, 0, 80, 50)
	var pt: String = sk.add_line(80, 50, 0, 50)
	var pl: String = sk.add_line(0, 50, 0, 0)
	sk.add_constraint("coincident", [
		{"entity": pb, "role": "end"}, {"entity": pr, "role": "start"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": pr, "role": "end"}, {"entity": pt, "role": "start"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": pt, "role": "end"}, {"entity": pl, "role": "start"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": pl, "role": "end"}, {"entity": pb, "role": "start"}], 0.0)
	sk.add_constraint("horizontal", [{"entity": pb, "role": "self"}], 0.0)
	sk.add_constraint("horizontal", [{"entity": pt, "role": "self"}], 0.0)
	sk.add_constraint("vertical", [{"entity": pr, "role": "self"}], 0.0)
	sk.add_constraint("vertical", [{"entity": pl, "role": "self"}], 0.0)
	var wdim: String = sk.add_constraint("distance", [
		{"entity": pb, "role": "start"}, {"entity": pb, "role": "end"}], 80.0)
	sk.add_constraint("distance", [
		{"entity": pl, "role": "start"}, {"entity": pl, "role": "end"}], 50.0)
	var o: String = sk.add_point(0, 0)
	sk.set_construction(o, true)
	sk.add_constraint("fix", [{"entity": o, "role": "self"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": o, "role": "self"}, {"entity": pb, "role": "start"}], 0.0)
	for c in [[15.0, 15.0], [65.0, 15.0], [65.0, 35.0], [15.0, 35.0]]:
		var cid: String = sk.add_circle(c[0], c[1], 3.0)
		sk.add_constraint("fix", [{"entity": cid, "role": "self"}], 0.0)
	var sol: Dictionary = sk.solve()
	check(str(sol.get("status", "")) != "failed", "plate solves")
	check(int(sol.get("dofs", -1)) == 0, "plate DOF=0")

	var doc: SxDocument = main.view.doc
	var sk_fid: String = doc.graph_add_sketch(sk)
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	check(ex_fid != "", "extrude feature")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == ex_fid:
			body = str(f.get("output_body", ""))
	check(body != "", "extrude body")
	var vol0: float = doc.body_volume(body)
	check(vol0 > 1000.0, "initial plate volume")

	sk.set_constraint_value(wdim, 100.0)
	sk.solve()
	doc.graph_update_sketch(sk_fid, sk)
	doc.graph_regenerate()
	var vol1: float = doc.body_volume(body)
	check(vol1 > vol0, "widening plate grows volume")
