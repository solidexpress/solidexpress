# Hover measure pair + selection bound dimensions.
# Run: tools/godot/godot --headless --path game --script tests/run_measure_overlay_tests.gd
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
	print("measure overlay tests")
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_closest_edge_point(main)
	await test_perp_before_relocate(main)
	await test_selection_bound_labels(main)
	test_hover_pair_pins_on_leave(main)
	test_dual_sticky_marks(main)
	test_esc_clears_pair(main)
	test_screen_font_stable()
	await test_place_ghost_nearest_corner(main)
	await test_move_uses_transport_measure(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_closest_edge_point(main) -> void:
	print("- closest_edge_point / closest_measure_snap")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	var bb: Dictionary = view.doc.measure_bbox(id)
	check(not bb.is_empty(), "box has bbox")
	var center: Vector3 = (bb["min"] + bb["max"]) * 0.5
	var top := Vector3(center.x, center.y, bb["max"].z)
	var snapped := view.closest_edge_point(id, top)
	check(snapped.z == bb["max"].z or is_equal_approx(snapped.z, bb["max"].z),
			"snap stays on top z (%.3f)" % snapped.z)
	var outside: Vector3 = bb["max"] as Vector3 + Vector3(10, 10, 10)
	var edge_pt := view.closest_edge_point(id, outside)
	check(edge_pt.distance_to(outside) < outside.distance_to(center),
			"outside point snaps closer to the solid than the center")
	# Face-center hit plants X on the surface midpoint of that face.
	var face_hit := Vector3(center.x, center.y, bb["max"].z)
	var mid := view.closest_measure_snap(id, face_hit)
	check(mid.distance_to(face_hit) < 1e-3, "closest_measure_snap hits surface midpoint")
	check(mid.distance_to(view.closest_corner_point(id, face_hit)) > 0.5,
			"surface mid ≠ corner")
	# Perpendicular foot from a point above the top face.
	var foot := view.closest_surface_point(id, Vector3(center.x, center.y, 40.0))
	check(foot.distance_to(face_hit) < 1e-3, "closest_surface_point is top-face mid")


func test_perp_before_relocate(main) -> void:
	print("- perpendicular to near body appears before X relocates")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-200, 0, 0), Vector3(80, 80, 80))
	var b: String = view.insert_primitive("box", Vector3(200, 0, 0), Vector3(80, 80, 80))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()
	# Top-down on B so face UV maps cleanly to screen pixels.
	var bb_b: Dictionary = view.doc.measure_bbox(b)
	var mn: Vector3 = bb_b["min"]
	var mx: Vector3 = bb_b["max"]
	var face_mid := Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z)
	main.camera.apply_pose({
		"yaw": 0.0,
		"pitch": deg_to_rad(89.0),
		"distance": 120.0,
		"pivot": face_mid,
		"projection": main.camera.projection,
	})
	await process_frame

	var bb_a: Dictionary = view.doc.measure_bbox(a)
	var aa_max: Vector3 = bb_a["max"]
	mo.update_hover(a, aa_max)
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "X pinned on A")
	var pinned: Vector3 = mo.anchor_point as Vector3

	# Hit B on a face interior away from corners / face mid so relocate stays off.
	var off_mid := Vector3(
			lerpf(mn.x, mx.x, 0.22),
			lerpf(mn.y, mx.y, 0.22),
			mx.z)
	var snap_off := view.closest_measure_snap(b, off_mid)
	var px_off: float = ix._screen_delta_px(off_mid, snap_off)
	check(px_off > ViewportInteraction.MEASURE_RELOCATE_PX,
			"off-mid is outside relocate pixel radius (%.1f px)" % px_off)
	ix._update_measure_hover(b, off_mid)
	check(mo.anchor_body == a, "X stays on A when not near a snap")
	check(mo.anchor_point == pinned, "pinned X unchanged")
	check(mo._last_b != null, "live B shows perpendicular foot")
	var foot: Vector3 = mo._last_b as Vector3
	var expected := view.closest_surface_point(b, pinned)
	check(foot.distance_to(expected) < 1e-3, "B is perpendicular foot from X onto B")

	# Approach the surface midpoint — second X plants on B; prior stays on A.
	ix._update_measure_hover(b, face_mid)
	check(mo.anchor_body == b, "near surface mid plants active X onto B")
	check(mo.following, "following after plant")
	check((mo.anchor_point as Vector3).distance_to(face_mid) < 1e-3,
			"active X lands on surface midpoint")
	check(mo.has_prev(), "prior X retained on A")
	check(mo.prev_body == a, "prev body is A")
	check((mo.prev_point as Vector3).distance_to(pinned) < 1e-3, "prev point unchanged")
	check(mo.sticky_count() == 2, "two sticky marks")
	# Active mark uses the stronger color while following.
	var active_col: Color = Color.WHITE
	for m in mo.marks:
		if (m["p"] as Vector3).distance_to(face_mid) < 1e-3:
			active_col = m["color"]
	check(active_col.is_equal_approx(MeasureOverlay.COLOR_MARK_ACTIVE),
			"active X is orange-red while driving")


func test_selection_bound_labels(main) -> void:
	print("- selection shows bound dimension labels")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	await process_frame
	var mo: MeasureOverlay = ix.measure_overlay
	check(mo != null, "measure overlay mounted")
	if mo != null:
		mo.refresh_bounds()
	var n: int = mo.labels.size() if mo != null else 0
	check(n >= 3, "three bound size labels (%d)" % n)
	check(mo != null and mo.segments.size() >= 3, "bound dimension segments present")


func test_hover_pair_pins_on_leave(main) -> void:
	print("- leave A pins X; B compares; only one pair")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-40, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(40, 0, 0))
	var c: String = view.insert_primitive("box", Vector3(0, 40, 0))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()

	var bb_a: Dictionary = view.doc.measure_bbox(a)
	var pt_a: Vector3 = bb_a["max"]
	mo.update_hover(a, pt_a)
	check(mo.has_anchor(), "touch A sets anchor X")
	check(mo.following, "still following on A")
	var pinned: Vector3 = mo.anchor_point as Vector3

	# Leave A into empty space — X must stick for B to compare against.
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "X pinned after leaving A")
	check(not mo.following, "not following after leave")
	check(mo.anchor_point == pinned, "pinned point unchanged on leave")
	check(mo._last_b == null, "no B dims while in empty space")
	check(mo.marks.size() >= 1, "pinned X still in draw list")

	var bb_b: Dictionary = view.doc.measure_bbox(b)
	mo.update_hover(b, bb_b["min"] as Vector3)
	check(mo.anchor_body == a, "anchor stays on A")
	check(mo._last_b != null, "live B point set")
	var labels_ab: int = mo.labels.size()
	check(labels_ab >= 1, "pair shows measure labels (%d)" % labels_ab)

	var bb_c: Dictionary = view.doc.measure_bbox(c)
	mo.update_hover(c, bb_c["min"] as Vector3)
	check(mo.anchor_body == a, "third body does not grow a second anchor")
	check(mo.labels.size() <= labels_ab + 2, "still a single pair of labels")

	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "pinned X survives miss after B")
	check(mo._last_b == null, "live B dims hidden on miss")
	var has_delta := false
	for lab in mo.labels:
		if str(lab["text"]).begins_with("Δ"):
			has_delta = true
			break
	check(not has_delta, "no Δ cardinal labels after leaving B")

	# Dragging / mod hides measure chrome entirely.
	mo.update_hover(b, bb_b["min"] as Vector3)
	check(mo.is_showing_pair(), "pair armed again on B")
	ix._drag_mode = ViewportInteraction.DragMode.MOVE_BODY
	check(ix._is_modifying(), "move counts as modifying")
	ix._drag_mode = ViewportInteraction.DragMode.NONE


func test_dual_sticky_marks(main) -> void:
	print("- dual sticky X: retain prior, promote, relocate active only")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-200, 0, 0), Vector3(80, 80, 80))
	var b: String = view.insert_primitive("box", Vector3(200, 0, 0), Vector3(80, 80, 80))
	var c: String = view.insert_primitive("box", Vector3(0, 200, 0), Vector3(80, 80, 80))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()

	var bb_a: Dictionary = view.doc.measure_bbox(a)
	var pt_a: Vector3 = bb_a["max"]
	mo.update_hover(a, pt_a)
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor() and not mo.has_prev(), "single pinned X on A")

	var bb_b: Dictionary = view.doc.measure_bbox(b)
	var mid_b := Vector3(
			(bb_b["min"].x + bb_b["max"].x) * 0.5,
			(bb_b["min"].y + bb_b["max"].y) * 0.5,
			bb_b["max"].z)
	mo.relocate_anchor(b, mid_b)
	check(mo.sticky_count() == 2, "relocate plants second X")
	check(mo.anchor_body == b and mo.prev_body == a, "active=B prev=A")
	check((mo.anchor_point as Vector3).distance_to(mid_b) < 1e-3, "active on B mid")
	check((mo.prev_point as Vector3).distance_to(pt_a) < 1e-3, "prev still A corner")

	# Idle with two pins → dims between stickies; active colored.
	mo.update_hover("", Vector3.ZERO)
	check(mo._last_b == null, "no live B while idle")
	check(mo.labels.size() >= 1, "inter-sticky dims while two pins idle")
	var saw_active := false
	var saw_prev := false
	for m in mo.marks:
		var p: Vector3 = m["p"]
		var col: Color = m["color"]
		if p.distance_to(mid_b) < 1e-3:
			saw_active = col.is_equal_approx(MeasureOverlay.COLOR_MARK_ACTIVE)
		if p.distance_to(pt_a) < 1e-3:
			saw_prev = col.is_equal_approx(MeasureOverlay.COLOR_MARK)
	check(saw_active, "active X orange-red during inter-sticky snap")
	check(saw_prev, "prior X stays idle orange")

	# Approach snap on prev body → promote A back to active.
	mo.relocate_anchor(a, pt_a)
	check(mo.anchor_body == a and mo.prev_body == b, "snap on prev promotes it")
	check((mo.anchor_point as Vector3).distance_to(pt_a) < 1e-3, "promoted point on A")

	# Third body with two stickies already → relocate active only; keep prev.
	var bb_c: Dictionary = view.doc.measure_bbox(c)
	var mid_c := Vector3(
			(bb_c["min"].x + bb_c["max"].x) * 0.5,
			(bb_c["min"].y + bb_c["max"].y) * 0.5,
			bb_c["max"].z)
	var kept_prev: Vector3 = mo.prev_point as Vector3
	var kept_prev_body := mo.prev_body
	mo.relocate_anchor(c, mid_c)
	check(mo.sticky_count() == 2, "still two stickies after third snap")
	check(mo.anchor_body == c, "active moved onto C")
	check(mo.prev_body == kept_prev_body, "prev body unchanged")
	check((mo.prev_point as Vector3).distance_to(kept_prev) < 1e-3, "prev point unchanged")
	check((mo.anchor_point as Vector3).distance_to(mid_c) < 1e-3, "active on C mid")

	# Esc clears both.
	mo.clear_pair()
	check(not mo.has_anchor() and not mo.has_prev(), "clear_pair drops both marks")


func test_esc_clears_pair(main) -> void:
	print("- Esc clears measure pair before selection")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-30, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(30, 0, 0))
	view.select_entity(a, "")
	var mo: MeasureOverlay = ix.measure_overlay
	mo.update_hover(a, view.doc.measure_bbox(a)["max"] as Vector3)
	mo.update_hover("", Vector3.ZERO)
	mo.update_hover(b, view.doc.measure_bbox(b)["min"] as Vector3)
	check(mo.has_anchor(), "pair armed")

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	ix._gui_key(esc)
	check(not mo.has_anchor(), "Esc cleared measure pair")
	check(view.selected_body == a, "Esc cleared measure before selection")


func test_screen_font_stable() -> void:
	print("- measure font is DPI-stable (not viewport-tied)")
	check(MeasureOverlay.FONT_PX == 14, "FONT_PX == 14")
	UiScale.refresh()
	var a := UiScale.font(MeasureOverlay.FONT_PX)
	var b := UiScale.font(MeasureOverlay.FONT_PX)
	check(a == b, "font size stable across calls (%d)" % a)
	check(a >= 11 and a <= 36, "font size in readable range (%d)" % a)


func test_place_ghost_nearest_corner(main) -> void:
	print("- place measure uses nearest ghost corner")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-40, 0, 0))
	var side: String = view.insert_primitive("box", Vector3(0, 40, 0))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()
	var bb_a: Dictionary = view.doc.measure_bbox(a)
	mo.update_hover(a, bb_a["max"] as Vector3)
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "anchor pinned before place")

	ix.insert_at_center("box")
	await process_frame
	check(ix.is_placing(), "place armed")
	# Put the ghost well to the +X of the anchor (empty ground).
	ix._update_ghost(ix._model_to_screen(Vector3(40, 0, 0)))
	check(mo.is_showing_pair(), "pair dims while placing with anchor")
	var b: Vector3 = mo._last_b as Vector3
	var corners: Array[Vector3] = ix._ghost_corners()
	check(corners.size() == 8, "ghost has 8 corners")
	var nearest: Vector3 = ix._closest_ghost_corner(mo.anchor_point as Vector3)
	check(b.distance_to(nearest) < 1e-4, "live B is the nearest ghost corner")
	# Not the ghost center (unless degenerate).
	var center: Vector3 = ix._place_ghost.position
	check(b.distance_to(center) > 0.5, "corner ≠ ghost center")
	# Hover another solid while placing — X relocates when near a surface mid.
	var bb_side: Dictionary = view.doc.measure_bbox(side)
	var side_mid: Vector3 = Vector3(
			(bb_side["min"].x + bb_side["max"].x) * 0.5,
			(bb_side["min"].y + bb_side["max"].y) * 0.5,
			bb_side["max"].z)
	var side_screen: Vector2 = ix._model_to_screen(side_mid)
	ix._update_ghost(side_screen)
	check(mo.anchor_body == side, "place hover plants active X onto target body")
	check(mo.following, "following X on target while hovering it")
	check((mo.anchor_point as Vector3).distance_to(side_mid) < 1e-2,
			"X planted on target surface mid")
	check(mo.has_prev() and mo.prev_body == a, "prior X on A retained during place")
	# Move ghost to empty ground — pin X and dim to nearest corner again.
	ix._update_ghost(ix._model_to_screen(Vector3(40, 0, 0)))
	check(mo.anchor_body == side, "X stays on last target after leaving it")
	check(mo.is_showing_pair(), "ghost corner dims resume after leave target")
	ix._disarm_place(false)
	check(mo.has_anchor(), "anchor survives disarm")
	check(mo.has_prev(), "prior X survives disarm")
	check(not mo.is_showing_pair(), "live dims cleared on disarm")


func test_move_uses_transport_measure(main) -> void:
	print("- move uses place-like measure marks")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-40, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(40, 0, 0))
	var side: String = view.insert_primitive("box", Vector3(0, 80, 0))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()
	# Plant X on B, select A (the body we'll move).
	var bb_b: Dictionary = view.doc.measure_bbox(b)
	mo.relocate_anchor(b, (bb_b["min"] as Vector3 + bb_b["max"] as Vector3) * 0.5)
	mo.update_hover("", Vector3.ZERO)
	view.select_entity(a, "")
	await process_frame
	ix._update_transport_measure(ix._model_to_screen(Vector3(0, 0, 0)))
	check(mo.has_anchor(), "anchor kept with selection")
	check(mo.is_showing_pair(), "idle selection dims to perpendicular on subject")
	var idle_b: Vector3 = mo._last_b as Vector3
	var expected_idle := view.closest_surface_point(a, mo.anchor_point as Vector3)
	check(idle_b.distance_to(expected_idle) < 1e-3,
			"idle B is perpendicular foot onto selected body")

	# Begin move and drag — measure stays visible; dims track live corners.
	ix._begin_move_body(ix._model_to_screen(Vector3(-40, 0, 2.5)), Vector3(-40, 0, 2.5))
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "move armed")
	check(not ix._hide_measure_chrome(), "measure chrome visible during move")
	ix._apply_live_move(Vector3(10, 0, 0))
	ix._update_transport_measure(ix._model_to_screen(Vector3(0, 0, 0)))
	check(mo.is_showing_pair(), "pair dims while moving")
	var live_corners: Array[Vector3] = ix._transport_subject_corners()
	var live_b: Vector3 = mo._last_b as Vector3
	check(live_b.distance_to(ix._closest_corner_of(live_corners, mo.anchor_point as Vector3) as Vector3) < 1e-3,
			"live B tracks moved corners")
	check(live_b.x > idle_b.x + 1.0, "moved corner advanced in +X")

	# Plant a second mark on side (keeps B as prev), then touch B to promote.
	var b_mid: Vector3 = Vector3(
			(bb_b["min"].x + bb_b["max"].x) * 0.5,
			(bb_b["min"].y + bb_b["max"].y) * 0.5,
			bb_b["max"].z)
	var bb_side: Dictionary = view.doc.measure_bbox(side)
	mo.relocate_anchor(side, (bb_side["min"] as Vector3 + bb_side["max"] as Vector3) * 0.5)
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_prev() and mo.prev_body == b, "prior X retained before move-touch")
	ix._update_transport_measure(ix._model_to_screen(b_mid))
	check(mo.anchor_body == b, "touch during move promotes/plants active X onto B")
	check(mo.following, "following X on other body during move")
	check((mo.anchor_point as Vector3).distance_to(b_mid) < 1e-2,
			"X replanted on B surface mid")
	check(mo.sticky_count() == 2 and mo.prev_body == side,
			"side mark kept as prev after promoting B")
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	view.refresh()
