# Rung 1 replan 12 WP3 — a face sketch keeps the canvas next to the left rail clickable after a
# face selection, and Save As inside a sketch keeps the session.
# Real events: Viewport.push_input (motion, press, release), never ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_rail.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan12 WP3 rail clicks and Save As")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _entity_count(sm: SketchMode) -> int:
	return sm.sketch.entity_ids().size()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	await FilmUI.place_primitive(ctx, "box")
	var body: String = ctx.view.selected_body
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "box placed, +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	var sm: SketchMode = main.sketch_mode
	check(sm.active, "face sketch is active")

	var rail: Control = main.sketch_toolbar
	check(rail.visible, "sketch rail is visible")
	var stack: Control = main.left_stack
	var rail_right := rail.get_global_rect().end.x
	var stack_rect := stack.get_global_rect()
	print("  rail right edge %.1f, left_stack rect %s" % [rail_right, str(stack_rect)])
	check(stack_rect.end.x <= rail_right + 12.0,
			"left_stack is no wider than the visible rail (right edge %.1f vs rail %.1f)" % [
			stack_rect.end.x, rail_right])
	check(stack.mouse_filter == Control.MOUSE_FILTER_IGNORE, "left_stack ignores the mouse")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.wait_frames(self, 3)
	check(sm.tool == SketchMode.Tool.CIRCLE, "Circle tool is active")
	var vp_size := Vector2(ROOT_SIZE)
	var y := vp_size.y * 0.5
	var pos := Vector2(rail_right + 30.0, y)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	await process_frame
	var hovered := root.gui_get_hovered_control()
	print("  hovered at (%.0f, %.0f): %s" % [pos.x, pos.y, str(hovered)])
	check(hovered == main.interaction, "the control under the pointer is the viewport Interaction (got %s)" % str(hovered))
	var before := _entity_count(sm)
	await _push_click(pos)
	await _push_click(pos + Vector2(40.0, 0.0))
	check(_entity_count(sm) == before + 1,
			"Circle click 30 px right of the rail adds a circle (entities %d → %d)" % [before, _entity_count(sm)])

	# Save As inside the sketch keeps the session.
	sm.set_tool(SketchMode.Tool.SELECT)
	var fid_before := str(sm.editing_fid)
	var path := "/tmp/sx-replan12-saveas.sxp"
	DirAccess.remove_absolute(path)
	main.current_path = path
	main._save_current()
	await process_frame
	await process_frame
	check(FileAccess.file_exists(path), "Save As wrote %s" % path)
	check(sm.active, "sketch session is still active after Save As")
	check(sm.editing_fid != "", "session edits a saved sketch feature (%s, was '%s')" % [sm.editing_fid, fid_before])
	check(sm.tool == SketchMode.Tool.SELECT, "tool is Select after Save As")
	check(main.sketch_chrome != null and main.sketch_chrome.visible, "sketch finish bar is visible")
	check(_entity_count(sm) == before + 1, "the circle drawn before Save As is still in the sketch")
	var doc2 := SxDocument.new()
	check(doc2.load(path), "saved file loads")
	var has_sketch := false
	for f in doc2.graph_features():
		if str(f.get("type", "")) == "sketch":
			has_sketch = true
	check(has_sketch, "saved file contains the sketch")
	var feats_before: int = ctx.view.doc.graph_features().size()
	main._on_sketch_finish("new", 5.0)
	await process_frame
	await process_frame
	check(ctx.view.doc.graph_features().size() > feats_before,
			"Extrude on the profile works after Save As (%d → %d features)" % [
			feats_before, ctx.view.doc.graph_features().size()])
	DirAccess.remove_absolute(path)
	main.queue_free()
	await process_frame
	await process_frame
