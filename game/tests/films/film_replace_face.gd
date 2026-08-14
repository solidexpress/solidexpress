extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Replace one face — the rest of the solid stays named", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	var vol := 0.0
	if not bodies.is_empty():
		vol = float(doc.measure_mass(bodies[0]).get("volume", 0.0))
	await ctx.beat("Solid still valid — volume %.0f mm³" % vol, 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
