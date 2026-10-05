# Rung 1 replan 6 WP2 — a bare export name uses the path field, not HOME.
# Types the folder into the Path: LineEdit and does not press Enter there.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan6_export.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const EXPORT_DIR := "/tmp/sx-rung01-replan6-export"
const EXPORT_NAME := "nut.3mf"
const ABS_EXPORT := "/tmp/sx-rung01-replan6-abs/nut-abs.3mf"

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
	print("rung01 replan6 WP2 export")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	var booted: Array = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _build_closed_solid(ctx, main)
	await _test_bare_name_uses_path_field(ctx, main)
	await _test_absolute_path_still_writes(ctx, main)
	await _test_cancel_leaves_process(ctx, main)
	check(main.is_inside_tree(), "process is still running")
	check(FilmUI.fail_count == 0, "FilmUI reported no missing controls")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan6_export.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("set_up_to" + "_face"), "test source has no face-id setter")
	check(not src.contains("set_finish" + "_op"), "test source has no finish-op setter")
	check(not src.contains("set_finish" + "_end"), "test source has no finish-end setter")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	check(not src.contains(".text" + " ="), "test source does not assign LineEdit text")
	check(not src.contains(".value" + " ="), "test source does not assign SpinBox value")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("focus_dim" + "_for_typing"), "test source has no dim typing helper")
	check(not src.contains("focus_distance" + "_for_typing"), "test source has no distance typing helper")
	check(not src.contains("export_3mf" + "("), "test source has no export_3mf call")
	check(not src.contains("infer_enabled" + " = false"), "test source does not disable inference")
	check(not src.contains("current_path" + " ="), "test source does not assign dialog path")
	check(not src.contains("current_dir" + " ="), "test source does not assign dialog dir")
	check(not src.contains("sketch_mode.cancel" + "("), "test source does not call cancel")
	check(not src.contains("sketch_mode.exit_sketch" + "("), "test source does not call exit_sketch")
	check(not src.contains("sketch_mode.trim_at" + "("), "test source does not call trim_at")
	check(not src.contains("new_document" + "("), "test source does not call new_document")
	check(not src.contains("graph_update_sketch" + "("), "test source does not call graph_update_sketch")
	check(not src.contains("dimension_edit_requested" + ".emit"), "test source does not emit dimension_edit")
	check(src.contains("func _x11_" + "click(ctrl"), "test source copies the X11 click helper")
	check(src.contains("func _x11_" + "click_screen(vp"), "test source copies the X11 screen click helper")
	check(src.contains("func _x11_" + "type(vp"), "test source copies the X11 type helper")


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
	await _x11_click_screen(root.get_viewport(), screen)
	await process_frame
	await process_frame
	return true


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


func _dim_edit(main) -> LineEdit:
	var chrome: SketchContextChrome = main.sketch_chrome
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


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


func _path_edit(dlg: FileDialog) -> LineEdit:
	if dlg == null:
		return null
	var name_edit := _name_edit(dlg)
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit == null or edit == name_edit:
			continue
		return edit
	return null


func _wait_dialog(main, frames: int = 8) -> FileDialog:
	for _i in frames:
		await process_frame
	return main.file_dialog as FileDialog


func _norm_dir(p: String) -> String:
	return p.replace("\\", "/").trim_suffix("/")


func _dirs_match(a: String, b: String) -> bool:
	return _norm_dir(a) == _norm_dir(b)


func _x11_enter(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
	await process_frame


func _build_closed_solid(ctx: FilmContext, main) -> void:
	print("- sketch UI, typed radius, finish-bar Extrude")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	if sm == null or not sm.active:
		return
	await _zoom(ctx, Vector3.ZERO, 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Circle centre")
	var dim := _dim_edit(main)
	check(dim != null, "DimLineEdit exists")
	if dim != null:
		await _x11_click(dim)
		await _x11_type(dim.get_viewport(), "10")
		await _x11_enter(dim.get_viewport())
		await process_frame
		await process_frame
	await FilmUI.click_sketch(ctx, sm, Vector2(10, 0), "Circle rim")
	await process_frame
	var chrome: SketchContextChrome = main.sketch_chrome
	var ex: Button = chrome.extrude_button() if chrome != null else null
	check(ex != null and ex.is_visible_in_tree(), "finish-bar Extrude is visible")
	if ex != null:
		await _x11_click(ex)
		await process_frame
		await process_frame
		await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(ids.size() >= 1, "finish-bar Extrude built a closed solid (%d bodies)" % ids.size())


func _test_bare_name_uses_path_field(ctx: FilmContext, main) -> void:
	print("- File → Export 3MF, type folder in Path field (no Enter), bare nut.3mf")
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	var dest := EXPORT_DIR.path_join(EXPORT_NAME)
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	var home := OS.get_environment("HOME").strip_edges()
	var home_file := home.path_join(EXPORT_NAME)
	if FileAccess.file_exists(home_file):
		DirAccess.remove_absolute(home_file)
	check(not _dirs_match(EXPORT_DIR, home), "export directory is not HOME")
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF")
	check(opened, "File → Export 3MF was clicked at its popup rect")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export 3MF dialog is visible")
	if dlg == null or not dlg.visible:
		return
	check(not dlg.use_native_dialog, "Export 3MF does not use the native dialog")
	var path_edit := _path_edit(dlg)
	check(path_edit != null, "Path LineEdit exists (not get_line_edit)")
	if path_edit == null:
		return
	await _x11_click_embedded(path_edit)
	await process_frame
	await _x11_select_all(path_edit.get_viewport())
	await process_frame
	await _x11_type(path_edit.get_viewport(), EXPORT_DIR)
	await process_frame
	var typed_dir := str(path_edit.text).strip_edges()
	check(_dirs_match(typed_dir, EXPORT_DIR),
			"Path field shows typed directory %s (got %s)" % [EXPORT_DIR, typed_dir])
	check(not _dirs_match(str(dlg.current_dir), EXPORT_DIR),
			"current_dir is still not the typed folder (got %s)" % dlg.current_dir)
	var name_edit := _name_edit(dlg)
	check(name_edit != null, "filename LineEdit exists")
	if name_edit == null:
		return
	await _x11_click_embedded(name_edit)
	await process_frame
	await _x11_type(name_edit.get_viewport(), EXPORT_NAME)
	await process_frame
	print("  path field before OK: %s  current_dir: %s" % [
			str(path_edit.text).strip_edges(), dlg.current_dir])
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export OK is visible")
	if ok != null:
		await _x11_click_embedded(ok)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(dest), "OK writes %s" % dest)
	check(not (FileAccess.file_exists(home_file) and not FileAccess.file_exists(dest)),
			"bare name did not land only in HOME")
	var status := str(main.status_label.text)
	var expected_status := "Exported 3MF → " + dest
	check(status == expected_status or (status.begins_with("Exported 3MF → ") and status.contains(dest)),
			"status is Exported 3MF → plus the typed directory and nut.3mf (got %s)" % status)
	check(main.is_inside_tree(), "process still running after path-field bare export")
	if dlg.visible:
		dlg.hide()


func _test_absolute_path_still_writes(ctx: FilmContext, main) -> void:
	print("- second export types an absolute path")
	DirAccess.make_dir_recursive_absolute(ABS_EXPORT.get_base_dir())
	if FileAccess.file_exists(ABS_EXPORT):
		DirAccess.remove_absolute(ABS_EXPORT)
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF (absolute)")
	check(opened, "File → Export 3MF reopened for absolute path")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export dialog is visible for absolute path")
	if dlg == null or not dlg.visible:
		return
	var name_edit := _name_edit(dlg)
	check(name_edit != null, "filename LineEdit exists for absolute path")
	if name_edit == null:
		return
	await _x11_click_embedded(name_edit)
	await process_frame
	await _x11_type(name_edit.get_viewport(), ABS_EXPORT)
	await process_frame
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export OK is visible for absolute path")
	if ok != null:
		await _x11_click_embedded(ok)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(ABS_EXPORT), "absolute path still writes %s" % ABS_EXPORT)
	var status := str(main.status_label.text)
	check(status.begins_with("Exported 3MF → ") and status.contains(ABS_EXPORT),
			"absolute export status contains the typed path (got %s)" % status)
	check(main.is_inside_tree(), "process still running after absolute export")
	if dlg.visible:
		dlg.hide()


func _test_cancel_leaves_process(ctx: FilmContext, main) -> void:
	print("- one Cancel still leaves the process running")
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF (Cancel)")
	check(opened, "File → Export 3MF opened for Cancel")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export dialog is visible for Cancel")
	if dlg == null or not dlg.visible:
		return
	var cancel := dlg.get_cancel_button()
	check(cancel != null and cancel.is_visible_in_tree(), "Export Cancel is visible")
	if cancel != null:
		await _x11_click_embedded(cancel)
		await process_frame
		await process_frame
	check(dlg != null and not dlg.visible, "Cancel hides the Export dialog")
	check(main.is_inside_tree(), "main stays in the tree after Export Cancel")
	print("  note - script continues after Export Cancel")
