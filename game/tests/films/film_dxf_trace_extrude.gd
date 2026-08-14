extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("DXF trace → extrude — no extra library", 1.6)

	await ctx.beat("Write a rectangle DXF and import it", 0.45)
	var path := "user://film_rect.dxf"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("0\nSECTION\n2\nENTITIES\n"
				+ "0\nLINE\n10\n0\n20\n0\n11\n40\n21\n0\n"
				+ "0\nLINE\n10\n40\n20\n0\n11\n40\n21\n30\n"
				+ "0\nLINE\n10\n40\n20\n30\n11\n0\n21\n30\n"
				+ "0\nLINE\n10\n0\n20\n30\n11\n0\n21\n0\n"
				+ "0\nENDSEC\n0\nEOF\n")
		f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	var sk_fid := doc.import_dxf(abs_path)
	await ctx.after_regen()

	await ctx.beat("Extrude the imported profile", 0.45)
	if sk_fid != "":
		doc.graph_add_extrude_end(sk_fid, 10.0, "blind", "new", "")
		await ctx.after_regen()
	var ex := FilmUI.last_feature_id(doc, "extrude")
	var vol := 0.0
	for feat in doc.graph_features():
		if str(feat.get("id", "")) == ex:
			var body := str(feat.get("output_body", ""))
			if body != "":
				vol = doc.body_volume(body)
	await ctx.beat("DXF rectangle extruded — %.0f mm³" % vol, 0.8)
	await ctx.camera.showcase_smooth(1.2, 30.0)
