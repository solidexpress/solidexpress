# Click-driven coverage for UI buttons that other suites skip (selection strip
# booleans, extra palette kinds, merge spline, sketch-rail tools, Extrude Cut).
# Run: tools/godot/godot --headless --path game --script tests/run_ui_button_coverage_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0
var checks := 0
var results: Array[Dictionary] = []


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func record(button: String, worked: bool, detail: String = "") -> void:
	results.append({"button": button, "ok": worked, "detail": detail})
	check(worked, "%s%s" % [button, (" — " + detail) if detail != "" else ""])


func _init() -> void:
	print("ui button coverage tests")
	print("(buttons other suites rarely/never click)")
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

	await test_palette_primitives(ctx, main)
	await test_strip_booleans(ctx, main)
	await test_strip_group_similar(ctx, main)
	await test_merge_spline(ctx, main)
	await test_merge_composite(ctx, main)
	await test_sketch_rail_tools(ctx, main)
	await test_extrude_cut(ctx, main)
	await test_extrude_fuse(ctx, main)
	await test_construction_chip(ctx, main)
	await test_ops_fillet_chamfer(ctx, main)
	await test_ops_shell_draft_hole(ctx, main)
	await test_timeline_suppress_rollback(ctx, main)
	await test_assembly_mate_solve(ctx, main)
	await test_file_save_edit_undo(ctx, main)

	check(FilmUI.fail_count == 0,
			"FilmUI had no offscreen/control errors (got %d)" % FilmUI.fail_count)

	print("--- coverage summary ---")
	var ok_n := 0
	var bad_n := 0
	for r in results:
		if r["ok"]:
			ok_n += 1
			print("  WORKS  %s" % r["button"])
		else:
			bad_n += 1
			print("  BROKEN %s (%s)" % [r["button"], r["detail"]])
	print("%d buttons probed, %d work, %d broken; %d checks, %d failures" % [
		results.size(), ok_n, bad_n, checks, failures])
	quit(1 if failures > 0 else 0)


func _fresh(main) -> SxDocument:
	main.view.new_document()
	main.selected_sketch_pads.clear()
	main.selected_path_fid = ""
	return main.view.doc


func _body_count(doc: SxDocument) -> int:
	return doc.body_ids().size()


func _select_two_bodies(view: DocumentView, a: String, b: String) -> void:
	view.select_entity(a, "")
	view.selected_face = ""
	view.selected_bodies.clear()
	view.selected_bodies.append(a)
	view.selected_bodies.append(b)
	view.selected_body = a
	view._apply_selection_materials()
	view.selection_changed.emit(a, "")


func _disarm_place(main) -> void:
	var ix = main.interaction
	if ix != null and ix.has_method("_disarm_place"):
		ix._disarm_place(false)


## Palette Cylinder / Sphere / Cone / Torus — Box is clicked in other FilmUI tests.
func test_palette_primitives(ctx: FilmContext, main) -> void:
	print("-- palette primitives")
	var doc := _fresh(main)
	var before := _body_count(doc)
	await FilmUI.place_primitive_at(ctx, "cylinder", Vector3(20, 0, 0))
	await ctx.after_regen()
	_disarm_place(main)
	var after_cyl := _body_count(doc)
	record("Palette Cylinder", after_cyl > before,
			"bodies %d→%d" % [before, after_cyl])

	before = after_cyl
	await FilmUI.place_primitive_at(ctx, "sphere", Vector3(-20, 0, 0))
	await ctx.after_regen()
	_disarm_place(main)
	var after_sph := _body_count(doc)
	record("Palette Sphere", after_sph > before,
			"bodies %d→%d" % [before, after_sph])

	before = after_sph
	await FilmUI.place_primitive_at(ctx, "cone", Vector3(0, 20, 0))
	await ctx.after_regen()
	_disarm_place(main)
	var after_cone := _body_count(doc)
	record("Palette Cone", after_cone > before,
			"bodies %d→%d" % [before, after_cone])

	before = after_cone
	await FilmUI.place_primitive_at(ctx, "torus", Vector3(0, -20, 0))
	await ctx.after_regen()
	_disarm_place(main)
	var after_torus := _body_count(doc)
	record("Palette Torus", after_torus > before,
			"bodies %d→%d" % [before, after_torus])

## Selection-strip Join / Subtract / Intersect.
func test_strip_booleans(ctx: FilmContext, main) -> void:
	print("-- selection strip booleans")
	var doc := _fresh(main)
	# Overlapping boxes via kernel fixture; assert the strip *button* path.
	var a: String = doc.add_box(20, 20, 20, Vector3(-5, -5, 0))
	var b: String = doc.add_box(20, 20, 20, Vector3(5, -5, 0))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.size() < 2:
		record("Join", false, "fixture bodies missing")
		record("Subtract", false, "skipped")
		record("Intersect", false, "skipped")
		return
	a = str(bodies[0])
	b = str(bodies[1])
	_select_two_bodies(main.view, a, b)
	_disarm_place(main)
	main.interaction.refresh_selection_chrome()
	await ctx.tree.process_frame
	await ctx.tree.process_frame

	var join_btn := FilmUI.find_button(main, "Join")
	var vol0 := absf(doc.body_volume(a)) + absf(doc.body_volume(b))
	if join_btn == null or not join_btn.is_visible_in_tree():
		record("Join", false, "button missing/hidden")
	else:
		var n0 := _body_count(doc)
		await FilmUI.click_control(ctx, join_btn, FilmUICues.alert("Join", "Fuse selected bodies"))
		await ctx.after_regen()
		var n1 := _body_count(doc)
		record("Join", n1 < n0 or n1 == 1, "bodies %d→%d" % [n0, n1])

	# Fresh overlapping pair for Subtract.
	doc = _fresh(main)
	doc.add_box(30, 30, 20, Vector3(-10, -10, 0))
	doc.add_box(15, 15, 25, Vector3(-5, -5, 0))
	await ctx.after_regen()
	bodies = doc.body_ids()
	if bodies.size() < 2:
		record("Subtract", false, "fixture bodies missing")
	else:
		a = str(bodies[0])
		b = str(bodies[1])
		_select_two_bodies(main.view, a, b)
		main.interaction.refresh_selection_chrome()
		await ctx.tree.process_frame
		var cut_btn := FilmUI.find_button(main, "Subtract")
		if cut_btn == null or not cut_btn.is_visible_in_tree():
			record("Subtract", false, "button missing/hidden")
		else:
			var va := absf(doc.body_volume(a))
			await FilmUI.click_control(ctx, cut_btn,
					FilmUICues.alert("Subtract", "Cut tool from primary"))
			await ctx.after_regen()
			var ids: Array = doc.body_ids()
			var vok := false
			if ids.size() >= 1:
				var v1 := absf(doc.body_volume(str(ids[0])))
				vok = v1 > 1.0 and v1 < va + 1.0
			record("Subtract", vok, "primary vol was %.1f" % va)

	# Intersect
	doc = _fresh(main)
	doc.add_box(20, 20, 20, Vector3(-5, -5, 0))
	doc.add_box(20, 20, 20, Vector3(5, -5, 0))
	await ctx.after_regen()
	bodies = doc.body_ids()
	if bodies.size() < 2:
		record("Intersect", false, "fixture bodies missing")
	else:
		_select_two_bodies(main.view, str(bodies[0]), str(bodies[1]))
		main.interaction.refresh_selection_chrome()
		await ctx.tree.process_frame
		var common_btn := FilmUI.find_button(main, "Intersect")
		if common_btn == null or not common_btn.is_visible_in_tree():
			record("Intersect", false, "button missing/hidden")
		else:
			await FilmUI.click_control(ctx, common_btn,
					FilmUICues.alert("Intersect", "Keep common volume"))
			await ctx.after_regen()
			var ids2: Array = doc.body_ids()
			var ok := ids2.size() >= 1 and absf(doc.body_volume(str(ids2[0]))) > 1.0
			record("Intersect", ok, "bodies left=%d" % ids2.size())
	vol0 = vol0  # silence unused if Join short-circuited


## Group (isolate) + Similar strip buttons.
func test_strip_group_similar(ctx: FilmContext, main) -> void:
	print("-- selection strip Group / Similar")
	var doc := _fresh(main)
	doc.add_box(10, 10, 10, Vector3(0, 0, 0))
	doc.add_box(10, 10, 10, Vector3(40, 0, 0))
	doc.add_cylinder(5, 10, Vector3(80, 0, 0))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.size() < 3:
		record("Group", false, "need 3 bodies")
		record("Similar", false, "skipped")
		return
	_select_two_bodies(main.view, str(bodies[0]), str(bodies[1]))
	main.interaction.refresh_selection_chrome()
	await ctx.tree.process_frame
	var group_btn := FilmUI.find_button(main, "Group")
	if group_btn == null or not group_btn.is_visible_in_tree():
		record("Group", false, "button missing/hidden")
	else:
		await FilmUI.click_control(ctx, group_btn,
				FilmUICues.alert("Group", "Isolate selection"))
		await ctx.tree.process_frame
		var hidden_n := 0
		if main.view.has_method("is_body_hidden"):
			for bid in bodies:
				if main.view.is_body_hidden(str(bid)):
					hidden_n += 1
		elif "hidden_bodies" in main.view:
			hidden_n = main.view.hidden_bodies.size()
		record("Group", hidden_n >= 1, "hidden=%d" % hidden_n)

	# Similarity keys come from feature graph — use graph primitives, not raw add_box.
	main.view.new_document()
	doc = main.view.doc
	doc.graph_add_primitive("box", 10, 10, 10, Vector3(0, 0, 0))
	doc.graph_add_primitive("box", 10, 10, 10, Vector3(40, 0, 0))
	doc.graph_add_primitive("cylinder", 5, 10, 0, Vector3(80, 0, 0))
	await ctx.after_regen()
	bodies = doc.body_ids()
	if bodies.size() < 3:
		record("Similar", false, "graph primitive bodies missing")
		return
	main.view.select_entity(str(bodies[0]), "")
	_disarm_place(main)
	main.interaction.refresh_selection_chrome()
	await ctx.tree.process_frame
	var sim_btn := FilmUI.find_button(main, "Similar")
	if sim_btn == null or not sim_btn.is_visible_in_tree():
		record("Similar", false, "button missing/hidden")
	else:
		var key0: String = main.view.body_similarity_key(str(bodies[0]))
		var key1: String = main.view.body_similarity_key(str(bodies[1]))
		await FilmUI.click_control(ctx, sim_btn,
				FilmUICues.alert("Similar", "Add same-kind bodies"))
		await ctx.tree.process_frame
		record("Similar", main.view.selected_bodies.size() >= 2,
				"selected=%d keys=%s/%s" % [
					main.view.selected_bodies.size(), key0, key1])


## Merge Spline chip (Join is covered elsewhere).
func test_merge_spline(ctx: FilmContext, main) -> void:
	print("-- Merge Spline chip")
	var doc := _fresh(main)
	var sm: SketchMode = main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(12, 0))
	var r1 := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(16, 4), Vector2(24, 4))
	var r2 := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if r1.is_empty() or r2.is_empty():
		record("Merge Spline", false, "rail pads missing")
		return
	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	await FilmUI.select_sketch_pad_ctrl(ctx, r1)
	await FilmUI.select_sketch_pad_ctrl(ctx, r2)
	main._refresh_merge_chrome()
	await ctx.tree.process_frame
	await FilmUI.merge_sketches_ui(ctx, "bridge_spline")
	await ctx.after_regen()
	var path_fid := FilmUI.last_feature_id(doc, "path")
	record("Merge Spline", path_fid != "", "path=%s" % path_fid)


## Sketch rail tools that films rarely click.
func test_sketch_rail_tools(ctx: FilmContext, main) -> void:
	print("-- sketch rail tools")
	_fresh(main)
	var sm: SketchMode = main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	for entry in [
		[SketchMode.Tool.POLYGON, "Polygon"],
		[SketchMode.Tool.TRIM, "Trim"],
		[SketchMode.Tool.MIRROR, "Mirror"],
		[SketchMode.Tool.PATTERN, "Pattern"],
		[SketchMode.Tool.POINT, "Point"],
		[SketchMode.Tool.RECT, "Rectangle"],
		[SketchMode.Tool.CONVERT, "Convert"],
		[SketchMode.Tool.ELLIPSE, "Ellipse"],
		[SketchMode.Tool.SLOT, "Slot"],
	]:
		var tool: int = entry[0]
		var name: String = entry[1]
		var before_fails := FilmUI.fail_count
		await FilmUI.select_sketch_tool(ctx, sm, tool)
		var activated := sm.tool == tool
		var no_new_fail := FilmUI.fail_count == before_fails
		record("SketchTools %s" % name, activated and no_new_fail,
				"tool=%s" % str(sm.tool))
	await FilmUI.exit_sketch(ctx)


## Extrude finish-op Cut via chrome OptionButton.
func test_extrude_cut(ctx: FilmContext, main) -> void:
	print("-- Extrude Cut")
	var doc := _fresh(main)
	# Need a feature-graph host so face sketch gets target_fid for Cut.
	doc.graph_add_primitive("box", 40, 40, 10, Vector3(-20, -20, 0))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		record("Extrude Cut", false, "no host box")
		return
	var host := str(bodies[bodies.size() - 1])
	var top := FilmUI.find_face_by_normal(main.view, host, Vector3(0, 0, 1))
	if top == "":
		record("Extrude Cut", false, "no top face")
		return
	var vol0 := absf(doc.body_volume(host))
	main.view.select_entity(host, top)
	main._start_sketch_on_face(top, host)
	await ctx.tree.process_frame
	var sm: SketchMode = main.sketch_mode
	if not sm.active:
		record("Extrude Cut", false, "face sketch did not start")
		return
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(6, 0))
	var chrome: SketchContextChrome = main.sketch_chrome
	if chrome == null or not chrome.visible:
		record("Extrude Cut", false, "sketch chrome missing")
		await FilmUI.exit_sketch(ctx)
		return
	# Prefer Cut via the New/Cut/Fuse OptionButton (not Blind/Through All/Midplane).
	var op: OptionButton = null
	for c in chrome.find_children("*", "OptionButton", true, false):
		if c is OptionButton and (c as OptionButton).get_item_text(0) == "New":
			op = c as OptionButton
			break
	if op == null:
		record("Extrude Cut", false, "finish-op OptionButton missing")
		await FilmUI.exit_sketch(ctx)
		return
	if sm.target_fid == "":
		record("Extrude Cut", false, "no target_fid (need face sketch host)")
		await FilmUI.exit_sketch(ctx)
		return
	op.select(1)  # Cut
	await ctx.tree.process_frame
	await FilmUI.apply_extrude(ctx, 15.0)
	await ctx.after_regen()
	if sm.active:
		await FilmUI.exit_sketch(ctx)
		await ctx.after_regen()
	var ids: Array = doc.body_ids()
	var vol1 := 0.0
	if not ids.is_empty():
		vol1 = absf(doc.body_volume(str(ids[0])))
	record("Extrude Cut", vol1 > 1.0 and vol1 < vol0 - 10.0,
			"vol %.1f→%.1f" % [vol0, vol1])


## Construction selection chip.
func test_construction_chip(ctx: FilmContext, main) -> void:
	print("-- Construction chip")
	_fresh(main)
	var sm: SketchMode = main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	# Select the line via Select tool + click midpoint.
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(5, 0), "Select line")
	await ctx.tree.process_frame
	if sm.selected.is_empty() and sm.sketch.entity_ids().size() > 0:
		sm._set_selected([sm.sketch.entity_ids()[0]])
		sm.selection_actions_needed.emit()
		await ctx.tree.process_frame
	main._on_sketch_selection_chips()
	await ctx.tree.process_frame
	var chip := FilmUI.find_button(main.sketch_chrome, "Construction")
	if chip == null or not chip.is_visible_in_tree():
		record("Construction chip", false, "chip missing/hidden")
		await FilmUI.exit_sketch(ctx)
		return
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Construction", "Toggle construction"))
	await ctx.tree.process_frame
	var any_c := false
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			any_c = true
	record("Construction chip", any_c, "construction set=%s" % str(any_c))
	await FilmUI.exit_sketch(ctx)


## Merge Composite chip.
func test_merge_composite(ctx: FilmContext, main) -> void:
	print("-- Merge Composite chip")
	var doc := _fresh(main)
	var sm: SketchMode = main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var r1 := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(14, 0), Vector2(24, 0))
	var r2 := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if r1.is_empty() or r2.is_empty():
		record("Merge Composite", false, "rail pads missing")
		return
	await FilmUI.clear_pad_selection(ctx)
	main.selected_sketch_pads.clear()
	await FilmUI.select_sketch_pad_ctrl(ctx, r1)
	await FilmUI.select_sketch_pad_ctrl(ctx, r2)
	main._refresh_merge_chrome()
	await ctx.tree.process_frame
	await FilmUI.merge_sketches_ui(ctx, "composite")
	await ctx.after_regen()
	var path_fid := FilmUI.last_feature_id(doc, "path")
	record("Merge Composite", path_fid != "", "path=%s" % path_fid)


## Extrude finish-op Fuse via chrome OptionButton.
func test_extrude_fuse(ctx: FilmContext, main) -> void:
	print("-- Extrude Fuse")
	var doc := _fresh(main)
	doc.graph_add_primitive("box", 40, 40, 10, Vector3(-20, -20, 0))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		record("Extrude Fuse", false, "no host box")
		return
	var host := str(bodies[bodies.size() - 1])
	var top := FilmUI.find_face_by_normal(main.view, host, Vector3(0, 0, 1))
	if top == "":
		record("Extrude Fuse", false, "no top face")
		return
	var vol0 := absf(doc.body_volume(host))
	main.view.select_entity(host, top)
	main._start_sketch_on_face(top, host)
	await ctx.tree.process_frame
	var sm: SketchMode = main.sketch_mode
	if not sm.active:
		record("Extrude Fuse", false, "face sketch did not start")
		return
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(6, 0))
	var chrome: SketchContextChrome = main.sketch_chrome
	if chrome == null or not chrome.visible:
		record("Extrude Fuse", false, "sketch chrome missing")
		await FilmUI.exit_sketch(ctx)
		return
	var op: OptionButton = null
	for c in chrome.find_children("*", "OptionButton", true, false):
		if c is OptionButton and (c as OptionButton).get_item_text(0) == "New":
			op = c as OptionButton
			break
	if op == null or sm.target_fid == "":
		record("Extrude Fuse", false, "finish-op or target_fid missing")
		await FilmUI.exit_sketch(ctx)
		return
	op.select(2)  # Fuse
	await ctx.tree.process_frame
	await FilmUI.apply_extrude(ctx, 15.0)
	await ctx.after_regen()
	if sm.active:
		await FilmUI.exit_sketch(ctx)
		await ctx.after_regen()
	var ids: Array = doc.body_ids()
	var vol1 := 0.0
	if not ids.is_empty():
		vol1 = absf(doc.body_volume(str(ids[0])))
	record("Extrude Fuse", vol1 > vol0 + 10.0, "vol %.1f→%.1f" % [vol0, vol1])


## Ops Fillet / Chamfer (body ops — tooltip match on OpsPanel).
func test_ops_fillet_chamfer(ctx: FilmContext, main) -> void:
	print("-- Ops Fillet / Chamfer")
	var doc := _fresh(main)
	doc.graph_add_primitive("box", 40, 40, 40, Vector3(-20, -20, 0))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		record("Ops Fillet", false, "no box")
		record("Ops Chamfer", false, "skipped")
		return
	var body := str(bodies[0])
	main.view.select_entity(body, "")
	main._update_left_rail()
	await ctx.tree.process_frame
	await ctx.tree.process_frame
	var ops: OpsPanel = main.ops_panel
	if ops == null or not ops.visible:
		record("Ops Fillet", false, "ops panel hidden")
		record("Ops Chamfer", false, "skipped")
		return
	ops._radius_spin.value = 2.0
	var vol0 := absf(doc.body_volume(body))
	var fillet := FilmUI.find_button(ops, "Round the selected edges")
	if fillet == null or not fillet.is_visible_in_tree():
		record("Ops Fillet", false, "button missing/hidden")
	else:
		await FilmUI.click_control(ctx, fillet, FilmUICues.alert("Fillet", "Round edges"))
		await ctx.after_regen()
		bodies = doc.body_ids()
		var vol1 := absf(doc.body_volume(str(bodies[0]))) if not bodies.is_empty() else 0.0
		record("Ops Fillet", vol1 > 1.0 and vol1 < vol0 - 1.0, "vol %.1f→%.1f" % [vol0, vol1])

	doc = _fresh(main)
	doc.graph_add_primitive("box", 40, 40, 40, Vector3(-20, -20, 0))
	await ctx.after_regen()
	bodies = doc.body_ids()
	body = str(bodies[0])
	main.view.select_entity(body, "")
	main._update_left_rail()
	await ctx.tree.process_frame
	ops = main.ops_panel
	ops._radius_spin.value = 2.0
	vol0 = absf(doc.body_volume(body))
	var chamfer := FilmUI.find_button(ops, "Bevel the selected edges")
	if chamfer == null or not chamfer.is_visible_in_tree():
		record("Ops Chamfer", false, "button missing/hidden")
	else:
		await FilmUI.click_control(ctx, chamfer, FilmUICues.alert("Chamfer", "Bevel edges"))
		await ctx.after_regen()
		bodies = doc.body_ids()
		var volc := absf(doc.body_volume(str(bodies[0]))) if not bodies.is_empty() else 0.0
		record("Ops Chamfer", volc > 1.0 and volc < vol0 - 1.0, "vol %.1f→%.1f" % [vol0, volc])


## Ops Shell / Draft / Hole (face ops).
func test_ops_shell_draft_hole(ctx: FilmContext, main) -> void:
	print("-- Ops Shell / Draft / Hole")
	var doc := _fresh(main)
	doc.graph_add_primitive("box", 50, 50, 50, Vector3(-25, -25, 0))
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		record("Ops Shell", false, "no box")
		record("Ops Draft", false, "skipped")
		record("Ops Hole", false, "skipped")
		return
	var body := str(bodies[0])
	var top := FilmUI.find_face_by_normal(main.view, body, Vector3(0, 0, 1))
	var side := FilmUI.find_face_by_normal(main.view, body, Vector3(1, 0, 0))
	var ops: OpsPanel = main.ops_panel

	# Shell — open on top face.
	main.view.select_entity(body, top)
	main._update_left_rail()
	await ctx.tree.process_frame
	await ctx.tree.process_frame
	ops._thickness_spin.value = 2.0
	var vol0 := absf(doc.body_volume(body))
	var shell_btn := FilmUI.find_button(ops, "Hollow the body")
	if shell_btn == null or not shell_btn.is_visible_in_tree():
		record("Ops Shell", false, "button missing/hidden")
	else:
		await FilmUI.click_control(ctx, shell_btn, FilmUICues.alert("Shell", "Hollow body"))
		await ctx.after_regen()
		bodies = doc.body_ids()
		var vols := absf(doc.body_volume(str(bodies[0]))) if not bodies.is_empty() else 0.0
		record("Ops Shell", vols > 1.0 and vols < vol0 * 0.6, "vol %.1f→%.1f" % [vol0, vols])

	# Draft — side face on a fresh solid.
	doc = _fresh(main)
	doc.graph_add_primitive("box", 50, 50, 50, Vector3(-25, -25, 0))
	await ctx.after_regen()
	bodies = doc.body_ids()
	body = str(bodies[0])
	side = FilmUI.find_face_by_normal(main.view, body, Vector3(1, 0, 0))
	if side == "":
		record("Ops Draft", false, "no +X face")
	else:
		main.view.select_entity(body, side)
		main._update_left_rail()
		await ctx.tree.process_frame
		await ctx.tree.process_frame
		ops = main.ops_panel
		ops._draft_angle_spin.value = 5.0
		vol0 = absf(doc.body_volume(body))
		var draft_btn := FilmUI.find_button(ops, "Taper this face")
		if draft_btn == null or not draft_btn.is_visible_in_tree():
			record("Ops Draft", false, "button missing/hidden")
		else:
			await FilmUI.click_control(ctx, draft_btn, FilmUICues.alert("Draft", "Taper face"))
			await ctx.after_regen()
			bodies = doc.body_ids()
			var vold := absf(doc.body_volume(str(bodies[0]))) if not bodies.is_empty() else 0.0
			record("Ops Draft", absf(vold - vol0) > 1.0, "vol %.1f→%.1f" % [vol0, vold])

	# Hole — timeline body + top face.
	doc = _fresh(main)
	doc.graph_add_primitive("box", 50, 50, 50, Vector3(-25, -25, 0))
	await ctx.after_regen()
	bodies = doc.body_ids()
	body = str(bodies[0])
	top = FilmUI.find_face_by_normal(main.view, body, Vector3(0, 0, 1))
	if top == "":
		record("Ops Hole", false, "no top face")
		return
	main.view.select_entity(body, top)
	main._update_left_rail()
	await ctx.tree.process_frame
	await ctx.tree.process_frame
	ops = main.ops_panel
	ops._hole_type.select(0)
	ops._hole_diameter.value = 6.0
	ops._hole_depth.value = 0.0
	vol0 = absf(doc.body_volume(body))
	var feats0 := doc.graph_features().size()
	var hole_btn: Button = ops.find_child("ApplyHole", true, false) as Button
	if hole_btn == null:
		hole_btn = FilmUI.find_button(ops, "Drill at the center")
	if hole_btn == null or not hole_btn.is_visible_in_tree():
		record("Ops Hole", false, "button missing/hidden")
		return
	await FilmUI.click_control(ctx, hole_btn, FilmUICues.alert("Hole", "Drill face center"))
	await ctx.after_regen()
	bodies = doc.body_ids()
	var volh := absf(doc.body_volume(str(bodies[0]))) if not bodies.is_empty() else 0.0
	var has_hole := false
	for f in doc.graph_features():
		if f["type"] == "hole":
			has_hole = true
	record("Ops Hole", volh < vol0 and has_hole and doc.graph_features().size() == feats0 + 1,
			"vol %.1f→%.1f hole=%s" % [vol0, volh, str(has_hole)])


## Timeline suppress checkbox + rollback bar.
func test_timeline_suppress_rollback(ctx: FilmContext, main) -> void:
	print("-- Timeline suppress / rollback")
	var doc := _fresh(main)
	doc.graph_add_primitive("box", 20, 20, 20, Vector3(0, 0, 0))
	doc.graph_add_primitive("box", 20, 20, 20, Vector3(40, 0, 0))
	await ctx.after_regen()
	if main.has_method("_update_panel_visibility"):
		main._update_panel_visibility()
	# Force timeline refresh/visibility for feature graph.
	if main.timeline != null:
		main.timeline.visible = true
		main.timeline.refresh()
	await ctx.tree.process_frame
	await ctx.tree.process_frame

	var feats: Array = doc.graph_features()
	if feats.size() < 2:
		record("Timeline Suppress", false, "need 2 features")
		record("Timeline Rollback", false, "skipped")
		return
	var fid0: String = feats[0]["id"]
	var row: Control = main.timeline._rows.get(fid0, null)
	if row == null:
		record("Timeline Suppress", false, "row missing")
		record("Timeline Rollback", false, "skipped")
		return
	var cb := row.get_child(0) as CheckBox
	if cb == null:
		cb = FilmUI.find_checkbox(row, "Suppress")
	var bodies0 := _body_count(doc)
	if cb == null:
		record("Timeline Suppress", false, "checkbox missing")
	else:
		# Checked = not suppressed; uncheck to suppress.
		await FilmUI.set_checkbox(ctx, cb, false,
				FilmUICues.alert("Suppress", "Suppress first feature"))
		await ctx.after_regen()
		if main.timeline != null:
			main.timeline.refresh()
		await ctx.tree.process_frame
		var bodies1 := _body_count(doc)
		var feat_sup := false
		for f in doc.graph_features():
			if f["id"] == fid0 and f["suppressed"]:
				feat_sup = true
		record("Timeline Suppress", feat_sup and bodies1 < bodies0,
				"bodies %d→%d suppressed=%s" % [bodies0, bodies1, str(feat_sup)])
		# Rows are rebuilt on refresh — re-find before unsuppress.
		row = main.timeline._rows.get(fid0, null) as Control
		cb = null
		if row != null:
			cb = row.get_child(0) as CheckBox
		if cb != null:
			await FilmUI.set_checkbox(ctx, cb, true,
					FilmUICues.alert("Unsuppress", "Restore feature"))
			await ctx.after_regen()
			if main.timeline != null:
				main.timeline.refresh()
			await ctx.tree.process_frame

	# Rollback before feature 1 → only first feature regenerates.
	if not await FilmUI.timeline_rollback_before(ctx, 1):
		record("Timeline Rollback", false, "bar click/set failed")
		return
	await ctx.after_regen()
	var rb := doc.graph_rollback()
	var n_rb := _body_count(doc)
	var rolled := rb == 1 and n_rb == 1
	# Double-click bar rolls to end.
	if not await FilmUI.timeline_rollback_to_end(ctx):
		record("Timeline Rollback", rolled, "rollback ok but to-end failed; rb=%d bodies=%d" % [rb, n_rb])
		return
	await ctx.after_regen()
	var restored := doc.graph_rollback() < 0 and _body_count(doc) == 2
	record("Timeline Rollback", rolled and restored,
			"rb=%d→end bodies_mid=%d bodies_end=%d" % [rb, n_rb, _body_count(doc)])


## Assembly Place (ops) → Add mate → Solve mates.
func test_assembly_mate_solve(ctx: FilmContext, main) -> void:
	print("-- Assembly Place / Add mate / Solve")
	var doc := _fresh(main)
	var base: String = doc.add_box(100, 100, 20, Vector3(0, 0, 0))
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	await ctx.after_regen()
	main.view.select_entity(block, "")
	main._update_left_rail()
	await ctx.tree.process_frame
	await ctx.tree.process_frame

	# First instance comes from Ops "Place" (assembly panel is hidden until then).
	var ops: OpsPanel = main.ops_panel
	var place_btn := FilmUI.find_button(ops, "Place a linked instance")
	if place_btn == null:
		place_btn = FilmUI.find_button(ops, "Place")
	if place_btn == null or not place_btn.is_visible_in_tree():
		record("Assembly Place", false, "Ops Place missing")
		record("Assembly Add mate", false, "skipped")
		record("Assembly Solve mates", false, "skipped")
		return
	ops._inst_ox.value = 50.0
	ops._inst_oy.value = 50.0
	ops._inst_oz.value = 90.0
	await FilmUI.click_control(ctx, place_btn, FilmUICues.alert("Place", "Instance selected body"))
	await ctx.after_regen()
	var panel: AssemblyPanel = main.assembly_panel
	if panel != null:
		panel.refresh_lists()
	await ctx.tree.process_frame
	var inst_n := doc.instance_list().size()
	record("Assembly Place", inst_n >= 1 and panel != null and panel.visible,
			"instances=%d panel_vis=%s" % [inst_n, str(panel.visible if panel else false)])
	if inst_n < 1 or panel == null:
		record("Assembly Add mate", false, "no instance")
		record("Assembly Solve mates", false, "skipped")
		return

	# Face helpers: base top z=20, block bottom z=0.
	var base_top := ""
	var block_bottom := ""
	for fid in doc.get_face_ids(base):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		if absf(bb["min"].z - 20.0) < 1e-5 and absf(bb["max"].z - 20.0) < 1e-5:
			base_top = fid
	for fid in doc.get_face_ids(block):
		var bb2: Dictionary = doc.measure_bbox(fid)
		if bb2.is_empty():
			continue
		if absf(bb2["min"].z) < 1e-5 and absf(bb2["max"].z) < 1e-5:
			block_bottom = fid
	if base_top == "" or block_bottom == "":
		record("Assembly Add mate", false, "faces missing")
		record("Assembly Solve mates", false, "skipped")
		return

	for i in panel._type_option.item_count:
		if panel._type_option.get_item_text(i) == "plane_coincident":
			panel._type_option.select(i)
			break
	var add_mate := FilmUI.find_button(panel, "Add mate")
	if add_mate == null or not add_mate.is_visible_in_tree():
		record("Assembly Add mate", false, "button missing/hidden")
		record("Assembly Solve mates", false, "skipped")
		return
	await FilmUI.click_control(ctx, add_mate, FilmUICues.alert("Add mate", "Arm mate picks"))
	await ctx.tree.process_frame
	main.view.select_entity(base, base_top)
	await ctx.tree.process_frame
	main.view.select_entity(block, block_bottom)
	await ctx.after_regen()
	var mates_n := doc.mate_list().size()
	var tz := 0.0
	if not doc.instance_list().is_empty():
		tz = float(doc.instance_list()[0]["translation"].z)
	record("Assembly Add mate", mates_n == 1 and absf(tz - 20.0) < 0.1,
			"mates=%d tz=%.2f" % [mates_n, tz])

	# Nudge instance off, then Solve mates restores Z.
	if mates_n < 1 or doc.instance_list().is_empty():
		record("Assembly Solve mates", false, "no mate to solve")
		return
	var iid: String = doc.instance_list()[0]["id"]
	doc.set_instance_transform(iid, Vector3(50, 50, 90), Vector3(0, 0, 1), 0.0)
	main.view.refresh()
	await ctx.tree.process_frame
	var solve_btn := FilmUI.find_button(panel, "Solve mates")
	if solve_btn == null or not solve_btn.is_visible_in_tree():
		record("Assembly Solve mates", false, "button missing/hidden")
		return
	await FilmUI.click_control(ctx, solve_btn, FilmUICues.alert("Solve", "Re-apply mates"))
	await ctx.after_regen()
	var tz2 := float(doc.instance_list()[0]["translation"].z)
	record("Assembly Solve mates", absf(tz2 - 20.0) < 0.1, "tz after solve=%.2f" % tz2)


## File → Save and Edit → Undo via menu id_pressed (MenuButton items).
func test_file_save_edit_undo(ctx: FilmContext, main) -> void:
	print("-- File Save / Edit Undo")
	var doc := _fresh(main)
	doc.graph_add_primitive("box", 10, 10, 10, Vector3(0, 0, 0))
	await ctx.after_regen()
	var path := "/tmp/sx_ui_button_coverage_save.sxp"
	main.current_path = path
	var file_menu: MenuButton = null
	var edit_menu: MenuButton = null
	var chrome: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if chrome != null:
		for c in chrome.find_children("*", "MenuButton", true, false):
			var mb := c as MenuButton
			if mb == null:
				continue
			if mb.text == "File":
				file_menu = mb
			elif mb.text == "Edit":
				edit_menu = mb
	if file_menu == null:
		record("File Save", false, "File menu missing")
	else:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		await FilmUI.activate_menu_id(ctx, file_menu, 2,
				FilmUICues.alert("Save", "File → Save"))
		await ctx.tree.process_frame
		record("File Save", FileAccess.file_exists(path), "path=%s" % path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	if edit_menu == null:
		record("Edit Undo", false, "Edit menu missing")
		return
	var n0 := _body_count(doc)
	await FilmUI.activate_menu_id(ctx, edit_menu, 0,
			FilmUICues.alert("Undo", "Edit → Undo"))
	await ctx.after_regen()
	var n1 := _body_count(doc)
	record("Edit Undo", n1 < n0, "bodies %d→%d" % [n0, n1])
