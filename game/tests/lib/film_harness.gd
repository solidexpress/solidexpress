## Boots the main scene and loads one film from the movie manifest.
## Smoke and demo tests share the two-frame startup and the load failure reason.
class_name FilmHarness
extends RefCounted

const MANIFEST_PATH := "res://tests/ui_movie_manifest.json"
const _FilmActor := preload("res://tests/lib/film_actor.gd")

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
	attach_overlay(ctx)
	var _pres = preload("res://tests/lib/film_presentation.gd")
	await _pres.apply(ctx)
	if size != Vector2i.ZERO and size != _pres.RESOLUTION:
		await FilmUI.ensure_test_viewport(ctx, size)
	return ctx


## Caption + pointer overlay and the Actor every film action goes through.
static func attach_overlay(ctx: FilmContext) -> void:
	if ctx == null or ctx.tree == null:
		return
	if ctx.chrome == null:
		var chrome := FilmChrome.new()
		ctx.tree.root.add_child(chrome)
		ctx.chrome = chrome
	if ctx.actor == null:
		ctx.actor = _FilmActor.new()
		ctx.actor.bind(ctx)


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
