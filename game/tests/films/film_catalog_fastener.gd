extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Catalog fastener is in the base, not a paid tier", 1.5)
	var f: Dictionary = doc.catalog_fastener("M6x20")
	await ctx.beat("%s  Ø%.0f × %.0f mm" % [str(f.get("designation", "?")),
			float(f.get("diameter", 0)), float(f.get("length", 0))], 0.8)
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.camera.showcase_smooth(0.8, 18.0)
