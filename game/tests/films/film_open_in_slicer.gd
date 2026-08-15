extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Open in Slicer — one 3MF per body, your executable", 1.5)

	await ctx.beat("Two bodies ready for hand-off", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	doc.graph_add_primitive("cylinder", 5, 20, 0, Vector3(40, 0, 0))
	await ctx.after_regen()

	await ctx.beat("Register a dry-run slicer and Open in Slicer", 0.5)
	SlicerSettings.save_settings("/usr/bin/echo", PackedStringArray(["--open"]))
	var res: Dictionary = OpenInSlicer.open_in_slicer(doc, true)
	var files: PackedStringArray = res.get("files", PackedStringArray())
	await ctx.beat("%d per-body 3MF file(s) prepared" % files.size(), 0.7)
	if files.size() != 2:
		push_error("open_in_slicer film: expected 2 files, got %d" % files.size())
	await ctx.camera.showcase_smooth(0.9, 24.0)
