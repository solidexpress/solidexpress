extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode
	await ctx.movie_toast("If width > 100, suppress the rib — a rule, not a dock", 1.5)

	await ctx.beat("Plate with a rib along a drawn profile", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var body: String = doc.body_ids()[0] if doc.body_ids().size() > 0 else ""
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(10, 25), Vector2(40, 25),
	]))
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if body != "":
		ctx.view.select_entity(body, "")
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
