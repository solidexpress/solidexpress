class_name PropertyPanel
extends PanelContainer
## Schema-driven feature property editor: typed fields (spinbox / checkbox /
## option button / expression line) mapped onto the feature's JSON params,
## with live preview on every change. OK keeps the edits; Cancel undoes them
## (each preview regen is one undo snapshot, so cancel = undo * edits).
## Params without a schema entry (arrays, entity refs) are left untouched —
## the timeline's JSON editor remains the escape hatch for those.

signal status(text: String)
signal closed

var view: DocumentView

## type -> Array of field dicts:
##   {key, label, kind: "float"|"int"|"bool"|"enum", min, max, step, options}
## Extend freely; unknown feature types simply show no fields.
const SCHEMAS := {
	"primitive": [
		{"key": "a", "label": "W", "kind": "float", "min": 0.1, "max": 10000.0, "step": 1.0},
		{"key": "b", "label": "H", "kind": "float", "min": 0.0, "max": 10000.0, "step": 1.0},
		{"key": "c", "label": "D", "kind": "float", "min": 0.0, "max": 10000.0, "step": 1.0},
	],
	"extrude": [
		{"key": "distance", "label": "Distance", "kind": "float", "min": 0.01, "max": 10000.0, "step": 1.0},
		{"key": "end", "label": "End", "kind": "enum",
			"options": ["blind", "through_all", "to_face", "to_next", "symmetric"]},
		{"key": "symmetric", "label": "Symmetric", "kind": "bool"},
		{"key": "op", "label": "Result", "kind": "enum", "options": ["new", "fuse", "cut"]},
		{"key": "thin_thickness", "label": "Thin wall", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
	],
	"revolve": [
		{"key": "angle", "label": "Angle (°)", "kind": "float", "min": 0.1, "max": 360.0, "step": 5.0,
			"ui_unit": "deg_from_rad"},
		{"key": "op", "label": "Result", "kind": "enum", "options": ["new", "fuse", "cut"]},
	],
	"fillet": [
		{"key": "radius", "label": "Radius", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.5},
		{"key": "radius2", "label": "Radius 2", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
	],
	"direct_edit": [
		{"key": "kind", "label": "Kind", "kind": "enum",
			"options": ["push_pull", "move_face", "offset_face", "delete_face"]},
		{"key": "distance", "label": "Distance", "kind": "float", "min": -10000.0, "max": 10000.0, "step": 0.5},
	],
	"chamfer": [
		{"key": "distance", "label": "Distance", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.5},
	],
	"hole": [
		{"key": "type", "label": "Type", "kind": "enum", "options": ["simple", "counterbore", "countersink"]},
		{"key": "diameter", "label": "Diameter", "kind": "float", "min": 0.1, "max": 1000.0, "step": 0.5},
		{"key": "depth", "label": "Depth (0=thru)", "kind": "float", "min": 0.0, "max": 10000.0, "step": 1.0},
		{"key": "cb_diameter", "label": "C'bore Ø", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
		{"key": "cb_depth", "label": "C'bore depth", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
		{"key": "cs_diameter", "label": "C'sink Ø", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
		{"key": "cs_angle_deg", "label": "C'sink angle", "kind": "float", "min": 10.0, "max": 170.0, "step": 5.0},
		# positions: [[x,y,z],...] — Hole Wizard multi-point; edit via timeline Params JSON.
	],
	"shell": [
		{"key": "thickness", "label": "Thickness", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.5},
	],
	"draft": [
		{"key": "angle_deg", "label": "Angle (°)", "kind": "float", "min": 0.1, "max": 45.0, "step": 0.5},
	],
	"offset": [
		{"key": "offset", "label": "Offset", "kind": "float", "min": -1000.0, "max": 1000.0, "step": 0.5},
	],
	"linear_pattern": [
		{"key": "spacing", "label": "Spacing", "kind": "float", "min": 0.01, "max": 10000.0, "step": 1.0},
		{"key": "count", "label": "Count", "kind": "int", "min": 2, "max": 200, "step": 1},
	],
	"circular_pattern": [
		{"key": "count", "label": "Count", "kind": "int", "min": 2, "max": 200, "step": 1},
		{"key": "total_angle", "label": "Total angle (°)", "kind": "float", "min": 0.1, "max": 360.0,
			"step": 5.0, "ui_unit": "deg_from_rad"},
	],
	"helix_sweep": [
		{"key": "profile_radius", "label": "Profile r", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.5},
		{"key": "radius", "label": "Helix r", "kind": "float", "min": 0.01, "max": 10000.0, "step": 1.0},
		{"key": "pitch", "label": "Pitch", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.5},
		{"key": "turns", "label": "Turns", "kind": "float", "min": 0.1, "max": 1000.0, "step": 0.5},
		{"key": "left_handed", "label": "Left-handed", "kind": "bool"},
	],
	"thread": [
		{"key": "major_radius", "label": "Major r", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.25},
		{"key": "pitch", "label": "Pitch", "kind": "float", "min": 0.01, "max": 100.0, "step": 0.25},
		{"key": "turns", "label": "Turns", "kind": "float", "min": 0.1, "max": 1000.0, "step": 0.5},
		{"key": "depth", "label": "Depth", "kind": "float", "min": 0.01, "max": 100.0, "step": 0.1},
		{"key": "profile_angle_deg", "label": "Profile angle", "kind": "float", "min": 30.0, "max": 90.0, "step": 5.0},
	],
	"import_step": [
		{"key": "scale", "label": "Scale", "kind": "float", "min": 0.001, "max": 1000.0, "step": 0.1},
	],
	"import_stl": [
		{"key": "scale", "label": "Scale", "kind": "float", "min": 0.001, "max": 1000.0, "step": 0.1},
	],
	"loft": [
		{"key": "ruled", "label": "Ruled", "kind": "bool"},
	],
	"path": [
		{"key": "mode", "label": "Mode", "kind": "enum",
			"options": ["join_endpoints", "bridge_spline", "composite"]},
	],
	"sweep": [
		{"key": "op", "label": "Result", "kind": "enum", "options": ["new", "fuse", "cut"]},
		{"key": "thin_thickness", "label": "Thin wall", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
	],
	"boolean": [
		{"key": "op", "label": "Operation", "kind": "enum", "options": ["fuse", "cut", "common"]},
	],
	"rib": [
		{"key": "thickness", "label": "Thickness", "kind": "float", "min": 0.1, "max": 1000.0, "step": 0.5},
		{"key": "height", "label": "Height", "kind": "float", "min": 0.1, "max": 10000.0, "step": 1.0},
	],
	"flange": [
		{"key": "length", "label": "Length", "kind": "float", "min": 0.1, "max": 10000.0, "step": 1.0},
		{"key": "thickness", "label": "Thickness", "kind": "float", "min": 0.1, "max": 50.0, "step": 0.1},
		{"key": "k_factor", "label": "K-factor", "kind": "float", "min": 0.1, "max": 1.0, "step": 0.01},
		{"key": "radius", "label": "Bend R", "kind": "float", "min": 0.1, "max": 100.0, "step": 0.1},
	],
	"frame_member": [
		{"key": "profile_w", "label": "Profile W", "kind": "float", "min": 1.0, "max": 500.0, "step": 1.0},
		{"key": "profile_h", "label": "Profile H", "kind": "float", "min": 1.0, "max": 500.0, "step": 1.0},
	],
}

var _fid := ""
var _params := {}
var _original_json := ""
var _edits := 0
var _fields: VBoxContainer
var _title: Label
var _building := false


func _ready() -> void:
	visible = false
	var vbox := VBoxContainer.new()
	add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_fields = VBoxContainer.new()
	vbox.add_child(_fields)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	var ok := UIIcons.button("ok", "OK", "Keep these parameter changes")
	ok.pressed.connect(commit)
	buttons.add_child(ok)
	var cancel := UIIcons.button("cancel", "Cancel", "Undo all changes made in this panel")
	cancel.pressed.connect(cancel_edits)
	buttons.add_child(cancel)


## True when the feature type has at least one editable field.
static func has_schema(type: String) -> bool:
	return SCHEMAS.has(type)


func open(fid: String) -> bool:
	for f in view.doc.graph_features():
		if f["id"] != fid:
			continue
		var type: String = f["type"]
		if not SCHEMAS.has(type):
			return false
		_fid = fid
		_original_json = f["params"]
		_params = JSON.parse_string(f["params"])
		if _params == null:
			return false
		_edits = 0
		_title.text = "%s — %s" % [f["name"], type]
		_build_fields(type)
		visible = true
		return true
	return false


func _build_fields(type: String) -> void:
	_building = true
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	for field in SCHEMAS[type]:
		var key: String = field["key"]
		if not _params.has(key):
			continue
		var value = _params[key]
		# Expression-driven params ("=w*2") edit as text to keep the equation.
		if value is String and value.begins_with("="):
			_add_expression_row(field, value)
			continue
		match field["kind"]:
			"float", "int":
				_add_spin_row(field, value)
			"bool":
				_add_check_row(field, value)
			"enum":
				_add_enum_row(field, value)
	if type == "hole" and _params.has("positions") and _params["positions"] is Array:
		var note := Label.new()
		var n: int = (_params["positions"] as Array).size()
		note.text = "positions: %d point(s) — edit array in Params JSON" % n
		note.add_theme_font_size_override("font_size", 11)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fields.add_child(note)
	_building = false


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(96, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	return row


func _add_spin_row(field: Dictionary, value) -> void:
	var row := _row(field["label"])
	var spin := SpinBox.new()
	spin.min_value = field.get("min", -1e9)
	spin.max_value = field.get("max", 1e9)
	# Fine step so typed values are not snapped (Range snaps to min + k*step);
	# the arrows move by the schema's ergonomic step instead.
	spin.step = 1.0 if field["kind"] == "int" else 0.001
	spin.custom_arrow_step = field.get("step", 1.0)
	spin.rounded = field["kind"] == "int"
	var display := float(value)
	# Kernel stores some angles in radians; show degrees in the UI.
	if field.get("ui_unit", "") == "deg_from_rad":
		display = rad_to_deg(display)
	spin.value = display
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(v: float) -> void:
		var store = int(v) if field["kind"] == "int" else v
		if field.get("ui_unit", "") == "deg_from_rad":
			store = deg_to_rad(float(v))
		_set_param(field["key"], store))
	row.add_child(spin)


func _add_check_row(field: Dictionary, value) -> void:
	var row := _row(field["label"])
	var cb := CheckBox.new()
	cb.button_pressed = bool(value)
	cb.toggled.connect(func(on: bool) -> void: _set_param(field["key"], on))
	row.add_child(cb)


func _add_enum_row(field: Dictionary, value) -> void:
	var row := _row(field["label"])
	var opt := OptionButton.new()
	var options: Array = field["options"]
	for o in options:
		opt.add_item(o)
	var idx := options.find(str(value))
	opt.selected = idx if idx >= 0 else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i: int) -> void: _set_param(field["key"], options[i]))
	row.add_child(opt)


func _add_expression_row(field: Dictionary, value: String) -> void:
	var row := _row(field["label"] + " =")
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.tooltip_text = "Expression; keep the leading = to reference variables"
	edit.text_submitted.connect(func(t: String) -> void: _set_param(field["key"], t))
	row.add_child(edit)


## Live preview: write the param and regenerate immediately. Each write is one
## undoable graph snapshot; cancel_edits rolls them all back.
func _set_param(key: String, value) -> void:
	if _building or _fid == "":
		return
	_params[key] = value
	if view.doc.graph_set_params(_fid, JSON.stringify(_params)):
		_edits += 1
		view.graph_changed()
		status.emit("Preview: %s = %s" % [key, str(value)])
	else:
		status.emit("Value rejected (regenerate failed) — reverting")
		_params = JSON.parse_string(_original_json) if _edits == 0 else _params


func commit() -> void:
	if _edits > 0:
		status.emit("Feature updated (%d change(s))" % _edits)
	_close()


func cancel_edits() -> void:
	for i in range(_edits):
		view.undo()
	if _edits > 0:
		status.emit("Edits cancelled")
	_close()


func _close() -> void:
	_fid = ""
	_edits = 0
	visible = false
	closed.emit()
