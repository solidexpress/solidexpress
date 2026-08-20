# Critic A→L walk — merge gate for print-a-wrench.
# Replays the live critique order on a 1280×720 canvas.
# Run: tools/godot/godot --headless --path game --script tests/run_critic_walk_tests.gd
extends SceneTree

const ChromeDock := preload("res://scripts/chrome_dock.gd")

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("critic A→L walk gate")
	if FileAccess.file_exists(ChromeDock.CFG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ChromeDock.CFG_PATH))
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	root.add_child(vp)
	var main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await process_frame
	await process_frame

	await step_a_empty(main, vp)
	await step_b_box(main)
	await step_c_hole(main)
	await step_d_fillet(main)
	await step_e_chamfer(main)
	await step_f_degenerate(main)
	await step_g_extrude(main)
	await step_h_wizard(main)
	await step_i_jaw_af(main)
	await step_j_analyze(main)
	await step_l_docks(main, vp)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func step_a_empty(main, _vp: SubViewport) -> void:
	print("- A New = plate + flat bg + docks off")
	main.show_scenic_bg = false
	main._sync_world_background()
	main._do_new()
	for i in range(4):
		await process_frame
	check(not main.timeline.visible, "Timeline hidden by default after New")
	check(not main.variables_panel.visible, "Variables hidden by default after New")
	check(not main.show_timeline, "show_timeline flag false")
	var ids: PackedStringArray = main.view.doc.body_ids()
	check(ids.size() == 1, "New seeds one body")
	if ids.size() > 0:
		var vol: float = main.view.doc.body_volume(ids[0])
		check(absf(vol - 12500.0) < 1.0, "New plate volume ~12500 (got %.1f)" % vol)
	var named := false
	for f in main.view.doc.graph_features():
		if str(f.get("name", "")).begins_with("Box"):
			named = true
	check(named, "timeline feature named Box")
	var e = main._world_env.environment if main._world_env != null else null
	check(e != null and e.background_mode == Environment.BG_COLOR, "flat background by default")


func step_b_box(main) -> void:
	print("- B plate already from New; select it")
	var view = main.view
	var id: String = str(view.doc.body_ids()[0]) if view.doc.body_ids().size() > 0 else ""
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	check(view.selected_body == id, "plate selected")
	check(not main.show_timeline, "Timeline still user-off before fillet")


func step_c_hole(main) -> void:
	print("- C Hole Apply Ø6 thru")
	var view = main.view
	var id: String = view.selected_body
	var fid: String = view.feature_of_body(id)
	var h: String = view.doc.graph_add_hole(fid, "simple", Vector3(0, 0, 5),
			Vector3(0, 0, -1), 6.0, 0.0, 0.0, 0.0, 0.0, 90.0)
	check(h != "", "hole feature created")
	view.graph_changed()
	check(not main.show_timeline, "hole did not force Timeline on")
	check(view.doc.body_volume(id) < 12400.0, "hole cut volume")


func step_d_fillet(main) -> void:
	print("- D Fillet R chip")
	var view = main.view
	var id: String = str(view.doc.body_ids()[0]) if view.doc.body_ids().size() > 0 else ""
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ops = main.ops_panel
	var ix = main.interaction
	var edges = view.doc.get_edge_ids(id)
	check(edges.size() > 0, "edges available (got %d)" % edges.size())
	if edges.is_empty():
		return
	view.select_edge(id, str(edges[0]))
	ops.set_dressup_radius(0.5)
	ix._ctx_fillet()
	check(ops._pending == ops.Pending.FILLET_EDGES, "Fillet armed")
	var chip: Control = ix.find_child("StripDressupRadius", true, false)
	check(chip != null and chip.visible, "R chip visible")
	check(ops.try_commit_pending(), "Enter commits fillet r=0.5")
	check(not main.show_timeline, "fillet did not force Timeline on")
	check(not main.timeline.visible, "Timeline panel stays hidden after fillet")
	var has_f := false
	for f in view.doc.graph_features():
		if str(f.get("type")) == "fillet" and not bool(f.get("failed", false)):
			has_f = true
	check(has_f, "fillet on timeline")
	var id2: String = view.insert_primitive("box", Vector3(80, 0, 0), Vector3(20, 20, 5))
	view.select_entity(id2, "")
	var edges2 = view.doc.get_edge_ids(id2)
	if edges2.size() > 0:
		view.select_edge(id2, str(edges2[0]))
		ops.set_dressup_radius(99.0)
		ix._ctx_fillet()
		var ok_big: bool = ops.try_commit_pending()
		check(not ok_big and ops._pending == ops.Pending.FILLET_EDGES, "oversized re-arms")
		ops.cancel_pending_pick()
		ops.set_dressup_radius(0.5)
	view.select_entity(id, "")
	await process_frame


func step_e_chamfer(main) -> void:
	print("- E Chamfer")
	var view = main.view
	var id: String = str(view.doc.body_ids()[0]) if view.doc.body_ids().size() > 0 else ""
	view.select_entity(id, "")
	await process_frame
	var ops = main.ops_panel
	var edges = view.doc.get_edge_ids(id)
	if edges.size() > 2:
		view.select_edge(id, str(edges[2]))
	elif edges.size() > 0:
		view.select_edge(id, str(edges[0]))
	else:
		check(false, "chamfer edges available")
		return
	ops.set_dressup_radius(0.5)
	main.interaction._ctx_chamfer()
	check(ops._pending == ops.Pending.CHAMFER_EDGES, "Chamfer armed")
	check(ops.try_commit_pending(), "Enter commits chamfer")
	check(not main.show_timeline, "chamfer did not force Timeline on")


func step_f_degenerate(main) -> void:
	print("- F degenerate Line names view span")
	main._start_sketch_on_ground()
	await process_frame
	await process_frame
	var sm = main.sketch_mode
	sm.set_tool(SketchMode.Tool.LINE)
	var last := [""]
	sm.status.connect(func(t: String) -> void: last[0] = t)
	sm.click(Vector2(0, 0))
	sm.reject_tiny_draw(Vector2(0.1, 0))
	check(str(last[0]).contains("view is"), "tiny draw names view span (%s)" % last[0])


func step_g_extrude(main) -> void:
	print("- G closed polygon Extrude")
	var sm = main.sketch_mode
	if not sm.active:
		main._start_sketch_on_ground()
		await process_frame
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.set_tool_variant("across_flats")
	sm.click(Vector2(0, 0))
	sm.click(Vector2(18, 0))
	check(sm.profile_is_closed(sm.sketch), "polygon closed")
	sm.finish_extrude(20.0, "new", "blind")
	var has_ex := false
	for f in main.view.doc.graph_features():
		if str(f.get("type")) == "extrude" and not bool(f.get("failed", false)):
			has_ex = true
	check(has_ex, "extrude named solid")
	if sm.active:
		sm.cancel()
	await process_frame


func step_h_wizard(main) -> void:
	print("- H Hole Wizard after dressups")
	var view = main.view
	var id := ""
	for f in view.doc.graph_features():
		if str(f.get("type")) == "primitive":
			id = str(f.get("output_body", ""))
			break
	if id == "":
		id = str(view.doc.body_ids()[0])
	view.clear_selection()
	main._update_panel_visibility()
	await process_frame
	var ops = main.ops_panel
	if ops._hole_type != null:
		ops._hole_type.selected = 3
	ops._arm_hole_wizard()
	check(ops.is_hole_wizard_armed(), "wizard arms without body pre-select")
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 5.0) < 1.5:
			top = face_id
			break
	check(top != "", "top face for wizard")
	ops.handle_viewport_pick(id, top, Vector3(12, 12, 5))
	ops.handle_viewport_pick(id, top, Vector3(-12, 10, 5))
	check(ops.hole_wizard_point_count() == 2, "2 wizard points")
	var n0 := 0
	for f in view.doc.graph_features():
		if str(f.get("type")) == "hole":
			n0 += 1
	check(ops.try_commit_pending(), "Wizard Enter commits")
	var n1 := 0
	for f in view.doc.graph_features():
		if str(f.get("type")) == "hole" and not bool(f.get("failed", false)):
			n1 += 1
	check(n1 > n0, "extra hole feature(s) from wizard")


func step_i_jaw_af(main) -> void:
	print("- I Hex + Jaw AF 14 (strip chip)")
	var view = main.view
	var id := ""
	for f in view.doc.graph_features():
		if str(f.get("type")) == "primitive":
			id = str(f.get("output_body", ""))
			break
	if id == "":
		id = str(view.doc.body_ids()[0])
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 5.0) < 1.5:
			top = face_id
			break
	view.select_entity(id, top)
	main._update_panel_visibility()
	await process_frame
	check(main.ops_panel._apply_hex_opening(), "hex opening armed")
	if top != "":
		main.ops_panel.handle_viewport_pick(id, top, Vector3(12, 0, 5))
	var vol0: float = view.doc.body_volume(id)
	main.interaction._ctx_jaw_af(14)
	await process_frame
	var jaw := 0.0
	for v in view.doc.list_variables():
		if str(v.get("name")) == "jaw_af":
			jaw = float(v.get("value", 0.0))
	check(is_equal_approx(jaw, 14.0), "jaw_af = 14 (got %.1f)" % jaw)
	check(view.doc.body_volume(id) < vol0 - 10.0, "hex grows after AF 14")


func step_j_analyze(main) -> void:
	print("- J Analyze via View menu entry")
	main._on_mode_menu(5)
	await process_frame
	main._on_print_analyze()
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	var r: Dictionary = view.doc.print_analyze(id)
	check(float(r.get("min_wall", 99)) < 6.5, "min wall ~plate (%.2f)" % float(r.get("min_wall", 99)))
	check(str(r.get("digest", "")).find("nozzle") >= 0, "digest mentions nozzle")
	main._on_mode_menu(0)


func step_l_docks(main, vp: SubViewport) -> void:
	print("- L docks off plate; Assembly on right; Esc closes params")
	main.show_timeline = false
	main.show_variables = false
	main._sync_view_menu_checks()
	main._update_panel_visibility()
	for i in range(3):
		await process_frame
	check(not main.timeline.visible and not main.variables_panel.visible,
			"docks hidden by default after features")
	check(not main.assembly_panel.visible, "Assembly hidden without instances")
	# Place instance → Assembly docks to the RIGHT of center.
	var id: String = str(main.view.doc.body_ids()[0])
	main.view.select_entity(id, "")
	main.ops_panel._place_instance()
	main._update_panel_visibility()
	for i in range(3):
		await process_frame
	check(main.assembly_panel.visible, "Assembly visible with an instance")
	var ar: Rect2 = main.assembly_panel.get_global_rect()
	var mid_x := float(vp.size.x) * 0.5
	check(ar.position.x >= mid_x - 1.0,
			"Assembly left edge on right half (%.0f >= %.0f)" % [ar.position.x, mid_x])
	main.show_timeline = true
	main._sync_view_menu_checks()
	main._update_panel_visibility()
	for i in range(3):
		await process_frame
	check(main.timeline.visible, "Timeline shown when toggled")
	var t_r: Rect2 = main.timeline.get_global_rect()
	check(t_r.end.x <= float(vp.size.x) * 0.4 + 8.0,
			"Timeline right edge left of plate mid (%.0f)" % t_r.end.x)
	# Fillet second strip press commits.
	main.show_timeline = false
	main._update_panel_visibility()
	main.view.select_entity(id, "")
	var edges = main.view.doc.get_edge_ids(id)
	if edges.size() > 0:
		main.view.select_edge(id, str(edges[0]))
		main.ops_panel.set_dressup_radius(1.0)
		main.ops_panel.arm_or_apply_fillet()
		main.ops_panel.arm_or_apply_fillet()
		check(main.ops_panel._pending == main.ops_panel.Pending.NONE,
				"second Fillet press commits")
	check(not main.show_timeline, "Fillet still did not force Timeline")
