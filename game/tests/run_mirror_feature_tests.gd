# Headless smoke: feature-level Mirror (source_feature_ids), not body-only.
# Run: tools/godot/godot --headless --path game --script tests/run_mirror_feature_tests.gd
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
	print("feature-level mirror binding tests")
	test_body_mirror_still_works()
	test_feature_mirror_extrude_cut()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_body_mirror_still_works() -> void:
	print("- body mode graph_add_mirror (regression)")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 10, 10, 10, Vector3.ZERO)
	check(box_fid != "", "box feature")
	var mir_fid: String = doc.graph_add_mirror(
		box_fid, Vector3(15, 0, 0), Vector3(1, 0, 0))
	check(mir_fid != "", "body mirror feature")
	var mirrored: String = _feature_output_body(doc, mir_fid)
	check(mirrored != "", "body mirror output_body")
	check(doc.body_ids().size() == 2, "body mirror keeps original + copy")
	check(absf(doc.body_volume(mirrored) - 1000.0) < 1e-3, "mirrored volume 1000")
	var mp: Dictionary = doc.measure_mass(mirrored)
	check(not mp.is_empty(), "measure_mass on mirrored body")
	var com: Vector3 = mp["center_of_mass"]
	check(absf(com.x - 25.0) < 1e-3, "body mirror COM x≈25 (got %.3f)" % com.x)


func test_feature_mirror_extrude_cut() -> void:
	print("- feature mode: off-center cut mirrored across midplane")
	var doc := SxDocument.new()

	# 40×40×10 box; mid-plane at x=20.
	var base_fid: String = doc.graph_add_primitive("box", 40, 40, 10, Vector3.ZERO)
	check(base_fid != "", "base box feature")
	var body: String = _feature_output_body(doc, base_fid)
	check(body != "", "base output body")
	check(absf(doc.body_volume(body) - 16000.0) < 1e-3, "solid box volume")

	# Off-center hole (r=5 at x=10, y=20) → twin at x=30 after feature mirror.
	var sk := SxSketch.new()
	sk.add_circle(10, 20, 5)
	var sk_fid: String = doc.graph_add_sketch(sk)
	check(sk_fid != "", "cut sketch feature")

	var cut_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "cut", base_fid)
	check(cut_fid != "", "extrude cut feature")
	var vol_one_cut: float = doc.body_volume(body)
	var hole := PI * 25.0 * 10.0
	check(absf(vol_one_cut - (16000.0 - hole)) < 1.0,
		"one cut volume (%.1f vs %.1f)" % [vol_one_cut, 16000.0 - hole])

	var sources := PackedStringArray()
	sources.append(cut_fid)
	var mir_fid: String = doc.graph_add_mirror(
		base_fid, Vector3(20, 0, 0), Vector3(1, 0, 0), sources)
	check(mir_fid != "", "feature mirror feature")
	check(_feature_output_body(doc, mir_fid) == "",
		"feature-mode mirror has no separate output_body")
	check(doc.body_ids().size() == 1, "still a single body after feature mirror")

	var expected := 16000.0 - 2.0 * hole
	var vol: float = doc.body_volume(body)
	check(absf(vol - expected) < 1.0,
		"two-cut volume after feature mirror (%.1f vs %.1f)" % [vol, expected])
	check(vol < vol_one_cut - 100.0, "mirrored cut removed more material")

	var mp: Dictionary = doc.measure_mass(body)
	check(not mp.is_empty(), "measure_mass after feature mirror")
	var com: Vector3 = mp["center_of_mass"]
	check(absf(com.x - 20.0) < 0.05, "COM on midplane x≈20 (got %.3f)" % com.x)
