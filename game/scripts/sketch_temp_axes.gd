class_name SketchTempAxes
extends RefCounted
## Temporary Axes overlay: dashed revolve axes while a Front sketch sits on
## a revolved body. View → Hide/Show → Temporary Axes / menu:TemporaryAxes.


const DASH_MM := 4.0
const GAP_MM := 3.0
const COLOR := Color(0.55, 0.78, 0.95, 0.85)


## True when the document has a revolve feature with a live body.
static func has_revolve(doc) -> bool:
	if doc == null or not doc.has_method("graph_features"):
		return false
	for f in doc.graph_features():
		if str(f.get("type", "")) != "revolve":
			continue
		if str(f.get("output_body", "")) != "":
			return true
	return false


## Snap `p` onto x = 0 when it is within `rad`. Unchanged otherwise.
static func snap_y_axis(p: Vector2, rad: float) -> Vector2:
	if absf(p.x) <= rad:
		return Vector2(0.0, p.y)
	return p


## Endpoints and centres of other visible sketches, in this sketch's UV.
static func other_sketch_points(doc, current_fid: String, plane) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for hit in other_sketch_hits(doc, current_fid, plane):
		out.append(hit["uv"])
	return out


## Same as other_sketch_points, with the source entity so coincident can land.
static func other_sketch_hits(doc, current_fid: String, plane) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or plane == null or not doc.has_method("graph_features"):
		return out
	for f in doc.graph_features():
		if str(f.get("type", "")) != "sketch":
			continue
		var fid := str(f.get("id", ""))
		if fid == "" or fid == current_fid:
			continue
		var sk = doc.graph_get_sketch(fid)
		if sk == null:
			continue
		var info: Dictionary = sk.plane_info() if sk.has_method("plane_info") else {}
		var origin: Vector3 = info.get("origin", Vector3.ZERO)
		var x: Vector3 = info.get("x_dir", info.get("x", Vector3.RIGHT))
		var y: Vector3 = info.get("y_dir", info.get("y", Vector3.UP))
		for eid in sk.entity_ids():
			var e: Dictionary = sk.entity_info(eid)
			for key in ["start", "end", "center", "position", "major_start", "major_end"]:
				if not e.has(key):
					continue
				var uv: Vector2 = e[key]
				var world: Vector3 = origin + x * uv.x + y * uv.y
				if absf((world - plane.origin).dot(plane.normal)) > 0.75:
					continue
				var role: String = "center" if str(key) == "center" else str(key)
				if key == "position":
					role = "self"
				if key == "major_start":
					role = "start"
				if key == "major_end":
					role = "end"
				out.append({
					"uv": plane.to_uv(world),
					"fid": fid,
					"entity": str(eid),
					"role": role,
				})
	return out


## World-space dashed segments for the overlay.
static func dashes(plane, y_min: float, y_max: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if plane == null:
		return out
	var a := float(minf(y_min, y_max))
	var b := float(maxf(y_min, y_max))
	var t := a
	var on := true
	while t < b:
		var n := t + (DASH_MM if on else GAP_MM)
		if n > b:
			n = b
		if on:
			out.append(plane.to_world(Vector2(0.0, t)))
			out.append(plane.to_world(Vector2(0.0, n)))
		t = n
		on = not on
	return out
