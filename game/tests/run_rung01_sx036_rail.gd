# sx-036 checklist A1 — at 1280×800 every sketch-rail label sits in the
# visible rail (no scroll) and the selection chip row starts to the right
# of that rail.
# Validation suite: sketch setup may use the document API; layout is read
# from real Control global rects after the chrome restacks.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx036_rail.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
## Exit Sketch through Auto Dim — the labelled rail, including the 11 that
## used to fit and the ones that sat below the fold (Trim … Pattern).
const RAIL_LABELS := ["Exit Sketch", "Select", "Line", "Arc", "Circle", "Rect", "Jaw",
		"Polygon", "Ellipse", "Slot", "Spline", "Point", "Trim", "Extend", "Smart Dim",
		"Convert", "Mirror", "Pattern", "Auto Dim"]



func _init() -> void:
	print("rung01 sx-036 A1 sketch rail fits at 1280×800")
	FilmUI.reset_fail_count()
	await _run()
	finish()


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
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	await FilmUI.enter_sketch(ctx)
	if main.has_method("_reflow_left_stack"):
		main._reflow_left_stack()
	await _settle()
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "ground sketch is active")

	var rail: Control = main.sketch_toolbar
	check(rail != null and rail.visible, "sketch rail is visible")
	var scroll := _rail_scroll(rail)
	check(scroll != null, "sketch rail has a ScrollContainer")
	if rail == null or scroll == null:
		main.queue_free()
		return
	check(scroll.scroll_vertical == 0, "rail scroll starts at 0 (got %d)" % scroll.scroll_vertical)
	var bar := scroll.get_v_scroll_bar()
	var room := 0
	if bar != null:
		room = maxi(0, int(ceil(bar.max_value - bar.page)))
	check(room == 0, "rail content fits the visible column (scroll room %d px)" % room)

	var visible := scroll.get_global_rect()
	print("  rail %s scroll %s" % [str(rail.get_global_rect()), str(visible)])
	var seen := {}
	var buttons: Array[Button] = []
	var rows := rail.find_child("SketchRailRows", true, false)
	var host: Node = rows if rows != null else rail
	for c in host.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		if b is OptionButton:
			continue
		buttons.append(b)
	check(buttons.size() >= RAIL_LABELS.size(),
			"rail exposes %d visible buttons (got %d)" % [RAIL_LABELS.size(), buttons.size()])
	for b in buttons:
		var r := b.get_global_rect()
		var inside := visible.encloses(r.grow(-0.5))
		check(inside, "rail button '%s' is fully inside the visible rail (%s vs %s)" % [
				b.text if b.text != "" else b.name, str(r), str(visible)])
		if b.text != "":
			seen[b.text] = r
			print("  label '%s' %s" % [b.text, str(r)])
	for label in RAIL_LABELS:
		check(seen.has(label), "rail label '%s' is visible without scrolling" % label)

	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b_id: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	check(a != "" and b_id != "", "two circles exist")
	sm.set_tool(SketchMode.Tool.SELECT)
	sm._set_selected([a, b_id])
	await _settle()
	if main.has_method("_reflow_left_stack"):
		main._reflow_left_stack()
	await _settle()
	var chrome: SketchContextChrome = main.sketch_chrome
	var action: Control = chrome._action_bar if chrome != null else null
	check(action != null and action.visible, "selection chip row is visible")
	if action != null and action.visible:
		var chip_r := action.get_global_rect()
		var rail_r := rail.get_global_rect()
		var vp := Rect2(Vector2.ZERO, Vector2(ROOT_SIZE))
		print("  chip row %s rail %s" % [str(chip_r), str(rail_r)])
		check(chip_r.position.x > rail_r.end.x,
				"chip row starts right of the rail (chip x=%.1f rail right=%.1f)" % [
				chip_r.position.x, rail_r.end.x])
		check(chip_r.end.x <= vp.end.x + 0.5,
				"chip row ends inside the window (chip end x=%.1f window %.1f)" % [
				chip_r.end.x, vp.end.x])
		for tool_name in ["Arc", "Point"]:
			var tool_r: Rect2 = seen.get(tool_name, Rect2())
			check(tool_r.size.x > 1.0 and not chip_r.intersects(tool_r),
					"chip row does not cover %s (chip %s tool %s)" % [
					tool_name, str(chip_r), str(tool_r)])

	main.queue_free()
	await process_frame
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _rail_scroll(rail: Control) -> ScrollContainer:
	if rail == null:
		return null
	var named := rail.find_child("SketchRailScroll", true, false)
	if named is ScrollContainer:
		return named
	return null
