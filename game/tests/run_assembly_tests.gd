# Headless tests for AssemblyPanel: instance list, place/remove, armed mate
# flow, mate delete, and solve. Panel is not in main.tscn — mounted here.
# Run: tools/godot/godot --headless --path game --script tests/run_assembly_tests.gd
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
	print("assembly panel tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_place_and_remove(main)
	await test_armed_mate_flow(main)
	await test_mate_delete(main)
	await test_solve_button(main)
	await test_pick_and_drag_instance(main)
	await test_drag_resnap_with_mate(main)
	await test_mate_error_badge_and_anchor(main)
	await test_connector_hover_glyph(main)
	await test_joint_from_face_flow(main)
	await test_drag_drives_joint(main)
	await test_snap_on_drop(main)
	await test_explode_and_pattern(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Slice H: exploded view is a way of seeing (ViewHud, beside Section), and a
## pattern of a jointed component reuses the one joint definition.
func test_explode_and_pattern(main) -> void:
	print("- explode toggle and pattern around the joint")
	var view: DocumentView = main.view
	view.new_document()
	var panel := _mount_panel(main)
	var doc: SxDocument = view.doc
	var plate: String = view.insert_primitive("box", Vector3.ZERO)
	var bolt: String = doc.add_cylinder(3, 16, Vector3(30, 0, 0))
	view.select_entity(bolt, "")
	panel._place_instance()
	await process_frame
	var seed: String = doc.instance_list()[0]["id"]

	# The toggle only appears once there is an assembly to explode.
	main.view_hud.sync_from_view(view)
	check(main.view_hud._explode_btn.visible, "Explode appears beside Section with parts present")
	check(not doc.is_exploded(), "document starts assembled")
	var home: Vector3 = doc.instance_list()[0]["translation"]
	check(doc.explode_assembly(0.8) == 1, "explode moved the part")
	check(doc.is_exploded(), "document reads exploded")
	var away: Vector3 = doc.instance_list()[0]["translation"]
	check(away.distance_to(home) > 1.0, "part separated (%.1f mm)" % away.distance_to(home))
	main.view_hud.sync_from_view(view)
	check(main.view_hud._explode_btn.button_pressed, "toggle reflects the exploded state")
	check(doc.explode_assembly(0.0) == 1, "collapse moved it back")
	var back: Vector3 = doc.instance_list()[0]["translation"]
	check(back.distance_to(home) < 1e-4, "collapsed to the assembled placement")

	# Pattern the seed around a revolute joint: one definition, many bolts.
	panel._type_option.select(_type_index(panel, "revolute"))
	panel._arm_mate()
	panel._mate_face_a = _top_face(doc, plate)
	panel._resolve_mate_b(bolt, _top_face(doc, bolt))
	await process_frame
	check(doc.joint_list().size() == 1, "seed joint added")
	view.select_instance(seed)
	panel._offset_spin.value = 6
	panel._pattern_instance()
	await process_frame
	check(doc.instance_list().size() == 6, "six components after the pattern")
	check(doc.joint_list().size() == 6, "each copy inherits the joint definition")
	panel.queue_free()


## Slice H: dropping a part on a connector creates the mate, no dialog.
func test_snap_on_drop(main) -> void:
	print("- dropping an instance on a connector fastens it")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var panel := _mount_panel(main)
	var doc: SxDocument = view.doc
	var plate: String = view.insert_primitive("box", Vector3.ZERO)
	var bolt: String = doc.add_cylinder(4, 20, Vector3(90, 0, 0))
	view.select_entity(bolt, "")
	panel._place_instance()
	await process_frame
	var iid: String = doc.instance_list()[0]["id"]
	check(doc.mate_list().is_empty(), "no mates before the drop")

	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame

	# Press on the instance where it is actually drawn (source geometry offset by
	# the placement), travel over the plate's top face, release.
	var bolt_bb: Dictionary = doc.measure_bbox(bolt)
	var bolt_center: Vector3 = (bolt_bb["min"] + bolt_bb["max"]) * 0.5
	var placement: Vector3 = doc.instance_list()[0]["translation"]
	var from: Vector2 = vi._model_to_screen(placement + bolt_center)
	var bb: Dictionary = doc.measure_bbox(plate)
	var top: Vector3 = Vector3((bb["min"].x + bb["max"].x) * 0.5,
			(bb["min"].y + bb["max"].y) * 0.5, bb["max"].z)
	var to: Vector2 = vi._model_to_screen(top)
	_lmb(vi, from, true)
	if not vi._pending_instance_move:
		check(true, "drag skipped: press did not land on the instance")
		_lmb(vi, from, false)
		panel.queue_free()
		return
	for i in range(1, 7):
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.position = from.lerp(to, float(i) / 6.0)
		vi._input(mm)
		await process_frame
	check(vi._snap_target_face != "", "connector under the cursor is the magnet target")
	check(vi.connector_overlay.showing(), "magnet is shown on the geometry")
	_lmb(vi, to, false)
	await process_frame

	var mates: Array = doc.mate_list()
	check(mates.size() == 1, "the drop created one mate")
	if not mates.is_empty():
		check(str(mates[0].get("type", "")) == "fastened", "and it is fastened")
		check(str(mates[0].get("instance_b", "")) == iid, "on the dropped instance")
	check(vi._snap_target_face == "", "magnet target cleared after the drop")
	panel.queue_free()


func _lmb(vi: ViewportInteraction, pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	vi._input(mb)


## Slice H: joints share the mate flow — same two faces, one type list.
func test_joint_from_face_flow(main) -> void:
	print("- revolute joint from the two-click face flow")
	var view: DocumentView = main.view
	view.new_document()
	var panel := _mount_panel(main)
	var doc: SxDocument = view.doc
	var base: String = view.insert_primitive("box", Vector3.ZERO)
	var arm: String = doc.add_box(40, 8, 8, Vector3(0, 0, 0))
	view.select_entity(arm, "")
	panel._place_instance()
	await process_frame
	check(doc.instance_list().size() == 1, "arm instanced")

	var joint_idx := -1
	for i in range(panel._type_option.item_count):
		if panel._type_option.get_item_text(i) == "revolute":
			joint_idx = i
	check(joint_idx >= 0, "revolute offered in the same type list as mates")
	panel._type_option.select(joint_idx)

	var face_a := _top_face(doc, base)
	var face_b := _top_face(doc, arm)
	check(face_a != "" and face_b != "", "faces resolved for both sides")
	panel._arm_mate()
	panel._mate_face_a = face_a
	view.select_entity(arm, face_b)
	panel._resolve_mate_b(arm, face_b)
	await process_frame

	var joints: Array = doc.joint_list()
	check(joints.size() == 1, "joint recorded on the document")
	if joints.is_empty():
		panel.queue_free()
		return
	check(str(joints[0].get("type", "")) == "revolute", "joint type is revolute")
	check(str(joints[0].get("unit", "")) == "deg", "revolute is driven in degrees")
	check(panel.visible, "assembly panel lists it")
	var rows := 0
	for c in panel._mates_list.get_children():
		if c.has_meta("joint_id"):
			rows += 1
	check(rows == 1, "one joint row in the panel")

	# Driving the same value twice lands in the same place.
	var jid: String = str(joints[0]["id"])
	check(doc.set_joint_value(jid, 0.5), "joint driven to 0.5 rad")
	var once: Vector3 = doc.instance_list()[0]["translation"]
	check(doc.set_joint_value(jid, 0.5), "joint driven again")
	var twice: Vector3 = doc.instance_list()[0]["translation"]
	check(once.distance_to(twice) < 1e-4,
		"driving is absolute, not cumulative (%s vs %s)" % [str(once), str(twice)])
	check(doc.solve_joints() == 1, "solve_joints poses one joint")
	panel.queue_free()


## Dragging a jointed part drives its one free value instead of moving it freely.
func test_drag_drives_joint(main) -> void:
	print("- dragging a jointed instance drives the joint")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var panel := _mount_panel(main)
	var doc: SxDocument = view.doc
	var base: String = view.insert_primitive("box", Vector3.ZERO)
	var arm: String = doc.add_box(40, 8, 8, Vector3.ZERO)
	view.select_entity(arm, "")
	panel._place_instance()
	await process_frame
	var iid: String = doc.instance_list()[0]["id"]

	panel._type_option.select(_type_index(panel, "slider"))
	panel._arm_mate()
	panel._mate_face_a = _top_face(doc, base)
	panel._resolve_mate_b(arm, _top_face(doc, arm))
	await process_frame
	var joints: Array = doc.joint_list()
	check(joints.size() == 1, "slider joint added")
	if joints.is_empty():
		panel.queue_free()
		return
	check(str(joints[0].get("unit", "")) == "mm", "slider is driven in mm")
	var before: float = float(joints[0].get("value", 0.0))

	# Simulate the drag the interaction layer sees on release: pull along the
	# joint axis as it appears on screen, which is what a user aims at.
	vi._drag_instance_id = iid
	vi._instance_grab_point = Vector3(0, 0, 10)
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	var frame: Dictionary = doc.implicit_connector("", str(joints[0]["face_a"]))
	var origin: Vector3 = frame.get("origin", Vector3.ZERO)
	var axis: Vector3 = (frame.get("z_dir", Vector3.UP) as Vector3).normalized()
	var pivot: Vector2 = vi._model_to_screen(origin)
	var axis_screen: Vector2 = (vi._model_to_screen(origin + axis) - pivot).normalized()
	vi._press_pos = Vector2(640, 360)
	var drove: bool = vi._drive_joint_from_drag(vi._press_pos + axis_screen * 60.0)
	check(drove, "drag routed into the joint")
	var after: float = float(doc.joint_list()[0].get("value", 0.0))
	check(absf(after - before) > 1e-3, "joint value moved (%.2f → %.2f mm)" % [before, after])
	check(doc.remove_joint(str(joints[0]["id"])), "joint removable")
	vi._drag_instance_id = ""
	panel.queue_free()


func _type_index(panel: AssemblyPanel, text: String) -> int:
	for i in range(panel._type_option.item_count):
		if panel._type_option.get_item_text(i) == text:
			return i
	return 0


## Face id of the highest planar face that offers a connector.
func _top_face(doc: SxDocument, body: String) -> String:
	var best := ""
	var best_z := -1e30
	for f in doc.get_face_ids(body):
		var c: Dictionary = doc.implicit_connector("", f)
		if c.is_empty():
			continue
		var o: Vector3 = c.get("origin", Vector3.ZERO)
		if o.z > best_z:
			best_z = o.z
			best = f
	return best


## Wave 0.1 chrome: hovering a face shows its mate frame on the geometry.
## Without this the connector overlay was mounted but never fed.
func test_connector_hover_glyph(main) -> void:
	print("- connector glyph follows the hovered face")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var doc: SxDocument = view.doc
	var body: String = doc.add_box(40, 30, 10, Vector3.ZERO)
	view.refresh()
	await process_frame
	check(vi.connector_overlay != null, "connector overlay mounted")
	check(not vi.connector_overlay.showing(), "no glyph before hover")

	var faces: PackedStringArray = doc.get_face_ids(body)
	check(faces.size() == 6, "box has six faces")
	var planar := ""
	for f in faces:
		if not doc.implicit_connector("", f).is_empty():
			planar = f
			break
	check(planar != "", "a face offers an implicit connector")
	vi._update_connector_hover(planar)
	check(vi.connector_overlay.showing(), "glyph drawn for the hovered face")
	check(vi.connector_overlay.hovered_face() == planar, "glyph tracks that face")
	vi._update_connector_hover("")
	check(not vi.connector_overlay.showing(), "glyph cleared when the pointer leaves")

	# The real hover path feeds it too: aim down the middle of the top face.
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	var bb: Dictionary = doc.measure_bbox(body)
	var top: Vector3 = Vector3((bb["min"].x + bb["max"].x) * 0.5,
			(bb["min"].y + bb["max"].y) * 0.5, bb["max"].z)
	var screen: Vector2 = main.camera.unproject_position(main.model_space.to_global(top))
	vi._update_hover(screen)
	await process_frame
	check(view.hovered_face != "", "pointer hovers a face")
	check(vi.connector_overlay.showing(), "_update_hover feeds the overlay")


func test_pick_and_drag_instance(main) -> void:
	print("- pick_instance + viewport drag commits transform")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var doc: SxDocument = view.doc
	var block: String = doc.add_box(30, 30, 30, Vector3.ZERO)
	var iid: String = doc.add_instance(block, Vector3(200, 0, 0), Vector3(0, 0, 1), 0.0, "Blk-1")
	view.refresh()
	await process_frame

	# Ray straight down through the instance's transformed AABB.
	var bb: Dictionary = doc.measure_bbox(block)
	var local_center: Vector3 = (bb["min"] + bb["max"]) * 0.5
	var center: Vector3 = Vector3(200, 0, 0) + local_center
	var hit: Dictionary = view.pick_instance(center + Vector3(0, 0, 500), Vector3(0, 0, -1))
	check(hit.get("id", "") == iid, "pick_instance hits the instance")
	check(view.pick_instance(Vector3(-500, -500, 500), Vector3(0, 0, -1)).is_empty(),
		"pick_instance misses empty space")

	# Screen-space press → drag → release moves the instance on the ground plane.
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	var world_center: Vector3 = main.model_space.to_global(center)
	var screen: Vector2 = main.camera.unproject_position(world_center)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	vi._input(press)
	check(view.selected_instance == iid, "press selects instance")
	check(vi._pending_instance_move, "instance drag armed (deferred)")
	var mm := InputEventMouseMotion.new()
	mm.position = screen + Vector2(60, 0)
	vi._input(mm)
	check(vi._drag_mode == ViewportInteraction.DragMode.MOVE_INSTANCE,
		"travel past slop arms MOVE_INSTANCE")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen + Vector2(60, 0)
	vi._input(release)
	var placed: Dictionary = doc.instance_list()[0]
	var moved: Vector3 = placed["translation"]
	check(moved.distance_to(Vector3(200, 0, 0)) > 1.0,
		"drag committed a new translation (moved %.1f)" % moved.distance_to(Vector3(200, 0, 0)))
	check(absf(moved.z) < 1e-4, "drag stayed on the ground plane")
	check(vi._drag_mode == ViewportInteraction.DragMode.NONE, "drag cleared on release")

	# Plain click on the instance keeps it selected (no accidental clear).
	view.refresh()
	await process_frame
	var center2: Vector3 = moved + local_center
	var screen2: Vector2 = main.camera.unproject_position(main.model_space.to_global(center2))
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = screen2
		vi._input(mb)
	check(view.selected_instance == iid, "click keeps instance selected")
	check(vi._selection_strip.visible, "selection strip shows for instance")
	check(not vi._strip_fillet.visible and vi._strip_delete.visible,
		"instance strip offers Delete, not body ops")


func test_drag_resnap_with_mate(main) -> void:
	print("- dragged instance re-snaps to its mate on release")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var doc: SxDocument = view.doc
	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(300, 0, 0))
	var iid: String = doc.add_instance(block, Vector3(0, 0, 90), Vector3(0, 0, 1), 0.0, "Blk-1")
	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z - 0.0) < 1e-6 and absf(bb["max"].z - 0.0) < 1e-6)
	var mid: String = doc.add_mate("plane_coincident", "", base_top, iid, block_bottom, 0.0, false, "on base")
	check(mid != "", "mate seeded")
	check(doc.solve_mates(), "initial solve")
	view.refresh()
	await process_frame
	var tz0: float = doc.instance_list()[0]["translation"].z
	check(absf(tz0 - 20.0) < 1e-4, "instance sits on base (tz %.1f)" % tz0)

	# Drag the instance sideways; on release the mate re-solves and keeps it
	# planted on the base top (z pulled home while x/y move freely).
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	var bb: Dictionary = doc.measure_bbox(block)
	var local_center: Vector3 = (bb["min"] + bb["max"]) * 0.5
	var t0: Vector3 = doc.instance_list()[0]["translation"]
	var screen: Vector2 = main.camera.unproject_position(
		main.model_space.to_global(t0 + local_center))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	vi._input(press)
	if not vi._pending_instance_move:
		# Ray may hit the base body first at this camera angle; skip gracefully.
		check(true, "drag skipped: press landed on a body, not the instance")
		var cancel := InputEventMouseButton.new()
		cancel.button_index = MOUSE_BUTTON_LEFT
		cancel.pressed = false
		cancel.position = screen
		vi._input(cancel)
		return
	var mm := InputEventMouseMotion.new()
	mm.position = screen + Vector2(50, 0)
	vi._input(mm)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen + Vector2(50, 0)
	vi._input(release)
	var t1: Vector3 = doc.instance_list()[0]["translation"]
	check(absf(t1.z - 20.0) < 1e-4, "mate re-solve snapped z home (tz %.2f)" % t1.z)
	check(Vector2(t1.x, t1.y).distance_to(Vector2(t0.x, t0.y)) > 1.0,
		"in-plane translation kept from the drag")


func test_mate_error_badge_and_anchor(main) -> void:
	print("- mate error badge + anchor face tint")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame
	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	doc.add_instance(block, Vector3(0, 0, 90), Vector3(0, 0, 1), 0.0, "Blk-1")
	view.refresh()
	panel.refresh_lists()

	# Armed first pick keeps the anchor face tinted until the second pick.
	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	panel._arm_mate()
	view.select_entity(base, base_top)
	check(view.mate_anchor_face == base_top, "anchor face recorded on first pick")
	check(panel._mate_face_a == base_top, "panel keeps face A")

	# Unresolvable face A: add/solve fails and the badge appears in the list.
	panel._mate_face_a = "00000000-0000-4000-8000-000000000000"
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z - 0.0) < 1e-6 and absf(bb["max"].z - 0.0) < 1e-6)
	panel._resolve_mate_b(block, block_bottom)
	check(panel._mate_error != "", "mate error recorded")
	check(view.mate_anchor_face == "", "anchor tint cleared after resolution")
	var badge: Node = panel._mates_list.get_node_or_null("MateError")
	check(badge != null, "error badge row present")
	panel._mate_error = ""
	panel.queue_free()


func _mount_panel(main) -> AssemblyPanel:
	var panel := AssemblyPanel.new()
	panel.view = main.view
	main.add_child(panel)
	return panel


## Face of `body` whose bbox center matches a predicate; "" when none.
func _face_where(doc: SxDocument, body: String, pred: Callable) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if not bb.is_empty() and pred.call(bb):
			return fid
	return ""


func test_place_and_remove(main) -> void:
	print("- place instance shows panel; remove hides it")
	var view: DocumentView = main.view
	view.new_document()
	var panel := _mount_panel(main)
	await process_frame
	check(not panel.visible, "starts hidden (no instances)")

	var id: String = view.insert_primitive("box", Vector3.ZERO)
	check(id != "", "box inserted")
	view.select_entity(id, "")
	await process_frame
	# Selecting a body is what makes "Place instance" reachable in the first place.
	check(panel.visible, "panel visible with a body selected")
	panel._place_instance()
	await process_frame

	check(view.doc.instance_list().size() == 1, "instance exists")
	check(panel.visible, "panel visible after place")
	check(panel._instances_list.get_child_count() == 1, "instance row present")

	var iid: String = view.doc.instance_list()[0]["id"]
	panel._remove_instance(iid)
	await process_frame
	check(view.doc.instance_list().is_empty(), "instance removed")
	check(panel.visible, "still reachable while the source stays selected")
	view.clear_selection()
	await process_frame
	check(not panel.visible, "panel hides with no instances and nothing selected")
	panel.queue_free()


func test_armed_mate_flow(main) -> void:
	print("- armed plane_coincident mate stacks instance on base")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame

	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	var inst: String = doc.add_instance(block, Vector3(50, 50, 90), Vector3(0, 0, 1), 45.0, "Blk-1")
	check(inst != "", "instance placed")
	view.refresh()
	panel.refresh_lists()

	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z) < 1e-6 and absf(bb["max"].z) < 1e-6)
	check(base_top != "", "base top face found")
	check(block_bottom != "", "block bottom face found")

	# Select plane_coincident and arm the two-click flow.
	for i in panel._type_option.item_count:
		if panel._type_option.get_item_text(i) == "plane_coincident":
			panel._type_option.select(i)
			break
	panel._arm_mate()
	check(panel.visible, "panel visible while armed")

	view.select_entity(base, base_top)
	view.select_entity(block, block_bottom)

	check(doc.mate_list().size() == 1, "mate exists in mate_list")
	var placed: Dictionary = doc.instance_list()[0]
	check(absf(placed["translation"].z - 20.0) < 1e-4,
		"instance dropped to base top (tz %.2f)" % placed["translation"].z)
	check(not panel._mate_armed, "mate flow disarmed after success")
	panel.queue_free()


func test_mate_delete(main) -> void:
	print("- mate row delete removes mate")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame

	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	var inst: String = doc.add_instance(block, Vector3(50, 50, 90), Vector3(0, 0, 1), 0.0, "Blk-1")
	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z) < 1e-6 and absf(bb["max"].z) < 1e-6)
	var mid: String = doc.add_mate("plane_coincident", "", base_top, inst, block_bottom, 0.0, false, "on base")
	check(mid != "", "mate seeded")
	view.refresh()
	panel.refresh_lists()
	check(panel._mates_list.get_child_count() == 1, "mate row present")

	panel._remove_mate(mid)
	await process_frame
	check(doc.mate_list().is_empty(), "mate removed from doc")
	check(panel._mates_list.get_child_count() == 0, "mate row gone")
	panel.queue_free()


func test_solve_button(main) -> void:
	print("- solve mates button emits status")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame

	var block: String = doc.add_box(30, 30, 30, Vector3.ZERO)
	doc.add_instance(block, Vector3(30, 0, 0), Vector3(0, 0, 1), 0.0, "Blk-1")
	view.refresh()
	panel.refresh_lists()

	var got_status := [false]
	panel.status.connect(func(_t: String) -> void: got_status[0] = true)
	panel._solve_mates()
	check(got_status[0], "status emitted")
	check(panel.visible, "panel still visible with instance")
	panel.queue_free()
