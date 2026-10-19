## Kernel-built UBC wrench that reaches check_rung01.py wrench (28/28).
## Blank / hole / jaw / slot / fillets are graph ops (no click walk).
class_name WrenchFixture
extends RefCounted

const HEAD := Vector2(200.0, 0.0)
const HEAD_R := 22.5
const PIVOT_R := 10.0
const HOLE_R := 5.0
const THICK := 10.0
const JAW_HALF := 10.0
const JAW_OUT := 40.0
const SLOT_A := Vector2(18.5, 0.0)
const SLOT_B := Vector2(168.5, 0.0)
const SLOT_R := 5.0
const SLOT_DEPTH := 2.5
const NECK_R := 10.0
const EDGE_R := 1.0


static func output_body(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("output_body", ""))
	return ""


static func build(doc: SxDocument) -> String:
	var dx := sqrt(HEAD_R * HEAD_R - PIVOT_R * PIVOT_R)
	var xhit := HEAD.x - dx
	var ang := atan2(PIVOT_R, -dx)
	var blank := SxSketch.new()
	blank.add_arc(0.0, 0.0, PIVOT_R, PI / 2.0, 3.0 * PI / 2.0)
	blank.add_line(0.0, -PIVOT_R, xhit, -PIVOT_R)
	blank.add_arc(HEAD.x, HEAD.y, HEAD_R, -ang, ang)
	blank.add_line(xhit, PIVOT_R, 0.0, PIVOT_R)
	var blank_fid := doc.graph_add_sketch(blank)
	if blank_fid == "":
		return ""
	var host := doc.graph_add_extrude(blank_fid, THICK, false, "new", "")
	if host == "":
		return ""

	var top := Vector3(0, 0, THICK)
	var x_dir := Vector3(1, 0, 0)
	var y_dir := Vector3(0, 1, 0)

	var hole := SxSketch.new()
	hole.set_plane(top, x_dir, y_dir)
	hole.add_circle(0.0, 0.0, HOLE_R)
	var hole_sk := doc.graph_add_sketch(hole)
	if hole_sk == "" or doc.graph_add_extrude(hole_sk, -THICK, false, "cut", host) == "":
		return ""

	var s2 := sqrt(2.0) * 0.5
	var jd := Vector2(s2, s2)
	var ja := Vector2(-s2, s2)
	var p0 := HEAD + ja * JAW_HALF
	var p1 := HEAD + jd * JAW_OUT + ja * JAW_HALF
	var p2 := HEAD + jd * JAW_OUT - ja * JAW_HALF
	var p3 := HEAD - ja * JAW_HALF
	var jaw := SxSketch.new()
	jaw.set_plane(top, x_dir, y_dir)
	jaw.add_line(p0.x, p0.y, p1.x, p1.y)
	jaw.add_line(p1.x, p1.y, p2.x, p2.y)
	jaw.add_line(p2.x, p2.y, p3.x, p3.y)
	jaw.add_line(p3.x, p3.y, p0.x, p0.y)
	var jaw_sk := doc.graph_add_sketch(jaw)
	if jaw_sk == "" or doc.graph_add_extrude(jaw_sk, -THICK, false, "cut", host) == "":
		return ""

	var slot := SxSketch.new()
	slot.set_plane(top, x_dir, y_dir)
	slot.add_line(SLOT_A.x, -SLOT_R, SLOT_B.x, -SLOT_R)
	slot.add_arc(SLOT_B.x, SLOT_B.y, SLOT_R, -PI / 2.0, PI / 2.0)
	slot.add_line(SLOT_B.x, SLOT_R, SLOT_A.x, SLOT_R)
	slot.add_arc(SLOT_A.x, SLOT_A.y, SLOT_R, PI / 2.0, 3.0 * PI / 2.0)
	var slot_sk := doc.graph_add_sketch(slot)
	if slot_sk == "" or doc.graph_add_extrude(slot_sk, -SLOT_DEPTH, false, "cut", host) == "":
		return ""

	var body := output_body(doc, host)
	if body == "":
		return ""
	var neck := _neck_edges(doc, body, xhit)
	if neck.size() == 2:
		doc.graph_add_fillet(host, neck, NECK_R)
	for z_want in [THICK, 0.0, THICK - SLOT_DEPTH]:
		var face := _face_at(doc, body, z_want)
		if face == "":
			continue
		doc.graph_add_fillet(host, doc.edges_of_face(face), EDGE_R)
	if doc.body_ids().is_empty():
		return ""
	return str(doc.body_ids()[0])


static func _face_at(doc: SxDocument, body: String, z_want: float) -> String:
	var best := ""
	var best_area := 20.0
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = bb["max"] - bb["min"]
		if ext.z > 0.05:
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		var mid_z := (mn.z + mx.z) * 0.5
		if absf(mid_z - z_want) > 0.2:
			continue
		var area := ext.x * ext.y
		if area > best_area:
			best_area = area
			best = str(fid)
	return best


static func _neck_edges(doc: SxDocument, body: String, neck_x: float) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: Dictionary = doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(pts[0].z - pts[pts.size() - 1].z) < 5.0:
			continue
		if absf(mid.x - neck_x) < 1.5 and absf(absf(mid.y) - PIVOT_R) < 0.8:
			out.append(str(eid))
	return out
