# re-PLAN 19 WP6 — Timeline double-click stays on the row, and the Modify
# column does not move under a second Radius click.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_timeline.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan19 timeline")
	FilmUI.reset_fail_count()
	await _case_double_click()
	await _case_radius()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case_double_click() -> void:
	print("- double-click extrude keeps both presses on the row")
	var ctx := await _boot()
	var built: Dictionary = await _build_wrench(ctx)
	var ex_fid: String = built["extrude"]
	var body: String = built["body"]
	check(ex_fid != "", "extrude feature exists")
	if ex_fid == "":
		await _shutdown(ctx)
		return
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await _frames(4)
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await _frames(2)
	check(tl.visible, "Timeline is visible")
	var types := _feature_types(ctx)
	check(types.contains("sketch") and types.contains("extrude") and types.contains("fillet"),
			"doc is sketch, extrude, fillet (got '%s')" % types)
	var btn := _row_name_button(tl, ex_fid)
	check(btn != null and btn.is_visible_in_tree(), "extrude row name is visible")
	if btn == null:
		await _shutdown(ctx)
		return

	# Open once, then Esc. A no-edit panel does not own Esc (Fillet must), so
	# one digit makes the quoted cancel status.
	var opened := await _open_distance(ctx, btn)
	check(opened != null and opened.has_focus(), "first double-click focuses Distance")
	if opened != null:
		var sel := opened.get_selected_text()
		check(sel != "" and sel == opened.text,
				"first open selects Distance text ('%s' of '%s')" % [sel, opened.text])
		_push_key(ctx.main.get_viewport(), KEY_1)
		await _frames(2)
		_push_key(ctx.main.get_viewport(), KEY_ENTER)
		await _frames(2)
	_status_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await _frames(3)
	var esc_status := str(ctx.main.status_label.text)
	check(esc_status == "Edits cancelled" or _status_blob().contains("Edits cancelled"),
			"Esc status is Edits cancelled (got '%s' log '%s')" % [esc_status, _status_blob()])
	check(tl.property_panel == null or not tl.property_panel.visible,
			"Esc closes the Distance panel")

	var saw_move := false
	for i in 5:
		var want_selected := i % 2 == 1
		_clock(ctx, 800000 + i * 10000)
		_flush_past_guard(ctx)
		await _frames(2)
		if want_selected:
			ctx.view.select_entity(body, "")
		else:
			ctx.view.clear_selection()
		_flush_past_guard(ctx)
		await _frames(3)
		tl.refresh()
		await _frames(1)
		btn = _row_name_button(tl, ex_fid)
		check(btn != null and btn.is_visible_in_tree(), "row %d is visible" % i)
		if btn == null:
			continue
		var selected_before := ctx.view.selected_body != ""
		check(selected_before == want_selected,
				"repeat %d body selected beforehand=%s" % [i, str(want_selected)])
		var y0 := tl.get_global_rect().position.y
		var pos := btn.get_global_rect().get_center()
		_motion(ctx.main.get_viewport(), pos)
		await process_frame
		var t0 := 900000 + i * 20000
		_clock(ctx, t0)
		ctx.main.interaction.last_click_disposition = ""
		_press(ctx.main.get_viewport(), pos, false)
		var d1 := str(ctx.main.interaction.last_click_disposition)
		_release(ctx.main.get_viewport(), pos)
		_clock(ctx, t0 + 80)
		ctx.main.interaction.last_click_disposition = ""
		_press(ctx.main.get_viewport(), pos, true)
		var d2 := str(ctx.main.interaction.last_click_disposition)
		_release(ctx.main.get_viewport(), pos)
		var y1 := tl.get_global_rect().position.y
		check(d1.begins_with("drop:not-owner:"),
				"repeat %d press 1 is drop:not-owner (got '%s')" % [i, d1])
		check(not d1.contains("model-click"), "repeat %d press 1 is not model-click" % i)
		check(d2.begins_with("drop:not-owner:"),
				"repeat %d press 2 is drop:not-owner (got '%s')" % [i, d2])
		check(not d2.contains("model-click"), "repeat %d press 2 is not model-click" % i)
		check(absf(y1 - y0) <= 1.0,
				"repeat %d Timeline top unchanged across the double-click (%.1f -> %.1f)" % [i, y0, y1])
		await _frames(4)
		var edit: LineEdit = _distance_edit(tl)
		var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
		check(edit != null and owner == edit,
				"repeat %d Distance is focused (got %s)" % [i, owner.name if owner != null else "none"])
		if edit != null:
			var selected := edit.get_selected_text()
			check(selected != "" and selected == edit.text,
					"repeat %d Distance text is selected ('%s' of '%s')" % [i, selected, edit.text])
		else:
			check(false, "repeat %d Distance line exists" % i)
		if not want_selected:
			_clock(ctx, t0 + 80 + 599)
			ctx.main._flush_relayout_guard()
			var y_hold := tl.get_global_rect().position.y
			check(absf(y_hold - y0) <= 1.0,
					"repeat %d Timeline stays put at +599 ms (%.1f)" % [i, y_hold])
			_clock(ctx, t0 + 80 + 600)
			await process_frame
			ctx.main._flush_relayout_guard()
			await _frames(2)
			var y2 := tl.get_global_rect().position.y
			var chip := _chip_bottom(ctx)
			check(y2 > y0 + 1.0, "repeat %d Timeline moves after the guard (%.1f -> %.1f)" % [i, y0, y2])
			check(chip < 0.0 or y2 + 1.0 >= chip + 4.0,
					"repeat %d Timeline is >= 4 px under the chip row (top %.1f chip %.1f)" % [i, y2, chip])
			saw_move = true
		_push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await _frames(2)

	check(saw_move, "an unselected double-click moved the Timeline only after the guard")
	# Nothing selected: Timeline returns to the top.
	_clock(ctx, 1200000)
	_flush_past_guard(ctx)
	ctx.view.clear_selection()
	ctx.main._update_panel_visibility()
	await _frames(3)
	var y_clear := tl.get_global_rect().position.y
	var y_selected := y_clear
	ctx.view.select_entity(body, "")
	ctx.main._update_panel_visibility()
	await _frames(3)
	y_selected = tl.get_global_rect().position.y
	var chip_sel := _chip_bottom(ctx)
	check(chip_sel < 0.0 or y_selected + 1.0 >= chip_sel + 4.0,
			"N23 Timeline is under the chip row when a body is selected (top %.1f chip %.1f)" % [y_selected, chip_sel])
	ctx.view.clear_selection()
	ctx.main._update_panel_visibility()
	await _frames(3)
	var y_top := tl.get_global_rect().position.y
	check(y_top + 4.0 < y_selected,
			"Timeline returns toward the top when nothing is selected (%.1f vs selected %.1f)" % [y_top, y_selected])
	await _shutdown(ctx)


func _case_radius() -> void:
	print("- Modify Radius second click stays in the field")
	var ctx := await _boot()
	var built: Dictionary = await _build_wrench(ctx)
	var body: String = built["body"]
	check(body != "", "radius case has a body")
	if body == "":
		await _shutdown(ctx)
		return
	ctx.view.select_entity(body, "")
	await _frames(2)
	ctx.main.ops_panel.arm_or_apply_fillet()
	await _frames(4)
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet is armed")
	var edit: LineEdit = ctx.main.ops_panel._radius_spin.get_line_edit()
	check(edit != null and edit.is_visible_in_tree(), "panel Radius line is visible")
	if edit == null:
		await _shutdown(ctx)
		return
	var pos: Vector2 = edit.get_global_rect().get_center()
	_motion(ctx.main.get_viewport(), pos)
	await process_frame
	_status_log.clear()
	var t0 := 500000
	_clock(ctx, t0)
	ctx.main.interaction.last_click_disposition = ""
	_press(ctx.main.get_viewport(), pos, false)
	var d1 := str(ctx.main.interaction.last_click_disposition)
	_release(ctx.main.get_viewport(), pos)
	_clock(ctx, t0 + 300)
	ctx.main.interaction.last_click_disposition = ""
	_press(ctx.main.get_viewport(), pos, false)
	var d2 := str(ctx.main.interaction.last_click_disposition)
	_release(ctx.main.get_viewport(), pos)
	await _frames(2)
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == edit, "Radius focus stays in the field (got %s)" % (owner.name if owner != null else "none"))
	check(not d1.contains("model-click") and not d2.contains("model-click"),
			"Radius presses are not model clicks ('%s' / '%s')" % [d1, d2])
	var blob := _status_blob() + " | " + str(ctx.main.status_label.text)
	check(not blob.contains("Selected face"), "second Radius click never selects a face (got '%s')" % blob)
	var y_during: float = ctx.main.ops_panel.get_global_rect().position.y
	_clock(ctx, t0 + 300 + 599)
	ctx.main._flush_relayout_guard()
	check(absf(ctx.main.ops_panel.get_global_rect().position.y - y_during) <= 1.0,
			"Modify column holds still inside the guard")
	await _shutdown(ctx)


func _build_wrench(ctx: FilmContext) -> Dictionary:
	var view: DocumentView = ctx.view
	view.new_document()
	var doc: SxDocument = view.doc
	var sk := SxSketch.new()
	sk.add_line(-10, -8, 10, -8)
	sk.add_line(10, -8, 10, 8)
	sk.add_line(10, 8, -10, 8)
	sk.add_line(-10, 8, -10, -8)
	var sk_fid: String = doc.graph_add_sketch(sk)
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	view.graph_changed()
	await process_frame
	var body := ""
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.size() > 0:
		body = bodies[0]
	var host := view.feature_of_body(body) if body != "" else ""
	var edges: PackedStringArray = doc.get_edge_ids(body) if body != "" else PackedStringArray()
	if host != "" and edges.size() > 0:
		doc.graph_add_fillet(host, PackedStringArray([edges[0]]), 1.0)
		view.graph_changed()
	await process_frame
	return {"extrude": ex_fid, "body": body, "sketch": sk_fid}


func _open_distance(ctx: FilmContext, btn: Button) -> LineEdit:
	var pos := btn.get_global_rect().get_center()
	_motion(ctx.main.get_viewport(), pos)
	await process_frame
	_clock(ctx, 100000)
	_press(ctx.main.get_viewport(), pos, false)
	_release(ctx.main.get_viewport(), pos)
	_clock(ctx, 100080)
	_press(ctx.main.get_viewport(), pos, true)
	_release(ctx.main.get_viewport(), pos)
	await _frames(4)
	return _distance_edit(ctx.main.timeline)


func _distance_edit(tl: TimelinePanel) -> LineEdit:
	if tl.property_panel == null or not tl.property_panel.visible:
		return null
	var spin := tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	if spin == null:
		return null
	return spin.get_line_edit()


func _chip_bottom(ctx: FilmContext) -> float:
	if ctx.main.interaction == null:
		return -1.0
	if ctx.main.interaction.has_method("selection_strip_content_bottom"):
		return ctx.main.interaction.selection_strip_content_bottom()
	return -1.0


func _feature_types(ctx: FilmContext) -> String:
	var parts: PackedStringArray = []
	for f in ctx.view.doc.graph_features():
		parts.append(str(f.get("type", "")))
	return ",".join(parts)


func _clock(ctx: FilmContext, msec: int) -> void:
	ctx.main._clock_override_msec = msec


func _flush_past_guard(ctx: FilmContext) -> void:
	if ctx.main._relayout_press_msec < 0:
		ctx.main._flush_relayout_guard()
		return
	ctx.main._clock_override_msec = ctx.main._relayout_press_msec + ctx.main.TIMELINE_RELAYOUT_GUARD_MSEC
	ctx.main._relayout_button_down = false
	ctx.main._flush_relayout_guard()


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


func _press(vp: Viewport, pos: Vector2, double_click: bool) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)


func _release(vp: Viewport, pos: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)


func _push_key(vp: Viewport, code: Key) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = code
	down.physical_keycode = code
	down.unicode = code if code >= KEY_0 and code <= KEY_9 else 0
	vp.push_input(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = code
	up.physical_keycode = code
	vp.push_input(up)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


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
	check(root.size == ROOT_SIZE, "root is %s (got %s)" % [ROOT_SIZE, root.size])
	_status_log.clear()
	if main.interaction != null and main.interaction.has_signal("status"):
		main.interaction.status.connect(_on_status)
	if main.timeline != null and main.timeline.has_signal("status"):
		main.timeline.status.connect(_on_status)
	if main.ops_panel != null and main.ops_panel.has_signal("status"):
		main.ops_panel.status.connect(_on_status)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	# Let deferred SpinBox line updates land before the scene is freed.
	await _frames(3)
	if ctx.main != null:
		ctx.main._clock_override_msec = -1
		ctx.main.queue_free()
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_blob() -> String:
	return " | ".join(_status_log)


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null
