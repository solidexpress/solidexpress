class_name FilmCaptionMath
extends RefCounted

## Math helpers for film captions (kept dependency-free for unit tests).

enum Dock { BOTTOM, TOP }

static func choose_dock(caption_bottom_rect: Rect2, target: Rect2, margin: float) -> int:
	# Pick TOP when a bottom-docked caption (grown by margin) would intersect
	# the click target; otherwise BOTTOM.
	return pick_dock(caption_bottom_rect, Rect2(), [target], margin)


static func pick_dock(bottom_rect: Rect2, top_rect: Rect2, obstacles: Array, margin: float) -> int:
	## Prefer BOTTOM when it misses every obstacle; else TOP if that misses;
	## else the dock with the smaller overlap area.
	var b_hit := _hits_any(bottom_rect.grow(margin), obstacles)
	if not b_hit:
		return Dock.BOTTOM
	var t_hit := false
	if top_rect.size.x > 0.0 and top_rect.size.y > 0.0:
		t_hit = _hits_any(top_rect.grow(margin), obstacles)
	if not t_hit:
		return Dock.TOP
	var ib := _total_overlap(bottom_rect, obstacles)
	var it := _total_overlap(top_rect, obstacles)
	return Dock.TOP if it < ib else Dock.BOTTOM


static func rect_for_dock(viewport_size: Vector2, caption_size: Vector2, dock: int, margin: float) -> Rect2:
	## Anchor-center math: no scene-tree / await needed.
	var size := caption_size
	if size.x <= 0.0:
		size.x = 840.0
	if size.y <= 0.0:
		size.y = 52.0
	var x := (viewport_size.x - size.x) * 0.5
	var y := margin if dock == Dock.TOP else (viewport_size.y - size.y - margin)
	return Rect2(Vector2(x, y), size)


static func intersection_area(a: Rect2, b: Rect2) -> float:
	var x1 := maxf(a.position.x, b.position.x)
	var y1 := maxf(a.position.y, b.position.y)
	var x2 := minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var y2 := minf(a.position.y + a.size.y, b.position.y + b.size.y)
	return maxf(0.0, x2 - x1) * maxf(0.0, y2 - y1)


static func _hits_any(rect: Rect2, obstacles: Array) -> bool:
	for item in obstacles:
		if typeof(item) != TYPE_RECT2:
			continue
		if rect.intersects(item):
			return true
	return false


static func _total_overlap(rect: Rect2, obstacles: Array) -> float:
	var acc := 0.0
	for item in obstacles:
		if typeof(item) != TYPE_RECT2:
			continue
		acc += intersection_area(rect, item)
	return acc
