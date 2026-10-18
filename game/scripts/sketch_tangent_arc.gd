class_name SketchTangentArc
extends RefCounted
## Tangent Arc: first click near an endpoint of a line or arc adds Tangent
## to that host and coincident start. Second click is the end. Empty-space
## two clicks stay a free arc in SketchMode. Radius 0 adds nothing.


const POLICY := {
	"host": "line_or_arc_endpoint",
	"constraints": ["coincident_start", "tangent"],
	"radius_zero": "refuse",
}

const MIN_RADIUS := 1e-4
## Centre+ends on a diameter line (SW coincident-with-line). View-span snap
## is much larger than a wrench throat offset, so do not use it here.
const ON_LINE_MM := 0.5


## Host endpoint within `tol`, or {} if the click is empty space.
static func host_at(sketch, pos: Vector2, tol: float) -> Dictionary:
	if sketch == null:
		return {}
	var best := {}
	var best_d := tol
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "line" and kind != "arc":
			continue
		for role in ["start", "end"]:
			var pt: Vector2 = info[role]
			var d := pos.distance_to(pt)
			if d < best_d:
				best_d = d
				best = {
					"id": str(id),
					"role": role,
					"point": pt,
					"tangent": _tangent_at(info, kind, role),
				}
	return best


## Centre, radius, and CCW angles for a G1 arc from `start` along `tangent`.
static func pose(start: Vector2, tangent: Vector2, end: Vector2) -> Dictionary:
	if tangent.length_squared() < 1e-12:
		return {}
	var t := tangent.normalized()
	var chord := end - start
	if chord.length_squared() < 1e-12:
		return {}
	var n := Vector2(-t.y, t.x)
	var proj := chord.dot(n)
	if absf(proj) < 1e-9:
		return {}
	if proj < 0.0:
		n = -n
		proj = -proj
	var radius := chord.length_squared() / (2.0 * proj)
	if radius <= MIN_RADIUS:
		return {}
	var center: Vector2 = start + n * radius
	var sa := (start - center).angle()
	var ea := (end - center).angle()
	return {
		"center": center,
		"radius": radius,
		"start_angle": sa,
		"end_angle": ea,
	}


## Arc id, or "" when there is no host or the radius is zero.
static func build(sketch, start: Vector2, end: Vector2, tol: float) -> String:
	var host := host_at(sketch, start, tol)
	if host.is_empty():
		return ""
	var posed := pose(host["point"], host["tangent"], end)
	if posed.is_empty():
		return ""
	var c: Vector2 = posed["center"]
	var r := float(posed["radius"])
	var host_pt: Vector2 = host["point"]
	var sa := (host_pt - c).angle()
	var ea := (end - c).angle()
	# Kernel arcs are CCW. A "right then down" quarter is CW from the host,
	# so store the complementary CCW and coincident the matching end.
	var host_role := "start"
	if (host_pt - c).cross(end - c) < 0.0:
		var tmp := sa
		sa = ea
		ea = tmp
		host_role = "end"
	var aid: String = sketch.add_arc(c.x, c.y, r, sa, ea)
	if aid == "":
		return ""
	sketch.add_constraint("coincident", [
		{"entity": aid, "role": host_role},
		{"entity": host["id"], "role": host["role"]}], 0.0)
	var host_kind := str(sketch.entity_info(host["id"]).get("type", ""))
	if host_kind == "line":
		sketch.add_constraint("tangent", [
			{"entity": host["id"], "role": "self"},
			{"entity": aid, "role": "self"}], 0.0)
	else:
		sketch.add_constraint("tangent", [
			{"entity": host["id"], "role": "self"},
			{"entity": aid, "role": "self"}], 0.0)
	return aid


## Three clicks: start, bulge, end. Kernel arcs are CCW, so the stored sweep
## is the half that contains the bulge (not the complementary half).
static func add_three_point(sketch, p1: Vector2, p2: Vector2, p3: Vector2, tol: float) -> String:
	if sketch == null:
		return ""
	var ctr_v: Variant = circumcenter(p1, p2, p3)
	if ctr_v == null:
		return ""
	var ctr: Vector2 = ctr_v
	var r := ctr.distance_to(p1)
	if r <= MIN_RADIUS:
		return ""
	var sa := (p1 - ctr).angle()
	var ea := (p3 - ctr).angle()
	var ma := (p2 - ctr).angle()
	if not _ccw_contains(ma, sa, ea):
		var tmp := sa
		sa = ea
		ea = tmp
	var aid: String = sketch.add_arc(ctr.x, ctr.y, r, sa, ea)
	if aid == "":
		return ""
	constrain_three_point_on_line(sketch, aid, p1, p3, minf(tol, ON_LINE_MM))
	return aid


static func circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Variant:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-12:
		return null
	var ux := ((a.x * a.x + a.y * a.y) * (b.y - c.y)
			+ (b.x * b.x + b.y * b.y) * (c.y - a.y)
			+ (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d
	var uy := ((a.x * a.x + a.y * a.y) * (c.x - b.x)
			+ (b.x * b.x + b.y * b.y) * (a.x - c.x)
			+ (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d
	return Vector2(ux, uy)


static func _ccw_contains(ang: float, sa: float, ea: float) -> bool:
	var from := fposmod(ang - sa, TAU)
	var span := fposmod(ea - sa, TAU)
	if span < 1e-9:
		span = TAU
	return from <= span + 1e-6


## After a 3-point commit: centre and both ends on the same line pick up
## point-on-line (SW "coincident with the line").
static func constrain_three_point_on_line(sketch, arc_id: String, p1: Vector2, p3: Vector2, tol: float) -> void:
	if sketch == null or arc_id == "":
		return
	var info: Dictionary = sketch.entity_info(arc_id)
	if str(info.get("type", "")) != "arc":
		return
	var center: Vector2 = info["center"]
	var line_id := _line_through(sketch, center, p1, p3, tol)
	if line_id == "":
		return
	sketch.add_constraint("point_on_line", [
		{"entity": arc_id, "role": "center"},
		{"entity": line_id, "role": "self"}], 0.0)
	for role in ["start", "end"]:
		var pt: Vector2 = info[role]
		var hit := _endpoint_on_line(sketch, line_id, pt, tol)
		if not hit.is_empty():
			sketch.add_constraint("coincident", [
				{"entity": arc_id, "role": role},
				{"entity": hit["id"], "role": hit["role"]}], 0.0)
		else:
			sketch.add_constraint("point_on_line", [
				{"entity": arc_id, "role": role},
				{"entity": line_id, "role": "self"}], 0.0)


static func _tangent_at(info: Dictionary, kind: String, role: String) -> Vector2:
	if kind == "line":
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		return (b - a) if role == "end" else (a - b)
	var c: Vector2 = info["center"]
	var p: Vector2 = info[role]
	var radial := p - c
	if radial.length_squared() < 1e-12:
		return Vector2.RIGHT
	# CCW tangent at the end; opposite at the start so the chain continues out.
	var ccw := Vector2(-radial.y, radial.x)
	return ccw if role == "end" else -ccw


static func _line_through(sketch, center: Vector2, a: Vector2, b: Vector2, tol: float) -> String:
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		if SketchGeom.point_line_distance(center, s, e) > tol:
			continue
		if SketchGeom.point_line_distance(a, s, e) > tol:
			continue
		if SketchGeom.point_line_distance(b, s, e) > tol:
			continue
		return str(id)
	return ""


static func _endpoint_on_line(sketch, line_id: String, pt: Vector2, tol: float) -> Dictionary:
	var info: Dictionary = sketch.entity_info(line_id)
	if pt.distance_to(info["start"]) <= tol:
		return {"id": line_id, "role": "start"}
	if pt.distance_to(info["end"]) <= tol:
		return {"id": line_id, "role": "end"}
	return {}
