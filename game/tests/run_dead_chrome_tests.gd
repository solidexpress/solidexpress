# Click-driven coverage for previously dead / optionless chrome.
# Run: tools/godot/godot --headless --path game --script tests/run_dead_chrome_tests.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("dead-chrome repair tests")
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	root.add_child(vp)
	var main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	for i in range(4):
		await process_frame

	check(main.view != null and main.view.doc != null, "DocumentView alive")

	var bodies0: int = int(main.view.doc.body_ids().size())
	var id: String = main.view.insert_hex_driver_blank()
	check(id != "" and int(main.view.doc.body_ids().size()) == bodies0 + 1, "hex driver catalog insert")

	main.view.new_document()
	# Tall cylinder (r=5, h=40) so Thread accepts it as shaft-like.
	main.view.doc.graph_add_primitive("cylinder", 5, 40, 0, Vector3.ZERO)
	main.view.graph_changed()
	await process_frame
	var bid: String = str(main.view.doc.body_ids()[0])
	main.view.select_entity(bid, "")
	main._update_panel_visibility()
	await process_frame
	main.ops_panel._apply_thread()
	await process_frame
	var has_thread := false
	for f in main.view.doc.graph_features():
		if str(f.get("type", "")) == "thread":
			has_thread = true
	check(has_thread, "Thread feature created on cylinder")

	main.ops_panel._hole_diameter.value = 6.0
	check(is_equal_approx(main.ops_panel._hole_diameter.value, 6.0),
			"Hole Ø 6.0 sticks (got %.3f)" % main.ops_panel._hole_diameter.value)

	# Fresh doc before mode chrome (drawing HLR on a threaded solid is slow).
	main.view.new_document()
	await process_frame

	main._on_mode_menu(3)
	await process_frame
	check(main.cam_rail != null and main.cam_rail.visible, "Cam rail visible")
	main._on_mode_menu(4)
	await process_frame
	check(main.sim_rail != null and main.sim_rail.visible, "Sim rail visible")
	main._on_mode_menu(1)
	await process_frame
	check(main.drawing_sheet.visible, "Draw sheet visible")
	check(main.drawing_sheet.find_child("DrawTools", true, false) != null, "Draw tools present")
	main._on_mode_menu(2)
	await process_frame
	check(main.sheet_metal_view.visible, "Sheet view visible")
	check(main.sheet_metal_view.find_child("SheetTools", true, false) != null, "Sheet tools present")
	main._on_mode_menu(5)
	await process_frame
	check(main.print_strip.visible, "Form print strip visible")
	check(main.print_strip.find_child("PrintParams", true, false) != null, "Form print params present")
	main._on_mode_menu(0)
	await process_frame

	check(main._slicer_dialog != null, "Slicer dialog built")
	check(main._drawing_options != null, "Drawing options dialog built")
	check(main.has_method("open_feature_params"), "open_feature_params helper present")
	check(main.view.doc.has_method("set_print_setup"), "set_print_setup bound")
	check(main.view.doc.has_method("thread_table"), "thread_table bound")
	check(main.view.doc.has_method("cam_post_gcode"), "cam_post_gcode bound")
	check(main.view.doc.has_method("graph_add_draft"), "graph_add_draft bound")
	check(main.view.doc.has_method("sxp_component_info"), "sxp_component_info bound")
	check(main._insert_dialog != null, "Insert Components dialog built")
	check(main._paste_as_instance != null, "Paste Special has instance option")
	check(main._rail_extrude != null and main._rail_revolve != null, "left-rail Extrude/Revolve present")
	check(main._rail_sweep != null and main._rail_loft != null, "left-rail Sweep/Loft present")
	check(main._datum_dialog != null, "Datum offset dialog built")
	check(main.interaction != null and main.interaction.hole_preview != null,
			"Hole Wizard preview overlay mounted")

	# Thread refuses a box.
	main.view.new_document()
	main.view.doc.graph_add_primitive("box", 40, 40, 40, Vector3(-20, -20, 0))
	main.view.graph_changed()
	await process_frame
	var box_id: String = str(main.view.doc.body_ids()[0])
	main.view.select_entity(box_id, "")
	main._update_panel_visibility()
	await process_frame
	main.ops_panel._apply_thread()
	await process_frame
	var threaded_box := false
	for f in main.view.doc.graph_features():
		if str(f.get("type", "")) == "thread":
			threaded_box = true
	check(not threaded_box, "Thread refuses a box")

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
