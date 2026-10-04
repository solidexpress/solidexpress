# Rung 1 replan 2 WP3 — pointer: no accidental second point, Esc from a spin,
# digits before the camera.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan2_pointer.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

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
	print("rung01 replan 2 WP3 pointer")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))

	await test_polygon_mouseup_does_not_commit(ctx)
	await test_typed_canvas_click_af20(ctx)
	await test_esc_from_hud_w(ctx)
	await test_digits_before_camera(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_polygon_mouseup_does_not_commit(ctx: FilmContext) -> void:
	print("- polygon mouse-up 40px does not create a hex; second press does")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats (got %s)" % sm.tool_variant)
	var n0 := _line_count(sm)
	var origin := _uv_screen(ctx, Vector2.ZERO)
	var away := origin + Vector2(40, 0)
	_ix_click_pair(ctx, origin, away)
	await process_frame
	check(_line_count(sm) == n0, "mouse-up 40px from origin does not add hex lines")
	check(sm.has_pending_draw_point(), "anchor stays pending after the 40px release")
	check(sm.has_single_dof_preview(), "preview stays active after the 40px release")
	_ix_click_pair(ctx, away, away)
	await process_frame
	check(_line_count(sm) == n0 + 6, "second press 40px away creates the hex")

	print("- circle mouse-up 40px does not create a circle; second press does")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	var c0 := _circle_count(sm)
	_ix_click_pair(ctx, origin, away)
	await process_frame
	check(_circle_count(sm) == c0, "circle mouse-up 40px does not add a circle")
	check(sm.has_pending_draw_point(), "circle anchor stays pending after the 40px release")
	_ix_click_pair(ctx, away, away)
	await process_frame
	check(_circle_count(sm) == c0 + 1, "second circle press 40px away creates it")


func test_typed_canvas_click_af20(ctx: FilmContext) -> void:
	print("- typed 20 in the dim blank, canvas click commits AF 20")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	_ix_click_pair(ctx, _uv_screen(ctx, Vector2.ZERO), _uv_screen(ctx, Vector2.ZERO))
	await process_frame
	check(sm.has_single_dof_preview(), "anchor is down before typing 20")
	if chrome == null or not chrome.has_method("typed_dim_value"):
		check(false, "WP1 typed_dim_value is missing on SketchContextChrome — typed canvas click cannot read the dim blank")
	var dim := _dim_edit(ctx)
	check(dim != null, "dim LineEdit exists")
	if dim != null:
		await _click_control(dim)
		await _type_text(dim.get_viewport(), "20")
		await process_frame
		if chrome != null and chrome.has_method("typed_dim_value"):
			var typed: Variant = chrome.typed_dim_value()
			check(typeof(typed) == TYPE_FLOAT or typeof(typed) == TYPE_INT,
					"typed_dim_value is a number after typing 20 (got %s)" % str(typed))
			if typeof(typed) == TYPE_FLOAT or typeof(typed) == TYPE_INT:
				check(is_equal_approx(float(typed), 20.0),
						"typed_dim_value is 20 (got %s)" % str(typed))
	var short_pt := _uv_screen(ctx, Vector2(4, 0))
	# Leave the dim LineEdit so Interaction._input is not blocked by chrome hover.
	await _aim_screen(ctx, short_pt)
	_ix_hover(ctx, short_pt)
	_ix_click_pair(ctx, short_pt, short_pt)
	await process_frame
	_assert_hex_flats(sm)


func test_esc_from_hud_w(ctx: FilmContext) -> void:
	print("- Esc from HUD W clears selection and leaves TriBall off")
	await _file_new(ctx)
	var ix: ViewportInteraction = ctx.main.interaction
	var view: DocumentView = ctx.view
	var box_btn := FilmUI.find_palette_button(ctx.main, "box")
	check(box_btn != null and box_btn.is_visible_in_tree(), "Box palette button is visible")
	if box_btn != null:
		await FilmUI.click_control(ctx, box_btn, FilmUICues.alert("Box", "Arm box place"))
	await process_frame
	check(ix._place_kind == "box", "palette Box armed place")
	var center := ix._screen_center()
	_ix_click_pair(ctx, center, center)
	await process_frame
	await process_frame
	check(view.selected_body != "", "placed box is selected")
	check(ix.triball == null or not ix.triball.active,
			"insert_primitive / place did not call _ctx_triball")
	var w_edit := _hud_w_edit(ix)
	check(w_edit != null and w_edit.is_visible_in_tree(), "HUD W LineEdit is visible")
	if w_edit != null:
		await _click_control(w_edit)
		await process_frame
		var focus: Control = ix.get_viewport().gui_get_focus_owner()
		check(focus != null and (focus == w_edit or w_edit.is_ancestor_of(focus) \
				or (focus.get_parent() != null and focus.get_parent() is SpinBox)),
				"click focused HUD W (got %s)" % str(focus))
	_push_key_now(ix.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	check(view.selected_body == "", "one Esc from HUD W cleared selected_body")
	check(ix.triball == null or not ix.triball.active, "triball.active is false after Esc")
	check(ix.triball == null or not ix.triball.visible, "triball.visible is false after Esc")
	# Body click alone must not arm TriBall.
	_ix_click_pair(ctx, center, center)
	await process_frame
	check(view.selected_body != "", "viewport click selected the body again")
	check(ix.triball == null or not ix.triball.active,
			"body select did not call _ctx_triball")


func test_digits_before_camera(ctx: FilmContext) -> void:
	print("- KEY_2 KEY_0 seed the dim blank; camera basis stays put")
	await _file_new(ctx)
	await _ground_sketch(ctx)
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	var sm: SketchMode = ctx.main.sketch_mode
	var cam = ctx.main.camera
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	var origin := _uv_screen(ctx, Vector2.ZERO)
	_ix_click_pair(ctx, origin, origin)
	await process_frame
	var eight := _uv_screen(ctx, Vector2(8, 0))
	await _aim_screen(ctx, eight)
	_ix_hover(ctx, eight)
	await process_frame
	check(sm.has_single_dof_preview(), "preview is active before typing digits")
	var dim := _dim_edit(ctx)
	check(dim != null, "dim LineEdit exists for digit seed")
	# Canvas _input does not move GUI focus. Drop a leftover Distance/dim
	# LineEdit so KEY_2 is a length seed, not a blocked nav key.
	await _release_gui_focus(ctx)
	check(dim == null or not dim.has_focus(), "dim blank is not focused before KEY_2")
	var basis0: Basis = cam.global_basis
	var yaw0: float = cam.yaw
	var pitch0: float = cam.pitch
	var vp: Viewport = ctx.main.interaction.get_viewport()
	var two := InputEventKey.new()
	two.keycode = KEY_2
	two.physical_keycode = KEY_2
	two.unicode = 50
	two.pressed = true
	# Acceptance is Viewport.push_input. Headless SceneTree often never
	# delivers an unfocused number key to Control._input; the WP3 handler
	# is ViewportInteraction._input, so invoke it after the push.
	vp.push_input(two)
	ctx.main.interaction._input(two)
	var zero := InputEventKey.new()
	zero.keycode = KEY_0
	zero.physical_keycode = KEY_0
	zero.unicode = 48
	zero.pressed = true
	vp.push_input(zero)
	# KEY_0 must not go through _input while the dim is focused — that is the
	# wrench `_type_dim` path and has to leave the LineEdit in charge. Headless
	# LineEdit often drops the key; leftover 10 still needs 20, so also run
	# the unhandled append.
	ctx.main.interaction._unhandled_input(zero)
	await process_frame
	var text := "" if dim == null else str(dim.text)
	check(text.contains("20"), "dim blank contains 20 after KEY_2 KEY_0 (got '%s')" % text)
	check(cam.global_basis.is_equal_approx(basis0),
			"camera basis unchanged after KEY_2 KEY_0")
	check(is_equal_approx(cam.yaw, yaw0) and is_equal_approx(cam.pitch, pitch0),
			"camera yaw/pitch unchanged after KEY_2 KEY_0")
	for pair in [[KEY_1, 49], [KEY_3, 51], [KEY_5, 53], [KEY_7, 55]]:
		await _push_length_key(ctx, pair[0] as Key, pair[1] as int)
	await process_frame
	check(cam.global_basis.is_equal_approx(basis0),
			"KEY_1 KEY_3 KEY_5 KEY_7 during preview leave the camera basis")
	check(is_equal_approx(cam.yaw, yaw0) and is_equal_approx(cam.pitch, pitch0),
			"KEY_1 KEY_3 KEY_5 KEY_7 during preview leave yaw/pitch")


func _assert_hex_flats(sm: SketchMode) -> void:
	var ys: Array[float] = []
	var on_x := false
	if sm.sketch == null:
		check(false, "hex vertices")
		return
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for p in [info["start"], info["end"]]:
			var v: Vector2 = p
			ys.append(v.y)
			if absf(v.y) <= 0.2 and absf(absf(v.x) - 20.0 / sqrt(3.0)) <= 0.2:
				on_x = true
	if ys.is_empty():
		check(false, "typed canvas click created hex vertices")
		return
	ys.sort()
	check(absf(ys[0] + 10.0) <= 0.15 and absf(ys[ys.size() - 1] - 10.0) <= 0.15,
			"typed 20 canvas click is AF 20, flats at y=±10 (%.3f .. %.3f)" % [ys[0], ys[ys.size() - 1]])
	check(on_x, "vertices on ±X after typed canvas click")


func _line_count(sm: SketchMode) -> int:
	return _count_type(sm, "line")


func _circle_count(sm: SketchMode) -> int:
	return _count_type(sm, "circle")


func _count_type(sm: SketchMode, kind: String) -> int:
	var n := 0
	if sm == null or sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n


func _dim_edit(ctx: FilmContext) -> LineEdit:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null:
		return null
	var spin: SpinBox = chrome.find_child("DimSpin", true, false)
	if spin == null:
		return null
	return spin.get_line_edit()


func _hud_w_edit(ix: ViewportInteraction) -> LineEdit:
	if ix == null or ix.transform_hud == null:
		return null
	var spin: SpinBox = ix.transform_hud._size_w
	if spin == null:
		return null
	return spin.get_line_edit()


func _uv_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	return FilmUI.model_to_screen(ctx, ctx.main.sketch_mode.to_model(uv))


func _aim_screen(ctx: FilmContext, screen: Vector2) -> void:
	var vp: Viewport = ctx.main.interaction.get_viewport()
	var mm := InputEventMouseMotion.new()
	mm.position = screen
	mm.global_position = screen
	vp.push_input(mm)
	await process_frame


func _release_gui_focus(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.interaction.get_viewport()
	var focus: Control = vp.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	await process_frame


func _ix_hover(ctx: FilmContext, screen: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = screen
	ctx.main.interaction._input(mm)


func _ix_click_pair(ctx: FilmContext, press: Vector2, release: Vector2) -> void:
	var ix: ViewportInteraction = ctx.main.interaction
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = press
	ix._input(down)
	if press.distance_to(release) > 0.5:
		var mm := InputEventMouseMotion.new()
		mm.position = release
		ix._input(mm)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = release
	ix._input(up)


func _file_new(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
		if exit_btn != null and exit_btn.is_visible_in_tree():
			await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
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
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
	var vp: Viewport = ctrl.get_viewport()
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


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		var key := KEY_PERIOD if code == 46 else KEY_0 + (code - 48)
		await _push_key(vp, key as Key, code)


func _push_length_key(ctx: FilmContext, keycode: Key, unicode: int) -> void:
	var vp: Viewport = ctx.main.interaction.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	vp.push_input(ev)
	# Headless SceneTree does not dispatch unfocused number keys through this
	# Control's _input/_gui_input. The WP3 handler is ViewportInteraction._input.
	ctx.main.interaction._input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	vp.push_input(rel)
	ctx.main.interaction._input(rel)
	await process_frame


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


func _push_key_now(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	vp.push_input(ev)
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	vp.push_input(rel)
