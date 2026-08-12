extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Demo: Flip Mate Alignment — two faces that would hang inverted with the
## default oppose-normals mate sit face-to-face after Flip (SW assembly video).


func _face_z(doc: SxDocument, body: String, z: float) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		if absf(bb["min"].z - z) < 0.2 and absf(bb["max"].z - z) < 0.2:
			return fid
	return ""


func _hold(ctx: FilmContext, caption: String, frames: int) -> void:
	if ctx.chrome != null:
		ctx.chrome.show_caption(caption)
	await FilmUI.wait_frames(ctx.tree, maxi(frames, 1))


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc
	var panel: AssemblyPanel = ctx.main.assembly_panel
	var cam = ctx.main.camera

	await ctx.movie_toast("Flip Mate Alignment — face two tops together", 0.05)
	await _hold(ctx, "Flip Mate Alignment — oppose vs align face normals", 90)

	view.new_document()
	doc = view.doc
	var base: String = doc.add_box(80, 80, 16, Vector3.ZERO)
	var block: String = doc.add_box(28, 28, 28, Vector3(140, 0, 0))
	var iid: String = doc.add_instance(block, Vector3(20, 20, 70), Vector3(0, 0, 1), 0.0, "Block")
	view.refresh()
	await FilmUI.wait_frames(ctx.tree, 4)
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(40, 20, 30)
		cam.distance = 180.0
		cam.set_view(deg_to_rad(-32.0), deg_to_rad(42.0), false)

	await _hold(ctx, "Base + floating block — mate top to top", 48)
	var base_top := _face_z(doc, base, 16.0)
	var block_top := _face_z(doc, block, 28.0)
	if base_top == "" or block_top == "" or iid == "" or panel == null:
		FilmUI._fail("flip mate film setup failed")
		await _hold(ctx, "Setup failed", 60)
		return

	# Keep Assembly chrome on-screen for click-driven Flip / Add mate.
	panel.visible = true
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16
	panel.offset_right = 280
	panel.offset_top = 80
	panel.offset_bottom = 420
	panel.refresh_lists()
	await FilmUI.wait_frames(ctx.tree, 2)

	# Default (no flip): one orientation against the mate plane.
	await _hold(ctx, "Default mate: normals oppose", 36)
	var mid_opp: String = doc.add_mate(
		"plane_coincident", "", base_top, iid, block_top, 0.0, false, "tops")
	if mid_opp == "" or not doc.solve_mates():
		FilmUI._fail("oppose mate failed")
		return
	view.refresh()
	panel.refresh_lists()
	await _hold(ctx, "Opposed alignment — note which side of the base holds the block", 70)

	doc.remove_mate(mid_opp)
	doc.set_instance_transform(iid, Vector3(20, 20, 70), Vector3(0, 0, 1), 0.0)
	view.refresh()
	panel.refresh_lists()
	await _hold(ctx, "Reset — enable Flip alignment, mate again", 40)

	# Click the real Flip control, then Add mate + two face picks.
	const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
	if panel._flip_check == null or not panel._flip_check.is_visible_in_tree():
		# Panel may be hidden until instances exist — force refresh.
		panel.refresh_lists()
	if panel._flip_check == null:
		FilmUI._fail("Flip alignment control missing")
		return
	panel.visible = true
	panel._flip_check.button_pressed = true
	await FilmUI.click_control(ctx, panel._flip_check,
		FilmUICues.alert("Flip", "Flip Mate Alignment"))
	var add_btn := FilmUI.find_button(panel, "Add mate")
	if not await FilmUI.click_control(ctx, add_btn,
			FilmUICues.alert("Mate", "Add plane coincident mate")):
		return
	view.select_entity(base, base_top)
	await FilmUI.wait_frames(ctx.tree, 6)
	view.select_entity(block, block_top)
	await FilmUI.wait_frames(ctx.tree, 8)
	view.refresh()
	panel.refresh_lists()

	var mates: Array = doc.mate_list()
	if mates.is_empty() or not bool(mates[0].get("flip", false)):
		FilmUI._fail("flipped mate not recorded")
		await _hold(ctx, "Flip mate failed", 60)
		return

	await _hold(ctx, "Flipped — faces meet the other way (SW Flip Mate Alignment)", 90)
	if cam != null:
		await ctx.camera.showcase_smooth(1.2, 28.0)
	await _hold(ctx, "Flip Mate Alignment matches the SW assembly demo", 60)
