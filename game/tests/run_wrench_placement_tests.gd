# Hex place / hole move / resize remap / flat New — wrench placement gate.
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
	print("wrench placement gate")
	await test_flat_new_and_box_name()
	await test_hex_place_off_center()
	await test_resize_keeps_holes()
	await test_hole_move()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_flat_new_and_box_name() -> void:
	print("- New flat + Box name")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var e = main._world_env.environment
	check(e != null and e.background_mode == Environment.BG_COLOR, "New uses flat background")
	check(not main.show_scenic_bg, "scenic flag off after New")
	var named := false
	for f in main.view.doc.graph_features():
		if str(f.get("name", "")).begins_with("Box"):
			named = true
	check(named, "feature named Box")
	main.queue_free()
	await process_frame


func test_hex_place_off_center() -> void:
	print("- Hex place at end (not body center)")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	view.select_entity(id, "")
	# Grow to a bar so "end" is meaningful.
	view.resize_primitive_aabb(id, Vector3(-70, -21, 0), Vector3(70, 21, 10))
	await process_frame
	id = str(view.doc.body_ids()[0])
	view.select_entity(id, "")
	var top := ""
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 10.0) < 0.5:
			top = face_id
			break
	check(top != "", "top face on bar")
	view.select_entity(id, top)
	var ops = main.ops_panel
	ops._apply_hex_opening()
	check(ops._pending == ops.Pending.HEX_PLACE, "hex arms place pick")
	# Click near +X end.
	ops.handle_viewport_pick(id, top, Vector3(55, 0, 10))
	var hex_pos := Vector3.ZERO
	var found := false
	for f in view.doc.graph_features():
		if str(f.get("type")) != "hole":
			continue
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if p is Dictionary and str(p.get("type", "")) == "hex":
			var arr = p.get("position", [])
			if typeof(arr) == TYPE_ARRAY and arr.size() >= 3:
				hex_pos = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
				found = true
	check(found, "hex feature created")
	check(hex_pos.x > 20.0, "hex not at body center (x=%.1f)" % hex_pos.x)
	# Through: depth 0 → large volume drop.
	var vol: float = view.doc.body_volume(id)
	check(vol < 140.0 * 42.0 * 10.0 - 100.0, "hex cut removes volume (%.1f)" % vol)
	main.queue_free()
	await process_frame


func test_resize_keeps_holes() -> void:
	print("- Resize remaps hole positions")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	var fid: String = view.feature_of_body(id)
	view.doc.graph_add_hole(fid, "simple", Vector3(10, 10, 5), Vector3(0, 0, -1), 6.0, 0.0, 0, 0, 0, 90)
	view.graph_changed()
	var n0 := 0
	for f in view.doc.graph_features():
		if str(f.get("type")) == "hole" and not bool(f.get("failed", false)):
			n0 += 1
	check(n0 >= 1, "hole before resize")
	# Double plate in X (origin stays min corner style).
	check(view.resize_primitive_aabb(id, Vector3(-25, -25, 0), Vector3(75, 25, 5)), "resize ok")
	await process_frame
	id = str(view.doc.body_ids()[0])
	var n1 := 0
	var pos := Vector3.ZERO
	for f in view.doc.graph_features():
		if str(f.get("type")) != "hole" or bool(f.get("failed", false)):
			continue
		n1 += 1
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if p is Dictionary and p.has("position"):
			var a = p["position"]
			pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
	check(n1 >= 1, "hole still non-failed after resize")
	# Old (10,10) in 50-wide plate from -25..25 → frac 0.7 in X → new -25..75 → x=45.
	check(pos.x > 30.0, "hole remapped along X (x=%.1f)" % pos.x)
	main.queue_free()
	await process_frame


func test_hole_move() -> void:
	print("- Hole move via second click")
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
	ops._arm_hole_place(false)
	ops._hole_diameter.value = 6.0
	ops.handle_viewport_pick(id, top, Vector3(-10, -10, 5))
	check(ops._pending == ops.Pending.HOLE_MOVE or ops._hole_move_fid != "",
			"move armed after place")
	ops.handle_viewport_pick(id, top, Vector3(15, 15, 5))
	var pos := Vector3.ZERO
	for f in view.doc.graph_features():
		if str(f.get("type")) != "hole":
			continue
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if p is Dictionary and p.has("position"):
			var a = p["position"]
			pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
	check(pos.x > 5.0 and pos.y > 5.0, "hole moved toward click (%.1f,%.1f)" % [pos.x, pos.y])
	main.queue_free()
	await process_frame
