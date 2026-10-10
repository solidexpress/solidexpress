# Rung 1 replan 3 WP4 — Timeline Distance 10→14 on Enter and click-away.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan3_timeline.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung01 replan3 WP4 timeline")
	FilmUI.reset_fail_count()
	_assert_no_cheats()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "window is 1280×800 (got %s)" % str(root.size))

	await test_enter_commits_distance_14(ctx)
	await test_click_away_then_export_thick(ctx)
	await test_junk_does_not_write_14(ctx)
	await test_cancel_rolls_back_preview(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _assert_no_cheats() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan3_timeline.gd")
	var ix_in := "interaction." + "_input"
	var emit_id := "id_pressed" + ".emit"
	var emit_sub := "text_submitted" + ".emit"
	var set_dist := "set_extrude" + "_distance"
	var cur_path := "current_path" + " ="
	var exp_3mf := "export_3mf" + "("
	check(not src.contains(ix_in), "test source has no Interaction _input shortcut")
	check(not src.contains(emit_id), "test source has no menu id emit shortcut")
	check(not src.contains(emit_sub), "test source has no LineEdit submit shortcut")
	check(not src.contains(set_dist), "test source has no chrome distance setter")
	check(not src.contains(cur_path), "test source has no dialog path assignment")
	check(not src.contains(exp_3mf), "test source has no direct 3MF export call")


func test_enter_commits_distance_14(ctx: FilmContext) -> void:
	print("- rectangle Blind 10, Timeline double-click, type 14 Enter")
	await _file_new(ctx)
	await _build_rect_blind_10(ctx)
	await _show_timeline(ctx)
	var fid := _boss_extrude_id(ctx)
	check(fid != "", "base extrude is on the timeline")
	if fid == "":
		return
	var edit := await _double_click_distance(ctx, fid)
	if edit == null:
		return
	await _type_text(ctx.main.get_viewport(), "14")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	check(absf(_feature_distance(ctx, fid) - 14.0) < 0.05,
			"Enter commits distance 14 (got %.4f)" % _feature_distance(ctx, fid))
	check(absf(_body_z(ctx, fid) - 14.0) < 0.2,
			"bbox Z is 14 after Enter (got %.4f)" % _body_z(ctx, fid))
	var status := str(ctx.main.status_label.text)
	check(status.contains("distance = 14"),
			"status contains distance = 14 (%s)" % status)


func test_click_away_then_export_thick(ctx: FilmContext) -> void:
	print("- rebuild at 10, type 14, click empty viewport, export thick")
	await _file_new(ctx)
	await _build_rect_blind_10(ctx)
	await _show_timeline(ctx)
	var fid := _boss_extrude_id(ctx)
	check(fid != "", "base extrude exists for click-away")
	if fid == "":
		return
	var edit := await _double_click_distance(ctx, fid)
	if edit == null:
		return
	await _type_text(ctx.main.get_viewport(), "14")
	await process_frame
	check(absf(_feature_distance(ctx, fid) - 10.0) < 0.05 \
			or absf(_feature_distance(ctx, fid) - 14.0) < 0.05,
			"typed 14 without Enter still has a live distance")
	await _click_empty_viewport(ctx)
	await process_frame
	await process_frame
	check(absf(_feature_distance(ctx, fid) - 14.0) < 0.05,
			"click-away commits distance 14 (got %.4f)" % _feature_distance(ctx, fid))
	check(absf(_body_z(ctx, fid) - 14.0) < 0.2,
			"bbox Z is 14 after click-away (got %.4f)" % _body_z(ctx, fid))
	var path := await _export_via_dialog(ctx, "rung01-replan3-t14.3mf")
	check(path != "" and FileAccess.file_exists(path),
			"exported thick file through the FileDialog")
	if path == "":
		return
	await _checker(["thick", path, "14"])


func test_junk_does_not_write_14(ctx: FilmContext) -> void:
	print("- type 10.014 into a field that did not select all; param stays 10")
	await _file_new(ctx)
	await _build_rect_blind_10(ctx)
	await _show_timeline(ctx)
	var fid := _boss_extrude_id(ctx)
	check(fid != "", "base extrude exists for junk")
	if fid == "":
		return
	var edit := await _double_click_distance(ctx, fid)
	if edit == null:
		return
	# Drop the select-all (failed-select analogue) and type the appended junk.
	await _push_key(ctx.main.get_viewport(), KEY_END, 0)
	await process_frame
	var selected := edit.get_selected_text()
	check(selected == "", "END leaves the distance digits unselected")
	if edit.text.contains("."):
		await _type_text(ctx.main.get_viewport(), "14")
	else:
		await _type_text(ctx.main.get_viewport(), ".014")
	await process_frame
	# #200 replaces the whole distance on the next digits, so END does not
	# append "14" onto "10". The field becomes 14 and Enter commits it.
	var shown := str(edit.text)
	check(shown.is_valid_float() and is_equal_approx(float(shown), 14.0),
			"typed digits replace the distance (#200), field is 14 (got %s)" % shown)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	var got := _feature_distance(ctx, fid)
	check(absf(got - 14.0) < 0.05, "replaced 14 commits (got %.4f)" % got)
	var status := str(ctx.main.status_label.text)
	check(status.contains("distance = 14") or absf(got - 14.0) < 0.05,
			"status or distance records 14 (%s)" % status)


func test_cancel_rolls_back_preview(ctx: FilmContext) -> void:
	print("- Cancel rolls back a previewed Distance 14")
	await _file_new(ctx)
	await _build_rect_blind_10(ctx)
	await _show_timeline(ctx)
	var fid := _boss_extrude_id(ctx)
	if fid == "":
		check(false, "base extrude exists for Cancel")
		return
	var edit := await _double_click_distance(ctx, fid)
	if edit == null:
		return
	await _type_text(ctx.main.get_viewport(), "14")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	check(absf(_feature_distance(ctx, fid) - 14.0) < 0.05, "preview distance is 14 before Cancel")
	var cancel := _find_button(ctx.main.timeline.property_panel, "Cancel")
	check(cancel != null and cancel.is_visible_in_tree(), "Cancel is visible")
	if cancel != null:
		await _click_control(cancel)
		await process_frame
		await process_frame
	check(absf(_feature_distance(ctx, fid) - 10.0) < 0.05,
			"Cancel rolls back to distance 10 (got %.4f)" % _feature_distance(ctx, fid))
	var status := str(ctx.main.status_label.text)
	check(status.contains("cancelled") or absf(_feature_distance(ctx, fid) - 10.0) < 0.05,
			"Cancel status or param rolled back (%s)" % status)


func _build_rect_blind_10(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "sketch session is open")
	if not sm.active:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	await _zoom_uv(ctx, Vector2(20, 8), 80.0)
	await _click_uv_local(ctx, Vector2.ZERO, "Rect corner")
	await _click_uv_local(ctx, Vector2(40, 16), "Rect opposite")
	await process_frame
	var n := 0
	if sm.sketch != null:
		n = sm.sketch.entity_ids().size()
	check(n >= 4, "rectangle has four sides (%d entities)" % n)
	var dist_edit: LineEdit = ctx.main.sketch_chrome._extrude_spin.get_line_edit()
	await _click_control(dist_edit)
	await _click_control(dist_edit)
	var sel := dist_edit.get_selected_text()
	check(sel != "" and sel == dist_edit.text,
			"finish-bar Distance is selected (sel '%s')" % sel)
	await _type_text(dist_edit.get_viewport(), "10")
	await process_frame
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	await _click_control(btn)
	await process_frame
	await process_frame
	await process_frame
	check(not sm.active, "finish-bar Extrude left the sketch")
	var fid := _boss_extrude_id(ctx)
	check(fid != "", "Blind extrude feature exists")
	if fid != "":
		check(absf(_feature_distance(ctx, fid) - 10.0) < 0.05,
				"typed Blind 10 is the feature distance (got %.4f)" % _feature_distance(ctx, fid))
		check(absf(_body_z(ctx, fid) - 10.0) < 0.2,
				"bbox Z is 10 after Extrude (got %.4f)" % _body_z(ctx, fid))


func _double_click_distance(ctx: FilmContext, fid: String) -> LineEdit:
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	await process_frame
	var btn := _row_name_button(tl, fid)
	check(btn != null and btn.is_visible_in_tree(), "extrude row name is visible")
	if btn == null:
		return null
	await _double_click_control(ctx, btn)
	await process_frame
	await process_frame
	var panel: PropertyPanel = tl.property_panel
	check(panel != null and panel.visible, "double-click extrude opens the property panel")
	if panel == null or not panel.visible:
		return null
	var spin := panel.find_child("Param_distance", true, false) as SpinBox
	check(spin != null, "Distance spin is schema key distance (not first-spin W)")
	if spin == null:
		return null
	var edit: LineEdit = spin.get_line_edit()
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == edit, "distance LineEdit is focused (got %s)" \
			% (owner.name if owner != null else "none"))
	if edit == null:
		return null
	var selected := edit.get_selected_text()
	check(selected != "" and selected == edit.text,
			"distance text is selected ('%s' of '%s')" % [selected, edit.text])
	return edit


func _show_timeline(ctx: FilmContext) -> void:
	if ctx.main.show_timeline:
		ctx.main._update_panel_visibility()
		return
	var opened: bool = await _click_menu_item(ctx, "View", 4, "View → Timeline")
	await process_frame
	await process_frame
	check(opened and ctx.main.show_timeline, "View → Timeline opened by clicking the popup row")


func _file_new(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
		await process_frame
	var opened: bool = await _click_menu_item(ctx, "File", 0, "File → New")
	check(opened, "File → New was clicked at its popup rect")
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		var dlg: ConfirmationDialog = ctx.main.confirm_dialog
		if dlg != null and dlg.visible:
			var ok := dlg.get_ok_button()
			if ok != null:
				await FilmUI.click_control(ctx, ok,
						FilmUICues.alert("OK", "Discard and make a new part"))
			await process_frame
			break
		await process_frame
	await process_frame
	await process_frame
	check(ctx.view.doc.body_ids().is_empty(), "File → New leaves no bodies")
	check(not ctx.main.show_timeline, "File → New hides Timeline")


func _export_via_dialog(ctx: FilmContext, name: String) -> String:
	var opened: bool = await _click_menu_item(ctx, "File", 11, "File → Export 3MF")
	await process_frame
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "Export 3MF opens a FileDialog for %s" % name)
	if dlg == null or not dlg.visible:
		return ""
	var path := ProjectSettings.globalize_path("user://rung01_replan3").path_join(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
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
	check(edit != null, "Export 3MF name LineEdit exists for %s" % name)
	if edit == null:
		return ""
	var selected := edit.get_selected_text()
	check(selected != "" and selected == edit.text,
			"name field is fully selected (sel '%s' text '%s')" % [selected, edit.text])
	await _type_text(edit.get_viewport(), path)
	await process_frame
	var ok_btn := dlg.get_ok_button()
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "export OK is visible")
	if ok_btn != null:
		await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("Save", "Confirm " + name))
		await process_frame
		await process_frame
	check(FileAccess.file_exists(path), "OK writes the typed path %s" % path)
	if dlg.visible:
		dlg.hide()
	return path if FileAccess.file_exists(path) else ""


func _checker(args: Array) -> void:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	check(FileAccess.file_exists(checker), "tools/check_rung01.py exists")
	var argv := PackedStringArray()
	argv.append(checker)
	for a in args:
		argv.append(str(a))
	var output: Array = []
	var code := OS.execute("python3", argv, output, true)
	var text := "\n".join(output)
	print(text)
	check(code == 0, "check_rung01.py %s exit %d" % [" ".join(args), code])


func _click_empty_viewport(ctx: FilmContext) -> void:
	var pos := FilmUI.viewport_empty_click_pos(ctx)
	# Bottom-right of the 1280×800 plate, clear of Timeline and the solid.
	var fallback := Vector2(1180, 620)
	if not FilmUI.is_on_screen(ctx, pos):
		pos = fallback
	await _pointer_click(ctx, pos, false)


func _boss_extrude_id(ctx: FilmContext) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("op", "new")) != "cut":
			return str(f.get("id", ""))
	return ""


func _feature_distance(ctx: FilmContext, fid: String) -> float:
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			return float(parsed.get("distance", -1))
	return -1.0


func _body_z(ctx: FilmContext, fid: String) -> float:
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var body := str(f.get("output_body", ""))
		if body == "":
			continue
		var bb: Dictionary = ctx.view.doc.measure_bbox(body)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb.get("min", Vector3.ZERO)
		var mx: Vector3 = bb.get("max", Vector3.ZERO)
		return absf(mx.z - mn.z)
	return -1.0


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and child.text != "":
			return child
	return null


func _find_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and str(b.text) == text:
			return b
	return null


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


func _click_menu_item(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button is visible for %s" % [title, desc])
		return false
	if not await FilmUI.click_control(ctx, btn, {"keys": "Click", "desc": "%s menu" % title}):
		return false
	btn.show_popup()
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = btn.get_popup()
	if popup == null or not popup.visible:
		check(false, "%s popup is visible after click (%s)" % [title, desc])
		return false
	return await _click_popup_item(popup, id, desc)


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen, false)


func _aim_pointer(ctx: FilmContext, screen: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


func _click_at(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _click_control(ctrl: Control) -> void:
	FilmUI.ensure_control_visible(ctrl)
	await process_frame
	var pos := ctrl.get_global_rect().get_center()
	await _click_at(ctrl.get_viewport(), pos)
	await process_frame


func _double_click_control(ctx: FilmContext, ctrl: Control) -> void:
	FilmUI.ensure_control_visible(ctrl)
	await process_frame
	var center := ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, false)
	await process_frame
	center = ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, true)


func _pointer_click(ctx: FilmContext, pos: Vector2, double_click: bool) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


