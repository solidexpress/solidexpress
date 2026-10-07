# Headless tests for the File/Insert menus (AI context export, datum insertion)
# and camera projection toggle.
# Run: tools/godot/godot --headless --path game --script tests/run_menu_tests.gd
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
	print("menu tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_insert_datums(main)
	test_edit_menu(main)
	test_export_context(main)
	test_projection_toggle(main)
	test_dirty_guard(main)
	test_recent_files(main)
	await test_materials(main)
	await test_configurations(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_insert_datums(main) -> void:
	print("- insert menu datums")
	check(main.view.doc.datum_list().size() == 0, "no datums initially")
	# Datum planes ask for an offset before they exist. Confirming 0 mm
	# (through the origin) is the insert; the menu item itself only opens
	# the dialog.
	main._on_insert_menu(0)  # Datum Plane XY
	check(main._datum_dialog != null and main._datum_dialog.visible,
			"Insert → Datum Plane XY opens the offset dialog")
	check(main.view.doc.datum_list().is_empty(),
			"the plane is not inserted until the offset dialog is confirmed")
	main._datum_dialog.confirmed.emit()
	check(main.view.doc.datum_list().size() == 1, "confirming offset 0 adds the XY plane")
	main._on_insert_menu(3)  # axis X
	main._on_insert_menu(6)  # point at origin
	var datums: Array = main.view.doc.datum_list()
	check(datums.size() == 3, "three datums after inserts")
	var kinds := {}
	for d in datums:
		kinds[d["kind"]] = true
		check(main.view.datum_node(d["id"]) != null, "datum rendered: " + str(d["kind"]))
	check(kinds.has("plane") and kinds.has("axis") and kinds.has("point"),
		"plane, axis, and point kinds present")


func test_edit_menu(main) -> void:
	print("- Edit menu cut/copy/paste")
	check(main._edit_popup != null, "Edit menu exists")
	var view: DocumentView = main.view
	# Don't wipe the document (later tests rely on prior datums); add a disposable body.
	var before: int = view.doc.body_ids().size()
	var a: String = view.insert_primitive("box", Vector3(200, 0, 0), Vector3(20, 20, 20))
	view.select_entity(a, "")
	main._on_edit_menu(3)  # Copy
	check(view.has_clipboard(), "Edit→Copy")
	var n0: int = view.doc.body_ids().size()
	main._on_edit_menu(4)  # Paste
	check(view.doc.body_ids().size() == n0 + 1, "Edit→Paste added body")
	view.select_entity(a, "")
	main._on_edit_menu(2)  # Cut
	check(view.has_clipboard(), "Edit→Cut keeps clipboard")
	check(view.hidden_bodies.size() >= 1 or view.doc.body_ids().size() <= n0,
		"Edit→Cut removed/hid source")
	main._on_edit_menu(4)  # Paste after cut
	check(view.doc.body_ids().size() > before, "Edit→Paste after cut")
	main._refresh_edit_menu()


func test_export_context(main) -> void:
	print("- export AI context via file menu")
	main.view.insert_primitive("box", Vector3.ZERO)
	var path := OS.get_user_data_dir() + "/context_test.md"
	main._file_action = main.FileAction.EXPORT_CONTEXT
	main._on_file_selected(path)
	check(FileAccess.file_exists(path), "context markdown written")
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("# Model context"), "has context header")
	check(text.contains("## Datums"), "includes datums section")
	check(text.contains("## Bodies"), "includes bodies section")
	DirAccess.remove_absolute(path)


func test_projection_toggle(main) -> void:
	print("- camera projection toggle")
	var cam: OrbitCamera = main.camera
	check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "starts perspective")
	cam.toggle_projection()
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "toggles to orthographic")
	var expected := 2.0 * cam.distance * tan(deg_to_rad(cam.fov) / 2.0)
	check(absf(cam.size - expected) < 0.01, "ortho size matches perspective frustum at pivot")
	var size_before: float = cam.size
	cam.distance *= 0.5
	cam._update_transform()
	check(cam.size < size_before, "wheel zoom shrinks ortho frustum")
	cam.toggle_projection()
	check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "toggles back to perspective")


func test_materials(main) -> void:
	print("- body material and mass")
	var body: String = main.view.insert_primitive("box", Vector3.ZERO)
	var mats: Array = main.view.doc.material_list()
	check(mats.size() == 13, "material table exposed (%d entries)" % mats.size())
	check(str(main.view.doc.body_material(body)) == "Unspecified", "default material")

	check(main.view.doc.set_body_material(body, "PLA"), "assign PLA")
	var mp: Dictionary = main.view.doc.measure_mass(body)
	# 20mm default box = 8000 mm^3 = 8 cm^3 -> 9.92 g of PLA.
	var expected: float = mp["volume"] / 1000.0 * 1.24
	check(absf(float(mp["mass_g"]) - expected) < 0.01, "mass uses density (%.1f g)" % mp["mass_g"])
	check(str(mp["material"]) == "PLA", "mass readout names material")
	check(not main.view.doc.set_body_material(body, "Unobtainium"), "unknown material rejected")

	# Ops panel dropdown syncs to the selected body's material.
	main.view.select_entity(body, "")
	await process_frame
	var opt: OptionButton = main.ops_panel._material_option
	check(str(opt.get_item_metadata(opt.selected)) == "PLA", "ops panel dropdown synced")
	main.view.clear_selection()


func test_configurations(main) -> void:
	print("- configurations snapshot variables and regenerate")
	main.view.new_document()
	await process_frame
	var doc = main.view.doc
	check(doc.set_variable("w", "20"), "variable w set")
	var fid: String = doc.graph_add_primitive("box", 20, 20, 10, Vector3.ZERO)
	# Drive the box size by the variable through params JSON.
	doc.graph_set_params(fid, JSON.stringify({"kind": "box", "a": "=w", "b": "=w", "c": 10.0}))
	main.view.graph_changed()
	var body: String = main.view.body_of_feature(fid)
	check(absf(doc.body_volume(body) - 4000.0) < 1.0, "box follows w=20 (vol %.0f)" % doc.body_volume(body))

	check(doc.save_configuration("Small"), "save Small")
	doc.set_variable("w", "40")
	main.view.graph_changed()
	check(doc.save_configuration("Large"), "save Large")
	check(doc.configuration_list().size() == 2, "two configurations")
	check(str(doc.active_configuration()) == "Large", "Large active")

	check(doc.activate_configuration("Small"), "activate Small")
	main.view.refresh()
	check(absf(doc.body_volume(body) - 4000.0) < 1.0, "Small regenerated (vol %.0f)" % doc.body_volume(body))
	check(doc.activate_configuration("Large"), "activate Large")
	check(absf(doc.body_volume(body) - 16000.0) < 1.0, "Large regenerated (vol %.0f)" % doc.body_volume(body))

	# Variables panel exposes the switcher.
	var panel = main.variables_panel
	panel.refresh()
	check(panel._config_option.item_count == 2, "config dropdown populated")
	check(doc.remove_configuration("Small"), "delete Small")
	panel.refresh()
	check(panel._config_option.item_count == 1, "dropdown updates after delete")
	main.view.new_document()
	await process_frame


func test_dirty_guard(main) -> void:
	print("- unsaved changes discard guard")
	# Fresh empty document is not dirty.
	main.view.new_document()
	main.current_path = ""
	main._last_saved_revision = main.view.doc.revision()
	var ran := {"ok": false}
	main._confirm_discard(func() -> void: ran["ok"] = true)
	check(ran["ok"], "confirm_discard runs immediately when clean")
	check(not main.confirm_dialog.visible, "dialog hidden when not dirty")

	main.view.insert_primitive("box", Vector3.ZERO)
	check(main.view.doc.revision() != main._last_saved_revision, "insert marks document dirty")
	check(main.view.doc.body_ids().size() > 0, "document has a body")

	main._on_file_menu(0)  # guarded New
	check(main.confirm_dialog.visible, "dirty New shows confirm dialog")
	check(main.view.doc.body_ids().size() > 0, "document not cleared before confirm")

	main.confirm_dialog.confirmed.emit()
	check(main.view.doc.body_ids().size() == 0, "document cleared after confirm")
	check(main.current_path == "", "New clears path after confirm")


func test_recent_files(main) -> void:
	print("- recent files list")
	main.view.new_document()
	main.current_path = ""
	main._last_saved_revision = main.view.doc.revision()
	main._recent.clear()
	main._save_recent()
	main._rebuild_recent_menu()

	main.view.insert_primitive("box", Vector3.ZERO)
	var path_a := OS.get_user_data_dir() + "/recent_a.sxp"
	var path_b := OS.get_user_data_dir() + "/recent_b.sxp"
	main._file_action = main.FileAction.SAVE_AS
	main._on_file_selected(path_a)
	check(main._recent.has(path_a), "recent list contains first save")
	var item_texts: PackedStringArray = []
	for i in range(main._recent_menu.item_count):
		if not main._recent_menu.is_item_separator(i):
			item_texts.append(main._recent_menu.get_item_text(i))
	check(item_texts.has(path_a), "recent submenu lists first save")

	main._file_action = main.FileAction.SAVE_AS
	main._on_file_selected(path_b)
	check(main._recent.size() >= 2, "recent has two entries")
	check(main._recent[0] == path_b, "most recent save is first")
	check(main._recent[1] == path_a, "older save is second")

	main._on_recent_menu(main._RECENT_CLEAR_ID)
	check(main._recent.is_empty(), "clear recent empties list")
	var only_clear := true
	for i in range(main._recent_menu.item_count):
		if main._recent_menu.is_item_separator(i):
			continue
		if main._recent_menu.get_item_id(i) != main._RECENT_CLEAR_ID:
			only_clear = false
	check(only_clear, "submenu only has Clear Recent after clear")

	DirAccess.remove_absolute(path_a)
	DirAccess.remove_absolute(path_b)
