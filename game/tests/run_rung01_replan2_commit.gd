# Rung 1 replan 2 WP2 — typed length wins over the cursor.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan2_commit.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const POINTER_AF := 10.438

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
	print("rung01 replan2 WP2 commit")
	_assert_test_source()
	FilmUI.reset_fail_count()
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
	await FilmUI.ensure_test_viewport(ctx)
	main.sketch_mode.status.connect(func(text: String) -> void:
		_status_log.append(text)
		print("  status: " + text))

	await test_empty_new_sketch(ctx)
	await test_typed_20_beats_cursor_4(ctx)
	await test_typed_circle_radius_5(ctx)
	await test_pointer_af_control(ctx)
	await test_typed_too_short(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_test_source() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan2_commit.gd")
	check(src.find("set_length_override(") < 0,
			"test source does not call set_length_override")
	check(src.find("edit.text") < 0 and src.find("LineEdit.text") < 0,
			"test source does not assign LineEdit text")
	check(src.find("set_extrude_distance") < 0,
			"test source does not call set_extrude_distance")
	check(src.find("export_3mf(") < 0,
			"test source does not call export_3mf")


func test_empty_new_sketch(ctx: FilmContext) -> void:
	print("- empty new sketch: is_empty_new_sketch and discard status")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.has_method("is_empty_new_sketch"), "is_empty_new_sketch is published")
	check(sm.is_empty_new_sketch(), "fresh sketch is_empty_new_sketch is true")
	_status_log.clear()
	var fid := sm.exit_sketch()
	check(fid == "", "empty exit returns no feature id")
	check(not sm.active, "empty exit leaves sketch mode")
	var st := _joined_status()
	check(st.contains("Empty sketch discarded — nothing was drawn"),
			"empty exit status is the discard sentence (%s)" % st)
	check(not st.contains("Sketch saved"),
			"empty exit does not emit Sketch saved (%s)" % st)


func test_typed_20_beats_cursor_4(ctx: FilmContext) -> void:
	print("- typed 20 beats a 4 mm cursor; Polygon AF 20.0000")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats without a chip click (got %s)" % sm.tool_variant)
	check(sm.is_empty_new_sketch(), "sketch is empty before the hex")
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Hex centre")
	check(sm.has_single_dof_preview(), "polygon preview is active after the centre click")
	await _hover_uv(ctx, Vector2(4, 0))
	await _type_into_dim(ctx, "20", false)
	await process_frame
	check(sm.has_length_override() or _dim_edit(ctx).text.contains("20"),
			"typed 20 is in the dim blank or locked as an override")
	var before := _entity_count(sm)
	await _click_uv(ctx, Vector2(4, 0), "Cursor 4 mm along +X")
	await process_frame
	await process_frame
	check(_entity_count(sm) > before, "second click committed the hex")
	_assert_hex_af(sm, 20.0, 0.15)
	check(sm.has_method("last_commit_text"), "last_commit_text is published")
	var sentence := sm.last_commit_text() if sm.has_method("last_commit_text") else ""
	check(sentence.contains("Polygon AF 20.0000"),
			"last_commit_text contains Polygon AF 20.0000 (got '%s')" % sentence)
	check(not sentence.contains("centre-to-flat"),
			"AF commit is not centre-to-flat")
	check(not sm.is_empty_new_sketch(), "is_empty_new_sketch is false after the hex")


func test_typed_circle_radius_5(ctx: FilmContext) -> void:
	print("- typed 5 beats a 2 mm cursor; Circle r=5.0000 (Ø10.0000)")
	var sm: SketchMode = ctx.main.sketch_mode
	if not sm.active:
		await _file_new(ctx)
		await _ground_sketch(ctx)
		sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Circle centre")
	await _hover_uv(ctx, Vector2(2, 0))
	await _type_into_dim(ctx, "5", false)
	await process_frame
	await _click_uv(ctx, Vector2(2, 0), "Cursor 2 mm along +X")
	await process_frame
	await process_frame
	var circ := _first_of(sm, "circle")
	check(circ != "", "circle created")
	if circ != "":
		var r := float(sm.sketch.entity_info(circ)["radius"])
		check(absf(r - 5.0) <= 0.05, "typed 5 is radius 5 (got %.4f)" % r)
	var sentence := sm.last_commit_text() if sm.has_method("last_commit_text") else ""
	check(sentence.contains("r=5.0000") and sentence.contains("Ø10.0000"),
			"last_commit_text contains r=5.0000 and Ø10.0000 (got '%s')" % sentence)


func test_pointer_af_control(ctx: FilmContext) -> void:
	print("- no override: pointer click at 10.438 mm is AF 10.438")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Pointer hex centre")
	check(not sm.has_length_override(), "control case has no length override")
	await _hover_uv(ctx, Vector2(POINTER_AF, 0))
	await _click_uv(ctx, Vector2(POINTER_AF, 0), "Pointer 10.438 mm along +X")
	await process_frame
	await process_frame
	_assert_hex_af(sm, POINTER_AF, 0.05)


func test_typed_too_short(ctx: FilmContext) -> void:
	print("- typed 0.1 commits nothing and status is Too short")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await _click_uv(ctx, Vector2.ZERO, "Short hex centre")
	await _hover_uv(ctx, Vector2(8, 0))
	var before := _entity_count(sm)
	_status_log.clear()
	await _type_into_dim(ctx, "0.1", true)
	await process_frame
	await process_frame
	check(_entity_count(sm) == before, "typed 0.1 adds no polygon entities")
	var st := _joined_status()
	check(st.contains("Too short"), "typed 0.1 status contains Too short (%s)" % st)
	check(sm.active and sm.has_single_dof_preview(),
			"too-short leave the polygon preview up")


func _assert_hex_af(sm: SketchMode, af: float, tol: float) -> void:
	var ys: Array[float] = []
	var on_x := false
	var half := af * 0.5
	var circum := af / sqrt(3.0)
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for p in [info["start"], info["end"]]:
			var v: Vector2 = p
			ys.append(v.y)
			if absf(v.y) <= 0.2 and absf(absf(v.x) - circum) <= maxf(tol, 0.2):
				on_x = true
	if ys.is_empty():
		check(false, "hex vertices for AF %.4f" % af)
		return
	ys.sort()
	check(absf(ys[0] + half) <= tol and absf(ys[ys.size() - 1] - half) <= tol,
			"flats at y=±%.4f (%.4f .. %.4f)" % [half, ys[0], ys[ys.size() - 1]])
	if is_equal_approx(af, 20.0):
		check(on_x, "vertices on ±X for AF 20")


func _file_new(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
		if exit_btn != null and exit_btn.is_visible_in_tree() and not sm.is_empty_new_sketch():
			await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
		elif sm.active:
			sm.cancel()
		await process_frame
	ctx.main._file_popup.id_pressed.emit(0)
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible:
		dlg.confirmed.emit()
		await process_frame
	await process_frame


func _ground_sketch(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "sketch session is open")


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


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, sm.to_model(uv), size_mm)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	await FilmUI.click_sketch(ctx, ctx.main.sketch_mode, uv, desc)


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await process_frame


func _dim_edit(ctx: FilmContext) -> LineEdit:
	return ctx.main.sketch_chrome._dim_spin.get_line_edit()


func _type_into_dim(ctx: FilmContext, text: String, press_enter: bool) -> void:
	var edit := _dim_edit(ctx)
	await _click_control(edit)
	if not edit.has_focus():
		edit.grab_focus()
		await process_frame
	if not edit.is_editing():
		edit.edit()
		await process_frame
	edit.select_all()
	await process_frame
	await _push_text(edit.get_viewport(), text)
	await process_frame
	if press_enter:
		await _push_key(edit.get_viewport(), KEY_ENTER, 0)
		await process_frame
		await process_frame


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var hover := InputEventMouseMotion.new()
	hover.position = pos
	hover.global_position = pos
	vp.push_input(hover)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
	await process_frame


func _push_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		var key := KEY_PERIOD if code == 46 else KEY_0 + (code - 48)
		await _push_key(vp, key as Key, code)


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _entity_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return 0
	return sm.sketch.entity_ids().size()


func _first_of(sm: SketchMode, kind: String) -> String:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			return id
	return ""


func _joined_status() -> String:
	if _status_log.is_empty():
		return ""
	return " | ".join(_status_log)
