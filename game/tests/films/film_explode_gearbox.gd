extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Explode separates the gearbox — and collapse puts it back", 1.6)

	await ctx.beat("Housing and a shaft instance", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var shaft: String = doc.add_cylinder(6.0, 40.0, Vector3(80, 0, 0))
	ctx.view.refresh()
	await FilmUI.wait_frames(ctx.tree, 2)
	ctx.view.select_entity(shaft, "")
	await FilmUI.click_button(ctx, "Place instance of selection")
	await ctx.after_regen()

	await ctx.beat("Explode — parts travel along their joints", 0.45)
	var home: Vector3 = doc.instance_list()[0]["translation"]
	await FilmUI.click_button(ctx, "Explode")
	var away: Vector3 = doc.instance_list()[0]["translation"]
	var gap: float = away.distance_to(home)
	if gap > 1.0:
		await ctx.beat("Separated %.1f mm — the assembled pose is remembered" % gap, 0.8)
	else:
		await ctx.beat("Explode needs a component instance", 0.6)

	await ctx.beat("Collapse restores the assembled placement", 0.4)
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.click_button(ctx, "Explode")
	var back: Vector3 = doc.instance_list()[0]["translation"]
	if back.distance_to(home) < 0.05:
		await ctx.beat("Home again — explode is a way of seeing, not a mate", 0.8)
	else:
		await ctx.beat("Collapsed", 0.5)
	await ctx.camera.showcase_smooth(1.0, 24.0)
