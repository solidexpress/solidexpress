extends "res://tests/lib/sx_suite.gd"
## Rung 1 replan 12 WP1. Validation: fillets survive a thickness edit, and a fillet
## that loses edges says so.
## Run:
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_fillet.gd

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung01 replan12 WP1 fillets survive thickness")
	await _case_face()
	await _case_all_lost()
	await _case_partial()
	finish()


func _fresh() -> Dictionary:
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
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	return {"main": main, "view": view, "doc": view.doc, "body": body,
			"prim": view.feature_of_body(body)}


func _top_face(doc: SxDocument, body: String) -> String:
	var best := ""
	var best_z := -1e9
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if mx.z - mn.z > 0.1:
			continue
		if mx.z > best_z:
			best_z = mx.z
			best = str(fid)
	return best


## Edge of `body` whose polyline midpoint is within 0.1 mm of `mid`.
func _edge_at(doc: SxDocument, body: String, mid: Vector3) -> String:
	var lines: Dictionary = doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var m := (pts[0] + pts[pts.size() - 1]) * 0.5
		if m.distance_to(mid) < 0.1:
			return str(id)
	return ""


func _set_thickness(ctx: Dictionary, t: float) -> bool:
	var doc: SxDocument = ctx["doc"]
	var prim := str(ctx["prim"])
	var params = JSON.parse_string(_params_of(doc, prim))
	params["c"] = t
	return doc.graph_set_params(prim, JSON.stringify(params))


func _params_of(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("params", ""))
	return ""


func _case_face() -> void:
	print("- face-derived top fillet follows the top")
	var c := await _fresh()
	var doc: SxDocument = c["doc"]
	var body := str(c["body"])
	var top := _top_face(doc, body)
	var edges := doc.edges_of_face(top)
	check(edges.size() == 4, "top face has 4 edges (got %d)" % edges.size())
	var ff := doc.graph_add_fillet(str(c["prim"]), edges, 1.0)
	check(ff != "", "face fillet created (err '%s')" % doc.last_graph_error())
	check(_params_of(doc, ff).contains("face_cues"), "fillet params carry face_cues")
	var ok := _set_thickness(c, 14.0)
	check(ok, "thickness 14 accepted (err '%s')" % doc.last_graph_error())
	check(_warnings(doc).is_empty(), "no warnings (got %s)" % str(_warnings(doc)))
	var mesh := _load_mesh(doc, body)
	check(not _inside(mesh, Vector3(-19.9, 0, 13.9)), "top rim is rounded at z=13.9")
	check(_inside(mesh, Vector3(-19.7, 0, 9.0)), "wall is solid at z=9")
	(c["main"] as Node).queue_free()
	await process_frame


## Cuts a 8 x 4 x 2.5 pocket from the top of the box with the sketch session the
## GUI uses. Its floor edges get new ids every rebuild.
func _cut_pocket(c: Dictionary) -> void:
	var main = c["main"]
	var sm: SketchMode = main.sketch_mode
	main._start_sketch_on_face(_top_face(c["doc"], str(c["body"])), str(c["body"]))
	await process_frame
	sm.sketch.add_line(-4, -2, 4, -2)
	sm.sketch.add_line(4, -2, 4, 2)
	sm.sketch.add_line(4, 2, -4, 2)
	sm.sketch.add_line(-4, 2, -4, -2)
	sm.finish_extrude(2.5, "cut", "blind")
	await process_frame
	await process_frame


func _case_all_lost() -> void:
	print("- a fillet whose edges all vanish warns by name and the edit stands")
	var c := await _fresh()
	await _cut_pocket(c)
	var doc: SxDocument = c["doc"]
	var body := str(c["body"])
	var a := _edge_at(doc, body, Vector3(0, -2, 7.5))
	var b := _edge_at(doc, body, Vector3(0, 2, 7.5))
	check(a != "" and b != "", "pocket floor edges found")
	var ff := doc.graph_add_fillet((c["view"] as DocumentView).feature_of_body(body), PackedStringArray([a, b]), 0.5)
	check(ff != "", "two-edge floor fillet created (err '%s')" % doc.last_graph_error())
	var ok := _set_thickness(c, 14.0)
	check(ok, "thickness 14 is accepted (err '%s')" % doc.last_graph_error())
	var warnings := _warnings(doc)
	check(warnings.size() == 1 and warnings[0].contains("all 2 edges lost on rebuild") and warnings[0].contains("fillet"),
			"the warning names the loss (got %s)" % str(warnings))
	var bb: Dictionary = doc.measure_bbox(body)
	var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
	check(absf(ext.z - 14.0) < 0.01, "body is 14 thick (got %.3f)" % ext.z)
	(c["main"] as Node).queue_free()
	await process_frame


func _warnings(doc: SxDocument) -> PackedStringArray:
	if not doc.has_method("graph_warnings"):
		return PackedStringArray()
	return doc.call("graph_warnings")


func _case_partial() -> void:
	print("- a fillet that loses one of two edges warns")
	var c := await _fresh()
	await _cut_pocket(c)
	var main = c["main"]
	var doc: SxDocument = c["doc"]
	var body := str(c["body"])
	var floor_edge := _edge_at(doc, body, Vector3(0, -2, 7.5))
	var bottom := _edge_at(doc, body, Vector3(0, -10, 0))
	check(floor_edge != "" and bottom != "", "pocket floor edge and a bottom edge found")
	var ff := doc.graph_add_fillet((c["view"] as DocumentView).feature_of_body(body), PackedStringArray([floor_edge, bottom]), 0.5)
	check(ff != "", "mixed fillet created (err '%s')" % doc.last_graph_error())
	check(_warnings(doc).is_empty(), "no warning before the edit")
	var ok := _set_thickness(c, 14.0)
	check(ok, "thickness 14 accepted (err '%s')" % doc.last_graph_error())
	var warnings := _warnings(doc)
	check(warnings.size() == 1 and warnings[0].contains("1 of 2 edges lost on rebuild"),
			"one warning (got %s)" % str(warnings))
	var row_warning := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == ff:
			row_warning = str(f.get("warning", ""))
	check(row_warning.contains("1 of 2 edges lost on rebuild"),
			"graph_features names the warning (got '%s')" % row_warning)
	main.show_timeline = true
	main._update_panel_visibility()
	main.timeline.refresh()
	await process_frame
	check(main.timeline.find_child("WarnBadge", true, false) != null, "timeline row shows a warning badge")
	main.queue_free()
	await process_frame


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
