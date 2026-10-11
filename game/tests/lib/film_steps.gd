## Click-only steps shared by UI films.
## Calls FilmUI and SxInput; a missing control fails through FilmUI._fail.
class_name FilmSteps
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")


static func press_rail(ctx: FilmContext, label: String) -> void:
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	await FilmUI.click_control(ctx, b, FilmUICues.alert(label, label))


static func click_uv(ctx: FilmContext, uv: Vector2, desc: String, span: float = 80.0) -> void:
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


static func type_dim(ctx: FilmContext, text: String) -> void:
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


static func type_distance(ctx: FilmContext, text: String) -> void:
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


static func pick_finish(ctx: FilmContext, op_index: int, end_index: int) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	var endp: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	await pick_option(ctx, op, op_index, "FinishOp")
	await pick_option(ctx, endp, end_index, "FinishEnd")


static func pick_option(ctx: FilmContext, opt: OptionButton, index: int, desc: String) -> void:
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


static func select_body(ctx: FilmContext, body: String) -> void:
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


static func arm_fillet(ctx: FilmContext, radius: float) -> void:
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


static func commit_fillet(ctx: FilmContext) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 4)


static func fillet_at(ctx: FilmContext, body: String, point: Vector3, radius: float, view_key: Key) -> void:
	await arm_fillet(ctx, radius)
	await SxInput.push_key(ctx.main.get_viewport(), view_key)
	await FilmUI.wait_frames(ctx.tree, 2)
	if radius <= 1.01 and absf(point.z - 7.5) < 0.2:
		await FilmUI.zoom_point_clear_of_edges(ctx, body, point)
	var screen := FilmUI.model_to_screen(ctx, point)
	if not FilmUI.require_on_screen(ctx, screen, "fillet pick"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Fillet edges"))
	await commit_fillet(ctx)


static func only_body(ctx: FilmContext) -> String:
	var ids: Array = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


static func circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	return out


static func export_3mf(ctx: FilmContext) -> void:
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
