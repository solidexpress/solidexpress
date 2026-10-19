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
	var t0 := float(info.get("start_angle", 0.0))
	var t1 := float(info.get("end_angle", TAU))
	if str(info.get("type", "")) == "elliptical_arc":
		if t1 <= t0:
			t1 += TAU
		n = maxi(8, int(ceil(absf(t1 - t0) / (TAU / float(n)))))
	else:
		t0 = 0.0
		t1 = TAU
	for i in range(n + 1):
		var t := t0 + (t1 - t0) * float(i) / float(n)
		out.append(c + Vector2(rx * cos(t), ry * sin(t)).rotated(ang))
	return out


## Ellipse parameter of `p` from the major axis.
static func param_at(info: Dictionary, p: Vector2) -> float:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var rx := float(info.get("rx", 0.0))
	var ry := float(info.get("ry", 0.0))
	var ang := float(info.get("angle", 0.0))
	if rx <= 1e-9 or ry <= 1e-9:
		return 0.0
	var local := (p - c).rotated(-ang)
	return atan2(local.y / ry, local.x / rx)


static func param_on_span(info: Dictionary, t: float) -> bool:
	if str(info.get("type", "")) != "elliptical_arc":
		return true
	var sa := float(info.get("start_angle", 0.0))
	var ea := float(info.get("end_angle", TAU))
	var span := ea - sa
	while span < 0.0:
		span += TAU
	if span < 1e-9:
		span = TAU
	var from := t - sa
	while from < 0.0:
		from += TAU
	while from >= TAU:
		from -= TAU
	return from <= span + 1e-6


## Distance from `p` to the ellipse (or remaining elliptical-arc) curve.
static func distance(info: Dictionary, p: Vector2) -> float:
	var on := closest(info, p)
	return p.distance_to(on)


## Closest point on the ellipse (or remaining arc) to `p`.
static func closest(info: Dictionary, p: Vector2) -> Vector2:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var rx := float(info.get("rx", 0.0))
	var ry := float(info.get("ry", 0.0))
	var ang := float(info.get("angle", 0.0))
	if rx <= 1e-9 or ry <= 1e-9:
		return c
	var local := (p - c).rotated(-ang)
	var n := Vector2(local.x / rx, local.y / ry)
	if n.length_squared() < 1e-12:
		n = Vector2(1.0, 0.0)
	else:
		n = n.normalized()
	var on := c + Vector2(rx * n.x, ry * n.y).rotated(ang)
	if param_on_span(info, param_at(info, on)):
		return on
	var a: Vector2 = info.get("start", on)
	var b: Vector2 = info.get("end", on)
	return a if p.distance_to(a) <= p.distance_to(b) else b


## "major" or "minor" according to which axis `p` is closer to.
static func axis_at(info: Dictionary, p: Vector2) -> String:
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var ang := float(info.get("angle", 0.0))
	var local := (p - c).rotated(-ang)
	return "minor" if absf(local.y) > absf(local.x) else "major"
