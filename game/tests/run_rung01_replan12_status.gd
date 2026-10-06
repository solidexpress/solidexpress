# Rung 1 replan 12 WP4 — sketch statuses: Slot c-c readback, Jaw commit, Centerline, Circle and
# Select tool hints.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_status.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan12 WP6 sketch statuses")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


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
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	sm.status.connect(func(m): _log.append(str(m)))

	sm.set_tool(SketchMode.Tool.CIRCLE)
	check(_last().begins_with("Circle — click the centre"), "Circle tool status is its own hint (got `%s`)" % _last())
	check(not _last().contains("Rect"), "Circle status no longer carries the Rect hint")
	sm.set_tool(SketchMode.Tool.SELECT)
	check(_last().begins_with("Select — click geometry"), "Select tool press has a status (got `%s`)" % _last())
	sm.set_tool(SketchMode.Tool.CENTERLINE)
	check(_last().begins_with("Centerline — click 2 points"), "Centerline tool status (got `%s`)" % _last())
	sm.click(Vector2(-60.0, 40.0))
	sm.click(Vector2(-20.0, 40.0))
	check(_last().begins_with("Centerline added"), "Centerline commit has a status (got `%s`)" % _last())

	sm.set_tool(SketchMode.Tool.SLOT)
	sm.slot_radius = 5.0
	sm.click(Vector2(0.0, 0.0))
	sm.click(Vector2(150.0, 0.0))
	check(_last() == "Slot c-c 150.0000 R5.0000", "Slot status reads back the length (got `%s`)" % _last())
	sm.set_tool(SketchMode.Tool.SLOT)
	sm.click(Vector2(0.0, -30.0))
	sm.set_length_override(150.0)
	sm.click(Vector2(100.0, -30.0))
	check(_last() == "Slot c-c 150.0000 R5.0000 — typed", "typed Slot length is marked typed (got `%s`)" % _last())
	sm.set_tool(SketchMode.Tool.SLOT)
	sm.click(Vector2(0.0, -60.0))
	sm.click(Vector2(150.3466, -60.0))
	check(_last() == "Slot c-c 150.3466 R5.0000", "a rubber-band 150.35 is visible in the status (got `%s`)" % _last())

	# A11a walk: first centre, type length Enter. Dim-submit used to overwrite
	# Slot c-c with a bare `Length 150.0000 mm` because last_commit_text was empty.
	sm.set_tool(SketchMode.Tool.SLOT)
	sm.slot_radius = 5.0
	sm.click(Vector2(0.0, -90.0))
	sm.hover(Vector2(40.0, -90.0))
	main.sketch_chrome.sync_for_tool()
	var cc_label: Label = main.sketch_chrome.find_child("RadiusLabel", true, false)
	var cc_cue: Label = main.sketch_chrome.find_child("DimRadiusCue", true, false)
	check(cc_label != null and cc_label.visible and str(cc_label.text) == "c-c",
			"after the first centre the dim field is labelled c-c (got `%s` visible=%s)" % [
				str(cc_label.text) if cc_label != null else "missing",
				str(cc_label.visible) if cc_label != null else "missing"])
	check(cc_cue == null or not cc_cue.visible,
			"after the first centre the r cue is hidden")
	main._on_sketch_dim_submitted(150.0)
	check(str(main.status_label.text) == "Slot c-c 150.0000 R5.0000 — typed",
			"typed Slot length via dim Enter is Slot c-c … — typed (got `%s`)" % main.status_label.text)
	check(not str(main.status_label.text).begins_with("Length"),
			"typed Slot length does not fall back to Length … mm")
	check(sm.last_commit_text() == "Slot c-c 150.0000 R5.0000 — typed",
			"last_commit_text is the Slot c-c sentence (got `%s`)" % sm.last_commit_text())

	# Rule 23 fallback: editing the 150 label must re-read Slot c-c, not only
	# Dimension updated.
	var cc_i := -1
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == "distance":
			cc_i = i
	check(cc_i >= 0, "slot recorded a centre-to-centre dimension")
	if cc_i >= 0:
		main.interaction._dim_edit_index = cc_i
		main.interaction._apply_dim_edit("150")
		check(str(main.status_label.text) == "Slot c-c 150.0000 R5.0000",
				"Smart Dim of the slot c-c re-reads Slot c-c (got `%s`)" % main.status_label.text)

	sm.start_jaw_tool()
	sm.click(Vector2(200.0, 0.0))
	sm.click(Vector2(230.0, 0.0))
	sm.click(Vector2(230.0, 10.0))
	check(_last().begins_with("Jaw committed — width 20.0000, long side 0.0°"), "Jaw commit has a status (got `%s`)" % _last())
	main.queue_free()
	await process_frame
	await process_frame
