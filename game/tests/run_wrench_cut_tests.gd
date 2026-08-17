# Wrench-cut: Line draws, polygon extrudes, wizard/chamfer picks not stolen.
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
	print("wrench cut regressions")
	await test_line_and_polygon_extrude()
	await test_wizard_with_face_selected_press()
	await test_chamfer_pick_after_fallback()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_line_and_polygon_extrude() -> void:
	print("- LINE clicks + polygon Across Flats extrude")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm.active, "sketch active")
	sm.set_tool(SketchMode.Tool.LINE)
	var n0: int = sm.sketch.entity_ids().size()
	sm.click(Vector2(0, 0))
	sm.click(Vector2(30, 0))
	check(sm.sketch.entity_ids().size() == n0 + 1, "LINE two clicks → 1 entity")
	# Fresh sketch for polygon
	sm.cancel()
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	sm = main.sketch_mode
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.set_tool_variant("across_flats")
	sm.click(Vector2(0, 0))
	sm.click(Vector2(12, 0))
	check(sm.sketch.entity_ids().size() >= 6, "polygon created ≥6 lines (got %d)" % sm.sketch.entity_ids().size())
	check(SketchMode.profile_is_closed(sm.sketch), "polygon profile closed")
	var bodies0: int = main.view.doc.body_ids().size()
	sm.finish_extrude(8.0, "new", "blind")
	await process_frame
	check(main.view.doc.body_ids().size() == bodies0 + 1, "extrude created solid body")
	# Pending polygon tip auto-commits on Extrude.
	main._start_sketch_on_ground()
	await process_frame
	sm = main.sketch_mode
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.set_tool_variant("across_flats")
	sm.click(Vector2(0, 0))
	check(sm.has_pending_draw_point(), "pending polygon tip")
	sm._hover = Vector2(15, 0)
	bodies0 = main.view.doc.body_ids().size()
	sm.finish_extrude(5.0, "new", "blind")
	await process_frame
	check(main.view.doc.body_ids().size() == bodies0 + 1, "extrude auto-committed pending polygon")
	main.queue_free()
	await process_frame


func test_wizard_with_face_selected_press() -> void:
	print("- Hole Wizard: face-selected press must not start push-pull")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	FilmUI_noop()
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 40, 10))
	var top := _top_face(view, id, 10.0)
	check(top != "", "top face")
	view.select_entity(id, top)
	main._update_panel_visibility()
	await process_frame
	var ops: OpsPanel = main.ops_panel
	ops.interaction = main.interaction
	ops._arm_hole_wizard()
	check(ops.consumes_viewport_pick(), "wizard consumes picks")
	var ix: ViewportInteraction = main.interaction
	# Press on selected face while wizard armed — must NOT enter PUSH_PULL.
	var screen := Vector2(400, 300)
	ix._on_press(screen)
	check(ix._drag_mode != ix.DragMode.PUSH_PULL, "press did not start push-pull (mode=%s)" % ix._drag_mode)
	check(not ix._pending_body_move, "press did not arm body move")
	# Release as a click should accumulate via consume path.
	# Use model pick directly for reliability of count:
	var mid: Vector3 = view.doc.face_midpoint(top)
	ops.handle_viewport_pick(id, top, mid)
	ops.handle_viewport_pick(id, top, mid + Vector3(8, 5, 0))
	check(ops.hole_wizard_point_count() == 2, "2 wizard points")
	check(ops._apply_holes_btn != null and not ops._apply_holes_btn.disabled, "Apply holes enabled")
	var vol0: float = view.doc.body_volume(id)
	check(ops._apply_hole_wizard(), "wizard apply")
	check(view.doc.body_volume(id) < vol0 - 20.0, "wizard cut")
	main.queue_free()
	await process_frame


func test_chamfer_pick_after_fallback() -> void:
	print("- Chamfer all-edges fail then edge pick accumulates")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 5))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ops: OpsPanel = main.ops_panel
	# Force a value that fails all-edges on a thin plate, then pick.
	ops._radius_spin.value = 4.0
	ops._chamfer_all()
	check(ops._pending == ops.Pending.CHAMFER_EDGES, "chamfer pick armed after fail")
	var ix: ViewportInteraction = main.interaction
	ix._on_press(Vector2(400, 300))
	check(ix._drag_mode != ix.DragMode.PUSH_PULL, "chamfer press not push-pull")
	check(not ix._pending_body_move, "chamfer press not body-move")
	var lines: Dictionary = view.doc.get_edge_lines(id)
	var pick_pt := Vector3.ZERO
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.size() >= 2:
			pick_pt = (pts[0] + pts[1]) * 0.5
			break
	ops.handle_viewport_pick(id, "", pick_pt)
	check(view.selected_edge != "" or view.selected_edges.size() > 0, "chamfer edge accumulated")
	var vol0: float = view.doc.body_volume(id)
	check(ops.try_commit_pending(), "chamfer commit")
	check(view.doc.body_volume(id) != vol0, "chamfer changed volume")
	main.queue_free()
	await process_frame


func _top_face(view: DocumentView, body: String, z: float) -> String:
	for face_id in view.doc.get_face_ids(body):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - z) < 0.5:
			return face_id
	return ""


func FilmUI_noop() -> void:
	pass
