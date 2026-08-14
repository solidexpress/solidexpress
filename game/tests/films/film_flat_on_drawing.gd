extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Flat pattern on the drawing — bend lines, not a second file", 1.5)
	doc.graph_add_flange(30.0, 1.5, 0.44, 1.5)
	await ctx.after_regen()
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(1)
	var path := "user://film_flat.svg"
	doc.export_drawing_svg(path, 1.0)
	await ctx.beat("Sheet view + SVG — bend direction lives on the paper", 0.8)
	await ctx.camera.showcase_smooth(0.9, 20.0)
