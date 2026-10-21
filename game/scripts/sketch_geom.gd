class_name SketchGeom
extends RefCounted
## Segment and rect distances. Zero-length segments measure to the first endpoint
## (Geometry2D / Geometry3D do the same).


static func point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Perpendicular distance to the infinite line through `a` and `b`.
static func point_line_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len := ab.length()
	if len < 1e-9:
		return p.distance_to(a)
	return absf((p - a).cross(ab)) / len


## Power Trim pick: on the segment, or a short overflow past an end.
static func trim_line_pick_distance(p: Vector2, a: Vector2, b: Vector2,
		on_mm: float = 3.0, overflow_mm: float = 25.0) -> float:
	var perp := point_line_distance(p, a, b)
	if perp > on_mm:
		return point_segment_distance(p, a, b)
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1e-12:
		return p.distance_to(a)
	var t := (p - a).dot(ab) / len2
	if t >= 0.0 and t <= 1.0:
		return perp
	var past := p.distance_to(a) if t < 0.0 else p.distance_to(b)
	if past <= overflow_mm:
		return perp
	return point_segment_distance(p, a, b)


static func point_rect_distance(p: Vector2, rect: Rect2) -> float:
	var c := Vector2(
		clampf(p.x, rect.position.x, rect.end.x),
		clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(c)


static func segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for i in corners.size():
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % corners.size()]) != null:
			return 0.0
	var best := point_rect_distance(a, rect)
	best = minf(best, point_rect_distance(b, rect))
	for c in corners:
		best = minf(best, point_segment_distance(c, a, b))
	return best


static func closest_point_on_segment_3d(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	return Geometry3D.get_closest_point_to_segment(p, a, b)


static func point_segment_distance_3d(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(closest_point_on_segment_3d(p, a, b))
