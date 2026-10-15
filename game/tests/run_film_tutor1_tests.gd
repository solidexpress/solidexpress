# Validation of film_tutor1 end state (kernel + checkers allowed).
# Bbox comes from check_rung03.py params. The feature list is this film's timeline.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

const FEATURES := "sketch 1, extrude 2, sketch 3, extrude 4, sketch 5, extrude 6, fillet 7, fillet 8, Shell 1.0000 mm"
const FILLET_EDGES: Array[int] = [9, 2]
const BBOX_TOL := 0.2


func _init() -> void:
	print("film tutor1")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("tutor1")
	check(not entry.is_empty(), "tutor1 is in the movie manifest")
	if entry.is_empty():
		finish()
		return
	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_tutor1.gd")
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
	check(ctx.view.section_enabled == false, "section is off")
	_assert_features(doc)
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())
	var tmp := OS.get_temp_dir().path_join("sx-film-tutor1-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	check(doc.export_3mf(glob), "export_3mf to %s" % glob)
	var result := SxChecker.run("rung03", ["final", glob])
	var code := int(result["code"])
	var text := str(result["text"])
	check(code == 0, "check_rung03.py final exit %d" % code)
	check(text.contains("29/29 passed"), "checker output contains 29/29 passed")
	finish()


func _bbox_from_params() -> Vector3:
	var result := SxChecker.run("rung03", ["params"])
	check(int(result["code"]) == 0, "check_rung03.py params exit 0")
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) != TYPE_DICTIONARY:
		check(false, "params JSON")
		return Vector3.ZERO
	var part: Variant = parsed.get("PART", {})
	if typeof(part) != TYPE_DICTIONARY:
		check(false, "params PART")
		return Vector3.ZERO
	return Vector3(float(part.get("SIDE", 0.0)), float(part.get("SIDE", 0.0)), float(part.get("TOP", 0.0)))


func _near_bbox(ext: Vector3, want: Vector3) -> bool:
	return absf(ext.x - want.x) <= BBOX_TOL \
			and absf(ext.y - want.y) <= BBOX_TOL \
			and absf(ext.z - want.z) <= BBOX_TOL


func _assert_features(doc: SxDocument) -> void:
	var names := PackedStringArray()
	var feats: Array = doc.graph_features()
	var fillet_edges: Array[int] = []
	for f in feats:
		names.append(str(f.get("name", "")))
		if str(f.get("type", "")) != "fillet":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			fillet_edges.append(-1)
			continue
		var edges: Variant = parsed.get("edges", [])
		fillet_edges.append(edges.size() if typeof(edges) == TYPE_ARRAY else -1)
	var got := ", ".join(names)
	check(got == FEATURES, "feature names (got %s)" % got)
	check(fillet_edges == FILLET_EDGES, "fillet edge counts R5 then R1.5 (got %s)" % str(fillet_edges))
