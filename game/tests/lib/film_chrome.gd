class_name FilmChrome
extends CanvasLayer

## On-screen closed captions + soft-subtitle cue list (WebVTT).

var fps := 60.0

var _root: Control
var _cc_panel: PanelContainer
var _cc: Label
var _badge: Label
const _FilmPointerScript = preload("res://tests/lib/film_pointer.gd")

var _pointer: Control
var _toast_panel: PanelContainer
var _toast: Label
var _move_tween: Tween

## Closed cues: { "start_frame": int, "end_frame": int, "text": String }
var cues: Array[Dictionary] = []
var _caption_text := ""
var _caption_start_frame := 0


func _ready() -> void:
	layer = 100
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_cc_panel = PanelContainer.new()
	_cc_panel.visible = false
	_cc_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cc_panel.anchor_top = 1.0
	_cc_panel.anchor_bottom = 1.0
	_cc_panel.offset_top = -96
	_cc_panel.offset_bottom = -28
	_cc_panel.offset_left = -420
	_cc_panel.offset_right = 420
	_cc_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var cc_style := StyleBoxFlat.new()
	cc_style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	cc_style.set_corner_radius_all(4)
	cc_style.content_margin_left = 18
	cc_style.content_margin_right = 18
	cc_style.content_margin_top = 10
	cc_style.content_margin_bottom = 10
	_cc_panel.add_theme_stylebox_override("panel", cc_style)
	_root.add_child(_cc_panel)

	_cc = Label.new()
	_cc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cc.add_theme_font_size_override("font_size", 22)
	_cc.add_theme_color_override("font_color", Color(1, 1, 1))
	_cc_panel.add_child(_cc)

	_badge = Label.new()
	_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_badge.offset_left = 16
	_badge.offset_top = 50
	_badge.offset_right = 480
	_badge.add_theme_font_size_override("font_size", 16)
	_badge.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_badge.add_theme_constant_override("shadow_offset_x", 1)
	_badge.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(_badge)

	_pointer = _FilmPointerScript.new()
	_pointer.visible = false
	_root.add_child(_pointer)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_top = 88
	_toast_panel.offset_bottom = 88 + 52
	_toast_panel.offset_left = -360
	_toast_panel.offset_right = 360
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.08, 0.12, 0.22, 0.88)
	toast_style.set_corner_radius_all(6)
	toast_style.content_margin_left = 20
	toast_style.content_margin_right = 20
	toast_style.content_margin_top = 12
	toast_style.content_margin_bottom = 12
	_toast_panel.add_theme_stylebox_override("panel", toast_style)
	_root.add_child(_toast_panel)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.95, 0.98, 1))
	_toast_panel.add_child(_toast)


## Show a closed caption and open a soft-subtitle cue (ended by the next caption or finish).
func show_caption(text: String) -> void:
	_close_open_cue(Engine.get_frames_drawn())
	_caption_text = text.strip_edges()
	_caption_start_frame = Engine.get_frames_drawn()
	_cc.text = _caption_text
	_cc_panel.visible = not _caption_text.is_empty()


func finish_captions() -> void:
	_close_open_cue(Engine.get_frames_drawn())
	_cc_panel.visible = false


func write_webvtt(path: String) -> bool:
	var body := cues_to_webvtt(cues, fps)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("FilmChrome: cannot write captions %s" % path)
		return false
	f.store_string(body)
	return true


static func format_webvtt_time(sec: float) -> String:
	sec = maxf(sec, 0.0)
	var total_ms := int(round(sec * 1000.0))
	var ms := total_ms % 1000
	var total_s := total_ms / 1000
	var s := total_s % 60
	var total_m := total_s / 60
	var m := total_m % 60
	var h := total_m / 60
	return "%02d:%02d:%02d.%03d" % [h, m, s, ms]


static func cues_to_webvtt(cue_list: Array, cue_fps: float = 60.0) -> String:
	var rate := maxf(cue_fps, 1.0)
	var lines: PackedStringArray = PackedStringArray(["WEBVTT", ""])
	var n := 0
	for cue in cue_list:
		var text := str(cue.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		var start_f := int(cue.get("start_frame", 0))
		var end_f := int(cue.get("end_frame", start_f + 1))
		if end_f <= start_f:
			end_f = start_f + 1
		n += 1
		lines.append(str(n))
		lines.append("%s --> %s" % [
			format_webvtt_time(float(start_f) / rate),
			format_webvtt_time(float(end_f) / rate),
		])
		lines.append(text)
		lines.append("")
	return "\n".join(lines)


func show_toast(text: String) -> void:
	var t := text.strip_edges()
	_toast.text = t
	_toast_panel.visible = not t.is_empty()


func hide_toast() -> void:
	_toast.text = ""
	_toast_panel.visible = false


func show_keys(text: String) -> void:
	_badge.text = text


func clear_keys() -> void:
	_badge.text = ""


## Shortcut chip (top-left) + closed caption (bottom) for doc-style films.
func show_action_alert(keys: String, desc: String) -> void:
	var chip := keys.strip_edges()
	if not desc.is_empty():
		chip = ("[%s]  %s" % [keys, desc]) if keys != "" else desc
	show_keys(chip)
	if not desc.is_empty():
		show_caption(desc)


## Move pointer, flash white on click, update alerts. Await before applying the real action.
func animate_pointer_click(screen_pos: Vector2, keys: String = "Click", desc: String = "") -> void:
	var vp := get_viewport().get_visible_rect().grow(-2.0)
	if not vp.has_point(screen_pos):
		push_error("FilmChrome: cursor offscreen for %s at %s (vp %s)" % [
			desc if desc != "" else keys, str(screen_pos), str(get_viewport().get_visible_rect())])
		FilmUI.fail_count += 1
		return
	show_action_alert(keys, desc)
	_pointer.visible = true
	var half: Vector2 = _pointer.size * 0.5
	var target: Vector2 = screen_pos - half
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var start: Vector2 = _pointer.global_position
	if not _pointer.visible or start == Vector2.ZERO:
		start = target
		_pointer.global_position = start
	if _pointer.has_method("set_moving"):
		_pointer.set_moving(true)
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(_pointer, "global_position", target, 0.55)
	await _move_tween.finished
	if _pointer.has_method("set_moving"):
		_pointer.set_moving(false)
	if _pointer.has_method("play_click_flash"):
		await _pointer.play_click_flash()
	await get_tree().create_timer(0.08).timeout


func click_at(screen_pos: Vector2, label: String = "Click") -> void:
	show_action_alert(label, label)
	_pointer.visible = true
	_pointer.global_position = screen_pos - _pointer.size * 0.5
	if _pointer.has_method("play_click_flash"):
		_pointer.play_click_flash()


func _close_open_cue(end_frame: int) -> void:
	if _caption_text.is_empty():
		return
	var end_f := maxi(end_frame, _caption_start_frame + 1)
	cues.append({
		"start_frame": _caption_start_frame,
		"end_frame": end_f,
		"text": _caption_text,
	})
	_caption_text = ""
