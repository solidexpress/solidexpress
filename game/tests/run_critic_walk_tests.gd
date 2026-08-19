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
	# Wipe remembered dock layout so defaults apply.
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


func _plate_center_rect(vp: SubViewport) -> Rect2:
	var s := Vector2(vp.size)
	return Rect2(s * 0.3, s * 0.4)


func _covers_plate_center(panel: Control, vp: SubViewport) -> bool:
	if panel == null or not panel.visible:
		return false
	var hit := panel.get_global_rect().intersection(_plate_center_rect(vp))
	return hit.size.x > 40.0 and hit.size.y > 40.0


func step_a_empty(main, vp: SubViewport) -> void:
	print("- A empty-doc chrome")
	main.show_timeline = false
	main.show_variables = false
	main._update_panel_visibility()
	for i in range(3):
		await process_frame
	check(not main.timeline.visible, "Timeline hidden by default")
	check(not main.variables_panel.visible, "Variables hidden by default")
	check(not _covers_plate_center(main.timeline, vp), "Timeline not over plate center")
	check(not _covers_plate_center(main.variables_panel, vp), "Variables not over plate center")


func step_b_box(main) -> void:
	print("- B box 50×50×5")
	var view = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 5))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var vol: float = view.doc.body_volume(id)
	check(absf(vol - 12500.0) < 1.0, "plate volume ~12500 (got %.1f)" % vol)
	check(view.selected_body == id, "box selected")


func step_c_hole(main) -> void:
	print("- C Hole Apply Ø6 thru")
	var view = main.view
	var id: String = view.selected_body
	var fid: String = view.feature_of_body(id)
	var h: String = view.doc.graph_add_hole(fid, "simple", Vector3(0, 0, 5),
			Vector3(0, 0, -1), 6.0, 0.0, 0.0, 0.0, 0.0, 90.0)
	check(h != "", "hole feature created")
	view.graph_changed()
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
	# Close property panel so Timeline auto-hides and does not hold focus.
	if main.timeline != null and main.timeline.property_panel != null \
			and main.timeline.property_panel.visible:
		main.timeline.property_panel.commit()
		main.hide_timeline_if_idle()
	var has_f := false
	for f in view.doc.graph_features():
		if str(f.get("type")) == "fillet" and not bool(f.get("failed", false)):
			has_f = true
	check(has_f, "fillet on timeline")
	# Oversized re-arm on a disposable doc — never poison the walk document.
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
	# Reselect the plate for Chamfer / later steps.
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
	# Prefer the plate body (first primitive), not the extrude solid.
	var id := ""
	for f in view.doc.graph_features():
		if str(f.get("type")) == "primitive":
			id = str(f.get("output_body", ""))
			break
	if id == "":
		id = str(view.doc.body_ids()[0])
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ops = main.ops_panel
	if ops._hole_type != null:
		ops._hole_type.selected = 3  # leftover Hex — arm must reset
	ops._arm_hole_wizard()
	check(ops._hole_type == null or ops._hole_type.selected == 0, "wizard resets to Simple")
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 5.0) < 1.5:
			top = face_id
			break
	check(top != "", "top face for wizard")
	ops._pending_face = top
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
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	check(main.ops_panel._apply_hex_opening(), "hex opening")
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
	print("- J Analyze min wall + nozzle")
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	var r: Dictionary = view.doc.print_analyze(id)
	check(float(r.get("min_wall", 99)) < 6.5, "min wall ~plate (%.2f)" % float(r.get("min_wall", 99)))
	check(str(r.get("digest", "")).find("nozzle") >= 0, "digest mentions nozzle")


func step_l_docks(main, vp: SubViewport) -> void:
	print("- L docks off plate by default; tight when forced")
	main.show_timeline = false
	main.show_variables = false
	main._update_panel_visibility()
	for i in range(3):
		await process_frame
	check(not main.timeline.visible and not main.variables_panel.visible,
			"docks hidden by default after features")
	# Forced on against the SubViewport size (not the 64×64 root window).
	main.show_timeline = true
	main.show_variables = true
	ChromeDock.rail_right = 56.0
	var sz := Vector2(float(vp.size.x), float(vp.size.y))
	ChromeDock.apply(main.timeline, "timeline", sz)
	ChromeDock.apply(main.variables_panel, "variables", sz)
	main.timeline.visible = true
	main.variables_panel.visible = true
	for i in range(4):
		await process_frame
	check(main.timeline.visible, "Timeline shown when toggled")
	var t_r: Rect2 = main.timeline.get_global_rect()
	var v_r: Rect2 = main.variables_panel.get_global_rect()
	# Tight left column: right edge stays left of plate center (40% of width).
	var mid_x := float(vp.size.x) * 0.4
	check(t_r.end.x <= mid_x + 8.0,
			"Timeline right edge left of plate mid (%.0f <= %.0f)" % [t_r.end.x, mid_x])
	check(v_r.end.x <= mid_x + 8.0,
			"Variables right edge left of plate mid (%.0f <= %.0f)" % [v_r.end.x, mid_x])
