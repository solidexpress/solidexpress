# Rung 3 WP9 — kernel-built Lesson-1 part, check_rung03 at every stage.
# Validation may call the kernel (export + SxChecker). Paths are globalized.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung03_part_check.gd
extends "res://tests/lib/sx_suite.gd"

const SxChecker = preload("res://tests/lib/sx_checker.gd")

const STAGES := ["base", "boss", "cut", "r5", "rounded", "final"]


func _init() -> void:
	print("rung03 part check")
	_run()
	finish()


func _run() -> void:
	var doc := SxDocument.new()
	var base_ex := _build_base(doc)
	check(base_ex != "", "base extrude feature")
	if base_ex == "":
		return
	_export_and_check(doc, "base")

	var boss_ex := _build_boss(doc, base_ex)
	check(boss_ex != "", "boss extrude feature")
	if boss_ex == "":
		return
	_export_and_check(doc, "boss")

	var cut_ex := _build_cut(doc, base_ex)
	check(cut_ex != "", "cut extrude feature")
	if cut_ex == "":
		return
	_export_and_check(doc, "cut")

	var body := _only_body(doc)
	var r5_edges := _r5_edges(doc, body)
	check(r5_edges.size() == 9, "nine R5 edges (got %d)" % r5_edges.size())
	var r5 := doc.graph_add_fillet(base_ex, r5_edges, 5.0)
	check(r5 != "", "R5 fillet feature")
	if r5 == "":
		return
	_export_and_check(doc, "r5")

	body = _only_body(doc)
	var rims := _annulus_rims(doc, body)
	check(rims.size() == 2, "two annulus rims (got %d)" % rims.size())
	var r15 := doc.graph_add_fillet(base_ex, rims, 1.5)
	check(r15 != "", "R1.5 fillet feature")
	if r15 == "":
		return
	_export_and_check(doc, "rounded")

	body = _only_body(doc)
	var back := _back_face(doc, body)
	check(back != "", "back face z=0")
	if back == "":
		return
	var faces := PackedStringArray([back])
	var sh := doc.graph_add_shell(base_ex, faces, 1.0)
	check(sh != "", "Shell feature")
	if sh == "":
		return
	_export_and_check(doc, "final")


func _build_base(doc: SxDocument) -> String:
	var sk := SxSketch.new()
	sk.add_line(-60, -60, 60, -60)
	sk.add_line(60, -60, 60, 60)
	sk.add_line(60, 60, -60, 60)
	sk.add_line(-60, 60, -60, -60)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	return doc.graph_add_extrude(sk_fid, 30.0, false, "new", "")


func _build_boss(doc: SxDocument, target: String) -> String:
	var sk := SxSketch.new()
	sk.set_plane(Vector3(0, 0, 30), Vector3(1, 0, 0), Vector3(0, 1, 0))
	sk.add_circle(0, 0, 35)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	return doc.graph_add_extrude(sk_fid, 25.0, false, "fuse", target)


func _build_cut(doc: SxDocument, target: String) -> String:
	var sk := SxSketch.new()
	sk.set_plane(Vector3(0, 0, 55), Vector3(1, 0, 0), Vector3(0, 1, 0))
	sk.add_circle(0, 0, 30)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	return doc.graph_add_extrude(sk_fid, -1.0, false, "cut", target, "through_all")


func _export_and_check(doc: SxDocument, stage: String) -> void:
	var tmp := "user://rung03_%s.3mf" % stage
	var path := ProjectSettings.globalize_path(tmp)
	check(not path.begins_with("user://") and not path.begins_with("res://"),
			"%s path is globalized (%s)" % [stage, path])
	check(doc.export_3mf(path), "export_3mf %s" % stage)
	var result := SxChecker.run("rung03", [stage, path])
	var code := int(result["code"])
	var text := str(result["text"])
	check(code == 0, "check_rung03.py %s exit 0 (got %d)" % [stage, code])
	check(text.contains("PASS") or text.contains("passed"),
			"check_rung03.py %s has PASS lines" % stage)
	print("  stage %s checker exit %d" % [stage, code])


func _only_body(doc: SxDocument) -> String:
	var ids: PackedStringArray = doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


func _edge_mid(pts: PackedVector3Array) -> Vector3:
	if pts.is_empty():
		return Vector3.ZERO
	if pts.size() == 1:
		return pts[0]
	return pts[0].lerp(pts[pts.size() - 1], 0.5)


func _r5_edges(doc: SxDocument, body: String) -> PackedStringArray:
	var lines: Dictionary = doc.get_edge_lines(body)
	var vertical := PackedStringArray()
	var front := PackedStringArray()
	var root := PackedStringArray()
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var mid := _edge_mid(pts)
		var length := float(doc.measure_edge_length(str(eid)))
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[pts.size() - 1]
		var dir := (b - a).normalized()
		if absf(dir.z) > 0.99 and absf(length - 30.0) < 0.5:
			if absf(absf(mid.x) - 60.0) < 0.5 and absf(absf(mid.y) - 60.0) < 0.5:
				vertical.append(str(eid))
		elif absf(mid.z - 30.0) < 0.4 and absf(dir.z) < 0.1 and absf(length - 120.0) < 1.0:
			var on_x := absf(absf(mid.x) - 60.0) < 0.5 and absf(mid.y) < 55.0
			var on_y := absf(absf(mid.y) - 60.0) < 0.5 and absf(mid.x) < 55.0
			if on_x or on_y:
				front.append(str(eid))
		elif pts.size() > 8 and absf(mid.z - 30.0) < 0.5:
			# Root circle Ø70 ≈ 219.9 mm.
			if absf(length - (TAU * 35.0)) < 2.0:
				root.append(str(eid))
	var out := PackedStringArray()
	out.append_array(vertical)
	out.append_array(front)
	out.append_array(root)
	print("  r5 edges vertical=%d front=%d root=%d" % [vertical.size(), front.size(), root.size()])
	return out


func _annulus_rims(doc: SxDocument, body: String) -> PackedStringArray:
	var lines: Dictionary = doc.get_edge_lines(body)
	var out := PackedStringArray()
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 8:
			continue
		var mid := _edge_mid(pts)
		if absf(mid.z - 55.0) > 0.5:
			continue
		var length := float(doc.measure_edge_length(str(eid)))
		var r30 := absf(length - (TAU * 30.0)) < 2.0
		var r35 := absf(length - (TAU * 35.0)) < 2.0
		if r30 or r35:
			out.append(str(eid))
	return out


func _back_face(doc: SxDocument, body: String) -> String:
	# Prefer a face whose pick lies on z≈0 (the open-back face).
	for face_id in doc.get_face_ids(body):
		var fid := str(face_id)
		var pt: Vector3 = FacePick.point(doc, fid)
		if absf(pt.z) < 0.5 and absf(pt.x) > 20.0:
			return fid
	# Ray from below: first hit on the back plate (outside the Ø60 hole).
	var hit: Dictionary = doc.pick(Vector3(45, 0, -10), Vector3(0, 0, 1))
	if hit.is_empty():
		return ""
	return str(hit.get("face", ""))
