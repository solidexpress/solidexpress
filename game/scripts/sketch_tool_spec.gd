class_name SketchToolSpec
extends RefCounted
## One row per SketchMode.Tool. Text and flags live here; click and preview stay
## on SketchMode.

var id: int
var key: String
var label: String
var rail_hint: String
var icon: String
var shortcut: String
var default_variant: String
var variants: Array = []
var numeric_key: Callable = Callable()
var undo_label: String
var arm_hint: String
var family: String
var sets_default_variant := false
var default_variant_fn: Callable = Callable()
var variants_fn: Callable = Callable()

static var TABLE: Dictionary = {}
static var _rail: Array = []


static func of(tool: int) -> SketchToolSpec:
	_ensure()
	return TABLE[tool]


static func tool_names() -> PackedStringArray:
	_ensure()
	var out := PackedStringArray()
	for i in SketchMode.Tool.size():
		out.append(of(i).label)
	return out


static func rail_specs() -> Array:
	_ensure()
	return _rail


static func undo_label_for(mode) -> String:
	if mode.is_jaw_armed():
		return "Jaw"
	return of(int(mode.tool)).undo_label


func default_variant_of(mode) -> String:
	if default_variant_fn.is_valid():
		return str(default_variant_fn.call(mode))
	return default_variant


func variants_of(mode) -> Array:
	if variants_fn.is_valid():
		return variants_fn.call(mode)
	return variants


func numeric_for(mode) -> String:
	if numeric_key.is_valid():
		return str(numeric_key.call(mode))
	return "tool:%d" % int(mode.tool)


static func _ensure() -> void:
	if not TABLE.is_empty():
		return
	var T := SketchMode.Tool
	_add(T.NONE, "none", "None", "Edit")
	_add(T.LINE, "line", "Line", "Line")
	_add(T.RECT, "rect", "Rect", "Rect")
	_add(T.CIRCLE, "circle", "Circle", "Circle")
	_add(T.ARC, "arc", "Arc", "Arc")
	_add(T.POLYGON, "polygon", "Polygon", "Polygon")
	_add(T.SELECT, "select", "Select", "Edit")
	_add(T.TRIM, "trim", "Trim", "Trim")
	_add(T.EXTEND, "extend", "Extend", "Extend")
	_add(T.SMART_DIM, "smart_dim", "Smart Dim", "Dimension")
	_add(T.CONVERT, "convert", "Convert", "Convert")
	_add(T.MIRROR, "mirror", "Mirror", "Mirror")
	_add(T.PATTERN, "pattern", "Pattern", "Pattern")
	_add(T.SPLINE, "spline", "Spline", "Spline")
	_add(T.POINT, "point", "Point", "Point")
	_add(T.CENTERLINE, "centerline", "Centerline", "Line")
	_add(T.ELLIPSE, "ellipse", "Ellipse", "Ellipse")
	_add(T.SLOT, "slot", "Slot", "Slot")
	_add(T.CHAMFER, "chamfer", "Chamfer", "Chamfer")

	_rail_row(T.SELECT, "select", "Select (S)", "S")
	_rail_row(T.LINE, "line", "Line / centerline (L)", "L")
	_rail_row(T.ARC, "arc", "Arc tool (A)", "A")
	_rail_row(T.CIRCLE, "circle", "Circle (C)", "C")
	_rail_row(T.RECT, "rect", "Rectangle (R)", "R")
	_rail_row(T.POLYGON, "polygon", "Polygon", "")
	_rail_row(T.ELLIPSE, "circle", "Ellipse (approx)", "")
	_rail_row(T.SLOT, "rect", "Straight slot", "")
	_rail_row(T.SPLINE, "spline", "Fit spline", "")
	_rail_row(T.POINT, "point", "Sketch point", "")
	_rail_row(T.TRIM, "trim", "Power Trim (T)", "T")
	_rail_row(T.EXTEND, "extend", "Extend to next", "")
	_rail_row(T.SMART_DIM, "dimension", "Smart Dimension (D)", "D")
	_rail_row(T.CONVERT, "convert", "Convert entities", "")
	_rail_row(T.MIRROR, "mirror", "Mirror selection", "")
	_rail_row(T.PATTERN, "pattern", "Linear / circular pattern", "")

	_hint(T.SELECT, "Select — click geometry, or a dimension label to edit it")
	_hint(T.LINE, "Line — click 2 points (or type a length)")
	_hint(T.ARC, "Arc — click the centre, then the start, then the end")
	_hint(T.CIRCLE, "Circle — click the centre, then the rim (or type a radius)")
	_hint(T.RECT, "Rect — click 1 first corner, click 2 the opposite corner")
	_hint(T.POLYGON, "Polygon — click the centre, then a vertex (or type the size)")
	_hint(T.ELLIPSE, "Ellipse — click the centre, then a corner of the box")
	_hint(T.SLOT, "Slot — type the radius, click the first centre, then the second (or type the length)")
	_hint(T.SPLINE, "Spline — click fit points; Done / Esc / right-click to finish")
	_hint(T.POINT, "Point — click to place a sketch point")
	_hint(T.TRIM, "Trim — drag across entities to trim them")
	_hint(T.EXTEND, "Extend — click a segment to extend it to the next")
	_hint(T.SMART_DIM, "Smart Dim — click geometry to dimension it")
	_hint(T.CONVERT, "Convert — click to convert pierce points")
	_hint(T.MIRROR, "Mirror — select geometry and a mirror axis, then click")
	_hint(T.PATTERN, "Pattern — select geometry, then a linear or circular variant")
	_hint(T.CENTERLINE, "Centerline — click 2 points (construction, never part of the profile)")

	_const_key(T.LINE, "line")
	_const_key(T.CENTERLINE, "centerline")
	_const_key(T.CIRCLE, "circle")
	_const_key(T.ARC, "arc")
	_const_key(T.ELLIPSE, "ellipse")
	of(T.SLOT).numeric_key = func(mode):
		return "slot_cc" if mode.has_single_dof_preview() else "slot_radius"
	of(T.POLYGON).numeric_key = func(mode):
		return "polygon:" + str(mode.tool_variant)

	_variants(T.CIRCLE, ["center", "perimeter", "three_point"])
	_variants(T.ARC, ["center", "tangent", "three_point"])
	_variants(T.PATTERN, ["linear", "circular"])
	_variants(T.LINE, ["line", "centerline"])
	_variants(T.CENTERLINE, ["line", "centerline"])
	_variants(T.POLYGON, ["vertex", "across_flats"])
	of(T.RECT).variants_fn = func(mode) -> Array:
		if mode.is_jaw_armed():
			return []
		return ["corner", "center", "three_point", "center_three_point", "parallelogram"]

	_default_variant(T.RECT, "corner")
	_default_variant(T.CIRCLE, "center")
	_default_variant(T.ARC, "center")
	_default_variant(T.PATTERN, "linear")
	var poly := of(T.POLYGON)
	poly.sets_default_variant = true
	poly.default_variant_fn = func(mode) -> String:
		return str(mode.get("_polygon_variant"))

	of(T.RECT).family = "rect"
	of(T.CIRCLE).family = "circle"
	of(T.ARC).family = "arc"
	of(T.PATTERN).family = "pattern"
	of(T.LINE).family = "line"
	of(T.CENTERLINE).family = "line"


static func _add(id: int, key: String, label: String, undo: String) -> void:
	var s := SketchToolSpec.new()
	s.id = id
	s.key = key
	s.label = label
	s.undo_label = undo
	s.numeric_key = func(mode): return "tool:%d" % int(mode.tool)
	TABLE[id] = s


static func _rail_row(id: int, icon: String, hint: String, shortcut: String) -> void:
	var s: SketchToolSpec = TABLE[id]
	s.icon = icon
	s.rail_hint = hint
	s.shortcut = shortcut
	_rail.append(s)


static func _hint(id: int, text: String) -> void:
	(TABLE[id] as SketchToolSpec).arm_hint = text


static func _const_key(id: int, key: String) -> void:
	(TABLE[id] as SketchToolSpec).numeric_key = func(_mode): return key


static func _variants(id: int, items: Array) -> void:
	(TABLE[id] as SketchToolSpec).variants = items


static func _default_variant(id: int, variant: String) -> void:
	var s: SketchToolSpec = TABLE[id]
	s.sets_default_variant = true
	s.default_variant = variant
