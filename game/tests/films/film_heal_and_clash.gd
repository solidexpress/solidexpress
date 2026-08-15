extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Heal report + clash volume on two bodies", 1.6)

	await ctx.beat("Place two overlapping boxes", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.size() >= 2:
		ctx.view.select_entity(bodies[0], "")
		# Shift-add second via API so Clash strip appears, then click it.
		# Multi-select both bodies so the selection strip shows Clash.
		if ctx.view.has_method("select_all_bodies"):
			ctx.view.select_all_bodies()
		else:
			# Fallback: keep primary selected if multi-select API is unavailable.
			await FilmUI.wait_frames(ctx.tree, 2)
		await ctx.beat("Click Clash on the strip", 0.4)
		await FilmUI.click_button(ctx, "Clash")
		var v: float = doc.interference_volume(bodies[0], bodies[1])
		await ctx.beat("Overlap %.1f mm³" % maxf(v, 0.0), 0.7)
	var report := ""
	for feat in doc.graph_features():
		var hid := str(feat.get("id", ""))
		var r: String = doc.heal_report(hid)
		if r != "":
			report = r
			break
	if report == "":
		report = "heal: ready on Import STEP"
	await ctx.beat(report, 0.8)
	await ctx.camera.showcase_smooth(1.1, 28.0)
