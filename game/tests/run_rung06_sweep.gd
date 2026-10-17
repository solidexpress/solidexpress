# Rung 6 WP6 — Swept Boss fuses onto a revolved body. Hex-key empty-part stays new.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_sweep.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SPAN := 320.0


func _init() -> void:
	print("rung06 sweep")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	await _zoom(ctx, Vector3(50, 110, 0), SPAN)
	Rung06Part.add_revolve_profile(sm.sketch)
	sm.run_solve()
	await process_frame
	sm.finish_revolve(TAU, "new")
	await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "revolve body exists")
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	sm = ctx.main.sketch_mode
	Rung06Part.add_path(sm.sketch)
	sm.run_solve()
	var path_fid := await FilmUI.exit_sketch(ctx)
	check(path_fid != "", "path sketch saved")
	OriginPlanes.begin(ctx.main, "Right")
	await process_frame
	sm = ctx.main.sketch_mode
	Rung06Part.add_ellipse(sm.sketch)
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
	await _click_named(ctx, "SweepBoss", "Swept Boss")
	await _pick_sketch(ctx, ell_fid, "Ellipse profile")
	await _click_named(ctx, "SweepOk", "OK with profile only")
	check(ctx.view.doc.body_ids().size() == bodies_before, "profile-only Ok adds no body")
	await _click_named(ctx, "SweepBoss", "Swept Boss again")
	await _pick_sketch(ctx, ell_fid, "Ellipse profile")
	await _pick_sketch(ctx, path_fid, "Path rail")
	await _click_named(ctx, "SweepOk", "Sweep OK")
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


func _click_named(ctx: FilmContext, node_name: String, desc: String) -> void:
	if node_name == "SweepBoss":
		ctx.view.clear_selection()
		ctx.main._update_left_rail()
		await process_frame
	var n: Node = ctx.main.find_child(node_name, true, false)
	check(n is BaseButton, "%s is a button" % node_name)
	if n is BaseButton:
		await FilmUI.click_control(ctx, n as BaseButton, FilmUICues.alert("Click", desc))
	await process_frame


func _pick_sketch(ctx: FilmContext, fid: String, desc: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	var row: Control = tl._rows.get(fid)
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str(child.text) != "":
				btn = child
				break
	check(btn != null, "timeline row for %s" % desc)
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Click", desc))
	await process_frame
