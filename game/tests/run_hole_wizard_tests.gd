# Headless smoke: multi-point Hole Wizard via graph_add_holes.
# Run: tools/godot/godot --headless --path game --script tests/run_hole_wizard_tests.gd
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


func _feature_output_body(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("output_body", ""))
	return ""


func _init() -> void:
	print("hole wizard binding tests")
	test_graph_add_holes_two_points()
	test_graph_add_hole_single_still_works()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_graph_add_holes_two_points() -> void:
	print("- graph_add_holes: box 40x40x10, two Ø6 through")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 40, 40, 10, Vector3.ZERO)
	check(box_fid != "", "box feature")
	var body: String = _feature_output_body(doc, box_fid)
	check(body != "", "box output body")
	var vol0: float = doc.body_volume(body)
	check(absf(vol0 - 16000.0) < 1e-3, "solid box volume 16000")

	var positions := PackedVector3Array()
	positions.append(Vector3(10, 10, 10))
	positions.append(Vector3(30, 30, 10))
	var hole_fid: String = doc.graph_add_holes(
		box_fid, "simple", positions, Vector3(0, 0, -1), 6.0, 0.0,
		0.0, 0.0, 0.0, 90.0)
	check(hole_fid != "", "graph_add_holes feature id")

	var expected_drop := 2.0 * PI * 9.0 * 10.0
	var drop: float = vol0 - doc.body_volume(body)
	check(absf(drop - expected_drop) < expected_drop * 0.02,
		"volume drop ~2 holes (%.1f vs %.1f)" % [drop, expected_drop])

	# Parametric edit via set_params: diameter drives both holes.
	var params: Dictionary = {}
	for f in doc.graph_features():
		if str(f.get("id", "")) == hole_fid:
			params = JSON.parse_string(str(f.get("params", "{}")))
			break
	check(params.has("positions"), "params include positions array")
	check((params["positions"] as Array).size() == 2, "two positions stored")
	params["diameter"] = 8.0
	check(doc.graph_set_params(hole_fid, JSON.stringify(params)), "set diameter 8")
	var expected_drop2 := 2.0 * PI * 16.0 * 10.0
	drop = vol0 - doc.body_volume(body)
	check(absf(drop - expected_drop2) < expected_drop2 * 0.02,
		"both holes update with diameter (%.1f vs %.1f)" % [drop, expected_drop2])


func test_graph_add_hole_single_still_works() -> void:
	print("- graph_add_hole single position (regression)")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 20, 20, 10, Vector3.ZERO)
	var body: String = _feature_output_body(doc, box_fid)
	var vol0: float = doc.body_volume(body)
	var hole_fid: String = doc.graph_add_hole(
		box_fid, "simple", Vector3(10, 10, 10), Vector3(0, 0, -1), 6.0, 0.0,
		0.0, 0.0, 0.0, 90.0)
	check(hole_fid != "", "graph_add_hole feature id")
	var expected_drop := PI * 9.0 * 10.0
	var drop: float = vol0 - doc.body_volume(body)
	check(absf(drop - expected_drop) < expected_drop * 0.02,
		"single hole volume drop (%.1f vs %.1f)" % [drop, expected_drop])
