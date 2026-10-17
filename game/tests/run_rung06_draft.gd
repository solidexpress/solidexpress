# Rung 6 WP8 — Extrude Cut Blind 25, Draft On 15 inward.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_draft.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SPAN := 320.0


func _init() -> void:
	print("rung06 draft")
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
	sm.finish_revolve(TAU, "new")
	await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "revolve body exists")
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	sm = ctx.main.sketch_mode
	Rung06Part.add_path(sm.sketch)
	sm.run_solve()
	var path_fid := await FilmUI.exit_sketch(ctx)
	OriginPlanes.begin(ctx.main, "Right")
	await process_frame
	sm = ctx.main.sketch_mode
	Rung06Part.add_ellipse(sm.sketch)
	sm.run_solve()
	var ell_fid := await FilmUI.exit_sketch(ctx)
	await _click_named(ctx, "SweepBoss", "Swept Boss")
	await _pick_sketch(ctx, ell_fid, "Ellipse")
	await _pick_sketch(ctx, path_fid, "Path")
	await _click_named(ctx, "SweepOk", "Sweep OK")
	await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "fused body before cut")
	var top := _top_disc(ctx)
	check(str(top.get("face", "")) != "", "top disc face at y=220")
	if str(top.get("face", "")) != "":
		await FilmUI.enter_sketch_on_face(ctx, str(top["body"]), str(top["face"]))
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "face sketch on the top disc")
	sm.sketch.add_circle(0.0, 0.0, 15.0)
	sm.run_solve()
	await process_frame
	var sk_fid := sm.exit_sketch()
	check(sk_fid != "", "Ø30 face sketch saved")
	sm.target_fid = ""
	sm.support_host = ""
	sm.host_face_id = ""
	check(sm.begin_edit(sk_fid), "pencil reopens the cut sketch")
	check(sm.target_fid != "", "begin_edit restores the cut target")
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_draft_on(true)
	chrome.set_draft_deg(15.0)
	check(absf(chrome.draft_deg() - 15.0) <= 0.05, "draft 15 on")
	sm.finish_extrude(25.0, "cut", "blind", 0.0, "one_side", false, [], 15.0, true)
	await process_frame
	check(not sm.active, "cut finished")
	check(ctx.view.doc.body_ids().size() == 1, "one body after cut")
	var tmp := "user://rung06_final.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(ctx.view.doc.export_3mf(path), "export_3mf final")
	var result := SxChecker.run("rung06", ["final", path])
	check(int(result["code"]) == 0,
			"check_rung06.py final exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])
	# 75° refuse.
	await FilmUI.enter_sketch(ctx)
	sm = ctx.main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	var feats := ctx.view.doc.graph_features().size()
	chrome.set_draft_on(true)
	chrome.set_draft_deg(75.0)
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [], 75.0, true)
	await process_frame
	check(sm.active, "75° draft keeps the sketch open")
	check(ctx.view.doc.graph_features().size() == feats, "timeline unchanged on 75°")
	check(str(ctx.main.status_label.text).to_lower().contains("draft"),
			"refuse names draft (%s)" % ctx.main.status_label.text)


func _top_disc(ctx: FilmContext) -> Dictionary:
	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	if bodies.is_empty():
		return {}
	var body := str(bodies[0])
	var best := ""
	var best_y := -INF
	for face in ctx.view.faces_matching(body, Vector3.UP, 0.99):
		var c: Vector3 = face.get("centre", Vector3.ZERO)
		if c.y > best_y:
			best_y = c.y
			best = str(face.get("id", ""))
	return {"body": body, "face": best, "y": best_y}


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
