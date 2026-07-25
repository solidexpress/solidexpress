# Phase B exit: expression-valued sketch dims + variable regen.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_expr_dim_tests.gd
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
	print("sketch expression dim tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_expr_dim_via_sketch_mode(main)
	test_variable_regen_updates_solid(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_expr_dim_via_sketch_mode(main) -> void:
	print("- Smart Dim accepts =w/2")
	main.view.doc.set_variable("w", "40")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	var ln: String = sm.sketch.add_line(0, 0, 10, 0)
	sm.sketch.add_constraint("horizontal", [{"entity": ln, "role": "self"}], 0.0)
	var o: String = sm.sketch.add_point(0, 0)
	sm.sketch.set_construction(o, true)
	sm.sketch.add_constraint("fix", [{"entity": o, "role": "self"}], 0.0)
	sm.sketch.add_constraint("coincident", [
		{"entity": o, "role": "self"}, {"entity": ln, "role": "start"}], 0.0)
	sm._set_selected([ln])
	sm.constrain("distance", 10.0)
	check(sm.dimensions.size() >= 1, "dimension recorded")
	var st: String = sm.set_dimension_value(sm.dimensions.size() - 1, "=w/2")
	check(st != "failed", "expr dim solve ok")
	var info: Dictionary = sm.sketch.entity_info(ln)
	var len: float = info["start"].distance_to(info["end"])
	check(absf(len - 20.0) < 0.05, "line length follows =w/2 (got %s)" % str(len))
	sm.exit_sketch()


func test_variable_regen_updates_solid(main) -> void:
	print("- change variable regenerates extruded solid")
	var doc: SxDocument = main.view.doc
	doc.set_variable("plate_w", "40")
	var sk := SxSketch.new()
	var ln: String = sk.add_line(0, 0, 40, 0)
	var r: String = sk.add_line(40, 0, 40, 20)
	var t: String = sk.add_line(40, 20, 0, 20)
	var l: String = sk.add_line(0, 20, 0, 0)
	sk.add_constraint("coincident", [
		{"entity": ln, "role": "end"}, {"entity": r, "role": "start"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": r, "role": "end"}, {"entity": t, "role": "start"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": t, "role": "end"}, {"entity": l, "role": "start"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": l, "role": "end"}, {"entity": ln, "role": "start"}], 0.0)
	sk.add_constraint("horizontal", [{"entity": ln, "role": "self"}], 0.0)
	sk.add_constraint("horizontal", [{"entity": t, "role": "self"}], 0.0)
	sk.add_constraint("vertical", [{"entity": r, "role": "self"}], 0.0)
	sk.add_constraint("vertical", [{"entity": l, "role": "self"}], 0.0)
	var cid: String = sk.add_constraint("distance", [
		{"entity": ln, "role": "start"}, {"entity": ln, "role": "end"}], 40.0)
	sk.set_constraint_expr(cid, "=plate_w")
	sk.add_constraint("distance", [
		{"entity": l, "role": "start"}, {"entity": l, "role": "end"}], 20.0)
	var o: String = sk.add_point(0, 0)
	sk.set_construction(o, true)
	sk.add_constraint("fix", [{"entity": o, "role": "self"}], 0.0)
	sk.add_constraint("coincident", [
		{"entity": o, "role": "self"}, {"entity": ln, "role": "start"}], 0.0)
	var sk_fid: String = doc.graph_add_sketch(sk)
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 5.0, false, "new", "")
	check(ex_fid != "", "extrude created")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == ex_fid:
			body = str(f.get("output_body", ""))
	var vol0: float = doc.body_volume(body)
	check(vol0 > 100.0, "initial volume")
	doc.set_variable("plate_w", "80")
	doc.graph_regenerate()
	var vol1: float = doc.body_volume(body)
	check(vol1 > vol0 * 1.5, "variable change grows solid (%.1f -> %.1f)" % [vol0, vol1])
