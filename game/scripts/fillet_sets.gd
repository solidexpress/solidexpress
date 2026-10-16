class_name FilletSets
extends RefCounted
## Face → edge list for one fillet feature. FACE_LOOP drops bolt-hole
## circles on an annulus so face-first Fillet is ID+OD, not every wire.


## All-circle faces: keep rims with r >= keep_frac * r_max (OD + bore).
## Mixed faces (rung 3 z=30) keep every edge.
const FACE_LOOP := {
	"keep_frac": 0.4,
	"seam_mm": 20.0,
}


## Boundary edges of `face` on `body`. `body` selects which solid the face
## belongs to; the kernel resolves the face id.
static func edges_of_face(doc, body: String, face: String) -> PackedStringArray:
	if doc == null or face == "":
		return PackedStringArray()
	if body != "" and doc.has_method("get_face_ids"):
		var faces: PackedStringArray = doc.get_face_ids(body)
		if faces.find(face) < 0:
			return PackedStringArray()
	if not doc.has_method("edges_of_face"):
		return PackedStringArray()
	return rims_of(doc, body, doc.edges_of_face(face))


## True when `edge` is a circular wire (closed or open arc), not a seam.
static func circular(doc, body: String, edge: String) -> bool:
	return _circle_radius(doc, body, str(edge)) > 0.0


## Annulus rims from a face loop. Bolt holes (small circles) drop; a
## rectangle-plus-boss keeps the mixed set.
static func rims_of(doc, body: String, edges: PackedStringArray) -> PackedStringArray:
	if edges.size() < 3 or body == "" or doc == null or not doc.has_method("get_edge_lines"):
		return edges
	var circles := PackedStringArray()
	var others := PackedStringArray()
	var radii: Array[float] = []
	var r_max := 0.0
	var circ_len_max := 0.0
	for e in edges:
		var id := str(e)
		var r := _circle_radius(doc, body, id)
		if r > 0.0:
			circles.append(id)
			radii.append(r)
			if r > r_max:
				r_max = r
			var clen := r * TAU
			if clen > circ_len_max:
				circ_len_max = clen
		else:
			others.append(id)
	# Annulus + a short seam (10 mm flange split): drop the seam. A
	# rectangle-plus-boss keeps its long mixed edges (rung 3 z=30).
	if circles.size() >= 2 and not others.is_empty() and _short_seams(doc, others, circ_len_max):
		edges = circles
	elif not others.is_empty():
		return _drop_short_seams(doc, edges)
	if edges.size() < 3:
		return _drop_short_seams(doc, edges)
	var floor_r := float(FACE_LOOP["keep_frac"]) * r_max
	var out := PackedStringArray()
	for i in circles.size():
		if radii[i] >= floor_r:
			out.append(str(circles[i]))
	return _drop_short_seams(doc, out if not out.is_empty() else edges)


static func _short_seams(doc, others: PackedStringArray, circ_len_max: float) -> bool:
	if circ_len_max <= 1.0 or not doc.has_method("measure_edge_length"):
		return false
	var cap := float(FACE_LOOP["keep_frac"]) * circ_len_max
	for e in others:
		if float(doc.measure_edge_length(str(e))) > cap:
			return false
	return true


## A 10 mm flange seam drops when two longer rims exist. Rung 3's 30 mm
## verticals stay (they are at or above seam_mm).
static func _drop_short_seams(doc, edges: PackedStringArray) -> PackedStringArray:
	if edges.size() < 3 or not doc.has_method("measure_edge_length"):
		return edges
	var seam := float(FACE_LOOP["seam_mm"])
	var kept := PackedStringArray()
	for e in edges:
		if float(doc.measure_edge_length(str(e))) >= seam:
			kept.append(str(e))
	if kept.size() >= 2 and kept.size() < edges.size():
		return kept
	return edges


static func _circle_radius(doc, body: String, edge: String) -> float:
	if not doc.has_method("measure_edge_length"):
		return 0.0
	var length := float(doc.measure_edge_length(edge))
	if length < 1.0:
		return 0.0
	if not _circular_edge(doc, body, edge, length):
		return 0.0
	return length / TAU


## Same chord test as dressup "arc" vs "line": a 10 mm flange seam is a
## line (chord ≈ length); an open circular rim is an arc (chord ≪ length).
static func _circular_edge(doc, body: String, edge: String, length: float) -> bool:
	if not doc.has_method("get_edge_lines"):
		return false
	var lines: Dictionary = doc.get_edge_lines(body)
	var pts := _polyline(lines, edge)
	if pts.size() < 2:
		return false
	var chord := pts[0].distance_to(pts[pts.size() - 1])
	return chord < length * 0.95


static func _polyline(lines: Dictionary, edge: String) -> PackedVector3Array:
	if lines.has(edge) and lines[edge] is PackedVector3Array:
		return lines[edge]
	for k in lines.keys():
		if str(k) == edge and lines[k] is PackedVector3Array:
			return lines[k]
	return PackedVector3Array()
