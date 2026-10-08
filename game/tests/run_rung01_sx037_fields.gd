# sx-037 — a tool's numeric blank never shows another tool's number, Slot c-c
# does not start on the cap radius, and a Power Trim drag trail is gone on release.
# Real events: Viewport.push_input for clicks, drags, and keys under test.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx037_fields.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 sx037 per-tool numeric fields and trim trail")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var ctx := await _boot()
	await _test_fields(ctx)
	await _test_trim_trail(ctx)
	await _test_new_document(ctx)
	await _shutdown(ctx)


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
	await FilmUI.enter_sketch(ctx)
	check(main.sketch_mode.active, "sketch is active")
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


func _test_fields(ctx: FilmContext) -> void:
	print("- Circle 22.5 must not leak into Line, Arc, Polygon, or Slot")
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _click_uv(ctx, Vector2.ZERO, "Circle centre")
	await process_frame
	check(_dim_edit(chrome) != null and _dim_edit(chrome).has_focus(), "circle centre focuses Radius")
	await _type_text(ctx, "22.5")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(_status_blob().contains("Circle r=22.5"), "status has Circle r=22.5")
	check(is_equal_approx(sm.circle_radius, 22.5), "circle radius stored as 22.5")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	await process_frame
	var line_digits := _digits(_dim_edit(chrome))
	check(not _parses_to(_dim_edit(chrome), 22.5),
			"Line length is not the circle radius (got '%s')" % line_digits)
	check(line_digits == "" or _parses_to(_dim_edit(chrome), sm.own_numeric()),
			"Line length is empty or Line's own value (got '%s')" % line_digits)

	await _click_uv(ctx, Vector2(12, 0), "Line start")
	await process_frame
	await _type_text(ctx, "18")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	check(sm._tool_numeric.has("line"), "Line remembered its own length")
	var line_own := float(sm._tool_numeric.get("line", -1.0))
	check(is_equal_approx(line_own, 18.0), "Line's own length is 18 (got %.4f)" % line_own)

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	check(_parses_to(_dim_edit(chrome), 22.5) and not _parses_to(_dim_edit(chrome), 18.0),
			"Circle radius stays 22.5, not the line length (got '%s')" % _digits(_dim_edit(chrome)))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	check(_parses_to(_dim_edit(chrome), 18.0) and not _parses_to(_dim_edit(chrome), 22.5),
			"Line length is its own 18, not 22.5 (got '%s')" % _digits(_dim_edit(chrome)))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ARC)
	await process_frame
	check(not _parses_to(_dim_edit(chrome), 22.5) and not _parses_to(_dim_edit(chrome), 18.0),
			"Arc field is not Line or Circle (got '%s')" % _digits(_dim_edit(chrome)))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await process_frame
	check(sm.tool_variant == "across_flats", "polygon variant is across flats")
	check(not _parses_to(_dim_edit(chrome), 22.5),
			"Polygon AF is not the circle radius (got '%s')" % _digits(_dim_edit(chrome)))
	var poly_edit := _dim_edit(chrome)
	check(poly_edit != null and str(poly_edit.text).contains("AF"),
			"Polygon AF suffix still shows (got '%s')" % (str(poly_edit.text) if poly_edit != null else ""))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SLOT)
	await process_frame
	await process_frame
	check(_parses_to(_dim_edit(chrome), sm.slot_radius) and not _parses_to(_dim_edit(chrome), 22.5),
			"Slot radius is its own %.4f, not 22.5 (got '%s')" % [
				sm.slot_radius, _digits(_dim_edit(chrome))])
	var radius_label: Label = chrome.find_child("RadiusLabel", true, false)
	check(radius_label != null and str(radius_label.text) == "Radius",
			"Slot arms on Radius (got '%s')" % (str(radius_label.text) if radius_label != null else ""))
	await _type_text(ctx, "5")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(is_equal_approx(sm.slot_radius, 5.0), "typed slot radius is 5 (got %.4f)" % sm.slot_radius)

	sm.fit_view()
	await process_frame
	await process_frame
	await _click_uv(ctx, Vector2(0, 0), "Slot centre 1")
	await process_frame
	await process_frame
	radius_label = chrome.find_child("RadiusLabel", true, false)
	check(radius_label != null and str(radius_label.text) == "c-c",
			"after the first centre the field is c-c (got '%s')" % (
				str(radius_label.text) if radius_label != null else ""))
	var cc_digits := _digits(_dim_edit(chrome))
	check(not _parses_to(_dim_edit(chrome), sm.slot_radius),
			"c-c is not prefilled with the radius %.4f (got '%s')" % [sm.slot_radius, cc_digits])
	check(cc_digits == "" or _parses_to(_dim_edit(chrome), float(sm._tool_numeric.get("slot_cc", -1.0))),
			"c-c is empty or the slot's own last c-c (got '%s')" % cc_digits)

	await _type_text(ctx, "30")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	check(_status_blob().contains("Slot c-c 30"), "typed c-c commits 30 (log '%s')" % _status_blob())
	check(is_equal_approx(float(sm._tool_numeric.get("slot_cc", -1.0)), 30.0),
			"slot remembered c-c 30")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SLOT)
	await process_frame
	await process_frame
	radius_label = chrome.find_child("RadiusLabel", true, false)
	check(radius_label != null and str(radius_label.text) == "Radius",
			"re-armed Slot is Radius again (got '%s')" % (
				str(radius_label.text) if radius_label != null else ""))
	check(_parses_to(_dim_edit(chrome), 5.0) and not _parses_to(_dim_edit(chrome), 30.0),
			"re-armed Slot shows radius 5, not c-c 30 (got '%s')" % _digits(_dim_edit(chrome)))
	await _click_uv(ctx, Vector2(8, 3), "Slot centre 2")
	await process_frame
	await process_frame
	radius_label = chrome.find_child("RadiusLabel", true, false)
	check(radius_label != null and str(radius_label.text) == "c-c",
			"second slot centre relabels to c-c")
	check(_parses_to(_dim_edit(chrome), 30.0) and not _parses_to(_dim_edit(chrome), 5.0),
			"c-c shows the slot's own last 30, not the radius (got '%s')" % _digits(_dim_edit(chrome)))


func _test_trim_trail(ctx: FilmContext) -> void:
	print("- Power Trim drag trail clears on release")
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_line(-20, 0, 20, 0)
	sm.sketch.add_line(0, -20, 0, 20)
	sm.run_solve()
	sm.fit_view()
	await process_frame
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await process_frame
	await _drag_between(ctx, Vector2(-15, 0), Vector2(15, 0))
	await process_frame
	await process_frame
	check(_status_blob().contains("Trimmed"), "drag across the crossing trims")
	var trail: Node = sm.find_child("TrimDragTrail", true, false)
	var trail_gone: bool = trail == null or not is_instance_valid(trail) \
			or trail.is_queued_for_deletion() or not trail.visible
	check(trail_gone, "trim drag trail node is hidden or freed")
	var red_preview := false
	if sm._preview_node != null and sm._preview_node.mesh != null and sm._preview_material != null \
			and not sm._trim_dragging:
		var col: Color = sm._preview_material.albedo_color
		red_preview = col.r > 0.9 and col.g < 0.4 and col.b < 0.4
	check(not red_preview, "trim hover preview is not left red on the canvas")


func _test_new_document(ctx: FilmContext) -> void:
	print("- File → New and Open drop the previous document's numbers")
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	# A new sketch in the same document goes through reset_finish_for_new_sketch.
	# That must put Extrude back to 20 without wiping this document's tool numbers.
	chrome.reset_finish_for_new_sketch()
	chrome.sync_for_tool()
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	check(_parses_to(_dim_edit(chrome), 22.5),
			"same-document new sketch keeps circle 22.5 (got '%s')" % _digits(_dim_edit(chrome)))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	check(_parses_to(_dim_edit(chrome), 18.0),
			"same-document new sketch keeps line 18 (got '%s')" % _digits(_dim_edit(chrome)))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await _click_uv(ctx, Vector2.ZERO, "Circle for 45")
	await process_frame
	await _type_text(ctx, "45")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(is_equal_approx(sm.circle_radius, 45.0), "circle radius is 45 before New (got %.4f)" % sm.circle_radius)
	_show_distance(chrome, 5.0)
	await process_frame
	await process_frame
	check(_parses_to(_distance_edit(chrome), 5.0),
			"extrude distance is 5 before New (got '%s')" % _digits(_distance_edit(chrome)))
	ctx.main._on_file_menu(0)
	await process_frame
	await process_frame
	if ctx.main.confirm_dialog != null and ctx.main.confirm_dialog.visible:
		ctx.main._on_discard_confirmed()
		await process_frame
		await process_frame
	check(str(ctx.main.status_label.text).contains("New — empty part"),
			"File → New status (got '%s')" % str(ctx.main.status_label.text))
	check(_parses_to(_distance_edit(chrome), 20.0) and not _parses_to(_distance_edit(chrome), 5.0),
			"Extrude distance is the default 20 after New (got '%s')" % _digits(_distance_edit(chrome)))
	check(is_equal_approx(sm.circle_radius, 10.0), "circle radius default 10 after New (got %.4f)" % sm.circle_radius)
	check(not sm._tool_numeric.has("line"), "Line length from the discarded doc is gone")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	check(_parses_to(_distance_edit(chrome), 20.0),
			"new sketch Extrude distance stays 20 (got '%s')" % _digits(_distance_edit(chrome)))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	check(_parses_to(_dim_edit(chrome), 10.0) and not _parses_to(_dim_edit(chrome), 45.0),
			"Circle radius is the default 10, not 45 (got '%s')" % _digits(_dim_edit(chrome)))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	var line_digits := _digits(_dim_edit(chrome))
	check(line_digits == "" or not _parses_to(_dim_edit(chrome), 5.0),
			"Line length is not the discarded 5 (got '%s')" % line_digits)
	check(not _parses_to(_dim_edit(chrome), 18.0) and not _parses_to(_dim_edit(chrome), 45.0),
			"Line length is not a previous tool or document value (got '%s')" % line_digits)

	var path := "/tmp/sx037-blank.sxp"
	check(ctx.main.view.save(path), "saved a document to reopen")
	sm.circle_radius = 50.0
	_show_distance(chrome, 5.0)
	sm.remember_numeric(5.0, "line")
	await process_frame
	await process_frame
	check(_parses_to(_distance_edit(chrome), 5.0),
			"extrude distance is 5 before Open (got '%s')" % _digits(_distance_edit(chrome)))
	ctx.main._open_document(path)
	await process_frame
	await process_frame
	check(str(ctx.main.status_label.text).begins_with("Opened "),
			"Open status (got '%s')" % str(ctx.main.status_label.text))
	check(is_equal_approx(sm.circle_radius, 10.0), "Open resets circle radius to 10 (got %.4f)" % sm.circle_radius)
	check(not sm._tool_numeric.has("line"), "Open clears the previous line length")
	check(_parses_to(_distance_edit(chrome), 20.0) and not _parses_to(_distance_edit(chrome), 5.0),
			"Open resets Extrude distance to 20 (got '%s')" % _digits(_distance_edit(chrome)))
	await FilmUI.enter_sketch(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	check(_parses_to(_dim_edit(chrome), 10.0) and not _parses_to(_dim_edit(chrome), 50.0),
			"Circle radius after Open is 10, not 50 (got '%s')" % _digits(_dim_edit(chrome)))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	check(not _parses_to(_dim_edit(chrome), 5.0),
			"Line length after Open is not 5 (got '%s')" % _digits(_dim_edit(chrome)))


func _show_distance(chrome: SketchContextChrome, v: float) -> void:
	if chrome == null or chrome._extrude_spin == null:
		return
	chrome._distance_line_invalid = false
	chrome._distance_invalid_raw = ""
	chrome._distance_syncing = true
	chrome._extrude_spin.value = v
	var edit := chrome._extrude_spin.get_line_edit()
	if edit != null:
		edit.text = chrome._format_distance_text(v)
	chrome._distance_syncing = false
	chrome._distance_origin = v
	chrome._refresh_extrude_readout(v)


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


func _digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := str(edit.text).strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	elif text.ends_with(" AF"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("AF"):
		text = text.substr(0, text.length() - 2)
	return text.strip_edges()


func _parses_to(edit: LineEdit, v: float) -> bool:
	if v < 0.0:
		return false
	var text := _digits(edit)
	if text == "" or not text.is_valid_float():
		return false
	return is_equal_approx(float(text), v)


func _status_blob() -> String:
	return " ".join(_status_log)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	vp.push_input(up)
	await process_frame


func _drag_between(ctx: FilmContext, from_uv: Vector2, to_uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var a := FilmUI.model_to_screen(ctx, sm.to_model(from_uv))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(to_uv))
	check(FilmUI.require_on_screen(ctx, a, "trim drag start"), "trim drag start on screen")
	check(FilmUI.require_on_screen(ctx, b, "trim drag end"), "trim drag end on screen")
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	await process_frame
	var mid: Node = sm.find_child("TrimDragTrail", true, false)
	check(mid != null and is_instance_valid(mid) and mid.visible and not mid.is_queued_for_deletion(),
			"trim drag trail is visible while the drag is down")
	for i in range(1, 17):
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / 16.0)
		m.global_position = m.position
		vp.push_input(m)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await process_frame


func _type_text(ctx: FilmContext, text: String) -> void:
	for i in text.length():
		await _push_char(ctx, text.substr(i, 1))


func _push_char(ctx: FilmContext, ch: String) -> void:
	var code := KEY_NONE
	var unicode := ch.unicode_at(0)
	if unicode >= 48 and unicode <= 57:
		code = (KEY_0 + (unicode - 48)) as Key
	elif unicode == 46:
		code = KEY_PERIOD
	else:
		push_error("no key for %s" % ch)
		return
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
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
	await process_frame
