# UI tests for multi-doc Insert Components (Video 5), Fix/Float restraints
# (Video 6), plane_parallel mates (Video 7), and reference-geometry insert
# after components (Video 8). Exercises Insert menu chrome + AssemblyPanel.
# Run: tools/godot/godot --headless --path game --script tests/run_insert_component_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

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
	print("insert component / assembly slice tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_insert_menu_components_item(main)
	await test_insert_sxp_workflow(main)
	await test_fix_float_restraint(main)
	await test_plane_parallel_mate_ui(main)
	await test_reference_geometry_after_insert(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _ctx(main) -> FilmContext:
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	return ctx


func _part_path() -> String:
	return OS.get_user_data_dir().path_join("jaw_part.sxp")


func _make_jaw_part(main) -> String:
	var view: DocumentView = main.view
	view.new_document()
	# Direct kernel body so the .sxp carries a stable "Jaw" name.
	view.doc.add_box(40, 20, 10, Vector3.ZERO)
	# Rename via graph is awkward; body_name from add_box is typically "Box".
	# Stamp a clearer name if the binding allows.
	var ids: PackedStringArray = view.doc.body_ids()
	check(ids.size() == 1, "jaw part has one body")
	if ids.size() == 1 and view.doc.has_method("rename_body"):
		view.doc.rename_body(ids[0], "Jaw")
	var path := _part_path()
	check(view.save(path), "saved jaw part .sxp")
	return path


func _face_where(doc: SxDocument, body: String, pred: Callable) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if not bb.is_empty() and pred.call(bb):
			return fid
	return ""


func test_insert_menu_components_item(main) -> void:
	print("- Insert menu exposes Components… (Video 5)")
	var insert_btn: MenuButton = main.find_child("InsertMenu", true, false)
	if insert_btn == null:
		for child in main.find_children("*", "MenuButton", true, false):
			if child.text == "Insert":
				insert_btn = child
				break
	check(insert_btn != null, "Insert MenuButton present")
	if insert_btn == null:
		return
	var popup: PopupMenu = insert_btn.get_popup()
	var found := false
	for i in popup.item_count:
		if popup.get_item_id(i) == 10 and str(popup.get_item_text(i)).begins_with("Components"):
			found = true
			break
	check(found, "Components… item id=10 in Insert menu")
	# Click-drive the menu button, then activate the item (user path).
	var ctx := _ctx(main)
	await FilmUI.click_control(ctx, insert_btn, {"keys": "Click", "desc": "Open Insert menu"})
	popup.id_pressed.emit(10)
	await process_frame
	check(main._file_action == main.FileAction.INSERT_SXP,
		"Components… arms INSERT_SXP file dialog")
	main._file_action = main.FileAction.NONE
	if main.file_dialog and main.file_dialog.visible:
		main.file_dialog.hide()


func test_insert_sxp_workflow(main) -> void:
	print("- multi-doc insert places Fixed first component")
	var path := _make_jaw_part(main)
	var view: DocumentView = main.view
	view.new_document()
	view.doc.add_box(100, 100, 5, Vector3.ZERO)  # ground
	check(view.doc.instance_list().is_empty(), "assembly starts with no instances")

	check(main.insert_components_from(path, Vector3(0, 0, 20)), "insert_components_from ok")
	var instances: Array = view.doc.instance_list()
	check(instances.size() == 1, "one component instance inserted")
	if instances.is_empty():
		return
	check(bool(instances[0].get("fixed", false)), "first insert is Fixed")
	check(str(instances[0].get("source_path", "")).ends_with("jaw_part.sxp"),
		"source_path provenance recorded")
	check(not view.hidden_bodies.is_empty(), "inserted source body hidden")

	main.assembly_panel.refresh_lists()
	check(main.assembly_panel.visible, "assembly panel visible after insert")
	var found_fixed_label := false
	for row in main.assembly_panel._instances_list.get_children():
		for c in row.get_children():
			if c is Label and str(c.text).begins_with("(f)"):
				found_fixed_label = true
	check(found_fixed_label, "Fixed instance shows (f) prefix in panel")


func test_fix_float_restraint(main) -> void:
	print("- Fix/Float restraint blocks and restores drag (Video 6)")
	var path := _make_jaw_part(main)
	var view: DocumentView = main.view
	view.new_document()
	check(main.insert_components_from(path), "insert for restraint test")
	var instances: Array = view.doc.instance_list()
	check(instances.size() == 1, "one instance")
	var iid: String = instances[0]["id"]
	check(bool(instances[0]["fixed"]), "starts Fixed")
	check(not view.doc.set_instance_transform(iid, Vector3(50, 0, 0), Vector3(0, 0, 1), 0.0),
		"Fixed refuses set_instance_transform")

	main.assembly_panel.refresh_lists()
	await process_frame  # let queue_free'd rows leave the tree
	var fix_btn: Button = null
	for row in main.assembly_panel._instances_list.get_children():
		if not is_instance_valid(row) or row.is_queued_for_deletion():
			continue
		fix_btn = row.find_child("FixFloat", true, false)
		if fix_btn != null and is_instance_valid(fix_btn):
			break
	check(fix_btn != null, "FixFloat button on instance row")
	if fix_btn != null:
		fix_btn.pressed.emit()
		await process_frame
	var after: Array = view.doc.instance_list()
	check(after.size() == 1 and not bool(after[0]["fixed"]), "click Float clears fixed")
	check(view.doc.set_instance_transform(iid, Vector3(50, 0, 0), Vector3(0, 0, 1), 0.0),
		"Floated instance accepts transform")

	check(view.doc.set_instance_fixed(iid, true), "re-Fix")
	var has_fixed_mate := false
	for m in view.doc.mate_list():
		if m["type"] == "fixed" and m["instance_b"] == iid:
			has_fixed_mate = true
	check(has_fixed_mate, "Fixed mate present after Fix")


func test_plane_parallel_mate_ui(main) -> void:
	print("- plane_parallel available in mate type list (Video 7)")
	var view: DocumentView = main.view
	var doc: SxDocument = view.doc
	view.new_document()
	var base: String = doc.add_box(80, 80, 10, Vector3.ZERO)
	var block: String = doc.add_box(20, 20, 20, Vector3(120, 0, 0))
	var iid: String = doc.add_instance(block, Vector3(0, 0, 40), Vector3(0, 1, 0), 45.0, "Blk")
	check(iid != "", "seeded instance")
	view.refresh()

	main.assembly_panel.refresh_lists()
	var opt: OptionButton = main.assembly_panel._type_option
	check(opt != null, "mate type OptionButton")
	var parallel_idx := -1
	for i in opt.item_count:
		if opt.get_item_text(i) == "plane_parallel":
			parallel_idx = i
	check(parallel_idx >= 0, "plane_parallel in mate type list")
	opt.select(parallel_idx)

	var base_top := _face_where(doc, base, func(bb):
		return absf(bb["min"].z - 10.0) < 1e-4 and absf(bb["max"].z - 10.0) < 1e-4)
	var block_top := _face_where(doc, block, func(bb):
		return absf(bb["min"].z - 20.0) < 1e-4 and absf(bb["max"].z - 20.0) < 1e-4)
	check(base_top != "" and block_top != "", "planar faces for parallel mate")
	var mid: String = doc.add_mate("plane_parallel", "", base_top, iid, block_top,
		0.0, false, "parallel top")
	check(mid != "", "plane_parallel mate added")
	check(doc.solve_mates(), "parallel mate solves")
	check(doc.set_instance_transform(iid, Vector3(0, 0, 70), Vector3(0, 0, 1), 0.0),
		"still movable after parallel")
	check(doc.solve_mates(), "re-solve keeps translation free")
	var placed_tz := 0.0
	for inst in doc.instance_list():
		if inst["id"] == iid:
			placed_tz = inst["translation"].z
	# Parallel must not snap onto the base (coincident would force ~z=10).
	check(placed_tz > 40.0,
		"Z stayed free after parallel solve (tz=%.2f)" % placed_tz)


func test_reference_geometry_after_insert(main) -> void:
	print("- reference geometry insert after components (Video 8)")
	var path := _make_jaw_part(main)
	var view: DocumentView = main.view
	view.new_document()
	check(main.insert_components_from(path), "insert component first")
	var before: int = view.doc.datum_list().size()
	main._on_insert_menu(0)  # XY plane
	main._on_insert_menu(5)  # Z axis
	main._on_insert_menu(6)  # origin point
	var datums: Array = view.doc.datum_list()
	check(datums.size() == before + 3, "three datums added after components")
	var kinds := {}
	for d in datums:
		kinds[d["kind"]] = true
		check(view.datum_node(d["id"]) != null, "datum rendered: " + str(d["kind"]))
	check(kinds.has("plane") and kinds.has("axis") and kinds.has("point"),
		"plane + axis + point reference geometry present")
	check(view.doc.instance_list().size() == 1, "component survived datum inserts")
	check(bool(view.doc.instance_list()[0]["fixed"]), "component still Fixed")
