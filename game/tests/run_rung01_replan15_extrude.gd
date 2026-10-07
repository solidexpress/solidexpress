# Rung 1 replan 15 WP5 — a real click on Extrude extrudes once, and the
# success status is only `Extrude <End> <depth> mm`.
# Clicks under test are Viewport.push_input motion + press + release.
# Run: DISPLAY=:1 LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan15_extrude.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const SMALL_SIZE := Vector2i(1024, 768)

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
	print("rung01 replan15 WP5 extrude click")
	FilmUI.reset_fail_count()
	await test_blind_then_second_click()
	await test_focused_button()
	await test_cut_blind()
	await test_cut_up_to_surface()
	await test_invalid_distance()
	await test_overlap_at_1024()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_blind_then_second_click() -> void:
	print("-- A0/A1/A2/A3 blind extrude, second pixel, then AF 12")
	var ctx := await _boot(ROOT_SIZE)
	await _ground_rectangle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := chrome.extrude_button()
	check(btn != null, "Extrude button exists")
	if btn == null:
		await _shutdown(ctx)
		return
	var edit := await _type_distance(ctx, "10")
	print("A1 distance text='%s'" % (edit.text if edit != null else ""))
	var before := btn.get_global_rect()
	var centre := before.get_center()
	print("A0 ExtrudeButton before %s center=%s visible=%s" % [before, centre, btn.is_visible_in_tree()])
	check(btn.is_visible_in_tree() and FilmUI.is_on_screen(ctx, centre),
			"A0 Extrude button visible and on screen before the click")
	var doc = ctx.view.doc
	var bodies0 := doc.body_ids().size()
	var ex0 := _extrude_count(doc)
	_status_log.clear()
	var vp: Viewport = ctx.main.get_viewport()
	print("A1 focus before click: %s" % _focus_desc(vp))
	await _x11_click_screen(vp, centre)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	_print_strip_overlap(ctx, centre, "A0")
	var bodies1 := doc.body_ids().size()
	var ex1 := _extrude_count(doc)
	var last := _last_status()
	print("A1 last status='%s' log=%s" % [last, str(_status_log)])
	if ex1 == ex0:
		_dump_hits(ctx.main, centre)
	check(bodies1 == bodies0 + 1, "A1 exactly one new body (%d -> %d)" % [bodies0, bodies1])
	check(ex1 == ex0 + 1, "A1 exactly one new extrude (%d -> %d)" % [ex0, ex1])
	check(last == "Extrude Blind 10.0000 mm",
			"A1 last status is Extrude Blind 10.0000 mm (got '%s')" % last)
	check(not _log_has("jaw_af"), "A1 no status contains jaw_af (log=%s)" % str(_status_log))
	# jaw_af is seeded to 10 on every new document. The chip is what saves
	# configuration "10"; a plain Extrude must leave the active config empty.
	check(str(doc.active_configuration()) == "",
			"A1 the AF chip did not run (active='%s')" % str(doc.active_configuration()))
	if bodies1 > 0:
		var ext := _extents(doc, doc.body_ids()[0])
		check(absf(ext.x - 40.0) <= 0.2 and absf(ext.y - 20.0) <= 0.2 and absf(ext.z - 10.0) <= 0.2,
				"A1 bbox is 40 × 20 × 10 (got %s)" % str(ext))
	else:
		check(false, "A1 bbox is 40 × 20 × 10 (no body)")
	var log_n := _status_log.size()
	var last_before := last
	await _x11_click_screen(vp, centre)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	var stray := false
	for i in range(log_n, _status_log.size()):
		if _status_log[i] != last_before:
			stray = true
	print("A2 log after second click=%s" % str(_status_log))
	check(_extrude_count(doc) == ex1, "A2 extrude feature count still %d" % ex1)
	check(doc.body_ids().size() == bodies1, "A2 body count still %d" % bodies1)
	check(not stray, "A2 status log has no new entry (log=%s)" % str(_status_log))
	check(str(doc.active_configuration()) == "",
			"A2 the AF chip did not run (active='%s')" % str(doc.active_configuration()))
	check(str(doc.last_graph_error()) == "",
			"A2 last_graph_error empty (got '%s')" % str(doc.last_graph_error()))
	await create_timer(0.7).timeout
	var jaw := ctx.main.interaction.find_child("StripJaw12", true, false) as Button
	check(jaw != null and jaw.is_visible_in_tree(), "A3 StripJaw12 is visible after the window")
	if jaw != null:
		_status_log.clear()
		await _x11_click_screen(jaw.get_viewport(), jaw.get_global_rect().get_center())
		await process_frame
		await process_frame
		_capture_status(ctx.main)
	var jaw_last := _last_status()
	print("A3 last status='%s'" % jaw_last)
	check(jaw_last == "jaw_af = 12 (config 12)",
			"A3 status is jaw_af = 12 (config 12) (got '%s')" % jaw_last)
	check(_var_is(doc, "jaw_af", 12.0), "A3 jaw_af == 12 in list_variables")
	await _shutdown(ctx)


func test_focused_button() -> void:
	print("-- A1b focused Extrude button")
	var ctx := await _boot(ROOT_SIZE)
	await _ground_rectangle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := chrome.extrude_button()
	var edit := await _type_distance(ctx, "10")
	print("A1b distance text='%s'" % (edit.text if edit != null else ""))
	if btn != null:
		btn.grab_focus()
	await process_frame
	var doc = ctx.view.doc
	var bodies0 := doc.body_ids().size()
	var ex0 := _extrude_count(doc)
	var centre := btn.get_global_rect().get_center() if btn != null else Vector2.ZERO
	_status_log.clear()
	var vp: Viewport = ctx.main.get_viewport()
	print("A1b focus before click: %s" % _focus_desc(vp))
	await _x11_click_screen(vp, centre)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	var last := _last_status()
	print("A1b last status='%s' log=%s" % [last, str(_status_log)])
	if _extrude_count(doc) == ex0:
		_dump_hits(ctx.main, centre)
	check(doc.body_ids().size() == bodies0 + 1, "A1b exactly one new body")
	check(_extrude_count(doc) == ex0 + 1, "A1b exactly one new extrude")
	check(last == "Extrude Blind 10.0000 mm",
			"A1b last status is Extrude Blind 10.0000 mm (got '%s')" % last)
	check(not _log_has("jaw_af"), "A1b no status contains jaw_af (log=%s)" % str(_status_log))
	check(str(doc.active_configuration()) == "",
			"A1b the AF chip did not run (active='%s')" % str(doc.active_configuration()))
	if doc.body_ids().size() > 0:
		var ext := _extents(doc, doc.body_ids()[0])
		check(absf(ext.x - 40.0) <= 0.2 and absf(ext.y - 20.0) <= 0.2 and absf(ext.z - 10.0) <= 0.2,
				"A1b bbox is 40 × 20 × 10 (got %s)" % str(ext))
	else:
		check(false, "A1b bbox is 40 × 20 × 10 (no body)")
	await _shutdown(ctx)


func test_cut_blind() -> void:
	print("-- A4 cut blind 2.5")
	var ctx := await _blank_with_top_rect()
	if ctx == null:
		check(false, "A4 blank sketch on the top face")
		return
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_finish_op("cut")
	var edit := await _type_distance(ctx, "2.5")
	print("A4 distance text='%s'" % (edit.text if edit != null else ""))
	var btn := chrome.extrude_button()
	_status_log.clear()
	await _x11_click_screen(btn.get_viewport(), btn.get_global_rect().get_center())
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	var last := _last_status()
	print("A4 last status='%s' log=%s" % [last, str(_status_log)])
	check(last == "Extrude Blind 2.5000 mm",
			"A4 last status is Extrude Blind 2.5000 mm (got '%s')" % last)
	check(not _log_has("jaw_af"), "A4 no jaw_af text (log=%s)" % str(_status_log))
	await _shutdown(ctx)


func test_cut_up_to_surface() -> void:
	print("-- A5 cut Up To Surface")
	var ctx := await _blank_with_top_rect()
	if ctx == null:
		check(false, "A5 blank sketch on the top face")
		return
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_finish_op("cut")
	chrome.set_finish_end("to_face")
	chrome._on_finish_end_selected(3)
	await process_frame
	var opp := chrome.opposite_face_button()
	check(opp != null and opp.is_visible_in_tree(), "A5 Opposite face button is visible")
	if opp != null:
		await _x11_click_screen(opp.get_viewport(), opp.get_global_rect().get_center())
		await process_frame
		await process_frame
	var btn := chrome.extrude_button()
	_status_log.clear()
	await _x11_click_screen(btn.get_viewport(), btn.get_global_rect().get_center())
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	var last := _last_status()
	print("A5 last status='%s' log=%s" % [last, str(_status_log)])
	check(last == "Extrude Up To Surface 10.0000 mm",
			"A5 last status is Extrude Up To Surface 10.0000 mm (got '%s')" % last)
	check(not _log_has("jaw_af"), "A5 no jaw_af text (log=%s)" % str(_status_log))
	await _shutdown(ctx)


func test_invalid_distance() -> void:
	print("-- B1 invalid distance")
	var ctx := await _boot(ROOT_SIZE)
	await _ground_rectangle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var sm: SketchMode = ctx.main.sketch_mode
	var edit := await _type_distance(ctx, "abc")
	print("B1 distance text='%s'" % (edit.text if edit != null else ""))
	var doc = ctx.view.doc
	var ex0 := _extrude_count(doc)
	var btn := chrome.extrude_button()
	_status_log.clear()
	await _x11_click_screen(btn.get_viewport(), btn.get_global_rect().get_center())
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	var last := _last_status()
	print("B1 status='%s' log=%s" % [last, str(_status_log)])
	check(last.begins_with("Cannot read distance:"),
			"B1 status is the invalid-distance sentence (got '%s')" % last)
	check(_extrude_count(doc) == ex0, "B1 no feature added")
	check(sm.active, "B1 the sketch stays open")
	check(not _log_has("jaw_af"), "B1 no jaw_af text (log=%s)" % str(_status_log))
	await _shutdown(ctx)


## Print-only: the gate asks whether a chip sits under the Extrude pixel at 1024×768.
func test_overlap_at_1024() -> void:
	print("-- A0 measurement at 1024×768")
	var ctx := await _boot(SMALL_SIZE)
	await _ground_rectangle(ctx)
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	if btn == null:
		print("A0-1024 Extrude button missing")
		await _shutdown(ctx)
		return
	await _type_distance(ctx, "10")
	var centre: Vector2 = btn.get_global_rect().get_center()
	print("A0-1024 ExtrudeButton before %s center=%s" % [btn.get_global_rect(), centre])
	await _x11_click_screen(btn.get_viewport(), centre)
	await process_frame
	await process_frame
	_print_strip_overlap(ctx, centre, "A0-1024")
	await _shutdown(ctx)


func _ground_rectangle(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.run_solve()
	await process_frame


func _blank_with_top_rect() -> FilmContext:
	var ctx := await _boot(ROOT_SIZE)
	await _ground_rectangle(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	if doc.body_ids().is_empty():
		check(false, "blank extrude produced a body")
		await _shutdown(ctx)
		return null
	var body: String = doc.body_ids()[0]
	var top := _face_at(doc, body, 10.0)
	if top == "":
		check(false, "blank has a top face at z=10")
		await _shutdown(ctx)
		return null
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active:
		check(false, "top-face sketch is active")
		await _shutdown(ctx)
		return null
	sm.sketch.add_line(-15, -8, 15, -8)
	sm.sketch.add_line(15, -8, 15, 8)
	sm.sketch.add_line(15, 8, -15, 8)
	sm.sketch.add_line(-15, 8, -15, -8)
	sm.run_solve()
	await process_frame
	return ctx


func _face_at(doc, body: String, z: float) -> String:
	for f in doc.get_face_ids(body):
		var m: Vector3 = doc.face_midpoint(f)
		var bb: Dictionary = doc.measure_bbox(f)
		var ext: Vector3 = bb["max"] - bb["min"]
		if absf(m.z - z) < 0.01 and ext.z < 0.01 and ext.x * ext.y > 100.0:
			return f
	return ""


func _type_distance(ctx: FilmContext, text: String) -> LineEdit:
	var edit := ctx.main.sketch_chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(edit != null and edit.is_visible_in_tree(), "Distance field is visible for typing '%s'" % text)
	if edit == null:
		return null
	await _x11_click_screen(edit.get_viewport(), edit.get_global_rect().get_center())
	await process_frame
	await _type_keys(edit.get_viewport(), text)
	await process_frame
	return edit


func _type_keys(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code: Key = ch as Key
		if ch == 46:
			code = KEY_PERIOD
		elif ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		await _push_key(vp, code, ch)


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.unicode = unicode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
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


func _print_strip_overlap(ctx: FilmContext, centre: Vector2, tag: String) -> void:
	var strip := ctx.main.interaction.find_child("SelectionStrip", true, false) as Control
	var overlapped: PackedStringArray = PackedStringArray()
	if strip == null:
		print("%s SelectionStrip missing" % tag)
		print("OVERLAP none")
		return
	_print_strip_controls(strip, centre, overlapped, tag)
	if overlapped.is_empty():
		print("OVERLAP none")
	else:
		for n in overlapped:
			print("OVERLAP %s" % n)


func _print_strip_controls(node: Node, centre: Vector2, overlapped: PackedStringArray, tag: String) -> void:
	if node is Control:
		var c := node as Control
		var named := _control_label(c)
		if c is Button or named.begins_with("StripJaw"):
			var r := c.get_global_rect()
			print("%s %s rect=%s visible=%s" % [tag, named, r, c.is_visible_in_tree()])
			if c.is_visible_in_tree() and r.has_point(centre):
				overlapped.append(named)
	for child in node.get_children():
		_print_strip_controls(child, centre, overlapped, tag)


func _control_label(c: Control) -> String:
	var n := str(c.name)
	if n != "" and not n.begins_with("@"):
		return n
	if c is Button and str((c as Button).text) != "":
		return str((c as Button).text)
	return n


func _dump_hits(main: Node, pos: Vector2) -> void:
	var vp := main.get_viewport()
	print("FOCUS %s" % _focus_desc(vp))
	_dump_hits_walk(main, pos)


func _dump_hits_walk(node: Node, pos: Vector2) -> void:
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			print("HIT path=%s filter=%s rect=%s" % [c.get_path(), c.mouse_filter, c.get_global_rect()])
	for child in node.get_children():
		_dump_hits_walk(child, pos)


func _focus_desc(vp: Viewport) -> String:
	if vp == null:
		return "no viewport"
	var f := vp.gui_get_focus_owner()
	if f == null:
		return "none"
	return "%s (%s)" % [f.get_path(), f.get_class()]


func _extrude_count(doc) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _extents(doc, body: String) -> Vector3:
	var bb: Dictionary = doc.measure_bbox(body)
	return (bb["max"] as Vector3) - (bb["min"] as Vector3)


func _var_is(doc, var_name: String, want: float) -> bool:
	for e in doc.list_variables():
		if str(e.get("name", "")) == var_name:
			return absf(float(e.get("value", NAN)) - want) < 1e-6
	return false


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _log_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _capture_status(main) -> void:
	if main == null or main.status_label == null:
		return
	var t := str(main.status_label.text)
	if t == "":
		return
	if _status_log.is_empty() or _status_log[_status_log.size() - 1] != t:
		_status_log.append(t)


func _boot(size: Vector2i) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, size)
	check(root.size == size, "root is %s (got %s)" % [size, root.size])
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx != null and ctx.main != null:
		ctx.main.queue_free()
	await process_frame
	await process_frame
