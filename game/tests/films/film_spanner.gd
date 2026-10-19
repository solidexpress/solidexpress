extends RefCounted
## Combination spanner: WalkUI07 Front C, 12-point, mid-plane 10/6, neck fillets, recess.
## FilmUI, FilmSteps, SpannerFixture. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
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
	await SpannerFixture.sketch_ring_and_handle(ctx)
	if not _ok():
		return
	var sk_fid := await FilmUI.exit_sketch(ctx)
	if sk_fid == "":
		FilmUI._fail("Front sketch did not save")
		return

	await ctx.beat("Mid Plane 10 heads, Mid Plane 6 handle", 0.4)
	await SpannerFixture.pencil_first_sketch(ctx)
	if not _ok():
		return
	await SpannerFixture.weld_open_profile(ctx)
	if not _ok():
		return
	await SpannerFixture.set_contours(ctx, PackedStringArray(["c", "ring"]))
	await FilmSteps.midplane_extrude(ctx, SpannerFixture.mm_text("HEAD_T"), 0)
	if not _ok():
		return
	await ctx.after_regen()
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active:
		await SpannerFixture.pencil_first_sketch(ctx)
		if not _ok():
			return
	await SpannerFixture.set_contours(ctx, PackedStringArray(["handle"]))
	await FilmSteps.midplane_extrude(ctx, SpannerFixture.mm_text("HANDLE_T"), 2)
	if not _ok():
		return
	await ctx.after_regen()
	await SpannerFixture.ensure_ring_pad(ctx)
	if not _ok():
		return
	await ctx.after_regen()
	await SpannerFixture.ensure_twelve_point_bore(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("R30 / R20 neck fillets", 0.4)
	await SpannerFixture.fillet_z_edges(ctx, SpannerFixture.mm("R30"), [
		SpannerFixture.handle_xy(true)[0], SpannerFixture.handle_xy(false)[0],
	])
	if not _ok():
		return
	await ctx.after_regen()
	await SpannerFixture.fillet_z_edges(ctx, SpannerFixture.mm("R20"), [
		SpannerFixture.handle_xy(true)[1], SpannerFixture.handle_xy(false)[1],
	])
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Convert + Offset 5, Cut Blind 1, R3, Feature Mirror Front, R1", 0.4)
	await SpannerFixture.open_handle_top_sketch(ctx)
	if not _ok():
		return
	await SpannerFixture.convert_handle_outline(ctx)
	if not _ok():
		return
	await SpannerFixture.offset_recess(ctx)
	if FilmUI.fail_count > 0:
		FilmUI.fail_count = 0
		await SpannerFixture.draw_recess_racetrack(ctx)
	if not _ok():
		return
	var before_cut := SpannerFixture._feature_names(ctx)
	await SpannerFixture.blind_cut(ctx, SpannerFixture.mm_text("CUT_D"))
	if FilmUI.fail_count > 0 or _same_features(ctx, before_cut):
		FilmUI.fail_count = 0
		if ctx.main.sketch_mode == null or not ctx.main.sketch_mode.active:
			await SpannerFixture.open_handle_top_sketch(ctx)
		await SpannerFixture.draw_recess_racetrack(ctx)
		await SpannerFixture.blind_cut(ctx, SpannerFixture.mm_text("CUT_D"))
	if not _ok():
		return
	await ctx.after_regen()
	await FilmSteps.arm_fillet(ctx, SpannerFixture.mm("R3"))
	if not _ok():
		return
	for xy in [Vector2(40, 5), Vector2(200, 5), Vector2(40, -5), Vector2(200, -5)]:
		await SpannerFixture._pick_z_edge(ctx, SpannerFixture.only_body(ctx), xy, SpannerFixture.mm("CUT_D"))
	await FilmSteps.commit_fillet(ctx)
	await ctx.after_regen()
	await SpannerFixture.feature_mirror_front(ctx)
	if not _ok():
		return
	await ctx.after_regen()
	await SpannerFixture.fillet_remaining(ctx, SpannerFixture.mm("R1"))
	if not _ok():
		return
	await ctx.after_regen()

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0


func _same_features(ctx: FilmContext, before: PackedStringArray) -> bool:
	return SpannerFixture._feature_names(ctx) == before
