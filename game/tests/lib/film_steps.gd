## Click-only steps shared by UI films.
## Calls FilmUI and SxInput; a missing control fails through FilmUI._fail.
class_name FilmSteps
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")
const _FilmActorBoot = preload("res://tests/lib/film_actor.gd")

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
		await FilmActor.of(ctx).zoom_to(sm.to_model(uv), span, "Zoom %s" % desc)
	var screen := FilmUI.sketch_uv_to_screen(ctx, uv)
	if screen == Vector2.ZERO:
		screen = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	if not FilmUI.require_on_screen(ctx, screen, desc):
		return
	await FilmActor.of(ctx).tap_x11(screen, FilmUICues.alert("Click", desc))


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
	await FilmActor.of(ctx).edit_field(edit, text, "Dimension %s" % text)


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
	await FilmActor.of(ctx).edit_field(edit, text, "Distance %s" % text)


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
	await FilmActor.of(ctx).press(opt, FilmUICues.alert("Click", desc))
	opt.show_popup()
	await FilmUI.wait_frames(ctx.tree, 4)
	var popup: PopupMenu = opt.get_popup()
	if popup == null or not popup.visible:
		FilmUI._fail("%s popup not visible" % desc)
		return
	await FilmActor.of(ctx).pick_popup_row(popup, index, FilmUICues.alert("Click", "%s item" % desc))


static func select_body(ctx: FilmContext, body: String) -> void:
	await FilmActor.of(ctx).view_key(KEY_4, "Back view")
	await FilmActor.of(ctx).dwell()
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
	var digits := str(int(round(radius))) if is_equal_approx(radius, round(radius)) else str(radius)
	await FilmActor.of(ctx).edit_field(spin, digits, "Fillet r=%s" % digits)
	await _release_line_focus(ctx)
	await FilmActor.of(ctx).dwell()


static func commit_fillet(ctx: FilmContext) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 4)


static func fillet_at(ctx: FilmContext, body: String, point: Vector3, radius: float, view_key: Key) -> void:
	await arm_fillet(ctx, radius)
	await FilmActor.of(ctx).view_key(view_key)
	await FilmActor.of(ctx).dwell()
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
	await FilmActor.of(ctx).dwell()
	var dlg: FileDialog = ctx.main.file_dialog
	if dlg == null or not dlg.visible:
		FilmUI._fail("Export 3MF dialog did not open")
		return
	var dest := "/tmp/sx-film-ubc-wrench.3mf"
	var name_edit := _file_dialog_name_edit(dlg)
	if name_edit == null:
		FilmUI._fail("export filename field missing")
		return
	await FilmActor.of(ctx).edit_field(name_edit, dest, "Export path")
	# Enter in the filename field often confirms the dialog; click Save if it stays up.
	if dlg.visible:
		var ok_btn := dlg.get_ok_button()
		if ok_btn == null or not ok_btn.is_visible_in_tree():
			FilmUI._fail("export OK missing")
			return
		await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("Save", "Export 3MF"))
	await FilmActor.of(ctx).result_pause()
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
		await FilmActor.of(ctx).view_key(spec["key"] as Key)
		var world := Vector3(x, y, mid_z)
		await FilmActor.of(ctx).zoom_to(world, 70.0, "Frame corner")
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
	await FilmActor.of(ctx).edit_field(field, digits, "Shell %s mm" % digits)
	await _release_line_focus(ctx)
	await FilmUI.wait_frames(ctx.tree, 2)
	var ok := _by_auto(ctx.main, "finish:Ok") as Button
	if ok != null and ok.is_visible_in_tree():
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


## Feature Mirror: origin Front / Top / Right while the collector is waiting.
## Named datum matches the walk (`click(datum=Front)`); Front sits inside a
## mid-plane solid so a body-face ray is the wrong plane.
static func click_mirror_datum(ctx: FilmContext, name: String) -> void:
	await _release_line_focus(ctx)
	var ops = ctx.main.ops_panel if ctx.main != null else null
	if ops != null and ops.has_method("try_mirror_datum") and bool(ops.try_mirror_datum(name)):
		await FilmUI.wait_frames(ctx.tree, 2)
		return
	FilmUI._fail("origin plane %s was not accepted as the mirror plane" % name)


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
	await FilmActor.of(ctx).zoom_to(aim, 220.0, "Frame mirror plane")
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
	await FilmActor.of(ctx).view_key(view_key)
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
	await FilmActor.of(ctx).view_key(view_key)
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
	await FilmActor.of(ctx).zoom_to(world, 140.0, "Frame convert edge")
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
	await FilmActor.of(ctx).view_key(key)
	var n: Vector3 = row["normal"] as Vector3
	var plane := float(row["plane"])
	await FilmActor.of(ctx).zoom_to(n * plane, 220.0, "Frame face")
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
	await FilmActor.of(ctx).view_key(key)


static func _type_auto_spin(ctx: FilmContext, auto_id: String, text: String) -> void:
	var node := _by_auto(ctx.main, auto_id)
	var edit: LineEdit = (node as SpinBox).get_line_edit() if node is SpinBox else node as LineEdit
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("%s is hidden" % auto_id)
		return
	await SxInput.x11_click(edit)
	edit.select_all()
	await SxInput.type_text(edit.get_viewport(), text)
	await _release_line_focus(ctx)


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
		await FilmActor.of(ctx).view_key(row["view"] as Key)
		var pt := Vector3(float(row["x"]), float(row["y"]), z_mid)
		await FilmActor.of(ctx).zoom_to(pt, 80.0, "Frame corner")
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
	if not await FilmActor.of(ctx).pick_popup_label(popup, "Top", FilmUICues.alert("Top", "Section plane Top")):
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
	var cue := FilmUICues.alert("Shift+Click" if shift else "Click", "Face")
	if await _click_face_at(ctx, pt, cue, shift, id):
		return
	# Annulus centroid sits in the hole; FacePick.point then misses. Outer rim is meat.
	var bb: Dictionary = ctx.view.doc.measure_bbox(id)
	if not bb.is_empty():
		var mx: Vector3 = bb["max"] as Vector3
		var rim := Vector3(mx.x * 0.92, 0.0, pt.z)
		if await _click_face_at(ctx, rim, cue, shift, id):
			return
	FilmUI._fail("face on plane %s not selected" % str(plane))


static func _click_face_at(ctx: FilmContext, pt: Vector3, cue: Dictionary, shift: bool, id: String) -> bool:
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.is_on_screen(ctx, screen):
		return false
	await FilmUI.viewport_click(ctx, screen, cue, false, MOUSE_BUTTON_LEFT, shift)
	await FilmUI.wait_frames(ctx.tree, 2)
	# Fillet replaces the face with its loop. A second click would toggle one rim off.
	if shift or ctx.view.selected_face == id or not ctx.view.selected_edges.is_empty():
		return true
	await FilmUI.viewport_click(ctx, screen, cue, false, MOUSE_BUTTON_LEFT, false)
	await FilmUI.wait_frames(ctx.tree, 2)
	return ctx.view.selected_face == id or not ctx.view.selected_edges.is_empty()


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


static func _file_dialog_name_edit(dlg: FileDialog) -> LineEdit:
	if dlg == null:
		return null
	var best: LineEdit = null
	var best_w := 0.0
	if dlg.has_method("get_line_edit"):
		var le: Variant = dlg.get_line_edit()
		if le is LineEdit and (le as LineEdit).is_visible_in_tree():
			best = le as LineEdit
			best_w = best.get_global_rect().size.x
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit == null or not edit.is_visible_in_tree():
			continue
		var w := edit.get_global_rect().size.x
		if w > best_w:
			best_w = w
			best = edit
	return best


static func _type_offset_distance(ctx: FilmContext, text: String) -> void:
	var node := _by_auto(ctx.main, "offset:Distance")
	var edit: LineEdit = (node as SpinBox).get_line_edit() if node is SpinBox else node as LineEdit
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("offset:Distance is hidden")
		return
	await FilmActor.of(ctx).edit_field(edit, text, "Offset %s" % text)


## Click the visible VariantBar chip (`Tangent`, `Three Point`, …) or sx_auto
## `variant:<id>`. Hidden → FilmUI._fail.
static func pick_variant(ctx: FilmContext, label: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var bar: Node = chrome.find_child("VariantBar", true, false) if chrome != null else null
	var chip := FilmUI.find_button(bar, label) if bar != null else null
	if chip == null or not chip.is_visible_in_tree():
		chip = _by_auto(ctx.main, "variant:%s" % label) as BaseButton
	if chip == null or not chip.is_visible_in_tree():
		FilmUI._fail("%s variant is hidden" % label)
		return
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert(label, "%s variant" % label)):
		return
	await FilmUI.wait_frames(ctx.tree, 1)


## Rail Arc, variant Tangent, click start (host endpoint), click end.
## Snap-off for the end click if the Snap rail button is visible.
static func tangent_arc(ctx: FilmContext, start: Vector2, endp: Vector2, span: float = 280.0) -> void:
	await press_rail(ctx, "Arc")
	if FilmUI.fail_count > 0:
		return
	await pick_variant(ctx, "Tangent")
	if FilmUI.fail_count > 0:
		return
	await click_uv(ctx, start, "Tangent start", span)
	await _snap_off_if_visible(ctx)
	await click_uv(ctx, endp, "Tangent end", span)
	await FilmUI.wait_frames(ctx.tree, 1)


## Rail Arc, variant Three Point, three clicks.
static func three_point_arc(ctx: FilmContext, p1: Vector2, bulge: Vector2, p3: Vector2,
		span: float = 280.0) -> void:
	await press_rail(ctx, "Arc")
	if FilmUI.fail_count > 0:
		return
	await pick_variant(ctx, "Three Point")
	if FilmUI.fail_count > 0:
		return
	await click_uv(ctx, p1, "3-point start", span)
	await click_uv(ctx, bulge, "3-point bulge", span)
	await click_uv(ctx, p3, "3-point end", span)
	await FilmUI.wait_frames(ctx.tree, 1)


## Rail Ellipse, three clicks (centre, major, minor). Uses FilmUI.draw_ellipse.
static func ellipse3(ctx: FilmContext, centre: Vector2, major: Vector2, minor: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null:
		FilmUI._fail("sketch missing for ellipse")
		return
	var corner := Vector2(major.x, minor.y)
	await FilmUI.draw_ellipse(ctx, sm, centre, corner)


## Swept Boss: sweep:Boss (or visible control), profile pad, path pad, sweep:Ok.
static func swept_boss(ctx: FilmContext, profile_fid: String, path_fid: String) -> void:
	if ctx.view != null:
		ctx.view.clear_selection()
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await ctx.tree.process_frame
	var boss := ctx.main.find_child("SweepBoss", true, false) as BaseButton
	if boss == null or not boss.is_visible_in_tree():
		boss = _by_auto(ctx.main, "sweep:Boss") as BaseButton
	if boss == null or not boss.is_visible_in_tree():
		FilmUI._fail("Swept Boss is hidden")
		return
	if not await FilmUI.click_control(ctx, boss, FilmUICues.alert("Click", "Swept Boss")):
		return
	await ctx.tree.process_frame
	var prof := ctx.main.find_child("SweepProfile", true, false) as BaseButton
	if prof != null and prof.is_visible_in_tree():
		await FilmUI.click_control(ctx, prof, FilmUICues.alert("Click", "Sweep profile"))
		await ctx.tree.process_frame
	await _pick_timeline_row(ctx, profile_fid, "profile sketch")
	if FilmUI.fail_count > 0:
		return
	var path_btn := ctx.main.find_child("SweepPathPick", true, false) as BaseButton
	if path_btn != null and path_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, path_btn, FilmUICues.alert("Click", "Sweep path"))
		await ctx.tree.process_frame
	await _pick_timeline_row(ctx, path_fid, "path sketch")
	if FilmUI.fail_count > 0:
		return
	var ok := ctx.main.find_child("SweepOk", true, false) as BaseButton
	if ok == null or not ok.is_visible_in_tree():
		ok = _by_auto(ctx.main, "sweep:Ok") as BaseButton
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("sweep:Ok is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("Click", "Sweep OK"))
	await ctx.tree.process_frame
	await ctx.tree.process_frame
	if not _feature_types(ctx).has("sweep"):
		FilmUI._fail("Swept Boss did not add a sweep")


## Finish Op Cut, End Blind, Distance, Draft On, DraftAngle, Extrude.
static func draft_cut(ctx: FilmContext, distance: float, angle: float) -> void:
	await pick_finish(ctx, 1, 0)
	if FilmUI.fail_count > 0:
		return
	var dist := str(int(round(distance))) if is_equal_approx(distance, round(distance)) else str(distance)
	await type_distance(ctx, dist)
	if FilmUI.fail_count > 0:
		return
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var draft := chrome.find_child("DraftToggle", true, false) as BaseButton if chrome != null else null
	if draft == null or not draft.is_visible_in_tree():
		draft = _by_auto(ctx.main, "finish:Draft") as BaseButton
	if draft == null or not draft.is_visible_in_tree():
		FilmUI._fail("finish:Draft is hidden")
		return
	# CheckButton: FilmActor.press toggles twice (button_pressed + pressed.emit).
	# A real X11 click toggles once, like WalkUI06.try_extrude_cut.
	for _i in 3:
		var spin := chrome.find_child("DraftAngleSpin", true, false) as SpinBox if chrome != null else null
		if draft.button_pressed and spin != null and spin.is_visible_in_tree():
			break
		var center := FilmUI.control_screen_center(draft)
		if not await FilmActor.of(ctx).aim(center, FilmUICues.alert("Draft", "Draft On")):
			return
		await SxInput.x11_click(draft)
		await FilmUI.wait_frames(ctx.tree, 4)
	var spinbox := chrome.find_child("DraftAngleSpin", true, false) as SpinBox if chrome != null else null
	var edit: LineEdit = spinbox.get_line_edit() if spinbox != null else null
	if edit == null or not edit.is_visible_in_tree():
		FilmUI._fail("finish:DraftAngle is hidden")
		return
	var ang := str(int(round(angle))) if is_equal_approx(angle, round(angle)) else str(angle)
	await FilmActor.of(ctx).edit_field(edit, ang, "Draft %s°" % ang)
	if FilmUI.fail_count > 0:
		return
	var ex := _by_auto(ctx.main, "finish:Extrude") as Button
	if ex == null or not ex.is_visible_in_tree():
		ex = chrome.extrude_button() if chrome != null else null
	if ex == null or not ex.is_visible_in_tree():
		FilmUI._fail("finish:Extrude is hidden")
		return
	if not await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Extrude")):
		return
	await ctx.after_regen()


static func _feature_types(ctx: FilmContext) -> PackedStringArray:
	var out := PackedStringArray()
	if ctx.view == null or ctx.view.doc == null:
		return out
	for f in ctx.view.doc.graph_features():
		out.append(str(f.get("type", "")))
	return out


static func _snap_off_if_visible(ctx: FilmContext) -> void:
	var snap := _by_auto(ctx.main, "rail:Snap") as BaseButton
	if snap == null or not snap.is_visible_in_tree():
		snap = ctx.main.find_child("SnapToggle", true, false) as BaseButton
	if snap == null or not snap.is_visible_in_tree():
		return
	if snap.button_pressed:
		await FilmUI.click_control(ctx, snap, FilmUICues.alert("Snap", "Snap off"))


static func _pick_timeline_row(ctx: FilmContext, fid: String, desc: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await ctx.tree.process_frame
	var row: Control = tl._rows.get(fid)
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str(child.text) != "":
				btn = child as Button
				break
	if btn == null or not btn.is_visible_in_tree():
		FilmUI._fail("timeline row for %s is hidden" % desc)
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Click", desc))
	await ctx.tree.process_frame
