extends RefCounted
## Flanged pipe: Front Ø150 tube, two-face shell, flange, circular pattern, mirror, fillet.
## FilmUI, FilmSteps, PipeFixture, SxInput. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	await ctx.movie_toast("A flanged pipe: shell, circular pattern, feature mirror, fillet", 2.0)

	await ctx.beat("Sketch a Ø150 circle on Front and extrude 250", 0.4)
	await PipeFixture.click_front(ctx)
	if not _ok():
		return
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("Front sketch did not start")
		return
	await FilmSteps.press_rail(ctx, "Circle")
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø150 centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(PipeFixture.mm("OD") * 0.5, 0), "Ø150 rim", 280.0)
	await PipeFixture.dim_diameter(ctx, Vector2(PipeFixture.mm("OD") * 0.5, 0), "150")
	if not _ok():
		return
	await PipeFixture.extrude_blind(ctx, "250", 0)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Shell 10, both ends", 0.4)
	await _select_body(ctx)
	if not _ok():
		return
	await FilmSteps.two_face_shell(ctx, {
		"normal": Vector3(0, 0, 1), "plane": PipeFixture.mm("L0"), "view_key": KEY_3,
	}, {
		"normal": Vector3(0, 0, -1), "plane": 0.0, "view_key": KEY_8,
	}, PipeFixture.mm("WALL"))
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Flange Ø225, fuse 10", 0.4)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, PipeFixture.mm("L0"))
	if not _ok():
		return
	await FilmSteps.press_rail(ctx, "Circle")
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø225 centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(PipeFixture.mm("FLANGE_D") * 0.5, 0), "Ø225 rim", 280.0)
	await PipeFixture.dim_diameter(ctx, Vector2(PipeFixture.mm("FLANGE_D") * 0.5, 0), "225")
	if not _ok():
		return
	await PipeFixture.extrude_blind(ctx, "10", 2)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Bore Ø130, eight Ø10 holes on a 94 mm pitch, cut 10", 0.4)
	var cut_z := PipeFixture.mm("L0") + PipeFixture.mm("FLANGE_T")
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, cut_z)
	if not _ok():
		return
	var pcd := PipeFixture.mm("PCD")
	var hole_r := PipeFixture.mm("HOLE_D") * 0.5
	var id_r := PipeFixture.mm("ID") * 0.5
	await FilmSteps.press_rail(ctx, "Circle")
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø130 centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(id_r, 0), "Ø130 rim", 280.0)
	await PipeFixture.dim_diameter(ctx, Vector2(id_r, 0), "130")
	await FilmSteps.press_rail(ctx, "Circle")
	await FilmSteps.click_uv(ctx, Vector2(0, pcd), "Ø10 centre", 160.0)
	await FilmSteps.click_uv(ctx, Vector2(0, pcd + hole_r), "Ø10 rim", 80.0)
	await PipeFixture.dim_diameter(ctx, Vector2(0, pcd + hole_r), "10")
	await PipeFixture.dim_distance(ctx, Vector2.ZERO, Vector2(0, pcd), "94")
	await PipeFixture.vertical_centres(ctx, Vector2.ZERO, Vector2(0, pcd))
	if not _ok():
		return
	await PipeFixture.select_seed(ctx)
	await FilmSteps.circular_pattern(ctx, 8, 360.0)
	if not _ok():
		return
	await PipeFixture.extrude_blind(ctx, "10", 1)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Mirror the four features about z = 0", 0.4)
	await _select_body(ctx)
	await PipeFixture.show_timeline(ctx)
	if not _ok():
		return
	var names: Array = PipeFixture.source_names(ctx.view.doc)
	if names.size() != 4:
		FilmUI._fail("need four timeline names (got %s)" % str(names))
		return
	await FilmSteps.feature_mirror(ctx, Vector3(0, 0, -1), 0.0, names)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Shell the mirrored half 10", 0.4)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_8)
	await FilmUI.wait_frames(ctx.tree, 6)
	await FilmSteps.click_face(ctx, Vector3(0, 0, -1), 260.0)
	if not _ok():
		return
	await FilmSteps.shell_selected_face(ctx, PipeFixture.mm("WALL"))
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Fillet R5 on both flange faces", 0.4)
	await _select_body(ctx)
	if not _ok():
		return
	await FilmSteps.arm_fillet(ctx, PipeFixture.mm("FILLET"))
	await SxInput.push_key(ctx.main.get_viewport(), KEY_3)
	await FilmUI.wait_frames(ctx.tree, 6)
	await SxInput.zoom(ctx, Vector3(0, 0, 260), 280.0)
	await FilmSteps.click_face(ctx, Vector3(0, 0, 1), 260.0)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_8)
	await FilmUI.wait_frames(ctx.tree, 6)
	await SxInput.zoom(ctx, Vector3(0, 0, -260), 280.0)
	await FilmSteps.shift_click_face(ctx, Vector3(0, 0, -1), 260.0)
	await FilmSteps.commit_fillet(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0


func _select_body(ctx: FilmContext) -> void:
	var body := FilmSteps.only_body(ctx)
	if body == "":
		FilmUI._fail("no body")
		return
	await SxInput.push_key(ctx.main.get_viewport(), KEY_7)
	await FilmUI.wait_frames(ctx.tree, 4)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var mid := Vector3.ZERO
	if not bb.is_empty():
		mid = ((bb["min"] as Vector3) + (bb["max"] as Vector3)) * 0.5
	await SxInput.zoom(ctx, mid, 420.0)
	var screen := FilmUI.model_to_screen(ctx, mid)
	if not FilmUI.require_on_screen(ctx, screen, "body"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select body"))
	await FilmUI.wait_frames(ctx.tree, 2)
