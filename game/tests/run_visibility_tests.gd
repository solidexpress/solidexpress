# Headless tests for hide/isolate and rubber-band box selection.
# Run: tools/godot/godot --headless --path game --script tests/run_visibility_tests.gd
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
	print("visibility / box-select tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_hide_and_pick_through(main)
	test_unhide_all(main)
	test_isolate(main)
	test_hidden_survives_refresh(main)
	test_select_in_rect(main)
	test_box_select_drag(main)
	test_box_select_crossing_drag(main)
	test_select_similar(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _ray_at(x: float, y: float) -> Array:
	return [Vector3(x, y, 200), Vector3(0, 0, -1)]


func _screen_of(main, body_id: String) -> Vector2:
	var world: Vector3 = main.model_space.to_global(main.view.body_center(body_id))
	return main.camera.unproject_position(world)


func test_hide_and_pick_through(main) -> void:
	print("- hide + pick-through")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3.ZERO)
	# Stack B above A so a -Z ray hits B first, then A.
	view.doc.translate_body(b, Vector3(0, 0, 60))
	view.refresh()
	view.clear_selection()

	view.select_entity(b, "")
	view.set_body_hidden(b, true)
	var node_b: MeshInstance3D = view.body_node(b)
	check(node_b != null and not node_b.visible, "hidden body mesh invisible")
	check(not view.selected_bodies.has(b) and view.selected_body != b, "hiding clears selection")

	var r := _ray_at(0, 0)
	check(view.select_ray(r[0], r[1]), "pick-through hits body behind")
	check(view.selected_body == a, "selected the body behind (A)")
	check(a != "" and b != "", "ids present")


func test_unhide_all(main) -> void:
	print("- unhide_all")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.set_body_hidden(a, true)
	view.set_body_hidden(b, true)
	check(not view.body_node(a).visible and not view.body_node(b).visible, "both hidden")
	view.unhide_all()
	check(view.hidden_bodies.is_empty(), "hidden_bodies cleared")
	check(view.body_node(a).visible and view.body_node(b).visible, "both visible again")


func test_isolate(main) -> void:
	print("- isolate")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	var c: String = view.insert_primitive("box", Vector3(200, 0, 0))
	view.select_entity(a, "")
	view.isolate([a])
	check(view.body_node(a).visible, "isolated target visible")
	check(not view.body_node(b).visible and not view.body_node(c).visible, "others hidden")

	# I with nothing selected restores all (via key path).
	view.clear_selection()
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.pressed = true
	vi._gui_key(key)
	check(view.hidden_bodies.is_empty(), "I with empty selection unhides all")
	check(view.body_node(a).visible and view.body_node(b).visible and view.body_node(c).visible,
		"all bodies shown after I")


func test_hidden_survives_refresh(main) -> void:
	print("- hidden survives refresh")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.set_body_hidden(a, true)
	check(not view.body_node(a).visible, "hidden before refresh")
	view.refresh()
	check(view.hidden_bodies.has(a), "hidden_bodies keeps id after refresh")
	check(not view.body_node(a).visible, "still invisible after refresh")


func test_select_in_rect(main) -> void:
	print("- select_in_rect (window vs crossing)")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()

	var aa := view.body_screen_aabb(a, main.camera, main.model_space)
	var ab := view.body_screen_aabb(b, main.camera, main.model_space)
	check(aa.size != Vector2.ZERO and ab.size != Vector2.ZERO, "screen AABBs present")
	var both := aa.merge(ab).grow(8.0)
	view.select_in_rect(both, main.camera, main.model_space, false, false)
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "window encloses both")
	check(view.selection_size() == 2, "selection size 2")

	# Tiny window around A's center: does not fully enclose A → empty.
	var sa := _screen_of(main, a)
	var tiny := Rect2(sa - Vector2(4, 4), Vector2(8, 8))
	view.select_in_rect(tiny, main.camera, main.model_space, false, false)
	check(view.selection_size() == 0, "window tiny rect selects nothing")

	# Same tiny rect as crossing: intersects A only.
	view.select_in_rect(tiny, main.camera, main.model_space, false, true)
	check(view.selected_bodies.has(a) and not view.selected_bodies.has(b), "crossing tiny hits A only")
	check(view.selected_body == a, "primary is A")

	# Crossing rect that only clips B's AABB (not fully enclosing) should still get B.
	var clip_b := Rect2(ab.position + ab.size * 0.25, ab.size * 0.2)
	view.select_entity(a, "")
	view.select_in_rect(clip_b, main.camera, main.model_space, true, true)
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "additive crossing unions B")

	# Window must fully enclose A — use A's AABB grown slightly.
	view.clear_selection()
	view.select_in_rect(aa.grow(2.0), main.camera, main.model_space, false, false)
	check(view.selected_bodies.has(a) and not view.selected_bodies.has(b), "window encloses only A")


func test_box_select_drag(main) -> void:
	print("- Shift+left window box via _gui_input drag")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()

	var aa := view.body_screen_aabb(a, main.camera, main.model_space)
	var ab := view.body_screen_aabb(b, main.camera, main.model_space)
	var band := aa.merge(ab).grow(16.0)
	# Start in empty screen space near the band corner, then drag across.
	var start := band.position - Vector2(20, 20)
	var ray := vi._model_ray(start)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	check(hit.is_empty(), "drag starts on empty space")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.shift_pressed = true
	press.position = start
	vi._gui_input(press)

	var end := band.end + Vector2(8, 8)
	var steps := [0.25, 0.5, 0.75, 1.0]
	for t in steps:
		var mm := InputEventMouseMotion.new()
		mm.position = start.lerp(end, t)
		vi._gui_input(mm)
	check(vi._drag_mode == ViewportInteraction.DragMode.BOX_SELECT, "drag armed BOX_SELECT")
	check(not vi._box_crossing, "left-drag is window (exclusive)")
	check(vi._box_rect.size.length() > 0.0, "rubber-band rect has size")

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.shift_pressed = true
	release.position = end
	vi._gui_input(release)

	check(view.selected_bodies.has(a) and view.selected_bodies.has(b),
		"window band selected both (got %d)" % view.selection_size())
	check(vi._drag_mode == ViewportInteraction.DragMode.NONE, "drag mode cleared on release")


func test_box_select_crossing_drag(main) -> void:
	print("- Shift+right crossing box via _gui_input drag")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()

	var aa := view.body_screen_aabb(a, main.camera, main.model_space)
	var ab := view.body_screen_aabb(b, main.camera, main.model_space)
	# Band that only partially covers each AABB (crossing should still hit both).
	var mid := (aa.get_center() + ab.get_center()) * 0.5
	var start := mid - Vector2(30, 10)
	var end := mid + Vector2(30, 10)
	var ray := vi._model_ray(start)
	check(view.pick_info(ray[0], ray[1]).is_empty(), "crossing drag starts empty")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.shift_pressed = true
	press.position = start
	vi._gui_input(press)

	for t in [0.35, 0.7, 1.0]:
		var mm := InputEventMouseMotion.new()
		mm.position = start.lerp(end, t)
		vi._gui_input(mm)
	check(vi._drag_mode == ViewportInteraction.DragMode.BOX_SELECT, "right-drag armed BOX_SELECT")
	check(vi._box_crossing, "right-drag is crossing (inclusive)")

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.shift_pressed = true
	release.position = end
	vi._gui_input(release)

	check(view.selected_bodies.has(a) and view.selected_bodies.has(b),
		"crossing band selected both (got %d)" % view.selection_size())
	check(vi._drag_mode == ViewportInteraction.DragMode.NONE, "crossing drag cleared")


func test_select_similar(main) -> void:
	print("- select_similar")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(80, 0, 0))
	var c: String = view.insert_primitive("cylinder", Vector3(160, 0, 0))
	view.select_entity(a, "")
	var added := view.select_similar()
	check(added == 1, "similar added one other box")
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "both boxes selected")
	check(not view.selected_bodies.has(c), "cylinder not selected")