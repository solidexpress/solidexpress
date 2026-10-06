# Rung 1 replan 12 follow-up — constraint chips sit to the right of the sketch
# rail at 1280×800 and stay inside the viewport (sx-033 checklist A1).
# Validation suite: script-side sketch setup is allowed; layout is read from
# real Control global rects after the chrome restacks.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_chiprow.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
## The 16-chip two-circle row from the sx-033 screenshot (Split is the 17th).
const SIXTEEN_CHIPS := [
	"construction", "delete", "shaft_lines", "horizontal", "vertical",
	"parallel", "perpendicular", "equal", "coincident", "tangent",
	"midpoint", "symmetric", "offset", "pattern", "mirror", "block",
]

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
	print("rung01 replan12 chip row stays right of the sketch rail")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


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
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "ground sketch is active")
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	check(a != "" and b != "", "two circles exist")

	sm.set_tool(SketchMode.Tool.SELECT)
	sm._set_selected([a, b])
	await _settle()
	check(sm.selected.size() == 2, "two circles are selected")
	check(sm.selection_actions().has("shaft_lines"), "two circles offer shaft_lines")
	_assert_chip_row(ctx, "two circles selected")
	var shaft := FilmUI.find_button(main.sketch_chrome, "Shaft Lines")
	check(shaft != null and shaft.is_visible_in_tree(),
			"Shaft Lines is visible without scrolling (got %s)" % str(shaft))
	if shaft != null:
		var vp := _viewport_rect()
		check(vp.encloses(shaft.get_global_rect().grow(-0.5)),
				"Shaft Lines sits inside the viewport (%s)" % str(shaft.get_global_rect()))

	_scroll_rail(ctx, 180)
	await _settle()
	_assert_chip_row(ctx, "two circles, rail scrolled")
	_scroll_rail(ctx, 0)
	await _settle()

	var chrome: SketchContextChrome = main.sketch_chrome
	chrome.show_selection_actions(SIXTEEN_CHIPS, Vector2(12, 219))
	await _settle()
	check(_action_chip_texts(chrome) == _labels_of(SIXTEEN_CHIPS),
			"16-chip case keeps chip order and labels (got %s)" % str(_action_chip_texts(chrome)))
	_assert_chip_row(ctx, "16-chip case")
	check(_action_chips(chrome).size() == 16, "16-chip case shows 16 chips (got %d)" % _action_chips(chrome).size())

	# Smart Dim second-pick: first pick keeps a pending centre and a chip row.
	sm._set_selected([a, b])
	await _settle()
	sm.set_tool(SketchMode.Tool.SMART_DIM)
	sm.click(Vector2(0.0, 10.0))
	await _settle()
	check(sm.has_pending_dim_pick(), "Smart Dim holds the first pick (second-pick state)")
	_assert_chip_row(ctx, "Smart Dim second-pick")

	# A pointer over the rail must not drag the chips back onto Arc/Point.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(20, 220)
	motion.global_position = Vector2(20, 220)
	root.push_input(motion)
	await _settle()
	_assert_chip_row(ctx, "pointer over the rail")

	main.queue_free()
	await process_frame
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(ROOT_SIZE))


func _scroll_rail(ctx: FilmContext, y: int) -> void:
	var rail: Control = ctx.main.sketch_toolbar
	if rail == null:
		return
	for c in rail.find_children("*", "ScrollContainer", true, false):
		var sc := c as ScrollContainer
		if sc != null:
			sc.scroll_vertical = y
			return


func _action_chips(chrome: SketchContextChrome) -> Array[Button]:
	var out: Array[Button] = []
	if chrome == null or chrome._action_bar == null or not chrome._action_bar.visible:
		return out
	for c in chrome._action_bar.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.is_visible_in_tree():
			out.append(b)
	return out


func _action_chip_texts(chrome: SketchContextChrome) -> PackedStringArray:
	var texts := PackedStringArray()
	for b in _action_chips(chrome):
		texts.append(b.text)
	return texts


func _labels_of(verbs: Array) -> PackedStringArray:
	var texts := PackedStringArray()
	for v in verbs:
		texts.append(str(v).capitalize().replace("_", " "))
	return texts


func _assert_chip_row(ctx: FilmContext, why: String) -> void:
	var rail: Control = ctx.main.sketch_toolbar
	check(rail != null and rail.visible, "%s: sketch rail is visible" % why)
	if rail == null:
		return
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var chips := _action_chips(chrome)
	check(not chips.is_empty(), "%s: action chips are visible (%d)" % [why, chips.size()])
	var rail_rect := rail.get_global_rect()
	var vp := _viewport_rect()
	print("  %s: rail %s, %d chips, action bar %s" % [
			why, str(rail_rect), chips.size(),
			str(chrome._action_bar.get_global_rect() if chrome._action_bar else Rect2())])
	var bar: Control = chrome._action_bar
	if bar != null and bar.visible:
		check(bar.get_global_rect().position.x >= rail_rect.end.x - 0.5,
				"%s: action bar starts to the right of the rail (bar x=%.1f rail right=%.1f)" % [
				why, bar.get_global_rect().position.x, rail_rect.end.x])
	for b in chips:
		var r := b.get_global_rect()
		var right_of := r.position.x >= rail_rect.end.x - 0.5
		var overlap := r.intersects(rail_rect)
		var inside := vp.encloses(r.grow(-0.5))
		check(right_of and not overlap and inside,
				"%s: chip '%s' is right of the rail, does not overlap it, and stays in the viewport (chip %s rail %s vp %s)" % [
				why, b.text, str(r), str(rail_rect), str(vp)])
