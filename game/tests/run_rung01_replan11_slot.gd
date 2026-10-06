extends SceneTree
## Rung 1 replan 11 WP9. Validation: face sketch support keys follow thickness.
## Run:
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_slot.gd

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
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
	print("rung01 replan11 WP9 slot sketch follows the face")
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	var doc: SxDocument = view.doc

	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	var top := _top_face(doc, body)

	main._start_sketch_on_face("no-such-face", body)
	await process_frame
	var bad_status := str(main.status_label.text)
	check(not sm.active and bad_status.contains("Could not measure"),
			"bad face does not begin (active=%s status=%s)" % [sm.active, bad_status])

	main._start_sketch_on_face(top, body)
	await process_frame
	var face_status := str(main.status_label.text)
	check(sm.active and face_status.contains("Sketch on face") and face_status.contains("+Z"),
			"top face starts a +Z session (active=%s status=%s)" % [sm.active, face_status])

	var host := view.feature_of_body(body)
	check(sm.support_host == host and sm.support_side == "max" and sm.support_normal.z > 0.9,
			"support host/side/normal (host=%s want=%s side=%s n.z=%.3f)" % [
				sm.support_host, host, sm.support_side, sm.support_normal.z])

	sm.sketch.add_line(-4, -2, 4, -2)
	sm.sketch.add_line(4, -2, 4, 2)
	sm.sketch.add_line(4, 2, -4, 2)
	sm.sketch.add_line(-4, 2, -4, -2)
	sm.finish_extrude(2.5, "cut", "blind")
	await process_frame
	var cut_status := str(main.status_label.text)
	var sketch_fid := _sketch_fid_with_support(doc)
	var sketch_params := _feature_params(doc, sketch_fid)
	check(not sm.active and sketch_params.contains("support_host"),
			"cut sketch saved with support_host (active=%s status=%s params=%s)" % [
				sm.active, cut_status, sketch_params])
	if cut_status.contains("open profile"):
		printerr("  note - status contains open profile; four endpoints are not shared")

	var prim := view.feature_of_body(body)
	var params := {}
	var parsed = JSON.parse_string(_feature_params(doc, prim))
	if typeof(parsed) == TYPE_DICTIONARY:
		params = parsed
	params["c"] = 14
	doc.graph_set_params(prim, JSON.stringify(params))
	await process_frame
	var sk: SxSketch = doc.graph_get_sketch(sketch_fid)
	var origin_z := 0.0
	if sk != null:
		var pi: Dictionary = sk.plane_info()
		origin_z = (pi["origin"] as Vector3).z
	check(absf(origin_z - 14.0) <= 0.05,
			"sketch plane origin z is 14 ± 0.05 (got %.4f)" % origin_z)

	var mesh: Array = _load_mesh(doc, body)
	check(not _inside(mesh, Vector3(0, 0, 12.75)), "mesh is not inside at (0,0,12.75)")
	check(not _inside(mesh, Vector3(0, 0, 13.5)), "mesh is not inside at (0,0,13.5)")
	check(_inside(mesh, Vector3(0, 0, 11.0)), "mesh is inside at (0,0,11.0)")

	main._start_sketch_on_ground()
	await process_frame
	var ground_status := str(main.status_label.text)
	var after_params := _feature_params(doc, sketch_fid)
	check(sm.support_host == "" and ground_status.contains("Sketch on ground (XY)")
			and after_params.contains("support_host"),
			"ground sketch clears session support; cut sketch keeps keys (host=%s status=%s)" % [
				sm.support_host, ground_status])

	main.queue_free()
	await process_frame


func _top_face(doc: SxDocument, body: String) -> String:
	var best := ""
	var best_z := -1e9
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		var extent := mx - mn
		var cz := (mn.z + mx.z) * 0.5
		if extent.z > 0.1:
			continue
		if cz > best_z:
			best_z = cz
			best = str(fid)
	return best


func _feature_params(doc: SxDocument, fid: String) -> String:
	if fid == "":
		return ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("params", ""))
	return ""


func _sketch_fid_with_support(doc: SxDocument) -> String:
	for f in doc.graph_features():
		if str(f.get("type", "")) != "sketch":
			continue
		var raw := str(f.get("params", ""))
		if raw.contains("support_host"):
			return str(f.get("id", ""))
	return ""


func _load_mesh(doc: SxDocument, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if ii.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	return [verts, idx]


func _ray_hits(mesh: Array, origin: Vector3, dir: Vector3) -> Array[float]:
	var verts: PackedVector3Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	var d := dir.normalized()
	var hits: Array[float] = []
	var ntri := idx.size() / 3
	for t in ntri:
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var e1 := b - a
		var e2 := c - a
		var pvec := d.cross(e2)
		var det := e1.dot(pvec)
		if absf(det) < 1e-12:
			continue
		var inv := 1.0 / det
		var s := origin - a
		var u := s.dot(pvec) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := s.cross(e1)
		var v := d.dot(q) * inv
		if v < 0.0 or u + v > 1.0:
			continue
		var dist := e2.dot(q) * inv
		if dist > 1e-6:
			hits.append(dist)
	hits.sort()
	return hits


func _inside(mesh: Array, pt: Vector3) -> bool:
	var votes := 0
	for d in [Vector3(1, 0.0123, 0.0071), Vector3(0.0091, 1, 0.0137), Vector3(0.0113, 0.0067, 1)]:
		if _ray_hits(mesh, pt, d).size() % 2 == 1:
			votes += 1
	return votes >= 2
