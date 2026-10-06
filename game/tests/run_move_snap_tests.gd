# Headless tests for body-move snap (grid bar, AABB center/face magnets).
# Run: tools/godot/godot --headless --path game --script tests/run_move_snap_tests.gd
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
	print("body-move snap tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_aabb_anchors(main)
	await test_snap_bar_during_move(main)
	await test_center_snap_near_align(main)
	await test_no_snap_when_far(main)
	await test_grid_snap_during_move(main)
	await test_face_end_snap(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_aabb_anchors(main) -> void:
	print("- AABB snap anchors: center + 6 face mids (+ surface mids with body)")
	var ix: ViewportInteraction = main.interaction
	var bb := {
		"min": Vector3(0, 0, 0),
		"max": Vector3(10, 8, 6),
		"center": Vector3(5, 4, 3),
		"size": Vector3(10, 8, 6),
	}
	var anchors: Array = ix._aabb_snap_anchors(bb)
	check(anchors.size() == 7, "7 anchors (center + 6 faces)")
	check(anchors[0]["kind"] == "center"
			and anchors[0]["point"].is_equal_approx(Vector3(5, 4, 3)),
		"first anchor is center")
	var faces := 0
	for a in anchors:
		if a["kind"] == "face":
			faces += 1
	check(faces == 6, "six face midpoints")
	# With a live body, surface midpoints are appended.
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	var live_bb := view.doc.measure_bbox(id)
	var with_surf: Array = ix._aabb_snap_anchors(live_bb, id)
	var surfaces := 0
	for a in with_surf:
		if a["kind"] == "surface":
			surfaces += 1
	check(surfaces == 6, "box adds 6 surface midpoints (%d)" % surfaces)
	check(with_surf.size() == 13, "7 AABB + 6 surface anchors")


func test_snap_bar_during_move(main) -> void:
	print("- Snap-to-grid dock stays visible (top bar)")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	main.camera.frame_contents()
	await process_frame
	check(ix._place_snap_panel != null and ix._place_snap_panel.visible,
		"snap dock visible when idle")
	check(is_equal_approx(ix._place_snap_panel.anchor_top, 0.0),
		"snap dock anchored at screen top")
	check(ix._place_snap_panel.offset_bottom <= 48.0, "snap dock stays compact")
	var center: Vector3 = view.selection_bbox()["center"]
	var screen: Vector2 = ix._model_to_screen(center)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	ix._handle_model_pointer(press)
	var drag := InputEventMouseMotion.new()
	drag.position = screen + Vector2(40, 0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	ix._handle_model_pointer(drag)
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "move armed")
	check(ix._place_snap_panel.visible, "snap dock still visible during move")
	check(ix._place_snap_check != null and ix._place_snap_check.button_pressed,
		"snap checkbox shown")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen + Vector2(40, 0)
	ix._handle_model_pointer(release)
	check(ix._place_snap_panel.visible, "snap dock still visible after move release")


func test_center_snap_near_align(main) -> void:
	print("- center→center magnet when within hold")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	# Two default 5 mm cubes; A at origin, B shifted +20 on X (centers 20 apart).
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(20, 0, 0))
	view.select_entity(a, "")
	main.camera.frame_contents()
	await process_frame
	ix._begin_move_body(Vector2(100, 100), view.selection_bbox()["center"])
	ix.place_snap_enabled = false
	ix._move_snap_hover_body = ""
	# Raw delta that almost aligns A's center with B's center (need +20 on X).
	var raw := Vector3(20.05, 0.02, 0.0)
	var snap: Dictionary = ix._resolve_move_snap(raw)
	check(not snap.is_empty(), "snap engages near center align")
	check(str(snap.get("kind", "")).begins_with("center"),
		"prefers center→center (got %s)" % snap.get("kind", ""))
	check(snap["delta"].distance_to(Vector3(20, 0, 0)) < 1e-3,
		"snap delta aligns centers (got %s)" % snap["delta"])
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	ix._move_snap_active = {}
	ix._hide_snap_bar_unless_placing()


func test_no_snap_when_far(main) -> void:
	print("- no object snap when far from align")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.insert_primitive("box", Vector3(40, 0, 0))
	view.select_entity(a, "")
	main.camera.frame_contents()
	await process_frame
	ix._begin_move_body(Vector2(100, 100), view.selection_bbox()["center"])
	ix.place_snap_enabled = false
	var snap: Dictionary = ix._resolve_move_snap(Vector3(5, 5, 0))
	check(snap.is_empty(), "no snap far from any alignment")
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	ix._hide_snap_bar_unless_placing()


func test_grid_snap_during_move(main) -> void:
	print("- grid snap holds when object snap absent")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	main.camera.frame_contents()
	await process_frame
	ix._begin_move_body(Vector2(100, 100), view.selection_bbox()["center"])
	ix.place_snap_enabled = true
	ix.place_snap_mm = 1.0
	# Start center is (2.5, 2.5, 2.5); raw nudges toward a nearby grid point.
	var start_c: Vector3 = ix._move_start_center
	var raw := Vector3(0.4, 0.0, 0.0)
	var snap: Dictionary = ix._resolve_move_snap(raw)
	check(not snap.is_empty() and str(snap.get("kind", "")) == "grid",
		"grid snap when near grid (got %s)" % snap.get("kind", "none"))
	if not snap.is_empty():
		var live: Vector3 = start_c + snap["delta"]
		check(is_equal_approx(fmod(absf(live.x), 1.0), 0.0)
				or is_equal_approx(fmod(absf(live.x), 1.0), 1.0),
			"snapped center X on 1 mm grid (x=%s)" % live.x)
	ix.place_snap_enabled = true
	ix.place_snap_mm = 0.1
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	ix._hide_snap_bar_unless_placing()


func test_face_end_snap(main) -> void:
	print("- face mid → face mid snap")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	# Place so +X face of A nearly meets -X face of B (gap ~0.2).
	# Default box: floor at point, size 5 → A max.x=2.5, B at (7.7,0,0) → min.x=5.2
	# Wait: insert point is place point on floor; box sits with floor on plane.
	# measure: center ≈ (point.x, point.y, 2.5) for default 5³ at Vector3.ZERO?
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(5.2, 0, 0))
	view.select_entity(a, "")
	main.camera.frame_contents()
	await process_frame
	var abb: Dictionary = view.doc.measure_bbox(a)
	var bbb: Dictionary = view.doc.measure_bbox(b)
	# Delta that aligns A's +X face with B's -X face.
	var want_dx: float = float(bbb["min"].x) - float(abb["max"].x)
	ix._begin_move_body(Vector2(100, 100), view.selection_bbox()["center"])
	ix.place_snap_enabled = false
	var snap: Dictionary = ix._resolve_move_snap(Vector3(want_dx + 0.03, 0.01, 0.0))
	check(not snap.is_empty(), "face snap engages near face align")
	check(str(snap.get("kind", "")) == "face→face"
			or str(snap.get("kind", "")).contains("face"),
		"snap involves face ends (got %s)" % snap.get("kind", ""))
	if not snap.is_empty():
		check(absf(float(snap["delta"].x) - want_dx) < 0.05,
			"ΔX aligns faces (got %s want ~%s)" % [snap["delta"].x, want_dx])
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	ix._hide_snap_bar_unless_placing()
