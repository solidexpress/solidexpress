# sx-037 N2 / A11c: Enter in strip R or panel Radius commits the number and
# returns the keys. Viewport Enter applies the fillet as a committed feature
# (`Fillet N edges R applied — View ▸ Timeline to edit parameters`) and does
# not open the editor. Timeline → parameters → Cancel undoes a radius edit.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan16_n2.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOP_PITCH := deg_to_rad(89.0)
const APPLIED := "Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters"

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
	print("rung01 replan16 N2 fillet radius Enter")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


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
	if main.ops_panel != null and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.timeline != null and not main.timeline.status.is_connected(_on_status):
		main.timeline.status.connect(_on_status)
	var view: DocumentView = main.view
	var vp: Viewport = main.get_viewport()
	var body: String = view.insert_primitive("box", Vector3(80, 0, 0), Vector3(80, 80, 40))
	await process_frame
	view.select_entity(body, "")
	await process_frame
	await process_frame
	if main.has_method("_update_panel_visibility"):
		main._update_panel_visibility()
	await process_frame

	var fillet: Button = main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "Fillet chip is visible")
	await _click_control(vp, fillet)
	await process_frame
	await process_frame
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet is armed")
	var picked := _select_two_verticals(view, body)
	check(picked.size() == 2, "two vertical edges pending (got %d)" % picked.size())
	await process_frame

	var strip := _strip(main)
	var panel := _panel(main)
	check(strip != null and strip.is_visible_in_tree(), "strip R is visible")
	var want2 := SxUi.fmt_mm(2.0)
	await process_frame
	var strip_txt := _line_text(strip)
	var panel_txt := _line_text(panel)
	print("  resting format strip=`%s` panel=`%s`" % [strip_txt, panel_txt])
	check(strip_txt == want2, "strip resting text is %s (got `%s`)" % [want2, strip_txt])
	check(panel_txt == want2, "panel resting text is %s (got `%s`)" % [want2, panel_txt])
	check(strip_txt == panel_txt, "strip and panel use the same text")

	await _click_at(vp, _spin_text_pos(strip), 1)
	await _push_char(vp, "1")
	await _push_char(vp, "0")
	print("  strip after typing `%s`" % _line_text(strip))
	_status_log.clear()
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES,
			"strip Enter keeps Fillet armed")
	check(view.selected_edges.size() == 2, "strip Enter keeps 2 edges (got %d)" % view.selected_edges.size())
	check(is_equal_approx(main.ops_panel.dressup_radius(), 10.0),
			"strip Enter radius is 10 (got %s)" % str(main.ops_panel.dressup_radius()))
	var want10 := SxUi.fmt_mm(10.0)
	check(_line_text(strip) == want10, "strip reads %s (got `%s`)" % [want10, _line_text(strip)])
	check(_line_text(panel) == want10, "panel reads %s (got `%s`)" % [want10, _line_text(panel)])
	var owner: Control = vp.gui_get_focus_owner()
	check(owner == main.interaction,
			"strip Enter returns viewport focus (got %s)" % _owner_name(owner))
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	check(_label(main).contains("Top view") or _status_has("Top view"),
			"key 3 after strip Enter is Top view (label `%s`)" % _label(main))
	check(absf(main.camera.pitch - TOP_PITCH) < 0.05, "camera is Top after key 3")
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet still armed after key 3")
	check(view.selected_edges.size() == 2, "2 edges still pending after key 3")

	FilmUI.ensure_control_visible(panel)
	await process_frame
	await _click_at(vp, _spin_text_pos(panel), 1)
	await _push_char(vp, "1")
	await _push_char(vp, "0")
	print("  panel after typing `%s`" % _line_text(panel))
	_status_log.clear()
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES,
			"panel Enter keeps Fillet armed")
	check(view.selected_edges.size() == 2, "panel Enter keeps 2 edges")
	check(is_equal_approx(main.ops_panel.dressup_radius(), 10.0),
			"panel Enter radius is 10 (got %s)" % str(main.ops_panel.dressup_radius()))
	check(_line_text(panel) == want10 and _line_text(strip) == want10,
			"panel Enter text is %s (panel `%s` strip `%s`)" % [want10, _line_text(panel), _line_text(strip)])
	owner = vp.gui_get_focus_owner()
	check(owner == main.interaction,
			"panel Enter returns viewport focus (got %s)" % _owner_name(owner))
	_status_log.clear()
	await _push_key(vp, KEY_4, 52)
	await process_frame
	check(_label(main).contains("Back view") or _status_has("Back view"),
			"key 4 after panel Enter is Back view (label `%s`)" % _label(main))

	# Timeline already on must not turn apply into an editor session.
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	main.interaction.return_viewport_keys()
	await process_frame
	var fillets_before := _fillet_count(view)
	_status_log.clear()
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	print("  apply status `%s`" % _label(main))
	check(_label(main) == APPLIED, "viewport Enter status is `%s` (got `%s`)" % [APPLIED, _label(main)])
	check(main.ops_panel._pending == OpsPanel.Pending.NONE, "viewport Enter disarms Fillet")
	check(_fillet_count(view) == fillets_before + 1, "viewport Enter adds one fillet")
	var pp: PropertyPanel = main.timeline.property_panel
	check(pp == null or not pp.visible, "apply does not open the fillet editor")
	var fid := _last_fillet_fid(view)
	check(is_equal_approx(_fillet_radius(view, fid), 10.0),
			"committed fillet radius is 10 (got %s)" % str(_fillet_radius(view, fid)))
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	await process_frame
	check(_fillet_count(view) == fillets_before + 1, "Esc after apply keeps the fillet")
	check(not _status_has("Edits cancelled"), "Esc after apply does not cancel the fillet")
	check(is_equal_approx(_fillet_radius(view, fid), 10.0), "Esc leaves radius 10")
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	if main.timeline != null:
		main.timeline.refresh()
	await process_frame

	var params_btn := _row_params(main, fid)
	check(params_btn != null and params_btn.is_visible_in_tree(), "Timeline params button is visible")
	if params_btn != null:
		FilmUI.ensure_control_visible(params_btn)
		await process_frame
		await _click_control(vp, params_btn)
		await process_frame
		await process_frame
	check(pp != null and pp.visible, "Timeline opens the fillet editor")
	check(str(pp._title.text).contains("fillet"), "editor title is the fillet (got `%s`)" % str(pp._title.text))
	var radius_spin: SpinBox = pp._spin_for_key("radius")
	check(radius_spin != null, "editor Radius spin exists")
	if radius_spin != null:
		FilmUI.ensure_control_visible(radius_spin)
		await process_frame
		await _click_at(vp, _spin_text_pos(radius_spin), 3)
		await _push_char(vp, "4")
		print("  editor radius after key 4 `%s`" % _line_text(radius_spin))
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
		await process_frame
		owner = vp.gui_get_focus_owner()
		check(not (owner is LineEdit) and not (owner is SpinBox),
				"editor Radius Enter releases the field (got %s)" % _owner_name(owner))
		_status_log.clear()
		await _push_key(vp, KEY_3, 51)
		await process_frame
		check(_label(main).contains("Top view") or _status_has("Top view"),
				"key 3 after editor Enter is Top view (label `%s`)" % _label(main))
		check(is_equal_approx(_fillet_radius(view, fid), 4.0),
				"editor Enter previews radius 4 (got %s)" % str(_fillet_radius(view, fid)))
	var cancel: Button = pp.find_child("PropertyCancel", true, false)
	check(cancel != null and cancel.is_visible_in_tree(), "Cancel button is visible")
	if cancel != null:
		FilmUI.ensure_control_visible(cancel)
		await process_frame
		_status_log.clear()
		await _click_control(vp, cancel)
		await process_frame
		await process_frame
	print("  cancel status `%s` log=%s" % [_label(main), str(_status_log)])
	check(not pp.visible, "Cancel closes the editor")
	check(_label(main) == "Edits cancelled" or _status_has("Edits cancelled"),
			"Cancel status is Edits cancelled (got `%s`)" % _label(main))
	check(_fillet_count(view) == fillets_before + 1, "Cancel keeps the fillet on the Timeline")
	check(is_equal_approx(_fillet_radius(view, fid), 10.0),
			"Cancel restores radius 10 (got %s)" % str(_fillet_radius(view, fid)))

	main.queue_free()
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


func _owner_name(owner: Control) -> String:
	if owner == null:
		return "null"
	return "%s/%s" % [owner.get_class(), owner.name]


func _strip(main) -> SpinBox:
	return main.interaction.find_child("StripRadius", true, false) as SpinBox


func _panel(main) -> SpinBox:
	return main.ops_panel._radius_spin as SpinBox


func _line_text(spin: SpinBox) -> String:
	if spin == null:
		return ""
	var le := spin.get_line_edit()
	return "" if le == null else str(le.text)


func _fillet_count(view: DocumentView) -> int:
	var n := 0
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


func _last_fillet_fid(view: DocumentView) -> String:
	var fid := ""
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			fid = str(f.get("id", ""))
	return fid


func _fillet_radius(view: DocumentView, fid: String) -> float:
	for f in view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			return float((parsed as Dictionary).get("radius", -1.0))
	return -1.0


func _row_params(main, fid: String) -> Button:
	var row: Node = main.timeline._rows.get(fid)
	if row == null:
		return null
	return row.find_child("RowParams", true, false) as Button


func _vertical_edges(view: DocumentView, body: String) -> Array:
	var out := []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) >= 20.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			out.append(str(id))
	return out


func _select_two_verticals(view: DocumentView, body: String) -> PackedStringArray:
	var verts := _vertical_edges(view, body)
	if verts.size() < 2:
		return PackedStringArray()
	var best_a := str(verts[0])
	var best_b := str(verts[1])
	var best_d := -1.0
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for i in verts.size():
		var pa: PackedVector3Array = lines[verts[i]]
		var ma := (pa[0] + pa[pa.size() - 1]) * 0.5
		for j in range(i + 1, verts.size()):
			var pb: PackedVector3Array = lines[verts[j]]
			var mb := (pb[0] + pb[pb.size() - 1]) * 0.5
			var d := Vector2(ma.x - mb.x, ma.y - mb.y).length()
			if d > best_d:
				best_d = d
				best_a = str(verts[i])
				best_b = str(verts[j])
	view.select_edge(body, best_a)
	var edges: Array[String] = [best_a, best_b]
	view.selected_edges = edges
	view.selected_edge = best_a
	return PackedStringArray(edges)


func _push_key(vp: Viewport, code: int, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode if pressed else 0
		ev.pressed = pressed
		ev.echo = false
		vp.push_input(ev)
		await process_frame
	await process_frame


func _push_char(vp: Viewport, ch: String) -> void:
	var unicode := ch.unicode_at(0)
	var code := KEY_NONE
	if unicode >= 48 and unicode <= 57:
		code = (KEY_0 + (unicode - 48)) as Key
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
	return r.get_center()
