class_name SketchCircleTangent
extends RefCounted
## Perimeter circle tangent to two lines. The third click is the side.
## A zero inset adds nothing. Misses stay a circumcircle in SketchMode.


const MIN_RADIUS := 1e-4


## True when the first two picks land on two different lines.
static func two_lines(sketch, p1: Vector2, p2: Vector2, tol: float) -> bool:
	var a := line_at(sketch, p1, tol)
	var b := line_at(sketch, p2, tol)
	return a != "" and b != "" and a != b


## Nearest line segment within `tol`, construction included. "" if none.
static func line_at(sketch, pos: Vector2, tol: float) -> String:
	if sketch == null:
		return ""
	var best := ""
	var best_d := tol
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d := SketchGeom.point_segment_distance(pos, info["start"], info["end"])
		if d < best_d:
			best_d = d
			best = str(id)
	return best


## Circle id tangent to both lines on `side`'s side, or "" when the inset is zero.
static func build(sketch, p1: Vector2, p2: Vector2, side: Vector2, tol: float) -> String:
	var a := line_at(sketch, p1, tol)
	var b := line_at(sketch, p2, tol)
	if a == "" or b == "" or a == b:
		return ""
	var ia: Dictionary = sketch.entity_info(a)
	var ib: Dictionary = sketch.entity_info(b)
	var pose := _pose(ia["start"], ia["end"], ib["start"], ib["end"], side)
	if pose.is_empty():
		return ""
	var center: Vector2 = pose["center"]
	var radius := float(pose["radius"])
	var cid: String = sketch.add_circle(center.x, center.y, radius)
	if cid == "":
		return ""
	# Solver tangent is line then circle.
	sketch.add_constraint("tangent", [
		{"entity": a, "role": "self"},
		{"entity": cid, "role": "self"}], 0.0)
	sketch.add_constraint("tangent", [
		{"entity": b, "role": "self"},
		{"entity": cid, "role": "self"}], 0.0)
	return cid


static func _pose(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, side: Vector2) -> Dictionary:
	var da := a1 - a0
	var db := b1 - b0
	if da.length_squared() < 1e-12 or db.length_squared() < 1e-12:
		return {}
	var na := Vector2(-da.y, da.x).normalized()
	var nb := Vector2(-db.y, db.x).normalized()
	if (side - a0).dot(na) < 0.0:
		na = -na
	if (side - b0).dot(nb) < 0.0:
		nb = -nb
	var cross := da.x * db.y - da.y * db.x
	if absf(cross) <= 1e-8 * da.length() * db.length():
		return _parallel(a0, da, na, b0, nb, side)
	var hit: Variant = _intersect(a0, da, b0, db)
	if hit == null:
		return {}
	var corner: Vector2 = hit
	var radius := minf(absf((side - a0).dot(na)), absf((side - b0).dot(nb)))
	if radius <= MIN_RADIUS:
		return {}
	var denom := 1.0 + na.dot(nb)
	if absf(denom) <= 1e-6:
		return {}
	return {"center": corner + (na + nb) * (radius / denom), "radius": radius}


## Two parallel lines: the circle sits in the gap, diameter equal to the gap.
static func _parallel(a0: Vector2, da: Vector2, na: Vector2, b0: Vector2, nb: Vector2, side: Vector2) -> Dictionary:
	if na.dot(nb) > -0.5:
		return {}
	var gap := absf((b0 - a0).dot(na))
	var radius := gap * 0.5
	if radius <= MIN_RADIUS:
		return {}
	var along := da.normalized()
	var t := (side - a0).dot(along)
	return {"center": a0 + along * t + na * radius, "radius": radius}


static func _intersect(origin: Vector2, dir: Vector2, other: Vector2, other_dir: Vector2) -> Variant:
	var cross := dir.x * other_dir.y - dir.y * other_dir.x
	if absf(cross) < 1e-12:
		return null
	var d := other - origin
	var t := (d.x * other_dir.y - d.y * other_dir.x) / cross
	return origin + dir * t
