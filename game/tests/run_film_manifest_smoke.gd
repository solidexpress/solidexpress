# Headless smoke: run each enabled film from ui_movie_manifest.json with a per-film frame budget.
# Run: tools/godot/godot --headless --path game --script tests/run_film_manifest_smoke.gd
extends SceneTree

const MANIFEST_PATH := "res://tests/ui_movie_manifest.json"
const _FILM_UI_BOOT := preload("res://tests/lib/film_ui.gd")
const _FILM_CHROME_BOOT := preload("res://tests/lib/film_chrome.gd")
const _FILM_CONTEXT_BOOT := preload("res://tests/lib/film_context.gd")
const _FILM_HARNESS := preload("res://tests/lib/film_harness.gd")

var failures := 0
var films_run := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film manifest smoke tests")
	var manifest: Array = _load_manifest()
	if manifest.is_empty():
		printerr("  FAIL - manifest empty or unreadable")
		quit(1)
		return

	for entry in manifest:
		if entry.get("enabled", true) == false:
			continue
		var film_id := str(entry.get("id", ""))
		if film_id.is_empty():
			continue
		if _suite_owns(film_id):
			print("- smoke skip %s owned by film_%s_tests" % [film_id, film_id])
			continue
		await _run_one(entry)

	print("%d films, %d failures" % [films_run, failures])
	quit(1 if failures > 0 else 0)


func _suite_owns(film_id: String) -> bool:
	var root := ProjectSettings.globalize_path("res://")
	var path := root.path_join("../packaging/ci/suites.d/film_%s_tests.suite" % film_id)
	return FileAccess.file_exists(path)


func _load_manifest() -> Array:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func _run_one(entry: Dictionary) -> void:
	var film_id := str(entry.get("id", ""))
	var budget_frames := int(entry.get("quit_after", 1200)) * 2 + 600
	print("- smoke %s" % film_id)
	FilmUI.reset_fail_count()

	var ctx := await FilmHarness.boot(self)
	var main = ctx.main
	# A script with a parse error still loads as a GDScript but cannot be
	# instantiated; without this guard the film was skipped silently.
	var film: Object = FilmHarness.load_film(entry)
	if film == null:
		check(false, "%s: %s" % [film_id, FilmHarness.load_reason])
		main.queue_free()
		return

	var state := {"done": false}
	_execute_film(film, ctx, state)

	var frames := 0
	while not state.done and frames < budget_frames:
		await process_frame
		frames += 1

	if not state.done:
		check(false, "%s: timed out after %d frames" % [film_id, budget_frames])
	else:
		check(true, "%s: finished" % film_id)
		films_run += 1
	check(FilmUI.fail_count == 0,
			"%s: no FilmUI offscreen/control errors (got %d)" % [film_id, FilmUI.fail_count])

	main.queue_free()
	await process_frame


func _execute_film(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
