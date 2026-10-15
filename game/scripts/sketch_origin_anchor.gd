class_name SketchOriginAnchor
extends RefCounted
## Pins a centre-drawn shape that already sits on the sketch origin.
## One RULES row per tool. Callers pass the tool key; they do not branch.


const ORIGIN_PIN_TOL := 0.5

## tool → lock. `enabled` is the opt-in column: a suite whose DOF must stay
## free turns that row off instead of growing a special case in sketch_mode.
const RULES: Array[Dictionary] = [
	{"tool": "rect.center", "lock": "diagonal", "enabled": true},
	{"tool": "circle.center", "lock": "centre", "enabled": true},
	{"tool": "polygon.af", "lock": "centre", "enabled": true},
]


static func apply(sketch, entity_ids: Array, tool_key: String, centre: Vector2) -> void:
	if sketch == null or centre.length() > ORIGIN_PIN_TOL:
		return
	for row in RULES:
		if str(row.get("tool", "")) != tool_key:
			continue
		if not bool(row.get("enabled", true)):
			return
		match str(row.get("lock", "")):
			"diagonal":
				_lock_rect(sketch, entity_ids)
			"centre":
				if _first_is_line(sketch, entity_ids):
					_lock_rect(sketch, entity_ids)
				else:
					_lock_circle(sketch, entity_ids)
		return


## Construction diagonal through opposite corners. Its midpoint is the
## origin anchor, same idea as the jaw's centre pin, so the profile stays
## one loop.
static func _lock_rect(sketch, entity_ids: Array) -> void:
	var ends: Array = []
	for raw in entity_ids:
		var id := str(raw)
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		ends.append({"id": id, "role": "start", "p": info["start"]})
		ends.append({"id": id, "role": "end", "p": info["end"]})
	var best := -1.0
	var ia := -1
	var ib := -1
	for i in ends.size():
		for j in range(i + 1, ends.size()):
			var d: float = (ends[i]["p"] as Vector2).distance_to(ends[j]["p"])
			if d > best:
				best = d
				ia = i
				ib = j
	if ia < 0 or best < 1e-6:
		return
	var a: Dictionary = ends[ia]
	var b: Dictionary = ends[ib]
	var pa: Vector2 = a["p"]
	var pb: Vector2 = b["p"]
	var diag: String = sketch.add_line(pa.x, pa.y, pb.x, pb.y)
	if diag == "":
		return
	sketch.set_construction(diag, true)
	sketch.add_constraint("coincident", [
		{"entity": str(a["id"]), "role": str(a["role"])},
		{"entity": diag, "role": "start"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": str(b["id"]), "role": str(b["role"])},
		{"entity": diag, "role": "end"}], 0.0)
	var anchor := _ensure_origin_point(sketch)
	if anchor == "":
		return
	sketch.add_constraint("midpoint", [
		{"entity": anchor, "role": "self"},
		{"entity": diag, "role": "self"}], 0.0)


static func _first_is_line(sketch, entity_ids: Array) -> bool:
	if entity_ids.is_empty():
		return false
	var info: Dictionary = sketch.entity_info(str(entity_ids[0]))
	return str(info.get("type", "")) == "line"


## Centre-only fix, or coincident to an origin anchor that already exists.
## A centre-distance dimension must not invent that point (T14).
static func _lock_circle(sketch, entity_ids: Array) -> void:
	if entity_ids.is_empty():
		return
	var id := str(entity_ids[0])
	var anchor := _find_origin_point(sketch)
	if anchor == "":
		if not _has_constraint(sketch, id, "fix"):
			sketch.add_constraint("fix", [{"entity": id, "role": "center"}], 0.0)
		return
	if _already_coincident(sketch, id, anchor):
		return
	sketch.add_constraint("coincident", [
		{"entity": id, "role": "center"},
		{"entity": anchor, "role": "self"}], 0.0)


static func _ensure_origin_point(sketch) -> String:
	var found := _find_origin_point(sketch)
	if found != "":
		return found
	var origin: String = sketch.add_point(0.0, 0.0)
	if origin == "":
		return ""
	sketch.set_construction(origin, true)
	sketch.add_constraint("fix", [{"entity": origin, "role": "self"}], 0.0)
	return origin


static func _find_origin_point(sketch) -> String:
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "point" or not sketch.is_construction(id):
			continue
		if not _has_constraint(sketch, str(id), "fix"):
			continue
		var pos: Vector2 = info.get("position", Vector2.INF)
		if pos.length() <= ORIGIN_PIN_TOL:
			return str(id)
	return ""


static func _has_constraint(sketch, entity_id: String, type_name: String) -> bool:
	if entity_id == "":
		return false
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != type_name:
			continue
		for ref in info.get("refs", []):
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			if str(ref.get("entity", "")) == entity_id:
				return true
	return false


static func _already_coincident(sketch, id: String, anchor: String) -> bool:
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "coincident":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() == 2 and str(refs[0].get("entity", "")) == id \
				and str(refs[1].get("entity", "")) == anchor:
			return true
	return false
