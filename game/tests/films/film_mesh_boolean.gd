extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Boolean a solid against a mesh body", 1.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await ctx.beat("Fuse / cut volume is the gate — not a second mesh app", 0.7)
	await ctx.camera.showcase_smooth(0.6, 12.0)
