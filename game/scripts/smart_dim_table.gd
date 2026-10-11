class_name SmartDimTable
extends RefCounted
## Smart Dim intent: channel and entity class pick one constraint form.
## A line's external flag rides on the pick; it is not its own kind.


enum Kind { LINE, CIRCLE, ARC, CIRCLE_CENTER, ARC_CENTER }
enum Channel { SINGLE, BETWEEN, SELECTION }
enum Class { NONE, LINE_LIKE, ROUND, CENTRE }
## Which side of a pair must be an external line. NONE means the flag is ignored.
enum Side { NONE, A, B }


class End:
	var kind: Kind
	var external: bool

	static func make(k: Kind, ext: bool = false) -> End:
		var end := End.new()
		end.kind = k
		end.external = ext
		return end


## channel, class, class → form. `external_side` is set only when the line must be external.
const _RULES: Array[Dictionary] = [
	{
		"channel": Channel.SINGLE, "a": Class.LINE_LIKE, "b": Class.NONE,
		"form": "line_length", "label_anchor": "mid", "also": "angle_to_horizontal",
	},
	{
		"channel": Channel.SINGLE, "a": Class.ROUND, "b": Class.NONE,
		"form": "diameter", "label_anchor": "rim",
	},
	{
		"channel": Channel.BETWEEN, "a": Class.CENTRE, "b": Class.CENTRE,
		"form": "centres", "label_anchor": "mid",
	},
	{
		"channel": Channel.BETWEEN, "a": Class.CENTRE, "b": Class.LINE_LIKE,
		"form": "point_line", "point": "a", "label_anchor": "mid",
	},
	{
		"channel": Channel.BETWEEN, "a": Class.LINE_LIKE, "b": Class.CENTRE,
		"form": "point_line", "point": "b", "label_anchor": "mid",
	},
	{
		"channel": Channel.BETWEEN, "a": Class.LINE_LIKE, "b": Class.LINE_LIKE,
		"form": "angle", "label_anchor": "vertex",
	},
	{
		"channel": Channel.SELECTION, "a": Class.LINE_LIKE, "b": Class.LINE_LIKE,
		"form": "angle", "label_anchor": "vertex",
	},
	{
		"channel": Channel.SELECTION, "a": Class.ROUND, "b": Class.LINE_LIKE,
		"form": "point_line", "point": "a", "point_role": "center", "label_anchor": "mid",
		"external_side": Side.B,
	},
	{
		"channel": Channel.SELECTION, "a": Class.LINE_LIKE, "b": Class.ROUND,
		"form": "point_line", "point": "b", "point_role": "center", "label_anchor": "mid",
		"external_side": Side.A,
	},
]


static func end_for(type: String, role: String, external: bool) -> End:
	var kind := _kind_of(type, role)
	if kind < 0:
		return null
	return End.make(kind as Kind, external and type == "line")


static func resolve(channel: Channel, a: End, b: End = null) -> Dictionary:
	var ca := _class_of(a)
	var cb := _class_of(b)
	for rule in _RULES:
		if int(rule["channel"]) != channel:
			continue
		if int(rule["a"]) != ca or int(rule["b"]) != cb:
			continue
		if not _external_ok(rule, a, b):
			continue
		return _intent(rule)
	return {}


static func _kind_of(type: String, role: String) -> int:
	if role == "center":
		if type == "circle":
			return Kind.CIRCLE_CENTER
		if type == "arc":
			return Kind.ARC_CENTER
	match type:
		"line":
			return Kind.LINE
		"circle":
			return Kind.CIRCLE
		"arc":
			return Kind.ARC
		_:
			return -1


static func _class_of(end: End) -> Class:
	if end == null:
		return Class.NONE
	match end.kind:
		Kind.LINE:
			return Class.LINE_LIKE
		Kind.CIRCLE, Kind.ARC:
			return Class.ROUND
		Kind.CIRCLE_CENTER, Kind.ARC_CENTER:
			return Class.CENTRE
	return Class.NONE


static func _external_ok(rule: Dictionary, a: End, b: End) -> bool:
	var side := int(rule.get("external_side", Side.NONE))
	if side == Side.NONE:
		return true
	var line := a if side == Side.A else b
	return line != null and line.kind == Kind.LINE and line.external


static func _intent(rule: Dictionary) -> Dictionary:
	var out := {"form": str(rule["form"]), "label_anchor": str(rule["label_anchor"])}
	if rule.has("point"):
		out["point"] = str(rule["point"])
	if rule.has("point_role"):
		out["point_role"] = str(rule["point_role"])
	if rule.has("also"):
		out["also"] = str(rule["also"])
	return out
