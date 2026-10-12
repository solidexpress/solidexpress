extends RefCounted
## Click-driven Lesson 2 box: ground rectangle, fillet, shell, side hole, resize.
## FilmUI, FilmSteps, and SxInput only. A missing control fails the film.

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	await ctx.movie_toast("A hollow box with a side hole — resize it and everything follows", 2.0)

	await ctx.beat("Sketch a rectangle on the ground", 0.4)
	await FilmUI.enter_sketch(ctx)
	if not _ok():
		return
	await FilmSteps.press_rail(ctx, "Rect")
	await FilmSteps.click_uv(ctx, Vector2(0, 0), "Rectangle origin", 180.0)
	await FilmSteps.click_uv(ctx, Vector2(100, 65), "Rectangle opposite corner", 180.0)
	if not _ok():
		return

	await ctx.beat("Dimension it: 100 by 65, then change 65 to 60", 0.4)
	await _dim_line(ctx, Vector2(50, 30), Vector2(50, 65), "100")
	await _dim_line(ctx, Vector2(50, 30), Vector2(100, 32.5), "65")
	await _edit_label(ctx, "65", "60")
	if not _ok():
		return

	await ctx.beat("Extrude 50", 0.35)
	await _extrude(ctx, "50")
	if not _ok():
		return
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await ctx.beat("Round the four corners R10 in one fillet", 0.4)
	var body := FilmSteps.only_body(ctx)
	if body == "":
		FilmUI._fail("no body after extrude")
		return
	await _select_body_face(ctx, body)
	await FilmSteps.arm_fillet(ctx, 10.0)
	await FilmSteps.pick_corner_edges(ctx, body)
	await FilmSteps.commit_fillet(ctx)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Shell 5, open the top", 0.4)
	body = FilmSteps.only_body(ctx)
	await _select_top_face(ctx, body)
	await FilmSteps.shell_selected_face(ctx, 5.0)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Sketch on the right-hand face", 0.35)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(1, 0, 0), KEY_2)
	if not _ok():
		return

	await ctx.beat("Ø10 hole, 25 from the left edge, 40 from the bottom", 0.45)
	await FilmSteps.press_rail(ctx, "Circle")
	await FilmSteps.click_uv(ctx, Vector2(35, 40), "Hole centre", 120.0)
	await FilmSteps.click_uv(ctx, Vector2(40, 40), "Hole rim", 120.0)
	await FilmSteps.convert_edge(ctx, Vector3(100, 10, 25))
	await FilmSteps.convert_edge(ctx, Vector3(100, 30, 0))
	await _dim_line(ctx, Vector2(50, 20), Vector2(40, 40), "10")
	await _dim_pair(ctx, Vector2(50, 20), Vector2(35, 40), Vector2(10, 25), "25")
	await _dim_pair(ctx, Vector2(50, 20), Vector2(35, 40), Vector2(30, 0), "40")
	if not _ok():
		return

	await ctx.beat("Cut through all", 0.35)
	await FilmSteps.pick_finish(ctx, 1, 1)
	await _extrude(ctx, "")
	if not _ok():
		return
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await ctx.beat("Change the width back to 65 — fillet, shell and hole follow", 0.45)
	await _edit_base_width(ctx, "60", "65")
	if not _ok():
		return
	await ctx.after_regen()

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0


func _clear_picks(ctx: FilmContext, empty_uv: Vector2) -> void:
	await FilmSteps.press_rail(ctx, "Select")
	await FilmSteps.click_uv(ctx, empty_uv, "Clear selection", 180.0)


func _dim_line(ctx: FilmContext, empty_uv: Vector2, uv: Vector2, text: String) -> void:
	await _clear_picks(ctx, empty_uv)
	await FilmSteps.press_rail(ctx, "Smart Dim")
	await FilmSteps.click_uv(ctx, uv, "Smart Dim line")
	await _type_last_label(ctx, text)


func _dim_pair(ctx: FilmContext, empty_uv: Vector2, a: Vector2, b: Vector2, text: String) -> void:
	await _clear_picks(ctx, empty_uv)
	await FilmSteps.press_rail(ctx, "Smart Dim")
	await FilmSteps.click_uv(ctx, a, "Smart Dim first")
	await FilmSteps.click_uv(ctx, b, "Smart Dim second")
	await _type_last_label(ctx, text)


func _select_body_face(ctx: FilmContext, body: String) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_7)
	await FilmUI.wait_frames(ctx.tree, 3)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		FilmUI._fail("fillet: body has no bbox")
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
		FilmUI._fail("body not selected for fillet")


func _select_top_face(ctx: FilmContext, body: String) -> void:
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	if face == "":
		FilmUI._fail("no top face to shell")
		return
	await SxInput.push_key(ctx.main.get_viewport(), KEY_3)
	await FilmUI.wait_frames(ctx.tree, 3)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		FilmUI._fail("top face: body has no bbox")
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var pt := Vector3(mn.x + 18.0, mn.y + 18.0, mx.z)
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.require_on_screen(ctx, screen, "top face"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Top face"))
	await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Top face"))
		await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face:
		FilmUI._fail("top face not selected")


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
	await _type_label_rect(ctx, hit["rect"], text)


func _edit_label(ctx: FilmContext, token: String, text: String) -> void:
	await FilmSteps.press_rail(ctx, "Select")
	await FilmUI.wait_frames(ctx.tree, 2)
	var sm: SketchMode = ctx.main.sketch_mode
	var rects: Array = sm.dimension_label_screen_rects() if sm != null else []
	for row in rects:
		var shown := str(row.get("text", ""))
		if shown == token or shown == "Ø" + token:
			await _type_label_rect(ctx, row["rect"], text)
			return
	FilmUI._fail("dimension label %s is not on screen" % token)


func _type_label_rect(ctx: FilmContext, rect: Rect2, text: String) -> void:
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
	await SxInput.type_text(line.get_viewport(), text)
	await SxInput.push_key(line.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 3)


func _extrude(ctx: FilmContext, distance: String) -> void:
	if distance != "":
		await FilmSteps.type_distance(ctx, distance)
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var ex: Button = chrome.extrude_button() if chrome != null else null
	if not await FilmUI.click_control(ctx, ex, FilmUICues.extrude(50.0 if distance == "50" else 0.0)):
		return
	await ctx.after_regen()


func _edit_base_width(ctx: FilmContext, token: String, text: String) -> void:
	var view_btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		if str((c as MenuButton).text) == "View":
			view_btn = c as MenuButton
			break
	if not await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline")):
		return
	await FilmUI.wait_frames(ctx.tree, 2)
	var pencil: Button = null
	var tl: Node = ctx.main.timeline
	if tl != null:
		for c in tl.find_children("*", "Button", true, false):
			var auto := str(c.get_meta("sx_auto", ""))
			if auto.begins_with("timeline:pencil:sketch"):
				pencil = c as Button
				break
	if pencil == null or not pencil.is_visible_in_tree():
		FilmUI._fail("sketch pencil is hidden")
		return
	await FilmUI.click_control(ctx, pencil, FilmUICues.edit_pad())
	await FilmUI.wait_frames(ctx.tree, 4)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("base sketch did not reopen")
		return
	await _edit_label(ctx, token, text)
	await FilmUI.exit_sketch(ctx)
