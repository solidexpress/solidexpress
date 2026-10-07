# Rung 1 replan 3 WP6 — rail Extrude distance gate and absolute export path.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan3_shell.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0


func check(c: bool, w: String) -> void:
	checks += 1
	if c:
		print("  ok   - " + w)
	else:
		failures += 1
		printerr("  FAIL - " + w)


func _init() -> void:
	print("rung01 replan3 shell (WP6)")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan3_shell.gd")
	var ban_input := "interaction." + "_input"
	var ban_id := "id_pressed" + ".emit"
	var ban_submit := "text_submitted" + ".emit"
	var ban_dist := "set_extrude" + "_distance"
	var ban_face := "set_up_to" + "_face"
	var ban_export := "export_3mf" + "("
	var ban_path := "current_path" + " ="
	check(not src.contains(ban_input), "test source has no interaction input call")
	check(not src.contains(ban_id), "test source has no menu id emit")
	check(not src.contains(ban_submit), "test source has no text_submitted emit")
	check(not src.contains(ban_dist), "test source has no distance setter")
	check(not src.contains(ban_face), "test source has no face-id setter")
	check(not src.contains(ban_export), "test source has no kernel 3MF export call")
	check(not src.contains(ban_path), "test source has no dialog path assignment")
	await test_rail_extrude()
	await test_export_absolute_path()
	check(FilmUI.fail_count == 0, "FilmUI reported no missing controls")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _boot() -> Array:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "viewport is 1280×800 (got %s)" % str(root.size))
	return [main, ctx]


func _file_button(main) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == "File":
			return btn
	return null


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


func _push_mouse(vp: Viewport, pos: Vector2, pressed: bool) -> void:
	if vp == null:
		return
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


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _push_mouse(vp, pos, true)
	await _push_mouse(vp, pos, false)


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await _click_at(ctrl.get_viewport(), pos)


func _keycode_for_char(ch: String) -> Key:
	var c := ch.unicode_at(0)
	if ch == "/":
		return KEY_SLASH
	if ch == "\\":
		return KEY_BACKSLASH
	if ch == "-":
		return KEY_MINUS
	if ch == "_":
		return KEY_UNDERSCORE
	if ch == ".":
		return KEY_PERIOD
	if c >= 48 and c <= 57:
		return (KEY_0 + (c - 48)) as Key
	if c >= 97 and c <= 122:
		return (KEY_A + (c - 97)) as Key
	if c >= 65 and c <= 90:
		return (KEY_A + (c - 65)) as Key
	return KEY_NONE


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		await _push_key(vp, _keycode_for_char(ch), ch.unicode_at(0))


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
			top += panel.get_margin(SIDE_TOP)
	for i in index:
		top += _popup_row_height(popup, i, font_h, v_sep)
	var row_h := _popup_row_height(popup, index, font_h, v_sep)
	var local := Vector2(popup.size.x * 0.5, top + row_h * 0.5)
	return Vector2(popup.position) + local


func _click_file_item(ctx: FilmContext, id: int, desc: String) -> bool:
	var main = ctx.main
	var file_btn := _file_button(main)
	if file_btn == null or not file_btn.is_visible_in_tree():
		check(false, "File menu button is visible for %s" % desc)
		return false
	if not await FilmUI.click_control(ctx, file_btn, {"keys": "Click", "desc": "File menu"}):
		return false
	file_btn.show_popup()
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = file_btn.get_popup()
	if popup == null or not popup.visible:
		check(false, "File popup is visible after File click (%s)" % desc)
		return false
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


func _type_distance(main, text: String) -> LineEdit:
	var chrome: SketchContextChrome = main.sketch_chrome
	if chrome == null or chrome._extrude_spin == null:
		check(false, "Distance spin exists")
		return null
	var edit: LineEdit = chrome._extrude_spin.get_line_edit()
	await _click_control(edit)
	await _click_control(edit)
	await _type_text(edit.get_viewport(), text)
	await process_frame
	await process_frame
	return edit


func test_rail_extrude() -> void:
	print("- Rail Extrude refuses 20.07.5 and sends typed 7.5")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	var chrome: SketchContextChrome = main.sketch_chrome
	if chrome == null or not chrome.has_method("distance_line_parses"):
		check(false, "WP1 gap: SketchContextChrome.distance_line_parses() is missing")
		main.queue_free()
		await process_frame
		return
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	if sm == null or not sm.active:
		main.queue_free()
		await process_frame
		return
	await _zoom(ctx, Vector3.ZERO, 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Circle centre")
	await FilmUI.click_sketch(ctx, sm, Vector2(10, 0), "Circle radius")
	await process_frame
	check(sm.active, "closed circle leaves the sketch session open")
	# The palette hides for the whole sketch (`_update_left_rail`). A person
	# extrudes from the finish bar, which is the sketch-mode Extrude path.
	var rail: Button = main._rail_extrude
	var finish_ex: Button = chrome.extrude_button() if chrome != null else null
	check(finish_ex != null and finish_ex.is_visible_in_tree(),
			"sketch-mode Extrude is visible while the sketch is open")
	check(rail != null and finish_ex != null and rail != finish_ex,
			"palette Extrude is a different button from the finish bar")
	check(rail == null or not rail.is_visible_in_tree(),
			"palette Extrude stays hidden while a sketch is active")
	var bodies_before := ctx.view.doc.body_ids().size()
	await _type_distance(main, "20.07.5")
	check(not chrome.distance_line_parses(), "20.07.5 does not parse")
	if finish_ex != null:
		await FilmUI.click_control(ctx, finish_ex, {"keys": "Click", "desc": "Sketch Extrude unparseable"})
		await process_frame
		await process_frame
	check(ctx.view.doc.body_ids().size() == bodies_before,
			"unparseable sketch Extrude does not add a body")
	check(sm.active, "unparseable sketch Extrude leaves the sketch active")
	var bad_status := str(main.status_label.text)
	check(bad_status.contains("Cannot read distance"),
			"unparseable sketch status contains Cannot read distance (got %s)" % bad_status)
	check(not bad_status.contains("Extrude Blind"),
			"unparseable sketch does not overwrite with success (got %s)" % bad_status)
	await _type_distance(main, "7.5")
	check(chrome.distance_line_parses(), "7.5 parses")
	if finish_ex != null:
		await FilmUI.click_control(ctx, finish_ex, {"keys": "Click", "desc": "Sketch Extrude 7.5"})
		await process_frame
		await process_frame
		await process_frame
	check(not sm.active, "sketch Extrude 7.5 finishes the sketch")
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(ids.size() == bodies_before + 1, "sketch Extrude 7.5 adds one body")
	if ids.size() > 0:
		var bb: Dictionary = ctx.view.doc.measure_bbox(ids[ids.size() - 1])
		var ext: Vector3 = bb["max"] - bb["min"]
		check(absf(ext.z - 7.5) <= 0.2, "bbox Z is 7.5 ± 0.2 (got %.4f)" % ext.z)
	var ok_status := str(main.status_label.text)
	check(ok_status.contains("Extrude Blind 7.5000 mm"),
			"status contains Extrude Blind 7.5000 mm (got %s)" % ok_status)
	main.queue_free()
	await process_frame


func _name_edit(dlg: FileDialog) -> LineEdit:
	if dlg == null:
		return null
	if dlg.has_method("get_line_edit"):
		var le: Variant = dlg.get_line_edit()
		if le is LineEdit:
			return le as LineEdit
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit != null:
			return edit
	return null


func test_export_absolute_path() -> void:
	print("- Export 3MF types an absolute path over the suggested name")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	check(body != "", "closed solid exists for export")
	await process_frame
	var dest := ProjectSettings.globalize_path("user://rung01_replan3_shell/abs.3mf")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	var glued := ProjectSettings.globalize_path("user://rung01_replan3_shell/glued.3mf")
	if FileAccess.file_exists(glued):
		DirAccess.remove_absolute(glued)
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF")
	check(opened, "File → Export 3MF was clicked at its popup rect")
	await process_frame
	await process_frame
	await process_frame
	var dlg: FileDialog = main.file_dialog
	check(dlg != null and dlg.visible, "Export 3MF opens a FileDialog")
	if dlg == null or not dlg.visible:
		main.queue_free()
		await process_frame
		return
	for _i in 4:
		await process_frame
	var start_dir := str(dlg.current_dir)
	check(str(dlg.current_file).ends_with(".3mf"),
			"dialog still opens on a .3mf filename default (got %s)" % dlg.current_file)
	check(start_dir != "", "dialog still opens on a directory default")
	var edit := _name_edit(dlg)
	check(edit != null, "Export 3MF name LineEdit exists")
	if edit == null:
		main.queue_free()
		await process_frame
		return
	await process_frame
	var selected := edit.get_selected_text()
	check(selected != "" and selected == edit.text,
			"name field selection is the entire suggested name (sel '%s' text '%s')" % [selected, edit.text])
	await _click_control(edit)
	for _j in 3:
		await process_frame
	var selected_click := edit.get_selected_text()
	check(selected_click != "" and selected_click == edit.text,
			"later click still selects the entire name (sel '%s' text '%s')" % [selected_click, edit.text])
	edit.grab_focus()
	await process_frame
	await _type_text(edit.get_viewport(), dest)
	await process_frame
	check(edit.text == dest,
			"typed absolute path replaced the suggested name (got %s)" % edit.text)
	check(not str(edit.text).begins_with("part.3mf"),
			"typed path is not glued onto part.3mf (got %s)" % edit.text)
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export dialog OK is visible")
	if ok != null:
		await FilmUI.click_control(ctx, ok, {"keys": "Click", "desc": "Export 3MF OK"})
		await process_frame
		await process_frame
	check(FileAccess.file_exists(dest), "OK writes the typed absolute path %s" % dest)
	var joined_wrong := start_dir.path_join(dest.trim_prefix("/"))
	if dest.is_absolute_path() and start_dir != dest.get_base_dir():
		check(not FileAccess.file_exists(joined_wrong) or joined_wrong == dest,
				"file is not under current_dir joined with the absolute path")
	var status := str(main.status_label.text)
	check(status == "Exported 3MF → " + dest,
			"status is Exported 3MF → <path> (got %s)" % status)

	print("- Missed select-all still exports the absolute tail")
	var opened2: bool = await _click_file_item(ctx, 11, "File → Export 3MF (glued)")
	check(opened2, "File → Export 3MF reopened")
	await process_frame
	await process_frame
	await process_frame
	for _k in 4:
		await process_frame
	dlg = main.file_dialog
	edit = _name_edit(dlg)
	check(dlg != null and dlg.visible and edit != null, "second Export dialog is open with a name field")
	if dlg == null or not dlg.visible or edit == null:
		main.queue_free()
		await process_frame
		return
	edit.grab_focus()
	await process_frame
	await _push_key(edit.get_viewport(), KEY_END, 0)
	await process_frame
	var before_append := str(edit.text)
	await _type_text(edit.get_viewport(), glued)
	await process_frame
	var glued_text := str(edit.text)
	if glued_text == glued:
		print("  note - End still replaced (select-all held); absolute path stands")
	else:
		check(glued_text.contains(before_append) and glued_text.contains(glued),
				"End then type glues the absolute path onto the suggested name (got %s)" % glued_text)
	var start_dir2 := str(dlg.current_dir)
	ok = dlg.get_ok_button()
	if ok != null:
		await FilmUI.click_control(ctx, ok, {"keys": "Click", "desc": "Export 3MF glued OK"})
		await process_frame
		await process_frame
	check(FileAccess.file_exists(glued), "glued/absolute export writes %s" % glued)
	var glued_joined := start_dir2.path_join(glued_text)
	if glued_joined != glued:
		check(not FileAccess.file_exists(glued_joined),
				"glued name is not written under current_dir (%s)" % glued_joined)
	var glued_status := str(main.status_label.text)
	check(glued_status == "Exported 3MF → " + glued,
			"glued export status is Exported 3MF → <path> (got %s)" % glued_status)
	if dlg.visible:
		dlg.hide()
	main.queue_free()
	await process_frame
