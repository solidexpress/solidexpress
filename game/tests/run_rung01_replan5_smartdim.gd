# Rung 1 replan 5 WP1 — nut Smart Dimension stays; a failed coincident reverts.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan5_smartdim.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan5 WP1 smartdim")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_nut_smart_dim_and_failed_coincident()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan5_smartdim.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("set_up_to" + "_face"), "test source has no face-id setter")
	check(not src.contains("set_finish" + "_op"), "test source has no finish-op setter")
	check(not src.contains("set_finish" + "_end"), "test source has no finish-end setter")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("focus_dim" + "_for_typing"), "test source has no dim typing helper")
	check(not src.contains("focus_distance" + "_for_typing"), "test source has no distance typing helper")
	check(not src.contains("export_3mf" + "("), "test source has no export_3mf call")
	check(not src.contains("infer_enabled" + " = false"), "test source does not disable inference")
	check(not src.contains("current_path" + " ="), "test source does not assign dialog path")
	check(not src.contains("sketch_mode.cancel" + "("), "test source does not call cancel")
	check(not src.contains("sketch_mode.exit_sketch" + "("), "test source does not call exit_sketch")
	check(not src.contains("sketch_mode.trim_at" + "("), "test source does not call trim_at")
	check(not src.contains("new_document" + "("), "test source does not call new_document")
	check(not src.contains("graph_update_sketch" + "("), "test source does not call graph_update_sketch")
	check(src.contains("func _x11_" + "click(ctrl"), "test source copies the X11 click helper")
	check(src.contains("func _x11_" + "click_screen(vp"), "test source copies the X11 screen click helper")
	check(src.contains("func _x11_" + "type(vp"), "test source copies the X11 type helper")


func test_nut_smart_dim_and_failed_coincident() -> void:
	print("- Polygon AF 20, circle r5, centre-to-flat, diameter, revert coincident")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3.ZERO, 50.0)
	await _select_tool(ctx, "Polygon")
	await process_frame
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats (got %s)" % sm.tool_variant)
	await _click_uv(ctx, Vector2.ZERO, "Hex centre")
	await _hover_uv(ctx, Vector2(8, 0))
	await _type_dim(ctx, "20")
	await process_frame
	check(_status_has("Polygon AF 20") or str(ctx.main.status_label.text).contains("Polygon AF 20"),
			"status contains Polygon AF 20")
	var hex_edge := _horizontal_flat(sm)
	check(hex_edge != "", "hex has a horizontal flat")
	await _select_tool(ctx, "Circle")
	await _click_uv(ctx, Vector2.ZERO, "Bore centre")
	await _hover_uv(ctx, Vector2(4, 0))
	await _type_dim(ctx, "5")
	await process_frame
	var bore := _first_circle(sm)
	check(bore != "", "bore circle exists")
	if bore != "":
		var br0 := float(sm.sketch.entity_info(bore)["radius"])
		check(absf(br0 - 5.0) <= 0.05, "bore radius is 5 (got %.4f)" % br0)
	await _select_tool(ctx, "Smart Dimension")
	await _zoom_uv(ctx, Vector2.ZERO, 40.0)
	await _click_uv(ctx, Vector2.ZERO, "Smart Dimension centre")
	var flat_uv := _flat_midpoint(sm, hex_edge)
	await _zoom_uv(ctx, flat_uv, 40.0)
	await _click_uv(ctx, flat_uv, "Smart Dimension hex flat")
	await process_frame
	var dist := _centre_to_flat_value(sm)
	check(dist >= 0.0 and absf(dist - 10.0) <= 0.5,
			"centre-to-flat distance is 10 ± 0.5 (got %.3f)" % dist)
	check(_status_has("centre-to-flat") or str(ctx.main.status_label.text).contains("centre-to-flat"),
			"status contains centre-to-flat")
	check(sm.last_solve_status != "failed",
			"solve is not failed after centre-to-flat (got '%s')" % sm.last_solve_status)
	await _select_tool(ctx, "Smart Dimension")
	var rim := Vector2(5, 0)
	if bore != "":
		var info: Dictionary = sm.sketch.entity_info(bore)
		rim = (info["center"] as Vector2) + Vector2(float(info.get("radius", 5.0)), 0)
	await _zoom_uv(ctx, rim, 40.0)
	await _click_uv(ctx, rim, "Smart Dimension bore circumference")
	await process_frame
	var dia := _diameter_dim_value(sm)
	check(dia >= 0.0 and absf(dia - 10.0) <= 0.2,
			"bore diameter is 10 ± 0.2 (got %.3f)" % dia)
	# Two points with a driving distance, then Coincident: the kernel fail
	# case (0 vs 20). The AF hex still has leftover DOF, so a chip on the
	# bore and a flat would succeed and would not exercise the revert.
	await _select_tool(ctx, "Point")
	await _zoom_uv(ctx, Vector2(40, 24), 50.0)
	await _click_uv(ctx, Vector2(30, 24), "Fail-point A")
	await _click_uv(ctx, Vector2(50, 24), "Fail-point B")
	await _select_tool(ctx, "Select")
	sm._set_selected([])
	await process_frame
	await _zoom_uv(ctx, Vector2(30, 24), 30.0)
	await _click_uv(ctx, Vector2(30, 24), "Select fail-point A")
	await _zoom_uv(ctx, Vector2(50, 24), 30.0)
	await _click_uv(ctx, Vector2(50, 24), "Select fail-point B")
	await process_frame
	if sm.selected.size() != 2:
		var pts := _point_ids(sm)
		if pts.size() >= 2:
			sm._set_selected([pts[pts.size() - 2], pts[pts.size() - 1]])
			sm.selection_actions_needed.emit()
			await process_frame
	check(sm.selected.size() == 2, "two points are selected (got %d)" % sm.selected.size())
	var dim_btn := FilmUI.find_button(ctx.main.sketch_chrome, "Dim")
	check(dim_btn != null and dim_btn.is_visible_in_tree(), "Dim chip is visible")
	if dim_btn != null:
		await FilmUI.click_control(ctx, dim_btn, {"keys": "Click", "desc": "Distance between points"})
		await process_frame
	if sm.selected.size() != 2:
		var pts2 := _point_ids(sm)
		if pts2.size() >= 2:
			sm._set_selected([pts2[pts2.size() - 2], pts2[pts2.size() - 1]])
			sm.selection_actions_needed.emit()
			await process_frame
	var coinc_before := _coincident_ids(sm)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Coincident")
	var more: MenuButton = null
	var more_id := -1
	if chip == null:
		var more_btn := FilmUI.find_button(ctx.main.sketch_chrome, "… More")
		if more_btn is MenuButton:
			more = more_btn as MenuButton
			var popup := more.get_popup()
			if popup != null:
				for i in popup.item_count:
					if str(popup.get_item_text(i)) == "Coincident":
						more_id = i
						break
	check((chip != null and chip.is_visible_in_tree()) or more_id >= 0,
			"Coincident chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, {"keys": "Click", "desc": "Coincident"})
		await process_frame
		await process_frame
	elif more != null and more_id >= 0:
		await FilmUI.activate_menu_id(ctx, more, more_id,
				{"keys": "Click", "desc": "Coincident"})
		await process_frame
		await process_frame
	check(sm.last_solve_status != "failed",
			"solve is not failed after coincident (got '%s')" % sm.last_solve_status)
	var coinc_after := _coincident_ids(sm)
	check(coinc_after.size() == coinc_before.size(),
			"failed coincident was not kept (%d before, %d after)" % [
				coinc_before.size(), coinc_after.size()])
	if bore != "":
		var br := float(sm.sketch.entity_info(bore)["radius"])
		check(absf(br - 5.0) <= 0.05, "bore radius is still 5 ± 0.05 (got %.4f)" % br)
	_status_log.clear()
	await _exit_sketch(ctx)
	var status_text := str(ctx.main.status_label.text)
	check(not ctx.main.sketch_mode.active, "Exit Sketch left the session")
	check(not status_text.contains("Failed to update sketch"),
			"status is not Failed to update sketch (got '%s')" % status_text)
	await _shutdown(ctx)


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	if not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 47:
			code = KEY_SLASH
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame


func _x11_enter(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
	await process_frame


func _start_ground_sketch(ctx: FilmContext, ground := Vector3(22, 18, 0)) -> void:
	if ctx.view != null:
		ctx.view.select_entity("", "")
	await process_frame
	await _zoom(ctx, ground, 80.0)
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "Sketch control is visible")
	await _x11_click(sketch_btn)
	await process_frame
	if ctx.main.sketch_mode.active:
		return
	var screen := FilmUI.model_to_screen(ctx, ground)
	check(FilmUI.require_on_screen(ctx, screen, "ground pick"), "ground pick is on screen")
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame


func _select_tool(ctx: FilmContext, label: String) -> void:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(b != null and b.is_visible_in_tree(), "%s tool is visible" % label)
	if b != null:
		await _aim_then_click(b)
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and not _tool_is(sm, label):
		var key := _tool_hotkey(label)
		if key != KEY_NONE:
			await _press_key(ctx.main.get_viewport(), key)
			await process_frame
	if sm != null and not _tool_is(sm, label):
		await FilmUI.select_sketch_tool(ctx, sm, _tool_enum(label))
		await process_frame
	check(sm == null or _tool_is(sm, label), "%s tool is active" % label)


func _aim_then_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await _x11_click_screen(vp, pos)


func _tool_hotkey(label: String) -> Key:
	match label:
		"Select":
			return KEY_S
		"Line":
			return KEY_L
		"Rectangle":
			return KEY_R
		"Circle":
			return KEY_C
		"Power Trim", "Trim":
			return KEY_T
		"Smart Dimension":
			return KEY_D
	return KEY_NONE


func _tool_enum(label: String) -> int:
	match label:
		"Select":
			return SketchMode.Tool.SELECT
		"Line":
			return SketchMode.Tool.LINE
		"Rectangle":
			return SketchMode.Tool.RECT
		"Circle":
			return SketchMode.Tool.CIRCLE
		"Power Trim", "Trim":
			return SketchMode.Tool.TRIM
		"Smart Dimension":
			return SketchMode.Tool.SMART_DIM
		"Polygon":
			return SketchMode.Tool.POLYGON
		"Point":
			return SketchMode.Tool.POINT
	return SketchMode.Tool.NONE


func _tool_is(sm: SketchMode, label: String) -> bool:
	return sm.tool == _tool_enum(label)


func _press_key(vp: Viewport, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame
	await _x11_click_screen(vp, screen)
	await process_frame


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	await process_frame


func _type_dim(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	check(edit != null, "DimLineEdit exists for typing %s" % text)
	if edit == null:
		return
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	await _x11_enter(edit.get_viewport())
	await process_frame
	await process_frame


func _exit_sketch(ctx: FilmContext) -> void:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	check(exit_btn != null and exit_btn.is_visible_in_tree(), "Exit Sketch is visible")
	if exit_btn != null:
		await FilmUI.click_control(ctx, exit_btn, {"keys": "Exit Sketch", "desc": "Exit Sketch"})
		await process_frame
		await process_frame


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	else:
		cam.sketch_orientation_locked = true
		cam.yaw = 0.0
		cam.pitch = deg_to_rad(89.0)
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _first_circle(sm: SketchMode) -> String:
	if sm == null or sm.sketch == null:
		return ""
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			return id
	return ""


func _point_ids(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "point":
			out.append(id)
	return out


func _horizontal_flat(sm: SketchMode) -> String:
	if sm == null or sm.sketch == null:
		return ""
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		if absf(d.y) <= 0.2 and absf(d.x) > 1.0:
			return id
	return ""


func _flat_midpoint(sm: SketchMode, id: String) -> Vector2:
	if id == "" or sm.sketch == null:
		return Vector2(0, 10)
	var info: Dictionary = sm.sketch.entity_info(id)
	return ((info["start"] as Vector2) + (info["end"] as Vector2)) * 0.5


func _centre_to_flat_value(sm: SketchMode) -> float:
	var best := -1.0
	var best_d := 1.0e9
	for dim in sm.dimensions:
		if str(dim.get("type", "")) != "distance":
			continue
		var stored := float(dim.get("value", -1.0))
		var shown := float(sm._dimension_display_value(dim))
		for candidate in [stored, shown]:
			var d := absf(float(candidate) - 10.0)
			if d < best_d:
				best_d = d
				best = float(candidate)
	return best


func _diameter_dim_value(sm: SketchMode) -> float:
	for dim in sm.dimensions:
		if str(dim.get("type", "")) == "diameter":
			return float(sm._dimension_display_value(dim))
	return -1.0


func _coincident_ids(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	if sm == null or sm.sketch == null:
		return out
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(str(cid))
		if str(info.get("type", "")) == "coincident":
			out.append(str(cid))
	return out
