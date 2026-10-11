# Validation of film_lesson2_box end state (kernel + checkers allowed).
# Volume comes from check_rung02.py params; the feature list is the Lesson 2 timeline.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

const FEATURES := "sketch 1, extrude 2, fillet 3, Shell 5.0000 mm, sketch 5, extrude 6"
const BBOX := Vector3(100.0, 65.0, 50.0)
const BBOX_TOL := 0.2
const VOL_TOL := 0.005


func _init() -> void:
	print("film lesson2_box")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("lesson2_box")
	check(not entry.is_empty(), "lesson2_box is in the movie manifest")
	if entry.is_empty():
		finish()
		return

	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_lesson2_box.gd")
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
	check(_near_bbox(ext), "bbox 100 × 65 × 50 within 0.2 (got %s)" % str(ext))
	var want := _final_volume_65()
	var vol := absf(doc.body_volume(body))
	var rel := 1.0 if want <= 0.0 else absf(vol - want) / want
	check(want > 0.0 and rel <= VOL_TOL,
			"volume within 0.5%% of volumes 65 final (got %.4f want %.4f)" % [vol, want])
	_assert_features(doc)
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())

	var tmp := OS.get_temp_dir().path_join("sx-film-lesson2-box-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	check(doc.export_3mf(glob), "export_3mf to %s" % glob)
	var result := SxChecker.run("rung02", ["final", glob, "--width", "65"])
	var code := int(result["code"])
	var text := str(result["text"])
	check(code == 0, "check_rung02.py final --width 65 exit %d" % code)
	check(text.contains("16/16 passed"), "checker output contains 16/16 passed")
	finish()


func _near_bbox(ext: Vector3) -> bool:
	return absf(ext.x - BBOX.x) <= BBOX_TOL \
			and absf(ext.y - BBOX.y) <= BBOX_TOL \
			and absf(ext.z - BBOX.z) <= BBOX_TOL


func _final_volume_65() -> float:
	var result := SxChecker.run("rung02", ["params"])
	check(int(result["code"]) == 0, "check_rung02.py params exit 0")
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) != TYPE_DICTIONARY:
		check(false, "params JSON")
		return 0.0
	var volumes: Variant = parsed.get("volumes", {})
	if typeof(volumes) != TYPE_DICTIONARY:
		check(false, "params volumes")
		return 0.0
	var row: Variant = volumes.get("65", {})
	if typeof(row) != TYPE_DICTIONARY:
		check(false, "params volumes 65")
		return 0.0
	return float(row.get("final", 0.0))


func _assert_features(doc: SxDocument) -> void:
	var names := PackedStringArray()
	var feats: Array = doc.graph_features()
	var fillet_edges := -1
	var last_extrude_cut := false
	var saw_extrude := false
	for f in feats:
		names.append(str(f.get("name", "")))
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(f.get("type", "")) == "fillet":
			var edges: Variant = parsed.get("edges", [])
			fillet_edges = edges.size() if typeof(edges) == TYPE_ARRAY else -1
		if str(f.get("type", "")) == "extrude":
			saw_extrude = true
			last_extrude_cut = str(parsed.get("op", "")) == "cut" \
					and str(parsed.get("end", "")) == "through_all"
	var got := ", ".join(names)
	check(got == FEATURES, "feature names (got %s)" % got)
	check(fillet_edges == 4, "fillet has 4 edges (got %d)" % fillet_edges)
	check(saw_extrude and last_extrude_cut, "last extrude is a cut with end through_all")
