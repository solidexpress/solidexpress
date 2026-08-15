class_name OpsPanel
extends PanelContainer
## Context operations for the current selection. Body selected: fillet/chamfer
## (all edges), mirror, linear/circular pattern, offset, boolean (arm, then
## click the tool body), measure (arm, then click the other entity). Face
## selected: shell (removes that face) plus face measurements. Armed
## precision picks (hole place, pattern direction, mirror plane) listen to
## DocumentView.picked so a re-click on the same face still lands a point.

signal status(text: String)
signal sketch_requested

enum Pending { NONE, BOOLEAN, MEASURE, HOLE, HOLE_WIZARD, LINEAR, CIRCULAR, MIRROR }

var view: DocumentView
var timeline_panel: TimelinePanel

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
var _hole_size: OptionButton
var _hole_diameter: SpinBox
var _hole_depth: SpinBox
var _hole_inset: SpinBox
var _size_w: SpinBox
var _size_h: SpinBox
var _size_d: SpinBox
var _size_row: HBoxContainer
var _size_syncing := false
var _apply_holes_btn: Button
## True after the user edits Inset; auto-inferred defaults stop overwriting.
var _hole_inset_manual := false
var _hole_inset_syncing := false
var _boolean_op := "fuse"
var _pending: Pending = Pending.NONE
var _pending_first := ""  # armed source entity (body for boolean, any for measure)
## Body/face captured when arming hole / pattern / mirror (selection may change).
var _pending_body := ""
var _pending_face := ""
var _pending_fid := ""
## Accumulated drill points for Hole Wizard (one Hole feature on Apply).
var _hole_wizard_positions: PackedVector3Array = PackedVector3Array()
var _hole_wizard_direction := Vector3.ZERO
## World-space magnet hold for Place hole… (mm). Farther clicks stay free.
const HOLE_SNAP_MM := 8.0
const HOLE_CORNER_TOL_MM := 0.45


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
	view.picked.connect(_on_picked)
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
	spin.step = 0.001
	spin.custom_arrow_step = step
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

	_size_row = VBoxContainer.new()
	_size_row.name = "PrimitiveSizeRow"
	_body_ops.add_child(_size_row)
	_size_w = _labeled_spin(_size_row, "W", 0.1, 10000.0, 0.1, 5.0)
	_size_h = _labeled_spin(_size_row, "H", 0.1, 10000.0, 0.1, 5.0)
	_size_d = _labeled_spin(_size_row, "D", 0.1, 10000.0, 0.1, 5.0)
	_size_w.value_changed.connect(_on_primitive_size_changed)
	_size_h.value_changed.connect(_on_primitive_size_changed)
	_size_d.value_changed.connect(_on_primitive_size_changed)

	_body_ops.add_child(HSeparator.new())
	var sketch_row := HBoxContainer.new()
	_body_ops.add_child(sketch_row)
	_op_button(sketch_row, "Sketch", func() -> void:
			sketch_requested.emit(),
		"sketch", "Sketch on a face or the ground plane")
	_body_ops.add_child(HSeparator.new())
	var hole_body_row := HBoxContainer.new()
	_body_ops.add_child(hole_body_row)
	_op_button(hole_body_row, "Hole…", _prompt_hole, "hole",
		"Size / depth / through-all hole on this body")
	_op_button(hole_body_row, "Hole Wizard…", _arm_hole_wizard, "hole",
		"Multi-place holes: click points, then Apply holes / Enter")
	_op_button(hole_body_row, "Hex opening", _apply_hex_opening, "polygon",
		"Through hex cut sized to jaw_af + clearance")

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
		"Repeat along +X (default). Use Linear… to pick an edge for direction.")
	_op_button(pat_row, "Circular", _circular_pattern, "circular_pattern",
		"Repeat around +Z (default). Use Circular… to pick an edge/face for the axis.")
	_op_button(pat_row, "Mirror", _mirror, "mirror",
		"Mirror across the body's +X face (default). Use Mirror… to pick a plane.")
	var pat_pick_row := HBoxContainer.new()
	_body_ops.add_child(pat_pick_row)
	_op_button(pat_pick_row, "Linear…", _arm_linear, "linear_pattern",
		"Arm: click an edge to set the pattern direction")
	_op_button(pat_pick_row, "Circular…", _arm_circular, "circular_pattern",
		"Arm: click an edge or face to set the pattern axis")
	_op_button(pat_pick_row, "Mirror…", _arm_mirror, "mirror",
		"Arm: click a planar face to set the mirror plane")

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
	_op_button(_body_ops, "Thread…", _apply_thread, "hole",
		"Cut an external thread on this body (axis +Z through body center)")


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
	_hole_type.add_item("Hex", 3)
	hole_type_row.add_child(_hole_type)
	var size_row := HBoxContainer.new()
	_face_ops.add_child(size_row)
	var size_lbl := Label.new()
	size_lbl.text = "Size"
	size_lbl.custom_minimum_size = Vector2(80, 0)
	size_lbl.add_theme_font_size_override("font_size", 11)
	size_row.add_child(size_lbl)
	_hole_size = OptionButton.new()
	_hole_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hole_size.tooltip_text = "Nominal fastener size; Ø = nominal + hole_compensation"
	for spec in [["M3", 3.0], ["M4", 4.0], ["M5", 5.0], ["M6", 6.0],
			["M8", 8.0], ["M10", 10.0], ["Custom", 0.0]]:
		_hole_size.add_item(str(spec[0]))
		_hole_size.set_item_metadata(_hole_size.item_count - 1, spec[1])
	_hole_size.selected = 3
	_hole_size.item_selected.connect(_on_hole_size_selected)
	size_row.add_child(_hole_size)
	_hole_diameter = _labeled_spin(_face_ops, "Hole Ø", 0.1, 200.0, 0.1, 6.0)
	_hole_depth = _labeled_spin(_face_ops, "Depth (0=thru)", 0.0, 1000.0, 1.0, 0.0)
	_hole_depth.tooltip_text = "Blind depth in mm; 0 = through-all"
	_hole_inset = _labeled_spin(_face_ops, "Inset", 0.5, 500.0, 0.5, 8.0)
	_hole_inset.tooltip_text = "Corner edge distance (auto from Ø, thickness, material softness)"
	_hole_diameter.value_changed.connect(_on_hole_diameter_changed)
	_hole_inset.value_changed.connect(_on_hole_inset_changed)
	var hole_row := HBoxContainer.new()
	_face_ops.add_child(hole_row)
	_op_button(hole_row, "Apply hole", _apply_hole, "hole",
		"Drill at the center of this face")
	_op_button(hole_row, "Place hole…", _arm_hole, "hole",
		"Arm: click a point on a face (near corner → inset; near mid → snap; else free)")
	var wizard_row := HBoxContainer.new()
	_face_ops.add_child(wizard_row)
	_op_button(wizard_row, "Hole Wizard…", _arm_hole_wizard, "hole",
		"Multi-place: click several face points, then Apply holes / Enter (one Hole feature)")
	_apply_holes_btn = _op_button(wizard_row, "Apply holes", _apply_hole_wizard, "hole",
		"Commit accumulated Hole Wizard points as one feature (Enter)")
	_apply_holes_btn.disabled = true
	_op_button(_face_ops, "Hex opening", _apply_hex_opening, "polygon",
		"Through hex cut on this face, AF = jaw_af + clearance")
	_op_button(_face_ops, "Face area", func() -> void:
		status.emit("Area: %.2f mm^2" % view.doc.measure_face_area(view.selected_face)),
		"area", "Show the area of this face")


func _on_selection_changed(body: String, face: String) -> void:
	# Boolean / measure still resolve on selection change (different entity).
	# Hole / pattern / mirror resolve via picked so same-face re-clicks work.
	if _pending == Pending.BOOLEAN or _pending == Pending.MEASURE:
		_resolve_pending(body, face, view.last_pick_point)
		return
	visible = body != ""
	_body_ops.visible = body != "" and face == ""
	_face_ops.visible = face != ""
	if body != "" and face == "":
		_name_edit.text = view.doc.body_name(body)
		_color_picker.color = view.doc.get_body_color(body)
		_sync_material_option(body)
		_sync_primitive_size(body)
	if face != "":
		# New face: re-infer inset unless the user typed one this session.
		_hole_inset_manual = false
		_sync_hole_inset_default()
	_clamp_height()


func _on_picked(body: String, face: String, point: Vector3) -> void:
	if _pending == Pending.HOLE_WIZARD:
		_accumulate_hole_wizard_pick(body, face, point)
		return
	if _pending == Pending.HOLE or _pending == Pending.LINEAR \
			or _pending == Pending.CIRCULAR or _pending == Pending.MIRROR:
		_resolve_pending(body, face, point)


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
		# Softer / denser stock changes the inferred corner inset.
		if not _hole_inset_manual:
			_sync_hole_inset_default()


func _sync_primitive_size(body: String) -> void:
	if _size_row == null or view == null:
		return
	var prim := view.is_primitive_body(body)
	_size_row.visible = prim
	if not prim:
		return
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return
	var sz: Vector3 = bb["max"] - bb["min"]
	_size_syncing = true
	_size_w.value = sz.x
	_size_h.value = sz.y
	_size_d.value = sz.z
	_size_syncing = false


func _on_primitive_size_changed(_v: float) -> void:
	if _size_syncing or view == null or view.selected_body == "":
		return
	if not view.is_primitive_body(view.selected_body):
		return
	var bb: Dictionary = view.selection_bbox()
	if bb.is_empty():
		return
	var size := Vector3(_size_w.value, _size_h.value, _size_d.value)
	var center: Vector3 = bb["center"]
	var half := size * 0.5
	if view.resize_primitive_aabb(view.selected_body, center - half, center + half):
		status.emit("Size → %.3f × %.3f × %.3f" % [size.x, size.y, size.z])


func _on_hole_size_selected(index: int) -> void:
	if _hole_size == null or _hole_diameter == null:
		return
	var nom := float(_hole_size.get_item_metadata(index))
	if nom > 0.0:
		_hole_diameter.value = nom
	if not _hole_inset_manual:
		_sync_hole_inset_default()


func _on_hole_diameter_changed(_v: float) -> void:
	if not _hole_inset_manual:
		_sync_hole_inset_default()


func _on_hole_inset_changed(_v: float) -> void:
	if not _hole_inset_syncing:
		_hole_inset_manual = true


func _sync_hole_inset_default() -> void:
	if _hole_inset == null or view == null:
		return
	var body := view.selected_body
	var face := view.selected_face
	if body == "" or face == "":
		return
	var suggested := suggested_hole_inset(
			_hole_diameter.value, _face_thickness_mm(body, face), view.doc.body_material(body))
	_hole_inset_syncing = true
	_hole_inset.value = suggested
	_hole_inset_syncing = false


## Softness 0 (hard metal) … ~1 (elastomer). Drives default corner inset.
static func material_softness(material_name: String) -> float:
	match material_name:
		"TPU":
			return 0.95
		"Nylon", "PLA", "PC", "PPA":
			return 0.55
		"Aluminum", "Titanium":
			return 0.25
		"Copper", "Stainless Steel", "Tool Steel", "Inconel", "Cobalt Chrome":
			return 0.1
		_:
			return 0.4  # Unspecified / unknown — middle of the road


## Default center-to-edge distance for corner snaps (mm).
## Bigger Ø and softer + thicker stock push the hole farther in.
static func suggested_hole_inset(diameter: float, thickness: float, material_name: String) -> float:
	var d := maxf(diameter, 0.5)
	var t := maxf(thickness, 0.5)
	var soft := material_softness(material_name)
	# ~1×Ø on hard thin stock; grows with softness and thickness (tear-out).
	var inset := d * (1.0 + 0.55 * soft) + t * soft * 0.35
	var lo := d * 0.75
	var hi := maxf(d * 3.0, t * 2.5)
	return clampf(snapped(inset, 0.5), lo, hi)


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
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return
	# Feature mode: mid-X of bbox. Body mode: +X extent (keeps body tests green).
	var plane_x: float = bb["max"].x
	if _mirror_source_feature_id(body) != "":
		plane_x = (bb["min"].x + bb["max"].x) * 0.5
	_do_mirror(body, Vector3(plane_x, 0, 0), Vector3(1, 0, 0))


func _linear_pattern() -> void:
	var body := view.selected_body
	if body == "":
		return
	_do_linear(body, Vector3(1, 0, 0))


func _circular_pattern() -> void:
	var body := view.selected_body
	if body == "":
		return
	_do_circular(body, Vector3.ZERO, Vector3(0, 0, 1))


func _mirror_source_feature_id(body: String) -> String:
	if timeline_panel == null:
		return ""
	var selected_fid := timeline_panel.selected_feature_id()
	if selected_fid == "":
		return ""
	var target_fid := view.feature_of_body(body)
	if target_fid == "":
		return ""
	const MODIFYING := {
		"extrude": true, "revolve": true, "fillet": true, "chamfer": true,
		"hole": true, "shell": true, "draft": true, "push_pull": true,
	}
	for f in view.doc.graph_features():
		if str(f.get("id", "")) != selected_fid:
			continue
		var ftype := str(f.get("type", ""))
		if not MODIFYING.has(ftype):
			return ""
		# Modifying features target a body via params.target (feature id).
		var params: Dictionary = f.get("params", {})
		var tgt := str(params.get("target", ""))
		if tgt == target_fid or tgt == body:
			return selected_fid
		# Also accept when the selected feature's output is this body (rare).
		if str(f.get("output_body", "")) == body:
			return selected_fid
		return ""
	return ""


func _do_mirror(body: String, plane_point: Vector3, plane_normal: Vector3) -> void:
	var fid := view.feature_of_body(body)
	var created := ""
	var feature_mode := false
	var source_fid := _mirror_source_feature_id(body)
	if source_fid != "" and fid != "":
		var sources := PackedStringArray()
		sources.append(source_fid)
		created = view.doc.graph_add_mirror(fid, plane_point, plane_normal, sources)
		feature_mode = true
	elif fid != "":
		created = view.doc.graph_add_mirror(fid, plane_point, plane_normal)
	else:
		created = view.doc.mirror_body(body, plane_point, plane_normal, true)
	view.graph_changed()
	if created == "":
		status.emit("Mirror failed")
	elif feature_mode:
		status.emit("Mirrored feature")
	else:
		status.emit("Mirrored body")


func _do_linear(body: String, direction: Vector3) -> void:
	if direction.length_squared() < 1e-12:
		status.emit("Pattern failed (zero direction)")
		return
	var made: PackedStringArray = PackedStringArray()
	# Body-mode pattern makes count-1 copies (UI expectation in ops panel tests).
	made = view.doc.linear_pattern(
		body, direction.normalized(), _pattern_spacing.value, int(_pattern_count.value))
	view.graph_changed()
	status.emit("%d copies created" % made.size() if made.size() > 0 else "Pattern failed")


func _do_circular(body: String, axis_point: Vector3, axis_dir: Vector3) -> void:
	if axis_dir.length_squared() < 1e-12:
		status.emit("Pattern failed (zero axis)")
		return
	var made: PackedStringArray = PackedStringArray()
	# Body-mode circular pattern produces separate copies.
	made = view.doc.circular_pattern(
		body, axis_point, axis_dir.normalized(), int(_pattern_count.value), TAU)
	view.graph_changed()
	status.emit("%d copies created" % made.size() if made.size() > 0 else "Pattern failed")


func _apply_thread() -> void:
	_show_thread_dialog()


func _show_thread_dialog() -> void:
	if view == null or view.selected_body == "":
		status.emit("Thread: select a body")
		return
	var bb: Dictionary = view.doc.measure_bbox(view.selected_body)
	if bb.is_empty():
		status.emit("Thread failed (no bbox)")
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var size := mx - mn
	var major_r: float = 0.5 * minf(size.x, size.y)
	var height: float = maxf(size.z, 1.0)
	var dlg := AcceptDialog.new()
	dlg.title = "Thread"
	dlg.ok_button_text = "Apply"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	dlg.add_child(col)
	var hint := Label.new()
	hint.text = "Modeled triangular thread along +Z through the body."
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var rspin := _labeled_spin(col, "Major r", 0.2, 200.0, 0.1, maxf(major_r, 0.5))
	var pspin := _labeled_spin(col, "Pitch", 0.2, 20.0, 0.05, clampf(major_r * 0.2, 0.4, 2.0))
	var cosmetic := CheckBox.new()
	cosmetic.text = "Cosmetic only (no cut)"
	col.add_child(cosmetic)
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		_commit_thread(rspin.value, pspin.value, height, mn, mx, cosmetic.button_pressed)
		dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	dlg.close_requested.connect(func() -> void: dlg.queue_free())
	dlg.popup_centered(Vector2i(340, 240))


func _commit_thread(major_r: float, pitch: float, height: float, mn: Vector3, mx: Vector3,
		cosmetic: bool) -> void:
	var body := view.selected_body
	var fid := view.feature_of_body(body)
	if fid == "":
		status.emit("Thread needs a timeline body")
		return
	if cosmetic:
		status.emit("Cosmetic thread Ø%.1f (not modeled)" % (2.0 * major_r))
		return
	if major_r < 0.2 or height < 0.5:
		status.emit("Thread failed (body too small)")
		return
	var turns: float = maxf(1.0, height / maxf(pitch, 0.2) - 0.5)
	var depth: float = pitch * 0.5
	var axis_point := Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z)
	var tid: String = view.doc.graph_add_thread(
		fid, major_r, pitch, turns, depth, 60.0, axis_point, Vector3(0, 0, 1))
	if tid != "":
		view.graph_changed()
		status.emit("Thread Ø%.1f pitch %.2f (%d turns)" % [2.0 * major_r, pitch, int(turns)])
	else:
		status.emit("Thread failed")


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
	# Use body-mode draft to ensure consistent behavior across app versions.
	ok = view.doc.draft_faces(PackedStringArray([face]), angle, Vector3(0, 0, 1),
			neutral_point, Vector3(0, 0, 1))
	if ok:
		view.graph_changed()
		status.emit("Draft %.1f° applied" % angle)
		return true
	status.emit("Draft failed")
	return false


func _apply_hole() -> bool:
	var body := view.selected_body if view.selected_body != "" else _pending_body
	if body == "":
		status.emit("Hole: select a body")
		return false
	var face := view.selected_face if view.selected_face != "" else _pending_face
	var bb: Dictionary = view.doc.measure_bbox(body)
	if not bb.is_empty():
		var sz: Vector3 = bb["max"] - bb["min"]
		var min_e := minf(sz.x, minf(sz.y, sz.z))
		if _hole_type == null or _hole_type.selected != 3:
			if _hole_diameter.value >= min_e - 0.05:
				status.emit("Hole Ø%.1f is larger than the part (%.1f mm)" % [
					_hole_diameter.value, min_e])
				_show_hole_dialog(false)
				return false
	return _commit_hole(body, face, _default_hole_position(body, face))


func _prompt_hole() -> void:
	_show_hole_dialog(false)


func _show_hole_dialog(hex_mode: bool) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Hex opening" if hex_mode else "Hole"
	dlg.ok_button_text = "Apply"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	dlg.add_child(col)
	var hint := Label.new()
	hint.text = "AF = jaw_af + clearance · Depth 0 = through-all" if hex_mode \
			else "Ø = nominal + hole_compensation · Depth 0 = through-all"
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var dspin := _labeled_spin(col, "AF" if hex_mode else "Ø", 0.1, 200.0, 0.1,
			_hex_af() if hex_mode else _hole_diameter.value)
	var zspin := _labeled_spin(col, "Depth (0=thru)", 0.0, 1000.0, 1.0, _hole_depth.value)
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		_hole_diameter.value = dspin.value
		_hole_depth.value = zspin.value
		if hex_mode:
			_apply_hex_opening()
		else:
			_apply_hole()
		dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	dlg.close_requested.connect(func() -> void: dlg.queue_free())
	dlg.popup_centered(Vector2i(340, 220))


func _default_hole_position(body: String, face: String) -> Vector3:
	if face != "" and view != null:
		var mid: Variant = view.doc.face_midpoint(face)
		if mid is Vector3:
			return mid
		var face_bb: Dictionary = view.doc.measure_bbox(face)
		if not face_bb.is_empty():
			return (face_bb["min"] + face_bb["max"]) * 0.5
	if body != "" and view != null:
		var bb: Dictionary = view.doc.measure_bbox(body)
		if not bb.is_empty():
			var mn: Vector3 = bb["min"]
			var mx: Vector3 = bb["max"]
			return Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z)
	return Vector3.ZERO


func _hex_af() -> float:
	return view._default_jaw_af() + _variable_number("clearance", 0.3) if view != null \
			else 10.3


func _variable_number(name: String, fallback: float) -> float:
	if view == null:
		return fallback
	for v in view.doc.list_variables():
		if str(v.get("name", "")).strip_edges() == name:
			var val = v.get("value", NAN)
			if typeof(val) == TYPE_FLOAT and not is_nan(val):
				return float(val)
			var parsed := str(v.get("expr", "")).to_float()
			if parsed != 0.0 or str(v.get("expr", "")).begins_with("0"):
				return parsed
	return fallback


func _arm_hole() -> void:
	var body := view.selected_body
	if body == "":
		status.emit("Hole: select a body")
		return
	var fid := view.feature_of_body(body)
	if fid == "":
		status.emit("Hole needs a timeline body")
		return
	_clear_hole_wizard()
	_pending = Pending.HOLE
	_pending_body = body
	_pending_face = view.selected_face
	_pending_fid = fid
	_pending_first = _pending_face
	status.emit("Hole: click a face (near corner → inset %.1f mm)" % _hole_inset.value)


func _arm_hole_wizard() -> void:
	var body := view.selected_body
	if body == "":
		status.emit("Hole Wizard: select a body")
		return
	var fid := view.feature_of_body(body)
	if fid == "":
		status.emit("Hole Wizard needs a timeline body")
		return
	_pending = Pending.HOLE_WIZARD
	_pending_body = body
	_pending_face = view.selected_face
	_pending_fid = fid
	_pending_first = _pending_face
	_hole_wizard_positions = PackedVector3Array()
	_hole_wizard_direction = Vector3.ZERO
	_sync_apply_holes_btn()
	status.emit("Hole Wizard: click points on a face, then Apply holes / Enter")


func _clear_hole_wizard() -> void:
	_hole_wizard_positions = PackedVector3Array()
	_hole_wizard_direction = Vector3.ZERO
	_sync_apply_holes_btn()


func _sync_apply_holes_btn() -> void:
	if _apply_holes_btn != null:
		_apply_holes_btn.disabled = _hole_wizard_positions.is_empty()


func is_hole_wizard_armed() -> bool:
	return _pending == Pending.HOLE_WIZARD


func hole_wizard_point_count() -> int:
	return _hole_wizard_positions.size()


## Cancel Hole Wizard (or any armed pending pick). Returns true if something was armed.
func cancel_pending_pick() -> bool:
	if _pending == Pending.NONE:
		return false
	var was_wizard := _pending == Pending.HOLE_WIZARD
	_pending = Pending.NONE
	_clear_hole_wizard()
	status.emit("Hole Wizard cancelled" if was_wizard else "Cancelled")
	return true


func _accumulate_hole_wizard_pick(body: String, face: String, point: Vector3) -> void:
	var target_body := _pending_body
	var target_face := face if face != "" else _pending_face
	if body != "" and body != target_body:
		status.emit("Hole Wizard: pick the same body (or Apply holes / Esc)")
		return
	if target_face == "":
		status.emit("Hole Wizard: need a face")
		return
	var position := _hole_place_position(target_body, target_face, point)
	_pending_face = target_face
	if _hole_wizard_direction.length_squared() < 1e-12:
		var outward: Vector3 = view.face_normal(target_body, target_face)
		if outward.length_squared() > 1e-12:
			_hole_wizard_direction = -outward.normalized()
		else:
			_hole_wizard_direction = Vector3(0, 0, -1)
	_hole_wizard_positions.append(position)
	_sync_apply_holes_btn()
	status.emit("Hole Wizard: %d point(s) — click more, Apply holes / Enter, Esc cancel" %
			_hole_wizard_positions.size())


func _apply_hole_wizard() -> bool:
	if _pending != Pending.HOLE_WIZARD and _hole_wizard_positions.is_empty():
		status.emit("Hole Wizard: arm first (Hole Wizard…), then click points")
		return false
	if _hole_wizard_positions.is_empty():
		status.emit("Hole Wizard: click at least one point")
		return false
	var body := _pending_body if _pending_body != "" else view.selected_body
	var face := _pending_face if _pending_face != "" else view.selected_face
	var ok := _commit_holes(body, face, _hole_wizard_positions, _hole_wizard_direction)
	_pending = Pending.NONE
	_clear_hole_wizard()
	return ok


func _commit_holes(body: String, face: String, positions: PackedVector3Array,
		direction: Vector3) -> bool:
	var target_fid := view.feature_of_body(body)
	if target_fid == "" or positions.is_empty():
		status.emit("Hole Wizard needs a timeline body and points")
		return false
	var dir := direction
	if dir.length_squared() < 1e-12:
		var outward: Vector3 = view.face_normal(body, face) if face != "" else Vector3.ZERO
		if outward.length_squared() > 1e-12:
			dir = -outward.normalized()
		else:
			dir = Vector3(0, 0, -1)
	var d: float = _hole_diameter.value
	var depth: float = _hole_depth.value
	var type_names := ["simple", "counterbore", "countersink", "hex"]
	var idx: int = _hole_type.selected if _hole_type != null else 0
	var htype: String = type_names[clampi(idx, 0, type_names.size() - 1)]
	var hole_fid: String = view.doc.graph_add_holes(
		target_fid, htype, positions, dir, d, depth,
		1.6 * d, 0.5 * d, 2.0 * d, 90.0)
	if hole_fid != "":
		_stamp_hole_expressions(hole_fid, htype, d)
		view.graph_changed()
		status.emit("Hole Wizard: %d × Ø%.1f" % [positions.size(), d])
		return true
	status.emit("Hole Wizard failed")
	return false


func _commit_hole(body: String, face: String, position: Vector3) -> bool:
	var target_fid := view.feature_of_body(body)
	if target_fid == "":
		status.emit("Hole needs a timeline body")
		return false
	var outward: Vector3 = view.face_normal(body, face)
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
	var type_names := ["simple", "counterbore", "countersink", "hex"]
	var idx: int = _hole_type.selected if _hole_type != null else 0
	var htype: String = type_names[clampi(idx, 0, type_names.size() - 1)]
	var hole_fid: String = view.doc.graph_add_hole(
		target_fid, htype, position, direction, d, depth,
		1.6 * d, 0.5 * d, 2.0 * d, 90.0)
	if hole_fid != "":
		_stamp_hole_expressions(hole_fid, htype, d)
		view.graph_changed()
		status.emit("Hole Ø%.1f at (%.1f, %.1f, %.1f)" % [d, position.x, position.y, position.z])
		return true
	status.emit("Hole failed")
	return false


func _stamp_hole_expressions(hole_fid: String, htype: String, nominal: float) -> void:
	var raw: String = ""
	for f in view.doc.graph_features():
		if f["id"] == hole_fid:
			raw = f["params"]
			break
	var params = JSON.parse_string(raw) if raw != "" else null
	if typeof(params) != TYPE_DICTIONARY:
		return
	if htype == "hex":
		params["diameter"] = "=jaw_af+clearance"
	else:
		params["nominal"] = nominal
	view.doc.graph_set_params(hole_fid, JSON.stringify(params))


func _apply_hex_opening() -> bool:
	if view == null or view.selected_body == "":
		status.emit("Hex opening: select a body")
		return false
	if _hole_type != null:
		_hole_type.selected = 3
	_hole_diameter.value = _hex_af()
	_hole_depth.value = 0.0
	var ok := _apply_hole()
	if ok:
		status.emit("Hex opening AF = jaw_af+clearance")
	return ok


# --- two-target / precision-pick ops: arm, then click ---

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


func _arm_linear() -> void:
	var body := view.selected_body
	if body == "":
		return
	_pending = Pending.LINEAR
	_pending_body = body
	_pending_fid = view.feature_of_body(body)
	_pending_first = body
	status.emit("Linear pattern: click an edge for direction")


func _arm_circular() -> void:
	var body := view.selected_body
	if body == "":
		return
	_pending = Pending.CIRCULAR
	_pending_body = body
	_pending_fid = view.feature_of_body(body)
	_pending_first = body
	status.emit("Circular pattern: click an edge or face for the axis")


func _arm_mirror() -> void:
	var body := view.selected_body
	if body == "":
		return
	_pending = Pending.MIRROR
	_pending_body = body
	_pending_fid = view.feature_of_body(body)
	_pending_first = body
	status.emit("Mirror: click a planar face for the mirror plane")


func _resolve_pending(body: String, face: String, point: Vector3) -> void:
	var mode := _pending
	_pending = Pending.NONE
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
			var second := face if face != "" else body
			if second == "" or second == _pending_first:
				status.emit("Cancelled")
				return
			var r: Dictionary = view.doc.measure_distance(_pending_first, second)
			if r.is_empty():
				status.emit("Measure failed")
			else:
				status.emit("Distance: %.2f mm" % r["distance"])
		Pending.HOLE:
			_resolve_hole_pick(body, face, point)
		Pending.LINEAR:
			_resolve_linear_pick(body, face)
		Pending.CIRCULAR:
			_resolve_circular_pick(body, face)
		Pending.MIRROR:
			_resolve_mirror_pick(body, face)


func _resolve_hole_pick(body: String, face: String, point: Vector3) -> void:
	var target_body := _pending_body
	var target_face := face if face != "" else _pending_face
	if body != "" and body != target_body:
		# Allow drilling into another face of the same body only.
		status.emit("Hole cancelled (pick the same body)")
		return
	if target_face == "":
		status.emit("Hole cancelled (need a face)")
		return
	var position := _hole_place_position(target_body, target_face, point)
	_commit_hole(target_body, target_face, position)


## Resolve click → drill point: nearby magnets snap; corners inset by Inset.
func _hole_place_position(body: String, face: String, point: Vector3) -> Vector3:
	var snap: Vector3 = view.closest_measure_snap(body, point)
	var snap_tol := maxf(HOLE_SNAP_MM, maxf(_hole_diameter.value * 0.75, _hole_inset.value * 0.5))
	var raw_on_face: Dictionary = view.doc.closest_point_on(face, point)
	var raw: Vector3 = raw_on_face["point_b"] if not raw_on_face.is_empty() else point
	if point.distance_to(snap) > snap_tol:
		return raw
	if _is_corner_snap(body, snap):
		var inset_pt := _inset_from_corner(body, face, snap, _hole_inset.value)
		var on_face: Dictionary = view.doc.closest_point_on(face, inset_pt)
		return on_face["point_b"] if not on_face.is_empty() else inset_pt
	var mid_on_face: Dictionary = view.doc.closest_point_on(face, snap)
	return mid_on_face["point_b"] if not mid_on_face.is_empty() else snap


## Body extent along the face normal (plate thickness for a top face).
func _face_thickness_mm(body: String, face: String) -> float:
	var n: Vector3 = view.face_normal(body, face)
	if n.length_squared() < 1e-12:
		return 1.0
	n = n.normalized()
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return 1.0
	var size: Vector3 = bb["max"] - bb["min"]
	return maxf(absf(n.x) * size.x + absf(n.y) * size.y + absf(n.z) * size.z, 0.5)


func _is_corner_snap(body: String, snap: Vector3) -> bool:
	for c in _corner_candidates(body):
		if snap.distance_to(c) <= HOLE_CORNER_TOL_MM:
			return true
	return false


func _corner_candidates(body: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var bb: Dictionary = view.doc.measure_bbox(body)
	if not bb.is_empty():
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		for x in [mn.x, mx.x]:
			for y in [mn.y, mx.y]:
				for z in [mn.z, mx.z]:
					out.append(Vector3(x, y, z))
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.is_empty():
			continue
		out.append(pts[0])
		if pts.size() > 1:
			out.append(pts[pts.size() - 1])
	return out


func _inset_from_corner(body: String, face: String, corner: Vector3, inset: float) -> Vector3:
	var mid: Vector3 = view.doc.face_midpoint(face)
	var n: Vector3 = view.face_normal(body, face)
	if n.length_squared() < 1e-12:
		return corner
	n = n.normalized()
	var to_mid := mid - corner
	to_mid -= n * to_mid.dot(n)
	var dirs := _corner_inward_edge_dirs(body, face, corner, n, to_mid)
	if dirs.size() >= 2:
		return corner + dirs[0] * inset + dirs[1] * inset
	if dirs.size() == 1:
		var along: Vector3 = dirs[0]
		var perp := n.cross(along).normalized()
		if perp.dot(to_mid) < 0.0:
			perp = -perp
		return corner + along * inset + perp * inset
	if to_mid.length_squared() < 1e-12:
		return corner
	return corner + to_mid.normalized() * (inset * sqrt(2.0))


func _corner_inward_edge_dirs(
		body: String, face: String, corner: Vector3, normal: Vector3, to_mid: Vector3
) -> Array[Vector3]:
	var face_plane_pt: Vector3 = view.doc.face_midpoint(face)
	var dirs: Array[Vector3] = []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.size() < 2:
			continue
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[pts.size() - 1]
		var near_a := a.distance_to(corner) <= HOLE_CORNER_TOL_MM
		var near_b := b.distance_to(corner) <= HOLE_CORNER_TOL_MM
		if not near_a and not near_b:
			continue
		var da := absf((a - face_plane_pt).dot(normal))
		var db := absf((b - face_plane_pt).dot(normal))
		if da > 0.75 or db > 0.75:
			continue
		var along := (b - a).normalized()
		if near_b:
			along = -along
		if absf(along.dot(normal)) > 0.35:
			continue
		if along.dot(to_mid) <= 1e-6:
			continue
		var dup := false
		for existing in dirs:
			if absf(existing.dot(along)) > 0.92:
				dup = true
				break
		if not dup:
			dirs.append(along)
		if dirs.size() >= 2:
			break
	return dirs


func _resolve_linear_pick(body: String, _face: String) -> void:
	var src := _pending_body
	var edge_body := body if body != "" else src
	var edge := _nearest_edge(edge_body, view.last_pick_point)
	var dir := view.edge_direction(edge_body, edge)
	if dir.length_squared() < 1e-12:
		status.emit("Linear cancelled (pick an edge)")
		return
	_do_linear(src, dir)
	view.select_entity(src, "")


func _resolve_circular_pick(body: String, face: String) -> void:
	var src := _pending_body
	var axis_point := Vector3.ZERO
	var axis_dir := Vector3.ZERO
	var pick_body := body if body != "" else src
	# Prefer an edge near the click (axis along the edge); else use face normal.
	var edge := _nearest_edge(pick_body, view.last_pick_point)
	var edge_dir := view.edge_direction(pick_body, edge)
	if edge != "" and edge_dir.length_squared() > 1e-12 \
			and view.last_pick_point.distance_to(view.edge_midpoint(pick_body, edge)) < 8.0:
		axis_dir = edge_dir
		axis_point = view.edge_midpoint(pick_body, edge)
	elif face != "":
		axis_dir = view.face_normal(pick_body, face)
		axis_point = view.doc.face_midpoint(face)
	if axis_dir.length_squared() < 1e-12:
		status.emit("Circular cancelled (pick an edge or face)")
		return
	_do_circular(src, axis_point, axis_dir)
	view.select_entity(src, "")


func _resolve_mirror_pick(body: String, face: String) -> void:
	var src := _pending_body
	if face == "":
		status.emit("Mirror cancelled (pick a planar face)")
		return
	var face_body := body if body != "" else src
	var n := view.face_normal(face_body, face)
	if n.length_squared() < 1e-12:
		status.emit("Mirror cancelled (need a planar face)")
		return
	var pt := view.doc.face_midpoint(face)
	_do_mirror(src, pt, n.normalized())
	view.select_entity(src, "")


func _nearest_edge(body_id: String, point: Vector3) -> String:
	if body_id == "":
		return ""
	var lines: Dictionary = view.doc.get_edge_lines(body_id)
	var best_d := 1e30
	var best_e := ""
	for eid in lines:
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var mid: Vector3 = view.edge_midpoint(body_id, eid)
		var d: float = mid.distance_squared_to(point)
		d = minf(d, pts[0].distance_squared_to(point))
		d = minf(d, pts[pts.size() - 1].distance_squared_to(point))
		if d < best_d:
			best_d = d
			best_e = eid
	return best_e
