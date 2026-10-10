# Rung 1 replan 14 WP3 — part context bar stays put and stays on screen.
# Leftovers 3 (bar shifts ~54 px) and 4 (overlaps menu/Snap, clips at right).
# Real events: Viewport.push_input for keys and clicks. Setup may place via FilmUI.
# Layout assertions at 1280×800. Run:
#   LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#     --script res://tests/run_rung01_replan14_ctxbar.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const SMALL_SIZE := Vector2i(1024, 768)
const POS_TOL := 1.0
const COMMON := [
	"StripGroup", "StripSimilar", "StripHole", "StripHoleWizard",
	"StripTriBall", "StripFillet", "StripChamfer",
]

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan14 WP3 part context bar")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	var vp: Viewport = ctx.main.get_viewport()
	var ix: ViewportInteraction = ctx.main.interaction
	# Default palette box is 5 mm — its centre sits inside the 2.5 mm edge
	# pick tolerance, so the refine click would arm an edge instead of a face.
	await FilmUI.place_primitive_at(ctx, "box", Vector3(15, 0, 0), Vector3(40, 20, 10))
	await process_frame
	await process_frame
	await _push_key_local(vp, KEY_3)
	await process_frame
	await process_frame

	var body: String = ctx.view.selected_body
	if body == "":
		var ids: PackedStringArray = ctx.view.doc.body_ids()
		if not ids.is_empty():
			body = ids[0]
	check(body != "", "box body exists after place")
	var pick := _body_pick_screen(ctx, body)
	var face_pick := _face_pick_screen(ctx, body)
	check(FilmUI.is_on_screen(ctx, pick), "body pick is on screen (%s)" % str(pick))
	check(FilmUI.is_on_screen(ctx, face_pick), "face pick is on screen (%s)" % str(face_pick))

	# Body-only state: Esc until nothing is selected, then a real click on the body.
	await _esc_until_hidden(ctx, vp, ix, 4)
	await _push_click(vp, pick)
	await process_frame
	await process_frame
	check(ctx.view.selected_body == body, "real click selected the body")
	check(ctx.view.selected_face == "", "body click has no face yet (got `%s`)" % ctx.view.selected_face)
	var strip: PanelContainer = ix._selection_strip
	check(strip != null and strip.visible, "SelectionStrip visible with body selected")
	await process_frame
	await process_frame
	await process_frame
	var r_body := _record_named(strip)
	var bar_body := strip.get_global_rect()
	_print_layout("body", ctx, ix, bar_body)
	_print_rect_table("body", r_body, bar_body)

	# Face refine: a real click on the top-face interior once the body is selected.
	await _push_click(vp, face_pick)
	await process_frame
	await process_frame
	print("FACE click at %s → face=`%s` edge=`%s`" % [
			str(face_pick), ctx.view.selected_face, ctx.view.selected_edge])
	check(ctx.view.selected_face != "", "second click refined to a face (`%s`)" % ctx.view.selected_face)
	check(_strip_button(strip, "Sketch") != null and _strip_button(strip, "Sketch").visible,
			"Sketch is visible with a face selected")
	check(_strip_button(strip, "Look at") != null and _strip_button(strip, "Look at").visible,
			"Look at is visible with a face selected")
	check(_strip_button(strip, "Active plane") != null and _strip_button(strip, "Active plane").visible,
			"Active plane is visible with a face selected")
	await process_frame
	await process_frame
	var r_face := _record_named(strip)
	var bar_face := strip.get_global_rect()
	_print_layout("face", ctx, ix, bar_face)
	_print_rect_table("face", r_face, bar_face)

	# Arm Fillet by clicking the body-state Fillet centre (must not land on Chamfer).
	var fillet_body: Rect2 = r_body.get("StripFillet", Rect2())
	check(fillet_body.size.x > 1.0, "body-state StripFillet rect is real (%s)" % str(fillet_body))
	_status_log.clear()
	await _push_click(vp, fillet_body.get_center())
	await process_frame
	await process_frame
	var st := _status_text(ctx)
	print("STATUS after Fillet click at body-centre: `%s`" % st)
	check(st.begins_with("Fillet"), "status starts with Fillet (got `%s`)" % st)
	check(not st.begins_with("Chamfer"), "status is never Chamfer (got `%s`)" % st)
	var radius_box: Control = strip.find_child("StripDressupRadius", true, false)
	check(radius_box != null and radius_box.visible, "R field is visible once Fillet is armed")
	var r_armed := _record_named(strip)
	var bar_armed := strip.get_global_rect()
	_print_layout("armed", ctx, ix, bar_armed)
	_print_rect_table("armed", r_armed, bar_armed)

	# 4. Common buttons stay put across body / face / armed.
	for name in ["StripGroup", "StripFillet", "StripChamfer"]:
		_assert_rect_stable(name, r_body, r_face, r_armed)

	# 5. Bar is below the menu/Snap row, right of the left panel, inside the window.
	_assert_bar_clear_of_chrome(ctx, bar_body, "body")
	_assert_bar_clear_of_chrome(ctx, bar_face, "face")
	_assert_bar_clear_of_chrome(ctx, bar_armed, "armed")
	_assert_children_inside(strip, bar_armed, ROOT_SIZE, "armed")

	# 7. Common-item x is non-decreasing in every recorded state.
	_assert_order(r_body, "body")
	_assert_order(r_face, "face")
	_assert_order(r_armed, "armed")

	# 6. A click just to the right of the bar reaches the viewport (does not swallow).
	var outside := Vector2(bar_armed.end.x + 12.0, bar_armed.position.y + bar_armed.size.y * 0.5)
	if outside.x > float(ROOT_SIZE.x) - 4.0:
		outside.x = float(ROOT_SIZE.x) - 4.0
	print("CLICK outside bar at %s (bar end.x=%.1f)" % [str(outside), bar_armed.end.x])
	var sel_before := ctx.view.selected_body
	var face_before := ctx.view.selected_face
	await _push_click(vp, outside)
	await process_frame
	await process_frame
	var swallowed := ctx.view.selected_body == sel_before \
			and ctx.view.selected_face == face_before \
			and strip.visible \
			and strip.get_global_rect().has_point(outside)
	check(not swallowed,
			"click right of bar is not swallowed by the strip (sel %s→%s face %s→%s)" \
			% [sel_before, ctx.view.selected_body, face_before, ctx.view.selected_face])
	check(not strip.get_global_rect().has_point(outside) or not strip.visible,
			"outside click is not inside the live bar rect")

	# Restore body+face+armed so wrap is measured on the widest strip.
	if not strip.visible or ctx.view.selected_body == "":
		await _push_click(vp, pick)
		await process_frame
		await process_frame
	if ctx.view.selected_face == "":
		await _push_click(vp, face_pick)
		await process_frame
		await process_frame
	var live_fillet := strip.find_child("StripFillet", true, false) as Control
	var radius_now: Control = strip.find_child("StripDressupRadius", true, false)
	if live_fillet != null and live_fillet.visible and (radius_now == null or not radius_now.visible):
		await _push_click(vp, live_fillet.get_global_rect().get_center())
		await process_frame
		await process_frame

	# 8. At 1024×768 the bar wraps to two rows and stays inside the window.
	await FilmUI.ensure_test_viewport(ctx, SMALL_SIZE)
	await process_frame
	await process_frame
	await process_frame
	var bar_small := strip.get_global_rect()
	print("RECTS small bar=%s" % str(bar_small))
	_assert_bar_clear_of_chrome(ctx, bar_small, "1024x768")
	_assert_children_inside(strip, bar_small, SMALL_SIZE, "1024x768")
	var row_count := _visible_row_count(strip)
	print("WRAP rows=%d height=%.1f" % [row_count, bar_small.size.y])
	check(row_count >= 2, "bar wraps to two rows at 1024×768 (got %d)" % row_count)

	# Back to 1280×800 for the hide / reselect check against step-1 Fillet x.
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	await process_frame
	await process_frame
	await process_frame

	# 9. Esc hides the bar (IGNORE); selecting the body again keeps Fillet x.
	await _esc_until_hidden(ctx, vp, ix, 4)
	check(strip.visible == false, "bar hides after Esc")
	check(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"hidden bar mouse_filter is IGNORE (got %d)" % strip.mouse_filter)
	await _push_click(vp, _body_pick_screen(ctx, body))
	await process_frame
	await process_frame
	check(strip.visible, "bar returns after selecting the body again")
	var fillet_again: Control = strip.find_child("StripFillet", true, false)
	check(fillet_again != null and fillet_again.visible, "Fillet is visible after reselect")
	if fillet_again != null:
		var dx := absf(fillet_again.get_global_rect().position.x - fillet_body.position.x)
		print("RESELECT Fillet x=%.1f body-state x=%.1f dx=%.1f" % [
				fillet_again.get_global_rect().position.x, fillet_body.position.x, dx])
		check(dx <= POS_TOL, "Fillet x after reselect matches step 1 (dx=%.1f)" % dx)

	await _shutdown(ctx)


func _assert_rect_stable(name: String, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	var ra: Rect2 = a.get(name, Rect2())
	var rb: Rect2 = b.get(name, Rect2())
	var rc: Rect2 = c.get(name, Rect2())
	var dx_bf := absf(ra.position.x - rb.position.x)
	var dx_ba := absf(ra.position.x - rc.position.x)
	var dy_bf := absf(ra.position.y - rb.position.y)
	var dy_ba := absf(ra.position.y - rc.position.y)
	var dsx_bf := absf(ra.size.x - rb.size.x)
	var dsx_ba := absf(ra.size.x - rc.size.x)
	print("STABLE %s body=%s face=%s armed=%s dx(body-face)=%.1f dx(body-armed)=%.1f" % [
			name, str(ra), str(rb), str(rc), dx_bf, dx_ba])
	check(dx_bf <= POS_TOL and dy_bf <= POS_TOL,
			"%s position equal body vs face within 1 px (dx=%.1f dy=%.1f)" % [name, dx_bf, dy_bf])
	check(dx_ba <= POS_TOL and dy_ba <= POS_TOL,
			"%s position equal body vs armed within 1 px (dx=%.1f dy=%.1f)" % [name, dx_ba, dy_ba])
	check(dsx_bf <= POS_TOL and absf(ra.size.y - rb.size.y) <= POS_TOL,
			"%s size equal body vs face within 1 px" % name)
	check(dsx_ba <= POS_TOL and absf(ra.size.y - rc.size.y) <= POS_TOL,
			"%s size equal body vs armed within 1 px" % name)


func _assert_order(rec: Dictionary, tag: String) -> void:
	var last := -INF
	var parts: PackedStringArray = PackedStringArray()
	for name in COMMON:
		if not rec.has(name):
			continue
		var r: Rect2 = rec[name]
		parts.append("%s x=%.1f" % [name, r.position.x])
		check(r.position.x + 0.5 >= last,
				"%s order: %s x=%.1f is non-decreasing after %.1f" % [tag, name, r.position.x, last])
		last = r.position.x
	print("ORDER %s %s" % [tag, ", ".join(parts)])


func _assert_bar_clear_of_chrome(ctx: FilmContext, bar: Rect2, tag: String) -> void:
	var root_n: Node = ctx.main
	var top_chrome: Control = root_n.find_child("TopChrome", true, false) as Control
	var file_menu: Control = root_n.find_child("FileMenu", true, false) as Control
	var snap: Control = root_n.find_child("PlaceSnapBar", true, false) as Control
	var left_stack: Control = root_n.find_child("LeftStack", true, false) as Control
	check(top_chrome != null, "%s: TopChrome exists" % tag)
	check(file_menu != null, "%s: FileMenu exists" % tag)
	check(snap != null, "%s: PlaceSnapBar exists" % tag)
	check(left_stack != null, "%s: LeftStack exists" % tag)
	if top_chrome != null:
		var tc_bottom := top_chrome.get_global_rect().end.y
		print("CHROME %s bar=%s top_chrome.bottom=%.1f left_stack.end.x=%.1f" % [
				tag, str(bar), tc_bottom,
				left_stack.get_global_rect().end.x if left_stack != null else -1.0])
		check(bar.position.y + 0.5 >= tc_bottom,
				"%s: bar.y=%.1f is below TopChrome bottom=%.1f" % [tag, bar.position.y, tc_bottom])
		for child in top_chrome.get_children():
			var cc := child as Control
			if cc == null or not cc.visible:
				continue
			var cr := cc.get_global_rect()
			check(not bar.intersects(cr),
					"%s: bar does not intersect TopChrome child %s (%s vs %s)" % [
							tag, cc.name, str(bar), str(cr)])
	if file_menu != null:
		check(not bar.intersects(file_menu.get_global_rect()),
				"%s: bar does not intersect FileMenu" % tag)
	if snap != null:
		check(not bar.intersects(snap.get_global_rect()),
				"%s: bar does not intersect PlaceSnapBar (%s vs %s)" % [
						tag, str(bar), str(snap.get_global_rect())])
	if left_stack != null:
		check(bar.position.x + 0.5 >= left_stack.get_global_rect().end.x,
				"%s: bar.x=%.1f is right of LeftStack end=%.1f" % [
						tag, bar.position.x, left_stack.get_global_rect().end.x])
	var win := Vector2(float(ROOT_SIZE.x), float(ROOT_SIZE.y)) if tag != "1024x768" \
			else Vector2(float(SMALL_SIZE.x), float(SMALL_SIZE.y))
	check(bar.end.x <= win.x + 0.5, "%s: bar.end.x=%.1f ≤ %.0f" % [tag, bar.end.x, win.x])
	check(bar.end.y <= win.y + 0.5, "%s: bar.end.y=%.1f ≤ %.0f" % [tag, bar.end.y, win.y])


func _assert_children_inside(strip: Control, bar: Rect2, win: Vector2i, tag: String) -> void:
	var win_r := Rect2(Vector2.ZERO, Vector2(win))
	var row := _strip_row(strip)
	if row == null:
		check(false, "%s: strip row exists" % tag)
		return
	for child in row.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		if c is Container:
			for grand in c.get_children():
				var g := grand as Control
				if g == null or not g.visible:
					continue
				_assert_rect_inside(bar, win_r, g.get_global_rect(), tag, g.name)
		else:
			_assert_rect_inside(bar, win_r, c.get_global_rect(), tag, c.name)


func _assert_rect_inside(bar: Rect2, win: Rect2, r: Rect2, tag: String, name: String) -> void:
	var grown := bar.grow(1.0)
	check(grown.encloses(r) or grown.intersects(r) and r.position.x >= bar.position.x - 1.0 \
			and r.end.x <= bar.end.x + 1.0 and r.position.y >= bar.position.y - 1.0 \
			and r.end.y <= bar.end.y + 1.0,
			"%s: %s rect %s is inside the bar %s" % [tag, name, str(r), str(bar)])
	check(win.encloses(r) or (r.position.x >= -0.5 and r.end.x <= win.size.x + 0.5 \
			and r.position.y >= -0.5 and r.end.y <= win.size.y + 0.5),
			"%s: %s rect %s is inside the window %s" % [tag, name, str(r), str(win)])


func _visible_row_count(strip: Control) -> int:
	var row := _strip_row(strip)
	if row == null:
		return 0
	var ys: Array[float] = []
	for child in row.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var y := c.get_global_rect().position.y
		var found := false
		for existing in ys:
			if absf(existing - y) <= 2.0:
				found = true
				break
		if not found:
			ys.append(y)
	return ys.size()


func _strip_row(strip: Control) -> Control:
	if strip == null:
		return null
	for child in strip.get_children():
		if child is Container:
			return child as Control
	return null


func _strip_button(strip: Control, text: String) -> Button:
	if strip == null:
		return null
	for c in strip.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _record_named(strip: Control) -> Dictionary:
	var out := {}
	for name in COMMON:
		var c: Control = strip.find_child(name, true, false) as Control
		if c != null and c.visible:
			out[name] = c.get_global_rect()
	return out


func _print_layout(tag: String, ctx: FilmContext, ix: ViewportInteraction, bar: Rect2) -> void:
	var left_stack: Control = ctx.main.find_child("LeftStack", true, false) as Control
	print("LAYOUT %s bar=%s x_floor=%.1f rail_right=%.1f left_stack=%s" % [
			tag, str(bar), ix._strip_x_floor, ChromeDock.rail_right,
			str(left_stack.get_global_rect()) if left_stack != null else "missing"])


func _print_rect_table(tag: String, rec: Dictionary, bar: Rect2) -> void:
	print("RECTS %s bar=%s" % [tag, str(bar)])
	for name in COMMON:
		if rec.has(name):
			var r: Rect2 = rec[name]
			print("  %s pos=(%.1f, %.1f) size=(%.1f, %.1f)" % [
					name, r.position.x, r.position.y, r.size.x, r.size.y])


func _body_pick_screen(ctx: FilmContext, body: String) -> Vector2:
	if ctx.view == null or body == "":
		return Vector2(640, 400)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		return Vector2(640, 400)
	var centre: Vector3 = (bb["min"] + bb["max"]) * 0.5
	return FilmUI.model_to_screen(ctx, centre)


func _face_pick_screen(ctx: FilmContext, body: String) -> Vector2:
	if ctx.view == null or body == "":
		return _body_pick_screen(ctx, body)
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	var pt := FilmUI.face_pick_point(ctx.view, body, face)
	if pt == Vector3.INF:
		var bb: Dictionary = ctx.view.doc.measure_bbox(body)
		if bb.is_empty():
			return _body_pick_screen(ctx, body)
		pt = (bb["min"] + bb["max"]) * 0.5
		pt.z = float(bb["max"].z) - 0.2
	return FilmUI.model_to_screen(ctx, pt)


func _status_text(ctx: FilmContext) -> String:
	if not _status_log.is_empty():
		return _status_log[_status_log.size() - 1]
	if ctx.main.status_label != null:
		return str(ctx.main.status_label.text)
	return ""


func _esc_until_hidden(ctx: FilmContext, vp: Viewport, ix: ViewportInteraction, cap: int) -> void:
	var strip: Control = ix._selection_strip
	for _i in cap:
		if strip == null or not strip.visible:
			return
		await _push_key_local(vp, KEY_ESCAPE)
		await process_frame
		await process_frame


func _push_click(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _push_key_local(vp: Viewport, keycode: Key, shift := false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


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
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.ops_panel != null and main.ops_panel.has_signal("status") \
			and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame
