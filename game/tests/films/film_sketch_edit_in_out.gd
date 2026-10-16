extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: draw rect, exit to yellow pad, reopen pad, add a line, exit again.


func run_film(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode

	await ctx.beat("Draw a closed rectangle with lines", 0.08)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(0, 0), Vector2(20, 0), Vector2(20, 12), Vector2(0, 12), Vector2(0, 0),
	]))
	var fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid.is_empty():
		await ctx.beat("Sketch commit failed", 1.0)
		return

	await ctx.beat("Click the yellow pad to reopen the sketch", 0.08)
	await FilmUI.edit_sketch_pad(ctx, fid)
	await ctx.after_regen()
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active:
		await ctx.beat("Reopen sketch failed — pad not editable", 1.0)
		return

	await ctx.beat("Add a diagonal line inside the profile", 0.08)
	await FilmUI.draw_line(ctx, sm, Vector2(2, 2), Vector2(18, 10))
	await FilmUI.apply_extrude(ctx, 8.0)
	await ctx.after_regen()

	await ctx.beat("Sketch edited in place — pad preserved", 0.12)
