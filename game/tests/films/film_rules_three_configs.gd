extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode
	await ctx.movie_toast("If width > 100, suppress the rib — a rule, not a dock", 1.5)

	await ctx.beat("Plate with a rib along a drawn profile", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await ctx.camera.frame_all_smooth(0.0)
	var body: String = doc.body_ids()[0] if doc.body_ids().size() > 0 else ""
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(6, 12), Vector2(24, 12),
	]))
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
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

	await ctx.beat("Wide configuration: width 120", 0.45)
	doc.set_variable("width", "120")
	var n: int = doc.apply_rule("width > 100", "suppress rib")
	await ctx.after_regen()
	var suppressed := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "rib" and bool(f.get("suppressed", false)):
			suppressed += 1
	await ctx.beat("Rule fired %d time(s); %d rib suppressed" % [n, suppressed], 0.8)
	await ctx.camera.showcase_smooth(0.9, 22.0)
