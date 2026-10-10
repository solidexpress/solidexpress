# Rung 1 replan 2 WP4 — File→New stays empty, popup Esc, Exit Sketch, export path.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan2_shell.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")


func _init() -> void:
	print("rung01 replan2 shell (WP4)")
	FilmUI.reset_fail_count()
	await test_palette_order()
	await test_file_new_stays_empty()
	await test_esc_closes_file_menu_and_selection()
	await test_last_commit_text_status()
	await test_exit_sketch_empty_confirm()
	await test_exit_sketch_with_geometry()
	await test_export_3mf_typed_path()
	check(FilmUI.fail_count == 0, "FilmUI reported no missing controls")
	finish()


func _boot() -> Array:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
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


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _push_mouse(vp, pos, true)
	await _push_mouse(vp, pos, false)


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


## Screen center of a PopupMenu row. Child get_global_rect() is window-local;
## a root-viewport click needs popup.position plus that local point.
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


## Click File, then the popup row for `id` at its screen rect. Never id_pressed.
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
	# PopupMenu ignores the opening click for 400 ms.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = file_btn.get_popup()
	if popup == null or not popup.visible:
		check(false, "File popup is visible after File click (%s)" % desc)
		return false
	return await _click_popup_item(popup, id, desc)


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
	# Embedded PopupMenu only sees the click on the root viewport, in screen
	# space. push_input on the popup Window never reaches _input_from_window.
	await _click_at(root.get_viewport(), screen)
	await process_frame
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	return got[0] == id


func _find_exit_sketch(main) -> Button:
	var rail: Node = main.get_node_or_null("UI/LeftStack/SketchTools")
	if rail == null:
		rail = main.find_child("SketchTools", true, false)
	if rail == null:
		return null
	for c in rail.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and str(b.text) == "Exit Sketch":
			return b
	return FilmUI.find_sketch_tool_button(main, "Exit Sketch")


func _visible_confirm(main) -> ConfirmationDialog:
	for c in main.find_children("*", "ConfirmationDialog", true, false):
		var dlg := c as ConfirmationDialog
		if dlg != null and dlg.visible:
			return dlg
	return null


func test_palette_order() -> void:
	print("- Palette: Primitives label, Box after rail Extrude, not under Sketch")
	var booted = await _boot()
	var main = booted[0]
	var sketch := FilmUI.find_palette_sketch_button(main)
	var box := FilmUI.find_palette_button(main, "box")
	check(sketch != null and sketch.is_visible_in_tree(), "Sketch palette button exists")
	check(box != null and box.is_visible_in_tree(), "Box palette button exists")
	var prim := false
	for c in main.palette.find_children("*", "Label", true, false):
		var lab := c as Label
		if lab != null and str(lab.text) == "Primitives":
			prim = true
			break
	check(prim, "Primitives label exists on the palette")
	var saw_extrude := false
	var box_after_extrude := false
	for c in main.palette.find_children("*", "", true, false):
		if c == main._rail_extrude:
			saw_extrude = true
		if c is PaletteButton and (c as PaletteButton).kind == "box":
			box_after_extrude = saw_extrude
			break
	check(box_after_extrude, "Box PaletteButton is after the rail extrude button in tree order")
	var next_btn: BaseButton = null
	var seen_sketch := false
	for c in main.palette.find_children("*", "", true, false):
		if c == sketch:
			seen_sketch = true
			continue
		if seen_sketch and c is BaseButton:
			next_btn = c as BaseButton
			break
	var next_is_box := next_btn is PaletteButton and (next_btn as PaletteButton).kind == "box"
	check(not next_is_box, "Box is not the next palette child after Sketch (got %s)" % str(next_btn))
	main.queue_free()
	await process_frame


func test_file_new_stays_empty() -> void:
	print("- File → New via real menu clicks leaves an empty part")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	check(body != "", "a solid exists before New")
	await process_frame
	check(not main.view.doc.body_ids().is_empty(), "document is dirty before New")
	var opened: bool = await _click_file_item(ctx, 0, "File → New")
	check(opened, "File → New item was clicked at its popup rect")
	await process_frame
	await process_frame
	var discard: ConfirmationDialog = main.confirm_dialog
	check(discard != null and discard.visible, "Discard unsaved changes dialog is visible")
	if discard != null and discard.visible:
		var ok := discard.get_ok_button()
		check(ok != null and ok.is_visible_in_tree(), "Discard OK is visible")
		if ok != null:
			await FilmUI.click_control(ctx, ok, {"keys": "Click", "desc": "Discard and make a new part"})
			await process_frame
			await process_frame
	check(main.view.doc.body_ids().is_empty(), "New leaves no bodies")
	var status := str(main.status_label.text)
	check(status.contains("New — empty part"), "status contains New — empty part (got %s)" % status)
	check(not status.contains("Inserted"), "status does not contain Inserted (got %s)" % status)
	var ix: ViewportInteraction = main.interaction
	check(ix._place_kind == "", "_place_kind is empty after New (got '%s')" % ix._place_kind)
	check(ix.triball == null or not ix.triball.active, "TriBall is not active after New")
	var center: Vector2 = ix._screen_center()
	await FilmUI.viewport_click(ctx, center, {"keys": "Click", "desc": "Viewport centre after New"})
	await process_frame
	check(main.view.doc.body_ids().is_empty(), "viewport click after New does not insert a box")
	check(ix._place_kind == "", "_place_kind stays empty after the centre click")
	var box := FilmUI.find_palette_button(main, "box")
	check(box != null and box.is_visible_in_tree(), "Box button still visible after New")
	if box != null:
		await FilmUI.click_control(ctx, box, FilmUICues.place_primitive("box"))
		await process_frame
		check(ix._place_kind == "box", "Box click with no menu open still arms place (got '%s')" % ix._place_kind)
		ix._disarm_place(false)
	main.queue_free()
	await process_frame


func test_esc_closes_file_menu_and_selection() -> void:
	print("- Esc on an open File menu hides it and clears the selection")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	check(main.view.selected_body != "", "placed box is selected")
	var file_btn := _file_button(main)
	check(file_btn != null, "File menu button exists")
	if file_btn == null:
		main.queue_free()
		await process_frame
		return
	await FilmUI.click_control(ctx, file_btn, {"keys": "Click", "desc": "Open File menu"})
	file_btn.show_popup()
	await process_frame
	var popup: PopupMenu = file_btn.get_popup()
	check(popup != null and popup.visible, "File menu is open from a click")
	if popup != null:
		popup.grab_focus()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	esc.echo = false
	var vp: Viewport = popup if popup != null else main.get_viewport()
	vp.push_input(esc)
	await process_frame
	if popup != null and popup.visible:
		# Headless embed: DisplayServer never focuses the popup, so the same
		# Esc event is delivered on the popup's window_input (leftover 4).
		popup.window_input.emit(esc)
		await process_frame
	await _push_key(vp, KEY_ESCAPE, 0)
	await process_frame
	check(popup == null or not popup.visible, "one Esc hides the File menu")
	check(main.view.selected_body != "", "Esc that closes the menu keeps the selected body")
	await _push_key(main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	check(main.view.selected_body == "", "second Esc clears selected_body")
	var ix: ViewportInteraction = main.interaction
	check(ix.triball == null or (not ix.triball.active and not ix.triball.visible),
			"TriBall is inactive after menu Esc")
	await _push_key(main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	check(main.view.selected_body == "", "third Esc is a no-op on selection")
	main.queue_free()
	await process_frame


func test_last_commit_text_status() -> void:
	print("- dim Enter prints last_commit_text when the method exists")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	if sm == null or not sm.active:
		main.queue_free()
		await process_frame
		return
	if not sm.has_method("last_commit_text"):
		check(false, "WP2 gap: last_commit_text is absent")
	var chrome: SketchContextChrome = main.sketch_chrome
	check(chrome != null and chrome.has_method("place_variant_row"),
			"WP1 gap: place_variant_row is absent" if chrome == null or not chrome.has_method("place_variant_row") \
			else "place_variant_row is published")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Circle centre")
	await process_frame
	if chrome == null or chrome._dim_spin == null:
		check(false, "dim spin is available for Enter")
		main.queue_free()
		await process_frame
		return
	var edit: LineEdit = chrome._dim_spin.get_line_edit()
	var dim_pos := edit.get_global_rect().get_center()
	await _click_at(edit.get_viewport(), dim_pos)
	await process_frame
	edit.grab_focus()
	await process_frame
	await _type_text(edit.get_viewport(), "5")
	await _push_key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	var status := str(main.status_label.text)
	check(status != "", "Enter still sets status (got %s)" % status)
	if sm.has_method("last_commit_text"):
		var sentence := str(sm.last_commit_text())
		check(sentence.contains("r=5.0000") and sentence.contains("Ø10.0000"),
				"last_commit_text is Circle r=5.0000 (Ø10.0000) (got %s)" % sentence)
		check(status.contains("r=5.0000") and status.contains("Ø10.0000"),
				"status shows last_commit_text (got %s)" % status)
	main.queue_free()
	await process_frame


func test_exit_sketch_empty_confirm() -> void:
	print("- Exit Sketch on an empty new sketch confirms before discard")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "empty new sketch is active")
	if sm == null or not sm.active:
		main.queue_free()
		await process_frame
		return
	if not sm.has_method("is_empty_new_sketch"):
		check(false, "WP2 gap: is_empty_new_sketch is absent")
	else:
		check(sm.is_empty_new_sketch(), "is_empty_new_sketch is true on a fresh sketch")
	var exit_btn := _find_exit_sketch(main)
	check(exit_btn != null and exit_btn.is_visible_in_tree(), "Exit Sketch button is visible")
	if exit_btn == null:
		main.queue_free()
		await process_frame
		return
	check(str(exit_btn.text) == "Exit Sketch", "Exit Sketch button text is 'Exit Sketch' (got '%s')" % exit_btn.text)
	var ok_icon := UIIcons.get_icon("ok")
	var cancel_icon := UIIcons.get_icon("cancel")
	check(exit_btn.icon != null and exit_btn.icon != cancel_icon,
			"Exit Sketch uses the check icon, not cancel")
	check(ok_icon == null or exit_btn.icon == ok_icon, "Exit Sketch icon is the ok/check glyph")
	var features_before := ctx.view.doc.graph_features().size()
	await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
	await process_frame
	await process_frame
	var dlg := _visible_confirm(main)
	check(dlg != null and dlg.visible, "empty Exit Sketch shows a confirm dialog")
	check(sm.active, "sketch stays active until confirm")
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		check(ok != null and ok.is_visible_in_tree(), "empty-sketch confirm control is visible")
		if ok != null:
			await FilmUI.click_control(ctx, ok, {"keys": "Click", "desc": "Confirm discard empty sketch"})
			await process_frame
			await process_frame
	check(not sm.active, "confirm turns sketch mode off")
	check(ctx.view.doc.graph_features().size() == features_before, "no sketch feature was added")
	var status := str(main.status_label.text)
	check(status.contains("nothing was drawn"),
			"status contains nothing was drawn (got %s)" % status)
	check(status.contains("Empty sketch discarded") or status.contains("nothing was drawn"),
			"status explains the empty discard (got %s)" % status)
	main.queue_free()
	await process_frame


func test_exit_sketch_with_geometry() -> void:
	print("- Exit Sketch after a line does not confirm and saves")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "sketch session is open for a line")
	if sm == null or not sm.active:
		main.queue_free()
		await process_frame
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Line start")
	await FilmUI.click_sketch(ctx, sm, Vector2(20, 0), "Line end")
	await process_frame
	var n := 0
	if sm.sketch != null:
		n = sm.sketch.entity_ids().size()
	check(n >= 1, "one committed line exists (%d entities)" % n)
	if sm.has_method("is_empty_new_sketch"):
		check(not sm.is_empty_new_sketch(), "is_empty_new_sketch is false after a line")
	var exit_btn := _find_exit_sketch(main)
	check(exit_btn != null, "Exit Sketch button exists after a line")
	if exit_btn == null:
		main.queue_free()
		await process_frame
		return
	await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
	await process_frame
	await process_frame
	var dlg := _visible_confirm(main)
	check(dlg == null or not dlg.visible, "drawn sketch does not show the empty-sketch dialog")
	check(not sm.active, "Exit Sketch on a drawn sketch leaves sketch mode")
	var status := str(main.status_label.text)
	check(status.contains("Sketch saved"), "status contains Sketch saved (got %s)" % status)
	main.queue_free()
	await process_frame


func test_export_3mf_typed_path() -> void:
	print("- Export 3MF selects the name, types an absolute path, reports it")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	check(body != "", "closed solid exists for export")
	await process_frame
	var dest := ProjectSettings.globalize_path("user://rung01_replan2_shell/typed.3mf")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
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
	# Deferred focus + select_all on the 3MF name field.
	for _i in 4:
		await process_frame
	check(str(dlg.current_file).ends_with(".3mf"),
			"dialog still opens on a .3mf filename default (got %s)" % dlg.current_file)
	check(str(dlg.current_dir) != "", "dialog still opens on a directory default")
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
		main.queue_free()
		await process_frame
		return
	await process_frame
	var selected := edit.get_selected_text()
	check(selected != "" and selected == edit.text,
			"name field selection is the entire suggested name (sel '%s' text '%s')" % [selected, edit.text])
	edit.grab_focus()
	await process_frame
	await _type_text(edit.get_viewport(), dest)
	await process_frame
	check(edit.text == dest or edit.text.ends_with("typed.3mf"),
			"typed absolute path replaced the suggested name (got %s)" % edit.text)
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export dialog OK is visible")
	if ok != null:
		await FilmUI.click_control(ctx, ok, {"keys": "Click", "desc": "Export 3MF OK"})
		await process_frame
		await process_frame
	check(FileAccess.file_exists(dest), "OK writes the typed absolute path %s" % dest)
	var status := str(main.status_label.text)
	check(status == "Exported 3MF → " + dest,
			"status is Exported 3MF → <path> (got %s)" % status)
	if dlg.visible:
		dlg.hide()
	main.queue_free()
	await process_frame
