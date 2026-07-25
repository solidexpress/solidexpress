extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: two open rail pads → merge path → profile → sweep (matches sketch-to-3d UI test).


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = main.sketch_mode

	await ctx.movie_toast("Merge open pads into a path, then sweep a profile", 1.5)

	await ctx.beat("Sketch the first open rail on the ground", 0.4)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(16, 0))
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_a.is_empty():
		await ctx.beat("Rail sketch failed", 0.8)
		return

	await ctx.beat("Sketch a second open leg that meets the rail end", 0.4)
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(16, 0), Vector2(16, 14))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_b.is_empty():
		await ctx.beat("Leg sketch failed", 0.8)
		return

	await ctx.beat("Ctrl+click both cyan pads, then Merge Join", 0.4)
	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	if main.view != null:
		main.view.refresh_sketch_pads("")
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)
	await FilmUI.merge_sketches_ui(ctx, "join_endpoints")
	await ctx.after_regen()
	if FilmUI.last_feature_id(doc, "path").is_empty():
		await ctx.beat("Path merge failed", 0.8)
		return

	await ctx.beat("Sketch a circle profile, then Sweep along path", 0.4)
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if prof_fid.is_empty():
		await ctx.beat("Profile sketch failed", 0.8)
		return

	await FilmUI.clear_pad_selection(ctx)
	await FilmUI.select_sketch_pad_ctrl(ctx, prof_fid)
	await FilmUI.sweep_along_path_ui(ctx)
	await ctx.after_regen()

	var sw := FilmUI.last_feature_id(doc, "sweep")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == sw:
			var body := str(f.get("output_body", ""))
			if body != "":
				vol = absf(doc.body_volume(body))
	if sw.is_empty() or vol < 10.0:
		await ctx.beat("Sweep failed", 0.8)
		return

	await ctx.beat("Solid path sweep — %.0f mm³" % vol, 0.6)
	await ctx.camera.showcase_smooth(1.1, 40.0)
