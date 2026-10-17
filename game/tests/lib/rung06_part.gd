class_name Rung06Part
extends RefCounted
## Kernel-side candlestick sketches for WP6/WP8 suites. Clicks own Sweep/Cut.


## CCW arc from `start` to `end` that contains `through`. Endpoints are then
## written back so they match the joining lines (float32 angle round-trip
## otherwise opens the loop past profile_face's 1e-6 join).
static func _arc_through(sk, c: Vector2, r: float, start: Vector2, end: Vector2,
		through: Vector2) -> String:
	var sa := (start - c).angle()
	var ea := (end - c).angle()
	var ta := (through - c).angle()
	var ea1 := ea
	while ea1 <= sa + 1.0e-9:
		ea1 += TAU
	var t := ta
	while t < sa - 1.0e-9:
		t += TAU
	var eid: String
	if t <= ea1 + 1.0e-9:
		eid = str(sk.add_arc(c.x, c.y, r, sa, ea1))
	else:
		var sa2 := ea
		var ea2 := sa
		while ea2 <= sa2 + 1.0e-9:
			ea2 += TAU
		eid = str(sk.add_arc(c.x, c.y, r, sa2, ea2))
	if eid == "":
		return ""
	var info: Dictionary = sk.entity_info(eid)
	var ast: Vector2 = info.get("start", start)
	if ast.distance_to(start) <= ast.distance_to(end):
		sk.set_entity_geometry(eid, {"start": start, "end": end})
	else:
		sk.set_entity_geometry(eid, {"start": end, "end": start})
	return eid


static func add_revolve_profile(sk) -> void:
	sk.add_line(0.0, 0.0, 0.0, 220.0)
	sk.add_line(0.0, 220.0, 20.0, 220.0)
	_arc_through(sk, Vector2(20.0, 210.0), 10.0, Vector2(30.0, 210.0), Vector2(20.0, 220.0),
			Vector2(27.0, 217.0))
	sk.add_line(30.0, 210.0, 30.0, 170.0)
	_arc_through(sk, Vector2(30.0, 150.0), 20.0, Vector2(30.0, 130.0), Vector2(30.0, 170.0),
			Vector2(50.0, 150.0))
	sk.add_line(30.0, 130.0, 30.0, 80.0)
	var c60 := Vector2(90.0, 80.0)
	var r60 := 60.0
	var c12 := Vector2(99.499, 8.125)
	var d := c60.distance_to(c12)
	var tanp: Vector2 = c60 + (c12 - c60) * (r60 / d)
	var r12 := c12.distance_to(tanp)
	var clip := Vector2(c12.x + sqrt(maxf(0.0, r12 * r12 - c12.y * c12.y)), 0.0)
	_arc_through(sk, c60, r60, Vector2(30.0, 80.0), tanp, Vector2(90.0, 20.0))
	_arc_through(sk, c12, r12, tanp, clip, Vector2(c12.x + r12, c12.y))
	sk.add_line(clip.x, clip.y, 0.0, 0.0)


static func add_path(sk) -> void:
	sk.add_line(0.0, 10.0, 60.0, 10.0)
	var c150 := Vector2(60.0, 160.0)
	var r150 := 150.0
	var c20 := Vector2(167.113, 86.333)
	var dir: Vector2 = (c20 - c150).normalized()
	var tanp: Vector2 = c150 + dir * r150
	var r20 := c20.distance_to(tanp)
	var hook_end := Vector2(150.634, 75.0)
	_arc_through(sk, c150, r150, Vector2(60.0, 10.0), tanp, Vector2(150.0, 40.0))
	_arc_through(sk, c20, r20, tanp, hook_end, Vector2(c20.x + r20, c20.y))


static func add_ellipse(sk) -> String:
	return str(sk.add_ellipse(0.0, 10.0, 17.5, 5.0, 0.0))
