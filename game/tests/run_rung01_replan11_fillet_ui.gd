extends SceneTree
## Needs WP2. LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_fillet_ui.gd

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
	print("rung01 replan11 WP3 fillet ui")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var view = main.view
	var ops = main.ops_panel
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 10, 10))
	await process_frame
	view.select_entity(body, "")
	ops._on_picked(body, "", Vector3.ZERO)
	check(ops._pending != OpsPanel.Pending.FILLET_EDGES, "body click does not arm fillet")
	var edges: PackedStringArray = view.doc.get_edge_ids(body)
	check(edges.size() >= 2, "two edges")
	ops.arm_or_apply_fillet()
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet button arms")
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[0]), "")
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[1]), "")
	var status_add: String = main.status_label.text
	check(status_add.contains("mm"), "status lists a length (got %s)" % status_add)
	check(view.selected_edges.has(edges[0]) and view.selected_edges.has(edges[1]), "both edges selected")
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[0]), "")
	check(not view.selected_edges.has(edges[0]), "re-click removes the edge")
	check(main.status_label.text.contains("removed"), "status says removed")
	# Refusal names the limit. Radius 50 cannot fit a 10 mm edge.
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[0]), "")
	ops.set_dressup_radius(50.0)
	ops.try_commit_pending()
	var refused: String = main.status_label.text
	check(refused.contains("exceeds the"), "limit refusal (got %s)" % refused)
	check(refused.contains("mm"), "limit refusal names the edge")
	check(refused.contains("click it again to remove it"), "limit refusal tells the user to re-click")
	check(not refused.contains("too large for selected edge"), "the old sentence is gone")
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "refusal keeps the set armed")
	# Face first.
	ops.cancel_pending_pick()
	view.selected_edges.clear()
	view.selected_edge = ""
	var faces: PackedStringArray = view.doc.get_face_ids(body)
	view.select_entity(body, faces[0])
	ops.arm_or_apply_fillet()
	var committed: bool = ops._commit_armed_dressup()
	check(not main.status_label.text.contains("No edges selected"), "face-first does not cancel (got %s)" % main.status_label.text)
	check(committed or view.selected_edges.size() > 0 or main.status_label.text.contains("applied") or main.status_label.text.contains("fillet the R10 neck first") or main.status_label.text.contains("exceeds the"),
			"face-first applies or names a real refusal")
	main.queue_free()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _mid(view, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return (pts[0] + pts[pts.size() - 1]) * 0.5
