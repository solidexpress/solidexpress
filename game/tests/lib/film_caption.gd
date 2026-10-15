class_name FilmCaption
extends PanelContainer

## Bottom-docked closed-caption panel that can hop to top to avoid clicks.
##
## Styling comes from FilmPresentation. The parent should add a Label child
## and set its text.

enum Dock { BOTTOM, TOP }
const _Math = preload("res://tests/lib/film_caption_math.gd")

var _label: Label
var _dock: int = Dock.BOTTOM
var _tween: Tween

var _dock_margin := FilmPresentation.DOCK_MARGIN
var _hop_margin := FilmPresentation.HOP_MARGIN
var _hop_sec := FilmPresentation.HOP_DURATION_SEC

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_apply_offsets_for_dock(Dock.BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = FilmPresentation.CAPTION_BG
	sb.set_corner_radius_all(FilmPresentation.CAPTION_CORNER_RADIUS)
	sb.content_margin_left = FilmPresentation.CAPTION_MARGIN_H
	sb.content_margin_right = FilmPresentation.CAPTION_MARGIN_H
	sb.content_margin_top = FilmPresentation.CAPTION_MARGIN_V
	sb.content_margin_bottom = FilmPresentation.CAPTION_MARGIN_V
	add_theme_stylebox_override("panel", sb)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FilmPresentation.CAPTION_FONT_SIZE)
	_label.add_theme_color_override("font_color", FilmPresentation.CAPTION_TEXT)
	add_child(_label)

func set_text(t: String) -> void:
	_label.text = str(t)

func text() -> String:
	return _label.text

static func choose_dock(caption_bottom_rect: Rect2, target: Rect2, margin: float) -> int:
	# Delegate to the dependency-free helper so unit tests can load it alone.
	return _Math.choose_dock(caption_bottom_rect, target, margin)

func _apply_offsets_for_dock(d: int) -> void:
	if d == Dock.BOTTOM:
		set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		offset_bottom = _dock_margin
		offset_top = 0
		offset_left = -420
		offset_right = 420
	else:
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		offset_top = _dock_margin
		offset_bottom = 0
		offset_left = -420
		offset_right = 420

func _rect_for_dock(d: int) -> Rect2:
	var old_anchor := anchor_top
	var old_off_t := offset_top
	var old_off_b := offset_bottom
	var old_off_l := offset_left
	var old_off_r := offset_right
	_apply_offsets_for_dock(d)
	# Force minimum size compute
	await get_tree().process_frame
	var r := get_global_rect()
	# Restore existing dock without tween
	anchor_top = old_anchor
	offset_top = old_off_t
	offset_bottom = old_off_b
	offset_left = old_off_l
	offset_right = old_off_r
	return r

func avoid(point: Vector2) -> void:
	var sz := Vector2(FilmPointer.DIAM, FilmPointer.DIAM)
	avoid_rect(Rect2(point - 0.5 * sz, sz))

func avoid_rect(target: Rect2) -> void:
	# Pick a dock that avoids the click target; if both intersect, pick smaller overlap.
	var bottom_rect := _rect_for_dock(Dock.BOTTOM)
	var top_rect := _rect_for_dock(Dock.TOP)
	var want := Dock.BOTTOM
	if bottom_rect.grow(_hop_margin).intersects(target):
		want = Dock.TOP
	if bottom_rect.grow(_hop_margin).intersects(target) and top_rect.grow(_hop_margin).intersects(target):
		var ib := _intersection_area(bottom_rect, target)
		var it := _intersection_area(top_rect, target)
		want = Dock.TOP if it < ib else Dock.BOTTOM
	_hop_to(want)

func _hop_to(want: int) -> void:
	if _dock == want:
		return
	_dock = want
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var to_top := want == Dock.TOP
	# Animate the top/bottom offsets only; keep horizontal size fixed.
	if to_top:
		# switch anchors first so the tween animates the correct property
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		_tween.tween_property(self, "offset_top", _dock_margin, _hop_sec)
	else:
		set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_tween.tween_property(self, "offset_bottom", _dock_margin, _hop_sec)
	await _tween.finished

static func _intersection_area(a: Rect2, b: Rect2) -> float:
	var x1 := maxf(a.position.x, b.position.x)
	var y1 := maxf(a.position.y, b.position.y)
	var x2 := minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var y2 := minf(a.position.y + a.size.y, b.position.y + b.size.y)
	return maxf(0.0, x2 - x1) * maxf(0.0, y2 - y1)

