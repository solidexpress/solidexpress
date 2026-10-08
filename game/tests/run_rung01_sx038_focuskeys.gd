# sx-038 — keys typed in the same frame as focus (or as the previous commit)
# must not be dropped. Covers finish-bar Distance, Circle radius, the
# in-viewport dimension label editor, sketch redo, and the sketch rail.
# Every press and key under test is a real InputEvent via Viewport.push_input.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx038_focuskeys.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 sx038 focus keys")
	FilmUI.reset_fail_count()
	await _test_distance_fast()
	await _test_distance_framed()
	await _test_distance_ctrl_a()
	await _test_distance_tab()
	await _test_circle_shortcut()
	await _test_circle_radius_fast()
	await _test_circle_radius_framed()
	await _test_angle_fast()
	await _test_angle_framed()
	await _test_redo_while_editor_open()
	await _test_redo_after_dim_commit()
	await _test_rail_select_after_line_click(false)
	await _test_rail_select_after_line_click(true)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	await FilmUI.enter_sketch(ctx)
	await process_frame
	check(main.sketch_mode != null and main.sketch_mode.active, "sketch is active")
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


func _status_blob() -> String:
	return " ".join(_status_log)


func _test_distance_fast() -> void:
	print("- L10 Distance fast 10 Enter, 14 Enter, 10 Enter")
	await _distance_sequence(false)


func _test_distance_framed() -> void:
	print("- L10 Distance framed 10 Enter, 14 Enter, 10 Enter")
	await _distance_sequence(true)


func _test_distance_ctrl_a() -> void:
	print("- Distance Ctrl+A then fast 2.5 replaces 20")
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	check(dist != null and _near(_parsed(dist), 20.0),
			"Distance starts at 20 (got '%s')" % (dist.text if dist != null else ""))
	if dist == null:
		await _shutdown(ctx)
		return
	await _click_control(dist)
	# No frame between Ctrl+A and the digits. A spin rewrite of "2" to "2.0"
	# used to splice this into "2.05".
	_push_chord_now(ctx.main.get_viewport(), KEY_A, true)
	await _type_text(ctx.main.get_viewport(), "2.5", false)
	check(_near(_parsed(dist), 2.5), "Ctrl+A then 2.5 reads 2.5 (got '%s')" % dist.text)
	check(not str(dist.text).contains("2.05"),
			"Distance did not splice to 2.05 (got '%s')" % dist.text)
	await _push_chord(ctx.main.get_viewport(), KEY_A, true, false)
	check(_selection_covers_all(dist),
			"Ctrl+A selects all Distance text (got '%s' sel %s-%s)" % [
				dist.text, dist.get_selection_from_column(), dist.get_selection_to_column()])
	await _type_text(ctx.main.get_viewport(), "2.5", false)
	check(_near(_parsed(dist), 2.5), "second Ctrl+A then 2.5 reads 2.5 (got '%s')" % dist.text)
	check(not str(dist.text).contains("2.052.5"),
			"second try did not append (got '%s')" % dist.text)
	await _shutdown(ctx)


func _test_distance_tab() -> void:
	print("- Tab into Distance then fast 2.5 replaces 20")
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	var dim := _dim_edit(ctx.main.sketch_chrome)
	if dist == null or dim == null:
		check(false, "Distance and Dim lines exist for Tab")
		await _shutdown(ctx)
		return
	dim.grab_focus()
	await process_frame
	var landed := false
	for _i in 12:
		await _push_key(ctx.main.get_viewport(), KEY_TAB)
		if dist.has_focus():
			landed = true
			break
	check(landed, "Tab reaches Distance (owner '%s')" % _focus_name(ctx))
	await _type_text(ctx.main.get_viewport(), "2.5", false)
	check(_near(_parsed(dist), 2.5), "Tab then 2.5 reads 2.5 (got '%s')" % dist.text)
	await _shutdown(ctx)


func _distance_sequence(framed: bool) -> void:
	var ctx := await _boot()
	var dist := _distance_edit(ctx.main.sketch_chrome)
	check(dist != null, "DistanceLineEdit exists")
	if dist == null:
		await _shutdown(ctx)
		return
	await _click_control(dist)
	await _type_text(ctx.main.get_viewport(), "10", framed)
	check(_near(_parsed(dist), 10.0), "fast/framed typed 10 reads 10 (got '%s')" % dist.text)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(not dist.has_focus(), "Distance Enter releases focus (text '%s')" % dist.text)
	check(_near(_parsed(dist), 10.0), "Distance stays 10 after Enter (got '%s')" % dist.text)
	await _type_text(ctx.main.get_viewport(), "14", framed)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(not dist.has_focus(), "second Distance Enter releases focus")
	check(_near(_parsed(dist), 14.0), "Distance replaced with 14 (got '%s')" % dist.text)
	await _type_text(ctx.main.get_viewport(), "10", framed)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(not dist.has_focus(), "third Distance Enter releases focus")
	check(_near(_parsed(dist), 10.0), "Distance replaced with 10 (got '%s')" % dist.text)
	_status_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_S)
	await process_frame
	check(_status_blob().begins_with("Select"),
			"key after Distance Enter reaches the viewport (status '%s')" % _status_blob())
	await _shutdown(ctx)


func _test_circle_shortcut() -> void:
	print("- L1 Circle armed, S selects")
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	var dim := _dim_edit(ctx.main.sketch_chrome)
	check(dim != null and dim.is_visible_in_tree(), "Circle radius field is visible")
	check(dim != null and dim.has_focus(),
			"arming Circle focuses Radius (focus %s)" % str(dim.has_focus() if dim != null else false))
	_status_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_S)
	await process_frame
	check(sm.tool == SketchMode.Tool.SELECT, "S switches Circle to Select (tool %s)" % str(sm.tool))
	check(_status_blob().begins_with("Select"),
			"S status starts with Select (got '%s')" % _status_blob())
	await _shutdown(ctx)


func _test_circle_radius_fast() -> void:
	print("- A3 Circle centre then fast 22.5")
	await _circle_radius(false)


func _test_circle_radius_framed() -> void:
	print("- A3 Circle centre then framed 22.5")
	await _circle_radius(true)


func _circle_radius(framed: bool) -> void:
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, sm, Vector2(10, 8), "Circle centre")
	await process_frame
	var dim := _dim_edit(ctx.main.sketch_chrome)
	check(dim != null, "Radius field exists after the centre click")
	_status_log.clear()
	await _type_text(ctx.main.get_viewport(), "22.5", framed)
	if dim != null:
		check(_near(_parsed(dim), 22.5),
				"radius burst reads 22.5 before Enter (got '%s')" % dim.text)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var radius := _circle_radius_of(sm)
	var blob := _status_blob()
	check(is_equal_approx(radius, 22.5) or blob.contains("Circle r=22.5000"),
			"circle commit is 22.5 (radius %s status '%s')" % [str(radius), blob])
	await _shutdown(ctx)


func _test_angle_fast() -> void:
	print("- jaw angle editor fast 45")
	await _angle_editor(false)


func _test_angle_framed() -> void:
	print("- jaw angle editor framed 45")
	await _angle_editor(true)


func _angle_editor(framed: bool) -> void:
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	if not await _open_angle_editor(ctx):
		await _shutdown(ctx)
		return
	var line := _dim_popup_line(ctx)
	_status_log.clear()
	await _type_text(ctx.main.get_viewport(), "45", framed)
	line = _dim_popup_line(ctx)
	check(line != null and str(line.text) == "45",
			"angle editor keeps both digits (got '%s')" % (str(line.text) if line != null else "null"))
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var shown := _angle_display(sm)
	check(is_equal_approx(shown, 45.0) or _status_blob().contains("Dimension updated"),
			"angle edit commits 45 (display %s status '%s')" % [str(shown), _status_blob()])
	var popup := ctx.main.interaction.find_child("DimEditPopup", true, false) as PopupPanel
	check(popup == null or not popup.visible, "angle Enter closes the editor")
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == null or not (owner is LineEdit),
			"angle Enter releases the keyboard (owner %s)" % (
				"null" if owner == null else str(owner.name)))
	await _shutdown(ctx)


func _test_redo_while_editor_open() -> void:
	print("- Ctrl+Shift+Z while the angle editor is open and untouched")
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	if not await _open_angle_editor(ctx):
		await _shutdown(ctx)
		return
	var extra: String = sm.sketch.add_line(20, 20, 30, 20)
	sm._redraw()
	await process_frame
	var undone: String = sm.undo()
	check(undone != "", "undo removed the extra line (label '%s')" % undone)
	check(not sm.sketch.entity_ids().has(extra), "extra line is gone before redo")
	var line := _dim_popup_line(ctx)
	var popup := ctx.main.interaction.find_child("DimEditPopup", true, false) as PopupPanel
	check(popup != null and popup.visible, "editor still open after undo")
	check(line == null or not SxUi.mid_entry(line), "opened editor is not mid-entry")
	_status_log.clear()
	await _push_chord(ctx.main.get_viewport(), KEY_Z, true, true)
	await process_frame
	var blob := _status_blob()
	check(blob.contains("Redo"), "Ctrl+Shift+Z redo is not dropped (status '%s')" % blob)
	check(sm.sketch.entity_ids().has(extra), "redo restored the extra line")
	await _shutdown(ctx)


func _test_redo_after_dim_commit() -> void:
	print("- Ctrl+Shift+Z after the angle editor commits")
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	if not await _open_angle_editor(ctx):
		await _shutdown(ctx)
		return
	await _type_text(ctx.main.get_viewport(), "45", true)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var popup := ctx.main.interaction.find_child("DimEditPopup", true, false) as PopupPanel
	check(popup == null or not popup.visible, "editor closed before redo")
	_status_log.clear()
	await _push_chord(ctx.main.get_viewport(), KEY_Z, true, false)
	await process_frame
	check(_status_blob().contains("Undo"),
			"Ctrl+Z after commit undoes (status '%s')" % _status_blob())
	_status_log.clear()
	await _push_chord(ctx.main.get_viewport(), KEY_Z, true, true)
	await process_frame
	check(_status_blob().contains("Redo"),
			"Ctrl+Shift+Z after commit redos (status '%s')" % _status_blob())
	check(is_equal_approx(_angle_display(sm), 45.0) or _status_blob().contains("Redo"),
			"redo status reached the viewport (angle %s)" % str(_angle_display(sm)))
	await _shutdown(ctx)


func _test_rail_select_after_line_click(split_release: bool) -> void:
	var tag := "split release" if split_release else "same frame"
	print("- rail Select after Line's first click (%s)" % tag)
	var ctx := await _boot()
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	check(sm.tool == SketchMode.Tool.LINE, "Line is armed")
	await FilmUI.click_sketch(ctx, sm, Vector2(12, 6), "Line first point")
	await process_frame
	check(sm.tool == SketchMode.Tool.LINE, "Line stays armed after the first point")
	check(sm.has_single_dof_preview() or sm.has_open_chain(),
			"first Line click left a rubber-band")
	var dim := _dim_edit(ctx.main.sketch_chrome)
	check(dim != null, "Line length field exists")
	if dim != null and not dim.has_focus():
		# The walk's field already owned the keyboard. Arm that state if this
		# click did not, then require the rail press to take it back.
		dim.grab_focus()
		await process_frame
	check(dim != null and dim.has_focus(),
			"length field owns the keyboard before the rail press (text '%s')" % (
				dim.text if dim != null else ""))
	var select_btn := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	check(select_btn != null and select_btn.is_visible_in_tree(), "rail Select is visible")
	if select_btn == null:
		await _shutdown(ctx)
		return
	await _press_control(select_btn, split_release)
	await process_frame
	check(sm.tool == SketchMode.Tool.SELECT,
			"first rail Select press switches off Line (%s, tool %s, dim focus %s text '%s')" % [
				tag, str(sm.tool), str(dim.has_focus() if dim != null else false),
				dim.text if dim != null else ""])
	check(dim == null or not dim.has_focus(),
			"rail Select does not leave the length field focused (%s)" % tag)
	await _shutdown(ctx)


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
	check(label != Vector2.INF, "angle dimension has a label")
	if label == Vector2.INF:
		return false
	await _click_uv(ctx, label)
	await process_frame
	await process_frame
	await process_frame
	var popup := ctx.main.interaction.find_child("DimEditPopup", true, false) as PopupPanel
	var line := _dim_popup_line(ctx)
	check(line != null and popup != null and popup.visible, "dimension editor is open")
	return line != null and popup != null and popup.visible


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


func _angle_display(sm: SketchMode) -> float:
	for dim in sm.dimensions:
		if typeof(dim) == TYPE_DICTIONARY and str(dim.get("type", "")) == "angle":
			return sm._dimension_display_value(dim)
	return -1.0


func _circle_radius_of(sm: SketchMode) -> float:
	var best := -1.0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			best = float(info.get("radius", -1.0))
	return best


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


func _parsed(edit: LineEdit) -> float:
	var text := str(edit.text).strip_edges()
	for suffix in [" mm", "mm", " AF"]:
		if text.ends_with(suffix):
			text = text.substr(0, text.length() - suffix.length()).strip_edges()
	if not text.is_valid_float():
		return NAN
	return float(text)


func _near(v: float, want: float) -> bool:
	return not is_nan(v) and absf(v - want) < 0.001


func _click_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	await _click_screen(ctrl.get_viewport(), pos)


func _press_control(ctrl: Control, split_release: bool) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
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
	if split_release:
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _click_screen(vp: Viewport, pos: Vector2) -> void:
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


func _click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "angle label"), "angle label is on screen")
	await _click_screen(ctx.main.get_viewport(), screen)


func _type_text(vp: Viewport, text: String, framed: bool) -> void:
	for i in text.length():
		await _push_char(vp, text.substr(i, 1), framed)
	await process_frame


func _push_char(vp: Viewport, ch: String, framed: bool) -> void:
	var code := KEY_NONE
	var unicode := ch.unicode_at(0)
	if unicode >= 48 and unicode <= 57:
		code = (KEY_0 + (unicode - 48)) as Key
	elif unicode == 46:
		code = KEY_PERIOD
	else:
		push_error("no key for %s" % ch)
		return
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
	if framed:
		await process_frame


func _push_key(vp: Viewport, keycode: Key) -> void:
	await _push_chord(vp, keycode, false, false)


func _push_chord(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	_push_chord_now(vp, keycode, ctrl, shift)
	await process_frame


func _push_chord_now(vp: Viewport, keycode: Key, ctrl: bool, shift: bool = false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)


func _selection_covers_all(edit: LineEdit) -> bool:
	if edit == null or not edit.has_selection():
		return false
	return edit.get_selection_from_column() == 0 \
			and edit.get_selection_to_column() == edit.text.length()


func _focus_name(ctx: FilmContext) -> String:
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	if owner == null:
		return ""
	return str(owner.name)
