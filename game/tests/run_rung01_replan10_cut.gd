# Rung 1 replan 10 WP2 — Cut Up To Surface never leaves an open shell, and never leaves one without a refusal.
# Part 1: the trimmed handout jaw (hole, Ø45 head, 20 mm jaw at 45 degrees, cutter 12 mm off the head centre,
#   Power Trim by click) must cut cleanly every time. The OCCT boolean used to return an open shell for it in
#   about half of all documents (the result depends on the document's random ids), so it runs 4 times.
# Part 2: an overlapping contour is allowed to be refused, but each attempt asserts the invariant:
#   accepted -> the body exports as a closed 3MF; refused -> named, volume and feature count unchanged.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_cut.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const CUTTER_OFFSET := 12.0
## 9 mm on the shaft side of the cutter, 8 mm off the jaw axis: where the walk's Power Trim click lands.
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0
const HANDOUT_ATTEMPTS := 4
const ATTEMPTS := 6

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan10 WP2 cut guard")
	FilmUI.reset_fail_count()
	for i in range(HANDOUT_ATTEMPTS):
		var h := await run_cut("handout jaw attempt %d" % (i + 1), "handout")
		check(h["accepted"], "handout jaw attempt %d: the trimmed jaw cut is accepted (log: %s)" % [i + 1, str(h["log"])])
		check(h["export_ok"], "handout jaw attempt %d: the cut body exports as a closed 3MF (%s)" % [i + 1, h["export_msg"]])
		check(h["vol_after"] < h["vol_before"] - 4000.0 and h["vol_after"] > h["vol_before"] - 6000.0,
				"handout jaw attempt %d: the jaw removed about 5100 mm³ (%.1f -> %.1f)" % [i + 1, h["vol_before"], h["vol_after"]])
	var accepted := 0
	var refused := 0
	for i in range(ATTEMPTS):
		var r := await run_cut("jaw contour attempt %d" % (i + 1), "jaw")
		if r["accepted"]:
			accepted += 1
		else:
			refused += 1
	print("jaw contour: %d accepted, %d refused" % [accepted, refused])
	var good := await run_cut("small hole through the shaft", "hole")
	check(good["accepted"], "a clean Ø8 hole cut Up To Surface is accepted (log: %s)" % str(good["log"]))
	check(good["export_ok"], "the holed body exports as a closed 3MF (%s)" % good["export_msg"])
	check(good["vol_after"] < good["vol_before"] - 300.0 and good["vol_after"] > good["vol_before"] - 700.0,
			"the hole removed about 500 mm³ (%.1f -> %.1f)" % [good["vol_before"], good["vol_after"]])
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _extrude_count(doc) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _face_at(doc, body: String, z: float) -> String:
	for f in doc.get_face_ids(body):
		var m: Vector3 = doc.face_midpoint(f)
		var bb: Dictionary = doc.measure_bbox(f)
		var ext: Vector3 = bb["max"] - bb["min"]
		if absf(m.z - z) < 0.01 and ext.z < 0.01 and ext.x * ext.y > 100.0:
			return f
	return ""


func _log_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


## Returns {accepted, export_ok, export_msg, vol_before, vol_after, log}.
func run_cut(label: String, kind: String) -> Dictionary:
	print("-- " + label)
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var sk = sm.sketch
	sk.add_circle(0.0, 0.0, 10.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var tangent_x := HEAD.x - sqrt(22.5 * 22.5 - 100.0)
	sk.add_line(0.0, 10.0, tangent_x, 10.0)
	sk.add_line(0.0, -10.0, tangent_x, -10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	var doc = ctx.view.doc
	check(not doc.body_ids().is_empty(), "the blank was extruded")
	var body: String = doc.body_ids()[0]
	var top := _face_at(doc, body, 10.0)
	var bottom := _face_at(doc, body, 0.0)
	check(top != "" and bottom != "", "the blank has a top and a bottom face")
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	sk = sm.sketch
	check(sm.active, "the face sketch is active")
	if kind == "handout":
		await _build_and_trim_handout_jaw(ctx)
	elif kind == "jaw":
		sk.add_circle(HEAD.x, HEAD.y, 22.5)
		sk.add_line(177.0, -0.5, 237.0, -0.5)
		sk.add_line(237.0, -0.5, 237.0, 12.5)
		sk.add_line(237.0, 12.5, 177.0, 12.5)
		sk.add_line(177.0, 12.5, 177.0, -0.5)
	else:
		sk.add_circle(100.0, 0.0, 4.0)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if kind == "handout":
		check(SketchMode.profile_is_closed(sm.sketch), "the handout jaw profile is closed after the trim")
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	var end: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	op.select(1)
	end.select(3)
	end.item_selected.emit(3)
	await process_frame
	await _x11_click(chrome.opposite_face_button())
	await process_frame
	await process_frame
	check(str(chrome.up_to_face_id) == bottom, "Opposite face stored the bottom face")
	var vol_before := float(doc.measure_mass(body)["volume"])
	var exts_before := _extrude_count(doc)
	_status_log.clear()
	await _x11_click(chrome.extrude_button())
	await process_frame
	await process_frame
	await process_frame
	var out := {"accepted": false, "export_ok": false, "export_msg": "n/a", "vol_before": vol_before,
			"vol_after": -1.0, "log": _status_log.duplicate()}
	var bodies: PackedStringArray = doc.body_ids()
	if not bodies.is_empty():
		out["vol_after"] = float(doc.measure_mass(bodies[0])["volume"])
		var path := OS.get_cache_dir().path_join("sx-replan10-cut-%s.3mf" % kind)
		var ok: bool = doc.export_3mf_for_body(bodies[0], path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		out["export_ok"] = ok
		out["export_msg"] = "closed" if ok else str(doc.last_export_error())
	out["accepted"] = _extrude_count(doc) > exts_before
	if kind == "handout":
		pass
	elif out["accepted"]:
		check(out["export_ok"], "%s: an accepted cut leaves a closed mesh (%s)" % [label, out["export_msg"]])
	else:
		check(_log_has("Nothing was") or _log_has("Cut removed"), "%s: a refused cut is named (log: %s)" % [label, str(out["log"])])
		check(absf(float(out["vol_after"]) - vol_before) < 0.5, "%s: a refused cut keeps the volume (%.1f vs %.1f)" % [
				label, float(out["vol_after"]), vol_before])
		check(_extrude_count(doc) == exts_before, "%s: a refused cut adds no extrude feature" % label)
		check(sm.active, "%s: a refused cut keeps the sketch open" % label)
		check(out["export_ok"], "%s: the body is still a closed mesh after a refusal (%s)" % [label, out["export_msg"]])
	await _shutdown(ctx)
	return out


func _build_and_trim_handout_jaw(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var sk = sm.sketch
	sk.add_circle(0.0, 0.0, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p1 := HEAD + JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p2 := HEAD + JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	var p3 := HEAD - JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + JAW_DIR * CUTTER_OFFSET
	var c0 := cc - JAW_ACROSS * 25.0
	var c1 := cc + JAW_ACROSS * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()
	await _zoom(ctx, sm.to_model(HEAD), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	_status_log.clear()
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(SHAFT_SIDE))
	check(FilmUI.require_on_screen(ctx, screen, "trim click"), "the Power Trim click is on screen")
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	check(_log_has("Trimmed open jaw"), "Power Trim opened the jaw (log: %s)" % str(_status_log))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)


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


