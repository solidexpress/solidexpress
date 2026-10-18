# Validation of film_candlestick end state (kernel + check_rung06).
# Bbox comes from check_rung06.py PART. The feature list is this film's timeline.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

const FEATURES := "sketch 1, revolve 2, sketch 3, sketch 4, path 5, sweep 6, sketch 7, extrude 8"
const BBOX_TOL := 0.2
const HANDLE_XMAX_MIN := 180.0


func _init() -> void:
	print("film candlestick")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("candlestick")
	check(not entry.is_empty(), "candlestick is in the movie manifest")
	if entry.is_empty():
		finish()
		return
	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_candlestick.gd")
	if film == null:
		finish()
		return
	await film.run_film(ctx)
	check(FilmUI.fail_count == 0, "FilmUI.fail_count == 0 (got %d)" % FilmUI.fail_count)
	var doc: SxDocument = ctx.view.doc
	var bodies: Array = doc.body_ids()
	check(bodies.size() == 1, "exactly one body (got %d)" % bodies.size())
	if bodies.is_empty():
		finish()
		return
	var body := str(bodies[0])
	var bb: Dictionary = doc.measure_bbox(body)
	var ext := Vector3.ZERO
	var xmax := 0.0
	if not bb.is_empty():
		ext = bb["max"] - bb["min"]
		xmax = float((bb["max"] as Vector3).x)
	var want := _bbox_from_params()
	check(_near_bbox(ext, want), "bbox %.1f × %.1f × %.1f within 0.2 (got %s)" % [want.x, want.y, want.z, str(ext)])
	check(xmax >= HANDLE_XMAX_MIN, "handle on +X xmax >= %.0f (got %.1f)" % [HANDLE_XMAX_MIN, xmax])
	_assert_features(doc)
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())
	var tmp := OS.get_temp_dir().path_join("sx-film-candlestick-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	check(doc.export_3mf(glob), "export_3mf to %s" % glob)
	var result := SxChecker.run("rung06", ["final", glob])
	var code := int(result["code"])
	var text := str(result["text"])
	check(code == 0, "check_rung06.py final exit %d\n%s" % [code, text])
	check(text.contains("7/7 passed"), "checker output contains 7/7 passed")
	finish()


func _bbox_from_params() -> Vector3:
	var result := SxChecker.run("rung06", ["params"])
	check(int(result["code"]) == 0, "check_rung06.py params exit 0")
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) != TYPE_DICTIONARY:
		check(false, "params JSON")
		return Vector3.ZERO
	var part: Variant = parsed.get("PART", {})
	if typeof(part) != TYPE_DICTIONARY:
		check(false, "params PART")
		return Vector3.ZERO
	var bmax: Variant = part.get("BBOX_MAX", [])
	var bmin: Variant = part.get("BBOX_MIN", [])
	if typeof(bmax) != TYPE_ARRAY or typeof(bmin) != TYPE_ARRAY \
			or bmax.size() < 3 or bmin.size() < 3:
		check(false, "params BBOX")
		return Vector3.ZERO
	return Vector3(
			float(bmax[0]) - float(bmin[0]),
			float(bmax[1]) - float(bmin[1]),
			float(bmax[2]) - float(bmin[2]))


func _near_bbox(ext: Vector3, want: Vector3) -> bool:
	return absf(ext.x - want.x) <= BBOX_TOL \
			and absf(ext.y - want.y) <= BBOX_TOL \
			and absf(ext.z - want.z) <= BBOX_TOL


func _assert_features(doc: SxDocument) -> void:
	var names := PackedStringArray()
	for f in doc.graph_features():
		names.append(str(f.get("name", "")))
	var got := ", ".join(names)
	check(got == FEATURES, "feature names (got %s)" % got)
