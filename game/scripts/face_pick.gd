class_name FacePick
extends RefCounted
## A point on a face, and which parallel face a normal names.
## Callers use these; they do not recompute a UV midpoint.


const ALIGN := 0.999


static func point(doc, face_id: String) -> Vector3:
	if doc == null or face_id == "" or not doc.has_method("face_pick_point"):
		return Vector3.ZERO
	var got: Variant = doc.face_pick_point(face_id)
	return got if got is Vector3 else Vector3.ZERO


## Signed offset of the face plane: n · pick, in millimetres.
static func plane_offset(normal: Vector3, pick: Vector3) -> float:
	if normal.length_squared() < 1e-12:
		return 0.0
	return normal.normalized().dot(pick)


## Faces whose unit normal meets ALIGN against `want`.
## No `plane`: the one furthest along `want` (centre · want), first on a tie.
## `plane` set: the one whose plane offset is nearest that value.
static func match_normal(faces: Array, want: Vector3, plane: Variant = null) -> Dictionary:
	if want.length_squared() < 1e-8:
		return {}
	want = want.normalized()
	var use_plane := plane != null
	var want_plane := float(plane) if use_plane else 0.0
	var best := {}
	var best_along := -1.0e30
	var best_plane := 1.0e30
	for face in faces:
		if not (face is Dictionary):
			continue
		var normal := _vec3(face.get("normal", []))
		if normal.length_squared() < 1e-12:
			continue
		normal = normal.normalized()
		if normal.dot(want) < ALIGN:
			continue
		var centre := _vec3(face.get("centre", []))
		var along := Vector3(
				snappedf(centre.x, 0.001),
				snappedf(centre.y, 0.001),
				snappedf(centre.z, 0.001)).dot(want)
		if use_plane:
			var off := float(face.get("plane", plane_offset(normal, _vec3(face.get("pick", [])))))
			var gap := absf(off - want_plane)
			if best.is_empty() or gap < best_plane - 1e-6 \
					or (absf(gap - best_plane) <= 1e-6 and along > best_along):
				best = face
				best_plane = gap
				best_along = along
		elif best.is_empty() or along > best_along:
			best = face
			best_along = along
	return best


static func _vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO
