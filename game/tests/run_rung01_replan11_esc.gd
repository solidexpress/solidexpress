# Rung 1 replan 11 WP5 — Esc drops a pending first point before the measure anchor.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_esc.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const FIRST_DROP := "First point dropped — Esc again exits the sketch"

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan11 WP5 Esc drops the first point first")
	FilmUI.reset_fail_count()
	await _circle_row()
	await _line_row()
	await _rect_row()
	await _polygon_row()
	finish()


func _circle_row() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Circle centre")
	await process_frame
	var mo := _force_anchor(ctx)
	_status_log.clear()
	await _push_esc(vp)
	check(_last_status() == FIRST_DROP,
			"Circle: first Esc text is `%s`" % FIRST_DROP)
	check(not mo.has_anchor(), "Circle: anchor is clear")
	check(sm.active, "Circle: sketch still active")
	await _push_esc(vp)
	check(not sm.active, "Circle: second Esc leaves the sketch")
	await _shutdown(ctx)


func _line_row() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Line first point")
	await process_frame
	_force_anchor(ctx)
	_status_log.clear()
	await _push_esc(vp)
	check(_last_status().contains("First point dropped"),
			"Line: first Esc is `First point dropped`")
	await _push_esc(vp)
	check(not sm.active, "Line: second Esc exits")
	await _shutdown(ctx)


func _rect_row() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Rect first corner")
	await process_frame
	var mo := _force_anchor(ctx)
	_status_log.clear()
	await _push_esc(vp)
	check(_last_status().contains("First point dropped"),
			"Rect: first Esc is `First point dropped`")
	check(not mo.has_anchor() and sm.active,
			"Rect: anchor clear and sketch still active")
	await _push_esc(vp)
	await _shutdown(ctx)


func _polygon_row() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Polygon centre")
	await process_frame
	_force_anchor(ctx)
	_status_log.clear()
	await _push_esc(vp)
	check(_last_status().contains("First point dropped"),
			"Polygon: first Esc is `First point dropped`")
	await _push_esc(vp)
	check(not sm.active, "Polygon: second Esc exits")
	await _shutdown(ctx)


func _force_anchor(ctx: FilmContext) -> MeasureOverlay:
	# The overlay the KEY_ESCAPE arm reads lives on ViewportInteraction.
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	if not mo.has_anchor():
		mo.anchor_point = Vector3.ZERO
		if "anchor_entity" in mo:
			mo.anchor_entity = "forced"
	return mo


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


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


func _push_esc(vp: Viewport) -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.physical_keycode = KEY_ESCAPE
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	up.echo = false
	vp.push_input(up)
	await process_frame


