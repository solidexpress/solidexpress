# re-PLAN 20 WP3 — Centerline keeps the Line rail button lit.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_rail.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const CENTERLINE_ARM := "Centerline — click 2 points (construction, never part of the profile)"
const CENTERLINE_ADD := "Centerline added — construction, not part of the profile"
const TOOL_DROPPED := "Tool dropped — Esc again exits the sketch"

var failures := 0
var checks := 0
var _log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan20 rail")
	var ctx := await _boot()
	await _case(ctx)
	print("%d checks, %d failures" % [checks, failures])
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	quit(1 if failures > 0 else 0)


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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(msg: String) -> void:
	_log.append(str(msg))


func _case(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var rail: Control = ctx.main.sketch_toolbar
	var rows := rail.find_child("SketchRailRows", true, false) as VBoxContainer
	check(rows != null, "sketch rail rows exist")
	var labels := _rail_labels(rows)
	var width_before := rail.get_global_rect().size.x
	check(labels.size() == 19, "19 rail labels (got %d: %s)" % [labels.size(), str(labels)])
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.LINE)
	await process_frame
	_expect_lit(rows, ["Line"], "Line armed")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Centerline")
	check(chip != null, "Centerline chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Centerline"))
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.tool == SketchMode.Tool.CENTERLINE, "Centerline chip arms tool 15 (got %s)" % str(sm.tool))
	check(str(ctx.main.status_label.text) == CENTERLINE_ARM or _saw(CENTERLINE_ARM),
			"Centerline arm status (got '%s')" % ctx.main.status_label.text)
	_expect_lit(rows, ["Line"], "Centerline armed")
	await FilmUI.click_sketch(ctx, sm, Vector2(0, 0), "centerline start")
	await FilmUI.click_sketch(ctx, sm, Vector2(30, 0), "centerline end")
	await process_frame
	check(_saw(CENTERLINE_ADD) or str(ctx.main.status_label.text) == CENTERLINE_ADD,
			"centerline committed (got '%s')" % ctx.main.status_label.text)
	_expect_lit(rows, ["Line"], "after Centerline commit")
	ctx.main.get_viewport().gui_release_focus()
	ctx.main.interaction.grab_focus()
	_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_Z, true, false)
	await process_frame
	await process_frame
	check(_saw("Undo: Line"), "Ctrl+Z undoes the centreline (log %s)" % " | ".join(_log))
	_expect_lit(rows, ["Line"], "after Centerline undo")
	_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_Z, true, true)
	await process_frame
	await process_frame
	check(_saw("Redo: Line"), "Ctrl+Shift+Z redoes the centreline (log %s)" % " | ".join(_log))
	_expect_lit(rows, ["Line"], "after Centerline redo")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _chip(ctx, "Centerline")
	await _chip(ctx, "Line")
	check(sm.tool == SketchMode.Tool.LINE, "Line chip returns to Line (got %s)" % str(sm.tool))
	_expect_lit(rows, ["Line"], "Line chip after Centerline")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _chip(ctx, "Centerline")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	_expect_lit(rows, ["Circle"], "Circle after Centerline")
	for pair in [["L", KEY_L, "Line"], ["D", KEY_D, "Smart Dim"], ["T", KEY_T, "Trim"], ["C", KEY_C, "Circle"], ["S", KEY_S, "Select"]]:
		ctx.main.get_viewport().gui_release_focus()
		ctx.main.interaction.grab_focus()
		_push_key(ctx.main.get_viewport(), pair[1], false, false)
		await process_frame
		await process_frame
		_expect_lit(rows, [pair[2]], "key %s" % pair[0])
	var jaw: Button = rail.find_child("JawTool", true, false) as Button
	check(jaw != null, "Jaw button exists")
	if jaw != null:
		await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Click", "Jaw"))
		await process_frame
		var rect_btn := _button_named(rows, "Rect")
		check(jaw.button_pressed, "Jaw is lit")
		check(rect_btn == null or not rect_btn.button_pressed, "Rect is not lit while Jaw is armed")
		check(_lit(rows).size() <= 1, "Jaw arm leaves at most one row button lit (got %s)" % str(_lit(rows)))
	var rect := _button_named(rows, "Rect")
	if rect != null:
		await FilmUI.click_control(ctx, rect, FilmUICues.alert("Click", "Rect"))
		await process_frame
		check(rect.button_pressed, "Rect is lit")
		check(jaw == null or not jaw.button_pressed, "Jaw is not lit after Rect")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _chip(ctx, "Centerline")
	ctx.main.get_viewport().gui_release_focus()
	ctx.main.interaction.grab_focus()
	_log.clear()
	_push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await process_frame
	await process_frame
	check(_saw(TOOL_DROPPED) or str(ctx.main.status_label.text) == TOOL_DROPPED,
			"Esc drops Centerline (got '%s')" % ctx.main.status_label.text)
	var dropped := _lit(rows)
	check(dropped.size() <= 1, "Esc leaves at most one rail button lit (got %s)" % str(dropped))
	check(dropped.is_empty() or dropped[0] == "Select",
			"Esc lights nothing or Select (got %s)" % str(dropped))
	_push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await process_frame
	await process_frame
	check(not sm.active, "second Esc leaves the sketch")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var again := _lit(rows)
	check(again.size() == 1, "re-entering the sketch lights one button (got %s)" % str(again))
	var width_after := rail.get_global_rect().size.x
	var labels_after := _rail_labels(rows)
	check(labels_after == labels, "rail labels are unchanged")
	check(absf(width_after - width_before) <= 1.0,
			"rail width unchanged (%.1f -> %.1f)" % [width_before, width_after])


func _expect_lit(rows: VBoxContainer, want: Array, tag: String) -> void:
	var lit := _lit(rows)
	check(lit.size() == 1, "%s lights exactly one button (got %s)" % [tag, str(lit)])
	check(lit == want, "%s lights %s (got %s)" % [tag, str(want), str(lit)])


func _chip(ctx: FilmContext, label: String) -> void:
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, label)
	check(chip != null, "%s chip is visible" % label)
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", label))
	await process_frame


func _lit(rows: VBoxContainer) -> Array:
	var lit: Array = []
	if rows == null:
		return lit
	for child in rows.get_children():
		var btn := child as Button
		if btn != null and btn.toggle_mode and not (btn is CheckBox) and btn.button_pressed:
			lit.append(str(btn.text))
	return lit


func _rail_labels(rows: VBoxContainer) -> Array:
	var labels: Array = []
	if rows == null:
		return labels
	for child in rows.get_children():
		if child is CheckBox or child is OptionButton:
			continue
		var btn := child as Button
		if btn == null or str(btn.text) == "":
			continue
		labels.append(str(btn.text))
	return labels


func _button_named(rows: VBoxContainer, text: String) -> Button:
	if rows == null:
		return null
	for child in rows.get_children():
		var btn := child as Button
		if btn != null and str(btn.text) == text:
			return btn
	return null


func _saw(fragment: String) -> bool:
	for line in _log:
		if line.contains(fragment):
			return true
	return false


func _push_key(vp: Viewport, code: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = code
	down.physical_keycode = code
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)
