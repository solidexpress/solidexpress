extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: two profile pads + open guide rail → smooth loft with guide curves.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = main.sketch_mode

	await ctx.movie_toast("Loft with a guide rail (open pad steers the waist)", 1.9)

	await ctx.beat("Sketch a large circle on the ground plane", 0.5)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var fid_bot := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_bot.is_empty():
		await ctx.beat("Bottom profile failed", 1.0)
		return

	await ctx.beat("Place a box, then sketch a smaller circle on its top face", 0.55)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place box failed", 1.0)
		return
	var host: String = bodies[bodies.size() - 1]
	var top_face := FilmUI.find_face_by_normal(ctx.view, host, Vector3(0, 0, 1))
	if top_face.is_empty():
		await ctx.beat("Top face not found", 1.0)
		return
	await FilmUI.enter_sketch_on_face(ctx, host, top_face)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(4, 0))
	var fid_top := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_top.is_empty() or fid_top == fid_bot:
		await ctx.beat("Top profile failed", 1.0)
		return

	await ctx.beat("Sketch an open guide rail beside the profiles", 0.55)
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	# Single segment stays cyan (rail); Auto-close needs 2+ segments.
	await FilmUI.draw_line(ctx, sm, Vector2(18, 16), Vector2(26, 28))
	var fid_guide := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_guide.is_empty() or fid_guide == fid_bot or fid_guide == fid_top:
		await ctx.beat("Guide rail failed", 1.0)
		return
	if main._sketch_pad_role(fid_guide) != "rail":
		await ctx.beat("Guide pad is not an open rail", 1.0)
		return

	await ctx.beat("Hide the box, then Ctrl+click top, guide, and bottom pads", 0.55)
	await FilmUI.clear_pad_selection(ctx)
	var hide_btn := FilmUI.find_button(main, "Hide")
	if hide_btn != null and hide_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, hide_btn, FilmUICues.alert("Hide", "Hide solid to reach pads"))
	elif not doc.body_ids().is_empty():
		var face := FilmUI.find_face_by_normal(ctx.view, host, Vector3(0, 0, 1))
		if face != "":
			await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx,
					FilmUI.face_pick_point(ctx.view, host, face)),
					FilmUICues.alert("Click", "Select solid"))
			hide_btn = FilmUI.find_button(main, "Hide")
			if hide_btn != null:
				await FilmUI.click_control(ctx, hide_btn,
						FilmUICues.alert("Hide", "Hide solid to reach pads"))
	main.selected_sketch_pads.clear()
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_top)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_guide)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_bot)
	if main.selected_sketch_pads.size() < 3:
		await ctx.beat("Need two profiles plus the guide rail selected", 1.0)
		return

	await ctx.beat("Loft smooth — open rail becomes a guide curve", 0.55)
	main._refresh_merge_chrome()
	await ctx.tree.process_frame
	await FilmUI.loft_profiles_ui(ctx, false)
	await ctx.after_regen()

	var loft_fid := FilmUI.last_feature_id(doc, "loft")
	var vol := 0.0
	var has_guide := false
	for f in doc.graph_features():
		if str(f.get("id", "")) != loft_fid:
			continue
		var out_body := str(f.get("output_body", ""))
		if out_body != "":
			vol = doc.body_volume(out_body)
		var raw: Variant = f.get("params", "{}")
		var parsed: Variant = raw
		if typeof(raw) == TYPE_STRING:
			parsed = JSON.parse_string(str(raw))
		if typeof(parsed) == TYPE_DICTIONARY:
			var guides: Variant = parsed.get("guides", [])
			if typeof(guides) == TYPE_ARRAY:
				for g in guides:
					if str(g) == fid_guide:
						has_guide = true
		break
	if loft_fid.is_empty() or absf(vol) <= 10.0 or not has_guide:
		await ctx.beat("Guided loft failed", 1.0)
		return

	await ctx.beat("Guided loft solid — %.0f mm³" % absf(vol), 0.7)
	await ctx.camera.showcase_smooth(1.4, 40.0)
