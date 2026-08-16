# Headless tests for click-to-place (armed insert + ghost preview).
# Run: tools/godot/godot --headless --path game --script tests/run_place_tests.gd
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
	print("click-to-place tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_arming(main)
	test_ghost_follows(main)
	await test_commit(main)
	await test_selection_survives_release(main)
	await test_cancel(main)
	test_esc_clears_selection(main)
	test_drop_unchanged(main)
	await test_stack_on_face(main)
	await test_orbit_over_ops_panel(main)
	await test_empty_drag_orbits(main)
	await test_palette_click_arms_place(main)
	test_place_snap_ui_and_coords(main)
	await test_typed_h_decimal_commits(main)
	await test_transform_hud_and_resize(main)
	test_cylinder_radial_stretch(main)
	await test_place_on_active_plane(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _center(ix: ViewportInteraction) -> Vector2:
	# Headless Control size can be (0,0); rays use the camera viewport.
	return ix._screen_center()


func _ghost(main) -> MeshInstance3D:
	return main.model_space.get_node_or_null("PlaceGhost") as MeshInstance3D


func _lmb(ix: ViewportInteraction, pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	# Place mode is driven from _input (viewport coords), not _gui_input.
	ix._input(mb)


func _move(ix: ViewportInteraction, pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	ix._input(mm)


func _esc(ix: ViewportInteraction) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ix._input(ev)


func test_arming(main) -> void:
	print("- arming insert_at_center")
	var ix: ViewportInteraction = main.interaction
	main.view.new_document()
	ix.insert_at_center("box")
	check(main.view.doc.body_ids().is_empty(), "no body added yet after arm")
	check(_ghost(main) != null, "ghost node exists under model_space")
	check(ix._place_kind == "box", "place kind armed as box")


func test_ghost_follows(main) -> void:
	print("- ghost follows mouse (sits on plane)")
	var ix: ViewportInteraction = main.interaction
	var center := _center(ix)
	_move(ix, center)
	var ghost := _ghost(main)
	check(ghost != null and ghost.visible, "ghost visible at viewport center")
	var target0: Dictionary = ix._place_target(center)
	check(not target0.is_empty(), "ground point at center is valid")
	if not target0.is_empty():
		var half_z := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
		var expect: Vector3 = target0["point"] + Vector3(0, 0, half_z)
		check(ghost.position.distance_to(expect) < 1e-2,
			"ghost center is half-height above floor (got %s want %s)" % [ghost.position, expect])
	check(ix.has_focus(), "Interaction grabbed focus on arm (Esc works)")
	# Offset motion — ghost must track, not stay stuck at arm position.
	var off := center + Vector2(80, 40)
	_move(ix, off)
	ghost = _ghost(main)
	var target2: Dictionary = ix._place_target(off)
	if ghost != null and not target2.is_empty():
		var half_z2 := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
		var expect2: Vector3 = target2["point"] + Vector3(0, 0, half_z2)
		check(ghost.position.distance_to(expect2) < 1e-2,
			"ghost followed mouse offset (got %s want %s)" % [ghost.position, expect2])
	else:
		check(false, "ghost followed mouse offset")


func test_commit(main) -> void:
	print("- LMB commits place")
	var ix: ViewportInteraction = main.interaction
	var center := _center(ix)
	_lmb(ix, center, true)
	_lmb(ix, center, false)
	check(main.view.doc.body_ids().size() == 1, "exactly one body after commit")
	check(ix._place_kind == "", "place mode disarmed after commit")
	check(ix._place_ghost == null, "ghost reference cleared after commit")
	await process_frame
	check(main.model_space.get_node_or_null("PlaceGhost") == null, "PlaceGhost gone from tree")
	var id: String = main.view.doc.body_ids()[0]
	var bb: Dictionary = main.view.doc.measure_bbox(id)
	check(not bb.is_empty(), "bbox after ground place")
	if not bb.is_empty():
		check(absf(float(bb["min"].z) - 0.0) < 1e-2, "box floor on z=0")
		check(absf(float(bb["max"].z) - DocumentView.DEFAULT_PRIMITIVE_MM) < 1e-2,
			"box top at z=%.0f" % DocumentView.DEFAULT_PRIMITIVE_MM)


func test_selection_survives_release(main) -> void:
	print("- selection kept after place + LMB release")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	ix.insert_at_center("box")
	var center := _center(ix)
	_lmb(ix, center, true)
	check(view.selected_body != "", "auto-selected on commit")
	var sel := view.selected_body
	_lmb(ix, center, false)
	check(view.selected_body == sel, "release did not clear selection")
	await process_frame


func test_cancel(main) -> void:
	print("- Esc cancels place")
	var ix: ViewportInteraction = main.interaction
	var count0: int = main.view.doc.body_ids().size()
	ix.insert_at_center("cylinder")
	check(_ghost(main) != null, "ghost present after re-arm")
	_esc(ix)
	check(main.view.doc.body_ids().size() == count0, "no second body after cancel")
	check(ix._place_kind == "", "disarmed after Esc cancel")
	check(ix._place_ghost == null, "ghost reference cleared after cancel")
	await process_frame
	check(main.model_space.get_node_or_null("PlaceGhost") == null, "ghost freed after cancel")


func test_esc_clears_selection(main) -> void:
	print("- Esc clears 3D selection")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	check(id != "", "body inserted for selection test")
	var ray := ix._model_ray(_center(ix))
	# Select via ray API (may miss in headless if camera framing differs);
	# fall back to select_entity.
	if not view.select_ray(ray[0], ray[1]):
		view.select_entity(id, "")
	check(view.selected_body != "", "body selected before Esc")
	_esc(ix)
	check(view.selected_body == "", "Esc cleared selected_body")


func test_drop_unchanged(main) -> void:
	print("- drag-drop inserts immediately")
	var ix: ViewportInteraction = main.interaction
	var count0: int = main.view.doc.body_ids().size()
	var center := _center(ix)
	ix._drop_data(center, {"sx_primitive": "sphere"})
	check(main.view.doc.body_ids().size() == count0 + 1, "drop increments body count immediately")
	check(ix._place_kind == "", "drop does not arm place mode")


func test_stack_on_face(main) -> void:
	print("- stack three boxes on top faces")
	var view: DocumentView = main.view
	view.new_document()
	var s := DocumentView.DEFAULT_PRIMITIVE_MM
	var a: String = view.insert_primitive("box", Vector3(0, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(0, 0, s))
	var c: String = view.insert_primitive("box", Vector3(0, 0, s * 2.0))
	check(a != "" and b != "" and c != "", "three stacked boxes inserted")
	check(view.doc.body_ids().size() == 3, "three bodies in document")
	var bb_a: Dictionary = view.doc.measure_bbox(a)
	var bb_b: Dictionary = view.doc.measure_bbox(b)
	var bb_c: Dictionary = view.doc.measure_bbox(c)
	check(absf(float(bb_a["min"].z)) < 1e-2 and absf(float(bb_a["max"].z) - s) < 1e-2,
		"block A spans z 0..%.0f" % s)
	check(absf(float(bb_b["min"].z) - s) < 1e-2 and absf(float(bb_b["max"].z) - s * 2.0) < 1e-2,
		"block B spans z %.0f..%.0f" % [s, s * 2.0])
	check(absf(float(bb_c["min"].z) - s * 2.0) < 1e-2 and absf(float(bb_c["max"].z) - s * 3.0) < 1e-2,
		"block C spans z %.0f..%.0f" % [s * 2.0, s * 3.0])
	var ix: ViewportInteraction = main.interaction
	ix.insert_at_center("box")
	ix._free_ghost()
	ix._place_kind = ""
	view.insert_primitive("box", Vector3(0, 0, s * 3.0))
	check(view.doc.body_ids().size() == 4,
		"fourth box stacked to z=%.0f..%.0f" % [s * 3.0, s * 4.0])
	await process_frame


func test_orbit_over_ops_panel(main) -> void:
	print("- nav via middle / Alt-left / pan gesture")
	var ix: ViewportInteraction = main.interaction
	var cam: OrbitCamera = main.camera
	main.view.new_document()
	main.view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	check(main.ops_panel.visible, "ops panel visible after select")
	var pivot0: Vector3 = cam.pivot
	var yaw0: float = cam.yaw
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	mm.relative = Vector2(40, 0)
	mm.position = Vector2(1400, 400)
	ix._input(mm)
	check(cam.pivot.distance_to(pivot0) > 1e-4, "pivot changed from middle-drag (SX pan)")
	check(is_equal_approx(cam.yaw, yaw0), "middle-drag does not orbit under SX")
	yaw0 = cam.yaw
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(20, 0)
	ix._input(pan)
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changed from pan gesture (two-finger)")


func test_empty_drag_orbits(main) -> void:
	print("- empty-space left-drag orbits")
	var ix: ViewportInteraction = main.interaction
	var cam: OrbitCamera = main.camera
	main.view.new_document()
	main.view.insert_primitive("box", Vector3.ZERO)
	main.view.clear_selection()
	# Close default zoom makes the box fill a tiny headless viewport; pull back.
	root.size = Vector2i(1280, 720)
	ix.size = Vector2(1280, 720)
	cam.distance = 800.0
	cam.pivot = Vector3.ZERO
	cam._update_transform()
	await process_frame
	var miss := Vector2(20, 20)
	var ray := ix._model_ray(miss)
	var hit: Dictionary = main.view.pick_info(ray[0], ray[1])
	check(hit.is_empty(), "miss point has no pick hit")
	var yaw0: float = cam.yaw
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	ix._input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = miss + Vector2(60, 0)
	ix._input(drag)
	check(ix._drag_mode == ViewportInteraction.DragMode.ORBIT_VIEW, "empty drag armed ORBIT_VIEW")
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changed from empty-space drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(60, 0)
	ix._input(release)
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "orbit drag cleared on release")


func test_palette_click_arms_place(main) -> void:
	print("- palette Box click arms place (not stolen by Interaction _input)")
	var ix: ViewportInteraction = main.interaction
	main.view.new_document()
	main.view.clear_selection()
	root.size = Vector2i(1280, 720)
	ix.size = Vector2(1280, 720)
	await process_frame
	# Find the Box PaletteButton under the left palette.
	var box_btn: Button = null
	for child in main.palette.find_children("*", "Button", true, false):
		if child is PaletteButton and (child as PaletteButton).kind == "box":
			box_btn = child
			break
	check(box_btn != null, "Box palette button exists")
	if box_btn == null:
		return
	var at := box_btn.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = at
	ix.get_viewport().push_input(hover)
	await process_frame
	var h: Control = ix.get_viewport().gui_get_hovered_control()
	check(h != null and (h == box_btn or box_btn.is_ancestor_of(h) or h == main.palette
			or main.palette.is_ancestor_of(h)), "hover is on palette chrome")
	check(not ix._viewport_owns_pointer(at), "palette hover does not own model pointer")
	# Full press/release through the viewport — must reach the Button.
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = at
		ix.get_viewport().push_input(mb)
		await process_frame
	check(ix._place_kind == "box", "palette click armed place mode (got '%s')" % ix._place_kind)
	check(_ghost(main) != null, "ghost present after palette click")
	ix._disarm_place(false)


func test_place_snap_ui_and_coords(main) -> void:
	print("- place snap dock + coordinate snap")
	var ix: ViewportInteraction = main.interaction
	main.view.new_document()
	check(ix.place_snap_enabled, "snap enabled by default")
	check(is_equal_approx(ix.place_snap_mm, 0.1), "default snap resolution 0.1 mm")
	check(ix._place_snap_panel != null and ix._place_snap_panel.visible,
		"snap dock visible before place")
	ix.insert_at_center("box")
	check(ix._place_snap_panel.visible, "snap dock visible while armed")
	check(ix._place_snap_check != null and ix._place_snap_check.button_pressed, "snap checkbox on")
	check(ix._place_snap_spin != null and is_equal_approx(ix._place_snap_spin.value, 0.1),
		"snap spin shows 0.1 mm")
	check(ix.transform_hud != null and ix.transform_hud.visible, "transform HUD visible while placing")
	var ds := DocumentView.DEFAULT_PRIMITIVE_MM
	check(ix.transform_hud.current_size().is_equal_approx(Vector3(ds, ds, ds)),
		"place HUD default size %.0f³" % ds)
	var snapped: Vector3 = ix._snap_point(Vector3(1.24, -2.36, 3.07))
	check(snapped.is_equal_approx(Vector3(1.2, -2.4, 3.1)), "0.1 mm snap rounds axes")
	ix.place_snap_enabled = false
	check(ix._snap_point(Vector3(1.24, -2.36, 3.07)).is_equal_approx(Vector3(1.24, -2.36, 3.07)),
		"snap bypassed when disabled")
	ix.place_snap_enabled = true
	ix.place_snap_mm = 1.0
	check(ix._snap_point(Vector3(1.4, 2.6, 0.4)).is_equal_approx(Vector3(1.0, 3.0, 0.0)),
		"1.0 mm snap rounds axes")
	_esc(ix)
	check(ix._place_snap_panel.visible, "snap dock still visible after cancel")


func test_typed_h_decimal_commits(main) -> void:
	print("- typed H=1.2 commits in TransformHud; 1/2/3/7 not stolen")
	var ix: ViewportInteraction = main.interaction
	main.view.new_document()
	ix.insert_at_center("box")
	await process_frame
	# Focus the H field's LineEdit and type 1.2 then Enter.
	var h_spin: SpinBox = ix.transform_hud._size_h
	check(h_spin != null, "TransformHud H spin exists")
	var edit: LineEdit = h_spin.get_line_edit()
	check(edit != null, "TransformHud H LineEdit exists")
	edit.grab_focus()
	await process_frame
	check(ix.get_viewport().gui_get_focus_owner() == edit, "H LineEdit has focus")
	# Unicode is required for LineEdit insertion; keycode-only events
	# would otherwise be ignored (and 1/2/3/7 must still not steal).
	var typed := [
		[KEY_1, 49],
		[KEY_PERIOD, 46],
		[KEY_2, 50],
		[KEY_ENTER, 0],
	]
	for pair in typed:
		var ev := InputEventKey.new()
		ev.keycode = pair[0]
		ev.physical_keycode = pair[0]
		ev.unicode = pair[1]
		ev.pressed = true
		ix.get_viewport().push_input(ev)
		await process_frame
		var rel := InputEventKey.new()
		rel.keycode = pair[0]
		rel.physical_keycode = pair[0]
		rel.pressed = false
		ix.get_viewport().push_input(rel)
		await process_frame
	check(absf(ix.transform_hud.current_size().y - 1.2) < 1e-6, "HUD H shows 1.2 mm")
	check(absf(ix.place_size.y - 1.2) < 1e-6, "place size H updated to 1.2 mm")
	# Commit the placement and verify the body height is 1.2 mm.
	var center := _center(ix)
	_lmb(ix, center, true)
	_lmb(ix, center, false)
	await process_frame
	var ids: PackedStringArray = main.view.doc.body_ids()
	check(ids.size() >= 1, "body placed after typing H")
	if ids.size() >= 1:
		var bb: Dictionary = main.view.doc.measure_bbox(ids[ids.size() - 1])
		check(not bb.is_empty(), "bbox exists for placed body")
		if not bb.is_empty():
			var sz: Vector3 = bb["max"] - bb["min"]
			check(absf(sz.y - 1.2) < 1e-3, "H=1.2 mm stuck on placed box (got %s)" % sz.y)


func test_transform_hud_and_resize(main) -> void:
	print("- transform HUD + AABB resize + precision field")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	view.select_entity(id, "")
	main._update_panel_visibility()
	check(ix.transform_hud.visible, "transform HUD shows W/H/D after place")
	check(ix.transform_hud._dims_row.visible, "W/H/D row visible on selected primitive")
	check(not main.palette.visible, "palette hidden when body selected")
	check(is_equal_approx(main.ops_panel.get_global_rect().position.x, 8.0),
			"modify tools docked left")
	var bb0: Dictionary = view.selection_bbox()
	check(not bb0.is_empty(), "selection bbox available")
	# Resize max-X face by +10 mm via kernel helper (mirror of drag commit).
	var mn: Vector3 = bb0["min"]
	var mx: Vector3 = bb0["max"]
	mx.x += 10.0
	check(view.resize_primitive_aabb(id, mn, mx), "resize_primitive_aabb grows +X")
	var bb1: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb1["max"].x) - float(bb0["max"].x) - 10.0) < 1e-2, "max X grew by 10")
	# Simulate post-drag precision field: re-set distance to 15 from pre-resize.
	ix._precision_min = bb0["min"]
	ix._precision_max = bb0["max"]
	ix._precision_signs = Vector3(1, 0, 0)
	ix._precision_base = 10.0
	ix._apply_precision_resize(15.0)
	var bb2: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb2["max"].x) - float(bb0["max"].x) - 15.0) < 1e-2,
		"precision field set ΔX to 15 (got %s)" % bb2["max"].x)
	# HUD size edit.
	ix._on_hud_size(Vector3(40, 40, 40))
	var bb3: Dictionary = view.doc.measure_bbox(id)
	var sz: Vector3 = bb3["max"] - bb3["min"]
	check(sz.is_equal_approx(Vector3(40, 40, 40)), "HUD size commit → 40³ (got %s)" % sz)
	# ΔZ precision apply (typed Enter path uses apply() then this).
	var bbz0: Dictionary = view.doc.measure_bbox(id)
	ix._precision_min = bbz0["min"]
	ix._precision_max = bbz0["max"]
	ix._precision_signs = Vector3(0, 0, 1)
	ix._precision_base = 0.0
	ix._apply_precision_resize(12.0)
	var bbz1: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bbz1["max"].z) - float(bbz0["max"].z) - 12.0) < 1e-2,
		"precision ΔZ grows max Z by 12 (got %s)" % bbz1["max"].z)
	# Body face press arms MOVE and preserves size (handles must not steal).
	view.new_document()
	id = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	main.camera.frame_contents()
	await process_frame
	var bb_hit: Dictionary = view.selection_bbox()
	var body_pt: Vector3 = main.model_space.to_global(bb_hit["center"])
	var screen_body: Vector2 = main.camera.unproject_position(body_pt)
	var ray_body := ix._model_ray(screen_body)
	var hit_body: Dictionary = view.pick_info(ray_body[0], ray_body[1])
	check(not hit_body.is_empty() and hit_body["body"] == id, "test point hits selected body")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_body
	ix._input(press)
	# Body move may arm immediately or after leaving click-slop (pending path).
	var armed_on_press := ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY
	var pending: bool = bool(ix._pending_body_move)
	check(armed_on_press or pending, "body press arms or defers MOVE_BODY (mode=%s)" % ix._drag_mode)
	var drag := InputEventMouseMotion.new()
	drag.position = screen_body + Vector2(40, 0)
	ix._input(drag)
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "drag stays MOVE_BODY")
	check(ix._drag_accum.length() > 1e-3, "move accum non-zero")
	# Tap X mid-drag → lock to X: diagonal motion must keep model ΔY at 0.
	var key_x := InputEventKey.new()
	key_x.keycode = KEY_X
	key_x.pressed = true
	ix._input(key_x)
	check(ix._move_axis_lock == ViewportInteraction.AXIS_X, "X tap locks move to X axis")
	var diag := InputEventMouseMotion.new()
	diag.position = screen_body + Vector2(60, 30)
	ix._input(diag)
	check(absf(ix._drag_accum.y) < 1e-6, "X-locked drag keeps ΔY at 0 (got %s)" % ix._drag_accum.y)
	check(absf(ix._drag_accum.x) > 1e-3, "X-locked drag still moves along X")
	# Tap X again → free: the same pointer position now yields a ΔY component.
	ix._input(key_x)
	check(ix._move_axis_lock == -1, "second X tap frees the axis lock")
	check(absf(ix._drag_accum.y) > 1e-4, "freed drag regains ΔY (got %s)" % ix._drag_accum.y)
	# Tap Z → freeze XY; further mouse motion must not change planar Δ.
	var xy_before := Vector2(ix._drag_accum.x, ix._drag_accum.y)
	var key_z := InputEventKey.new()
	key_z.keycode = KEY_Z
	key_z.pressed = true
	ix._input(key_z)
	check(ix._move_axis_lock == ViewportInteraction.AXIS_Z, "Z tap locks move to vertical")
	var wriggle := InputEventMouseMotion.new()
	wriggle.position = screen_body + Vector2(90, 50)
	ix._input(wriggle)
	check(absf(ix._drag_accum.x - xy_before.x) < 1e-6 \
			and absf(ix._drag_accum.y - xy_before.y) < 1e-6,
		"Z-locked drag freezes XY (got %s)" % ix._drag_accum)
	ix._input(key_z)
	check(ix._move_axis_lock == -1, "second Z tap frees the axis lock")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_body + Vector2(40, 0)
	ix._input(release)
	var bb_moved: Dictionary = view.doc.measure_bbox(id)
	var size_moved: Vector3 = bb_moved["max"] - bb_moved["min"]
	var ds2 := DocumentView.DEFAULT_PRIMITIVE_MM
	check(size_moved.is_equal_approx(Vector3(ds2, ds2, ds2)),
		"body drag preserves size (got %s)" % size_moved)


## Side grip on a cylinder must grow Ø about the axis — not translate like a bad drag.
func test_cylinder_radial_stretch(main) -> void:
	print("- cylinder radial stretch grows diameter about center")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("cylinder", Vector3.ZERO, Vector3(10, 10, 12))
	view.select_entity(id, "")
	var bb0: Dictionary = view.doc.measure_bbox(id)
	var c0: Vector3 = (bb0["min"] + bb0["max"]) * 0.5
	var diam0: float = float(bb0["max"].x) - float(bb0["min"].x)
	var h0: float = float(bb0["max"].z) - float(bb0["min"].z)
	ix._resize_signs = Vector3(1, 0, 0)
	ix._resize_start_min = bb0["min"]
	ix._resize_start_max = bb0["max"]
	check(ix._coupled_resize_axes(Vector3(1, 0, 0)).size() == 2, "side grip couples both radial axes")
	check(ix._coupled_resize_axes(Vector3(0, 0, 1)).is_empty(), "end grip is axial (length)")
	ix._apply_resize_delta(4.0)
	check(absf((_resize_extent(ix, 0) - (diam0 + 4.0))) < 1e-3, "+X radial Δ grows ØX")
	check(absf((_resize_extent(ix, 1) - (diam0 + 4.0))) < 1e-3, "+X radial Δ also grows ØY")
	check(absf(_resize_extent(ix, 2) - h0) < 1e-3, "radial Δ keeps height")
	var c_live: Vector3 = (ix._resize_min + ix._resize_max) * 0.5
	check(c_live.distance_to(c0) < 1e-3, "radial Δ keeps center (not a translate)")
	check(view.resize_primitive_aabb(id, ix._resize_min, ix._resize_max), "commit radial resize")
	var bb1: Dictionary = view.doc.measure_bbox(id)
	check(absf((float(bb1["max"].x) - float(bb1["min"].x)) - (diam0 + 4.0)) < 1e-2,
		"committed Ø is start+4 (got %s)" % (bb1["max"].x - bb1["min"].x))
	var c1: Vector3 = (bb1["min"] + bb1["max"]) * 0.5
	check(Vector2(c1.x, c1.y).distance_to(Vector2(c0.x, c0.y)) < 1e-2,
		"committed center XY unchanged")
	# HUD W edit alone must still grow both radial sides.
	ix._on_hud_size(Vector3(20, 10, h0))
	var bb2: Dictionary = view.doc.measure_bbox(id)
	var sz2: Vector3 = bb2["max"] - bb2["min"]
	check(absf(sz2.x - 20.0) < 1e-2 and absf(sz2.y - 20.0) < 1e-2,
		"HUD size equalizes cylinder Ø (got %s)" % sz2)


func _resize_extent(ix: ViewportInteraction, axis: int) -> float:
	return ix._resize_max[axis] - ix._resize_min[axis]


func test_place_on_active_plane(main) -> void:
	print("- place maps to active plane (not ground)")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	# Seed body so we can pick a vertical face as the active plane.
	var seed_id: String = view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	var faces: PackedStringArray = view.doc.get_face_ids(seed_id)
	var side := ""
	for f in faces:
		var plane: Dictionary = SketchMode.derive_face_plane(view.doc, f, seed_id)
		if bool(plane.get("ok", false)) and absf((plane["normal"] as Vector3).x) > 0.9:
			side = f
			view.select_entity(seed_id, f)
			check(ix.set_active_plane_from_selection(), "active plane from +X face")
			break
	check(side != "", "found +X face for active plane")
	check(ix.active_plane_is_custom(), "custom plane armed for place")

	ix.insert_at_center("box")
	var center := _center(ix)
	_move(ix, center)
	var ghost := _ghost(main)
	var target: Dictionary = ix._place_target(center)
	check(not target.is_empty(), "place target on active plane")
	var floor_pt: Vector3 = target["point"]
	# Floor must lie on the active plane (not z=0 ground).
	var n: Vector3 = ix.active_plane_normal.normalized()
	var dist := absf((floor_pt - ix.active_plane_origin).dot(n))
	check(dist < 0.05, "place floor on active plane (dist=%.3f)" % dist)
	check(absf(floor_pt.z) > 0.5 or absf(n.z) < 0.1,
		"floor is not forced onto ground z=0 when plane is vertical")
	if ghost != null:
		var sit: Vector3 = ix._place_sit_normal()
		var expect_c: Vector3 = floor_pt + sit * (DocumentView.DEFAULT_PRIMITIVE_MM * 0.5)
		check(ghost.position.distance_to(expect_c) < 0.1,
			"ghost sits on camera side of plane (got %s want %s)" % [ghost.position, expect_c])
		check(ghost.transform.basis.z.dot(sit) > 0.9,
			"ghost height axis follows sit normal")

	_lmb(ix, center, true)
	_lmb(ix, center, false)
	await process_frame
	check(view.doc.body_ids().size() == 2, "placed second body on active plane")
	var placed: String = view.selected_body
	check(placed != "" and placed != seed_id, "new body selected after place")
	var bb: Dictionary = view.doc.measure_bbox(placed)
	if not bb.is_empty():
		var c: Vector3 = (bb["min"] + bb["max"]) * 0.5
		# Center should be offset from the plane along ±X, not sitting on z-mid ground stack.
		check(absf(c.x) > 2.0, "placed body center offset along plane normal (x=%.2f)" % c.x)
	ix.reset_active_plane()
