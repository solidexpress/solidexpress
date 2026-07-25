class_name OpsPanel
extends PanelContainer
## Context operations for the current selection. Body selected: fillet/chamfer
## (all edges), mirror, linear/circular pattern, offset, boolean (arm, then
## click the tool body), measure (arm, then click the other entity). Face
## selected: shell (removes that face) plus face measurements.

signal status(text: String)

enum Pending { NONE, BOOLEAN, MEASURE }

var view: DocumentView

var _body_ops: VBoxContainer
var _face_ops: VBoxContainer
var _name_edit: LineEdit
var _color_picker: ColorPickerButton
var _radius_spin: SpinBox
var _pattern_count: SpinBox
var _pattern_spacing: SpinBox
var _inst_ox: SpinBox
var _inst_oy: SpinBox
var _inst_oz: SpinBox
var _offset_spin: SpinBox
var _thickness_spin: SpinBox
var _draft_angle_spin: SpinBox
var _hole_type: OptionButton
var _material_option: OptionButton
var _hole_diameter: SpinBox
var _hole_depth: SpinBox
var _boolean_op := "fuse"
var _pending: Pending = Pending.NONE
var _pending_first := ""  # armed source entity (body for boolean, any for measure)


var _scroll: ScrollContainer
var _content: VBoxContainer
## Cap so left-docked Modify + selection card stay above the timeline.
const MAX_HEIGHT := 240.0


func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(vbox)
	_content = vbox
	var title := Label.new()
	title.text = "Modify"
	title.visible = false
	vbox.add_child(title)

	_body_ops = VBoxContainer.new()
	vbox.add_child(_body_ops)
	_build_body_ops()

	_face_ops = VBoxContainer.new()
	vbox.add_child(_face_ops)
	_build_face_ops()

	view.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(view.selected_body, view.selected_face)


func _labeled_spin(parent: Container, text: String, min_v: float, max_v: float,
		step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _op_button(parent: Container, text: String, handler: Callable,
		icon_name := "", tooltip := "") -> Button:
	var tip := tooltip if tooltip != "" else text
	var b: Button
	if icon_name != "":
		b = UIIcons.button(icon_name, "", tip)
	else:
		b = Button.new()
		b.text = text
		b.tooltip_text = tip
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _build_body_ops() -> void:
	var name_row := HBoxContainer.new()
	_body_ops.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_row.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(_on_name_submitted)
	name_row.add_child(_name_edit)

	var color_row := HBoxContainer.new()
	_body_ops.add_child(color_row)
	var color_lbl := Label.new()
	color_lbl.text = "Color"
	color_lbl.custom_minimum_size = Vector2(80, 0)
	color_lbl.add_theme_font_size_override("font_size", 11)
	color_row.add_child(color_lbl)
	_color_picker = ColorPickerButton.new()
	_color_picker.tooltip_text = "Change this body's display color"
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.edit_alpha = false
	_color_picker.color_changed.connect(_on_color_changed)
	color_row.add_child(_color_picker)

	var mat_row := HBoxContainer.new()
	_body_ops.add_child(mat_row)
	var mat_lbl := Label.new()
	mat_lbl.text = "Material"
	mat_lbl.custom_minimum_size = Vector2(80, 0)
	mat_lbl.add_theme_font_size_override("font_size", 11)
	mat_row.add_child(mat_lbl)
	_material_option = OptionButton.new()
	_material_option.tooltip_text = "Material (density in g/cm³) — drives mass"
	_material_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material_option.fit_to_longest_item = false
	for m in view.doc.material_list():
		_material_option.add_item("%s (%.2f)" % [m["name"], m["density_g_cm3"]])
		_material_option.set_item_metadata(_material_option.item_count - 1, m["name"])
	_material_option.item_selected.connect(_on_material_selected)
	mat_row.add_child(_material_option)

	_body_ops.add_child(HSeparator.new())
	_radius_spin = _labeled_spin(_body_ops, "Radius", 0.1, 100.0, 0.5, 2.0)
	var round_row := HBoxContainer.new()
	_body_ops.add_child(round_row)
	_op_button(round_row, "Fillet", _fillet_all, "fillet",
		"Round the selected edges (or all edges) with the radius above")
	_op_button(round_row, "Chamfer", _chamfer_all, "chamfer",
		"Bevel the selected edges (or all edges) by the distance above")

	_body_ops.add_child(HSeparator.new())
	# Default ~body width of the 10 mm palette primitives (was 60 — flung copies away).
	_pattern_spacing = _labeled_spin(_body_ops, "Spacing", 0.1, 1000.0, 0.5, 12.0)
	_pattern_count = _labeled_spin(_body_ops, "Count", 2, 36, 1, 3)
	var pat_row := HBoxContainer.new()
	_body_ops.add_child(pat_row)
	_op_button(pat_row, "Linear", _linear_pattern, "linear_pattern",
		"Repeat the body along X with the spacing and count above")
	_op_button(pat_row, "Circular", _circular_pattern, "circular_pattern",
		"Repeat the body around the Z axis with the count above")
	_op_button(pat_row, "Mirror", _mirror, "mirror",
		"Mirror the body across the YZ plane")

	# Instance placement (direct doc mutation — not undoable in v1).
	_body_ops.add_child(HSeparator.new())
	var inst_lbl := Label.new()
	inst_lbl.text = "Instance"
	inst_lbl.add_theme_font_size_override("font_size", 11)
	_body_ops.add_child(inst_lbl)
	_inst_ox = _labeled_spin(_body_ops, "Offset X", -10000.0, 10000.0, 1.0, 30.0)
	_inst_oy = _labeled_spin(_body_ops, "Offset Y", -10000.0, 10000.0, 1.0, 0.0)
	_inst_oz = _labeled_spin(_body_ops, "Offset Z", -10000.0, 10000.0, 1.0, 0.0)
	_op_button(_body_ops, "Place", _place_instance, "instance",
		"Place a linked instance of this body at the offset above")

	_body_ops.add_child(HSeparator.new())
	_offset_spin = _labeled_spin(_body_ops, "Offset", -50.0, 50.0, 0.5, 2.0)
	_op_button(_body_ops, "Offset body", _offset, "offset",
		"Grow or shrink the body by the offset above")

	_body_ops.add_child(HSeparator.new())
	var bool_row := HBoxContainer.new()
	_body_ops.add_child(bool_row)
	for entry in [["fuse", "Fuse: combine this body with the next one clicked"],
			["cut", "Cut: subtract the next body clicked from this one"],
			["common", "Common: keep only the overlap with the next body clicked"]]:
		var op: String = entry[0]
		var b := UIIcons.button(op, "", entry[1])
		b.pressed.connect(_arm_boolean.bind(op))
		bool_row.add_child(b)
	_op_button(_body_ops, "Measure to...", _arm_measure, "measure",
		"Measure distance: click the other body or face")
	_op_button(_body_ops, "Mass properties", func() -> void:
		var mp: Dictionary = view.doc.measure_mass(view.selected_body)
		if mp.is_empty():
			status.emit("No body selected")
		else:
			status.emit("%s: %.1f g · %.0f mm^3 · CoM %s" % [mp.get("material", "?"),
				mp.get("mass_g", 0.0), mp.get("volume", 0.0), str(mp.get("center_of_mass"))]),
		"mass", "Show mass, volume, and center of mass for this body")


func _build_face_ops() -> void:
	_thickness_spin = _labeled_spin(_face_ops, "Thickness", 0.1, 50.0, 0.5, 2.0)
	_op_button(_face_ops, "Shell (open here)", _shell, "shell",
		"Hollow the body, removing the selected face(s) as the opening")
	_face_ops.add_child(HSeparator.new())
	_draft_angle_spin = _labeled_spin(_face_ops, "Draft °", 0.1, 45.0, 0.5, 3.0)
	_op_button(_face_ops, "Apply draft", _draft, "draft",
		"Taper this face by the angle above (pull direction +Z)")
	_face_ops.add_child(HSeparator.new())
	var hole_type_row := HBoxContainer.new()
	_face_ops.add_child(hole_type_row)
	var hole_type_lbl := Label.new()
	hole_type_lbl.text = "Hole type"
	hole_type_lbl.custom_minimum_size = Vector2(80, 0)
	hole_type_lbl.add_theme_font_size_override("font_size", 11)
	hole_type_row.add_child(hole_type_lbl)
	_hole_type = OptionButton.new()
	_hole_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hole_type.add_item("Simple", 0)
	_hole_type.add_item("Counterbore", 1)
	_hole_type.add_item("Countersink", 2)
	hole_type_row.add_child(_hole_type)
	_hole_diameter = _labeled_spin(_face_ops, "Hole Ø", 0.1, 200.0, 0.5, 6.0)
	_hole_depth = _labeled_spin(_face_ops, "Depth", 0.0, 1000.0, 1.0, 0.0)
	_op_button(_face_ops, "Apply hole", _apply_hole, "hole",
		"Drill the hole at the center of this face")
	_op_button(_face_ops, "Face area", func() -> void:
		status.emit("Area: %.2f mm^2" % view.doc.measure_face_area(view.selected_face)),
		"area", "Show the area of this face")


func _on_selection_changed(body: String, face: String) -> void:
	if _pending != Pending.NONE:
		_resolve_pending(body, face)
		return
	visible = body != ""
	_body_ops.visible = body != "" and face == ""
	_face_ops.visible = face != ""
	if body != "" and face == "":
		_name_edit.text = view.doc.body_name(body)
		_color_picker.color = view.doc.get_body_color(body)
		_sync_material_option(body)
	_clamp_height()


func _sync_material_option(body: String) -> void:
	var current: String = view.doc.body_material(body)
	for i in range(_material_option.item_count):
		if str(_material_option.get_item_metadata(i)) == current:
			_material_option.select(i)
			return
	_material_option.select(0)


func _on_material_selected(index: int) -> void:
	if view.selected_body == "":
		return
	var mat := str(_material_option.get_item_metadata(index))
	if view.doc.set_body_material(view.selected_body, mat):
		var mp: Dictionary = view.doc.measure_mass(view.selected_body)
		status.emit("%s: %.1f g" % [mat, mp.get("mass_g", 0.0)])


func _clamp_height() -> void:
	# Shrink-to-fit up to MAX_HEIGHT, then scroll.
	await get_tree().process_frame
	if _scroll == null or _content == null:
		return
	var want := _content.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(240, minf(want, MAX_HEIGHT))
	reset_size()


func _on_name_submitted(text: String) -> void:
	if view.selected_body == "":
		return
	if view.doc.rename_body(view.selected_body, text):
		view.refresh()
		status.emit("Renamed to %s" % text)


func _on_color_changed(color: Color) -> void:
	if view.selected_body == "":
		return
	if view.doc.set_body_color(view.selected_body, color):
		view.refresh()
		view._apply_selection_materials()


# --- body ops ---

# Fillet/chamfer target: all multi-selected edges when present, else the
# single selected edge, else all edges of the body.
func _round_targets() -> PackedStringArray:
	if not view.selected_edges.is_empty():
		return PackedStringArray(view.selected_edges)
	if view.selected_edge != "":
		return PackedStringArray([view.selected_edge])
	return view.doc.get_edge_ids(view.selected_body)


func _fillet_all() -> void:
	_apply_dressup(true)


func _chamfer_all() -> void:
	_apply_dressup(false)


func _apply_dressup(fillet: bool) -> void:
	if view.selected_body == "":
		return
	var name := "Fillet" if fillet else "Chamfer"
	var targets := _round_targets()
	var scope := "all edges"
	if view.selected_edges.size() > 1:
		scope = "%d edges" % view.selected_edges.size()
	elif view.selected_edge != "":
		scope = "edge"
	var value: float = _radius_spin.value
	# Timeline bodies get a parametric feature; free bodies use the direct command.
	var fid := view.feature_of_body(view.selected_body)
	var ok: bool
	if fid != "":
		if fillet:
			ok = view.doc.graph_add_fillet(fid, targets, value) != ""
		else:
			ok = view.doc.graph_add_chamfer(fid, targets, value) != ""
	elif fillet:
		ok = view.doc.fillet_edges(targets, value)
	else:
		ok = view.doc.chamfer_edges(targets, value)
	if ok:
		view.graph_changed()
		status.emit("%s %s %.1f applied" % [name, scope, value])
	else:
		status.emit("%s failed (value too large?)" % name)


func _mirror() -> void:
	var body := view.selected_body
	if body == "":
		return
	# Mirror across the YZ plane through the body's +X extent.
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return
	var fid := view.feature_of_body(body)
	var created := ""
	if fid != "":
		created = view.doc.graph_add_mirror(fid, Vector3(bb["max"].x, 0, 0), Vector3(1, 0, 0))
	else:
		created = view.doc.mirror_body(body, Vector3(bb["max"].x, 0, 0), Vector3(1, 0, 0), true)
	view.graph_changed()
	status.emit("Mirrored body" if created != "" else "Mirror failed")


func _linear_pattern() -> void:
	var body := view.selected_body
	if body == "":
		return
	var fid := view.feature_of_body(body)
	var made: PackedStringArray = PackedStringArray()
	if fid != "":
		var pfid: String = view.doc.graph_add_linear_pattern(
			fid, Vector3(1, 0, 0), _pattern_spacing.value, int(_pattern_count.value))
		if pfid != "":
			made = PackedStringArray([pfid])
	else:
		made = view.doc.linear_pattern(
			body, Vector3(1, 0, 0), _pattern_spacing.value, int(_pattern_count.value))
	view.graph_changed()
	status.emit("%d copies created" % made.size() if made.size() > 0 else "Pattern failed")


func _circular_pattern() -> void:
	var body := view.selected_body
	if body == "":
		return
	var fid := view.feature_of_body(body)
	var made: PackedStringArray = PackedStringArray()
	if fid != "":
		var pfid: String = view.doc.graph_add_circular_pattern(
			fid, Vector3.ZERO, Vector3(0, 0, 1), int(_pattern_count.value), TAU)
		if pfid != "":
			made = PackedStringArray([pfid])
	else:
		made = view.doc.circular_pattern(
			body, Vector3.ZERO, Vector3(0, 0, 1), int(_pattern_count.value), TAU)
	view.graph_changed()
	status.emit("%d copies created" % made.size() if made.size() > 0 else "Pattern failed")


# Direct document mutation — not undoable in v1.
func _place_instance() -> void:
	var body := view.selected_body
	if body == "":
		return
	var offset := Vector3(_inst_ox.value, _inst_oy.value, _inst_oz.value)
	var iname: String = view.doc.body_name(body) + " (inst)"
	var iid: String = view.doc.add_instance(body, offset, Vector3(0, 0, 1), 0.0, iname)
	if iid != "":
		view.refresh()
		view._apply_selection_materials()
		status.emit("Placed instance at (%.0f, %.0f, %.0f)" % [offset.x, offset.y, offset.z])
	else:
		status.emit("Instance failed")


func _offset() -> void:
	var body := view.selected_body
	if body == "":
		return
	var fid := view.feature_of_body(body)
	var ok: bool
	if fid != "":
		ok = view.doc.graph_add_offset(fid, _offset_spin.value) != ""
	else:
		ok = view.doc.offset_body(body, _offset_spin.value)
	if ok:
		view.graph_changed()
		status.emit("Offset %.1f mm applied" % _offset_spin.value)
	else:
		status.emit("Offset failed")


func _shell() -> void:
	# Multi-selected faces all open; else the single selected face.
	var faces := PackedStringArray(view.selected_faces)
	if faces.is_empty() and view.selected_face != "":
		faces = PackedStringArray([view.selected_face])
	if faces.is_empty():
		return
	var fid := view.feature_of_body(view.selected_body)
	var ok: bool
	if fid != "":
		ok = view.doc.graph_add_shell(fid, faces, _thickness_spin.value) != ""
	else:
		ok = view.doc.shell_body(faces, _thickness_spin.value)
	if ok:
		view.graph_changed()
		status.emit("Shelled %d face(s), wall %.1f mm" % [faces.size(), _thickness_spin.value])
	else:
		status.emit("Shell failed (thickness too large?)")


func _draft() -> bool:
	var face := view.selected_face
	var body := view.selected_body
	if face == "" or body == "":
		return false
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		status.emit("Draft failed (no bbox)")
		return false
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	# Neutral plane at the body's bounding-box bottom; pull along +Z.
	var neutral_point := Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z)
	var angle: float = _draft_angle_spin.value
	var fid := view.feature_of_body(body)
	var ok: bool
	if fid != "":
		ok = view.doc.graph_add_draft(fid, PackedStringArray([face]), angle, Vector3(0, 0, 1),
				neutral_point, Vector3(0, 0, 1)) != ""
	else:
		ok = view.doc.draft_faces(PackedStringArray([face]), angle, Vector3(0, 0, 1),
				neutral_point, Vector3(0, 0, 1))
	if ok:
		view.graph_changed()
		status.emit("Draft %.1f° applied" % angle)
		return true
	status.emit("Draft failed")
	return false


func _apply_hole() -> bool:
	var face := view.selected_face
	var body := view.selected_body
	if face == "" or body == "":
		return false
	var target_fid := view.feature_of_body(body)
	if target_fid == "":
		status.emit("Hole needs a timeline body")
		return false
	var face_bb: Dictionary = view.doc.measure_bbox(face)
	if face_bb.is_empty():
		status.emit("Hole failed (no face bbox)")
		return false
	var fmn: Vector3 = face_bb["min"]
	var fmx: Vector3 = face_bb["max"]
	var position := (fmn + fmx) * 0.5
	# Outward face normal → reverse so direction points into the material.
	var outward: Vector3 = view.selected_face_normal()
	var direction: Vector3
	if outward.length_squared() > 1e-12:
		direction = -outward.normalized()
	else:
		var body_bb: Dictionary = view.doc.measure_bbox(body)
		if body_bb.is_empty():
			status.emit("Hole failed (no body bbox)")
			return false
		var bmn: Vector3 = body_bb["min"]
		var bmx: Vector3 = body_bb["max"]
		var body_center := (bmn + bmx) * 0.5
		direction = (body_center - position).normalized()
	var d: float = _hole_diameter.value
	var depth: float = _hole_depth.value
	var type_names := ["simple", "counterbore", "countersink"]
	var htype: String = type_names[_hole_type.selected]
	var hole_fid: String = view.doc.graph_add_hole(
		target_fid, htype, position, direction, d, depth,
		1.6 * d, 0.5 * d, 2.0 * d, 90.0)
	if hole_fid != "":
		view.graph_changed()
		status.emit("Hole Ø%.1f applied" % d)
		return true
	status.emit("Hole failed")
	return false


# --- two-target ops: arm, then click the second entity ---

func _arm_boolean(op: String) -> void:
	if view.selected_body == "":
		return
	_boolean_op = op
	_pending = Pending.BOOLEAN
	_pending_first = view.selected_body
	status.emit("%s: click the tool body" % op.capitalize())


func _arm_measure() -> void:
	var first := view.selected_face if view.selected_face != "" else view.selected_body
	if first == "":
		return
	_pending = Pending.MEASURE
	_pending_first = first
	status.emit("Measure: click the other body/face")


func _resolve_pending(body: String, face: String) -> void:
	var mode := _pending
	_pending = Pending.NONE
	var second := face if face != "" else body
	if second == "" or second == _pending_first:
		status.emit("Cancelled")
		return
	match mode:
		Pending.BOOLEAN:
			if body == "" or body == _pending_first:
				status.emit("Boolean cancelled")
				return
			if view.boolean_bodies(_pending_first, body, _boolean_op):
				view.select_entity(_pending_first, "")
				status.emit("Boolean %s applied" % _boolean_op)
			else:
				status.emit("Boolean %s failed" % _boolean_op)
		Pending.MEASURE:
			var r: Dictionary = view.doc.measure_distance(_pending_first, second)
			if r.is_empty():
				status.emit("Measure failed")
			else:
				status.emit("Distance: %.2f mm" % r["distance"])
