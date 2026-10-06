# Rung 1 replan 14 WP2 — numeric fields give focus back so view keys work;
# Ctrl+A and Esc in a sketch field. Leftovers 2, 5, 6.
# Setup may use helpers; every click, key and motion under test is a real
# Viewport.push_input event (or FilmUI.click_control for the Fillet button).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script res://tests/run_rung01_replan14_focuskeys.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const FIRST_DROP := "First point dropped — Esc again exits the sketch"
const TOP_PITCH := deg_to_rad(89.0)
const BACK_PITCH := 0.0
const ISO_PITCH := deg_to_rad(40.0)
const ISO_YAW := deg_to_rad(-35.0)
const VIEW_EPS := 0.01

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
	print("rung01 replan14 WP2 numeric field focus / view keys / Ctrl+A / Esc")
	FilmUI.reset_fail_count()
	await _part_rows()
	await _sketch_rows()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _st(main) -> String:
	return str(main.status_label.text)


func _strip(main) -> SpinBox:
	return main.interaction.find_child("StripRadius", true, false) as SpinBox


func _strip_text(main) -> String:
	var spin := _strip(main)
	if spin == null:
		return ""
	var le: LineEdit = spin.get_line_edit()
	return le.text if le != null else ""


func _panel_spin(main) -> SpinBox:
	return main.ops_panel._radius_spin as SpinBox


func _panel_text(main) -> String:
	var spin := _panel_spin(main)
	if spin == null:
		return ""
	var le: LineEdit = spin.get_line_edit()
	return le.text if le != null else ""


func _text_radius(text: String) -> float:
	var t := text.strip_edges().replace("mm", "").replace("MM", "").strip_edges()
	if t.is_valid_float():
		return float(t)
	return NAN


func _parses_to(text: String, want: float) -> bool:
	var got := _text_radius(text)
	return not is_nan(got) and is_equal_approx(got, want)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	if needle != "" and _status_log.size() > 0:
		pass
	return false


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _focus_probe(vp: Viewport, tag: String) -> void:
	var f := vp.gui_get_focus_owner()
	var cls := "null" if f == null else f.get_class()
	var name := "" if f == null else str(f.name)
	var parent_cls := ""
	if f != null and f.get_parent() != null:
		parent_cls = f.get_parent().get_class()
	print("  focus %s: class=%s name=%s parent=%s" % [tag, cls, name, parent_cls])


func _observe_spin(main, tag: String, spin: SpinBox) -> void:
	var text := ""
	var val := NAN
	if spin != null:
		val = spin.value
		var le: LineEdit = spin.get_line_edit()
		text = le.text if le != null else ""
	print("  observed %s: value=%s text=`%s` status=`%s` log_tail=`%s`" % [
		tag, str(val), text, _st(main), _last_status()])


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


func _click_at(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
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


func _spin_text_pos(spin: SpinBox) -> Vector2:
	var r: Rect2 = spin.get_global_rect()
	return Vector2(r.position.x + minf(r.size.x * 0.35, r.size.x - 24.0), r.get_center().y)


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	var spin: SpinBox = chrome.find_child("DimSpin", true, false)
	if spin == null:
		return null
	return spin.get_line_edit()


func _preview_hidden(sm: SketchMode) -> bool:
	if sm == null:
		return true
	if not sm.has_pending_draw_point() and not sm.has_single_dof_preview():
		return true
	if sm._preview_node == null:
		return true
	if sm._preview_node.mesh == null:
		return true
	return not sm._preview_node.visible


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


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


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


func _arm_fillet_strip(ctx: FilmContext) -> void:
	var fillet: Button = ctx.main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "StripFillet is visible")
	if fillet == null:
		return
	await FilmUI.click_control(ctx, fillet, FilmUICues.alert("Fillet", "Arm Fillet"))
	await process_frame
	await process_frame
	await process_frame


func _assert_top(cam: OrbitCamera, tag: String) -> void:
	check(absf(cam.pitch - TOP_PITCH) < VIEW_EPS,
			"%s: camera is Top (pitch %.4f want %.4f)" % [tag, cam.pitch, TOP_PITCH])
	var saw := _status_has("Top view") or _st_from_cam(cam).contains("Top view")
	check(saw, "%s: status log has Top view (log=%s label=`%s`)" % [
		tag, str(_status_log.slice(maxi(_status_log.size() - 6, 0))), _last_label()])


func _assert_back(cam: OrbitCamera, tag: String) -> void:
	check(absf(cam.pitch - BACK_PITCH) < VIEW_EPS,
			"%s: camera is Back (pitch %.4f)" % [tag, cam.pitch])
	var saw := _status_has("Back view")
	check(saw, "%s: status log has Back view (log_tail=`%s`)" % [tag, _last_status()])


func _assert_iso(cam: OrbitCamera, tag: String) -> void:
	check(absf(cam.pitch - ISO_PITCH) < VIEW_EPS,
			"%s: camera is Iso (pitch %.4f want %.4f)" % [tag, cam.pitch, ISO_PITCH])
	check(absf(wrapf(cam.yaw - ISO_YAW, -PI, PI)) < 0.05,
			"%s: camera Iso yaw (got %.4f)" % [tag, cam.yaw])


func _last_label() -> String:
	return ""


func _st_from_cam(_cam: OrbitCamera) -> String:
	return _last_status()


func _zoom_model(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
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


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "on screen: %s" % desc)
	await _click_at(ctx.main.get_viewport(), screen)


func _part_rows() -> void:
	print("- part mode: strip / panel Radius release focus so view keys work")
	var ctx := await _boot()
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var cam: OrbitCamera = main.camera
	var body := await _place_box(ctx)
	check(body != "", "box placed")
	await _arm_fillet_strip(ctx)
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES,
			"1: Fillet is armed (status `%s`)" % _st(main))
	check(_st(main).contains("Fillet r=") or _status_has("Fillet r="),
			"1: status is Fillet r=… (got `%s`)" % _st(main))
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "StripRadius is visible")
	if spin == null:
		await _shutdown(ctx)
		return
	_focus_probe(vp, "after arm")
	_observe_spin(main, "armed strip", spin)

	print("- 2. strip ▲ then ▼, then KEY_3 is Top")
	var before_arrows := _strip_text(main)
	await _click_at(vp, _spin_arrow_pos(spin, true))
	await process_frame
	await process_frame
	await _click_at(vp, _spin_arrow_pos(spin, false))
	await process_frame
	await process_frame
	await process_frame
	_focus_probe(vp, "after strip arrows")
	_observe_spin(main, "after strip arrows", spin)
	var after_arrows := _strip_text(main)
	_status_log.clear()
	var pitch_before_3 := cam.pitch
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_focus_probe(vp, "after KEY_3")
	_observe_spin(main, "after KEY_3", spin)
	print("  camera after KEY_3: pitch=%.4f (was %.4f) yaw=%.4f" % [
		cam.pitch, pitch_before_3, cam.yaw])
	_assert_top(cam, "2 strip arrows")
	check(_parses_to(_strip_text(main), _text_radius(after_arrows)) \
			or _strip_text(main) == after_arrows \
			or not _strip_text(main).contains("3"),
			"2: strip text has no stray 3 (before `%s` after arrows `%s` after key `%s`)" % [
				before_arrows, after_arrows, _strip_text(main)])
	var after3 := _strip_text(main)
	check(not after3.contains("3") or _parses_to(after3, _text_radius(after_arrows)),
			"2: key 3 did not type into the strip (got `%s`)" % after3)

	print("- 3. click strip text, Ctrl+A, 10 Enter, KEY_4 is Back")
	await _click_at(vp, _spin_text_pos(spin))
	await process_frame
	_focus_probe(vp, "strip text click")
	await _push_key(vp, KEY_A, 0, true)
	await _push_key(vp, KEY_1, 49)
	await _push_key(vp, KEY_0, 48)
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	_focus_probe(vp, "after strip 10 Enter")
	_observe_spin(main, "after strip 10 Enter", spin)
	_observe_spin(main, "panel after strip 10 Enter", _panel_spin(main))
	_status_log.clear()
	await _push_key(vp, KEY_4, 52)
	await process_frame
	await process_frame
	_assert_back(cam, "3 strip typed 10 Enter")
	check(_parses_to(_strip_text(main), 10.0),
			"3: strip parses to 10 (got `%s`)" % _strip_text(main))
	check(_parses_to(_panel_text(main), 10.0),
			"3: panel parses to 10 (got `%s`)" % _panel_text(main))
	check(not _strip_text(main).contains("104") and not _strip_text(main).contains("410"),
			"3: no stray digit in strip (got `%s`)" % _strip_text(main))

	print("- 4. KEY_8 then KEY_3 each change the view")
	_status_log.clear()
	await _push_key(vp, KEY_8, 56)
	await process_frame
	check(absf(cam.pitch - deg_to_rad(-89.0)) < VIEW_EPS,
			"4: KEY_8 is Bottom (pitch %.4f)" % cam.pitch)
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	_assert_top(cam, "4 KEY_3")

	print("- 5. caret in strip: KEY_3 types, camera does not move")
	if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		ctx.view.select_entity(body, "")
		await process_frame
		await _arm_fillet_strip(ctx)
	spin = _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "5: StripRadius visible")
	if spin != null:
		await _click_at(vp, _spin_text_pos(spin))
		await process_frame
		await process_frame
	_focus_probe(vp, "caret in strip")
	var pitch_caret := cam.pitch
	var text_caret := _strip_text(main)
	await _push_key(vp, KEY_3, 51)
	await process_frame
	_observe_spin(main, "caret KEY_3", spin)
	check(_strip_text(main).contains("3"),
			"5: field text contains 3 while caret is in it (got `%s`, was `%s`)" % [
				_strip_text(main), text_caret])
	check(absf(cam.pitch - pitch_caret) < VIEW_EPS,
			"5: camera did not move (pitch %.4f)" % cam.pitch)

	print("- 6. empty viewport click releases the field; KEY_7 is Iso")
	var empty := Vector2(float(ROOT_SIZE.x) - 90.0, 110.0)
	await _click_at(vp, empty)
	await process_frame
	await process_frame
	_focus_probe(vp, "after empty click")
	var owner := vp.gui_get_focus_owner()
	check(not (owner is LineEdit),
			"6: focus owner is not a LineEdit (got %s)" % [
				"null" if owner == null else owner.get_class()])
	_status_log.clear()
	await _push_key(vp, KEY_7, 55)
	await process_frame
	_assert_iso(cam, "6 KEY_7")
	check(_status_has("Isometric view") or absf(cam.pitch - ISO_PITCH) < VIEW_EPS,
			"6: Iso view (status_tail=`%s`)" % _last_status())

	print("- 7. panel Radius arrows / typed 10 Enter / view keys")
	if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		ctx.view.select_entity(body, "")
		await process_frame
		await _arm_fillet_strip(ctx)
	var panel := _panel_spin(main)
	check(panel != null, "7: panel Radius exists")
	if panel != null:
		FilmUI.ensure_control_visible(panel)
		await process_frame
		await process_frame
		print("  panel rect=%s line=%s" % [
			str(panel.get_global_rect()),
			str(panel.get_line_edit().get_global_rect() if panel.get_line_edit() else "?")])
		_observe_spin(main, "panel before arrows", panel)
		await _click_at(vp, _spin_arrow_pos(panel, true))
		await process_frame
		await process_frame
		await _click_at(vp, _spin_arrow_pos(panel, false))
		await process_frame
		await process_frame
		await process_frame
		_focus_probe(vp, "after panel arrows")
		_observe_spin(main, "after panel arrows", panel)
		var panel_after_arrows := _panel_text(main)
		_status_log.clear()
		await _push_key(vp, KEY_3, 51)
		await process_frame
		_assert_top(cam, "7 panel arrows")
		check(not _panel_text(main).contains("3") or _parses_to(_panel_text(main), _text_radius(panel_after_arrows)),
				"7: panel has no stray 3 (got `%s`)" % _panel_text(main))

		await _click_at(vp, _spin_text_pos(panel))
		await process_frame
		await _push_key(vp, KEY_A, 0, true)
		await _push_key(vp, KEY_1, 49)
		await _push_key(vp, KEY_0, 48)
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
		await process_frame
		_focus_probe(vp, "after panel 10 Enter")
		_observe_spin(main, "after panel 10 Enter", panel)
		_status_log.clear()
		await _push_key(vp, KEY_4, 52)
		await process_frame
		_assert_back(cam, "7 panel typed 10 Enter")
		check(_parses_to(_panel_text(main), 10.0),
				"7: panel parses to 10 (got `%s`)" % _panel_text(main))
		check(_parses_to(_strip_text(main), 10.0),
				"7: strip parses to 10 (got `%s`)" % _strip_text(main))
		_status_log.clear()
		await _push_key(vp, KEY_8, 56)
		await process_frame
		check(absf(cam.pitch - deg_to_rad(-89.0)) < VIEW_EPS, "7: KEY_8 Bottom")
		await _push_key(vp, KEY_3, 51)
		await process_frame
		_assert_top(cam, "7 KEY_3 after panel")

	print("- 8. Esc with the field focused still clears the armed fillet")
	if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		ctx.view.select_entity(body, "")
		await process_frame
		await _arm_fillet_strip(ctx)
	spin = _strip(main)
	if spin != null:
		await _click_at(vp, _spin_text_pos(spin))
		await process_frame
	_focus_probe(vp, "before Esc")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	await process_frame
	check(_status_has("Edge pick cancelled") or _st(main).contains("Edge pick cancelled"),
			"8: Esc says Edge pick cancelled (got `%s` log_tail=`%s`)" % [
				_st(main), _last_status()])
	await _shutdown(ctx)


func _sketch_rows() -> void:
	print("- sketch: Ctrl+A in the Radius field; Esc drops the pending point")
	var ctx := await _boot()
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	await _zoom_model(ctx, Vector3.ZERO, 80.0)

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	check(sm.tool == SketchMode.Tool.POLYGON, "Polygon tool is active")
	await _click_uv(ctx, Vector2.ZERO, "Polygon centre")
	await process_frame
	var dim := _dim_edit(main.sketch_chrome)
	check(dim != null, "chrome dim LineEdit exists")
	if dim != null:
		FilmUI.ensure_control_visible(dim)
		await process_frame
		await _click_at(vp, dim.get_global_rect().get_center())
		await process_frame
		await _push_key(vp, KEY_2, 50)
		await _push_key(vp, KEY_0, 48)
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
	check(sm.sketch.entity_ids().size() >= 1, "polygon committed (ids %d)" % sm.sketch.entity_ids().size())

	print("- 9. Circle Radius field Ctrl+A does not select sketch entities")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2.ZERO, "Circle centre")
	await process_frame
	check(sm.has_pending_draw_point(), "circle has a pending centre")
	dim = _dim_edit(main.sketch_chrome)
	check(dim != null and dim.is_visible_in_tree(), "Radius field is visible")
	var selected_before: Array = sm.selected.duplicate()
	if dim != null:
		FilmUI.ensure_control_visible(dim)
		await process_frame
		await _click_at(vp, dim.get_global_rect().get_center())
		await process_frame
		await process_frame
		_focus_probe(vp, "circle radius click (item 5)")
		print("  dim.has_focus=%s text=`%s` selected_text=`%s`" % [
			str(dim.has_focus()), dim.text, dim.get_selected_text()])
		_status_log.clear()
		await _push_key(vp, KEY_A, 0, true)
		await process_frame
		_focus_probe(vp, "after Ctrl+A")
		print("  after Ctrl+A: focus_text=`%s` selected=`%s` sm.selected=%s status=`%s` log=%s" % [
			dim.text, dim.get_selected_text(), str(sm.selected), _st(main), str(_status_log)])
		check(dim.get_selected_text() == dim.text and dim.text.strip_edges() != "",
				"9: LineEdit selected text equals text and is non-empty (text=`%s` sel=`%s`)" % [
					dim.text, dim.get_selected_text()])
		check(sm.selected.is_empty() or sm.selected == selected_before,
				"9: sketch selection unchanged (before %s after %s)" % [
					str(selected_before), str(sm.selected)])
		var saw_selected := false
		for s in _status_log:
			if s.begins_with("Selected"):
				saw_selected = true
		check(not saw_selected,
				"9: no status begins Selected (log=%s label=`%s`)" % [str(_status_log), _st(main)])

	print("- 10. Esc with the field focused drops the pending point")
	if dim != null and not dim.has_focus():
		await _click_at(vp, dim.get_global_rect().get_center())
		await process_frame
	_focus_probe(vp, "before focused Esc")
	check(sm.has_pending_draw_point(), "10: still has a pending point")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	await process_frame
	print("  after focused Esc: pending=%s preview_hidden=%s focus=%s last_status=`%s`" % [
		str(sm.has_pending_draw_point()), str(_preview_hidden(sm)),
		str(vp.gui_get_focus_owner()), _last_status()])
	check(not sm.has_pending_draw_point(), "10: pending point is gone")
	check(_last_status() == FIRST_DROP or _status_has(FIRST_DROP),
			"10: last status is First point dropped (got `%s` log=%s)" % [
				_last_status(), str(_status_log)])
	check(_preview_hidden(sm), "10: preview circle is gone")
	var owner10 := vp.gui_get_focus_owner()
	check(not (owner10 is LineEdit) or (dim != null and not dim.has_focus()),
			"10: field no longer has focus")
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	print("  after second Esc: active=%s last_status=`%s`" % [str(sm.active), _last_status()])

	print("- 11. Esc with the field not focused is the same two-press ladder")
	if not sm.active:
		await FilmUI.enter_sketch(ctx)
		sm = main.sketch_mode
		await _zoom_model(ctx, Vector3.ZERO, 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2(8, 0), "Circle centre unfocused")
	await process_frame
	dim = _dim_edit(main.sketch_chrome)
	if dim != null and dim.has_focus():
		await _click_at(vp, Vector2(float(ROOT_SIZE.x) - 90.0, 110.0))
		await process_frame
	_focus_probe(vp, "unfocused before Esc")
	check(sm.has_pending_draw_point(), "11: pending point with field not focused")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	check(not sm.has_pending_draw_point(), "11: first Esc drops the pending point")
	check(_last_status() == FIRST_DROP or _status_has(FIRST_DROP),
			"11: first Esc is First point dropped (got `%s`)" % _last_status())
	var active_after_first := sm.active
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	print("  11 second Esc: was_active=%s now_active=%s last=`%s`" % [
		str(active_after_first), str(sm.active), _last_status()])
	await _shutdown(ctx)
