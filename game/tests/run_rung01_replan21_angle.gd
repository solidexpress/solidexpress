# re-PLAN 21 WP4 — a jaw angle never reads a flipped direction.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan21_angle.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmJaw = preload("res://tests/lib/film_jaw.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan21 angle")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var ctx := await _boot()
	_unit_cases(ctx.main.sketch_mode)
	for side in [1.0, -1.0]:
		await _fresh_sketch(ctx)
		await _draw_jaw(ctx, side)
		await _assert_angle(ctx, "side %s" % side)
	for cycles in [1, 2]:
		await _fresh_sketch(ctx)
		await _draw_jaw(ctx, 1.0)
		var fid := await FilmUI.exit_sketch(ctx)
		for _i in cycles:
			await _reopen(ctx, fid)
			await FilmUI.exit_sketch(ctx)
		await _reopen(ctx, fid)
		await _assert_angle(ctx, "reopen %d" % cycles)
	for undos in [0, 1, 2]:
		for redos in [0, 1, 2]:
			if undos == 0 and redos == 0:
				continue
			await _fresh_sketch(ctx)
			await _draw_jaw(ctx, 1.0)
			var pencil_fid := await FilmUI.exit_sketch(ctx)
			for _u in undos:
				_push_key(ctx.main.get_viewport(), KEY_Z, true, false)
				await process_frame
			for _r in redos:
				_push_key(ctx.main.get_viewport(), KEY_Z, true, true)
				await process_frame
			if _feature_named(ctx, "sketch"):
				await _reopen(ctx, pencil_fid)
				await _assert_angle(ctx, "undo %d redo %d" % [undos, redos])
	await _fresh_sketch(ctx)
	await _draw_jaw(ctx, 1.0)
	var fid2 := await FilmUI.exit_sketch(ctx)
	await _reopen(ctx, fid2)
	for _i in 12:
		_push_key(ctx.main.get_viewport(), KEY_Z, true, false)
		await process_frame
		if str(ctx.main.status_label.text).contains("Nothing to undo"):
			break
	for _i in 12:
		_push_key(ctx.main.get_viewport(), KEY_Z, true, true)
		await process_frame
	if ctx.main.sketch_mode.active:
		await _assert_angle(ctx, "sketch undo redo")
	await _delete_redraw(ctx)
	await _circles_and_trim(ctx, true)
	await _circles_and_trim(ctx, false)
	ctx.main.queue_free()
	await process_frame


func _unit_cases(sm: SketchMode) -> void:
	var cases := [
		[135.0, 45.0], [-45.0, 45.0], [-135.0, 45.0], [0.0, 0.0],
		[90.0, 90.0], [5.0, 5.0], [45.0, 45.0], [-90.0, 90.0],
		[180.0, 0.0], [-180.0, 0.0], [120.0, 60.0], [-120.0, 60.0],
	]
	for row in cases:
		var got: float = sm._jaw_angle_from_direction(Vector2.from_angle(deg_to_rad(row[0])))
		check(absf(got - row[1]) < 0.05, "wall %.0f° reads %.0f° (got %.3f)" % [row[0], row[1], got])
		check(got >= 0.0 and got <= 90.0, "wall %.0f° stays in (0, 90] (got %.3f)" % [row[0], got])


func _assert_angle(ctx: FilmContext, tag: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if not sm.active:
		check(false, "%s sketch is open" % tag)
		return
	var texts: Array = []
	for entry in FilmJaw.drawn_labels(sm):
		texts.append(str(entry.get("text", "")))
	var degrees: Array = []
	for t in texts:
		if str(t).contains("°"):
			degrees.append(str(t))
	var one := degrees.size() == 1 and _is_plain_degree(str(degrees[0]))
	check(one, "%s one plain degree label (got %s)" % [tag, str(degrees)])
	var reads_45 := one and str(degrees[0]).replace(" ", "").begins_with("45")
	check(reads_45, "%s label reads 45° (got %s)" % [tag, str(degrees)])
	var minus := false
	for t in texts:
		if str(t).contains("-"):
			minus = true
	check(not minus, "%s no label contains a minus (got %s)" % [tag, str(texts)])
	var editor := await _editor_text(ctx, true)
	check(editor.begins_with("45") and not editor.contains("-"), "%s editor reads 45 (got `%s`)" % [tag, editor])
	await _dismiss_editor(ctx)
	var angle_ok := false
	var angle_n := 0
	for dim in sm.dimensions:
		if str(dim.get("callout", "")) != "jaw_angle" and not (str(dim.get("type", "")) == "angle" and sm._ids_are_jaw_angle(dim.get("ids", []))):
			continue
		angle_n += 1
		var deg := rad_to_deg(float(dim.get("value", 0.0)))
		angle_ok = deg > -90.0 and deg <= 90.0 and absf(deg - 45.0) < 0.2
	check(angle_n == 1 and angle_ok, "%s one jaw angle record in (−90°, 90°] (n=%d)" % [tag, angle_n])


func _is_plain_degree(text: String) -> bool:
	var body := text.replace(" ", "").trim_suffix("°")
	if body == "" or body.contains("-"):
		return false
	return body.is_valid_float()


func _draw_jaw(ctx: FilmContext, side: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	if jaw != null:
		await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Jaw", "Jaw"))
	var dir := Vector2(1, 1).normalized()
	var nrm := Vector2(-dir.y, dir.x) * side
	var ctr := Vector2(20, 10)
	await _zoom_uv(ctx, ctr, 140.0)
	await _click_uv(ctx, ctr)
	await _click_uv(ctx, ctr + dir * 30.0)
	await _click_uv(ctx, ctr + dir * 30.0 + nrm * 10.0)
	await process_frame
	check(str(ctx.main.status_label.text).begins_with("Jaw committed"), "jaw committed side %s" % side)


func _editor_text(ctx: FilmContext, degree: bool) -> String:
	var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	if sel != null:
		await FilmUI.click_control(ctx, sel, FilmUICues.alert("Select", "Select"))
	var sm: SketchMode = ctx.main.sketch_mode
	var pos := FilmJaw.click_label_first_glyph(ctx.main.get_viewport(), sm, degree)
	await process_frame
	await process_frame
	var ix = ctx.main.interaction
	if ix != null and ix._dim_edit_line != null and ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		return str(ix._dim_edit_line.text)
	return "" if pos == Vector2.ZERO else str(ctx.main.get_viewport().gui_get_focus_owner())


func _dismiss_editor(ctx: FilmContext) -> void:
	_push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await process_frame


func _fresh_sketch(ctx: FilmContext) -> void:
	if ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)
	ctx.view.new_document()
	await process_frame
	await FilmUI.enter_sketch(ctx)
	ctx.main.sketch_mode.set_snap(false)


func _reopen(ctx: FilmContext, fid: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	if ctx.main.timeline != null:
		ctx.main.timeline.refresh()
	await process_frame
	var tl: TimelinePanel = ctx.main.timeline
	var row: Control = tl._rows.get(fid) as Control if tl != null else null
	var pencil: Button = row.get_node_or_null("RowEdit") as Button if row != null else null
	if pencil != null:
		await FilmUI.click_control(ctx, pencil, FilmUICues.alert("Edit", "pencil"))
		await process_frame
		await process_frame


func _delete_redraw(ctx: FilmContext) -> void:
	if not ctx.main.sketch_mode.active:
		await _fresh_sketch(ctx)
		await _draw_jaw(ctx, 1.0)
	var sm: SketchMode = ctx.main.sketch_mode
	var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	if sel != null:
		await FilmUI.click_control(ctx, sel, FilmUICues.alert("Select", "Select"))
	var ids: PackedStringArray = sm.sketch.entity_ids() if sm.sketch != null else PackedStringArray()
	for id in ids:
		var info: Dictionary = sm.sketch.entity_info(str(id))
		var p: Vector2 = info.get("start", info.get("center", Vector2.ZERO))
		await _click_uv(ctx, p)
		_push_key(ctx.main.get_viewport(), KEY_DELETE, false, false)
		await process_frame
	await _draw_jaw(ctx, -1.0)
	await _assert_angle(ctx, "delete redraw")


func _circles_and_trim(ctx: FilmContext, outer: bool) -> void:
	await _fresh_sketch(ctx)
	await _draw_jaw(ctx, 1.0 if outer else -1.0)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(5, 0))
	await FilmUI.draw_circle(ctx, sm, Vector2(40, 0), Vector2(50, 0))
	await FilmUI.draw_line(ctx, sm, Vector2(30, 12), Vector2(48, -8))
	var trim := FilmUI.find_sketch_tool_button(ctx.main, "Trim")
	if trim != null:
		await FilmUI.click_control(ctx, trim, FilmUICues.alert("Trim", "Trim"))
	if outer:
		await _drag_uv(ctx, Vector2(46, -4), Vector2(40, 0))
	else:
		await _click_uv(ctx, Vector2(30, 12))
	await process_frame
	await _assert_angle(ctx, "trim %s" % ("outer" if outer else "inner"))


func _feature_named(ctx: FilmContext, type_name: String) -> bool:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch" and type_name == "sketch":
			return true
	return false


func _last_sketch(ctx: FilmContext) -> String:
	var fid := ""
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			fid = str(f.get("id", ""))
	return fid


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


func _click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var screen: Vector2 = FilmUI.model_to_screen(ctx, ctx.main.sketch_mode.to_model(uv))
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
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
	await process_frame


func _drag_uv(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var va: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(a))
	var vb: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(b))
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = va
	motion.global_position = va
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = va
	down.global_position = va
	vp.push_input(down)
	motion = InputEventMouseMotion.new()
	motion.position = vb
	motion.global_position = vb
	vp.push_input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = vb
	up.global_position = vb
	vp.push_input(up)
	await process_frame


func _push_key(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		vp.push_input(ev)


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
