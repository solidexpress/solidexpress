# Rung 1 replan 8 WP2 — two selected circles get a Shaft Lines chip; the connected blank passes check_rung01 blank.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_shaft.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan8 WP2 shaft lines")
	FilmUI.reset_fail_count()
	await test_shaft_web()
	await test_refuses_non_circles()
	await test_mouse_select_then_chip()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_shaft_web() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	check(a != "" and b != "", "two circles exist")
	var none: Array = sm.selection_actions()
	check(not none.has("shaft_lines"), "no Shaft Lines chip with nothing selected")
	sm._set_selected([a])
	check(not sm.selection_actions().has("shaft_lines"), "no Shaft Lines chip with one circle")
	sm._set_selected([a, b])
	await process_frame
	await process_frame
	check(sm.selection_actions().has("shaft_lines"), "two circles offer shaft_lines")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "the Shaft Lines chip is visible")
	_status_log.clear()
	var ok := await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shaft Lines", "Shaft Lines"))
	check(ok, "the Shaft Lines chip was clicked")
	await process_frame

	var lines := 0
	var tangents := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	for cid in sm.sketch.constraint_ids():
		if str(sm.sketch.constraint_info(cid).get("type", "")) == "tangent":
			tangents += 1
	check(lines == 2, "two shaft lines were added (got %d)" % lines)
	check(tangents == 2, "each shaft line is tangent to the small circle (got %d tangent constraints)" % tangents)
	var ys: Array[float] = []
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "line":
			ys.append(float((info["start"] as Vector2).y))
			check(absf(float((info["start"] as Vector2).y) - float((info["end"] as Vector2).y)) < 1e-3, "a shaft line is parallel to the centre line")
			check(absf(float((info["end"] as Vector2).x) - 179.844) < 0.01, "a shaft line ends on the large circle at x = 179.844 (got %.3f)" % float((info["end"] as Vector2).x))
	ys.sort()
	check(ys.size() == 2 and absf(ys[0] + 10.0) < 1e-3 and absf(ys[1] - 10.0) < 1e-3, "the shaft lines sit at y = -10 and y = +10")
	check(_status_has("Shaft lines: 2 added"), "status reports 2 lines added")
	check(SketchMode.profile_is_closed(sm.sketch), "the web closes the profile")

	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	check(doc.body_ids().size() == 1, "one connected blank body (got %d)" % doc.body_ids().size())
	var body: String = doc.body_ids()[0]
	var bb: Dictionary = doc.measure_bbox(body)
	check(absf(float(bb["min"].x) + 10.0) < 0.05, "blank min X is -10 (got %.3f)" % float(bb["min"].x))
	check(absf(float(bb["max"].x) - 222.5) < 0.05, "blank max X is 222.5 (got %.3f)" % float(bb["max"].x))
	check(absf(float(bb["max"].y) - 22.5) < 0.05 and absf(float(bb["min"].y) + 22.5) < 0.05, "blank Y is +-22.5")
	check(absf(float(bb["max"].z) - 10.0) < 0.05, "blank is 10 mm tall")
	var vol := float(doc.measure_mass(body).get("volume", 0.0))
	check(absf(vol - 53128.0) < 60.0, "blank volume is the handout shape, 53128 mm3 (got %.1f)" % vol)
	var out := "/tmp/replan8_blank.3mf"
	check(doc.export_3mf(out), "3MF export succeeded")
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var output: Array = []
	var code := OS.execute("python3", [repo.path_join("tools/check_rung01.py"), "blank", out], output, true)
	print("\n".join(output))
	check(code == 0, "tools/check_rung01.py blank passes on the exported 3MF (exit %d)" % code)
	await _shutdown(ctx)


func test_refuses_non_circles() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(5.0, 0.0, 30.0)
	sm._set_selected([a, b])
	_status_log.clear()
	var n: int = int(sm.call("shaft_lines_selected")) if sm.has_method("shaft_lines_selected") else -1
	check(n == 0, "nested circles add no shaft lines")
	check(_status_has("must sit outside the large one"), "nested circles get a named refuse")
	var c: String = sm.sketch.add_circle(100.0, 0.0, 30.0)
	var d: String = sm.sketch.add_circle(200.0, 0.0, 30.0)
	sm._set_selected([c, d])
	_status_log.clear()
	n = int(sm.call("shaft_lines_selected")) if sm.has_method("shaft_lines_selected") else -1
	check(n == 0 and _status_has("same size"), "two equal circles get a named refuse")
	var l: String = sm.sketch.add_line(0.0, 50.0, 10.0, 50.0)
	sm._set_selected([a, l])
	_status_log.clear()
	n = int(sm.call("shaft_lines_selected")) if sm.has_method("shaft_lines_selected") else -1
	check(n == 0 and _status_has("select two circles first"), "a circle plus a line is refused with a named status")
	await _shutdown(ctx)


func test_mouse_select_then_chip() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(200.0, 0.0, 22.5)
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await _click_uv(ctx, vp, Vector2(200.0, 22.5))
	await process_frame
	await process_frame
	check(sm.selected.size() == 2, "two Select-tool clicks on the circle edges select both (got %d)" % sm.selected.size())
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "Shaft Lines chip appears after the mouse selection")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shaft Lines", "Shaft Lines"))
	var lines := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	check(lines == 2, "the chip adds two lines after a mouse selection (got %d)" % lines)
	check(SketchMode.profile_is_closed(sm.sketch), "the mouse-selected web closes the profile")
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


