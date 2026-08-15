class_name PrintStrip
extends PanelContainer
## Form-mode print-prep chips (Analyze / Orient) plus nozzle / overhang / bed
## settings. Not a dock — stays on the top chrome strip.

signal analyze_requested
signal orient_requested

var _digest: Label
var _analyze: Button
var _orient: Button
var _thickness_toggle: CheckBox
var _overhang_toggle: CheckBox
var _bed_toggle: CheckBox
var _nozzle: SpinBox
var _overhang_deg: SpinBox
var _bed_x: SpinBox
var _bed_y: SpinBox
var _syncing := false

# Wired in by main.gd
var view: DocumentView
var bed_ghost: Node3D


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_analyze = UIIcons.button("measure", "Analyze", "Print check — min wall, overhang, bed fit")
	_analyze.name = "PrintAnalyze"
	_analyze.pressed.connect(func() -> void: analyze_requested.emit())
	row.add_child(_analyze)
	_orient = UIIcons.button("revolve", "Orient", "Lay the part on the bed — least overhang, then height")
	_orient.name = "PrintOrient"
	_orient.pressed.connect(func() -> void: orient_requested.emit())
	row.add_child(_orient)
	_thickness_toggle = CheckBox.new()
	_thickness_toggle.name = "ThicknessPaint"
	_thickness_toggle.text = "Thickness"
	_thickness_toggle.tooltip_text = "Color thin faces below min wall"
	_thickness_toggle.toggled.connect(_on_thickness_toggled)
	row.add_child(_thickness_toggle)
	_overhang_toggle = CheckBox.new()
	_overhang_toggle.name = "OverhangPaint"
	_overhang_toggle.text = "Overhang"
	_overhang_toggle.tooltip_text = "Color faces steeper than overhang angle"
	_overhang_toggle.toggled.connect(_on_overhang_toggled)
	row.add_child(_overhang_toggle)
	_bed_toggle = CheckBox.new()
	_bed_toggle.name = "BedGhost"
	_bed_toggle.text = "Bed"
	_bed_toggle.tooltip_text = "Show the 3D printer bed"
	_bed_toggle.toggled.connect(_on_bed_toggled)
	row.add_child(_bed_toggle)
	_digest = Label.new()
	_digest.name = "PrintDigest"
	_digest.text = "Form — print prep"
	_digest.add_theme_font_size_override("font_size", 11)
	row.add_child(_digest)

	var params := HBoxContainer.new()
	params.name = "PrintParams"
	params.add_theme_constant_override("separation", 6)
	col.add_child(params)
	_nozzle = _mini_spin(params, "Nozzle", 0.1, 2.0, 0.05, 0.4, "mm")
	_nozzle.value_changed.connect(func(_v: float) -> void: _push_setup())
	_overhang_deg = _mini_spin(params, "Hang°", 1.0, 89.0, 1.0, 45.0, "°")
	_overhang_deg.value_changed.connect(func(_v: float) -> void: _push_setup())
	_bed_x = _mini_spin(params, "Bed X", 50.0, 1000.0, 10.0, 220.0, "mm")
	_bed_x.value_changed.connect(func(_v: float) -> void: _push_setup())
	_bed_y = _mini_spin(params, "Bed Y", 50.0, 1000.0, 10.0, 220.0, "mm")
	_bed_y.value_changed.connect(func(_v: float) -> void: _push_setup())


func _mini_spin(parent: Container, label: String, lo: float, hi: float, step: float,
		value: float, suffix: String) -> SpinBox:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	box.add_child(lbl)
	var spin := SpinBox.new()
	SxUi.configure_spin(spin, lo, hi, step, value)
	spin.suffix = suffix
	spin.custom_minimum_size = Vector2(72, 0)
	box.add_child(spin)
	return spin


func set_digest(text: String) -> void:
	if _digest:
		_digest.text = text if text != "" else "Form — print prep"


func sync_from_doc() -> void:
	if view == null or view.doc == null:
		return
	_syncing = true
	var s: Dictionary = view.doc.print_setup()
	if _nozzle:
		_nozzle.value = float(s.get("nozzle_mm", 0.4))
	if _overhang_deg:
		_overhang_deg.value = float(s.get("overhang_deg", 45.0))
	if _bed_x:
		_bed_x.value = float(s.get("bed_x", 220.0))
	if _bed_y:
		_bed_y.value = float(s.get("bed_y", 220.0))
	_syncing = false
	_apply_bed_size()


func _push_setup() -> void:
	if _syncing or view == null or view.doc == null:
		return
	if not view.doc.has_method("set_print_setup"):
		return
	var d := {
		"nozzle_mm": _nozzle.value,
		"overhang_deg": _overhang_deg.value,
		"bed_x": _bed_x.value,
		"bed_y": _bed_y.value,
	}
	view.doc.set_print_setup(d)
	_apply_bed_size()


func _apply_bed_size() -> void:
	if bed_ghost != null and bed_ghost.has_method("set_bed_size"):
		bed_ghost.call("set_bed_size", _bed_x.value, _bed_y.value)


func _on_thickness_toggled(on: bool) -> void:
	if view != null and view.has_method("set_thickness_paint"):
		view.call("set_thickness_paint", on)


func _on_overhang_toggled(on: bool) -> void:
	if view != null and view.has_method("set_overhang_paint"):
		view.call("set_overhang_paint", on)


func _on_bed_toggled(on: bool) -> void:
	if bed_ghost != null:
		bed_ghost.visible = on
		_apply_bed_size()
