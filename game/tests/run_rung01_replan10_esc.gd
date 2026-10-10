# Rung 1 replan 10 WP3 — Esc clears a selection, then drops the tool, before it ever discards a sketch that has geometry.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_esc.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan10 WP3 Esc keeps a sketch that has geometry")
	FilmUI.reset_fail_count()
	await test_jaw_esc_ladder()
	await test_empty_sketch_esc_exits()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _sketch_feature_count(ctx: FilmContext) -> int:
	var n := 0
	if ctx.view == null or ctx.view.doc == null:
		return 0
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("type", "")) == "sketch":
			n += 1
	return n


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func test_jaw_esc_ladder() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point", "Jaw is the active tool")
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(30.0, 0.0))
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	check(_profile_lines(sm) == 4, "the Jaw rectangle has four lines (got %d)" % _profile_lines(sm))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	check(sm.selected.size() == 1, "one Jaw line is selected (got %d)" % sm.selected.size())

	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	check(mo == null or not mo.has_anchor(),
			"selecting a Jaw line does not start a measure")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "the first Esc after selecting a Jaw line keeps the sketch open")
	check(not _status_has("Measure cleared"),
			"the first Esc is not spent on a measure (log: %s)" % str(_status_log))
	check(sm.selected.is_empty(), "the first Esc clears the selection")
	check(_profile_lines(sm) == 4, "the Jaw lines are all still there (got %d)" % _profile_lines(sm))
	check(_status_has("Selection cleared — Esc again exits the sketch"),
			"Esc names what it dropped (log: %s)" % str(_status_log))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT, "Jaw is the active tool again")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with the Jaw tool active and geometry drawn keeps the sketch open")
	check(sm.tool == SketchMode.Tool.SELECT, "Esc drops the Jaw tool back to Select")
	check(_profile_lines(sm) == 4, "the Jaw lines survive the tool drop (got %d)" % _profile_lines(sm))
	check(_status_has("Tool dropped — Esc again exits the sketch"),
			"the tool drop is named (log: %s)" % str(_status_log))

	var sketches_before := _sketch_feature_count(ctx)
	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing selected and the Select tool still exits the sketch")
	check(_sketch_feature_count(ctx) == sketches_before + 1,
			"the last Esc keeps the Jaw as a sketch feature")
	check(_status_has("Sketch saved"), "the last Esc saves the sketch (log: %s)" % str(_status_log))
	await _shutdown(ctx)


func test_empty_sketch_esc_exits() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	check(sm.sketch.entity_ids().is_empty(), "the sketch is empty")
	# Tool-drop is named only when the sketch already holds geometry.
	# An empty sketch cancels on the Esc that reaches the viewport.
	var focus_owner := vp.gui_get_focus_owner()
	if focus_owner != null and focus_owner.has_method("release_focus"):
		focus_owner.release_focus()
	if ctx.main.interaction != null:
		ctx.main.interaction.grab_focus()
	await process_frame
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	_note_label(ctx)
	if sm.active:
		await _x11_key(vp, KEY_ESCAPE)
		_note_label(ctx)
	check(not sm.active, "Esc exits the empty sketch")
	check(_status_has("Sketch cancelled"),
			"empty sketch Esc cancels (log: %s label: %s)" % [
				str(_status_log), _label(ctx)])
	await _shutdown(ctx)

func _label(ctx: FilmContext) -> String:
	if ctx.main != null and ctx.main.status_label != null:
		return str(ctx.main.status_label.text)
	return ""


func _note_label(ctx: FilmContext) -> void:
	var text := _label(ctx)
	if text != "":
		_status_log.append(text)


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
	main.interaction.status.connect(_on_status)
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


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
