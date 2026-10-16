# Pointer-path contract for film_ubc_wrench: every click and field edit is
# preceded by a pointer move to the same screen point, and scenic stays off.
# Run: tools/godot/godot --headless --path game --script tests/run_film_ubc_wrench_pointer_tests.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const FilmPresentation = preload("res://tests/lib/film_presentation.gd")
const FilmActorScript = preload("res://tests/lib/film_actor.gd")

const SLACK_PX := 8.0


func _init() -> void:
	print("film ubc_wrench pointer path")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("ubc_wrench")
	check(not entry.is_empty(), "ubc_wrench is in the movie manifest")
	if entry.is_empty():
		finish()
		return

	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	check(ctx.chrome != null, "FilmChrome attached")
	check(ctx.actor != null, "FilmActor attached")
	check(ctx.main.presentation_lock, "presentation_lock on")
	check(FilmPresentation.scenic_is_flat(ctx.main), "scenic flat at boot")

	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_ubc_wrench.gd")
	if film == null:
		finish()
		return
	await film.run_film(ctx)
	check(FilmUI.fail_count == 0, "FilmUI.fail_count == 0 (got %d)" % FilmUI.fail_count)

	var log: Array = ctx.actor.action_log if ctx.actor != null else []
	print("  action log %d events" % log.size())
	var n_move := 0
	var n_click := 0
	var n_edit := 0
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
	check(n_click > 0, "at least one click in the action log (got %d)" % n_click)
	check(n_edit > 0, "at least one field edit in the action log (got %d)" % n_edit)
	check(n_move >= n_click, "every click has a pointer_move (%d moves, %d clicks)" % [n_move, n_click])
	var gaps: PackedStringArray = FilmActorScript.pointer_gaps(log, SLACK_PX)
	if not gaps.is_empty():
		for g in gaps:
			printerr("  pointer gap: " + g)
	check(gaps.is_empty(), "every click/edit has a preceding pointer_move within %.0f px (%d gaps)" % [
			SLACK_PX, gaps.size()])
	check(FilmPresentation.scenic_is_flat(ctx.main), "scenic still flat after the film")
	check(not bool(ctx.main.show_scenic_bg), "show_scenic_bg stayed off")
	check(ctx.main.presentation_lock, "presentation_lock held")
	if ctx.view != null and "_scenic_reflections" in ctx.view:
		check(not bool(ctx.view._scenic_reflections), "scenic reflections off")
	finish()
