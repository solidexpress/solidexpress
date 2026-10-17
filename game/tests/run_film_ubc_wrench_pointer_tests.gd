# Pointer-path + camera-credit contract for website films.
# Run: tools/godot/godot --headless --path game --script tests/run_film_ubc_wrench_pointer_tests.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const FilmPresentation = preload("res://tests/lib/film_presentation.gd")
const FilmActorScript = preload("res://tests/lib/film_actor.gd")

const SLACK_PX := 8.0
const FILMS: PackedStringArray = ["ubc_wrench", "loft_guide_rail"]


func _init() -> void:
	print("film pointer path")
	FilmUI.reset_fail_count()
	for id in FILMS:
		await _run_film(id)
	finish()


func _run_film(id: String) -> void:
	print("  film %s" % id)
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry(id)
	check(not entry.is_empty(), "%s is in the movie manifest" % id)
	if entry.is_empty():
		return
	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	check(ctx.chrome != null, "%s FilmChrome attached" % id)
	check(ctx.actor != null, "%s FilmActor attached" % id)
	check(ctx.main.presentation_lock, "%s presentation_lock on" % id)
	check(FilmPresentation.scenic_is_flat(ctx.main), "%s scenic flat at boot" % id)
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load %s" % str(entry.get("script", "")))
	if film == null:
		_teardown(ctx)
		return
	await film.run_film(ctx)
	check(FilmUI.fail_count == 0, "%s FilmUI.fail_count == 0 (got %d)" % [id, FilmUI.fail_count])
	var actor = ctx.actor
	var log: Array = actor.action_log if actor != null else []
	print("    action log %d events" % log.size())
	var n_move := 0
	var n_click := 0
	var n_edit := 0
	var n_cam := 0
	for ev in log:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		match str(ev.get("kind", "")):
			"pointer_move":
				n_move += 1
			"click":
				n_click += 1
			"edit":
				n_edit += 1
			"camera":
				n_cam += 1
	check(n_click > 0, "%s at least one click (got %d)" % [id, n_click])
	check(n_edit > 0, "%s at least one field edit (got %d)" % [id, n_edit])
	check(n_move >= n_click, "%s every click has a pointer_move (%d/%d)" % [id, n_move, n_click])
	var gaps: PackedStringArray = FilmActorScript.pointer_gaps(log, SLACK_PX)
	if not gaps.is_empty():
		for g in gaps:
			printerr("    pointer gap: " + g)
	check(gaps.is_empty(), "%s every click/edit has a preceding pointer_move within %.0f px (%d gaps)" % [
			id, SLACK_PX, gaps.size()])
	if actor != null and actor.has_method("audit_camera"):
		actor.audit_camera("%s end" % id)
	var uncredited: PackedStringArray = actor.camera_uncredited() if actor != null else PackedStringArray()
	if not uncredited.is_empty():
		for u in uncredited:
			printerr("    camera: " + u)
	check(uncredited.is_empty(), "%s no camera change without Actor credit (%d)" % [id, uncredited.size()])
	var cam_gaps: PackedStringArray = FilmActorScript.camera_gaps(log, SLACK_PX)
	if not cam_gaps.is_empty():
		for g in cam_gaps:
			printerr("    camera log: " + g)
	check(cam_gaps.is_empty(), "%s every camera event has pointer + via (%d gaps)" % [id, cam_gaps.size()])
	check(n_cam > 0, "%s at least one credited camera action (got %d)" % [id, n_cam])
	check(FilmPresentation.scenic_is_flat(ctx.main), "%s scenic still flat after the film" % id)
	check(not bool(ctx.main.show_scenic_bg), "%s show_scenic_bg stayed off" % id)
	check(ctx.main.presentation_lock, "%s presentation_lock held" % id)
	if ctx.view != null and "_scenic_reflections" in ctx.view:
		check(not bool(ctx.view._scenic_reflections), "%s scenic reflections off" % id)
	if id == "loft_guide_rail":
		_assert_hull(ctx)
	_teardown(ctx)


func _assert_hull(ctx: FilmContext) -> void:
	if ctx == null or ctx.view == null or ctx.view.doc == null:
		check(false, "hull: missing document")
		return
	var doc: SxDocument = ctx.view.doc
	var loft_id := FilmUI.last_feature_id(doc, "loft")
	check(loft_id != "", "hull loft feature exists")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) != loft_id:
			continue
		var out_body := str(f.get("output_body", ""))
		if out_body != "":
			vol = absf(doc.body_volume(out_body))
		break
	check(vol > 200.0, "hull loft volume > 200 mm³ (got %.1f)" % vol)


func _teardown(ctx: FilmContext) -> void:
	if ctx == null:
		return
	if ctx.chrome != null:
		ctx.chrome.queue_free()
		ctx.chrome = null
	if ctx.main != null:
		ctx.main.queue_free()
		ctx.main = null
	await process_frame
