# Rung 1 replan 12 WP5 — the timeline edit panel closes on Esc and on an empty-viewport click
# with the Distance field focused (the GUI state), through real pushed events.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_panel.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan12 WP5 timeline panel dismiss")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_key(code: int, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _push_click(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
	await process_frame


func _empty_point(main) -> Vector2:
	for p in [Vector2(1150, 150), Vector2(1100, 600), Vector2(900, 120), Vector2(700, 650)]:
		var ray: Array = main.interaction._model_ray(p)
		if main.view.pick_info(ray[0], ray[1]).is_empty():
			return p
	return Vector2.INF


func _distance(doc, fid: String) -> float:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			var p = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(p) == TYPE_DICTIONARY:
				return float((p as Dictionary).get("distance", -1.0))
	return -1.0


## Open the panel on `fid`, type 14 + Enter into Distance, and return the focused LineEdit.
func _open_and_type(main, fid: String) -> LineEdit:
	var pp = main.timeline.property_panel
	pp.open(fid)
	await process_frame
	await process_frame
	var spin: SpinBox = pp._spin_for_key("distance")
	var le: LineEdit = spin.get_line_edit()
	le.grab_focus()
	le.select_all()
	await process_frame
	await _push_key(KEY_1, 49)
	await _push_key(KEY_4, 52)
	await _push_key(KEY_ENTER)
	return le


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	var pp = main.timeline.property_panel
	await FilmUI.enter_sketch(ctx)
	sm.sketch.add_circle(0.0, 0.0, 8.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	var ex_fid := ""
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			ex_fid = str(f.get("id", ""))
	check(ex_fid != "", "extrude feature exists")
	check(absf(_distance(view.doc, ex_fid) - 10.0) < 0.01, "distance starts at 10")

	var le := await _open_and_type(main, ex_fid)
	check(pp.visible, "panel is open after typing 14 + Enter")
	check(absf(_distance(view.doc, ex_fid) - 14.0) < 0.01, "Enter previews distance 14 (got %.3f)" % _distance(view.doc, ex_fid))
	check(le.has_focus(), "the Distance field keeps focus after Enter (the GUI state)")
	await _push_key(KEY_ESCAPE)
	check(not pp.visible, "one Esc closes the panel with Distance focused")
	check(absf(_distance(view.doc, ex_fid) - 10.0) < 0.01, "Esc cancels the preview (distance %.3f)" % _distance(view.doc, ex_fid))
	check(str(main.status_label.text) == "Edits cancelled", "status is `Edits cancelled` (got `%s`)" % str(main.status_label.text))

	le = await _open_and_type(main, ex_fid)
	check(pp.visible and absf(_distance(view.doc, ex_fid) - 14.0) < 0.01, "panel reopened with distance 14 previewed")
	var empty := _empty_point(main)
	check(empty != Vector2.INF, "found a background pixel off the solid and off the chrome (%s)" % str(empty))
	await _push_click(empty)
	check(not pp.visible, "one click on empty viewport closes the panel")
	check(absf(_distance(view.doc, ex_fid) - 14.0) < 0.01, "click-away keeps the previewed distance (got %.3f)" % _distance(view.doc, ex_fid))

	main.queue_free()
	await process_frame
	await process_frame
