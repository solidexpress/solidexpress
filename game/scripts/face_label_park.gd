## Host-face dim labels take the shortest screen-edge exit whose plate misses parked labels.
## SketchMode keeps the host-face rect and projected-label geometry.
class_name FaceLabelPark
extends RefCounted


static func park(sm, cam: Camera3D, k: float) -> void:
	if k < 1e-6 or sm.host_face_id == "" or sm.view == null or sm.view.doc == null:
		return
	var face: Rect2 = sm._host_face_screen_rect(cam)
	if face.size.x < 4.0 or face.size.y < 4.0:
		return
	var placed: Array[Rect2] = []
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var rect: Rect2 = sm._projected_label_rect(dim, cam, k)
		var centre: Vector2 = rect.get_center()
		if not face.has_point(centre):
			placed.append(rect)
			continue
		var prev: Vector2 = dim.get("label_clamp", Vector2.ZERO)
		var push := exit_clear_of_labels(centre, face, dim, prev, cam, k, placed, sm)
		dim["label_clamp"] = prev + Vector2(push.x / k, -push.y / k)
		sm.dimensions[i] = dim
		placed.append(sm._projected_label_rect(dim, cam, k))


static func face_exits(centre: Vector2, face: Rect2) -> Array:
	var exits := [
		{"gap": centre.x - face.position.x, "push": Vector2(-(centre.x - face.position.x + 2.0), 0.0)},
		{"gap": face.end.x - centre.x, "push": Vector2(face.end.x - centre.x + 2.0, 0.0)},
		{"gap": centre.y - face.position.y, "push": Vector2(0.0, -(centre.y - face.position.y + 2.0))},
		{"gap": face.end.y - centre.y, "push": Vector2(0.0, face.end.y - centre.y + 2.0)},
	]
	exits.sort_custom(func(a, b): return float(a["gap"]) < float(b["gap"]))
	return exits


static func exit_clear_of_labels(centre: Vector2, face: Rect2, dim: Dictionary,
		prev: Vector2, cam: Camera3D, k: float, placed: Array[Rect2], sm) -> Vector2:
	var fallback := Vector2.ZERO
	for exit in face_exits(centre, face):
		var push: Vector2 = exit["push"]
		if fallback == Vector2.ZERO:
			fallback = push
		var trial := dim.duplicate()
		trial["label_clamp"] = prev + Vector2(push.x / k, -push.y / k)
		var rect: Rect2 = sm._projected_label_rect(trial, cam, k)
		var clash := false
		for other in placed:
			if rect.intersects(other):
				clash = true
				break
		if not clash:
			return push
	return fallback
