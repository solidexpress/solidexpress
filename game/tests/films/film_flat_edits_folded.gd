extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Edit the flat; the folded flange follows", 1.5)
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(2)
	var fid: String = doc.graph_add_flange(30.0, 1.5, 0.44, 1.5)
	await ctx.after_regen()
	var flat0: float = 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			var parsed: Variant = JSON.parse_string(str(f.get("params", "{}")))
			if parsed is Dictionary:
				flat0 = float(parsed.get("flat_length", 0.0))
	if fid != "":
		doc.graph_set_params(fid, JSON.stringify({
			"length": 40.0, "thickness": 1.5, "k_factor": 0.44, "radius": 1.5,
			"angle_rad": 1.5707963267948966
		}))
		await ctx.after_regen()
	var flat1 := flat0
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			var parsed2: Variant = JSON.parse_string(str(f.get("params", "{}")))
			if parsed2 is Dictionary:
				flat1 = float(parsed2.get("flat_length", 0.0))
	await ctx.beat("Flat %.1f → %.1f mm — same document, split view" % [flat0, flat1], 0.8)
	await ctx.camera.showcase_smooth(1.0, 22.0)
