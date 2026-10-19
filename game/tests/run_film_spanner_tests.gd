# Validation of film_spanner end state (kernel + check_rung07).
# Bbox comes from check_rung07.py PART. The feature list is this film's timeline.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")

const FEATURES := ""
const BBOX_TOL := 0.2


func _init() -> void:
	print("film spanner")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("spanner")
	check(not entry.is_empty(), "spanner is in the movie manifest")
	if entry.is_empty():
		finish()
		return
	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_spanner.gd")
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
	var xmin := 0.0
	var xmax := 0.0
	if not bb.is_empty():
		ext = bb["max"] - bb["min"]
		xmin = float((bb["min"] as Vector3).x)
		xmax = float((bb["max"] as Vector3).x)
	var want := _bbox_from_params()
	var handle_min := float(SpannerFixture.part().get("PART", {}).get("HANDLE_XMAX_MIN", 250.0))
	var open_max := float(SpannerFixture.part().get("PART", {}).get("OPEN_XMIN_MAX", -24.5))
	check(_near_bbox(ext, want), "bbox %.3f × %.3f × %.3f within 0.2 (got %s)" % [want.x, want.y, want.z, str(ext)])
	check(xmax >= handle_min, "handle on +X xmax >= %.1f (got %.1f)" % [handle_min, xmax])
	check(xmin <= open_max, "open end on −X xmin <= %.1f (got %.1f)" % [open_max, xmin])
	_assert_features(doc)
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())
	var tmp := OS.get_temp_dir().path_join("sx-film-spanner-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	check(doc.export_3mf(glob), "export_3mf to %s" % glob)
	var result := SxChecker.run("rung07", ["final", glob])
	var code := int(result["code"])
	var text := str(result["text"])
	check(code == 0, "check_rung07.py final exit %d\n%s" % [code, text])
	check(text.contains("8/8 passed"), "checker output contains 8/8 passed")
	finish()


func _bbox_from_params() -> Vector3:
	var table: Variant = SpannerFixture.part().get("PART", {})
	if typeof(table) != TYPE_DICTIONARY:
		check(false, "params PART")
		return Vector3.ZERO
	var size: Variant = table.get("BBOX_SIZE", [])
	if typeof(size) == TYPE_ARRAY and size.size() >= 3:
		return Vector3(float(size[0]), float(size[1]), float(size[2]))
	var bmax: Variant = table.get("BBOX_MAX", [])
	var bmin: Variant = table.get("BBOX_MIN", [])
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
	print("PIN FEATURES := \"%s\"" % got)
	if FEATURES == "":
		return
	check(got == FEATURES, "feature names (got %s)" % got)
