class_name FilletSets
extends RefCounted
## Face → edge list for one fillet feature.
## OpsPanel stays on the single-edge path (WP1). Callers pass this list to
## graph_add_fillet, or select the edges and click Fillet.


## Boundary edges of `face` on `body`. `body` selects which solid the face
## belongs to; the kernel resolves the face id.
static func edges_of_face(doc, body: String, face: String) -> PackedStringArray:
	if doc == null or face == "":
		return PackedStringArray()
	if body != "" and doc.has_method("get_face_ids"):
		var faces: PackedStringArray = doc.get_face_ids(body)
		if faces.find(face) < 0:
			return PackedStringArray()
	if doc.has_method("edges_of_face"):
		return doc.edges_of_face(face)
	return PackedStringArray()
