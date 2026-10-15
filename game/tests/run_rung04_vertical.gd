# Rung 4 WP3 — Vertical on two endpoints turns an origin AF hex point-up.
# Click-built. The nut's flats-horizontal pose is a separate suite.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_vertical.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const AF := 7.65


func _init() -> void:
	print("rung04 vertical")
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
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	var across := FilmUI.find_button(ctx.main.sketch_chrome, "Across Flats")
	if across != null:
		await FilmUI.click_control(ctx, across, FilmUICues.alert("Across Flats", "AF variant"))
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Hex centre")
	await _hover(ctx, Vector2(1, 0))
	await _commit_dim(ctx, AF)
	var before := _points(sm)
	var r := AF / sqrt(3.0)
	check(_near(before, "y", -AF * 0.5) and _near(before, "Y", AF * 0.5),
			"flats at ±Y before Vertical (%.3f .. %.3f)" % [_axis(before, "y"), _axis(before, "Y")])
	check(_near(before, "x", -r) and _near(before, "X", r),
			"vertices on ±X before Vertical")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, Vector2(12, 12), "Stray line start")
	await FilmUI.click_sketch(ctx, sm, Vector2(22, 12), "Stray line end")
	var stray_h := _horizontal_count(sm)
	check(stray_h >= 1, "stray line is horizontal (%d)" % stray_h)

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var held := _points(sm)
	await FilmUI.click_sketch(ctx, sm, Vector2(r, 0), "One +X vertex")
	await _click_vertical(ctx)
	var after_one := _points(sm)
	check(_same_points(held, after_one), "one endpoint Vertical does not move the hex")
	check(not str(ctx.main.status_label.text).contains("Vertical:"),
			"one pick refuses (status %s)" % ctx.main.status_label.text)

	await FilmUI.click_sketch(ctx, sm, Vector2(-r, 0), "−X vertex")
	await _click_vertical(ctx)
	var after := _points(sm)
	check(str(ctx.main.status_label.text).contains("Vertical"),
			"status names Vertical (%s)" % ctx.main.status_label.text)
	var pair := _axis_pair(after)
	check(pair["ok"], "point-up vertices x=0 y=±R (got %s)" % str(pair["pts"]))
	var span_x := _axis(after, "X") - _axis(after, "x")
	check(absf(span_x - AF) <= 0.15, "AF unchanged along X (%.4f)" % span_x)
	check(_horizontal_count(sm) >= 1, "horizontal off the loop stays (%d)" % _horizontal_count(sm))


func _click_vertical(ctx: FilmContext) -> void:
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := FilmUI.find_button(chrome, "Vertical")
	if btn != null:
		check(true, "Vertical chip is on screen")
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Vertical", "Vertical relation"))
	else:
		var more := FilmUI.find_button(chrome, "… More")
		var item := -1
		if more is MenuButton:
			var popup := (more as MenuButton).get_popup()
			for i in popup.item_count:
				if popup.get_item_text(i) == "Vertical":
					item = popup.get_item_id(i)
					break
		check(item >= 0, "Vertical is in … More")
		if item >= 0:
			await FilmUI.activate_menu_id(ctx, more as MenuButton, item,
					FilmUICues.alert("Vertical", "Vertical relation"))
	await process_frame
	await process_frame


func _commit_dim(ctx: FilmContext, value: float) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.focus_dim_for_typing(str(value))
	var edit: LineEdit = chrome._dim_spin.get_line_edit()
	edit.text = str(value)
	edit.text_submitted.emit(str(value))
	await process_frame
	await process_frame
	chrome.release_dim_focus()


func _hover(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await process_frame


func _points(sm: SketchMode) -> Array:
	var out: Array = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line" or bool(info.get("construction", false)):
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.y - 12.0) < 0.2 and absf(b.y - 12.0) < 0.2:
			continue
		out.append(a)
		out.append(b)
	return out


func _axis(pts: Array, which: String) -> float:
	var use_y := which == "y" or which == "Y"
	var want_max := which == "X" or which == "Y"
	var best := 0.0
	var first := true
	for p in pts:
		var v: float = (p as Vector2).y if use_y else (p as Vector2).x
		if first or (want_max and v > best) or (not want_max and v < best):
			best = v
			first = false
	return best


func _near(pts: Array, which: String, want: float) -> bool:
	return absf(_axis(pts, which) - want) <= 0.15


func _same_points(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if (a[i] as Vector2).distance_to(b[i]) > 0.05:
			return false
	return true


func _axis_pair(pts: Array) -> Dictionary:
	var r := AF / sqrt(3.0)
	var hit := 0
	var got: Array = []
	for p in pts:
		var v: Vector2 = p
		if absf(v.x) <= 0.15 and (absf(absf(v.y) - r) <= 0.15):
			hit += 1
			got.append(v)
	return {"ok": hit >= 2, "pts": got}


func _horizontal_count(sm: SketchMode) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		if str(info.get("type", "")) != "horizontal":
			continue
		for ref in info.get("refs", []):
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			var ent: Dictionary = sm.sketch.entity_info(str(ref.get("entity", "")))
			if bool(ent.get("construction", false)):
				continue
			var a: Vector2 = ent["start"]
			var b: Vector2 = ent["end"]
			if absf(a.y - 12.0) < 0.5 and absf(b.y - 12.0) < 0.5:
				n += 1
	return n
