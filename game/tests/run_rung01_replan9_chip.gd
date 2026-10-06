# Rung 1 replan 9 WP1 — exactly one variant chip is highlighted: the active one (Jaw highlights Center Three Point).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan9_chip.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan9 WP1 variant chip highlight")
	FilmUI.reset_fail_count()
	await test_chip_highlight()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_chip_highlight() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm.active, "sketch is active")

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Rect"))
	await process_frame
	check(_pressed(ctx) == ["Corner"], "Rect: only Corner is highlighted (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool_variant == "center_three_point", "Jaw sets the Center Three Point variant")
	check(_pressed(ctx) == ["Center Three Point"], "Jaw: only Center Three Point is highlighted (got %s)" % str(_pressed(ctx)))
	var chip := _chip(ctx, "Center Three Point")
	check(chip != null and chip.is_visible_in_tree(), "the Center Three Point chip is visible")
	if chip != null:
		var style := chip.get_theme_stylebox("pressed") as StyleBoxFlat
		check(style != null and style.bg_color == Color("2d5f93") and style.border_color == Color("6ab0f3"),
				"the highlighted chip draws the accent fill and border")
	check(_chip(ctx, "Corner") == null, "Jaw does not show the Corner chip")
	check(_chip(ctx, "Parallelogram") == null, "Jaw does not show the Parallelogram chip")
	check(_chip_names(ctx) == ["Center Three Point"],
			"Jaw chips are only Center Three Point (got %s)" % str(_chip_names(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Rect"))
	await process_frame
	check(_pressed(ctx) == ["Corner"], "Rect after Jaw: only Corner is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Parallelogram"))
	await process_frame
	check(sm.tool_variant == "parallelogram", "clicking Parallelogram sets the variant")
	check(_pressed(ctx) == ["Parallelogram"], "Parallelogram click: only Parallelogram is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Parallelogram"))
	await process_frame
	check(_pressed(ctx) == ["Parallelogram"], "clicking the active chip again keeps it highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Corner"))
	await process_frame
	check(_pressed(ctx) == ["Corner"], "Corner click moves the highlight back (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Circle"))
	await process_frame
	check(_pressed(ctx) == ["Center"], "Circle: only Center is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Perimeter"))
	await process_frame
	check(_pressed(ctx) == ["Perimeter"], "Perimeter click: only Perimeter is highlighted (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Line"))
	await process_frame
	check(_pressed(ctx) == ["Line"], "Line: only Line is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Centerline"))
	await process_frame
	check(sm.tool == SketchMode.Tool.CENTERLINE, "clicking Centerline switches the tool")
	check(_pressed(ctx) == ["Centerline"], "Centerline click: only Centerline is highlighted (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Polygon"))
	await process_frame
	await _x11_click(_chip(ctx, "Across Flats"))
	await process_frame
	check(_pressed(ctx) == ["Across Flats"], "Polygon: Across Flats click highlights only Across Flats (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(30.0, 0.0))
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	var lines := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	check(lines == 4, "Jaw still draws a four-line rectangle after the highlight change (got %d)" % lines)
	await _shutdown(ctx)


func _variant_bar(ctx: FilmContext) -> Node:
	return ctx.main.sketch_chrome.find_child("VariantBar", true, false)


func _chip(ctx: FilmContext, text: String) -> Button:
	var bar := _variant_bar(ctx)
	if bar == null:
		return null
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _chip_names(ctx: FilmContext) -> Array[String]:
	var out: Array[String] = []
	var bar := _variant_bar(ctx)
	if bar == null:
		return out
	for c in bar.get_children():
		var b := c as Button
		if b != null:
			out.append(b.text)
	return out


func _pressed(ctx: FilmContext) -> Array[String]:
	var out: Array[String] = []
	var bar := _variant_bar(ctx)
	if bar == null:
		return out
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.button_pressed:
			out.append(b.text)
	return out


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


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


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


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


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


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


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
