# Rung 1 replan 13 WP7 — Save As selects the file name; popups are opaque.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan13_chrome.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)



func _init() -> void:
	print("rung01 replan13 WP7 Save As name select and opaque popups")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)

	await _test_open_does_not_select_name(ctx, main)
	await _test_save_as_selects_and_replaces(ctx, main, "blank.sxp", true)
	await _test_save_as_selects_and_replaces(ctx, main, "untitled.sxp", false)
	await _test_export_3mf_still_selects(ctx, main)
	await _test_popups_are_opaque(main)

	main.queue_free()
	await process_frame
	finish()


func _test_open_does_not_select_name(ctx: FilmContext, main) -> void:
	print("- File → Open does not select a pre-filled name")
	main.current_path = ""
	var opened: bool = await _click_file_item(ctx, 1, "File → Open")
	await process_frame
	await process_frame
	var dlg: FileDialog = main.file_dialog
	check(opened and dlg != null and dlg.visible, "Open dialog is visible")
	var edit := _name_edit(dlg)
	check(edit != null, "Open dialog has a filename LineEdit")
	var selected := ""
	if edit != null and edit.has_selection():
		selected = edit.get_selected_text()
	check(selected == "" and str(dlg.current_file) == "",
			"Open does not select a name (no pre-filled file; selected `%s` current_file `%s`)" % [
				selected, dlg.current_file])
	if dlg != null and dlg.visible:
		dlg.hide()
	await process_frame


func _test_save_as_selects_and_replaces(ctx: FilmContext, main, expected_name: String, named_doc: bool) -> void:
	print("- File → Save As selects %s and typing replaces it" % expected_name)
	if named_doc:
		main.current_path = ProjectSettings.globalize_path("user://%s" % expected_name)
	else:
		main.current_path = ""
	var opened: bool = await _click_file_item(ctx, 3, "File → Save As (%s)" % expected_name)
	await process_frame
	await process_frame
	var dlg: FileDialog = main.file_dialog
	check(opened and dlg != null and dlg.visible, "Save As dialog is visible for %s" % expected_name)
	var edit := _name_edit(dlg)
	check(edit != null, "Save As filename LineEdit exists for %s" % expected_name)
	if edit == null or dlg == null:
		return
	check(edit.has_focus(), "Save As filename LineEdit has focus (%s)" % expected_name)
	check(edit.has_selection(), "Save As filename LineEdit has a selection (%s)" % expected_name)
	check(edit.get_selected_text() == expected_name,
			"Save As selected text is %s (got `%s`)" % [expected_name, edit.get_selected_text()])
	await _type_keys_into_dialog(dlg, "p.sxp")
	check(edit.text == "p.sxp",
			"typing p.sxp replaced the pre-filled name (got `%s`, not an append)" % edit.text)
	dlg.hide()
	await process_frame


func _test_export_3mf_still_selects(ctx: FilmContext, main) -> void:
	print("- File → Export 3MF still selects its name")
	main.current_path = ""
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF")
	await process_frame
	await process_frame
	var dlg: FileDialog = main.file_dialog
	check(opened and dlg != null and dlg.visible, "Export 3MF dialog is visible")
	var edit := _name_edit(dlg)
	check(edit != null, "Export 3MF filename LineEdit exists")
	if edit == null or dlg == null:
		return
	check(edit.has_focus(), "Export 3MF filename LineEdit has focus")
	check(edit.has_selection(), "Export 3MF filename LineEdit has a selection")
	check(edit.get_selected_text() == "part.3mf",
			"Export 3MF selected text is part.3mf (got `%s`)" % edit.get_selected_text())
	dlg.hide()
	await process_frame


func _test_popups_are_opaque(main) -> void:
	print("- PopupPanel / PopupMenu panels are opaque")
	var hud: ViewHud = main.view_hud
	check(hud != null, "View HUD exists")
	var ix: ViewportInteraction = main.interaction
	check(ix != null, "viewport interaction exists")
	_assert_opaque_popup(hud._views_popup, "PopupPanel", "view_hud._views_popup")
	_assert_opaque_popup(hud._rename_popup, "PopupPanel", "view_hud._rename_popup")
	_assert_opaque_popup(ix._orient_popup, "PopupPanel", "viewport_interaction._orient_popup")
	_assert_opaque_popup(ix._dim_edit_popup, "PopupPanel", "viewport_interaction._dim_edit_popup")
	_assert_opaque_popup(main._view_popup, "PopupMenu", "main._view_popup")

	var timeline_pops: Array = []
	if main.timeline != null:
		timeline_pops = main.timeline.find_children("*", "PopupPanel", true, false)
		if timeline_pops.is_empty():
			var feats: Array = main.view.doc.graph_features()
			if feats.is_empty():
				main.view.insert_primitive("box", Vector3.ZERO)
				feats = main.view.doc.graph_features()
			if not feats.is_empty() and main.timeline.has_method("_show_whats_wrong"):
				main.timeline._show_whats_wrong(str(feats[0]["id"]))
				await process_frame
				timeline_pops = main.timeline.find_children("*", "PopupPanel", true, false)
	check(not timeline_pops.is_empty(), "timeline has a PopupPanel to inspect")
	for pop in timeline_pops:
		_assert_opaque_popup(pop as Window, "PopupPanel", "timeline %s" % (pop as Node).name)


func _assert_opaque_popup(win: Window, theme_type: String, label: String) -> void:
	check(win != null, "%s exists" % label)
	if win == null:
		return
	var sb: StyleBox = win.get_theme_stylebox("panel", theme_type)
	check(sb is StyleBoxFlat,
			"%s panel stylebox is StyleBoxFlat (got %s)" % [label, sb.get_class() if sb != null else "null"])
	var alpha := 0.0
	if sb is StyleBoxFlat:
		alpha = (sb as StyleBoxFlat).bg_color.a
	check(sb is StyleBoxFlat and is_equal_approx(alpha, 1.0),
			"%s bg_color.a == 1.0 (got %.3f)" % [label, alpha])
	check(win.transparent == false, "%s Window.transparent is false" % label)
	check(win.transparent_bg == false, "%s Window.transparent_bg is false" % label)


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


func _type_keys_into_dialog(dlg: Window, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		else:
			push_error("no key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		dlg.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		dlg.push_input(rel)
		await process_frame


func _file_button(main) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == "File":
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
			top += panel.get_margin(SIDE_TOP)
	for i in index:
		top += _popup_row_height(popup, i, font_h, v_sep)
	var row_h := _popup_row_height(popup, index, font_h, v_sep)
	var local := Vector2(popup.size.x * 0.5, top + row_h * 0.5)
	return Vector2(popup.position) + local


func _x11_click_at(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_at(ctrl.get_viewport(), pos)


func _click_file_item(ctx: FilmContext, id: int, desc: String) -> bool:
	var main = ctx.main
	var file_btn := _file_button(main)
	if file_btn == null or not file_btn.is_visible_in_tree():
		check(false, "File menu button is visible for %s" % desc)
		return false
	await _x11_click(file_btn)
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
	await _x11_click_at(root.get_viewport(), screen)
	await process_frame
	await process_frame
	return true
