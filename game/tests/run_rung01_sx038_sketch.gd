# sx-038 — one lit sketch-rail button, and no stray point marker after Smart Dim.
# Real events: Viewport.push_input (motion, press, release, keys). 1280×800.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script res://tests/run_rung01_sx038_sketch.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const ARMED_FILL_MIX := 0.32
const RIGHT_CENTRE := Vector2(50.0, 0.0)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 sx038 rail highlight and Smart Dim marker")
	FilmUI.reset_fail_count()
	await test_one_lit_rail_button()
	await test_smart_dim_centres_leave_no_marker()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_one_lit_rail_button() -> void:
	print("- rail presses then keys: exactly one lit tool button")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	var rail_order: Array[String] = ["Jaw", "Line", "Smart Dim", "Trim", "Slot", "Circle", "Select"]
	var prev: Button = null
	for label in rail_order:
		var btn := await _click_rail(ctx, label)
		check(btn != null, "rail press hit %s" % label)
		await process_frame
		await process_frame
		_assert_tool(sm, label)
		var armed := _armed_button(ctx.main, sm)
		check(armed != null and armed == btn, "%s is the armed rail button" % label)
		await _assert_one_lit(ctx.main, armed, "%s rail press" % label)
		if prev != null and prev != armed:
			await _hover_control(prev)
			check(not _button_lit(prev), "hover on the previous button is not lit after %s" % label)
			await _assert_one_lit(ctx.main, armed, "%s with previous hovered" % label)
		prev = armed
	var keys: Array = [
		[KEY_L, "Line"],
		[KEY_D, "Smart Dim"],
		[KEY_T, "Trim"],
		[KEY_C, "Circle"],
		[KEY_S, "Select"],
	]
	for pair in keys:
		var key: Key = pair[0]
		var label: String = pair[1]
		await _press_key(ctx.main.get_viewport(), key)
		await process_frame
		_assert_tool(sm, label)
		var armed := _armed_button(ctx.main, sm)
		check(armed != null, "key %s arms a rail button" % label)
		await _assert_one_lit(ctx.main, armed, "key %s" % label)
		if prev != null and prev != armed:
			await _hover_control(prev)
			check(not _button_lit(prev), "hover on the previous button is not lit after key %s" % label)
			await _assert_one_lit(ctx.main, armed, "key %s with previous hovered" % label)
		prev = armed
	await _shutdown(ctx)


func test_smart_dim_centres_leave_no_marker() -> void:
	print("- two circles, Smart Dim 200, no stray point marker")
	var ctx := await _boot()
	await _start_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open for Smart Dim")
	await _zoom(ctx, Vector3.ZERO, 160.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10")
	await _zoom_uv(ctx, RIGHT_CENTRE, 80.0)
	await _draw_circle_typed(ctx, RIGHT_CENTRE, "22.5")
	var circs := _circle_infos(sm)
	check(circs.size() == 2, "two circles exist (got %d)" % circs.size())
	if circs.size() != 2:
		await _shutdown(ctx)
		return
	var c0: Vector2 = circs[0]["center"]
	var c1: Vector2 = circs[1]["center"]
	check(c0.length() <= 0.5, "first circle centre is the origin (got %s)" % str(c0))
	check(absf(float(circs[0]["radius"]) - 10.0) <= 0.05, "first radius is 10")
	check(absf(float(circs[1]["radius"]) - 22.5) <= 0.05, "second radius is 22.5")
	check(c1.x > c0.x + 10.0, "second circle is to the right")
	var entities_before := _entity_count(sm)
	var points_before := _point_count(sm)
	await _click_rail(ctx, "Smart Dim")
	await process_frame
	check(sm.tool == SketchMode.Tool.SMART_DIM, "Smart Dim is armed from the rail")
	await _zoom_uv(ctx, c0, 40.0)
	_status_log.clear()
	await _click_uv(ctx, c0, "Smart Dim first centre")
	await process_frame
	var first_status := _joined_status(ctx)
	check(first_status.contains("Smart Dim: first pick set"),
			"first centre pick says so (got `%s`)" % first_status)
	await _zoom_uv(ctx, c1, 40.0)
	await _click_uv(ctx, c1, "Smart Dim second centre")
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"dimension popup is visible after the second centre click")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible or ix._dim_edit_line == null:
		await _shutdown(ctx)
		return
	_status_log.clear()
	await _x11_click(ix._dim_edit_line)
	await _x11_type(ix._dim_edit_line.get_viewport(), "200")
	await _x11_enter(ix._dim_edit_line.get_viewport())
	await process_frame
	await process_frame
	await process_frame
	var after := _joined_status(ctx)
	check(after.contains("Dimension updated"), "typing 200 commits (got `%s`)" % after)
	check(_entity_count(sm) == entities_before,
			"Smart Dim adds no sketch entity (%d was %d)" % [_entity_count(sm), entities_before])
	check(_point_count(sm) == points_before,
			"Smart Dim adds no sketch point (%d was %d)" % [_point_count(sm), points_before])
	circs = _circle_infos(sm)
	if circs.size() >= 2:
		var a: Vector2 = circs[0]["center"]
		var b: Vector2 = circs[1]["center"]
		var gap := a.distance_to(b)
		check(absf(gap - 200.0) <= 0.2, "centre distance is 200 ± 0.2 (got %.3f)" % gap)
		check(absf(a.y - b.y) <= 0.05, "centres stay level (dy %.4f)" % absf(a.y - b.y))
		check(a.length() <= 1.0, "origin circle stays at the origin (got %s)" % str(a))
	_assert_no_pick_marker(sm, "after Dimension updated")
	_assert_no_stray_glyph(sm, c0)
	await _zoom_uv(ctx, c0, 40.0)
	await _hover_uv(ctx, c0)
	await process_frame
	_assert_no_pick_marker(sm, "hovering the first centre after the dimension")
	await _shutdown(ctx)


func _assert_tool(sm: SketchMode, label: String) -> void:
	match label:
		"Jaw":
			check(sm.tool == SketchMode.Tool.RECT and sm.is_jaw_armed(),
					"Jaw arms centre-three-point rect (tool %d jaw %s)" % [int(sm.tool), str(sm.is_jaw_armed())])
		"Line":
			check(sm.tool == SketchMode.Tool.LINE, "Line is armed")
		"Smart Dim":
			check(sm.tool == SketchMode.Tool.SMART_DIM, "Smart Dim is armed")
		"Trim":
			check(sm.tool == SketchMode.Tool.TRIM, "Trim is armed")
		"Slot":
			check(sm.tool == SketchMode.Tool.SLOT, "Slot is armed")
		"Circle":
			check(sm.tool == SketchMode.Tool.CIRCLE, "Circle is armed")
		"Select":
			check(sm.tool == SketchMode.Tool.SELECT, "Select is armed")
		_:
			check(false, "unknown tool %s" % label)


func _assert_one_lit(main, armed: Button, what: String) -> void:
	var lit: Array[Button] = []
	for b in _rail_tool_buttons(main):
		if _button_lit(b):
			lit.append(b)
	var names: PackedStringArray = PackedStringArray()
	for b in lit:
		names.append(b.name)
	check(lit.size() == 1, "%s lights exactly one rail button (got %d: %s)" % [what, lit.size(), ", ".join(names)])
	if armed != null:
		check(lit.size() == 1 and lit[0] == armed, "%s lights %s" % [what, armed.name])


func _button_lit(b: Button) -> bool:
	if b == null or not is_instance_valid(b):
		return false
	if b.button_pressed:
		return true
	var bar := b.get_node_or_null("RailAccentBar") as ColorRect
	if bar != null and bar.visible:
		return true
	var mode := b.get_draw_mode()
	if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED:
		return true
	var box := _draw_style(b, mode)
	if _style_armed(box):
		return true
	if mode == BaseButton.DRAW_HOVER and box is StyleBoxFlat:
		var accent := _accent()
		var armed_fill := accent.lerp(Color(0.08, 0.11, 0.16, 1.0), ARMED_FILL_MIX)
		armed_fill.a = 1.0
		var fill := (box as StyleBoxFlat).bg_color
		if absf(fill.r - armed_fill.r) < 0.08 and absf(fill.g - armed_fill.g) < 0.08 \
				and absf(fill.b - armed_fill.b) < 0.08:
			return true
	return false


func _accent() -> Color:
	return Color.html("#6ab0f3")


func _draw_style(b: Button, mode: BaseButton.DrawMode) -> StyleBox:
	var key := "normal"
	match mode:
		BaseButton.DRAW_PRESSED:
			key = "pressed"
		BaseButton.DRAW_HOVER:
			key = "hover"
		BaseButton.DRAW_HOVER_PRESSED:
			key = "hover_pressed"
		BaseButton.DRAW_DISABLED:
			key = "disabled"
	return b.get_theme_stylebox(key)


func _style_armed(box: StyleBox) -> bool:
	if not (box is StyleBoxFlat):
		return false
	var flat := box as StyleBoxFlat
	if flat.get_border_width(SIDE_LEFT) < 3:
		return false
	var accent := _accent()
	var c := flat.border_color
	return absf(c.r - accent.r) <= 0.05 and absf(c.g - accent.g) <= 0.05 \
			and absf(c.b - accent.b) <= 0.05 and c.a >= 0.85


func _rail_tool_buttons(main) -> Array[Button]:
	var out: Array[Button] = []
	if main.sketch_toolbar == null:
		return out
	for c in main.sketch_toolbar.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.toggle_mode:
			continue
		if b.name == "JawTool" or b.has_meta("sx_tool"):
			out.append(b)
	return out


func _armed_button(main, sm: SketchMode) -> Button:
	if sm.is_jaw_armed():
		return main.sketch_toolbar.find_child("JawTool", true, false) as Button
	var tool := int(sm.tool)
	for b in _rail_tool_buttons(main):
		if int(b.get_meta("sx_tool", -999)) == tool:
			return b
	return null


func _assert_no_pick_marker(sm: SketchMode, what: String) -> void:
	var marker := sm.get_node_or_null("PickMarker") as MeshInstance3D
	var visible := marker != null and marker.visible and marker.is_visible_in_tree()
	var has_mesh := marker != null and marker.mesh != null
	check(marker != null and not visible and not has_mesh,
			"PickMarker is hidden with no mesh %s" % what)


func _assert_no_stray_glyph(sm: SketchMode, origin: Vector2) -> void:
	var glyphs := sm.get_node_or_null("ConstraintGlyphs")
	var stray := 0
	if glyphs != null:
		var want := sm.to_global(sm.to_model(origin))
		for c in glyphs.get_children():
			var label := c as Label3D
			if label == null:
				continue
			var near := label.global_position.distance_to(want) <= 15.0
			if label.text == "◉" or (near and (label.text == "H" or label.text == "◉")):
				stray += 1
				print("  stray glyph `%s` at %s" % [label.text, str(label.global_position)])
	check(stray == 0, "no coincident or horizontal badge inside the origin circle")


func _entity_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return -1
	return sm.sketch.entity_ids().size()


func _point_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return -1
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "point":
			n += 1
	return n


func _circle_infos(sm: SketchMode) -> Array:
	var out: Array = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	out.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	return out


func _joined_status(ctx: FilmContext) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if ctx.main.status_label != null:
		parts.append(str(ctx.main.status_label.text))
	for line in _status_log:
		parts.append(line)
	return " | ".join(parts)


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
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
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


func _rail_scroll(rail: Control) -> ScrollContainer:
	if rail == null:
		return null
	var named := rail.find_child("SketchRailScroll", true, false)
	if named is ScrollContainer:
		return named
	return null


func _scroll_btn_to_band(scroll: ScrollContainer, btn: Control, want_y: float) -> void:
	if scroll == null or btn == null:
		return
	scroll.ensure_control_visible(btn)
	await process_frame
	await process_frame
	var c: Vector2 = btn.get_global_rect().get_center()
	scroll.scroll_vertical = maxi(0, scroll.scroll_vertical + int(c.y - want_y))
	await process_frame
	await process_frame


func _btn_center_visible(btn: Control, scroll: ScrollContainer) -> Vector2:
	if btn == null:
		return Vector2.INF
	var c := btn.get_global_rect().get_center()
	if scroll == null:
		return c
	var sr: Rect2 = scroll.get_global_rect()
	var inner := sr.grow_individual(0.0, -6.0, 0.0, -6.0)
	if inner.has_point(c):
		return c
	return Vector2.INF


func _click_rail(ctx: FilmContext, label: String) -> Button:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null and btn.is_visible_in_tree(), "%s is on the sketch rail" % label)
	if btn == null:
		return null
	var scroll := _rail_scroll(ctx.main.sketch_toolbar)
	var pos := _btn_center_visible(btn, scroll)
	if pos == Vector2.INF or pos.y < 80.0 or pos.y > 740.0:
		await _scroll_btn_to_band(scroll, btn, 360.0)
		pos = _btn_center_visible(btn, scroll)
	if pos == Vector2.INF:
		check(false, "%s rail button is inside the rail viewport" % label)
		return null
	await _x11_click_screen(ctx.main.get_viewport(), pos)
	await process_frame
	return btn


func _hover_control(btn: Control) -> void:
	if btn == null:
		return
	var scroll: ScrollContainer = null
	var rail := btn.get_parent()
	while rail != null and scroll == null:
		if rail is ScrollContainer:
			scroll = rail
		rail = rail.get_parent()
	var pos := _btn_center_visible(btn, scroll)
	if pos == Vector2.INF:
		await _scroll_btn_to_band(scroll, btn, 360.0)
		pos = _btn_center_visible(btn, scroll)
	if pos == Vector2.INF:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	btn.get_viewport().push_input(motion)
	await process_frame
	await process_frame


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	await _click_rail(ctx, "Circle")
	await process_frame
	await _click_uv(ctx, center, "Circle centre")
	await _hover_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text)


func _type_dim(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	check(edit != null and edit.is_visible_in_tree(), "DimLineEdit is visible for typing %s" % text)
	if edit == null:
		return
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	await _x11_enter(edit.get_viewport())
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		return
	await _x11_click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


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
		elif ch == 46:
			code = KEY_PERIOD
		else:
			push_error("no key for U+%X" % ch)
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
	vp.push_input(rel)
	await process_frame


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
