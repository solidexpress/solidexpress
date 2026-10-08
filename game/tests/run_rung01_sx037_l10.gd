# sx-037 L10 — finish-bar Distance commits on Enter and releases the keyboard.
# type 10 Enter, type 14 Enter → 14, click again, type 10 → 10.
# A frame between digits must not turn "10" into "0". Enter gives the next
# key to the viewport; the following number still replaces the committed value.
# Circle radius, Slot (same blank), Smart Dim, and Fillet R share the
# select / submit path and are checked the same way.
# A fresh click must own the keyboard: 1.5 stays 1.5, Ctrl+A selects the
# field text (not every face), and Circle's 5 does not land in Extrude.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx037_l10.gd
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
	print("rung01 sx037 L10 numeric commit focus")
	FilmUI.reset_fail_count()
	await _distance_l10()
	await _dim_blank_refocus()
	await _fillet_radius_commit()
	await _circle_radius_not_extrude()
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


func _distance_l10() -> void:
	print("- L10 Distance: 10 Enter, 14 Enter, click, 10")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await _draw_closed_rect(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	check(dist != null, "DistanceLineEdit exists")
	if dist == null:
		await _shutdown(ctx)
		return
	await _x11_click(dist)
	check(dist.has_focus(), "Distance click focuses the field")
	await _type_gap(dist, "10")
	check(_near(_parsed(dist), 10.0), "typed 10 reads 10 before Enter (got '%s')" % dist.text)
	await _x11_enter(dist.get_viewport())
	await _assert_committed(dist, 10.0, 20.0, "after 10 Enter")
	# No second click: the next number must replace the committed 10.
	await _type_gap(dist, "14")
	check(_near(_parsed(dist), 14.0), "typed 14 without a re-click (got '%s')" % dist.text)
	await _x11_enter(dist.get_viewport())
	await _assert_committed(dist, 14.0, 10.0, "after 14 Enter")
	await _x11_click(dist)
	check(dist.has_focus() and dist.is_editing(),
			"click-refocus is really editing (focus %s editing %s)" % [
				str(dist.has_focus()), str(dist.is_editing())])
	await _type_gap(dist, "10")
	check(_near(_parsed(dist), 10.0),
			"click-refocus then 10 reads 10, not 0 (got '%s')" % dist.text)
	check(not _digits(dist).begins_with("0"),
			"click-refocus did not drop the first digit (got '%s')" % dist.text)
	await _x11_enter(dist.get_viewport())
	await _assert_committed(dist, 10.0, 14.0, "after refocus 10 Enter")
	var spin := dist.get_parent() as SpinBox
	check(spin != null and _near(spin.value, 10.0),
			"Distance spin value ends at 10 (got %s)" % str(spin.value if spin else "null"))
	await _shutdown(ctx)


func _dim_blank_refocus() -> void:
	print("- Circle radius blank: Enter does not half-focus; click then 10")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _click_uv(ctx, Vector2.ZERO, "Circle centre")
	var dim := _dim_edit(ctx.main.sketch_chrome)
	check(dim != null, "DimLineEdit exists")
	if dim == null:
		await _shutdown(ctx)
		return
	await _x11_click(dim)
	check(dim.has_focus(), "radius click focuses DimLineEdit")
	await _type_gap(dim, "10")
	check(_near(_parsed(dim), 10.0), "radius typed 10 (got '%s')" % dim.text)
	await _x11_enter(dim.get_viewport())
	await process_frame
	await process_frame
	_assert_not_half_focused(dim, "radius after Enter")
	await _x11_click(dim)
	await _type_gap(dim, "10")
	check(_near(_parsed(dim), 10.0),
			"radius click-refocus then 10 reads 10, not 0 (got '%s')" % dim.text)
	await _shutdown(ctx)


func _fillet_radius_commit() -> void:
	print("- Fillet R and panel Radius: click owns keys, 1.5, Ctrl+A")
	var ctx := await _boot()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	await process_frame
	if ctx.main.has_method("_update_panel_visibility"):
		ctx.main._update_panel_visibility()
	await process_frame
	var fillet: Button = ctx.main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "StripFillet is visible")
	if fillet != null:
		await _x11_click(fillet)
	await process_frame
	await process_frame
	var strip: SpinBox = ctx.main.interaction.find_child("StripRadius", true, false)
	check(strip != null and strip.is_visible_in_tree(), "StripRadius visible")
	if strip == null:
		await _shutdown(ctx)
		return
	var line := strip.get_line_edit()
	var faces_before := ctx.view.selected_faces.size()
	var pending_before: int = ctx.main.ops_panel._pending
	await _x11_click_at(line, 0.82)
	await process_frame
	check(line.has_focus() and line.is_editing(),
			"strip R click is real keyboard focus (focus %s editing %s)" % [
				str(line.has_focus()), str(line.is_editing())])
	_status_log.clear()
	await _type_gap(line, "10")
	check(_near(_parsed(line), 10.0), "strip R typed 10 (got '%s')" % line.text)
	check(not _status_has("Front view") and not _status_has("No view for key 0"),
			"strip R first 10 did not change the view (%s)" % str(_status_log))
	await _x11_ctrl_a(line.get_viewport())
	await process_frame
	check(line.has_focus() and line.has_selection(),
			"Ctrl+A selects strip R text (focus %s sel %s '%s')" % [
				str(line.has_focus()), str(line.has_selection()), line.text])
	check(ctx.main.ops_panel._pending == pending_before,
			"Ctrl+A left Fillet armed (pending %s)" % str(ctx.main.ops_panel._pending))
	check(ctx.view.selected_faces.size() == faces_before,
			"Ctrl+A did not select faces (%d → %d)" % [
				faces_before, ctx.view.selected_faces.size()])
	await _x11_enter(line.get_viewport())
	await process_frame
	await process_frame
	_assert_not_half_focused(line, "strip R after Enter")
	var owner: Control = line.get_viewport().gui_get_focus_owner()
	check(owner == null or not (owner is LineEdit),
			"strip R Enter left the keyboard (owner %s)" % (
				"null" if owner == null else owner.get_class()))
	await _x11_click_at(line, 0.82)
	await process_frame
	_status_log.clear()
	await _type_gap(line, "1.5")
	check(_near(_parsed(line), 1.5),
			"strip R fresh click then 1.5 reads 1.5, not 15 (got '%s')" % line.text)
	check(not _status_has("Front view") and not _status_has("No view for key 0"),
			"strip R 1.5 did not change the view (%s)" % str(_status_log))
	var panel: SpinBox = ctx.main.ops_panel._radius_spin
	check(panel != null, "panel Radius exists")
	if panel != null:
		var panel_line := panel.get_line_edit()
		FilmUI.ensure_control_visible(panel)
		await process_frame
		await _x11_click_at(panel_line, 0.82)
		await process_frame
		check(panel_line.has_focus() and panel_line.is_editing(),
				"panel Radius click is real keyboard focus (focus %s editing %s)" % [
					str(panel_line.has_focus()), str(panel_line.is_editing())])
		_status_log.clear()
		await _type_gap(panel_line, "1.5")
		check(_near(_parsed(panel_line), 1.5),
				"panel Radius fresh click then 1.5 reads 1.5, not 15 (got '%s')" % panel_line.text)
		check(not _status_has("Front view") and not _status_has("No view for key 0"),
				"panel Radius 1.5 did not change the view (%s)" % str(_status_log))
		await _x11_ctrl_a(panel_line.get_viewport())
		await process_frame
		check(panel_line.has_focus() and panel_line.has_selection(),
				"Ctrl+A selects panel Radius text (focus %s sel %s)" % [
					str(panel_line.has_focus()), str(panel_line.has_selection())])
		check(ctx.main.ops_panel._pending == pending_before,
				"panel Ctrl+A left Fillet armed")
		await _x11_enter(panel_line.get_viewport())
		await process_frame
		_assert_not_half_focused(panel_line, "panel Radius after Enter")
	await _shutdown(ctx)


func _circle_radius_not_extrude() -> void:
	print("- Circle armed: 5 goes to Radius, not Extrude")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await process_frame
	var dim := _dim_edit(ctx.main.sketch_chrome)
	var dist := _distance_edit(ctx.main.sketch_chrome)
	check(dim != null and dist != null, "Circle radius and Extrude fields exist")
	if dim == null or dist == null:
		await _shutdown(ctx)
		return
	var dist_before := _parsed(dist)
	check(dim.has_focus() and dim.is_editing(),
			"Circle radius owns the keyboard (focus %s editing %s owner %s)" % [
				str(dim.has_focus()), str(dim.is_editing()), _owner_name(dim)])
	await _type_gap(dim, "5")
	check(_near(_parsed(dim), 5.0),
			"Circle radius typed 5 (got '%s')" % dim.text)
	check(_near(_parsed(dist), dist_before),
			"Extrude stayed %s when Circle radius took 5 (got '%s')" % [
				_num(dist_before), dist.text])
	await _shutdown(ctx)


func _assert_committed(edit: LineEdit, want: float, previous: float, tag: String) -> void:
	await process_frame
	var now := _parsed(edit)
	check(_near(now, want), "%s reads %s (got '%s')" % [tag, _num(want), edit.text])
	check(not _near(now, previous),
			"%s does not still show %s (got '%s')" % [tag, _num(previous), edit.text])
	_assert_not_half_focused(edit, tag)
	check(not edit.has_focus(),
			"%s releases the keyboard (focus %s editing %s text '%s')" % [
				tag, str(edit.has_focus()), str(edit.is_editing()), edit.text])
	await process_frame
	var later := _parsed(edit)
	check(_near(later, want),
			"%s still %s one frame later (got '%s')" % [tag, _num(want), edit.text])
	check(not _near(later, previous),
			"%s one frame later is not the previous value (got '%s')" % [tag, edit.text])


func _assert_not_half_focused(edit: LineEdit, tag: String) -> void:
	var half := edit.has_focus() and not edit.is_editing()
	check(not half, "%s is not focused-but-dead (focus %s editing %s)" % [
		tag, str(edit.has_focus()), str(edit.is_editing())])


func _type_gap(edit: LineEdit, text: String) -> void:
	var vp := edit.get_viewport()
	for i in text.length():
		await _x11_type(vp, text.substr(i, 1))
		await process_frame


func _parsed(edit: LineEdit) -> float:
	var digits := _digits(edit)
	if digits.is_empty() or not digits.is_valid_float():
		return NAN
	return float(digits)


func _digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := str(edit.text).strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	elif text.ends_with(" AF"):
		text = text.substr(0, text.length() - 3)
	return text.strip_edges()


func _near(v: float, want: float) -> bool:
	return not is_nan(v) and absf(v - want) < 0.001


func _num(v: float) -> String:
	return str(v)


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _draw_closed_rect(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	await _click_uv(ctx, Vector2(-15, -10), "Rect corner A")
	await _click_uv(ctx, Vector2(15, 10), "Rect corner B")
	await process_frame
	var closed := false
	if sm != null and sm.sketch != null:
		for id in sm.sketch.entity_ids():
			var info: Dictionary = sm.sketch.entity_info(id)
			if str(info.get("type", "")) == "rect" or str(info.get("type", "")) == "line":
				closed = true
				break
	check(closed, "sketch has a closed profile")


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
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	vp.push_input(up)
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
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


func _status_has(fragment: String) -> bool:
	for row in _status_log:
		if row.find(fragment) >= 0:
			return true
	return false


func _owner_name(ctrl: Control) -> String:
	if ctrl == null:
		return "null"
	var vp := ctrl.get_viewport()
	if vp == null:
		return "no-vp"
	var owner: Control = vp.gui_get_focus_owner()
	if owner == null:
		return "none"
	return "%s/%s" % [owner.name, owner.get_class()]


func _x11_click(ctrl: Control) -> void:
	await _x11_click_at(ctrl, 0.5)


func _x11_click_at(ctrl: Control, x_frac: float) -> void:
	if ctrl == null:
		return
	var rect := ctrl.get_global_rect()
	var pos := Vector2(rect.position.x + rect.size.x * x_frac,
			rect.position.y + rect.size.y * 0.5)
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
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_ctrl_a(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.physical_keycode = KEY_A
	ev.unicode = 97
	ev.ctrl_pressed = true
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
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
