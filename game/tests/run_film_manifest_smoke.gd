# Headless smoke: run each enabled film from ui_movie_manifest.json with a per-film frame budget.
# Run: tools/godot/godot --headless --path game --script tests/run_film_manifest_smoke.gd
extends SceneTree

const MANIFEST_PATH := "res://tests/ui_movie_manifest.json"
const _FILM_UI_BOOT := preload("res://tests/lib/film_ui.gd")
const _FILM_CHROME_BOOT := preload("res://tests/lib/film_chrome.gd")
const _FILM_CONTEXT_BOOT := preload("res://tests/lib/film_context.gd")

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
		await _run_one(entry)

	print("%d films, %d failures" % [films_run, failures])
	quit(1 if failures > 0 else 0)


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
	var script_path := str(entry.get("script", ""))
	var budget_frames := int(entry.get("quit_after", 1200)) * 2 + 600
	print("- smoke %s" % film_id)
	FilmUI.reset_fail_count()

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.camera = FilmCamera.new(main.camera)
	ctx.clock = FilmClock.new()
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)

	var film_script: GDScript = load(script_path) as GDScript
	if film_script == null:
		check(false, "%s: load script %s" % [film_id, script_path])
		main.queue_free()
		return
	var film: Object = film_script.new()
	if not film.has_method("run_film"):
		check(false, "%s: missing run_film" % film_id)
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
