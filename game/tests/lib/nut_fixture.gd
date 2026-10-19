## Kernel-built UBC hex nut (AF 20, Ø10 bore, T=7.5). No click walk.
class_name NutFixture
extends RefCounted


static func output_body(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("output_body", ""))
	return ""


static func build(doc: SxDocument) -> String:
	var af := 20.0
	var r_vert := af / sqrt(3.0)
	var sk := SxSketch.new()
	var pts: Array[Vector2] = []
	for i in 6:
		var a := float(i) * PI / 3.0
		pts.append(Vector2(r_vert * cos(a), r_vert * sin(a)))
	for i in 6:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 6]
		sk.add_line(a.x, a.y, b.x, b.y)
	sk.add_circle(0.0, 0.0, 5.0)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	var ext := doc.graph_add_extrude(sk_fid, 7.5, false, "new", "")
	if ext == "":
		return ""
	return output_body(doc, ext)
