extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Zebra stripes on a cylinder — continuity you can see", 1.5)
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.after_regen()
	await FilmUI.click_button(ctx, "Zebra")
	await ctx.beat("Zebra is a ViewHud toggle, like Section", 0.8)
	await ctx.camera.showcase_smooth(1.0, 24.0)
