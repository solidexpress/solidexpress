class_name FilmCaption
extends PanelContainer

## Bottom-docked closed-caption panel that can hop to top to avoid clicks.
##
## Styling comes from FilmPresentation. Position is computed from
## FilmCaptionMath.rect_for_dock (top-left + size) so hop math matches the
## on-screen rect — no await, no stale anchor offsets.

enum Dock { BOTTOM, TOP }
const _Math = preload("res://tests/lib/film_caption_math.gd")

var _label: Label
var _dock: int = Dock.BOTTOM
var _tween: Tween

var _dock_margin := FilmPresentation.DOCK_MARGIN
var _hop_margin := FilmPresentation.HOP_MARGIN
var _hop_sec := FilmPresentation.HOP_DURATION_SEC
var _min_width := FilmPresentation.CAPTION_MIN_WIDTH


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = false
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
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)
	_sync_label_wrap_width()
	_apply_offsets_for_dock(Dock.BOTTOM)


func set_text(t: String) -> void:
	if _label == null:
		return
	_label.text = str(t)
	_sync_label_wrap_width()
	_apply_offsets_for_dock(_dock)


func text() -> String:
	return _label.text if _label != null else ""


func layout_in_viewport() -> void:
	_sync_label_wrap_width()
	_apply_offsets_for_dock(_dock)


func current_rect() -> Rect2:
	# Prefer the dock math we just applied; fall back to the laid-out rect.
	var r := get_global_rect()
	if r.size.x >= _min_width * 0.5 and r.size.y >= 20.0 and r.size.x <= 1200.0 and r.size.y <= 180.0:
		return r
	return _rect_for_dock(_dock)


static func choose_dock(caption_bottom_rect: Rect2, target: Rect2, margin: float) -> int:
	# Delegate to the dependency-free helper so unit tests can load it alone.
	return _Math.choose_dock(caption_bottom_rect, target, margin)


func _sync_label_wrap_width() -> void:
	custom_minimum_size.x = _min_width
	if _label == null:
		return
	var inner := _min_width - 2.0 * FilmPresentation.CAPTION_MARGIN_H
	_label.custom_minimum_size.x = maxf(inner, 120.0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _caption_size() -> Vector2:
	var sz := get_combined_minimum_size()
	if sz.x < 1.0 or sz.y < 1.0:
		sz = size
	sz.x = maxf(sz.x, _min_width)
	sz.y = maxf(sz.y, 36.0)
	if _label != null and not _label.text.is_empty():
		# Prefer the laid-out height once the panel has measured the wrapped label.
		sz.y = maxf(sz.y, _label.get_minimum_size().y + 2.0 * FilmPresentation.CAPTION_MARGIN_V)
	# Never let a wrap-measurement failure expand over the viewport (hop would
	# then collide with every click).
	sz.y = minf(sz.y, 160.0)
	sz.x = minf(sz.x, 1200.0)
	return sz


func _apply_offsets_for_dock(d: int, margin: float = -1.0) -> void:
	_dock = d
	var m := margin if margin >= 0.0 else _dock_margin
	if d == Dock.BOTTOM:
		m = _dock_margin
	var vp := get_viewport_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		vp = Vector2(FilmPresentation.WIDTH, FilmPresentation.HEIGHT)
	var r := _Math.rect_for_dock(vp, _caption_size(), d, m)
	set("layout_mode", 0)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Explicit position/size so get_global_rect matches hop math after a resize.
	position = r.position
	size = r.size
	custom_minimum_size = Vector2(_min_width, r.size.y)


func _rect_for_dock(d: int, top_margin: float = -1.0) -> Rect2:
	var vp := get_viewport_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		vp = Vector2(FilmPresentation.WIDTH, FilmPresentation.HEIGHT)
	var margin := _dock_margin if d == Dock.BOTTOM else (top_margin if top_margin >= 0.0 else _dock_margin)
	return _Math.rect_for_dock(vp, _caption_size(), d, margin)


func avoid(point: Vector2) -> void:
	var sz := Vector2(FilmPointer.DIAM, FilmPointer.DIAM)
	await avoid_rect(Rect2(point - 0.5 * sz, sz))


func avoid_rect(target: Rect2, extra_obstacles: Array = []) -> void:
	layout_in_viewport()
	var obstacles: Array = extra_obstacles.duplicate()
	obstacles.append(target)
	var top_margin := _dock_margin
	for item in extra_obstacles:
		if typeof(item) != TYPE_RECT2:
			continue
		var r: Rect2 = item
		# Push the top dock below any toast / banner so hop does not cover it.
		top_margin = maxf(top_margin, r.position.y + r.size.y + _hop_margin)
	var bottom_rect := _rect_for_dock(Dock.BOTTOM)
	var top_rect := _rect_for_dock(Dock.TOP, top_margin)
	var want := _Math.pick_dock(bottom_rect, top_rect, obstacles, _hop_margin)
	await _hop_to(want, top_margin if want == Dock.TOP else _dock_margin)
	# If the laid-out rect still hits (wrap height / toast), hop to the other dock.
	if current_rect().grow(_hop_margin).intersects(target):
		var other := Dock.TOP if _dock == Dock.BOTTOM else Dock.BOTTOM
		await _hop_to(other, top_margin if other == Dock.TOP else _dock_margin)


func _hop_to(want: int, margin: float) -> void:
	var from := position
	_apply_offsets_for_dock(want, margin)
	var to := position
	if from.distance_squared_to(to) < 1.0:
		return
	position = from
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", to, _hop_sec)
	await _tween.finished
	_apply_offsets_for_dock(want, margin)
