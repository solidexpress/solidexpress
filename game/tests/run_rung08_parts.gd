# Rung 8 WP2 — kernel fixtures: nut, pipe, wrench .sxp + 3MF checkers.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const NutFix = preload("res://tests/lib/nut_fixture.gd")
const WrenchFix = preload("res://tests/lib/wrench_fixture.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const OUT := "/tmp/sx-rung08-parts"


func _init() -> void:
	print("rung08 parts fixtures")
	FilmUI.reset_fail_count()
	DirAccess.make_dir_recursive_absolute(OUT)
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	listen_status(ctx.main)
	await _nut(ctx)
	await _pipe(ctx)
	await _wrench(ctx)
	check(FileAccess.file_exists(OUT.path_join("nut.sxp"))
			and FileAccess.file_exists(OUT.path_join("pipe.sxp"))
			and FileAccess.file_exists(OUT.path_join("wrench.sxp")),
			"three .sxp on disk")
	check(FilmUI.fail_count == 0, "FilmUI stayed on screen (%d)" % FilmUI.fail_count)
	ctx.main.queue_free()
	finish()


func _nut(ctx: FilmContext) -> void:
	print("- nut")
	ctx.view.new_document()
	await process_frame
	await process_frame
	var body := NutFix.build(ctx.view.doc)
	check(body != "", "nut body (%s)" % ctx.view.doc.last_graph_error())
	if body == "":
		return
	ctx.view.graph_changed()
	for _i in 8:
		await process_frame
	var mf := OUT.path_join("nut.3mf")
	var sxp := OUT.path_join("nut.sxp")
	check(ctx.view.doc.export_3mf(mf), "export nut.3mf")
	check(ctx.view.save(sxp), "save nut.sxp")
	var result := SxChecker.run("rung01", ["nut", mf])
	check(int(result["code"]) == 0, "check_rung01.py nut (got %d)" % int(result["code"]))


func _pipe(ctx: FilmContext) -> void:
	print("- pipe")
	ctx.view.new_document()
	await process_frame
	await process_frame
	var ext := PipeFixture.build_final(ctx.view.doc)
	check(ext != "", "filleted pipe (%s)" % ctx.view.doc.last_graph_error())
	if ext == "":
		return
	ctx.view.graph_changed()
	for _i in 12:
		await process_frame
	var mf := OUT.path_join("pipe.3mf")
	var sxp := OUT.path_join("pipe.sxp")
	check(ctx.view.doc.export_3mf(mf), "export pipe.3mf")
	check(ctx.view.save(sxp), "save pipe.sxp")
	var result := SxChecker.run("rung05", ["final", mf])
	check(int(result["code"]) == 0, "check_rung05.py final (got %d)" % int(result["code"]))


func _wrench(ctx: FilmContext) -> void:
	print("- wrench")
	ctx.view.new_document()
	await process_frame
	await process_frame
	var body := WrenchFix.build(ctx.view.doc)
	check(body != "", "wrench body (%s)" % ctx.view.doc.last_graph_error())
	if body == "":
		return
	ctx.view.graph_changed()
	for _i in 8:
		await process_frame
	var vol := ctx.view.doc.body_volume(body)
	print("V_WRENCH %s" % str(vol))
	var mf := OUT.path_join("wrench.3mf")
	var sxp := OUT.path_join("wrench.sxp")
	check(ctx.view.doc.export_3mf(mf), "export wrench.3mf")
	check(ctx.view.save(sxp), "save wrench.sxp")
	var result := SxChecker.run("rung01", ["wrench", mf])
	check(int(result["code"]) == 0, "check_rung01.py wrench (got %d)" % int(result["code"]))
