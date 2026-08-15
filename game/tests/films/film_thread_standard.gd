extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Modeled thread from an ISO standard — then edit on the timeline", 1.5)

	await ctx.beat("Place a shaft", 0.4)
	doc.graph_add_primitive("cylinder", 5, 40, 0, Vector3.ZERO)
	await ctx.after_regen()
	var body: String = str(doc.body_ids()[0])
	ctx.view.select_entity(body, "")
	ctx.main._update_panel_visibility()
	await ctx.tree.process_frame

	await ctx.beat("Insert → Thread… (cylinder-like body)", 0.5)
	ctx.main.ops_panel._apply_thread()
	await ctx.after_regen()
	var tid := FilmUI.last_feature_id(doc, "thread")
	if tid == "":
		push_error("thread film: no thread feature")
	else:
		ctx.main.open_feature_params(tid)
		await ctx.tree.process_frame
		await ctx.beat("PropertyPanel opens — pick a standard (M10, UNC…)", 0.8)
	await ctx.camera.showcase_smooth(1.0, 28.0)
