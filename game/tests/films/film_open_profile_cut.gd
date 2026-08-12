extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

## Demo: open-profile Extruded Cut with Flip Side to Cut (SW Cut Extrude video).
## Half-space removal — not a thin-wall shortcut.


func _hold(ctx: FilmContext, caption: String, frames: int) -> void:
	if ctx.chrome != null:
		ctx.chrome.show_caption(caption)
	await FilmUI.wait_frames(ctx.tree, maxi(frames, 1))


func _top_face(doc: SxDocument, body: String, z: float) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		if absf(bb["min"].z - z) < 0.3 and absf(bb["max"].z - z) < 0.3:
			return fid
	return ""


func _cut_once(ctx: FilmContext, flip: bool) -> float:
	var view: DocumentView = ctx.view
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var sm: SketchMode = ctx.main.sketch_mode
	view.new_document()
	var doc: SxDocument = view.doc
	# Place via UI so sketch-on-face matches other films.
	await FilmUI.place_primitive_at(ctx, "box", Vector3(40, 30, 0), Vector3(80, 60, 20))
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.is_empty():
		FilmUI._fail("box place failed")
		return -1.0
	var box := bodies[0]
	var top := _top_face(doc, box, 20.0)
	if top == "":
		FilmUI._fail("top face missing")
		return -1.0
	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(40, 30, 10)
		cam.distance = 160.0
		cam.set_view(deg_to_rad(-40.0), deg_to_rad(0.0), false)
		await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.enter_sketch_on_face(ctx, box, top)
	# Divider near mid-width in sketch UV (face local). Keep points near origin
	# so headless framing stays on-screen after Look-at.
	await FilmUI.draw_line(ctx, sm, Vector2(-10, -20), Vector2(-10, 20))
	if chrome != null:
		chrome.set_finish_op("cut")
		chrome.set_finish_end("through_all")
		chrome.set_flip_side(flip)
		chrome.set_extrude_distance(20.0)
		if flip:
			var flip_btn := chrome.flip_side_button()
			if flip_btn != null and flip_btn.is_visible_in_tree():
				await FilmUI.click_control(ctx, flip_btn,
					FilmUICues.alert("Flip", "Flip Side to Cut"))
	await FilmUI.apply_extrude(ctx, 20.0)
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	return doc.body_volume(box)


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Open-profile cut — Flip Side to Cut", 0.05)
	await _hold(ctx, "Open sketch cut removes one side of a divider line", 70)

	await _hold(ctx, "Cut without Flip — one half-space removed", 36)
	var vol: float = await _cut_once(ctx, false)
	if vol < 0.0:
		await _hold(ctx, "Cut failed", 40)
		return
	await _hold(ctx, "Result volume ≈ %.0f mm³" % vol, 55)

	await _hold(ctx, "Again with Flip Side — the other half remains", 40)
	var vol_flip: float = await _cut_once(ctx, true)
	if vol_flip < 0.0:
		await _hold(ctx, "Flip cut failed", 40)
		return
	await _hold(ctx, "Flipped volume ≈ %.0f mm³" % vol_flip, 55)
	if absf(vol - vol_flip) < 500.0:
		FilmUI._fail("Flip Side did not change which material was cut (%.0f vs %.0f)" % [vol, vol_flip])
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.1, 30.0)
	await _hold(ctx, "Matches SW Flip Side to Cut — half-space, not thin wall", 55)
