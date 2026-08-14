extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("A tall box lies down — height drops from 80 to 10", 1.5)
	var doc: SxDocument = ctx.view.doc
	doc.add_box(10, 10, 80, Vector3.ZERO)
	await ctx.after_regen()
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(5)
	await FilmUI.wait_frames(ctx.tree, 2)
	var before: Dictionary = doc.print_analyze("")
	await FilmUI.click_button(ctx, "Orient")
	var after: Dictionary = doc.print_analyze("")
	await ctx.beat("Height %.1f → %.1f mm" % [float(before.get("height", 0)), float(after.get("height", 0))], 0.9)
	await ctx.camera.showcase_smooth(0.8, 18.0)
