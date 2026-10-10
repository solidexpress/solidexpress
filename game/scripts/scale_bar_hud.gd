class_name ScaleBarHud
extends Control
## Bottom-left millimetre scale: a short tick bar labeled with the current
## grid major cell (1 mm, 0.1 mm, 10 mm, …). Tracks OrbitCamera zoom via
## WorldGizmos LOD.

const BAR_MIN_PX := 36.0
const BAR_MAX_PX := 140.0
const LINE_W := 1.5
const TICK_H := 6.0
const PAD := Vector2(12.0, 10.0)
const COLOR_BAR := Color(0.82, 0.84, 0.88, 0.85)
const COLOR_LABEL := Color(0.78, 0.80, 0.84, 0.92)

var _length_mm := 1.0
var _px_per_mm := 40.0
var _label := "1 mm"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sit above the 30 px status bar inside the full-rect Interaction overlay.
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 0.0
	offset_top = -56.0
	offset_right = 180.0
	offset_bottom = -30.0
	queue_redraw()


func _draw() -> void:
	var px := clampf(_length_mm * _px_per_mm, BAR_MIN_PX * 0.5, BAR_MAX_PX)
	var y := size.y - PAD.y - 2.0
	var x0 := PAD.x
	var x1 := x0 + px
	draw_line(Vector2(x0, y), Vector2(x1, y), COLOR_BAR, LINE_W, true)
	draw_line(Vector2(x0, y - TICK_H), Vector2(x0, y + 1.0), COLOR_BAR, LINE_W, true)
	draw_line(Vector2(x1, y - TICK_H), Vector2(x1, y + 1.0), COLOR_BAR, LINE_W, true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(x1 + 8.0, y - 1.0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiScale.body(), COLOR_LABEL)
