class_name OriginPlanes
extends RefCounted
## The three origin planes of a new part. BASIS is the sketch frame.
## The stored datum x_dir is only the visible quad. Callers do not branch.


## name, plane normal, sketch X, sketch Y, how a click starts the sketch,
## and a point that lies on this quad and not the other two.
const BASIS: Array[Dictionary] = [
	{
		"name": "Front",
		"normal": Vector3(0, 0, 1),
		"x": Vector3(1, 0, 0),
		"y": Vector3(0, 1, 0),
		"entry": "ground",
		"pick": Vector3(4, -6, 0),
	},
	{
		"name": "Top",
		"normal": Vector3(0, 1, 0),
		"x": Vector3(1, 0, 0),
		"y": Vector3(0, 0, 1),
		"entry": "plane",
		"pick": Vector3(10, 0, 10),
	},
	{
		"name": "Right",
		"normal": Vector3(1, 0, 0),
		"x": Vector3(0, 0, 1),
		"y": Vector3(0, 1, 0),
		"entry": "plane",
		"pick": Vector3(0, 10, 10),
	},
]


## Idempotent. A document that already has Front is left alone, so load
## does not grow a second set.
static func seed(doc) -> void:
	if doc == null:
		return
	for d in doc.datum_list():
		if str(d.get("name", "")) == "Front":
			return
	for row in BASIS:
		var id := str(doc.add_datum_plane(Vector3.ZERO, row["normal"]))
		if id == "":
			continue
		doc.rename_datum(id, str(row["name"]))


static func row(name: String) -> Dictionary:
	for row in BASIS:
		if str(row["name"]) == name:
			return row
	return {}


static func pick_point(name: String) -> Variant:
	var found := row(name)
	if found.is_empty():
		return null
	return found["pick"]


## Front uses the ground sketch. Right and Top use their BASIS row.
static func begin(main, name: String) -> void:
	var found := row(name)
	if found.is_empty() or str(found.get("entry", "")) == "ground":
		main._start_sketch_on_ground()
		return
	main._start_sketch_on_plane(Vector3.ZERO, found["x"], found["y"])


## A hit this close to another origin plane sits on an axis, not a unique quad.
const AXIS_BAND := 5.0
## Orbit yaw/pitch vs the datum normal. Iso look·n is ~0.44–0.64; named
## Front/Right/Top are ~1. Empty space behind a glancing quad stays ground.
const FACE_ON := 0.90


## Same frame as the visible quad in DocumentView.
static func frame(d: Dictionary) -> Dictionary:
	var origin: Vector3 = d["origin"]
	var normal: Vector3 = (d["normal"] as Vector3).normalized()
	var x_dir: Vector3 = d["x_dir"]
	var y_dir := normal.cross(x_dir).normalized()
	if y_dir.length_squared() < 1e-12:
		y_dir = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		y_dir = normal.cross(y_dir).normalized()
	x_dir = y_dir.cross(normal).normalized()
	return {"origin": origin, "normal": normal, "x": x_dir, "y": y_dir}


## Nearest unique finite quad, or "". Origin and the axes miss so empty
## space (and the walk's ground click at the origin) still starts XY.
static func ray_hit(view, ray_origin: Vector3, ray_dir: Vector3) -> String:
	if view == null or view.doc == null:
		return ""
	var datums: Array = view.doc.datum_list()
	var half := DocumentView.DATUM_PLANE_HALF
	var best_t := INF
	var best := ""
	var dir := ray_dir.normalized()
	var look := _look(view, dir)
	for d in datums:
		if str(d.get("kind", "")) != "plane":
			continue
		var fr := frame(d)
		var normal: Vector3 = fr["normal"]
		if absf(look.dot(normal)) < FACE_ON:
			continue
		var denom := dir.dot(normal)
		if absf(denom) < 1e-8:
			continue
		var t := ((fr["origin"] as Vector3) - ray_origin).dot(normal) / denom
		if t < 1e-4 or t >= best_t:
			continue
		var p := ray_origin + dir * t
		var rel := p - (fr["origin"] as Vector3)
		var u := rel.dot(fr["x"])
		var v := rel.dot(fr["y"])
		if absf(u) > half or absf(v) > half:
			continue
		if not _exclusive(p, d, datums):
			continue
		best_t = t
		best = str(d.get("name", ""))
	return best


## Orbit yaw/pitch in kernel Z-up, not `-basis.z` (empty-scene Y-bias tilts
## that under FACE_ON) and not the pick ray (iso screen-right can align with
## Right). Iso look·n is ~0.44–0.64; named Right/Front/Top are ~1.
static func _look(view, ray_dir: Vector3) -> Vector3:
	if view != null and view.is_inside_tree():
		var vp: Viewport = view.get_viewport()
		var cam: Camera3D = vp.get_camera_3d() if vp != null else null
		if cam != null:
			var world := _world_look(cam)
			var inv: Transform3D = view.global_transform.affine_inverse()
			return (inv.basis * world).normalized()
	return ray_dir.normalized()


static func _world_look(cam: Camera3D) -> Vector3:
	if cam is OrbitCamera:
		var oc: OrbitCamera = cam
		var yaw: float = oc.yaw
		var pitch: float = oc.pitch
		var sp := sin(pitch)
		var cp := cos(pitch)
		if absf(absf(pitch) - PI * 0.5) < 1e-5:
			sp = signf(pitch)
			cp = 0.0
		return Vector3(-cp * sin(yaw), -sp, -cp * cos(yaw)).normalized()
	return -cam.global_transform.basis.z.normalized()


static func _exclusive(p: Vector3, chosen: Dictionary, datums: Array) -> bool:
	var chosen_n: Vector3 = (chosen["normal"] as Vector3).normalized()
	var chosen_o: Vector3 = chosen.get("origin", Vector3.ZERO)
	for other in datums:
		if str(other.get("kind", "")) != "plane":
			continue
		var on: Vector3 = (other["normal"] as Vector3).normalized()
		var oo: Vector3 = other.get("origin", Vector3.ZERO)
		if absf(on.dot(chosen_n)) > 0.99 and oo.distance_squared_to(chosen_o) < 1e-12:
			continue
		var fr := frame(other)
		var dist := absf((p - (fr["origin"] as Vector3)).dot(fr["normal"]))
		if dist <= AXIS_BAND:
			return false
	return true
