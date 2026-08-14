extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("BOM balloons match instance counts", 1.5)
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.size() > 0:
		ctx.view.select_entity(bodies[0], "")
		await FilmUI.click_button(ctx, "Place instance of selection")
		await FilmUI.click_button(ctx, "Place instance of selection")
	doc.ensure_drawing_sheet()
	var rows: Array = doc.bom_rows()
	var qty := 0
	for r in rows:
		qty += int(r.get("qty", 0))
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(1)
	await ctx.beat("BOM qty = %d (from the sheet, not a count in the test)" % qty, 0.8)
	await ctx.camera.showcase_smooth(1.0, 22.0)
