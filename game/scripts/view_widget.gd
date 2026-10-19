class_name ViewWidget
extends Control
## Perspective ViewCube (70–90 px). Labelled faces; corners are isometric
## octants. Click jumps the linked OrbitCamera (keys 1/2/3/7 stay).

@export var camera: OrbitCamera
## When true, click_zone / gui clicks use duration 0 (instant snap).
var snap := false

const WIDGET_SIZE := 84.0
const ZONE_EPS := 0.08
const HOVER := Color(0.35, 0.55, 0.75)
const FACE_FILL := Color(0.30, 0.34, 0.40, 1.0)
const FACE_EDGE := Color(0.55, 0.60, 0.65, 1.0)
const LABEL := Color(0.92, 0.94, 0.96)
const CORNER_R := 7.0

const FACES: Array = [
	{"id": "front", "n": Vector3(0, 0, 1), "label": "FRONT"},
	{"id": "back", "n": Vector3(0, 0, -1), "label": "BACK"},
	{"id": "right", "n": Vector3(1, 0, 0), "label": "RIGHT"},
	{"id": "left", "n": Vector3(-1, 0, 0), "label": "LEFT"},
	{"id": "top", "n": Vector3(0, 1, 0), "label": "TOP"},
	{"id": "bottom", "n": Vector3(0, -1, 0), "label": "BOT"},
]

## Vertex in cube space (±1) → iso-corner id. KEY_7 iso is Front-Top-Left.
const CORNERS: Array = [
	{"id": "iso_ftl", "p": Vector3(-1, 1, 1), "yaw": -35.0, "pitch": 40.0},
	{"id": "iso_ftr", "p": Vector3(1, 1, 1), "yaw": 35.0, "pitch": 40.0},
	{"id": "iso_fbl", "p": Vector3(-1, -1, 1), "yaw": -35.0, "pitch": -40.0},
	{"id": "iso_fbr", "p": Vector3(1, -1, 1), "yaw": 35.0, "pitch": -40.0},
	{"id": "iso_btl", "p": Vector3(-1, 1, -1), "yaw": -145.0, "pitch": 40.0},
	{"id": "iso_btr", "p": Vector3(1, 1, -1), "yaw": 145.0, "pitch": 40.0},
	{"id": "iso_bbl", "p": Vector3(-1, -1, -1), "yaw": -145.0, "pitch": -40.0},
	{"id": "iso_bbr", "p": Vector3(1, -1, -1), "yaw": 145.0, "pitch": -40.0},
]

var _hover := ""


func _ready() -> void:
	custom_minimum_size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_camera(camera)
	queue_redraw()


func set_camera(cam: OrbitCamera) -> void:
	if camera != null and camera.view_changed.is_connected(queue_redraw):
		camera.view_changed.disconnect(queue_redraw)
	camera = cam
	if camera != null:
		camera.view_changed.connect(queue_redraw)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func zone_at(local_pos: Vector2) -> String:
	if local_pos.x < 0.0 or local_pos.y < 0.0 or local_pos.x >= size.x or local_pos.y >= size.y:
		return ""
	var best_corner := ""
	var best_d := CORNER_R * CORNER_R
	for c in CORNERS:
		if not _corner_visible(c["p"]):
			continue
		var d := local_pos.distance_squared_to(_project(c["p"]))
		if d < best_d:
			best_d = d
			best_corner = str(c["id"])
	if best_corner != "":
		return best_corner
	var eye := _cam_eye()
	var best_face := ""
	var best_dot := 0.05
	for f in FACES:
		var n: Vector3 = f["n"]
		var d: float = n.dot(eye)
		if d < 0.05:
			continue
		var quad := _face_quad(n)
		if _point_in_quad(local_pos, quad) and d > best_dot:
			best_dot = d
			best_face = str(f["id"])
	return best_face


func click_zone(zone: String) -> void:
	if camera == null or not has_zone(zone):
		return
	if camera.sketch_orientation_locked:
		return
	if zone == "iso":
		zone = "iso_ftl"
	camera.apply_standard_view_id(zone, not snap)


func has_zone(zone: String) -> bool:
	if zone == "iso":
		return true
	for f in FACES:
		if str(f["id"]) == zone:
			return true
	for c in CORNERS:
		if str(c["id"]) == zone:
			return true
	return false


func hit_pos(zone: String) -> Vector2:
	if zone == "iso":
		zone = "iso_ftl"
	for c in CORNERS:
		if str(c["id"]) == zone:
			return _project(c["p"])
	for f in FACES:
		if str(f["id"]) == zone:
			return _project(f["n"])
	return size * 0.5


func angles_for(zone: String) -> Vector2:
	if zone == "iso":
		zone = "iso_ftl"
	var spec := OrbitCamera.standard_view_by_id(zone)
	if spec.is_empty():
		for c in CORNERS:
			if str(c["id"]) == zone:
				return Vector2(deg_to_rad(float(c["yaw"])), deg_to_rad(float(c["pitch"])))
		return Vector2.ZERO
	return Vector2(deg_to_rad(float(spec["yaw"])), deg_to_rad(float(spec["pitch"])))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var z := zone_at((event as InputEventMouseMotion).position)
		if z != _hover:
			_hover = z
			queue_redraw()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var zone := zone_at(mb.position)
			if zone != "":
				click_zone(zone)
				accept_event()


func _draw() -> void:
	var eye := _cam_eye()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.14, 0.16, 0.18, 0.0), true)
	var faces: Array = []
	for f in FACES:
		var n: Vector3 = f["n"]
		var d: float = n.dot(eye)
		if d <= 0.02:
			continue
		faces.append({"f": f, "d": d})
	faces.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var font := ThemeDB.fallback_font
	var active := _current_zone()
	for item in faces:
		var f: Dictionary = item["f"]
		var z: String = str(f["id"])
		var quad := _face_quad(f["n"])
		var fill := FACE_FILL
		if z == active or z == _hover:
			fill = HOVER
		draw_colored_polygon(PackedVector2Array(quad), fill)
		draw_polyline(PackedVector2Array(quad + [quad[0]]), FACE_EDGE, 1.2, true)
		var label: String = str(f["label"])
		var fs := 9 if label.length() > 4 else 10
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var mid: Vector2 = _project(f["n"])
		draw_string(font, mid - text_size * 0.5 + Vector2(0, text_size.y * 0.35),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LABEL)
	for c in CORNERS:
		if not _corner_visible(c["p"]):
			continue
		var p: Vector2 = _project(c["p"])
		var cid: String = str(c["id"])
		var col := Color(0.72, 0.76, 0.80, 1.0)
		if cid == active or cid == _hover or (cid == "iso_ftl" and active == "iso"):
			col = HOVER
		draw_circle(p, 3.4, col)


func _current_zone() -> String:
	if camera == null:
		return ""
	for z in ["front", "back", "right", "left", "top", "bottom"]:
		var a: Vector2 = angles_for(z)
		var dyaw := absf(wrapf(camera.yaw - a.x, -PI, PI))
		if dyaw < ZONE_EPS and absf(camera.pitch - a.y) < ZONE_EPS:
			return z
	for c in CORNERS:
		var a2: Vector2 = angles_for(str(c["id"]))
		var dyaw2 := absf(wrapf(camera.yaw - a2.x, -PI, PI))
		if dyaw2 < ZONE_EPS and absf(camera.pitch - a2.y) < ZONE_EPS:
			return str(c["id"])
	return ""


func _cam_eye() -> Vector3:
	var yaw := deg_to_rad(-35.0)
	var pitch := deg_to_rad(40.0)
	if camera != null:
		yaw = camera.yaw
		pitch = camera.pitch
	var sp := sin(pitch)
	var cp := cos(pitch)
	return Vector3(cp * sin(yaw), sp, cp * cos(yaw)).normalized()


func _project(p: Vector3) -> Vector2:
	var eye := _cam_eye()
	var up := Vector3.UP
	if absf(eye.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var zaxis := eye
	var xaxis := up.cross(zaxis)
	if xaxis.length_squared() < 1e-8:
		xaxis = Vector3.RIGHT.cross(zaxis)
	xaxis = xaxis.normalized()
	var yaxis := zaxis.cross(xaxis).normalized()
	var local := Vector3(p.dot(xaxis), p.dot(yaxis), p.dot(zaxis))
	var persp := 1.55 / (2.15 + local.z)
	var c := size * 0.5
	var scale := minf(size.x, size.y) * 0.36
	return c + Vector2(local.x, -local.y) * scale * persp


func _face_quad(n: Vector3) -> Array:
	var t := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := t.cross(n).normalized()
	var v := n.cross(u).normalized()
	return [
		_project(n + u + v),
		_project(n - u + v),
		_project(n - u - v),
		_project(n + u - v),
	]


func _corner_visible(p: Vector3) -> bool:
	return p.normalized().dot(_cam_eye()) > 0.05


func _point_in_quad(p: Vector2, quad: Array) -> bool:
	return _point_in_tri(p, quad[0], quad[1], quad[2]) \
			or _point_in_tri(p, quad[0], quad[2], quad[3])


func _point_in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var inv := dot00 * dot11 - dot01 * dot01
	if absf(inv) < 1e-10:
		return false
	var u := (dot11 * dot02 - dot01 * dot12) / inv
	var v := (dot00 * dot12 - dot01 * dot02) / inv
	return u >= -0.02 and v >= -0.02 and (u + v) <= 1.02
