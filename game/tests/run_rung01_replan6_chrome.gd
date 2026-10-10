# Rung 1 replan 6 WP3 — finish bar clear of Exit Sketch; Radius vs Extrude.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan6_chrome.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL_R := 0.05
const VIEWPORT := Rect2(0, 0, 1280, 800)
const RAIL_GAP := 8.0
const SPIN_GAP := 24.0

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan6 WP3 chrome")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_exit_sketch_and_radius_blank()
	await test_extrude_blank_75()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan6_chrome.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("set_up_to" + "_face"), "test source has no face-id setter")
	check(not src.contains("set_finish" + "_op"), "test source has no finish-op setter")
	check(not src.contains("set_finish" + "_end"), "test source has no finish-end setter")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	check(not src.contains(".text" + " ="), "test source does not assign LineEdit.text")
	check(not src.contains(".value" + " ="), "test source does not assign SpinBox.value")
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
	check(not src.contains("dimension_edit_requested" + ".emit"),
			"test source does not emit dimension_edit_requested")
	check(not src.contains("_pointer" + "_click"), "test source does not use pointer-click helper")
	check(not src.contains("_click" + "_control"), "test source does not call FilmUI click_control")
	check(not src.contains("_dimension_label" + "_pos2"), "test source does not click a computed dim label")
	check(src.contains("func _x11_" + "click(ctrl"), "test source copies the X11 click helper")
	check(src.contains("func _x11_" + "click_screen(vp"), "test source copies the X11 screen click helper")
	check(src.contains("func _x11_" + "type(vp"), "test source copies the X11 type helper")
	check(not _x11_click_awaits_between_down_up(src, "func _x11_" + "click_screen(vp"),
			"chrome screen click helper has no await between mouse-down and mouse-up")


func _x11_click_awaits_between_down_up(src: String, header: String) -> bool:
	var start := src.find(header)
	if start < 0:
		return true
	var nxt := src.find("\nfunc ", start + 1)
	var body := src.substr(start, nxt - start if nxt > start else src.length() - start)
	var down := body.find("pressed = true")
	var up := body.find("pressed = false")
	if down < 0 or up < 0 or up <= down:
		return true
	return body.find("await ", down) >= 0 and body.find("await ", down) < up


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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _status_blob(ctx: FilmContext) -> String:
	var parts: PackedStringArray = PackedStringArray(_status_log)
	if ctx != null and ctx.main != null and ctx.main.status_label != null:
		parts.append(str(ctx.main.status_label.text))
	return " ".join(parts)


func _status_has(ctx: FilmContext, needle: String) -> bool:
	if str(needle) == "":
		return false
	return _status_blob(ctx).contains(needle)


func test_exit_sketch_and_radius_blank() -> void:
	print("- ground sketch Circle: Exit Sketch clear of spins; Radius vs Extrude")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	await _zoom(ctx, Vector3.ZERO, 140.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(chrome != null and chrome.visible, "sketch chrome is visible")
	_assert_finish_bar_layout(ctx, chrome)

	var dim := _dim_edit(chrome)
	var dist := _distance_edit(chrome)
	check(dim != null, "DimLineEdit exists")
	check(dist != null, "DistanceLineEdit exists")
	var dist_before := 20.0
	if chrome != null:
		dist_before = chrome.extrude_distance()
	await _click_uv_local(ctx, Vector2.ZERO, "Circle centre")
	await _hover_uv(ctx, Vector2(8, 0))
	check(dim != dist, "radius blank is not the extrude blank")
	if dim != null:
		await _x11_click(dim)
		check(dim.has_focus(), "radius blank click focuses DimLineEdit")
		check(dist == null or not dist.has_focus(),
				"radius blank click does not focus DistanceLineEdit")
		await _x11_type(dim.get_viewport(), "22.5")
		await _x11_enter(dim.get_viewport())
		await process_frame
		await process_frame
	var cid := _nth_circle(sm, 0)
	check(cid != "", "a circle exists after typing 22.5")
	if cid != "":
		var r := float(sm.sketch.entity_info(cid)["radius"])
		check(absf(r - 22.5) <= TOL_R, "typed 22.5 is radius 22.5 (got %.4f)" % r)
	var dist_after := chrome.extrude_distance() if chrome != null else -1.0
	check(absf(dist_after - dist_before) < 0.05,
			"typing radius did not change extrude_distance (was %.4f now %.4f)" % [
				dist_before, dist_after])
	var st := _status_blob(ctx)
	check(not _status_has(ctx, "Extrude 22.5"),
			"status does not contain Extrude 22.5 (got %s)" % st)
	await _shutdown(ctx)


func test_extrude_blank_75() -> void:
	print("- closed profile: X11 click Extrude blank, type 7.5, Extrude")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await _draw_closed_rect(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dim := _dim_edit(chrome)
	var dist := _distance_edit(chrome)
	check(dist != null, "DistanceLineEdit exists")
	var dim_before := 10.0
	if chrome != null:
		dim_before = chrome.dim_value()
	if dist != null:
		await _x11_click(dist)
		check(dist.has_focus(), "extrude blank click focuses DistanceLineEdit")
		check(dim == null or not dim.has_focus(),
				"extrude blank click does not focus DimLineEdit")
		await _x11_type(dist.get_viewport(), "7.5")
		await process_frame
		await process_frame
	check(absf(chrome.dim_value() - dim_before) < 0.05,
			"typing extrude distance did not change dim_value (was %.4f now %.4f)" % [
				dim_before, chrome.dim_value()])
	var btn := chrome.extrude_button()
	check(btn != null, "finish-bar Extrude exists")
	if btn != null:
		await _x11_click(btn)
	await process_frame
	await process_frame
	await process_frame
	var st := _status_blob(ctx)
	check(_status_has(ctx, "Extrude Blind 7.5000 mm"),
			"status contains Extrude Blind 7.5000 mm (got %s)" % st)
	await _shutdown(ctx)


func _assert_finish_bar_layout(ctx: FilmContext, chrome: SketchContextChrome) -> void:
	var exit_btn := ctx.main.find_child("ExitSketch", true, false) as Control
	var rail := ctx.main.find_child("SketchTools", true, false) as Control
	var finish: Control = chrome.find_child("FinishBar", true, false)
	var dim_spin: Control = chrome.find_child("DimSpin", true, false)
	var dist_spin: Control = chrome.find_child("DistanceSpin", true, false)
	check(exit_btn != null and exit_btn.is_visible_in_tree(), "ExitSketch is visible")
	check(rail != null and rail.is_visible_in_tree(), "SketchTools rail is visible")
	check(finish != null and finish.visible, "FinishBar is visible")
	check(dim_spin != null and dist_spin != null, "DimSpin and DistanceSpin exist")
	if exit_btn == null or rail == null or finish == null or dim_spin == null or dist_spin == null:
		return
	var er := exit_btn.get_global_rect()
	var rr := rail.get_global_rect()
	var fr := finish.get_global_rect()
	var dr := dim_spin.get_global_rect()
	var xr := dist_spin.get_global_rect()
	print("  layout ExitSketch=%s SketchTools=%s FinishBar=%s DimSpin=%s DistanceSpin=%s" % [
		str(er), str(rr), str(fr), str(dr), str(xr)])
	check(fr.position.x + 0.5 >= rr.end.x + RAIL_GAP,
			"finish bar is ≥ 8 px right of SketchTools (bar x=%.1f rail end=%.1f)" % [
				fr.position.x, rr.end.x])
	check(not er.intersects(dr),
			"ExitSketch does not intersect DimSpin (exit %s dim %s)" % [str(er), str(dr)])
	check(not er.intersects(xr),
			"ExitSketch does not intersect DistanceSpin (exit %s dist %s)" % [str(er), str(xr)])
	check(_contained(VIEWPORT, er),
			"ExitSketch inside 1280×800 (exit %s)" % str(er))
	check(_contained(VIEWPORT, dr),
			"DimSpin inside 1280×800 (dim %s)" % str(dr))
	check(_contained(VIEWPORT, xr),
			"DistanceSpin inside 1280×800 (dist %s)" % str(xr))
	var radius_lbl := _visible_label(chrome, "Radius")
	var extrude_lbl := _visible_label(chrome, "Extrude")
	check(radius_lbl != null,
			"radius label text is Radius (got %s)" % _label_dump(chrome))
	check(extrude_lbl != null,
			"distance label text is Extrude (got %s)" % _label_dump(chrome))
	check(_spins_separated(dim_spin, dist_spin, chrome),
			"DimSpin and DistanceSpin are ≥ 24 px apart or have a control between them (dim %s dist %s)" % [
				str(dr), str(xr)])


func _visible_label(root: Node, exact: String) -> Label:
	if root == null:
		return null
	for n in root.find_children("*", "Label", true, false):
		var lbl := n as Label
		if lbl == null or not lbl.is_visible_in_tree():
			continue
		if str(lbl.text) == exact:
			return lbl
	return null


func _label_dump(root: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if root == null:
		return ""
	for n in root.find_children("*", "Label", true, false):
		var lbl := n as Label
		if lbl == null or not lbl.is_visible_in_tree():
			continue
		parts.append("%s='%s'" % [lbl.name, lbl.text])
	return ", ".join(parts)


func _spins_separated(dim: Control, dist: Control, chrome: Node) -> bool:
	var a := dim.get_global_rect()
	var b := dist.get_global_rect()
	if a.intersects(b):
		return false
	var gap := -1.0
	if a.end.x <= b.position.x:
		gap = b.position.x - a.end.x
	elif b.end.x <= a.position.x:
		gap = a.position.x - b.end.x
	if gap + 0.5 >= SPIN_GAP:
		return true
	var left := minf(a.end.x, b.end.x)
	var right := maxf(a.position.x, b.position.x)
	var top := minf(a.position.y, b.position.y)
	var bottom := maxf(a.end.y, b.end.y)
	var band := Rect2(Vector2(left, top), Vector2(maxf(0.0, right - left), maxf(0.0, bottom - top)))
	for n in chrome.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or c == dim or c == dist:
			continue
		if not c.is_visible_in_tree() or c.get_child_count() > 0:
			continue
		var r := c.get_global_rect()
		if r.size.x < 4.0 or r.size.y < 4.0:
			continue
		if band.intersects(r):
			return true
	return false


func _contained(outer: Rect2, inner: Rect2, eps := 1.0) -> bool:
	return inner.position.x >= outer.position.x - eps \
			and inner.position.y >= outer.position.y - eps \
			and inner.end.x <= outer.end.x + eps \
			and inner.end.y <= outer.end.y + eps


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _nth_circle(sm: SketchMode, index: int) -> String:
	if sm == null or sm.sketch == null:
		return ""
	var rows: Array = []
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		rows.append({"id": id, "x": float((info["center"] as Vector2).x)})
	rows.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))
	if index < 0 or index >= rows.size():
		return ""
	return str(rows[index]["id"])


func _draw_closed_rect(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await process_frame
	await _click_uv_local(ctx, Vector2(-15, -10), "Rect corner A")
	await _click_uv_local(ctx, Vector2(15, 10), "Rect corner B")
	await process_frame


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _aim_pointer(ctx, screen)


func _aim_pointer(ctx: FilmContext, screen: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


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
