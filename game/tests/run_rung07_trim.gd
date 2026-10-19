# Rung 7 WP2 — trim the outer ellipse between the jaws into a C.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung07_trim.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")
const SPAN := 90.0


func _init() -> void:
	print("rung07 trim ellipse")
	FilmUI.reset_fail_count()
	var ctx := await SpannerFixture.boot(self, Vector2i(1280, 800))
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	await _zoom(ctx, Vector3.ZERO, SPAN)
	var xj := SpannerFixture.x_jaw()
	var off := SpannerFixture.mm("JAW_OFF")
	var jaw_len := SpannerFixture.mm("JAW_LEN")
	var r15 := SpannerFixture.mm("R15")
	var o_hi := SpannerFixture.world(xj, off)
	var o_lo := SpannerFixture.world(xj, -off)
	var i_hi := SpannerFixture.world(xj + jaw_len, off)
	var i_lo := SpannerFixture.world(xj + jaw_len, -off)
	var cx_local := (xj + jaw_len) - sqrt(r15 * r15 - off * off)
	var throat := SpannerFixture.world(cx_local + r15, 0.0)
	# Opening curve, off the 17° construction so the click is on the ellipse.
	var pick := SpannerFixture.world(-24.73, 4.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ellipse centre", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(0.0, SpannerFixture.mm("ELLIPSE_MAJ") * 0.5),
			"Ellipse major", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(SpannerFixture.mm("ELLIPSE_MIN") * 0.5, 0.0),
			"Ellipse minor", SPAN)
	await process_frame
	check(SpannerFixture.count_type(sm, "ellipse") == 1, "one ellipse before trim")
	await FilmSteps.press_rail(ctx, "Line")
	if FilmUI.fail_count == 0:
		await FilmSteps.pick_variant(ctx, "Centerline")
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "17° origin", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(40.0, 0.0), "17° handle", SPAN)
	await FilmUI.end_line_chain(ctx)
	await FilmSteps._snap_off_if_visible(ctx)
	await SpannerFixture.line(ctx, o_hi, i_hi, "upper jaw", SPAN)
	await SpannerFixture.line(ctx, o_lo, i_lo, "lower jaw", SPAN)
	await FilmSteps.three_point_arc(ctx, i_lo, throat, i_hi, SPAN)
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await FilmSteps.click_uv(ctx, pick, "Trim opening", SPAN)
	await process_frame
	check(SpannerFixture.count_type(sm, "ellipse") == 0,
			"no full ellipse left (got %d)" % SpannerFixture.count_type(sm, "ellipse"))
	check(SpannerFixture.count_type(sm, "elliptical_arc") == 1,
			"one elliptical arc (got %d)" % SpannerFixture.count_type(sm, "elliptical_arc"))
	check(sm.sketch.contour_count() == 1, "one C region (got %d)" % sm.sketch.contour_count())
	check(SketchMode.profile_is_closed(sm.sketch, 0.05), "C profile is closed")
