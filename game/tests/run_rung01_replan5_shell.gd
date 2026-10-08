# Rung 1 replan 5 WP2 — Exit / Undo / New recover; bare export uses dialog folder.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan5_shell.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const EXPORT_DIR := "/tmp/sx-replan5-wp2-export"
const EXPORT_NAME := "nut.3mf"
const ABS_EXPORT := "/tmp/sx-replan5-wp2-abs/nut-abs.3mf"
const FAILED_SKETCH := "Failed to update sketch"
const NEW_SENTENCE := "New — empty part, Top plane (XY). View ▸ Timeline to edit features"

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
	print("rung01 replan5 WP2 shell")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan5_shell.gd")
	var ban_input := "interaction." + "_input"
	var ban_id := "id_pressed" + ".emit"
	var ban_face := "set_up_to" + "_face"
	var ban_fop := "set_finish" + "_op"
	var ban_fend := "set_finish" + "_end"
	var ban_dist := "set_extrude" + "_distance"
	var ban_text := ".text" + " ="
	var ban_value := ".value" + " ="
	var ban_submit := "text_submitted" + ".emit"
	var ban_dim := "focus_dim" + "_for_typing"
	var ban_dfocus := "focus_distance" + "_for_typing"
	var ban_export := "export_3mf" + "("
	var ban_infer := "infer_enabled" + "=" + "false"
	var ban_cpath := "current_path" + "="
	var ban_cdir := "current_dir" + "="
	var ban_cancel := "sketch_mode" + ".cancel("
	var ban_exit := "sketch_mode" + ".exit_sketch("
	var ban_trim := "sketch_mode" + ".trim_at("
	var ban_new := "new_document" + "("
	var ban_update := "graph_update_sketch" + "("
	check(not src.contains(ban_input), "test source has no interaction input call")
	check(not src.contains(ban_id), "test source has no menu id emit")
	check(not src.contains(ban_face), "test source has no face-id setter")
	check(not src.contains(ban_fop), "test source has no finish-op setter")
	check(not src.contains(ban_fend), "test source has no finish-end setter")
	check(not src.contains(ban_dist), "test source has no distance setter")
	check(not src.contains(ban_text), "test source does not assign LineEdit text")
	check(not src.contains(ban_value), "test source does not assign SpinBox value")
	check(not src.contains(ban_submit), "test source has no text_submitted emit")
	check(not src.contains(ban_dim), "test source does not call dim focus helper")
	check(not src.contains(ban_dfocus), "test source does not call distance focus helper")
	check(not src.contains(ban_export), "test source has no kernel 3MF export call")
	check(not src.contains(ban_infer), "test source does not disable infer")
	check(not src.contains(ban_cpath), "test source has no dialog path assignment")
	check(not src.contains(ban_cdir), "test source has no dialog dir assignment")
	check(not src.contains(ban_cancel), "test source does not call sketch cancel")
	check(not src.contains(ban_exit), "test source does not call sketch exit")
	check(not src.contains(ban_trim), "test source does not call sketch trim")
	check(not src.contains(ban_new), "test source does not call new_document")
	check(not src.contains(ban_update), "test source does not call graph_update_sketch")
	var booted: Array = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _test_exit_after_open_profile(ctx, main)
	await _test_undo_then_exit(ctx, main)
	await _test_file_new_then_circle(ctx, main)
	await _test_bare_export_uses_dialog_folder(ctx, main)
	check(main.is_inside_tree(), "process still running after export")
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


func _push_key(vp: Viewport, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _status(main) -> String:
	if main.status_label == null:
		return ""
	return str(main.status_label.text)


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
			top += panel.get_margin(SIDE_TOP)
	for i in index:
		top += _popup_row_height(popup, i, font_h, v_sep)
	var row_h := _popup_row_height(popup, index, font_h, v_sep)
	var local := Vector2(popup.size.x * 0.5, top + row_h * 0.5)
	return Vector2(popup.position) + local


func _click_menu_item(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button is visible for %s" % [title, desc])
		return false
	await _x11_click(btn)
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


func _click_sketch_uv(ctx: FilmContext, uv: Vector2) -> void:
	var screen := FilmUI.sketch_uv_to_screen(ctx, uv)
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame


func _click_tool(ctx: FilmContext, label: String) -> void:
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(b != null and b.is_visible_in_tree(), "%s tool is visible" % label)
	if b != null:
		await _x11_click(b)
		await process_frame


func _exit_btn(main) -> Button:
	return FilmUI.find_sketch_tool_button(main, "Exit Sketch")


func _click_exit(ctx: FilmContext) -> void:
	var btn := _exit_btn(ctx.main)
	check(btn != null and btn.is_visible_in_tree(), "Exit Sketch button is visible")
	if btn == null:
		return
	var n: Node = btn
	while n != null:
		if n is ScrollContainer:
			(n as ScrollContainer).scroll_vertical = 0
			(n as ScrollContainer).ensure_control_visible(btn)
		n = n.get_parent()
	await process_frame
	await process_frame
	var r: Rect2 = btn.get_global_rect()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400 and (r.size.x < 8.0 or r.position.x < 1.0):
		await process_frame
		r = btn.get_global_rect()
	check(r.size.x > 8.0 and r.position.x > 1.0, "Exit Sketch clickable at %s" % r)
	var vp: Viewport = ctx.main.get_viewport()
	# Finish-bar DimLineEdit can sit on the Exit label at 1280×800. Click the
	# icon (left) side of the button so the press hits Exit Sketch.
	var pos := Vector2(r.position.x + 16.0, r.get_center().y)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null:
		var dim: Control = chrome.find_child("DimLineEdit", true, false) as Control
		if dim != null and dim.is_visible_in_tree():
			var dr: Rect2 = dim.get_global_rect()
			if dr.has_point(pos):
				pos = Vector2(r.position.x + 10.0, r.position.y + 10.0)
				if dr.has_point(pos):
					pos = Vector2(r.end.x - 8.0, r.position.y + 8.0)
	await _x11_click_screen(vp, pos)
	await process_frame
	await process_frame
	await process_frame


func _enter_ground_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		return
	var b := FilmUI.find_palette_sketch_button(ctx.main)
	check(b != null and b.is_visible_in_tree(), "Sketch palette button is visible")
	if b != null:
		await _x11_click(b)
		await process_frame
		await process_frame
	var ground := FilmUI.model_to_screen(ctx, Vector3(22, 18, 0))
	if not FilmUI.is_on_screen(ctx, ground):
		ground = FilmUI.viewport_empty_click_pos(ctx)
	await _x11_click_screen(ctx.main.get_viewport(), ground)
	await process_frame
	await process_frame
	await process_frame


func _draw_rectangle(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open for rectangle")
	if sm == null or not sm.active:
		return
	await _zoom(ctx, Vector3.ZERO, 80.0)
	await _click_tool(ctx, "Rectangle")
	await _click_sketch_uv(ctx, Vector2(-20, -15))
	await _click_sketch_uv(ctx, Vector2(20, 15))
	await process_frame
	var n := 0
	if sm.sketch != null:
		n = sm.sketch.entity_ids().size()
	check(n >= 4, "rectangle has four sides (%d entities)" % n)


func _finish_extrude(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var ex: Button = chrome.extrude_button() if chrome != null else null
	check(ex != null and ex.is_visible_in_tree(), "finish-bar Extrude is visible")
	if ex != null:
		await _x11_click(ex)
		await process_frame
		await process_frame
		await process_frame


func _show_timeline(ctx: FilmContext) -> void:
	if ctx.main.show_timeline:
		ctx.main._update_panel_visibility()
		await process_frame
		return
	var opened: bool = await _click_menu_item(ctx, "View", 4, "View → Timeline")
	await process_frame
	await process_frame
	check(opened and ctx.main.show_timeline, "View → Timeline opened by clicking the popup row")


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null


func _sketch_feature_id(ctx: FilmContext) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			return str(f.get("id", ""))
	return ""


func _reopen_sketch_from_timeline(ctx: FilmContext) -> void:
	await _show_timeline(ctx)
	var tl: TimelinePanel = ctx.main.timeline
	check(tl != null and tl.visible, "timeline is visible")
	if tl == null:
		return
	tl.refresh()
	await process_frame
	await process_frame
	var fid := _sketch_feature_id(ctx)
	check(fid != "", "sketch feature exists on the timeline")
	var btn := _row_name_button(tl, fid)
	check(btn != null and btn.is_visible_in_tree(), "sketch row name is visible")
	if btn == null:
		return
	var pos := btn.get_global_rect().get_center()
	await _x11_click_screen(ctx.main.get_viewport(), pos)
	await process_frame
	# The first click selects the feature. Timeline docks under the chip row
	# while a body is selected, so the sketch row can move before the second
	# press. Sample the row again or the double-click lands on Extrude.
	btn = _row_name_button(tl, fid)
	if btn != null:
		pos = btn.get_global_rect().get_center()
	await _x11_click_screen(ctx.main.get_viewport(), pos, true)
	await process_frame
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "timeline double-click reopened the sketch")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		var exit_btn := _exit_btn(ctx.main)
		if exit_btn != null and exit_btn.is_visible_in_tree():
			break
		await process_frame
	if sm != null and sm.active:
		await _zoom(ctx, Vector3.ZERO, 80.0)


func _delete_one_edge(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "session is active before deleting an edge")
	if sm == null or not sm.active:
		return
	await _click_tool(ctx, "Select")
	await _click_sketch_uv(ctx, Vector2(0, -15))
	await process_frame
	check(not sm.selected.is_empty(), "one rectangle edge is selected")
	await _push_key(ctx.main.get_viewport(), KEY_DELETE)
	await process_frame
	await process_frame
	var n := 0
	if sm.sketch != null:
		n = sm.sketch.entity_ids().size()
	check(n == 3, "deleting one edge leaves three entities (got %d)" % n)


func _body_count(ctx: FilmContext) -> int:
	return ctx.view.doc.body_ids().size()


func _click_discard_ok(ctx: FilmContext) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		var dlg: ConfirmationDialog = ctx.main.confirm_dialog
		if dlg != null and dlg.visible:
			var ok := dlg.get_ok_button()
			check(ok != null and ok.is_visible_in_tree(), "Discard OK is visible")
			if ok != null:
				await _x11_click_embedded(ok)
			await process_frame
			await process_frame
			return
		await process_frame
	check(false, "Discard unsaved changes dialog is visible")


func _build_rect_extrude(ctx: FilmContext) -> void:
	await _enter_ground_sketch(ctx)
	await _draw_rectangle(ctx)
	await _finish_extrude(ctx)
	check(_body_count(ctx) >= 1, "Extrude built a body")


func _test_exit_after_open_profile(ctx: FilmContext, main) -> void:
	print("- rectangle, Extrude, reopen, delete edge, Exit Sketch")
	await _build_rect_extrude(ctx)
	var bodies := _body_count(ctx)
	await _reopen_sketch_from_timeline(ctx)
	await _delete_one_edge(ctx)
	await _click_exit(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and not sm.active, "Exit Sketch leaves sketch_mode.active false")
	var status := _status(main)
	check(not status.contains(FAILED_SKETCH),
			"Exit status does not contain Failed to update sketch (got %s)" % status)
	check(_body_count(ctx) == bodies, "body is still there after discarded open-profile Exit")


func _test_undo_then_exit(ctx: FilmContext, main) -> void:
	print("- reopen, delete edge, Edit → Undo, Exit Sketch")
	await _reopen_sketch_from_timeline(ctx)
	await _delete_one_edge(ctx)
	var opened: bool = await _click_menu_item(ctx, "Edit", 0, "Edit → Undo")
	check(opened, "Edit → Undo was clicked at its popup rect")
	await process_frame
	await process_frame
	await _click_exit(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and not sm.active, "Undo then Exit leaves active false")
	var status := _status(main)
	check(not status.contains(FAILED_SKETCH),
			"Undo+Exit status does not contain Failed to update sketch (got %s)" % status)


func _test_file_new_then_circle(ctx: FilmContext, main) -> void:
	print("- open-profile session, File → New, ground circle")
	await _reopen_sketch_from_timeline(ctx)
	await _delete_one_edge(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "session is left active on an open profile")
	var opened: bool = await _click_menu_item(ctx, "File", 0, "File → New")
	check(opened, "File → New was clicked at its popup rect")
	await _click_discard_ok(ctx)
	await process_frame
	await process_frame
	var status := _status(main)
	check(status == NEW_SENTENCE, "status is the New sentence (got %s)" % status)
	check(not status.contains(FAILED_SKETCH),
			"New status does not contain Failed to update sketch (got %s)" % status)
	check(sm != null and not sm.active, "File → New leaves sketch_mode.active false")
	check(ctx.view.doc.graph_features().is_empty(), "New document has no graph features")
	await _enter_ground_sketch(ctx)
	check(sm != null and sm.active, "ground sketch starts after New")
	await _zoom(ctx, Vector3.ZERO, 80.0)
	await _click_tool(ctx, "Circle")
	await _click_sketch_uv(ctx, Vector2.ZERO)
	await _click_sketch_uv(ctx, Vector2(10, 0))
	await process_frame
	status = _status(main)
	check(status.contains("Circle"), "status contains Circle after drawing (got %s)" % status)


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


func _dirs_match(a: String, b: String) -> bool:
	return _norm_dir(a) == _norm_dir(b)


func _norm_dir(p: String) -> String:
	var s := p.replace("\\", "/").strip_edges()
	if s == "/":
		return "/"
	return s.trim_suffix("/")


func _dialog_dir(dlg: FileDialog) -> String:
	return _norm_dir(str(dlg.current_dir))


func _find_dir_up(dlg: FileDialog) -> Button:
	for c in dlg.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		var tip := str(b.tooltip_text).to_lower()
		var txt := str(b.text).to_lower()
		if tip.find("parent") >= 0 or txt == ".." or tip.find("up") >= 0:
			return b
	return null


func _list_dialog_names(dlg: FileDialog) -> PackedStringArray:
	var names := PackedStringArray()
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
		if item.get_child_count() > 0:
			item = item.get_first_child()
		else:
			item = item.get_next_in_tree()
		while item != null:
			names.append(item.get_text(0))
			item = item.get_next()
	return names


func _wheel_list(lst: Control, down: bool) -> void:
	var pos := lst.size * 0.5
	if lst.has_method("get_screen_position"):
		pos = lst.get_screen_position() + lst.size * 0.5
	var vp := root.get_viewport()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventMouseButton
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _itemlist_vscroll(lst: ItemList) -> VScrollBar:
	for c in lst.find_children("*", "VScrollBar", true, false):
		var sb := c as VScrollBar
		if sb != null and sb.is_visible_in_tree():
			return sb
	return null


func _click_dialog_row(dlg: FileDialog, needle: String) -> bool:
	var want := needle.to_lower()
	for c in dlg.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		if str(b.text).to_lower() == want:
			await _x11_click_embedded(b)
			await process_frame
			await process_frame
			return true
	for c in dlg.find_children("*", "ItemList", true, false):
		var lst := c as ItemList
		if lst == null or not lst.is_visible_in_tree():
			continue
		for i in lst.item_count:
			var text := lst.get_item_text(i)
			if text.to_lower() != want and not text.to_lower().ends_with("/" + want):
				continue
			lst.select(i)
			if lst.has_method("ensure_current_is_visible"):
				lst.ensure_current_is_visible()
			await process_frame
			await process_frame
			var sb := _itemlist_vscroll(lst)
			var rect: Rect2 = lst.get_item_rect(i)
			var center := rect.position + rect.size * 0.5
			if sb != null:
				center.y -= sb.value
			if center.y < 2.0 or center.y > lst.size.y - 2.0:
				# Thumbnails keep content-space rects; scroll until the icon is in view.
				for _w in 24:
					rect = lst.get_item_rect(i)
					center = rect.position + rect.size * 0.5
					if sb != null:
						center.y = rect.position.y + rect.size.y * 0.5 - sb.value
					if center.y >= 4.0 and center.y <= lst.size.y - 4.0:
						break
					await _wheel_list(lst, center.y > lst.size.y * 0.5)
					if sb != null:
						sb = _itemlist_vscroll(lst)
			await _x11_click_embedded_at(lst, center)
			await process_frame
			await _x11_click_embedded_at(lst, center, true)
			await process_frame
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
				await _x11_click_embedded_at(tree, local, true)
				await process_frame
				await process_frame
				return true
			item = item.get_next_in_tree()
	return false


func _click_into_export_dir(dlg: FileDialog) -> bool:
	var target := EXPORT_DIR.replace("\\", "/").trim_suffix("/")
	var folder := target.get_file()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		var here := _dialog_dir(dlg)
		if _dirs_match(here, target):
			return true
		if _dirs_match(here, "/tmp") or _dirs_match(here, target.get_base_dir()):
			if await _click_dialog_row(dlg, folder):
				await process_frame
				await process_frame
				continue
		elif _dirs_match(here, "/") or here == "":
			if await _click_dialog_row(dlg, "tmp"):
				await process_frame
				await process_frame
				continue
		elif here.begins_with(target + "/"):
			var up := _find_dir_up(dlg)
			if up != null:
				await _x11_click_embedded(up)
				await process_frame
				await process_frame
				continue
		else:
			if await _click_dialog_row(dlg, "tmp"):
				await process_frame
				await process_frame
				if _dirs_match(_dialog_dir(dlg), "/tmp") or _dirs_match(_dialog_dir(dlg), target):
					continue
			var up_btn := _find_dir_up(dlg)
			if up_btn != null:
				await _x11_click_embedded(up_btn)
				await process_frame
				await process_frame
				continue
		break
	check(false, "clicked into %s (now %s, rows %s)" % [
			target, _dialog_dir(dlg), ", ".join(_list_dialog_names(dlg))])
	return _dirs_match(_dialog_dir(dlg), target)


func _type_dialog_name(dlg: FileDialog, name: String) -> void:
	var edit := _name_edit(dlg)
	check(edit != null, "dialog name LineEdit exists")
	if edit == null:
		return
	await _x11_click_embedded(edit)
	await process_frame
	await _x11_type(edit.get_viewport(), name)
	await process_frame


func _test_bare_export_uses_dialog_folder(ctx: FilmContext, main) -> void:
	print("- File → Export 3MF, click into non-HOME dir, type nut.3mf")
	var sm: SketchMode = main.sketch_mode
	if sm != null and sm.active:
		await _finish_extrude(ctx)
	if _body_count(ctx) < 1:
		await _enter_ground_sketch(ctx)
		await _draw_rectangle(ctx)
		await _finish_extrude(ctx)
	check(_body_count(ctx) >= 1, "a solid exists before export")
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	DirAccess.make_dir_recursive_absolute(ABS_EXPORT.get_base_dir())
	var dest := EXPORT_DIR.path_join(EXPORT_NAME)
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if FileAccess.file_exists(ABS_EXPORT):
		DirAccess.remove_absolute(ABS_EXPORT)
	var home := OS.get_environment("HOME").strip_edges()
	check(not _dirs_match(EXPORT_DIR, home), "export directory is not HOME")
	var opened: bool = await _click_menu_item(ctx, "File", 11, "File → Export 3MF")
	check(opened, "File → Export 3MF was clicked at its popup rect")
	var dlg := await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export 3MF dialog is visible")
	if dlg == null or not dlg.visible:
		return
	check(not dlg.use_native_dialog, "Export 3MF does not use the native dialog")
	var entered: bool = await _click_into_export_dir(dlg)
	check(entered, "dialog current_dir is the clicked folder %s (got %s)" % [
			EXPORT_DIR, _dialog_dir(dlg)])
	if not entered:
		return
	await _type_dialog_name(dlg, EXPORT_NAME)
	var ok := dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export OK is visible")
	if ok != null:
		await _x11_click_embedded(ok)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(dest), "OK writes %s" % dest)
	var home_file := home.path_join(EXPORT_NAME)
	check(not _dirs_match(EXPORT_DIR, home) and not (
			FileAccess.file_exists(home_file) and not FileAccess.file_exists(dest)),
			"bare name did not land only in HOME")
	var status := _status(main)
	check(status.begins_with("Exported 3MF → "),
			"status starts with Exported 3MF → (got %s)" % status)
	check(status.contains(dest) or status.ends_with(dest),
			"status path is the dialog folder plus nut.3mf (got %s)" % status)
	check(main.is_inside_tree(), "process still running after bare-name export")

	print("- second export types an absolute path")
	opened = await _click_menu_item(ctx, "File", 11, "File → Export 3MF (absolute)")
	check(opened, "File → Export 3MF reopened for absolute path")
	dlg = await _wait_dialog(main)
	check(dlg != null and dlg.visible, "Export dialog is visible for absolute path")
	if dlg == null or not dlg.visible:
		return
	await _type_dialog_name(dlg, ABS_EXPORT)
	ok = dlg.get_ok_button()
	check(ok != null and ok.is_visible_in_tree(), "Export OK is visible for absolute path")
	if ok != null:
		await _x11_click_embedded(ok)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(ABS_EXPORT), "absolute path still writes %s" % ABS_EXPORT)
	status = _status(main)
	check(status.begins_with("Exported 3MF → ") and status.contains(ABS_EXPORT),
			"absolute export status contains the typed path (got %s)" % status)
	check(main.is_inside_tree(), "process still running after absolute export")
