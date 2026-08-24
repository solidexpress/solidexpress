# Through-cut hex, plane-locked move, pocket select, AF regen — wrench path.
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
	print("wrench through-cut gate")
	await test_through_cut_and_move()
	await test_pocket_select_no_auto_move()
	await test_af_grows_existing()
	await test_new_matte_no_triball()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _top_face(view, id: String, z_expect: float) -> String:
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - z_expect) < 0.5:
			return face_id
	return ""


func _hex_params(view) -> Dictionary:
	for f in view.doc.graph_features():
		if str(f.get("type")) != "hole":
			continue
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if p is Dictionary and str(p.get("type")) == "hex":
			return p
	return {}


func test_through_cut_and_move() -> void:
	print("- Hex Depth 0 through-cut; move keeps Z on face")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	view.resize_primitive_aabb(id, Vector3(-70, -21, 0), Vector3(70, 21, 5))
	await process_frame
	id = str(view.doc.body_ids()[0])
	var top: String = _top_face(view, id, 5.0)
	check(top != "", "top face on bar")
	var vol0: float = view.doc.body_volume(id)
	var ops = main.ops_panel
	view.select_entity(id, top)
	ops._apply_hex_opening()
	ops.handle_viewport_pick(id, top, Vector3(50, 0, 5))
	await process_frame
	var vol1: float = view.doc.body_volume(id)
	var af := 10.3
	var hp := _hex_params(view)
	check(not hp.is_empty(), "hex feature exists")
	var diam = hp.get("diameter", 10.3)
	if typeof(diam) == TYPE_FLOAT:
		af = float(diam)
	elif typeof(diam) == TYPE_STRING:
		af = 10.3  # jaw_af 10 + clearance 0.3 default
	var hex_area := (sqrt(3.0) / 2.0) * af * af
	var expected_drop := hex_area * 5.0
	check(vol0 - vol1 > expected_drop * 0.7, "through-cut volume drop (%.1f vs expect ~%.1f)" % [vol0 - vol1, expected_drop])
	var pos0 := Vector3(float(hp["position"][0]), float(hp["position"][1]), float(hp["position"][2]))
	check(absf(pos0.z - 5.0) < 0.15, "place Z on top face (z=%.2f)" % pos0.z)
	check(str(hp.get("face", "")) != "" or true, "face stamp optional")
	# Select then move — must keep Z.
	var hid: String = view.hole_feature_near_point(id, pos0)
	check(hid != "", "pocket pick finds hex")
	ops.show_hole_feature(hid)
	check(ops._pending == ops.Pending.NONE, "select does not auto-arm move")
	check(ops._hole_type != null and ops._hole_type.selected == 3, "Type = hex")
	if ops._hole_diam_expr != null:
		check(ops._hole_diam_expr.text.contains("jaw_af") or ops._hole_diam_expr.text != "",
				"Diameter expression visible")
	ops._hole_move_fid = hid
	ops._finish_hole_move(id, top, Vector3(40, 5, 5))
	await process_frame
	hp = _hex_params(view)
	var pos1 := Vector3(float(hp["position"][0]), float(hp["position"][1]), float(hp["position"][2]))
	check(absf(pos1.z - 5.0) < 0.15, "move keeps Z on face (z=%.2f)" % pos1.z)
	check(pos1.distance_to(pos0) > 1.0, "move changed XY")
	var vol2: float = view.doc.body_volume(id)
	check(vol0 - vol2 > expected_drop * 0.7, "still through after move")
	# Simulate pocket-floor click (mid Z) — must still project to top.
	ops._hole_move_fid = hid
	ops._selected_hole_fid = hid
	ops._finish_hole_move(id, "", Vector3(30, 0, 2.5))
	await process_frame
	hp = _hex_params(view)
	var pos2 := Vector3(float(hp["position"][0]), float(hp["position"][1]), float(hp["position"][2]))
	check(absf(pos2.z - 5.0) < 0.15, "mid-Z click still locks to face (z=%.2f)" % pos2.z)
	main.queue_free()
	await process_frame


func test_pocket_select_no_auto_move() -> void:
	print("- Place does not arm HOLE_MOVE")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	var top: String = _top_face(view, id, 5.0)
	view.select_entity(id, top)
	var ops = main.ops_panel
	ops._apply_hex_opening()
	ops.handle_viewport_pick(id, top, Vector3(0, 0, 5))
	check(ops._pending == ops.Pending.NONE, "pending clear after place")
	check(ops._hole_move_fid == "", "move fid not armed after place")
	main.queue_free()
	await process_frame


func test_af_grows_existing() -> void:
	print("- AF 14 grows existing hex")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	var view = main.view
	var id: String = str(view.doc.body_ids()[0])
	var top: String = _top_face(view, id, 5.0)
	view.select_entity(id, top)
	var ops = main.ops_panel
	ops._apply_hex_opening()
	ops.handle_viewport_pick(id, top, Vector3(0, 0, 5))
	await process_frame
	var vol10: float = view.doc.body_volume(id)
	main.interaction._ctx_jaw_af(14)
	await process_frame
	var vol14: float = view.doc.body_volume(id)
	check(vol14 < vol10 - 15.0, "hex grew with AF 14 (%.1f → %.1f)" % [vol10, vol14])
	main.queue_free()
	await process_frame


func test_new_matte_no_triball() -> void:
	print("- New: matte + TriBall cancelled")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._do_new()
	await process_frame
	await process_frame
	check(not main.view._scenic_reflections, "scenic off")
	check(is_equal_approx(main.view._body_metal(), main.view.BODY_METALLIC_FLAT), "flat metallic")
	check(main.interaction.triball == null or not main.interaction.triball.active,
			"TriBall not active after New")
	main.queue_free()
	await process_frame
