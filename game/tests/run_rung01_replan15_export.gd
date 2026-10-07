# Rung 1 replan 15 WP4 — Export 3MF keeps the .3mf the user typed.
# Real File-menu click, per-key name, real OK. Pure-function table at the end.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan15_export.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const OUT := "/tmp/sx-replan15"

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
	print("rung01 replan15 WP4 export 3mf extension")
	FilmUI.reset_fail_count()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
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
	await _run(ctx)
	check(FilmUI.fail_count == 0, "FilmUI setup stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run(ctx: FilmContext) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_wipe_out()
	print("- setup: place a box so export_3mf has a body")
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	await process_frame
	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	check(not bodies.is_empty(), "a box body exists for export (got %d)" % bodies.size())

	await _row_absolute(ctx, "T1", "/tmp/sx-replan15/wrench.3mf", "wrench.3mf",
			["wrench.3", "wrench"])
	await _row_absolute(ctx, "T2", "/tmp/sx-replan15/trunc.3", "trunc.3mf",
			["trunc.3", "trunc"])
	await _row_absolute(ctx, "T3", "/tmp/sx-replan15/noext", "noext.3mf",
			["noext"])
	await _row_bare(ctx, "T4", "bare.3mf", "bare.3mf", ["bare"])
	await _row_bare(ctx, "T5", "barenoext", "barenoext.3mf", ["barenoext"])
	await _row_absolute(ctx, "T6", "/tmp/sx-replan15/Upper.3MF", "Upper.3MF",
			["Upper.3MF.3mf", "Upper.3mf"])
	await _row_absolute(ctx, "T7", "/tmp/sx-replan15/two.part.3mf", "two.part.3mf",
			["two.3mf", "two.part"])
	await _row_suggest(ctx)
	_pure_table(ctx.main)


func _wipe_out() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT.path_join(str(f)))


func _clear_home_names(names: Array) -> void:
	var home := OS.get_environment("HOME").strip_edges()
	if home == "":
		return
	for n in names:
		var p := home.path_join(str(n))
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _listing() -> PackedStringArray:
	var names := DirAccess.get_files_at(OUT)
	var sorted: Array[String] = []
	for f in names:
		sorted.append(str(f))
	sorted.sort()
	print("  files at %s: [%s]" % [OUT, ", ".join(sorted)])
	return names


func _assert_files(tag: String, expected_name: String, forbidden: Array) -> void:
	var names := _listing()
	var have := false
	var stray: Array[String] = []
	for f in names:
		var n := str(f)
		if n == expected_name:
			have = true
		else:
			stray.append(n)
	check(have, "%s file %s exists" % [tag, OUT.path_join(expected_name)])
	for bad in forbidden:
		var bad_name := str(bad)
		var present := false
		for f in names:
			if str(f) == bad_name:
				present = true
		check(not present, "%s has no sibling %s" % [tag, bad_name])
	check(stray.is_empty(), "%s listing is only %s (stray: %s)" % [
			tag, expected_name, ", ".join(stray)])


func _status_is(ctx: FilmContext, tag: String, path: String) -> void:
	var status := str(ctx.main.status_label.text)
	print("  %s status: %s" % [tag, status])
	check(status == "Exported 3MF → " + path,
			"%s status is Exported 3MF → %s (got %s)" % [tag, path, status])


func _open_export(ctx: FilmContext, tag: String) -> FileDialog:
	var opened: bool = await _click_menu_item(ctx, "File", 11, "File → Export 3MF (%s)" % tag)
	await process_frame
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "%s Export 3MF opens a FileDialog" % tag)
	if dlg == null or not dlg.visible:
		return null
	for _i in 4:
		await process_frame
	return dlg


func _dismiss_dialog(dlg: FileDialog) -> void:
	if dlg != null and is_instance_valid(dlg) and dlg.visible:
		dlg.hide()
	await process_frame


func _type_into_name(dlg: FileDialog, text: String) -> String:
	var edit := _dialog_name_edit(dlg)
	check(edit != null, "Export 3MF name LineEdit exists")
	if edit == null:
		return ""
	await _x11_click_embedded(edit)
	await process_frame
	await _x11_select_all(edit.get_viewport())
	await process_frame
	await _type_name_keys(edit.get_viewport(), text)
	await process_frame
	await process_frame
	return str(edit.text)


func _press_ok(ctx: FilmContext, dlg: FileDialog, tag: String) -> void:
	var ok_btn := dlg.get_ok_button()
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "%s export OK is visible" % tag)
	if ok_btn == null:
		return
	await _x11_click_embedded(ok_btn)
	var status := ""
	for _i in 40:
		await process_frame
		status = str(ctx.main.status_label.text)
		if status.begins_with("Exported 3MF") or status.begins_with("3MF export failed"):
			break
	check(ctx.main.is_inside_tree(), "%s main stays in the tree after export OK" % tag)


func _row_absolute(ctx: FilmContext, tag: String, typed: String, expected_name: String, forbidden: Array) -> void:
	print("- %s type %s" % [tag, typed])
	_wipe_out()
	_clear_home_names([expected_name] + forbidden)
	var dlg := await _open_export(ctx, tag)
	if dlg == null:
		_assert_files(tag, expected_name, forbidden)
		return
	var field := await _type_into_name(dlg, typed)
	print("  %s field before OK: '%s' (typed '%s')" % [tag, field, typed])
	check(field == typed, "%s name field holds the typed text (got '%s')" % [tag, field])
	await _press_ok(ctx, dlg, tag)
	_status_is(ctx, tag, OUT.path_join(expected_name))
	_assert_files(tag, expected_name, forbidden)
	await _dismiss_dialog(dlg)


func _row_bare(ctx: FilmContext, tag: String, typed: String, expected_name: String, forbidden: Array) -> void:
	print("- %s bare %s in %s" % [tag, typed, OUT])
	_wipe_out()
	var home_names: Array = [typed, expected_name]
	for bad in forbidden:
		home_names.append(bad)
	_clear_home_names(home_names)
	var dlg := await _open_export(ctx, tag)
	if dlg == null:
		_assert_files(tag, expected_name, forbidden)
		return
	print("  export: typed folder into Path field (no Enter), then bare filename %s" % typed)
	await _export_bare_via_path_field(dlg, OUT, typed)
	var edit := _dialog_name_edit(dlg)
	var field := str(edit.text) if edit != null else ""
	print("  %s field before OK: '%s' (typed '%s')" % [tag, field, typed])
	check(field == typed, "%s name field holds the bare name (got '%s')" % [tag, field])
	await _press_ok(ctx, dlg, tag)
	var expect_path := OUT.path_join(expected_name)
	_status_is(ctx, tag, expect_path)
	_assert_files(tag, expected_name, forbidden)
	var home := OS.get_environment("HOME").strip_edges()
	var home_file := home.path_join(expected_name)
	var home_typed := home.path_join(typed)
	check(not _dirs_match(OUT, home), "%s bare export directory is not HOME" % tag)
	check(not FileAccess.file_exists(home_file), "%s did not write %s" % [tag, home_file])
	check(not FileAccess.file_exists(home_typed) or typed == expected_name,
			"%s did not write unsuffixed %s" % [tag, home_typed])
	await _dismiss_dialog(dlg)


func _row_suggest(ctx: FilmContext) -> void:
	print("- T8 second export suggests a .3mf name in the previous directory")
	var dlg := await _open_export(ctx, "T8")
	if dlg == null:
		return
	var suggested := str(dlg.current_file)
	var dir := str(dlg.current_dir)
	print("  T8 current_file: '%s'  current_dir: '%s'" % [suggested, dir])
	check(suggested.ends_with(".3mf"),
			"T8 dialog suggests a .3mf name (got %s)" % suggested)
	check(_dirs_match(dir, OUT),
			"T8 dialog reopens in the previous directory %s (got %s)" % [OUT, dir])
	var cancel := dlg.get_cancel_button()
	check(cancel != null, "T8 export Cancel button exists")
	if cancel != null:
		await _x11_click_embedded(cancel)
		await process_frame
		await process_frame
	await _dismiss_dialog(dlg)


func _pure_table(main) -> void:
	print("- P1 _with_3mf_extension")
	var rows: Array = [
		["/tmp/a/wrench.3mf", "/tmp/a/wrench.3mf"],
		["/tmp/a/Wrench.3MF", "/tmp/a/Wrench.3MF"],
		["/tmp/a/wrench.3", "/tmp/a/wrench.3mf"],
		["/tmp/a/wrench.3m", "/tmp/a/wrench.3mf"],
		["/tmp/a/wrench", "/tmp/a/wrench.3mf"],
		["/tmp/a/wrench.", "/tmp/a/wrench.3mf"],
		["/tmp/a/my.part.v2", "/tmp/a/my.part.v2.3mf"],
		["/tmp/a.b/wrench", "/tmp/a.b/wrench.3mf"],
		["C:\\tmp\\wrench.3", "C:\\tmp\\wrench.3mf"],
		["", ""],
	]
	var has: bool = main.has_method("_with_3mf_extension")
	check(has, "main.has_method(\"_with_3mf_extension\")")
	if not has:
		for row in rows:
			check(false, "P1 `%s` -> `%s` (missing _with_3mf_extension)" % [row[0], row[1]])
		return
	for row in rows:
		var got: String = main._with_3mf_extension(row[0])
		check(got == str(row[1]), "P1 `%s` -> `%s` (got `%s`)" % [row[0], row[1], got])


func _x11_char_supported(ch: int) -> bool:
	if ch >= 48 and ch <= 57:
		return true
	if ch >= 97 and ch <= 122:
		return true
	if ch == 46 or ch == 45 or ch == 47:
		return true
	return false


## Lowercase / digit / . - / go through the copied `_x11_type`. Uppercase is
## the same key event with shift, because that helper rejects A–Z.
func _type_name_keys(vp: Viewport, text: String) -> void:
	var i := 0
	while i < text.length():
		var ch := text.unicode_at(i)
		if _x11_char_supported(ch):
			var j := i + 1
			while j < text.length() and _x11_char_supported(text.unicode_at(j)):
				j += 1
			await _x11_type(vp, text.substr(i, j - i))
			i = j
		elif ch >= 65 and ch <= 90:
			var code := (KEY_A + (ch - 65)) as Key
			var ev := InputEventKey.new()
			ev.keycode = code
			ev.physical_keycode = code
			ev.unicode = ch
			ev.shift_pressed = true
			ev.pressed = true
			ev.echo = false
			vp.push_input(ev)
			var rel := ev.duplicate() as InputEventKey
			rel.pressed = false
			rel.unicode = 0
			vp.push_input(rel)
			await process_frame
			i += 1
		else:
			push_error("no X11 key for U+%X" % ch)
			check(false, "can type U+%X" % ch)
			return


func _dialog_name_edit(dlg: FileDialog) -> LineEdit:
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


func _dialog_path_edit(dlg: FileDialog) -> LineEdit:
	if dlg == null:
		return null
	var name_edit := _dialog_name_edit(dlg)
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit == null or edit == name_edit:
			continue
		return edit
	return null


func _export_bare_via_path_field(dlg: FileDialog, target_dir: String, name: String) -> void:
	var path_edit := _dialog_path_edit(dlg)
	check(path_edit != null, "Path LineEdit exists (not get_line_edit)")
	if path_edit == null:
		return
	await _x11_click_embedded(path_edit)
	await process_frame
	await _x11_select_all(path_edit.get_viewport())
	await process_frame
	# The walk asserts current_dir is not the typed folder because that dialog
	# opens in HOME. This suite's dialog is already in OUT after earlier rows,
	# so the invariant is: typing the path leaves current_dir unchanged.
	var dir_before := str(dlg.current_dir)
	await _x11_type(path_edit.get_viewport(), target_dir)
	await process_frame
	var typed_dir := str(path_edit.text).strip_edges()
	check(_dirs_match(typed_dir, target_dir),
			"Path field shows typed directory %s (got %s)" % [target_dir, typed_dir])
	check(_dirs_match(str(dlg.current_dir), dir_before),
			"typing the Path field leaves current_dir unchanged (before %s, now %s)" % [
				dir_before, dlg.current_dir])
	print("  path field before OK: %s  current_dir: %s" % [typed_dir, dlg.current_dir])
	var name_edit := _dialog_name_edit(dlg)
	check(name_edit != null, "filename LineEdit exists")
	if name_edit == null:
		return
	await _x11_click_embedded(name_edit)
	await process_frame
	await _x11_select_all(name_edit.get_viewport())
	await process_frame
	await _x11_type(name_edit.get_viewport(), name)
	await process_frame


func _norm_dir(p: String) -> String:
	return p.replace("\\", "/").trim_suffix("/")


func _dirs_match(a: String, b: String) -> bool:
	return _norm_dir(a) == _norm_dir(b)


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
	await _x11_click_screen(root.get_viewport(), screen)
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
	var center := FilmUI.ensure_control_visible(btn)
	check(FilmUI.is_on_screen(ctx, center), "%s menu is on screen for %s" % [title, desc])
	await _x11_click(btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	var t0 := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t0 < 450:
		await process_frame
	if popup == null or not popup.visible:
		check(false, "%s popup is visible after click (%s)" % [title, desc])
		return false
	return await _click_popup_item(popup, id, desc)


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)


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


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 47:
			code = KEY_SLASH
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
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


func _x11_click_at(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	await _x11_click_screen(vp, pos, double_click)


## Embedded FileDialog only sees the click on the root viewport, in screen
## space (push_input on the dialog Window does not hit Cancel/OK/name).
## Same-burst X11 sequence as `_x11_click`.
func _x11_click_embedded(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + pos
	await _x11_click_at(root.get_viewport(), pos)
