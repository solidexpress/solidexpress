extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A slider joint leaves one degree of freedom to drag", 1.6)

	await ctx.beat("Place the frame and the slider", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	var frame_body: String = bodies[0] if bodies.size() > 0 else ""
	var slider_body: String = doc.add_box(30, 10, 10, Vector3(60, 0, 0))
	ctx.view.refresh()
	await FilmUI.wait_frames(ctx.tree, 2)

	await ctx.beat("Instance the slider, then joint it to the frame", 0.5)
	ctx.view.select_entity(slider_body, "")
	await FilmUI.click_button(ctx, "Place instance of selection")
	var insts: Array = doc.instance_list()
	if insts.is_empty() or frame_body == "":
		await ctx.beat("Slider did not instance", 0.6)
		return
	var face_a := FilmUI.find_face_by_normal(ctx.view, frame_body, Vector3(1, 0, 0))
	var face_b := FilmUI.find_face_by_normal(ctx.view, slider_body, Vector3(1, 0, 0))
	var jid: String = doc.add_joint("slider", "", face_a, str(insts[0]["id"]), face_b, "Slide")
	if jid == "":
		await ctx.beat("Slider joint needs two planar faces", 0.6)
		return
	await ctx.after_regen()

	await ctx.beat("Drive the free axis — 20 mm out, then home again", 0.5)
	doc.set_joint_value(jid, 20.0)
	ctx.view.refresh()
	await FilmUI.wait_frames(ctx.tree, 3)
	var out_pos: Vector3 = doc.instance_list()[0]["translation"]
	doc.set_joint_value(jid, 0.0)
	ctx.view.refresh()
	await FilmUI.wait_frames(ctx.tree, 3)
	var home: Vector3 = doc.instance_list()[0]["translation"]
	await ctx.beat("Out %.0f mm, home again — driving is absolute" % out_pos.distance_to(home), 0.8)

	# The mechanism the joint belongs to: crank angle to slider position.
	var x0: float = doc.crank_slider_x(20.0, 80.0, 0.0)
	var x90: float = doc.crank_slider_x(20.0, 80.0, PI / 2.0)
	await ctx.beat("Crank 0° → %.1f mm, 90° → %.1f mm" % [x0, x90], 0.8)
	await ctx.camera.showcase_smooth(1.1, 30.0)
