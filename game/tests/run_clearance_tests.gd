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
	print("clearance language tests")
	test_builtins_and_hole_tracks_clearance()
	test_quick_configs_change_jaw_af_single_model()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func test_builtins_and_hole_tracks_clearance() -> void:
	print("- new doc seeds built-ins; hole Ø tracks clearance + compensation")
	var doc := SxDocument.new()
	# Built-ins present
	var names := {}
	for e in doc.list_variables():
		names[str(e["name"])] = str(e["expr"])
	for k in ["clearance", "hole_compensation", "layer", "nozzle", "jaw_af"]:
		check(names.has(k), "has builtin " + k)
	check(names.get("clearance", "") == "0.3", "clearance default 0.3")
	check(names.get("hole_compensation", "") == "0.2", "hole_compensation default 0.2")
	check(names.get("jaw_af", "") == "10", "jaw_af default 10")

	# Box and hole whose diameter is expression-driven.
	var box_fid: String = doc.graph_add_primitive("box", 20, 20, 10, Vector3.ZERO)
	var body: String = _feature_output_body(doc, box_fid)
	var vol0: float = doc.body_volume(body)
	var hole_fid: String = doc.graph_add_hole(
		box_fid, "simple", Vector3(10, 10, 10), Vector3(0, 0, -1), 1.0, 0.0,
		0.0, 0.0, 0.0, 90.0)
	# Overwrite hole params to use expression on diameter.
	var params: Dictionary = {}
	for f in doc.graph_features():
		if str(f.get("id", "")) == hole_fid:
			params = JSON.parse_string(str(f.get("params", "{}")))
			break
	params["diameter"] = "=jaw_af + clearance + hole_compensation"
	check(doc.graph_set_params(hole_fid, JSON.stringify(params)), "set hole to expr diameter")
	# Compute expected drop with defaults: d = 10 + 0.3 + 0.2
	var d1 := 10.0 + 0.3 + 0.2
	var expected_drop1 := PI * 0.25 * d1 * d1 * 10.0
	var drop1 := vol0 - doc.body_volume(body)
	check(absf(drop1 - expected_drop1) < expected_drop1 * 0.03, "hole drop matches defaults")
	# Increase clearance; hole grows.
	check(doc.set_variable("clearance", "0.6"), "set clearance 0.6")
	var d2 := 10.0 + 0.6 + 0.2
	var expected_drop2 := PI * 0.25 * d2 * d2 * 10.0
	var drop2 := vol0 - doc.body_volume(body)
	check(absf(drop2 - expected_drop2) < expected_drop2 * 0.03, "hole drop tracks clearance")

func test_quick_configs_change_jaw_af_single_model() -> void:
	print("- configs 10/12/14 switch jaw_af only (single model)")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 10, 10, 10, Vector3.ZERO)
	var body: String = _feature_output_body(doc, box_fid)
	# Make 'a' track jaw_af.
	var params: Dictionary = {}
	for f in doc.graph_features():
		if str(f.get("id", "")) == box_fid:
			params = JSON.parse_string(str(f.get("params", "{}")))
			break
	params["a"] = "=jaw_af"
	check(doc.graph_set_params(box_fid, JSON.stringify(params)), "box a = =jaw_af")
	var ids0 := doc.body_ids()
	check(ids0.size() == 1, "one body initially")
	# Seed and switch configs using the Variables panel quick flow emulation.
	check(doc.set_variable("jaw_af", "10"), "jaw_af=10")
	check(doc.save_configuration("10"), "save cfg 10")
	check(doc.set_variable("jaw_af", "14"), "jaw_af=14")
	check(doc.save_configuration("14"), "save cfg 14")
	check(doc.activate_configuration("10"), "activate 10")
	var v10 := doc.body_volume(body)
	check(absf(v10 - 10.0 * 10.0 * 10.0) < 1e-3, "volume with jaw_af=10")
	check(doc.activate_configuration("14"), "activate 14")
	var v14 := doc.body_volume(body)
	check(absf(v14 - 14.0 * 10.0 * 10.0) < 1e-3, "volume with jaw_af=14")
	var ids1 := doc.body_ids()
	check(ids1.size() == 1, "still one body after config switch")

