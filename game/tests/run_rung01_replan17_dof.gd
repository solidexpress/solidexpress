# DOF chip after leaving a sketch and reopening it.
# Jaw + two driving dims, Exit, part Ctrl+Z / Ctrl+Shift+Z, Timeline pencil.
# The chip text after the pencil must equal the text from before Exit.
# "—" is only for an empty sketch.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan17_dof.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const EMPTY_CHIP := "—"

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
	print("rung01 replan17 DOF chip on sketch reopen")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _on_status(msg: String) -> void:
	_log.append(str(msg))


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	main.timeline.status.connect(_on_status)
	return ctx


func _uv_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	return FilmUI.model_to_screen(ctx, sm.to_model(uv))


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
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
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s on screen at %s" % [desc, str(screen)])
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _push_key(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		ev.echo = false
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		vp.push_input(ev)
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


func _release_focus(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var owner: Control = vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
	await process_frame


func _sketch_ids(ctx: FilmContext) -> PackedStringArray:
	var ids := PackedStringArray()
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			ids.append(str(f.get("id", "")))
	return ids


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
		if b == null or b is CheckBox:
			continue
		if str(b.tooltip_text) == "Edit sketch":
			return b
	return null


func _dim_kinds(sm: SketchMode) -> Dictionary:
	var kinds := {}
	for dim in sm.dimensions:
		var t := str(dim.get("type", ""))
		kinds[t] = int(kinds.get(t, 0)) + 1
	return kinds


func _run() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch is active")
	check(ctx.main.dof_label != null, "DOF chip exists")
	check(ctx.main.dof_label.text == EMPTY_CHIP,
			"empty sketch chip is — (got `%s`)" % ctx.main.dof_label.text)
	sm.set_snap(false)
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null and jaw.is_visible_in_tree(), "Jaw is on the sketch rail")
	if jaw != null:
		await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Jaw", "Jaw tool"))
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
			"Jaw arms Center Three Point")
	var dir := Vector2(cos(deg_to_rad(37.0)), sin(deg_to_rad(37.0)))
	var nrm := Vector2(-dir.y, dir.x)
	var ctr := Vector2(6.0, 4.0)
	await _zoom_uv(ctx, ctr, 120.0)
	await _click_uv(ctx, ctr, "Jaw centre")
	await _click_uv(ctx, ctr + dir * 22.0, "Jaw long side")
	await _click_uv(ctx, ctr + nrm * 7.0, "Jaw width")
	var committed := _last()
	var label := str(ctx.main.status_label.text)
	check(committed.begins_with("Jaw committed — width") or label.begins_with("Jaw committed — width"),
			"jaw committed (got `%s`)" % label)
	var kinds := _dim_kinds(sm)
	check(int(kinds.get("distance", 0)) >= 1 and int(kinds.get("angle", 0)) >= 1,
			"jaw has a distance dim and an angle dim (got %s)" % str(kinds))
	var before := str(ctx.main.dof_label.text)
	check(before != EMPTY_CHIP and before != "— DOF" and before != "",
			"pre-exit chip is a solved count (got `%s`)" % before)
	var sketches_before := _sketch_ids(ctx)
	await _release_focus(ctx)
	var fid := await FilmUI.exit_sketch(ctx)
	check(fid != "" and not sm.active, "Exit Sketch saved and left the session (fid `%s`)" % fid)
	check(_sketch_ids(ctx).size() == sketches_before.size() + 1,
			"the jaw sketch is on the timeline")
	await _show_timeline(ctx)
	var listed := _sketch_ids(ctx).size()
	await _release_focus(ctx)
	_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_Z, true, false)
	var undo_line := str(ctx.main.status_label.text)
	check(undo_line.begins_with("Undo"), "part Ctrl+Z begins Undo (got `%s`)" % undo_line)
	check(_sketch_ids(ctx).size() == listed - 1, "part Ctrl+Z removed the jaw sketch")
	_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_Z, true, true)
	var redo_line := str(ctx.main.status_label.text)
	check(redo_line.begins_with("Redo"), "part Ctrl+Shift+Z begins Redo (got `%s`)" % redo_line)
	var restored := _sketch_ids(ctx)
	check(restored.size() == listed and fid in restored,
			"part redo restored the jaw sketch")
	await _show_timeline(ctx)
	var pencil := _row_edit(ctx, fid)
	check(pencil != null and pencil.is_visible_in_tree(), "timeline pencil is visible")
	_log.clear()
	if pencil != null:
		await FilmUI.click_control(ctx, pencil, FilmUICues.alert("Edit", "timeline pencil"))
		await process_frame
		await process_frame
	var status_now := str(ctx.main.status_label.text)
	check(sm.active and (status_now.contains("Editing sketch") or _last().contains("Editing sketch")),
			"pencil reopens the sketch (active=%s status `%s`)" % [str(sm.active), status_now])
	var after := str(ctx.main.dof_label.text)
	check(after == before,
			"reopened DOF chip equals the pre-exit text (before `%s` now `%s`)" % [before, after])
	check(after != "— DOF", "reopened chip is not the empty placeholder `— DOF`")
	check(sm.sketch != null and not sm.sketch.entity_ids().is_empty(),
			"reopened sketch still has the jaw")
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	ctx.main.queue_free()
	await process_frame
	await process_frame
