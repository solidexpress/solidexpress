## Click-only steps shared by UI films.
## Calls FilmUI and SxInput; a missing control fails through FilmUI._fail.
class_name FilmSteps
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")

## Lesson 2 box: four vertical corners. Iso shows the y-min pair;
## Right and Left show the y-max pair (the walk's CORNERS table).
const _BOX_CORNERS: Array = [
	{"x_max": true, "y_max": false, "key": KEY_7},
	{"x_max": false, "y_max": false, "key": KEY_7},
	{"x_max": true, "y_max": true, "key": KEY_2},
	{"x_max": false, "y_max": true, "key": KEY_6},
]


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
	if op_index < 0 and end_index < 0:
		return
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	var endp: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	if op_index >= 0:
		await pick_option(ctx, op, op_index, "FinishOp")
	if end_index >= 0:
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
	if not is_equal_approx(float(spin.value), radius):
		await SxInput.x11_click(edit)
		var digits := str(int(round(radius))) if is_equal_approx(radius, round(radius)) else str(radius)
		await SxInput.type_text(edit.get_viewport(), digits)
		await SxInput.push_key(edit.get_viewport(), KEY_ENTER)
	await _release_line_focus(ctx)
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


static func pick_corner_edges(ctx: FilmContext, body: String) -> void:
	if body == "" or ctx.view == null or ctx.view.doc == null:
		FilmUI._fail("corner fillet needs a body")
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		FilmUI._fail("corner fillet: body has no bbox")
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var mid_z := (mn.z + mx.z) * 0.5
	await _release_line_focus(ctx)
	for spec in _BOX_CORNERS:
		var x := mx.x if bool(spec["x_max"]) else mn.x
		var y := mx.y if bool(spec["y_max"]) else mn.y
		await SxInput.push_key(ctx.main.get_viewport(), spec["key"] as Key)
		await FilmUI.wait_frames(ctx.tree, 3)
		var world := Vector3(x, y, mid_z)
		await SxInput.zoom(ctx, world, 70.0)
		var screen := FilmUI.model_to_screen(ctx, world)
		if not FilmUI.require_on_screen(ctx, screen, "corner edge"):
			return
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Corner edge"))
		await FilmUI.wait_frames(ctx.tree, 2)


static func shell_selected_face(ctx: FilmContext, mm: float) -> void:
	var chip := _by_auto(ctx.main, "strip:shell") as Button
	if chip == null or not chip.is_visible_in_tree():
		FilmUI._fail("Shell chip is hidden")
		return
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shell", "Hollow the selected face")):
		return
	await FilmUI.wait_frames(ctx.tree, 3)
	var field := _by_auto(ctx.main, "finish:Thickness") as LineEdit
	if field == null or not field.is_visible_in_tree():
		FilmUI._fail("Shell thickness field is hidden")
		return
	var digits := str(int(round(mm))) if is_equal_approx(mm, round(mm)) else str(mm)
	await SxInput.type_text(field.get_viewport(), digits)
	await FilmUI.wait_frames(ctx.tree, 1)
	var ok := _by_auto(ctx.main, "finish:Ok") as Button
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("Shell Apply is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("Apply", "Shell %s mm" % digits))
	await FilmUI.wait_frames(ctx.tree, 4)


## Two planar faces then Shell thickness. first/second are {normal, plane, view_key}.
static func two_face_shell(ctx: FilmContext, first: Dictionary, second: Dictionary, mm: float) -> void:
	await _face_from_row(ctx, first, false)
	if FilmUI.fail_count > 0:
		return
	await _face_from_row(ctx, second, true)
	if FilmUI.fail_count > 0:
		return
	await shell_selected_face(ctx, mm)


## Circular Sketch Pattern: rail Pattern, Circular chip, Count, Angle, Ok.
## Seed selection is the caller's click, not a private set_selected.
static func circular_pattern(ctx: FilmContext, count: int, angle: float) -> void:
	await press_rail(ctx, "Pattern")
	if FilmUI.fail_count > 0:
		return
	await FilmUI.wait_frames(ctx.tree, 2)
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false) \
			if ctx.main.sketch_chrome != null else null
	var chip := FilmUI.find_button(bar, "Circular") if bar != null else null
	if chip == null or not chip.is_visible_in_tree():
		chip = _by_auto(ctx.main, "variant:Circular") as BaseButton
	if chip == null or not chip.is_visible_in_tree():
		FilmUI._fail("Circular variant is hidden")
		return
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Circular", "circular variant")):
		return
	await _type_auto_spin(ctx, "pattern:Count", str(count))
	if FilmUI.fail_count > 0:
		return
	var ang := str(int(round(angle))) if is_equal_approx(angle, round(angle)) else str(angle)
	await _type_auto_spin(ctx, "pattern:Angle", ang)
	if FilmUI.fail_count > 0:
		return
	var ok := _by_auto(ctx.main, "pattern:Ok") as Button
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("pattern:Ok is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("Apply", "Pattern %d / %s" % [count, ang]))
	await FilmUI.wait_frames(ctx.tree, 2)


## Feature Mirror: arm Features, click the plane face, Shift+click timeline rows, Ok.
static func feature_mirror(ctx: FilmContext, plane_normal: Vector3, plane_offset: float, names: Array) -> void:
	await _release_line_focus(ctx)
	var arm := _by_auto(ctx.main, "mirror:Features") as BaseButton
	if arm == null or not arm.is_visible_in_tree():
		FilmUI._fail("mirror:Features is hidden")
		return
	if not await FilmUI.click_control(ctx, arm, FilmUICues.alert("Features", "Feature Mirror")):
		return
	await FilmUI.wait_frames(ctx.tree, 2)
	await _release_line_focus(ctx)
	await _view_for_normal(ctx, plane_normal)
	var body := only_body(ctx)
	var face_id := _face_on_plane(ctx, body, plane_normal, plane_offset)
	var aim := FacePick.point(ctx.view.doc, face_id)
	if aim == Vector3.ZERO:
		aim = plane_normal * plane_offset
	await SxInput.zoom(ctx, aim, 220.0)
	await click_face(ctx, plane_normal, plane_offset)
	if FilmUI.fail_count > 0:
		return
	for i in names.size():
		if FilmUI.fail_count > 0:
			return
		var name := str(names[i])
		var row := _by_auto(ctx.main, "timeline:row:%s" % name) as BaseButton
		if row == null or not row.is_visible_in_tree():
			FilmUI._fail("timeline:row:%s is hidden" % name)
			return
		FilmUI.ensure_control_visible(row)
		await FilmUI.wait_frames(ctx.tree, 1)
		if i == 0:
			if not await FilmUI.click_control(ctx, row, FilmUICues.alert("Click", "timeline row")):
				return
		else:
			await _shift_click_control(ctx, row)
		await FilmUI.wait_frames(ctx.tree, 1)
	var ok := _by_auto(ctx.main, "mirror:Ok") as Button
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("mirror:Ok is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Mirror OK"))
	await FilmUI.wait_frames(ctx.tree, 8)


static func open_side_face_sketch(ctx: FilmContext, normal: Vector3, view_key: Key, plane: float = INF) -> void:
	var body := only_body(ctx)
	if body == "":
		FilmUI._fail("side sketch needs one body")
		return
	await _release_line_focus(ctx)
	await SxInput.push_key(ctx.main.get_viewport(), view_key)
	await FilmUI.wait_frames(ctx.tree, 3)
	var face := FilmUI.find_face_by_normal(ctx.view, body, normal) if is_inf(plane) \
			else _face_on_plane(ctx, body, normal, plane)
	if face == "":
		FilmUI._fail("no face for normal %s" % str(normal))
		return
	var pt := FilmUI.face_pick_point(ctx.view, body, face)
	if not is_inf(plane):
		var on_face := FacePick.point(ctx.view.doc, face)
		if on_face != Vector3.ZERO:
			pt = on_face
	if pt == Vector3.INF:
		FilmUI._fail("no pick point for the side face")
		return
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.require_on_screen(ctx, screen, "side face"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Side face"))
	await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Side face"))
		await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face:
		FilmUI._fail("side face not selected")
		return
	await SxInput.push_key(ctx.main.get_viewport(), view_key)
	await FilmUI.wait_frames(ctx.tree, 2)
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Sketch") if strip != null else null
	if chip == null or not chip.is_visible_in_tree():
		FilmUI._fail("Sketch chip is hidden")
		return
	await FilmUI.click_control(ctx, chip, FilmUICues.toolbar_sketch())
	await FilmUI.wait_frames(ctx.tree, 4)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("side-face sketch did not start")


static func convert_edge(ctx: FilmContext, world: Vector3) -> void:
	await press_rail(ctx, "Convert")
	if FilmUI.fail_count > 0:
		return
	await SxInput.zoom(ctx, world, 140.0)
	var screen := FilmUI.model_to_screen(ctx, world)
	if not FilmUI.require_on_screen(ctx, screen, "Convert edge"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click("Convert edge"))
	await FilmUI.wait_frames(ctx.tree, 3)


static func _by_auto(root: Node, id: String) -> Control:
	if root == null:
		return null
	for c in root.find_children("*", "Control", true, false):
		if str(c.get_meta("sx_auto", "")) == id:
			return c as Control
	return null


static func _face_from_row(ctx: FilmContext, row: Dictionary, shift: bool) -> void:
	await _release_line_focus(ctx)
	var key: Key = row.get("view_key", row.get("view", KEY_7)) as Key
	await SxInput.push_key(ctx.main.get_viewport(), key)
	await FilmUI.wait_frames(ctx.tree, 6)
	var n: Vector3 = row["normal"] as Vector3
	var plane := float(row["plane"])
	await SxInput.zoom(ctx, n * plane, 220.0)
	if shift:
		await shift_click_face(ctx, n, plane)
	else:
		await click_face(ctx, n, plane)


static func _view_for_normal(ctx: FilmContext, normal: Vector3) -> void:
	await _release_line_focus(ctx)
	var key := KEY_7
	if normal.dot(Vector3(0, 0, 1)) > 0.9:
		key = KEY_3
	elif normal.dot(Vector3(0, 0, -1)) > 0.9:
		key = KEY_8
	await SxInput.push_key(ctx.main.get_viewport(), key)
	await FilmUI.wait_frames(ctx.tree, 6)


static func _type_auto_spin(ctx: FilmContext, auto_id: String, text: String) -> void:
	var node := _by_auto(ctx.main, auto_id)
	var edit: LineEdit = (node as SpinBox).get_line_edit() if node is SpinBox else node as LineEdit
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("%s is hidden" % auto_id)
		return
	await SxInput.x11_click(edit)
	edit.select_all()
	await SxInput.type_text(edit.get_viewport(), text)
	await FilmUI.wait_frames(ctx.tree, 1)


static func _shift_click_control(ctx: FilmContext, button: BaseButton) -> void:
	var ke := InputEventKey.new()
	ke.keycode = KEY_SHIFT
	ke.physical_keycode = KEY_SHIFT
	ke.pressed = true
	ke.shift_pressed = true
	Input.parse_input_event(ke)
	await FilmUI.wait_frames(ctx.tree, 1)
	if not await FilmUI.click_control(ctx, button, FilmUICues.alert("Shift+Click", "timeline row")):
		ke.pressed = false
		ke.shift_pressed = false
		Input.parse_input_event(ke)
		return
	ke.pressed = false
	ke.shift_pressed = false
	Input.parse_input_event(ke)


static func _release_line_focus(ctx: FilmContext) -> void:
	var owner: Node = ctx.main.get_viewport().gui_get_focus_owner()
	if owner is LineEdit:
		await SxInput.push_key(ctx.main.get_viewport(), KEY_TAB)


## Centre-rectangle: rail Rect, variant Center, centre click, corner click.
static func centre_rect(ctx: FilmContext, centre: Vector2, corner: Vector2) -> void:
	await press_rail(ctx, "Rect")
	if FilmUI.fail_count > 0:
		return
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false) if ctx.main.sketch_chrome != null else null
	var chip := FilmUI.find_button(bar, "Center") if bar != null else null
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center", "Center")):
		return
	await click_uv(ctx, centre, "Rectangle centre", 220.0)
	await click_uv(ctx, corner, "Rectangle corner", 220.0)


## Offset Entities: distance, Reverse, rim click, Apply.
static func offset_rim(ctx: FilmContext, distance: String, uv: Vector2) -> void:
	await press_rail(ctx, "Offset")
	if FilmUI.fail_count > 0:
		return
	await FilmUI.wait_frames(ctx.tree, 2)
	await _type_offset_distance(ctx, distance)
	if FilmUI.fail_count > 0:
		return
	var rev := _by_auto(ctx.main, "offset:Reverse") as BaseButton
	if rev == null or not rev.is_visible_in_tree():
		FilmUI._fail("offset:Reverse is hidden")
		return
	if not rev.button_pressed:
		if not await FilmUI.click_control(ctx, rev, FilmUICues.alert("Reverse", "Offset inward")):
			return
	await click_uv(ctx, uv, "Offset rim", 140.0)
	var ok := _by_auto(ctx.main, "offset:Ok") as Button
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("offset:Ok is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("Apply", "Offset Apply"))
	await FilmUI.wait_frames(ctx.tree, 2)


## Shift+click a face. The face is the one on `plane` along `normal`.
static func shift_click_face(ctx: FilmContext, normal: Vector3, plane: float) -> void:
	await _click_face(ctx, normal, plane, true)


## Plain click of the face on `plane` along `normal`.
static func click_face(ctx: FilmContext, normal: Vector3, plane: float) -> void:
	await _click_face(ctx, normal, plane, false)


## Rows are FilletPick.CORNERS: x, y, view. z_mid is the click height on that vertical.
static func pick_corner_table(ctx: FilmContext, rows: Array, z_mid: float) -> void:
	await _release_line_focus(ctx)
	for row in rows:
		if FilmUI.fail_count > 0:
			return
		await _release_line_focus(ctx)
		await SxInput.push_key(ctx.main.get_viewport(), row["view"] as Key)
		await FilmUI.wait_frames(ctx.tree, 8)
		var pt := Vector3(float(row["x"]), float(row["y"]), z_mid)
		await SxInput.zoom(ctx, pt, 80.0)
		var screen := FilmUI.model_to_screen(ctx, pt)
		if not FilmUI.require_on_screen(ctx, screen, "corner edge"):
			return
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Corner edge"))
		await FilmUI.wait_frames(ctx.tree, 2)


static func section_top(ctx: FilmContext) -> void:
	var btn := _by_auto(ctx.main, "hud:Section") as Button
	if not await FilmUI.click_control(ctx, btn, FilmUICues.alert("Section", "Section")):
		return
	await FilmUI.wait_frames(ctx.tree, 3)
	var popup := ctx.main.find_child("SectionPlanePopup", true, false) as PopupMenu
	if popup == null or not popup.visible:
		FilmUI._fail("Section plane popup is hidden")
		return
	if not await SxInput.click_popup_label(popup, "Top"):
		FilmUI._fail("popup:Top did not take the click")
		return
	await FilmUI.wait_frames(ctx.tree, 3)


static func section_off(ctx: FilmContext) -> void:
	var btn := _by_auto(ctx.main, "hud:Section") as Button
	if btn == null or not btn.is_visible_in_tree():
		FilmUI._fail("Section button is hidden")
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Section", "Section off"))
	await FilmUI.wait_frames(ctx.tree, 3)


static func _click_face(ctx: FilmContext, normal: Vector3, plane: float, shift: bool) -> void:
	var body := only_body(ctx)
	if body == "":
		FilmUI._fail("face click needs one body")
		return
	var id := _face_on_plane(ctx, body, normal, plane)
	if id == "":
		FilmUI._fail("no face on plane %s" % str(plane))
		return
	var pt := FacePick.point(ctx.view.doc, id)
	if pt == Vector3.ZERO:
		pt = FilmUI.face_pick_point(ctx.view, body, id)
	var bb: Dictionary = ctx.view.doc.measure_bbox(id)
	if not bb.is_empty() and Vector2(pt.x, pt.y).length() < 40.0:
		var mx: Vector3 = bb["max"] as Vector3
		pt = Vector3(mx.x * 0.65, mx.y * 0.35, pt.z)
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.require_on_screen(ctx, screen, "face"):
		return
	var cue := FilmUICues.alert("Shift+Click" if shift else "Click", "Face")
	await FilmUI.viewport_click(ctx, screen, cue, false, MOUSE_BUTTON_LEFT, shift)
	await FilmUI.wait_frames(ctx.tree, 2)
	# Fillet replaces the face with its loop. A second click would toggle one rim off.
	if shift or ctx.view.selected_face == id or not ctx.view.selected_edges.is_empty():
		return
	await FilmUI.viewport_click(ctx, screen, cue, false, MOUSE_BUTTON_LEFT, false)
	await FilmUI.wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != id:
		FilmUI._fail("face on plane %s not selected" % str(plane))


static func _face_on_plane(ctx: FilmContext, body: String, normal: Vector3, plane: float) -> String:
	var rows: Array = []
	for face in ctx.view.faces_matching(body, normal, FacePick.ALIGN):
		var id := str(face.get("id", ""))
		var pick := FacePick.point(ctx.view.doc, id)
		rows.append({
			"id": id,
			"normal": face.get("normal", normal),
			"centre": face.get("centre", pick),
			"pick": pick,
			"plane": FacePick.plane_offset(normal, pick),
		})
	return str(FacePick.match_normal(rows, normal, plane).get("id", ""))


static func _type_offset_distance(ctx: FilmContext, text: String) -> void:
	var node := _by_auto(ctx.main, "offset:Distance")
	var edit: LineEdit = (node as SpinBox).get_line_edit() if node is SpinBox else node as LineEdit
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("offset:Distance is hidden")
		return
	await SxInput.x11_click(edit)
	edit.select_all()
	await SxInput.type_text(edit.get_viewport(), text)
	await FilmUI.wait_frames(ctx.tree, 1)
