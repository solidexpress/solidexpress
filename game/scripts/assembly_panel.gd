class_name AssemblyPanel
extends PanelContainer
## Assembly browser: component instances and mates with place / remove / solve.
## Hidden when the document has nothing assembly-related and no mate pick is armed.

signal status(text: String)
signal instance_selected(id: String)

## Joint types share the mate type list: one question ("how do these two faces
## relate?"), one two-click flow. Joints leave one degree of freedom to drag.
const JOINT_TYPES := ["revolute", "slider", "cylindrical", "planar", "ball", "pin_slot"]

var view: DocumentView

var _instances_list: VBoxContainer
var _mates_list: VBoxContainer
var _type_option: OptionButton
var _offset_spin: SpinBox
var _refreshing := false

## Armed two-click mate flow: wait for ground face A, then instanced face B.
var _mate_armed := false
var _mate_face_a := ""
## Sticky error from the last mate add / solve ("" when healthy). Shown as a
## red badge above the mates list instead of only a transient status line.
var _mate_error := ""


func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Assembly"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var inst_hdr := Label.new()
	inst_hdr.text = "Instances"
	inst_hdr.add_theme_font_size_override("font_size", 11)
	vbox.add_child(inst_hdr)
	_instances_list = VBoxContainer.new()
	vbox.add_child(_instances_list)
	_op_button(vbox, "Place instance of selection", _place_instance, "instance",
		"Place a linked copy of the selected body offset to the side")
	_op_button(vbox, "Insert Components…", _insert_components, "instance",
		"Insert bodies from another .sxp as component instances (multi-doc)")
	_op_button(vbox, "Pattern around joint", _pattern_instance, "circular_pattern",
		"Copy the selected component around its joint axis; every copy inherits the joint")

	vbox.add_child(HSeparator.new())

	var mate_hdr := Label.new()
	mate_hdr.text = "Mates"
	mate_hdr.add_theme_font_size_override("font_size", 11)
	vbox.add_child(mate_hdr)
	_mates_list = VBoxContainer.new()
	vbox.add_child(_mates_list)

	_type_option = OptionButton.new()
	_type_option.name = "MateType"
	_type_option.tooltip_text = "How the two faces relate: a mate locks degrees of freedom, a joint leaves one free to drag"
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in ["fastened", "plane_coincident", "plane_parallel", "concentric", "fixed"]:
		_type_option.add_item(t)
	for t in JOINT_TYPES:
		_type_option.add_item(t)
	vbox.add_child(_type_option)

	_offset_spin = _labeled_spin(vbox, "Offset", -1000.0, 1000.0, 0.5, 0.0)
	_op_button(vbox, "Add mate", _arm_mate, "mate",
		"Add a mate or joint: click a ground face, then a face on an instance")
	_op_button(vbox, "Solve mates", _solve_mates, "solve",
		"Re-apply every mate and pose every joint, moving instances into position")

	view.selection_changed.connect(_on_selection_changed)
	view.document_changed.connect(refresh_lists)
	refresh_lists()


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
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = UIIcons.get_icon(icon_name)
	b.tooltip_text = tooltip if tooltip != "" else text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _truncate(s: String, n: int = 18) -> String:
	if s.length() <= n:
		return s
	return s.substr(0, n)


func refresh_lists() -> void:
	if _refreshing:
		return
	_refreshing = true
	for child in _instances_list.get_children():
		child.queue_free()
	for child in _mates_list.get_children():
		child.queue_free()

	var instances: Array = view.doc.instance_list()
	for inst in instances:
		_instances_list.add_child(_make_instance_row(inst))

	if _mate_error != "":
		var badge := Label.new()
		badge.name = "MateError"
		badge.text = "! " + _mate_error
		badge.tooltip_text = _mate_error
		badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		badge.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
		badge.add_theme_font_size_override("font_size", 11)
		_mates_list.add_child(badge)

	var mates: Array = view.doc.mate_list()
	for mate in mates:
		_mates_list.add_child(_make_mate_row(mate))

	var joints: Array = view.doc.joint_list()
	for joint in joints:
		_mates_list.add_child(_make_joint_row(joint))

	var connectors: Array = view.doc.connector_list() if view.doc.has_method("connector_list") else []
	if not connectors.is_empty():
		var ch := Label.new()
		ch.text = "Connectors"
		ch.add_theme_font_size_override("font_size", 11)
		_mates_list.add_child(ch)
		for c in connectors:
			var cl := Label.new()
			cl.text = str(c.get("name", "connector"))
			cl.tooltip_text = "Implicit/explicit mate connector"
			cl.add_theme_font_size_override("font_size", 11)
			_mates_list.add_child(cl)

	# Also show on a body selection: placing the *first* instance is the one
	# assembly verb you need while the assembly is still empty.
	var can_instance: bool = view != null and view.selected_body != ""
	visible = can_instance or not instances.is_empty() or not mates.is_empty() or _mate_armed \
			or not connectors.is_empty() or not joints.is_empty()
	_refreshing = false


func _make_instance_row(inst: Dictionary) -> Control:
	var id: String = inst["id"]
	var is_fixed: bool = bool(inst.get("fixed", false))
	var row := HBoxContainer.new()
	row.set_meta("instance_id", id)
	var name_lbl := Label.new()
	var prefix := "(f) " if is_fixed else ""
	name_lbl.text = prefix + _truncate(str(inst.get("name", id)))
	name_lbl.tooltip_text = str(inst.get("source_path", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)
	var sel := UIIcons.button("select", "", "Highlight this instance in the viewport")
	sel.pressed.connect(func() -> void: instance_selected.emit(id))
	row.add_child(sel)
	var fix_icon := "unlock" if is_fixed else "lock"
	var fix_tip := "Float this component (allow drag)" if is_fixed else "Fix this component (lock in place)"
	var fix_btn := UIIcons.button(fix_icon, "", fix_tip)
	fix_btn.name = "FixFloat"
	fix_btn.pressed.connect(_toggle_fixed.bind(id, not is_fixed))
	row.add_child(fix_btn)
	var rm := UIIcons.button("delete", "", "Remove this instance (and its mates)")
	rm.pressed.connect(_remove_instance.bind(id))
	row.add_child(rm)
	return row


func _make_mate_row(mate: Dictionary) -> Control:
	var id: String = mate["id"]
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	var mname: String = str(mate.get("name", ""))
	name_lbl.text = ("%s %s" % [mate["type"], mname]).strip_edges()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)
	var rm := UIIcons.button("delete", "", "Delete this mate")
	rm.pressed.connect(_remove_mate.bind(id))
	row.add_child(rm)
	return row


## Joints read out their one free value; the value itself is driven by dragging
## the part in the viewport, not by a spinbox in here.
func _make_joint_row(joint: Dictionary) -> Control:
	var id: String = str(joint.get("id", ""))
	var row := HBoxContainer.new()
	row.name = "JointRow"
	row.set_meta("joint_id", id)
	var lbl := Label.new()
	var unit: String = str(joint.get("unit", "mm"))
	var value: float = float(joint.get("value", 0.0))
	var shown: float = rad_to_deg(value) if unit == "deg" else value
	lbl.text = "%s  %.1f %s" % [str(joint.get("type", "joint")), shown, unit]
	lbl.tooltip_text = "Drag the part in the viewport to drive this joint"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var rm := UIIcons.button("delete", "", "Delete this joint")
	rm.pressed.connect(_remove_joint.bind(id))
	row.add_child(rm)
	return row


func _place_instance() -> void:
	var body := view.selected_body
	if body == "":
		status.emit("Select a body to instance")
		return
	var offset := Vector3(30, 0, 0)
	var iname: String = view.doc.body_name(body) + " (inst)"
	var iid: String = view.doc.add_instance(body, offset, Vector3(0, 0, 1), 0.0, iname)
	if iid != "":
		view.refresh()
		refresh_lists()
		status.emit("Placed instance at (%.0f, %.0f, %.0f)" % [offset.x, offset.y, offset.z])
	else:
		status.emit("Instance failed")


## One joint definition, many bolts: the copies ride the seed's axis.
func _pattern_instance() -> void:
	var seed := view.selected_instance
	if seed == "":
		var insts: Array = view.doc.instance_list()
		if insts.size() == 1:
			seed = str(insts[0].get("id", ""))
	if seed == "":
		status.emit("Select a component instance to pattern")
		return
	var count := int(_offset_spin.value) if _offset_spin.value >= 2.0 else 8
	var made: PackedStringArray = view.doc.pattern_instance(seed, count, TAU)
	if made.is_empty():
		status.emit("Pattern failed — needs an instance and count of two or more")
		return
	view.refresh()
	refresh_lists()
	status.emit("Patterned %d more around the joint axis" % made.size())


func _insert_components() -> void:
	# Prefer the main composition root's file dialog (Insert > Components…).
	var main := _find_main()
	if main != null and main.has_method("_on_insert_menu"):
		main._on_insert_menu(10)
		return
	status.emit("Insert Components unavailable")


func _find_main() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("insert_components_from"):
			return n
		n = n.get_parent()
	return null


func _toggle_fixed(id: String, make_fixed: bool) -> void:
	if view.doc.set_instance_fixed(id, make_fixed):
		view.refresh()
		refresh_lists()
		status.emit(("Fixed " if make_fixed else "Floated ") + id.substr(0, 8))
	else:
		status.emit("Fix/Float failed")


func _remove_instance(id: String) -> void:
	if view.doc.remove_instance(id):
		view.refresh()
		refresh_lists()
		status.emit("Instance removed")
	else:
		status.emit("Remove instance failed")


func _arm_mate() -> void:
	_mate_armed = true
	_mate_face_a = ""
	view.mate_anchor_face = ""
	refresh_lists()
	status.emit("Mate: click ground face, then instance face")


func _on_selection_changed(_body: String, face: String) -> void:
	if not _mate_armed:
		refresh_lists()  # selection decides whether "Place instance" is reachable
		return
	if face == "":
		return
	if _mate_face_a == "":
		_mate_face_a = face
		# Keep the anchor face tinted green while waiting for the second pick.
		view.mate_anchor_face = face
		status.emit("Mate: click face on an instanced body (anchor shown green)")
		return
	_resolve_mate_b(view.selected_body, face)


func _resolve_mate_b(body: String, face_b: String) -> void:
	var inst_b := _instance_for_source(body)
	if inst_b == "":
		status.emit("Pick a face on an instanced body")
		return
	var mtype: String = _type_option.get_item_text(_type_option.selected)
	var is_joint: bool = mtype in JOINT_TYPES
	var mid: String
	if is_joint:
		mid = view.doc.add_joint(mtype, "", _mate_face_a, inst_b, face_b, "")
	else:
		mid = view.doc.add_mate(
			mtype, "", _mate_face_a, inst_b, face_b, _offset_spin.value, false, "")
	_mate_armed = false
	_mate_face_a = ""
	view.mate_anchor_face = ""
	if mid == "":
		_mate_error = "%s rejected — %s needs matching face types" % \
				["Joint" if is_joint else "Mate", mtype]
		refresh_lists()
		status.emit("Mate failed")
		return
	var solved: bool = view.doc.solve_mates()
	_mate_error = "" if solved else "Solve failed — check mate faces/offsets"
	view.refresh()
	refresh_lists()
	if is_joint:
		status.emit("%s joint added — drag the part to drive it" % mtype)
	else:
		status.emit("Mate added" if solved else "Mate added — solve FAILED")


func _instance_for_source(body: String) -> String:
	if body == "":
		return ""
	var matches: Array[String] = []
	for inst in view.doc.instance_list():
		if inst["source_body"] == body:
			matches.append(inst["id"])
	if matches.size() == 1:
		return matches[0]
	return ""


func _remove_mate(id: String) -> void:
	if view.doc.remove_mate(id):
		view.refresh()
		refresh_lists()
		status.emit("Mate removed")
	else:
		status.emit("Remove mate failed")


func _solve_mates() -> void:
	var ok: bool = view.doc.solve_mates()
	var posed: int = view.doc.solve_joints()
	_mate_error = "" if ok else "Solve failed — check mate faces/offsets"
	view.refresh()
	refresh_lists()
	if not ok:
		status.emit("Solve mates failed")
	elif posed > 0:
		status.emit("Mates solved, %d joint(s) posed" % posed)
	else:
		status.emit("Mates solved")


func _remove_joint(id: String) -> void:
	if view.doc.remove_joint(id):
		view.refresh()
		refresh_lists()
		status.emit("Joint removed")
	else:
		status.emit("Remove joint failed")
