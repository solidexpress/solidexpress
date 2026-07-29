class_name AssemblyPanel
extends PanelContainer
## Assembly browser: component instances and mates with place / remove / solve.
## Hidden when the document has nothing assembly-related and no mate pick is armed.

signal status(text: String)
signal instance_selected(id: String)

var view: DocumentView

var _instances_list: VBoxContainer
var _mates_list: VBoxContainer
var _type_option: OptionButton
var _offset_spin: SpinBox
var _refreshing := false

## Armed two-click mate flow: face A (ground or instance), then face B on an instance.
var _mate_armed := false
var _mate_face_a := ""
var _mate_instance_a := ""  # "" = grounded body face
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

	vbox.add_child(HSeparator.new())

	var mate_hdr := Label.new()
	mate_hdr.text = "Mates"
	mate_hdr.add_theme_font_size_override("font_size", 11)
	vbox.add_child(mate_hdr)
	_mates_list = VBoxContainer.new()
	vbox.add_child(_mates_list)

	_type_option = OptionButton.new()
	_type_option.tooltip_text = "Mate type: plane-to-plane, axis-to-axis, or fixed"
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in ["plane_coincident", "concentric", "fixed"]:
		_type_option.add_item(t)
	vbox.add_child(_type_option)

	_offset_spin = _labeled_spin(vbox, "Offset", -1000.0, 1000.0, 0.5, 0.0)
	_op_button(vbox, "Add mate", _arm_mate, "mate",
		"Add a mate: click face A (ground or instance), then a face on the instance to move")
	_op_button(vbox, "Solve mates", _solve_mates, "solve",
		"Re-apply all mates in order, moving instances into position")

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

	visible = not instances.is_empty() or not mates.is_empty() or _mate_armed
	_refreshing = false


func _make_instance_row(inst: Dictionary) -> Control:
	var id: String = inst["id"]
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = _truncate(str(inst.get("name", id)))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)
	var sel := UIIcons.button("select", "", "Highlight this instance in the viewport")
	sel.pressed.connect(func() -> void: instance_selected.emit(id))
	row.add_child(sel)
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
	_mate_instance_a = ""
	view.mate_anchor_face = ""
	refresh_lists()
	status.emit("Mate: click face A (ground or instance), then face B on the moving instance")


func _on_selection_changed(_body: String, face: String) -> void:
	if not _mate_armed:
		return
	if face == "":
		return
	if _mate_face_a == "":
		_mate_face_a = face
		# Prefer the selected instance when the face belongs to its source.
		_mate_instance_a = _instance_for_face(face)
		view.mate_anchor_face = face
		status.emit("Mate: click face on the instance to move (anchor shown green)")
		return
	_resolve_mate_b(view.selected_body, face)


func _resolve_mate_b(body: String, face_b: String) -> void:
	var inst_b := _instance_for_face(face_b)
	if inst_b == "":
		inst_b = _instance_for_source(body)
	if inst_b == "":
		status.emit("Pick a face on an instanced body")
		return
	if inst_b == _mate_instance_a and _mate_instance_a != "":
		status.emit("Pick a different instance for the moving side")
		return
	var mtype: String = _type_option.get_item_text(_type_option.selected)
	var mid: String = view.doc.add_mate(
		mtype, _mate_instance_a, _mate_face_a, inst_b, face_b, _offset_spin.value, false, "")
	_mate_armed = false
	_mate_face_a = ""
	_mate_instance_a = ""
	view.mate_anchor_face = ""
	if mid == "":
		_mate_error = "Mate rejected — %s needs matching face types" % mtype
		refresh_lists()
		status.emit("Mate failed")
		return
	var solved: bool = view.doc.solve_mates()
	_mate_error = "" if solved else "Solve failed — check mate faces/offsets"
	view.refresh()
	refresh_lists()
	status.emit("Mate added" if solved else "Mate added — solve FAILED")


## Instance that owns `face` when exactly one instance of that source is selected
## or exists; prefers `view.selected_instance` when its source owns the face.
func _instance_for_face(face: String) -> String:
	if face == "" or view == null:
		return ""
	var owner := ""
	for body_id in view.doc.body_ids():
		for fid in view.doc.get_face_ids(body_id):
			if fid == face:
				owner = body_id
				break
		if owner != "":
			break
	if owner == "":
		return ""
	if view.selected_instance != "":
		for inst in view.doc.instance_list():
			if str(inst["id"]) == view.selected_instance \
					and str(inst["source_body"]) == owner:
				return view.selected_instance
	return _instance_for_source(owner)


func _instance_for_source(body: String) -> String:
	if body == "":
		return ""
	var matches: Array[String] = []
	for inst in view.doc.instance_list():
		if inst["source_body"] == body:
			matches.append(inst["id"])
	if matches.size() == 1:
		return matches[0]
	# Multiple instances of the same source: use the selected one if it matches.
	if view.selected_instance != "" and matches.has(view.selected_instance):
		return view.selected_instance
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
	_mate_error = "" if ok else "Solve failed — check mate faces/offsets"
	view.refresh()
	refresh_lists()
	status.emit("Mates solved" if ok else "Solve mates failed")
