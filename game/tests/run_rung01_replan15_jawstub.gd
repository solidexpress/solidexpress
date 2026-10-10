# Outer-stub Power Trim (WALK_LOG chunk 3 R3) must cut the minor jaw mouth,
# not the complementary bulge that eats the Ø45 head. Same chain as
# run_rung01_replan15_chain.gd after that drag: Up To Surface, slot, neck R10,
# slot-floor R1, then top and bottom face R1, closed 3MF, check_rung01 wrench.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan15_jawstub.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL := 0.2
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0
const LONG_DISCARD := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 10.0
const CUTTER_MID := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 12.0
# Upper-right stub, past the Ø45 rim (u=22.5). The stroke crosses that stub.
const OUTER_STUB := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 30.0
const STAGES: Array[String] = ["S1", "S2", "S2b", "S3", "S3b", "S4", "S5", "S6", "S7", "S8"]
const BAD_STATUS: Array[String] = [
	"breaks the chain",
	"open profile",
	"Open-profile cut needs a line chain",
	"left an open shell",
]

var _status_log: Array[String] = []
var _stage := ""
var _stage_base := ""
var _first_red := ""
var _stage_fail: Dictionary = {}
var _skipped: Dictionary = {}
var _main = null
var _cutter_id := ""
var _blank_path := ""
var _wrench_path := ""
var _thick_path := ""
var _shell_n := 0
var _slot_floor_refused := false
var _slot_floor_error := ""


func check(cond: bool, what: String) -> void:
	super.check(cond, what)
	if not cond:
		if STAGES.has(_stage) and not _skipped.get(_stage, false):
			if not _stage_fail.has(_stage):
				_stage_fail[_stage] = what
			if _first_red == "":
				_first_red = _stage


func _init() -> void:
	print("rung01 replan15 outer-stub jaw trim")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	var built := await _setup_blank(ctx)
	if not built:
		_skip("setup", STAGES)
	else:
		await _run_chain(ctx)
	_print_summary()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	finish()


func _begin(id: String) -> void:
	_stage = id
	print("-- %s" % id)
	_status_log.clear()
	_stage_base = str(_main.status_label.text) if _main != null else ""


func _capture() -> void:
	if _main == null or _main.status_label == null:
		return
	var t := str(_main.status_label.text)
	if t == "" or t == _stage_base:
		return
	if _status_log.size() > 0 and _status_log[_status_log.size() - 1] == t:
		return
	_status_log.append(t)


func _dump_log() -> void:
	print("STATUS-LOG %s" % _stage)
	if _status_log.is_empty():
		print("  | (empty)")
	for s in _status_log:
		print("  | %s" % s)


func _skip(reason: String, ids: Array) -> void:
	for id in ids:
		_stage = str(id)
		_skipped[_stage] = true
		print("-- %s" % _stage)
		check(false, "skipped: %s red" % reason)
		_dump_log()


func _print_summary() -> void:
	print("STAGE-TABLE")
	for id in STAGES:
		var state := "GREEN"
		if _skipped.get(id, false):
			state = "SKIP"
		elif _stage_fail.has(id):
			state = "RED"
		var detail := str(_stage_fail.get(id, ""))
		if detail != "":
			print("  %s %s — %s" % [id, state, detail])
		else:
			print("  %s %s" % [id, state])
	var red := "none" if _first_red == "" else _first_red
	print("CHAIN-SUMMARY stages=%d first_red=%s" % [STAGES.size(), red])


func _run_chain(ctx: FilmContext) -> void:
	var doc = ctx.view.doc
	var body: String = doc.body_ids()[0]
	var top := _face_at(doc, body, 10.0)
	var bottom := _face_at(doc, body, 0.0)
	check(top != "" and bottom != "", "setup: blank has a top and a bottom face")
	if top == "" or bottom == "":
		_skip("setup", STAGES)
		return
	await _stage_s1(ctx, top, body)
	await _stage_s2(ctx)
	await _stage_s2b(ctx)
	await _stage_s3(ctx, bottom)
	if _stage_fail.has("S3"):
		_skip("S3", ["S3b", "S4", "S5", "S6", "S7", "S8"])
		return
	body = ctx.view.doc.body_ids()[0]
	await _stage_s3b(ctx, body)
	top = _face_at(ctx.view.doc, body, 10.0)
	await _stage_s4(ctx, top, body)
	body = ctx.view.doc.body_ids()[0]
	await _stage_s5(ctx, body)
	await _stage_s6(ctx)
	await _stage_s7(ctx)
	await _stage_s8()


func _setup_blank(ctx: FilmContext) -> bool:
	_stage = "setup"
	print("-- setup blank")
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "setup: ground sketch is active")
	if sm == null or not sm.active:
		return false
	var sk = sm.sketch
	sk.add_circle(0.0, 0.0, 10.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var tangent_x := HEAD.x - sqrt(22.5 * 22.5 - 100.0)
	sk.add_line(0.0, 10.0, tangent_x, 10.0)
	sk.add_line(0.0, -10.0, tangent_x, -10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	check(doc.body_ids().size() == 1, "setup: one body (got %d)" % doc.body_ids().size())
	if doc.body_ids().is_empty():
		return false
	var body: String = doc.body_ids()[0]
	var bb: Dictionary = doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.x - 232.5) <= TOL and absf(ext.y - 45.0) <= TOL and absf(ext.z - 10.0) <= TOL,
			"setup: blank bbox 232.5 × 45 × 10 (got %.3f × %.3f × %.3f)" % [ext.x, ext.y, ext.z])
	_blank_path = "/tmp/sx-rung01-jawstub-blank.3mf"
	var ok: bool = doc.export_3mf_for_body(body, _blank_path)
	check(ok and FileAccess.file_exists(_blank_path), "setup: blank closed-shell export")
	_run_checker_print("blank", [_blank_path])
	return doc.body_ids().size() == 1


func _stage_s1(ctx: FilmContext, top: String, body: String) -> void:
	_begin("S1")
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "S1: jaw sketch is active")
	if not sm.active:
		_dump_log()
		return
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	var prev_snap := sm.snap_enabled
	sm.snap_enabled = false
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_DIR * 30.0)
	sm.click(HEAD + JAW_ACROSS * 10.0)
	sm.snap_enabled = prev_snap
	for i in sm.dimensions.size():
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) == "distance":
			sm.set_dimension_value(i, 20.0)
		elif str(dim.get("type", "")) == "angle":
			sm.set_dimension_value(i, 45.0)
	_cutter_id = _add_profile_cutter(sm, "perp")
	sm.run_solve()
	var constructed := _cutter_id != "" and sm.sketch.is_construction(_cutter_id)
	check(_cutter_id != "" and not constructed,
			"S1: cutter is not construction (id=%s construction=%s)" % [_cutter_id, str(constructed)])
	var contours := int(sm.sketch.contour_count())
	check(contours >= 1, "S1: contour_count >= 1 (got %d)" % contours)
	_dump_log()


func _stage_s2(ctx: FilmContext) -> void:
	_begin("S2")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "S2: sketch still active")
	if sm == null or not sm.active:
		_dump_log()
		return
	await _zoom_model(ctx, sm.to_model(HEAD), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	check(sm.tool == SketchMode.Tool.TRIM, "S2: Power Trim is the active tool")
	var origin0: Vector3 = sm.plane_origin
	var pivot0: Vector3 = ctx.main.camera.pivot
	_status_log.clear()
	_stage_base = str(_main.status_label.text)
	await _drag_between(ctx, OUTER_STUB + JAW_DIR * 4.0, OUTER_STUB - JAW_DIR * 4.0)
	_capture()
	check(_saw("Trimmed open jaw"), "S2: status log has Trimmed open jaw (log=%s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "S2: profile is closed")
	_assert_minor_mouth(sm)
	check(not _cutter_remains(sm), "S2: the cutter Line is gone")
	var origin1: Vector3 = sm.plane_origin
	var pivot1: Vector3 = ctx.main.camera.pivot
	check(origin0.distance_to(origin1) <= 0.5 and pivot0.distance_to(pivot1) <= 0.5,
			"S2: no pan (plane origin moved %.3f mm, camera target moved %.3f mm)" % [
				origin0.distance_to(origin1), pivot0.distance_to(pivot1)])
	_dump_log()


func _assert_minor_mouth(sm: SketchMode) -> void:
	var arc: Dictionary = {}
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "arc":
			arc = info
			break
	check(not arc.is_empty(), "S2: outer-stub trim left a jaw arc")
	if arc.is_empty():
		return
	var sa := float(arc["start_angle"])
	var ea := float(arc["end_angle"])
	var sweep := wrapf(ea - sa, 0.0, TAU)
	check(sweep <= PI + 0.05, "S2: jaw arc is the minor mouth (sweep %.3f rad)" % sweep)
	var mid := Vector2.from_angle(sa + sweep * 0.5)
	check(mid.dot(JAW_DIR) > 0.5, "S2: jaw arc midpoint faces the stub (dot %.3f)" % mid.dot(JAW_DIR))


func _stage_s2b(ctx: FilmContext) -> void:
	_begin("S2b")
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		check(false, "S2b: sketch still active for the second drag")
		_dump_log()
		return
	await _drag_between(ctx, LONG_DISCARD + JAW_DIR * 2.0 + JAW_ACROSS * 4.0,
			LONG_DISCARD + JAW_DIR * 2.0 - JAW_ACROSS * 4.0)
	_capture()
	check(_saw("Jaw is already open"), "S2b: status log has Jaw is already open (log=%s)" % str(_status_log))
	_dump_log()


func _stage_s3(ctx: FilmContext, bottom: String) -> void:
	_begin("S3")
	var sm: SketchMode = ctx.main.sketch_mode
	_print_sketch_snapshot(sm, "S3")
	var doc = ctx.view.doc
	var exts_before := _extrude_count(doc)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_op(_finish_op(ctx), 1)
	await _pick_end(_finish_end(ctx), 3)
	_capture()
	var opp := chrome.opposite_face_button()
	var t0 := Time.get_ticks_msec()
	while opp != null and not opp.is_visible_in_tree() and Time.get_ticks_msec() - t0 < 1000:
		await process_frame
	check(opp != null and opp.is_visible_in_tree(), "S3: Opposite face button is visible")
	if opp != null and opp.is_visible_in_tree():
		await _x11_click(opp)
		await process_frame
		await process_frame
	_capture()
	check(str(chrome.up_to_face_id) == bottom,
			"S3: up_to_face_id is the bottom face (got %s want %s)" % [chrome.up_to_face_id, bottom])
	var ex_btn := chrome.extrude_button()
	check(ex_btn != null and not ex_btn.disabled, "S3: Extrude is enabled")
	_status_log.clear()
	_stage_base = str(_main.status_label.text)
	if ex_btn != null:
		await _x11_click(ex_btn)
	for _i in 4:
		await process_frame
	_capture()
	check(_saw("Extrude Up To Surface 10.0000 mm"),
			"S3: status has Extrude Up To Surface 10.0000 mm (log=%s label=%s)" % [
				str(_status_log), str(_main.status_label.text)])
	check(not _bad_hit(), "S3: no bad status (log=%s label=%s)" % [str(_status_log), str(_main.status_label.text)])
	check(_extrude_count(doc) == exts_before + 1,
			"S3: one more extrude feature (%d -> %d)" % [exts_before, _extrude_count(doc)])
	var bodies: PackedStringArray = doc.body_ids()
	var shell := false
	if not bodies.is_empty():
		shell = _closed_shell(doc, bodies[0])
	check(shell, "S3: closed-shell export")
	_dump_log()


func _stage_s3b(ctx: FilmContext, body: String) -> void:
	_begin("S3b")
	var doc = ctx.view.doc
	var mesh := _load_mesh(doc, body)
	var open_pt := Vector3(HEAD.x + JAW_DIR.x * 15.0, HEAD.y + JAW_DIR.y * 15.0, 5.0)
	# HEAD − JAW_DIR·30 is 30 mm from the head centre, outside the Ø45 disc, so it
	# cannot be solid. The wall probe is inside the head, beside the 20 mm jaw.
	var wall_pt := Vector3(
			HEAD.x + JAW_DIR.x * 10.0 + JAW_ACROSS.x * 14.0,
			HEAD.y + JAW_DIR.y * 10.0 + JAW_ACROSS.y * 14.0,
			5.0)
	var spec_pt := Vector3(HEAD.x - JAW_DIR.x * 30.0, HEAD.y - JAW_DIR.y * 30.0, 5.0)
	check(not _inside(mesh, open_pt),
			"S3b: jaw interior open at HEAD + JAW_DIR·15, z=5 (inside=%s)" % str(_inside(mesh, open_pt)))
	check(_inside(mesh, wall_pt),
			"S3b: wall solid beside the jaw at z=5 (inside=%s)" % str(_inside(mesh, wall_pt)))
	var bb: Dictionary = doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.x - 232.5) <= TOL and absf(ext.y - 45.0) <= TOL and absf(ext.z - 10.0) <= TOL,
			"S3b: head survives the cut (bbox %.3f × %.3f × %.3f)" % [ext.x, ext.y, ext.z])
	print("  note - HEAD − JAW_DIR·30 inside=%s (outside the Ø45; diagnostic only)" % str(_inside(mesh, spec_pt)))
	_assert_jaw(mesh, 20.0)
	_assert_pivot(mesh)
	_dump_log()


func _stage_s4(ctx: FilmContext, top: String, body: String) -> void:
	_begin("S4")
	check(top != "", "S4: top face after the jaw cut")
	if top == "":
		_dump_log()
		return
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	_print_sketch_snapshot(sm, "S4")
	check(sm.active, "S4: slot sketch is active")
	if not sm.active:
		_dump_log()
		return
	await _zoom_model(ctx, sm.to_model(Vector2(93.5, 0.0)), 280.0)
	await _press_rail_label(ctx, "Slot")
	_capture()
	check(sm.tool == SketchMode.Tool.SLOT, "S4: Slot tool is armed (got %s)" % str(sm.tool))
	await _type_dim(ctx, "5", false)
	_capture()
	check(absf(sm.slot_radius - 5.0) < 1e-3, "S4: slot radius typed 5 (got %.4f)" % sm.slot_radius)
	await _click_uv_local(ctx, Vector2(18.5, 0.0), "S4 slot first centre")
	await _hover_uv(ctx, Vector2(168.5, 0.0))
	await _type_dim(ctx, "150", false)
	_capture()
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_op(_finish_op(ctx), 1)
	await _pick_end(_finish_end(ctx), 0)
	await _type_distance(ctx, "2.5")
	_capture()
	var ex_btn := chrome.extrude_button()
	check(ex_btn != null and not ex_btn.disabled, "S4: Extrude is enabled")
	_status_log.clear()
	_stage_base = str(_main.status_label.text)
	if ex_btn != null:
		await _x11_click(ex_btn)
	for _i in 4:
		await process_frame
	_capture()
	check(_saw("Extrude Blind 2.5000 mm"),
			"S4: status Extrude Blind 2.5000 mm (log=%s label=%s)" % [
				str(_status_log), str(_main.status_label.text)])
	check(not _bad_hit(), "S4: no bad status (log=%s label=%s)" % [str(_status_log), str(_main.status_label.text)])
	var doc = ctx.view.doc
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.is_empty():
		check(false, "S4: body remains after the slot cut")
		_dump_log()
		return
	body = bodies[0]
	var mesh := _load_mesh(doc, body)
	check(not _inside(mesh, Vector3(93.5, 0, 8.75)), "S4: slot open at (93.5, 0, 8.75)")
	check(_inside(mesh, Vector3(93.5, 0, 6.5)), "S4: pocket floor solid at (93.5, 0, 6.5)")
	check(_closed_shell(doc, body), "S4: closed-shell export")
	_dump_log()


func _stage_s5(ctx: FilmContext, body: String) -> void:
	_begin("S5")
	var doc = ctx.view.doc
	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	await _fillet_one(ctx, body, "neck", far_x, Vector3.ZERO, 10.0)
	await _fillet_one(ctx, body, "top face", 0.0, Vector3(200, -16, 10), 1.0)
	await _fillet_one(ctx, body, "bottom face", 0.0, Vector3(50, 0, 0), 1.0)
	await _fillet_slot_floor(ctx, body)
	await _refuse_slot_floor(ctx, body)
	check(_slot_floor_refused, "S5: R1.5 on the slot floor is refused")
	check(_slot_floor_error.contains("1.25"),
			"S5: R1.5 last_graph_error contains 1.25 (got '%s')" % _slot_floor_error)
	check(_closed_shell(doc, body), "S5: closed-shell export after the refused fillet")
	_dump_log()


func _fillet_one(ctx: FilmContext, body: String, label: String, neck_x: float, point: Vector3,
		radius: float) -> void:
	var before := _count_type(ctx, "fillet")
	var log_at := _status_log.size()
	if label == "neck":
		await _fillet_neck(ctx, body, neck_x)
	elif label == "bottom face":
		await _fillet_face(ctx, body, Vector3(0, 0, -1), point, radius, label)
	else:
		await _fillet_face(ctx, body, Vector3(0, 0, 1), point, radius, label)
	_capture()
	check(_count_type(ctx, "fillet") == before + 1, "S5: %s adds one fillet feature" % label)
	check(ctx.view.doc.last_graph_error() == "",
			"S5: %s last_graph_error empty (got '%s')" % [label, ctx.view.doc.last_graph_error()])
	check(_fresh_has("applied", log_at),
			"S5: %s success status contains applied (label=%s)" % [label, ctx.main.status_label.text])
	check(_closed_shell(ctx.view.doc, body), "S5: closed-shell export after %s" % label)


func _fillet_slot_floor(ctx: FilmContext, body: String) -> void:
	var point := Vector3(93.5, 0, 7.5)
	await _ensure_body_selected(ctx, body)
	var before := _count_type(ctx, "fillet")
	var tris0 := _tri_count(ctx.view.doc, body)
	var log_at := _status_log.size()
	await _arm_fillet(ctx, 1.0)
	await _view_key(ctx, KEY_3)
	await FilmUI.zoom_point_clear_of_edges(ctx, body, point)
	await _click_model(ctx, point, "slot floor")
	_capture()
	_print_edge_pick(ctx, body)
	var n := ctx.view.selected_edges.size()
	check(n >= 4, "S5: slot floor click selected the face edges (got %d, status %s)" % [
			n, ctx.main.status_label.text])
	var long150 := 0
	var neck := 0
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for eid in ctx.view.selected_edges:
		var length := _edge_length(lines, str(eid))
		if absf(length - 150.0) <= 1.0:
			long150 += 1
		if absf(length - 175.4) < 1.0 or absf(length - 42.2) < 1.0:
			neck += 1
	check(long150 >= 2, "S5: slot-floor pick has >= 2 lines of length 150 (got %d)" % long150)
	check(neck == 0, "S5: slot-floor pick has no neck loop of length 175.4 or 42.2 (got %d)" % neck)
	if n < 1:
		check(false, "S5: slot floor fillet adds one fillet feature")
		return
	await _commit_fillet(ctx)
	_capture()
	var tris1 := _tri_count(ctx.view.doc, body)
	check(_count_type(ctx, "fillet") == before + 1, "S5: slot floor adds one fillet feature")
	check(ctx.view.doc.last_graph_error() == "",
			"S5: slot floor last_graph_error empty (got '%s')" % ctx.view.doc.last_graph_error())
	check(_fresh_has("applied", log_at),
			"S5: slot floor success status contains applied (label=%s)" % ctx.main.status_label.text)
	check(tris1 > tris0, "S5: slot-floor R1 increases triangle count (%d -> %d)" % [tris0, tris1])
	check(_closed_shell(ctx.view.doc, body), "S5: closed-shell export after slot floor")


func _stage_s6(ctx: FilmContext) -> void:
	_begin("S6")
	_wrench_path = await _export_via_dialog(ctx, "wrench.3mf")
	_capture()
	check(_wrench_path != "" and FileAccess.file_exists(_wrench_path),
			"S6: wrench.3mf exists (%s)" % _wrench_path)
	var status := str(ctx.main.status_label.text)
	check(status.begins_with("Exported 3MF → ") and status.contains(_wrench_path),
			"S6: status starts Exported 3MF → and names the path (%s)" % status)
	_dump_log()


func _stage_s7(ctx: FilmContext) -> void:
	_begin("S7")
	await _show_timeline(ctx)
	var boss := _boss_extrude_id(ctx)
	check(boss != "", "S7: base extrude is on the timeline")
	if boss != "":
		await _type_timeline_distance(ctx, boss, "14")
		await _timeline_panel_dismiss(ctx, boss)
	_capture()
	_thick_path = await _export_via_dialog(ctx, "wrench-t14.3mf")
	_capture()
	check(_thick_path != "" and FileAccess.file_exists(_thick_path),
			"S7: wrench-t14.3mf exists (%s)" % _thick_path)
	var warns := str(ctx.view.doc.graph_warnings())
	check(warns.find("lost on rebuild") < 0, "S7: graph_warnings has no lost on rebuild (%s)" % warns)
	_dump_log()


func _stage_s8() -> void:
	_begin("S8")
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	check(FileAccess.file_exists(checker), "S8: tools/check_rung01.py exists")
	var blank := _run_checker_print("blank", [_blank_path])
	check(blank["code"] == 0 and str(blank["text"]).contains("5/5"),
			"S8: blank checker 5/5 (exit %d)" % int(blank["code"]))
	var wrench := _run_checker_print("wrench", [_wrench_path])
	var wtext := str(wrench["text"])
	check(int(wrench["code"]) == 0 and wtext.contains("28/28") and not wtext.contains("22/22"),
			"S8: wrench checker exit 0 and 28/28 (not 22/22) (exit %d)" % int(wrench["code"]))
	var thick := _run_checker_print("thick", [_thick_path, "14"])
	check(int(thick["code"]) == 0 and str(thick["text"]).contains("7/7"),
			"S8: thick checker 7/7 (exit %d)" % int(thick["code"]))
	_dump_log()


func _run_checker_print(kind: String, args: Array) -> Dictionary:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	var output: Array = []
	var argv := PackedStringArray()
	argv.append(checker)
	argv.append(kind)
	for a in args:
		argv.append(str(a))
	print("CHECKER %s" % kind)
	var code := OS.execute("python3", argv, output, true)
	var text := "\n".join(output)
	print(text)
	return {"code": code, "text": text}


func _fresh_has(needle: String, log_at: int) -> bool:
	if _main != null and str(_main.status_label.text).contains(needle):
		return true
	var start := log_at
	if start > _status_log.size():
		start = 0
	for i in range(start, _status_log.size()):
		if _status_log[i].contains(needle):
			return true
	return false


func _saw(needle: String) -> bool:
	if _status_has(needle):
		return true
	if _main == null:
		return false
	var label := str(_main.status_label.text)
	if label == _stage_base:
		return false
	return label.contains(needle)


func _bad_hit() -> bool:
	for needle in BAD_STATUS:
		if _saw(needle):
			return true
	return false


func _closed_shell(doc, body: String) -> bool:
	_shell_n += 1
	var path := "/tmp/sx-rung01-replan15-shell-%d.3mf" % _shell_n
	return bool(doc.export_3mf_for_body(body, path))


func _cutter_remains(sm: SketchMode) -> bool:
	if sm == null or sm.sketch == null:
		return true
	if _cutter_id != "" and sm.sketch.entity_ids().has(_cutter_id):
		return true
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		var mid := (a + b) * 0.5
		if mid.distance_to(CUTTER_MID) <= 1.0 and a.distance_to(b) > 20.0:
			return true
	return false


func _print_sketch_snapshot(sm: SketchMode, tag: String) -> void:
	if sm == null or sm.sketch == null:
		print("SKETCH-SNAPSHOT %s (no sketch)" % tag)
		return
	var ids: PackedStringArray = sm.sketch.entity_ids()
	print("SKETCH-SNAPSHOT %s entities=%d" % [tag, ids.size()])
	for id in ids:
		var info: Dictionary = sm.sketch.entity_info(id)
		print("  %s type=%s construction=%s" % [id, str(info.get("type", "")), str(sm.sketch.is_construction(id))])


func _print_edge_pick(ctx: FilmContext, body: String) -> void:
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	print("EDGE-PICK slot-floor count=%d status=%s" % [
			ctx.view.selected_edges.size(), str(ctx.main.status_label.text)])
	for eid in ctx.view.selected_edges:
		print("  edge %s length=%.3f" % [str(eid), _edge_length(lines, str(eid))])


func _edge_length(lines: Dictionary, eid: String) -> float:
	if not lines.has(eid):
		return -1.0
	var pts: PackedVector3Array = lines[eid]
	if pts.size() < 2:
		return 0.0
	var n := 0.0
	for i in range(1, pts.size()):
		n += pts[i - 1].distance_to(pts[i])
	return n


func _tri_count(doc, body: String) -> int:
	var mesh := _load_mesh(doc, body)
	var idx: PackedInt32Array = mesh[1]
	return idx.size() / 3


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


func _add_profile_cutter(sm: SketchMode, kind: String) -> String:
	var c0: Vector2
	var c1: Vector2
	if kind == "horiz":
		c0 = Vector2(HEAD.x - 40.0, HEAD.y)
		c1 = Vector2(HEAD.x + 40.0, HEAD.y)
	else:
		var cc := HEAD + JAW_DIR * 12.0
		c0 = cc - JAW_ACROSS * 25.0
		c1 = cc + JAW_ACROSS * 25.0
	var id: String = sm.sketch.add_line(c0.x, c0.y, c1.x, c1.y)
	return id


func _drag_between(ctx: FilmContext, from_uv: Vector2, to_uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var a := FilmUI.model_to_screen(ctx, sm.to_model(from_uv))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(to_uv))
	check(FilmUI.require_on_screen(ctx, a, "trim drag start"), "trim drag start on screen")
	check(FilmUI.require_on_screen(ctx, b, "trim drag end"), "trim drag end on screen")
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	for i in range(1, 13):
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / 12.0)
		m.global_position = m.position
		vp.push_input(m)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await process_frame


func _zoom_model(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


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
	_main = main
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	if main.ops_panel != null:
		main.ops_panel.status.connect(_on_status)
	if main.interaction != null:
		main.interaction.status.connect(_on_status)
	if main.timeline != null:
		main.timeline.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _finish_end(ctx: FilmContext) -> OptionButton:
	return ctx.main.sketch_chrome.find_child("FinishEnd", true, false) as OptionButton


func _finish_op(ctx: FilmContext) -> OptionButton:
	return ctx.main.sketch_chrome.find_child("FinishOp", true, false) as OptionButton


func _pick_end(opt: OptionButton, index: int) -> void:
	check(opt != null and opt.is_visible_in_tree(), "finish end is visible")
	if opt == null:
		return
	await _click_control(opt)
	opt.show_popup()
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = opt.get_popup()
	check(popup != null and popup.visible, "FinishEnd popup is visible")
	if popup == null:
		return
	var id := popup.get_item_id(index)
	var clicked: bool = await _click_popup_item(popup, id, "FinishEnd index %d" % index)
	check(clicked, "FinishEnd item %d was clicked" % index)
	await process_frame


func _pick_op(opt: OptionButton, index: int) -> void:
	check(opt != null and opt.is_visible_in_tree(), "finish op is visible")
	if opt == null:
		return
	await _click_control(opt)
	opt.show_popup()
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:
		await process_frame
	var popup: PopupMenu = opt.get_popup()
	check(popup != null and popup.visible, "FinishOp popup is visible")
	if popup == null:
		return
	var id := popup.get_item_id(index)
	var clicked: bool = await _click_popup_item(popup, id, "FinishOp index %d" % index)
	check(clicked, "FinishOp item %d was clicked" % index)
	await process_frame


func _click_control(ctrl: Control) -> void:
	var pos := FilmUI.ensure_control_visible(ctrl)
	await process_frame
	pos = ctrl.get_global_rect().get_center()
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


func _x11_click_screen_local(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
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


func _x11_click_at(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	await _x11_click_screen_local(vp, pos, double_click)


func _x11_click_embedded(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + pos
	await _x11_click_at(root.get_viewport(), pos)


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


func _item_screen_center(popup: PopupMenu, index: int) -> Vector2:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		y += _popup_row_height(popup, i, font_h, v_sep)
	y += _popup_row_height(popup, index, font_h, v_sep) * 0.5
	return Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)


func _click_popup_item(popup: PopupMenu, id: int, desc: String) -> bool:
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "popup has item id %d (%s)" % [id, desc])
		return false
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(idx)
	popup.reset_size()
	await process_frame
	var screen: Vector2 = _item_screen_center(popup, idx)
	var got: Array = [-1]
	var cb := func(pressed_id: int) -> void:
		got[0] = pressed_id
	popup.id_pressed.connect(cb)
	await _x11_click_screen_local(root.get_viewport(), screen)
	await process_frame
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	return got[0] == id


func _click_menu_item(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button is visible for %s" % [title, desc])
		return false
	var center := FilmUI.ensure_control_visible(btn)
	check(FilmUI.is_on_screen(ctx, center), "%s menu is on screen for %s" % [title, desc])
	await _x11_click(btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	var t0 := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t0 < 450:
		await process_frame
	if popup == null or not popup.visible:
		check(false, "%s popup is visible after click (%s)" % [title, desc])
		return false
	return await _click_popup_item(popup, id, desc)


func _dialog_name_edit(dlg: FileDialog) -> LineEdit:
	if dlg == null:
		return null
	if dlg.has_method("get_line_edit"):
		var le: Variant = dlg.get_line_edit()
		if le is LineEdit:
			return le as LineEdit
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit != null:
			return edit
	return null


func _type_export_name(dlg: FileDialog, path: String) -> void:
	var edit := _dialog_name_edit(dlg)
	check(edit != null, "Export 3MF name LineEdit exists")
	if edit == null:
		return
	await _x11_click_embedded(edit)
	await process_frame
	await _x11_type(edit.get_viewport(), path)
	await process_frame


func _export_via_dialog(ctx: FilmContext, name: String, _probe_survival: bool = false, _bare: bool = false) -> String:
	var path := "/tmp/sx-rung01-%s" % name
	var opened: bool = await _click_menu_item(ctx, "File", 11, "File → Export 3MF")
	await process_frame
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "Export 3MF opens a FileDialog for %s" % name)
	if dlg == null or not dlg.visible:
		return ""
	check(str(dlg.current_file).ends_with(".3mf"),
			"dialog suggests a .3mf name (got %s)" % dlg.current_file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	for _i in 4:
		await process_frame
	await _type_export_name(dlg, path)
	var ok_btn := dlg.get_ok_button()
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "export OK is visible for %s" % name)
	if ok_btn != null:
		await _x11_click_embedded(ok_btn)
		await process_frame
		await process_frame
		await process_frame
	check(ctx.main.is_inside_tree(), "main stays in the tree after export OK for %s" % name)
	var status := str(ctx.main.status_label.text)
	check(status.begins_with("Exported 3MF → ") and status.contains(path),
			"export status for %s starts with Exported 3MF → and contains the path (%s)" % [name, status])
	if dlg.visible:
		dlg.hide()
	return path if FileAccess.file_exists(path) else ""


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 47:
			code = KEY_SLASH
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame


func _x11_select_all(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.physical_keycode = KEY_A
	ev.unicode = 0
	ev.ctrl_pressed = true
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _x11_enter(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
	await process_frame


func _type_dim(ctx: FilmContext, text: String, second_click: bool) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null and chrome._dim_spin != null:
		edit = chrome._dim_spin.get_line_edit()
	check(edit != null, "DimLineEdit exists for typing %s" % text)
	if edit == null:
		return
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	if second_click:
		var raw := _spin_digits(edit)
		check(not raw.contains("2.522"),
				"second dim text does not contain 2.522 (got '%s')" % raw)
		check(raw.contains(text) or (raw.is_valid_float() and absf(float(raw) - float(text)) < 0.001),
				"second dim text parses as %s (got '%s')" % [text, raw])
	await _x11_enter(edit.get_viewport())
	await process_frame
	await process_frame


func _spin_digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := str(edit.text).strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	return text.strip_edges()


func _type_distance(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	if edit == null and chrome._extrude_spin != null:
		edit = chrome._extrude_spin.get_line_edit()
	check(edit != null, "DistanceLineEdit exists for typing %s" % text)
	if edit == null:
		return
	var t0 := Time.get_ticks_msec()
	while not edit.is_visible_in_tree() and Time.get_ticks_msec() - t0 < 800:
		await process_frame
	check(edit.is_visible_in_tree(), "DistanceLineEdit is visible for typing %s" % text)
	var vr := edit.get_global_rect()
	var vp_r := edit.get_viewport().get_visible_rect()
	check(vr.intersects(vp_r) or vp_r.encloses(vr),
			"DistanceLineEdit is on screen for %s (edit %s vp %s)" % [text, str(vr), str(vp_r)])
	print("  DistanceLineEdit click %s at %s" % [text, str(vr)])
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	await process_frame
	await process_frame
	var got := chrome.extrude_distance()
	if absf(got - float(text)) > TOL:
		print("  distance was %.3f after first type, Ctrl+A retry for %s" % [got, text])
		await _x11_click(edit)
		await process_frame
		await _x11_select_all(edit.get_viewport())
		await _x11_type(edit.get_viewport(), text)
		await process_frame
		await process_frame
		got = chrome.extrude_distance()
	check(absf(got - float(text)) <= TOL, "typed Blind distance %s (got %.3f)" % [text, got])


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "on screen: %s" % desc)
	await _x11_click_screen_local(ctx.main.get_viewport(), screen)
	await process_frame


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _aim_pointer(ctx, screen)


func _aim_pointer(ctx: FilmContext, screen: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


func _rail_scroll(rail: Control) -> ScrollContainer:
	if rail == null:
		return null
	var named := rail.find_child("SketchRailScroll", true, false)
	if named is ScrollContainer:
		return named
	for c in rail.find_children("*", "ScrollContainer", true, false):
		return c as ScrollContainer
	return null


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


func _press_rail_label(ctx: FilmContext, label: String) -> Button:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null and btn.is_visible_in_tree(), "rail button `%s` is visible" % label)
	if btn == null:
		return null
	var scroll := _rail_scroll(ctx.main.sketch_toolbar)
	var pos := _btn_center_visible(btn, scroll)
	if pos == Vector2.INF or pos.y < 160.0 or pos.y > 520.0:
		await _scroll_btn_to_band(scroll, btn, 300.0)
		pos = _btn_center_visible(btn, scroll)
	check(pos != Vector2.INF, "rail button `%s` centre is on the rail clip" % label)
	if pos == Vector2.INF:
		return null
	await _x11_click_screen_local(ctx.main.get_viewport(), pos)
	await process_frame
	return btn


func _ensure_body_selected(ctx: FilmContext, body: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	if ctx.view.selected_body == body and ctx.main.interaction._selection_strip.visible:
		return
	await _view_key(ctx, KEY_4)
	await _click_model(ctx, Vector3(100, 10, 5), "Select wrench")
	ctx.main.interaction._refresh_selection_strip()
	await process_frame


func _fillet_neck(ctx: FilmContext, body: String, neck_x: float) -> void:
	await _ensure_body_selected(ctx, body)
	check(ctx.view.selected_body == body, "wrench selected for fillet")
	var before := _count_type(ctx, "fillet")
	await _arm_fillet(ctx, 10.0)
	var pts := _neck_click_points(ctx, body, neck_x)
	if pts.size() < 2:
		pts = [Vector3(neck_x, 10.0, 5.0), Vector3(neck_x, -10.0, 5.0)]
	for i in pts.size():
		var p: Vector3 = pts[i]
		var from_y := 1.0 if p.y >= 0.0 else -1.0
		await _view_key(ctx, KEY_4 if from_y > 0.0 else KEY_1)
		await _click_model(ctx, p, "Neck edge %s" % ("+Y" if from_y > 0.0 else "-Y"))
	check(ctx.view.selected_edges.size() >= 2, "both neck edges selected (got %d)" % ctx.view.selected_edges.size())
	check(str(ctx.main.status_label.text).contains("mm vertical"),
			"status contains mm vertical (got %s)" % ctx.main.status_label.text)
	var first_neck: Vector3 = pts[0]
	var first_y := 1.0 if first_neck.y >= 0.0 else -1.0
	await _view_key(ctx, KEY_4 if first_y > 0.0 else KEY_1)
	await _click_model(ctx, first_neck, "Neck edge deselect")
	check(str(ctx.main.status_label.text).contains("removed"),
			"status contains removed (got %s)" % ctx.main.status_label.text)
	await _click_model(ctx, first_neck, "Neck edge reselect")
	await _commit_fillet(ctx)
	check(_count_type(ctx, "fillet") == before + 1, "one fillet on both neck edges")
	check(ctx.view.doc.last_graph_error() == "", "neck fillet accepted (%s)" % ctx.view.doc.last_graph_error())


func _neck_click_points(ctx: FilmContext, body: String, neck_x: float) -> Array:
	var found: Dictionary = {}
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.is_empty():
			continue
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(mid.x - neck_x) < 1.5 and absf(absf(mid.y) - 10.0) < 0.8 and absf(mid.z - 5.0) < 1.5:
			var side := 1 if mid.y >= 0.0 else -1
			if not found.has(side):
				found[side] = mid
	var out: Array = []
	if found.has(1):
		out.append(found[1])
	if found.has(-1):
		out.append(found[-1])
	return out


func _fillet_face(ctx: FilmContext, body: String, from_side: Vector3, point: Vector3,
		radius: float, label: String) -> void:
	await _ensure_body_selected(ctx, body)
	var before := _count_type(ctx, "fillet")
	await _arm_fillet(ctx, radius)
	if from_side.z < -0.5:
		await _view_key(ctx, KEY_8)
	else:
		await _view_key(ctx, KEY_3)
	var bb0: Dictionary = {}
	if label == "bottom face":
		print("  B13.4 Bottom-face pick")
		bb0 = ctx.view.doc.measure_bbox(body)
		_status_log.clear()
	if label == "slot floor":
		await FilmUI.zoom_point_clear_of_edges(ctx, body, point)
	await _click_model(ctx, point, label)
	if label == "bottom face":
		var screen := FilmUI.model_to_screen(ctx, point)
		var moved := screen + Vector2(40, 0)
		await _aim_pointer(ctx, moved)
		await process_frame
		var bb1: Dictionary = ctx.view.doc.measure_bbox(body)
		var min0: Vector3 = bb0.get("min", Vector3.ZERO)
		var max0: Vector3 = bb0.get("max", Vector3.ZERO)
		var min1: Vector3 = bb1.get("min", Vector3.ZERO)
		var max1: Vector3 = bb1.get("max", Vector3.ZERO)
		check(min0.is_equal_approx(min1) and max0.is_equal_approx(max1),
				"B13.4 bbox unchanged after bottom-face click + 40px move")
		check(not _status_has("Moved body") and not str(ctx.main.status_label.text).contains("Moved body"),
				"B13.4 status never says Moved body (got %s)" % ctx.main.status_label.text)
	var n := ctx.view.selected_edges.size()
	check(n >= 4, "%s click selected the face edges (got %d, status %s)" % [
		label, n, ctx.main.status_label.text])
	if label == "top face":
		check(not str(ctx.main.status_label.text).contains("No edges selected"),
				"top-face fillet status is not No edges selected (got %s)" % ctx.main.status_label.text)
	if n < 1:
		return
	await _commit_fillet(ctx)
	check(_count_type(ctx, "fillet") == before + 1, "fillet committed on %s" % label)
	check(ctx.view.doc.last_graph_error() == "", "%s fillet accepted (%s)" % [label, ctx.view.doc.last_graph_error()])


func _refuse_slot_floor(ctx: FilmContext, body: String) -> void:
	var point := Vector3(93.5, 0, 7.5)
	await _ensure_body_selected(ctx, body)
	var before := _count_type(ctx, "fillet")
	var vol0: float = ctx.view.doc.body_volume(body)
	await _arm_fillet(ctx, 1.5)
	await _view_key(ctx, KEY_3)
	await FilmUI.zoom_point_clear_of_edges(ctx, body, point)
	await _click_model(ctx, point, "Slot floor")
	if ctx.view.selected_edges.is_empty():
		_slot_floor_error = str(ctx.view.doc.last_graph_error())
		_slot_floor_refused = false
		return
	await _commit_fillet(ctx)
	_slot_floor_error = str(ctx.view.doc.last_graph_error())
	_slot_floor_refused = _count_type(ctx, "fillet") == before and _slot_floor_error != ""
	check(absf(ctx.view.doc.body_volume(body) - vol0) < 1e-3, "body unchanged after refused fillet")
	check(_count_type(ctx, "fillet") == before, "S5: R1.5 leaves the fillet count unchanged")
	print("  slot floor refusal: " + _slot_floor_error)
	await _esc_ends_pick(ctx)


func _arm_fillet(ctx: FilmContext, radius: float) -> void:
	var btn: Button = ctx.main.interaction._strip_fillet
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Fillet", "Arm fillet"))
	await process_frame
	var spin: SpinBox = ctx.main.interaction._strip_radius
	check(spin != null and spin.is_visible_in_tree(), "fillet radius blank visible")
	if spin == null:
		return
	await _type_strip_radius(ctx, _radius_digits(radius))


func _commit_fillet(ctx: FilmContext) -> void:
	var spin: SpinBox = ctx.main.interaction._strip_radius
	if spin == null:
		return
	var edit: LineEdit = spin.get_line_edit()
	edit.grab_focus()
	await process_frame
	await _push_key_local(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	# Field Enter commits the radius only. Viewport Enter applies.
	if ctx.main.ops_panel._pending != OpsPanel.Pending.NONE:
		ctx.main.interaction.return_viewport_keys()
		await process_frame
		await _push_key_local(ctx.main.get_viewport(), KEY_ENTER, 0)
		await process_frame
		await process_frame
	var applied := spin.value
	if is_equal_approx(applied, 10.0) or is_equal_approx(applied, 1.0):
		print("  B13.8 Fillet radius %s" % _radius_digits(applied))
		_assert_strip_equals_panel(ctx, applied, _radius_digits(applied))
	if str(ctx.view.doc.last_graph_error()) != "":
		await _push_key_local(ctx.main.get_viewport(), KEY_ESCAPE, 0)
		await process_frame


func _radius_digits(radius: float) -> String:
	if is_equal_approx(radius, round(radius)):
		return str(int(round(radius)))
	return str(radius)


func _type_strip_radius(ctx: FilmContext, digits: String) -> void:
	var spin: SpinBox = ctx.main.interaction._strip_radius
	check(spin != null and spin.is_visible_in_tree(), "radius spin is visible for typing %s" % digits)
	if spin == null:
		return
	var edit: LineEdit = spin.get_line_edit()
	edit.grab_focus()
	await process_frame
	await _ctrl_a(edit.get_viewport())
	await process_frame
	var sel := edit.get_selected_text()
	check(sel != "" and sel == edit.text,
			"radius field is selected (sel '%s' text '%s')" % [sel, edit.text])
	await _type_text(edit.get_viewport(), digits)
	await process_frame
	var shown := edit.text.strip_edges()
	check(shown == digits or shown.begins_with(digits + ".") or shown.begins_with(digits + " "),
			"typed radius %s is in the spin (got '%s')" % [digits, edit.text])


func _ctrl_a(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.physical_keycode = KEY_A
	ev.unicode = 0
	ev.ctrl_pressed = true
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = KEY_A
	rel.physical_keycode = KEY_A
	rel.unicode = 0
	rel.ctrl_pressed = true
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _assert_strip_equals_panel(ctx: FilmContext, want: float, tag: String) -> void:
	var spin: SpinBox = ctx.main.interaction.find_child("StripRadius", true, false)
	check(spin != null, "B13.8 %s StripRadius exists" % tag)
	if spin == null:
		return
	var panel: float = ctx.main.ops_panel.dressup_radius()
	check(is_equal_approx(spin.value, want) and is_equal_approx(panel, want),
			"B13.8 %s StripRadius equals panel Radius %s (strip %s panel %s)" % [
				tag, str(want), str(spin.value), str(panel)])


func _push_key_local(vp: Viewport, keycode: Key, unicode: int, ctrl := false, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	rel.echo = false
	rel.ctrl_pressed = ctrl
	rel.shift_pressed = shift
	vp.push_input(rel)
	await process_frame


func _view_key(ctx: FilmContext, code: int) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.sketch_orientation_locked = false
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	cam.handle_input(ev, true)
	await process_frame
	await process_frame


func _click_model(ctx: FilmContext, pt: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, pt)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen, false)
	await process_frame


func _pointer_click(ctx: FilmContext, pos: Vector2, double_click: bool) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _count_type(ctx: FilmContext, type: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == type:
			n += 1
	return n


func _show_timeline(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	if ctx.main.show_timeline:
		ctx.main._update_panel_visibility()
		if ctx.main.timeline != null:
			ctx.main.timeline.refresh()
		await process_frame
		return
	var opened: bool = await _click_menu_item(ctx, "View", 4, "View → Timeline")
	await process_frame
	check(opened and ctx.main.show_timeline, "View → Timeline opened")
	if ctx.main.timeline != null:
		ctx.main.timeline.refresh()
		await process_frame


func _type_timeline_distance(ctx: FilmContext, fid: String, digits: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	var btn := _row_name_button(tl, fid)
	check(btn != null, "extrude row")
	if btn == null:
		return
	await _double_click_control(ctx, btn)
	await process_frame
	await process_frame
	check(tl.property_panel.visible, "double-click extrude opens Distance")
	var spin := tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	check(spin != null, "distance field is Param_distance")
	if spin == null:
		return
	var edit: LineEdit = spin.get_line_edit()
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == edit, "distance LineEdit is focused")
	var selected := edit.get_selected_text() if edit != null else ""
	check(selected != "" and selected == edit.text,
			"distance text is selected ('%s')" % selected)
	await _type_text(ctx.main.get_viewport(), digits)
	await _push_key_local(ctx.main.get_viewport(), KEY_ENTER, 0)
	if digits == "14":
		print("  B13.14 Typed fields (Distance)")
		for i in 5:
			await process_frame
			var shown := "" if edit == null else edit.text.strip_edges()
			check(not shown.contains("10") or shown.contains("14"),
					"B13.14 Distance never flashes old 10 after 14 Enter (frame %d got `%s`)" % [i, shown])
	else:
		await process_frame
		await process_frame
	var got := _feature_distance(ctx, fid)
	check(absf(got - float(digits)) < 0.05, "base extrude distance is %.3f" % got)


func _timeline_panel_dismiss(ctx: FilmContext, boss: String) -> void:
	print("- timeline panel: Esc cancels the preview, an empty click keeps it")
	var panel = ctx.main.timeline.property_panel
	check(panel.visible, "the Distance panel is open with the focused field")
	await _real_esc(ctx)
	check(not panel.visible, "one real Esc closes the Distance panel")
	check(absf(_feature_distance(ctx, boss) - 10.0) < 0.05,
			"Esc cancelled the previewed 14 (distance %.3f)" % _feature_distance(ctx, boss))
	await _type_timeline_distance(ctx, boss, "14")
	var empty := _walk_empty_pixel(ctx)
	check(empty != Vector2.INF, "found a pixel off the solid for the click-away")
	if empty != Vector2.INF:
		await _aim_pointer(ctx, empty)
		await _pointer_click(ctx, empty, false)
	check(not panel.visible, "one empty-viewport click closes the Distance panel")
	check(absf(_feature_distance(ctx, boss) - 14.0) < 0.05,
			"the click-away keeps 14 (distance %.3f)" % _feature_distance(ctx, boss))


func _esc_ends_pick(ctx: FilmContext) -> void:
	var presses := 0
	while ctx.main.ops_panel._pending != OpsPanel.Pending.NONE and presses < 3:
		await _real_esc(ctx)
		presses += 1
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.NONE and presses <= 2,
			"real Esc ends the armed fillet within two presses (%d)" % presses)


func _real_esc(ctx: FilmContext) -> void:
	await _push_key_local(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame


func _walk_empty_pixel(ctx: FilmContext) -> Vector2:
	var size: Vector2 = ctx.main.get_viewport().get_visible_rect().size
	for f in [Vector2(0.9, 0.19), Vector2(0.86, 0.75), Vector2(0.7, 0.15), Vector2(0.55, 0.81)]:
		var p: Vector2 = f * size
		var ray: Array = ctx.main.interaction._model_ray(p)
		if ctx.view.pick_info(ray[0], ray[1]).is_empty():
			return p
	return Vector2.INF


func _double_click_control(ctx: FilmContext, ctrl: Control) -> void:
	FilmUI.ensure_control_visible(ctrl)
	await process_frame
	var center := ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, false)
	await process_frame
	center = ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, true)


func _boss_extrude_id(ctx: FilmContext) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("op", "new")) != "cut":
			return str(f.get("id", ""))
	return ""


func _feature_distance(ctx: FilmContext, fid: String) -> float:
	for f in ctx.view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			return float(parsed.get("distance", -1))
	return -1.0


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and child.text != "":
			return child
	return null


func _assert_pivot(mesh: Array) -> void:
	var open := true
	for z in [0.5, 5.0, 9.5]:
		if _inside(mesh, Vector3(0, 0, z)):
			open = false
	check(open, "S3b: pivot hole open at z=0.5/5/9.5")


func _assert_jaw(mesh: Array, af: float) -> void:
	var s2 := sqrt(2.0) / 2.0
	var axis := Vector3(s2, s2, 0)
	var pv := Vector3(-s2, s2, 0)
	var h := Vector3(200, 0, 0)
	var open := true
	for u in [3.0, 11.0, 18.0]:
		for z in [0.5, 5.0, 9.5]:
			if _inside(mesh, h + axis * u + Vector3(0, 0, z)):
				open = false
				print("  jaw still solid at u=%.1f z=%.1f" % [u, z])
	check(open, "S3b: jaw open through the depth")
	for z in [2.0, 5.0, 8.0]:
		var pa := _first_hit(mesh, h + axis * 10.0 + Vector3(0, 0, z), pv)
		var pb := _first_hit(mesh, h + axis * 10.0 + Vector3(0, 0, z), -pv)
		var g := pa + pb if pa >= 0.0 and pb >= 0.0 else -1.0
		check(g > 0.0 and absf(g - af) <= TOL, "S3b: jaw AF at z=%.0f is %.3f (want %.1f)" % [z, g, af])


func _load_mesh(doc, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	if mesh == null:
		return [verts, idx]
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if ii.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	return [verts, idx]


func _ray_hits(mesh: Array, origin: Vector3, dir: Vector3) -> Array[float]:
	var verts: PackedVector3Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	var d := dir.normalized()
	var hits: Array[float] = []
	var ntri := idx.size() / 3
	for t in ntri:
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var e1 := b - a
		var e2 := c - a
		var pvec := d.cross(e2)
		var det := e1.dot(pvec)
		if absf(det) < 1e-12:
			continue
		var inv := 1.0 / det
		var svec := origin - a
		var u := svec.dot(pvec) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := svec.cross(e1)
		var v := d.dot(q) * inv
		if v < 0.0 or u + v > 1.0:
			continue
		var dist := e2.dot(q) * inv
		if dist > 1e-6:
			hits.append(dist)
	hits.sort()
	return hits


func _inside(mesh: Array, pt: Vector3) -> bool:
	var votes := 0
	for d in [Vector3(1, 0.0123, 0.0071), Vector3(0.0091, 1, 0.0137), Vector3(0.0113, 0.0067, 1)]:
		if _ray_hits(mesh, pt, d).size() % 2 == 1:
			votes += 1
	return votes >= 2


func _first_hit(mesh: Array, origin: Vector3, dir: Vector3) -> float:
	var hits := _ray_hits(mesh, origin, dir)
	if hits.is_empty():
		return -1.0
	return hits[0]
