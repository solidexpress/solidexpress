# Headless tests for the Phase 1 drag-and-drop shell (scene + view-model).
# Run: tools/godot/godot --headless --path game --script tests/run_ui_tests.gd
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
	print("phase 1 shell tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	# Let _ready run.
	await process_frame
	await process_frame

	test_scene_structure(main)
	test_insert_and_render(main)
	test_selection_and_cards(main)
	test_move(main)
	test_push_pull(main)
	test_undo_wiring(main)
	test_sketch_mode(main)
	await test_sketch_toolbar_no_clickthrough(main)
	await test_timeline(main)
	test_ops_panel(main)
	test_sketch_constraints(main)
	await test_done_ends_line_chain(main)
	test_revolve_and_cut(main)
	test_card_editing(main)
	test_edge_selection(main)
	test_file_actions(main)
	test_camera_views(main)
	test_body_props(main)
	test_draft(main)
	test_graph_sweep_loft()
	test_datums(main)
	test_hole(main)
	test_variables(main)
	test_graph_move_rename(main)
	test_graph_import_step(main)
	test_graph_import_stl(main)
	test_instances(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_scene_structure(main) -> void:
	print("- scene structure")
	check(main.camera is Camera3D, "camera exists")
	check(main.view is DocumentView, "document view exists")
	check(main.interaction is Control, "interaction overlay exists")
	var up: Vector3 = main.model_space.basis * Vector3(0, 0, 1)
	check(up.distance_to(Vector3(0, 1, 0)) < 0.01, "model space maps kernel +Z to world +Y")
	check(main.get_node("UI/Palette") != null, "palette panel exists")
	check(main.get_node("UI/CardPanel") != null, "card panel exists")


func test_insert_and_render(main) -> void:
	print("- insert primitives via palette path")
	var view: DocumentView = main.view
	var id: String = view.insert_primitive("box", Vector3(0, 0, 0))
	check(id.length() == 36, "insert box returns uuid")
	var id2: String = view.insert_primitive("cylinder", Vector3(100, 0, 0))
	check(id2.length() == 36, "insert cylinder returns uuid")
	check(view.doc.body_ids().size() == 2, "two bodies in document")
	var node := view.body_node(id)
	check(node != null and node.mesh != null, "box has a mesh node")
	check(node.mesh.get_surface_count() == 6, "box mesh has 6 face surfaces")
	check(view.selected_body == id2, "last inserted body is selected")


func test_selection_and_cards(main) -> void:
	print("- selection and semantic cards")
	var view: DocumentView = main.view
	var box_id: String = view.doc.body_ids()[0]
	# Ray straight down onto the box (model space, kernel Z-up).
	var hit := view.select_ray(Vector3(0, 0, 500), Vector3(0, 0, -1))
	check(hit, "ray selects box body")
	check(view.selected_body == box_id, "correct body selected")
	check(view.selected_face == "", "first click selects body, not face")
	view.select_ray(Vector3(0, 0, 500), Vector3(0, 0, -1))
	check(view.selected_face != "", "second click drills into face")
	var card := view.selection_card()
	check(card.contains("## Digest"), "card panel shows face digest")
	check(card.contains("planar"), "face card describes planar face")
	var n := view.selected_face_normal()
	check(n.distance_to(Vector3(0, 0, 1)) < 0.01, "top face normal is +Z (model space)")
	view.set_selection_alias("the lid face")
	check(view.selection_card().contains("the lid face"), "alias round-trips")


func test_move(main) -> void:
	print("- move body")
	var view: DocumentView = main.view
	var box_id: String = view.doc.body_ids()[0]
	view.select_entity(box_id, "")
	var vol0: float = view.doc.body_volume(box_id)
	check(view.move_selected(Vector3(30, 0, 0)), "move accepted")
	check(absf(view.doc.body_volume(box_id) - vol0) < 1e-6, "volume unchanged by move")
	var hit: Dictionary = view.pick_info(Vector3(30, 0, 500), Vector3(0, 0, -1))
	check(not hit.is_empty() and hit["body"] == box_id, "body pickable at new location")


func test_push_pull(main) -> void:
	print("- push/pull via view-model")
	var view: DocumentView = main.view
	var box_id: String = view.doc.body_ids()[0]
	var vol0: float = view.doc.body_volume(box_id)
	# Select top face (two clicks) then pull 10.
	view.clear_selection()
	view.select_ray(Vector3(30, 0, 500), Vector3(0, 0, -1))
	view.select_ray(Vector3(30, 0, 500), Vector3(0, 0, -1))
	check(view.selected_face != "", "top face selected")
	check(view.push_pull_selected(10.0), "push/pull applies")
	var vol1: float = view.doc.body_volume(box_id)
	check(vol1 > vol0 + 1.0, "volume grew after pull (%.0f -> %.0f)" % [vol0, vol1])
	check(view.selected_body == box_id, "body stays selected after push/pull")


func test_undo_wiring(main) -> void:
	print("- undo/redo wiring")
	var view: DocumentView = main.view
	var count0: int = view.doc.body_ids().size()
	view.insert_primitive("sphere", Vector3(200, 200, 0))
	check(view.doc.body_ids().size() == count0 + 1, "sphere added")
	check(view.undo(), "undo")
	check(view.doc.body_ids().size() == count0, "sphere gone after undo")
	check(view.redo(), "redo")
	check(view.doc.body_ids().size() == count0 + 1, "sphere back after redo")
	# View nodes track the document (refresh is synchronous).
	var live := 0
	for id in view.doc.body_ids():
		if view.body_node(id) != null:
			live += 1
	check(live == view.doc.body_ids().size(), "scene nodes exist for all bodies")


func test_timeline(main) -> void:
	print("- timeline panel")
	var view: DocumentView = main.view
	var tl: TimelinePanel = main.timeline
	check(tl != null, "timeline panel exists")

	tl.refresh()
	await process_frame
	var feats: Array = view.doc.graph_features()
	check(feats.size() > 0, "timeline has features")
	check(tl._rows.size() == feats.size(), "one row per feature")

	# Find a primitive feature and edit its params through the panel.
	var prim: Dictionary = {}
	for f in feats:
		if f["type"] == "primitive" and not f["suppressed"]:
			prim = f
			break
	check(not prim.is_empty(), "found a primitive feature")
	var body: String = prim["output_body"]
	var vol0: float = view.doc.body_volume(body)
	tl._select_feature(prim["id"])
	check(tl._editor_box.visible, "param editor opens on select")
	check(view.selected_body == body, "selecting feature selects its body")
	var params: Dictionary = JSON.parse_string(tl._params_edit.text)
	params["a"] = float(params["a"]) * 2.0
	tl._params_edit.text = JSON.stringify(params)
	tl._apply_params()
	var vol1: float = view.doc.body_volume(body)
	check(vol1 > vol0 * 1.5, "param edit grew the body (%.0f -> %.0f)" % [vol0, vol1])

	# Suppress removes the body from the scene; undo brings the edit back.
	tl._set_suppressed(prim["id"], true)
	check(view.doc.body_volume(body) == 0.0, "suppressed body gone")
	check(view.undo(), "undo suppress")
	check(absf(view.doc.body_volume(body) - vol1) < 1e-6, "body back after undo")
	check(view.undo(), "undo param edit")
	check(absf(view.doc.body_volume(body) - vol0) < 1e-6, "original size after second undo")


func test_sketch_constraints(main) -> void:
	print("- sketch select tool + constraints")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()

	# Rough quadrilateral, roughly axis-aligned.
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0)); sm.click(Vector2(52, 3))
	sm.click(Vector2(51, 32)); sm.click(Vector2(-2, 29))
	sm.click(Vector2(0, 0))
	sm.end_chain()
	check(sm.sketch.entity_ids().size() == 4, "four lines drawn")

	# Select the bottom line, make it horizontal, dimension it to 50.
	sm.set_tool(SketchMode.Tool.SELECT)
	sm.click(Vector2(25, 1))
	check(sm.selected.size() == 1, "bottom line selected")
	check(sm.measured_value() > 40.0, "measured length pre-filled")
	check(sm.constrain("horizontal") == "success", "horizontal solves")
	check(sm.constrain("distance", 50.0) == "success", "length dim solves")
	var info: Dictionary = sm.sketch.entity_info(sm.selected[0])
	check(absf(info["start"].y - info["end"].y) < 1e-6, "line is horizontal")
	check(absf((info["end"] - info["start"]).length() - 50.0) < 1e-6, "line is 50 long")

	# Select two adjacent lines, apply perpendicular.
	sm.click(Vector2(51, 16))
	check(sm.selected.size() == 2, "two lines selected")
	check(sm.constrain("perpendicular") == "success", "perpendicular solves")

	# Empty click clears the selection; constraint without selection is a no-op.
	sm.click(Vector2(500, 500))
	check(sm.selected.is_empty(), "empty click clears selection")
	check(sm.constrain("horizontal") == "", "constrain with no selection is no-op")
	sm.cancel()


## Finish-bar Done ends a multi-line chain (keeps the sketch session).
func test_done_ends_line_chain(main) -> void:
	print("- Done chip ends line chain")
	var sm: SketchMode = main.sketch_mode
	var chrome: SketchContextChrome = main.sketch_chrome
	main.view.clear_selection()
	main._start_sketch()
	await process_frame
	sm.set_snap(false)
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(10, 0))
	sm.click(Vector2(10, 8))
	check(sm.sketch.entity_ids().size() == 2, "two segments before Done")
	var done := chrome.done_button()
	check(done != null and done.is_visible_in_tree(), "Done chip visible")
	done.pressed.emit()
	await process_frame
	check(sm.active, "Done kept sketch session")
	check(sm.sketch.entity_ids().size() >= 2, "Done closed the chain")
	sm.cancel()


func test_camera_views(main) -> void:
	print("- camera standard views + fit")
	var cam: OrbitCamera = main.camera
	var view: DocumentView = main.view
	view.insert_primitive("box", Vector3.ZERO)

	cam.set_view(0.0, deg_to_rad(89.0))  # top
	check(cam.global_position.y > 0.0, "top view is above the scene")
	var to_pivot: Vector3 = (cam.pivot - cam.global_position).normalized()
	check(to_pivot.dot(Vector3(0, -1, 0)) > 0.95, "top view looks down")

	cam.set_view(0.0, 0.0)  # front
	check(absf(cam.global_position.y - cam.pivot.y) < 1.0, "front view is level")

	cam.frame_contents()
	check(cam.distance > OrbitCamera.MIN_DISTANCE, "fit sets a sane distance")
	var world_pivot: Vector3 = cam.pivot
	# All bodies should be inside the view sphere used for framing.
	for id in view.doc.body_ids():
		var node := view.body_node(id)
		var aabb: AABB = node.global_transform * node.get_aabb()
		check(world_pivot.distance_to(aabb.get_center()) < cam.distance,
			"body within framed view")
		break


func test_body_props(main) -> void:
	print("- body rename and display color")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3(-800, -800, 0))
	view.select_entity(id, "")
	check(ops._name_edit.text == view.doc.body_name(id), "name edit prefilled")

	ops._on_name_submitted("Bracket")
	check(view.doc.body_name(id) == "Bracket", "rename updates body_name")

	var tint := Color(0.3, 0.55, 0.2)
	ops._on_color_changed(tint)
	var got: Color = view.doc.get_body_color(id)
	check(absf(got.r - tint.r) < 1e-4 and absf(got.g - tint.g) < 1e-4
			and absf(got.b - tint.b) < 1e-4, "get_body_color round-trips")
	view.clear_selection()
	var node := view.body_node(id)
	var mat := node.get_surface_override_material(0) as ShaderMaterial
	var albedo: Color = mat.get_shader_parameter("albedo_color") if mat != null else Color.BLACK
	check(mat != null and absf(albedo.r - tint.r) < 1e-4
			and absf(albedo.g - tint.g) < 1e-4
			and absf(albedo.b - tint.b) < 1e-4,
			"body mesh albedo matches color")

	var path := "/tmp/sx_ui_bodyprops.sxp"
	check(view.save(path), "save with name+color")
	view.new_document()
	check(view.load_from(path), "reload bodyprops file")
	var ids: PackedStringArray = view.doc.body_ids()
	check(ids.size() == 1, "one body after reload")
	check(view.doc.body_name(ids[0]) == "Bracket", "name survived save/load")
	var loaded: Color = view.doc.get_body_color(ids[0])
	check(absf(loaded.r - tint.r) < 1e-4 and absf(loaded.g - tint.g) < 1e-4
			and absf(loaded.b - tint.b) < 1e-4, "color survived save/load")
	DirAccess.remove_absolute(path)


func test_draft(main) -> void:
	print("- draft face via ops panel")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	view.new_document()
	# Box centered at (-900,-900), spans -925..-875 in x/y, 0..50 in z
	# (explicit 50 mm — the palette default shrank to 10 mm).
	var id: String = view.insert_primitive("box", Vector3(-900, -900, 0), Vector3(50, 50, 50))
	view.select_entity(id, "")
	# Ray from +X onto the side face.
	view.select_ray(Vector3(-870, -900, 25), Vector3(-1, 0, 0))
	check(view.selected_face != "" and ops._face_ops.visible, "side face selected for draft")
	var n := view.selected_face_normal()
	check(n.distance_to(Vector3(1, 0, 0)) < 0.01, "selected +X side face")

	var vol0: float = view.doc.body_volume(id)
	ops._draft_angle_spin.value = 5.0
	check(ops._draft(), "draft apply returned true")
	var vol1: float = view.doc.body_volume(id)
	check(absf(vol1 - vol0) > 1.0, "draft changed volume (%.0f -> %.0f)" % [vol0, vol1])
	check(view.doc.undo(), "undo draft")
	check(absf(view.doc.body_volume(id) - vol0) < 1e-6, "undo restored original volume")


func test_file_actions(main) -> void:
	print("- file menu actions")
	var view: DocumentView = main.view
	check(main.file_dialog is FileDialog, "file dialog exists")
	check(main.get_node("UI/TopChrome/FileMenu") != null, "file menu exists")

	# Save As via the dialog callback, then New, then Open round-trips.
	var count0: int = view.doc.body_ids().size()
	check(count0 > 0, "document has bodies to save")
	main._file_action = main.FileAction.SAVE_AS
	main._on_file_selected("/tmp/sx_ui_file_test")  # extension auto-appended
	check(main.current_path == "/tmp/sx_ui_file_test.sxp", "save-as sets current path")
	check(FileAccess.file_exists("/tmp/sx_ui_file_test.sxp"), "file written")

	main._on_file_menu(0)  # New
	check(view.doc.body_ids().size() == 0, "new document is empty")
	check(main.current_path == "", "new clears path")

	main._file_action = main.FileAction.OPEN
	main._on_file_selected("/tmp/sx_ui_file_test.sxp")
	check(view.doc.body_ids().size() == count0, "open restored all bodies")
	check(main.current_path == "/tmp/sx_ui_file_test.sxp", "open sets current path")

	# STEP export via the menu path.
	main._file_action = main.FileAction.EXPORT_STEP
	main._on_file_selected("/tmp/sx_ui_file_test.step")
	check(FileAccess.file_exists("/tmp/sx_ui_file_test.step"), "step exported")
	DirAccess.remove_absolute("/tmp/sx_ui_file_test.sxp")
	DirAccess.remove_absolute("/tmp/sx_ui_file_test.step")


func test_edge_selection(main) -> void:
	print("- edge selection + targeted fillet")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	var a: String = view.insert_primitive("box", Vector3(-600, -600, 0), Vector3(50, 50, 50))
	# Box spans -625..-575 in x/y, 0..50 in z. Ray down the top-front edge
	# (y = -625): hits the top face within edge tolerance.
	view.select_entity(a, "")
	view.select_ray(Vector3(-600, -624.9, 500), Vector3(0, 0, -1))
	check(view.selected_edge != "", "edge picked near hit point")
	check(view.selection_card().contains("50.0"), "edge card shows length 50")

	# Targeted fillet: only the selected edge is rounded (6 faces becomes 7).
	# The body came from the palette, so the fillet lands on the timeline.
	var feats0: int = view.doc.graph_features().size()
	var vol0: float = view.doc.body_volume(a)
	ops._radius_spin.value = 3.0
	ops._fillet_all()
	check(view.doc.body_volume(a) < vol0, "edge fillet removed material")
	check(view.doc.get_face_ids(a).size() == 7, "only one edge filleted (7 faces)")
	check(view.doc.graph_features().size() == feats0 + 1, "fillet is a timeline feature")

	# The fillet radius is parametric.
	var fillet_fid := ""
	for f in view.doc.graph_features():
		if f["type"] == "fillet":
			fillet_fid = f["id"]
	var fparams: Dictionary = {}
	for f in view.doc.graph_features():
		if f["id"] == fillet_fid:
			fparams = JSON.parse_string(f["params"])
	fparams["radius"] = 8.0
	var vol_r3: float = view.doc.body_volume(a)
	check(view.doc.graph_set_params(fillet_fid, JSON.stringify(fparams)), "fillet radius edited")
	check(view.doc.body_volume(a) < vol_r3, "bigger radius removed more material")

	# Clicking mid-face selects the face, not an edge.
	view.select_entity(a, "")
	view.select_ray(Vector3(-600, -600, 500), Vector3(0, 0, -1))
	check(view.selected_edge == "" and view.selected_face != "", "mid-face click picks face")


func test_card_editing(main) -> void:
	print("- semantic card editing")
	var view: DocumentView = main.view
	var a: String = view.insert_primitive("box", Vector3(-400, -400, 0))
	view.select_entity(a, "")
	main._save_card_text("the base plate", "keep this under 5mm thick")
	check(view.doc.get_card_alias(a) == "the base plate", "alias saved")
	check(view.doc.get_card_notes(a) == "keep this under 5mm thick", "notes saved")
	check(view.selection_card().contains("the base plate"), "alias visible in card markdown")

	# Free text survives a parametric rebuild of the body.
	var fid := view.feature_of_body(a)
	var params: Dictionary = {}
	for f in view.doc.graph_features():
		if f["id"] == fid:
			params = JSON.parse_string(f["params"])
	params["a"] = 80.0
	view.doc.graph_set_params(fid, JSON.stringify(params))
	check(view.doc.get_card_notes(a) == "keep this under 5mm thick", "notes survive rebuild")

	# Selection change repopulates the editors.
	view.clear_selection()
	check(main.alias_edit.text == "", "editors cleared on deselect")
	view.select_entity(a, "")
	check(main.alias_edit.text == "the base plate", "alias editor repopulated")


func test_revolve_and_cut(main) -> void:
	print("- revolve and extrude-cut via sketch finish")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode

	# Revolve: 20x20 rectangle centered at x=40, around the sketch Y axis.
	view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.RECT)
	sm.click(Vector2(30, 0))
	sm.click(Vector2(50, 20))
	var count0: int = view.doc.body_ids().size()
	sm.finish_revolve(TAU, "new")
	check(view.doc.body_ids().size() == count0 + 1, "revolve created a body")
	var ring: String = view.selected_body
	# Pappus: V = 2*pi*R_centroid*A = 2*pi*40*400.
	check(absf(view.doc.body_volume(ring) - TAU * 40.0 * 400.0) < 300.0,
		"revolved volume matches Pappus")
	view.delete_selected()

	# Extrude-cut: sketch a circle on a box top face, cut 20 deep
	# (explicit 50 mm box so the Ø20 circle fits and the cut has depth).
	var box: String = view.insert_primitive("box", Vector3(800, 800, 0), Vector3(50, 50, 50))
	var vol0: float = view.doc.body_volume(box)
	view.select_entity(box, "")
	view.select_ray(Vector3(800, 800, 500), Vector3(0, 0, -1))
	check(view.selected_face != "", "top face selected for sketch")
	main._start_sketch()
	check(sm.target_fid != "", "cut target feature recorded")
	sm.set_tool(SketchMode.Tool.CIRCLE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(10, 0))
	sm.finish_extrude(20.0, "cut")
	var vol1: float = view.doc.body_volume(box)
	check(absf((vol0 - vol1) - PI * 100.0 * 20.0) < 50.0,
		"cut removed a 10x20 cylinder (%.0f removed)" % (vol0 - vol1))
	check(view.doc.body_ids().size() == count0 + 1, "cut did not add a body")

	# The cut is parametric: deepen it via the timeline params.
	var cut_fid := ""
	for f in view.doc.graph_features():
		if f["type"] == "extrude":
			cut_fid = f["id"]
	check(cut_fid != "", "cut feature on timeline")
	var params: Dictionary = {}
	for f in view.doc.graph_features():
		if f["id"] == cut_fid:
			params = JSON.parse_string(f["params"])
	params["distance"] = -40.0
	check(view.doc.graph_set_params(cut_fid, JSON.stringify(params)), "deepen cut")
	var vol2: float = view.doc.body_volume(box)
	check(vol1 - vol2 > PI * 100.0 * 15.0, "cut got deeper")


func test_ops_panel(main) -> void:
	print("- ops panel")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	check(ops != null, "ops panel exists")

	view.clear_selection()
	check(not ops.visible, "hidden with no selection")

	var a: String = view.insert_primitive("box", Vector3(400, 400, 0), Vector3(50, 50, 50))
	check(ops.visible and ops._body_ops.visible, "body ops shown on body selection")

	# Fillet all edges shrinks volume.
	var vol0: float = view.doc.body_volume(a)
	ops._radius_spin.value = 2.0
	ops._fillet_all()
	check(view.doc.body_volume(a) < vol0, "fillet-all removed material")
	view.doc.undo()

	# Linear pattern makes count-1 copies.
	var bodies0: int = view.doc.body_ids().size()
	view.select_entity(a, "")
	ops._pattern_count.value = 3
	ops._pattern_spacing.value = 80.0
	ops._linear_pattern()
	check(view.doc.body_ids().size() == bodies0 + 2, "linear pattern added 2 copies")
	view.doc.undo()
	view.refresh()

	# Shell: select the top face (body already selected, so one click refines
	# to the face), open it, wall 2mm.
	view.select_entity(a, "")
	view.select_ray(Vector3(400, 400, 500), Vector3(0, 0, -1))
	check(view.selected_face != "" and ops._face_ops.visible, "face ops shown on face selection")
	var vol1: float = view.doc.body_volume(a)
	ops._thickness_spin.value = 2.0
	ops._shell()
	check(view.doc.body_volume(a) < vol1 * 0.6, "shell hollowed the body")

	# Measure between two bodies via the armed two-click flow.
	var b: String = view.insert_primitive("box", Vector3(600, 400, 0))
	view.select_entity(a, "")
	ops._arm_measure()
	view.select_entity(b, "")
	check(ops._pending == OpsPanel.Pending.NONE, "measure pending resolved")

	# Boolean fuse via armed flow: select a, arm fuse, click b.
	var bodies1: int = view.doc.body_ids().size()
	view.select_entity(a, "")
	ops._arm_boolean("fuse")
	view.select_entity(b, "")
	check(view.doc.body_ids().size() == bodies1 - 1, "fuse consumed tool body")
	view.doc.undo()
	view.refresh()


func test_sketch_mode(main) -> void:
	print("- sketch mode: rect on ground plane, extrude")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	var count0: int = view.doc.body_ids().size()

	view.clear_selection()
	main._start_sketch()
	check(sm.active, "sketch mode active")
	check(main.sketch_toolbar.visible, "sketch toolbar shown")

	# Draw a 60x40 rectangle with the rect tool via direct 2D clicks.
	sm.set_tool(SketchMode.Tool.RECT)
	sm.click(Vector2(200, 200))
	sm.hover(Vector2(260, 240))
	sm.click(Vector2(260, 240))
	check(sm.sketch.entity_ids().size() == 4, "rect tool created 4 lines")

	sm.finish_extrude(25.0)
	check(not sm.active, "sketch mode exits on finish")
	check(view.doc.body_ids().size() == count0 + 1, "extruded body added")
	var new_body: String = view.selected_body
	check(new_body != "", "new body selected")
	check(absf(view.doc.body_volume(new_body) - 60.0 * 40.0 * 25.0) < 1e-3,
		"extruded volume 60*40*25")

	# Ray through the middle of the new pad must hit it.
	var hit: Dictionary = view.pick_info(Vector3(230, 220, 500), Vector3(0, 0, -1))
	check(not hit.is_empty() and hit["body"] == new_body, "pad pickable from above")

	# Cancel path: start a sketch, draw, cancel; nothing added.
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.CIRCLE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(10, 0))
	check(sm.sketch.entity_ids().size() == 1, "circle drawn")
	sm.cancel()
	check(not sm.active, "cancel exits sketch mode")
	check(view.doc.body_ids().size() == count0 + 1, "cancel adds nothing")


## Toolbar / dock chrome must own the pointer while sketching — clicks on the
## sketch bar must not place geometry on the canvas underneath.
func test_sketch_toolbar_no_clickthrough(main) -> void:
	print("- sketch toolbar: no click-through to canvas")
	var ix: ViewportInteraction = main.interaction
	var sm: SketchMode = main.sketch_mode
	var tb: Control = main.sketch_toolbar
	main.view.clear_selection()
	# Headless viewports need an explicit size for Control hit-testing (see place tests).
	root.size = Vector2i(1280, 720)
	ix.size = Vector2(1280, 720)
	await process_frame
	main._start_sketch()
	await process_frame
	check(tb != null and tb.visible, "sketch toolbar visible")
	sm.set_tool(SketchMode.Tool.LINE)
	var before: int = sm.sketch.entity_ids().size()

	var at := tb.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = at
	ix.get_viewport().push_input(hover)
	await process_frame
	var h: Control = ix.get_viewport().gui_get_hovered_control()
	check(h != null and (h == tb or tb.is_ancestor_of(h)),
		"hover is on sketch toolbar chrome (got %s)" % (h.name if h else "null"))
	check(not ix._viewport_owns_pointer(at),
		"toolbar hover does not own sketch/model pointer")

	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = at
		ix.get_viewport().push_input(mb)
		await process_frame
	check(sm.sketch.entity_ids().size() == before,
		"LMB on toolbar did not create sketch entities")

	# Click a labeled Line tool button — switches tool without a canvas point.
	var line_btn: Button = null
	for child in _all_buttons(tb):
		if child.text == "Line" or str(child.tooltip_text).begins_with("Line"):
			line_btn = child
			break
	check(line_btn != null, "Line toolbar button exists")
	if line_btn != null:
		sm.set_tool(SketchMode.Tool.SELECT)
		var btn_at := line_btn.get_global_rect().get_center()
		var hov2 := InputEventMouseMotion.new()
		hov2.position = btn_at
		ix.get_viewport().push_input(hov2)
		await process_frame
		check(not ix._viewport_owns_pointer(btn_at),
			"Line button hover does not own pointer")
		for pressed2 in [true, false]:
			var mb2 := InputEventMouseButton.new()
			mb2.button_index = MOUSE_BUTTON_LEFT
			mb2.pressed = pressed2
			mb2.position = btn_at
			ix.get_viewport().push_input(mb2)
			await process_frame
		check(sm.tool == SketchMode.Tool.LINE, "Line button selects line tool")
		check(sm.sketch.entity_ids().size() == before,
			"Line button click did not place a canvas point")
	sm.cancel()


func _all_buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in root.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out


func test_graph_sweep_loft() -> void:
	print("- graph sweep and loft")
	var doc := SxDocument.new()

	# Sweep: circle profile along a 2-segment L-path.
	var sk := SxSketch.new()
	sk.add_circle(0, 0, 2.0)
	var sk_fid: String = doc.graph_add_sketch(sk)
	check(sk_fid != "", "sweep sketch feature added")

	var path := PackedVector3Array()
	path.append(Vector3(0, 0, 0))
	path.append(Vector3(0, 0, 20))
	path.append(Vector3(15, 0, 20))
	var bodies0: int = doc.body_ids().size()
	var sw_fid: String = doc.graph_add_sweep(sk_fid, path)
	check(sw_fid != "", "sweep feature added")
	check(doc.body_ids().size() == bodies0 + 1, "sweep created a body")
	var sw_body: String = ""
	for f in doc.graph_features():
		if f["id"] == sw_fid:
			sw_body = f["output_body"]
	check(sw_body != "", "sweep has output_body")
	check(doc.body_volume(sw_body) > 0.0, "swept body volume > 0")

	# Undo removes the swept body (and the sweep feature via graph snapshot).
	check(doc.undo(), "undo sweep")
	check(doc.body_ids().size() == bodies0, "undo dropped swept body")

	# Loft: concentric circles on offset parallel planes via set_plane.
	var bottom := SxSketch.new()
	bottom.add_circle(0, 0, 10.0)
	var bottom_fid: String = doc.graph_add_sketch(bottom)
	check(bottom_fid != "", "loft bottom sketch added")

	var top := SxSketch.new()
	top.set_plane(Vector3(0, 0, 25), Vector3(1, 0, 0), Vector3(0, 1, 0))
	top.add_circle(0, 0, 5.0)
	var top_fid: String = doc.graph_add_sketch(top)
	check(top_fid != "", "loft top sketch added")

	var loft_fids := PackedStringArray()
	loft_fids.append(bottom_fid)
	loft_fids.append(top_fid)
	var loft_bodies0: int = doc.body_ids().size()
	var loft_fid: String = doc.graph_add_loft(loft_fids, true)
	check(loft_fid != "", "loft feature added")
	check(doc.body_ids().size() == loft_bodies0 + 1, "loft created a body")
	var loft_body: String = ""
	for f in doc.graph_features():
		if f["id"] == loft_fid:
			loft_body = f["output_body"]
	check(loft_body != "", "loft has output_body")
	check(doc.body_volume(loft_body) > 0.0, "lofted body volume > 0")


func test_datums(main) -> void:
	print("- datums: add, visuals, remove, save/load")
	var view: DocumentView = main.view
	view.new_document()

	var plane_id: String = view.doc.add_datum_plane(Vector3(0, 0, 0), Vector3(0, 0, 1))
	var axis_id: String = view.doc.add_datum_axis(Vector3(0, 0, 0), Vector3(0, 1, 0))
	var point_id: String = view.doc.add_datum_point(Vector3(10, 20, 30))
	check(plane_id.length() == 36, "add_datum_plane returns uuid")
	check(axis_id.length() == 36, "add_datum_axis returns uuid")
	check(point_id.length() == 36, "add_datum_point returns uuid")

	view.refresh()
	var listed: Array = view.doc.datum_list()
	check(listed.size() == 3, "datum_list has 3 entries")
	var kinds := {}
	for d in listed:
		kinds[d["kind"]] = true
	check(kinds.has("plane") and kinds.has("axis") and kinds.has("point"),
		"datum_list covers all kinds")

	check(view.datum_node(plane_id) != null, "plane visual exists")
	check(view.datum_node(axis_id) != null, "axis visual exists")
	check(view.datum_node(point_id) != null, "point visual exists")
	var plane_mi: MeshInstance3D = view.datum_node(plane_id) as MeshInstance3D
	check(plane_mi != null and plane_mi.mesh != null, "plane has mesh")

	check(view.doc.remove_datum(axis_id), "remove_datum axis")
	view.refresh()
	check(view.doc.datum_list().size() == 2, "datum_list size after remove")
	check(view.datum_node(axis_id) == null, "axis visual cleared")

	var path := "/tmp/sx_ui_datums.sxp"
	check(view.save(path), "save datums document")
	view.new_document()
	check(view.doc.datum_list().size() == 0, "new document has no datums")
	check(view.load_from(path), "reload datums file")
	var reloaded: Array = view.doc.datum_list()
	check(reloaded.size() == 2, "two datums after reload")
	var re_ids := {}
	for d in reloaded:
		re_ids[d["id"]] = d["kind"]
	check(re_ids.has(plane_id) and re_ids[plane_id] == "plane", "plane id survived")
	check(re_ids.has(point_id) and re_ids[point_id] == "point", "point id survived")
	check(view.datum_node(plane_id) != null, "plane visual after reload")
	check(view.datum_node(point_id) != null, "point visual after reload")
	DirAccess.remove_absolute(path)


func test_hole(main) -> void:
	print("- hole via ops panel")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	view.new_document()
	# Graph box: 50^3 with origin at (-25,-25,0) so top face center is (0,0,50).
	var box_fid: String = view.doc.graph_add_primitive("box", 50.0, 50.0, 50.0, Vector3(-25, -25, 0))
	check(box_fid != "", "box feature added")
	var body: String = ""
	for f in view.doc.graph_features():
		if f["id"] == box_fid:
			body = f["output_body"]
	check(body != "", "box has output_body")
	view.refresh()
	view.select_entity(body, "")
	# Top face (+Z).
	view.select_ray(Vector3(0, 0, 500), Vector3(0, 0, -1))
	check(view.selected_face != "" and ops._face_ops.visible, "top face selected for hole")
	var n := view.selected_face_normal()
	check(n.distance_to(Vector3(0, 0, 1)) < 0.01, "selected +Z top face")

	var vol0: float = view.doc.body_volume(body)
	var feats0: int = view.doc.graph_features().size()
	ops._hole_type.select(0)  # Simple
	ops._hole_diameter.value = 6.0
	ops._hole_depth.value = 0.0  # through-all
	check(ops._apply_hole(), "hole apply returned true")
	var vol1: float = view.doc.body_volume(body)
	check(vol1 < vol0, "hole decreased volume (%.0f -> %.0f)" % [vol0, vol1])
	check(view.doc.graph_features().size() == feats0 + 1, "timeline gained a Hole feature")
	var has_hole := false
	for f in view.doc.graph_features():
		if f["type"] == "hole":
			has_hole = true
	check(has_hole, "hole feature on timeline")
	check(view.doc.undo(), "undo hole")
	check(absf(view.doc.body_volume(body) - vol0) < 1e-6, "undo restored original volume")


func test_variables(main) -> void:
	print("- variables panel + expression params")
	var view: DocumentView = main.view
	var vp: VariablesPanel = main.variables_panel
	check(vp != null, "variables panel exists")
	check(main.get_node("UI/Variables") != null, "Variables node in UI dock")
	view.new_document()

	check(view.doc.set_variable("w", "20"), "set_variable w=20")
	view.graph_changed()
	var box_fid: String = view.doc.graph_add_primitive("box", 10.0, 10.0, 10.0, Vector3.ZERO)
	check(box_fid != "", "box feature added for variables test")
	var feats: Array = view.doc.graph_features()
	var params: Dictionary = JSON.parse_string(feats[0]["params"])
	params["a"] = "=w"
	params["b"] = "=w"
	params["c"] = 10.0
	check(view.doc.graph_set_params(box_fid, JSON.stringify(params)), "box a/b = =w")
	view.graph_changed()
	var body: String = ""
	for f in view.doc.graph_features():
		if f["id"] == box_fid:
			body = f["output_body"]
	check(body != "", "box has output_body")
	var vol0: float = view.doc.body_volume(body)
	check(absf(vol0 - 20.0 * 20.0 * 10.0) < 1e-3, "volume tracks w=20 (%.0f)" % vol0)

	check(view.doc.set_variable("w", "30"), "set_variable w=30")
	view.graph_changed()
	var vol1: float = view.doc.body_volume(body)
	check(absf(vol1 - 30.0 * 30.0 * 10.0) < 1e-3, "volume tracks w=30 (%.0f)" % vol1)

	var listed: Array = view.doc.list_variables()
	var w_entry := {}
	for e in listed:
		if e["name"] == "w":
			w_entry = e
	check(not w_entry.is_empty(), "variable w present in list_variables")
	check(w_entry["expr"] == "30", "list entry name/expr")
	check(absf(float(w_entry["value"]) - 30.0) < 1e-9, "list_variables value is 30")
	check(str(w_entry.get("error", "")) == "", "list entry has no error")

	check(view.doc.remove_variable("w"), "remove_variable works")
	view.graph_changed()
	var regen: Dictionary = view.doc.graph_regenerate()
	check(not regen["ok"] and str(regen["error"]).length() > 0,
			"regenerate reports missing reference")
	var after_rm := view.doc.list_variables()
	var found_w := false
	for e in after_rm:
		if e["name"] == "w":
			found_w = true
	check(not found_w, "variable gone after remove")
	check(view.undo(), "undo remove_variable")
	check(absf(view.doc.body_volume(body) - vol1) < 1e-3, "undo restored volume")
	listed = view.doc.list_variables()
	var found_w2 := false
	for e in listed:
		if e["name"] == "w":
			found_w2 = true
	check(found_w2, "undo restored variable")

	# Drive the panel's add/edit methods directly.
	view.new_document()
	vp.refresh()
	check(vp.add_variable("h", "12"), "panel add_variable")
	check(vp._rows.has("h"), "panel row for h after add")
	check(vp.edit_variable("h", "24"), "panel edit_variable")
	var panel_list: Array = view.doc.list_variables()
	var found_h := false
	for e in panel_list:
		if e["name"] == "h":
			found_h = true
			check(e["expr"] == "24", "panel edit updated expr")
			check(absf(float(e["value"]) - 24.0) < 1e-9, "panel edit value is 24")
	check(found_h, "h present after panel edit")
	check(vp.delete_variable("h"), "panel delete_variable")
	check(not vp._rows.has("h"), "panel row cleared after delete")


func test_graph_move_rename(main) -> void:
	print("- graph move / rename + undo")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.doc.graph_add_primitive("box", 10.0, 10.0, 10.0, Vector3.ZERO)
	var b: String = view.doc.graph_add_primitive("cylinder", 5.0, 20.0, 0.0, Vector3(50, 0, 0))
	check(a != "" and b != "", "two primitives added")
	var feats: Array = view.doc.graph_features()
	check(feats.size() == 2, "two features in timeline")
	check(feats[0]["id"] == a and feats[1]["id"] == b, "initial order a then b")
	var name_a: String = feats[0]["name"]
	var name_b: String = feats[1]["name"]

	check(view.doc.graph_move(b, 0), "graph_move index 1 -> 0")
	view.graph_changed()
	feats = view.doc.graph_features()
	check(feats[0]["id"] == b and feats[1]["id"] == a, "order flipped after move")

	check(view.doc.graph_rename(b, "CylinderA"), "graph_rename")
	view.graph_changed()
	feats = view.doc.graph_features()
	check(feats[0]["name"] == "CylinderA", "rename visible in graph_features")

	check(view.undo(), "undo rename")
	feats = view.doc.graph_features()
	check(feats[0]["id"] == b and feats[0]["name"] == name_b, "undo restored name")
	check(view.undo(), "undo move")
	feats = view.doc.graph_features()
	check(feats[0]["id"] == a and feats[1]["id"] == b, "undo restored order")
	check(feats[0]["name"] == name_a and feats[1]["name"] == name_b, "names intact after undo move")


func test_graph_import_step(main) -> void:
	print("- graph import_step + undo")
	var view: DocumentView = main.view
	view.new_document()
	var box_fid: String = view.doc.graph_add_primitive("box", 10.0, 20.0, 30.0, Vector3.ZERO)
	check(box_fid != "", "source box feature added")
	var step_path := "/tmp/sx_ui_import_step.step"
	check(view.doc.export_step(step_path), "export_step wrote box")
	check(FileAccess.file_exists(step_path), "step file exists")

	view.new_document()
	var bodies0: int = view.doc.body_ids().size()
	var imp_fid: String = view.doc.graph_add_import_step(step_path, 1.0)
	check(imp_fid != "", "graph_add_import_step returned id")
	var feats: Array = view.doc.graph_features()
	check(feats.size() == 1, "timeline has one feature")
	check(feats[0]["type"] == "import_step", "feature type is import_step")
	var body: String = feats[0]["output_body"]
	check(body != "", "import_step has output_body")
	check(view.doc.body_ids().size() == bodies0 + 1, "import created a body")
	check(absf(view.doc.body_volume(body) - 6000.0) < 1.0, "imported box volume ~6000")

	check(view.undo(), "undo import_step")
	check(view.doc.graph_features().is_empty(), "timeline empty after undo")
	check(view.doc.body_ids().size() == bodies0, "body gone after undo")
	DirAccess.remove_absolute(step_path)


func test_graph_import_stl(main) -> void:
	print("- graph import_stl + scale + select-all")
	var view: DocumentView = main.view
	view.new_document()
	var box_fid: String = view.doc.graph_add_primitive("box", 10.0, 20.0, 30.0, Vector3.ZERO)
	check(box_fid != "", "source box feature added")
	var stl_path := "/tmp/sx_ui_import_mesh.stl"
	check(view.doc.export_stl(stl_path, true), "export_stl wrote box")
	check(FileAccess.file_exists(stl_path), "stl file exists")

	view.new_document()
	var imp_fid: String = view.doc.graph_add_import_stl(stl_path, 1.0)
	check(imp_fid != "", "graph_add_import_stl returned id")
	var feats: Array = view.doc.graph_features()
	check(feats.size() == 1, "timeline has one feature")
	check(feats[0]["type"] == "import_stl", "feature type is import_stl")
	var body: String = feats[0]["output_body"]
	check(body != "", "import_stl has output_body")
	view.graph_changed()
	check(view.is_import_body(body), "is_import_body true")
	check(view.is_scalable_body(body), "import is scalable")

	# Drop path: select whole body (one selection) then scale via param.
	view.select_entity(body, "")
	check(view.selection_size() == 1, "STL drop default is one body selection")
	check(view.set_import_scale(body, 2.0), "set_import_scale 2x")
	var bb: Dictionary = view.doc.measure_bbox(body)
	check(not bb.is_empty(), "bbox after scale")
	var extent: float = (bb["max"] - bb["min"]).x
	check(extent > 15.0, "scaled mesh larger on X (got %.1f)" % extent)

	var nfaces := view.select_all_faces(body)
	check(nfaces > 0, "select_all_faces on mesh (%d)" % nfaces)

	check(main._import_stl_file(stl_path), "main._import_stl_file path")
	check(view.selected_body != "", "post-drop body selected")

	# SVG underlay onto ground sketch.
	var svg_path := "/tmp/sx_ui_drop.svg"
	var sf := FileAccess.open(svg_path, FileAccess.WRITE)
	check(sf != null, "wrote temp svg")
	sf.store_string("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"20\"><rect width=\"40\" height=\"20\" fill=\"#00f\"/></svg>")
	sf.close()
	check(main._import_svg_to_surface(svg_path), "svg drop to surface")
	check(main.sketch_mode.active, "sketch started for svg")
	check(main.sketch_mode.sketch_picture != null, "svg picture underlay set")
	check(main.sketch_mode.sketch_picture_size.x > 1.0, "picture has size")
	main.sketch_mode.cancel()

	DirAccess.remove_absolute(stl_path)
	DirAccess.remove_absolute(svg_path)


func test_instances(main) -> void:
	print("- instances: place, transform, remove, cascade")
	var view: DocumentView = main.view
	view.new_document()
	var body: String = view.doc.add_box(20, 20, 20, Vector3.ZERO)
	check(body.length() == 36, "box body for instance source")
	view.refresh()

	var iid: String = view.doc.add_instance(
		body, Vector3(30, 0, 0), Vector3(0, 0, 1), 0.0, "Box (inst)")
	check(iid.length() == 36, "add_instance returns uuid")
	view.refresh()

	var listed: Array = view.doc.instance_list()
	check(listed.size() == 1, "instance_list has 1")
	check(listed[0]["id"] == iid, "listed id matches")
	check(listed[0]["source_body"] == body, "listed source_body matches")
	check(listed[0]["translation"].distance_to(Vector3(30, 0, 0)) < 1e-4,
		"listed translation is offset")
	var inode: MeshInstance3D = view.instance_node(iid)
	check(inode != null and inode.mesh != null, "instance visual node exists")
	check(inode.position.distance_to(Vector3(30, 0, 0)) < 1e-4,
		"instance node at translation")

	check(view.doc.set_instance_transform(iid, Vector3(50, 10, 0), Vector3(0, 0, 1), 0.0),
		"set_instance_transform")
	view.refresh()
	inode = view.instance_node(iid)
	check(inode != null and inode.position.distance_to(Vector3(50, 10, 0)) < 1e-4,
		"instance node moved after set_instance_transform")

	check(view.doc.remove_instance(iid), "remove_instance")
	view.refresh()
	check(view.doc.instance_list().is_empty(), "instance_list empty after remove")
	check(view.instance_node(iid) == null, "instance visual cleared")

	# Cascade: deleting the source body removes its instances.
	iid = view.doc.add_instance(body, Vector3(30, 0, 0), Vector3(0, 0, 1), 0.0, "Box (inst)")
	view.refresh()
	check(view.doc.instance_list().size() == 1, "instance re-added for cascade")
	check(view.doc.delete_body(body), "delete source body")
	view.refresh()
	check(view.doc.instance_list().is_empty(), "instance cleared by source cascade")
	check(view.instance_node(iid) == null, "cascade cleared instance visual")
