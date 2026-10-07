# Rung 1 replan 16 WP3 — strip R, panel Radius, and finish-bar Distance
# replace on the first key; strip and panel print the same "N mm"; Save
# inside a sketch keeps the finish bar. Real InputEvents for every press,
# key, and motion under test.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan16_fields.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOP_PITCH := deg_to_rad(89.0)
const FILLET_IDLE := "Fillet r=1.50 — edit Radius, click edges, Enter"

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
	print("rung01 replan16 WP3 numeric fields / finish bar")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var ctx := await _boot()
	await _f1_replace(ctx)
	await _f2_format(ctx)
	await _shutdown(ctx)
	ctx = await _boot()
	await _f3_draw_fields(ctx)
	await _shutdown(ctx)
	ctx = await _boot()
	await _f3_a10(ctx)
	await _shutdown(ctx)
	ctx = await _boot()
	await _f4_save_finish(ctx)
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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.ops_panel != null and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
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


func _label(main) -> String:
	if main == null or main.status_label == null:
		return ""
	return str(main.status_label.text)


func _status_has(needle: String) -> bool:
	if _label(root.get_child(0) if root.get_child_count() > 0 else null).contains(needle):
		return true
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _push_key(vp: Viewport, code: int, unicode: int = 0, ctrl := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode if pressed else 0
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		ev.echo = false
		vp.push_input(ev)
		await process_frame
	await process_frame


func _push_char(vp: Viewport, ch: String) -> void:
	var code := KEY_NONE
	var unicode := ch.unicode_at(0)
	if unicode >= 48 and unicode <= 57:
		code = (KEY_0 + (unicode - 48)) as Key
	elif unicode == 46:
		code = KEY_PERIOD
	elif unicode == 45:
		code = KEY_MINUS
	else:
		push_error("no key for %s" % ch)
		return
	await _push_key(vp, code, unicode)


func _click_at(vp: Viewport, pos: Vector2, times: int = 1) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for _i in times:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = pos
			ev.global_position = pos
			vp.push_input(ev)
			await process_frame
	await process_frame


func _click_control(vp: Viewport, ctrl: Control) -> void:
	if ctrl == null:
		return
	FilmUI.ensure_control_visible(ctrl)
	await process_frame
	var r: Rect2 = ctrl.get_global_rect()
	await _click_at(vp, r.get_center())


func _spin_text_pos(spin: SpinBox) -> Vector2:
	var le: LineEdit = spin.get_line_edit()
	if le != null:
		var lr: Rect2 = le.get_global_rect()
		return Vector2(lr.position.x + minf(24.0, lr.size.x * 0.35), lr.get_center().y)
	var r: Rect2 = spin.get_global_rect()
	return Vector2(r.position.x + minf(r.size.x * 0.35, r.size.x - 24.0), r.get_center().y)


func _spin_arrow_pos(spin: SpinBox, up: bool) -> Vector2:
	var r: Rect2 = spin.get_global_rect()
	var le: LineEdit = spin.get_line_edit()
	var x := r.position.x + r.size.x - 8.0
	if le != null:
		var lr: Rect2 = le.get_global_rect()
		x = maxf(lr.position.x + lr.size.x + 6.0, r.position.x + r.size.x - 10.0)
		x = minf(x, r.position.x + r.size.x - 4.0)
	var y := r.position.y + r.size.y * (0.22 if up else 0.78)
	return Vector2(x, y)


func _line_text(le: LineEdit) -> String:
	return "" if le == null else str(le.text)


func _digits(text: String) -> String:
	var t := text.strip_edges()
	if t.ends_with(" mm"):
		t = t.substr(0, t.length() - 3)
	elif t.ends_with("mm"):
		t = t.substr(0, t.length() - 2)
	elif t.ends_with(" AF"):
		t = t.substr(0, t.length() - 3)
	return t.strip_edges()


func _fmt_mm(v: float) -> String:
	var scr := load("res://scripts/ui_spin.gd")
	if scr != null and scr.has_method("fmt_mm"):
		return str(scr.call("fmt_mm", v))
	if is_equal_approx(v, roundf(v)):
		return "%d mm" % int(roundf(v))
	var s := "%.4f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s + " mm"


func _strip(main) -> SpinBox:
	return main.interaction.find_child("StripRadius", true, false) as SpinBox


func _panel(main) -> SpinBox:
	return main.ops_panel._radius_spin as SpinBox


func _place_box(ctx: FilmContext) -> String:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	await process_frame
	if ctx.main.has_method("_update_panel_visibility"):
		ctx.main._update_panel_visibility()
	await process_frame
	return body


func _arm_fillet(ctx: FilmContext) -> void:
	var fillet: Button = ctx.main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "StripFillet is visible")
	if fillet == null:
		return
	await _click_control(ctx.main.get_viewport(), fillet)
	await process_frame
	await process_frame


func _agree_fmt(main, v: float, tag: String) -> void:
	var want := _fmt_mm(v)
	var strip := _strip(main)
	var panel := _panel(main)
	var stxt := _line_text(strip.get_line_edit() if strip != null else null)
	var ptxt := _line_text(panel.get_line_edit() if panel != null else null)
	print("  format %s: strip=`%s` panel=`%s` want=`%s`" % [tag, stxt, ptxt, want])
	check(stxt == want, "%s: strip text is %s (got `%s`)" % [tag, want, stxt])
	check(ptxt == want, "%s: panel text is %s (got `%s`)" % [tag, want, ptxt])
	check(stxt == ptxt, "%s: strip and panel texts match (`%s` vs `%s`)" % [tag, stxt, ptxt])
	check(not stxt.contains("10.0") and not ptxt.contains("10.0"),
			"%s: no 10.0 variant (strip `%s` panel `%s`)" % [tag, stxt, ptxt])
	if is_equal_approx(v, 10.0):
		check(stxt != "10" and ptxt != "10",
				"%s: 10 is not a bare 10 (strip `%s` panel `%s`)" % [tag, stxt, ptxt])


func _f1_replace(ctx: FilmContext) -> void:
	print("- F1 strip R and panel Radius replace on the first key")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	check(body != "", "F1 box placed")
	await _arm_fillet(ctx)
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "F1 Fillet armed")
	var strip := _strip(main)
	check(strip != null and strip.is_visible_in_tree(), "F1 StripRadius visible")
	if strip == null:
		return
	var before := _line_text(strip.get_line_edit())
	print("  F1 strip before triple-click `%s`" % before)
	await _click_at(vp, _spin_text_pos(strip), 3)
	await _push_char(vp, "1")
	var got := _digits(_line_text(strip.get_line_edit()))
	print("  F1 strip after key 1 `%s`" % _line_text(strip.get_line_edit()))
	check(got == "1", "F1 strip first key reads 1 (got `%s`, was `%s`)" % [got, before])
	check(got != "10" and got != "", "F1 strip first key is not 10 and not empty (got `%s`)" % got)
	await _push_char(vp, ".")
	await _push_char(vp, "5")
	got = _digits(_line_text(strip.get_line_edit()))
	print("  F1 strip after 1.5 `%s`" % _line_text(strip.get_line_edit()))
	check(got == "1.5", "F1 strip reads 1.5 (got `%s`)" % got)
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	check(_label(main) == FILLET_IDLE or _status_has(FILLET_IDLE),
			"F1 Enter status is `%s` (got `%s`)" % [FILLET_IDLE, _label(main)])

	var panel := _panel(main)
	check(panel != null, "F1 panel Radius exists")
	if panel != null:
		FilmUI.ensure_control_visible(panel)
		await process_frame
		await process_frame
		print("  F1 panel before triple-click `%s` rect %s" % [
			_line_text(panel.get_line_edit()), str(panel.get_global_rect())])
		await _click_at(vp, _spin_text_pos(panel), 3)
		await _push_char(vp, "1")
		got = _digits(_line_text(panel.get_line_edit()))
		print("  F1 panel after key 1 `%s`" % _line_text(panel.get_line_edit()))
		check(got == "1", "F1 panel first key reads 1 (got `%s`)" % got)
		check(got != "10" and got != "", "F1 panel first key is not 10 and not empty (got `%s`)" % got)
		await _push_char(vp, ".")
		await _push_char(vp, "5")
		got = _digits(_line_text(panel.get_line_edit()))
		check(got == "1.5", "F1 panel reads 1.5 (got `%s`)" % got)
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
		check(_label(main) == FILLET_IDLE or _status_has(FILLET_IDLE),
				"F1 panel Enter status (got `%s`)" % _label(main))

	if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		await _arm_fillet(ctx)
	strip = _strip(main)
	await _click_at(vp, _spin_text_pos(strip), 1)
	await _push_char(vp, "1")
	await _push_char(vp, "0")
	got = _digits(_line_text(strip.get_line_edit()))
	print("  F1 strip after click+10 `%s`" % _line_text(strip.get_line_edit()))
	check(got == "10", "F1 click then 10 reads 10 (got `%s`)" % got)
	check(not got.contains("100") and got != ".0" and not got.begins_with("."),
			"F1 10 is not 100 or a .0 fragment (got `%s`)" % got)
	await _push_key(vp, KEY_TAB)
	await process_frame
	await process_frame
	var owner: Control = vp.gui_get_focus_owner()
	var owner_cls := "null" if owner == null else owner.get_class()
	check(not (owner is LineEdit) and not (owner is SpinBox),
			"F1 Tab focus is not a LineEdit or SpinBox (got %s)" % owner_cls)
	var cam: OrbitCamera = main.camera
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	check(_label(main).contains("Top view") or _status_has("Top view"),
			"F1 key 3 is Top view (label `%s` pitch %.3f)" % [_label(main), cam.pitch])
	check(absf(cam.pitch - TOP_PITCH) < 0.05, "F1 camera pitch is Top (%.4f)" % cam.pitch)


func _f2_format(ctx: FilmContext) -> void:
	print("- F2 one number format in strip and panel")
	var spin_scr := load("res://scripts/ui_spin.gd")
	check(spin_scr != null and spin_scr.has_method("fmt_mm"), "F2 SxUi.fmt_mm exists")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		ctx.view.select_entity(ctx.view.selected_body, "")
		await process_frame
		await _arm_fillet(ctx)
	var strip := _strip(main)
	if strip == null:
		check(false, "F2 StripRadius visible")
		return
	await _click_at(vp, _spin_text_pos(strip), 3)
	await _push_char(vp, "1")
	await _push_char(vp, "0")
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	_agree_fmt(main, 10.0, "F2 type 10 Enter")

	await _click_at(vp, _spin_text_pos(strip), 3)
	await _push_char(vp, "1")
	await _push_char(vp, ".")
	await _push_char(vp, "5")
	await _push_key(vp, KEY_TAB)
	await process_frame
	await process_frame
	await process_frame
	_agree_fmt(main, 1.5, "F2 type 1.5 Tab")

	main.ops_panel.set_dressup_radius(2.0)
	await process_frame
	await process_frame
	_agree_fmt(main, 2.0, "F2 set_dressup_radius 2")
	strip = _strip(main)
	await _click_at(vp, _spin_arrow_pos(strip, true))
	await process_frame
	await process_frame
	_agree_fmt(main, 2.5, "F2 arrow up 2.5")
	await _click_at(vp, _spin_arrow_pos(strip, false))
	await process_frame
	await process_frame
	_agree_fmt(main, 2.0, "F2 arrow down 2")

	var panel := _panel(main)
	FilmUI.ensure_control_visible(panel)
	await process_frame
	await _click_at(vp, _spin_text_pos(panel), 3)
	await _push_char(vp, "0")
	await _push_char(vp, ".")
	await _push_char(vp, "2")
	await _push_char(vp, "5")
	var away := Vector2(float(ROOT_SIZE.x) - 80.0, 140.0)
	await _click_at(vp, away)
	await process_frame
	await process_frame
	await process_frame
	_agree_fmt(main, 0.25, "F2 focus exit 0.25")

	main.ops_panel.set_dressup_radius(10.0)
	await process_frame
	await process_frame
	_agree_fmt(main, 10.0, "F2 set_dressup_radius 10")
	main.ops_panel.set_dressup_radius(1.5)
	await process_frame
	_agree_fmt(main, 1.5, "F2 set_dressup_radius 1.5")
	main.ops_panel.set_dressup_radius(0.25)
	await process_frame
	_agree_fmt(main, 0.25, "F2 set_dressup_radius 0.25")


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	return chrome.find_child("DimLineEdit", true, false) as LineEdit if chrome != null else null


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit if chrome != null else null


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "on screen: %s" % desc)
	await _click_at(ctx.main.get_viewport(), screen)


func _press_rail(ctx: FilmContext, label: String) -> void:
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(b != null and b.is_visible_in_tree(), "rail %s is visible" % label)
	if b == null:
		return
	await _click_control(ctx.main.get_viewport(), b)
	await process_frame


func _f3_one_tool(ctx: FilmContext, label: String, keys: String, status_needle: String) -> void:
	print("- F3 %s first click then type" % label)
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var chrome: SketchContextChrome = main.sketch_chrome
	var sm: SketchMode = main.sketch_mode
	await _press_rail(ctx, label)
	await process_frame
	var dist := _distance_edit(chrome)
	var dist_before := _line_text(dist)
	print("  F3 %s distance before `%s`" % [label, dist_before])
	var n_before: int = sm.sketch.entity_ids().size() if sm.sketch != null else -1
	var pts_before: int = sm._tool_points.size()
	_status_log.clear()
	await _click_uv(ctx, Vector2(18, 12), "%s first click" % label)
	await process_frame
	await process_frame
	var dim := _dim_edit(chrome)
	var dist_focus := dist != null and dist.has_focus()
	var dim_focus := dim != null and dim.has_focus()
	print("  F3 %s after click status `%s` dim_focus=%s dist_focus=%s points=%d entities=%d" % [
		label, _label(main), str(dim_focus), str(dist_focus),
		sm._tool_points.size(), sm.sketch.entity_ids().size() if sm.sketch != null else -1])
	if label == "Circle":
		check(_label(main).contains("Circle — centre set, click the rim or type a radius") \
				or _status_has("Circle — centre set, click the rim or type a radius"),
				"F3 Circle centre status (got `%s`)" % _label(main))
		check(dim_focus, "F3 Circle Radius LineEdit has focus")
		check(not dist_focus, "F3 Circle Distance LineEdit does not have focus")
	elif label == "Slot":
		check(sm._tool_points.size() == pts_before + 1,
				"F3 Slot first click placed a centre (points %d was %d)" % [
					sm._tool_points.size(), pts_before])
	else:
		check(sm._tool_points.size() == pts_before + 1 or _label(main).contains("centre"),
				"F3 %s first click placed the centre (points %d status `%s`)" % [
					label, sm._tool_points.size(), _label(main)])
	for i in keys.length():
		await _push_char(vp, keys.substr(i, 1))
	dim = _dim_edit(chrome)
	var typed := _digits(_line_text(dim))
	print("  F3 %s radius field `%s` distance `%s`" % [label, typed, _line_text(_distance_edit(chrome))])
	check(typed == keys, "F3 %s radius reads %s (got `%s`)" % [label, keys, typed])
	check(_line_text(_distance_edit(chrome)) == dist_before,
			"F3 %s distance text unchanged (was `%s` now `%s`)" % [
				label, dist_before, _line_text(_distance_edit(chrome))])
	if label == "Circle":
		check(dist_before == "20.0 mm", "F3 Circle distance starts at 20.0 mm (got `%s`)" % dist_before)
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	check(_label(main).contains(status_needle) or _status_has(status_needle),
			"F3 %s status contains `%s` (got `%s`)" % [label, status_needle, _label(main)])
	if label == "Slot":
		check(sm.sketch.entity_ids().size() == n_before,
				"F3 Slot radius Enter does not commit geometry yet")


func _f3_slot_radius(ctx: FilmContext) -> void:
	print("- F3 Slot radius then first centre click")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var chrome: SketchContextChrome = main.sketch_chrome
	var sm: SketchMode = main.sketch_mode
	await _press_rail(ctx, "Slot")
	await process_frame
	var dist_before := _line_text(_distance_edit(chrome))
	_status_log.clear()
	await _push_char(vp, "5")
	var typed := _digits(_line_text(_dim_edit(chrome)))
	print("  F3 Slot after key 5 radius `%s` distance `%s` focus dim=%s dist=%s" % [
		_line_text(_dim_edit(chrome)), _line_text(_distance_edit(chrome)),
		str(_dim_edit(chrome) != null and _dim_edit(chrome).has_focus()),
		str(_distance_edit(chrome) != null and _distance_edit(chrome).has_focus())])
	check(typed == "5", "F3 Slot radius reads 5 (got `%s`)" % typed)
	check(_line_text(_distance_edit(chrome)) == dist_before,
			"F3 Slot distance unchanged while typing radius (was `%s` now `%s`)" % [
				dist_before, _line_text(_distance_edit(chrome))])
	await _push_key(vp, KEY_ENTER)
	await process_frame
	check(_label(main).contains("Slot radius 5.0000") or _status_has("Slot radius 5.0000"),
			"F3 Slot status contains Slot radius 5.0000 (got `%s`)" % _label(main))
	var pts_before: int = sm._tool_points.size()
	await _click_uv(ctx, Vector2(22, -6), "Slot first centre")
	await process_frame
	check(sm._tool_points.size() == pts_before + 1,
			"F3 Slot first click placed the centre (points %d was %d, status `%s`)" % [
				sm._tool_points.size(), pts_before, _label(main)])


func _f3_draw_fields(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	check(ctx.main.sketch_mode.active, "F3 sketch active")
	await _f3_one_tool(ctx, "Circle", "50", "Circle r=50.0000 (Ø100.0000)")
	await _f3_one_tool(ctx, "Polygon", "20", "Polygon AF 20.0000 — flats horizontal")
	await _f3_slot_radius(ctx)


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		bar = main.find_child("FileMenu", true, false)
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


func _item_screen_center(popup: PopupMenu, index: int) -> Vector2:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		y += _popup_row_height(popup, i, font_h, v_sep)
	y += _popup_row_height(popup, index, font_h, v_sep) * 0.5
	return Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)


func _click_menu_item(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button visible for %s" % [title, desc])
		return false
	await _click_control(ctx.main.get_viewport(), btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	if popup == null or not popup.visible:
		check(false, "%s popup visible (%s)" % [title, desc])
		return false
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "popup has item %d (%s)" % [id, desc])
		return false
	popup.reset_size()
	await process_frame
	var screen: Vector2 = _item_screen_center(popup, idx)
	var got: Array = [-1]
	var cb := func(pressed_id: int) -> void:
		got[0] = pressed_id
	popup.id_pressed.connect(cb)
	await _click_at(ctx.main.get_viewport(), screen)
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	return got[0] == id


func _file_new(ctx: FilmContext) -> void:
	var opened: bool = await _click_menu_item(ctx, "File", 0, "File → New")
	check(opened, "F3 A10 File → New was clicked")
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	var shown := false
	for _i in 8:
		await process_frame
		if dlg != null and dlg.visible:
			shown = true
			break
	print("  F3 A10 discard dialog visible=%s dirty=%s" % [
		str(shown), str(ctx.main._document_is_dirty())])
	if shown:
		var ok := dlg.get_ok_button()
		if ok != null:
			var screen := ok.get_screen_position() + ok.size * 0.5
			await _click_at(ctx.main.get_viewport(), screen)
			await process_frame
			if dlg.visible:
				var local := ok.get_global_rect().get_center()
				await _click_at(ok.get_viewport(), local)
				await process_frame
		if dlg.visible:
			await _push_key(ok.get_viewport() if ok != null else ctx.main.get_viewport(), KEY_ENTER)
			await process_frame
	await process_frame


func _f3_a10(ctx: FilmContext) -> void:
	print("- F3 A10 extrude, New, sketch, Circle, first click, type")
	var main = ctx.main
	await FilmUI.enter_sketch(ctx)
	check(main.sketch_mode.active, "F3 A10 sketch active before extrude")
	main.sketch_mode.sketch.add_circle(0, 0, 8)
	main.sketch_mode._redraw()
	await process_frame
	var extrude: Button = main.sketch_chrome.extrude_button() if main.sketch_chrome != null else null
	check(extrude != null and extrude.is_visible_in_tree(), "F3 A10 Extrude button visible")
	if extrude != null:
		await _click_control(main.get_viewport(), extrude)
		await process_frame
		await process_frame
		await process_frame
	print("  F3 A10 after Extrude status `%s` active=%s shield=%s" % [
		_label(main), str(main.sketch_mode.active),
		str(main.interaction._finish_click_shield_armed)])
	check(not main.sketch_mode.active, "F3 A10 Extrude left the sketch")
	await _file_new(ctx)
	check(_label(main).contains("New — empty part"),
			"F3 A10 New status (got `%s`)" % _label(main))
	var sketch_btn := FilmUI.find_palette_sketch_button(main)
	check(sketch_btn != null, "F3 A10 rail Sketch exists")
	await _click_control(main.get_viewport(), sketch_btn)
	await process_frame
	var ground := FilmUI.model_to_screen(ctx, Vector3(16, 12, 0))
	check(FilmUI.require_on_screen(ctx, ground, "A10 ground"), "F3 A10 ground click on screen")
	await _click_at(main.get_viewport(), ground)
	await process_frame
	await process_frame
	await process_frame
	check(main.sketch_mode.active, "F3 A10 ground click started a sketch (status `%s`)" % _label(main))
	if not main.sketch_mode.active:
		return
	await _press_rail(ctx, "Circle")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist_before := _line_text(_distance_edit(chrome))
	var shield: bool = main.interaction._finish_click_shield_armed
	print("  F3 A10 before first click shield=%s distance=`%s` focus=%s" % [
		str(shield), dist_before,
		"null" if main.get_viewport().gui_get_focus_owner() == null \
				else main.get_viewport().gui_get_focus_owner().get_class()])
	_status_log.clear()
	await _click_uv(ctx, Vector2(14, 9), "A10 Circle first click")
	await process_frame
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var dim := _dim_edit(chrome)
	print("  F3 A10 after click status `%s` points=%d dim_focus=%s dist_focus=%s" % [
		_label(main), sm._tool_points.size(),
		str(dim != null and dim.has_focus()),
		str(_distance_edit(chrome) != null and _distance_edit(chrome).has_focus())])
	check(sm._tool_points.size() == 1,
			"F3 A10 first click placed the centre (points %d, shield was %s, status `%s`)" % [
				sm._tool_points.size(), str(shield), _label(main)])
	check(_label(main).contains("Circle — centre set") or _status_has("Circle — centre set"),
			"F3 A10 centre status (got `%s`)" % _label(main))
	check(dim != null and dim.has_focus(), "F3 A10 Radius has focus after the first click")
	check(_distance_edit(chrome) == null or not _distance_edit(chrome).has_focus(),
			"F3 A10 Distance does not have focus")
	await _push_char(main.get_viewport(), "5")
	await _push_char(main.get_viewport(), "0")
	var typed := _digits(_line_text(_dim_edit(chrome)))
	print("  F3 A10 typed radius `%s` distance `%s`" % [
		_line_text(_dim_edit(chrome)), _line_text(_distance_edit(chrome))])
	check(typed == "50", "F3 A10 radius reads 50 (got `%s`)" % typed)
	check(_line_text(_distance_edit(chrome)) == dist_before,
			"F3 A10 distance unchanged (was `%s` now `%s`)" % [
				dist_before, _line_text(_distance_edit(chrome))])


func _top_face(view: DocumentView, body: String) -> String:
	var best := ""
	var best_z := -INF
	if view.doc == null or not view.doc.has_method("get_face_ids"):
		return ""
	for fid in view.doc.get_face_ids(body):
		var mid: Variant = view.doc.face_midpoint(str(fid))
		if mid is Vector3 and (mid as Vector3).z > best_z:
			best_z = (mid as Vector3).z
			best = str(fid)
	return best


func _pick_option(ctx: FilmContext, option: OptionButton, index: int, desc: String) -> void:
	if option == null:
		check(false, "%s option exists" % desc)
		return
	FilmUI.ensure_control_visible(option)
	await process_frame
	await _click_control(ctx.main.get_viewport(), option)
	var popup := option.get_popup()
	if popup == null:
		check(false, "%s popup" % desc)
		return
	popup.reset_size()
	await process_frame
	var screen := _item_screen_center(popup, index)
	await _click_at(ctx.main.get_viewport(), screen)
	await process_frame
	check(option.selected == index, "%s selected index %d (got %d)" % [desc, index, option.selected])


func _finish_dict(chrome: SketchContextChrome) -> Dictionary:
	if chrome != null and chrome.has_method("finish_snapshot"):
		return chrome.finish_snapshot()
	return {}


func _f4_save_finish(ctx: FilmContext) -> void:
	print("- F4 Save inside a sketch keeps the finish bar")
	var main = ctx.main
	var body := await _place_box(ctx)
	var face := _top_face(ctx.view, body)
	check(face != "", "F4 top face resolved")
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	check(main.sketch_mode.active, "F4 face sketch active (status `%s`)" % _label(main))
	if not main.sketch_mode.active:
		return
	await _press_rail(ctx, "Circle")
	await _click_uv(ctx, Vector2(4, 3), "F4 circle centre")
	await process_frame
	await _push_char(main.get_viewport(), "4")
	await _push_key(main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = main.sketch_chrome
	var op: OptionButton = chrome.find_child("FinishOp", true, false)
	var endb: OptionButton = chrome.find_child("FinishEnd", true, false)
	await _pick_option(ctx, op, 1, "F4 Cut")
	await _pick_option(ctx, endb, 3, "F4 Up To Surface")
	var opp: Button = chrome.opposite_face_button()
	check(opp != null and opp.is_visible_in_tree(), "F4 Opposite face is visible")
	await _click_control(main.get_viewport(), opp)
	await process_frame
	var face_lbl: Label = chrome.find_child("UpToFaceLabel", true, false)
	print("  F4 face label `%s` id `%s`" % [
		str(face_lbl.text) if face_lbl != null else "", chrome.up_to_face_id])
	check(face_lbl != null and str(face_lbl.text).contains("Face: z 0.0 mm"),
			"F4 opposite face reads Face: z 0.0 mm (got `%s`)" % (
				str(face_lbl.text) if face_lbl != null else ""))
	var dist := _distance_edit(chrome)
	await _click_at(main.get_viewport(), dist.get_global_rect().get_center())
	await _push_char(main.get_viewport(), "7")
	print("  F4 distance after key 7 `%s`" % _line_text(dist))
	check(_digits(_line_text(dist)) == "7" or _digits(_line_text(dist)) == "7.0",
			"F4 Distance reads 7 (got `%s`)" % _line_text(dist))
	var thin: CheckButton = chrome.find_child("ThinFeature", true, false)
	await _click_control(main.get_viewport(), thin)
	await process_frame
	var flip: CheckButton = chrome.find_child("FlipSide", true, false)
	check(flip != null and flip.is_visible_in_tree(), "F4 Flip is visible")
	await _click_control(main.get_viewport(), flip)
	await process_frame
	check(flip.button_pressed, "F4 flip is on")
	var path := "/tmp/sx-replan16-fields.sxp"
	main.current_path = path
	var before: Dictionary = _finish_dict(chrome)
	check(not before.is_empty(), "F4 finish_snapshot before save")
	print("  F4 snapshot before %s" % str(before))
	var extrude: Button = chrome.extrude_button()
	check(extrude != null and not extrude.disabled, "F4 Extrude enabled before save")
	_status_log.clear()
	await _push_key(main.get_viewport(), KEY_S, 0, true)
	await process_frame
	await process_frame
	await process_frame
	var after: Dictionary = _finish_dict(chrome)
	print("  F4 snapshot after %s" % str(after))
	print("  F4 status after save `%s`" % _label(main))
	check(after == before, "F4 finish_snapshot unchanged by Save")
	check(_label(main) == "Saved " + path or _status_has("Saved " + path),
			"F4 status is Saved %s (got `%s`)" % [path, _label(main)])
	extrude = chrome.extrude_button()
	check(extrude != null and not extrude.disabled, "F4 Extrude still enabled after Save")
	check(main.sketch_mode.active, "F4 still in the sketch after Save")
	_status_log.clear()
	await _push_key(main.get_viewport(), KEY_Z, 0, true)
	await process_frame
	check(_label(main).begins_with("Undo:"),
			"F4 Ctrl+Z status begins Undo: (got `%s`)" % _label(main))
