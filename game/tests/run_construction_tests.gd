# Wave 6 construction chrome: post-place W/H/D, hole/thread/hex, variables.
# Run: tools/godot/godot --headless --path game --script tests/run_construction_tests.gd
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
	print("construction usability tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_palette_has_sketch_and_torus(main)
	await test_post_place_whd(main)
	await test_typed_12_sticks(main)
	await test_hole_cuts_and_analyze_changes(main)
	await test_hex_opening_tracks_jaw_af(main)
	await test_o_hotkey_without_focus(main)
	await test_hole_wizard_arms_from_body(main)
	test_insert_thread_and_sketch(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_palette_has_sketch_and_torus(main) -> void:
	print("- left rail has Sketch and Torus")
	var sketch: Button = main.find_child("PaletteSketch", true, false)
	check(sketch != null, "Sketch button on palette")
	check(_find_palette_kind(main.palette, "torus") != null, "Torus palette button exists")


func _find_palette_kind(n: Node, kind: String) -> PaletteButton:
	if n is PaletteButton and n.kind == kind:
		return n
	for c in n.get_children():
		var hit := _find_palette_kind(c, kind)
		if hit != null:
			return hit
	return null


func test_post_place_whd(main) -> void:
	print("- placed box keeps W/H/D")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 15, 10))
	view.select_entity(id, "")
	main._update_panel_visibility()
	await process_frame
	var ix: ViewportInteraction = main.interaction
	ix._refresh_transform_hud()
	check(ix.transform_hud.visible and ix.transform_hud._dims_row.visible,
		"TransformHud W/H/D visible after place")
	check(absf(ix.transform_hud.current_size().x - 20.0) < 1e-3, "HUD W is 20")
	var ops: OpsPanel = main.ops_panel
	check(ops._size_row != null and ops._size_row.visible, "OpsPanel W/H/D row visible")
	ops._size_w.value = 30.0
	var bb: Dictionary = view.doc.measure_bbox(id)
	var sz: Vector3 = bb["max"] - bb["min"]
	check(absf(sz.x - 30.0) < 1e-2, "editing W resizes the box (got %.3f)" % sz.x)


func test_typed_12_sticks(main) -> void:
	print("- Enter commits 1.2 not 1.1")
	var view: DocumentView = main.view
	view.new_document()
	var ix: ViewportInteraction = main.interaction
	ix.insert_at_center("box")
	await process_frame
	var h: SpinBox = ix.transform_hud._size_h
	h.get_line_edit().text = "1.2"
	h.apply()
	check(absf(h.value - 1.2) < 1e-6, "spin value is 1.2 (got %s)" % h.value)
	check(absf(ix.place_size.y - 1.2) < 1e-6, "place_size H is 1.2")


func test_hole_cuts_and_analyze_changes(main) -> void:
	print("- hole at body center cuts; analyze digest changes")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	view.select_entity(id, "")
	await process_frame
	var before: Dictionary = view.doc.print_analyze(id)
	var vol0: float = view.doc.body_volume(id)
	var ops: OpsPanel = main.ops_panel
	ops._hole_diameter.value = 6.0
	ops._hole_depth.value = 0.0
	if ops._hole_type != null:
		ops._hole_type.selected = 0
	check(ops._apply_hole(), "Apply hole on body (no face) succeeds")
	var vol1: float = view.doc.body_volume(id)
	check(vol1 < vol0 - 50.0, "hole removed volume (%.1f → %.1f)" % [vol0, vol1])
	var after: Dictionary = view.doc.print_analyze(id)
	check(str(after.get("digest", "")) != str(before.get("digest", "")),
		"analyze digest changes after hole")


func test_hex_opening_tracks_jaw_af(main) -> void:
	print("- hex opening consumes jaw_af + clearance")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 40, 10))
	view.select_entity(id, "")
	await process_frame
	var vol0: float = view.doc.body_volume(id)
	var ops: OpsPanel = main.ops_panel
	check(ops._apply_hex_opening(), "hex opening applied")
	var vol10: float = view.doc.body_volume(id)
	check(vol10 < vol0 - 100.0, "hex cut removed volume at AF 10")
	check(view.doc.set_variable("jaw_af", "14"), "jaw_af → 14")
	view.graph_changed()
	var vol14: float = view.doc.body_volume(id)
	check(vol14 < vol10 - 20.0, "hex grows when jaw_af becomes 14 (%.1f → %.1f)" % [vol10, vol14])


func test_o_hotkey_without_focus(main) -> void:
	print("- O applies hole without Interaction focus")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	view.select_entity(id, "")
	await process_frame
	var vol0: float = view.doc.body_volume(id)
	var ix: ViewportInteraction = main.interaction
	ix.release_focus()
	var ev := InputEventKey.new()
	ev.keycode = KEY_O
	ev.pressed = true
	ix._gui_key(ev)
	await process_frame
	var vol1: float = view.doc.body_volume(id)
	check(vol1 < vol0 - 50.0, "O cut a hole without focus (%.1f → %.1f)" % [vol0, vol1])


func test_hole_wizard_arms_from_body(main) -> void:
	print("- Hole Wizard arms from body-only selection")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	view.select_entity(id, "")
	await process_frame
	main.ops_panel._arm_hole_wizard()
	check(main.ops_panel.is_hole_wizard_armed(), "wizard armed without a face")


func test_insert_thread_and_sketch(main) -> void:
	print("- Insert menu has Thread, Sketch, Hex opening")
	var insert_btn: MenuButton = main.find_child("InsertMenu", true, false)
	check(insert_btn != null, "Insert menu exists")
	if insert_btn == null:
		return
	var pop := insert_btn.get_popup()
	var found := {}
	for i in pop.item_count:
		if not pop.is_item_separator(i):
			found[str(pop.get_item_text(i))] = true
	check(found.has("Thread…"), "Insert → Thread…")
	check(found.has("Sketch…"), "Insert → Sketch…")
	check(found.has("Hex opening…"), "Insert → Hex opening…")
