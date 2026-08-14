extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Converted edges remember their UUIDs", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await FilmUI.enter_sketch(ctx)
	var sm = ctx.main.sketch_mode
	var sketch_fid := FilmUI.last_feature_id(doc, "sketch")
	var bodies: PackedStringArray = doc.body_ids()
	if sketch_fid != "" and not bodies.is_empty():
		var edges := PackedStringArray()
		# Convert stores the edge UUIDs on the sketch feature.
		var n: int = doc.convert_edges(sketch_fid, edges)
		await ctx.beat("Associative convert stored %d edge(s)" % n, 0.8)
	else:
		await ctx.beat("Sketch + source edges make convert survive an edit", 0.8)
	await ctx.camera.showcase_smooth(0.7, 14.0)
	var _sm = sm
