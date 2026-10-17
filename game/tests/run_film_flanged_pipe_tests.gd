# Validation of film_flanged_pipe end state (kernel + check_rung05).
# Bbox comes from check_rung05.py PART. The feature list is this film's timeline.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

const FEATURES := "sketch 1, extrude 2, Shell 10.0000 mm, sketch 4, extrude 5, sketch 6, extrude 7, mirror 8, Shell 10.0000 mm 2, fillet 10"
const FILLET_EDGES := 4
const BBOX_TOL := 0.2


func _init() -> void:
	print("film flanged_pipe")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("flanged_pipe")
	check(not entry.is_empty(), "flanged_pipe is in the movie manifest")
	if entry.is_empty():
		finish()
		return
	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_flanged_pipe.gd")
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
	if not bb.is_empty():
		ext = bb["max"] - bb["min"]
	var want := _bbox_from_params()
	check(_near_bbox(ext, want), "bbox %.0f × %.0f × %.0f within 0.2 (got %s)" % [want.x, want.y, want.z, str(ext)])
	_assert_features(doc)
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())
	var tmp := OS.get_temp_dir().path_join("sx-film-flanged-pipe-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	check(doc.export_3mf(glob), "export_3mf to %s" % glob)
	var result := SxChecker.run("rung05", ["final", glob])
	var code := int(result["code"])
	var text := str(result["text"])
	check(code == 0, "check_rung05.py final exit %d\n%s" % [code, text])
	check(text.contains("10/10 passed"), "checker output contains 10/10 passed")
	finish()


func _bbox_from_params() -> Vector3:
	var result := SxChecker.run("rung05", ["params"])
	check(int(result["code"]) == 0, "check_rung05.py params exit 0")
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) != TYPE_DICTIONARY:
		check(false, "params JSON")
		return Vector3.ZERO
	var part: Variant = parsed.get("PART", {})
	if typeof(part) != TYPE_DICTIONARY:
		check(false, "params PART")
		return Vector3.ZERO
	var fd := float(part.get("FLANGE_D", 0.0))
	var bmax: Variant = part.get("BBOX_MAX", [])
	var bmin: Variant = part.get("BBOX_MIN", [])
	var z := 0.0
	if typeof(bmax) == TYPE_ARRAY and typeof(bmin) == TYPE_ARRAY \
			and bmax.size() >= 3 and bmin.size() >= 3:
		z = float(bmax[2]) - float(bmin[2])
	return Vector3(fd, fd, z)


func _near_bbox(ext: Vector3, want: Vector3) -> bool:
	return absf(ext.x - want.x) <= BBOX_TOL \
			and absf(ext.y - want.y) <= BBOX_TOL \
			and absf(ext.z - want.z) <= BBOX_TOL


func _assert_features(doc: SxDocument) -> void:
	var names := PackedStringArray()
	var feats: Array = doc.graph_features()
	var fillet_edges := -1
	for f in feats:
		names.append(str(f.get("name", "")))
		if str(f.get("type", "")) != "fillet":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			fillet_edges = -1
			continue
		var edges: Variant = parsed.get("edges", [])
		fillet_edges = edges.size() if typeof(edges) == TYPE_ARRAY else -1
	var got := ", ".join(names)
	check(got == FEATURES, "feature names (got %s)" % got)
	check(fillet_edges == FILLET_EDGES, "fillet edge count (got %d)" % fillet_edges)
