class_name PolygonPose
extends RefCounted
## Vertical pair on a closed loop: two endpoints share X, and that loop's
## horizontals drop. Other lines keep theirs. sketch_mode only calls this.


const _WELD := 0.001
const _ORIGIN_TOL := 0.5


static func vertical_pair(sketch, endpoint_a: Dictionary, endpoint_b: Dictionary) -> String:
	if sketch == null:
		return ""
	var lines := _loop_lines(sketch, endpoint_a, endpoint_b)
	if lines.is_empty():
		return ""
	var verts := _ordered_vertices(sketch, lines)
	var locks := _lock_regular(sketch, lines, verts)
	_pin_centre(sketch, endpoint_a, endpoint_b)
	var flats := _drop_loop_horizontals(sketch, lines)
	var cid := str(sketch.add_constraint("vertical", [endpoint_a, endpoint_b], 0.0))
	if cid == "":
		_restore_horizontals(sketch, flats)
		return ""
	var res: Dictionary = sketch.solve()
	if str(res.get("status", "")) == "failed":
		sketch.remove_constraint(cid)
		for lock in locks:
			if lock != "":
				sketch.remove_constraint(lock)
		_restore_horizontals(sketch, flats)
		return ""
	return cid


static func _lock_regular(sketch, lines: Array[String], verts: Array) -> Array[String]:
	var locks: Array[String] = []
	if lines.is_empty():
		return locks
	var first := lines[0]
	var info: Dictionary = sketch.entity_info(first)
	var length: float = (info["end"] as Vector2).distance_to(info["start"])
	locks.append(_distance(sketch, {"entity": first, "role": "start"},
			{"entity": first, "role": "end"}, length))
	for i in range(1, lines.size()):
		var cid := str(sketch.add_constraint("equal", [
			{"entity": first, "role": "self"},
			{"entity": lines[i], "role": "self"}], 0.0))
		_tag(sketch, cid)
		locks.append(cid)
	var n := verts.size()
	if n < 4 or n % 2 != 0:
		return locks
	var half := n / 2
	for i in half:
		var pa: Dictionary = verts[i]
		var pb: Dictionary = verts[i + half]
		var dist: float = (pa["p"] as Vector2).distance_to(pb["p"])
		locks.append(_distance(sketch, {"entity": pa["entity"], "role": pa["role"]},
				{"entity": pb["entity"], "role": pb["role"]}, dist))
	return locks


static func _distance(sketch, a: Dictionary, b: Dictionary, value: float) -> String:
	var cid := str(sketch.add_constraint("distance", [a, b], value))
	_tag(sketch, cid)
	return cid


static func _tag(sketch, cid: String) -> void:
	if cid != "" and sketch.has_method("set_constraint_expr"):
		sketch.set_constraint_expr(cid, "pose-lock")


static func _pin_centre(sketch, endpoint_a: Dictionary, endpoint_b: Dictionary) -> void:
	var pa := _pos(sketch, endpoint_a)
	var pb := _pos(sketch, endpoint_b)
	if ((pa + pb) * 0.5).length() > _ORIGIN_TOL:
		return
	var diag := str(sketch.add_line(pa.x, pa.y, pb.x, pb.y))
	if diag == "":
		return
	sketch.set_construction(diag, true)
	sketch.add_constraint("coincident", [
		endpoint_a, {"entity": diag, "role": "start"}], 0.0)
	sketch.add_constraint("coincident", [
		endpoint_b, {"entity": diag, "role": "end"}], 0.0)
	var anchor := _origin_point(sketch)
	if anchor == "":
		return
	sketch.add_constraint("midpoint", [
		{"entity": anchor, "role": "self"},
		{"entity": diag, "role": "self"}], 0.0)


static func _origin_point(sketch) -> String:
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "point":
			continue
		if not bool(info.get("construction", false)):
			continue
		if not _has_fix(sketch, str(id)):
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


static func _ordered_vertices(sketch, lines: Array[String]) -> Array:
	if lines.is_empty():
		return []
	var unused := {}
	for id in lines:
		unused[id] = true
	var cur := lines[0]
	var info: Dictionary = sketch.entity_info(cur)
	var origin: Vector2 = info["start"]
	var verts: Array = [{"entity": cur, "role": "start", "p": origin}]
	var depart := "end"
	var guard := 0
	while guard < lines.size():
		guard += 1
		var at: Dictionary = sketch.entity_info(cur)
		var next: Vector2 = at["end"] if depart == "end" else at["start"]
		unused.erase(cur)
		if unused.is_empty():
			break
		if next.distance_to(origin) <= _WELD:
			break
		var found := ""
		var next_depart := ""
		for id in lines:
			if not unused.has(id):
				continue
			var other: Dictionary = sketch.entity_info(id)
			if (other["start"] as Vector2).distance_to(next) <= _WELD:
				found = id
				next_depart = "end"
				break
			if (other["end"] as Vector2).distance_to(next) <= _WELD:
				found = id
				next_depart = "start"
				break
		if found == "":
			break
		var role := "start" if next_depart == "end" else "end"
		verts.append({"entity": found, "role": role, "p": next})
		cur = found
		depart = next_depart
	return verts


static func _pos(sketch, ref: Dictionary) -> Vector2:
	var info: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
	if str(ref.get("role", "start")) == "end":
		return info["end"]
	return info["start"]
