# Headless tests for multi-select (Shift/Ctrl+click via select_ray additive)
# and empty-click deselection.
# Run: tools/godot/godot --headless --path game --script tests/run_select_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("multi-select tests")
	# Tiny default headless size makes stretch/rotate grips fill the viewport.
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_additive_bodies(main)
	test_additive_faces(main)
	test_additive_edges_and_fillet(main)
	test_single_select_resets(main)
	await test_shift_click_event_path(main)
	test_empty_click_deselect(main)
	test_jitter_reselect_after_deselect(main)
	await test_chrome_hover_does_not_block_empty_input(main)
	test_shift_empty_keeps_selection(main)
	test_multi_boolean_instant(main)
	test_copy_paste_offset(main)
	test_cut_paste_and_special(main)
	test_delete_key_and_strip(main)

	finish()


func _ray_at(x: float, y: float) -> Array:
	return [Vector3(x, y, 200), Vector3(0, 0, -1)]


func _screen_miss(main) -> Vector2:
	# Far from bodies in screen space.
	return Vector2(20, 20)


func test_additive_bodies(main) -> void:
	print("- additive body selection")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)          # -25..25
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))    # 75..125
	view.clear_selection()

	var r := _ray_at(0, 0)
	check(view.select_ray(r[0], r[1]), "click selects body A")
	check(view.selected_body == a, "primary is A")
	r = _ray_at(100, 0)
	check(view.select_ray(r[0], r[1], true), "additive click adds body B")
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "both bodies in set")
	check(view.selected_body == b, "primary follows last added")
	check(view.selection_size() == 2, "selection size 2")

	# Additive click B again toggles it off.
	check(view.select_ray(r[0], r[1], true), "additive click toggles B off")
	check(not view.selected_bodies.has(b), "B removed")
	check(view.selected_body == a, "primary falls back to A")


func test_additive_faces(main) -> void:
	print("- additive face selection")
	var view: DocumentView = main.view
	view.new_document()
	# Explicit 50 mm box so side-face ray and shell volume stay stable.
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 50))
	view.select_entity(a, "")
	# Additive click the top face of the already-selected body refines to a face.
	var r := _ray_at(0, 0)
	check(view.select_ray(r[0], r[1], true), "additive click on selected body picks face")
	check(view.selected_faces.size() == 1, "one face in set")
	check(view.selected_face != "", "primary face set")
	# Additive click a side face adds a second face.
	var side := [Vector3(200, 0, 25), Vector3(-1, 0, 0)]
	check(view.select_ray(side[0], side[1], true), "additive click side face")
	check(view.selected_faces.size() == 2, "two faces in set")

	# Multi-face shell through the ops panel.
	main.ops_panel._thickness_spin.value = 2.0
	main.ops_panel._shell()
	var vol: float = view.doc.body_volume(a)
	# Two open faces: thinner than a one-face shell, thicker than empty.
	check(vol > 15000.0 and vol < 30000.0, "multi-face shell applied (vol %.0f)" % vol)


func test_additive_edges_and_fillet(main) -> void:
	print("- additive edge selection + multi-edge fillet")
	var view: DocumentView = main.view
	view.new_document()
	# Explicit 50 mm box so fillet volume math stays stable.
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 50))
	view.select_entity(a, "")
	# Box spans -25..25 in x/y, 0..50 in z. Vertical edge at (25, 25) and (25, -25):
	# aim rays at two vertical edges (diagonal direction hits the corner line).
	var hits := 0
	for corner in [Vector3(25, 25, 25), Vector3(25, -25, 25)]:
		var origin: Vector3 = corner + Vector3(30, 30.0 if corner.y > 0 else -30.0, 0)
		var dir: Vector3 = (corner - origin).normalized()
		if view.select_ray(origin, dir, true):
			hits += 1
	check(hits == 2, "two additive clicks near corners hit")
	check(view.selected_edges.size() == 2, "two edges in set (got %d)" % view.selected_edges.size())

	var vol_before: float = view.doc.body_volume(a)
	main.ops_panel._radius_spin.value = 3.0
	main.ops_panel._fillet_all()
	var vol_after: float = view.doc.body_volume(a)
	# Two convex vertical edges filleted r=3, h=50: removes 2 * (9 - pi 9/4) * 50.
	# OCCT rolls the fillet around the edge ends, removing slightly more than
	# the ideal prism formula — allow 10%.
	var expected := 2.0 * (9.0 - PI * 9.0 / 4.0) * 50.0
	check(absf((vol_before - vol_after) - expected) < expected * 0.10,
		"multi-edge fillet removed ~%.0f mm^3 (got %.0f)" % [expected, vol_before - vol_after])


func test_single_select_resets(main) -> void:
	print("- plain click resets multi-select")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()
	var ra := _ray_at(0, 0)
	var rb := _ray_at(100, 0)
	view.select_ray(ra[0], ra[1])
	view.select_ray(rb[0], rb[1], true)
	check(view.selection_size() == 2, "two selected before plain click")
	view.select_ray(ra[0], ra[1])
	check(view.selection_size() == 1 and view.selected_body == a, "plain click collapses to A")
	view.clear_selection()
	check(view.selection_size() == 0 and view.selected_bodies.is_empty(), "clear empties sets")
	check(b != "", "b silences unused warning")


## Shift+click through the real input path (`_input`) toggles additive selection
## and never arms a body drag.
func test_shift_click_event_path(main) -> void:
	print("- shift+click via viewport input")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()
	view.select_entity(a, "")
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame

	# Screen position of body B's center, then a synthetic Shift+LMB click.
	var half_b := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
	var center_b: Vector3 = main.model_space.to_global(Vector3(100, 0, half_b))
	var screen_b: Vector2 = main.camera.unproject_position(center_b)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.shift_pressed = true
		mb.position = screen_b
		vi._input(mb)
	check(view.selection_size() == 2, "shift+click added B (size %d)" % view.selection_size())
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "both bodies selected")


func _find_empty_screen(main, view: DocumentView, vi: ViewportInteraction) -> Vector2:
	# Headless Interaction can stay 64² unless forced; back the camera off so
	# stretch/rotate grips don't cover the viewport corners.
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.distance = 800.0
	main.camera.pivot = Vector3.ZERO
	main.camera._update_transform()
	var sz := Vector2(1280, 720)
	var candidates: Array[Vector2] = []
	for x in [8.0, 32.0, sz.x * 0.5, sz.x - 32.0, sz.x - 8.0]:
		for y in [8.0, 32.0, sz.y - 32.0, sz.y - 8.0]:
			candidates.append(Vector2(x, y))
	for candidate in candidates:
		var ray := vi._model_ray(candidate)
		if not view.pick_info(ray[0], ray[1]).is_empty():
			continue
		if not vi._pick_rotate_grip(candidate).is_empty():
			continue
		if not vi._pick_resize_handle(candidate).is_empty():
			continue
		return candidate
	push_error("no empty screen point found")
	return Vector2(-1, -1)


func test_empty_click_deselect(main) -> void:
	print("- empty click clears selection")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	check(view.selected_body == a, "body selected before empty click")
	var miss := _find_empty_screen(main, view, vi)
	check(miss.x >= 0.0, "found empty screen point for deselect")
	var ray_miss := vi._model_ray(miss)
	check(view.pick_info(ray_miss[0], ray_miss[1]).is_empty(), "miss is empty space")
	check(vi._pick_rotate_grip(miss).is_empty(), "miss not on rotate grip")
	check(vi._pick_resize_handle(miss).is_empty(), "miss not on stretch grip")
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = miss
		vi._gui_input(mb)
	check(view.selected_body == "", "empty click cleared selection")
	check(view.selection_size() == 0, "selection size 0 after empty click")


func test_jitter_reselect_after_deselect(main) -> void:
	print("- trackpad-jitter click still selects / deselects")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.clear_selection()
	var half := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
	var center: Vector3 = main.model_space.to_global(Vector3(0, 0, half))
	var screen: Vector2 = main.camera.unproject_position(center)
	# Drive via `_input` (live app path) — press on body, release with jitter.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	vi._input(press)
	var mm := InputEventMouseMotion.new()
	mm.position = screen + Vector2(10, 4)
	vi._input(mm)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen + Vector2(10, 4)
	vi._input(release)
	check(view.selected_body == a, "jittered click still selected body via _input")

	# Soft empty orbit (12–20px) should still deselect.
	var miss := _find_empty_screen(main, view, vi)
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	vi._input(press)
	mm = InputEventMouseMotion.new()
	mm.position = miss + Vector2(16, 0)
	vi._input(mm)
	release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(16, 0)
	vi._input(release)
	check(view.selected_body == "", "soft empty orbit still deselects via _input")

	# Empty-space drag via `_input` should arm ORBIT_VIEW.
	view.select_entity(a, "")
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	vi._input(press)
	mm = InputEventMouseMotion.new()
	mm.position = miss + Vector2(40, 0)
	vi._input(mm)
	check(vi._drag_mode == ViewportInteraction.DragMode.ORBIT_VIEW, "empty drag via _input arms orbit")
	release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(40, 0)
	vi._input(release)
	check(vi._drag_mode == ViewportInteraction.DragMode.NONE, "orbit cleared on release")


## Regression: stale TransformHud / SelectionStrip hover must not block empty-space
## LMB via `_input` when the click is outside chrome rects.
func test_chrome_hover_does_not_block_empty_input(main) -> void:
	print("- chrome hover does not block empty _input")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	check(vi._selection_strip.visible, "selection strip visible after select")
	var miss := _find_empty_screen(main, view, vi)
	check(miss.x >= 0.0, "found empty screen point")
	check(not vi._over_chrome(miss), "miss is outside chrome rects")
	# Park the cursor over the strip so gui hover is our chrome, not empty space.
	var strip_center := vi._selection_strip.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = strip_center
	vi.get_viewport().push_input(hover)
	await process_frame
	var h: Control = vi.get_viewport().gui_get_hovered_control()
	check(h != null and vi.is_ancestor_of(h), "cursor hover is interaction chrome")
	check(vi._viewport_owns_pointer(miss), "empty miss still owns pointer despite chrome hover")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	vi._input(press)
	var mm := InputEventMouseMotion.new()
	mm.position = miss + Vector2(16, 0)
	vi._input(mm)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(16, 0)
	vi._input(release)
	check(view.selected_body == "", "soft empty orbit deselects with chrome hover")


func test_shift_empty_keeps_selection(main) -> void:
	print("- shift+empty click keeps selection")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	var miss := _screen_miss(main)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.shift_pressed = true
		mb.position = miss
		vi._gui_input(mb)
	check(view.selected_body == a, "shift+empty kept selection")
	check(view.selection_size() == 1, "selection size still 1")


func test_multi_boolean_instant(main) -> void:
	print("- multi-select Join/Subtract apply instantly")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 20))
	var b: String = view.insert_primitive("box", Vector3(10, 0, 0), Vector3(20, 20, 20))
	view.select_entity(a, "")
	check(view.select_ray(Vector3(15, 0, 200), Vector3(0, 0, -1), true), "additive select overlapping B")
	check(view.selected_bodies.size() == 2, "two bodies multi-selected (got %d)" % view.selected_bodies.size())
	vi._refresh_selection_strip()
	check(vi._strip_fuse.visible and vi._strip_cut.visible, "Join/Subtract visible for multi-select")
	var vol0: float = float(view.doc.body_volume(a))
	vi._ctx_boolean("fuse")
	check(view.doc.body_ids().size() == 1, "fuse consumed tool body")
	var remaining: String = str(view.doc.body_ids()[0])
	var vol1: float = float(view.doc.body_volume(remaining))
	check(vol1 > vol0 + 1.0, "fused volume larger than primary alone")
	check(b != "", "tool body id allocated")


func test_copy_paste_offset(main) -> void:
	print("- Ctrl+C / Ctrl+V paste offset")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	# 50×30×10 box so XY offset is predictable: 20% → (10, 6, 0).
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 30, 10))
	view.select_entity(a, "")
	var bb0: Dictionary = view.doc.measure_bbox(a)
	check(not bb0.is_empty(), "source has bbox")

	var key_c := InputEventKey.new()
	key_c.keycode = KEY_C
	key_c.ctrl_pressed = true
	key_c.pressed = true
	check(vi._gui_key(key_c), "Ctrl+C handled")
	check(view._clipboard_bodies.size() == 1, "one body on clipboard")
	check(view._clipboard_bodies[0] == a, "clipboard is the selected body")

	var before_ids: PackedStringArray = view.doc.body_ids()
	var key_v := InputEventKey.new()
	key_v.keycode = KEY_V
	key_v.ctrl_pressed = true
	key_v.pressed = true
	check(vi._gui_key(key_v), "Ctrl+V handled")
	check(view.doc.body_ids().size() == before_ids.size() + 1, "paste added one body")
	check(view.selection_size() == 1, "paste selects the new body")
	var pasted: String = view.selected_body
	check(pasted != "" and pasted != a, "selection is the paste, not the source")
	var bb1: Dictionary = view.doc.measure_bbox(pasted)
	var delta: Vector3 = bb1["min"] - bb0["min"]
	check(is_equal_approx(delta.x, 10.0), "paste ΔX = 20%% of width (got %.3f)" % delta.x)
	check(is_equal_approx(delta.y, 6.0), "paste ΔY = 20%% of depth (got %.3f)" % delta.y)
	check(is_equal_approx(delta.z, 0.0), "paste stays on plane (ΔZ=0, got %.3f)" % delta.z)

	# Second paste steps further by the same offset.
	check(vi._gui_key(key_v), "second Ctrl+V")
	check(view.doc.body_ids().size() == before_ids.size() + 2, "second paste added another body")
	var bb2: Dictionary = view.doc.measure_bbox(view.selected_body)
	var delta2: Vector3 = bb2["min"] - bb0["min"]
	check(is_equal_approx(delta2.x, 20.0), "second paste ΔX = 40%% of width (got %.3f)" % delta2.x)
	check(is_equal_approx(delta2.y, 12.0), "second paste ΔY = 40%% of depth (got %.3f)" % delta2.y)

	# Multi-select copy/paste keeps relative spacing.
	view.new_document()
	var p: String = view.insert_primitive("box", Vector3.ZERO, Vector3(10, 10, 10))
	var q: String = view.insert_primitive("box", Vector3(40, 0, 0), Vector3(10, 10, 10))
	view.select_entity(p, "")
	view.select_ray(Vector3(40, 0, 200), Vector3(0, 0, -1), true)
	check(view.selection_size() == 2, "multi-selected two bodies")
	check(view.copy_selection() == 2, "copied two")
	var n0: int = view.doc.body_ids().size()
	var made: Array = view.paste_clipboard()
	check(made.size() == 2, "pasted two (got %d)" % made.size())
	check(view.doc.body_ids().size() == n0 + 2, "doc gained two bodies")
	check(view.selection_size() == 2, "selection is both pastes")
	# Combined group is 50 wide (0..10 and 40..50); 20% → 10 mm in X for both.
	var bb_p: Dictionary = view.doc.measure_bbox(p)
	var bb_m0: Dictionary = view.doc.measure_bbox(made[0])
	check(is_equal_approx((bb_m0["min"] - bb_p["min"]).x, 10.0),
		"multi paste shares group XY offset")
	check(q != "", "second source allocated")


func test_cut_paste_and_special(main) -> void:
	print("- Cut / Paste Special / Edit menu")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 30, 10))
	view.select_entity(a, "")
	var bb0: Dictionary = view.doc.measure_bbox(a)
	check(not bb0.is_empty(), "cut source bbox")

	var key_x := InputEventKey.new()
	key_x.keycode = KEY_X
	key_x.ctrl_pressed = true
	key_x.pressed = true
	check(vi._gui_key(key_x), "Ctrl+X cut handled")
	check(view.doc.body_ids().size() == 0 or view.hidden_bodies.size() >= 1,
		"cut removed visible original (bodies=%d hidden=%d)" % [
				view.doc.body_ids().size(), view.hidden_bodies.size()])
	check(view.has_clipboard(), "clipboard after cut")
	check(view._clipboard_cut, "clipboard marked cut")

	var key_v := InputEventKey.new()
	key_v.keycode = KEY_V
	key_v.ctrl_pressed = true
	key_v.pressed = true
	check(vi._gui_key(key_v), "Ctrl+V after cut")
	check(view.doc.body_ids().size() >= 1, "paste after cut restored a body")
	check(not view._clipboard_cut, "cut flag cleared after paste")
	var pasted: String = view.selected_body
	check(pasted != "", "paste selected body")
	var bb1: Dictionary = view.doc.measure_bbox(pasted)
	var delta: Vector3 = bb1["min"] - bb0["min"]
	check(is_equal_approx(delta.x, 10.0), "cut-paste ΔX 20%% (got %.3f)" % delta.x)

	# Paste Special with custom offset from Edit menu path.
	view.copy_selection()
	var n0: int = view.doc.body_ids().size()
	var made: Array = view.paste_clipboard(Vector3(25, 0, 0))
	check(made.size() == 1, "paste special offset created one")
	check(view.doc.body_ids().size() == n0 + 1, "doc gained one from paste special")
	var bb2: Dictionary = view.doc.measure_bbox(made[0])
	check(is_equal_approx((bb2["min"] - bb1["min"]).x, 25.0),
		"paste special ΔX=25 (got %.3f)" % (bb2["min"] - bb1["min"]).x)

	# In-place paste special.
	view.copy_selection()
	var at: String = view.selected_body
	var bb_at: Dictionary = view.doc.measure_bbox(at)
	var inplace: Array = view.paste_clipboard(Vector3.ZERO)
	check(inplace.size() == 1, "in-place paste created body")
	var bb_ip: Dictionary = view.doc.measure_bbox(inplace[0])
	check((bb_ip["min"] - bb_at["min"]).length() < 0.05, "in-place near source")

	# Edit menu exists and routes.
	check(main._edit_popup != null, "Edit menu popup mounted")
	main._refresh_edit_menu()
	view.select_entity(inplace[0], "")
	main.edit_copy()
	check(view.has_clipboard(), "Edit→Copy filled clipboard")
	main.edit_paste_special()
	check(main._paste_special_dialog != null and main._paste_special_dialog.visible,
		"Paste Special dialog opened")
	main._paste_special_dialog.hide()


func test_delete_key_and_strip(main) -> void:
	print("- Del / Backspace / Delete strip remove selection")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(40, 0, 0))
	view.select_entity(a, "")
	check(view.selected_body == a, "body selected before delete")
	# Focus elsewhere (simulates size HUD / dock) — Del must still work.
	vi.release_focus()
	check(not vi.has_focus(), "Interaction unfocused")
	var key_del := InputEventKey.new()
	key_del.keycode = KEY_DELETE
	key_del.pressed = true
	vi._input(key_del)
	check(view.doc.body_ids().size() == 1, "Delete key removed body without focus")
	check(view.selected_body == "", "selection cleared after Delete")
	view.select_entity(b, "")
	vi.release_focus()
	var key_bs := InputEventKey.new()
	key_bs.keycode = KEY_BACKSPACE
	key_bs.pressed = true
	vi._input(key_bs)
	check(view.doc.body_ids().is_empty(), "Backspace removed remaining body")
	# Strip Delete button.
	var c: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(c, "")
	vi._refresh_selection_strip()
	check(vi._strip_delete.visible, "Delete strip button visible")
	vi._strip_delete.pressed.emit()
	check(view.doc.body_ids().is_empty(), "strip Delete removed body")
	# Multi-select delete removes every selected body.
	var p: String = view.insert_primitive("box", Vector3.ZERO)
	var q: String = view.insert_primitive("box", Vector3(40, 0, 0))
	view.select_entity(p, "")
	view.select_ray(Vector3(40, 0, 200), Vector3(0, 0, -1), true)
	check(view.selection_size() == 2, "two bodies selected")
	check(view.delete_selected(), "delete_selected removes multi")
	check(view.doc.body_ids().is_empty(), "both bodies gone")
	check(p != "" and q != "", "ids allocated")
