extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("One joint definition, a circle of bolts", 1.6)

	await ctx.beat("Plate and a bolt instance", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bolt: String = doc.add_cylinder(3.0, 16.0, Vector3(40, 0, 0))
	ctx.view.refresh()
	await FilmUI.wait_frames(ctx.tree, 2)
	ctx.view.select_entity(bolt, "")
	await FilmUI.click_button(ctx, "Place instance of selection")

	var insts: Array = doc.instance_list()
	if not insts.is_empty():
		var seed: String = str(insts[0]["id"])
		await ctx.beat("Pattern around the joint — six placements, one definition", 0.5)
		ctx.view.select_instance(seed)
		await FilmUI.click_button(ctx, "Pattern around joint")

	var n: int = doc.instance_list().size()
	var jn: int = doc.joint_list().size()
	await ctx.beat("%d bolts, %d joints — copies inherit the seed" % [n, jn], 0.9)
	await ctx.camera.showcase_smooth(1.1, 28.0)
