# Rung 1 replan 11 WP4 — Power Trim picks a cross-jaw cutter over an along-jaw leftover,
# names the leftover when it is the only line, and Construction/X replace jaw cutters only.
# Validation: calls trim_at / toggle_construction_selected on SketchMode.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_trim.gd
extends SceneTree

const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
## The walk's Power Trim click: 3 mm along the jaw and 8 mm across it, on the shaft side of the cutter.
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan11 WP4 trim cutter")
	await test_prefers_cross_jaw_cutter()
	await test_along_jaw_refusal()
	await test_toggle_replaces_jaw_cutters()
	await test_toggle_outside_jaw()
	check(true, "validation path")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Ø10 hole at the origin (or at `hole_c`), Ø45 head at HEAD, the 20 mm wide Jaw rectangle at 45 degrees,
## and the perpendicular cutter centreline `offset` mm along the jaw from the head centre.
func _build_jaw(sm: SketchMode, offset: float, hole_c: Vector2) -> String:
	var sk = sm.sketch
	sk.add_circle(hole_c.x, hole_c.y, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p1 := HEAD + JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p2 := HEAD + JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	var p3 := HEAD - JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + JAW_DIR * offset
	var c0 := cc - JAW_ACROSS * 25.0
	var c1 := cc + JAW_ACROSS * 25.0
	var cutter_id: String = sk.add_line(c0.x, c0.y, c1.x, c1.y)
	sk.set_construction(cutter_id, true)
	sm.run_solve()
	return cutter_id


## Along-jaw construction 2 mm off the shaft-side click (closer than the 9 mm
## cross-jaw cutter, but not collinear with the click so trim_at can refuse).
func _add_along_jaw(sk) -> String:
	var origin := SHAFT_SIDE - JAW_ACROSS * 2.0
	var a := origin - JAW_DIR * 25.0
	var b := origin + JAW_DIR * 25.0
	var id: String = sk.add_line(a.x, a.y, b.x, b.y)
	sk.set_construction(id, true)
	return id


func _alive(sm: SketchMode, id: String) -> bool:
	return id != "" and not sm.sketch.entity_info(id).is_empty()


func _arc_radius_near(sm: SketchMode, centre: Vector2) -> float:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "arc" and (info["center"] as Vector2).distance_to(centre) <= 0.5:
			return float(info.get("radius", 0.0))
	return -1.0


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func test_prefers_cross_jaw_cutter() -> void:
	print("-- both construction lines: trim prefers the cross-jaw cutter")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	_build_jaw(sm, 12.0, Vector2.ZERO)
	var along_id := _add_along_jaw(sm.sketch)
	_status_log.clear()
	sm.trim_at(SHAFT_SIDE)
	check(_status_has("Trimmed open jaw"), "trim_at opens the jaw with both construction lines (log: %s)" % str(_status_log))
	check(not _status_has("does not cross two jaw sides"), "status does not claim the cutter misses the sides (log: %s)" % str(_status_log))
	check(_alive(sm, along_id), "the along-jaw construction line is still in the sketch")
	check(SketchMode.profile_is_closed(sm.sketch), "the trimmed Jaw profile is closed")
	_status_log.clear()
	sm.trim_at(SHAFT_SIDE)
	check(_status_has("Jaw is already open"), "a second trim_at says the jaw is already open (log: %s)" % str(_status_log))
	await _shutdown(main)


func test_along_jaw_refusal() -> void:
	print("-- only the along-jaw line: named refusal")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	var cutter_id := _build_jaw(sm, 12.0, Vector2.ZERO)
	sm.sketch.remove_entity(cutter_id)
	_add_along_jaw(sm.sketch)
	_status_log.clear()
	sm.trim_at(SHAFT_SIDE)
	check(_status_has("runs along the jaw") and _status_has("delete the along-jaw line"),
			"along-jaw-only trim names the leftover (log: %s)" % str(_status_log))
	check(not SketchMode.profile_is_closed(sm.sketch) or _arc_radius_near(sm, HEAD) < 0.0,
			"profile is not closed after the along-jaw refusal")
	await _shutdown(main)


func test_toggle_replaces_jaw_cutters() -> void:
	print("-- Construction on a cross-jaw line drops the along-jaw leftover")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	var datum_id := _build_jaw(sm, 12.0, Vector2.ZERO)
	sm._angle_datum_lines[datum_id] = true
	var along_id := _add_along_jaw(sm.sketch)
	var far_id: String = sm.sketch.add_line(0.0, 80.0, 30.0, 80.0)
	sm.sketch.set_construction(far_id, true)
	var x0 := HEAD - JAW_ACROSS * 25.0
	var x1 := HEAD + JAW_ACROSS * 25.0
	var cross_id: String = sm.sketch.add_line(x0.x, x0.y, x1.x, x1.y)
	var sel: Array[String] = [cross_id]
	sm._set_selected(sel)
	_status_log.clear()
	sm.toggle_construction_selected()
	check(not _alive(sm, along_id) and _status_has("Removed 1 jaw construction line"),
			"toggle drops the along-jaw leftover (log: %s)" % str(_status_log))
	check(_alive(sm, far_id), "a construction line far from the jaw survives the toggle")
	check(_alive(sm, datum_id), "a datum construction line is not removed")
	await _shutdown(main)


func test_toggle_outside_jaw() -> void:
	print("-- Construction on a lone line is Construction on")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	var id: String = sm.sketch.add_line(0.0, 0.0, 10.0, 0.0)
	var n := sm.sketch.entity_ids().size()
	var sel: Array[String] = [id]
	sm._set_selected(sel)
	_status_log.clear()
	sm.toggle_construction_selected()
	check(_last_status() == "Construction on" and sm.sketch.entity_ids().size() == n
			and sm.sketch.is_construction(id),
			"toggle outside a jaw emits Construction on (log: %s)" % str(_status_log))
	await _shutdown(main)


func _boot():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.view.clear_selection()
	main._start_sketch()
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return main


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(main) -> void:
	main.queue_free()
	await process_frame
	await process_frame
