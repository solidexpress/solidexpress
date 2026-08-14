extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await ctx.movie_toast("Concentric + weak dim — the hole stays centered", 1.6)

	await ctx.beat("Sketch an outer circle and a hole", 0.45)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(20, 0))
	await FilmUI.draw_circle(ctx, sm, Vector2(2, 1), Vector2(5, 1))
	var sk: SxSketch = sm.sketch if sm != null else null
	if sk != null:
		var ids: PackedStringArray = sk.entity_ids()
		var circles: Array = []
		for id in ids:
			var info: Dictionary = sk.entity_info(id)
			if str(info.get("type", "")) == "circle":
				circles.append(id)
		if circles.size() >= 2:
			var refs := [
				{"entity": circles[0], "role": "center"},
				{"entity": circles[1], "role": "center"},
			]
			var cid := sk.add_constraint("concentric", refs, 0.0)
			var weak := sk.add_constraint("distance", refs, 6.0)
			if weak != "":
				sk.set_constraint_weak(weak, true)
			var solved: Dictionary = sk.solve()
			await ctx.beat("Concentric holds; weak dim yields — DOF %s" % str(solved.get("dofs", "?")), 0.9)
			if cid == "":
				await ctx.beat("Concentric missing", 0.4)
	await FilmUI.exit_sketch(ctx)
	await ctx.camera.showcase_smooth(1.1, 28.0)
