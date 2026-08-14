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

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_empty_document_hides_context(main) -> void:
	print("- empty document shows no context panels")
	check(not main.card_box.visible, "selection card hidden")
	check(not main.ops_panel.visible, "ops panel hidden")
	check(not main.timeline.visible, "timeline hidden")
	check(not main.variables_panel.visible, "variables hidden")
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
	print("- variables panel: View menu override and data-driven show")
	check(not main.variables_panel.visible, "hidden with no variables")
	main.show_variables = true
	main._update_panel_visibility()
	check(main.variables_panel.visible, "View menu override shows it")
	main.show_variables = false
	main._update_panel_visibility()
	check(not main.variables_panel.visible, "hidden again when override off")
	main.view.doc.set_variable("w", "40")
	main.view.graph_changed()
	await process_frame
	check(main.variables_panel.visible, "visible once a variable exists")
	# With no timeline, the variables panel slides to the left edge.
	check(main.variables_panel.offset_left == 12, "flush left without timeline")
	main.view.insert_primitive("box", Vector3(50, 0, 0))
	await process_frame
	check(main.variables_panel.offset_left == 280, "beside the timeline when both shown")


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
