extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

## UI: block + fit spline, then extend — compact UV so clicks stay on-screen.


func _reframe(sm: SketchMode) -> void:
	if sm == null or sm.camera == null:
		return
	var ext: Dictionary = sm.sketch_extents(0.35)
	if ext.is_empty():
		return
	sm.camera.enter_sketch_view(sm.plane_normal(), ext["center"], ext["radius"], sm.plane_y)


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var sm: SketchMode = main.sketch_mode

	await ctx.movie_toast("Sketch tools — blocks, splines, and extend", 1.6)

	await ctx.beat("Enter sketch mode", 0.45)
	await FilmUI.enter_sketch(ctx)

	await ctx.beat("Create a line and save it as a block", 0.4)
	var a: String = sm.sketch.add_line(0, 0, 5, 0)
	sm._set_selected([a])
	sm.create_block("Blk1")
	sm.place_block("Blk1", Vector2(0, 6))
	_reframe(sm)
	await FilmUI.wait_frames(ctx.tree, 2)
	await ctx.clock.wait_sec(ctx.tree, 0.35)

	await ctx.beat("Fit a spline through successive clicks", 0.4)
	var sketch_pts := PackedVector2Array([
		Vector2(0, 10), Vector2(4, 12), Vector2(8, 10),
	])
	_reframe(sm)
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.draw_spline_through(ctx, sm, sketch_pts)
	await ctx.clock.wait_sec(ctx.tree, 0.4)

	await ctx.beat("Sketch a short line and a vertical target, then Extend", 0.45)
	var _line: String = sm.sketch.add_line(0, -4, 6, -4)
	var _target: String = sm.sketch.add_line(10, -7, 10, -1)
	_reframe(sm)
	await FilmUI.wait_frames(ctx.tree, 2)

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.EXTEND)
	var hit := Vector2(5.5, -4)
	var screen := FilmUI.sketch_uv_to_screen(ctx, hit)
	if not FilmUI.require_on_screen(ctx, screen, "extend tool click"):
		return
	var cue: Dictionary = FilmUICues.tool_keys(SketchMode.Tool.EXTEND)
	await ctx.chrome.animate_pointer_click(screen, str(cue.keys), str(cue.desc))
	sm.extend_at(hit)
	await ctx.clock.wait_sec(ctx.tree, 0.5)
	ctx.chrome.clear_keys()

	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await ctx.beat("Block, spline, and extended line on one pad", 0.8)
	await ctx.camera.showcase_smooth(1.0, 32.0)
