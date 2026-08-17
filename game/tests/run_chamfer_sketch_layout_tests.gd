# Chamfer apply + sketch extrude keep-alive + layout clear of left rail.
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
	print("chamfer/sketch/layout cut")
	await test_chamfer_enter_applies()
	await test_extrude_keeps_open_sketch()
	await test_extrude_closes_and_solids()
	await test_timeline_clear_of_rail()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_chamfer_enter_applies() -> void:
	print("- chamfer pick + commit creates feature")
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
	var ops = main.ops_panel
	ops._radius_spin.value = 4.0
	ops._chamfer_all()
	check(ops._pending == ops.Pending.CHAMFER_EDGES, "armed after fail")
	var lines = view.doc.get_edge_ids(id)
	view.select_edge(id, str(lines[0]))
	ops._radius_spin.value = 0.5
	# Simulate Enter in the radius field.
	ops._radius_spin.get_line_edit().text_submitted.emit("0.5")
	await process_frame
	var has_ch := false
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "chamfer" and not bool(f.get("failed", false)):
			has_ch = true
	check(has_ch, "chamfer feature on timeline after Enter")
	main.queue_free()
	await process_frame


func test_extrude_keeps_open_sketch() -> void:
	print("- Extrude of open profile keeps sketch session")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	var sm = main.sketch_mode
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(20, 0))
	sm.click(Vector2(20, 15))  # open L
	var bodies0 = main.view.doc.body_ids().size()
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	check(sm.active, "sketch still active after open Extrude")
	check(main.view.doc.body_ids().size() == bodies0, "no body from open Extrude")
	main.queue_free()
	await process_frame


func test_extrude_closes_and_solids() -> void:
	print("- nearly-closed chain auto-closes; polygon Extrude solids")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	var sm = main.sketch_mode
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(20, 0))
	sm.click(Vector2(20, 20))
	sm.click(Vector2(0, 20))
	sm.click(Vector2(0.3, 0.3))  # nearly back to origin — leave a small gap
	# Don't click origin — let Extrude close it.
	var bodies0 = main.view.doc.body_ids().size()
	sm.finish_extrude(12.0, "new", "blind")
	await process_frame
	check(not sm.active, "sketch ended after closed Extrude")
	check(main.view.doc.body_ids().size() == bodies0 + 1, "solid body from auto-close")
	var has_ex := false
	for f in main.view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			has_ex = true
	check(has_ex, "extrude on timeline")
	main.queue_free()
	await process_frame


func test_timeline_clear_of_rail() -> void:
	print("- Timeline/Variables clear of left rail")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.view.insert_primitive("box", Vector3.ZERO)
	main._update_panel_visibility()
	await process_frame
	await process_frame
	var rail_right = main._CHROME_PAD + main._RAIL_ICON_W
	check(main.timeline.offset_left >= rail_right, "timeline right of rail (%.1f)" % main.timeline.offset_left)
	check(main.variables_panel.offset_left >= main.timeline.offset_left,
			"variables at/after timeline")
	main.queue_free()
	await process_frame
