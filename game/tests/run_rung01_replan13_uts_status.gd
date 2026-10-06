# sx-034 A9b — Up To Surface success status uses solved depth, not Blind Distance.
# Repro: 10 mm blank, face sketch, leftover Distance 20, End Up To Surface,
# Opposite face (z 0), Cut, Extrude. Status must be Extrude Up To Surface 10.0000 mm.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan13_uts_status.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan13 A9b Up To Surface status depth")
	FilmUI.reset_fail_count()
	await _case_uts_cut_status(10.0, 20.0)
	await _case_uts_cut_status(14.0, 20.0)
	await _case_blind_still_echoes_distance()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _case_uts_cut_status(blank_mm: float, leftover_blind: float) -> void:
	print("- UTS cut of a %.0f mm blank with Blind leftover %.0f" % [blank_mm, leftover_blind])
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.finish_extrude(blank_mm, "new", "blind")
	await process_frame
	var doc = ctx.view.doc
	check(not doc.body_ids().is_empty(), "blank extruded at %.0f mm" % blank_mm)
	var body: String = doc.body_ids()[0]
	var top := _face_at(doc, body, blank_mm)
	var bottom := _face_at(doc, body, 0.0)
	check(top != "" and bottom != "", "top z=%.0f and bottom z=0 faces exist" % blank_mm)
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "top-face sketch is active")
	sm.sketch.add_circle(0.0, 0.0, 4.0)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(absf(chrome.extrude_distance() - leftover_blind) < 0.05,
			"new face sketch leaves Blind Distance at %.0f (got %.3f)" % [
				leftover_blind, chrome.extrude_distance()])
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	var end: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	op.select(1)
	end.select(3)
	end.item_selected.emit(3)
	await process_frame
	await _x11_click(chrome.opposite_face_button())
	await process_frame
	await process_frame
	check(chrome.get_finish_end() == "to_face", "End is Up To Surface")
	check(str(chrome.up_to_face_id) == bottom, "Opposite face stored the bottom")
	check(absf(chrome.extrude_distance() - leftover_blind) < 0.05,
			"Blind Distance is still %.0f after Opposite face (got %.3f)" % [
				leftover_blind, chrome.extrude_distance()])
	var solved := sm.up_to_surface_depth()
	check(is_finite(solved) and absf(solved - blank_mm) < 0.05,
			"up_to_surface_depth is %.0f (got %.4f)" % [blank_mm, solved])
	var want := "Extrude Up To Surface %.4f mm" % blank_mm
	var blind_echo := "%.4f" % leftover_blind
	await _x11_click(chrome.extrude_button())
	await process_frame
	await process_frame
	await process_frame
	check(sm == null or not sm.active, "UTS cut left the sketch")
	var status := str(ctx.main.status_label.text)
	check(status.contains(want), "status is %s (got '%s')" % [want, status])
	check(not status.contains(blind_echo),
			"status does not echo leftover Blind %s (got '%s')" % [blind_echo, status])
	await _shutdown(ctx)


func _case_blind_still_echoes_distance() -> void:
	print("- Blind still reports the Distance field")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 8.0)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(absf(chrome.extrude_distance() - 20.0) < 0.05, "fresh sketch Distance is 20")
	await _x11_click(chrome.extrude_button())
	await process_frame
	await process_frame
	var status := str(ctx.main.status_label.text)
	check(status.contains("Extrude Blind 20.0000 mm"),
			"Blind status still uses Distance 20 (got '%s')" % status)
	await _shutdown(ctx)


func _face_at(doc, body: String, z: float) -> String:
	for f in doc.get_face_ids(body):
		var m: Vector3 = doc.face_midpoint(f)
		var bb: Dictionary = doc.measure_bbox(f)
		var ext: Vector3 = bb["max"] - bb["min"]
		if absf(m.z - z) < 0.05 and ext.z < 0.05:
			return f
	return ""


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
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	check(ctrl != null and ctrl.is_visible_in_tree(), "click target is visible")
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
