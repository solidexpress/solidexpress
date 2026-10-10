# Rung 1 replan WP4 — status line, Esc backup, Export 3MF dialog.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan_shell.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")


func _init() -> void:
	print("rung01 replan shell (WP4)")
	FilmUI.reset_fail_count()
	await test_export_dialog()
	await test_unhandled_esc()
	await test_dim_rejected_status()
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
	await FilmUI.ensure_test_viewport(ctx)
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


func _norm_dir(path: String) -> String:
	var s := path.replace("\\", "/").strip_edges()
	while s.ends_with("/") and s.length() > 1:
		s = s.substr(0, s.length() - 1)
	return s


func _dirs_match(a: String, b: String) -> bool:
	return _norm_dir(a) == _norm_dir(b)


func _open_export(main, ctx: FilmContext) -> bool:
	var file_btn := _file_button(main)
	if file_btn == null or not file_btn.is_visible_in_tree():
		check(false, "File menu button is visible")
		return false
	var opened: bool = await FilmUI.activate_menu_id(ctx, file_btn, 11,
			{"keys": "Click", "desc": "File → Export 3MF"})
	await process_frame
	return opened


func _confirm_dialog(ctx: FilmContext, dlg: FileDialog) -> bool:
	var ok := dlg.get_ok_button()
	if ok == null or not ok.is_visible_in_tree():
		check(false, "Export dialog OK button is visible")
		return false
	return await FilmUI.click_control(ctx, ok, {"keys": "Click", "desc": "Export dialog OK"})


func test_export_dialog() -> void:
	print("- Export 3MF dialog defaults, confirm, and status")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	var file_btn := _file_button(main)
	check(file_btn != null, "File menu button exists")
	if file_btn == null:
		main.queue_free()
		await process_frame
		return
	file_btn.get_popup().id_pressed.emit(0)
	await process_frame
	check(str(main.current_path) == "", "New leaves the document nameless")

	var opened: bool = await _open_export(main, ctx)
	var dlg: FileDialog = main.file_dialog
	check(opened and dlg != null and dlg.visible, "File menu id 11 opens a visible FileDialog")
	if dlg == null or not dlg.visible:
		main.queue_free()
		await process_frame
		return
	check(str(dlg.current_file).ends_with(".3mf"),
			"nameless current_file ends in .3mf (got %s)" % dlg.current_file)
	check(str(dlg.current_file) == "part.3mf",
			"nameless document suggests part.3mf (got %s)" % dlg.current_file)
	var home := OS.get_environment("HOME").strip_edges()
	if home == "":
		home = OS.get_environment("USERPROFILE").strip_edges()
	check(_dirs_match(str(dlg.current_dir), home),
			"nameless current_dir is home (got %s, home %s)" % [dlg.current_dir, home])
	dlg.hide()
	await process_frame

	var doc_dir := "/tmp/sx-rung01-replan-doc"
	DirAccess.make_dir_recursive_absolute(doc_dir)
	main.current_path = doc_dir.path_join("nut.sxp")
	opened = await _open_export(main, ctx)
	check(opened and dlg.visible, "Export 3MF reopens for a named document")
	check(str(dlg.current_file) == "nut.3mf",
			"named document suggests nut.3mf (got %s)" % dlg.current_file)
	check(_dirs_match(str(dlg.current_dir), doc_dir),
			"named document opens in its directory (got %s)" % dlg.current_dir)
	dlg.hide()
	await process_frame
	main.current_path = ""

	# Empty part: the write returns false. Status must not claim success.
	opened = await _open_export(main, ctx)
	check(opened and dlg.visible, "Export 3MF opens on an empty part")
	var fail_path := ProjectSettings.globalize_path("user://rung01_replan_shell/empty.3mf")
	DirAccess.make_dir_recursive_absolute(fail_path.get_base_dir())
	if FileAccess.file_exists(fail_path):
		DirAccess.remove_absolute(fail_path)
	dlg.current_path = fail_path
	var confirmed: bool = await _confirm_dialog(ctx, dlg)
	await process_frame
	check(confirmed, "empty-part dialog OK was pressed")
	var fail_status := str(main.status_label.text)
	check(fail_status.begins_with("3MF export failed — "),
			"false export status is 3MF export failed — (got %s)" % fail_status)
	check(not fail_status.contains("Exported 3MF"),
			"false export does not say Exported 3MF (got %s)" % fail_status)
	check(not FileAccess.file_exists(fail_path), "failed export leaves no file")
	if dlg.visible:
		dlg.hide()
	await process_frame

	opened = await _open_export(main, ctx)
	check(_dirs_match(str(dlg.current_dir), home),
			"failed export does not stick as the next directory (got %s)" % dlg.current_dir)
	if dlg.visible:
		dlg.hide()

	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	check(body != "", "closed solid exists for a successful export")
	await process_frame
	opened = await _open_export(main, ctx)
	check(opened and dlg.visible, "Export 3MF opens for a closed solid")
	check(str(dlg.current_file).ends_with(".3mf"),
			"closed-solid current_file ends in .3mf (got %s)" % dlg.current_file)
	var dest := ProjectSettings.globalize_path("user://rung01_replan_shell/closed.3mf")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	dlg.current_path = dest
	# OK reads the filename LineEdit, not current_path alone.
	var name_edit: LineEdit = null
	if dlg.has_method("get_line_edit"):
		var le: Variant = dlg.get_line_edit()
		if le is LineEdit:
			name_edit = le
	if name_edit != null:
		name_edit.text = dest.get_file()
	# OK snapshots the filename on button_down, while the dialog is visible.
	var ok_pre := dlg.get_ok_button()
	if ok_pre != null:
		ok_pre.button_down.emit()
	check(_dirs_match(str(dlg.current_path), dest) or str(dlg.current_file) == dest.get_file(),
			"dialog current_path points at the globalized user file (got %s)" % dlg.current_path)
	confirmed = await _confirm_dialog(ctx, dlg)
	await process_frame
	check(confirmed, "closed-solid dialog OK was pressed")
	check(FileAccess.file_exists(dest), "dialog OK wrote %s" % dest)
	var ok_status := str(main.status_label.text)
	check(ok_status.contains("Exported 3MF"),
			"closed solid status contains Exported 3MF (got %s)" % ok_status)
	if dlg.visible:
		dlg.hide()
	await process_frame

	opened = await _open_export(main, ctx)
	check(opened and dlg.visible, "next Export 3MF opens after a success")
	check(_dirs_match(str(dlg.current_dir), dest.get_base_dir()),
			"next export opens in the last export directory (got %s)" % dlg.current_dir)
	if dlg.visible:
		dlg.hide()
	main.queue_free()
	await process_frame


func _push_key_local(vp: Viewport, keycode: Key, unicode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = pressed
	ev.echo = false
	vp.push_input(ev)


func test_unhandled_esc() -> void:
	print("- Esc after TriBall, without Interaction focus, clears the selection")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	var file_btn := _file_button(main)
	if file_btn != null:
		file_btn.get_popup().id_pressed.emit(0)
		await process_frame
	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(30, 20, 8))
	await process_frame
	await process_frame
	check(body != "" and main.view.selected_body == body, "box is selected before TriBall")
	var ix: ViewportInteraction = main.interaction
	ix._refresh_selection_strip()
	await process_frame
	var tb_btn: Button = ix._strip_triball
	check(tb_btn != null and tb_btn.is_visible_in_tree(), "TriBall strip button is visible")
	var clicked: bool = await FilmUI.click_control(ctx, tb_btn,
			{"keys": "Click", "desc": "Arm TriBall"})
	check(clicked, "TriBall button was pressed")
	var tb = ix.triball
	check(tb != null and tb.active and tb.visible, "TriBall is armed")
	# The strip button takes focus. Do not hand focus back to Interaction;
	# Esc must arrive as an unhandled key.
	tb_btn.grab_focus()
	await process_frame
	var focus := ix.get_viewport().gui_get_focus_owner()
	check(focus != ix and not ix.has_focus(),
			"focus stays off Interaction (owner %s)" % str(focus))
	var vp := ix.get_viewport()
	_push_key_local(vp, KEY_ESCAPE, 0, true)
	await process_frame
	_push_key_local(vp, KEY_ESCAPE, 0, false)
	await process_frame
	check(tb == null or (not tb.active and not tb.visible), "unhandled Esc clears TriBall")
	check(main.view.selected_body == "", "unhandled Esc clears the selection")
	check(ix._selection_strip == null or not ix._selection_strip.visible,
			"unhandled Esc hides the selection strip")
	main.queue_free()
	await process_frame


func test_dim_rejected_status() -> void:
	print("- dim_rejected reaches the status line")
	var booted = await _boot()
	var main = booted[0]
	var chrome = main.sketch_chrome
	if chrome == null or not chrome.has_signal("dim_rejected"):
		check(false, "WP1 gap: SketchContextChrome.dim_rejected is absent, so status cannot show Cannot read dimension")
		main.queue_free()
		await process_frame
		return
	var raw := "23.22.5"
	chrome.dim_rejected.emit(raw)
	await process_frame
	var text := str(main.status_label.text)
	check(text.contains("Cannot read dimension: " + raw),
			"status shows rejected dimension (got %s)" % text)
	main.queue_free()
	await process_frame
