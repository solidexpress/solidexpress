# re-PLAN 19 WP1 — X11 burst echo and same-frame focus writes.
# Every press under test is a real InputEvent via Viewport.push_input.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan19_keys.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const ECHO_STRINGS: PackedStringArray = ["22.5", "200", "1.5", "45", "2.5", "10", "100"]

var _status_log: Array[String] = []
var _clock := 0


func _init() -> void:
	print("rung01 replan19 keys")
	FilmUI.reset_fail_count()
	await _test_echo_matrix()
	await _test_real_repeat()
	await _test_same_frame()
	await _test_keys_before_focus()
	await _test_trace()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	_clear_clock()
	SxUi.trace_enabled_override = null
	finish()


func _boot() -> FilmContext:
	_clear_clock()
	SxUi.key_trace_log = PackedStringArray()
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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	_connect_status(main)
	await FilmUI.enter_sketch(ctx)
	await process_frame
	check(main.sketch_mode != null and main.sketch_mode.active, "sketch is active")
	return ctx


func _boot_part() -> FilmContext:
	_clear_clock()
	SxUi.key_trace_log = PackedStringArray()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	_status_log.clear()
	_connect_status(main)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _connect_status(main) -> void:
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.ops_panel != null and main.ops_panel.has_signal("status") \
			and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)


func _label(main) -> String:
	if main == null or main.status_label == null:
		return ""
	return str(main.status_label.text)


func _saw(main, needle: String) -> bool:
	if _label(main).contains(needle) or _status_blob().contains(needle):
		return true
	return false


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _status_blob() -> String:
	return " ".join(_status_log)


func _clear_clock() -> void:
	_clock = 0
	SxUi._now_msec_override = Callable()


func _set_clock(ms: int) -> void:
	_clock = ms
	SxUi._now_msec_override = func() -> int: return _clock


func _test_echo_matrix() -> void:
	print("- echo burst into each numeric field")
	await _echo_circle()
	await _echo_distance()
	await _echo_slot()
	await _echo_dim_editor()
	await _echo_strip_and_panel()


func _echo_circle() -> void:
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, sm, Vector2(0, 0), "Circle centre")
	await process_frame
	var dim := _dim_edit(ctx.main.sketch_chrome)
	check(dim != null, "Circle Radius blank exists")
	if dim == null:
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	for s in ECHO_STRINGS:
		await _click_control(dim)
		_push_x11_burst(vp, s)
		await process_frame
		check(_body(dim.text) == s, "Circle Radius echo '%s' reads '%s'" % [s, dim.text])
		if s == "22.5":
			_status_log.clear()
			_push_key_now(vp, KEY_ENTER)
			await process_frame
			await process_frame
			check(_saw(ctx.main, "Circle r=22.5000 (Ø45.0000)"),
					"Circle 22.5 commits (status '%s' label '%s')" % [_status_blob(), _label(ctx.main)])
	await _shutdown(ctx)


func _echo_distance() -> void:
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	check(dist != null, "Distance blank exists")
	if dist == null:
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	for s in ECHO_STRINGS:
		await _click_control(dist)
		_push_x11_burst(vp, s)
		await process_frame
		check(_body(dist.text) == s, "Distance echo '%s' reads '%s'" % [s, dist.text])
		var spin := dist.get_parent() as SpinBox
		if spin != null:
			check(is_equal_approx(spin.value, float(s)),
					"Distance model is %s (got %s)" % [s, str(spin.value)])
	await _shutdown(ctx)


func _echo_slot() -> void:
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SLOT)
	await FilmUI.click_sketch(ctx, sm, Vector2(0, 0), "Slot centre")
	await process_frame
	var dim := _dim_edit(ctx.main.sketch_chrome)
	check(dim != null, "Slot c-c blank exists")
	if dim == null:
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	for s in ECHO_STRINGS:
		await _click_control(dim)
		_push_x11_burst(vp, s)
		await process_frame
		check(_body(dim.text) == s, "Slot blank echo '%s' reads '%s'" % [s, dim.text])
	await _click_control(dim)
	_push_x11_burst(vp, "150")
	await process_frame
	check(_body(dim.text) == "150", "Slot c-c burst reads 150 (got '%s')" % dim.text)
	_status_log.clear()
	_push_key_now(vp, KEY_ENTER)
	await process_frame
	await process_frame
	check(_saw(ctx.main, "Slot c-c 150.0000 R5.0000 — typed"),
			"Slot 150 commits (status '%s' label '%s')" % [_status_blob(), _label(ctx.main)])
	await _shutdown(ctx)


func _echo_dim_editor() -> void:
	var ctx := await _boot()
	if not await _open_angle_editor(ctx):
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	for s in ECHO_STRINGS:
		var line := _dim_popup_line(ctx)
		if line == null or not line.is_visible_in_tree():
			if not await _open_angle_editor(ctx):
				check(false, "dimension editor reopened for '%s'" % s)
				break
			line = _dim_popup_line(ctx)
		else:
			await _click_control(line)
		_push_x11_burst(vp, s)
		await process_frame
		line = _dim_popup_line(ctx)
		check(line != null and _body(line.text) == s,
				"dimension editor echo '%s' reads '%s'" % [s, line.text if line != null else ""])
	await _shutdown(ctx)


func _echo_strip_and_panel() -> void:
	var ctx := await _boot_part()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	await process_frame
	var fillet: Button = ctx.main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "Fillet chip is visible")
	if fillet == null:
		await _shutdown(ctx)
		return
	await _click_control(fillet)
	await process_frame
	await process_frame
	var strip := ctx.main.interaction.find_child("StripRadius", true, false) as SpinBox
	var panel := ctx.main.ops_panel._radius_spin as SpinBox
	check(strip != null and strip.is_visible_in_tree(), "strip R is visible")
	check(panel != null, "panel Radius exists")
	var vp: Viewport = ctx.main.get_viewport()
	if strip != null:
		var sle := strip.get_line_edit()
		for s in ECHO_STRINGS:
			await _click_control(sle)
			_push_x11_burst(vp, s)
			await process_frame
			check(_body(sle.text) == s, "strip R echo '%s' reads '%s'" % [s, sle.text])
			if float(s) >= strip.min_value - 1e-6 and float(s) <= strip.max_value + 1e-6:
				check(is_equal_approx(strip.value, float(s)),
						"strip R model is %s (got %s)" % [s, str(strip.value)])
		if sle != null:
			await _click_control(sle)
			_push_x11_burst(vp, "1.5")
			_status_log.clear()
			_push_key_now(vp, KEY_ENTER)
			await process_frame
			await process_frame
			check(_saw(ctx.main, "Fillet r=1.50 — edit Radius, click edges, Enter"),
					"strip 1.5 status (got '%s' label '%s')" % [_status_blob(), _label(ctx.main)])
	if panel != null:
		FilmUI.ensure_control_visible(panel)
		await process_frame
		var ple := panel.get_line_edit()
		for s in ECHO_STRINGS:
			await _click_control(ple)
			_push_x11_burst(vp, s)
			await process_frame
			check(_body(ple.text) == s, "panel Radius echo '%s' reads '%s'" % [s, ple.text])
			if float(s) >= panel.min_value - 1e-6 and float(s) <= panel.max_value + 1e-6:
				check(is_equal_approx(panel.value, float(s)),
						"panel Radius model is %s (got %s)" % [s, str(panel.value)])
	await _shutdown(ctx)


func _test_real_repeat() -> void:
	print("- real auto-repeat is a single 5")
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	if dist == null:
		check(false, "Distance exists for repeat")
		await _shutdown(ctx)
		return
	await _click_control(dist)
	_set_clock(1000)
	_push_char_now(ctx.main.get_viewport(), "5", false)
	_set_clock(1400)
	_push_char_now(ctx.main.get_viewport(), "5", true)
	_set_clock(1430)
	_push_char_now(ctx.main.get_viewport(), "5", true)
	_set_clock(1460)
	_push_char_now(ctx.main.get_viewport(), "5", true)
	await process_frame
	await process_frame
	check(_body(dist.text) == "5", "repeat echo does not add digits (got '%s')" % dist.text)
	check(not _body(dist.text).contains("55"), "field is not 55 (got '%s')" % dist.text)
	_clear_clock()
	await _shutdown(ctx)


func _test_same_frame() -> void:
	print("- same-frame click and burst")
	for which in ["strip", "panel", "distance"]:
		var ctx := await _field_ctx(which)
		var spun := _field_line(ctx, which)
		var line := spun[0] as LineEdit
		var spin := spun[1] as SpinBox
		if line == null:
			check(false, which + " field exists for same-frame")
			await _shutdown(ctx)
			continue
		var vp: Viewport = ctx.main.get_viewport()
		for with_select_all in [true, false]:
			for s in ["1.5", "22.5", "10"]:
				var tag := "%s %s select_all=%s" % [which, s, str(with_select_all)]
				_click_control_now(line)
				if with_select_all:
					_push_chord_now(vp, KEY_A, true)
				_push_x11_burst(vp, s)
				for _i in 3:
					await process_frame
				check(_body(line.text) == s, tag + " text is '%s' (got '%s')" % [s, line.text])
				if spin != null:
					check(is_equal_approx(spin.value, float(s)),
							tag + " model is %s (got %s)" % [s, str(spin.value)])
		_click_control_now(line)
		_push_x11_burst(vp, "1.5")
		_push_key_now(vp, KEY_ENTER)
		_status_log.clear()
		_push_key_now(vp, KEY_3)
		await process_frame
		var owner := _focus_name(ctx)
		check(owner == "Interaction", which + " Enter then 3 focus is Interaction (got '%s')" % owner)
		check(_saw(ctx.main, "Top view"),
				which + " key 3 is Top view (status '%s' label '%s')" % [_status_blob(), _label(ctx.main)])
		check(not _status_blob().contains("Front view") and not _label(ctx.main).contains("Front view"),
				which + " key 3 is not Front view (status '%s')" % _status_blob())
		await _shutdown(ctx)
	await _a11d_strip()


func _field_ctx(which: String) -> FilmContext:
	if which == "distance":
		return await _boot()
	return await _arm_fillet_part()


func _field_line(ctx: FilmContext, which: String) -> Array:
	if which == "distance":
		var dist := _distance_edit(ctx.main.sketch_chrome)
		return [dist, dist.get_parent() if dist != null else null]
	var spin: SpinBox
	if which == "strip":
		spin = ctx.main.interaction.find_child("StripRadius", true, false) as SpinBox
	else:
		spin = ctx.main.ops_panel._radius_spin as SpinBox
		if spin != null:
			FilmUI.ensure_control_visible(spin)
	var line := spin.get_line_edit() if spin != null else null
	return [line, spin]


func _a11d_strip() -> void:
	var ctx := await _arm_fillet_part()
	var spin := ctx.main.interaction.find_child("StripRadius", true, false) as SpinBox
	var line := spin.get_line_edit() if spin != null else null
	if line == null:
		check(false, "A11d strip exists")
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	await _click_control(line)
	await _push_chord(vp, KEY_A, true)
	await _push_char(vp, "1", false)
	await _push_key(vp, KEY_ENTER)
	_status_log.clear()
	await _push_key(vp, KEY_3)
	await process_frame
	check(_saw(ctx.main, "Top view"), "A11d key 3 is Top view (status '%s' label '%s')" % [_status_blob(), _label(ctx.main)])
	check(_body(line.text) == "1" or line.text.contains("1 mm"),
			"A11d strip text is 1 mm (got '%s')" % line.text)
	await _shutdown(ctx)


func _test_keys_before_focus() -> void:
	print("- key before focus does not become Front view")
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	if dist == null:
		check(false, "Distance exists for pre-focus")
		await _shutdown(ctx)
		return
	ctx.main.interaction.grab_focus()
	await process_frame
	check(_focus_name(ctx) == "Interaction",
			"viewport owns focus before the burst (got '%s')" % _focus_name(ctx))
	var vp: Viewport = ctx.main.get_viewport()
	_status_log.clear()
	_click_control_now(dist)
	_push_char_now(vp, "1", false)
	await process_frame
	await process_frame
	check(not _status_blob().contains("Front view") and not _label(ctx.main).contains("Front view"),
			"same-frame 1 is not Front view (status '%s' label '%s')" % [_status_blob(), _label(ctx.main)])
	check(_body(dist.text) == "1" or _body(dist.text).begins_with("1"),
			"same-frame 1 landed in Distance (got '%s')" % dist.text)
	await _shutdown(ctx)


func _test_trace() -> void:
	print("- key trace gate")
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	if dist == null:
		check(false, "Distance exists for trace")
		await _shutdown(ctx)
		return
	await _click_control(dist)
	SxUi.trace_enabled_override = false
	SxUi.key_trace_log = PackedStringArray()
	_push_char_now(ctx.main.get_viewport(), "4", false)
	await process_frame
	check(SxUi.key_trace_log.is_empty(),
			"trace off prints nothing (got %d)" % SxUi.key_trace_log.size())
	SxUi.trace_enabled_override = true
	SxUi.key_trace_log = PackedStringArray()
	_push_char_now(ctx.main.get_viewport(), "5", false)
	_push_char_now(ctx.main.get_viewport(), "5", true)
	await process_frame
	check(SxUi.key_trace_log.size() >= 2, "trace on prints one line per press (got %d)" % SxUi.key_trace_log.size())
	var saw_echo := false
	var saw_accept := false
	for line in SxUi.key_trace_log:
		check(str(line).begins_with("[key-trace] "), "trace line starts with [key-trace] ('%s')" % line)
		check(str(line).contains("echo="), "trace line has echo= ('%s')" % line)
		check(str(line).contains("accepted="), "trace line has accepted= ('%s')" % line)
		if str(line).contains("echo=1"):
			saw_echo = true
		if str(line).contains("accepted=1"):
			saw_accept = true
	check(saw_echo, "an echo press was traced")
	check(saw_accept, "an accepted press was traced")
	SxUi.trace_enabled_override = false
	await _shutdown(ctx)


func _arm_fillet_part() -> FilmContext:
	var ctx := await _boot_part()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	var fillet: Button = ctx.main.interaction.find_child("StripFillet", true, false)
	if fillet != null:
		await _click_control(fillet)
		await process_frame
		await process_frame
	return ctx


func _open_angle_editor(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	var h: String = sm.sketch.add_line(0, 0, 40, 0)
	var v: String = sm.sketch.add_line(0, 0, 0, 40)
	sm._set_selected([h, v])
	sm.constrain("angle", PI * 0.5)
	sm.run_solve()
	sm._rebuild_dimension_labels()
	sm._redraw()
	sm.fit_view()
	await process_frame
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var label := _angle_label(sm)
	if label == Vector2.INF:
		check(false, "angle dimension has a label")
		return false
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(label))
	await _click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame
	var popup := ctx.main.interaction.find_child("DimEditPopup", true, false) as PopupPanel
	var line := _dim_popup_line(ctx)
	var open := line != null and popup != null and popup.visible
	check(open, "dimension editor is open")
	return open


func _angle_label(sm: SketchMode) -> Vector2:
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "angle":
			continue
		var lp = dim.get("label_pos", null)
		if lp is Vector2:
			return lp
	return Vector2.INF


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _dim_popup_line(ctx: FilmContext) -> LineEdit:
	var ix: ViewportInteraction = ctx.main.interaction
	if ix == null:
		return null
	return ix.find_child("DimEditLine", true, false) as LineEdit


func _body(raw: String) -> String:
	var text := str(raw).strip_edges()
	for suffix in [" mm", "mm", " AF"]:
		if text.ends_with(suffix):
			text = text.substr(0, text.length() - suffix.length()).strip_edges()
	return text


func _focus_name(ctx: FilmContext) -> String:
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	if owner == null:
		return ""
	return str(owner.name)


func _click_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	_click_control_now(ctrl)
	await process_frame


func _click_control_now(ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	_click_screen_now(ctrl.get_viewport(), pos)


func _click_screen(vp: Viewport, pos: Vector2) -> void:
	_click_screen_now(vp, pos)
	await process_frame


func _click_screen_now(vp: Viewport, pos: Vector2) -> void:
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


func _push_x11_burst(vp: Viewport, text: String) -> void:
	var prev := ""
	var i := 0
	while i < text.length():
		var ch := text.substr(i, 1)
		var echo := ch == prev
		if echo:
			# X11 drops the release of the first identical press and flags
			# the second press as echo.
			_push_char_down(vp, ch, true)
			_push_char_up(vp, ch)
			prev = ""
		else:
			var nxt := text.substr(i + 1, 1) if i + 1 < text.length() else ""
			if nxt == ch:
				_push_char_down(vp, ch, false)
				prev = ch
			else:
				_push_char_now(vp, ch, false)
				prev = ""
		i += 1


func _push_char(vp: Viewport, ch: String, echo: bool) -> void:
	_push_char_now(vp, ch, echo)
	await process_frame


func _push_char_now(vp: Viewport, ch: String, echo: bool) -> void:
	_push_char_down(vp, ch, echo)
	_push_char_up(vp, ch)


func _push_char_down(vp: Viewport, ch: String, echo: bool) -> void:
	var code := _key_for(ch)
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = ch.unicode_at(0)
	ev.pressed = true
	ev.echo = echo
	vp.push_input(ev)


func _push_char_up(vp: Viewport, ch: String) -> void:
	var code := _key_for(ch)
	var rel := InputEventKey.new()
	rel.keycode = code
	rel.physical_keycode = code
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)


func _key_for(ch: String) -> Key:
	var unicode := ch.unicode_at(0)
	if unicode >= 48 and unicode <= 57:
		return (KEY_0 + (unicode - 48)) as Key
	if unicode == 46:
		return KEY_PERIOD
	push_error("no key for %s" % ch)
	return KEY_NONE


func _push_key(vp: Viewport, keycode: Key) -> void:
	_push_key_now(vp, keycode)
	await process_frame


func _push_key_now(vp: Viewport, keycode: Key) -> void:
	_push_chord_now(vp, keycode, false)


func _push_chord(vp: Viewport, keycode: Key, ctrl: bool) -> void:
	_push_chord_now(vp, keycode, ctrl)
	await process_frame


func _push_chord_now(vp: Viewport, keycode: Key, ctrl: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.echo = false
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)
