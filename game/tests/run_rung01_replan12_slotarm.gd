# sx-033 A11a — Slot (and every sketch-rail tool) arms from a real viewport click
# at the button's on-screen position. Drive InputEventMouseButton through
# Viewport.push_input; never emit the button's pressed signal.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_slotarm.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

# label on the rail, expected SketchMode.Tool, status prefix after the press
const RAIL_TOOLS := [
	["Select", SketchMode.Tool.SELECT, "Select —"],
	["Line", SketchMode.Tool.LINE, "Line —"],
	["Arc", SketchMode.Tool.ARC, "Arc —"],
	["Circle", SketchMode.Tool.CIRCLE, "Circle —"],
	["Rect", SketchMode.Tool.RECT, "Rect —"],
	["Polygon", SketchMode.Tool.POLYGON, "Polygon —"],
	["Ellipse", SketchMode.Tool.ELLIPSE, "Ellipse —"],
	["Slot", SketchMode.Tool.SLOT, "Slot —"],
	["Spline", SketchMode.Tool.SPLINE, "Spline —"],
	["Point", SketchMode.Tool.POINT, "Point —"],
	["Trim", SketchMode.Tool.TRIM, "Trim —"],
	["Extend", SketchMode.Tool.EXTEND, "Extend —"],
	["Smart Dim", SketchMode.Tool.SMART_DIM, "Smart Dim —"],
	["Convert", SketchMode.Tool.CONVERT, "Convert —"],
	["Mirror", SketchMode.Tool.MIRROR, "Mirror —"],
	["Pattern", SketchMode.Tool.PATTERN, "Pattern —"],
]

var failures := 0
var checks := 0
var _log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 A11a Slot rail arming via real clicks")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


func _status_of(main) -> String:
	if main.status_label != null:
		return str(main.status_label.text)
	return _last()


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


func _wheel_at(pos: Vector2, down: bool, notches: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	for _i in notches:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.factor = 1.0
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
		ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		ev.pressed = false
		ev.factor = 1.0
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
	await process_frame


func _rail_scroll_room(scroll: ScrollContainer) -> int:
	if scroll == null:
		return 0
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return 0
	return maxi(0, int(ceil(bar.max_value - bar.page)))


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
	# Only the button centre, not a 1-px sliver at the clip edge. A top sliver
	# of Ellipse after a wheel is really Jaw; a bottom sliver is the next tool.
	var inner := sr.grow_individual(0.0, -6.0, 0.0, -6.0)
	if inner.has_point(c):
		return c
	return Vector2.INF


func _click_rail_button(main, label: String) -> Button:
	var btn := FilmUI.find_sketch_tool_button(main, label)
	if btn == null or not btn.is_visible_in_tree():
		return null
	var scroll := _rail_scroll(main.sketch_toolbar)
	var pos := _btn_center_visible(btn, scroll)
	# ensure_control_visible pins the control to the clip rim (y≈86), under
	# the finish-bar band, where the press never reaches the button.
	if pos == Vector2.INF or pos.y < 160.0 or pos.y > 520.0:
		await _scroll_btn_to_band(scroll, btn, 300.0)
		pos = _btn_center_visible(btn, scroll)
	if pos == Vector2.INF:
		return null
	print("  click %s at (%.0f, %.0f) tool_before=%s hovered=%s" % [
			label, pos.x, pos.y, str(main.sketch_mode.tool),
			str(root.gui_get_hovered_control())])
	await _push_click(pos)
	var hovered := root.gui_get_hovered_control()
	print("  after %s tool=%s status=`%s` hovered=%s pressed=%s" % [
			label, str(main.sketch_mode.tool), _status_of(main), str(hovered),
			str(btn.button_pressed)])
	return btn


func _type_into_dim(main, text: String) -> void:
	var chrome: SketchContextChrome = main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	if edit == null:
		return
	var pos := edit.get_global_rect().get_center()
	await _push_click(pos)
	await _type_keys(text, true)


## Unfocused burst — the A11a walk types radius/length without clicking the blank.
func _type_unfocused(text: String) -> void:
	await _type_keys(text, true)


func _type_keys(text: String, press_enter: bool) -> void:
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
	if not press_enter:
		return
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


func _assert_tool_from_click(main, label: String, want_tool: int, hint_prefix: String) -> void:
	var sm: SketchMode = main.sketch_mode
	var btn := await _click_rail_button(main, label)
	check(btn != null, "rail button `%s` is clickable at a visible position" % label)
	if btn == null:
		return
	check(int(sm.tool) == want_tool,
			"`%s` click arms tool %d (got %d, status `%s`)" % [
				label, want_tool, int(sm.tool), _status_of(main)])
	var st := _status_of(main)
	check(st.begins_with(hint_prefix) or st.contains(hint_prefix),
			"`%s` arm hint starts with `%s` (got `%s`)" % [label, hint_prefix, st])
	check(btn.button_pressed,
			"`%s` rail button is highlighted after the press" % label)


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
	main.sketch_mode.status.connect(func(m): _log.append(str(m)))
	main.interaction.status.connect(func(m): _log.append(str(m)))

	await FilmUI.place_primitive(ctx, "box")
	var body: String = ctx.view.selected_body
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "box placed, +Z face found")
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	var sm: SketchMode = main.sketch_mode
	check(sm.active, "first face sketch is active")
	var rail: Control = main.sketch_toolbar
	check(rail != null and rail.visible, "sketch rail is visible")
	var scroll := _rail_scroll(rail)
	check(scroll != null, "sketch rail has a ScrollContainer")

	# Dirty the finish bar the way the jaw cut leaves it.
	var chrome: SketchContextChrome = main.sketch_chrome
	chrome.set_finish_op("cut")
	chrome.set_finish_end("to_face")
	chrome._on_finish_end_selected(3)
	chrome.set_dim_value(38.76)
	check(chrome.get_finish_end() == "to_face", "setup: End is Up To Surface")

	# Wheel proves the rail scrolls when the column is shorter than the tools.
	# At 1280×800 the rail fits (sx-036 A1), so the wheel stays at 0. Do not
	# click a tool in the same gesture: Godot keeps the ScrollContainer
	# capturing LMB after a wheel.
	if scroll != null:
		var room := _rail_scroll_room(scroll)
		var wheel_at := rail.get_global_rect().get_center()
		await _wheel_at(wheel_at, true, 12)
		print("  scrolled rail scroll_vertical=%d room=%d" % [scroll.scroll_vertical, room])
		if room > 1:
			check(scroll.scroll_vertical > 0, "wheel over the rail scrolls it down")
		else:
			check(scroll.scroll_vertical == 0,
					"rail fits at 1280×800 so the wheel leaves scroll at 0")

	# Exit, open a new face sketch: scroll resets, finish bar resets, Slot arms.
	await FilmUI.exit_sketch(ctx)
	check(not sm.active, "exited the first sketch")
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	check(sm.active, "second face sketch is active")
	scroll = _rail_scroll(rail)
	if scroll != null:
		check(scroll.scroll_vertical == 0,
				"a newly opened sketch resets the rail scroll to the top (got %d)" % scroll.scroll_vertical)
	check(chrome.get_finish_end() == "blind",
			"new sketch End is Blind (got %s)" % chrome.get_finish_end())
	var op := chrome.find_child("FinishOp", true, false) as OptionButton
	check(op != null and op.selected == 0, "new sketch Op is New")
	var ex := chrome.extrude_button()
	check(ex != null and not ex.disabled, "new sketch Extrude is enabled")
	check(absf(chrome.extrude_distance() - 20.0) < 0.01,
			"new sketch Extrude distance is 20 mm (got %.3f)" % chrome.extrude_distance())

	# Park the pointer on the canvas so hover is Interaction — the real-GUI
	# trap. Sketch `_input` used to mark that motion handled, so Slot's press
	# was a canvas click (hide Rect chips, LINE rubber-band, no set_tool).
	await _assert_tool_from_click(main, "Rect", SketchMode.Tool.RECT, "Rect —")
	var canvas := Vector2(ROOT_SIZE.x * 0.55, ROOT_SIZE.y * 0.55)
	var park := InputEventMouseMotion.new()
	park.position = canvas
	park.global_position = canvas
	root.push_input(park)
	await process_frame
	await process_frame
	var parked := root.gui_get_hovered_control()
	print("  parked hover=%s (want Interaction)" % str(parked))
	check(parked == main.interaction,
			"canvas park puts hover on Interaction (got %s)" % str(parked))

	# Core A11a: press Slot at its visible position with real mouse events.
	var slot_btn := await _click_rail_button(main, "Slot")
	check(slot_btn != null, "Slot is visible on the unscrolled rail")
	check(int(sm.tool) == int(SketchMode.Tool.SLOT),
			"Slot click arms SketchMode.Tool.SLOT (got %d)" % int(sm.tool))
	check(_status_of(main).begins_with("Slot"),
			"Slot arm status is `Slot …` (got `%s`)" % _status_of(main))
	check(slot_btn != null and slot_btn.button_pressed,
			"Slot rail button is highlighted")
	var variants := main.find_child("VariantBar", true, false) as Control
	check(variants == null or not variants.visible,
			"Slot has no leftover Rect chip row")

	# Typing 5 + Enter is the slot radius, not Extrude Distance. Seed a
	# non-default radius first: default is already 5, so a stolen Extrude
	# burst would still leave slot_radius == 5.
	sm.slot_radius = 3.0
	chrome.sync_for_tool()
	var dist_edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(absf(chrome.extrude_distance() - 20.0) < 0.01,
			"Extrude is 20 mm before typing Slot radius (got %.3f)" % chrome.extrude_distance())
	await _type_unfocused("5")
	check(absf(sm.slot_radius - 5.0) < 1e-3,
			"unfocused 5 sets slot radius (got %.4f)" % sm.slot_radius)
	check(absf(chrome.extrude_distance() - 20.0) < 0.01,
			"typing Slot radius does not change Extrude (got %.3f)" % chrome.extrude_distance())
	check(dist_edit == null or not dist_edit.has_focus(),
			"Extrude does not keep focus after Slot radius")
	check(not _status_of(main).contains("Select entities"),
			"Enter on the Slot radius does not apply a dimension (got `%s`)" % _status_of(main))
	check(int(sm.tool) == int(SketchMode.Tool.SLOT),
			"tool is still SLOT after typing the radius")

	# 150 c-c after the first centre — A11a typed-length read-back on the
	# status bar. Type unfocused so leftover Extrude focus cannot eat 150.
	sm.click(Vector2(0.0, 0.0))
	sm.hover(Vector2(40.0, 0.0))
	main.sketch_chrome.sync_for_tool()
	var cc_label: Label = chrome.find_child("RadiusLabel", true, false)
	check(cc_label != null and cc_label.visible and str(cc_label.text) == "c-c",
			"after the first centre the dim field is labelled c-c (got `%s`)" % [
				str(cc_label.text) if cc_label != null else "missing"])
	await _type_unfocused("150")
	check(_status_of(main) == "Slot c-c 150.0000 R5.0000 — typed",
			"A11a read-back is Slot c-c 150.0000 R5.0000 — typed (got `%s`)" % _status_of(main))
	check(not _status_of(main).begins_with("Length"),
			"typed Slot length is not a bare Length … mm (got `%s`)" % _status_of(main))
	check(absf(chrome.extrude_distance() - 20.0) < 0.01,
			"typed Slot length does not change Extrude (got %.3f)" % chrome.extrude_distance())
	await process_frame
	cc_label = chrome.find_child("RadiusLabel", true, false)
	check(cc_label != null and cc_label.visible and str(cc_label.text) == "Radius",
			"after typed Slot commit the blank is labelled Radius (got `%s`)" % [
				str(cc_label.text) if cc_label != null else "missing"])
	check(absf(chrome.dim_value() - 5.0) < 0.01,
			"after typed Slot commit the blank shows radius 5, not 150 (got %.3f)" % chrome.dim_value())

	# Every remaining rail tool at scroll 0, then again after scrolling.
	for row in RAIL_TOOLS:
		if str(row[0]) == "Slot":
			continue
		await _assert_tool_from_click(main, str(row[0]), int(row[1]), str(row[2]))

	var jaw := await _click_rail_button(main, "Jaw")
	check(jaw != null, "Jaw is on the rail")
	check(int(sm.tool) == int(SketchMode.Tool.RECT),
			"Jaw click arms the rectangle tool (got %d)" % int(sm.tool))
	check(_status_of(main).begins_with("Jaw"),
			"Jaw arm hint starts with Jaw (got `%s`)" % _status_of(main))

	if scroll != null:
		var slot_for_scroll := FilmUI.find_sketch_tool_button(main, "Slot")
		await _scroll_btn_to_band(scroll, slot_for_scroll, 300.0)
		if _rail_scroll_room(scroll) > 1:
			check(scroll.scroll_vertical > 0, "second scroll pass moved the rail")
		else:
			var slot_r := slot_for_scroll.get_global_rect() if slot_for_scroll != null else Rect2()
			check(slot_for_scroll != null and scroll.get_global_rect().encloses(slot_r.grow(-0.5)),
					"Slot stays fully on the rail without scrolling (%s)" % str(slot_r))
		await _assert_tool_from_click(main, "Slot", SketchMode.Tool.SLOT, "Slot —")
		await _assert_tool_from_click(main, "Ellipse", SketchMode.Tool.ELLIPSE, "Ellipse —")
		await _assert_tool_from_click(main, "Spline", SketchMode.Tool.SPLINE, "Spline —")

	main.queue_free()
	await process_frame
	await process_frame
