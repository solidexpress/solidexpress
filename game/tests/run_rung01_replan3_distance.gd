# Rung 1 replan 3 WP1 — Distance stores the number Extrude will send.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan3_distance.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")



func _init() -> void:
	print("rung01 replan3 WP1 distance")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan3_distance.gd")
	var banned_set := "set_extrude" + "_distance"
	var banned_input := "interaction." + "_input"
	var banned_submit := "text_submitted" + ".emit"
	check(not src.contains(banned_set), "test source has no distance setter")
	check(not src.contains(banned_input), "test source does not call Interaction _input")
	check(not src.contains(banned_submit), "test source does not emit submitted")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	check(main.sketch_mode.active, "sketch session is open")
	await test_published_api(main)
	await test_readout_layout(ctx)
	await test_unparseable_stays_20(main)
	await test_typed_distance_without_enter(main)
	await test_enter_commits_7_5(main)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_published_api(main) -> void:
	print("- published Distance API")
	var chrome: SketchContextChrome = main.sketch_chrome
	check(chrome.has_method("focus_distance_for_typing"),
			"focus_distance_for_typing is published")
	check(chrome.has_method("distance_line_parses"),
			"distance_line_parses is published")
	check(chrome.has_method("extrude_distance"), "extrude_distance stays")
	if not chrome.has_method("focus_distance_for_typing"):
		return
	chrome.focus_distance_for_typing("20")
	await process_frame
	await process_frame
	check(chrome.distance_line_parses(), "seed 20 parses")
	check(is_equal_approx(chrome._extrude_spin.value, 20.0),
			"focus_distance_for_typing('20') stores 20 on the spin")
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	check(readout != null and str(readout.text).contains("20"),
			"seed 20 updates ExtrudeReadout (%s)" % (readout.text if readout else ""))
	chrome.focus_distance_for_typing()
	await process_frame
	await process_frame
	var edit := chrome._extrude_spin.get_line_edit()
	check(edit.has_focus(), "empty seed focuses Distance")
	var sel := edit.get_selected_text()
	check(sel == edit.text and sel != "",
			"empty seed selects all (sel '%s' text '%s')" % [sel, edit.text])


func test_readout_layout(ctx: FilmContext) -> void:
	print("- ExtrudeReadout vs variant chips at 1280x800")
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var rail_x := 56.0
	if ctx.main.sketch_toolbar != null and ctx.main.sketch_toolbar.visible:
		rail_x = ctx.main.sketch_toolbar.global_position.x + ctx.main.sketch_toolbar.size.x + 8.0
	chrome.place_variant_row(rail_x)
	await process_frame
	await process_frame
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	var variant: Control = chrome.find_child("VariantBar", true, false)
	var btn := chrome.extrude_button()
	check(readout != null, "ExtrudeReadout exists")
	check(readout != null and readout.name == "ExtrudeReadout",
			"readout name is ExtrudeReadout")
	check(variant != null and variant.visible, "polygon variant bar is visible")
	check(btn != null, "Extrude button exists")
	if readout == null or variant == null or btn == null:
		return
	var vp := chrome.get_viewport().get_visible_rect()
	var rr := readout.get_global_rect()
	var vr := variant.get_global_rect()
	var br := btn.get_global_rect()
	check(_contained(vp, rr),
			"readout inside 1280x800 (readout %s vp %s)" % [str(rr), str(vp)])
	check(not rr.intersects(vr),
			"readout does not intersect variant chips (readout %s chips %s)" % [
				str(rr), str(vr)])
	check(_contained(vp, br),
			"Extrude button inside 1280x800 (btn %s vp %s)" % [str(br), str(vp)])
	check(rr.size.x + 0.5 >= UiScale.px(120.0),
			"readout min width fits Extrude 20 mm / 7.5 mm (w=%.1f)" % rr.size.x)


func test_unparseable_stays_20(main) -> void:
	print("- 20.07.5 emits distance_rejected and leaves spin at 20")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	if dist == null:
		check(false, "DistanceSpin exists")
		return
	chrome.focus_distance_for_typing("20")
	await process_frame
	await process_frame
	var edit := dist.get_line_edit()
	await _click(edit)
	await _click(edit)
	await process_frame
	await _type(edit, "20.07.5")
	await process_frame
	await process_frame
	check(not chrome.distance_line_parses(), "20.07.5 does not parse")
	check(is_equal_approx(dist.value, 20.0),
			"spin stays 20 while line is 20.07.5 (got %s)" % str(dist.value))
	var got := {"fired": false, "rejected": "", "count": 0}
	var on_finish := func(_op: String, _distance: float, _end: String, _thin: float,
			_thin_type: String, _flip: bool, _contours: Array) -> void:
		got["fired"] = true
	var on_reject := func(raw: String) -> void:
		got["rejected"] = raw
		got["count"] = int(got["count"]) + 1
	chrome.finish_requested.connect(on_finish)
	chrome.distance_rejected.connect(on_reject)
	await _key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	check(not bool(got["fired"]), "Enter on 20.07.5 does not emit finish_requested")
	check(int(got["count"]) >= 1 and str(got["rejected"]).contains("20.07.5"),
			"Enter on 20.07.5 emits distance_rejected (%s)" % str(got["rejected"]))
	check(is_equal_approx(dist.value, 20.0),
			"Enter on 20.07.5 leaves spin at 20 (got %s)" % str(dist.value))
	got["fired"] = false
	got["rejected"] = ""
	got["count"] = 0
	var btn := chrome.extrude_button()
	check(btn != null, "Extrude button exists for reject click")
	if btn != null:
		await _click(btn)
	await process_frame
	await process_frame
	chrome.finish_requested.disconnect(on_finish)
	chrome.distance_rejected.disconnect(on_reject)
	check(not bool(got["fired"]), "Extrude on 20.07.5 does not emit finish_requested")
	check(int(got["count"]) >= 1 and str(got["rejected"]).contains("20.07.5"),
			"Extrude on 20.07.5 emits distance_rejected (%s)" % str(got["rejected"]))
	check(is_equal_approx(dist.value, 20.0),
			"Extrude on 20.07.5 leaves spin at 20 (got %s)" % str(dist.value))


func test_typed_distance_without_enter(main) -> void:
	print("- typed 7.5 without Enter is the Extrude distance")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	check(dist != null, "DistanceSpin exists")
	check(readout != null, "ExtrudeReadout exists")
	if dist == null:
		return
	if chrome.has_method("focus_distance_for_typing"):
		chrome.focus_distance_for_typing("20")
		await process_frame
		await process_frame
	check(readout != null and str(readout.text).contains("20"),
			"default readout contains 20 (%s)" % (readout.text if readout else ""))
	var edit := dist.get_line_edit()
	await _click(edit)
	await _click(edit)
	await process_frame
	check(edit.has_focus(), "second click leaves Distance focused")
	var sel := edit.get_selected_text()
	check(sel == edit.text and sel != "",
			"second click selects all (sel '%s' text '%s')" % [sel, edit.text])
	await _type(edit, "7.5")
	await process_frame
	await process_frame
	check(readout != null and str(readout.text).contains("7.5"),
			"readout contains 7.5 after typing (%s, line '%s')" % [
				readout.text if readout else "", edit.text])
	check(is_equal_approx(dist.value, 7.5),
			"spin.value is 7.5 before Extrude (got %s, line '%s')" % [
				str(dist.value), edit.text])
	check(chrome.distance_line_parses(),
			"Distance line parses (line '%s')" % edit.text)
	var got := {"dist": NAN, "fired": false, "rejected": false}
	var on_finish := func(_op: String, distance: float, _end: String, _thin: float,
			_thin_type: String, _flip: bool, _contours: Array) -> void:
		got["dist"] = distance
		got["fired"] = true
	var on_reject := func(_raw: String) -> void:
		got["rejected"] = true
	chrome.finish_requested.connect(on_finish)
	chrome.distance_rejected.connect(on_reject)
	var btn := chrome.extrude_button()
	check(btn != null, "Extrude button exists")
	if btn != null:
		await _click(btn)
	await process_frame
	await process_frame
	chrome.finish_requested.disconnect(on_finish)
	chrome.distance_rejected.disconnect(on_reject)
	check(bool(got["fired"]), "Extrude pressed emitted finish_requested")
	check(is_equal_approx(float(got["dist"]), 7.5),
			"finish_requested distance is 7.5 (got %s)" % str(got["dist"]))
	check(not bool(got["rejected"]), "typed 7.5 does not emit distance_rejected")
	check(readout != null and str(readout.text).contains("7.5"),
			"readout still contains 7.5 after Extrude (%s)" % (readout.text if readout else ""))
	check(is_equal_approx(chrome.extrude_distance(), 7.5), "extrude_distance() is 7.5")


func test_enter_commits_7_5(main) -> void:
	print("- Enter after 7.5 leaves spin and readout at 7.5")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	if dist == null:
		return
	var edit := dist.get_line_edit()
	await _click(edit)
	await _click(edit)
	await process_frame
	await _type(edit, "7.5")
	await process_frame
	var got := {"fired": false, "rejected": false}
	var on_finish := func(_op: String, _distance: float, _end: String, _thin: float,
			_thin_type: String, _flip: bool, _contours: Array) -> void:
		got["fired"] = true
	var on_reject := func(_raw: String) -> void:
		got["rejected"] = true
	chrome.finish_requested.connect(on_finish)
	chrome.distance_rejected.connect(on_reject)
	await _key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	chrome.finish_requested.disconnect(on_finish)
	chrome.distance_rejected.disconnect(on_reject)
	check(not bool(got["fired"]), "Enter does not emit finish_requested")
	check(not bool(got["rejected"]), "Enter on 7.5 does not emit distance_rejected")
	check(is_equal_approx(dist.value, 7.5),
			"Enter leaves spin at 7.5 (got %s)" % str(dist.value))
	check(readout != null and str(readout.text).contains("7.5"),
			"Enter leaves readout containing 7.5 (%s)" % (readout.text if readout else ""))


func _contained(outer: Rect2, inner: Rect2, eps := 1.0) -> bool:
	return inner.position.x >= outer.position.x - eps \
			and inner.position.y >= outer.position.y - eps \
			and inner.end.x <= outer.end.x + eps \
			and inner.end.y <= outer.end.y + eps


func _click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var hover := InputEventMouseMotion.new()
	hover.position = pos
	hover.global_position = pos
	vp.push_input(hover)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
	await process_frame
	if ctrl is LineEdit:
		var le := ctrl as LineEdit
		if le.has_method("edit") and not le.is_editing():
			le.edit()
			await process_frame


func _type(edit: LineEdit, text: String) -> void:
	var vp := edit.get_viewport()
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = ch as Key
		elif ch == 46:
			code = KEY_PERIOD
		await _key(vp, code, ch)


func _key(vp: Viewport, code: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = code
	rel.physical_keycode = code
	rel.unicode = 0
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame
