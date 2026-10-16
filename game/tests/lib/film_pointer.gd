class_name FilmPointer
extends Control

## Large yellow ring pointer for UI movies; flashes white on click.

const DIAM := 72.0
const RING := 7.0

var _flash := 0.0
var _flash_tween: Tween
var _moving := false
var _badge := ""


func set_moving(v: bool) -> void:
	_moving = v
	queue_redraw()


func set_badge(text: String) -> void:
	_badge = text.strip_edges()
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(DIAM, DIAM)
	size = Vector2(DIAM, DIAM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	if _moving:
		draw_arc(center, DIAM * 0.5 + 10.0, 0, TAU, 64, Color(1.0, 0.88, 0.12, 0.28), 5.0, true)
	var ring_col := Color(1.0, 0.88, 0.12, 0.95).lerp(Color(1, 1, 1, 1), _flash)
	draw_arc(center, DIAM * 0.5 - RING * 0.5, 0, TAU, 72, ring_col, RING, true)
	draw_circle(center, 5.0, Color(1, 1, 1, 0.95))
	if not _badge.is_empty():
		var font: Font = ThemeDB.fallback_font
		var fs := 15
		var tw := font.get_string_size(_badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pad := Vector2(8, 5)
		var box := Rect2(Vector2(DIAM * 0.62, 4.0), tw + pad * 2.0)
		draw_rect(box, Color(0.08, 0.09, 0.12, 0.88), true, -1.0, true)
		draw_rect(box, Color(1.0, 0.88, 0.12, 0.85), false, 1.5, true)
		draw_string(font, box.position + Vector2(pad.x, pad.y + fs - 3.0), _badge,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1))


func play_click_flash(sec: float = 0.12) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var dur := maxf(sec, 0.06)
	var up := minf(0.05, dur * 0.4)
	var down := maxf(0.04, dur - up)
	_flash_tween = create_tween()
	_flash_tween.tween_method(set_flash, 0.0, 1.0, up)
	_flash_tween.tween_method(set_flash, 1.0, 0.0, down)
	await _flash_tween.finished


func set_flash(v: float) -> void:
	_flash = v
	queue_redraw()
