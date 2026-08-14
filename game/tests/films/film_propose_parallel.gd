extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Two near-parallel lines — one click makes them parallel", 1.5)
	await FilmUI.enter_sketch(ctx)
	var sm = ctx.main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(180, 180), Vector2(360, 184))
	await FilmUI.draw_line(ctx, sm, Vector2(180, 260), Vector2(360, 268))
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.click_button(ctx, "parallel?")
	await ctx.beat("Proposed parallel", 0.8)
	await ctx.camera.showcase_smooth(0.7, 14.0)
