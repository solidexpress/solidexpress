# sx-037 A17 / N20 — a chip, finish-bar, or HUD click over the canvas is not a
# line point, and undo/redo clears relation-suggestion chips.
# Setup may use the sketch API. The chip click, the canvas click, and
# Ctrl+Z / Ctrl+Shift+Z are real Viewport.push_input events.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_sx037_chipclick.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("sx-037 chip click is not a line point; undo clears suggestion chips")
	FilmUI.reset_fail_count()
	await test_centerline_chip_and_suggestions()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_centerline_chip_and_suggestions() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Line"))
	await process_frame
	await _arm_line(ctx, sm)
	var chip := _variant_chip(ctx, "Centerline")
	check(chip != null and chip.is_visible_in_tree(), "Centerline chip is visible over the sketch")
	if chip == null:
		await _shutdown(ctx)
		return
	var chip_pos := chip.get_global_rect().get_center()
	var ix: Control = ctx.main.interaction
	check(ix.get_global_rect().has_point(chip_pos),
			"Centerline chip center sits over the canvas (%s)" % str(chip_pos))

	var before := sm.sketch.entity_ids().size()
	var undo_before := sm.can_undo()
	await _x11_click_screen(vp, chip_pos)
	await process_frame
	check(sm.tool == SketchMode.Tool.CENTERLINE, "Centerline chip switches the tool")
	check(sm.sketch.entity_ids().size() == before,
			"Centerline chip does not add a sketch entity (got %d, was %d)" % [
				sm.sketch.entity_ids().size(), before])
	check(not sm.has_pending_draw_point(), "Centerline chip leaves no pending line start")
	check(sm.can_undo() == undo_before, "Centerline chip does not push an undo step")
	check(not sm.can_redo(), "Centerline chip leaves the redo stack empty")

	# Every other visible chip / finish-bar / HUD button, with Line re-armed
	# so a leak would be the first point of a line. Skip controls that leave
	# the sketch or open a menu. Re-find each button: arming Line rebuilds
	# the chip row and frees the previous buttons.
	var chrome_labels: PackedStringArray = PackedStringArray()
	for btn in _chrome_buttons(ctx):
		if not _safe_chrome_click(btn):
			continue
		var label: String = btn.text if btn.text != "" else str(btn.name)
		if label == "Line" or label == "Centerline":
			continue
		if label not in chrome_labels:
			chrome_labels.append(label)
	for label in chrome_labels:
		await _arm_line(ctx, sm)
		var live := _button_by_label(ctx, label)
		if live == null or not live.is_visible_in_tree():
			continue
		var count_before := sm.sketch.entity_ids().size()
		var redo_before := sm.can_redo()
		await _x11_click_screen(vp, live.get_global_rect().get_center())
		await process_frame
		if not sm.active:
			check(false, "click on %s stays in the sketch" % label)
			break
		check(sm.sketch.entity_ids().size() == count_before,
				"click on %s does not add a sketch entity" % label)
		check(not sm.has_pending_draw_point(),
				"click on %s leaves no pending line start" % label)
		check(sm.can_redo() == redo_before,
				"click on %s does not put a line on the redo stack" % label)

	# A rubber-band is already down and the chip row is still showing: the
	# Centerline click must not become the second point.
	await _arm_line(ctx, sm)
	var count_before_anchor := sm.sketch.entity_ids().size()
	await _click_uv(ctx, vp, Vector2(12.0, -18.0))
	check(sm.has_pending_draw_point(), "canvas click arms a line start")
	check(sm.sketch.entity_ids().size() == count_before_anchor, "the line start is not an entity yet")
	ctx.main._on_sketch_tool_changed(SketchMode.Tool.LINE)
	await process_frame
	chip = _variant_chip(ctx, "Centerline")
	check(chip != null and chip.is_visible_in_tree(), "Centerline chip still visible with a line pending")
	if chip != null:
		await _x11_click_screen(vp, chip.get_global_rect().get_center())
		await process_frame
	check(sm.sketch.entity_ids().size() == count_before_anchor,
			"Centerline chip with a pending start does not commit a line (got %d)" % sm.sketch.entity_ids().size())
	check(not sm.can_redo(), "that click did not leave a line on the redo stack")
	check(sm.tool == SketchMode.Tool.CENTERLINE, "the pending-start click still selects Centerline")
	check(not sm.has_pending_draw_point(), "switching to Centerline drops the pending line start")

	# Relation suggestions: parallel + equal horizontals, and a perpendicular.
	# Deleting the centerline and undoing it used to leave the ? chips up.
	await process_frame
	var base_construction := _construction_count(sm)
	var a: String = sm.sketch.add_line(0.0, 0.0, 30.0, 0.0)
	var b: String = sm.sketch.add_line(0.0, 10.0, 30.0, 10.0)
	var c: String = sm.sketch.add_line(0.0, 0.0, 0.0, 30.0)
	var cl: String = sm.sketch.add_line(5.0, 20.0, 35.0, 20.0)
	check(a != "" and b != "" and c != "" and cl != "", "profile lines and a centerline exist")
	sm.sketch.set_construction(cl, true)
	sm._redraw()
	await process_frame
	check(_construction_count(sm) == base_construction + 1, "one construction line was added")
	check(sm.can_undo(), "adding the lines captured an undo step")
	sm._set_selected([cl])
	var removed := sm.delete_selected_entities()
	await process_frame
	check(removed == 1, "deleted the centerline")
	check(_construction_count(sm) == base_construction, "centerline is gone before undo")
	await _push_key_local(vp, KEY_Z, true, false)
	check(_construction_count(sm) == base_construction + 1, "Ctrl+Z restores the centerline")
	var after_undo := _suggestion_labels(ctx)
	check(after_undo.is_empty(), "undo leaves no suggestion chips (got %s)" % str(after_undo))
	await _push_key_local(vp, KEY_Z, true, true)
	check(_construction_count(sm) == base_construction, "Ctrl+Shift+Z removes the centerline again")
	var after_redo := _suggestion_labels(ctx)
	check(after_redo.is_empty(), "redo leaves no suggestion chips (got %s)" % str(after_redo))
	await _shutdown(ctx)


func _arm_line(ctx: FilmContext, sm: SketchMode) -> void:
	var line := _variant_chip(ctx, "Line")
	if line != null and line.is_visible_in_tree() and sm.tool != SketchMode.Tool.LINE:
		await _x11_click(line)
	elif sm.tool != SketchMode.Tool.LINE or sm.has_pending_draw_point():
		sm.set_tool(SketchMode.Tool.LINE)
		ctx.main._on_sketch_tool_changed(SketchMode.Tool.LINE)
	await process_frame


func _safe_chrome_click(btn: Button) -> bool:
	var label: String = (btn.text if btn.text != "" else btn.name).to_lower()
	# Commit buttons run a feature (empty Revolve prints a kernel error).
	# Menus and Save change focus. The rest of the chrome is the click-through set.
	for skip in ["cancel", "finish", "extrude", "revolve", "ok", "done", "close",
			"view", "▼", "save", "new", "cut", "intersect", "thin feature", "boss"]:
		if label == skip or label.begins_with(skip + " "):
			return false
	if label.begins_with("@") or label == "":
		return false
	return true


func _chrome_buttons(ctx: FilmContext) -> Array[Button]:
	var out: Array[Button] = []
	var chrome: Node = ctx.main.sketch_chrome
	if chrome != null:
		for bar_name in ["VariantBar", "ActionBar", "FinishBar", "ContourBar"]:
			var bar: Node = chrome.find_child(bar_name, true, false)
			_collect_buttons(bar, out)
	_collect_buttons(ctx.main.view_hud, out)
	return out


func _button_by_label(ctx: FilmContext, label: String) -> Button:
	for btn in _chrome_buttons(ctx):
		var text: String = btn.text if btn.text != "" else str(btn.name)
		if text == label:
			return btn
	return null


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node == null:
		return
	for child in node.find_children("*", "Button", true, false):
		var b := child as Button
		if b != null and b.is_visible_in_tree():
			out.append(b)


func _construction_count(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			n += 1
	return n


func _suggestion_labels(ctx: FilmContext) -> Array[String]:
	var out: Array[String] = []
	var chrome: Node = ctx.main.sketch_chrome
	if chrome == null:
		return out
	var bar: Control = chrome.find_child("ActionBar", true, false) as Control
	if bar == null or not bar.visible:
		return out
	for node in bar.find_children("*", "Button", true, false):
		var b := node as Button
		if b == null or not b.is_visible_in_tree():
			continue
		if str(b.text).ends_with("?"):
			out.append(b.text)
	return out


func _variant_chip(ctx: FilmContext, text: String) -> Button:
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	if bar == null:
		return null
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


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
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		check(false, "click target exists")
		return
	await _x11_click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


func _push_key_local(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame
