class_name PolygonPose
extends RefCounted
## AF hex pose. regularize and inscribed_circle run at commit.
## vertical_pair turns two opposite vertices onto X = 0.
## sketch_mode calls these; it does not branch on the hex.


const _WELD := 0.001
const _ORIGIN_TOL := 0.5


## Drop this loop's horizontals, turn the chord vertical, and lock that pose.
## Horizontals on any other line stay.
static func vertical_pair(sketch, endpoint_a: Dictionary, endpoint_b: Dictionary) -> String:
	if sketch == null:
		return ""
	var lines := _loop_lines(sketch, endpoint_a, endpoint_b)
	if lines.is_empty():
		return ""
	var before := str(sketch.snapshot()) if sketch.has_method("snapshot") else ""
	var flats := _drop_loop_horizontals(sketch, lines)
	_seed_share_x(sketch, lines, endpoint_a, endpoint_b)
	var cid := str(sketch.add_constraint("vertical", [endpoint_a, endpoint_b], 0.0))
	if cid == "":
		_restore_horizontals(sketch, flats)
		return ""
	# The second horizontal locked rotation. A flat that is now vertical does.
	_vertical_on_flat(sketch, flats)
	var res: Dictionary = sketch.solve()
	if str(res.get("status", "")) == "failed" and before != "":
		sketch.restore(before)
		return ""
	return cid


## Equal edges, and opposite edges parallel, so the hex stays regular
## after the flat horizontals drop. Not a driving dimension.
static func regularize(sketch, line_ids: Array) -> void:
	if sketch == null or line_ids.size() < 3:
		return
	var first := str(line_ids[0])
	for i in range(1, line_ids.size()):
		sketch.add_constraint("equal", [
			{"entity": first, "role": "self"},
			{"entity": str(line_ids[i]), "role": "self"}], 0.0)
	var n := line_ids.size()
	if n % 2 != 0:
		return
	var half := n / 2
	for i in half:
		sketch.add_constraint("parallel", [
			{"entity": str(line_ids[i]), "role": "self"},
			{"entity": str(line_ids[i + half]), "role": "self"}], 0.0)


## Construction incircle. Tangency follows the one driving flat distance.
## The circle is not a second dimension and is not part of the profile.
static func inscribed_circle(sketch, line_ids: Array) -> String:
	if sketch == null or line_ids.size() < 4:
		return ""
	var flats := _opposite_flats(sketch, line_ids)
	if flats.size() != 2:
		return ""
	var a: Dictionary = sketch.entity_info(flats[0])
	var b: Dictionary = sketch.entity_info(flats[1])
	var ma: Vector2 = (a["start"] + a["end"]) * 0.5
	var mb: Vector2 = (b["start"] + b["end"]) * 0.5
	var centre := (ma + mb) * 0.5
	var radius := ma.distance_to(mb) * 0.5
	if radius < 1e-6:
		return ""
	var cid := str(sketch.add_circle(centre.x, centre.y, radius))
	if cid == "":
		return ""
	sketch.set_construction(cid, true)
	var origin := _origin_point(sketch)
	if origin != "":
		sketch.add_constraint("coincident", [
			{"entity": cid, "role": "center"},
			{"entity": origin, "role": "self"}], 0.0)
	for id in line_ids:
		sketch.add_constraint("tangent", [
			{"entity": str(id), "role": "self"},
			{"entity": cid, "role": "self"}], 0.0)
	return cid


static func _seed_share_x(sketch, lines: Array[String], endpoint_a: Dictionary, endpoint_b: Dictionary) -> void:
	var pa := _pos(sketch, endpoint_a)
	var pb := _pos(sketch, endpoint_b)
	var chord := pb - pa
	if chord.length_squared() < 1e-12:
		return
	var theta := _angle_to_vertical(chord)
	if absf(theta) < 1e-8:
		return
	var centre := (pa + pb) * 0.5
	var verts: Array[Vector2] = []
	for id in lines:
		var info: Dictionary = sketch.entity_info(id)
		verts.append(info["start"])
		verts.append(info["end"])
	for id in lines:
		_rotate_line(sketch, id, centre, theta)
	for id in sketch.entity_ids():
		var sid := str(id)
		if lines.has(sid):
			continue
		var info: Dictionary = sketch.entity_info(sid)
		if str(info.get("type", "")) != "line" or not bool(info.get("construction", false)):
			continue
		if _near_any(info["start"], verts) or _near_any(info["end"], verts):
			_rotate_line(sketch, sid, centre, theta)


static func _angle_to_vertical(v: Vector2) -> float:
	var ang := atan2(v.y, v.x)
	var up := _wrap(PI * 0.5 - ang)
	var down := _wrap(-PI * 0.5 - ang)
	return up if absf(up) <= absf(down) else down


static func _wrap(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a


static func _rotate_line(sketch, id: String, centre: Vector2, theta: float) -> void:
	var info: Dictionary = sketch.entity_info(id)
	if info.is_empty():
		return
	sketch.set_entity_geometry(id, {
		"start": _rot(info["start"], centre, theta),
		"end": _rot(info["end"], centre, theta),
	})


static func _rot(p: Vector2, centre: Vector2, theta: float) -> Vector2:
	var d := p - centre
	var c := cos(theta)
	var s := sin(theta)
	return centre + Vector2(d.x * c - d.y * s, d.x * s + d.y * c)


static func _near_any(p: Vector2, pts: Array[Vector2]) -> bool:
	for q in pts:
		if p.distance_to(q) <= _WELD:
			return true
	return false


static func _vertical_on_flat(sketch, flats: Array[String]) -> String:
	for lid in flats:
		var info: Dictionary = sketch.entity_info(lid)
		if info.is_empty():
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.x - b.x) <= 0.05 and absf(a.y - b.y) > 0.5:
			return str(sketch.add_constraint("vertical", [
				{"entity": lid, "role": "self"}], 0.0))
	return ""


static func _origin_point(sketch) -> String:
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "point":
			continue
		if not bool(info.get("construction", false)) or not _has_fix(sketch, str(id)):
			continue
		var p: Vector2 = info["position"]
		if p.length() <= _ORIGIN_TOL:
			return str(id)
	var origin := str(sketch.add_point(0.0, 0.0))
	if origin == "":
		return ""
	sketch.set_construction(origin, true)
	sketch.add_constraint("fix", [{"entity": origin, "role": "self"}], 0.0)
	return origin


static func _has_fix(sketch, id: String) -> bool:
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "fix":
			continue
		for ref in info.get("refs", []):
			if typeof(ref) == TYPE_DICTIONARY and str(ref.get("entity", "")) == id:
				return true
	return false


static func _opposite_flats(sketch, line_ids: Array) -> Array[String]:
	var best := -1.0
	var pair: Array[String] = []
	for i in line_ids.size():
		var ia: Dictionary = sketch.entity_info(str(line_ids[i]))
		var da: Vector2 = ia["end"] - ia["start"]
		for j in range(i + 1, line_ids.size()):
			var ib: Dictionary = sketch.entity_info(str(line_ids[j]))
			var db: Vector2 = ib["end"] - ib["start"]
			if da.length_squared() < 1e-12 or db.length_squared() < 1e-12:
				continue
			if absf(da.cross(db)) > 1e-3 * da.length() * db.length():
				continue
			var ma: Vector2 = (ia["start"] + ia["end"]) * 0.5
			var mb: Vector2 = (ib["start"] + ib["end"]) * 0.5
			var gap := ma.distance_to(mb)
			if gap > best:
				best = gap
				pair = [str(line_ids[i]), str(line_ids[j])]
	return pair


static func _drop_loop_horizontals(sketch, lines: Array[String]) -> Array[String]:
	var on_loop := {}
	for id in lines:
		on_loop[id] = true
	var drop: Array[String] = []
	var owners: Array[String] = []
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "horizontal":
			continue
		for ref in info.get("refs", []):
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			var ent := str(ref.get("entity", ""))
			if on_loop.has(ent):
				drop.append(str(cid))
				owners.append(ent)
				break
	for cid in drop:
		sketch.remove_constraint(cid)
	return owners


static func _restore_horizontals(sketch, owners: Array[String]) -> void:
	for lid in owners:
		sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)


static func _loop_lines(sketch, endpoint_a: Dictionary, endpoint_b: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line" or bool(info.get("construction", false)):
			continue
		ids.append(str(id))
	var parent := {}
	for id in ids:
		parent[id] = id
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if _lines_welded(sketch, ids[i], ids[j]):
				_union(parent, ids[i], ids[j])
	var root := _find(parent, str(endpoint_a.get("entity", "")))
	if root == "":
		root = _find(parent, str(endpoint_b.get("entity", "")))
	var out: Array[String] = []
	for id in ids:
		if _find(parent, id) == root and root != "":
			out.append(id)
	return out


static func _lines_welded(sketch, a: String, b: String) -> bool:
	var ia: Dictionary = sketch.entity_info(a)
	var ib: Dictionary = sketch.entity_info(b)
	for pa in [ia["start"], ia["end"]]:
		for pb in [ib["start"], ib["end"]]:
			if (pa as Vector2).distance_to(pb) <= _WELD:
				return true
	return false


static func _find(parent: Dictionary, id: String) -> String:
	if not parent.has(id):
		return ""
	var seen := {}
	while parent[id] != id and not seen.has(id):
		seen[id] = true
		id = str(parent[id])
	return id


static func _union(parent: Dictionary, a: String, b: String) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != "" and rb != "" and ra != rb:
		parent[rb] = ra


static func _pos(sketch, ref: Dictionary) -> Vector2:
	var info: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
	if str(ref.get("role", "start")) == "end":
		return info["end"]
	return info["start"]
