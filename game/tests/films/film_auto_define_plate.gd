extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("One click promotes weak dims to DOF 0", 1.5)
	await ctx.camera.frame_all_smooth(0.0)
	await FilmUI.enter_sketch(ctx)
	var sm = ctx.main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(20, 20), Vector2(36, 20))
	await FilmUI.draw_line(ctx, sm, Vector2(36, 20), Vector2(36, 30))
	await FilmUI.draw_line(ctx, sm, Vector2(36, 30), Vector2(20, 30))
	await FilmUI.draw_line(ctx, sm, Vector2(20, 30), Vector2(20, 20))
	await FilmUI.click_button(ctx, "Auto-define")
	await ctx.beat("Auto-define — DOF %d" % sm.last_dofs, 0.8)
	await ctx.camera.showcase_smooth(0.7, 14.0)
