extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("TriBall rotate-copy — one hole becomes a bolt circle", 1.6)

	await ctx.beat("Place a plate", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var plate := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == plate:
			body = str(f.get("output_body", ""))
	ctx.view.select_entity(body, "")
	await ctx.after_regen()

	await ctx.beat("Click TriBall on the selection strip", 0.45)
	await FilmUI.click_button(ctx, "TriBall")
	var ix = ctx.main.interaction
	if ix != null and ix.triball != null and ix.triball.active:
		ix.triball.end_drag()
		ix._on_triball_copy(6, TAU)

	await ctx.beat("Six copies about the ring — bolt circle from one seed", 0.8)
	await ctx.camera.showcase_smooth(1.2, 40.0)
