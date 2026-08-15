extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode
	await ctx.movie_toast("A rib follows the profile you draw — no extra dock", 1.5)

	await ctx.beat("Place a plate", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await ctx.camera.frame_all_smooth(0.0)
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
		Vector2(6, 12), Vector2(24, 12), Vector2(24, 20),
	]))
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await ctx.beat("Select the plate, then Rib from the S menu", 0.45)
	if body != "":
		ctx.view.select_entity(body, "")
		await FilmUI.wait_frames(ctx.tree, 2)
	var ix = ctx.main.interaction
	if ix != null and ix.has_method("_open_marking_menu"):
		ix._open_marking_menu(ix._screen_center() if ix.has_method("_screen_center") else Vector2(400, 300))
		await FilmUI.wait_frames(ctx.tree, 3)
		var menu: MarkingMenu = ix.marking_menu
		if menu != null and menu.visible:
			var b := FilmUI.find_button(menu, "Rib")
			if b != null:
				await FilmUI.click_control(ctx, b, FilmUI.FilmUICues.alert("S", "Rib from the marking menu"))
			else:
				await FilmUI.marking_verb(ctx, "Rib")
		else:
			await FilmUI.marking_verb(ctx, "Rib")
	else:
		await FilmUI.marking_verb(ctx, "Rib")
	await ctx.after_regen()
	var v1 := v0
	if body != "":
		v1 = float(doc.measure_mass(body).get("volume", 0.0))
	await ctx.beat("Volume %.0f → %.0f mm³ — the rib tracks the sketch" % [v0, v1], 0.8)
	await ctx.camera.showcase_smooth(1.0, 24.0)
