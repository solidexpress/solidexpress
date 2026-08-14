extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A user feature is a recipe that regenerates", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var prim := FilmUI.last_feature_id(doc, "primitive")
	if prim != "":
		var fid: String = doc.graph_add_user_csink(prim, Vector3(25, 25, 50), 6.0, 12.0, 12.0)
		await ctx.after_regen()
		await ctx.beat("User C-sink %s" % ("regenerated" if fid != "" else "needs a target"), 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
