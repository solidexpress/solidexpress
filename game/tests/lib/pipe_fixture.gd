## The kernel-built UBC pipe the rung-5 suites share.
## Boot, PART millimetres, mirrored / reshelled builders. Each suite keeps its checks.
class_name PipeFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

static var _part: Dictionary = {}


static func part() -> Dictionary:
	if not _part.is_empty():
		return _part
	var result := SxChecker.run("rung05", ["params"])
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) == TYPE_DICTIONARY:
		_part = parsed
	return _part


static func mm(key: String) -> float:
	var table: Variant = part().get("PART", {})
	if typeof(table) != TYPE_DICTIONARY:
		return 0.0
	return float(table.get(key, 0.0))


static func boot(tree: SceneTree, viewport: Vector2i, on_status: Callable = Callable(),
		sources: Array = []) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = tree
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, viewport)
	if on_status.is_valid():
		for source in sources:
			var node: Node = main.get(str(source))
			if node != null and node.has_signal("status") and not node.status.is_connected(on_status):
				node.status.connect(on_status)
	return ctx


static func find_auto(node: Node, id: String) -> Node:
	if node == null:
		return null
	if str(node.get_meta("sx_auto", "")) == id:
		return node
	for c in node.get_children():
		var hit := find_auto(c, id)
		if hit != null:
			return hit
	return null


static func output_body(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("output_body", ""))
	return ""


static func z_faces(doc: SxDocument, body: String) -> PackedStringArray:
	var out := PackedStringArray()
	if body == "":
		return out
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.z <= 0.2 and ext.x > 10.0 and ext.y > 10.0:
			out.append(str(fid))
	return out


static func planar_at_z(doc: SxDocument, body: String, z: float) -> PackedStringArray:
	var out := PackedStringArray()
	if body == "":
		return out
	for fid in doc.get_face_ids(body):
		var pick: Vector3 = doc.face_pick_point(str(fid))
		if absf(pick.z - z) > 0.5:
			continue
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.z <= 0.5 and ext.x > 10.0 and ext.y > 10.0:
			out.append(str(fid))
	return out


static func build_mirrored(doc: SxDocument) -> String:
	var od_r := mm("OD") * 0.5
	var id_r := mm("ID") * 0.5
	var l0 := mm("L0")
	var wall := mm("WALL")
	var flange_r := mm("FLANGE_D") * 0.5
	var flange_t := mm("FLANGE_T")
	var pcd := mm("PCD")
	var hole_r := mm("HOLE_D") * 0.5
	var n_holes := int(mm("N_HOLES"))
	var sk := SxSketch.new()
	sk.add_circle(0, 0, od_r)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	var ext := doc.graph_add_extrude(sk_fid, l0, false, "new", "")
	if ext == "":
		return ""
	var body := output_body(doc, ext)
	var ends := z_faces(doc, body)
	if ends.size() != 2:
		return ""
	var sh := doc.graph_add_shell(ext, ends, wall)
	if sh == "":
		return ""
	var fl_sk := SxSketch.new()
	fl_sk.set_plane(Vector3(0, 0, l0), Vector3(1, 0, 0), Vector3(0, 1, 0))
	fl_sk.add_circle(0, 0, flange_r)
	var fl_sk_fid := doc.graph_add_sketch(fl_sk)
	var flange := doc.graph_add_extrude(fl_sk_fid, flange_t, false, "fuse", ext)
	if flange == "":
		return ""
	var cut_sk := SxSketch.new()
	cut_sk.set_plane(Vector3(0, 0, l0 + flange_t), Vector3(1, 0, 0), Vector3(0, 1, 0))
	cut_sk.add_circle(0, 0, id_r)
	for k in n_holes:
		var ang := float(k) * TAU / float(n_holes)
		cut_sk.add_circle(pcd * sin(ang), pcd * cos(ang), hole_r)
	var cut_sk_fid := doc.graph_add_sketch(cut_sk)
	var cut := doc.graph_add_extrude(cut_sk_fid, -flange_t, false, "cut", ext)
	if cut == "":
		return ""
	var sources := PackedStringArray([ext, sh, flange, cut])
	var mir := doc.graph_add_mirror(ext, Vector3.ZERO, Vector3(0, 0, 1), sources)
	if mir == "":
		return ""
	return ext


static func build_reshelled(doc: SxDocument) -> String:
	var ext := build_mirrored(doc)
	if ext == "":
		return ""
	var body := output_body(doc, ext)
	var remove := PackedStringArray()
	remove.append_array(planar_at_z(doc, body, -mm("L0") - mm("FLANGE_T")))
	remove.append_array(planar_at_z(doc, body, 0.0))
	if remove.is_empty():
		return ""
	var sh := doc.graph_add_shell(ext, remove, mm("WALL"))
	if sh == "":
		return ""
	return ext
