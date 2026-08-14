extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("BOM knows which configuration it is counting", 1.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if not bodies.is_empty():
		ctx.view.select_entity(bodies[0], "")
		await FilmUI.click_button(ctx, "Place instance of selection")
	var rows: Array = doc.bom_rows()
	await ctx.beat("Config-aware BOM: %d row(s)" % rows.size(), 0.7)
	await ctx.camera.showcase_smooth(0.6, 12.0)
