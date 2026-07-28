extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: rectangular washer profile offset from Y axis → revolve 360°.


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode

	await ctx.movie_toast("Revolve a washer profile around the Y axis", 1.8)

	await ctx.beat("Sketch a rectangle offset from the Y axis", 0.5)
	await FilmUI.enter_sketch(ctx)
	if sm.has_method("set_snap"):
		sm.set_snap(false)
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(10, 0), Vector2(14, 0), Vector2(14, 4), Vector2(10, 4),
	]))
	if sm.has_method("set_snap"):
		sm.set_snap(true)

	await ctx.beat("Revolve the profile 360° into a washer", 0.5)
	await FilmUI.apply_revolve(ctx, TAU, "new")
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	var rv_fid := FilmUI.last_feature_id(doc, "revolve")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == rv_fid:
			var body := str(f.get("output_body", ""))
			if body != "":
				vol = doc.body_volume(body)
	if vol <= 0.0:
		await ctx.beat("Revolve failed — closed profile on one side of axis?", 1.0)
		return

	await ctx.beat("Washer solid — %.0f mm³" % vol, 0.7)
	await ctx.camera.showcase_smooth(1.2, 32.0)
