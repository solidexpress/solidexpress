# Headless layout-hygiene tests: context panels auto-hide when empty, and no
# two visible text controls or top-level panels overlap on screen.
# Run: tools/godot/godot --headless --path game --script tests/run_layout_tests.gd
extends SceneTree

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
	print("layout tests")
	# The headless window is pinned to 64x64, so host the scene in a
	# desktop-sized SubViewport and let the UI anchors resolve against that.
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	root.add_child(vp)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	vp.add_child(main)
	await process_frame
	await process_frame

	test_empty_document_hides_context(main)
	await test_selection_toggles_card(main)
	await test_timeline_appears_with_features(main)
	await test_variables_panel_visibility(main)
	await test_no_text_collisions(main)
	await test_busy_state_on_screen(main, vp, Vector2i(1600, 900))
	await test_busy_state_on_screen(main, vp, Vector2i(1280, 720))

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Busy chrome (body + timeline + hole PropertyPanel + assembly) must stay on-screen.
func test_busy_state_on_screen(main, vp: SubViewport, size: Vector2i) -> void:
	print("- busy chrome on-screen at %dx%d" % [size.x, size.y])
	vp.size = size
	for i in range(3):
		await process_frame
	main.view.new_document()
	main.view.doc.graph_add_primitive("box", 40, 40, 40, Vector3(-20, -20, 0))
	main.view.graph_changed()
	await process_frame
	var bid: String = str(main.view.doc.body_ids()[0])
	main.view.select_entity(bid, "")
	main._update_panel_visibility()
	for i in range(4):
		await process_frame
	# Open a hole feature's property panel so the timeline grows.
	var top := ""
	for fid in main.view.doc.get_face_ids(bid):
		var bb: Dictionary = main.view.doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		if absf(float(bb["min"].z) - 40.0) < 1e-3:
			top = fid
	if top != "":
		main.view.select_entity(bid, top)
		main._update_panel_visibility()
		await process_frame
		main.ops_panel._apply_hole()
		await process_frame
		for f in main.view.doc.graph_features():
			if str(f.get("type", "")) == "hole":
				main.open_feature_params(str(f.get("id", "")))
				break
	for i in range(4):
		await process_frame
	if main.timeline != null and main.timeline.has_method("_clamp_height"):
		main.timeline._clamp_height()
	if main.assembly_panel != null and main.assembly_panel.has_method("_clamp_height"):
		main.assembly_panel._clamp_height()
	for i in range(3):
		await process_frame
	var limit_y := float(size.y) - 30.0  # status bar
	for panel in [main.timeline, main.ops_panel, main.assembly_panel, main.card_box]:
		if panel == null or not panel.visible:
			continue
		var r: Rect2 = panel.get_global_rect()
		check(r.position.y + r.size.y <= limit_y + 2.0,
				"%s bottom on-screen at %dx%d (%.0f <= %.0f)" % [
					panel.name, size.x, size.y, r.position.y + r.size.y, limit_y])
		check(r.position.x >= -1.0 and r.position.x + r.size.x <= float(size.x) + 1.0,
				"%s horizontally on-screen at %dx%d" % [panel.name, size.x, size.y])


func test_empty_document_hides_context(main) -> void:
	print("- empty document shows no context panels")
	check(not main.card_box.visible, "selection card hidden")
	check(not main.ops_panel.visible, "ops panel hidden")
	check(not main.timeline.visible, "timeline hidden")
	# Wave 6.2 seeds clearance / hole_compensation / layer / nozzle / jaw_af, so
	# the variables panel is visible on an empty document by design.
	check(main.variables_panel.visible, "variables visible (seeded builtins)")
	check(main.view.doc.list_variables().size() >= 5, "seeded print builtins present")
	check(not main.sketch_toolbar.visible, "sketch toolbar hidden")
	check(main.print_strip == null or not main.print_strip.visible, "print strip hidden")


func test_selection_toggles_card(main) -> void:
	print("- selection card follows selection")
	var body: String = main.view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	main.view.select_entity(body, "")
	main._update_panel_visibility()
	check(main.card_box.visible, "card visible with selection")
	check(main.ops_panel.visible, "ops panel visible with selection")
	check(not main.palette.visible, "primitives palette hidden while selected")
	check(main.ops_panel.offset_left == 8.0, "ops panel docked left while selected")
	main.view.clear_selection()
	main._update_panel_visibility()
	check(not main.card_box.visible, "card hidden after deselect")
	check(not main.ops_panel.visible, "ops panel hidden after deselect")
	check(main.palette.visible, "primitives palette restored after deselect")


func test_timeline_appears_with_features(main) -> void:
	print("- timeline appears with first feature")
	# insert_primitive from the previous test already created a graph feature.
	check(main.timeline.visible, "timeline visible once a feature exists")
	var fids: Array = main.view.doc.graph_features()
	check(fids.size() > 0, "graph has features")
	for f in fids:
		main.view.doc.graph_remove(f["id"])
	main.view.graph_changed()
	await process_frame
	check(not main.timeline.visible, "timeline hidden after last feature removed")


func test_variables_panel_visibility(main) -> void:
	print("- variables panel: seeded builtins + View menu override")
	# Builtins keep the panel visible; View-menu override is still the entry
	# point when every variable is deleted.
	check(main.variables_panel.visible, "visible with seeded builtins")
	main.show_variables = true
	main._update_panel_visibility()
	check(main.variables_panel.visible, "View menu override shows it")
	main.show_variables = false
	main._update_panel_visibility()
	check(main.variables_panel.visible, "still visible via seeded builtins")
	# With no timeline, the variables panel sits beside the left rail (not on it).
	# Absolute left-edge flush is Phase 2; for now assert it is on screen.
	check(main.variables_panel.offset_left >= 0.0, "variables on-screen")
	main.view.insert_primitive("box", Vector3(50, 0, 0))
	await process_frame
	check(main.timeline.visible, "timeline appears with feature")
	check(main.variables_panel.visible, "variables still visible beside timeline")


func test_no_text_collisions(main) -> void:
	print("- no visible text controls overlap (all panels forced on)")
	# Force the busiest realistic state: body selected, sketch toolbar shown,
	# timeline + variables populated.
	var body := ""
	for b in main.view.doc.body_ids():
		body = b
	main.view.select_entity(body, "")
	# Enter sketch mode for real so modal chrome (selection strip hides,
	# sketch toolbar shows) matches what users actually see.
	main._start_sketch()
	# The ops panel clamps its height one frame after selection; give layout
	# a few frames to settle before measuring.
	for i in range(4):
		await process_frame

	var ui: CanvasLayer = main.get_node("UI")
	var texts: Array = []
	_collect_text_controls(ui, texts)
	check(texts.size() > 20, "collected text controls (%d)" % texts.size())
	var collisions := 0
	for i in range(texts.size()):
		for j in range(i + 1, texts.size()):
			var a: Control = texts[i]
			var b: Control = texts[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ra := _clipped_rect(a)
			var rb := _clipped_rect(b)
			var inter := ra.intersection(rb)
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				collisions += 1
				printerr("    overlap: %s ('%s') vs %s ('%s')" %
					[_describe(a), _text_of(a), _describe(b), _text_of(b)])
	check(collisions == 0, "no text collisions (%d found)" % collisions)

	# Top-level panels under the UI layer must not overlap each other either.
	var panels: Array = []
	for child in ui.get_children():
		if child is PanelContainer and child.visible:
			panels.append(child)
	var panel_hits := 0
	for i in range(panels.size()):
		for j in range(i + 1, panels.size()):
			var inter: Rect2 = panels[i].get_global_rect().intersection(panels[j].get_global_rect())
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				panel_hits += 1
				printerr("    panel overlap: %s vs %s" % [panels[i].name, panels[j].name])
	check(panel_hits == 0, "no top-level panel overlaps (%d found)" % panel_hits)
	main.sketch_mode.cancel()
	main.sketch_toolbar.visible = false


func _collect_text_controls(node: Node, out: Array) -> void:
	if node is Control and not node.visible:
		return
	if (node is Label or node is Button or node is LineEdit or node is SpinBox
			or node is OptionButton or node is CheckBox):
		if node.is_visible_in_tree():
			out.append(node)
		# Composite controls (SpinBox) own internal LineEdits; don't descend.
		if node is SpinBox or node is OptionButton:
			return
	for child in node.get_children():
		_collect_text_controls(child, out)


## Global rect clipped by any clipping ancestor (e.g. rows scrolled out of a
## ScrollContainer occupy no visible screen space).
func _clipped_rect(c: Control) -> Rect2:
	var rect := c.get_global_rect()
	var node: Node = c.get_parent()
	while node != null and not (node is CanvasLayer):
		if node is Control and (node.clip_contents or node is ScrollContainer):
			rect = rect.intersection((node as Control).get_global_rect())
		node = node.get_parent()
	return rect


func _describe(c: Control) -> String:
	return "%s(%s)" % [c.get_class(), c.get_path()]


func _text_of(c: Control) -> String:
	if c is Label or c is Button or c is LineEdit:
		return str(c.text).left(24)
	return ""
