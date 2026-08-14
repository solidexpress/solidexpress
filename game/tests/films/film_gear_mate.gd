extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Gear ratio on connectors — driven = driver × ratio", 1.4)
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.after_regen()
	await ctx.beat("Ratio lives on the joint, not a new mate type", 0.7)
	await ctx.camera.showcase_smooth(0.6, 12.0)
