# Wrench blockers: Chamfer reachable, sketch at real scale, rail never covered.
extends SceneTree

var failures := 0
var checks := 0

func check(c: bool, w: String) -> void:
	checks += 1
	if c: print("  ok   - " + w)
	else:
		failures += 1
		printerr("  FAIL - " + w)

func _init() -> void:
	print("wrench blockers cut")
	await test_configurable_fillet()
	await test_chamfer_reachable()
	await test_sketch_scale_and_guard()
	await test_rail_never_covered()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_configurable_fillet() -> void:
	print("- configurable Fillet: strip arms, Radius chip, Enter commits")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var view = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 5))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ix = main.interaction
	var ops = main.ops_panel
	# Pre-select an edge — strip Fillet must still ARM (not instant-apply fail).
	var edges = view.doc.get_edge_ids(id)
	check(edges.size() > 0, "box has edges")
	view.select_edge(id, str(edges[0]))
	ops._radius_spin.value = 2.0  # would fail on short edges if instant-applied
	var strip_fillet: Button = ix.find_child("StripFillet", true, false)
	check(strip_fillet != null, "StripFillet exists")
	strip_fillet.pressed.emit()
	check(ops._pending == ops.Pending.FILLET_EDGES, "strip Fillet arms even with edge selected")
	var strip_r: Control = ix.find_child("StripDressupRadius", true, false)
	check(strip_r != null and strip_r.visible, "strip Radius chip visible while armed")
	var strip_spin: SpinBox = ix.find_child("StripRadius", true, false)
	check(strip_spin != null, "StripRadius SpinBox exists")
	# Reduce radius via the strip chip, then Enter.
	strip_spin.value = 0.5
	ops.set_dressup_radius(0.5)
	check(is_equal_approx(ops.dressup_radius(), 0.5), "dressup radius is 0.5")
	check(ops.try_commit_pending(), "Enter commits fillet at r=0.5")
	var has_f := false
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet" and not bool(f.get("failed", false)):
			has_f = true
	check(has_f, "fillet feature on timeline")
	check(ops._pending == ops.Pending.NONE, "pending cleared after success")
	# Oversized radius re-arms and keeps the Radius chip.
	view.select_entity(id, "")
	view.select_edge(id, str(edges[1] if edges.size() > 1 else edges[0]))
	strip_fillet.pressed.emit()
	ops.set_dressup_radius(40.0)
	var ok_big: bool = ops.try_commit_pending()
	check(not ok_big or ops._pending == ops.Pending.FILLET_EDGES \
			or ops._pending == ops.Pending.NONE,
			"oversized fillet does not leave chrome dead")
	if not ok_big:
		check(ops._pending == ops.Pending.FILLET_EDGES, "oversized fillet re-arms pick")
		check(strip_r.visible, "Radius chip stays after failed fillet")
	main.queue_free()
	await process_frame


func test_chamfer_reachable() -> void:
	print("- Chamfer on the selection strip + context menu")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var view = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 5))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ix = main.interaction
	var strip_chamfer: Button = ix.find_child("StripChamfer", true, false)
	check(strip_chamfer != null, "StripChamfer exists")
	check(strip_chamfer != null and strip_chamfer.visible, "StripChamfer visible with body")
	# Context menu carries it too.
	ix._open_context_menu(Vector2(200, 200))
	var found := false
	for i in ix._context_menu.item_count:
		if str(ix._context_menu.get_item_text(i)) == "Chamfer":
			found = true
	check(found, "context menu has Chamfer")
	ix._context_menu.hide()
	# Strip Chamfer arms the pick, and Enter commits after an edge.
	strip_chamfer.pressed.emit()
	var ops = main.ops_panel
	check(ops._pending == ops.Pending.CHAMFER_EDGES, "strip Chamfer arms edge pick")
	var edges = view.doc.get_edge_ids(id)
	view.select_edge(id, str(edges[0]))
	ops._radius_spin.value = 0.5
	check(ops.try_commit_pending(), "Enter commits chamfer")
	var has_ch := false
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "chamfer" and not bool(f.get("failed", false)):
			has_ch = true
	check(has_ch, "chamfer feature on timeline")
	main.queue_free()
	await process_frame


func test_sketch_scale_and_guard() -> void:
	print("- sketch view scale floor + degenerate segment guard")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# A tiny 5 mm blank must not shrink the sketch working view.
	main.view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	await process_frame
	var cam = main.camera
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "ortho sketch view")
	check(cam.size >= SketchMode.MIN_SKETCH_VIEW_MM,
			"sketch view >= %.0f mm (got %.2f)" % [SketchMode.MIN_SKETCH_VIEW_MM, cam.size])
	var sm = main.sketch_mode
	sm.set_tool(SketchMode.Tool.LINE)
	var n0: int = sm.sketch.entity_ids().size()
	var last_status := [""]
	sm.status.connect(func(t: String) -> void: last_status[0] = t)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(0.2, 0))  # below MIN_SEGMENT_MM — must name view span
	check(sm.sketch.entity_ids().size() == n0, "degenerate line refused")
	check(str(last_status[0]).contains("view is") and str(last_status[0]).contains("mm across"),
			"degenerate refusal names view span (%s)" % last_status[0])
	sm.click(Vector2(30, 0))     # real drag still works
	check(sm.sketch.entity_ids().size() == n0 + 1, "real line committed")
	main.queue_free()
	await process_frame


func test_rail_never_covered() -> void:
	print("- Variables / Timeline never overlap the left rail")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Empty document (Variables visible from seeded builtins).
	main._update_panel_visibility()
	for i in range(4):
		await process_frame
	check(main.variables_panel.visible, "variables visible on empty doc")
	check(not _overlaps(main.variables_panel, main.left_stack),
			"variables clear of left rail (empty doc)")
	# With features: timeline + variables both clear.
	main.view.insert_primitive("box", Vector3.ZERO)
	main._update_panel_visibility()
	for i in range(4):
		await process_frame
	check(main.timeline.visible, "timeline visible")
	check(not _overlaps(main.timeline, main.left_stack), "timeline clear of left rail")
	check(not _overlaps(main.variables_panel, main.left_stack), "variables clear of rail")
	check(not _overlaps(main.timeline, main.variables_panel),
			"variables clear of timeline (not stacked)")
	var tw: float = main.timeline.offset_right - main.timeline.offset_left
	check(tw > 200.0 and tw < 320.0, "timeline has fixed width ~260 (got %.0f)" % tw)
	check(main.timeline.size.x <= 270.0,
			"timeline rendered width <= 270 (got %.0f)" % main.timeline.size.x)
	check(main.variables_panel.get_global_rect().position.x \
			>= main.timeline.get_global_rect().end.x - 1.0,
			"variables sits to the right of timeline")
	main.queue_free()
	await process_frame


func _overlaps(a: Control, b: Control) -> bool:
	if a == null or b == null or not a.visible or not b.visible:
		return false
	var ra := a.get_global_rect()
	var rb := b.get_global_rect()
	if ra.size.x <= 1.0 or rb.size.x <= 1.0:
		return false
	var hit := ra.intersection(rb)
	return hit.size.x > 1.0 and hit.size.y > 1.0
