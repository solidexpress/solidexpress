extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Drawing dim follows a parameter edit", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	var d0 := 0.0
	if not bodies.is_empty():
		doc.ensure_drawing_sheet()
		doc.add_drawing_dim(bodies[0], "")
		d0 = float(doc.drawing_preview().get("dims", [{}])[0].get("value", 0.0)) if \
				not (doc.drawing_preview().get("dims", []) as Array).is_empty() else 0.0
	var fid := FilmUI.last_feature_id(doc, "primitive")
	if fid != "":
		var p := {"kind": "box", "a": 55.0, "b": 50.0, "c": 50.0}
		for f in doc.graph_features():
			if str(f.get("id", "")) == fid:
				var parsed: Variant = JSON.parse_string(str(f.get("params", "{}")))
				if parsed is Dictionary:
					p = parsed
					p["a"] = 55.0
		doc.graph_set_params(fid, JSON.stringify(p))
		await ctx.after_regen()
		doc.refresh_drawing_dims()
	var d1 := d0
	var dims: Array = doc.drawing_preview().get("dims", [])
	if not dims.is_empty():
		d1 = float(dims[0].get("value", 0.0))
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(1)
	await ctx.beat("Associative width %.1f → %.1f mm" % [d0, d1], 0.8)
	await ctx.camera.showcase_smooth(1.0, 24.0)
