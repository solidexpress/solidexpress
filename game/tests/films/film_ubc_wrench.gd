extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmJaw = preload("res://tests/lib/film_jaw.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")

const HEAD := Vector2(200, 0)
const JAW_DIR := Vector2(sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)
const PERP := Vector2(-sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)


func run_film(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var actor := FilmActor.of(ctx)

	await ctx.beat("Draw the pivot and head circles")
	await FilmUI.enter_sketch(ctx)
	if not _ok():
		return
	await _typed_circle(ctx, Vector2.ZERO, "10")
	if not _ok():
		return
	await FilmActor.of(ctx).zoom_to(Vector3(100, 0, 0), 320.0, "Frame head")
	await _typed_circle(ctx, HEAD, "22.5")
	if not _ok():
		return

	await ctx.beat("Dimension the centres 200 apart")
	await _smart_dim_centres(ctx, "200")
	if not _ok():
		return

	await ctx.beat("Add the shaft lines")
	await _shaft_lines(ctx)
	if not _ok():
		return

	await ctx.beat("Extrude 10")
	await FilmUI.apply_extrude(ctx, 10.0)
	if not _ok():
		return

	var body := FilmSteps.only_body(ctx)
	if body == "":
		FilmUI._fail("no body after blank extrude")
		return
	var top := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	var bottom := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, -1))
	if top == "" or bottom == "":
		FilmUI._fail("missing top/bottom faces")
		return

	await ctx.beat("Open the jaw: centrelines, then Power Trim")
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	if not _ok() or sm == null or not sm.active:
		FilmUI._fail("jaw sketch did not start on the top face")
		return
	await FilmActor.of(ctx).zoom_to(sm.to_model(HEAD), 120.0, "Frame jaw")
	await FilmSteps.press_rail(ctx, "Jaw")
	await FilmJaw.draw_on_axis(ctx, HEAD, 20.0, -10.0)
	await _edit_jaw_labels(ctx)
	if not _ok():
		return
	await _typed_circle(ctx, HEAD, "22.5")
	await _typed_circle(ctx, Vector2.ZERO, "5")
	await _draw_centreline(ctx, HEAD, JAW_DIR)
	await _end_line(ctx, HEAD)
	await _draw_centreline(ctx, HEAD + JAW_DIR * 12.0, PERP)
	await _end_line(ctx, HEAD + JAW_DIR * 12.0)
	await FilmSteps.press_rail(ctx, "Trim")
	await FilmSteps.click_uv(ctx, HEAD + JAW_DIR * 3.0 + PERP * 8.0, "Power Trim shaft side")
	if not _ok():
		return

	await ctx.beat("Cut through the mouth")
	await FilmSteps.pick_finish(ctx, 1, 1)
	await FilmUI.apply_extrude(ctx, 10.0)
	if not _ok():
		return

	await ctx.beat("Grip slot")
	body = FilmSteps.only_body(ctx)
	top = FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	if not _ok() or not ctx.main.sketch_mode.active:
		FilmUI._fail("slot sketch did not start")
		return
	await FilmActor.of(ctx).zoom_to(ctx.main.sketch_mode.to_model(Vector2(90, 0)), 220.0, "Frame slot")
	await FilmSteps.press_rail(ctx, "Slot")
	await FilmSteps.type_dim(ctx, "5")
	await FilmSteps.click_uv(ctx, Vector2(18.5, 0), "Slot first centre", 0.0)
	await FilmActor.of(ctx).zoom_to(ctx.main.sketch_mode.to_model(Vector2(90, 0)), 220.0, "Frame slot length")
	await FilmUI.hover_uv(ctx, Vector2(168.5, 0), "Slot second centre")
	await FilmSteps.type_dim(ctx, "150")
	await FilmSteps.pick_finish(ctx, 1, 0)
	await FilmUI.apply_extrude(ctx, 2.5)
	if not _ok():
		return

	await ctx.beat("Round the neck and faces")
	body = FilmSteps.only_body(ctx)
	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	await FilmSteps.select_body(ctx, body)
	await _fillet_neck(ctx, body, far_x)
	await actor.result_pause()
	await FilmSteps.select_body(ctx, body)
	await FilmSteps.fillet_at(ctx, body, Vector3(200, -16, 10), 1.0, KEY_3)
	await FilmSteps.select_body(ctx, body)
	await FilmSteps.fillet_at(ctx, body, Vector3(50, 0, 0), 1.0, KEY_8)
	await FilmSteps.select_body(ctx, body)
	await FilmSteps.fillet_at(ctx, body, Vector3(93.5, 0, 7.5), 1.0, KEY_3)
	await actor.result_pause()
	if not _ok():
		return

	await ctx.beat("Change the thickness to 14 — the jaw and slot stay through")
	await _set_boss_distance(ctx, "14")
	if not _ok():
		return
	await actor.result_pause()

	await ctx.beat("Export 3MF")
	await FilmSteps.export_3mf(ctx)
	if not _ok():
		return


func _ok() -> bool:
	return FilmUI.fail_count == 0


func _typed_circle(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmSteps.click_uv(ctx, center, "Circle centre")
	await FilmUI.hover_uv(ctx, center + Vector2(6, 0), "Circle radius")
	await FilmSteps.type_dim(ctx, radius_text)


func _smart_dim_centres(ctx: FilmContext, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := FilmSteps.circles(sm)
	if circs.size() < 2:
		FilmUI._fail("need two circles for Smart Dimension (got %d)" % circs.size())
		return
	var c1: Vector2 = circs[0]["center"]
	var c2: Vector2 = circs[1]["center"]
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, c1, "Smart Dim first centre")
	await FilmSteps.click_uv(ctx, c2, "Smart Dim second centre")
	await FilmActor.of(ctx).dwell()
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		FilmUI._fail("dimension popup did not open after two centres")
		return
	var line: LineEdit = ix._dim_edit_line
	if line == null:
		FilmUI._fail("dimension popup has no line edit")
		return
	await FilmActor.of(ctx).edit_field(line, text, "Centre distance %s" % text)


func _shaft_lines(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := FilmSteps.circles(sm)
	if circs.size() < 2:
		FilmUI._fail("need two circles for Shaft Lines (got %d)" % circs.size())
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmActor.of(ctx).zoom_to(Vector3(100, 0, 0), 280.0, "Frame shaft")
	await FilmSteps.click_uv(ctx, Vector2(100, 80), "Clear selection", 0.0)
	for c in circs:
		var top: Vector2 = (c["center"] as Vector2) + Vector2(0.0, float(c["radius"]))
		await FilmSteps.click_uv(ctx, top, "Select circle edge", 0.0)
	if sm.selected.size() < 2:
		FilmUI._fail("Shaft Lines: selected %d circles" % sm.selected.size())
		return
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Shaft Lines")):
		return


func _edit_jaw_labels(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	for pair in [[false, "20"], [true, "45"]]:
		var pos := FilmJaw.label_first_glyph_pos(sm, bool(pair[0]))
		if pos == Vector2.INF:
			FilmUI._fail("jaw %s label not on screen" % str(pair[1]))
			return
		await FilmActor.of(ctx).tap_x11(pos, FilmUICues.alert("Click", "Jaw label %s" % str(pair[1])))
		var ix: ViewportInteraction = ctx.main.interaction
		if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
			FilmUI._fail("jaw label %s did not open the editor" % str(pair[1]))
			return
		var line: LineEdit = ix._dim_edit_line
		await FilmActor.of(ctx).edit_field(line, str(pair[1]), "Jaw %s" % str(pair[1]))


func _draw_centreline(ctx: FilmContext, center: Vector2, along: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Centerline")
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Centerline")):
		return
	var dir := along.normalized()
	await FilmActor.of(ctx).zoom_to(sm.to_model(center), 70.0, "Frame centreline")
	await FilmSteps.click_uv(ctx, center - dir * 25.0, "Centreline start")
	await FilmSteps.click_uv(ctx, center + dir * 25.0, "Centreline end")


func _end_line(ctx: FilmContext, at_uv: Vector2) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var done: Button = chrome.done_button() if chrome != null and chrome.has_method("done_button") else null
	if done != null and done.is_visible_in_tree():
		await FilmUI.click_control(ctx, done, FilmUICues.alert("Done", "End line chain"))
		return
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(at_uv))
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("RMB", "End line chain"),
			false, MOUSE_BUTTON_RIGHT)


func _fillet_neck(ctx: FilmContext, body: String, neck_x: float) -> void:
	await FilmSteps.arm_fillet(ctx, 10.0)
	await FilmActor.of(ctx).view_key(KEY_1, "Front")
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(neck_x, -10, 5)),
			FilmUICues.alert("Click", "Neck −Y"))
	await FilmActor.of(ctx).view_key(KEY_4, "Back")
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(neck_x, 10, 5)),
			FilmUICues.alert("Click", "Neck +Y"))
	await FilmSteps.commit_fillet(ctx)


func _set_boss_distance(ctx: FilmContext, digits: String) -> void:
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await FilmActor.of(ctx).dwell()
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await FilmActor.of(ctx).dwell()
	if not ctx.main.show_timeline:
		var view_btn := FilmUI.find_button(ctx.main, "View") as MenuButton
		if not await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline")):
			return
		await FilmActor.of(ctx).dwell()
	if not ctx.main.show_timeline:
		FilmUI._fail("View → Timeline did not show the timeline")
		return
	var boss := ""
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("op", "new")) != "cut":
			boss = str(f.get("id", ""))
			break
	if boss == "":
		FilmUI._fail("base extrude not on the timeline")
		return
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await FilmActor.of(ctx).dwell()
	var row: Control = tl._rows.get(boss)
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str((child as Button).text) != "":
				btn = child as Button
				break
	if btn == null or not btn.is_visible_in_tree():
		FilmUI._fail("timeline extrude row missing")
		return
	FilmUI.ensure_control_visible(btn)
	await FilmActor.of(ctx).dwell()
	await FilmActor.of(ctx).tap_x11(FilmUI.control_screen_center(btn),
			FilmUICues.alert("Click", "Base extrude"), true)
	await FilmActor.of(ctx).dwell()
	if tl.property_panel == null or not tl.property_panel.visible:
		FilmUI._fail("property panel did not open")
		return
	var spin := tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	if spin == null or not spin.is_visible_in_tree():
		FilmUI._fail("Distance field missing")
		return
	await FilmActor.of(ctx).edit_field(spin, digits, "Boss thickness %s" % digits)
	var empty := FilmUI.viewport_empty_click_pos(ctx)
	await FilmUI.viewport_click(ctx, empty, FilmUICues.alert("Click", "Dismiss Distance"))
