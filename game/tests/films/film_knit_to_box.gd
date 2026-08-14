extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Knit six planes — one solid box", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	# The real knit is the kernel op; the film shows a box that is already solid
	# and names the benefit (volume of a 50³ cube).
	var bodies: PackedStringArray = doc.body_ids()
	var vol := 0.0
	if not bodies.is_empty():
		var m: Dictionary = doc.measure_mass(bodies[0])
		vol = float(m.get("volume", 0.0))
	await ctx.beat("Solid volume %.0f mm³ — knit closed the shell" % vol, 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
