extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("“Make these flush” becomes a fastened mate", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var doc: SxDocument = ctx.view.doc
	var bolt: String = doc.add_cylinder(4.0, 16.0, Vector3(40, 0, 0))
	ctx.view.select_entity(bolt, "")
	await FilmUI.click_button(ctx, "Place instance of selection")
	if ctx.main.voice_executor != null:
		ctx.main.voice_executor.handle_text("make these flush")
	await ctx.beat("Intent → fastened offset 0", 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
