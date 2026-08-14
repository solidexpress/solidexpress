extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("The card names the feature — one auto sentence", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "primitive")
	var d := ""
	if fid != "":
		d = doc.card_digest(fid)
	await ctx.beat("Digest: %s" % d, 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
