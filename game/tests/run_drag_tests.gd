# Headless tests for SELECT-tool drag-to-edit: hit-testing, state machine,
# and live kernel commits through SxSketch.set_entity_geometry + re-solve.
# Run: tools/godot/godot --headless --path game --script tests/run_drag_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("sketch drag-to-edit tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_drag_hit_line_parts(main.sketch_mode)
	test_drag_hit_circle_parts(main.sketch_mode)
	test_drag_state_machine_and_preview(main.sketch_mode)
	test_whole_line_preview_delta(main.sketch_mode)
	test_circle_center_and_radius_preview(main.sketch_mode)
	test_line_tool_drag_noop(main.sketch_mode)
	test_constraint_wins_during_drag(main.sketch_mode)

	finish()


func _setup_line(sk: SketchMode) -> String:
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.infer_enabled = false
	sk.set_tool(SketchMode.Tool.LINE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0))
	sk.end_chain()
	return sk.sketch.entity_ids()[0]


func _setup_circle(sk: SketchMode) -> String:
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.infer_enabled = false
	sk.set_tool(SketchMode.Tool.CIRCLE)
	sk.click(Vector2(10, 10))
	sk.click(Vector2(20, 10))  # r=10
	return sk.sketch.entity_ids()[0]


func test_drag_hit_line_parts(sk: SketchMode) -> void:
	print("- drag_hit line start / end / whole")
	var eid := _setup_line(sk)
	sk.set_tool(SketchMode.Tool.SELECT)

	var h_end: Dictionary = sk.drag_hit(Vector2(40, 0))
	check(h_end.get("id", "") == eid and h_end.get("part", "") == "end",
		"hit near (40,0) is end")

	var h_start: Dictionary = sk.drag_hit(Vector2(0, 0))
	check(h_start.get("id", "") == eid and h_start.get("part", "") == "start",
		"hit near (0,0) is start")

	var h_whole: Dictionary = sk.drag_hit(Vector2(20, 0))
	check(h_whole.get("id", "") == eid and h_whole.get("part", "") == "whole",
		"hit mid-segment is whole")

	var h_miss: Dictionary = sk.drag_hit(Vector2(100, 100))
	check(h_miss.is_empty(), "far pick returns {}")
	sk.cancel()


func test_drag_hit_circle_parts(sk: SketchMode) -> void:
	print("- drag_hit circle center / radius")
	var eid := _setup_circle(sk)
	sk.set_tool(SketchMode.Tool.SELECT)

	var h_c: Dictionary = sk.drag_hit(Vector2(10, 10))
	check(h_c.get("id", "") == eid and h_c.get("part", "") == "center",
		"hit at center is center")

	var h_r: Dictionary = sk.drag_hit(Vector2(20, 10))
	check(h_r.get("id", "") == eid and h_r.get("part", "") == "radius",
		"hit on rim is radius")
	sk.cancel()


func test_drag_state_machine_and_preview(sk: SketchMode) -> void:
	print("- begin/update/end drag state + preview")
	var eid := _setup_line(sk)
	sk.set_tool(SketchMode.Tool.SELECT)
	check(sk._drag.is_empty(), "idle: _drag empty")

	sk.begin_drag(Vector2(40, 0))
	check(not sk._drag.is_empty(), "begin_drag populates _drag")
	check(sk._drag.get("id", "") == eid and sk._drag.get("part", "") == "end",
		"drag targets end of line")
	check(sk._preview_node.mesh != null, "preview mesh after begin_drag")

	sk.update_drag(Vector2(40, 10))
	var prev: Dictionary = sk._drag["preview_info"]
	check(prev["end"].distance_to(Vector2(40, 10)) < 1e-4,
		"preview end follows cursor (got %s)" % str(prev["end"]))
	check(prev["start"].distance_to(Vector2(0, 0)) < 1e-4,
		"preview start stays put")
	# Live commit: the kernel entity moves with the drag.
	var live: Dictionary = sk.sketch.entity_info(eid)
	check(live["end"].distance_to(Vector2(40, 10)) < 1e-3,
		"kernel end committed to (40,10) during drag (got %s)" % str(live["end"]))

	sk.end_drag()
	check(sk._drag.is_empty(), "end_drag clears _drag")
	check(sk._preview_node.mesh == null, "preview cleared after end_drag")
	var after: Dictionary = sk.sketch.entity_info(eid)
	check(after["end"].distance_to(Vector2(40, 10)) < 1e-3,
		"kernel keeps the dragged geometry after end")
	sk.cancel()


func test_whole_line_preview_delta(sk: SketchMode) -> void:
	print("- whole-line drag preview translates both ends")
	var eid := _setup_line(sk)
	sk.set_tool(SketchMode.Tool.SELECT)
	sk.begin_drag(Vector2(20, 0))
	check(sk._drag.get("part", "") == "whole", "grab mid is whole")
	sk.update_drag(Vector2(20, 15))
	var prev: Dictionary = sk._drag["preview_info"]
	check(prev["start"].distance_to(Vector2(0, 15)) < 1e-4, "start +delta")
	check(prev["end"].distance_to(Vector2(40, 15)) < 1e-4, "end +delta")
	sk.end_drag()
	var live: Dictionary = sk.sketch.entity_info(eid)
	check(live["start"].distance_to(Vector2(0, 15)) < 1e-3
		and live["end"].distance_to(Vector2(40, 15)) < 1e-3,
		"whole-line drag committed to kernel")
	sk.cancel()


func test_circle_center_and_radius_preview(sk: SketchMode) -> void:
	print("- circle center / radius drag preview")
	var eid := _setup_circle(sk)
	sk.set_tool(SketchMode.Tool.SELECT)

	sk.begin_drag(Vector2(10, 10))
	check(sk._drag.get("part", "") == "center", "center grab")
	sk.update_drag(Vector2(25, 30))
	var prev_c: Dictionary = sk._drag["preview_info"]
	check(prev_c["center"].distance_to(Vector2(25, 30)) < 1e-4, "center preview moves")
	check(absf(prev_c["radius"] - 10.0) < 1e-4, "radius unchanged on center drag")
	sk.end_drag()
	var live: Dictionary = sk.sketch.entity_info(eid)
	check(live["center"].distance_to(Vector2(25, 30)) < 1e-3, "center drag committed")

	sk.begin_drag(Vector2(35, 30))  # rim of the moved circle
	check(sk._drag.get("part", "") == "radius", "rim grab")
	sk.update_drag(Vector2(25, 45))  # dist from center (25,30) = 15
	var prev_r: Dictionary = sk._drag["preview_info"]
	check(absf(prev_r["radius"] - 15.0) < 1e-4,
		"radius preview = cursor dist (got %f)" % prev_r["radius"])
	check(prev_r["center"].distance_to(Vector2(25, 30)) < 1e-4, "center fixed on rim drag")
	sk.end_drag()
	var live_r: Dictionary = sk.sketch.entity_info(eid)
	check(absf(float(live_r["radius"]) - 15.0) < 1e-3, "radius drag committed")
	sk.cancel()


func test_line_tool_drag_noop(sk: SketchMode) -> void:
	print("- LINE tool: drag is a no-op")
	_setup_line(sk)
	sk.set_tool(SketchMode.Tool.LINE)
	sk.begin_drag(Vector2(40, 0))
	check(sk._drag.is_empty(), "begin_drag ignored on LINE tool")
	sk.update_drag(Vector2(40, 10))
	check(sk._drag.is_empty(), "update_drag no-op when idle")
	sk.end_drag()
	check(sk._drag.is_empty(), "end_drag no-op when idle")
	sk.cancel()


func test_constraint_wins_during_drag(sk: SketchMode) -> void:
	print("- horizontal constraint holds while dragging an endpoint")
	var eid := _setup_line(sk)
	sk.set_tool(SketchMode.Tool.SELECT)
	sk.sketch.add_constraint("horizontal", [{"entity": eid, "role": "self"}], 0.0)
	sk.run_solve()

	sk.begin_drag(Vector2(40, 0))
	sk.update_drag(Vector2(50, 10))
	sk.end_drag()
	var live: Dictionary = sk.sketch.entity_info(eid)
	check(absf(float(live["start"].y) - float(live["end"].y)) < 1e-3,
		"line stays horizontal after drag (y %f vs %f)" % [live["start"].y, live["end"].y])
	check(live["end"].x > 45.0, "endpoint x followed the drag (got %f)" % live["end"].x)
	sk.cancel()
