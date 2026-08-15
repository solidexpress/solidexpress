extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Neighbor grows — the consumer waits until Update Context", 1.6)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Need a neighbor body", 0.5)
		return
	ctx.view.select_entity(bodies[0], "")
	await ctx.beat("Capture the neighbor as a named context", 0.4)
	await ctx.camera.frame_all_smooth(0.0)
	var ix = ctx.main.interaction
	if ix != null and ix.has_method("_open_marking_menu"):
		ix._open_marking_menu(ix._screen_center() if ix.has_method("_screen_center") else Vector2(400, 300))
		await FilmUI.wait_frames(ctx.tree, 3)
		var menu: MarkingMenu = ix.marking_menu
		if menu != null and menu.visible:
			var b := FilmUI.find_button(menu, "In-context pad")
			if b != null:
				await FilmUI.click_control(ctx, b, FilmUI.FilmUICues.alert("S", "In-context pad"))
			else:
				await FilmUI.marking_verb(ctx, "In-context pad")
		else:
			await FilmUI.marking_verb(ctx, "In-context pad")
	else:
		await FilmUI.marking_verb(ctx, "In-context pad")
	await ctx.after_regen()
	var consumer := FilmUI.last_feature_id(doc, "in_context")
	var v0 := 0.0
	if consumer != "":
		for f in doc.graph_features():
			if str(f.get("id", "")) == consumer:
				var body := str(f.get("output_body", ""))
				if body != "":
					var m: Dictionary = doc.measure_mass(body)
					v0 = float(m.get("volume", 0.0))
	var prim := FilmUI.last_feature_id(doc, "primitive")
	if prim != "":
		var p := {"kind": "box", "a": 50.0, "b": 50.0, "c": 40.0}
		for f in doc.graph_features():
			if str(f.get("id", "")) == prim:
				var parsed: Variant = JSON.parse_string(str(f.get("params", "{}")))
				if parsed is Dictionary:
					p = parsed
					p["c"] = 40.0
		doc.graph_set_params(prim, JSON.stringify(p))
		await ctx.after_regen()
	await ctx.beat("Neighbor grew; consumer still %.0f mm³" % v0, 0.7)
	var upd := FilmUI.find_button(ctx.main, "Update Context")
	if upd != null:
		await FilmUI.click_button(ctx, "Update Context")
		await ctx.after_regen()
	await ctx.beat("Update Context — now the pad matches the neighbor", 0.8)
	await ctx.camera.showcase_smooth(1.0, 22.0)
