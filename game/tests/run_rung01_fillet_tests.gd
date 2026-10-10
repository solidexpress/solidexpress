# Rung 1 WP3 — fillets (click Fillet) and timeline double-click.
# Kernel to_face / hex coverage lives in sxkernel/tests/test_rung01_extrude.cpp.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_fillet_tests.gd
extends "res://tests/lib/sx_suite.gd"
const FilletSetsScript = preload("res://scripts/fillet_sets.gd")



func _init() -> void:
	print("rung01 fillet + timeline")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_fillets(main)
	await test_timeline_double_click(main)

	finish()


func test_fillets(main) -> void:
	print("- wrench blank fillets")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var built := _build_wrench(doc)
	check(built.get("ok", false), "wrench blank" if built.get("ok", false) else str(built.get("why", "wrench blank")))
	if not built.get("ok", false):
		return
	view.graph_changed()
	var body: String = built["body"]
	var target: String = built["extrude"]
	var x_neck: float = built["x_neck"]

	var neck := _neck_edges(doc, body, x_neck)
	check(neck.size() == 2, "two neck edges (got %d)" % neck.size())
	if neck.size() != 2:
		return
	var n_fillet_before := _count_type(doc, "fillet")
	check(await _click_fillet(main, body, neck, 10.0), "Fillet click commits R10 on both neck edges")
	check(_count_type(doc, "fillet") == n_fillet_before + 1, "one fillet feature for both neck edges")
	var mesh := doc.get_mesh(body)
	check(_inside(mesh, Vector3(179.0, 10.5, 5.0)), "R10 material at (179, 10.5, 5)")
	check(_inside(mesh, Vector3(179.0, -10.5, 5.0)), "R10 material at (179, -10.5, 5)")
	check(not _inside(mesh, Vector3(174.0, 12.5, 5.0)), "R10 not oversized at (174, 12.5, 5)")

	var floor := _face_at(doc, body, 7.5, 2.0)
	check(floor != "", "slot floor face")
	var floor_edges := FilletSetsScript.edges_of_face(doc, body, floor)
	check(floor_edges.size() >= 4, "floor edge set (got %d)" % floor_edges.size())
	var vol0: float = doc.body_volume(body)
	# graph_add_fillet — the Modify-card Fillet button falls back to a direct
	# fillet for radius <= 10, which would hide a kernel refusal.
	var refused_id: String = doc.graph_add_fillet(target, floor_edges, 1.5)
	check(refused_id == "", "Fillet R1.5 on slot floor is refused")
	var err := doc.last_graph_error()
	check(err.contains("1.25"), "last_graph_error contains limit 1.25 (got '%s')" % err)
	check(absf(doc.body_volume(body) - vol0) < 1e-3, "body unchanged after refused fillet")

	check(await _click_fillet(main, body, floor_edges, 1.0), "Fillet R1 on slot floor")
	mesh = doc.get_mesh(body)
	check(_inside(mesh, Vector3(93.5, 4.9, 7.6)), "slot floor corner material (93.5, 4.9, 7.6)")

	var top := _face_at(doc, body, 10.0, 40.0)
	var top_edges := FilletSetsScript.edges_of_face(doc, body, top)
	check(top_edges.size() >= 4, "top face edge set")
	check(await _click_fillet(main, body, top_edges, 1.0), "Fillet R1 on top face")
	mesh = doc.get_mesh(body)
	check(not _inside(mesh, Vector3(-9.9, 0, 9.9)), "R1 top removes (-9.9, 0, 9.9)")
	check(_inside(mesh, Vector3(-9.7, 0, 5.0)), "outer wall solid at (-9.7, 0, 5)")

	var bottom := _face_at(doc, body, 0.0, 40.0)
	var bottom_edges := FilletSetsScript.edges_of_face(doc, body, bottom)
	check(bottom_edges.size() >= 4, "bottom face edge set")
	check(await _click_fillet(main, body, bottom_edges, 1.0), "Fillet R1 on bottom face")
	mesh = doc.get_mesh(body)
	check(not _inside(mesh, Vector3(-9.9, 0, 0.1)), "R1 bottom removes (-9.9, 0, 0.1)")
	# target is used so the blank stays tied to the extrude feature the click path edits
	check(target != "", "fillets target the blank extrude")


func test_timeline_double_click(main) -> void:
	print("- timeline double-click")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var sk := SxSketch.new()
	sk.add_line(-10, -10, 10, -10)
	sk.add_line(10, -10, 10, 10)
	sk.add_line(10, 10, -10, 10)
	sk.add_line(-10, 10, -10, -10)
	var sk_fid: String = doc.graph_add_sketch(sk)
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 8.0, false, "new", "")
	check(sk_fid != "" and ex_fid != "", "sketch + extrude on the timeline")
	view.graph_changed()
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	var tl: TimelinePanel = main.timeline
	tl.refresh()
	await process_frame

	var ex_btn := _row_name_button(tl, ex_fid)
	check(ex_btn != null, "extrude row has a name button")
	if ex_btn != null:
		_double_click(ex_btn)
		await process_frame
		check(tl.property_panel.visible, "double-click extrude opens the property panel")
		check(_panel_has_label(tl.property_panel, "Distance"), "panel shows Distance")
		check(_panel_has_label(tl.property_panel, "End"), "panel shows End")

	var sk_btn := _row_name_button(tl, sk_fid)
	check(sk_btn != null, "sketch row has a name button")
	if sk_btn != null:
		_double_click(sk_btn)
		await process_frame
		check(main.sketch_mode.active, "double-click sketch enters the editor")
		check(main.sketch_mode.editing_fid == sk_fid, "editor is the double-clicked sketch")


func _build_wrench(doc: SxDocument) -> Dictionary:
	var dx := sqrt(22.5 * 22.5 - 100.0)
	var xhit := 200.0 - dx
	var ang := atan2(10.0, -dx)
	var sk := SxSketch.new()
	sk.add_arc(0, 0, 10.0, PI / 2.0, 3.0 * PI / 2.0)
	sk.add_line(0, -10, xhit, -10)
	sk.add_arc(200.0, 0, 22.5, -ang, ang)
	sk.add_line(xhit, 10, 0, 10)
	var sk_fid: String = doc.graph_add_sketch(sk)
	if sk_fid == "":
		return {"ok": false, "why": "sketch feature failed: " + doc.last_graph_error()}
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	if ex_fid == "":
		return {"ok": false, "why": "extrude failed: " + doc.last_graph_error()}
	var body := ""
	for f in doc.graph_features():
		if str(f["id"]) == ex_fid:
			body = str(f["output_body"])
	if body == "":
		return {"ok": false, "why": "extrude has no body"}
	var slot := SxSketch.new()
	slot.set_plane(Vector3(0, 0, 10), Vector3(1, 0, 0), Vector3(0, 1, 0))
	slot.add_line(13.5, -5, 173.5, -5)
	slot.add_line(173.5, -5, 173.5, 5)
	slot.add_line(173.5, 5, 13.5, 5)
	slot.add_line(13.5, 5, 13.5, -5)
	var slot_fid: String = doc.graph_add_sketch(slot)
	var cut: String = doc.graph_add_extrude(slot_fid, -2.5, false, "cut", ex_fid, "blind")
	if cut == "":
		return {"ok": false, "why": "slot cut failed: " + doc.last_graph_error()}
	return {"ok": true, "body": body, "extrude": ex_fid, "x_neck": xhit, "why": ""}


func _neck_edges(doc: SxDocument, body: String, x_neck: float) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: Dictionary = doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.is_empty():
			continue
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(mid.x - x_neck) < 1.5 and absf(absf(mid.y) - 10.0) < 0.5 and absf(mid.z - 5.0) < 1.0:
			out.append(str(eid))
	return out


func _face_at(doc: SxDocument, body: String, z_want: float, y_abs_max: float) -> String:
	var best := ""
	var best_d := 1e30
	for fid in doc.get_face_ids(body):
		var mid: Vector3 = doc.face_midpoint(fid)
		if absf(mid.y) > y_abs_max:
			continue
		var d := absf(mid.z - z_want)
		if d < best_d:
			best_d = d
			best = fid
	if best_d > 1.0:
		return ""
	return best


func _click_fillet(main, body: String, edges: PackedStringArray, radius: float) -> bool:
	var view: DocumentView = main.view
	if edges.is_empty():
		return false
	var arr: Array[String] = []
	for e in edges:
		arr.append(str(e))
	view.select_edge(body, arr[0])
	view.selected_edges = arr
	view.selected_body = body
	view.selected_edge = arr[0]
	view.selection_changed.emit(body, "")
	await process_frame
	var ops: OpsPanel = main.ops_panel
	var spin: SpinBox = ops._radius_spin
	if spin == null:
		return false
	spin.step = 0.001
	spin.value = radius
	var btn := _find_button(ops, "Round the selected edges")
	if btn == null or not btn.is_visible_in_tree():
		printerr("  Fillet button not visible")
		return false
	btn.pressed.emit()
	await process_frame
	return doc_has_success(view.doc)


func doc_has_success(doc: SxDocument) -> bool:
	return doc.last_graph_error() == ""


func _count_type(doc: SxDocument, type: String) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == type:
			n += 1
	return n


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and child.text != "":
			return child
	return null


func _double_click(btn: Button) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	btn.gui_input.emit(ev)


func _panel_has_label(panel: Node, text: String) -> bool:
	if panel is Label and str((panel as Label).text) == text:
		return true
	for child in panel.get_children():
		if _panel_has_label(child, text):
			return true
	return false


func _find_button(node: Node, tooltip_substr: String) -> Button:
	if node is Button and str(node.tooltip_text).contains(tooltip_substr):
		return node
	for child in node.get_children():
		var found := _find_button(child, tooltip_substr)
		if found != null:
			return found
	return null


func _inside(mesh: ArrayMesh, pt: Vector3) -> bool:
	var tris: Array = []
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			continue
		for i in range(0, idx.size(), 3):
			tris.append([verts[idx[i]], verts[idx[i + 1]], verts[idx[i + 2]]])
	var votes := 0
	for d in [Vector3(1, 0.0123, 0.0071), Vector3(0.0091, 1, 0.0137), Vector3(0.0113, 0.0067, 1)]:
		var dir: Vector3 = d.normalized()
		var hits := 0
		for t in tris:
			if _ray_hit(pt, dir, t[0], t[1], t[2]):
				hits += 1
		if hits % 2 == 1:
			votes += 1
	return votes >= 2


func _ray_hit(orig: Vector3, dir: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var e1 := b - a
	var e2 := c - a
	var pvec := dir.cross(e2)
	var det := e1.dot(pvec)
	if absf(det) < 1e-12:
		return false
	var inv := 1.0 / det
	var s := orig - a
	var u := s.dot(pvec) * inv
	if u < 0.0 or u > 1.0:
		return false
	var q := s.cross(e1)
	var v := dir.dot(q) * inv
	if v < 0.0 or u + v > 1.0:
		return false
	var t := e2.dot(q) * inv
	return t > 1e-7
