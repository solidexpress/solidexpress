# re-PLAN 20 WP6 — a Distance prefix is not a parameter write.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_distance.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan20 distance")
	FilmUI.reset_fail_count()
	await _story()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _story() -> void:
	var ctx := await _boot()
	var ex := await _build(ctx, "4")
	if ex == "":
		return
	await _case_prefix(ctx, ex)
	await _case_enter(ctx, ex)
	await _case_esc_and_focus(ctx, ex)
	await _case_arrows_and_burst(ctx, ex)
	await _case_tight_fillet(ctx)


func _boot() -> FilmContext:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	main.sketch_mode.status.connect(func(t: String) -> void: _log.append(t))
	if main.timeline != null and main.timeline.property_panel != null:
		main.timeline.property_panel.status.connect(func(t: String) -> void: _log.append(t))
	if main.ops_panel != null:
		main.ops_panel.status.connect(func(t: String) -> void: _log.append(t))
	return ctx


func _build(ctx: FilmContext, radius_text: String) -> String:
	print("- circle, extrude 10, fillet r%s" % radius_text)
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector2.ZERO, 4.0)
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, Vector2.ZERO, "circle centre")
	await process_frame
	await _type_into_dim(ctx, "10")
	check(_saw("Circle r=10.0000") or str(ctx.main.status_label.text).contains("Circle r=10.0000"),
			"circle r=10 (got '%s')" % ctx.main.status_label.text)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_option(ctx, chrome.find_child("FinishEnd", true, false) as OptionButton, 0)
	await _pick_option(ctx, chrome.find_child("FinishOp", true, false) as OptionButton, 0)
	var dist: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(dist != null, "finish DistanceLineEdit exists")
	if dist != null:
		_click_at(dist.get_global_rect().get_center(), ctx)
		await process_frame
		_type_text(ctx.main.get_viewport(), "10")
		await process_frame
	var extrude: Button = chrome.extrude_button()
	_log.clear()
	await FilmUI.click_control(ctx, extrude, FilmUICues.alert("Click", "Extrude"))
	await process_frame
	await process_frame
	await process_frame
	check(_saw("Extrude Blind 10") or str(ctx.main.status_label.text).contains("Extrude Blind 10"),
			"Extrude Blind 10 (got '%s')" % ctx.main.status_label.text)
	var ex := _extrude_id(ctx)
	check(ex != "", "extrude feature exists")
	await _key(ctx, KEY_ESCAPE)
	await _key(ctx, KEY_ESCAPE)
	await process_frame
	if ctx.view.doc.body_ids().is_empty():
		check(false, "extrude produced a body")
		return ""
	var body: String = ctx.view.doc.body_ids()[0]
	await _key(ctx, KEY_3)
	await _key(ctx, KEY_F)
	await process_frame
	var on_part := FilmUI.model_to_screen(ctx, Vector3(0, 0, 5))
	_click_at(on_part, ctx)
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	var fillet := ctx.main.interaction.find_child("StripFillet", true, false) as Button
	if fillet == null:
		fillet = FilmUI.find_button(ctx.main, "Fillet")
	check(fillet != null, "Fillet button is visible")
	if fillet != null:
		await FilmUI.click_control(ctx, fillet, FilmUICues.alert("Click", "Fillet"))
		await process_frame
		await process_frame
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES,
			"Fillet is armed (status '%s')" % ctx.main.status_label.text)
	var radius := _radius_edit(ctx)
	if radius != null:
		_click_at(radius.get_global_rect().get_center(), ctx)
		await process_frame
		_type_text(ctx.main.get_viewport(), radius_text)
		await _key(ctx, KEY_ENTER)
		await process_frame
	var face := FilmUI.model_to_screen(ctx, Vector3(0, 0, 10))
	_click_at(face, ctx)
	await process_frame
	await process_frame
	check(str(ctx.main.status_label.text).contains("edge"),
			"top face selects edges (got '%s')" % ctx.main.status_label.text)
	ctx.main.interaction.return_viewport_keys()
	await process_frame
	await _key(ctx, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	var n := _count_type(ctx, "fillet")
	check(n >= 1, "fillet r%s committed (got %d, status '%s')" % [radius_text, n, ctx.main.status_label.text])
	return ex


func _case_prefix(ctx: FilmContext, ex: String) -> void:
	print("- prefix 1 is not a write")
	var edit := await _open_distance(ctx, ex)
	check(edit != null and edit.has_focus(), "double-click focuses Distance")
	if edit == null:
		return
	var sel := edit.get_selected_text()
	check(sel != "" and sel == edit.text, "Distance text is selected ('%s' of '%s')" % [sel, edit.text])
	var before := _param(ctx, ex, "distance")
	var err_before := str(ctx.view.doc.last_graph_error())
	_log.clear()
	_type_text(ctx.main.get_viewport(), "1")
	for _i in 300:
		await process_frame
	var blob := _blob(ctx)
	check(not blob.contains("Preview: distance = 1.0"),
			"prefix 1 has no Preview: distance = 1.0 (got '%s')" % blob)
	check(not blob.contains("Value rejected"), "prefix 1 has no Value rejected (got '%s')" % blob)
	check(str(ctx.view.doc.last_graph_error()) == err_before,
			"prefix 1 adds no graph error ('%s')" % str(ctx.view.doc.last_graph_error()))
	check(is_equal_approx(_param(ctx, ex, "distance"), before),
			"distance stays %.3f (got %.3f)" % [before, _param(ctx, ex, "distance")])
	check(str(edit.text).begins_with("1"), "the line shows the prefix (got '%s')" % edit.text)


func _case_enter(ctx: FilmContext, ex: String) -> void:
	print("- 14 commits on Enter")
	var edit := _distance_edit(ctx)
	if edit == null or not edit.has_focus():
		edit = await _open_distance(ctx, ex)
	if edit == null:
		check(false, "Distance still open for 14")
		return
	_log.clear()
	_type_text(ctx.main.get_viewport(), "4")
	await process_frame
	check(str(edit.text).contains("14"), "the line reads 14 (got '%s')" % edit.text)
	check(is_equal_approx(_param(ctx, ex, "distance"), 10.0),
			"14 is not written before Enter (got %.3f)" % _param(ctx, ex, "distance"))
	_log.clear()
	await _key(ctx, KEY_ENTER)
	await process_frame
	await process_frame
	check(_saw("Preview: distance = 14.0") or str(ctx.main.status_label.text).contains("Preview: distance = 14.0"),
			"Enter previews distance 14.0 (got '%s')" % ctx.main.status_label.text)
	check(is_equal_approx(_param(ctx, ex, "distance"), 14.0),
			"param is 14 after Enter (got %.3f)" % _param(ctx, ex, "distance"))
	check(_count_type(ctx, "fillet") >= 1, "the fillet survives distance 14")
	if ctx.main.timeline.property_panel != null and ctx.main.timeline.property_panel.visible:
		ctx.main.timeline.property_panel.commit()
		await process_frame


func _case_esc_and_focus(ctx: FilmContext, ex: String) -> void:
	print("- Esc cancels, focus-exit commits once")
	var edit := await _open_distance(ctx, ex)
	if edit == null:
		check(false, "Distance opens for Esc")
		return
	var before := _param(ctx, ex, "distance")
	_log.clear()
	_type_text(ctx.main.get_viewport(), "1")
	await process_frame
	await _key(ctx, KEY_ESCAPE)
	await process_frame
	await process_frame
	check(_saw("Edits cancelled") or str(ctx.main.status_label.text) == "Edits cancelled",
			"Esc says Edits cancelled (got '%s')" % ctx.main.status_label.text)
	check(is_equal_approx(_param(ctx, ex, "distance"), before),
			"Esc leaves distance %.3f (got %.3f)" % [before, _param(ctx, ex, "distance")])
	check(not _blob(ctx).contains("Value rejected"), "Esc has no Value rejected")
	edit = await _open_distance(ctx, ex)
	if edit == null:
		check(false, "Distance reopens for focus-exit")
		return
	_log.clear()
	_type_text(ctx.main.get_viewport(), "1")
	await process_frame
	_type_text(ctx.main.get_viewport(), "2")
	await process_frame
	var previews := _count_needle("Preview: distance")
	_click_at(Vector2(1100, 500), ctx)
	await process_frame
	await process_frame
	await process_frame
	check(is_equal_approx(_param(ctx, ex, "distance"), 12.0),
			"focus-exit commits 12 (got %.3f)" % _param(ctx, ex, "distance"))
	var after := _count_needle("Preview: distance")
	check(after - previews == 1, "focus-exit previews once (got %d)" % (after - previews))


func _case_arrows_and_burst(ctx: FilmContext, ex: String) -> void:
	print("- arrows and a one-burst Enter")
	var edit := await _open_distance(ctx, ex)
	if edit == null:
		check(false, "Distance opens for arrows")
		return
	var before := _param(ctx, ex, "distance")
	var spin: SpinBox = edit.get_parent() as SpinBox
	check(spin != null and spin.is_visible_in_tree(), "Distance spin is on screen")
	if spin == null:
		return
	var up := _arrow_pos(spin, true)
	var down := _arrow_pos(spin, false)
	var gutter := spin.get_global_rect()
	check(up.x > gutter.position.x + gutter.size.x * 0.68 and down.y > up.y,
			"▲ / ▼ sit in the spin gutter")
	_log.clear()
	_click_at(up, ctx)
	await process_frame
	await process_frame
	check(is_equal_approx(_param(ctx, ex, "distance"), before + 1.0),
			"▲ commits %.3f (got %.3f)" % [before + 1.0, _param(ctx, ex, "distance")])
	check(_saw("Preview: distance"), "▲ emits a preview")
	var mid := _param(ctx, ex, "distance")
	_click_at(down, ctx)
	await process_frame
	await process_frame
	check(is_equal_approx(_param(ctx, ex, "distance"), mid - 1.0),
			"▼ commits %.3f (got %.3f)" % [mid - 1.0, _param(ctx, ex, "distance")])
	edit = _distance_edit(ctx)
	if edit == null or not edit.has_focus():
		edit = await _open_distance(ctx, ex)
	if edit == null:
		check(false, "Distance opens for the burst")
		return
	_log.clear()
	_type_text(ctx.main.get_viewport(), "14")
	await process_frame
	var burst_previews := _count_needle("Preview: distance = 14")
	await _key(ctx, KEY_ENTER)
	await process_frame
	await process_frame
	check(_count_needle("Preview: distance = 14") - burst_previews == 1,
			"burst 14 previews once on Enter")
	check(is_equal_approx(_param(ctx, ex, "distance"), 14.0),
			"burst commits 14 (got %.3f)" % _param(ctx, ex, "distance"))


func _case_tight_fillet(ctx: FilmContext) -> void:
	print("- fillet 0.5 limit, prefix 1")
	await _file_new(ctx)
	var ex := await _build(ctx, "0.5")
	if ex == "":
		check(false, "tight fillet part exists")
		return
	var edit := await _open_distance(ctx, ex)
	if edit == null:
		check(false, "Distance opens on the tight part")
		return
	var err_before := str(ctx.view.doc.last_graph_error())
	_log.clear()
	_type_text(ctx.main.get_viewport(), "1")
	for _i in 60:
		await process_frame
	var blob := _blob(ctx)
	check(not blob.contains("Value rejected"), "tight prefix has no Value rejected (got '%s')" % blob)
	check(not blob.contains("regenerate stopped"), "tight prefix has no regenerate stopped")
	check(str(ctx.view.doc.last_graph_error()) == err_before,
			"tight prefix adds no graph error")
	check(is_equal_approx(_param(ctx, ex, "distance"), 10.0),
			"tight prefix leaves distance 10 (got %.3f)" % _param(ctx, ex, "distance"))


func _open_distance(ctx: FilmContext, ex: String) -> LineEdit:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame
	await process_frame
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	var btn := _row_button(tl, ex)
	if btn == null:
		check(false, "extrude row is visible")
		return null
	var pos := btn.get_global_rect().get_center()
	_motion(ctx, pos)
	await process_frame
	ctx.main._clock_override_msec = 200000
	_click_at(pos, ctx)
	ctx.main._clock_override_msec = 200080
	var vp: Viewport = ctx.main.get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.double_click = true
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	ctx.main._clock_override_msec = -1
	return _distance_edit(ctx)


func _distance_edit(ctx: FilmContext) -> LineEdit:
	var tl: TimelinePanel = ctx.main.timeline
	if tl == null or tl.property_panel == null or not tl.property_panel.visible:
		return null
	var spin: SpinBox = tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	if spin == null:
		return null
	return spin.get_line_edit()


func _radius_edit(ctx: FilmContext) -> LineEdit:
	var spin: SpinBox = ctx.main.interaction.find_child("StripRadius", true, false) as SpinBox
	if spin == null and ctx.main.ops_panel != null:
		spin = ctx.main.ops_panel._radius_spin
	if spin == null:
		return null
	return spin.get_line_edit()


func _arrow_pos(spin: SpinBox, up: bool) -> Vector2:
	var r := spin.get_global_rect()
	var le := spin.get_line_edit()
	var x := r.position.x + r.size.x - 8.0
	if le != null:
		var lr := le.get_global_rect()
		x = minf(maxf(lr.position.x + lr.size.x + 6.0, r.position.x + r.size.x - 10.0),
				r.position.x + r.size.x - 4.0)
	return Vector2(x, r.position.y + r.size.y * (0.22 if up else 0.78))


func _file_new(ctx: FilmContext) -> void:
	var btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		var mb := c as MenuButton
		if mb != null and str(mb.text).begins_with("File"):
			btn = mb
			break
	if btn == null:
		check(false, "File menu is visible")
		return
	await FilmUI.activate_menu_id(ctx, btn, 0, FilmUICues.alert("Click", "File New"))
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	for _i in 8:
		await process_frame
		if dlg != null and dlg.visible:
			break
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		if ok != null:
			await FilmUI.click_control(ctx, ok, FilmUICues.alert("Click", "Discard"))
		await process_frame


func _rim_candidates(ctx: FilmContext, body: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cam: Camera3D = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	for i in 24:
		var ang := float(i) * TAU / 24.0
		var local := Vector3(cos(ang) * 10.0, sin(ang) * 10.0, 10.0)
		var world: Vector3 = ms.to_global(local) if ms != null else local
		var screen := cam.unproject_position(world)
		if screen.x < 30.0 or screen.y < 30.0 or screen.x > 1250.0 or screen.y > 770.0:
			continue
		if str(ctx.view.edge_near_screen(body, cam, screen, 12.0)) != "":
			out.append(screen)
	return out


func _rim_point(ctx: FilmContext, body: String) -> Vector2:
	var cam: Camera3D = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	for i in 36:
		var ang := float(i) * TAU / 36.0
		var local := Vector3(cos(ang) * 10.0, sin(ang) * 10.0, 10.0)
		var world: Vector3 = ms.to_global(local) if ms != null else local
		var screen := cam.unproject_position(world)
		if screen.x < 30.0 or screen.y < 30.0 or screen.x > 1250.0 or screen.y > 770.0:
			continue
		if str(ctx.view.edge_near_screen(body, cam, screen, 10.0)) != "":
			return screen
	return Vector2.ZERO


func _row_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null


func _extrude_id(ctx: FilmContext) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			return str(f.get("id", ""))
	return ""


func _param(ctx: FilmContext, fid: String, key: String) -> float:
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			return float(parsed.get(key, 0.0))
	return -1.0


func _count_type(ctx: FilmContext, kind: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == kind:
			n += 1
	return n


func _blob(ctx: FilmContext) -> String:
	return " | ".join(_log) + " | " + str(ctx.main.status_label.text)


func _count_needle(needle: String) -> int:
	var n := 0
	for s in _log:
		if s.contains(needle):
			n += 1
	return n


func _saw(needle: String) -> bool:
	for s in _log:
		if s.contains(needle):
			return true
	return false


func _type_into_dim(ctx: FilmContext, text: String) -> void:
	var edit: LineEdit = ctx.main.sketch_chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null:
		check(false, "DimLineEdit")
		return
	_click_at(edit.get_global_rect().get_center(), ctx)
	await process_frame
	_type_text(ctx.main.get_viewport(), text)
	await _key(ctx, KEY_ENTER)
	await process_frame


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		_key_vp(vp, code, ch)
		_key_up(vp, code)


func _key(ctx: FilmContext, code: Key) -> void:
	_key_vp(ctx.main.get_viewport(), code, 0)
	_key_up(ctx.main.get_viewport(), code)
	await process_frame


func _key_vp(vp: Viewport, code: Key, unicode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.unicode = unicode
	down.pressed = true
	vp.push_input(down)


func _key_up(vp: Viewport, code: Key) -> void:
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	vp.push_input(up)


func _click_at(pos: Vector2, ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
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


func _motion(ctx: FilmContext, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	ctx.main.get_viewport().push_input(motion)


func _pick_option(ctx: FilmContext, opt: OptionButton, index: int) -> void:
	if opt == null:
		return
	await FilmUI.click_control(ctx, opt, FilmUICues.alert("Click", "option"))
	opt.show_popup()
	await process_frame
	var popup: PopupMenu = opt.get_popup()
	if popup == null:
		return
	popup.reset_size()
	var y := popup.size.y * (float(index) + 0.5) / maxf(float(popup.item_count), 1.0)
	_click_at(Vector2(popup.position) + Vector2(popup.size.x * 0.5, y), ctx)
	await process_frame


func _zoom(ctx: FilmContext, uv: Vector2, ppm: float) -> void:
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var model_pivot: Vector3 = sm.to_model(uv) if sm != null else Vector3.ZERO
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var size_mm := 800.0 / ppm
	cam.distance = size_mm / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame
