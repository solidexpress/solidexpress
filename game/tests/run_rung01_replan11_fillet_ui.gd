extends "res://tests/lib/sx_suite.gd"
## Needs WP2. LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_fillet_ui.gd


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
	await _test_same_length_twin_toggle(main, view, ops)
	main.queue_free()
	finish()

func _mid(view, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return (pts[0] + pts[pts.size() - 1]) * 0.5


## Two parallel 50 mm top edges sit 5 mm apart. A face-hit 2.6 mm inward of
## the picked edge is closer to its same-length twin, so nearest-id would add
## a second `50.0 mm line` instead of toggling the first off.
func _test_same_length_twin_toggle(main, view, ops) -> void:
	ops.cancel_pending_pick()
	view.clear_selection()
	var thin: String = view.insert_primitive("box", Vector3(80, 0, 0), Vector3(50, 5, 10))
	await main.get_tree().process_frame
	var longs: Array[String] = _top_long_edges(view, thin)
	check(longs.size() == 2, "thin box has two top long edges (got %d)" % longs.size())
	if longs.size() < 2:
		return
	var a: String = longs[0]
	var b: String = longs[1]
	view.select_entity(thin, "")
	ops.arm_or_apply_fillet()
	var mid_a := _mid(view, thin, a)
	var mid_b := _mid(view, thin, b)
	ops._accumulate_dressup_edge(thin, mid_a, "")
	check(view.selected_edges.has(a) and view.selected_edges.size() == 1,
			"first 50 mm edge is the only pick (got %s)" % str(view.selected_edges))
	var toward := (mid_b - mid_a).normalized() * 2.6
	ops._accumulate_dressup_edge(thin, mid_a + toward, "")
	check(not view.selected_edges.has(a), "inward re-click removes the picked 50 mm edge")
	check(not view.selected_edges.has(b),
			"the same-length twin was not added (edges %s)" % str(view.selected_edges))
	check(view.selected_edges.is_empty() and view.selected_edge == "",
			"the set is empty after toggle-off")
	check(str(main.status_label.text).contains("removed"),
			"status names the removal (got %s)" % main.status_label.text)
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "toggle-off keeps Fillet armed")
	ops._accumulate_dressup_edge(thin, mid_a, "")
	ops._accumulate_dressup_edge(thin, mid_b, "")
	check(view.selected_edges.has(a) and view.selected_edges.has(b) \
			and view.selected_edges.size() == 2,
			"clicking the actual twin adds it (edges %s)" % str(view.selected_edges))
	ops._accumulate_dressup_edge(thin, mid_a, "")
	check(not view.selected_edges.has(a) and view.selected_edges.has(b),
			"exact re-click still removes only that edge")


func _top_long_edges(view, body: String) -> Array[String]:
	var out: Array[String] = []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(d.x) >= 40.0 and absf(d.y) < 0.3 and absf(d.z) < 0.3 and mid.z > 5.0:
			out.append(str(id))
	return out
