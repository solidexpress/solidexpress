# sx-033 A11d: a plain face-select click must not translate the body.
# Synthetic InputEventMouseButton press+release (and press-move-release)
# through ViewportInteraction._handle_model_pointer.
# Run: tools/godot/godot --headless --path game --script tests/run_body_move_click_tests.gd
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
	print("body-move click vs drag tests")
	root.size = Vector2i(1280, 800)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_still_click_selects_face(main)
	await test_sub_dead_zone_wiggle_selects_face(main)
	await test_lost_mouseup_motion_does_not_move(main)
	await test_drag_past_dead_zone_moves(main)
	await test_esc_cancels_in_progress_move(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _center(view: DocumentView, id: String) -> Vector3:
	var bb: Dictionary = view.doc.measure_bbox(id)
	if bb.has("center"):
		return bb["center"]
	return ((bb["min"] as Vector3) + (bb["max"] as Vector3)) * 0.5


func _unmoved(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 1e-3


func _lmb_press(pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = pos
	ev.global_position = pos
	return ev


func _lmb_release(pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	return ev


func _lmb_drag(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	return ev


func _hover_motion(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	return ev


func _setup_bottom_plate(main) -> Dictionary:
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO, Vector3(80, 40, 10))
	view.select_entity(id, "")
	main.camera.apply_standard_view(deg_to_rad(0.0), deg_to_rad(-89.0))
	main.camera.frame_contents()
	await process_frame
	await process_frame
	var bb: Dictionary = view.selection_bbox()
	# Interior of the visible bottom face, off the AABB center (lift grip).
	var pick := Vector3(
			float(bb["center"].x) + float(bb["size"].x) * 0.22,
			float(bb["center"].y),
			float(bb["min"].z))
	var screen: Vector2 = ix._model_to_screen(pick)
	var ray := ix._model_ray(screen)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	return {
		"view": view,
		"ix": ix,
		"id": id,
		"screen": screen,
		"hit": hit,
		"center": _center(view, id),
	}


func test_still_click_selects_face(main) -> void:
	print("- still press+release at one position selects the face, no move")
	var d: Dictionary = await _setup_bottom_plate(main)
	var view: DocumentView = d["view"]
	var ix: ViewportInteraction = d["ix"]
	var id: String = d["id"]
	var screen: Vector2 = d["screen"]
	check(not (d["hit"] as Dictionary).is_empty() and str((d["hit"] as Dictionary).get("body", "")) == id,
			"test point hits the selected body")
	ix._handle_model_pointer(_lmb_press(screen))
	check(ix._pending_body_move, "press on selected body defers MOVE")
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "press does not start MOVE_BODY")
	ix._handle_model_pointer(_lmb_release(screen))
	check(not ix._pending_body_move, "release clears pending move")
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "release is not MOVE_BODY")
	check(_unmoved(d["center"], _center(view, id)), "body transform unchanged after still click")
	check(view.selected_body == id, "body stays selected")
	check(view.selected_face != "", "still click selects a face")
	check(str(main.status_label.text).find("Moved body") < 0,
			"status is not Moved body (got '%s')" % main.status_label.text)


func test_sub_dead_zone_wiggle_selects_face(main) -> void:
	print("- press-move-release under BODY_MOVE_SLOP selects the face, no move")
	var d: Dictionary = await _setup_bottom_plate(main)
	var view: DocumentView = d["view"]
	var ix: ViewportInteraction = d["ix"]
	var screen: Vector2 = d["screen"]
	var slop: float = ViewportInteraction.BODY_MOVE_SLOP
	check(slop >= 5.0 and slop <= 12.0, "dead zone is a clear 5–12 px (got %s)" % slop)
	var dest := screen + Vector2(slop * 0.5, slop * 0.25)
	check(dest.distance_to(screen) < slop, "wiggle stays under the dead zone")
	ix._handle_model_pointer(_lmb_press(screen))
	ix._handle_model_pointer(_lmb_drag(dest))
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE,
			"sub-dead-zone wiggle does not arm MOVE_BODY")
	ix._handle_model_pointer(_lmb_release(dest))
	check(_unmoved(d["center"], _center(view, d["id"])),
			"body transform unchanged under the dead zone")
	check(view.selected_face != "", "sub-dead-zone wiggle still selects a face")
	check(str(main.status_label.text).find("Moved body") < 0,
			"wiggle release is not Moved body")


func test_lost_mouseup_motion_does_not_move(main) -> void:
	print("- press then pointer move without LMB mask does not translate")
	var d: Dictionary = await _setup_bottom_plate(main)
	var view: DocumentView = d["view"]
	var ix: ViewportInteraction = d["ix"]
	var screen: Vector2 = d["screen"]
	ix._handle_model_pointer(_lmb_press(screen))
	check(ix._pressed and ix._pending_body_move, "press left pending body move armed")
	var dest := screen + Vector2(-280, 310)
	ix._handle_model_pointer(_hover_motion(dest))
	check(ix._drag_mode != ViewportInteraction.DragMode.MOVE_BODY,
			"motion without LMB mask must not start MOVE_BODY")
	check(not ix._pressed, "hover motion finishes the press as a click")
	check(_unmoved(d["center"], _center(view, d["id"])),
			"body stays on the sketch plane after hover motion")
	check(view.selected_face != "", "lost-mouseup path still selects a face")
	check(str(main.status_label.text).find("Moved body") < 0,
			"lost mouse-up did not commit Moved body")


func test_drag_past_dead_zone_moves(main) -> void:
	print("- sustained LMB drag past the dead zone does move the body")
	var d: Dictionary = await _setup_bottom_plate(main)
	var view: DocumentView = d["view"]
	var ix: ViewportInteraction = d["ix"]
	var screen: Vector2 = d["screen"]
	var dest := screen + Vector2(ViewportInteraction.BODY_MOVE_SLOP + 16.0, 0)
	ix._handle_model_pointer(_lmb_press(screen))
	ix._handle_model_pointer(_lmb_drag(dest))
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY,
			"held drag past slop arms MOVE_BODY")
	check(ix._drag_accum.length() > 1e-3, "live move accum is non-zero")
	ix._handle_model_pointer(_lmb_release(dest))
	check(not _unmoved(d["center"], _center(view, d["id"])),
			"body center moved after sustained drag")
	check(str(main.status_label.text).find("Moved body") >= 0,
			"status reports Moved body (got '%s')" % main.status_label.text)


func test_esc_cancels_in_progress_move(main) -> void:
	print("- Esc restores the body and does not commit a pending translate")
	var d: Dictionary = await _setup_bottom_plate(main)
	var view: DocumentView = d["view"]
	var ix: ViewportInteraction = d["ix"]
	var screen: Vector2 = d["screen"]
	ix._handle_model_pointer(_lmb_press(screen))
	ix._handle_model_pointer(_lmb_drag(screen + Vector2(48, 12)))
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "drag is live")
	check(ix.cancel_stack(), "Esc cancel_stack acts")
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "Esc ends MOVE_BODY")
	check(not ix._pressed and not ix._pending_body_move, "Esc clears press/pending")
	check(_unmoved(d["center"], _center(view, d["id"])),
			"Esc restores the pre-drag transform")
	check(str(main.status_label.text).find("Moved body") < 0,
			"Esc did not commit Moved body")
