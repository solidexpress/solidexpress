# sx-036 N12 — a second click on the finish-bar Extrude pixel must not set jaw_af.
# The blank is a ground sketch, Distance 10, one real Extrude click, then another
# click at that same screen position (immediately, and again after 700 ms).
# Run: DISPLAY=:1 LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_n12_extrude.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 N12 extrude second click")
	FilmUI.reset_fail_count()
	await test_second_click_on_blank()
	await test_af_chips_when_jaw_in_use()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_second_click_on_blank() -> void:
	print("-- N12 blank extrude, second click at the same pixel")
	var ctx := await _boot()
	await _ground_rectangle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := chrome.extrude_button()
	check(btn != null and btn.is_visible_in_tree(), "Extrude button is visible")
	if btn == null:
		await _shutdown(ctx)
		return
	await _type_distance(ctx, "10")
	var centre := btn.get_global_rect().get_center()
	var doc = ctx.view.doc
	var bodies0 := doc.body_ids().size()
	var ex0 := _extrude_count(doc)
	var jaw0 := _var_value(doc, "jaw_af")
	_status_log.clear()
	var vp: Viewport = ctx.main.get_viewport()
	await _x11_click_screen(vp, centre)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	var last := _last_status()
	print("N12 after extrude status='%s' log=%s" % [last, str(_status_log)])
	check(doc.body_ids().size() == bodies0 + 1,
			"N12 one new body (%d -> %d)" % [bodies0, doc.body_ids().size()])
	check(_extrude_count(doc) == ex0 + 1, "N12 one new extrude")
	check(last == "Extrude Blind 10.0000 mm",
			"N12 status is Extrude Blind 10.0000 mm (got '%s')" % last)
	check(not _log_has("jaw_af"), "N12 no jaw_af text after the extrude (log=%s)" % str(_status_log))
	check(str(doc.active_configuration()) == "",
			"N12 active configuration stays empty (got '%s')" % str(doc.active_configuration()))
	var jaw_box := ctx.main.interaction.find_child("StripJawAF", true, false) as Control
	check(jaw_box == null or not jaw_box.is_visible_in_tree(),
			"N12 AF chips hidden on a blank body")
	var shield := ctx.main.interaction.find_child("FinishClickShield", true, false) as Control
	check(shield != null and shield.visible, "N12 click shield covers the Extrude pixel")
	if shield != null:
		check(shield.get_global_rect().has_point(centre),
				"N12 shield contains the Extrude pixel %s (shield %s)" % [centre, shield.get_global_rect()])
	var bodies1 := doc.body_ids().size()
	var ex1 := _extrude_count(doc)
	var log_n := _status_log.size()
	await _x11_click_screen(vp, centre)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	check(_extrude_count(doc) == ex1, "N12 second click adds no extrude")
	check(doc.body_ids().size() == bodies1, "N12 second click adds no body")
	check(not _log_grew(log_n, last),
			"N12 second click leaves status Extrude Blind 10.0000 mm (log=%s)" % str(_status_log))
	check(str(ctx.main.status_label.text) == "Extrude Blind 10.0000 mm",
			"N12 status label stays Extrude Blind 10.0000 mm (got '%s')" % ctx.main.status_label.text)
	check(not _log_has("jaw_af"), "N12 second click writes no jaw_af (log=%s)" % str(_status_log))
	check(is_equal_approx(_var_value(doc, "jaw_af"), jaw0),
			"N12 jaw_af unchanged (was %.4f now %.4f)" % [jaw0, _var_value(doc, "jaw_af")])
	check(str(doc.active_configuration()) == "", "N12 second click does not activate a config")
	# Soft-GL walk: the follow-up click can land after the 600 ms jaw guard.
	await create_timer(0.7).timeout
	log_n = _status_log.size()
	await _x11_click_screen(vp, centre)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	print("N12 log after late click=%s" % str(_status_log))
	check(_extrude_count(doc) == ex1, "N12 late click adds no extrude")
	check(doc.body_ids().size() == bodies1, "N12 late click keeps one body")
	check(not _log_grew(log_n, last),
			"N12 late click adds no status (log=%s)" % str(_status_log))
	check(str(ctx.main.status_label.text) == "Extrude Blind 10.0000 mm",
			"N12 late status is still Extrude Blind 10.0000 mm (got '%s')" % ctx.main.status_label.text)
	check(not _log_has("jaw_af"), "N12 late click writes no jaw_af")
	check(str(doc.active_configuration()) == "", "N12 late click does not activate a config")
	await _shutdown(ctx)


func test_af_chips_when_jaw_in_use() -> void:
	print("-- N12b AF chips show once the body uses jaw_af")
	var ctx := await _boot()
	var doc = ctx.view.doc
	var fid: String = doc.graph_add_primitive("box", 40, 40, 10, Vector3.ZERO)
	var hole: String = doc.graph_add_hole(fid, "hex", Vector3(0, 0, 10), Vector3(0, 0, -1),
			10.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	check(fid != "" and hole != "", "N12b box and hex hole exist")
	var params := {
		"target": fid,
		"type": "hex",
		"position": [0, 0, 10],
		"direction": [0, 0, -1],
		"diameter": "=jaw_af+clearance",
		"depth": 0,
	}
	check(doc.graph_set_params(hole, JSON.stringify(params)),
			"N12b diameter expression is jaw_af (err %s)" % str(doc.last_graph_error()))
	var body := ctx.view.body_of_feature(fid)
	ctx.view.select_entity(body, "")
	ctx.view.refresh()
	await process_frame
	await process_frame
	var jaw_box := ctx.main.interaction.find_child("StripJawAF", true, false) as Control
	var jaw := ctx.main.interaction.find_child("StripJaw12", true, false) as Button
	check(jaw_box != null and jaw_box.is_visible_in_tree(), "N12b AF chips visible when jaw_af is in use")
	check(jaw != null and jaw.is_visible_in_tree(), "N12b StripJaw12 is visible")
	if jaw != null and jaw.is_visible_in_tree():
		_status_log.clear()
		await _x11_click_screen(jaw.get_viewport(), jaw.get_global_rect().get_center())
		await process_frame
		await process_frame
		_capture_status(ctx.main)
		var got := _last_status()
		print("N12b status='%s'" % got)
		check(got == "jaw_af = 12 (config 12)",
				"N12b status is jaw_af = 12 (config 12) (got '%s')" % got)
		check(is_equal_approx(_var_value(doc, "jaw_af"), 12.0), "N12b jaw_af == 12")
	else:
		check(false, "N12b status is jaw_af = 12 (config 12)")
		check(false, "N12b jaw_af == 12")
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


func _type_distance(ctx: FilmContext, text: String) -> void:
	var edit := ctx.main.sketch_chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(edit != null and edit.is_visible_in_tree(), "Distance field is visible")
	if edit == null:
		return
	await _x11_click_screen(edit.get_viewport(), edit.get_global_rect().get_center())
	await process_frame
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := (KEY_0 + (ch - 48)) as Key
		await _push_key(edit.get_viewport(), code, ch)


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


func _extrude_count(doc) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _var_value(doc, var_name: String) -> float:
	for e in doc.list_variables():
		if str(e.get("name", "")) == var_name:
			return float(e.get("value", NAN))
	return NAN


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _log_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _log_grew(from_index: int, previous: String) -> bool:
	for i in range(from_index, _status_log.size()):
		if _status_log[i] != previous:
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
	check(root.size == ROOT_SIZE, "root is %s (got %s)" % [ROOT_SIZE, root.size])
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
