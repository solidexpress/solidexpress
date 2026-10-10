# Validation of film_ubc_wrench end state (kernel + checkers allowed).
# Run: tools/godot/godot --headless --path game --script tests/run_film_ubc_wrench_tests.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const MANIFEST_PATH := "res://tests/ui_movie_manifest.json"
# Walk T=14 mesh /tmp/sx-base/walk/wrench-t14.3mf (film ends after timeline 10→14).
# T=10 checkpoint /tmp/sx-base/walk/wrench.3mf is 43832.52 mm³.
const WRENCH_VOLUME := 63046.0885
const VOL_TOL := 0.005
const DIAG_FAILS := [
	"bbox Z (thickness)",
	"grip slot present at y=0,z=8.75",
	"1mm fillet top outer edge",
	"1mm fillet on jaw top edge",
]


func _init() -> void:
	print("film ubc_wrench")
	FilmUI.reset_fail_count()
	var entry := _manifest_entry("ubc_wrench")
	check(not entry.is_empty(), "ubc_wrench is in the movie manifest")
	if entry.is_empty():
		finish()
		return

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
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))

	var film_script: GDScript = load(str(entry.get("script", ""))) as GDScript
	check(film_script != null and film_script.can_instantiate(), "load film_ubc_wrench.gd")
	if film_script == null or not film_script.can_instantiate():
		finish()
		return
	var film: Object = film_script.new()
	await film.run_film(ctx)
	check(FilmUI.fail_count == 0, "FilmUI.fail_count == 0 (got %d)" % FilmUI.fail_count)

	var doc: SxDocument = ctx.view.doc
	var bodies: Array = doc.body_ids()
	check(bodies.size() == 1, "exactly one body (got %d)" % bodies.size())
	if bodies.is_empty():
		finish()
		return
	var body := str(bodies[0])
	var vol := absf(doc.body_volume(body))
	check(absf(vol - WRENCH_VOLUME) / WRENCH_VOLUME <= VOL_TOL,
			"volume within 0.5%% of walk wrench-t14 (got %.4f want %.4f)" % [vol, WRENCH_VOLUME])
	var bb: Dictionary = doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.z - 14.0) <= 0.2, "thickness 14 mm (got %.3f)" % ext.z)
	_assert_features(doc)
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())

	var tmp := OS.get_temp_dir().path_join("sx-film-ubc-wrench-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	check(doc.export_3mf(glob), "export_3mf to %s" % glob)
	await _run_checker(["thick", glob, "14"], true, "7/7")
	await _run_diag(glob)
	finish()


func _manifest_entry(want_id: String) -> Dictionary:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for item in parsed:
		if str(item.get("id", "")) == want_id:
			return item
	return {}


func _assert_features(doc: SxDocument) -> void:
	var kinds: Array[String] = []
	for f in doc.graph_features():
		var t := str(f.get("type", ""))
		if t == "extrude":
			var parsed = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("op", "")) == "cut":
				var end := str(parsed.get("end", ""))
				kinds.append("cut_face" if end == "to_face" else "cut_blind")
			else:
				kinds.append("extrude")
		else:
			kinds.append(t)
	print("  features: " + ", ".join(kinds))
	check(kinds.size() >= 6, "feature list long enough (got %d)" % kinds.size())
	if kinds.size() < 6:
		return
	check(kinds[0] == "sketch", "0 sketch (got %s)" % kinds[0])
	check(kinds[1] == "extrude", "1 extrude (got %s)" % kinds[1])
	check(kinds[2] == "sketch", "2 sketch (got %s)" % kinds[2])
	check(kinds[3] == "cut_face", "3 cut up-to-surface (got %s)" % kinds[3])
	check(kinds[4] == "sketch", "4 sketch (got %s)" % kinds[4])
	check(kinds[5] == "cut_blind", "5 cut blind (got %s)" % kinds[5])
	var n_fil := 0
	for k in kinds:
		if k == "fillet":
			n_fil += 1
	check(n_fil >= 2, "fillets after the cuts (got %d)" % n_fil)


func _run_checker(args: Array, expect_ok: bool, needle: String) -> String:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	var argv := PackedStringArray()
	argv.append(checker)
	for a in args:
		argv.append(str(a))
	var output: Array = []
	var code := OS.execute("python3", argv, output, true)
	var text := "\n".join(output)
	print(text)
	if expect_ok:
		check(code == 0, "check_rung01.py %s exit %d" % [" ".join(args), code])
	if needle != "":
		check(text.contains(needle), "checker output contains %s" % needle)
	return text


func _run_diag(path: String) -> void:
	var text := await _run_checker(["wrench", path], false, "18/22")
	check(text.contains("DIAG:"), "DIAG header present")
	for name in DIAG_FAILS:
		check(text.contains(name), "by-design DIAG names %s" % name)
