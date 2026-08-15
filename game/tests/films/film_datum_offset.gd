extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Datum plane with an offset — reference geometry you can place", 1.4)

	await ctx.beat("Insert → Datum Plane XY with offset 15 mm", 0.5)
	ctx.main._pending_datum_id = 0
	if ctx.main._datum_offset != null:
		ctx.main._datum_offset.value = 15.0
	ctx.main._on_datum_offset_confirmed()
	await ctx.after_regen()
	var n: int = doc.datum_list().size()
	await ctx.beat("%d datum(s) in the document" % n, 0.6)
	if n < 1:
		push_error("datum film: expected a datum")
	# Prefer graph-owned datum when the binding exists.
	if doc.has_method("graph_add_datum_plane"):
		var fid: String = doc.graph_add_datum_plane(Vector3(0, 0, 25), Vector3(0, 0, 1))
		await ctx.after_regen()
		if fid != "":
			await ctx.beat("Timeline Datum feature at Z=25", 0.6)
			ctx.main.open_feature_params(fid)
	await ctx.camera.showcase_smooth(0.9, 20.0)
