class_name SketchVertical
extends RefCounted
## Vertical relation: lines, endpoint pairs, or two circle centres.
## sketch_mode.constrain calls apply; it does not branch on entity kind.


const CENTRE_KINDS := ["circle", "arc"]


static func apply(sketch, ids: Array, roles: Array) -> String:
	if sketch == null or ids.is_empty():
		return ""
	if _any_endpoint(roles):
		if ids.size() == 2 and roles.size() >= 2 \
				and str(roles[0]) != "self" and str(roles[1]) != "self":
			return PolygonPose.vertical_pair(sketch,
				{"entity": ids[0], "role": roles[0]},
				{"entity": ids[1], "role": roles[1]})
		return ""
	if ids.size() == 2 and _both(sketch, ids, CENTRE_KINDS):
		return str(sketch.add_constraint("vertical", [
			{"entity": ids[0], "role": "center"},
			{"entity": ids[1], "role": "center"}], 0.0))
	var cid := ""
	for id in ids:
		if str(sketch.entity_info(id).get("type", "")) == "line":
			cid = str(sketch.add_constraint("vertical", [{"entity": id, "role": "self"}], 0.0))
	return cid


static func _any_endpoint(roles: Array) -> bool:
	for role in roles:
		var r := str(role)
		if r == "start" or r == "end":
			return true
	return false


static func _both(sketch, ids: Array, kinds: Array) -> bool:
	for id in ids:
		if str(sketch.entity_info(id).get("type", "")) not in kinds:
			return false
	return true
