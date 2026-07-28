# Runs one UI film from ui_movie_manifest.json (invoked by scripts/sx-movies).
# Godot CLI: --write-movie out.avi --fixed-fps 60 --quit-after N --script tests/movie_maker_run_one.gd -- --film-id ID [--captions-out path.vtt]
# Quits when the film finishes; --quit-after is a hang safety ceiling only.
extends SceneTree

const MANIFEST_PATH := "res://tests/ui_movie_manifest.json"
# Boot FilmUI before dynamically loaded film scripts (headless cache may omit new class_name).
const _FILM_UI_BOOT := preload("res://tests/lib/film_ui.gd")
const _FILM_CHROME_BOOT := preload("res://tests/lib/film_chrome.gd")


func _init() -> void:
	var film_id := _arg_value("--film-id")
	if film_id.is_empty():
		printerr("movie_maker_run_one: missing --film-id")
		quit(1)
		return

	var manifest: Array = _load_manifest()
	var entry: Dictionary = {}
	for item in manifest:
		if str(item.get("id", "")) == film_id:
			entry = item
			break
	if entry.is_empty():
		printerr("movie_maker_run_one: unknown film id: %s" % film_id)
		quit(1)
		return
	if entry.get("enabled", true) == false:
		print("movie_maker_run_one: film disabled: %s" % film_id)
		quit(0)
		return

	print("film: %s — %s" % [film_id, str(entry.get("title", ""))])

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var chrome := FilmChrome.new()
	chrome.fps = 60.0
	var fixed := _arg_value_from_all("--fixed-fps")
	if not fixed.is_empty():
		chrome.fps = float(fixed)
	root.add_child(chrome)
	await process_frame

	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.camera = FilmCamera.new(main.camera)
	ctx.chrome = chrome
	ctx.clock = FilmClock.new()
	ctx.tree = self
	FilmUI.reset_fail_count()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	if str(OS.get_environment("SX_TEST_WINDOW")).to_lower() not in ["onscreen", "1", "show", "visible"]:
		print("film window: minimized / no-focus (SX_TEST_WINDOW=onscreen to watch)")

	var script_path: String = str(entry.get("script", ""))
	if script_path.is_empty():
		printerr("movie_maker_run_one: no script in manifest entry")
		quit(1)
		return
	var film_script: GDScript = load(script_path) as GDScript
	if film_script == null:
		printerr("movie_maker_run_one: failed to load %s" % script_path)
		quit(1)
		return
	var film: Object = film_script.new()
	if not film.has_method("run_film"):
		printerr("movie_maker_run_one: %s missing run_film(ctx)" % script_path)
		quit(1)
		return

	await film.run_film(ctx)
	# Brief hold so the last caption/showcase is on screen, then stop recording.
	await create_timer(0.6).timeout
	chrome.finish_captions()
	var captions_out := _arg_value("--captions-out")
	if not captions_out.is_empty():
		if chrome.write_webvtt(captions_out):
			print("captions: %s (%d cues)" % [captions_out, chrome.cues.size()])
		else:
			printerr("movie_maker_run_one: failed to write %s" % captions_out)
	print("film done: %s" % film_id)
	if FilmUI.fail_count > 0:
		printerr("movie_maker_run_one: FilmUI reported %d error(s) (offscreen cursor, etc.)" % FilmUI.fail_count)
		await process_frame
		quit(1)
		return
	# quit() can race MovieWriter teardown (double-free on some builds); sx-movies
	# treats a non-zero exit as OK when the AVI was written. --quit-after is only
	# a safety ceiling if a film hangs.
	await process_frame
	await process_frame
	quit(0)


func _load_manifest() -> Array:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		printerr("movie_maker_run_one: cannot read manifest")
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		printerr("movie_maker_run_one: manifest must be a JSON array")
		return []
	return parsed


func _arg_value(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return str(args[i + 1])
	return ""


func _arg_value_from_all(flag: String) -> String:
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return str(args[i + 1])
		if args[i].begins_with(flag + "="):
			return args[i].substr(flag.length() + 1)
	return ""
