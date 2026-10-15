extends RefCounted
## Hex key: origin AF hex, Right-plane path, Swept Boss.
## FilmUI, FilmSteps, HexKeyFixture, SxInput. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
const HexKeyFixture = preload("res://tests/lib/hexkey_fixture.gd")


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	await ctx.movie_toast("A hex key, swept from a 7.65 mm profile", 2.0)

	await ctx.beat("Sketch a 7.65 across-flats hex on the origin, point-up", 0.4)
	var hex_fid := await HexKeyFixture.place_hex(ctx)
	if not _ok() or hex_fid == "":
		return

	await ctx.beat("Path on the Right plane: 37, 94, a Ø30 elbow, then the solid legs", 0.4)
	var path_fid := await HexKeyFixture.place_path(ctx)
	if not _ok() or path_fid == "":
		return

	await ctx.beat("Swept Boss: hex profile along the path", 0.35)
	await HexKeyFixture.sweep(ctx, hex_fid, path_fid)
	if not _ok():
		return
	await ctx.after_regen()

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0
