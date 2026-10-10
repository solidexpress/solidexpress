# L12 / N24 — suggestion chips clear when the selection becomes empty
# (Esc, empty click, Delete, undo), and the first empty-canvas drag is a box.
# Setup may use the sketch API. Presses, drags and keys under test are
# InputEventMouseButton / InputEventMouseMotion / InputEventKey via push_input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan17_selectbox.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan17 select box, nearest line, chips clear on Delete")
	FilmUI.reset_fail_count()
	await test_first_drag_and_nearest()
	await test_chips_clear_on_delete()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_first_drag_and_nearest() -> void:
	print("- first empty-canvas drag, Shift window, nearest line")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	var circ: String = sm.sketch.add_circle(0.0, 0.0, 6.0)
	var wall: String = sm.sketch.add_line(50.0, 40.0, 90.0, 40.0)
	var near_a: String = sm.sketch.add_line(0.0, -50.0, 50.0, -50.0)
	var near_b: String = sm.sketch.add_line(0.0, -49.6, 50.0, -49.6)
	sm._redraw()
	await _zoom(ctx, sm.to_model(Vector2(30.0, -5.0)), 180.0, false)
	await _arm_select(ctx, sm, vp)

	var win_lo := _uv(ctx, sm, Vector2(-14.0, -14.0))
	var win_hi := _uv(ctx, sm, Vector2(14.0, 14.0))
	var stray := _uv(ctx, sm, Vector2(40.0, -30.0))
	check(FilmUI.require_on_screen(ctx, win_lo, "window lo") \
			and FilmUI.require_on_screen(ctx, win_hi, "window hi") \
			and FilmUI.require_on_screen(ctx, stray, "stray"),
			"drag points are on screen")
	var box_a := win_lo if win_lo.x <= win_hi.x else win_hi
	var box_b := win_hi if win_lo.x <= win_hi.x else win_lo

	# Click's mouse-up arrives after the next press, before the drag motions.
	# A release at the new press is inside CLICK_SLOP and used to clear the box.
	await _press(vp, stray, false)
	await _press(vp, box_a, false)
	await _release(vp, box_a, false)
	await _motions(vp, box_a, box_b, false)
	await _release(vp, box_b, false)
	await process_frame
	check(sm.selected.has(circ) and not sm.selected.has(wall),
			"stale mouse-up then drag selects the circle (got %s)" % str(sm.selected))
	check(_status(ctx) == "Selected 1 sketch entity",
			"stale-then-drag status Selected 1 sketch entity (got `%s`)" % _status(ctx))

	# The late mouse-up is still at the abandoned click, not the new press.
	await _click_at(vp, stray)
	await process_frame
	check(sm.selected.is_empty(), "empty click before the abandoned-up drag clears")
	await _press(vp, stray, false)
	await _press(vp, box_a, false)
	await _release(vp, stray, false)
	await _motions(vp, box_a, box_b, false)
	await _release(vp, box_b, false)
	await process_frame
	check(sm.selected.has(circ) and not sm.selected.has(wall),
			"abandoned click mouse-up then drag selects the circle (got %s)" % str(sm.selected))

	# Motions never arrive; the release is still far enough to be a box.
	await _click_at(vp, stray)
	await process_frame
	await _press(vp, box_a, false)
	await _release(vp, box_b, false)
	await process_frame
	check(sm.selected.has(circ),
			"press and a far release with no motions select the circle (got %s)" % str(sm.selected))

	# Button-down motion beats its press. The box starts where that motion began.
	await _click_at(vp, stray)
	await process_frame
	await process_frame
	var past := _uv(ctx, sm, Vector2(30.0, 20.0))
	var inferred := InputEventMouseMotion.new()
	inferred.position = past
	inferred.global_position = past
	inferred.relative = past - box_a
	inferred.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(inferred)
	await _press(vp, past, false)
	await _motions(vp, past, box_b, false)
	await _release(vp, box_b, false)
	await process_frame
	check(sm.selected.has(circ) and not sm.selected.has(wall),
			"motion-before-press drag selects the circle (got %s)" % str(sm.selected))

	# In-order click, then the drag, including right-to-left.
	await _click_at(vp, stray)
	await process_frame
	await _drag(vp, box_a, box_b, false)
	await process_frame
	check(sm.selected.has(circ) and sm.selected.size() == 1,
			"click then window drag selects only the circle (got %s)" % str(sm.selected))

	var cross_out := _uv(ctx, sm, Vector2(20.0, 0.0))
	var cross_in := _uv(ctx, sm, Vector2(-2.0, 1.0))
	var cross_a := cross_out if cross_out.x >= cross_in.x else cross_in
	var cross_b := cross_in if cross_out.x >= cross_in.x else cross_out
	check(cross_a.x > cross_b.x, "crossing drag is right to left")
	await _click_at(vp, stray)
	await process_frame
	await _press(vp, stray, false)
	await _press(vp, cross_a, false)
	await _release(vp, stray, false)
	await _motions(vp, cross_a, cross_b, false)
	await _release(vp, cross_b, false)
	await process_frame
	check(sm.selected.has(circ) and not sm.selected.has(wall) and not sm.selected.has(near_a),
			"first R-to-L crossing drag selects the circle (got %s)" % str(sm.selected))
	check(_status(ctx) == "Selected 1 sketch entity",
			"crossing status Selected 1 sketch entity (got `%s`)" % _status(ctx))

	# Shift window adds the circle to a previously clicked line.
	await _click_at(vp, stray)
	await process_frame
	var on_wall := _uv(ctx, sm, Vector2(70.0, 40.0))
	check(FilmUI.require_on_screen(ctx, on_wall, "wall"), "wall click is on screen")
	await _click_at(vp, on_wall)
	await process_frame
	check(sm.selected.size() == 1 and sm.selected.has(wall),
			"one click selects only the wall (got %s)" % str(sm.selected))
	check(_status(ctx) == "Selected 1 sketch entity",
			"wall click status Selected 1 sketch entity (got `%s`)" % _status(ctx))
	await _drag(vp, box_a, box_b, true)
	await process_frame
	check(sm.selected.has(wall) and sm.selected.has(circ) and sm.selected.size() == 2,
			"Shift window adds the circle (got %s)" % str(sm.selected))
	check(_status(ctx) == "Selected 2 sketch entities",
			"Shift window status Selected 2 sketch entities (got `%s`)" % _status(ctx))

	# Two near-parallel lines: one click keeps the nearer one only.
	await _click_at(vp, stray)
	await process_frame
	var on_near := _uv(ctx, sm, Vector2(25.0, -50.0))
	check(FilmUI.require_on_screen(ctx, on_near, "near line"), "near-line click is on screen")
	await _click_at(vp, on_near)
	await process_frame
	check(sm.selected.size() == 1 and sm.selected.has(near_a) and not sm.selected.has(near_b),
			"click on the nearer of two close lines selects one (got %s)" % str(sm.selected))
	check(_status(ctx) == "Selected 1 sketch entity",
			"near-line status Selected 1 sketch entity (got `%s`)" % _status(ctx))
	await _click_at(vp, stray)
	await process_frame
	await _press(vp, on_near, false)
	# Stay under CLICK_SLOP (12 px) and step along the line, not toward its neighbor.
	var along := _uv(ctx, sm, Vector2(29.0, -50.0))
	var step: Vector2 = along - on_near
	if step.length() > 8.0:
		step = step.normalized() * 8.0
	var jitter := on_near + step
	await _motions(vp, on_near, jitter, false)
	await _release(vp, jitter, false)
	await process_frame
	check(sm.selected.size() == 1 and sm.selected.has(near_a),
			"sub-slop jitter on the line still selects one (got %s)" % str(sm.selected))
	await _shutdown(ctx)


func test_chips_clear_on_delete() -> void:
	print("- chips clear on Esc, empty click, Delete, undo")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "chip sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	var line_a: String = sm.sketch.add_line(0.0, 0.0, 40.0, 0.0)
	var line_b: String = sm.sketch.add_line(0.0, 16.0, 40.0, 16.0)
	var circ: String = sm.sketch.add_circle(70.0, 30.0, 3.0)
	sm._redraw()
	await process_frame
	await _zoom(ctx, sm.to_model(Vector2(35.0, 16.0)), 140.0, false)
	await _arm_select(ctx, sm, vp)
	var before := sm.sketch.entity_ids().size()

	var on_line := _uv(ctx, sm, Vector2(20.0, 0.0))
	var on_circ := _uv(ctx, sm, Vector2(73.0, 30.0))
	var empty := _uv(ctx, sm, Vector2(-30.0, 40.0))
	check(FilmUI.require_on_screen(ctx, on_line, "chip line") \
			and FilmUI.require_on_screen(ctx, on_circ, "chip circle") \
			and FilmUI.require_on_screen(ctx, empty, "chip empty"),
			"chip picks are on screen")

	await _click_at(vp, on_circ)
	await process_frame
	check(sm.selected.size() == 1 and sm.selected.has(circ),
			"throwaway circle is selected (got %s)" % str(sm.selected))
	var armed: Array[String] = _suggestion_labels(ctx)
	check(armed.has("Parallel?"),
			"Parallel? is offered while the circle is selected (got %s)" % str(armed))

	await _key(vp, KEY_ESCAPE, false)
	check(sm.selected.is_empty(), "Esc clears the selection")
	check(sm.active, "Esc keeps the sketch")
	check(_suggestion_labels(ctx).is_empty(),
			"Esc clears suggestion chips (got %s)" % str(_suggestion_labels(ctx)))
	check(_status(ctx) == "Selection cleared — Esc again exits the sketch",
			"Esc status sentence (got `%s`)" % _status(ctx))

	await _click_at(vp, on_circ)
	await process_frame
	check(not _suggestion_labels(ctx).is_empty(), "chips return when the circle is selected again")
	await _click_at(vp, empty)
	await process_frame
	check(sm.selected.is_empty(), "empty click clears the selection")
	check(_suggestion_labels(ctx).is_empty(),
			"empty click clears suggestion chips (got %s)" % str(_suggestion_labels(ctx)))
	check(_status(ctx) == "No sketch entities",
			"empty click status No sketch entities (got `%s`)" % _status(ctx))

	await _click_at(vp, on_circ)
	await process_frame
	check(_suggestion_labels(ctx).has("Parallel?"), "Parallel? is back before Delete")
	await _key(vp, KEY_DELETE, false)
	check(not sm.sketch.entity_ids().has(circ), "Delete removes the circle")
	check(sm.sketch.entity_ids().has(line_a) and sm.sketch.entity_ids().has(line_b),
			"Delete leaves the parallel lines")
	check(sm.selected.is_empty(), "Delete leaves nothing selected")
	check(sm.sketch.entity_ids().size() == before - 1,
			"entity count dropped by one (got %d)" % sm.sketch.entity_ids().size())
	check(_suggestion_labels(ctx).is_empty(),
			"Delete clears Parallel? / Equal? (got %s)" % str(_suggestion_labels(ctx)))
	check(_status(ctx) == "Deleted 1", "Delete status Deleted 1 (got `%s`)" % _status(ctx))

	await _key(vp, KEY_Z, true)
	check(sm.sketch.entity_ids().has(circ), "undo restores the circle")
	check(sm.selected.is_empty(), "undo leaves the selection empty")
	check(_suggestion_labels(ctx).is_empty(),
			"undo leaves suggestion chips clear (got %s)" % str(_suggestion_labels(ctx)))
	await _shutdown(ctx)


func _arm_select(ctx: FilmContext, sm: SketchMode, vp: Viewport) -> void:
	var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	check(sel != null and sel.is_visible_in_tree(), "Select tool button is visible")
	if sel != null:
		await _click_at(vp, sel.get_global_rect().get_center())
		await process_frame
	check(sm.tool == SketchMode.Tool.SELECT, "Select tool is armed")


func _suggestion_labels(ctx: FilmContext) -> Array[String]:
	var out: Array[String] = []
	var chrome: Node = ctx.main.sketch_chrome
	if chrome == null:
		return out
	var bar: Control = chrome.find_child("ActionBar", true, false) as Control
	if bar == null or not bar.visible:
		return out
	for node in bar.find_children("*", "Button", true, false):
		var b := node as Button
		if b == null or not b.is_visible_in_tree():
			continue
		if str(b.text).ends_with("?"):
			out.append(b.text)
		var more := node as MenuButton
		if more == null:
			continue
		var popup := more.get_popup()
		if popup == null:
			continue
		for i in popup.item_count:
			var item := popup.get_item_text(i)
			if item.ends_with("?"):
				out.append(item)
	return out


func _status(ctx: FilmContext) -> String:
	if ctx.main.status_label == null:
		return ""
	return str(ctx.main.status_label.text)


func _uv(ctx: FilmContext, sm: SketchMode, uv: Vector2) -> Vector2:
	return FilmUI.model_to_screen(ctx, sm.to_model(uv))


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
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float, top: bool) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if top:
		cam.yaw = PI
		cam.pitch = deg_to_rad(89.0)
	elif sm != null and sm.active:
		var nrm: Vector3 = sm.plane_normal()
		if nrm.length_squared() > 1e-8:
			cam.yaw = atan2(nrm.x, -nrm.y)
			cam.pitch = clampf(asin(clampf(nrm.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
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


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _press(vp, pos, false)
	await _release(vp, pos, false)
	await process_frame


func _press(vp: Viewport, pos: Vector2, shift: bool) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.shift_pressed = shift
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)


func _release(vp: Viewport, pos: Vector2, shift: bool) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	up.shift_pressed = shift
	up.button_mask = 0
	vp.push_input(up)


func _motions(vp: Viewport, a: Vector2, b: Vector2, shift: bool) -> void:
	var steps := 6
	var prev := a
	for i in range(1, steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		mv.relative = p - prev
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.shift_pressed = shift
		vp.push_input(mv)
		prev = p


func _drag(vp: Viewport, a: Vector2, b: Vector2, shift: bool) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = a
	hover.global_position = a
	vp.push_input(hover)
	# Shift is latched on the press. Motions and the release omit it, which
	# is how a dropped modifier used to make the box replace the selection.
	await _press(vp, a, shift)
	await _motions(vp, a, b, false)
	await _release(vp, b, false)


func _key(vp: Viewport, keycode: Key, ctrl: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame
