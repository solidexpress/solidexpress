# Rung 1 replan 4 WP1 — first-key replace for dim and Distance at 1280×800.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan4_numeric.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL_R := 0.05
const TOL_Z := 0.2

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan4 WP1 numeric")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_circles_replace_and_layout()
	await test_distance_75_extrude()
	await test_junk_distance_does_not_extrude()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan4_numeric.gd")
	check(not src.contains("focus_dim" + "_for_typing"),
			"test source does not call focus_dim_for_typing")
	check(not src.contains("focus_distance" + "_for_typing"),
			"test source does not call focus_distance_for_typing")
	check(not src.contains("set_extrude" + "_distance"),
			"test source does not call set_extrude_distance")
	check(not src.contains("text_submitted" + ".emit"),
			"test source does not emit submitted")
	check(not src.contains("interaction." + "_input"),
			"test source does not call Interaction _input")
	check(not src.contains("id_pressed" + ".emit"),
			"test source does not emit id_pressed")
	check(not src.contains(".text" + " ="),
			"test source does not assign LineEdit.text")
	check(not src.contains(".value" + " ="),
			"test source does not assign SpinBox.value")
	check(src.contains("func _x11_click"), "test source copies _x11_click")
	check(src.contains("func _x11_type"), "test source copies _x11_type")
	check(not _x11_click_awaits_between_down_up(src),
			"_x11_click has no await between mouse-down and mouse-up")


func _x11_click_awaits_between_down_up(src: String) -> bool:
	var start := src.find("func _x11_click")
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
	if _status_blob(ctx).contains(needle):
		return true
	return false


func test_circles_replace_and_layout() -> void:
	print("- layout at 1280×800, then circle r=10 and r=22.5 via X11 click")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open")
	await _zoom(ctx, Vector3.ZERO, 140.0)

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var rail_x := 56.0
	if ctx.main.sketch_toolbar != null and ctx.main.sketch_toolbar.visible:
		rail_x = ctx.main.sketch_toolbar.global_position.x + ctx.main.sketch_toolbar.size.x + 8.0
	chrome.place_variant_row(rail_x)
	await process_frame
	await process_frame
	_assert_readout_layout(chrome)

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _click_uv(ctx, Vector2.ZERO, "Circle 1 centre")
	await _hover_uv(ctx, Vector2(8, 0))
	var dim := _dim_edit(chrome)
	check(dim != null, "DimLineEdit exists")
	if dim != null:
		await _x11_click(dim)
		check(dim.has_focus(), "first dim click focuses DimLineEdit")
		await _x11_type(dim.get_viewport(), "10")
		await _x11_enter(dim.get_viewport())
		await process_frame
		await process_frame
	var c1 := _nth_circle(sm, 0)
	check(c1 != "", "first circle exists")
	if c1 != "":
		var r1 := float(sm.sketch.entity_info(c1)["radius"])
		check(absf(r1 - 10.0) <= TOL_R, "typed 10 is radius 10 (got %.4f)" % r1)
	var st1 := _status_blob(ctx)
	check(_status_has(ctx, "Circle r=10"),
			"status contains Circle r=10 (got %s)" % st1)
	check(_status_has(ctx, "Ø20"),
			"status contains Ø20 (got %s)" % st1)

	await _click_uv(ctx, Vector2(50, 0), "Circle 2 centre")
	await _hover_uv(ctx, Vector2(56, 0))
	if dim != null:
		await _x11_click(dim)
		check(dim.has_focus(), "second dim click focuses DimLineEdit")
		await _x11_type(dim.get_viewport(), "22.5")
		await process_frame
		var raw := _spin_digits(dim)
		check(raw.contains("22.5"),
				"second dim text parses as 22.5 (got '%s')" % dim.text)
		check(not raw.contains("2.522"),
				"second dim text does not contain 2.522 (got '%s')" % dim.text)
		check(raw.is_valid_float() and absf(float(raw) - 22.5) < 0.001,
				"stripped dim text is one float 22.5 (got '%s')" % raw)
		await _x11_enter(dim.get_viewport())
		await process_frame
		await process_frame
	var c2 := _nth_circle(sm, 1)
	check(c2 != "", "second circle exists")
	if c2 != "":
		var r2 := float(sm.sketch.entity_info(c2)["radius"])
		check(absf(r2 - 22.5) <= TOL_R, "typed 22.5 is radius 22.5 (got %.4f)" % r2)
	var st2 := _status_blob(ctx)
	check(_status_has(ctx, "Circle r=22.5"),
			"status contains Circle r=22.5 (got %s)" % st2)
	check(_status_has(ctx, "Ø45"),
			"status contains Ø45 (got %s)" % st2)
	await _shutdown(ctx)


func test_distance_75_extrude() -> void:
	print("- X11 click Distance, type 7.5, Extrude Blind 7.5 (no Enter)")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await _draw_closed_rect(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	check(dist != null, "DistanceLineEdit exists")
	check(readout != null, "ExtrudeReadout exists")
	if dist != null:
		await _x11_click(dist)
		check(dist.has_focus(), "Distance click focuses DistanceLineEdit")
		await _x11_type(dist.get_viewport(), "7.5")
		await process_frame
		await process_frame
		var digits := _spin_digits(dist)
		check(digits.contains("7.5"),
				"Distance line is 7.5 after typing (got '%s')" % dist.text)
		check(not digits.contains("20.07"),
				"Distance did not append onto 20 (got '%s')" % dist.text)
	check(readout != null and str(readout.text).contains("7.5"),
			"readout contains 7.5 before Extrude (%s)" % (readout.text if readout else ""))
	check(absf(chrome.extrude_distance() - 7.5) < 0.05,
			"extrude_distance() is 7.5 (got %s)" % str(chrome.extrude_distance()))
	var before := ctx.view.doc.body_ids().size()
	var btn := chrome.extrude_button()
	check(btn != null, "finish-bar Extrude exists")
	if btn != null:
		await _x11_click(btn)
	await process_frame
	await process_frame
	await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(ids.size() == before + 1, "Extrude created one body (was %d now %d)" % [before, ids.size()])
	if not ids.is_empty():
		var bb: Dictionary = ctx.view.doc.measure_bbox(ids[ids.size() - 1])
		var ext: Vector3 = bb["max"] - bb["min"]
		check(absf(ext.z - 7.5) <= TOL_Z, "bbox Z is 7.5 (got %.3f)" % ext.z)
		check(absf(ext.z - 20.0) > 1.0, "bbox Z is not the default 20 (got %.3f)" % ext.z)
	var st := _status_blob(ctx)
	check(_status_has(ctx, "Extrude Blind 7.5000 mm"),
			"status contains Extrude Blind 7.5000 mm (got %s)" % st)
	await _shutdown(ctx)


func test_junk_distance_does_not_extrude() -> void:
	print("- X11 click Distance, type 20.07.5, Extrude refuses")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await _zoom(ctx, Vector3.ZERO, 120.0)
	await _draw_closed_rect(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	check(dist != null, "DistanceLineEdit exists for junk")
	if dist != null:
		await _x11_click(dist)
		await _x11_type(dist.get_viewport(), "20.07.5")
		await process_frame
		await process_frame
		var digits := _spin_digits(dist)
		check(digits == "20.07.5",
				"first key replaced default; line is 20.07.5 (got '%s')" % dist.text)
		check(not chrome.distance_line_parses(),
				"20.07.5 does not parse (line '%s')" % dist.text)
	var before_ids: PackedStringArray = ctx.view.doc.body_ids()
	var btn := chrome.extrude_button()
	if btn != null:
		await _x11_click(btn)
	await process_frame
	await process_frame
	await process_frame
	var after_ids: PackedStringArray = ctx.view.doc.body_ids()
	check(after_ids.size() == before_ids.size(),
			"junk Distance does not create a body (was %d now %d)" % [
				before_ids.size(), after_ids.size()])
	check(_status_has(ctx, "Cannot read distance"),
			"status contains Cannot read distance (got %s)" % _status_blob(ctx))
	if not after_ids.is_empty():
		var bb: Dictionary = ctx.view.doc.measure_bbox(after_ids[after_ids.size() - 1])
		var ext: Vector3 = bb["max"] - bb["min"]
		check(absf(ext.z - 20.0) > 0.5,
				"junk Extrude did not make a 20 mm solid (Z=%.3f)" % ext.z)
	await _shutdown(ctx)


func _assert_readout_layout(chrome: SketchContextChrome) -> void:
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	var variant: Control = chrome.find_child("VariantBar", true, false)
	var btn := chrome.extrude_button()
	check(readout != null, "ExtrudeReadout exists")
	check(variant != null and variant.visible, "variant chips are visible")
	check(btn != null, "Extrude button exists")
	if readout == null or variant == null or btn == null:
		return
	var vp := chrome.get_viewport().get_visible_rect()
	var rr := readout.get_global_rect()
	var vr := variant.get_global_rect()
	var br := btn.get_global_rect()
	check(_contained(vp, rr),
			"readout inside 1280×800 (readout %s vp %s)" % [str(rr), str(vp)])
	check(not rr.intersects(vr),
			"readout does not intersect variant chips (readout %s chips %s)" % [
				str(rr), str(vr)])
	check(_contained(vp, br),
			"Extrude button inside 1280×800 (btn %s vp %s)" % [str(br), str(vp)])


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


func _spin_digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := str(edit.text).strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	return text.strip_edges()


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
	await _click_uv(ctx, Vector2(-15, -10), "Rect corner A")
	await _click_uv(ctx, Vector2(15, 10), "Rect corner B")
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	var vp: Viewport = ctx.main.get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	vp.push_input(up)
	await process_frame


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
