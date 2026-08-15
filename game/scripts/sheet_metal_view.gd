class_name SheetMetalView
extends Control
## Sheet mode: folded | flat split of the *same* viewport. Bend table is a
## thin strip on the flat side — not a second document.

signal tool_status(text: String)

var flat_length_mm := 0.0
var k_factor := 0.44
var _tools: HBoxContainer


func _ready() -> void:
	name = "SheetMetalView"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 8
	offset_top = 48
	offset_right = -8
	offset_bottom = -8
	_tools = HBoxContainer.new()
	_tools.name = "SheetTools"
	_tools.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tools.position = Vector2(12, 8)
	_tools.add_theme_constant_override("separation", 6)
	add_child(_tools)
	for label in ["Convert", "Edge flange", "Unfold", "Flat DXF"]:
		var b := Button.new()
		b.text = label
		var name_l: String = label
		b.pressed.connect(func() -> void: _on_tool(name_l))
		_tools.add_child(b)


func show_split(on: bool, flat_mm: float = 0.0, k: float = 0.44) -> void:
	visible = on
	flat_length_mm = flat_mm
	k_factor = k
	queue_redraw()


func _on_tool(label: String) -> void:
	match label:
		"Convert":
			tool_status.emit("Sheet: Convert thin solid — select a body and use timeline ConvertSheet")
		"Edge flange":
			tool_status.emit("Sheet: Edge flange — use graph_add_flange from a selected face")
		"Unfold":
			tool_status.emit("Flat length %.1f mm (K=%.2f)" % [flat_length_mm, k_factor])
		"Flat DXF":
			tool_status.emit("Sheet: File → Export Drawing (DXF) for the flat")


func _draw() -> void:
	if not visible:
		return
	var r := Rect2(Vector2.ZERO, size)
	var mid := r.size.x * 0.5
	draw_rect(Rect2(0, 0, mid - 2, r.size.y), Color(0.12, 0.14, 0.16, 0.35))
	draw_rect(Rect2(mid + 2, 0, r.size.x - mid - 2, r.size.y), Color(0.16, 0.16, 0.14, 0.35))
	draw_line(Vector2(mid, 8), Vector2(mid, r.size.y - 8), Color(0.7, 0.72, 0.74, 0.8), 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, 22), "Folded", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.92, 0.94))
	draw_string(font, Vector2(mid + 16, 22), "Flat", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.92, 0.94))
	var strip := Rect2(mid + 8, r.size.y - 36, r.size.x - mid - 24, 24)
	draw_rect(strip, Color(0.18, 0.18, 0.16, 0.85))
	var caption := "Bend table  K=%.2f  flat=%.1f mm" % [k_factor, flat_length_mm]
	draw_string(font, strip.position + Vector2(8, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.9, 0.82))
