# Rung 1 replan 8 WP3 — a cut that boolean-succeeds but wrecks the body is refused with a named status and rolled back.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_cut.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan8 WP3 cut refusal")
	FilmUI.reset_fail_count()
	await test_cut_guard()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _extrude_count(doc) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _volume(doc, body: String) -> float:
	return float(doc.measure_mass(body).get("volume", -1.0))


func _top_face(doc, body: String) -> String:
	for f in doc.get_face_ids(body):
		if absf(doc.face_midpoint(f).z - 10.0) < 0.01:
			return f
	return ""


func test_cut_guard() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 50.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	var doc = ctx.view.doc
	var body: String = doc.body_ids()[0]
	var base_vol := _volume(doc, body)
	check(absf(base_vol - PI * 50.0 * 50.0 * 10.0) < 1.0, "base disc volume is %.1f" % base_vol)
	var top := _top_face(doc, body)
	check(top != "", "top face exists")
	var extrudes_before := _extrude_count(doc)

	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	var big: String = sm.sketch.add_circle(0.0, 0.0, 45.0)
	_status_log.clear()
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [])
	await process_frame
	check(_status_has("Cut would remove 81% of the body"), "an 81%% cut gets the named refuse (log: %s)" % str(_status_log))
	check(sm.active, "the sketch session stays open after the refuse")
	check(_extrude_count(doc) == extrudes_before, "the refused cut leaves no extrude feature")
	check(absf(_volume(doc, doc.body_ids()[0]) - base_vol) < 1.0, "the body volume is unchanged after the refuse")

	sm.sketch.remove_entity(big)
	sm.sketch.add_circle(200.0, 0.0, 5.0)
	_status_log.clear()
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [])
	await process_frame
	check(_status_has("Cut removed nothing"), "a contour off the body gets the named refuse (log: %s)" % str(_status_log))
	check(sm.active and _extrude_count(doc) == extrudes_before, "nothing was cut and the session is open")

	for id in sm.sketch.entity_ids():
		sm.sketch.remove_entity(id)
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	_status_log.clear()
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [])
	await process_frame
	await process_frame
	check(not sm.active, "a small hole is accepted and the session ends")
	check(_extrude_count(doc) == extrudes_before + 1, "the hole adds exactly one extrude feature")
	var want := base_vol - PI * 25.0 * 10.0
	var got := _volume(doc, doc.body_ids()[0])
	check(absf(got - want) < 1.0, "hole volume %.1f matches %.1f" % [got, want])
	await _shutdown(ctx)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false

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
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


