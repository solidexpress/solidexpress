# Rung 1 replan 3 WP5 — typed fillet radius on a plate+slot, closed 3MF.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan3_fillet.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan3 WP5 fillet")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan3_fillet.gd")
	check(not src.contains("graph_add_" + "fillet"), "test source does not call the graph fillet adder")
	check(not src.contains("text_submitted" + ".emit"), "test source does not emit submitted text")
	check(not src.contains("current_" + "path ="), "test source does not assign the dialog path")
	check(not src.contains("spin" + ".value =") and not src.contains("_strip_radius" + ".value ="),
			"test source does not assign the radius spin")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))

	await test_plate_slot_fillets(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_plate_slot_fillets(ctx: FilmContext) -> void:
	print("- plate + blind slot through the sketch UI")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	await _click_uv(ctx, Vector2(-20, -15), "Plate corner A")
	await _click_uv(ctx, Vector2(20, 15), "Plate corner B")
	await process_frame
	await _type_distance(ctx, "10")
	await _press_extrude(ctx, "Extrude plate Blind 10")
	await process_frame
	await process_frame
	var body := _first_body(ctx)
	check(body != "", "plate extrude created a body")
	if body == "":
		return
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)
		await process_frame
	check(ctx.main.sketch_mode == null or not ctx.main.sketch_mode.active,
			"plate extrude left sketch mode")
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var zmax := 0.0
	if bb.has("max"):
		zmax = float((bb["max"] as Vector3).z)
	check(absf(zmax - 10.0) <= 0.2, "plate thickness is 10 (zmax %s)" % str(zmax))

	print("- sketch a 20×10 slot on the top and cut Blind 2.5")
	await _sketch_on_top(ctx, body)
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5, "slot sketch on the top face")
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	await _click_uv(ctx, Vector2(-10, -5), "Slot corner A")
	await _click_uv(ctx, Vector2(10, 5), "Slot corner B")
	await process_frame
	await _pick_finish_op(ctx, 1, "Cut")
	await _type_distance(ctx, "2.5")
	await _press_extrude(ctx, "Cut slot blind 2.5")
	await process_frame
	await process_frame
	check(not ctx.main.sketch_mode.active, "slot cut left sketch mode")

	print("- fillet R1 on the top face via the selection strip")
	await _dismiss_property_panel(ctx)
	await _ensure_body_selected(ctx, body)
	var n0 := _count_type(ctx, "fillet")
	await _arm_fillet(ctx)
	await _type_strip_radius(ctx, "1")
	await _look_along(ctx, Vector3(0, 0, 1), Vector3(15, 0, 10), 80.0)
	await _click_model(ctx, Vector3(15, 0, 10), "Top face")
	check(ctx.view.selected_edges.size() >= 4,
			"top face click selected face edges (got %d)" % ctx.view.selected_edges.size())
	await _commit_strip_radius(ctx)
	await process_frame
	await process_frame
	check(_count_type(ctx, "fillet") == n0 + 1, "one fillet feature on the top face")
	check(ctx.view.doc.last_graph_error() == "",
			"R1 top last_graph_error empty (%s)" % ctx.view.doc.last_graph_error())
	check(not str(ctx.view.doc.last_graph_error()).contains("1.250"),
			"R1 top does not report limit 1.250")

	print("- fillet R1.5 on the slot floor is refused")
	await _dismiss_property_panel(ctx)
	await _ensure_body_selected(ctx, body)
	var vol0: float = ctx.view.doc.body_volume(body)
	var n1 := _count_type(ctx, "fillet")
	await _arm_fillet(ctx)
	await _type_strip_radius(ctx, "1.5")
	await _look_along(ctx, Vector3(0, 0, 1), Vector3(0, 0, 7.5), 80.0)
	await _click_model(ctx, Vector3(0, 0, 7.5), "Slot floor")
	await _commit_strip_radius(ctx)
	await process_frame
	await process_frame
	var err := str(ctx.view.doc.last_graph_error())
	check(_count_type(ctx, "fillet") == n1, "R1.5 adds no fillet feature")
	check(err.contains("1.25"), "R1.5 error contains 1.25 (got '%s')" % err)
	check(absf(ctx.view.doc.body_volume(body) - vol0) < 1e-3, "body unchanged after refused R1.5")

	print("- fillet R1 on the slot floor succeeds")
	await _dismiss_property_panel(ctx)
	await _ensure_body_selected(ctx, body)
	await _arm_fillet(ctx)
	await _type_strip_radius(ctx, "1")
	await _look_along(ctx, Vector3(0, 0, 1), Vector3(0, 0, 7.5), 80.0)
	await _click_model(ctx, Vector3(0, 0, 7.5), "Slot floor R1")
	await _commit_strip_radius(ctx)
	await process_frame
	await process_frame
	check(_count_type(ctx, "fillet") == n1 + 1, "R1 slot floor adds a fillet")
	check(ctx.view.doc.last_graph_error() == "",
			"R1 floor last_graph_error empty (%s)" % ctx.view.doc.last_graph_error())

	print("- export 3MF through the FileDialog; mesh has 0 bad edges")
	var dest := ProjectSettings.globalize_path("user://rung01_replan3_fillet/plate.3mf")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	var path := await _export_via_dialog(ctx, dest)
	check(path != "" and FileAccess.file_exists(path), "exported plate 3MF through the dialog")
	if path != "" and FileAccess.file_exists(path):
		var bad := _manifold_bad_edges(path)
		check(bad == 0, "exported 3MF has 0 bad edges (got %d)" % bad)


func _first_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return str(ids[0])


func _count_type(ctx: FilmContext, type: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == type:
			n += 1
	return n


func _face_at(ctx: FilmContext, body: String, z_want: float) -> String:
	var best := ""
	var best_d := 1e30
	for fid in ctx.view.doc.get_face_ids(body):
		var mid: Vector3 = ctx.view.doc.face_midpoint(fid)
		var d := absf(mid.z - z_want)
		if d < best_d:
			best_d = d
			best = str(fid)
	return best if best_d < 1.0 else ""


func _sketch_on_top(ctx: FilmContext, body: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
		await process_frame
	var top := _face_at(ctx, body, 10.0)
	check(top != "", "top face exists for the slot sketch")
	if top == "":
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	await process_frame
	await process_frame


func _dismiss_property_panel(ctx: FilmContext) -> void:
	if ctx.main.has_method("cancel_property_panel"):
		ctx.main.cancel_property_panel()
	await process_frame


func _ensure_body_selected(ctx: FilmContext, body: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
		await process_frame
	await _dismiss_property_panel(ctx)
	if ctx.view.selected_body == body and ctx.main.interaction._selection_strip != null \
			and ctx.main.interaction._selection_strip.visible \
			and ctx.main.interaction._strip_fillet != null \
			and ctx.main.interaction._strip_fillet.is_visible_in_tree():
		return
	await _look_along(ctx, Vector3(0, 1, 0), Vector3(0, 15, 5), 80.0)
	await _click_model(ctx, Vector3(0, 15, 5), "Select plate")
	ctx.main.interaction._refresh_selection_strip()
	await process_frame
	check(ctx.view.selected_body == body, "plate is selected for fillet")


func _arm_fillet(ctx: FilmContext) -> void:
	var btn: Button = ctx.main.interaction._strip_fillet
	check(btn != null and btn.is_visible_in_tree(), "selection strip Fillet is visible")
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Fillet", "Arm fillet"))
	await process_frame
	var spin: SpinBox = ctx.main.interaction._strip_radius
	check(spin != null and spin.is_visible_in_tree(), "fillet radius blank visible")


func _type_strip_radius(ctx: FilmContext, digits: String) -> void:
	var spin: SpinBox = ctx.main.interaction._strip_radius
	check(spin != null and spin.is_visible_in_tree(), "radius spin is visible for typing %s" % digits)
	if spin == null:
		return
	var edit: LineEdit = spin.get_line_edit()
	edit.grab_focus()
	await process_frame
	await _ctrl_a(edit.get_viewport())
	await process_frame
	var sel := edit.get_selected_text()
	check(sel != "" and sel == edit.text,
			"radius field is selected (sel '%s' text '%s')" % [sel, edit.text])
	await _type_text(edit.get_viewport(), digits)
	await process_frame
	var shown := edit.text.strip_edges()
	check(shown == digits or shown.begins_with(digits + ".") or shown.begins_with(digits + " "),
			"typed radius %s is in the spin (got '%s')" % [digits, edit.text])


func _commit_strip_radius(ctx: FilmContext) -> void:
	var spin: SpinBox = ctx.main.interaction._strip_radius
	check(spin != null and spin.is_visible_in_tree(), "radius spin is visible for Enter")
	if spin == null:
		return
	var edit: LineEdit = spin.get_line_edit()
	edit.grab_focus()
	await process_frame
	await _ctrl_a(edit.get_viewport())
	await process_frame
	await _push_key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame


func _type_distance(ctx: FilmContext, text: String) -> void:
	var edit: LineEdit = ctx.main.sketch_chrome._extrude_spin.get_line_edit()
	await _click_control(edit)
	await _click_control(edit)
	var sel := edit.get_selected_text()
	check(sel != "" and sel == edit.text,
			"second Distance click selects the field (sel '%s' text '%s')" % [sel, edit.text])
	await _type_text(edit.get_viewport(), text)
	await process_frame


func _press_extrude(ctx: FilmContext, desc: String) -> void:
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Extrude", desc))
	await process_frame
	await process_frame
	await process_frame


func _pick_finish_op(ctx: FilmContext, index: int, desc: String) -> void:
	var opt: OptionButton = ctx.main.sketch_chrome.find_child("FinishOp", true, false)
	check(opt != null and opt.is_visible_in_tree(), "FinishOp is visible for %s" % desc)
	if opt == null:
		return
	await _click_control(opt)
	opt.show_popup()
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = opt.get_popup()
	check(popup != null and popup.visible, "FinishOp popup is visible for %s" % desc)
	if popup == null:
		return
	var id := popup.get_item_id(index)
	var clicked: bool = await _click_popup_item(popup, id, desc)
	check(clicked, "FinishOp %s was clicked" % desc)
	await process_frame


func _export_via_dialog(ctx: FilmContext, dest: String) -> String:
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF")
	await process_frame
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "Export 3MF opens a FileDialog")
	if dlg == null or not dlg.visible:
		return ""
	for _i in 4:
		await process_frame
	var edit: LineEdit = null
	if dlg.has_method("get_line_edit"):
		edit = dlg.get_line_edit()
	if edit == null:
		for c in dlg.find_children("*", "LineEdit", true, false):
			edit = c as LineEdit
			if edit != null:
				break
	check(edit != null, "Export 3MF name LineEdit exists")
	if edit == null:
		return ""
	var selected := edit.get_selected_text()
	check(selected != "" and selected == edit.text,
			"name field selection is the entire suggested name (sel '%s' text '%s')" % [selected, edit.text])
	edit.grab_focus()
	await process_frame
	await _type_text(edit.get_viewport(), dest)
	await process_frame
	var ok_btn := dlg.get_ok_button()
	var confirmed: bool = await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("Save", "Confirm 3MF"))
	await process_frame
	await process_frame
	check(confirmed, "export dialog OK was pressed")
	if dlg.visible:
		dlg.hide()
	return dest if FileAccess.file_exists(dest) else ""


func _click_file_item(ctx: FilmContext, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, "File")
	if btn == null or not btn.is_visible_in_tree():
		check(false, "File menu button is visible for %s" % desc)
		return false
	if not await FilmUI.click_control(ctx, btn, {"keys": "Click", "desc": "File menu"}):
		return false
	btn.show_popup()
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = btn.get_popup()
	if popup == null or not popup.visible:
		check(false, "File popup is visible after File click (%s)" % desc)
		return false
	return await _click_popup_item(popup, id, desc)


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


func _item_screen_center(popup: PopupMenu, index: int) -> Vector2:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		y += _popup_row_height(popup, i, font_h, v_sep)
	y += _popup_row_height(popup, index, font_h, v_sep) * 0.5
	return Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)


func _click_popup_item(popup: PopupMenu, id: int, desc: String) -> bool:
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "popup has item id %d (%s)" % [id, desc])
		return false
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(idx)
	popup.reset_size()
	await process_frame
	var screen: Vector2 = _item_screen_center(popup, idx)
	var got: Array = [-1]
	var cb := func(pressed_id: int) -> void:
		got[0] = pressed_id
	popup.id_pressed.connect(cb)
	await _click_at(root.get_viewport(), screen)
	await process_frame
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	return got[0] == id


func _look_along(ctx: FilmContext, from_side: Vector3, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var n := from_side.normalized()
	cam.sketch_orientation_locked = false
	cam._sketch_view_up = Vector3.UP
	cam.yaw = atan2(n.x, -n.y)
	cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
	cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, sm.to_model(uv), size_mm)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen)


func _click_model(ctx: FilmContext, pt: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, pt)
	check(FilmUI.require_on_screen(ctx, screen, desc), "model click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen)
	await process_frame


func _aim_pointer(ctx: FilmContext, screen: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


func _pointer_click(ctx: FilmContext, pos: Vector2) -> void:
	await _click_at(ctx.main.get_viewport(), pos)


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _push_mouse(vp, pos, true)
	await _push_mouse(vp, pos, false)


func _push_mouse(vp: Viewport, pos: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)
	await process_frame


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
	await _click_at(ctrl.get_viewport(), pos)
	await process_frame


func _ctrl_a(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.physical_keycode = KEY_A
	ev.unicode = 0
	ev.ctrl_pressed = true
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = KEY_A
	rel.physical_keycode = KEY_A
	rel.unicode = 0
	rel.ctrl_pressed = true
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		await _push_key(vp, _keycode_for_char(ch), ch.unicode_at(0))


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.unicode = unicode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _keycode_for_char(ch: String) -> Key:
	var c := ch.unicode_at(0)
	if ch == ".":
		return KEY_PERIOD
	if ch == "-":
		return KEY_MINUS
	if ch == "/":
		return KEY_SLASH
	if ch == "\\":
		return KEY_BACKSLASH
	if ch == "_":
		return KEY_UNDERSCORE
	if c >= 48 and c <= 57:
		return (KEY_0 + (c - 48)) as Key
	if c >= 97 and c <= 122:
		return (KEY_A + (c - 97)) as Key
	if c >= 65 and c <= 90:
		return (KEY_A + (c - 65)) as Key
	return KEY_NONE


func _manifold_bad_edges(path: String) -> int:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return -1
	var raw: PackedByteArray = zip.read_file("3D/3dmodel.model")
	zip.close()
	var xml := raw.get_string_from_utf8()
	var verts: Array[Vector3] = []
	var pos := 0
	while true:
		var i := xml.find("<vertex ", pos)
		if i < 0:
			break
		verts.append(Vector3(_xml_attr(xml, i, "x"), _xml_attr(xml, i, "y"), _xml_attr(xml, i, "z")))
		pos = i + 8
	var weld := {}
	var remap: Array[int] = []
	var next_id := 0
	for v in verts:
		var key := Vector3i(int(round(v.x * 1e6)), int(round(v.y * 1e6)), int(round(v.z * 1e6)))
		if not weld.has(key):
			weld[key] = next_id
			next_id += 1
		remap.append(int(weld[key]))
	var edges := {}
	pos = 0
	while true:
		var i := xml.find("<triangle ", pos)
		if i < 0:
			break
		var a := int(_xml_attr(xml, i, "v1"))
		var b := int(_xml_attr(xml, i, "v2"))
		var c := int(_xml_attr(xml, i, "v3"))
		if a >= 0 and b >= 0 and c >= 0 and a < remap.size() and b < remap.size() and c < remap.size():
			var ia := remap[a]
			var ib := remap[b]
			var ic := remap[c]
			if ia != ib and ib != ic and ia != ic:
				_bump_edge(edges, ia, ib)
				_bump_edge(edges, ib, ic)
				_bump_edge(edges, ic, ia)
		pos = i + 10
	var bad := 0
	for k in edges.keys():
		if int(edges[k]) != 2:
			bad += 1
	return bad


func _xml_attr(xml: String, from: int, name: String) -> float:
	var key := name + "=\""
	var i := xml.find(key, from)
	if i < 0:
		return 0.0
	i += key.length()
	var j := xml.find("\"", i)
	if j < 0:
		return 0.0
	return float(xml.substr(i, j - i))


func _bump_edge(edges: Dictionary, a: int, b: int) -> void:
	var u := mini(a, b)
	var v := maxi(a, b)
	var key := "%d %d" % [u, v]
	edges[key] = int(edges.get(key, 0)) + 1
