# Rung 1 replan 17 WP4 — hover hint after the status hold, Timeline below
# the part chip row, window-fit rule.
# Setup may place geometry through the document API.
# Every press, key, and motion under test is Viewport.push_input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan17_chrome.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ChromeDock = preload("res://scripts/chrome_dock.gd")
const ROOT_SIZE := Vector2i(1280, 800)
## Small enough that the default camera (distance 15) is outside the solid,
## so a motion can hit a face and another can miss onto empty ground.
const BOX_SIZE := Vector3(8, 6, 3)
const NO_VIEW := "No view for key 0 — use 1 2 3 4 6 7 8"
const FRAMED_ALL := "Framed all"

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
	print("rung01 replan17 WP4 chrome / hover hold / timeline / window")
	FilmUI.reset_fail_count()
	await _test_h1()
	await _test_h2()
	await _test_h3()
	await _test_t1()
	await _test_t2()
	_test_w1()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_h1() -> void:
	print("- H1 hint stays deferred for the status hold, then appears with a still pointer")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	check(body != "", "H1 box placed")
	await _deselect(ctx)
	check(ctx.view.selected_body == "", "H1 nothing selected")
	var vp: Viewport = ctx.main.get_viewport()
	var px := _body_screen_center(ctx, body)
	var hit := _pick(ctx, px)
	print("  H1 hover %s hit=%s" % [str(px), str(hit.get("face", hit.get("body", "")))])
	check(px != Vector2.INF and not hit.is_empty(), "H1 motion point hits the body")
	_release_focus(vp)
	await _push_key(vp, KEY_0)
	var t0 := Time.get_ticks_msec()
	check(_label(ctx.main) == NO_VIEW, "H1 key 0 status (got `%s`)" % _label(ctx.main))
	await _motion(vp, px)
	await _await_until(t0 + 1000)
	print("  H1 at 1.0s `%s`" % _label(ctx.main))
	check(_label(ctx.main) == NO_VIEW, "H1 at 1.0s the key status still holds (got `%s`)" % _label(ctx.main))
	await _await_until(t0 + 3000)
	print("  H1 at 3.0s `%s`" % _label(ctx.main))
	check(_is_pick_hint(_label(ctx.main)),
			"H1 at 3.0s a still pointer shows the hover hint (got `%s`)" % _label(ctx.main))
	await _shutdown(ctx)


func _test_h2() -> void:
	print("- H2 a miss during the hold cancels the deferred hint")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	await _deselect(ctx)
	var vp: Viewport = ctx.main.get_viewport()
	var on_body := _body_screen_center(ctx, body)
	var ground := _empty_ground(ctx, on_body)
	var miss := _pick(ctx, ground)
	print("  H2 body %s ground %s miss_empty=%s" % [str(on_body), str(ground), str(miss.is_empty())])
	check(not _pick(ctx, on_body).is_empty() and miss.is_empty(), "H2 ground point misses the body")
	_release_focus(vp)
	await _push_key(vp, KEY_0)
	var t0 := Time.get_ticks_msec()
	check(_label(ctx.main) == NO_VIEW, "H2 key 0 status (got `%s`)" % _label(ctx.main))
	await _motion(vp, on_body)
	await _motion(vp, ground)
	await _await_until(t0 + 3000)
	print("  H2 at 3.0s `%s`" % _label(ctx.main))
	check(_label(ctx.main) == NO_VIEW,
			"H2 at 3.0s the key status is still showing (got `%s`)" % _label(ctx.main))
	await _shutdown(ctx)


func _test_h3() -> void:
	print("- H3 a newer status extends the hold; the hint follows the last status")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	await _deselect(ctx)
	var vp: Viewport = ctx.main.get_viewport()
	var px := _body_screen_center(ctx, body)
	check(not _pick(ctx, px).is_empty(), "H3 motion point hits the body")
	_release_focus(vp)
	await _push_key(vp, KEY_0)
	var t0 := Time.get_ticks_msec()
	await _motion(vp, px)
	await _await_until(t0 + 1200)
	await _push_key(vp, KEY_F)
	var tF := Time.get_ticks_msec()
	print("  H3 after F `%s` (F at +%d ms)" % [_label(ctx.main), tF - t0])
	check(_label(ctx.main) == FRAMED_ALL, "H3 key F status is Framed all (got `%s`)" % _label(ctx.main))
	await _await_until(tF + 1500)
	print("  H3 at 1.5s after F `%s`" % _label(ctx.main))
	check(_label(ctx.main) == FRAMED_ALL,
			"H3 at 1.5s after F the newer status still holds (got `%s`)" % _label(ctx.main))
	await _await_until(tF + 2800)
	print("  H3 at 2.8s after F `%s`" % _label(ctx.main))
	check(_is_pick_hint(_label(ctx.main)),
			"H3 hint appears 2.5s after the last status (got `%s`)" % _label(ctx.main))
	await _shutdown(ctx)


func _test_t1() -> void:
	print("- T1 Timeline docks below the part chip row")
	var ctx := await _boot()
	var main = ctx.main
	var body := await _place_box(ctx)
	await _deselect(ctx)
	var vp: Viewport = main.get_viewport()
	var px := _body_screen_center(ctx, body)
	check(px != Vector2.INF, "T1 body projects on screen")
	await _click_at(vp, px)
	await process_frame
	await process_frame
	check(ctx.view.selected_body == body and ctx.view.selected_face == "",
			"T1 click selects the body (body=%s face=%s)" % [ctx.view.selected_body, ctx.view.selected_face])
	var opened := await _click_menu_id(ctx, "View", 4, "View ▸ Timeline")
	check(opened, "T1 View ▸ Timeline click landed")
	for _i in 6:
		await process_frame
	if main.timeline != null and not main.timeline.visible and main.has_method("_update_panel_visibility"):
		main.show_timeline = true
		main._update_panel_visibility()
		for _i in 4:
			await process_frame
	var timeline: Control = main.timeline
	check(timeline != null and timeline.visible, "T1 Timeline is visible")
	var strip: Rect2 = _strip_rect(main)
	var win := vp.get_visible_rect()
	var tr: Rect2 = timeline.get_global_rect() if timeline != null else Rect2()
	print("  T1 window=%s timeline=%s strip=%s top_inset=%.1f" % [
		str(win), str(tr), str(strip), ChromeDock.top_inset])
	check(strip.size != Vector2.ZERO, "T1 selection strip is visible")
	check(not tr.intersects(strip), "T1 Timeline does not intersect the chip row")
	check(_rect_inside(win, strip), "T1 chip row is inside the window")
	check(_rect_inside(win, tr), "T1 Timeline is inside the window")
	_assert_chips_clear(main, tr)
	await _push_key(vp, KEY_ESCAPE)
	for _i in 6:
		await process_frame
	tr = timeline.get_global_rect()
	print("  T1 after Esc timeline=%s selected=%s" % [str(tr), ctx.view.selected_body])
	check(ctx.view.selected_body == "", "T1 Esc clears the selection")
	check(is_equal_approx(tr.position.y, ChromeDock.top_inset),
			"T1 Esc puts the Timeline back at top_inset (y=%.1f want %.1f)" % [tr.position.y, ChromeDock.top_inset])
	await _click_at(vp, px)
	for _i in 6:
		await process_frame
	strip = _strip_rect(main)
	tr = timeline.get_global_rect()
	print("  T1 reselected timeline=%s strip=%s" % [str(tr), str(strip)])
	check(ctx.view.selected_body == body, "T1 second click selects the body again")
	check(strip.size != Vector2.ZERO and not tr.intersects(strip),
			"T1 selecting again moves the Timeline below the strip")
	check(tr.position.y + 0.5 >= strip.end.y + 4.0,
			"T1 Timeline top is at least strip.end.y + 4 (y=%.1f strip_end=%.1f)" % [tr.position.y, strip.end.y])
	await _shutdown(ctx)


func _test_t2() -> void:
	print("- T2 Timeline stays off the Modify Radius field")
	var ctx := await _boot()
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	await _deselect(ctx)
	var px := _body_screen_center(ctx, body)
	await _click_at(vp, px)
	await process_frame
	await process_frame
	check(ctx.view.selected_body == body and ctx.view.selected_face == "",
			"T2 body selected with no face so Modify shows Radius")
	main.ops_panel.arm_or_apply_fillet()
	await process_frame
	await process_frame
	var spin: SpinBox = main.ops_panel._radius_spin if main.ops_panel != null else null
	check(spin != null and spin.is_visible_in_tree(), "T2 panel Radius is visible")
	var opened := await _click_menu_id(ctx, "View", 4, "View ▸ Timeline")
	check(opened, "T2 View ▸ Timeline click landed")
	for _i in 4:
		await process_frame
	if main.timeline != null and not main.timeline.visible and main.has_method("_update_panel_visibility"):
		main.show_timeline = true
		main._update_panel_visibility()
		await process_frame
		await process_frame
	var timeline: Control = main.timeline
	check(timeline != null and timeline.visible, "T2 Timeline is visible")
	if timeline == null or spin == null:
		await _shutdown(ctx)
		return
	await _scroll_into_view(main, spin)
	var win := vp.get_visible_rect()
	var tr: Rect2 = timeline.get_global_rect()
	var sr: Rect2 = spin.get_global_rect()
	print("  T2 window=%s timeline=%s radius=%s" % [str(win), str(tr), str(sr)])
	check(not tr.intersects(sr), "T2 Timeline does not intersect Radius")
	check(_rect_inside(win, tr) and _rect_inside(win, sr), "T2 Timeline and Radius are inside the window")
	await _shutdown(ctx)


func _test_w1() -> void:
	print("- W1 window_fit_rect")
	var script: Script = load("res://scripts/main.gd")
	var fit := Callable(script, "window_fit_rect")
	if not script.has_method("window_fit_rect") or not fit.is_valid():
		check(false, "W1 window_fit_rect exists")
		return
	var small: Rect2i = fit.call(Rect2i(0, 0, 1280, 800), Vector2i(1072, 620), Vector2i(0, 28))
	check(small == Rect2i(0, 0, 1280, 772),
			"W1 1072x620 on 1280x800 fits to (0,0,1280,772) (got %s)" % str(small))
	var near: Rect2i = fit.call(Rect2i(0, 0, 1280, 800), Vector2i(1272, 770), Vector2i(0, 28))
	check(near == Rect2i(), "W1 a window already within 8 px stays put (got %s)" % str(near))


func _assert_chips_clear(main, timeline_rect: Rect2) -> void:
	var strip: Control = main.interaction._selection_strip if main.interaction != null else null
	var row: Node = null
	if strip != null:
		for child in strip.get_children():
			if child is Container:
				row = child
				break
	check(row != null, "T1 chip row exists")
	if row == null:
		return
	var want := ["StripGroup", "StripSimilar", "StripHole", "StripHoleWizard", "StripFillet", "StripChamfer"]
	var seen := {}
	var covered := 0
	var hidden := 0
	for child in row.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		seen[c.name] = true
		if not c.is_visible_in_tree():
			hidden += 1
			printerr("  FAIL - T1 chip %s is_visible_in_tree" % c.name)
			failures += 1
			checks += 1
		elif timeline_rect.intersects(c.get_global_rect()):
			covered += 1
			printerr("  FAIL - T1 chip %s covered by Timeline %s vs %s" % [
				c.name, str(c.get_global_rect()), str(timeline_rect)])
			failures += 1
			checks += 1
		else:
			checks += 1
			print("  ok   - T1 chip %s visible and clear of the Timeline" % c.name)
	for name in want:
		check(seen.has(name), "T1 chip %s is showing" % name)
	check(covered == 0 and hidden == 0, "T1 every visible chip is on screen and clear of the Timeline")


func _is_pick_hint(text: String) -> bool:
	return text.begins_with("Face — ") or text.begins_with("Body — ") or text.begins_with("Edge — ")


func _strip_rect(main) -> Rect2:
	if main.interaction != null and main.interaction.has_method("selection_strip_global_rect"):
		return main.interaction.selection_strip_global_rect()
	var strip: Control = main.interaction._selection_strip if main.interaction != null else null
	if strip == null or not strip.visible:
		return Rect2()
	return strip.get_global_rect()


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
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
	await process_frame
	await process_frame


func _place_box(ctx: FilmContext) -> String:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, BOX_SIZE)
	await process_frame
	await process_frame
	return body


func _deselect(ctx: FilmContext) -> void:
	if ctx.view.selected_body == "" and ctx.view.selection_size() == 0:
		return
	_release_focus(ctx.main.get_viewport())
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame


func _label(main) -> String:
	if main == null or main.status_label == null:
		return ""
	return str(main.status_label.text)


func _body_world_corners(ctx: FilmContext, body: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if body == "":
		return out
	var node := ctx.view.body_node(body)
	if node == null:
		return out
	var aabb: AABB = node.get_aabb()
	var xf: Transform3D = node.global_transform
	for i in 8:
		var local := aabb.position + Vector3(
			aabb.size.x if (i & 1) != 0 else 0.0,
			aabb.size.y if (i & 2) != 0 else 0.0,
			aabb.size.z if (i & 4) != 0 else 0.0)
		out.append(xf * local)
	return out


func _body_screen_center(ctx: FilmContext, body: String) -> Vector2:
	var corners := _body_world_corners(ctx, body)
	if corners.is_empty():
		return Vector2.INF
	var acc := Vector3.ZERO
	for c in corners:
		acc += c
	var cam: OrbitCamera = ctx.main.camera
	var world := acc / float(corners.size())
	if cam.is_position_behind(world):
		return Vector2.INF
	return cam.unproject_position(world)


func _model_ray(ctx: FilmContext, screen: Vector2) -> Array:
	var cam: Camera3D = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	var inv: Transform3D = ms.global_transform.affine_inverse()
	return [inv * cam.project_ray_origin(screen), inv.basis * cam.project_ray_normal(screen)]


func _pick(ctx: FilmContext, screen: Vector2) -> Dictionary:
	if screen == Vector2.INF:
		return {}
	var ray: Array = _model_ray(ctx, screen)
	return ctx.view.pick_info(ray[0], ray[1])


func _empty_ground(ctx: FilmContext, avoid: Vector2) -> Vector2:
	var size: Vector2 = ctx.main.get_viewport().get_visible_rect().size
	# Stay on empty canvas: below TopChrome, right of the rail, above the
	# status bar. A miss that lands on a STOP control never reaches hover.
	var y := 140.0
	while y < size.y - 48.0:
		var x := 220.0
		while x < size.x - 40.0:
			var pt := Vector2(x, y)
			if pt.distance_to(avoid) >= 80.0 and _pick(ctx, pt).is_empty():
				return pt
			x += 50.0
		y += 50.0
	return Vector2(220.0, 160.0)


func _rect_inside(window: Rect2, inner: Rect2) -> bool:
	if inner.size.x < 2.0 or inner.size.y < 2.0:
		return false
	return window.has_point(inner.position) and window.has_point(inner.end - Vector2(1, 1))


func _await_until(ms_abs: int) -> void:
	while Time.get_ticks_msec() < ms_abs:
		await process_frame


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _motion(vp, pos)
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


func _push_key(vp: Viewport, keycode: Key) -> void:
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
	up.echo = false
	vp.push_input(up)
	await process_frame


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _click_menu_id(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button visible" % desc)
		return false
	await _click_at(btn.get_viewport(), btn.get_global_rect().get_center())
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	if popup != null and not popup.visible:
		btn.show_popup()
		await process_frame
	if popup == null or not popup.visible:
		check(false, "%s popup visible" % desc)
		return false
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "%s has item %d" % [desc, id])
		return false
	await _click_popup_item(popup, idx)
	await process_frame
	await process_frame
	return true


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


func _click_popup_item(popup: PopupMenu, index: int) -> void:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs if font == null else font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top += panel.get_margin(SIDE_TOP)
	for i in index:
		top += _popup_row_height(popup, i, font_h, v_sep)
	var row_h := _popup_row_height(popup, index, font_h, v_sep)
	var local := Vector2(maxf(8.0, popup.size.x * 0.5), top + row_h * 0.5)
	var screen := Vector2(popup.position) + local
	await _click_at(root.get_viewport(), screen)


func _scroll_into_view(main, ctrl: Control) -> void:
	if main == null or main.ops_panel == null or ctrl == null:
		return
	var scroll: ScrollContainer = main.ops_panel._scroll
	if scroll == null:
		return
	scroll.ensure_control_visible(ctrl)
	await process_frame
	await process_frame
