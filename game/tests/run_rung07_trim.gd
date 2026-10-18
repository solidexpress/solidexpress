# Rung 7 WP2 — trim the outer ellipse between the jaws into a C.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung07_trim.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SPAN := 90.0
const DEG := 17.0


func _init() -> void:
	print("rung07 trim ellipse")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	return ctx


func _world(xp: float, yp: float) -> Vector2:
	var a := deg_to_rad(DEG)
	return Vector2(xp * cos(a) - yp * sin(a), xp * sin(a) + yp * cos(a))


func _x_jaw() -> float:
	return -25.0 * sqrt(1.0 - (12.5 / 27.5) * (12.5 / 27.5))


func _case(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	await _zoom(ctx, Vector3.ZERO, SPAN)
	var xj := _x_jaw()
	var o_hi := _world(xj, 12.5)
	var o_lo := _world(xj, -12.5)
	var i_hi := _world(xj + 20.0, 12.5)
	var i_lo := _world(xj + 20.0, -12.5)
	var cx_local := (xj + 20.0) - sqrt(15.0 * 15.0 - 12.5 * 12.5)
	var throat := _world(cx_local + 15.0, 0.0)
	# Opening curve, off the 17° construction so the click is on the ellipse.
	var pick := _world(-24.73, 4.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ellipse centre", SPAN)
	await FilmSteps.click_uv(ctx, _world(0.0, 27.5), "Ellipse major", SPAN)
	await FilmSteps.click_uv(ctx, _world(25.0, 0.0), "Ellipse minor", SPAN)
	await process_frame
	check(_count_type(sm, "ellipse") == 1, "one ellipse before trim")
	await FilmSteps.press_rail(ctx, "Line")
	if FilmUI.fail_count == 0:
		await FilmSteps.pick_variant(ctx, "Centerline")
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "17° origin", SPAN)
	await FilmSteps.click_uv(ctx, _world(40.0, 0.0), "17° handle", SPAN)
	await FilmUI.end_line_chain(ctx)
	await FilmSteps._snap_off_if_visible(ctx)
	await _line(ctx, o_hi, i_hi, "upper jaw")
	await _line(ctx, o_lo, i_lo, "lower jaw")
	await FilmSteps.three_point_arc(ctx, i_lo, throat, i_hi, SPAN)
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await FilmSteps.click_uv(ctx, pick, "Trim opening", SPAN)
	await process_frame
	check(_count_type(sm, "ellipse") == 0, "no full ellipse left (got %d)" % _count_type(sm, "ellipse"))
	check(_count_type(sm, "elliptical_arc") == 1, "one elliptical arc (got %d)" % _count_type(sm, "elliptical_arc"))
	check(sm.sketch.contour_count() == 1, "one C region (got %d)" % sm.sketch.contour_count())
	check(SketchMode.profile_is_closed(sm.sketch, 0.05), "C profile is closed")


func _line(ctx: FilmContext, a: Vector2, b: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, a, "%s start" % desc, SPAN)
	await FilmSteps.click_uv(ctx, b, "%s end" % desc, SPAN)
	await FilmUI.end_line_chain(ctx)


func _count_type(sm: SketchMode, kind: String) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n
