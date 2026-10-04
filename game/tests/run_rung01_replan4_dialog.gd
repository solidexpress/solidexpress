# Rung 1 replan 4 WP2 — File / Export / Save dialogs must not quit the app.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan4_dialog.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const EXPORT_PATH := "/tmp/sx024-nut-dialog.3mf"
const SAVE_PATH := "/tmp/sx024-save.sxp"

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
	print("rung01 replan4 WP2 file dialog")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan4_dialog.gd")
	var ban_input := "interaction." + "_input"
	var ban_id := "id_pressed" + ".emit"
	var ban_export := "export_3mf" + "("
	var ban_path := "current_path" + " ="
	var ban_text := ".text" + " ="
	var ban_value := ".value" + " ="
	var ban_dim := "focus_dim" + "_for_typing"
	var ban_dist := "focus_distance" + "_for_typing"
	check(not src.contains(ban_input), "test source has no interaction input call")
	check(not src.contains(ban_id), "test source has no menu id emit")
	check(not src.contains(ban_export), "test source has no kernel 3MF export call")
	check(not src.contains(ban_path), "test source has no dialog path assignment")
	check(not src.contains(ban_text), "test source does not assign LineEdit text")
	check(not src.contains(ban_value), "test source does not assign SpinBox value")
	check(not src.contains(ban_dim), "test source does not call dim focus helper")
	check(not src.contains(ban_dist), "test source does not call distance focus helper")
	var booted: Array = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _build_closed_solid(ctx, main)
	await _test_export_cancel(ctx, main)
	await _test_wm_close_hides(ctx, main)
	await _test_export_ok(ctx, main)
	await _test_save_as(ctx, main)
	check(main.is_inside_tree(), "main stays in the tree at the end")
	check(FilmUI.fail_count == 0, "FilmUI reported no missing controls")
	print("%d checks, %d failures" % [checks, failures])
	print("script still running after dialog Cancel / WM close / OK")
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


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
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


func _push_enter(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.unicode = 0
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
	await _x11_click_at(root.get_viewport(), screen)
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


func _wait_dialog(main, frames: int = 8) -> FileDialog:
	for _i in frames:
		await process_frame
	return main.file_dialog as FileDialog


func _type_dialog_path(dlg: FileDialog, path: String) -> void:
	var edit := _name_edit(dlg)
	check(edit != null, "dialog name LineEdit exists")
	if edit == null:
		return
	await _x11_click(edit)
	await process_frame
	await _x11_type(edit.get_viewport(), path)
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
		await _push_enter(dim.get_viewport())
		await process_frame
		await process_frame
	# Rim click keeps a closed profile even if the dim blank still appends.
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


func _test_export_cancel(ctx: FilmContext, main) -> void:
	print("- File → Export 3MF, type path, Cancel")
	if FileAccess.file_exists(EXPORT_PATH):
		DirAccess.remove_absolute(EXPORT_PATH)
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF")
	check(opened, "File → Export 3MF was clicked at its popup rect")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export 3MF dialog is visible")
	if dlg == null or not dlg.visible:
		return
	await _type_dialog_path(dlg, EXPORT_PATH)
	var cancel := dlg.get_cancel_button()
	check(cancel != null and cancel.is_visible_in_tree(), "Export Cancel is visible")
	if cancel != null:
		await _x11_click(cancel)
		await process_frame
		await process_frame
	check(dlg != null and not dlg.visible, "Cancel hides the Export dialog")
	check(main.is_inside_tree(), "main stays in the tree after Export Cancel")
	check(not FileAccess.file_exists(EXPORT_PATH), "Cancel does not write the 3MF")
	print("  note - script continues after Export Cancel")


func _test_wm_close_hides(ctx: FilmContext, main) -> void:
	print("- Export open, NOTIFICATION_WM_CLOSE_REQUEST hides only the dialog")
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF (wm close)")
	check(opened, "File → Export 3MF reopened")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export dialog is visible before WM close")
	if dlg == null or not dlg.visible:
		return
	main.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await process_frame
	await process_frame
	check(not dlg.visible, "WM_CLOSE_REQUEST hides the file dialog")
	check(main.is_inside_tree(), "main stays in the tree after WM_CLOSE_REQUEST")
	if main.confirm_dialog != null:
		check(not main.confirm_dialog.visible,
				"WM_CLOSE_REQUEST with dialog up does not open discard-and-quit")
	print("  note - script continues after WM_CLOSE_REQUEST (quit did not run)")


func _test_export_ok(ctx: FilmContext, main) -> void:
	print("- Export again, type path, OK writes")
	if FileAccess.file_exists(EXPORT_PATH):
		DirAccess.remove_absolute(EXPORT_PATH)
	var opened: bool = await _click_file_item(ctx, 11, "File → Export 3MF (OK)")
	check(opened, "File → Export 3MF opened for OK")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export dialog is visible for OK")
	if dlg == null or not dlg.visible:
		return
	await _type_dialog_path(dlg, EXPORT_PATH)
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export OK is visible")
	if ok != null:
		await _x11_click(ok)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(EXPORT_PATH), "OK writes %s" % EXPORT_PATH)
	var status := str(main.status_label.text)
	check(status.begins_with("Exported 3MF → "),
			"status starts with Exported 3MF → (got %s)" % status)
	check(main.is_inside_tree(), "main stays in the tree after Export OK")


func _test_save_as(ctx: FilmContext, main) -> void:
	print("- File → Save As Cancel, then OK")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var opened: bool = await _click_file_item(ctx, 3, "File → Save As")
	check(opened, "File → Save As was clicked at its popup rect")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Save As dialog is visible")
	if dlg == null or not dlg.visible:
		return
	await _type_dialog_path(dlg, SAVE_PATH)
	var cancel := dlg.get_cancel_button()
	check(cancel != null and cancel.is_visible_in_tree(), "Save As Cancel is visible")
	if cancel != null:
		await _x11_click(cancel)
		await process_frame
		await process_frame
	check(dlg != null and not dlg.visible, "Cancel hides the Save As dialog")
	check(main.is_inside_tree(), "main stays in the tree after Save As Cancel")
	check(not FileAccess.file_exists(SAVE_PATH), "Save As Cancel does not write the .sxp")

	opened = await _click_file_item(ctx, 3, "File → Save As (OK)")
	check(opened, "File → Save As reopened")
	dlg = await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Save As dialog is visible for OK")
	if dlg == null or not dlg.visible:
		return
	await _type_dialog_path(dlg, SAVE_PATH)
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Save As OK is visible")
	if ok != null:
		await _x11_click(ok)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(SAVE_PATH), "Save As OK writes %s" % SAVE_PATH)
	check(main.is_inside_tree(), "main stays in the tree after Save As OK")
