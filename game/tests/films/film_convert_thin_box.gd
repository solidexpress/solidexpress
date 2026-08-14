extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A thin solid becomes sheet metal", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var prim := FilmUI.last_feature_id(doc, "primitive")
	if prim != "":
		var p := {"kind": "box", "a": 40.0, "b": 30.0, "c": 2.0}
		doc.graph_set_params(prim, JSON.stringify(p))
		await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if not bodies.is_empty():
		ctx.view.select_entity(bodies[0], "")
		await FilmUI.marking_verb(ctx, "Convert sheet")
		await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "convert_sheet")
	await ctx.beat("Convert sheet %s — thickness lives on the feature" % ("landed" if fid != "" else "needs a thin solid"), 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
