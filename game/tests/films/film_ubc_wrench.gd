extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmJaw = preload("res://tests/lib/film_jaw.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")

const HEAD := Vector2(200, 0)
const JAW_DIR := Vector2(sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)
const PERP := Vector2(-sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)


func run_film(ctx: FilmContext) -> void:
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))
	var sm: SketchMode = ctx.main.sketch_mode

	await ctx.movie_toast("A parametric wrench, from a blank part to a print file", 2.0)

	await ctx.beat("Draw the pivot and head circles", 0.45)
	await FilmUI.enter_sketch(ctx)
	if not _ok():
		return
	await _typed_circle(ctx, Vector2.ZERO, "10")
	if not _ok():
		return
	await SxInput.zoom(ctx, Vector3(100, 0, 0), 320.0)
	await _typed_circle(ctx, HEAD, "22.5")
	if not _ok():
		return

	await ctx.beat("Dimension the centres 200 apart", 0.4)
	await _smart_dim_centres(ctx, "200")
	if not _ok():
		return

	await ctx.beat("Add the shaft lines", 0.4)
	await _shaft_lines(ctx)
	if not _ok():
		return

	await ctx.beat("Extrude 10", 0.4)
	await FilmUI.apply_extrude(ctx, 10.0)
	if not _ok():
		return
	await ctx.after_regen()

	var body := _only_body(ctx)
	if body == "":
		FilmUI._fail("no body after blank extrude")
		return
	var top := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	var bottom := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, -1))
	if top == "" or bottom == "":
		FilmUI._fail("missing top/bottom faces")
		return

	await ctx.beat("Open the jaw: centrelines, then Power Trim", 0.45)
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	if not _ok() or sm == null or not sm.active:
		FilmUI._fail("jaw sketch did not start on the top face")
		return
	await SxInput.zoom(ctx, sm.to_model(HEAD), 120.0)
	await _press_rail(ctx, "Jaw")
	await FilmJaw.draw_on_axis(ctx, HEAD, 20.0, -10.0)
	await FilmUI.wait_frames(ctx.tree, 3)
	await _edit_jaw_labels(ctx)
	if not _ok():
		return
	await _typed_circle(ctx, HEAD, "22.5")
	await _typed_circle(ctx, Vector2.ZERO, "5")
	await _draw_centreline(ctx, HEAD, JAW_DIR)
	await _end_line(ctx, HEAD)
	await _draw_centreline(ctx, HEAD + JAW_DIR * 12.0, PERP)
	await _end_line(ctx, HEAD + JAW_DIR * 12.0)
	await _press_rail(ctx, "Trim")
	await _click_uv(ctx, HEAD + JAW_DIR * 3.0 + PERP * 8.0, "Power Trim shaft side")
	if not _ok():
		return

	await ctx.beat("Cut up to the bottom face", 0.4)
	await _pick_finish(ctx, 1, 3)
	var opp: Button = ctx.main.sketch_chrome.opposite_face_button()
	if not await FilmUI.click_control(ctx, opp, FilmUICues.alert("Click", "Opposite face")):
		return
	await FilmUI.wait_frames(ctx.tree, 3)
	await FilmUI.apply_extrude(ctx, 10.0)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Grip slot", 0.4)
	body = _only_body(ctx)
	top = FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	if not _ok() or not ctx.main.sketch_mode.active:
		FilmUI._fail("slot sketch did not start")
		return
	await SxInput.zoom(ctx, ctx.main.sketch_mode.to_model(Vector2(90, 0)), 220.0)
	await _press_rail(ctx, "Slot")
	await _type_dim(ctx, "5")
	await _click_uv(ctx, Vector2(18.5, 0), "Slot first centre")
	await SxInput.hover_uv(ctx, Vector2(168.5, 0))
	await _type_dim(ctx, "150")
	await _pick_finish(ctx, 1, 0)
	await _type_distance(ctx, "2.5")
	await FilmUI.apply_extrude(ctx, 2.5)
	if not _ok():
		return
	await ctx.after_regen()

	await ctx.beat("Round the neck and faces", 0.45)
	body = _only_body(ctx)
	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	await _select_body(ctx, body)
	await _fillet_neck(ctx, body, far_x)
	await _select_body(ctx, body)
	await _fillet_at(ctx, body, Vector3(200, -16, 10), 1.0, KEY_3)
	await _select_body(ctx, body)
	await _fillet_at(ctx, body, Vector3(50, 0, 0), 1.0, KEY_8)
	await _select_body(ctx, body)
	await _fillet_at(ctx, body, Vector3(93.5, 0, 7.5), 1.0, KEY_3)
	if not _ok():
		return

	await ctx.beat("Change the thickness to 14 — the jaw and slot stay through", 0.5)
	await _set_boss_distance(ctx, "14")
	if not _ok():
		return

	await ctx.beat("Export 3MF", 0.4)
	await _export_3mf(ctx)
	if not _ok():
		return

	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 48.0)


func _ok() -> bool:
	return FilmUI.fail_count == 0


func _only_body(ctx: FilmContext) -> String:
	var ids: Array = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


func _press_rail(ctx: FilmContext, label: String) -> void:
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	await FilmUI.click_control(ctx, b, FilmUICues.alert(label, label))


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String, span: float = 80.0) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if span > 0.0:
		await SxInput.zoom(ctx, sm.to_model(uv), span)
	var screen := FilmUI.sketch_uv_to_screen(ctx, uv)
	if screen == Vector2.ZERO:
		screen = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	if not FilmUI.require_on_screen(ctx, screen, desc):
		return
	await SxInput.x11_click_screen(ctx.main.get_viewport(), screen)
	await FilmUI.wait_frames(ctx.tree, 2)


func _typed_circle(ctx: FilmContext, center: Vector2, radius_text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, center, "Circle centre")
	await SxInput.hover_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text)


func _type_dim(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null:
		FilmUI._fail("sketch chrome missing for dim %s" % text)
		return
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("DimLineEdit missing for %s" % text)
		return
	await SxInput.x11_click(edit)
	await SxInput.type_text(edit.get_viewport(), text)
	await SxInput.push_key(edit.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 2)


func _type_distance(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null:
		FilmUI._fail("sketch chrome missing for distance %s" % text)
		return
	var edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	if edit == null and chrome._extrude_spin != null:
		edit = chrome._extrude_spin.get_line_edit()
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("DistanceLineEdit missing for %s" % text)
		return
	await SxInput.x11_click(edit)
	await SxInput.type_text(edit.get_viewport(), text)
	await FilmUI.wait_frames(ctx.tree, 2)


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	return out


func _smart_dim_centres(ctx: FilmContext, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	if circs.size() < 2:
		FilmUI._fail("need two circles for Smart Dimension (got %d)" % circs.size())
		return
	var c1: Vector2 = circs[0]["center"]
	var c2: Vector2 = circs[1]["center"]
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv(ctx, c1, "Smart Dim first centre")
	await _click_uv(ctx, c2, "Smart Dim second centre")
	await FilmUI.wait_frames(ctx.tree, 4)
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		FilmUI._fail("dimension popup did not open after two centres")
		return
	var line: LineEdit = ix._dim_edit_line
	if line == null:
		FilmUI._fail("dimension popup has no line edit")
		return
	await SxInput.x11_click(line)
	await SxInput.type_text(line.get_viewport(), text)
	await SxInput.push_key(line.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 3)


func _shaft_lines(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	if circs.size() < 2:
		FilmUI._fail("need two circles for Shaft Lines (got %d)" % circs.size())
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await SxInput.zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _click_uv(ctx, Vector2(100, 80), "Clear selection", 0.0)
	for c in circs:
		var top: Vector2 = (c["center"] as Vector2) + Vector2(0.0, float(c["radius"]))
		await _click_uv(ctx, top, "Select circle edge", 0.0)
	if sm.selected.size() < 2:
		FilmUI._fail("Shaft Lines: selected %d circles" % sm.selected.size())
		return
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Shaft Lines")):
		return
	await FilmUI.wait_frames(ctx.tree, 3)


func _edit_jaw_labels(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	for pair in [[false, "20"], [true, "45"]]:
		var pos := FilmJaw.click_label_first_glyph(vp, sm, bool(pair[0]))
		if pos == Vector2.INF:
			FilmUI._fail("jaw %s label not on screen" % str(pair[1]))
			return
		await FilmUI.wait_frames(ctx.tree, 3)
		var ix: ViewportInteraction = ctx.main.interaction
		if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
			FilmUI._fail("jaw label %s did not open the editor" % str(pair[1]))
			return
		var line: LineEdit = ix._dim_edit_line
		await SxInput.x11_click(line)
		await SxInput.type_text(line.get_viewport(), str(pair[1]))
		await SxInput.push_key(line.get_viewport(), KEY_ENTER)
		await FilmUI.wait_frames(ctx.tree, 3)


func _draw_centreline(ctx: FilmContext, center: Vector2, along: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Centerline")
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Centerline")):
		return
	var dir := along.normalized()
	await SxInput.zoom(ctx, sm.to_model(center), 70.0)
	await _click_uv(ctx, center - dir * 25.0, "Centreline start")
	await _click_uv(ctx, center + dir * 25.0, "Centreline end")


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


func _pick_finish(ctx: FilmContext, op_index: int, end_index: int) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	var endp: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	await _pick_option(ctx, op, op_index, "FinishOp")
	await _pick_option(ctx, endp, end_index, "FinishEnd")


func _pick_option(ctx: FilmContext, opt: OptionButton, index: int, desc: String) -> void:
	if opt == null or not opt.is_visible_in_tree():
		FilmUI._fail("%s missing" % desc)
		return
	await SxInput.x11_click(opt)
	opt.show_popup()
	await FilmUI.wait_frames(ctx.tree, 10)
	var popup: PopupMenu = opt.get_popup()
	if popup == null or not popup.visible:
		FilmUI._fail("%s popup not visible" % desc)
		return
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = font.get_height(fs) if font != null else fs
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top + (float(font_h) + float(v_sep)) * (float(index) + 0.5)
	var pos := Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)
	await SxInput.x11_click_screen(ctx.main.get_viewport(), pos)
	await FilmUI.wait_frames(ctx.tree, 4)


func _select_body(ctx: FilmContext, body: String) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_4)
	await FilmUI.wait_frames(ctx.tree, 2)
	var screen := FilmUI.model_to_screen(ctx, Vector3(100, 0, 7))
	if FilmUI.is_on_screen(ctx, screen):
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select wrench"))
	if ctx.view.selected_body != body:
		var bb: Dictionary = ctx.view.doc.measure_bbox(body)
		if not bb.is_empty():
			var mid: Vector3 = (bb["min"] as Vector3 + bb["max"] as Vector3) * 0.5
			screen = FilmUI.model_to_screen(ctx, mid)
			if FilmUI.is_on_screen(ctx, screen):
				await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select wrench centre"))
	await FilmUI.wait_frames(ctx.tree, 3)


func _arm_fillet(ctx: FilmContext, radius: float) -> void:
	var btn: Button = ctx.main.interaction._strip_fillet
	if btn == null or not btn.is_visible_in_tree():
		FilmUI._fail("Fillet chip on the selection strip is hidden")
		return
	if not await FilmUI.click_control(ctx, btn, FilmUICues.alert("Fillet", "Arm fillet")):
		return
	await FilmUI.wait_frames(ctx.tree, 2)
	var spin: SpinBox = ctx.main.interaction._strip_radius
	if spin == null or not spin.is_visible_in_tree():
		FilmUI._fail("fillet radius blank missing")
		return
	var edit: LineEdit = spin.get_line_edit()
	await SxInput.x11_click(edit)
	var digits := str(int(round(radius))) if is_equal_approx(radius, round(radius)) else str(radius)
	await SxInput.type_text(edit.get_viewport(), digits)
	await SxInput.push_key(edit.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 2)


func _commit_fillet(ctx: FilmContext) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 4)


func _fillet_neck(ctx: FilmContext, body: String, neck_x: float) -> void:
	await _arm_fillet(ctx, 10.0)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_1)
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(neck_x, -10, 5)),
			FilmUICues.alert("Click", "Neck −Y"))
	await SxInput.push_key(ctx.main.get_viewport(), KEY_4)
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(neck_x, 10, 5)),
			FilmUICues.alert("Click", "Neck +Y"))
	await _commit_fillet(ctx)


func _fillet_at(ctx: FilmContext, body: String, point: Vector3, radius: float, view_key: Key) -> void:
	await _arm_fillet(ctx, radius)
	await SxInput.push_key(ctx.main.get_viewport(), view_key)
	await FilmUI.wait_frames(ctx.tree, 2)
	if radius <= 1.01 and absf(point.z - 7.5) < 0.2:
		await FilmUI.zoom_point_clear_of_edges(ctx, body, point)
	var screen := FilmUI.model_to_screen(ctx, point)
	if not FilmUI.require_on_screen(ctx, screen, "fillet pick"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Fillet edges"))
	await _commit_fillet(ctx)


func _set_boss_distance(ctx: FilmContext, digits: String) -> void:
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await FilmUI.wait_frames(ctx.tree, 2)
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await FilmUI.wait_frames(ctx.tree, 2)
	var view_btn := FilmUI.find_button(ctx.main, "View") as MenuButton
	if not await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline")):
		return
	await FilmUI.wait_frames(ctx.tree, 3)
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
	await FilmUI.wait_frames(ctx.tree, 2)
	var row: Control = tl._rows.get(boss)
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str((child as Button).text) != "":
				btn = child as Button
				break
	if btn == null:
		FilmUI._fail("timeline extrude row missing")
		return
	await SxInput.x11_click_screen(btn.get_viewport(), btn.get_global_rect().get_center(), true)
	await FilmUI.wait_frames(ctx.tree, 4)
	var spin := tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	if spin == null:
		FilmUI._fail("Distance field missing")
		return
	var edit: LineEdit = spin.get_line_edit()
	await SxInput.x11_click(edit)
	await SxInput.type_text(edit.get_viewport(), digits)
	await SxInput.push_key(edit.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 4)
	var empty := FilmUI.viewport_empty_click_pos(ctx)
	await FilmUI.viewport_click(ctx, empty, FilmUICues.alert("Click", "Dismiss Distance"))


func _export_3mf(ctx: FilmContext) -> void:
	var file_btn := FilmUI.find_button(ctx.main, "File") as MenuButton
	if not await FilmUI.activate_menu_id(ctx, file_btn, 11, FilmUICues.alert("File", "Export 3MF")):
		return
	await FilmUI.wait_frames(ctx.tree, 6)
	var dlg: FileDialog = ctx.main.file_dialog
	if dlg == null or not dlg.visible:
		FilmUI._fail("Export 3MF dialog did not open")
		return
	var dest := "/tmp/sx-film-ubc-wrench.3mf"
	var name_edit: LineEdit = null
	if dlg.has_method("get_line_edit"):
		var le: Variant = dlg.get_line_edit()
		if le is LineEdit:
			name_edit = le as LineEdit
	if name_edit == null:
		for c in dlg.find_children("*", "LineEdit", true, false):
			name_edit = c as LineEdit
			break
	if name_edit == null:
		FilmUI._fail("export filename field missing")
		return
	await SxInput.x11_click(name_edit)
	await SxInput.type_text(name_edit.get_viewport(), dest)
	await FilmUI.wait_frames(ctx.tree, 2)
	var ok_btn := dlg.get_ok_button()
	if ok_btn == null:
		FilmUI._fail("export OK missing")
		return
	await SxInput.x11_click(ok_btn)
	await FilmUI.wait_frames(ctx.tree, 6)
	if dlg.visible:
		dlg.hide()
