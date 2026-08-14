extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("What's Wrong names the failed fillet and offers a rematch", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var feats: Array = doc.graph_features()
	if not feats.is_empty():
		var diag: Dictionary = doc.diagnose_feature(str(feats[0].get("id", "")))
		await ctx.beat("Repairs: %s" % str(diag.get("repairs", [])), 0.8)
	await ctx.camera.showcase_smooth(0.7, 14.0)
