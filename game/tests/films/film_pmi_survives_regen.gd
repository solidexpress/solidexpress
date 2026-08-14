extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A 3D dim is a drawing dim in model space", 1.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if not bodies.is_empty():
		var did: String = doc.add_drawing_dim(bodies[0], "")
		doc.refresh_drawing_dims()
		await ctx.beat("PMI dim %s" % ("anchored" if did != "" else "missing"), 0.7)
	await ctx.camera.showcase_smooth(0.6, 12.0)
