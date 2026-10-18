# Rung 6 WP3 — Horizontal on two endpoints of an arc. Line-horizontal stays.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_horizontal_points.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SPAN := 80.0


func _init() -> void:
	print("rung06 horizontal points")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _hook(ctx)
	await _line_h(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _hook(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector3.ZERO, SPAN)
	# R20-ish hook: centre (0, 0), start (20, 0), end (-20, 8) — different Y.
	sm.sketch.add_arc(0.0, 0.0, 20.0, 0.0, PI * 0.75)
	sm.run_solve()
	await process_frame
	var arc := _last_arc(sm)
	check(arc != "", "hook arc exists")
	var info0: Dictionary = sm.sketch.entity_info(arc)
	var y0: float = (info0["end"] as Vector2).y
	check(absf(y0) > 0.5, "ends start at different Y")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, info0["start"], "Hook start")
	var end_screen := FilmUI.sketch_uv_to_screen(ctx, info0["end"])
	check(end_screen != Vector2.ZERO, "hook end projects on screen")
	# Ctrl+click: FilmActor.tap_x11 does not carry modifiers; viewport_click does.
	await FilmUI.viewport_click(ctx, end_screen, FilmUICues.alert("Click", "Hook end"), true)
	check(sm.selected.size() == 2,
			"two endpoints selected (got %d roles=%s)" % [sm.selected.size(), str(sm.selected_roles)])
	await _click_horizontal(ctx)
	check(str(ctx.main.status_label.text).contains("Horizontal"),
			"status names Horizontal (%s)" % ctx.main.status_label.text)
	var info: Dictionary = sm.sketch.entity_info(arc)
	var a: Vector2 = info["start"]
	var b: Vector2 = info["end"]
	check(absf(a.y - b.y) <= 0.2, "same Y ± 0.2 (%.3f vs %.3f)" % [a.y, b.y])
	check(str(info.get("type", "")) == "arc", "still an arc")
	check(float(info.get("radius", 0.0)) > 1.0, "arc did not collapse (r=%.3f)" % float(info.get("radius", 0.0)))
	# One endpoint refuses (chip may be absent — that is also a refuse).
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(0, -12), "Clear")
	await FilmUI.click_sketch(ctx, sm, a, "One end")
	var n_before := sm.sketch.constraint_ids().size()
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if FilmUI.find_button(chrome, "Horizontal") != null:
		await _click_horizontal(ctx)
	check(sm.sketch.constraint_ids().size() == n_before, "one endpoint adds nothing")


func _line_h(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, Vector2(-10, -25), "Stray start", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(10, -25), "Stray end", SPAN)
	check(_horizontal_line_count(sm) >= 1, "line-horizontal still works")


func _click_horizontal(ctx: FilmContext) -> void:
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := FilmUI.find_button(chrome, "Horizontal")
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Horizontal", "Horizontal relation"))
	else:
		var more := FilmUI.find_button(chrome, "… More")
		var item := -1
		if more is MenuButton:
			var popup := (more as MenuButton).get_popup()
			for i in popup.item_count:
				if popup.get_item_text(i) == "Horizontal":
					item = popup.get_item_id(i)
					break
		check(item >= 0, "Horizontal is on the chip row or in … More")
		if item >= 0:
			await FilmUI.activate_menu_id(ctx, more as MenuButton, item,
					FilmUICues.alert("Horizontal", "Horizontal relation"))
	await process_frame
	await process_frame


func _last_arc(sm: SketchMode) -> String:
	var last := ""
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "arc":
			last = str(id)
	return last


func _horizontal_line_count(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.y - b.y) <= 0.2:
			n += 1
	return n
