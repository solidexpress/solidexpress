class_name PrintStrip
extends PanelContainer
## Form-mode print-prep chips (Analyze / Orient). Not a dock.

signal analyze_requested
signal orient_requested

var _digest: Label
var _analyze: Button
var _orient: Button


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
	_digest = Label.new()
	_digest.name = "PrintDigest"
	_digest.text = "Form — print prep"
	_digest.add_theme_font_size_override("font_size", 11)
	row.add_child(_digest)


func set_digest(text: String) -> void:
	if _digest:
		_digest.text = text if text != "" else "Form — print prep"
