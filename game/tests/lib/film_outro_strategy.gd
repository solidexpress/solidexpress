class_name FilmOutroStrategy
extends RefCounted

## One strategy for website-film outros. Films do not branch on this.
## Drawing sheet stays put (hold). Sketch-only (no solid) frames top-down.
## Otherwise: fitted 3/4 orbit.

const _Pres := preload("res://tests/lib/film_presentation.gd")

enum Kind { SOLID, SKETCH, DRAWING }


static func kind(has_solid: bool, is_drawing: bool) -> int:
	if is_drawing:
		return Kind.DRAWING
	if has_solid:
		return Kind.SOLID
	return Kind.SKETCH


static func choose(ctx) -> int:
	return kind(_has_solid_body(ctx), _is_drawing(ctx))


static func play(ctx, kind_id: int) -> void:
	if ctx == null:
		return
	match kind_id:
		Kind.DRAWING:
			await _hold_unique(ctx, _Pres.DRAWING_HOLD_SEC)
		Kind.SKETCH:
			if ctx.camera != null and ctx.camera.has_method("fit_sketch_top_down"):
				ctx.camera.fit_sketch_top_down(ctx)
			await _hold_unique(ctx, _Pres.OUTRO_SEC)
		_:
			if ctx.camera != null:
				if ctx.camera.has_method("fit_oblique_fill"):
					ctx.camera.fit_oblique_fill(_Pres.OUTRO_FILL_FRAC)
				if ctx.tree != null:
					await ctx.tree.process_frame
				await ctx.camera.orbit_smooth(
						_Pres.OUTRO_ORBIT_DEG, _Pres.OUTRO_SEC)


static func _is_drawing(ctx) -> bool:
	if ctx == null or ctx.main == null:
		return false
	var sheet = ctx.main.get("drawing_sheet")
	if sheet != null and bool(sheet.get("visible")):
		return true
	return false


static func _has_solid_body(ctx) -> bool:
	if ctx == null or ctx.view == null or ctx.view.doc == null:
		return false
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return false
	for id in ids:
		if ctx.view.hidden_bodies.has(id):
			continue
		if ctx.view.body_node(id) != null:
			return true
	return false


static func _hold_unique(ctx, sec: float) -> void:
	# MovieWriter skips exact duplicate presents; nudge caption alpha each frame.
	var frames := maxi(1, int(round(sec * _Pres.FPS)))
	for i in frames:
		if ctx.chrome != null and ctx.chrome.has_method("tick_unique"):
			ctx.chrome.tick_unique(i)
		if ctx.tree != null:
			await ctx.tree.process_frame
