extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("PDM-lite: a version note on the .sxp", 1.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	doc.pdm_commit("first cut")
	await ctx.beat("%d version note(s) in the log" % doc.pdm_log().size(), 0.7)
	await ctx.camera.showcase_smooth(0.6, 12.0)
