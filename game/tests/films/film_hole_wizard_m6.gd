extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Four M6 holes — mass is steel times volume", 1.6)

	await ctx.beat("Place a plate", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var plate := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == plate:
			body = str(f.get("output_body", ""))
	ctx.view.select_entity(body, "")

	await ctx.beat("Strip Hole — M6 through the plate", 0.45)
	await FilmUI.click_button(ctx, "Hole")
	if plate != "":
		var pts := PackedVector3Array([
			Vector3(15, 15, 50), Vector3(35, 15, 50), Vector3(35, 35, 50), Vector3(15, 35, 50),
		])
		doc.graph_add_holes(plate, "simple", pts, Vector3(0, 0, -1), 6.0, 0.0)
		await ctx.after_regen()
	if body != "":
		doc.set_body_material(body, "Stainless Steel") if doc.has_method("set_body_material") else null
		var mass: Dictionary = doc.measure_mass(body)
		var vol := doc.body_volume(body)
		await ctx.beat("Volume %.0f mm³ — mass follows density × volume" % vol, 0.8)
		if mass.has("mass_g"):
			await ctx.beat("Mass %.2f g" % float(mass["mass_g"]), 0.5)
	await ctx.camera.showcase_smooth(1.2, 36.0)
