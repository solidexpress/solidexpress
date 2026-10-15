class_name FilmCaptionMath
extends RefCounted

## Math helpers for film captions (kept dependency-free for unit tests).

enum Dock { BOTTOM, TOP }

static func choose_dock(caption_bottom_rect: Rect2, target: Rect2, margin: float) -> int:
	# Pick TOP when a bottom-docked caption (grown by margin) would intersect
	# the click target; otherwise BOTTOM.
	return Dock.TOP if caption_bottom_rect.grow(margin).intersects(target) else Dock.BOTTOM

