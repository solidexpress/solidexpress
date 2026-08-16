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


## `length_mm` is the real-world length the bar represents; `px_per_mm` maps
## it onto the viewport at the orbit pivot.
func set_mm_scale(length_mm: float, px_per_mm: float) -> void:
	var ppm := maxf(px_per_mm, 1e-9)
	var mm := maxf(length_mm, 1e-9)
	# Prefer the grid major cell; if that is awkwardly short/long on screen,
	# step by decades until the bar lands in BAR_MIN…BAR_MAX.
	var px := mm * ppm
	while px > BAR_MAX_PX and mm > WorldGizmos.GRID_STEP_FINEST:
		mm *= 0.1
		px = mm * ppm
	while px < BAR_MIN_PX and mm < WorldGizmos.GRID_HALF_MAX:
		mm *= 10.0
		px = mm * ppm
	# Soft clamp so a pathological zoom still draws something readable.
	px = clampf(px, BAR_MIN_PX * 0.5, BAR_MAX_PX)
	_length_mm = mm
	_px_per_mm = ppm
	_label = _format_mm(mm)
	# Grow the control to fit the bar + label.
	var need_w := PAD.x * 2.0 + px + 8.0 + _label_width()
	offset_right = offset_left + maxf(need_w, 120.0)
	queue_redraw()


func _format_mm(mm: float) -> String:
	if mm >= 100.0:
		return "%.0f mm" % mm
	if mm >= 1.0:
		# Drop trailing .0 for whole millimetres.
		if is_equal_approx(mm, roundf(mm)):
			return "%.0f mm" % mm
		return "%.1f mm" % mm
	if mm >= 0.1:
		return "%.1f mm" % mm
	return "%.2f mm" % mm


func _label_width() -> float:
	return get_theme_default_font().get_string_size(
		_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiScale.body()).x


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
