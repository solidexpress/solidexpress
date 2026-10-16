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
		match _badge:
			"LMB", "RMB", "MMB", "Wheel":
				_draw_mouse(_badge)
			_:
				_draw_key_pill(_badge)


func _draw_key_pill(text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var fs := 15
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad := Vector2(8, 5)
	var box := Rect2(Vector2(DIAM * 0.62, 4.0), tw + pad * 2.0)
	draw_rect(box, Color(0.08, 0.09, 0.12, 0.88), true, -1.0, true)
	draw_rect(box, Color(1.0, 0.88, 0.12, 0.85), false, 1.5, true)
	draw_string(font, box.position + Vector2(pad.x, pad.y + fs - 3.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1))


func _draw_mouse(kind: String) -> void:
	var origin := Vector2(DIAM * 0.68, 2.0)
	var body := Rect2(origin, Vector2(26, 36))
	var outline := Color(1.0, 0.88, 0.12, 0.9)
	var fill := Color(0.08, 0.09, 0.12, 0.92)
	var lit := Color(1.0, 0.88, 0.12, 0.95)
	var dim := Color(0.32, 0.33, 0.38, 0.95)
	draw_rect(body, fill, true, -1.0, true)
	draw_rect(body, outline, false, 1.6, true)
	var lcol := lit if kind == "LMB" else dim
	var rcol := lit if kind == "RMB" else dim
	var wcol := lit if kind == "MMB" or kind == "Wheel" else dim
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(10, 12)), lcol, true, -1.0, true)
	draw_rect(Rect2(origin + Vector2(14, 2), Vector2(10, 12)), rcol, true, -1.0, true)
	draw_rect(Rect2(origin + Vector2(11, 3), Vector2(4, 10)), wcol, true, -1.0, true)
	if kind == "Wheel":
		var top := origin + Vector2(13, 1)
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(0, -5), top + Vector2(-4, 0), top + Vector2(4, 0)]), lit)
		var bot := origin + Vector2(13, 15)
		draw_colored_polygon(PackedVector2Array([
			bot + Vector2(0, 5), bot + Vector2(-4, 0), bot + Vector2(4, 0)]), lit)
	var font: Font = ThemeDB.fallback_font
	var fs := 11
	var label := kind
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, origin + Vector2((26.0 - tw.x) * 0.5, 32.0), label,
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
