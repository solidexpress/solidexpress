extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("2.5-axis pocket — our post, no CalculiX", 1.5)
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(3)
	var pts: PackedVector3Array = doc.cam_pocket(0, 0, 20, 10, 2.0, 2.0)
	await ctx.beat("Toolpath %d points (zig-zag)" % pts.size(), 0.8)
	await ctx.camera.showcase_smooth(0.8, 18.0)
