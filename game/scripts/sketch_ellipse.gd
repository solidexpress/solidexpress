class_name SketchEllipse
extends RefCounted
## Real ellipse: three clicks (centre, major, minor). Optional Horizontal
## on the major-axis ends. Not a 32-gon.


const SPEC := {
	"clicks": 3,
	"order": ["centre", "major", "minor"],
	"infer": "horizontal_on_major_ends",
}


## Centre, full-axis rx/ry, and major-axis angle from three clicks.
static func pose(centre: Vector2, major: Vector2, minor: Vector2) -> Dictionary:
	var maj := major - centre
	var minv := minor - centre
	var rx := maj.length()
	var ry := minv.length()
	if rx <= 1e-6 or ry <= 1e-6:
		return {}
	var ang := maj.angle()
	# Minor click is a length; drop it onto the perpendicular so a sloppy
	# third click still makes an axis-aligned ellipse.
	var perp := Vector2(-maj.y, maj.x).normalized()
	ry = absf(minv.dot(perp))
	if ry <= 1e-6:
		return {}
	return {
		"center": centre,
		"rx": rx,
		"ry": ry,
		"angle": ang,
		"major_start": centre + maj.normalized() * rx,
		"major_end": centre - maj.normalized() * rx,
		"minor_start": centre + perp * ry,
		"minor_end": centre - perp * ry,
	}


## Ellipse id, or "" when a radius is zero.
static func build(sketch, centre: Vector2, major: Vector2, minor: Vector2,
		infer_horizontal := true) -> String:
	var posed := pose(centre, major, minor)
	if posed.is_empty():
		return ""
	if not sketch.has_method("add_ellipse"):
		return ""
	var eid: String = sketch.add_ellipse(
		posed["center"].x, posed["center"].y,
		float(posed["rx"]), float(posed["ry"]), float(posed["angle"]))
	if eid == "":
		return ""
	if infer_horizontal:
		var maj: Vector2 = posed["major_start"] - posed["center"]
		if absf(maj.y) <= absf(maj.x):
			sketch.add_constraint("horizontal", [
				{"entity": eid, "role": "start"},
				{"entity": eid, "role": "end"}], 0.0)
	return eid


## Axis-aligned bounds of the (possibly rotated) ellipse, or empty Rect2.
static func aabb(info: Dictionary) -> Rect2:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var rx := float(info.get("rx", 0.0))
	var ry := float(info.get("ry", 0.0))
	if rx <= 1e-9 or ry <= 1e-9:
		return Rect2()
	var ang := float(info.get("angle", 0.0))
	var ux := Vector2(rx, 0.0).rotated(ang)
	var uy := Vector2(0.0, ry).rotated(ang)
	var hw := absf(ux.x) + absf(uy.x)
	var hh := absf(ux.y) + absf(uy.y)
	return Rect2(c - Vector2(hw, hh), Vector2(hw * 2.0, hh * 2.0))


## Sample the ellipse curve in sketch UV.
static func polyline(info: Dictionary, steps := 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var rx := float(info.get("rx", 0.0))
	var ry := float(info.get("ry", 0.0))
	if rx <= 1e-9 or ry <= 1e-9:
		return out
	var ang := float(info.get("angle", 0.0))
	var n := maxi(8, steps)
	for i in range(n + 1):
		var t := TAU * float(i) / float(n)
		out.append(c + Vector2(rx * cos(t), ry * sin(t)).rotated(ang))
	return out


## Distance from `p` to the ellipse curve (approx).
static func distance(info: Dictionary, p: Vector2) -> float:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var rx := float(info.get("rx", 0.0))
	var ry := float(info.get("ry", 0.0))
	if rx <= 1e-9 or ry <= 1e-9:
		return INF
	var ang := float(info.get("angle", 0.0))
	var local := (p - c).rotated(-ang)
	var n := Vector2(local.x / rx, local.y / ry)
	if n.length_squared() < 1e-12:
		return minf(rx, ry)
	n = n.normalized()
	var on := Vector2(rx * n.x, ry * n.y)
	return local.distance_to(on)


## Closest point on the ellipse to `p`.
static func closest(info: Dictionary, p: Vector2) -> Vector2:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var rx := float(info.get("rx", 0.0))
	var ry := float(info.get("ry", 0.0))
	var ang := float(info.get("angle", 0.0))
	var local := (p - c).rotated(-ang)
	var n := Vector2(local.x / rx, local.y / ry)
	if n.length_squared() < 1e-12:
		return c + Vector2(rx, 0.0).rotated(ang)
	n = n.normalized()
	return c + Vector2(rx * n.x, ry * n.y).rotated(ang)


## "major" or "minor" according to which axis `p` is closer to.
static func axis_at(info: Dictionary, p: Vector2) -> String:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var ang := float(info.get("angle", 0.0))
	var local := (p - c).rotated(-ang)
	return "minor" if absf(local.y) > absf(local.x) else "major"
