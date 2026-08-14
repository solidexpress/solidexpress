extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Pull an imported face — DirectEdit stays on the timeline", 1.6)

	await ctx.beat("Place a stand-in import (box primitive)", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var box_fid := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == box_fid:
			body = str(f.get("output_body", ""))
	var vol0 := doc.body_volume(body) if body != "" else 0.0

	await ctx.beat("Commit a DirectEdit pull on the top face", 0.45)
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	if face != "" and box_fid != "":
		doc.graph_add_direct_edit(box_fid, "push_pull", face, 8.0, Vector3(0, 0, 1))
		await ctx.after_regen()

	var vol1 := doc.body_volume(body) if body != "" else 0.0
	var de := FilmUI.last_feature_id(doc, "direct_edit")
	await ctx.beat("Timeline keeps DirectEdit — volume %.0f → %.0f mm³" % [vol0, vol1], 0.9)
	if de == "":
		await ctx.beat("DirectEdit row missing", 0.5)
	await ctx.camera.showcase_smooth(1.2, 32.0)
