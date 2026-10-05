# Rung 1 replan 8 WP1 — every sketch rail tool shows a text label; Jaw starts the Center Three Point rectangle.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_rail.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

const RAIL_LABELS := ["Exit Sketch", "Select", "Line", "Arc", "Circle", "Rect", "Jaw", "Polygon",
		"Ellipse", "Slot", "Spline", "Point", "Trim", "Extend", "Smart Dim", "Convert", "Mirror",
		"Pattern", "Auto Dim"]

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
	print("rung01 replan8 WP1 rail labels and Jaw")
	FilmUI.reset_fail_count()
	await test_rail()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_rail() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var rail: Control = ctx.main.sketch_toolbar
	check(sm.active and rail.is_visible_in_tree(), "sketch rail is visible in a sketch")

	var texts: Array[String] = []
	for b in rail.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn is OptionButton or btn is CheckBox:
			continue
		texts.append(btn.text)
		check(btn.icon != null, "rail button '%s' has an icon" % btn.text)
		check(btn.tooltip_text != "", "rail button '%s' has a tooltip" % btn.text)
	for label in RAIL_LABELS:
		check(texts.has(label), "rail shows the text label '%s'" % label)
	check(texts.size() == RAIL_LABELS.size(),
			"rail has %d labelled buttons (got %d)" % [RAIL_LABELS.size(), texts.size()])

	var by_tool := {
		SketchMode.Tool.SELECT: "Select", SketchMode.Tool.LINE: "Line",
		SketchMode.Tool.ARC: "Arc", SketchMode.Tool.CIRCLE: "Circle",
		SketchMode.Tool.RECT: "Rect", SketchMode.Tool.POLYGON: "Polygon",
		SketchMode.Tool.ELLIPSE: "Ellipse", SketchMode.Tool.SLOT: "Slot",
		SketchMode.Tool.SPLINE: "Spline", SketchMode.Tool.POINT: "Point",
		SketchMode.Tool.TRIM: "Trim", SketchMode.Tool.EXTEND: "Extend",
		SketchMode.Tool.SMART_DIM: "Smart Dim", SketchMode.Tool.CONVERT: "Convert",
		SketchMode.Tool.MIRROR: "Mirror", SketchMode.Tool.PATTERN: "Pattern",
	}
	for tool in by_tool:
		var want: String = by_tool[tool]
		await FilmUI.select_sketch_tool(ctx, sm, tool)
		var found := _rail_button_for(ctx, tool)
		check(found != null and found.text == want,
				"FilmUI resolves tool %s to the rail button '%s'" % [str(tool), want])

	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null and jaw.name == "JawTool", "Jaw button is on the rail")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	check(sm.tool_variant == "corner", "Rect starts as the corner rectangle")
	await _x11_click(jaw)
	await process_frame
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT, "Jaw selects the Rectangle tool")
	check(sm.tool_variant == "center_three_point", "Jaw selects the Center Three Point variant (got %s)" % sm.tool_variant)
	check(_status_has("Jaw — click 1 centre, click 2 end of the long side, click 3 half the width"), "Jaw status explains the three clicks")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	check(chip != null and chip.is_visible_in_tree(), "Center Three Point chip is visible after Jaw")

	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	var along := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var across := Vector2(-along.y, along.x)
	var vp: Viewport = ctx.main.get_viewport()
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, along * 30.0)
	await _click_uv(ctx, vp, across * 10.0)
	await process_frame
	var lines := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	check(lines == 4, "three Jaw clicks make a four-line rectangle (got %d)" % lines)
	var width := _distance_near(sm, 20.0)
	check(width >= 0, "the jaw width dimension reads 20")

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Rect"))
	await process_frame
	check(sm.tool_variant == "corner", "Rect resets the variant to corner after Jaw")
	await _shutdown(ctx)


func _rail_button_for(ctx: FilmContext, tool: int) -> Button:
	var label := ""
	match tool:
		SketchMode.Tool.SELECT: label = "Select"
		SketchMode.Tool.LINE: label = "Line"
		SketchMode.Tool.ARC: label = "Arc"
		SketchMode.Tool.CIRCLE: label = "Circle"
		SketchMode.Tool.RECT: label = "Rectangle"
		SketchMode.Tool.POLYGON: label = "Polygon"
		SketchMode.Tool.ELLIPSE: label = "Ellipse"
		SketchMode.Tool.SLOT: label = "Slot"
		SketchMode.Tool.SPLINE: label = "Spline"
		SketchMode.Tool.POINT: label = "Point"
		SketchMode.Tool.TRIM: label = "Trim"
		SketchMode.Tool.EXTEND: label = "Extend"
		SketchMode.Tool.SMART_DIM: label = "Smart Dimension"
		SketchMode.Tool.CONVERT: label = "Convert"
		SketchMode.Tool.MIRROR: label = "Mirror"
		SketchMode.Tool.PATTERN: label = "Pattern"
	return FilmUI.find_sketch_tool_button(ctx.main, label)


func _distance_near(sm: SketchMode, value: float) -> int:
	for i in sm.dimensions.size():
		var d: Dictionary = sm.dimensions[i]
		if str(d.get("type", "")) == "distance" and absf(float(d.get("value", -1.0)) - value) <= 0.5:
			return i
	return -1


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
