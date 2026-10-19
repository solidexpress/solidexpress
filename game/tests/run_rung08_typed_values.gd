# Rung 8 WP-L9 — typed values land as float(text), not a SpinBox step snap.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung08_typed_values.suite
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("rung08 typed values")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var chrome: SketchContextChrome = main.sketch_chrome
	check(sm.active, "sketch session")
	var dim: SpinBox = chrome.find_child("DimSpin", true, false)
	check(dim != null and is_zero_approx(dim.step), "DimSpin step is 0")
	check(main.dim_value != null and is_zero_approx(main.dim_value.step),
			"hidden dim_value step is 0")

	await _check_typed_dim(main, sm, chrome, "12.34", "line")
	await _check_typed_dim(main, sm, chrome, "9.525", "circle")
	await _check_typed_dim(main, sm, chrome, "1.2", "line")

	chrome.set_draft_on(true)
	var draft: SpinBox = chrome.find_child("DraftAngleSpin", true, false)
	check(draft != null and is_zero_approx(draft.step), "DraftAngleSpin step is 0")
	if draft != null:
		var edit := draft.get_line_edit()
		if edit != null:
			edit.text = "1.25"
		check(chrome.draft_deg() == float("1.25"),
				"draft 1.25° == float(text) (got %s)" % str(chrome.draft_deg()))

	if chrome.offset_tool != null and chrome.offset_tool._distance_spin != null:
		var oedit := chrome.offset_tool._distance_spin.get_line_edit()
		if oedit != null:
			oedit.text = "2.54"
		chrome.offset_tool._pull_typed_distance()
		check(chrome.offset_tool.distance == float("2.54"),
				"offset 2.54 == float(text) (got %s)" % str(chrome.offset_tool.distance))

	if sm.pattern_ui != null and sm.pattern_ui._angle_spin != null:
		var aedit := sm.pattern_ui._angle_spin.get_line_edit()
		if aedit != null:
			aedit.text = "51.428571"
		sm.pattern_ui.pull_fields()
		check(sm.pattern_ui.angle_deg == float("51.428571"),
				"pattern 51.428571° == float(text) (got %s)" % str(sm.pattern_ui.angle_deg))

	sm.exit_sketch()
	finish()


func _check_typed_dim(main, sm: SketchMode, chrome: SketchContextChrome, text: String, kind: String) -> void:
	if sm.active:
		sm.cancel()
	main._start_sketch()
	await process_frame
	sm = main.sketch_mode
	var id := ""
	if kind == "circle":
		id = sm.sketch.add_circle(0, 0, 10)
	else:
		id = sm.sketch.add_line(0, 0, 40, 0)
	sm._set_selected([id])
	var before: PackedStringArray = sm.sketch.constraint_ids()
	chrome._on_dim_text_submitted(text)
	await process_frame
	var want := float(text)
	var got := _new_constraint_value(sm, before)
	check(got == want, "typed %s %s == float(text) (got %s want %s)" % [
			kind, text, str(got), str(want)])
	check(not is_equal_approx(got, 12.5) or text == "12.5",
			"typed %s was not snapped to 0.5-step" % text)


func _new_constraint_value(sm: SketchMode, before: PackedStringArray) -> float:
	for cid in sm.sketch.constraint_ids():
		if before.has(cid):
			continue
		var info: Dictionary = sm.sketch.constraint_info(cid)
		var t := str(info.get("type", ""))
		if t == "distance" or t == "radius" or t == "diameter":
			return float(info.get("value", NAN))
	return NAN
