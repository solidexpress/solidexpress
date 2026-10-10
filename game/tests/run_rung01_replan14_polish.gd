# Rung 1 replan 14 WP7 — timeline pencil edits a sketch; File → Open enables on an existing .sxp.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan14_polish.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const SAVE_PATH := "/tmp/sx_polish_blank.sxp"

var _status_log: Array[String] = []
var _item15_disabled_seq: Array[String] = []
var _item15_row_click_needed_second := false


func _init() -> void:
	print("rung01 replan14 WP7 timeline pencil and File → Open")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("item15 disabled sequence: %s" % ", ".join(_item15_disabled_seq))
	if _item15_row_click_needed_second:
		print("item15 row 8 needed a second ItemList click (candidate b)")
	finish()


func _run() -> void:
	var ctx := await _boot()
	await _build_document(ctx)
	await _test_timeline_pencil(ctx)
	await _test_open_enable(ctx)
	await _shutdown(ctx)


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	if main.sketch_mode != null:
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null:
		main.interaction.status.connect(_on_status)
	if main.timeline != null:
		main.timeline.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	var live := str(ctx_status())
	return live.contains(needle)


func ctx_status() -> String:
	return ""


func _shutdown(ctx: FilmContext) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _build_document(ctx: FilmContext) -> void:
	print("- setup: datum plane, sketch, extrude")
	var doc = ctx.view.doc
	if doc.has_method("graph_add_datum_plane"):
		doc.graph_add_datum_plane(Vector3.ZERO, Vector3(0, 0, 1))
	else:
		doc.add_datum_plane(Vector3.ZERO, Vector3(0, 0, 1))
	ctx.view.graph_changed()
	await process_frame
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "setup started a sketch")
	if sm != null and sm.sketch != null:
		sm.sketch.add_circle(0.0, 0.0, 10.0)
		sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame
	await process_frame
	var types: PackedStringArray = PackedStringArray()
	for f in ctx.view.doc.graph_features():
		types.append("%s:%s" % [str(f.get("type", "")), str(f.get("name", ""))])
	print("  features: %s" % ", ".join(types))
	check(_fid_of(ctx, "sketch") != "", "document has a sketch feature")
	check(_fid_of(ctx, "extrude") != "", "document has an extrude feature")
	check(ctx.main.timeline != null and ctx.main.timeline.visible, "timeline is visible")


func _test_timeline_pencil(ctx: FilmContext) -> void:
	print("- 1. sketch pencil edits the sketch (no rename field)")
	var sketch_fid := _fid_of(ctx, "sketch")
	var extrude_fid := _fid_of(ctx, "extrude")
	var sketch_row := _row_for_fid(ctx, sketch_fid)
	var extrude_row := _row_for_fid(ctx, extrude_fid)
	var sketch_pencil := _row_edit_btn(sketch_row)
	var extrude_pencil := _row_edit_btn(extrude_row)
	check(sketch_row != null and sketch_pencil != null, "sketch row has a pencil")
	check(extrude_row != null and extrude_pencil != null, "extrude row has a pencil")
	if sketch_pencil == null:
		return
	_status_log.clear()
	await _click_settled(sketch_pencil)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var rename_after_sketch := _row_line_edit(_row_for_fid(ctx, sketch_fid))
	check(sm != null and sm.active and str(sm.editing_fid) == sketch_fid,
			"1: sketch pencil starts edit (active=%s fid=%s want=%s)" % [
				str(sm.active if sm != null else false),
				str(sm.editing_fid if sm != null else ""),
				sketch_fid])
	check(rename_after_sketch == null, "1: no rename LineEdit on the sketch row after the pencil")
	var status_now := str(ctx.main.status_label.text) if ctx.main.status_label != null else ""
	check(status_now.contains("Editing sketch") or _status_has("Editing sketch"),
			"1: status is Editing sketch (got `%s`)" % status_now)

	print("- exit sketch, then 2. extrude pencil still renames")
	await _exit_sketch_real(ctx)
	await process_frame
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame
	await process_frame
	extrude_row = _row_for_fid(ctx, extrude_fid)
	extrude_pencil = _row_edit_btn(extrude_row)
	check(extrude_pencil != null, "extrude pencil still exists after exiting the sketch")
	if extrude_pencil != null:
		check(str(extrude_pencil.tooltip_text) == "Rename feature",
				"2/4: extrude pencil tooltip is Rename feature (got `%s`)" % extrude_pencil.tooltip_text)
		await _click_settled(extrude_pencil)
		await process_frame
		await process_frame
	extrude_row = _row_for_fid(ctx, extrude_fid)
	var rename_edit := _row_line_edit(extrude_row)
	check(rename_edit != null, "2: extrude pencil opens a rename LineEdit")
	if rename_edit != null:
		await _x11_type(rename_edit.get_viewport(), "boss")
		await _x11_key(rename_edit.get_viewport(), KEY_ENTER)
		await process_frame
		await process_frame
	var extrude_name := _feature_name(ctx, extrude_fid)
	check(extrude_name == "boss", "2: extrude row shows the typed name (got `%s`)" % extrude_name)

	print("- 3. F2 and right-click Rename on the sketch row")
	sketch_row = _row_for_fid(ctx, sketch_fid)
	var sketch_name := _row_name_btn(sketch_row)
	check(sketch_name != null, "sketch name button exists")
	if sketch_name != null:
		await _x11_click(sketch_name)
		await process_frame
		await _x11_key(sketch_name.get_viewport(), KEY_F2)
		await process_frame
		await process_frame
	sketch_row = _row_for_fid(ctx, sketch_fid)
	var f2_edit := _row_line_edit(sketch_row)
	check(f2_edit != null, "3: F2 opens the rename field on the sketch row")
	if f2_edit != null:
		await _x11_key(f2_edit.get_viewport(), KEY_ESCAPE)
		await process_frame
		await process_frame
	check(_row_line_edit(_row_for_fid(ctx, sketch_fid)) == null, "3: Esc cancels the F2 rename")

	sketch_row = _row_for_fid(ctx, sketch_fid)
	sketch_name = _row_name_btn(sketch_row)
	if sketch_name != null:
		await _x11_click_right(sketch_name)
		await process_frame
		await process_frame
	var rename_menu := _find_rename_menu(ctx)
	check(rename_menu != null and rename_menu.visible,
			"3: right-click shows a Rename popup")
	if rename_menu != null and rename_menu.visible:
		var has_rename := false
		for i in rename_menu.item_count:
			if str(rename_menu.get_item_text(i)) == "Rename":
				has_rename = true
				break
		check(has_rename, "3: popup has a Rename item")
		await _x11_click_popup_item(rename_menu, 0)
		await process_frame
		await process_frame
	sketch_row = _row_for_fid(ctx, sketch_fid)
	check(_row_line_edit(sketch_row) != null, "3: clicking Rename opens the field")
	var open_edit := _row_line_edit(_row_for_fid(ctx, sketch_fid))
	if open_edit != null:
		await _x11_key(open_edit.get_viewport(), KEY_ESCAPE)
		await process_frame
		await process_frame

	print("- 4. tooltips")
	sketch_row = _row_for_fid(ctx, sketch_fid)
	extrude_row = _row_for_fid(ctx, extrude_fid)
	sketch_pencil = _row_edit_btn(sketch_row)
	extrude_pencil = _row_edit_btn(extrude_row)
	check(sketch_pencil != null and str(sketch_pencil.tooltip_text) == "Edit sketch",
			"4: sketch pencil tooltip is Edit sketch (got `%s`)" % [
				str(sketch_pencil.tooltip_text) if sketch_pencil != null else "missing"])
	check(extrude_pencil != null and str(extrude_pencil.tooltip_text) == "Rename feature",
			"4: extrude pencil tooltip is Rename feature (got `%s`)" % [
				str(extrude_pencil.tooltip_text) if extrude_pencil != null else "missing"])
	var sketch_tip := str(sketch_name.tooltip_text) if sketch_name != null else ""
	if sketch_name == null:
		sketch_name = _row_name_btn(sketch_row)
		sketch_tip = str(sketch_name.tooltip_text) if sketch_name != null else ""
	check(sketch_tip.contains("double-click a sketch to edit it"),
			"4: sketch name tooltip mentions double-click to edit (got `%s`)" % sketch_tip)

	print("- 5. double-click sketch name still edits the sketch")
	await _exit_sketch_real(ctx)
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame
	await process_frame
	sketch_row = _row_for_fid(ctx, sketch_fid)
	sketch_name = _row_name_btn(sketch_row)
	if sketch_name != null:
		await _x11_click(sketch_name, true)
		await process_frame
		await process_frame
	sm = ctx.main.sketch_mode
	check(sm != null and sm.active and str(sm.editing_fid) == sketch_fid,
			"5: double-click on the sketch name still edits it")
	await _exit_sketch_real(ctx)
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame


func _test_open_enable(ctx: FilmContext) -> void:
	print("- 6. File → Open enables for a typed existing .sxp")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	ctx.main.current_path = SAVE_PATH
	ctx.main._save_current()
	await process_frame
	check(FileAccess.file_exists(SAVE_PATH), "saved %s" % SAVE_PATH)
	var feat_count: int = ctx.view.doc.graph_features().size()
	if ctx.main.file_dialog != null:
		ctx.main.file_dialog.current_dir = "/tmp"
	_status_log.clear()
	await _open_file_menu(ctx, 1, "File → Open")
	await _click_discard_if_any(ctx)
	await process_frame
	await process_frame
	var dlg := await _wait_dialog(ctx.main)
	check(dlg != null and dlg.visible, "6: Open dialog is visible")
	if dlg == null or not dlg.visible:
		return
	var edit := _name_edit(dlg)
	check(edit != null, "6: Open dialog has a filename LineEdit")
	if edit != null:
		await _x11_click_embedded(edit)
		await process_frame
		await _x11_select_all(edit.get_viewport())
		await process_frame
		var typed := ""
		var name := SAVE_PATH.get_file()
		for i in name.length():
			var ch := name.substr(i, 1)
			await _x11_type(edit.get_viewport(), ch)
			typed += ch
			await process_frame
			var ok := dlg.get_ok_button()
			var dis := true if ok == null else ok.disabled
			var line := "'%s' disabled=%s" % [typed, str(dis)]
			_item15_disabled_seq.append(line)
			print("  open-disabled after %s" % line)
		var last_ok := dlg.get_ok_button()
		check(last_ok != null and last_ok.disabled == false,
				"6: Open is enabled after typing %s (disabled=%s)" % [
					name, str(last_ok.disabled if last_ok != null else "missing")])
		if last_ok != null:
			await _x11_click_embedded(last_ok)
			await process_frame
			await process_frame
			await process_frame
	var opened_status := str(ctx.main.status_label.text) if ctx.main.status_label != null else ""
	check(opened_status.contains("Opened") and opened_status.contains("sx_polish_blank.sxp"),
			"6: status mentions Opened and the file name (got `%s`)" % opened_status)
	check(ctx.view.doc.graph_features().size() == feat_count,
			"6: opened document has the same feature count (got %d want %d)" % [
				ctx.view.doc.graph_features().size(), feat_count])
	if dlg.visible:
		dlg.hide()
		await process_frame

	print("- 7. missing / non-.sxp names keep Open disabled")
	if ctx.main.file_dialog != null:
		ctx.main.file_dialog.current_dir = "/tmp"
	await _open_file_menu(ctx, 1, "File → Open (row 7)")
	await _click_discard_if_any(ctx)
	dlg = await _wait_dialog(ctx.main)
	check(dlg != null and dlg.visible, "7: Open dialog is visible")
	if dlg != null and dlg.visible:
		edit = _name_edit(dlg)
		if edit != null:
			await _x11_click_embedded(edit)
			await _x11_select_all(edit.get_viewport())
			await _x11_type(edit.get_viewport(), "nope.sxp")
			await process_frame
			var ok_nope := dlg.get_ok_button()
			print("  open-disabled after 'nope.sxp': %s" % str(ok_nope.disabled if ok_nope != null else "missing"))
			check(ok_nope != null and ok_nope.disabled,
					"7: Open stays disabled for nope.sxp (disabled=%s)" % [
						str(ok_nope.disabled if ok_nope != null else "missing")])
			await _x11_select_all(edit.get_viewport())
			await _x11_type(edit.get_viewport(), "sx_polish_blank.txt")
			await process_frame
			var ok_txt := dlg.get_ok_button()
			print("  open-disabled after 'sx_polish_blank.txt': %s" % str(
					ok_txt.disabled if ok_txt != null else "missing"))
			check(ok_txt != null and ok_txt.disabled,
					"7: Open stays disabled for sx_polish_blank.txt")
		dlg.hide()
		await process_frame

	print("- 8. single click on the ItemList row then Open")
	if ctx.main.file_dialog != null:
		ctx.main.file_dialog.current_dir = "/tmp"
	await _open_file_menu(ctx, 1, "File → Open (row 8)")
	await _click_discard_if_any(ctx)
	dlg = await _wait_dialog(ctx.main)
	check(dlg != null and dlg.visible, "8: Open dialog is visible")
	if dlg != null and dlg.visible:
		print("  dialog dir=%s lists=%d trees=%d rows=%s" % [
			dlg.current_dir,
			dlg.find_children("*", "ItemList", true, false).size(),
			dlg.find_children("*", "Tree", true, false).size(),
			", ".join(_list_dialog_names(dlg))])
		var clicked := await _click_dialog_row_once(dlg, "sx_polish_blank.sxp")
		check(clicked, "8: found ItemList/Tree row sx_polish_blank.sxp")
		await process_frame
		var name_after := _name_edit(dlg)
		print("  name field after row click: `%s` current_file=`%s`" % [
			str(name_after.text) if name_after != null else "?", dlg.current_file])
		var ok_row := dlg.get_ok_button()
		print("  open-disabled after one row click: %s" % str(
				ok_row.disabled if ok_row != null else "missing"))
		if ok_row != null and ok_row.disabled:
			_item15_row_click_needed_second = true
			print("  row 8 needed a second click (candidate b)")
			await _click_dialog_row_once(dlg, "sx_polish_blank.sxp")
			await process_frame
			ok_row = dlg.get_ok_button()
			print("  open-disabled after second row click: %s" % str(
					ok_row.disabled if ok_row != null else "missing"))
		check(ok_row != null and not ok_row.disabled,
				"8: Open is enabled after a row click")
		if ok_row != null and not ok_row.disabled:
			_status_log.clear()
			await _x11_click_embedded(ok_row)
			await process_frame
			await process_frame
			await process_frame
			var st := str(ctx.main.status_label.text) if ctx.main.status_label != null else ""
			check(st.contains("Opened") and st.contains("sx_polish_blank.sxp"),
					"8: Open from the row click loads the file (got `%s`)" % st)
		if dlg.visible:
			dlg.hide()
			await process_frame

	print("- 9. Insert .sxp and STEP import OK handling unchanged")
	await _assert_foreign_dialog_stays_disabled(ctx, "Insert", 10, "nope.sxp",
			"Insert → Components")
	await _assert_foreign_dialog_stays_disabled(ctx, "File", 4, "nope.step",
			"File → Import STEP")


func _assert_foreign_dialog_stays_disabled(ctx: FilmContext, menu: String, id: int, typed: String, desc: String) -> void:
	if menu == "Insert":
		var insert_btn := _menu_button(ctx.main, "Insert")
		await FilmUI.activate_menu_id(ctx, insert_btn, id, FilmUICues.alert("Insert", desc))
	else:
		await _open_file_menu(ctx, id, desc)
	await process_frame
	await process_frame
	var dlg := await _wait_dialog(ctx.main)
	check(dlg != null and dlg.visible, "%s dialog is visible" % desc)
	if dlg == null or not dlg.visible:
		return
	var ok := dlg.get_ok_button()
	var before := true if ok == null else ok.disabled
	print("  %s OK disabled before type: %s" % [desc, str(before)])
	var edit := _name_edit(dlg)
	if edit != null:
		await _x11_click_embedded(edit)
		await _x11_select_all(edit.get_viewport())
		await _x11_type(edit.get_viewport(), typed)
		await process_frame
	ok = dlg.get_ok_button()
	var after := true if ok == null else ok.disabled
	print("  %s OK disabled after '%s': %s" % [desc, typed, str(after)])
	check(after,
			"%s did not enable OK for a name that does not exist" % desc)
	dlg.hide()
	await process_frame


func _fid_of(ctx: FilmContext, ftype: String) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == ftype:
			return str(f.get("id", ""))
	return ""


func _feature_name(ctx: FilmContext, fid: String) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("name", ""))
	return ""


func _row_for_fid(ctx: FilmContext, fid: String) -> HBoxContainer:
	if fid == "" or ctx.main.timeline == null:
		return null
	var rows: Dictionary = ctx.main.timeline._rows
	if rows.has(fid):
		return rows[fid] as HBoxContainer
	return null


func _row_name_btn(row: Control) -> Button:
	if row == null:
		return null
	for c in row.get_children():
		if c is Button and not (c is CheckBox):
			return c as Button
	return null


func _row_edit_btn(row: Control) -> Button:
	if row == null:
		return null
	var named := row.get_node_or_null("RowEdit") as Button
	if named != null:
		return named
	for c in row.get_children():
		var b := c as Button
		if b == null or b is CheckBox:
			continue
		if b.name == "RowEdit":
			return b
		var tip := str(b.tooltip_text)
		if tip == "Rename feature" or tip == "Edit sketch":
			return b
	return null


func _row_line_edit(row: Control) -> LineEdit:
	if row == null:
		return null
	for c in row.get_children():
		if c is LineEdit:
			return c as LineEdit
	return null


func _find_rename_menu(ctx: FilmContext) -> PopupMenu:
	var roots: Array = [ctx.main.timeline, ctx.main]
	for root_n in roots:
		if root_n == null:
			continue
		for c in root_n.find_children("*", "PopupMenu", true, false):
			var menu := c as PopupMenu
			if menu == null or not menu.visible:
				continue
			if menu.item_count <= 0:
				continue
			if str(menu.get_item_text(0)) == "Rename" or menu.name == "RowRenameMenu":
				return menu
	return null


func _exit_sketch_real(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	if exit_btn != null and exit_btn.is_visible_in_tree():
		await _x11_click(exit_btn)
		await process_frame
		await process_frame
	if sm.active:
		await _x11_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await process_frame
		await process_frame
	if sm.active:
		await FilmUI._click_confirm_ok(ctx, "Confirm discard empty sketch")
	if sm.active:
		await _x11_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await process_frame


func _open_file_menu(ctx: FilmContext, id: int, desc: String) -> void:
	var file_btn := _menu_button(ctx.main, "File")
	await FilmUI.activate_menu_id(ctx, file_btn, id, FilmUICues.alert("File", desc))
	await process_frame
	await process_frame


func _click_discard_if_any(ctx: FilmContext) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		var dlg: ConfirmationDialog = ctx.main.confirm_dialog
		if dlg != null and dlg.visible:
			var ok := dlg.get_ok_button()
			if ok != null:
				await _x11_click_embedded(ok)
			await process_frame
			return
		await process_frame


func _wait_dialog(main, frames: int = 10) -> FileDialog:
	for _i in frames:
		await process_frame
		var dlg: FileDialog = main.file_dialog as FileDialog
		if dlg != null and dlg.visible:
			return dlg
	return main.file_dialog as FileDialog


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


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _list_dialog_names(dlg: FileDialog) -> PackedStringArray:
	var names := PackedStringArray()
	if dlg == null:
		return names
	for c in dlg.find_children("*", "ItemList", true, false):
		var lst := c as ItemList
		if lst == null or not lst.is_visible_in_tree():
			continue
		for i in lst.item_count:
			names.append(lst.get_item_text(i))
	for c in dlg.find_children("*", "Tree", true, false):
		var tree := c as Tree
		if tree == null or not tree.is_visible_in_tree():
			continue
		var item := tree.get_root()
		if item == null:
			continue
		item = item.get_next_in_tree()
		while item != null:
			names.append(item.get_text(0))
			item = item.get_next_in_tree()
	return names


func _itemlist_vscroll(lst: ItemList) -> VScrollBar:
	for c in lst.find_children("*", "VScrollBar", true, false):
		var sb := c as VScrollBar
		if sb != null and sb.is_visible_in_tree():
			return sb
	return null


func _click_dialog_row_once(dlg: FileDialog, needle: String) -> bool:
	var want := needle.to_lower()
	for c in dlg.find_children("*", "ItemList", true, false):
		var lst := c as ItemList
		if lst == null or not lst.is_visible_in_tree():
			continue
		for i in lst.item_count:
			var text := lst.get_item_text(i)
			if text.to_lower() != want and not text.to_lower().ends_with("/" + want):
				continue
			if lst.has_method("ensure_current_is_visible"):
				lst.select(i)
				lst.ensure_current_is_visible()
			await process_frame
			var rect: Rect2 = lst.get_item_rect(i)
			var center := rect.position + rect.size * 0.5
			var sb := _itemlist_vscroll(lst)
			if sb != null:
				center.y -= sb.value
			await _x11_click_embedded_at(lst, center)
			await process_frame
			return true
	for c in dlg.find_children("*", "Tree", true, false):
		var tree := c as Tree
		if tree == null or not tree.is_visible_in_tree():
			continue
		var item := tree.get_root()
		if item == null:
			continue
		item = item.get_next_in_tree()
		while item != null:
			var text := item.get_text(0)
			if text.to_lower() == want or text.to_lower().ends_with("/" + want):
				tree.scroll_to_item(item)
				await process_frame
				var area: Rect2 = tree.get_item_area_rect(item)
				var local := area.position + area.size * 0.5
				await _x11_click_embedded_at(tree, local)
				await process_frame
				return true
			item = item.get_next_in_tree()
	return false


## Motion, let the timeline dock, then click the button where it settled.
## A same-frame click is stolen when headless hover still names a neighbour.
func _click_settled(ctrl: Control) -> void:
	if ctrl == null:
		return
	var vp := ctrl.get_viewport()
	var pos := ctrl.get_global_rect().get_center()
	for _i in 4:
		var motion := InputEventMouseMotion.new()
		motion.position = pos
		motion.global_position = pos
		vp.push_input(motion)
		await process_frame
		if not is_instance_valid(ctrl):
			return
		var now := ctrl.get_global_rect().get_center()
		if now.distance_to(pos) < 0.5:
			pos = now
			break
		pos = now
	await _x11_click_screen(vp, pos)


func _x11_click(ctrl: Control, double_click: bool = false) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos, double_click)


func _x11_click_right(ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_click_screen(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
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


func _x11_click_embedded(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + pos
	await _x11_click_screen(root.get_viewport(), pos)


func _x11_click_embedded_at(ctrl: Control, local: Vector2, double_click: bool = false) -> void:
	var pos := local
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + local
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + ctrl.get_global_rect().position + local
		else:
			pos = ctrl.get_global_rect().position + local
	await _x11_click_screen(root.get_viewport(), pos, double_click)


func _x11_click_popup_item(popup: PopupMenu, index: int) -> void:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs if font == null else font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top += panel.get_margin(SIDE_TOP)
	var row_h := float(font_h) + float(v_sep)
	var local := Vector2(maxf(8.0, popup.size.x * 0.5), top + row_h * (float(index) + 0.5))
	var screen := Vector2(popup.position) + local
	await _x11_click_screen(root.get_viewport(), screen)


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame


func _x11_select_all(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.physical_keycode = KEY_A
	ev.unicode = 0
	ev.ctrl_pressed = true
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := _keycode_for_unicode(ch)
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		if ch == 95:
			ev.shift_pressed = true
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame


func _keycode_for_unicode(ch: int) -> Key:
	if ch >= 48 and ch <= 57:
		return (KEY_0 + (ch - 48)) as Key
	if ch >= 97 and ch <= 122:
		return (KEY_A + (ch - 97)) as Key
	if ch >= 65 and ch <= 90:
		return (KEY_A + (ch - 65)) as Key
	if ch == 46:
		return KEY_PERIOD
	if ch == 45:
		return KEY_MINUS
	if ch == 47:
		return KEY_SLASH
	if ch == 95:
		return KEY_MINUS
	return KEY_NONE
