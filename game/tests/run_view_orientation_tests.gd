# View menu Orientation, HUD View list, and number keys share one camera path.
# Cardinal views are axis-aligned, orthographic, and centred on the part.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_view_orientation_tests.gd
extends SceneTree

const AXIAL_EPS := 1e-4
const CENTER_MM := 0.05
const SCREEN_PX := 2.0

var failures := 0
var checks := 0

## Label, view id, number key, exact look direction (world, camera -Z).
const VIEWS: Array = [
	["Front", "front", KEY_1, Vector3(0, 0, -1), true],
	["Back", "back", KEY_4, Vector3(0, 0, 1), true],
	["Left", "left", KEY_6, Vector3(1, 0, 0), true],
	["Right", "right", KEY_2, Vector3(-1, 0, 0), true],
	["Top", "top", KEY_3, Vector3(0, -1, 0), true],
	["Bottom", "bottom", KEY_8, Vector3(0, 1, 0), true],
	["Isometric", "iso", KEY_7, Vector3.ZERO, false],
]


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("view orientation menu / HUD / keys")
	root.size = Vector2i(1280, 800)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_test_menu_items(main)
	var body: String = main.view.insert_primitive("box", Vector3(30, -20, 5), Vector3(40, 16, 12))
	await process_frame
	main.view.select_entity("", "")
	var center := _part_center(main, body)
	check(center.length_squared() > 1.0, "part center is off the origin (%s)" % str(center))
	for entry in VIEWS:
		await _test_one(main, center, entry)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_menu_items(main) -> void:
	print("- View menu Orientation items")
	var popup: PopupMenu = main._view_popup
	check(popup != null, "menu-bar View popup exists")
	if popup == null:
		return
	var texts: Array[String] = []
	for i in popup.item_count:
		texts.append(popup.get_item_text(i))
	check(texts.has("Orientation"), "View menu has an Orientation section (got %s)" % str(texts))
	for entry in VIEWS:
		var label := str(entry[0])
		var want: Key = entry[2]
		var idx := _item_index(popup, label)
		check(idx >= 0, "View menu lists %s" % label)
		if idx < 0:
			continue
		var sc: Shortcut = popup.get_item_shortcut(idx)
		var got := KEY_NONE
		if sc != null and not sc.events.is_empty() and sc.events[0] is InputEventKey:
			got = (sc.events[0] as InputEventKey).keycode
		check(got == want, "%s shortcut is %s (got %s)" % [label, _key_name(want), _key_name(got)])
		check(str(popup.get_item_metadata(idx)) == str(entry[1]),
				"%s metadata is %s" % [label, str(entry[1])])


func _test_one(main, center: Vector3, entry: Array) -> void:
	var label := str(entry[0])
	var vid := str(entry[1])
	var key: Key = entry[2]
	var look: Vector3 = entry[3]
	var axial: bool = entry[4]
	print("- %s: menu, HUD, key" % label)
	_scramble(main.camera, 0.4)
	_press_menu(main, label)
	await process_frame
	var menu_pose := _pose(main.camera)
	_scramble(main.camera, 1.7)
	_press_hud(main, label)
	await process_frame
	var hud_pose := _pose(main.camera)
	_scramble(main.camera, -1.1)
	await _press_key(main, key)
	var key_pose := _pose(main.camera)
	check(_pose_eq(menu_pose, hud_pose),
			"%s menu transform == HUD (menu %s hud %s)" % [label, _fmt(menu_pose), _fmt(hud_pose)])
	check(_pose_eq(menu_pose, key_pose),
			"%s menu transform == key (menu %s key %s)" % [label, _fmt(menu_pose), _fmt(key_pose)])
	_assert_centered(main, center, label)
	if axial:
		_assert_axial(main.camera, look, label)
		check(main.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
				"%s is orthographic" % label)
	else:
		var got_look: Vector3 = -main.camera.global_transform.basis.z
		var cardinal := maxf(absf(got_look.x), maxf(absf(got_look.y), absf(got_look.z)))
		check(cardinal < 0.95, "Isometric is not a cardinal axis (look %s)" % str(got_look))


func _assert_axial(cam: OrbitCamera, want: Vector3, label: String) -> void:
	var look := -cam.global_transform.basis.z
	var err := (look - want).length()
	check(err < AXIAL_EPS, "%s look is %s (got %s, err %.6f)" % [label, str(want), str(look), err])
	var offset := cam.global_position - cam.pivot
	if offset.length_squared() > 1e-8:
		var along := offset.normalized()
		# Camera sits on the opposite side of the look axis.
		check((along + want).length() < AXIAL_EPS,
				"%s camera is on the view axis (offset %s)" % [label, str(along)])
	var up_dot := absf(cam.global_transform.basis.y.dot(want))
	check(up_dot < AXIAL_EPS, "%s screen-up is perpendicular to the view axis (%.6f)" % [label, up_dot])


func _assert_centered(main, center: Vector3, label: String) -> void:
	var cam: OrbitCamera = main.camera
	check(cam.pivot.distance_to(center) < CENTER_MM,
			"%s pivot is the part center (pivot %s center %s)" % [label, str(cam.pivot), str(center)])
	var vp: Viewport = main.get_viewport()
	var screen := cam.unproject_position(center)
	var mid: Vector2 = vp.get_visible_rect().size * 0.5
	check(screen.distance_to(mid) < SCREEN_PX,
			"%s part center is at the window center (px %s mid %s)" % [label, str(screen), str(mid)])


func _part_center(main, body: String) -> Vector3:
	var bb: Dictionary = main.view.doc.measure_bbox(body)
	var c: Vector3 = (bb["min"] + bb["max"]) * 0.5
	return main.model_space.to_global(c)


func _scramble(cam: OrbitCamera, seed: float) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.yaw = seed
	cam.pitch = deg_to_rad(25.0 + seed * 10.0)
	cam.distance = 640.0 + absf(seed) * 80.0
	cam.pivot = Vector3(80.0, -40.0, 25.0) * seed
	cam._look_at_content = false
	cam._update_transform()


func _press_menu(main, label: String) -> void:
	var popup: PopupMenu = main._view_popup
	var idx := _item_index(popup, label)
	if idx < 0:
		return
	popup.id_pressed.emit(popup.get_item_id(idx))


func _press_hud(main, label: String) -> void:
	var hud: ViewHud = main.view_hud
	hud._rebuild_views_popup()
	for c in hud._views_list.get_children():
		if c is Button and str((c as Button).text) == label:
			(c as Button).pressed.emit()
			return


func _press_key(main, key: Key) -> void:
	var vp: Viewport = main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = true
	vp.push_input(ev)
	await process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)
	await process_frame


func _item_index(popup: PopupMenu, label: String) -> int:
	for i in popup.item_count:
		if popup.get_item_text(i) == label:
			return i
	return -1


func _pose(cam: OrbitCamera) -> Dictionary:
	var b := cam.global_transform.basis
	return {
		"o": cam.global_position,
		"x": b.x, "y": b.y, "z": b.z,
		"proj": cam.projection,
		"pivot": cam.pivot,
	}


func _pose_eq(a: Dictionary, b: Dictionary) -> bool:
	if int(a["proj"]) != int(b["proj"]):
		return false
	var keys := ["o", "x", "y", "z", "pivot"]
	for k in keys:
		var av: Vector3 = a[k]
		var bv: Vector3 = b[k]
		if av.distance_to(bv) > 1e-3:
			return false
	return true


func _fmt(p: Dictionary) -> String:
	return "o=%s z=%s proj=%s pivot=%s" % [str(p["o"]), str(p["z"]), str(p["proj"]), str(p["pivot"])]


func _key_name(k: Key) -> String:
	return OS.get_keycode_string(k)
