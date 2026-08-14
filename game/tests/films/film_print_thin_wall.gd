extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("A 1.2 mm plate fails the 2 mm wall check", 1.5)
	var doc: SxDocument = ctx.view.doc
	doc.add_box(20, 20, 1.2, Vector3.ZERO)
	doc.set_print_min_wall(2.0)
	await ctx.after_regen()
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(5)
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.click_button(ctx, "Analyze")
	var r: Dictionary = doc.print_analyze("")
	await ctx.beat(str(r.get("digest", "print check")), 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
