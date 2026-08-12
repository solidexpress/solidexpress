extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Demo: Selected Contours matching SW Video 2 (Sketch and Extrude).
## A circle plus a nose that shares the circle's arc — two regions, fused
## extrude = pliers head (cylinder + taper). Not two disjoint pads.


func _hold(ctx: FilmContext, caption: String, frames: int) -> void:
	if ctx.chrome != null:
		ctx.chrome.show_caption(caption)
	await FilmUI.wait_frames(ctx.tree, maxi(frames, 1))


func run_film(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome

	await ctx.movie_toast("Selected Contours — circle + nose share an arc", 0.05)
	await _hold(ctx, "SW Sketch and Extrude: pliers head from shared-arc regions", 70)

	await FilmUI.enter_sketch(ctx)
	# Circle r=10 at origin (Video 2 starts with a shaded circle).
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	await _hold(ctx, "Circle — one closed contour", 40)
	# Nose attached on the circle at (±6, 8); 36+64=100.
	await FilmUI.draw_polyline(ctx, sm, PackedVector2Array([
		Vector2(-6, 8), Vector2(-3, 22), Vector2(3, 22), Vector2(6, 8)]))
	await _hold(ctx, "Nose shares the circle's arc — two regions, not outer+hole", 55)

	if chrome != null and chrome.has_method("refresh_contours"):
		chrome.refresh_contours(sm.sketch)
	await FilmUI.wait_frames(ctx.tree, 6)
	var n: int = int(sm.sketch.contour_count()) if sm.sketch != null else 0
	if n < 2:
		FilmUI._fail("shared-edge contours missing (got %d)" % n)
		await _hold(ctx, "Need 2 regions (circle + nose)", 60)
		return

	await _hold(ctx, "Both contours on — extrude the pliers head", 40)
	await FilmUI.apply_extrude(ctx, 8.0)
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	if bodies.is_empty():
		FilmUI._fail("no body after shared-edge extrude")
		return
	var vol: float = ctx.view.doc.body_volume(bodies[0])
	# Disk π·100·8 ≈ 2513; nose ≈ 109.6·8 ≈ 877; fused ≈ 3390.
	# Disjoint-pad shortcut was ~960 or 1920. Bare disk would be ~2513.
	await _hold(ctx, "Fused head V≈%.0f (circle + nose, one body)" % vol, 70)
	if vol < 3000.0:
		FilmUI._fail("nose region missing — volume too small (%.0f)" % vol)
	if vol > 4000.0:
		FilmUI._fail("unexpected extra material (V=%.0f)" % vol)
	if cam_ok(ctx):
		await ctx.camera.showcase_smooth(1.2, 36.0)
	await _hold(ctx, "Selected Contours match the SW pliers-head extrude", 55)


func cam_ok(ctx: FilmContext) -> bool:
	return ctx.camera != null
