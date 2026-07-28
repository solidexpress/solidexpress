# Sketch → 3D workflows driven only through visible UI (pads, chips, tools).
# Covers path merge + sweep, ruled/smooth loft, and loft with guide rails.
# Owns the loft UI coverage formerly in run_film_loft_ui_tests.gd.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_to_3d_ui_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("sketch to 3d ui workflow tests (UI-only)")
	FilmUI.reset_fail_count()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx)

	await test_path_merge_and_sweep_ui(ctx, main)
	await test_single_rail_path_and_sweep_ui(ctx, main)
	await test_one_shot_profile_rail_sweep_ui(ctx, main)
	await test_sweep_requires_explicit_path_ui(ctx, main)
	await test_loft_ruled_ui(ctx, main)
	await test_loft_smooth_ui(ctx, main)
	await test_loft_with_guide_rail_ui(ctx, main)

	check(FilmUI.fail_count == 0,
			"FilmUI had no offscreen/control errors (got %d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _fresh_doc(main) -> SxDocument:
	main.view.new_document()
	main.selected_sketch_pads.clear()
	main.selected_path_fid = ""
	return main.view.doc


func _feature_body_volume(doc: SxDocument, ftype: String) -> Dictionary:
	var fid := FilmUI.last_feature_id(doc, ftype)
	var body := ""
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			body = str(f.get("output_body", ""))
			if body != "":
				vol = doc.body_volume(body)
			break
	return {"fid": fid, "body": body, "volume": vol}


func _hide_body_if_present(ctx: FilmContext, main, body: String) -> void:
	if body == "":
		return
	var any_face := FilmUI.find_face_by_normal(main.view, body, Vector3(0, 0, 1))
	if any_face == "":
		return
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx,
			FilmUI.face_pick_point(main.view, body, any_face)),
			{"keys": "Click", "desc": "Select solid to hide"})
	var hide_btn := FilmUI.find_button(main, "Hide")
	if hide_btn != null and hide_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, hide_btn,
				{"keys": "Hide", "desc": "Hide solid to reach pads"})


## Two open rails on ground → Merge Join chip → circle profile → Sweep Path chip.
func test_path_merge_and_sweep_ui(ctx: FilmContext, main) -> void:
	print("-- path merge + sweep (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	await FilmUI.enter_sketch(ctx)
	# Open L-rail as two segments that meet at a corner (path merge join).
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(16, 0))
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_a.is_empty(), "first rail pad from UI")

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(16, 0), Vector2(16, 14))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_b.is_empty(), "second rail pad from UI")

	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	if main.view != null:
		main.view.refresh_sketch_pads("")
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	check(fid_a in main.selected_sketch_pads, "first rail in multi-select")
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)
	check(fid_b in main.selected_sketch_pads, "second rail in multi-select")
	check(main.selected_sketch_pads.size() >= 2, "two rail pads selected")
	await FilmUI.merge_sketches_ui(ctx, "join_endpoints")
	await ctx.after_regen()
	var path := _feature_body_volume(doc, "path")
	check(path["fid"] != "", "path feature from Merge Join chip")

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not prof_fid.is_empty(), "sweep profile pad")

	await FilmUI.clear_pad_selection(ctx)
	await FilmUI.select_sketch_pad_ctrl(ctx, prof_fid)
	await FilmUI.sweep_along_path_ui(ctx)
	await ctx.after_regen()
	var sw := _feature_body_volume(doc, "sweep")
	check(sw["fid"] != "", "sweep feature from Sweep Path chip")
	check(sw["volume"] > 50.0, "sweep solid volume from UI (got %.1f)" % sw["volume"])


## One open rail → Use as path → profile → Sweep (explicit Path selection).
func test_single_rail_path_and_sweep_ui(ctx: FilmContext, main) -> void:
	print("-- single-rail path + sweep (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(20, 0))
	var rail_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not rail_fid.is_empty(), "single rail pad")

	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	main.selected_path_fid = ""
	await FilmUI.select_sketch_pad_ctrl(ctx, rail_fid)
	var actions: Array = main._sketch_to_3d_actions()
	check(actions.has("use_as_path"), "Use as path chip for single rail")
	check(not actions.has("sweep_path"), "no sweep without profile")
	await FilmUI.merge_sketches_ui(ctx, "use_as_path")
	await ctx.after_regen()
	check(FilmUI.last_feature_id(doc, "path") != "", "path from Use as path")
	check(main.selected_path_fid != "", "Path stays selected after Use as path")

	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await FilmUI.clear_pad_selection(ctx)
	await FilmUI.select_sketch_pad_ctrl(ctx, prof_fid)
	await FilmUI.sweep_along_path_ui(ctx)
	await ctx.after_regen()
	var sw := _feature_body_volume(doc, "sweep")
	check(sw["fid"] != "", "sweep from single-rail Path")
	check(sw["volume"] > 20.0, "single-rail sweep volume (got %.1f)" % sw["volume"])


## Profile + rail selected together → one-shot Sweep (creates Path + solid).
func test_one_shot_profile_rail_sweep_ui(ctx: FilmContext, main) -> void:
	print("-- one-shot profile+rail sweep (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(18, 0))
	var rail_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2.5, 0))
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	main.selected_path_fid = ""
	await FilmUI.select_sketch_pad_ctrl(ctx, prof_fid)
	await FilmUI.select_sketch_pad_ctrl(ctx, rail_fid)
	var actions: Array = main._sketch_to_3d_actions()
	check(actions.has("sweep_path"), "one-shot Sweep chip for profile+rail")
	await FilmUI.sweep_along_path_ui(ctx)
	await ctx.after_regen()
	check(FilmUI.last_feature_id(doc, "path") != "", "one-shot created Path")
	var sw := _feature_body_volume(doc, "sweep")
	check(sw["fid"] != "", "one-shot sweep feature")
	check(sw["volume"] > 20.0, "one-shot sweep volume (got %.1f)" % sw["volume"])


## Profile alone with no Path selected must not offer Sweep (no silent latest-Path).
func test_sweep_requires_explicit_path_ui(ctx: FilmContext, main) -> void:
	print("-- sweep requires explicit path (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	# Leave a stale Path in the document that must NOT auto-bind.
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var rail_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	await FilmUI.select_sketch_pad_ctrl(ctx, rail_fid)
	await FilmUI.merge_sketches_ui(ctx, "use_as_path")
	await ctx.after_regen()
	check(FilmUI.last_feature_id(doc, "path") != "", "stale path exists")
	main.selected_path_fid = ""

	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(3, 0))
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	main.selected_path_fid = ""
	await FilmUI.select_sketch_pad_ctrl(ctx, prof_fid)
	var actions: Array = main._sketch_to_3d_actions()
	check(not actions.has("sweep_path"),
			"Sweep chip hidden without selected Path or rail")


## Ground circle + box-top circle → Loft Ruled chip.
func test_loft_ruled_ui(ctx: FilmContext, main) -> void:
	print("-- loft ruled (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_a.is_empty(), "loft bottom profile pad")

	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	check(not bodies.is_empty(), "box host for loft top")
	var host: String = "" if bodies.is_empty() else str(bodies[bodies.size() - 1])
	var top_face := FilmUI.find_face_by_normal(main.view, host, Vector3(0, 0, 1))
	check(top_face != "", "box top face")
	await FilmUI.enter_sketch_on_face(ctx, host, top_face)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(3, 0))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_b.is_empty(), "loft top profile pad")

	await FilmUI.clear_pad_selection(ctx)
	await _hide_body_if_present(ctx, main, host)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)
	check(main.selected_sketch_pads.size() >= 2, "two loft pads selected")
	await FilmUI.loft_profiles_ui(ctx, true)
	await ctx.after_regen()
	var loft := _feature_body_volume(doc, "loft")
	check(loft["fid"] != "", "loft feature from Loft Ruled chip")
	check(loft["volume"] > 10.0, "ruled loft volume from UI (got %.1f)" % loft["volume"])


## Same pad setup → Loft Smooth chip (different action string / surface mode).
func test_loft_smooth_ui(ctx: FilmContext, main) -> void:
	print("-- loft smooth (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(8, 0))
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	var host: String = "" if bodies.is_empty() else str(bodies[bodies.size() - 1])
	var top_face := FilmUI.find_face_by_normal(main.view, host, Vector3(0, 0, 1))
	await FilmUI.enter_sketch_on_face(ctx, host, top_face)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2.5, 0))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await FilmUI.clear_pad_selection(ctx)
	await _hide_body_if_present(ctx, main, host)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)
	await FilmUI.loft_profiles_ui(ctx, false)
	await ctx.after_regen()
	var loft := _feature_body_volume(doc, "loft")
	check(loft["fid"] != "", "loft feature from Loft Smooth chip")
	check(loft["volume"] > 10.0, "smooth loft volume from UI (got %.1f)" % loft["volume"])


## Two closed profiles + one open rail → Loft Smooth uses the rail as a guide.
func test_loft_with_guide_rail_ui(ctx: FilmContext, main) -> void:
	print("-- loft with guide rail (UI)")
	var doc := _fresh_doc(main)
	var sm: SketchMode = main.sketch_mode

	# Profiles first (same path as ruled/smooth). Guide last — sketching the
	# rail before the face host leaves the camera unable to pick the box face
	# in the headless 64² viewport.
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var fid_bot := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_bot.is_empty(), "guided loft bottom pad")

	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	var host: String = "" if bodies.is_empty() else str(bodies[bodies.size() - 1])
	var top_face := FilmUI.find_face_by_normal(main.view, host, Vector3(0, 0, 1))
	await FilmUI.enter_sketch_on_face(ctx, host, top_face)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(4, 0))
	var fid_top := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_top.is_empty(), "guided loft top pad")
	check(fid_top != fid_bot, "top is distinct from bottom")
	check(main._sketch_pad_role(fid_top) == "profile",
			"top pad classified as profile (got %s)" % main._sketch_pad_role(fid_top))

	# Single-segment open rail outside the bottom circle (keep near origin so the
	# headless 64² viewport can still project the pad for Ctrl+click).
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(18, 16), Vector2(26, 28))
	var fid_guide := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_guide.is_empty(), "guide rail pad")
	check(fid_guide != fid_bot and fid_guide != fid_top,
			"guide is a new sketch (not a profile pad)")
	check(main._sketch_pad_role(fid_guide) == "rail",
			"guide pad classified as rail (got %s)" % main._sketch_pad_role(fid_guide))

	await FilmUI.clear_pad_selection(ctx)
	await _hide_body_if_present(ctx, main, host)
	main.selected_sketch_pads.clear()
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_top)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_guide)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_bot)
	check(fid_top in main.selected_sketch_pads, "top profile selected")
	check(fid_guide in main.selected_sketch_pads, "guide rail selected")
	check(fid_bot in main.selected_sketch_pads, "bottom profile selected")
	var nsel: int = main.selected_sketch_pads.size()
	check(nsel >= 3, "two profiles + guide selected (n=%d have %s)" % [
		nsel, str(main.selected_sketch_pads)])
	var actions: Array = main._sketch_to_3d_actions()
	check(actions.has("loft_smooth") or actions.has("loft_ruled"),
			"loft chips offered with guide in selection (actions=%s)" % str(actions))
	main._refresh_merge_chrome()
	await ctx.tree.process_frame
	await FilmUI.loft_profiles_ui(ctx, false)
	await ctx.after_regen()
	var loft := _feature_body_volume(doc, "loft")
	check(loft["fid"] != "", "guided loft feature from UI")
	var gvol: float = absf(float(loft["volume"]))
	check(gvol > 10.0 and gvol < 1.0e7,
			"guided loft volume from UI sane (got %.1f)" % float(loft["volume"]))
	var has_guides := false
	for f in doc.graph_features():
		if str(f.get("id", "")) != loft["fid"]:
			continue
		var raw: Variant = f.get("params", "{}")
		var parsed: Variant = raw
		if typeof(raw) == TYPE_STRING:
			parsed = JSON.parse_string(str(raw))
		if typeof(parsed) == TYPE_DICTIONARY:
			var guides: Variant = parsed.get("guides", [])
			if typeof(guides) == TYPE_ARRAY:
				for g in guides:
					if str(g) == fid_guide:
						has_guides = true
			if not has_guides and str(parsed).find(fid_guide) >= 0:
				has_guides = true
		break
	check(has_guides, "loft params include guide sketch ref")
