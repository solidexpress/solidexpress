# Validation of film_hexkey end state (kernel + check_rung04).
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmHarness = preload("res://tests/lib/film_harness.gd")
const HexKeyFixture = preload("res://tests/lib/hexkey_fixture.gd")


func _init() -> void:
	print("film hexkey")
	FilmUI.reset_fail_count()
	var entry := FilmHarness.manifest_entry("hexkey")
	check(not entry.is_empty(), "hexkey is in the movie manifest")
	if entry.is_empty():
		finish()
		return
	var ctx := await FilmHarness.boot(self, Vector2i(1600, 900))
	var film: Object = FilmHarness.load_film(entry)
	check(film != null, "load film_hexkey.gd")
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
	check(str(doc.last_graph_error()) == "", "last_graph_error empty (got %s)" % doc.last_graph_error())
	var result := HexKeyFixture.check_final(doc)
	check(bool(result["exported"]), "export_3mf")
	check(int(result["code"]) == 0, "check_rung04.py final exit %d\n%s" % [int(result["code"]), str(result["text"])])
	check(str(result["text"]).contains("5/5 passed"), "checker output contains 5/5 passed")
	finish()
