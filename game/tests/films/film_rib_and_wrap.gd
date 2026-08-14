extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode
	await ctx.movie_toast("A rib follows the profile you draw — no extra dock", 1.5)

	await ctx.beat("Place a plate", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			body = str(f.get("output_body", ""))
	var v0 := 0.0
	if body != "":
		v0 = float(doc.measure_mass(body).get("volume", 0.0))

	await ctx.beat("Draw the rib as an open two-leg profile", 0.5)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(10, 25), Vector2(40, 25), Vector2(40, 40),
	]))
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await ctx.beat("Select the plate, then Rib from the S menu", 0.45)
	if body != "":
		ctx.view.select_entity(body, "")
	await FilmUI.marking_verb(ctx, "Rib")
	await ctx.after_regen()
	var v1 := v0
	if body != "":
		v1 = float(doc.measure_mass(body).get("volume", 0.0))
	await ctx.beat("Volume %.0f → %.0f mm³ — the rib tracks the sketch" % [v0, v1], 0.8)
	await ctx.camera.showcase_smooth(1.0, 24.0)
