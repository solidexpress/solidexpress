extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Section through a hole — hatch on the sheet", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	doc.ensure_drawing_sheet()
	var sheet_id: String = doc.ensure_drawing_sheet()
	# A section view is stored on the drawing document; Draw mode paints hatch.
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		await FilmUI.click_control(ctx, mode, {"keys": "Draw", "desc": "Draw mode"})
		if mode.get_popup():
			mode.get_popup().id_pressed.emit(1)
	await FilmUI.wait_frames(ctx.tree, 2)
	var prev: Dictionary = doc.drawing_preview()
	var views: Array = prev.get("views", [])
	await ctx.beat("%d live HLR views on the sheet" % views.size(), 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
	var _keep := sheet_id
