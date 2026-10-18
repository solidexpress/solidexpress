extends RefCounted
## Candlestick: Front revolve, ellipse swept along an arc path, drafted Blind cut.
## FilmUI, FilmSteps, CandlestickFixture, SxInput. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	await ctx.movie_toast("A candlestick: revolve, sweep an ellipse along an arc, drafted cut", 2.0)

	await ctx.beat("Sketch the Front profile and revolve 360", 0.4)
	await CandlestickFixture.click_datum(ctx, "Front", "front")
	if not _ok():
		return
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("Front sketch did not start")
		return
	await CandlestickFixture.draw_profile(ctx)
	if not _ok():
		return
	await CandlestickFixture.revolve_360(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Path on Front: 60, R150, R20 hook, dim 10", 0.4)
	await CandlestickFixture.click_datum(ctx, "Front", "front")
	if not _ok():
		return
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("path Front sketch did not start")
		return
	await CandlestickFixture.click_temp_axes(ctx)
	await CandlestickFixture.draw_path(ctx)
	if not _ok():
		return
	var path_fid := await FilmUI.exit_sketch(ctx)
	if path_fid == "":
		FilmUI._fail("path sketch did not save")
		return

	await ctx.beat("Ellipse 35×10 on Right, coincident to the path", 0.4)
	await CandlestickFixture.click_datum(ctx, "Right", "right")
	if not _ok():
		return
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("Right ellipse sketch did not start")
		return
	await CandlestickFixture.draw_section_ellipse(ctx)
	if not _ok():
		return
	var ell_fid := await FilmUI.exit_sketch(ctx)
	if ell_fid == "":
		FilmUI._fail("ellipse sketch did not save")
		return

	await ctx.beat("Swept Boss, fuse onto the revolve", 0.4)
	await FilmSteps.swept_boss(ctx, ell_fid, path_fid)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Cut Ø30 Blind 25, draft 15° inward", 0.4)
	await CandlestickFixture.cut_top_disc(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0
