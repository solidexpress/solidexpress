extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Flange box — flat length from K-factor", 1.5)
	await ctx.beat("Switch to Sheet mode", 0.4)
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		await FilmUI.click_control(ctx, mode, {"keys": "Sheet", "desc": "Sheet mode"})
		mode.get_popup().id_pressed.emit(2)
	var flat: float = doc.sheet_flat_length(30.0, 30.0, 1.5, 0.44, 1.5)
	doc.graph_add_flange(30.0, 1.5, 0.44, 1.5)
	await ctx.after_regen()
	await ctx.beat("Flat length %.2f mm (legs + bend allowance)" % flat, 0.8)
	await ctx.camera.showcase_smooth(1.1, 28.0)
