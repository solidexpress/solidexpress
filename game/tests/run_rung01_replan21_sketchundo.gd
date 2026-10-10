# re-PLAN 21 WP3 — a no-op sketch reopen/exit does not push a part undo entry.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan21_sketchundo.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung01 replan21 sketch undo")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	_snapshot_cases(ctx.main.sketch_mode)
	await _plate(ctx)
	var jaw := await _jaw(ctx)
	check(jaw != "", "jaw sketch saved")
	check(_feature_names(ctx).has("sketch 3"), "jaw is sketch 3 (got %s)" % str(_feature_names(ctx)))
	var listed := _sketch_ids(ctx).size()
	await _part_undo(ctx)
	check(not _feature_names(ctx).has("sketch 3"), "A8b one Ctrl+Z removes sketch 3 (got %s)" % str(_feature_names(ctx)))
	check(_sketch_ids(ctx).size() == listed - 1, "A8b sketch count dropped by one")
	await _part_redo(ctx)
	check(_feature_names(ctx).has("sketch 3"), "A8b redo restored sketch 3")
	for cycle in [1, 2, 3]:
		await _reopen_exit(ctx, jaw)
		check(_feature_names(ctx).has("sketch 3"), "cycle %d still lists sketch 3" % cycle)
		check(not ctx.main.sketch_mode.active, "cycle %d left sketch mode" % cycle)
	var before_undo := _sketch_ids(ctx).size()
	await _part_undo(ctx)
	check(not _feature_names(ctx).has("sketch 3"), "one Ctrl+Z after 3 no-op cycles removes sketch 3")
	check(_sketch_ids(ctx).size() == before_undo - 1, "sketch count dropped after the cycles")
	await _part_redo(ctx)
	check(_feature_names(ctx).has("sketch 3"), "redo after the cycles brings sketch 3 back")
	await _real_edit(ctx, jaw)
	ctx.main.queue_free()
	await process_frame


func _snapshot_cases(sm: SketchMode) -> void:
	var base := '{"entities":[{"id":"e1","type":"line","params":[0,1]}],"constraints":[{"id":"c1","type":"distance","value":20.0,"driving":true,"refs":[{"entity":"e1","role":"self"}]}],"params":[1.0,2.0]}'
	check(sm._snapshots_equal(base, base), "identical snapshots are equal")
	var tiny := base.replace("1.0,2.0", "1.000000000001,2.0")
	check(sm._snapshots_equal(base, tiny), "a parameter +1e-12 is still equal")
	var coarse := base.replace("1.0,2.0", "1.000001,2.0")
	check(not sm._snapshots_equal(base, coarse), "a parameter +1e-6 is not equal")
	var dropped := base.replace(',"constraints":[{"id":"c1","type":"distance","value":20.0,"driving":true,"refs":[{"entity":"e1","role":"self"}]}]', ',"constraints":[]')
	check(not sm._snapshots_equal(base, dropped), "a removed constraint is not equal")
	var swapped := '{"entities":[{"id":"e2","type":"line","params":[0]},{"id":"e1","type":"line","params":[1]}],"constraints":[],"params":[1.0]}'
	var order := '{"entities":[{"id":"e1","type":"line","params":[1]},{"id":"e2","type":"line","params":[0]}],"constraints":[],"params":[1.0]}'
	check(not sm._snapshots_equal(swapped, order), "entity order is not equal")
	check(not sm._snapshots_equal("", base), "empty snapshot is not equal")
	check(sm._snapshots_equal("{}", "{}"), "empty objects are equal")


func _plate(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.set_snap(false)
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await FilmUI.draw_circle(ctx, sm, Vector2.ZERO, Vector2(10, 0))
	var fid := await FilmUI.exit_sketch(ctx)
	check(fid != "", "plate sketch saved")
	var ex := ctx.view.doc.graph_add_extrude(fid, 10.0, false, "new", "")
	ctx.view.graph_changed()
	await process_frame
	check(ex != "" and _feature_names(ctx).has("extrude 2"), "plate extrude is extrude 2 (got %s)" % str(_feature_names(ctx)))


func _jaw(ctx: FilmContext) -> String:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null, "Jaw is on the rail")
	if jaw != null:
		await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Jaw", "Jaw tool"))
	await _zoom_uv(ctx, Vector2(6, 4), 120.0)
	var dir := Vector2(cos(deg_to_rad(37.0)), sin(deg_to_rad(37.0)))
	var nrm := Vector2(-dir.y, dir.x)
	var ctr := Vector2(6.0, 4.0)
	await _click_uv_local(ctx, ctr, "Jaw centre")
	await _click_uv_local(ctx, ctr + dir * 22.0, "Jaw long side")
	await _click_uv_local(ctx, ctr + nrm * 7.0, "Jaw width")
	check(str(ctx.main.status_label.text).begins_with("Jaw committed"), "jaw committed")
	await _release_focus(ctx)
	return await FilmUI.exit_sketch(ctx)


func _reopen_exit(ctx: FilmContext, fid: String) -> void:
	await _show_timeline(ctx)
	var pencil := _row_edit(ctx, fid)
	check(pencil != null, "timeline pencil is visible")
	if pencil != null:
		await FilmUI.click_control(ctx, pencil, FilmUICues.alert("Edit", "timeline pencil"))
		await process_frame
		await process_frame
	check(ctx.main.sketch_mode.active, "pencil reopened the sketch")
	await _release_focus(ctx)
	_push_key_local(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await process_frame
	var saved := await FilmUI.exit_sketch(ctx)
	check(saved == fid or str(ctx.main.status_label.text).contains("Sketch saved"), "Esc / Exit saved the sketch")


func _real_edit(ctx: FilmContext, fid: String) -> void:
	await _show_timeline(ctx)
	var pencil := _row_edit(ctx, fid)
	if pencil != null:
		await FilmUI.click_control(ctx, pencil, FilmUICues.alert("Edit", "timeline pencil"))
		await process_frame
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "real-edit sketch is open")
	var moved := false
	if sm.sketch != null:
		for id in sm.sketch.entity_ids():
			var info: Dictionary = sm.sketch.entity_info(str(id))
			if str(info.get("type", "")) != "line":
				continue
			var a: Vector2 = info.get("start", Vector2.ZERO)
			await _click_uv_local(ctx, a, "point")
			await _drag_uv(ctx, a, a + Vector2(3, 1))
			moved = true
			break
	check(moved, "dragged a jaw point")
	await _release_focus(ctx)
	await FilmUI.exit_sketch(ctx)
	var names_before := _feature_names(ctx)
	await _part_undo(ctx)
	check(str(ctx.main.status_label.text).begins_with("Undo"), "real edit undo status is Undo")
	check(_feature_names(ctx) != names_before or not ctx.main.sketch_mode.active, "real edit undo changed the document")


func _feature_names(ctx: FilmContext) -> PackedStringArray:
	var names := PackedStringArray()
	for f in ctx.view.doc.graph_features():
		names.append(str(f.get("name", "")))
	return names


func _sketch_ids(ctx: FilmContext) -> PackedStringArray:
	var ids := PackedStringArray()
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			ids.append(str(f.get("id", "")))
	return ids


func _part_undo(ctx: FilmContext) -> void:
	await _release_focus(ctx)
	_push_key_local(ctx.main.get_viewport(), KEY_Z, true, false)
	await process_frame
	await process_frame
	check(str(ctx.main.status_label.text).begins_with("Undo"), "part Ctrl+Z says Undo (got `%s`)" % ctx.main.status_label.text)


func _part_redo(ctx: FilmContext) -> void:
	await _release_focus(ctx)
	_push_key_local(ctx.main.get_viewport(), KEY_Z, true, true)
	await process_frame
	await process_frame
	check(str(ctx.main.status_label.text).begins_with("Redo"), "part Ctrl+Shift+Z says Redo (got `%s`)" % ctx.main.status_label.text)


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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	return ctx


func _show_timeline(ctx: FilmContext) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	if ctx.main.timeline != null:
		ctx.main.timeline.refresh()
	await process_frame
	await process_frame


func _row_edit(ctx: FilmContext, fid: String) -> Button:
	var tl: TimelinePanel = ctx.main.timeline
	if tl == null or fid == "":
		return null
	var row: Control = tl._rows.get(fid) as Control
	if row == null:
		return null
	var named := row.get_node_or_null("RowEdit") as Button
	if named != null:
		return named
	for c in row.get_children():
		var b := c as Button
		if b != null and str(b.tooltip_text) == "Edit sketch":
			return b
	return null


func _uv_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	return FilmUI.model_to_screen(ctx, ctx.main.sketch_mode.to_model(uv))


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s on screen" % desc)
	_pointer(ctx.main.get_viewport(), screen, true)
	await process_frame
	await process_frame


func _drag_uv(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var sa := _uv_screen(ctx, a)
	var sb := _uv_screen(ctx, b)
	_motion(vp, sa)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = sa
	down.global_position = sa
	vp.push_input(down)
	_motion(vp, sb)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = sb
	up.global_position = sb
	vp.push_input(up)
	await process_frame
	await process_frame


func _pointer(vp: Viewport, pos: Vector2, click: bool) -> void:
	_motion(vp, pos)
	if not click:
		return
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


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


func _push_key_local(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		vp.push_input(ev)


func _release_focus(ctx: FilmContext) -> void:
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		cam.sketch_orientation_locked = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var pivot := sm.to_model(uv) if sm != null else Vector3.ZERO
	cam.pivot = ms.to_global(pivot) if ms != null else pivot
	cam.distance = size_mm / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame
