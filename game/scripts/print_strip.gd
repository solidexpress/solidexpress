class_name PrintStrip
extends PanelContainer
## Form-mode print-prep chips (Analyze / Orient). Not a dock.

signal analyze_requested
signal orient_requested

var _digest: Label
var _analyze: Button
var _orient: Button
var _thickness_toggle: CheckBox
var _overhang_toggle: CheckBox
var _bed_toggle: CheckBox

# Wired in by main.gd
var view: DocumentView
var bed_ghost: Node3D


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_analyze = UIIcons.button("measure", "Analyze", "Print check — min wall, overhang, bed fit")
	_analyze.name = "PrintAnalyze"
	_analyze.pressed.connect(func() -> void: analyze_requested.emit())
	row.add_child(_analyze)
	_orient = UIIcons.button("revolve", "Orient", "Lay the part on the bed — least overhang, then height")
	_orient.name = "PrintOrient"
	_orient.pressed.connect(func() -> void: orient_requested.emit())
	row.add_child(_orient)
	# See-the-print toggles (Wave 6.3)
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
	_bed_toggle.tooltip_text = "Show the 3D printer bed (default 220×220)"
	_bed_toggle.toggled.connect(_on_bed_toggled)
	row.add_child(_bed_toggle)
	_digest = Label.new()
	_digest.name = "PrintDigest"
	_digest.text = "Form — print prep"
	_digest.add_theme_font_size_override("font_size", 11)
	row.add_child(_digest)


func set_digest(text: String) -> void:
	if _digest:
		_digest.text = text if text != "" else "Form — print prep"


func _on_thickness_toggled(on: bool) -> void:
	if view != null:
		if view.has_method("set_thickness_paint"):
			view.call("set_thickness_paint", on)


func _on_overhang_toggled(on: bool) -> void:
	if view != null:
		if view.has_method("set_overhang_paint"):
			view.call("set_overhang_paint", on)


func _on_bed_toggled(on: bool) -> void:
	if bed_ghost != null:
		bed_ghost.visible = on
