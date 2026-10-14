extends RefCounted
## Click-driven Tutor1: centre rectangle, boss, offset cut, fillets, shell, section.
## FilmUI, FilmSteps, and SxInput only. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	await ctx.movie_toast("A boss, an offset cut, two fillets, a shell, and a section", 2.0)

	await ctx.beat("Sketch a 120 by 120 rectangle from the centre", 0.4)
	await FilmUI.enter_sketch(ctx)
	if not _ok():
		return
	await FilmSteps.centre_rect(ctx, Vector2.ZERO, Vector2(60, 60))
	await _dimension_line(ctx, Vector2(90, 90), Vector2(0, 60), "120")
	await _dimension_line(ctx, Vector2(90, 90), Vector2(60, 0), "120")
	if not _ok():
		return

	await ctx.beat("Extrude 30", 0.35)
	await _extrude(ctx, "30", 0, 0)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Boss: circle on the front face, diameter 70, extrude 25", 0.4)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, 30.0)
	if not _ok():
		return
	await FilmSteps.press_rail(ctx, "Circle")
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Boss centre", 160.0)
	await FilmSteps.click_uv(ctx, Vector2(35, 0), "Boss rim", 160.0)
	await _extrude(ctx, "25", 2, 0)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Offset the rim 5 mm inward and cut through", 0.4)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, 55.0)
	if not _ok():
		return
	await FilmSteps.offset_rim(ctx, "5", Vector2(35, 0))
	await _extrude(ctx, "", 1, 1)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Round the corners and the front face, R5", 0.4)
	await _select_body(ctx)
	if not _ok():
		return
	await FilmSteps.arm_fillet(ctx, 5.0)
	await FilmSteps.pick_corner_table(ctx, FilletPick.CORNERS, 15.0)
	await _view(ctx, KEY_3)
	await FilmSteps.shift_click_face(ctx, Vector3(0, 0, 1), 30.0)
	await FilmSteps.commit_fillet(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Round the hole rims, R1.5", 0.4)
	await _select_body(ctx)
	if not _ok():
		return
	await FilmSteps.arm_fillet(ctx, 1.5)
	await _view(ctx, KEY_3)
	await FilmSteps.click_face(ctx, Vector3(0, 0, 1), 55.0)
	await FilmSteps.commit_fillet(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Shell 1, open the back", 0.4)
	await _view(ctx, KEY_8)
	await FilmSteps.click_face(ctx, Vector3(0, 0, -1), 0.0)
	if not _ok():
		return
	await FilmSteps.shell_selected_face(ctx, 1.0)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Section on the Top plane, then off", 0.4)
	await FilmSteps.section_top(ctx)
	if not _ok():
		return
	await FilmSteps.section_off(ctx)
	if not _ok():
		return

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0


func _extrude(ctx: FilmContext, distance: String, op: int, end: int) -> void:
	await FilmSteps.pick_finish(ctx, op, end)
	if not _ok():
		return
	if distance != "":
		await FilmSteps.type_distance(ctx, distance)
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var ex: Button = chrome.extrude_button() if chrome != null else null
	if not await FilmUI.click_control(ctx, ex, FilmUICues.extrude(30.0 if distance == "30" else 0.0)):
		return
	await ctx.after_regen()
	await FilmUI.exit_sketch(ctx)


func _view(ctx: FilmContext, key: Key) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), key)
	await FilmUI.wait_frames(ctx.tree, 8)


func _select_body(ctx: FilmContext) -> void:
	var body := FilmSteps.only_body(ctx)
	if body == "":
		FilmUI._fail("no body")
		return
	await _view(ctx, KEY_7)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		FilmUI._fail("body has no bbox")
		return
	var mid: Vector3 = ((bb["min"] as Vector3) + (bb["max"] as Vector3)) * 0.5
	var screen := FilmUI.model_to_screen(ctx, mid)
	if not FilmUI.require_on_screen(ctx, screen, "body"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select body"))
	await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_body != body:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select body"))
		await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_body != body:
		FilmUI._fail("body not selected")


func _dimension_line(ctx: FilmContext, empty_uv: Vector2, uv: Vector2, text: String) -> void:
	await FilmSteps.press_rail(ctx, "Select")
	await FilmSteps.click_uv(ctx, empty_uv, "Clear selection", 220.0)
	await FilmSteps.press_rail(ctx, "Smart Dim")
	await FilmSteps.click_uv(ctx, uv, "Smart Dim line", 220.0)
	await _type_last_label(ctx, text)


func _type_last_label(ctx: FilmContext, text: String) -> void:
	if not _ok():
		return
	await FilmUI.wait_frames(ctx.tree, 3)
	var sm: SketchMode = ctx.main.sketch_mode
	var rects: Array = sm.dimension_label_screen_rects() if sm != null else []
	var hit: Dictionary = {}
	for i in range(rects.size() - 1, -1, -1):
		var row: Dictionary = rects[i]
		if not str(row.get("text", "")).ends_with("°"):
			hit = row
			break
	if hit.is_empty():
		FilmUI._fail("no dimension label to set %s" % text)
		return
	var rect: Rect2 = hit["rect"]
	var center := rect.get_center()
	if not FilmUI.require_on_screen(ctx, center, "dimension %s" % text):
		return
	await FilmUI.viewport_click(ctx, center, FilmUICues.alert("Click", "Dimension %s" % text))
	await FilmUI.wait_frames(ctx.tree, 4)
	var line := ctx.main.find_child("DimEditLine", true, false) as LineEdit
	if line == null or not line.is_visible_in_tree():
		FilmUI._fail("dimension editor did not open for %s" % text)
		return
	await SxInput.x11_click(line)
	line.select_all()
	await SxInput.type_text(line.get_viewport(), text)
	await SxInput.push_key(line.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 3)
