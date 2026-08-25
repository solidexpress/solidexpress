# TriBall Esc, hex in-face clamp, hole feature pick — post-#41 polish.
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
	print("triball / hex polish gate")
	await test_triball_esc()
	await test_hex_stays_on_face()
	await test_hex_feature_pick()
	await test_flat_material()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_triball_esc() -> void:
	print("- TriBall Esc clears active; end_drag does not copy")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var ix = main.interaction
	var id: String = str(main.view.doc.body_ids()[0])
	main.view.select_entity(id, "")
	ix._ctx_triball()
	check(ix.triball != null and ix.triball.active, "TriBall armed")
	var n0: int = main.view.doc.instance_list().size()
	ix.triball.begin_drag(ix.triball.origin + Vector3(10, 0, 0))
	ix.triball.update_drag(ix.triball.origin + Vector3(0, 10, 0))
	ix.triball.end_drag()
	check(main.view.doc.instance_list().size() == n0, "end_drag does not create copies")
	# Esc via Interaction key path
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ix._gui_key(ev)
	check(not ix.triball.active and not ix.triball.visible, "Esc cancels TriBall active")
	# Fillet can arm after
	var edges = main.view.doc.get_edge_ids(id)
	main.view.select_edge(id, str(edges[0]))
	main.ops_panel.arm_or_apply_fillet()
	check(main.ops_panel._pending == main.ops_panel.Pending.FILLET_EDGES,
			"Fillet arms after TriBall Esc")
	main.queue_free()
	await process_frame


func test_hex_stays_on_face() -> void:
	print("- Hex near edge stays fully on solid")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	view.resize_primitive_aabb(id, Vector3(-70, -21, 0), Vector3(70, 21, 10))
	await process_frame
	id = str(view.doc.body_ids()[0])
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 10.0) < 0.5:
			top = face_id
			break
	view.select_entity(id, top)
	var ops = main.ops_panel
	ops._apply_hex_opening()
	# Click very close to the -Y edge — must clamp inward.
	ops.handle_viewport_pick(id, top, Vector3(50, -20.5, 10))
	var pos := Vector3.ZERO
	var af := 10.3
	for f in view.doc.graph_features():
		if str(f.get("type")) != "hole":
			continue
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if p is Dictionary and str(p.get("type")) == "hex":
			var a = p.get("position", [])
			pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
			var d = p.get("diameter", 10.3)
			if typeof(d) == TYPE_FLOAT:
				af = float(d)
	var R := af / sqrt(3.0)
	var bb: Dictionary = view.doc.measure_bbox(id)
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	check(pos.y >= mn.y + R - 0.2, "hex center inset from -Y (y=%.2f R=%.2f)" % [pos.y, R])
	check(pos.y <= mx.y - R + 0.2, "hex center inset from +Y")
	check(pos.x >= mn.x + R - 0.2, "hex center inset from -X")
	check(pos.x <= mx.x - R + 0.2, "hex center inset from +X")
	main.queue_free()
	await process_frame


func test_hex_feature_pick() -> void:
	print("- Clicking hex selects hole feature (not only an edge)")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 5.0) < 0.5:
			top = face_id
			break
	view.select_entity(id, top)
	var ops = main.ops_panel
	ops._apply_hex_opening()
	ops.handle_viewport_pick(id, top, Vector3(0, 0, 5))
	await process_frame
	# Clear pending move, then pick near hex center.
	ops.cancel_pending_pick()
	var hid: String = view.hole_feature_near_point(id, Vector3(0, 0, 5))
	check(hid != "", "hole_feature_near_point finds hex")
	ops.show_hole_feature(hid)
	check(ops._hole_type != null and ops._hole_type.selected == 3, "Type = hex")
	check(ops._pending == ops.Pending.NONE, "select does not auto-arm move")
	check(ops._selected_hole_fid == hid, "selected hole fid set")
	# Timeline name
	var hex_named := false
	for f in view.doc.graph_features():
		if str(f.get("id")) == hid and str(f.get("name", "")).begins_with("hex"):
			hex_named = true
	check(hex_named, "timeline row named hex N")
	main.queue_free()
	await process_frame


func test_flat_material() -> void:
	print("- Flat scenic reflections")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	check(not main.view._scenic_reflections, "scenic reflections off after New")
	main.view.set_scenic_reflections(true)
	check(main.view._scenic_reflections, "scenic reflections can enable")
	main.view.set_scenic_reflections(false)
	check(is_equal_approx(main.view._body_metal(), main.view.BODY_METALLIC_FLAT),
			"flat metallic after scenic off")
	main.queue_free()
	await process_frame
