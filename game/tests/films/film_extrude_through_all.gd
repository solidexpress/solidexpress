extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode
	await ctx.movie_toast("Through-all cut — plate thickness stays put", 1.6)

	await ctx.beat("Place a plate", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var plate := FilmUI.last_feature_id(doc, "primitive")
	var plate_body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == plate:
			plate_body = str(f.get("output_body", ""))
	var z0 := 0.0
	if plate_body != "":
		var bb: Dictionary = doc.measure_bbox(plate_body)
		z0 = (bb["max"] as Vector3).z - (bb["min"] as Vector3).z

	await ctx.beat("Sketch a pocket on the top and extrude", 0.45)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(10, 10), Vector2(30, 10), Vector2(30, 30), Vector2(10, 30), Vector2(10, 10),
	]))
	await FilmUI.apply_extrude(ctx, 10.0)
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	var sk_fid := FilmUI.last_feature_id(doc, "sketch")
	if sk_fid != "" and plate != "":
		doc.graph_add_extrude_end(sk_fid, 1.0, "through_all", "cut", plate)
		await ctx.after_regen()

	var z1 := z0
	var vol := 0.0
	if plate_body != "":
		var bb2: Dictionary = doc.measure_bbox(plate_body)
		z1 = (bb2["max"] as Vector3).z - (bb2["min"] as Vector3).z
		vol = doc.body_volume(plate_body)
	await ctx.beat("Thickness %.1f mm (was %.1f) — hole through, stock unchanged" % [z1, z0], 0.9)
	if vol > 0.0:
		await ctx.beat("Volume %.0f mm³ after the through cut" % vol, 0.5)
	await ctx.camera.showcase_smooth(1.2, 36.0)
