extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

## UI: sized plate + Place-hole… near corners (magnet → edge-inset by inferred X).


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc

	await ctx.movie_toast("Precision plate — corner snaps inset holes from the edge", 1.9)

	await ctx.beat("Place a 100×80×10 mm plate", 0.45)
	# Drop at plate center so origin lands at (0,0,0).
	await FilmUI.place_primitive_at(ctx, "box", Vector3(50, 40, 0), Vector3(100, 80, 10))
	await ctx.after_regen()

	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Plate place failed", 1.0)
		return
	var body := str(bodies[0])
	var vol0 := absf(doc.body_volume(body))
	if vol0 < 70000.0:
		await ctx.beat("Unexpected plate volume %.0f" % vol0, 1.0)
		return

	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(50, 40, 5)
		cam.distance = 160.0
		cam.set_view(deg_to_rad(-28.0), deg_to_rad(42.0), false)
		await FilmUI.wait_frames(ctx.tree, 2)

	await ctx.beat("Select the top face", 0.35)
	var top := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	if top == "":
		await ctx.beat("Top face not found", 1.0)
		return
	await FilmUI.select_face(ctx, body, top)
	var look_btn := FilmUI.find_button(ctx.main, "Look at")
	if look_btn != null and look_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, look_btn,
				FilmUICues.alert("Look at", "Orient camera to the top face"))
		await FilmUI.wait_frames(ctx.tree, 2)

	var ops: OpsPanel = ctx.main.ops_panel
	if ops == null or not ops.visible:
		await ctx.beat("Modify panel not visible", 1.0)
		return

	await ctx.beat("Set hole Ø 6 mm — Inset auto-fills from Ø, thickness, material", 0.5)
	if not await FilmUI.set_labeled_spin(ctx, ops, "Hole Ø", 6.0, "Hole diameter 6 mm"):
		return
	await FilmUI.wait_frames(ctx.tree, 1)
	var inset_spin := FilmUI.find_labeled_spin(ops, "Inset")
	var inset := inset_spin.value if inset_spin != null else 8.0
	await ctx.beat("Inset %.1f mm from each edge at corners" % inset, 0.4)

	# Click near each corner so Place hole… magnets, then insets inward.
	var near_corners: Array[Vector3] = [
		Vector3(2, 2, 10),
		Vector3(98, 2, 10),
		Vector3(2, 78, 10),
		Vector3(98, 78, 10),
	]
	var n := 0
	for pos in near_corners:
		n += 1
		top = FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
		if top == "":
			FilmUI._fail("top face lost after hole %d" % (n - 1))
			return
		if ctx.view.selected_face != top:
			await FilmUI.select_face(ctx, body, top)
		var place_btn := FilmUI.find_button(ops, "Arm: click a point")
		if place_btn == null:
			place_btn = FilmUI.find_button(ops, "near corner")
		if not await FilmUI.click_control(ctx, place_btn,
				FilmUICues.alert("Place hole…", "Arm — click near corner %d" % n)):
			return
		await FilmUI.wait_frames(ctx.tree, 1)
		var screen := FilmUI.model_to_screen(ctx, pos)
		if not FilmUI.is_on_screen(ctx, screen):
			await ctx.beat("Corner %d off screen" % n, 0.8)
			return
		await FilmUI.viewport_click(ctx, screen,
				FilmUICues.alert("Click", "Snap near corner %d → inset" % n))
		await ctx.after_regen()
		await ctx.beat("Hole %d of 4" % n, 0.3)

	var vol := absf(doc.body_volume(body))
	var hole_count := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "hole":
			hole_count += 1
	if hole_count < 4:
		FilmUI._fail("expected 4 holes, got %d (vol %.0f)" % [hole_count, vol])
		await ctx.beat("Hole placement failed — %d of 4" % hole_count, 1.2)
		return

	await ctx.beat("Finished plate — %.0f mm³" % vol, 0.7)
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(50, 40, 5)
		cam.distance = 150.0
	await ctx.camera.showcase_smooth(1.6, 48.0)
