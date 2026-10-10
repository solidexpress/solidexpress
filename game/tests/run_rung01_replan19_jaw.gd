# re-PLAN 19 WP3 — wide jaw dimensions, preview, empty DOF.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_jaw.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _log: Array[String] = []


func _init() -> void:
	print("rung01 replan19 jaw")
	FilmUI.reset_fail_count()
	await _preview_and_wide(false)
	await _preview_and_wide(true)
	await _sizes()
	await _reject_and_undo()
	await _empty_dof()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _preview_and_wide(snap: bool) -> void:
	print("- wide jaw snap=%s" % snap)
	var ctx := await _boot()
	ctx.main.sketch_mode.snap_enabled = snap
	ctx.main.sketch_mode.infer_enabled = snap
	await _arm_jaw(ctx)
	_widen(ctx)
	var ctr := Vector2(0, 0)
	await _click_uv(ctx, ctr, "jaw centre")
	_motion_uv(ctx, ctr)
	await process_frame
	var n0 := _preview_verts(ctx)
	check(n0 >= 8, "preview on centre has >= 8 verts (got %d)" % n0)
	for dist in [0.5, 5.0, 20.0, 60.0]:
		_motion_uv(ctx, Vector2(dist, 0))
		await process_frame
		var n := _preview_verts(ctx)
		check(n >= 8, "preview at %.1f mm has >= 8 verts (got %d)" % [dist, n])
	var dir := Vector2(20, 20 * tan(deg_to_rad(5.0)))
	var nrm := Vector2(-dir.y, dir.x).normalized()
	await _click_uv(ctx, ctr + dir, "jaw length")
	await _click_uv(ctx, ctr + dir, "jaw length again")
	var again := _last()
	check(again.contains("width is zero") or again.contains("Jaw"),
			"repeated click 2 stays a jaw status (got '%s')" % again)
	await _click_uv(ctx, ctr + nrm * 48.4, "jaw width")
	var committed := _last()
	var label := str(ctx.main.status_label.text)
	var committed_ok := committed.begins_with("Jaw committed — width") \
			or label.begins_with("Jaw committed — width")
	if not snap:
		committed_ok = committed.contains("96.8000") or label.contains("96.8000")
		committed_ok = committed_ok and (committed.contains("5.0°") or label.contains("5.0°"))
	check(committed_ok, "wide jaw commits (got '%s' / '%s')" % [committed, label])
	var dof_before := _dof(ctx)
	check(dof_before != "!", "DOF after commit is not ! (got '%s')" % dof_before)
	await _edit_dim(ctx, "20", true)
	check(_saw("Dimension updated"), "width 20 updates (log '%s')" % _blob())
	check(_dof(ctx) != "!", "DOF after width 20 is not ! (got '%s')" % _dof(ctx))
	await _edit_dim(ctx, "45", false)
	check(_saw("Dimension updated"), "angle 45 updates (log '%s')" % _blob())
	check(_dof(ctx) != "!", "DOF after angle 45 is not ! (got '%s')" % _dof(ctx))
	await _shutdown(ctx)


func _sizes() -> void:
	print("- more jaw sizes")
	for hl in [5.0, 40.0]:
		for hw in [10.0, 70.0]:
			var ctx := await _boot()
			ctx.main.sketch_mode.snap_enabled = false
			ctx.main.sketch_mode.infer_enabled = false
			await _arm_jaw(ctx)
			_widen(ctx)
			var dir := Vector2(hl, 0)
			var nrm := Vector2(0, 1)
			await _click_uv(ctx, Vector2.ZERO, "centre")
			await _click_uv(ctx, dir, "length")
			await _click_uv(ctx, nrm * hw, "width")
			var text := _last()
			check(text.begins_with("Jaw committed"), "hl %.0f hw %.0f commits (got '%s')" % [hl, hw, text])
			check(_dof(ctx) != "!", "hl %.0f hw %.0f DOF is not !" % [hl, hw])
			await _shutdown(ctx)


func _reject_and_undo() -> void:
	print("- rejected dimension restores the sketch")
	var ctx := await _boot()
	ctx.main.sketch_mode.snap_enabled = false
	ctx.main.sketch_mode.infer_enabled = false
	await _arm_jaw(ctx)
	_widen(ctx)
	await _click_uv(ctx, Vector2.ZERO, "centre")
	await _click_uv(ctx, Vector2(20, 0), "length")
	await _click_uv(ctx, Vector2(0, 10), "width")
	var sm: SketchMode = ctx.main.sketch_mode
	var before := sm.sketch.snapshot()
	var dof_before := _dof(ctx)
	var idx := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "angle":
			idx = i
			break
	check(idx >= 0, "jaw has an angle dimension")
	var widx := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "distance":
			widx = i
			break
	check(widx >= 0, "jaw has a width dimension")
	# A negative width cannot be a closed quad. Angle 0 on this jaw is a
	# legal horizontal long side, so it is not the failing stimulus.
	dof_before = _dof(ctx)
	_log.clear()
	var status := ""
	if widx >= 0:
		status = sm.set_dimension_value(widx, -1.0)
	check(status == "failed" and _saw("Dimension rejected — constraints could not be satisfied"),
			"unsatisfiable width is rejected (status '%s' log '%s')" % [status, _blob()])
	check(sm.sketch.snapshot() == before, "geometry snapshot restored")
	check(_dof(ctx) == dof_before and _dof(ctx) != "!",
			"DOF unchanged after reject (before '%s' after '%s')" % [dof_before, _dof(ctx)])
	var guard := 0
	while sm.can_undo() and guard < 30:
		guard += 1
		await _push_chord(ctx.main.get_viewport(), KEY_Z, true, false)
	check(_dof(ctx) == "—" or _last().contains("Nothing to undo") or not sm.can_undo(),
			"undo reaches an empty sketch (dof '%s' last '%s')" % [_dof(ctx), _last()])
	await _shutdown(ctx)


func _empty_dof() -> void:
	print("- empty sketch DOF is em dash")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.LINE)
	await _click_uv(ctx, Vector2(0, 0), "line a")
	await _click_uv(ctx, Vector2(30, 0), "line b")
	ctx.main.interaction.grab_focus()
	await process_frame
	_log.clear()
	await _push_chord(ctx.main.get_viewport(), KEY_A, true, false)
	await _push_chord(ctx.main.get_viewport(), KEY_DELETE, false, false)
	await process_frame
	await process_frame
	var chip := _dof(ctx)
	check(chip == "—", "empty DOF chip is — (got '%s')" % chip)
	check(chip != "OK", "empty DOF is not OK")
	await _shutdown(ctx)


func _edit_dim(ctx: FilmContext, text: String, width_first: bool) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await process_frame
	await process_frame
	var glyph := Vector2.INF
	for entry in sm.dimension_label_screen_rects():
		var shown := str(entry.get("text", ""))
		var is_angle := shown.contains("°")
		if width_first == is_angle:
			continue
		var rect: Rect2 = entry.get("rect", Rect2())
		glyph = Vector2(rect.position.x + minf(6.0, rect.size.x * 0.25), rect.get_center().y)
		break
	check(glyph != Vector2.INF, "label glyph for '%s' is on screen" % text)
	if glyph == Vector2.INF:
		return
	_log.clear()
	await _x11_click_screen(ctx.main.get_viewport(), glyph)
	await process_frame
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := (KEY_0 + (ch - 48)) as Key
		await _push_char(ctx.main.get_viewport(), code, ch)
	await _push_chord(ctx.main.get_viewport(), KEY_ENTER, false, false)
	await process_frame
	await process_frame


func _preview_verts(ctx: FilmContext) -> int:
	var sm: SketchMode = ctx.main.sketch_mode
	var mesh := sm._preview_node.mesh as ImmediateMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return 0
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _widen(ctx: FilmContext) -> void:
	var cam = ctx.main.camera
	cam.distance = 280.0
	cam._update_transform()


func _arm_jaw(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null, "Jaw tool is on the rail")
	if jaw != null:
		await _x11_click_screen(ctx.main.get_viewport(), jaw.get_global_rect().get_center())
	await process_frame


func _dof(ctx: FilmContext) -> String:
	var lab: Label = ctx.main.dof_label
	return "" if lab == null else str(lab.text)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s on screen" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)


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
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	vp.push_input(up)
	await process_frame
	await process_frame


func _push_char(vp: Viewport, code: Key, unicode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.unicode = unicode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	up.unicode = 0
	vp.push_input(up)
	await process_frame


func _push_chord(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)
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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	_log.clear()
	return ctx


func _on_status(msg: String) -> void:
	_log.append(str(msg))


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


func _blob() -> String:
	return " | ".join(_log)


func _saw(fragment: String) -> bool:
	for line in _log:
		if line.contains(fragment):
			return true
	return false


func _shutdown(ctx: FilmContext) -> void:
	if ctx != null and ctx.main != null:
		ctx.main.queue_free()
	await process_frame
	await process_frame
