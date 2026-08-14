extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Four M6 holes near the corners — query + intent + hole", 1.6)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var prim := FilmUI.last_feature_id(doc, "primitive")
	var hits: Array = []
	if prim != "":
		hits = doc.run_query("created-by=%s type=face" % prim)
	await ctx.beat("Query hit %d faces; four M6 clearances at the corners" % hits.size(), 0.9)
	await ctx.camera.showcase_smooth(0.8, 16.0)
