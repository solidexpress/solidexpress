class_name SectionPlane
extends RefCounted
## Named section presets and the kept-half rule. ViewportInteraction asks;
## it does not hard-code Front/Top/Right normals.


## Flat colour on the cut (back-facing fragments while clipped).
const CAP_COLOUR := Color(0.62, 0.66, 0.72, 1.0)

## SOLIDWORKS names on our axes. point_rule "origin" = world origin.
const PRESETS: Array[Dictionary] = [
	{"name": "Front", "point": Vector3.ZERO, "normal": Vector3(0, 0, 1)},
	{"name": "Top", "point": Vector3.ZERO, "normal": Vector3(0, 1, 0)},
	{"name": "Right", "point": Vector3.ZERO, "normal": Vector3(1, 0, 0)},
]


static func preset(name: String) -> Dictionary:
	for row in PRESETS:
		if str(row["name"]) == name:
			return row
	return {}


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for row in PRESETS:
		out.append(str(row["name"]))
	return out


## Discard normal: points toward the camera so the kept half is away from it.
static func kept_side(camera_pos: Vector3, point: Vector3, base_normal: Vector3) -> Vector3:
	var n := base_normal.normalized()
	if n.length_squared() < 1e-12:
		n = Vector3.RIGHT
	if n.dot(camera_pos - point) < 0.0:
		n = -n
	return n


static func apply(view: DocumentView, camera_pos: Vector3, plane_name: String) -> Dictionary:
	var row := preset(plane_name)
	if row.is_empty() or view == null:
		return {}
	var point: Vector3 = row["point"]
	var normal := kept_side(camera_pos, point, row["normal"] as Vector3)
	view.set_section_plane(point, normal)
	return {
		"on": true,
		"plane": plane_name,
		"point": [point.x, point.y, point.z],
		"normal": [normal.x, normal.y, normal.z],
	}
