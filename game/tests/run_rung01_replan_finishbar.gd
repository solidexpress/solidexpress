# Rung 1 replan WP1 — finish bar a person can read and type into.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan_finishbar.gd
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
	print("rung01 replan WP1 finish bar")
	# Headless window stays 64×64, so host the app in a desktop-sized viewport
	# where finish-bar clicks can land.
	var host := SubViewport.new()
	host.size = Vector2i(1280, 720)
	host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(host)
	var main = load("res://scenes/main.tscn").instantiate()
	host.add_child(main)
	await process_frame
	await process_frame
	await _open_sketch(main)
	await test_distance_and_thin(main)
	await test_up_to_surface(main)
	await test_dim_typing(main)
	await test_across_flats_suffix(main)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _open_sketch(main) -> void:
	main.view.new_document()
	var body: String = main.view.insert_primitive("box", Vector3.ZERO)
	var face := _top_face(main.view, body)
	if face != "":
		main.view.select_entity(body, face)
	main._start_sketch()
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = main.sketch_chrome
	check(chrome != null and chrome.visible, "sketch chrome visible")
	check(face != "" and main.view.selected_face == face,
			"host face stays selected so Up To Surface must not copy it")


func _top_face(view, body_id: String) -> String:
	var best := ""
	var best_z := -1e9
	if body_id == "" or view == null or view.doc == null:
		return ""
	for face_id in view.doc.get_face_ids(body_id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if mid.z > best_z:
			best_z = mid.z
			best = face_id
	return best


func test_distance_and_thin(main) -> void:
	print("- distance readable, thin hidden, extrude thin is 0")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	var dim: SpinBox = chrome.find_child("DimSpin", true, false)
	var thin: SpinBox = chrome.find_child("ThinSpin", true, false)
	var thin_type: OptionButton = chrome.find_child("ThinType", true, false)
	var flip: CheckButton = chrome.find_child("FlipSide", true, false)
	var feature: CheckButton = chrome.find_child("ThinFeature", true, false)
	var d_label: Label = chrome.find_child("DistanceLabel", true, false)
	var thin_label: Label = chrome.find_child("ThinLabel", true, false)
	check(dist != null and dim != null and thin != null, "three spins exist")
	check(feature != null and not feature.button_pressed, "Thin feature defaults off")
	check(d_label != null and d_label.text == "D", "distance label is D")
	check(thin_label != null and thin_label.text == "Thin", "thin label is Thin")
	if dist == null or dim == null or thin == null or feature == null:
		return
	check(dist.custom_minimum_size.x >= UiScale.px(140) - 0.5, "distance spin min width")
	check(dim.custom_minimum_size.x >= UiScale.px(140) - 0.5, "dim spin min width")
	check(thin.custom_minimum_size.x >= UiScale.px(140) - 0.5, "thin spin min width")
	var dist_edit := dist.get_line_edit()
	check(dist_edit != null and dist_edit.text.contains("20.0"),
			"distance text contains 20.0 (%s)" % (dist_edit.text if dist_edit else ""))
	check(dist_edit != null and dist_edit.size.x >= UiScale.px(110) - 0.5,
			"distance LineEdit width %.1f >= %.1f" % [
				dist_edit.size.x if dist_edit else -1.0, UiScale.px(110)])
	check(thin != null and not thin.is_visible_in_tree(), "thin spin hidden")
	check(thin_type != null and not thin_type.is_visible_in_tree(), "thin type hidden")
	check(flip != null and not flip.is_visible_in_tree(), "Flip hidden")
	# A value sitting in the hidden spin must not leak into Extrude.
	thin.value = 4.0
	var thin_arg := _press_extrude(chrome)
	check(is_equal_approx(thin_arg, 0.0), "extrude thin_thickness is 0 while toggle off")
	feature.button_pressed = true
	await process_frame
	check(thin.is_visible_in_tree(), "thin spin shows when Thin feature is on")
	thin.value = 1.5
	await process_frame
	var badge: Label = chrome.find_child("ThinBadge", true, false)
	check(badge != null and badge.visible and str(badge.text).contains("1.5"),
			"thin badge contains 1.5 (%s)" % (badge.text if badge else ""))
	var thin_on := _press_extrude(chrome)
	check(is_equal_approx(thin_on, 1.5), "extrude thin_thickness is 1.5 while toggle on")
	feature.button_pressed = false
	await process_frame
	check(not thin.is_visible_in_tree(), "thin spin hides again")
	var thin_off := _press_extrude(chrome)
	check(is_equal_approx(thin_off, 0.0), "extrude thin_thickness returns to 0")


func _press_extrude(chrome: SketchContextChrome) -> float:
	var got := {"thin": NAN, "fired": false}
	var cb := func(op: String, distance: float, end: String, thin: float,
			thin_type: String, flip_side: bool, contours: Array) -> void:
		got["thin"] = thin
		got["fired"] = true
	chrome.finish_requested.connect(cb, CONNECT_ONE_SHOT)
	var btn := chrome.extrude_button()
	check(btn != null, "Extrude button exists")
	if btn != null:
		btn.pressed.emit()
	check(bool(got["fired"]), "Extrude pressed emitted finish_requested")
	return float(got["thin"])


func test_up_to_surface(main) -> void:
	print("- Up To Surface arms an empty face box")
	var chrome: SketchContextChrome = main.sketch_chrome
	var end: OptionButton = chrome.find_child("FinishEnd", true, false)
	check(end != null, "FinishEnd exists")
	if end == null:
		return
	var host := str(main.view.selected_face)
	# Popup index_pressed is the menu click. It emits item_selected.
	# select() alone does not, so this is the path a person uses.
	end.get_popup().index_pressed.emit(3)
	await process_frame
	check(end.selected == 3, "End is Up To Surface")
	var btn := chrome.extrude_button()
	check(btn != null and btn.disabled, "Extrude disabled until a face is picked")
	check(chrome.up_to_face_id == "", "up_to_face_id empty")
	check(host == "" or chrome.up_to_face_id != host, "did not copy selected_face")
	var face := _face_text(chrome)
	check(face.contains("Face: none"), "shows Face: none (%s)" % face)
	check(chrome.wants_face_pick(), "wants_face_pick")
	end.get_popup().index_pressed.emit(0)
	await process_frame
	check(chrome.up_to_face_id == "", "leaving Up To Surface keeps the id empty")
	check(not chrome.wants_face_pick(), "leaving Up To Surface disarms the pick")
	check(btn != null and not btn.disabled, "Extrude enabled on Blind")
	end.get_popup().index_pressed.emit(3)
	await process_frame
	check(chrome.wants_face_pick(), "reselect arms the pick again")
	chrome.show_for_session(true)
	await process_frame
	check(chrome.up_to_face_id == "", "session start clears the face id")
	check(not chrome.wants_face_pick(), "session start disarms the pick")
	check(_face_text(chrome).contains("Face: none"), "session start shows Face: none")


func _face_text(chrome: SketchContextChrome) -> String:
	var label: Label = chrome.find_child("UpToFaceLabel", true, false)
	if label == null:
		return ""
	return str(label.text)


func test_dim_typing(main) -> void:
	print("- dim blank select-all and parse")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dim: SpinBox = chrome.find_child("DimSpin", true, false)
	check(dim != null, "DimSpin exists")
	if dim == null:
		return
	var edit := dim.get_line_edit()
	var submitted: Array = []
	var rejected: Array = []
	chrome.dim_submitted.connect(func(v: float) -> void: submitted.append(v))
	chrome.dim_rejected.connect(func(raw: String) -> void: rejected.append(raw))
	await _click(edit)
	await _click(edit)
	check(edit.has_focus(), "second click leaves the dim blank focused")
	var sel := edit.get_selected_text()
	check(sel == edit.text and sel != "",
			"second click selects all (sel '%s' text '%s')" % [sel, edit.text])
	await _type(edit, "22.5")
	await _key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	check(submitted.size() == 1 and is_equal_approx(float(submitted[0]), 22.5),
			"22.5 commits (%s)" % str(submitted))
	check(is_equal_approx(chrome.dim_value(), 22.5), "dim value is 22.5")
	check(rejected.is_empty(), "22.5 does not reject")
	await _click(edit)
	await _click(edit)
	await _type(edit, "23.22.5")
	await _key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	check(rejected.size() == 1 and str(rejected[0]).contains("23.22.5"),
			"23.22.5 emits dim_rejected (%s)" % str(rejected))
	check(submitted.size() == 1, "23.22.5 does not emit dim_submitted")
	check(is_equal_approx(chrome.dim_value(), 22.5), "rejected text leaves the previous value")


func test_across_flats_suffix(main) -> void:
	print("- polygon across flats shows AF")
	var chrome: SketchContextChrome = main.sketch_chrome
	chrome.release_dim_focus()
	var sm: SketchMode = main.sketch_mode
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.set_tool_variant("across_flats")
	await process_frame
	await process_frame
	var dim: SpinBox = chrome.find_child("DimSpin", true, false)
	check(dim != null, "dim spin still present")
	if dim == null:
		return
	check(str(dim.suffix).contains("AF"), "suffix contains AF (%s)" % dim.suffix)
	var edit := dim.get_line_edit()
	check(edit.text.contains("AF"), "wider dim field shows AF (%s)" % edit.text)
	check(edit.size.x >= UiScale.px(110) - 0.5,
			"dim LineEdit width %.1f" % edit.size.x)


func _click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var hover := InputEventMouseMotion.new()
	hover.position = pos
	hover.global_position = pos
	vp.push_input(hover)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _type(edit: LineEdit, text: String) -> void:
	var vp := edit.get_viewport()
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = ch as Key
		elif ch == 46:
			code = KEY_PERIOD
		await _key(vp, code, ch)


func _key(vp: Viewport, code: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = code
	rel.physical_keycode = code
	rel.unicode = 0
	rel.pressed = false
	vp.push_input(rel)
	await process_frame
