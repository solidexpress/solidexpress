extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Drop the bolt on a connector and it fastens itself", 1.6)

	await ctx.beat("Plate on the floor, bolt beside it", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var plate: String = doc.body_ids()[0] if doc.body_ids().size() > 0 else ""
	var bolt: String = doc.add_cylinder(4.0, 20.0, Vector3(90, 0, 0))
	ctx.view.refresh()
	await FilmUI.wait_frames(ctx.tree, 2)

	await ctx.beat("Instance the bolt so it can be assembled", 0.45)
	ctx.view.select_entity(bolt, "")
	await FilmUI.click_button(ctx, "Place instance of selection")
	var insts: Array = doc.instance_list()
	if insts.is_empty() or plate == "":
		await ctx.beat("Bolt did not instance", 0.6)
		return

	await ctx.beat("Drag it over the plate — the connector lights up", 0.5)
	var iid: String = str(insts[0]["id"])
	var bb: Dictionary = doc.measure_bbox(plate)
	var target: Vector3 = Vector3((bb["min"].x + bb["max"].x) * 0.5,
			(bb["min"].y + bb["max"].y) * 0.5, bb["max"].z)
	# Grab the bolt where it is drawn: source geometry offset by the placement.
	var bolt_bb: Dictionary = doc.measure_bbox(bolt)
	var bolt_center: Vector3 = (bolt_bb["min"] + bolt_bb["max"]) * 0.5
	var placement: Vector3 = insts[0]["translation"]
	var from: Vector2 = FilmUI.model_to_screen(ctx, placement + bolt_center)
	var to: Vector2 = FilmUI.model_to_screen(ctx, target)
	var before: int = doc.mate_list().size()
	await FilmUI.viewport_drag(ctx, from, to,
			{"keys": "Drag", "desc": "Drop the bolt on the plate connector"})

	var mates: Array = doc.mate_list()
	if mates.size() > before:
		await ctx.beat("One fastened mate, created by the drop — %d in the tree" % mates.size(), 0.9)
	else:
		await ctx.beat("Bolt moved; drop it onto a planar face to fasten", 0.7)
	await ctx.camera.showcase_smooth(1.1, 30.0)
