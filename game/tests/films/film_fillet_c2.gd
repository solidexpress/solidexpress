extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("C2 fillet — two radii on the same chain", 1.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await ctx.beat("Variable fillet already carries radius2; C2 is the continuity tag", 0.8)
	await ctx.camera.showcase_smooth(0.6, 12.0)
