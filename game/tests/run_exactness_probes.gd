# Headless exactness probes (WP-L1). Validation, not a click walk.
# Run: tools/godot/godot --headless --path game --script tests/run_exactness_probes.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("exactness probes")
	test_box_hole()
	test_sketch_circle()
	finish()


func test_box_hole() -> void:
	print("- box + Ø10 hole")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 20.0, 20.0, 10.0, Vector3.ZERO)
	check(box_fid.length() == 36, "box feature")
	var hole_fid: String = doc.graph_add_hole(
		box_fid, "simple", Vector3(10, 10, 10), Vector3(0, 0, -1), 10.0, 0.0, 0.0, 0.0, 0.0, 90.0
	)
	check(hole_fid.length() == 36, "hole feature")
	var feats: Array = doc.graph_features()
	check(feats.size() == 2, "two features")
	var body_id: String = String(feats[0].get("output_body", ""))
	check(body_id.length() == 36, "box output body")
	var report_v: Variant = JSON.parse_string(doc.exactness_report(body_id))
	check(typeof(report_v) == TYPE_DICTIONARY, "body report json")
	var report: Dictionary = report_v
	var edges: Array = report.get("edges", [])
	var circles := 0
	var r5 := false
	for e in edges:
		var edge: Dictionary = e
		if String(edge.get("type", "")) == "GeomAbs_Circle":
			circles += 1
			if abs(float(edge.get("radius", 0.0)) - 5.0) <= 1e-6:
				r5 = true
	check(circles >= 1, "GeomAbs_Circle edge exists")
	check(r5, "circle radius 5")
	var analytic: float = 20.0 * 20.0 * 10.0 - PI * 25.0 * 10.0
	var vol: float = float(report.get("volume", 0.0))
	check(abs(vol - analytic) / analytic < 1e-9, "volume analytic")
	var feats_v: Variant = JSON.parse_string(doc.exactness_report())
	check(typeof(feats_v) == TYPE_DICTIONARY, "full report")
	var feats_report: Dictionary = feats_v
	var hole_params: Dictionary = {}
	for f in feats_report.get("features", []):
		var feat: Dictionary = f
		if String(feat.get("type", "")) == "hole":
			var raw: Variant = feat.get("params", {})
			if typeof(raw) == TYPE_DICTIONARY:
				hole_params = raw
			elif typeof(raw) == TYPE_STRING:
				var parsed: Variant = JSON.parse_string(raw)
				if typeof(parsed) == TYPE_DICTIONARY:
					hole_params = parsed
	check(abs(float(hole_params.get("diameter", 0.0)) - 10.0) < 1e-12, "diameter as written")


func test_sketch_circle() -> void:
	print("- sketch circle")
	var sk := SxSketch.new()
	sk.add_circle(0.0, 0.0, 5.0)
	var report_v: Variant = JSON.parse_string(sk.exactness_report())
	check(typeof(report_v) == TYPE_DICTIONARY, "sketch report")
	var report: Dictionary = report_v
	var ents: Array = report.get("entities", [])
	check(ents.size() == 1, "one entity")
	var ent: Dictionary = ents[0]
	check(String(ent.get("type", "")) == "circle", "type circle")
	check(abs(float(ent.get("radius", 0.0)) - 5.0) < 1e-12, "sketch radius 5")
