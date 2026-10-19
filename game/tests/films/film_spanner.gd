extends RefCounted
## Combination spanner: Front C, 12-point, mid-plane pads, neck fillets, mirrored recess.
## FilmUI, FilmSteps, SpannerFixture, SxInput. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	await ctx.movie_toast("A combination spanner: ellipse C, 12-point box end, mid-plane, mirrored recess", 2.0)

	await ctx.beat("Sketch the Front C: 17°, ellipse 55×50, Parallel jaws, Mirror, R15, Power Trim", 0.4)
	await SpannerFixture.click_datum(ctx, "Front", "front")
	if not _ok():
		return
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("Front sketch did not start")
		return
	await SpannerFixture.sketch_front_c(ctx)
	if not _ok():
		return

	await ctx.beat("Ø33, two AF-25 hexes, Power Trim 12-point, handle 10", 0.4)
	await SpannerFixture.sketch_ring(ctx)
	if not _ok():
		return
	await SpannerFixture.sketch_handle(ctx)
	if not _ok():
		return

	await ctx.beat("Mid Plane 10 heads, Mid Plane 6 handle", 0.4)
	await SpannerFixture.set_contours(ctx, PackedStringArray(["c", "ring"]))
	if not _ok():
		return
	await FilmSteps.midplane_extrude(ctx, SpannerFixture.digits("HEAD_T"), 0)
	if not _ok():
		return
	await ctx.after_regen()
	await SpannerFixture.pencil_edit_sketch(ctx)
	if not _ok():
		return
	await SpannerFixture.set_contours(ctx, PackedStringArray(["handle"]))
	if not _ok():
		return
	await FilmSteps.midplane_extrude(ctx, SpannerFixture.digits("HANDLE_T"), 2)
	if not _ok():
		return
	await ctx.after_regen()
	await SpannerFixture.click_datum(ctx, "Front", "front")
	if not _ok():
		return
	await SpannerFixture.sketch_twelve_point_hexes(ctx)
	if not _ok():
		return
	await FilmSteps.midplane_extrude(ctx, SpannerFixture.digits("HEAD_T"), 1)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("R30 / R20 neck fillets", 0.4)
	var open_xy := SpannerFixture.handle_xy(true)
	var open_lo := SpannerFixture.handle_xy(false)
	# Inset along the handle so the pick is the 6 mm crotch, not the C ellipse.
	var r30_hi := Vector2(open_xy[0].x + 8.0, open_xy[0].y)
	var r30_lo := Vector2(open_lo[0].x + 8.0, open_lo[0].y)
	var r20_hi := Vector2(open_xy[1].x - 6.0, open_xy[1].y)
	var r20_lo := Vector2(open_lo[1].x - 6.0, open_lo[1].y)
	await SpannerFixture.fillet_z_at(ctx, "R30", [r30_hi, r30_lo])
	if not _ok():
		return
	await SpannerFixture.fillet_z_at(ctx, "R20", [r20_hi, r20_lo])
	if not _ok():
		return

	await ctx.beat("Convert + Offset 5, Cut Blind 1, R3, Feature Mirror Front, R1", 0.4)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, SpannerFixture.mm("HANDLE_T") * 0.5)
	if not _ok():
		return
	await SpannerFixture.convert_handle_outline(ctx)
	if not _ok():
		return
	await FilmSteps.offset_rim(ctx, SpannerFixture.digits("OFFSET"), Vector2(120, 10))
	if not _ok():
		return
	var sm_rec: SketchMode = ctx.main.sketch_mode
	var n_ents := 0
	if sm_rec != null and sm_rec.sketch != null:
		n_ents = sm_rec.sketch.entity_ids().size()
	if n_ents < 4:
		await SpannerFixture.draw_recess_racetrack(ctx)
	if not _ok():
		return
	await SpannerFixture.set_contours(ctx, PackedStringArray(["recess"]))
	await FilmSteps.pick_finish(ctx, 1, 0)
	if not _ok():
		return
	await FilmSteps.type_distance(ctx, SpannerFixture.digits("CUT_D"))
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var ex: Button = chrome.extrude_button() if chrome != null else null
	if ex == null or not ex.is_visible_in_tree():
		FilmUI._fail("finish:Extrude is hidden")
		return
	if not await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Extrude")):
		return
	await ctx.after_regen()
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)
	await SpannerFixture.fillet_z_at(ctx, "R3", [
		Vector2(40, 5), Vector2(200, 5), Vector2(40, -5), Vector2(200, -5),
	])
	if not _ok():
		return
	var cut := SpannerFixture.last_name_of_type(ctx.view.doc, "extrude")
	var fillet := SpannerFixture.last_name_of_type(ctx.view.doc, "fillet")
	await SpannerFixture.feature_mirror_front(ctx, [fillet, cut])
	if not _ok():
		return
	await SpannerFixture.fillet_z_at(ctx, "R1", [Vector2(0, 20), Vector2(240, 16)])
	if not _ok():
		return

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0


