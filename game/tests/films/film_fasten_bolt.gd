extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("One fastened mate seats the bolt in the hole", 1.6)

	await ctx.beat("Place the plate and a bolt blank", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.after_regen()

	var bodies: PackedStringArray = doc.body_ids()
	if bodies.size() < 2:
		await ctx.beat("Need two bodies to instance", 0.6)
		return

	await ctx.beat("Instance the bolt and pick Fastened", 0.45)
	ctx.view.select_entity(bodies[1], "")
	await FilmUI.click_button(ctx, "Place instance of selection")
	var type_btn := ctx.main.find_child("MateType", true, false) as OptionButton
	if type_btn != null and type_btn.is_visible_in_tree():
		type_btn.select(0)  # fastened is first
		await FilmUI.wait_frames(ctx.tree, 2)

	var insts: Array = doc.instance_list()
	if insts.is_empty():
		await ctx.beat("Instance did not land", 0.6)
		return
	var hole_faces: PackedStringArray = doc.get_face_ids(bodies[0])
	var bolt_faces: PackedStringArray = doc.get_face_ids(bodies[1])
	var face_a := ""
	var face_b := ""
	for f in hole_faces:
		var c: Dictionary = doc.implicit_connector("", f)
		if not c.is_empty() and str(c.get("name", "")).find("cylinder") >= 0:
			face_a = f
			break
	for f in bolt_faces:
		var c2: Dictionary = doc.implicit_connector(str(insts[0].get("id", "")), f)
		if not c2.is_empty():
			face_b = f
			break
	if face_a == "" and hole_faces.size() > 0:
		face_a = hole_faces[0]
	if face_b == "" and bolt_faces.size() > 0:
		face_b = bolt_faces[0]
	var mid := doc.add_mate("fastened", "", face_a, str(insts[0]["id"]), face_b, 0.0, false, "Bolt")
	doc.solve_mates()

	await ctx.beat("Solve — bolt origin locks to the hole connector", 0.7)
	var seated: Dictionary = doc.implicit_connector(str(insts[0]["id"]), face_b)
	var ground: Dictionary = doc.implicit_connector("", face_a)
	if mid != "" and not seated.is_empty() and not ground.is_empty():
		var d: float = (seated["origin"] as Vector3).distance_to(ground["origin"] as Vector3)
		await ctx.beat("Connector gap %.2f mm — one mate, six DOF" % d, 0.8)
	else:
		await ctx.beat("Fastened mate on the timeline", 0.6)
	await ctx.camera.showcase_smooth(1.2, 40.0)
