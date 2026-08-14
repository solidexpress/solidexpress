extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Query lights faces created by a feature", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "primitive")
	var hits: Array = doc.run_query("type=face created-by=%s" % fid)
	await ctx.beat("Query hit %d faces" % hits.size(), 0.8)
	if fid != "":
		await ctx.beat(doc.card_digest(fid), 0.6)
	await ctx.camera.showcase_smooth(0.9, 20.0)
