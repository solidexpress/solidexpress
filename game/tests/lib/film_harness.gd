## Boots the main scene and loads one film from the movie manifest.
## Smoke and demo tests share the two-frame startup and the load failure reason.
class_name FilmHarness
extends RefCounted

const MANIFEST_PATH := "res://tests/ui_movie_manifest.json"

static var load_reason := ""


static func boot(tree: SceneTree, size := Vector2i(0, 0)) -> FilmContext:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.camera = FilmCamera.new(main.camera)
	ctx.clock = FilmClock.new()
	ctx.tree = tree
	var _pres = preload("res://tests/lib/film_presentation.gd")
	if size != Vector2i.ZERO:
		# Override only when a caller asserts a non-default size.
		await FilmUI.ensure_test_viewport(ctx, size)
	else:
		await _pres.apply(ctx)
	return ctx


static func manifest_entry(id: String) -> Dictionary:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for item in parsed:
		if str(item.get("id", "")) == id:
			return item
	return {}


static func load_film(entry: Dictionary) -> Object:
	load_reason = ""
	var script_path := str(entry.get("script", ""))
	var film_script: GDScript = load(script_path) as GDScript
	if film_script == null or not film_script.can_instantiate():
		load_reason = "load script %s" % script_path
		return null
	var film: Object = film_script.new()
	if not film.has_method("run_film"):
		load_reason = "missing run_film"
		return null
	return film
