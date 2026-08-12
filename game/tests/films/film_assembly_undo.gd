extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Demo: assembly undo — place instance, mate with Flip, then Ctrl+Z rewinds
## both gestures (SW series mistake→undo forgiveness).


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

	await ctx.movie_toast("Assembly undo — place, mate, Flip, rewind", 0.05)
	await _hold(ctx, "Assembly undo — mistake → Ctrl+Z forgiveness", 80)

	view.new_document()
	doc = view.doc
	var base: String = doc.add_box(80, 80, 16, Vector3.ZERO)
	var block: String = doc.add_box(28, 28, 28, Vector3(140, 0, 0))
	view.refresh()
	await FilmUI.wait_frames(ctx.tree, 4)
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(40, 20, 30)
		cam.distance = 180.0
		cam.set_view(deg_to_rad(-32.0), deg_to_rad(42.0), false)

	await _hold(ctx, "Place a floating block instance", 36)
	var iid: String = doc.add_instance(block, Vector3(20, 20, 70), Vector3(0, 0, 1), 0.0, "Block")
	if iid == "":
		FilmUI._fail("place instance failed")
		return
	view.refresh()
	if panel != null:
		panel.visible = true
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.offset_left = 16
		panel.offset_right = 280
		panel.offset_top = 80
		panel.offset_bottom = 420
		panel.refresh_lists()
	await _hold(ctx, "Instance placed — next: Flip mate to the base", 48)

	var base_top := _face_z(doc, base, 16.0)
	var block_top := _face_z(doc, block, 28.0)
	if base_top == "" or block_top == "":
		FilmUI._fail("assembly undo film setup failed")
		return

	await _hold(ctx, "Add Flip Mate Alignment (tops together)", 36)
	var mid: String = doc.add_mate(
		"plane_coincident", "", base_top, iid, block_top, 0.0, true, "tops")
	if mid == "":
		FilmUI._fail("flip mate failed")
		return
	view.refresh()
	if panel != null:
		panel.refresh_lists()
	await _hold(ctx, "Mated with Flip — note the block pose", 70)

	await _hold(ctx, "Undo mate (Ctrl+Z) — flip + solve rewind", 40)
	if not doc.undo():
		FilmUI._fail("undo mate failed")
		return
	view.refresh()
	if panel != null:
		panel.refresh_lists()
	if not doc.mate_list().is_empty():
		FilmUI._fail("mate still present after undo")
		return
	await _hold(ctx, "Mate gone — instance back in the air", 60)

	await _hold(ctx, "Undo place — instance disappears", 36)
	if not doc.undo():
		FilmUI._fail("undo place failed")
		return
	view.refresh()
	if panel != null:
		panel.refresh_lists()
	if not doc.instance_list().is_empty():
		FilmUI._fail("instance still present after undo")
		return
	await _hold(ctx, "Assembly edits are undoable — SW-style forgiveness", 80)
	if cam != null:
		await ctx.camera.showcase_smooth(1.0, 24.0)
	await _hold(ctx, "Assembly undo shipped", 48)
