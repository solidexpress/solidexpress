extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("SubD spike: round every edge of a box", 1.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await ctx.beat("OpenSubdiv later — today every edge fillets into a solid", 0.8)
	await ctx.camera.showcase_smooth(0.6, 12.0)
