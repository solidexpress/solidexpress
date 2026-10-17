class_name SketchHorizontal
extends RefCounted
## Horizontal relation: lines, or two endpoints (the R20 hook).
## sketch_mode.constrain calls apply; it does not branch on entity kind.


## True when the current selection can take a Horizontal constraint.
static func offers(sketch, ids: Array, roles: Array) -> bool:
	if sketch == null or ids.is_empty():
		return false
	if ids.size() == 1:
		return str(sketch.entity_info(ids[0]).get("type", "")) == "line"
	if ids.size() != 2:
		return false
	return _any_endpoint(roles) and roles.size() >= 2 \
			and str(roles[0]) != "self" and str(roles[1]) != "self"


static func apply(sketch, ids: Array, roles: Array) -> String:
	if sketch == null or ids.is_empty():
		return ""
	if _any_endpoint(roles):
		if ids.size() == 2 and roles.size() >= 2 \
				and str(roles[0]) != "self" and str(roles[1]) != "self":
			return str(sketch.add_constraint("horizontal", [
				{"entity": ids[0], "role": roles[0]},
				{"entity": ids[1], "role": roles[1]}], 0.0))
		return ""
	var cid := ""
	for id in ids:
		if str(sketch.entity_info(id).get("type", "")) == "line":
			cid = str(sketch.add_constraint("horizontal", [{"entity": id, "role": "self"}], 0.0))
	return cid


static func _any_endpoint(roles: Array) -> bool:
	for role in roles:
		var r := str(role)
		if r == "start" or r == "end":
			return true
	return false
