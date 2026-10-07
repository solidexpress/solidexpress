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
		{"key": "to_face", "label": "Face", "kind": "face_pick"},
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
		{"key": "type", "label": "Type", "kind": "enum", "options": ["simple", "counterbore", "countersink", "hex"]},
		{"key": "fit", "label": "Fit", "kind": "enum", "options": ["normal", "close", "loose"],
			"optional": true},
		{"key": "diameter", "label": "Diameter", "kind": "float", "min": 0.1, "max": 1000.0, "step": 0.5},
		{"key": "depth", "label": "Depth (0=thru)", "kind": "float", "min": 0.0, "max": 10000.0, "step": 1.0},
		{"key": "cb_diameter", "label": "C'bore Ø", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
		{"key": "cb_depth", "label": "C'bore depth", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
		{"key": "cs_diameter", "label": "C'sink Ø", "kind": "float", "min": 0.0, "max": 1000.0, "step": 0.5},
		{"key": "cs_angle_deg", "label": "C'sink angle", "kind": "float", "min": 10.0, "max": 170.0, "step": 5.0},
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
		{"key": "designation", "label": "Standard", "kind": "thread_standard", "optional": true},
		{"key": "major_radius", "label": "Major r", "kind": "float", "min": 0.01, "max": 1000.0, "step": 0.25},
		{"key": "pitch", "label": "Pitch", "kind": "float", "min": 0.01, "max": 100.0, "step": 0.25},
		{"key": "turns", "label": "Turns", "kind": "float", "min": 0.1, "max": 1000.0, "step": 0.5},
		{"key": "depth", "label": "Depth", "kind": "float", "min": 0.01, "max": 100.0, "step": 0.1},
		{"key": "profile_angle_deg", "label": "Profile angle", "kind": "float", "min": 30.0, "max": 90.0, "step": 5.0},
	],
	"datum": [
		{"key": "kind", "label": "Kind", "kind": "enum", "options": ["plane", "axis", "point"]},
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
var _type := ""
var _params := {}
var _original_json := ""
var _edits := 0
var _fields: VBoxContainer
var _title: Label
var _building := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.20, 1.0)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_fields = VBoxContainer.new()
	vbox.add_child(_fields)
	var buttons := HBoxContainer.new()
	buttons.name = "PropertyButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	# Live preview already wrote changes — Esc cancels; deselect keeps.
	# No OK button (redundant with deselect). Cancel stays for discoverability.
	var cancel := UIIcons.button("cancel", "Cancel", "Undo all changes (Esc)")
	cancel.pressed.connect(cancel_edits)
	buttons.add_child(cancel)
	var hint := Label.new()
	hint.text = "Deselect keeps · Esc cancels"
	hint.add_theme_font_size_override("font_size", UiScale.caption())
	hint.modulate = Color(0.7, 0.7, 0.75)
	buttons.add_child(hint)


## True when the feature type has at least one editable field.
static func has_schema(type: String) -> bool:
	return SCHEMAS.has(type)


func open(fid: String) -> bool:
	# A second click on the same row (double-click release) must not rebuild
	# the spins — that would drop the distance field's focus and selection.
	if visible and _fid == fid:
		return true
	for f in view.doc.graph_features():
		if f["id"] != fid:
			continue
		var type: String = f["type"]
		if not SCHEMAS.has(type):
			return false
		_fid = fid
		_type = type
		_original_json = f["params"]
		_params = JSON.parse_string(f["params"])
		if _params == null:
			return false
		_edits = 0
		_title.text = "%s — %s" % [f["name"], type]
		_build_fields(type)
		visible = true
		if _params.has("distance"):
			focus_schema_key("distance")
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if ke.pressed and ke.keycode == KEY_ESCAPE:
		cancel_edits()
		get_viewport().set_input_as_handled()


func _build_fields(type: String) -> void:
	_building = true
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	for field in SCHEMAS[type]:
		if str(field.get("kind", "")) == "face_pick":
			if str(_params.get("end", "")) == "to_face":
				_add_face_pick_row(field)
			continue
		var key: String = field["key"]
		var optional: bool = bool(field.get("optional", false))
		if not _params.has(key) and not optional and field["kind"] != "thread_standard":
			continue
		var value = _params[key] if _params.has(key) else null
		# Expression-driven params ("=w*2") edit as text to keep the equation.
		if value is String and value.begins_with("="):
			_add_expression_row(field, value)
			continue
		match field["kind"]:
			"float", "int":
				if value == null:
					continue
				_add_spin_row(field, value)
			"bool":
				if value == null:
					continue
				_add_check_row(field, value)
			"enum":
				if value == null and optional:
					value = field["options"][0]
					_params[key] = value
				if value == null:
					continue
				_add_enum_row(field, value)
			"thread_standard":
				_add_thread_standard_row(field)
	if type == "hole" and _params.has("positions") and _params["positions"] is Array:
		var note := Label.new()
		var n: int = (_params["positions"] as Array).size()
		note.text = "positions: %d point(s) — Place more… via Hole Wizard" % n
		note.add_theme_font_size_override("font_size", UiScale.body())
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fields.add_child(note)
	_building = false


func _add_thread_standard_row(field: Dictionary) -> void:
	var row := _row(field["label"])
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.fit_to_longest_item = false
	opt.add_item("(custom)")
	var table: Array = []
	if view != null and view.doc != null and view.doc.has_method("thread_table"):
		table = view.doc.thread_table()
	var current := str(_params.get("designation", ""))
	var select_i := 0
	for i in range(table.size()):
		var d: Dictionary = table[i]
		var des := str(d.get("designation", ""))
		opt.add_item(des)
		opt.set_item_metadata(opt.item_count - 1, d)
		if des == current:
			select_i = opt.item_count - 1
	opt.select(select_i)
	opt.item_selected.connect(func(i: int) -> void:
		if i <= 0:
			return
		var d: Dictionary = opt.get_item_metadata(i)
		_params["designation"] = str(d.get("designation", ""))
		var major := float(d.get("major_diameter_mm", 0.0)) * 0.5
		var pitch := float(d.get("pitch_mm", 0.0))
		_set_param("major_radius", major)
		_set_param("pitch", pitch)
		if _params.has("depth"):
			_set_param("depth", pitch * 0.5)
		# Rebuild so spins show the new values.
		_build_fields("thread")
		status.emit("Thread standard %s" % str(d.get("designation", "")))
	)
	row.add_child(opt)


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(96, 0)
	lbl.add_theme_font_size_override("font_size", UiScale.body())
	row.add_child(lbl)
	return row


func _add_spin_row(field: Dictionary, value) -> void:
	var row := _row(field["label"])
	var spin := SpinBox.new()
	var key: String = field["key"]
	spin.name = "Param_%s" % key
	spin.set_meta("schema_key", key)
	var display := float(value)
	# Kernel stores some angles in radians; show degrees in the UI.
	if field.get("ui_unit", "") == "deg_from_rad":
		display = rad_to_deg(display)
	# Fine step so typed values are not snapped (Range snaps to min + k*step);
	# the arrows move by the schema's ergonomic step instead.
	SxUi.configure_spin(
		spin,
		float(field.get("min", -1e9)),
		float(field.get("max", 1e9)),
		float(field.get("step", 1.0)),
		display,
		field["kind"] == "int")
	spin.value_changed.connect(func(v: float) -> void:
		if key == "distance" and not _distance_line_parses(spin):
			return
		var store = int(v) if field["kind"] == "int" else v
		if field.get("ui_unit", "") == "deg_from_rad":
			store = deg_to_rad(float(v))
		_set_param(key, store))
	var edit := spin.get_line_edit()
	if edit != null and key == "distance":
		# Every click, including a second click on an already-focused field,
		# reselects the digits so typing 14 replaces 10 instead of appending.
		edit.gui_input.connect(_on_distance_edit_gui_input.bind(spin))
		edit.text_submitted.connect(_on_distance_submitted.bind(spin))
		edit.focus_exited.connect(_on_distance_focus_exited.bind(spin))
	row.add_child(spin)


## Focus the spin whose schema key is `key` (extrude Distance, not W/H/D).
func focus_schema_key(key: String) -> void:
	var spin := _spin_for_key(key)
	if spin == null:
		return
	var edit := spin.get_line_edit()
	if edit != null:
		edit.grab_focus()
		_queue_select_all(edit)
	else:
		spin.grab_focus()


func _spin_for_key(key: String) -> SpinBox:
	if _fields == null:
		return null
	var named := _fields.find_child("Param_%s" % key, true, false)
	if named is SpinBox:
		return named as SpinBox
	for row in _fields.get_children():
		for child in row.get_children():
			if child is SpinBox and str(child.get_meta("schema_key", "")) == key:
				return child as SpinBox
	return null


func _on_distance_edit_gui_input(event: InputEvent, spin: SpinBox) -> void:
	if spin == null or not is_instance_valid(spin):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var edit := spin.get_line_edit()
			if edit != null:
				_queue_select_all(edit)


func _queue_select_all(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	# After the caret click, then once more next frame so the caret cannot win.
	edit.call_deferred("select_all")
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.process_frame.connect(func() -> void:
		if is_instance_valid(edit):
			edit.call_deferred("select_all")
	, CONNECT_ONE_SHOT)


func _on_distance_submitted(_raw: String, spin: SpinBox) -> void:
	_commit_distance_line(spin)


func _on_distance_focus_exited(spin: SpinBox) -> void:
	_commit_distance_line(spin)


## Parse the Distance LineEdit and write `distance` before the spin can be freed.
## Partial junk that is not a single float does not write.
func _commit_distance_line(spin: SpinBox) -> void:
	if _building or _fid == "" or spin == null or not is_instance_valid(spin):
		return
	var edit := spin.get_line_edit()
	if edit == null:
		return
	var parsed: Variant = _parse_spin_text(spin, edit.text)
	if parsed == null:
		var keep := float(_params.get("distance", spin.value))
		_restore_distance_value.call_deferred(spin, keep)
		return
	_set_param("distance", float(parsed))


func _restore_distance_value(spin: SpinBox, keep: float) -> void:
	if spin == null or not is_instance_valid(spin):
		return
	if is_equal_approx(spin.value, keep):
		return
	spin.value = keep


func _distance_line_parses(spin: SpinBox) -> bool:
	if spin == null or not is_instance_valid(spin):
		return false
	var edit := spin.get_line_edit()
	if edit == null:
		return false
	return _parse_spin_text(spin, edit.text) != null


func _parse_spin_text(spin: SpinBox, raw: String) -> Variant:
	var text := raw.strip_edges()
	if text.is_empty() or spin == null:
		return null
	var prefix := str(spin.prefix)
	var suffix := str(spin.suffix)
	if prefix != "":
		var spaced := prefix + " "
		if text.begins_with(spaced):
			text = text.substr(spaced.length())
		elif text.begins_with(prefix):
			text = text.substr(prefix.length())
	if suffix != "":
		var spaced := " " + suffix
		if text.ends_with(spaced):
			text = text.substr(0, text.length() - spaced.length())
		elif text.ends_with(suffix):
			text = text.substr(0, text.length() - suffix.length())
	text = text.strip_edges().replace(",", ".")
	if not text.is_valid_float():
		return null
	var v := float(text)
	if is_nan(v) or is_inf(v):
		return null
	return v


func _flush_distance_text() -> void:
	_commit_distance_line(_spin_for_key("distance"))


## Shown only while End is Up To Surface. The button arms the sketch chrome's
## one-shot face pick (WP1 owns arm_face_pick).
func _add_face_pick_row(field: Dictionary) -> void:
	var row := _row(field["label"])
	var btn := Button.new()
	btn.name = "PickFace"
	btn.text = "Pick face"
	btn.tooltip_text = "Pick the Up To Surface face again"
	btn.pressed.connect(_arm_face_pick)
	row.add_child(btn)


func _arm_face_pick() -> void:
	var tree := get_tree()
	var chrome: Node = tree.root.find_child("SketchContextChrome", true, false) if tree != null else null
	if chrome == null or not chrome.has_method("arm_face_pick"):
		push_error("SketchContextChrome.arm_face_pick is missing")
		status.emit("Face pick unavailable")
		return
	chrome.call("arm_face_pick")


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
	edit.text_submitted.connect(func(t: String) -> void:
		var s := t.strip_edges()
		# Mechanic often types jaw_af+clearance without '='; accept it.
		if s != "" and not s.begins_with("=") and _looks_like_expr(s):
			s = "=" + s
		_set_param(field["key"], s))
	row.add_child(edit)


func _looks_like_expr(s: String) -> bool:
	# Letters / operators → treat as equation, not a bare number.
	for i in s.length():
		var ch := s.unicode_at(i)
		if (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 43 or ch == 42 \
				or ch == 47 or ch == 45 or ch == 40 or ch == 41:
			# Has a letter or + * / ( ) or mid-minus after start
			if ch >= 65 or ch == 43 or ch == 42 or ch == 47 or ch == 40 or ch == 41:
				return true
			if ch == 45 and i > 0:
				return true
	return false


## Live preview: write the param and regenerate immediately. Each write is one
## undoable graph snapshot; cancel_edits rolls them all back.
func _set_param(key: String, value) -> void:
	if _building or _fid == "":
		return
	if _params.has(key) and _same_param(_params[key], value):
		return
	_params[key] = value
	if view.doc.graph_set_params(_fid, JSON.stringify(_params)):
		_edits += 1
		view.graph_changed()
		var note := ""
		if view.doc.has_method("graph_warnings"):
			var warnings: PackedStringArray = view.doc.graph_warnings()
			if not warnings.is_empty():
				note = " — " + "; ".join(warnings)
		status.emit("Preview: %s = %s%s" % [key, str(value), note])
		# End = Up To Surface reveals the face row; other ends hide it.
		if key == "end" and _type != "":
			_build_fields.call_deferred(_type)
	else:
		var why := ""
		if view.doc.has_method("last_graph_error"):
			why = str(view.doc.last_graph_error())
		status.emit("Value rejected%s" % ((" — " + why) if why != "" else " (regenerate failed)"))
		_params = JSON.parse_string(_original_json) if _edits == 0 else _params


func _same_param(a, b) -> bool:
	if a is float or a is int:
		if b is float or b is int:
			return is_equal_approx(float(a), float(b))
	return a == b


func commit() -> void:
	# Click-away / File may free the spin in the same turn as focus exit.
	# Parse Distance now so Export cannot steal an uncommitted 14.
	_flush_distance_text()
	if _edits > 0:
		status.emit("Feature updated (%d change(s))" % _edits)
	_close()


func cancel_edits() -> void:
	for i in range(_edits):
		view.undo()
	if _edits > 0:
		status.emit("Edits cancelled")
	_close()


## True while the user has changed a value that Esc must roll back.
## A panel that is only showing the last feature must not steal Esc from
## an armed Fillet / Hole pick.
func has_pending_edits() -> bool:
	return _edits > 0


func dismiss_keep_preview() -> void:
	_close()


func _close() -> void:
	_fid = ""
	_type = ""
	_edits = 0
	visible = false
	closed.emit()
