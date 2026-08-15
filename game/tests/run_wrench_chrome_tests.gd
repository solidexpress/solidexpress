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
	print("wrench chrome tests (Wave 6.6)")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_insert_menu_has_thread(main)
	await test_hole_wizard_from_context_strip(main)
	test_cut_default_end_through_all(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_insert_menu_has_thread(main) -> void:
	print("- Insert menu surfaces Thread…")
	var insert_btn: MenuButton = main.find_child("InsertMenu", true, false)
	check(insert_btn != null, "Insert menu button exists")
	if insert_btn == null:
		return
	var pop := insert_btn.get_popup()
	var has_thread := false
	for i in pop.item_count:
		if not pop.is_item_separator(i) and str(pop.get_item_text(i)) == "Thread…":
			has_thread = true
			break
	check(has_thread, "Insert menu contains Thread…")


func test_hole_wizard_from_context_strip(main) -> void:
	print("- Hole Wizard reachable from SelectionStrip")
	var view: DocumentView = main.view
	view.new_document()
	var body: String = view.insert_primitive("box", Vector3.ZERO)
	check(body != "", "inserted a box")
	view.select_entity(body, "")
	await process_frame
	var strip: PanelContainer = main.interaction.find_child("SelectionStrip", true, false)
	check(strip != null and strip.visible, "selection strip visible with a selected body")
	if strip == null:
		return
	var wiz: Button = strip.find_child("StripHoleWizard", true, false)
	check(wiz != null and wiz.is_visible_in_tree(), "Hole Wizard button visible")
	if wiz != null:
		wiz.pressed.emit()
		await process_frame
		check(main.ops_panel.is_hole_wizard_armed(), "Hole Wizard armed via context strip")


func test_cut_default_end_through_all(main) -> void:
	print("- Extrude Cut defaults End to Through All")
	main.view.new_document()
	main._start_sketch()
	await process_frame
	var chrome: SketchContextChrome = main.sketch_chrome
	check(chrome != null and chrome.visible, "sketch chrome visible")
	if chrome == null:
		return
	chrome.set_finish_op("cut")
	# Without user override, selecting Cut should set End to Through All.
	check(chrome.get_finish_end() == "through_all", "Cut end default is through_all")

