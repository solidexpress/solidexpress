# Headless tests for visual UX slice: hover, gizmos, context strip/RMB, view HUD.
# Run: tools/godot/godot --headless --path game --script tests/run_visual_ux_tests.gd
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
	print("visual UX tests")
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_hover_distinct(main)
	await test_rotate_stretch_and_pull_handles(main)
	await test_mod_hides_other_gizmos(main)
	await test_move_delta_hud(main)
	test_selection_strip_and_context(main)
	test_active_plane(main)
	await test_view_hud(main)
	test_push_pull_preview_state(main)
	test_rmb_orbit_and_peer_chrome(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_hover_distinct(main) -> void:
	print("- hover materials distinct from selection")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.clear_selection()
	view.clear_hover()
	check(view.hovered_body == "", "hover cleared")
	view.set_hover(id, "", "")
	check(view.hovered_body == id, "body hover set")
	var node := view.body_node(id)
	var hover_mat := node.get_surface_override_material(0)
	check(hover_mat == view._hover_body_material, "hovered body uses hover material")
	view.select_entity(id, "")
	var sel_mat := node.get_surface_override_material(0)
	check(sel_mat == view._selected_body_material, "selection wins over hover body tint")
	check(sel_mat != view._hover_body_material, "selected material ≠ hover material")
	# Face hover while another body is idle.
	view.clear_selection()
	var faces: PackedStringArray = view.doc.get_face_ids(id)
	check(faces.size() > 0, "box has faces")
	if faces.size() > 0:
		view.set_hover(id, faces[0], "")
		check(view.hovered_face == faces[0], "face hover set")
		check(node.get_surface_override_material(0) == view._hover_face_material \
				or node.get_surface_override_material(0) != view._selected_face_material,
			"face hover uses non-selected material")
	view.clear_hover()
	check(view.hovered_body == "" and view.hovered_face == "", "clear_hover empties")


func test_rotate_stretch_and_pull_handles(main) -> void:
	print("- rotate arcs + stretch grips + pull handle")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	main.camera.frame_contents()
	await process_frame
	var grips: Array = ix._rotate_grips()
	check(grips.size() == 3, "three rotate grips when body selected")
	if grips.size() == 3:
		var bb_r: Dictionary = view.selection_bbox()
		var expect_r: float = (bb_r["size"] as Vector3).length() * 0.5 * 1.08
		check(absf(float(grips[0]["radius"]) - expect_r) < 1e-3,
				"rotate ring hugs AABB (r=%.2f, expect≈%.2f)" % [grips[0]["radius"], expect_r])
		# Prefer a Z-tick that other rings don't share (45° is not a tick; use +Y).
		var g: Dictionary = grips[2]
		var ticks: Array = ix._rotate_tick_points(g)
		check(ticks.size() == 4, "four angle ticks per rotate ring")
		var tip_screen: Vector2 = ix._model_to_screen(ticks[1])
		var picked: Dictionary = ix._pick_rotate_grip(tip_screen)
		check(not picked.is_empty(), "pick_rotate_grip hits angle tick")
	var stretch: Dictionary = ix._pick_resize_handle(
			ix._model_to_screen(ix._selection_center() + Vector3(30, 0, 0)))
	# Stretch pick may be empty if still over body; force an outside pick point.
	var bb: Dictionary = view.selection_bbox()
	var out_pt: Vector3 = Vector3(bb["max"].x + 4.0, (bb["min"].y + bb["max"].y) * 0.5,
			(bb["min"].z + bb["max"].z) * 0.5)
	stretch = ix._pick_resize_handle(ix._model_to_screen(out_pt))
	check(not stretch.is_empty(), "stretch grip pickable outside silhouette")
	var z_grip: Dictionary = ix._z_move_grip_anchor()
	check(not z_grip.is_empty(), "lift grip present")
	if not z_grip.is_empty():
		check(not ix._pick_z_move_grip(ix._model_to_screen(z_grip["point"])).is_empty(),
			"lift grip pickable at tip")
		# Base sits inside the solid (below the top face) so it clears +Z stretch.
		check(float(z_grip["base"].z) < float(bb["max"].z) - 0.01,
			"lift grip base inset below AABB top (base.z=%.2f max.z=%.2f)" \
					% [z_grip["base"].z, bb["max"].z])
		check(not ix._pick_z_move_grip(ix._model_to_screen(z_grip["base"])).is_empty()
				or not ix._pick_z_move_grip(ix._model_to_screen(
					(z_grip["base"] as Vector3).lerp(z_grip["point"], 0.55))).is_empty(),
			"lift grip pickable at inset base or mid plate")
		# Tip must stay within ~10% of viewport height (vertical grip).
		var zb: Vector2 = ix._model_to_screen(z_grip["base"])
		var zt: Vector2 = ix._model_to_screen(z_grip["point"])
		var max_len := ix.get_viewport().get_visible_rect().size.y * ViewportInteraction.GRIP_SCREEN_FRAC
		if max_len < 8.0:
			max_len = ix.size.y * ViewportInteraction.GRIP_SCREEN_FRAC
		check(zb.distance_to(zt) <= max_len + 2.0,
			"lift grip screen length ≤ 10%% height (got %.1f, max %.1f)" % [zb.distance_to(zt), max_len])
	var faces: PackedStringArray = view.doc.get_face_ids(id)
	if faces.size() > 0:
		view.select_entity(id, faces[0])
		await process_frame
		check(ix._rotate_grips().is_empty(), "no rotate arcs with face selected")
		var pull: Dictionary = ix._face_pull_anchor()
		check(not pull.is_empty(), "pull anchor for selected face")
		if not pull.is_empty():
			var ps: Vector2 = ix._model_to_screen(pull["point"])
			check(not ix._pick_push_pull_handle(ps).is_empty(), "pick_push_pull_handle near tip")


func test_mod_hides_other_gizmos(main) -> void:
	print("- active mod hides other mod controls")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	main.camera.frame_contents()
	await process_frame
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "idle before mod")
	check(ix._rotate_grips().size() == 3, "idle has rotate grips available")
	# Stretch mod: only the active face control should be conceptually active.
	ix._drag_mode = ViewportInteraction.DragMode.RESIZE_BODY
	ix._resize_signs = Vector3(1, 0, 0)
	check(ix._is_modifying(), "resize is modifying")
	check(ix._drag_mode == ViewportInteraction.DragMode.RESIZE_BODY, "resize mode set")
	# Rotate mod: axis locked to one ring.
	ix._drag_mode = ViewportInteraction.DragMode.ROTATE_BODY
	ix._rotate_axis = Vector3(0, 0, 1)
	var matching := 0
	for g in ix._rotate_grips():
		if (g["axis"] as Vector3).distance_squared_to(ix._rotate_axis) < 1e-8:
			matching += 1
	check(matching == 1, "only one rotate ring matches active axis")
	ix._drag_mode = ViewportInteraction.DragMode.MOVE_BODY
	check(ix._is_modifying(), "move is modifying")
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	check(not ix._is_modifying(), "idle clears modifying")


func test_move_delta_hud(main) -> void:
	print("- move drag exposes Δ HUD / keeps body size")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	main.camera.frame_contents()
	await process_frame
	# Use interaction projection so screen coords match _model_ray.
	var center: Vector3 = view.selection_bbox()["center"]
	var screen: Vector2 = ix._model_to_screen(center)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	ix._handle_model_pointer(press)
	check(ix._pending_body_move, "body press defers MOVE (pending)")
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "drag mode still NONE on press")
	var drag := InputEventMouseMotion.new()
	drag.position = screen + Vector2(50, 0)
	ix._handle_model_pointer(drag)
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "travel past slop = MOVE_BODY")
	check(ix._drag_accum.length() > 1e-3, "move accum after drag")
	check(ix.transform_hud._move_row.visible, "Δ move row visible while dragging")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen + Vector2(50, 0)
	ix._handle_model_pointer(release)
	var sz: Vector3 = view.doc.measure_bbox(id)["max"] - view.doc.measure_bbox(id)["min"]
	var ds := DocumentView.DEFAULT_PRIMITIVE_MM
	check(sz.is_equal_approx(Vector3(ds, ds, ds)), "move preserves size (got %s)" % sz)
	# Typed ΔZ hops off plane after commit refine.
	ix._on_hud_move_delta(Vector3(ix._move_delta_base.x, ix._move_delta_base.y, 12.0))
	var bb2: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb2["min"].z) - 12.0) < 1e-2 \
			or absf(float(bb2["center"].z) - (ds * 0.5 + 12.0)) < 1e-1,
		"typed ΔZ raised body (min.z=%s)" % bb2["min"].z)


func test_selection_strip_and_context(main) -> void:
	print("- selection strip + RMB menu")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	view.clear_selection()
	ix._refresh_selection_strip()
	check(ix._selection_strip != null, "selection strip exists")
	check(not ix._selection_strip.visible, "strip hidden with no selection")
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	ix._refresh_selection_strip()
	check(ix._selection_strip.visible, "strip visible with body selected")
	check(ix._context_menu != null, "context menu exists")
	ix._open_context_menu(Vector2(40, 40))
	check(ix._context_menu.item_count >= 3, "context has items when selected")
	var faces: PackedStringArray = view.doc.get_face_ids(id)
	if faces.size() > 0:
		view.select_entity(id, faces[0])
		ix._refresh_selection_strip()
		check(ix._strip_look.visible, "Look at visible with face selected")
		check(ix._strip_sketch.visible, "Sketch visible with face selected")
		check(ix._strip_plane.visible, "Active plane visible with face selected")
		ix._open_context_menu(Vector2(40, 40))
		var has_plane_item := false
		for i in range(ix._context_menu.item_count):
			if str(ix._context_menu.get_item_text(i)).contains("active plane"):
				has_plane_item = true
				break
		check(has_plane_item, "RMB includes Set as active plane")
	view.clear_selection()
	ix._open_context_menu(Vector2(40, 40))
	check(ix._context_menu.item_count >= 1, "context has Fit/Unhide when empty")


func test_active_plane(main) -> void:
	print("- active plane set / reset / lift along normal")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	ix.reset_active_plane()
	check(not ix.active_plane_is_custom(), "starts on ground plane")
	var faces: PackedStringArray = view.doc.get_face_ids(id)
	check(faces.size() > 0, "box has faces")
	var side_face := ""
	for f in faces:
		var plane: Dictionary = SketchMode.derive_face_plane(view.doc, f, id)
		if not bool(plane.get("ok", false)):
			continue
		var n: Vector3 = plane["normal"]
		if absf(n.x) > 0.9:
			side_face = f
			view.select_entity(id, f)
			check(ix.set_active_plane_from_selection(), "set active plane from +X face")
			check(ix.active_plane_is_custom(), "custom plane flagged")
			check(absf(ix.active_plane_normal.x) > 0.9, "active normal is ±X")
			break
	check(side_face != "", "found an axis-aligned side face")
	view.select_entity(id, "")
	var grip: Dictionary = ix._z_move_grip_anchor()
	check(not grip.is_empty(), "lift grip with custom ±X plane")
	if not grip.is_empty():
		var gn: Vector3 = grip.get("normal", Vector3.ZERO)
		check(absf(gn.x) > 0.9, "lift grip oriented along active normal")
	ix.arm_pick_active_plane()
	check(ix._picking_active_plane, "pick mode armed")
	ix.cancel_pick_active_plane()
	check(not ix._picking_active_plane, "pick mode cancelled")
	var grid: MeshInstance3D = ix.world_gizmos.get_node_or_null("Grid") as MeshInstance3D
	check(grid != null, "world grid exists")
	if grid != null and side_face != "":
		check(absf(grid.transform.basis.z.x) > 0.9,
			"white grid normal follows active ±X plane")
		check(not grid.position.is_equal_approx(Vector3.ZERO),
			"white grid origin leaves ground when plane is custom")
	ix.reset_active_plane()
	check(not ix.active_plane_is_custom(), "reset restores ground")
	check(ix.active_plane_normal.is_equal_approx(Vector3(0, 0, 1)), "ground normal +Z")
	if grid != null:
		check(grid.transform.is_equal_approx(Transform3D.IDENTITY),
			"white grid returns to ground on reset")


func test_view_hud(main) -> void:
	print("- view HUD: dock, Shade, Section, Frame, View strip")
	var hud: ViewHud = main.view_hud
	var view: DocumentView = main.view
	var cam: OrbitCamera = main.camera
	check(hud != null, "ViewHud mounted")

	# Far bottom-right dock — above the status bar, same chrome pad as File bar.
	await process_frame
	check(is_equal_approx(hud.anchor_left, 1.0) and is_equal_approx(hud.anchor_right, 1.0),
		"HUD anchored to the right edge")
	check(is_equal_approx(hud.anchor_top, 1.0) and is_equal_approx(hud.anchor_bottom, 1.0),
		"HUD anchored to the bottom edge")
	check(is_equal_approx(hud.offset_bottom, -(30.0 + main._CHROME_PAD)),
		"HUD sits above the status bar")
	check(is_equal_approx(hud.offset_right, -main._CHROME_PAD), "HUD right pad matches File bar")
	check(is_equal_approx(hud.offset_left, -main._CHROME_PAD), "HUD grows from right pad")
	check(hud.origin_triad != null, "OriginTriad sits above the view menu")
	check(hud.origin_triad.camera == cam, "OriginTriad linked to OrbitCamera")
	check(not hud.has_signal("nav_preset_changed"), "nav menu signal removed")
	check(cam.nav_preset == OrbitCamera.NavPreset.FUSION, "Fusion is the only mouse preset")

	check(hud._display_btn != null and hud._section_btn != null and hud._fit_btn != null,
		"HUD has Shade/Section/Frame")
	check(hud._fit_btn.text == "Frame", "frame control labeled Frame")
	check(hud._save_view_btn != null, "View strip has Save button")
	check(hud._views_drop_btn != null and hud._views_drop_btn.text == "▼",
		"View strip has down-arrow")
	check(hud._views_popup != null and hud._views_list != null, "Views popup exists")

	# --- Shade / display cycle ---
	while int(view.display_mode) != 0:
		view.cycle_display_mode()
	hud.sync_from_view(view)
	check(hud._display_btn.text == "Shade", "display label Shade at mode 0")
	hud.display_cycle_requested.emit()
	await process_frame
	check(int(view.display_mode) == 1, "Shade click advances display mode")
	hud.sync_from_view(view)
	check(hud._display_btn.text == "Edges", "display label Edges after cycle")
	hud.display_cycle_requested.emit()
	await process_frame
	check(int(view.display_mode) == 2, "second cycle → wireframe mode")
	hud.sync_from_view(view)
	check(hud._display_btn.text == "Wire", "display label Wire after second cycle")
	hud.display_cycle_requested.emit()
	await process_frame
	check(int(view.display_mode) == 0, "third cycle wraps to shaded")
	hud.sync_from_view(view)
	check(hud._display_btn.text == "Shade", "display label wraps to Shade")

	# --- Section toggle ---
	check(not view.section_enabled, "section starts off")
	check(not hud._section_btn.button_pressed, "Section button starts up")
	hud.section_toggle_requested.emit()
	await process_frame
	hud.sync_from_view(view)
	check(view.section_enabled, "Section click enables section")
	check(hud._section_btn.button_pressed, "Section button pressed when on")
	hud.section_toggle_requested.emit()
	await process_frame
	hud.sync_from_view(view)
	check(not view.section_enabled, "second Section click disables")
	check(not hud._section_btn.button_pressed, "Section button up when off")

	# --- Frame ---
	view.new_document()
	var body: String = view.insert_primitive("box", Vector3(80, 0, 0))
	view.select_entity(body, "")
	cam.yaw = 0.0
	cam.pitch = 0.3
	cam.distance = 900.0
	cam.pivot = Vector3.ZERO
	cam._update_transform()
	var dist_before := cam.distance
	hud.fit_requested.emit()
	await process_frame
	check(cam.distance < dist_before - 1.0, "Frame zooms in on selection")
	check(cam.pivot.distance_to(Vector3(80, 0, 0)) < 5.0,
		"Frame recenters pivot near selection")

	# --- ▼ expands defaults + user views ---
	for existing in cam.named_view_list():
		cam.remove_named_view(existing)
	hud.sync_named_views(cam.named_view_list())
	hud._toggle_views_popup()
	await process_frame
	check(hud._views_popup.visible, "▼ opens views popup")
	var def_labels: Array = []
	for c in hud._views_list.get_children():
		if c is Button:
			def_labels.append(str(c.text))
	check(def_labels.has("Front") and def_labels.has("Right")
			and def_labels.has("Top") and def_labels.has("Isometric"),
		"popup lists default views")
	check(not def_labels.has("User"), "no user views before save")
	# Default Front moves the camera.
	cam.yaw = 1.5
	cam.pitch = 0.8
	cam._update_transform()
	hud.default_view_requested.emit("front")
	await process_frame
	check(is_equal_approx(cam.yaw, 0.0), "default Front sets yaw")
	check(is_equal_approx(cam.pitch, 0.0), "default Front sets pitch")
	hud._views_popup.hide()

	# --- Save pops rename blank; Enter accepts ---
	cam.yaw = 0.4
	cam.pitch = 0.25
	cam.distance = 180.0
	cam.pivot = Vector3(12, 3, -4)
	cam._update_transform()
	var saved_yaw := cam.yaw
	var saved_pitch := cam.pitch
	var saved_dist := cam.distance
	var saved_pivot: Vector3 = cam.pivot

	hud._begin_save_rename()
	await process_frame
	check(hud._rename_popup.visible, "Save opens rename blank")
	check(hud._rename_edit.text == "", "rename blank starts empty")
	hud._commit_save_rename("")  # Enter on empty → no save
	await process_frame
	check(cam.named_view_list().is_empty(), "empty Enter does not save")
	hud._begin_save_rename()
	await process_frame
	hud._commit_save_rename("Front")  # reserved default label
	await process_frame
	check(cam.named_view_list().is_empty(), "cannot shadow default Front name")
	hud._begin_save_rename()
	await process_frame
	hud._commit_save_rename("  Side  ")
	await process_frame
	check(not hud._rename_popup.visible, "Enter closes rename blank")
	var listed := cam.named_view_list()
	check(listed.size() == 1 and listed.has("Side"), "Enter saves trimmed name Side")
	hud._toggle_views_popup()
	await process_frame
	var restore_btns: Array = []
	var delete_btns: Array = []
	for c in hud._views_list.find_children("*", "Button", true, false):
		if str(c.text) == "Side":
			restore_btns.append(c)
		elif str(c.text) == "×" and str(c.tooltip_text).contains("Side"):
			delete_btns.append(c)
	check(restore_btns.size() == 1, "Saved section shows Side")
	check(delete_btns.size() == 1, "Side has delete (×) button")
	# Defaults are bare Buttons (no × sibling); user rows are HBoxes.
	var front_is_bare := false
	for c in hud._views_list.get_children():
		if c is Button and str(c.text) == "Front":
			front_is_bare = true
	check(front_is_bare, "default Front has no delete row")

	cam.yaw = 1.0
	cam._update_transform()
	hud._commit_save_rename("Detail")
	await process_frame
	check(cam.named_view_list().has("Detail"), "second Save adds Detail")

	cam.yaw = -1.2
	cam.pitch = -0.5
	cam.distance = 400.0
	cam.pivot = Vector3(100, 50, 20)
	cam._update_transform()
	check(not is_equal_approx(cam.yaw, saved_yaw), "camera moved away from saved pose")
	hud.view_restore_requested.emit("Side")
	# Restore animates orientation + zoom (~0.25s).
	await create_timer(0.35).timeout
	check(is_equal_approx(cam.yaw, saved_yaw), "restore returns yaw")
	check(is_equal_approx(cam.pitch, saved_pitch), "restore returns pitch")
	check(is_equal_approx(cam.distance, saved_dist), "restore returns distance")
	check(cam.pivot.is_equal_approx(saved_pivot), "restore returns pivot")

	hud.view_delete_requested.emit("Side")
	await process_frame
	check(not cam.named_view_list().has("Side"), "delete removes Side from camera")
	hud._rebuild_views_popup()
	var still_listed := false
	for c2 in hud._views_list.find_children("*", "Button", true, false):
		if str(c2.text) == "Side":
			still_listed = true
	check(not still_listed, "delete removes Side from Views popup")
	check(cam.named_view_list().has("Detail"), "Detail remains after deleting Side")
	check(not cam.restore_named_view("Side"), "restore after delete fails")
	hud.view_delete_requested.emit("Detail")
	await process_frame
	check(cam.named_view_list().is_empty(), "Views empty after deleting all")
	hud._views_popup.hide()


func test_push_pull_preview_state(main) -> void:
	print("- push/pull preview distance state")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	var faces: PackedStringArray = view.doc.get_face_ids(id)
	check(faces.size() > 0, "faces for push/pull")
	if faces.is_empty():
		return
	view.select_entity(id, faces[0])
	ix._drag_mode = ViewportInteraction.DragMode.PUSH_PULL
	ix._drag_normal = view.selected_face_normal()
	ix._drag_start_point = ix._selection_center()
	ix._pp_preview_dist = 12.5
	ix._pp_badge_screen = Vector2(100, 100)
	check(is_equal_approx(ix._pp_preview_dist, 12.5), "preview distance stored")
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	ix._pp_preview_dist = 0.0


func test_rmb_orbit_and_peer_chrome(main) -> void:
	print("- RMB orbit vs menu + Space orientation")
	var ix: ViewportInteraction = main.interaction
	var cam: OrbitCamera = main.camera
	var yaw0 := cam.yaw
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(200, 200)
	ix._handle_model_pointer(press)
	check(ix._rmb_pressed, "RMB press armed")
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(260, 200)
	ix._handle_model_pointer(drag)
	check(ix._rmb_orbiting, "RMB travel arms orbit")
	check(absf(cam.yaw - yaw0) > 1e-4, "RMB drag changed yaw")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = Vector2(260, 200)
	ix._handle_model_pointer(release)
	check(not ix._rmb_pressed and not ix._rmb_orbiting, "RMB state cleared")
	check(ix._orient_popup != null, "orientation popup exists")
	ix._show_orient_popup()
	check(ix._orient_popup.visible, "Space orient popup can show")
	ix._orient_popup.hide()
	# Fit selection with a body selected.
	main.view.new_document()
	var id: String = main.view.insert_primitive("box", Vector3(100, 0, 0))
	main.view.select_entity(id, "")
	check(cam.frame_selection(), "frame_selection succeeds with body")
