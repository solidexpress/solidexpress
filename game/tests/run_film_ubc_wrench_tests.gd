# Validation of film_ubc_wrench end state (kernel + checkers allowed).
# Run: tools/godot/godot --headless --path game --script tests/run_film_ubc_wrench_tests.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const FilmPresentation = preload("res://tests/lib/film_presentation.gd")
const FilmActorScript = preload("res://tests/lib/film_actor.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
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
	var entry := FilmHarness.manifest_entry("ubc_wrench")
	check(not entry.is_empty(), "ubc_wrench is in the movie manifest")
	if entry.is_empty():
		finish()
		return

	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_ubc_wrench.gd")
	if film == null:
		finish()
		return
	SxUi.trace_enabled_override = true
	if ctx.main != null and ctx.main.interaction != null:
		ctx.main.interaction.press_trace_log.clear()
	SxUi.key_trace_log.clear()
	await film.run_film(ctx)
	SxUi.trace_enabled_override = null
	check(FilmUI.fail_count == 0, "FilmUI.fail_count == 0 (got %d)" % FilmUI.fail_count)
	var actor = FilmActorScript.of(ctx)
	var gaps: PackedStringArray = FilmActorScript.pointer_gaps(actor.action_log)
	check(gaps.is_empty(), "pointer precedes every click/edit (%d gaps)" % gaps.size())
	check(FilmPresentation.scenic_is_flat(ctx.main), "scenic background stayed flat")
	_assert_click_budget(ctx)

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


func _assert_click_budget(ctx: FilmContext) -> void:
	var clicks := 0
	if ctx != null and ctx.main != null and ctx.main.interaction != null:
		for line in ctx.main.interaction.press_trace_log:
			if str(line).contains(" press "):
				clicks += 1
	var keys := 0
	for line in SxUi.key_trace_log:
		var s := str(line)
		if s.contains("pressed=1") and s.contains("echo=0"):
			keys += 1
	var repo := ProjectSettings.globalize_path("res://").simplify_path().get_base_dir()
	var raw := FileAccess.get_file_as_string(repo.path_join("packaging/ci/click_budget.json"))
	var data = JSON.parse_string(raw)
	var cap := 129
	if typeof(data) == TYPE_DICTIONARY:
		var row: Variant = data.get("ubc_wrench", {})
		if typeof(row) == TYPE_DICTIONARY:
			cap = int(row.get("max_actions", 129))
	var actions := clicks + keys
	print("  click budget ubc_wrench: %dC %dK = %d (budget %d)" % [clicks, keys, actions, cap])
	check(actions <= cap, "click budget %dC %dK = %d (budget %d)" % [clicks, keys, actions, cap])


func _assert_features(doc: SxDocument) -> void:
	var kinds: Array[String] = []
	for f in doc.graph_features():
		var t := str(f.get("type", ""))
		if t == "extrude":
			var parsed = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("op", "")) == "cut":
				var end := str(parsed.get("end", ""))
				if end == "through_all":
					kinds.append("cut_through")
				elif end == "to_face":
					kinds.append("cut_face")
				else:
					kinds.append("cut_blind")
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
	check(kinds[3] == "cut_through", "3 cut through all (got %s)" % kinds[3])
	check(kinds[4] == "sketch", "4 sketch (got %s)" % kinds[4])
	check(kinds[5] == "cut_blind", "5 cut blind (got %s)" % kinds[5])
	var n_fil := 0
	for k in kinds:
		if k == "fillet":
			n_fil += 1
	check(n_fil >= 2, "fillets after the cuts (got %d)" % n_fil)


func _run_checker(args: Array, expect_ok: bool, needle: String) -> String:
	var result := SxChecker.run("rung01", args)
	var code := int(result["code"])
	var text := str(result["text"])
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
