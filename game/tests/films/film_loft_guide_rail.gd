extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Ship hull: U transom lofted into an oval bow on a parallel face.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var doc: SxDocument = ctx.view.doc
	var actor := FilmActor.of(ctx)

	await ctx.beat("Place a long blank — the two ends become hull stations")
	await FilmUI.place_primitive_at(ctx, "box", Vector3(0, 0, 0), Vector3(140, 48, 36))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		FilmUI._fail("hull blank did not place")
		return
	var host: String = str(bodies[bodies.size() - 1])
	var stern := FilmUI.find_face_by_normal(ctx.view, host, Vector3(-1, 0, 0))
	var bow := FilmUI.find_face_by_normal(ctx.view, host, Vector3(1, 0, 0))
	if stern.is_empty() or bow.is_empty():
		FilmUI._fail("blank is missing transom / bow faces")
		return

	await ctx.beat("Sketch a U transom — flat floor, nearly vertical sides")
	await FilmUI.enter_sketch_on_face(ctx, host, stern)
	var sm: SketchMode = main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("transom sketch did not start")
		return
	var u := PackedVector2Array([
		Vector2(-18, -14), Vector2(18, -14), Vector2(16, 14), Vector2(-16, 14), Vector2(-18, -14),
	])
	await FilmUI.draw_polyline(ctx, sm, u)
	var fid_stern := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_stern.is_empty():
		FilmUI._fail("transom profile failed")
		return

	await ctx.beat("Sketch an oval at the bow")
	await FilmUI.enter_sketch_on_face(ctx, host, bow)
	sm = main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("bow sketch did not start")
		return
	await FilmUI.draw_ellipse(ctx, sm, Vector2.ZERO, Vector2(11, 8))
	var fid_bow := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_bow.is_empty() or fid_bow == fid_stern:
		FilmUI._fail("bow profile failed")
		return

	await ctx.beat("Hide the blank, then loft the two stations")
	await FilmUI.clear_pad_selection(ctx)
	var hide_btn := FilmUI.find_button(main, "Hide")
	if hide_btn != null and hide_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, hide_btn, FilmUICues.alert("Hide", "Hide blank to reach pads"))
	elif not doc.body_ids().is_empty():
		await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx,
				FilmUI.face_pick_point(ctx.view, host, bow)),
				FilmUICues.alert("Click", "Select blank"))
		hide_btn = FilmUI.find_button(main, "Hide")
		if hide_btn != null:
			await FilmUI.click_control(ctx, hide_btn,
					FilmUICues.alert("Hide", "Hide blank to reach pads"))
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_stern)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_bow)
	if main.selected_sketch_pads.size() < 2:
		FilmUI._fail("need transom and bow pads selected")
		return
	main._refresh_merge_chrome()
	await ctx.tree.process_frame
	await FilmUI.loft_profiles_ui(ctx, false)
	await ctx.after_regen()

	var loft_fid := FilmUI.last_feature_id(doc, "loft")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) != loft_fid:
			continue
		var out_body := str(f.get("output_body", ""))
		if out_body != "":
			vol = absf(doc.body_volume(out_body))
		break
	if loft_fid.is_empty() or vol <= 200.0:
		FilmUI._fail("hull loft failed (vol %.1f)" % vol)
		return
	await ctx.beat("Hull loft — U transom into an oval bow")
	await actor.result_pause()
