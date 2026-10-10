# Rung 1 replan 14 WP6 — Jaw lights its own rail button and shows no Rect chips;
# Circle's centre click says so; Slot c-c label regression (#151).
# Real events: Viewport.push_input (motion, press, release). 1280×800.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_railstatus.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const CIRCLE_CENTRE_SET := "Circle — centre set, click the rim or type a radius"
const CIRCLE_ARM := "Circle — click the centre, then the rim (or type a radius)"
## SolidWorks rectangle flyout, left to right. Corner is the default.
const RECT_CHIP_ORDER: Array[String] = [
	"Corner", "Center", "Three Point", "Center Three Point", "Parallelogram",
]



func _init() -> void:
	print("rung01 replan14 WP6 Jaw rail highlight, Circle centre status, Slot c-c")
	FilmUI.reset_fail_count()
	await _run()
	finish()


func _status_of(main) -> String:
	if main.status_label != null:
		return str(main.status_label.text)
	return ""


func _jaw_armed(sm: SketchMode) -> bool:
	return sm.has_method("is_jaw_armed") and sm.is_jaw_armed()


func _rail_scroll(rail: Control) -> ScrollContainer:
	if rail == null:
		return null
	var named := rail.find_child("SketchRailScroll", true, false)
	if named is ScrollContainer:
		return named
	for c in rail.find_children("*", "ScrollContainer", true, false):
		return c as ScrollContainer
	return null


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


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
	var br: Rect2 = btn.get_global_rect()
	var c := br.get_center()
	if scroll == null:
		return c
	var sr: Rect2 = scroll.get_global_rect()
	var inner := sr.grow_individual(0.0, -6.0, 0.0, -6.0)
	if inner.has_point(c):
		return c
	return Vector2.INF


func _click_control(main, btn: Control) -> Vector2:
	if btn == null or not btn.is_visible_in_tree():
		return Vector2.INF
	var scroll := _rail_scroll(main.sketch_toolbar)
	var pos := _btn_center_visible(btn, scroll)
	if pos == Vector2.INF or pos.y < 160.0 or pos.y > 520.0:
		await _scroll_btn_to_band(scroll, btn, 300.0)
		pos = _btn_center_visible(btn, scroll)
	if pos == Vector2.INF:
		return Vector2.INF
	await _push_click(pos)
	return pos


func _click_rail_label(main, label: String) -> Button:
	var btn := FilmUI.find_sketch_tool_button(main, label)
	if btn == null:
		return null
	var pos: Vector2 = await _click_control(main, btn)
	if pos == Vector2.INF:
		return null
	return btn


func _variant_bar(main) -> Control:
	if main.sketch_chrome == null:
		return null
	return main.sketch_chrome.find_child("VariantBar", true, false) as Control


func _visible_chip_labels(main) -> Array[String]:
	var out: Array[String] = []
	var bar := _variant_bar(main)
	if bar == null or not bar.visible:
		return out
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.is_visible_in_tree():
			out.append(b.text)
	return out


func _pressed_chip_labels(main) -> Array[String]:
	var out: Array[String] = []
	var bar := _variant_bar(main)
	if bar == null or not bar.visible:
		return out
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.is_visible_in_tree() and b.button_pressed:
			out.append(b.text)
	return out


func _find_visible_chip(main, text: String) -> Button:
	var bar := _variant_bar(main)
	if bar == null or not bar.visible:
		return null
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.is_visible_in_tree() and b.text == text:
			return b
	return null


func _click_chip(main, text: String) -> Button:
	var chip := _find_visible_chip(main, text)
	if chip == null:
		return null
	await _push_click(chip.get_global_rect().get_center())
	return chip


func _print_row(n: int, main, sm: SketchMode) -> void:
	var rect_btn := FilmUI.find_sketch_tool_button(main, "Rect")
	var jaw_btn := FilmUI.find_sketch_tool_button(main, "Jaw")
	print("  ROW %d  ToolRect.pressed=%s JawTool.pressed=%s tool=%s variant=%s jaw_armed=%s chips=%s status=`%s`" % [
			n,
			str(rect_btn.button_pressed) if rect_btn != null else "missing",
			str(jaw_btn.button_pressed) if jaw_btn != null else "missing",
			str(sm.tool), sm.tool_variant, str(_jaw_armed(sm)),
			str(_visible_chip_labels(main)), _status_of(main)])


func _type_into_dim(main, text: String) -> void:
	# Same DimLineEdit / spin LineEdit lookup as run_rung01_replan12_slotarm.gd.
	var chrome: SketchContextChrome = main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	if edit == null:
		return
	var pos := edit.get_global_rect().get_center()
	await _push_click(pos)
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		else:
			continue
		for pressed in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = code
			ev.unicode = ch
			ev.pressed = pressed
			root.push_input(ev)
			await process_frame
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	await process_frame
	enter = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = false
	root.push_input(enter)
	await process_frame
	await process_frame


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _run() -> void:
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

	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "blank sketch is active")
	var rect_btn := FilmUI.find_sketch_tool_button(main, "Rect")
	var jaw_btn := FilmUI.find_sketch_tool_button(main, "Jaw")
	check(rect_btn != null and rect_btn.name == "ToolRect", "Rect rail button is ToolRect")
	check(jaw_btn != null and jaw_btn.name == "JawTool", "Jaw rail button is JawTool")

	# 1. Press Rect: Rect lit, Jaw not, five Rect chips.
	rect_btn = await _click_rail_label(main, "Rect")
	await process_frame
	_print_row(1, main, sm)
	check(rect_btn != null and rect_btn.button_pressed, "row 1: ToolRect is pressed")
	check(jaw_btn != null and not jaw_btn.button_pressed, "row 1: JawTool is not pressed")
	var rect_chips := _visible_chip_labels(main)
	print("  ROW 1 chip labels: %s" % str(rect_chips))
	check(rect_chips == RECT_CHIP_ORDER,
			"row 1: Rect chips are Corner, Center, Three Point, Center Three Point, Parallelogram (got %s)" % str(rect_chips))
	check(_pressed_chip_labels(main) == ["Corner"],
			"row 1: Corner is the highlighted chip (got %s)" % str(_pressed_chip_labels(main)))

	# 2. Press Jaw: Jaw lit, Rect not, variant center_three_point, JAW_HINT, no chips.
	jaw_btn = await _click_rail_label(main, "Jaw")
	await process_frame
	_print_row(2, main, sm)
	check(jaw_btn != null and jaw_btn.button_pressed, "row 2: JawTool is pressed")
	check(rect_btn != null and not rect_btn.button_pressed, "row 2: ToolRect is not pressed")
	check(sm.tool == SketchMode.Tool.RECT, "row 2: tool is RECT")
	check(sm.tool_variant == "center_three_point",
			"row 2: tool_variant is center_three_point (got %s)" % sm.tool_variant)
	check(_jaw_armed(sm), "row 2: is_jaw_armed()")
	check(_status_of(main) == SketchMode.JAW_HINT,
			"row 2: status is JAW_HINT (got `%s`)" % _status_of(main))
	var jaw_chips := _visible_chip_labels(main)
	print("  ROW 2 chip labels: %s" % str(jaw_chips))
	check(jaw_chips.is_empty(), "row 2: Jaw chip row is hidden/empty (got %s)" % str(jaw_chips))

	# 3. Click the lit Jaw again: stays pressed and armed.
	jaw_btn = await _click_rail_label(main, "Jaw")
	await process_frame
	_print_row(3, main, sm)
	check(jaw_btn != null and jaw_btn.button_pressed, "row 3: JawTool stays pressed")
	check(_jaw_armed(sm), "row 3: still is_jaw_armed()")
	check(rect_btn != null and not rect_btn.button_pressed, "row 3: ToolRect still not pressed")

	# 4. Press Rect: Rect lit, Jaw not, chips back. Center Three Point chip is not Jaw.
	rect_btn = await _click_rail_label(main, "Rect")
	await process_frame
	_print_row(4, main, sm)
	check(rect_btn != null and rect_btn.button_pressed, "row 4: ToolRect is pressed")
	check(jaw_btn != null and not jaw_btn.button_pressed, "row 4: JawTool is not pressed")
	check(not _jaw_armed(sm), "row 4: is_jaw_armed() is false")
	var chips_back := _visible_chip_labels(main)
	print("  ROW 4 chip labels: %s" % str(chips_back))
	check(chips_back == RECT_CHIP_ORDER,
			"row 4: after Jaw then Rect, chips are Corner, Center, Three Point, Center Three Point, Parallelogram (got %s)" % str(chips_back))
	check(_pressed_chip_labels(main) == ["Corner"],
			"row 4: Corner is highlighted after Rect (got %s)" % str(_pressed_chip_labels(main)))
	var ctp := await _click_chip(main, "Center Three Point")
	await process_frame
	check(ctp != null, "row 4: Center Three Point chip is clickable")
	check(rect_btn.button_pressed, "row 4 after Center Three Point: ToolRect lit")
	check(not jaw_btn.button_pressed, "row 4 after Center Three Point: JawTool not lit")
	check(not _jaw_armed(sm), "row 4: a Rect variant is not Jaw")
	check(sm.tool_variant == "center_three_point",
			"row 4: Rect Center Three Point keeps tool_variant (got %s)" % sm.tool_variant)

	# 5a. Jaw then Line: only Line lit.
	jaw_btn = await _click_rail_label(main, "Jaw")
	await process_frame
	var line_btn := await _click_rail_label(main, "Line")
	await process_frame
	_print_row(5, main, sm)
	check(line_btn != null and line_btn.button_pressed, "row 5: Line is pressed")
	check(jaw_btn != null and not jaw_btn.button_pressed, "row 5: JawTool is not pressed after Line")
	check(rect_btn != null and not rect_btn.button_pressed, "row 5: ToolRect is not pressed after Line")
	var line_chips := _visible_chip_labels(main)
	print("  ROW 5a Line chip labels: %s" % str(line_chips))
	check(line_chips.is_empty() or line_chips.has("Line") or line_chips.has("Centerline"),
			"row 5: chip row is Line's own or hidden (got %s)" % str(line_chips))

	# 5b. Jaw then Rect then Corner chip.
	jaw_btn = await _click_rail_label(main, "Jaw")
	await process_frame
	rect_btn = await _click_rail_label(main, "Rect")
	await process_frame
	var corner := await _click_chip(main, "Corner")
	await process_frame
	print("  ROW 5b chip labels: %s" % str(_visible_chip_labels(main)))
	check(corner != null, "row 5: Corner chip is clickable")
	check(rect_btn != null and rect_btn.button_pressed, "row 5: Rect lit after Corner")
	check(jaw_btn != null and not jaw_btn.button_pressed, "row 5: JawTool not lit after Corner")
	check(not _jaw_armed(sm), "row 5: is_jaw_armed() false after Corner")

	# 6. Circle centre click names the next step.
	var circ := await _click_rail_label(main, "Circle")
	await process_frame
	check(circ != null and circ.button_pressed, "row 6: Circle is pressed")
	check(_status_of(main) == CIRCLE_ARM, "row 6: Circle arm status (got `%s`)" % _status_of(main))
	var before_n: int = sm.sketch.entity_ids().size()
	var c1 := Vector2(ROOT_SIZE.x * 0.55, ROOT_SIZE.y * 0.55)
	var c2 := c1 + Vector2(80.0, 0.0)
	await _push_click(c1)
	await process_frame
	print("  ROW 6 after centre click status=`%s`" % _status_of(main))
	check(_status_of(main) == CIRCLE_CENTRE_SET,
			"row 6: centre click status is CIRCLE_CENTRE_SET (got `%s`)" % _status_of(main))
	await _push_click(c2)
	await process_frame
	print("  ROW 6 after rim click status=`%s` entities %d → %d" % [
			_status_of(main), before_n, sm.sketch.entity_ids().size()])
	check(_status_of(main).begins_with("Circle r="),
			"row 6: second click status starts Circle r= (got `%s`)" % _status_of(main))
	check(sm.sketch.entity_ids().size() == before_n + 1,
			"row 6: second click adds a circle (entities %d → %d)" % [
				before_n, sm.sketch.entity_ids().size()])

	circ = await _click_rail_label(main, "Circle")
	await process_frame
	var peri := await _click_chip(main, "Perimeter")
	await process_frame
	check(peri != null, "row 6: Perimeter chip is clickable")
	var peri_before := _status_of(main)
	await _push_click(c1 + Vector2(0.0, 90.0))
	await process_frame
	print("  ROW 6 Perimeter first-click status=`%s` (arm was `%s`)" % [_status_of(main), peri_before])
	check(_status_of(main) != CIRCLE_CENTRE_SET,
			"row 6: Perimeter first click is not CIRCLE_CENTRE_SET (got `%s`)" % _status_of(main))

	# 7. Item 11 regression: Slot field labelled c-c after the first centre.
	var slot_btn := await _click_rail_label(main, "Slot")
	await process_frame
	check(slot_btn != null and int(sm.tool) == int(SketchMode.Tool.SLOT),
			"row 7: Slot is armed")
	await _type_into_dim(main, "5")
	check(absf(sm.slot_radius - 5.0) < 1e-3,
			"row 7: typed 5 sets slot radius (got %.4f)" % sm.slot_radius)
	var slot_centre := Vector2(ROOT_SIZE.x * 0.62, ROOT_SIZE.y * 0.62)
	await _push_click(slot_centre)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = main.sketch_chrome
	var cc_label: Label = chrome.find_child("RadiusLabel", true, false)
	var cc_text := str(cc_label.text) if cc_label != null else "missing"
	print("  ROW 7 RadiusLabel=`%s` visible=%s" % [
			cc_text, str(cc_label.visible) if cc_label != null else "missing"])
	check(cc_label != null and cc_label.visible and cc_text == "c-c",
			"row 7: after the first centre the dim field is labelled c-c (got `%s`)" % cc_text)
	check(not cc_text.contains("Radius") and not cc_text.contains("r"),
			"row 7: label does not contain Radius or r as a bare cue (got `%s`)" % cc_text)
	await _type_into_dim(main, "150")
	print("  ROW 7 after 150 status=`%s`" % _status_of(main))
	check(_status_of(main).begins_with("Slot c-c 150.0000"),
			"row 7: status starts Slot c-c 150.0000 (got `%s`)" % _status_of(main))

	# 8. Jaw end to end: three real clicks still commit a jaw.
	jaw_btn = await _click_rail_label(main, "Jaw")
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
			"row 8: Jaw is armed for the three-click gesture (tool %d variant %s)" % [
				int(sm.tool), sm.tool_variant])
	var before_lines := _profile_lines(sm)
	var j1 := Vector2(ROOT_SIZE.x * 0.48, ROOT_SIZE.y * 0.48)
	var j2 := j1 + Vector2(110.0, 0.0)
	var j3 := j1 + Vector2(0.0, -90.0)
	await _push_click(j1)
	await process_frame
	await _push_click(j2)
	await process_frame
	await _push_click(j3)
	await process_frame
	print("  ROW 8 after three clicks status=`%s` lines %d → %d JawTool.pressed=%s ToolRect.pressed=%s tool=%s" % [
			_status_of(main), before_lines, _profile_lines(sm),
			str(jaw_btn.button_pressed) if jaw_btn != null else "missing",
			str(rect_btn.button_pressed) if rect_btn != null else "missing",
			str(sm.tool)])
	check(_status_of(main).begins_with("Jaw committed — width "),
			"row 8: click 3 commits with the jaw status (got `%s`)" % _status_of(main))
	check(_profile_lines(sm) == before_lines + 4,
			"row 8: committed jaw has four profile lines (got %d, was %d)" % [
				_profile_lines(sm), before_lines])
	if sm.tool != SketchMode.Tool.RECT:
		check(rect_btn != null and not rect_btn.button_pressed,
				"row 8: Rect is not lit while tool is not RECT")

	main.queue_free()
	await process_frame
	await process_frame
