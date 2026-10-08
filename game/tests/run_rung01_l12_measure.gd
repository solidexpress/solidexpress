# sx-037 L12 — Select hover shows ✕ and Δ, Esc clears the measure, a thin-line
# click selects, and the next Esc clears the selection without leaving the
# sketch. The hover ✕ also clears when the pointer leaves, when the camera
# frames (F / Shift+F / HUD Frame), and when the part selection changes
# (empty-ground click / deselect), taking any 0.00 gizmo label with it.
# Run: tools/godot/godot --headless --path game --script res://tests/run_rung01_l12_measure.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const MEASURE_CLEARED := "Measure cleared"
const SELECTION_CLEARED := "Selection cleared — Esc again exits the sketch"

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
	print("rung01 L12 select hover measure, thin-line pick, Esc ladder")
	FilmUI.reset_fail_count()
	await test_sketch_l12()
	await test_part_hover_clears()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_sketch_l12() -> void:
	print("- sketch: Circle has no ✕; Select hover has ✕ and Δ; Esc ladder")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	var lid := sm.sketch.add_line(0.0, 30.0, 180.0, 30.0)
	sm.sketch.add_circle(200.0, 0.0, 22.5)
	sm._redraw()
	await process_frame
	# Ø45-at-150px scale: 45 mm / 150 px * 800 px ≈ 240 mm of view height.
	await _zoom(ctx, sm.to_model(Vector2(90.0, 30.0)), 240.0)
	await _settle_camera(ctx)
	var mid := Vector2(90.0, 30.0)
	var tol := sm._pick_tolerance()
	check(tol > SketchMode.PICK_TOLERANCE + 0.2,
			"pick radius grew past 2.5 mm at this zoom (%.2f mm)" % tol)
	var off_mm := (SketchMode.PICK_TOLERANCE + tol) * 0.5
	var off := Vector2(90.0, 30.0 + off_mm)
	check(sm._nearest_entity_at(off) == lid,
			"a point between 2.5 mm and the screen radius hits the shaft line")
	check(sm._entity_distance(sm.sketch.entity_info(lid), off) > SketchMode.PICK_TOLERANCE,
			"that point is outside the old 2.5 mm radius")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _hover_uv(ctx, vp, mid)
	await _hover_uv(ctx, vp, Vector2(200.0, 22.5))
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_delta(mo),
			"Circle hover leaves no ✕ and no Δ (marks=%d)" % mo.marks.size())

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _hover_uv(ctx, vp, mid)
	check(mo.has_anchor() and mo.marks.size() >= 1, "Select hover plants an ✕")
	check(_has_delta(mo), "Select hover shows Δ labels (%s)" % _label_texts(mo))
	await _hover_uv(ctx, vp, Vector2(90.0, 80.0))
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_delta(mo),
			"leaving the line clears the ✕ and Δ")

	await _hover_uv(ctx, vp, mid)
	check(mo.has_anchor(), "hover replants the ✕")
	await _frame_key(vp, false)
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_delta(mo),
			"F clears the sketch hover ✕")
	await _hover_uv(ctx, vp, mid)
	await _frame_key(vp, true)
	check(not mo.has_anchor() and mo.marks.is_empty(), "Shift+F clears the sketch hover ✕")
	await _hover_uv(ctx, vp, mid)
	await _click_frame(ctx)
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_delta(mo),
			"HUD Frame clears the sketch hover ✕")

	await _hover_uv(ctx, vp, mid)
	check(mo.has_anchor() and _has_delta(mo), "Select hover again shows ✕ and Δ")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE, false)
	check(_status_has(MEASURE_CLEARED), "Esc says Measure cleared (log: %s)" % str(_status_log))
	check(not mo.has_anchor() and not _has_delta(mo), "Esc clears the ✕ and Δ")
	check(sm.active, "Measure cleared keeps the sketch open")
	var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	check(sel != null and sel.is_visible_in_tree(), "Select chip still showing")

	await _click_uv_jitter(ctx, vp, off, Vector2(4.0, 0.0))
	check(sm.selected.has(lid), "jittered click off the thin line selects it (got %s)" % str(sm.selected))
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_delta(mo),
			"the Select click clears the hover ✕")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE, false)
	check(sm.active, "selection Esc keeps the sketch open")
	check(sm.selected.is_empty(), "selection Esc clears the line")
	check(_status_has(SELECTION_CLEARED),
			"Esc says Selection cleared — Esc again exits the sketch (log: %s)" % str(_status_log))
	check(not _status_has("Sketch saved") and not _status_has("Sketch cancelled"),
			"that Esc does not leave the sketch (log: %s)" % str(_status_log))
	await _shutdown(ctx)


func test_part_hover_clears() -> void:
	print("- part: leave, empty click, deselect, and frame clear the ✕ and 0.00")
	var ctx := await _boot()
	var view: DocumentView = ctx.view
	var ix: ViewportInteraction = ctx.main.interaction
	var mo: MeasureOverlay = ix.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	var body := view.insert_primitive("box", Vector3(0, 0, 0), Vector3(40, 40, 20))
	view.clear_selection()
	await process_frame
	ctx.main.camera.apply_standard_view(0.0, deg_to_rad(89.0), false, true)
	await _settle_camera(ctx)
	var bb: Dictionary = view.doc.measure_bbox(body)
	var top := Vector3(
			(bb["min"].x + bb["max"].x) * 0.5,
			(bb["min"].y + bb["max"].y) * 0.5,
			bb["max"].z - 0.5)
	var on_body := FilmUI.model_to_screen(ctx, top)
	check(FilmUI.require_on_screen(ctx, on_body, "box top"), "box top is on screen")
	await _motion(vp, on_body)
	await _motion(vp, on_body)
	check(mo.has_anchor() and mo.marks.size() >= 1,
			"hovering the body plants an ✕ (anchor=%s marks=%d)" % [str(mo.has_anchor()), mo.marks.size()])
	var empty := _empty_corner(ctx)
	check(empty != Vector2.INF, "found an empty-ground screen point")
	await _motion(vp, empty)
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_zero(mo),
			"moving off the body clears the ✕ and any 0.00 label")

	await _motion(vp, on_body)
	check(mo.has_anchor(), "hover replants the part ✕")
	await _click_screen(vp, empty)
	await process_frame
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_zero(mo) and not _has_delta(mo),
			"clicking empty ground clears the hover ✕ and labels")

	await _click_screen(vp, on_body)
	await process_frame
	check(view.selected_body == body, "clicking the body selects it")
	# The dimension row appears on select and can cover the earlier miss.
	empty = _empty_corner(ctx)
	check(empty != Vector2.INF, "found empty ground after the body is selected")
	await _click_screen(vp, empty)
	await process_frame
	check(view.selected_body == "", "empty click deselects (at %s)" % str(empty))
	check(not mo.has_anchor() and mo.marks.is_empty() and mo.labels.is_empty() and not _has_zero(mo),
			"deselect clears hover marks and gizmo labels (labels=%s)" % _label_texts(mo))
	var hud = ix.transform_hud
	check(hud == null or not hud._dims_row.visible, "deselect hides the dimension gizmo row")

	await _motion(vp, on_body)
	check(mo.has_anchor(), "hover after deselect plants an ✕")
	await _frame_key(vp, false)
	check(not mo.has_anchor() and mo.marks.is_empty() and not _has_zero(mo),
			"F clears the part hover ✕")
	on_body = FilmUI.model_to_screen(ctx, top)
	await _motion(vp, on_body)
	await _frame_key(vp, true)
	check(not mo.has_anchor() and mo.marks.is_empty(), "Shift+F clears the part hover ✕")
	on_body = FilmUI.model_to_screen(ctx, top)
	await _motion(vp, on_body)
	await _click_frame(ctx)
	check(not mo.has_anchor() and mo.marks.is_empty() and mo.labels.is_empty() and not _has_zero(mo),
			"HUD Frame clears the part hover ✕ and labels")
	await _shutdown(ctx)


func _empty_corner(ctx: FilmContext) -> Vector2:
	var ix: ViewportInteraction = ctx.main.interaction
	var view: DocumentView = ctx.view
	# Stay on the canvas. Left-stack buttons (and the dimension HUD that
	# appears after a select) sit on top of the viewport and swallow clicks.
	var size := ctx.tree.root.size
	for y in range(80, int(size.y) - 40, 40):
		for x in range(360, int(size.x) - 60, 50):
			var p := Vector2(x, y)
			if _pointer_blocked(ctx.main, p, ix):
				continue
			if view.selected_body != "":
				if not ix._pick_rotate_grip(p).is_empty():
					continue
				if not ix._pick_resize_handle(p).is_empty():
					continue
				if not ix._pick_z_move_grip(p).is_empty():
					continue
				if not ix._pick_push_pull_handle(p).is_empty():
					continue
			var ray: Array = ix._model_ray(p)
			if view.pick_info(ray[0], ray[1]).is_empty():
				return p
	return Vector2.INF


func _pointer_blocked(node: Node, p: Vector2, interaction: Control) -> bool:
	if node is Control and node != interaction:
		var c := node as Control
		if c.visible and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			var r := c.get_global_rect()
			if r.size.x >= 2.0 and r.size.y >= 2.0 and r.has_point(p):
				return true
	for child in node.get_children():
		if _pointer_blocked(child, p, interaction):
			return true
	return false


func _has_delta(mo: MeasureOverlay) -> bool:
	for lab in mo.labels:
		if str(lab["text"]).contains("Δ"):
			return true
	return false


func _has_zero(mo: MeasureOverlay) -> bool:
	for lab in mo.labels:
		var text := str(lab["text"])
		if text == "0.00" or text.begins_with("0.00"):
			return true
	return false


func _label_texts(mo: MeasureOverlay) -> String:
	var out: Array[String] = []
	for lab in mo.labels:
		out.append(str(lab["text"]))
	return str(out)


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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _uv_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	return FilmUI.model_to_screen(ctx, sm.to_model(uv))


func _hover_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, "sketch hover"), "hover on screen at %s" % str(uv))
	await _motion(vp, screen)
	await _motion(vp, screen)


func _motion(vp: Viewport, screen: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


func _click_uv_jitter(ctx: FilmContext, vp: Viewport, uv: Vector2, jitter: Vector2) -> void:
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, "line click"), "line click on screen")
	await _click_screen_jitter(vp, screen, jitter)


func _click_screen(vp: Viewport, pos: Vector2) -> void:
	await _click_screen_jitter(vp, pos, Vector2.ZERO)


func _click_screen_jitter(vp: Viewport, pos: Vector2, jitter: Vector2) -> void:
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
	var moved := pos + jitter
	var drag := InputEventMouseMotion.new()
	drag.position = moved
	drag.global_position = moved
	vp.push_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = moved
	up.global_position = moved
	vp.push_input(up)
	await process_frame
	await process_frame


func _frame_key(vp: Viewport, shift: bool) -> void:
	await _push_key(vp, KEY_F, shift)
	await create_timer(0.45).timeout
	await process_frame


func _click_frame(ctx: FilmContext) -> void:
	var frame := FilmUI.find_button(ctx.main, "Frame")
	check(frame != null and frame.is_visible_in_tree(), "HUD Frame button is visible")
	if frame == null:
		return
	await FilmUI.click_control(ctx, frame, FilmUICues.alert("Frame", "HUD Frame"))
	await create_timer(0.45).timeout
	await process_frame


func _push_key(vp: Viewport, keycode: Key, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


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


func _settle_camera(ctx: FilmContext) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		await cam._view_tween.finished
	await process_frame
