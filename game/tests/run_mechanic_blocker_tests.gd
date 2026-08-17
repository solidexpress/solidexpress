# Mechanic-blocker regressions: thin-plate hole, wizard picks, fillet edges.
# Run: tools/godot/godot --headless --path game --script tests/run_mechanic_blocker_tests.gd
extends SceneTree

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
	print("mechanic blocker regressions")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_thin_plate_hole(main)
	await test_hole_wizard_picks(main)
	await test_fillet_edge_arm(main)
	await test_sim_format(main)
	await test_hide_toggle(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_thin_plate_hole(main) -> void:
	print("- Ø6 through-hole on 50×50×5 plate")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 5))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ops: OpsPanel = main.ops_panel
	check(not ops._hole_diameter_too_large(id, 6.0), "Ø6 not rejected on 5 mm plate")
	# Dialog must expose an Apply button (not a blank ConfirmationDialog).
	ops._prompt_hole()
	await process_frame
	var win: Window = null
	for c in ops.get_children():
		if c is Window and str(c.title) == "Hole":
			win = c
			break
	check(win != null, "Hole Window opened")
	var apply_btn: Button = null
	if win != null:
		apply_btn = win.find_child("HoleApply", true, false) as Button
	check(apply_btn != null, "Hole Window has Apply button")
	ops._hole_diameter.value = 6.0
	ops._hole_depth.value = 0.0
	var vol0: float = view.doc.body_volume(id)
	if apply_btn != null:
		apply_btn.pressed.emit()
		await process_frame
	else:
		check(ops._apply_hole(), "Apply hole on thin plate (fallback)")
	var vol1: float = view.doc.body_volume(id)
	check(vol1 < vol0 - 50.0, "hole cut volume (%.1f → %.1f)" % [vol0, vol1])
	var r: Dictionary = view.doc.print_analyze(id)
	check(float(r.get("min_wall", 99)) < 6.0, "analyze min wall ~plate (%.2f)" % float(r.get("min_wall", 99)))
	check(str(r.get("digest", "")).find("nozzle") >= 0, "digest mentions nozzle")


func test_hole_wizard_picks(main) -> void:
	print("- Hole Wizard accumulates points without face refine wiping them")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 40, 10))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ops: OpsPanel = main.ops_panel
	ops._arm_hole_wizard()
	check(ops.is_hole_wizard_armed(), "wizard armed")
	check(ops.consumes_viewport_pick(), "wizard consumes viewport picks")
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 10.0) < 0.5:
			top = face_id
			break
	check(top != "", "top face found")
	ops.handle_viewport_pick(id, top, Vector3(10, 10, 10))
	ops.handle_viewport_pick(id, top, Vector3(30, 10, 10))
	ops.handle_viewport_pick(id, top, Vector3(20, 30, 10))
	check(ops.hole_wizard_point_count() == 3, "3 wizard points (got %d)" % ops.hole_wizard_point_count())
	check(ops._apply_holes_btn != null and not ops._apply_holes_btn.disabled, "Apply holes enabled")
	var vol0: float = view.doc.body_volume(id)
	check(ops._apply_hole_wizard(), "wizard commit")
	check(view.doc.body_volume(id) < vol0 - 50.0, "wizard cut volume")


func test_fillet_edge_arm(main) -> void:
	print("- Fillet arm accumulates edges (not faces)")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 50))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ops: OpsPanel = main.ops_panel
	ops.arm_or_apply_fillet()
	check(ops._pending == ops.Pending.FILLET_EDGES, "fillet armed")
	# Use a real edge midpoint from the kernel polyline.
	var pick_pt := Vector3.ZERO
	var lines: Dictionary = view.doc.get_edge_lines(id)
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.size() >= 2:
			pick_pt = (pts[0] + pts[1]) * 0.5
			break
	ops.handle_viewport_pick(id, "", pick_pt)
	check(view.selected_edges.size() >= 1 or view.selected_edge != "",
			"edge selected while fillet armed")
	check(view.selected_face == "", "face not selected over edge")
	var vol0: float = view.doc.body_volume(id)
	check(ops.try_commit_pending(), "Enter commits fillet")
	check(view.doc.body_volume(id) < vol0, "fillet removed material")


func test_sim_format(main) -> void:
	print("- Sim Solve shows a number, not %%g")
	main._on_mode_menu(4)
	await process_frame
	var rail = main.sim_rail
	check(rail != null and rail.visible, "Sim rail visible")
	rail._solve()
	check(str(rail._result.text).find("%") < 0, "result has no format %% (%s)" % rail._result.text)
	check(str(rail._result.text).find("δ") >= 0, "result shows delta")


func test_hide_toggle(main) -> void:
	print("- Hide toggles; Unhide all restores")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	await process_frame
	main.interaction._ctx_hide()
	check(view.hidden_bodies.has(id), "body hidden")
	# Selection cleared on hide — second Hide with empty selection unhides all.
	main.interaction._ctx_hide()
	check(not view.hidden_bodies.has(id), "second Hide unhides")
	main.interaction._ctx_hide()
	view.unhide_all()
	check(not view.hidden_bodies.has(id), "Unhide all clears")
