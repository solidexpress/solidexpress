# Rung 1 replan 13 WP1 — every armed tool names itself; the finish bar belongs
# to its sketch. Rail buttons and advertised shortcuts are real Viewport.push_input
# at the button centre (same path as run_rung01_replan12_slotarm.gd).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_arm.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

## Shortcuts the rail tooltips advertise (Select (S), Line (L), …).
const RAIL_SHORTCUTS := [
	["Select", KEY_S, "Select"],
	["Line", KEY_L, "Line"],
	["Arc", KEY_A, "Arc"],
	["Circle", KEY_C, "Circle"],
	["Rect", KEY_R, "Rect"],
	["Trim", KEY_T, "Trim"],
	["Smart Dim", KEY_D, "Smart Dim"],
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
	print("rung01 replan13 WP1 armed tools name themselves; finish bar owns its sketch")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _status_of(main) -> String:
	if main.status_label != null:
		return str(main.status_label.text)
	return ""


func _rail_scroll(rail: Control) -> ScrollContainer:
	if rail == null:
		return null
	var named := rail.find_child("SketchRailScroll", true, false)
	if named is ScrollContainer:
		return named
	for c in rail.find_children("*", "ScrollContainer", true, false):
		return c as ScrollContainer
	return null


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _push_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _scroll_btn_to_band(scroll: ScrollContainer, btn: Control, want_y: float) -> void:
	if scroll == null or btn == null:
		return
	scroll.ensure_control_visible(btn)
	await process_frame
	await process_frame
	var c: Vector2 = btn.get_global_rect().get_center()
	scroll.scroll_vertical = maxi(0, scroll.scroll_vertical + int(c.y - want_y))
	await process_frame
	await process_frame


func _btn_center_visible(btn: Control, scroll: ScrollContainer) -> Vector2:
	if btn == null:
		return Vector2.INF
	var br: Rect2 = btn.get_global_rect()
	var c := br.get_center()
	if scroll == null:
		return c
	var sr: Rect2 = scroll.get_global_rect()
	var inner := sr.grow_individual(0.0, -6.0, 0.0, -6.0)
	if inner.has_point(c):
		return c
	return Vector2.INF


func _click_control(main, btn: Control) -> Vector2:
	if btn == null or not btn.is_visible_in_tree():
		return Vector2.INF
	var scroll := _rail_scroll(main.sketch_toolbar)
	var pos := _btn_center_visible(btn, scroll)
	if pos == Vector2.INF or pos.y < 160.0 or pos.y > 520.0:
		await _scroll_btn_to_band(scroll, btn, 300.0)
		pos = _btn_center_visible(btn, scroll)
	if pos == Vector2.INF:
		return Vector2.INF
	await _push_click(pos)
	return pos


func _click_rail_label(main, label: String) -> Button:
	var btn := FilmUI.find_sketch_tool_button(main, label)
	if btn == null:
		return null
	var pos: Vector2 = await _click_control(main, btn)
	if pos == Vector2.INF:
		return null
	return btn


func _word_of_button(btn: Button) -> String:
	var t := str(btn.text).strip_edges()
	if t != "":
		return t
	return str(btn.tooltip_text).get_slice("(", 0).strip_edges()


func _finish_op_text(chrome: SketchContextChrome) -> String:
	var op := chrome.find_child("FinishOp", true, false) as OptionButton
	if op == null:
		return ""
	return op.get_item_text(op.selected)


func _distance_of(chrome: SketchContextChrome) -> float:
	if chrome != null and chrome._extrude_spin != null:
		return float(chrome._extrude_spin.value)
	return chrome.extrude_distance() if chrome != null else 0.0


func _dirt_finish(chrome: SketchContextChrome) -> void:
	chrome.set_finish_op("cut")
	chrome.set_finish_end("to_face")
	chrome._on_finish_end_selected(3)
	# Write D the same way reset_finish_for_new_sketch does. set_extrude_distance
	# keeps the LineEdit string, so extrude_distance() would still parse 20.
	if chrome._extrude_spin != null:
		chrome._distance_syncing = true
		chrome._extrude_spin.value = 7
		chrome._distance_syncing = false
		chrome._refresh_extrude_readout(7)
	else:
		chrome.set_extrude_distance(7.0)


func _is_defaults(chrome: SketchContextChrome) -> bool:
	return _finish_op_text(chrome) == "New" \
			and chrome.get_finish_end() == "blind" \
			and absf(_distance_of(chrome) - 20.0) < 0.01


func _is_dirty(chrome: SketchContextChrome) -> bool:
	return _finish_op_text(chrome) == "Cut" \
			and chrome.get_finish_end() == "to_face" \
			and absf(_distance_of(chrome) - 7.0) < 0.01


func _owner_of(chrome: SketchContextChrome) -> String:
	if chrome == null:
		return ""
	var v: Variant = chrome.get("_finish_owner")
	if v == null:
		return ""
	return str(v)


func _assert_defaults(chrome: SketchContextChrome, what: String) -> void:
	check(_is_defaults(chrome),
			"%s: Blind / New / 20 (got Op=%s End=%s D=%.3f owner='%s')" % [
				what, _finish_op_text(chrome), chrome.get_finish_end(),
				_distance_of(chrome), _owner_of(chrome)])


func _assert_dirty(chrome: SketchContextChrome, what: String) -> void:
	check(_is_dirty(chrome),
			"%s: Cut / Up To Surface / 7 (got Op=%s End=%s D=%.3f)" % [
				what, _finish_op_text(chrome), chrome.get_finish_end(),
				_distance_of(chrome)])


func _assert_named(main, word: String, prev: String, what: String) -> void:
	await process_frame
	var st := _status_of(main)
	check(st.begins_with(word),
			"%s status starts with `%s` (got `%s`)" % [what, word, st])
	if prev != "" and prev != st:
		check(not st.contains(prev),
				"%s status does not keep the previous sentence (got `%s`, previous `%s`)" % [
					what, st, prev])


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

	await _test_rail_and_keys(ctx, main)
	await _test_circle_empty_and_chip(ctx, main)
	await _test_finish_owner(ctx, main)

	main.queue_free()
	await process_frame
	await process_frame


func _test_rail_and_keys(ctx: FilmContext, main) -> void:
	print("- rail buttons and advertised shortcuts")
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "ground sketch is active")
	var rail: Control = main.sketch_toolbar
	check(rail != null and rail.visible, "sketch rail is visible")
	check(main._sketch_rail_buttons.size() > 0, "main._sketch_rail_buttons is populated")

	# Item 1: each rail-array button, after Jaw then Trim (or Jaw when the
	# button itself is Trim), names itself and drops the previous sentence.
	for b in main._sketch_rail_buttons:
		if b == null or not is_instance_valid(b):
			check(false, "rail button instance is valid")
			continue
		var word := _word_of_button(b)
		var jaw := await _click_rail_label(main, "Jaw")
		check(jaw != null, "`Jaw` is clickable before `%s`" % word)
		await process_frame
		var prev := _status_of(main)
		if word != "Trim":
			var trim_btn := await _click_rail_label(main, "Trim")
			check(trim_btn != null, "`Trim` is clickable before `%s`" % word)
			await process_frame
			prev = _status_of(main)
		var pos: Vector2 = await _click_control(main, b)
		check(pos != Vector2.INF, "rail button `%s` is clickable at a visible position" % word)
		await _assert_named(main, word, prev, "rail `%s`" % word)

	# Centerline is a Line chip, not a rail-array button.
	var line_btn := await _click_rail_label(main, "Line")
	check(line_btn != null, "Line is clickable before Centerline chip")
	await process_frame
	var prev_line := _status_of(main)
	var cl_chip := FilmUI.find_button(main.sketch_chrome, "Centerline")
	check(cl_chip != null and cl_chip.is_visible_in_tree(), "Centerline chip is visible after Line")
	if cl_chip != null:
		await _push_click(cl_chip.get_global_rect().get_center())
		await _assert_named(main, "Centerline", prev_line, "chip Centerline")

	# Item 2: advertised keyboard shortcuts.
	if main.sketch_chrome != null:
		main.sketch_chrome.release_dim_focus()
	var canvas := Vector2(ROOT_SIZE.x * 0.55, ROOT_SIZE.y * 0.55)
	var park := InputEventMouseMotion.new()
	park.position = canvas
	park.global_position = canvas
	root.push_input(park)
	await process_frame
	for row in RAIL_SHORTCUTS:
		var jaw2 := await _click_rail_label(main, "Jaw")
		check(jaw2 != null, "Jaw before shortcut `%s`" % str(row[0]))
		await process_frame
		var prev_k := _status_of(main)
		await _push_key(row[1] as Key)
		await _assert_named(main, str(row[2]), prev_k, "key `%s`" % str(row[0]))


func _test_circle_empty_and_chip(ctx: FilmContext, main) -> void:
	print("- Circle empty emit and Three Point chip")
	var sm: SketchMode = main.sketch_mode
	if sm == null or not sm.active:
		await FilmUI.enter_sketch(ctx)
		sm = main.sketch_mode
	var circ := await _click_rail_label(main, "Circle")
	check(circ != null, "Circle rail button is clickable")
	await process_frame
	var armed := _status_of(main)
	check(armed.begins_with("Circle"),
			"Circle arm status starts with Circle (got `%s`)" % armed)
	main._on_status("")
	await process_frame
	check(_status_of(main) == armed,
			"_on_status(\"\") leaves the Circle sentence (got `%s`)" % _status_of(main))
	var chip := FilmUI.find_button(main.sketch_chrome, "Three Point")
	check(chip != null and chip.is_visible_in_tree(),
			"Circle Three Point chip is visible")
	if chip != null:
		await _push_click(chip.get_global_rect().get_center())
		await process_frame
		var st := _status_of(main)
		check(st.begins_with("Circle"),
				"Three Point chip leaves a sentence that starts with Circle (got `%s`)" % st)


func _test_finish_owner(ctx: FilmContext, main) -> void:
	print("- finish bar owner")
	var sm: SketchMode = main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	await FilmUI.place_primitive(ctx, "box")
	var body: String = ctx.view.selected_body
	var face_a := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	var face_b := FilmUI.find_face_by_normal(ctx.view, body, Vector3(1, 0, 0))
	check(body != "" and face_a != "" and face_b != "" and face_a != face_b,
			"box placed with two distinct faces")
	await FilmUI.enter_sketch_on_face(ctx, body, face_a)
	check(sm.active, "sketch A on the top face is active")
	sm.sketch.add_circle(0.0, 0.0, 8.0)
	var chrome: SketchContextChrome = main.sketch_chrome
	_dirt_finish(chrome)
	_assert_dirty(chrome, "sketch A after setting Cut / Up To Surface / 7")
	var fid_a := await FilmUI.exit_sketch(ctx)
	check(fid_a != "", "sketch A saved as a feature (%s)" % fid_a)

	# #136: a brand-new sketch resets Blind / New / 20.
	await FilmUI.enter_sketch_on_face(ctx, body, face_b)
	check(sm.active, "sketch B on another plane is active")
	_assert_defaults(chrome, "new sketch B")
	sm.sketch.add_circle(0.0, 0.0, 6.0)
	var fid_b := await FilmUI.exit_sketch(ctx)
	check(fid_b != "" and fid_b != fid_a, "sketch B is a different feature (%s vs %s)" % [fid_b, fid_a])

	# Re-open A: A is the owner only if nothing else took the bar. After B,
	# A is a different sketch, so the bar is session defaults.
	check(sm.begin_edit(fid_a), "begin_edit sketch A")
	await process_frame
	await process_frame
	check(sm.active and sm.editing_fid == fid_a, "editing sketch A")
	_assert_defaults(chrome, "re-open A (not owner after B)")

	# Residual: dirty A, exit, begin_edit B must reset (different owner).
	_dirt_finish(chrome)
	_assert_dirty(chrome, "sketch A dirtied again")
	var left_a := sm.exit_sketch()
	check(left_a == fid_a, "exit A returns A's id")
	await process_frame
	await process_frame
	check(sm.begin_edit(fid_b), "begin_edit sketch B")
	await process_frame
	await process_frame
	check(sm.active and sm.editing_fid == fid_b, "editing sketch B")
	_assert_defaults(chrome, "re-open B after a different owner")

	# Item 5: Save As inside A keeps Cut / Up To Surface / 7.
	if sm.active:
		sm.exit_sketch()
		await process_frame
		await process_frame
	check(sm.begin_edit(fid_a), "begin_edit A for Save As")
	await process_frame
	await process_frame
	_dirt_finish(chrome)
	_assert_dirty(chrome, "A before Save As")
	var path := "/tmp/sx-replan13-saveas.sxp"
	DirAccess.remove_absolute(path)
	main.current_path = path
	main._save_current()
	await process_frame
	await process_frame
	check(sm.active, "sketch session is still active after Save As")
	check(sm.editing_fid == fid_a, "Save As re-enters the same sketch")
	_assert_dirty(chrome, "Save As keeps Cut / Up To Surface / 7")
	DirAccess.remove_absolute(path)

	# File → New still resets Op/End and clears the owner (distance is the
	# new-sketch path, not File → New).
	main._do_new()
	await process_frame
	await process_frame
	check(_finish_op_text(chrome) == "New" and chrome.get_finish_end() == "blind",
			"File → New resets Op/End to New / Blind (got %s / %s)" % [
				_finish_op_text(chrome), chrome.get_finish_end()])
	check(_owner_of(chrome) == "",
			"File → New clears finish_owner (got '%s')" % _owner_of(chrome))
