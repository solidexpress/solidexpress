# Rung 6 WP6 — Swept Boss fuses onto a revolved body. Hex-key empty-part stays new.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_sweep.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SPAN := 320.0


func _init() -> void:
	print("rung06 sweep")
	FilmUI.reset_fail_count()
	var ctx := await CandlestickFixture.boot(self, Vector2i(1280, 800))
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	await _zoom(ctx, Vector3(50, 110, 0), SPAN)
	CandlestickFixture.add_revolve_profile(sm.sketch)
	sm.run_solve()
	await process_frame
	sm.finish_revolve(TAU, "new")
	await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "revolve body exists")
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	sm = ctx.main.sketch_mode
	CandlestickFixture.add_path(sm.sketch)
	sm.run_solve()
	var path_fid := await FilmUI.exit_sketch(ctx)
	check(path_fid != "", "path sketch saved")
	OriginPlanes.begin(ctx.main, "Right")
	await process_frame
	sm = ctx.main.sketch_mode
	CandlestickFixture.add_ellipse(sm.sketch)
	sm.run_solve()
	var ell_fid := await FilmUI.exit_sketch(ctx)
	check(ell_fid != "", "ellipse sketch saved")
	var bodies_before := ctx.view.doc.body_ids().size()
	var feats := ctx.view.doc.graph_features().size()
	# A selected body hides the palette (Sweep lives there). Empty selection
	# is the same as a miss-click in the viewport.
	ctx.view.clear_selection()
	ctx.main._update_left_rail()
	await process_frame
	await CandlestickFixture.click_named(self, ctx, "SweepBoss", "Swept Boss")
	await CandlestickFixture.pick_sketch(self, ctx, ell_fid, "Ellipse profile")
	await CandlestickFixture.click_named(self, ctx, "SweepOk", "OK with profile only")
	check(ctx.view.doc.body_ids().size() == bodies_before, "profile-only Ok adds no body")
	await CandlestickFixture.click_named(self, ctx, "SweepBoss", "Swept Boss again")
	await CandlestickFixture.pick_sketch(self, ctx, ell_fid, "Ellipse profile")
	await CandlestickFixture.pick_sketch(self, ctx, path_fid, "Path rail")
	await CandlestickFixture.click_named(self, ctx, "SweepOk", "Sweep OK")
	await process_frame
	await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one fused body (got %d)" % ctx.view.doc.body_ids().size())
	check(ctx.view.doc.graph_features().size() > feats, "timeline gained a sweep")
	var tmp := "user://rung06_sweep.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(ctx.view.doc.export_3mf(path), "export_3mf sweep")
	var result := SxChecker.run("rung06", ["sweep", path])
	check(int(result["code"]) == 0,
			"check_rung06.py sweep exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])
