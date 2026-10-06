# Rung 1 replan 11 WP11 — 3D picks use view keys 1 3 4 8 (Front / Top /
# Back / Bottom), not a scripted camera look. The walk is the sx-026
# sequence: right-half head click, Smart Dimension popup on the second
# centre (no label click), Path-field bare export (no Enter in that field),
# leftover then offset centreline, shaft-side Power Trim, Cut. Numeric
# line edits keep the replan-4 _x11_click / _x11_type path. The four
# sx-026 steps use _x11_click_screen with no await between mouse-down
# and mouse-up.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const SHAFT_PICK_X := 100.0
const TOL := 0.2
const ROOT_SIZE := Vector2i(1280, 800)
const NEW_SENTENCE := "New — empty part, Top plane (XY). View ▸ Timeline to edit features"
const FAILED_SKETCH := "Failed to update sketch"
const BARE_EXPORT_DIR := "/tmp/sx-rung01-out"
const HEAD := Vector2(200, 0)
const JAW := Vector2(sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)
const PERP := Vector2(-sqrt(2.0) / 2.0, sqrt(2.0) / 2.0)

var failures := 0
var checks := 0
var _bad_status: Array[String] = []
var _status_log: Array[String] = []
var _slot_floor_refused := false
var _slot_floor_error := ""


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 wrench walk (replan-6 WP4 sx-026 sequence)")
	FilmUI.reset_fail_count()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 for the whole walk (got %s)" % str(root.size))
	main.sketch_mode.status.connect(_on_sketch_status)

	var paths := await _walk(ctx)
	if not paths.is_empty():
		await _run_checker(paths)
		_assert_timeline(ctx)
		await _edit_jaw_to_21(ctx, str(paths.get("jaw_sketch", "")))
		await _triball_one_esc(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _on_sketch_status(text: String) -> void:
	_status_log.append(text)
	if text.contains("Failed to add") or text.contains("Failed to save") \
			or text.contains("Failed to update") or text.contains("Extrude failed") \
			or text.contains("Trim failed"):
		_bad_status.append(text)
		printerr("  status: " + text)


func _status_has(needle: String) -> bool:
	if str(needle) == "":
		return false
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _take_bad_status() -> String:
	if _bad_status.is_empty():
		return ""
	var s := "; ".join(_bad_status)
	_bad_status.clear()
	return s


func _walk(ctx: FilmContext) -> Dictionary:
	print("- recovery: rectangle, Extrude, reopen, delete edge, Exit Sketch, File New")
	await _file_new(ctx)
	await _recovery_open_profile_then_new(ctx)

	print("- File New again, empty part, sketch on Top")
	await _file_new(ctx)
	check(ctx.view.doc.body_ids().is_empty(), "New leaves no bodies")
	check(ctx.main.interaction.triball == null or not ctx.main.interaction.triball.active,
			"New did not arm TriBall")
	await _empty_sketch_exit(ctx)
	await _ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var plane_z := sm.plane_normal().dot(Vector3(0, 0, 1)) if sm.active else 0.0
	var cam: Camera3D = ctx.main.camera
	var look_model := Vector3.ZERO
	if cam != null and ctx.main.model_space != null:
		var look_world := (-cam.global_basis.z).normalized()
		look_model = ctx.main.model_space.global_basis.inverse() * look_world
	check(sm.active and plane_z > 0.9, "sketch plane normal along Z (Top)")
	check(absf(look_model.z) > 0.9, "camera looks along model Z (got %s)" % look_model)

	print("- nut: polygon AF 20, circle radius 5, extrude 7.5")
	check(root.size == ROOT_SIZE, "nut runs at 1280×800 (got %s)" % str(root.size))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats without a setter (got %s)" % sm.tool_variant)
	_assert_polygon_chips_clear(ctx)
	await _click_uv(ctx, Vector2.ZERO, "Hex centre")
	print("  B13.14 Typed fields (polygon preview)")
	var last_r := -1.0
	var tips: Array[Vector2] = [Vector2(8, 3), Vector2(10, 6), Vector2(12, 4)]
	for tip in tips:
		await _hover_uv(ctx, tip)
		await process_frame
		var got_r := _preview_circumradius(sm, Vector2.ZERO)
		var want_r: float = tip.length() / sqrt(3.0)
		check(got_r > 0.0 and absf(got_r - want_r) <= 0.05,
				"B13.14 polygon preview radius follows pointer at %s (got %.4f want %.4f)" % [
					str(tip), got_r, want_r])
		check(last_r < 0.0 or not is_equal_approx(got_r, last_r),
				"B13.14 polygon preview changed with the pointer (was %.4f now %.4f)" % [last_r, got_r])
		last_r = got_r
	await _type_hex_af_digits(ctx, sm, cam)
	_assert_hex_flats(sm)
	_assert_hex_not_pointer_af(sm)
	check(_status_has("Polygon AF 20") or str(ctx.main.status_label.text).contains("Polygon AF 20"),
			"status contains Polygon AF 20 (got %s)" % ctx.main.status_label.text)
	check(_status_has("flats horizontal") or str(ctx.main.status_label.text).contains("flats horizontal"),
			"status contains flats horizontal (got %s)" % ctx.main.status_label.text)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2.ZERO, "Bore centre")
	await _hover_uv(ctx, Vector2(4, 0))
	await _type_dim(ctx, "5", false)
	var bore := _first_of(sm, "circle")
	check(bore != "", "bore circle exists")
	if bore != "":
		var br := float(sm.sketch.entity_info(bore)["radius"])
		check(absf(br - 5.0) <= 0.05, "typed 5 is bore radius 5 (got %.4f)" % br)
		check(absf(br - 3.04) > 0.2, "bore is not the pointer radius ~3.04 (got %.4f)" % br)
	check(_status_has("Circle r=5") or str(ctx.main.status_label.text).contains("Circle r=5"),
			"status contains Circle r=5 (got %s)" % ctx.main.status_label.text)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_end(_finish_end(ctx), 0)
	await _pick_op(_finish_op(ctx), 0)
	_assert_thin_off(ctx)
	check(not sm.has_single_dof_preview(), "bore is committed, no preview before 7.5")
	print("  nut Distance: X11 click DistanceLineEdit, type 7.5, no Enter")
	await _type_distance(ctx, "7.5")
	check(absf(chrome.extrude_distance() - 7.5) < 0.05, "nut distance is 7.5")
	var nut_readout := ""
	var nut_readout_node: Label = chrome.find_child("ExtrudeReadout", true, false)
	if nut_readout_node != null:
		nut_readout = str(nut_readout_node.text)
	check(nut_readout.contains("7.5"),
			"readout contains 7.5 before Extrude (got %s)" % nut_readout)
	await _press_extrude(ctx, "Extrude nut 7.5")
	var err := _take_bad_status()
	check(err == "", "nut extrude status clean" if err == "" else err)
	var nut_body := _only_body(ctx)
	check(nut_body != "", "nut body exists")
	if nut_body == "":
		return {}
	var nut_bb: Dictionary = ctx.view.doc.measure_bbox(nut_body)
	var nut_ext: Vector3 = nut_bb["max"] - nut_bb["min"]
	check(absf(nut_ext.z - 7.5) <= TOL, "nut bbox Z is 7.5 before export (got %.3f)" % nut_ext.z)
	var nut_status := str(ctx.main.status_label.text)
	check(_status_has("Extrude Blind 7.5000 mm") or nut_status.contains("Extrude Blind 7.5000 mm"),
			"status contains Extrude Blind 7.5000 mm (got %s)" % nut_status)
	var nut_path := await _export_via_dialog(ctx, "nut.3mf", true, true)
	check(nut_path != "" and FileAccess.file_exists(nut_path), "exported nut.3mf through the dialog")
	check(nut_path.begins_with(BARE_EXPORT_DIR),
			"bare nut.3mf landed in the browsed folder (got %s)" % nut_path)
	sm = ctx.main.sketch_mode
	if sm.active:
		await FilmUI.exit_sketch(ctx)
	check(not ctx.main.sketch_mode.active, "nut sketch quit")

	print("- Esc from HUD W and from the File menu (palette box)")
	await _esc_box_then_file_menu(ctx)
	await _assert_view_popup_opaque(ctx)

	print("- File New again, wrench blank")
	await _file_new(ctx)
	check(ctx.view.doc.body_ids().is_empty(), "second New leaves no bodies")
	check(not str(ctx.main.status_label.text).contains("Inserted"),
			"second New status does not contain Inserted (got %s)" % ctx.main.status_label.text)
	check(ctx.main.interaction.triball == null or not ctx.main.interaction.triball.active,
			"second New did not arm TriBall")
	await _ground_sketch(ctx)
	sm = ctx.main.sketch_mode
	check(root.size == ROOT_SIZE, "wrench blank runs at 1280×800 (got %s)" % str(root.size))
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	print("  wrench blank: typed radius 10 at origin, then right-half click for 22.5")
	await _draw_circle_typed(ctx, Vector2.ZERO, "10", false)
	var near_circ := _first_of(sm, "circle")
	if near_circ != "":
		var r10 := float(sm.sketch.entity_info(near_circ)["radius"])
		check(absf(r10 - 10.0) <= 0.05, "typed 10 is radius 10 (got %.4f)" % r10)
	check(_status_has("Ø20") or str(ctx.main.status_label.text).contains("Ø20"),
			"status contains Ø20 (got %s)" % ctx.main.status_label.text)
	print("  wrench blank: right-half _x11_click_screen for Ø45 centre (screen x > 640)")
	await _place_head_right_half(ctx)
	var dim_blank := _dim_edit(ctx)
	var dim_raw := _spin_digits(dim_blank)
	check(not dim_raw.contains("2.522"),
			"second dim text does not contain 2.522 (got '%s')" % dim_raw)
	var circs := _circles(sm)
	check(circs.size() == 2, "blank has two circles")
	if circs.size() == 2:
		var r45 := float(circs[1]["radius"])
		check(absf(r45 - 22.5) <= 0.05, "typed 22.5 is radius 22.5 (got %.4f)" % r45)
	check(_status_has("Ø45") or str(ctx.main.status_label.text).contains("Ø45"),
			"status contains Ø45 (got %s)" % ctx.main.status_label.text)
	print("- Smart Dimension 200 between the two wrench centres")
	await _smart_dim_centres(ctx, "200")
	circs = _circles(sm)
	if circs.size() == 2:
		var gap := (circs[0]["center"] as Vector2).distance_to(circs[1]["center"] as Vector2)
		check(absf(gap - 200.0) <= TOL, "centre distance is 200 ± 0.2 (got %.3f)" % gap)
	else:
		check(false, "two circles remain after Smart Dimension 200")
	print("  B13.10 Frame")
	await _push_key(ctx.main.get_viewport(), KEY_F, 0)
	await process_frame
	await process_frame
	_assert_both_circles_on_screen(ctx, "F after 200 dim")
	# Shaft 20 wide: the Shaft Lines chip adds the two lines at y = ±r0 that end on the Ø45.
	await _shaft_lines_via_chip(ctx)
	await _assert_shaft_lines_both_sides(sm)
	await _assert_contours_stay_on(ctx)
	chrome = ctx.main.sketch_chrome
	await _pick_end(_finish_end(ctx), 0)
	await _pick_op(_finish_op(ctx), 0)
	_assert_thin_off(ctx)
	await _type_distance(ctx, "10")
	_status_log.clear()
	await _press_extrude(ctx, "Extrude wrench blank 10")
	await process_frame
	await process_frame
	err = _take_bad_status()
	check(err == "", "blank extrude status clean" if err == "" else err)
	check(not _status_has("open profile"),
			"blank status does not contain open profile (%s)" % str(ctx.main.status_label.text))
	check(_count_type(ctx, "primitive") == 0, "blank is not a primitive")
	var body := _only_body(ctx)
	check(body != "", "wrench body exists")
	if body == "":
		return {}
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.x - 232.5) <= TOL, "blank bbox X %.3f" % ext.x)
	check(absf(ext.y - 45.0) <= TOL, "blank bbox Y %.3f" % ext.y)
	check(absf(ext.z - 10.0) <= TOL, "blank bbox Z %.3f" % ext.z)
	var blank_mesh := _load_mesh(ctx.view.doc, body)
	check(_inside(blank_mesh, Vector3(90, 0, 5)), "shaft is solid at (90, 0, 5)")
	var head_c := _head_centre_from_mesh(blank_mesh)
	print("  P2.6 head centre from mesh: (%.3f, %.3f, %.3f)" % [head_c.x, head_c.y, head_c.z])
	check(head_c.x > 0.0, "P2.6 head centre X is positive (got %.3f)" % head_c.x)
	check(absf(head_c.x - 200.0) <= 5.0,
			"P2.6 head centre X is near +200 so check_rung01 orientation is not flipX (got %.3f)" % head_c.x)

	print("- hole and open jaw, Up To Surface")
	var top := _face_along(ctx, body, 1)
	var bottom := _face_along(ctx, body, -1)
	check(top != "" and bottom != "", "top and bottom faces")
	if top == "" or bottom == "":
		return {}
	await _sketch_on_top(ctx, body, top, 10.0)
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5, "jaw sketch on the top face")
	await _zoom_uv(ctx, Vector2.ZERO, 40.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var esc_screen := FilmUI.model_to_screen(ctx, sm.to_model(Vector2.ZERO))
	await _aim_pointer(ctx, esc_screen)
	await _pointer_click(ctx, esc_screen, false)
	await process_frame
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	var drop_status := str(ctx.main.status_label.text)
	check(drop_status.contains("First point dropped — Esc again exits the sketch")
			or _status_has("First point dropped — Esc again exits the sketch"),
			"status contains First point dropped — Esc again exits the sketch (got %s)" % drop_status)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	check(not sm.active, "Esc again exits the face sketch")
	await _sketch_on_top(ctx, body, top, 10.0, false)
	sm = ctx.main.sketch_mode
	await _zoom_uv(ctx, Vector2.ZERO, 40.0)
	await _rail_click_probe(ctx)
	await _place_hole_circle(ctx)
	await _zoom_uv(ctx, Vector2(200, 0), 120.0)
	print("  B2.8 redraw Ø45 at the head as a sketch circle")
	await _draw_circle_typed(ctx, Vector2(200, 0), "22.5", true)
	var jaw_circs := _circles(sm)
	var head_r := 0.0
	for c in jaw_circs:
		var cr := float(c.get("radius", 0.0))
		var cc: Vector2 = c.get("center", Vector2.ZERO)
		if cc.distance_to(Vector2(200, 0)) < 1.0 and cr > 15.0:
			head_r = cr
	check(absf(head_r - 22.5) <= 0.05, "jaw sketch has Ø45 at the head (r=%.4f)" % head_r)
	await _draw_centre_rect(ctx, Vector2(200, 0))
	await _edit_rect_labels(ctx)
	await _circle_motions_leave_no_marks(ctx)
	await _save_as_in_sketch(ctx)
	var first_miss := 12.0
	check(first_miss > 0.15 * 22.5, "offset cutter misses the Ø45 15% gate")
	check(first_miss < 0.9 * 22.5, "offset cutter still crosses the Ø45 disc inside the 90% rim limit")
	print("  B2.10 leftover centreline along the jaw, then offset perpendicular retry")
	await _draw_centreline(ctx, HEAD, JAW)
	await _end_centreline_chain(ctx, HEAD)
	await _draw_centreline(ctx, HEAD + JAW * first_miss, PERP)
	var after_second := _non_datum_construction_ids(sm)
	check(after_second.size() == 1,
			"first centreline is gone; one cutter remains (got %d)" % after_second.size())
	var offset_d := _offset_construction_distance(sm, HEAD)
	check(offset_d > 0.15 * 22.5,
			"remaining cutter misses the head by > 3.375 (got %.3f)" % offset_d)
	await _press_rail_label(ctx, "Trim")
	_status_log.clear()
	await _power_trim_shaft_click(ctx)
	await process_frame
	await process_frame
	var trim_status := str(ctx.main.status_label.text)
	check(trim_status.contains("Trimmed open jaw") or _status_has("Trimmed open jaw"),
			"status contains Trimmed open jaw (got '%s')" % trim_status)
	err = _take_bad_status()
	check(err == "", "jaw trim status clean" if err == "" else err)
	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile closed")
	_assert_trim_typed_labels(ctx)
	_status_log.clear()
	await _power_trim_shaft_click(ctx)
	await process_frame
	check(_status_has("Jaw is already open"), "a second Power Trim click says the jaw is already open")
	err = _take_bad_status()
	check(err == "", "second trim click status clean" if err == "" else err)
	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile still closed after the second trim click")
	chrome = ctx.main.sketch_chrome
	await _pick_op(_finish_op(ctx), 1)
	await _pick_end(_finish_end(ctx), 3)
	var ex_btn := chrome.extrude_button()
	check(ex_btn != null and ex_btn.disabled, "Extrude disabled until a face is picked")
	check(str(chrome.up_to_face_id).strip_edges() == "", "Up To Surface starts with no face")
	check(chrome.wants_face_pick(), "Up To Surface arms a face pick")
	await _pick_opposite_face(ctx, bottom)
	check(str(chrome.up_to_face_id) == bottom, "Opposite face set the bottom face")
	check(ex_btn != null and not ex_btn.disabled, "Extrude enables after Opposite face")
	check(chrome.get_finish_end() == "to_face",
			"get_finish_end is to_face immediately before jaw Extrude")
	check(str(chrome.up_to_face_id) == bottom,
			"up_to_face_id is the bottom face immediately before jaw Extrude")
	var face_label := ""
	var face_node: Label = chrome.find_child("UpToFaceLabel", true, false)
	if face_node != null:
		face_label = str(face_node.text)
	check(face_label.contains("z 0"),
			"face label z is near 0 (%s)" % face_label)
	_assert_thin_off(ctx)
	_status_log.clear()
	await _press_extrude(ctx, "Cut jaw Up To Surface")
	await process_frame
	await process_frame
	err = _take_bad_status()
	check(err == "", "jaw cut status clean" if err == "" else err)
	var cut_status := str(ctx.main.status_label.text)
	var cut_blob := " | ".join(_status_log)
	check(not cut_status.contains("Open-profile cut needs a line chain")
			and not cut_blob.contains("Open-profile cut needs a line chain"),
			"jaw cut is not refused with Open-profile cut needs a line chain (got '%s')" % cut_status)
	print("  jaw cut status: %s" % cut_status)
	var cut := _extrude_with_end(ctx, "to_face")
	check(not cut.is_empty() and str(cut.get("end", "")) == "to_face", "jaw end is to_face")
	check(str(cut.get("to_face", "")) == bottom, "jaw cut stores the bottom face")
	var jaw_sketch := str(cut.get("sketch", ""))
	var mesh := _load_mesh(ctx.view.doc, body)
	_assert_jaw(mesh, 20.0)
	_assert_pivot(mesh)

	print("- grip slot R5, blind 2.5")
	top = _face_along(ctx, body, 1)
	await _sketch_on_top(ctx, body, top, 10.0)
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5, "slot sketch on the top face")
	print("  B13.6 Finish bar")
	chrome = ctx.main.sketch_chrome
	var slot_op: OptionButton = _finish_op(ctx)
	var slot_op_txt := ""
	if slot_op != null:
		slot_op_txt = slot_op.get_item_text(slot_op.selected)
	var slot_ex: Button = chrome.extrude_button() if chrome != null else null
	check(slot_op_txt == "New", "B13.6 new sketch Op is New (got %s)" % slot_op_txt)
	check(chrome != null and chrome.get_finish_end() == "blind",
			"B13.6 new sketch End is Blind (got %s)" % (chrome.get_finish_end() if chrome != null else ""))
	check(slot_ex != null and not slot_ex.disabled, "B13.6 Extrude is enabled on the new sketch")
	await _zoom_uv(ctx, Vector2(90, 0), 220.0)
	print("  B13.1 Slot by pointer")
	var slot_btn := await _press_rail_label(ctx, "Slot")
	check(slot_btn != null and slot_btn.button_pressed, "B13.1 Slot button is highlighted")
	check(sm.tool == SketchMode.Tool.SLOT, "B13.1 Slot tool is armed")
	var slot_arm := str(ctx.main.status_label.text)
	check(slot_arm.begins_with("Slot —") or slot_arm.begins_with("Slot -"),
			"B13.1 status starts Slot — (got `%s`)" % slot_arm)
	await _type_dim(ctx, "5", false)
	check(absf(sm.slot_radius - 5.0) < 1e-3, "slot radius typed into the dim blank (got %.4f)" % sm.slot_radius)
	_status_log.clear()
	await _click_uv(ctx, Vector2(18.5, 0), "Slot first centre")
	await _hover_uv(ctx, Vector2(168.5, 0))
	await _type_dim(ctx, "150", false)
	await process_frame
	var slot_commit := str(ctx.main.status_label.text)
	check(slot_commit == "Slot c-c 150.0000 R5.0000 — typed"
			or slot_commit.contains("Slot c-c 150.0000 R5.0000"),
			"B13.1 Slot c-c 150.0000 R5.0000 — typed (got `%s`)" % slot_commit)
	check(not slot_commit.begins_with("Length"),
			"B13.1 typed length is not a bare Length … mm (got `%s`)" % slot_commit)
	chrome = ctx.main.sketch_chrome
	await _pick_op(_finish_op(ctx), 1)
	await _pick_end(_finish_end(ctx), 0)
	check(str(chrome.up_to_face_id).strip_edges() == "", "Blind clears the previous face")
	_assert_thin_off(ctx)
	await _type_distance(ctx, "2.5")
	await _press_extrude(ctx, "Cut slot blind 2.5")
	await process_frame
	await process_frame
	err = _take_bad_status()
	check(err == "", "slot cut status clean" if err == "" else err)
	var slot_mesh := _load_mesh(ctx.view.doc, body)
	check(not _inside(slot_mesh, Vector3(93.5, 0, 8.75)), "slot is open at z=8.75")
	check(_inside(slot_mesh, Vector3(93.5, 0, 6.5)), "slot is a 2.5 mm pocket (solid at z=6.5)")

	print("- fillets: neck R10, faces R1, slot floor R1.5 refused")
	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	await _human_fillet_picks(ctx, body, far_x)
	await _fillet_neck(ctx, body, far_x)
	await _fillet_face(ctx, body, Vector3(0, 0, 1), Vector3(200, -16, 10), 1.0, "top face")
	await _fillet_face(ctx, body, Vector3(0, 0, -1), Vector3(50, 0, 0), 1.0, "bottom face")
	await _refuse_slot_floor(ctx, body)
	await _fillet_face(ctx, body, Vector3(0, 0, 1), Vector3(93.5, 0, 7.5), 1.0, "slot floor")
	check(_slot_floor_refused, "fillet 1.5 on the slot floor is refused")
	check(_slot_floor_error.contains("1.25"),
			"slot floor refusal names the limit (got '%s')" % _slot_floor_error)

	var wrench_path := await _export_via_dialog(ctx, "wrench.3mf")
	check(wrench_path != "" and FileAccess.file_exists(wrench_path), "exported wrench.3mf through the dialog")
	check(root.size == ROOT_SIZE, "thick edit runs at 1280×800 (got %s)" % str(root.size))
	print("- timeline: base extrude 10 → 14")
	await _show_timeline(ctx)
	var boss := _boss_extrude_id(ctx)
	check(boss != "", "base extrude is on the timeline")
	if boss != "":
		await _type_timeline_distance(ctx, boss, "14")
		await _timeline_panel_dismiss(ctx, boss)
	var thick_bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var thick_ext: Vector3 = thick_bb["max"] - thick_bb["min"]
	check(absf(thick_ext.z - 14.0) <= TOL, "thick bbox Z is 14 (got %.3f)" % thick_ext.z)
	var thick_mesh := _load_mesh(ctx.view.doc, body)
	check(not _inside(thick_mesh, Vector3(93.5, 0, 12.75)), "thick slot is open at z=12.75")
	check(not _inside(thick_mesh, Vector3(thick_bb["min"].x + 0.1, 0, 13.9)),
			"top R1 fillet survives T=14 (corner at z=13.9 is cut away)")
	check(_inside(thick_mesh, Vector3(93.5, 4.9, 11.6)),
			"slot-floor R1 fillet survives T=14 (corner material at z=11.6)")
	check(str(ctx.view.doc.graph_warnings()).find("lost on rebuild") < 0,
			"T=14 rebuild reports no lost fillet edges (%s)" % str(ctx.view.doc.graph_warnings()))
	var thick_path := await _export_via_dialog(ctx, "wrench-t14.3mf")
	check(thick_path != "" and FileAccess.file_exists(thick_path), "exported wrench-t14.3mf through the dialog")
	return {
		"nut": nut_path,
		"wrench": wrench_path,
		"thick": thick_path,
		"jaw_sketch": jaw_sketch,
	}


func _run_checker(paths: Dictionary) -> void:
	print("- check_rung01.py")
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	check(FileAccess.file_exists(checker), "tools/check_rung01.py exists")
	await _checker(checker, ["nut", str(paths["nut"])])
	await _checker(checker, ["wrench", str(paths["wrench"])])
	await _checker(checker, ["thick", str(paths["thick"]), "14"])


func _checker(checker: String, args: Array) -> void:
	var output: Array = []
	var argv := PackedStringArray()
	argv.append(checker)
	for a in args:
		argv.append(str(a))
	var code := OS.execute("python3", argv, output, true)
	var text := "\n".join(output)
	print(text)
	check(code == 0, "check_rung01.py %s exit %d" % [" ".join(args), code])
	if str(args[0]) == "thick":
		check(text.contains("7/7"), "B13.15 thick checker prints 7/7")


func _assert_timeline(ctx: FilmContext) -> void:
	var kinds: Array[String] = []
	for f in ctx.view.doc.graph_features():
		var t := str(f.get("type", ""))
		if t == "extrude":
			var parsed = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("op", "")) == "cut":
				kinds.append("cut")
			else:
				kinds.append("extrude")
		else:
			kinds.append(t)
	print("  timeline: " + ", ".join(kinds))
	var i_sketch := kinds.find("sketch")
	var i_ex := kinds.find("extrude")
	var i_cut := kinds.find("cut")
	var i_cut2 := kinds.find("cut", i_cut + 1) if i_cut >= 0 else -1
	var i_fil := kinds.find("fillet")
	var n_fil := 0
	for k in kinds:
		if k == "fillet":
			n_fil += 1
	check(i_sketch >= 0 and i_ex > i_sketch, "timeline has a sketch then an extrude")
	check(i_cut > i_ex and i_cut2 > i_cut, "timeline has two cuts after the extrude")
	check(i_fil > i_cut2 and n_fil >= 2, "timeline has fillets after the cuts (got %d)" % n_fil)


func _edit_jaw_to_21(ctx: FilmContext, jaw_sketch: String) -> void:
	print("- jaw width 20 → 21")
	check(jaw_sketch != "", "jaw sketch id")
	if jaw_sketch == "":
		return
	var sm0: SketchMode = ctx.main.sketch_mode
	if sm0 != null and sm0.active:
		await FilmUI.exit_sketch(ctx)
	await _show_timeline(ctx)
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	var btn := _row_name_button(tl, jaw_sketch)
	check(btn != null, "jaw sketch row")
	if btn == null:
		return
	await _double_click_control(ctx, btn)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active and sm.editing_fid == jaw_sketch, "double-click reopened the jaw sketch")
	if not sm.active:
		return
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var di := _dim_index_near(sm, "distance", 20.0)
	check(di >= 0, "jaw width dimension restored")
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	check(lp != null, "jaw width label has a position")
	if lp == null:
		return
	await _zoom_uv(ctx, lp as Vector2, 40.0)
	await _click_uv(ctx, lp as Vector2, "Edit jaw width")
	await process_frame
	await process_frame
	var ix = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension editor opened")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	await _type_popup(ctx, ix._dim_edit_line, "21")
	await process_frame
	await process_frame
	var ang_i := _dim_index(sm, "angle")
	var ang_shown := -1.0
	if ang_i >= 0:
		ang_shown = absf(float(sm._dimension_display_value(sm.dimensions[ang_i])))
	check(absf(ang_shown - 45.0) <= TOL, "jaw angle stays 45° after the width edit (got %.3f)" % ang_shown)
	var orient := _long_side_angle_deg(sm)
	check(absf(orient - 45.0) <= TOL, "jaw long side is still 45° (got %.3f)" % orient)
	if sm.active:
		await FilmUI.exit_sketch(ctx)
	var edited := await _export_via_dialog(ctx, "wrench-af21.3mf")
	check(edited != "" and FileAccess.file_exists(edited), "exported wrench-af21.3mf through the dialog")
	var metrics := _jaw_metrics_of_3mf(edited)
	check(metrics.x > 0.0 and absf(metrics.x - 21.0) <= TOL,
			"3MF jaw AF is 21 (got %.3f)" % metrics.x)
	check(metrics.y > 0.0 and absf(metrics.y - 45.0) <= TOL,
			"3MF jaw angle is 45° (got %.3f)" % metrics.y)


func _jaw_metrics_of_3mf(path: String) -> Vector2:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	var script := """
import importlib.util, math, sys
import numpy as np
spec = importlib.util.spec_from_file_location('chk', sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
V, T = m.load_3mf(sys.argv[2])
s2 = math.sqrt(2) / 2
ax = np.array([s2, s2, 0.0])
pv = np.array([-s2, s2, 0.0])
H = np.array([200.0, 0.0, 0.0])
best = None
for fx in (False, True):
    for fy in (False, True):
        if fx != fy:
            continue
        W = m.align(V, fx, fy, (-10, -22.5, 0))
        tris = m.tri_arrays(W, T)
        def J(u, v, z):
            return (H + u * ax + v * pv + np.array([0.0, 0.0, z])).tolist()
        def wall(u, z, sign):
            origin = np.array(J(u, 0.0, z))
            direction = sign * pv
            dist = m.first_hit(tris, origin.tolist(), direction.tolist())
            if dist is None:
                return None
            return origin + direction * float(dist)
        gs = []
        for z in (2.0, 5.0, 8.0):
            a = m.first_hit(tris, J(10, 0, z), pv)
            b = m.first_hit(tris, J(10, 0, z), -pv)
            if a is None or b is None:
                gs = []
                break
            gs.append(float(a + b))
        if not gs:
            continue
        mean = sum(gs) / len(gs)
        ang = -1.0
        p1 = wall(8.0, 5.0, 1.0)
        p2 = wall(18.0, 5.0, 1.0)
        if p1 is not None and p2 is not None:
            d = p2 - p1
            ang = abs(math.degrees(math.atan2(float(d[1]), float(d[0])))) % 180.0
            if ang > 90.0:
                ang = 180.0 - ang
        if best is None or abs(mean - 21.0) < abs(best[0] - 21.0):
            best = (mean, ang)
if best is None:
    best = (-1.0, -1.0)
print('%.6f %.6f' % (best[0], best[1]))
"""
	var py := "/tmp/rung01_jaw_af.py"
	var f := FileAccess.open(py, FileAccess.WRITE)
	if f == null:
		return Vector2(-1, -1)
	f.store_string(script)
	f.close()
	var output: Array = []
	OS.execute("python3", PackedStringArray([py, checker, path]), output, true)
	if output.is_empty():
		return Vector2(-1, -1)
	var parts := str(output[0]).strip_edges().split(" ")
	if parts.size() < 2:
		return Vector2(-1, -1)
	return Vector2(float(parts[0]), float(parts[1]))


func _triball_one_esc(ctx: FilmContext) -> void:
	print("- one Esc clears an armed TriBall")
	var body := _only_body(ctx)
	if body == "":
		check(false, "body for TriBall")
		return
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	check(not ctx.main.timeline.property_panel.visible, "no timeline panel is left open before TriBall")
	await process_frame
	await _ensure_body_selected(ctx, body)
	check(ctx.main.sketch_mode == null or not ctx.main.sketch_mode.active,
			"sketch is closed before TriBall")
	var tb_btn: Button = ctx.main.interaction._strip_triball
	await FilmUI.click_control(ctx, tb_btn, FilmUICues.alert("TriBall", "Arm TriBall"))
	await process_frame
	var tb = ctx.main.interaction.triball
	check(tb != null and tb.active, "user armed TriBall")
	tb_btn.grab_focus()
	await process_frame
	var focus: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(focus != ctx.main.interaction and not ctx.main.interaction.has_focus(),
			"Esc is not delivered by grab_focus on Interaction")
	_push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	check(tb == null or (not tb.active and not tb.visible), "one Esc clears TriBall")
	check(ctx.view.selected_body == "", "one Esc clears the selection with TriBall")
	check(ctx.main.interaction._selection_strip == null
			or not ctx.main.interaction._selection_strip.visible,
			"one Esc hides the selection strip")


func _ensure_body_selected(ctx: FilmContext, body: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	if ctx.view.selected_body == body and ctx.main.interaction._selection_strip.visible:
		return
	# Back view (key 4): a top-down click lands on the sketch pad and reopens the sketch.
	await _view_key(ctx, KEY_4)
	await _click_model(ctx, Vector3(100, 10, 5), "Select wrench")
	ctx.main.interaction._refresh_selection_strip()
	await process_frame


func _fillet_neck(ctx: FilmContext, body: String, neck_x: float) -> void:
	await _ensure_body_selected(ctx, body)
	check(ctx.view.selected_body == body, "wrench selected for fillet")
	var before := _count_type(ctx, "fillet")
	await _arm_fillet(ctx, 10.0)
	# Front (key 1) and Back (key 4): each vertical neck edge is a silhouette
	# from one side. One Front view stacks both midpoints on the same ray.
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
	var dirty0: bool = ctx.main._document_is_dirty()
	print("  B13.9 Refused fillet is clean")
	await _arm_fillet(ctx, 1.5)
	await _view_key(ctx, KEY_3)
	await _click_model(ctx, point, "Slot floor")
	if ctx.view.selected_edges.is_empty():
		_slot_floor_error = str(ctx.view.doc.last_graph_error())
		_slot_floor_refused = false
		check(ctx.main._document_is_dirty() == dirty0,
				"B13.9 dirty flag unchanged after refused R1.5 (before %s after %s)" % [
					str(dirty0), str(ctx.main._document_is_dirty())])
		return
	await _commit_fillet(ctx)
	_slot_floor_error = str(ctx.view.doc.last_graph_error())
	_slot_floor_refused = _count_type(ctx, "fillet") == before and _slot_floor_error != ""
	check(absf(ctx.view.doc.body_volume(body) - vol0) < 1e-3, "body unchanged after refused fillet")
	check(ctx.main._document_is_dirty() == dirty0,
			"B13.9 dirty flag unchanged after refused R1.5 (before %s after %s)" % [
				str(dirty0), str(ctx.main._document_is_dirty())])
	print("  slot floor refusal: " + _slot_floor_error)
	await _esc_ends_pick(ctx)


func _rail_click_probe(ctx: FilmContext) -> void:
	print("- a sketch click 30 px right of the left rail lands on the canvas")
	var sm: SketchMode = ctx.main.sketch_mode
	var rail: Control = ctx.main.sketch_toolbar
	check(rail != null and rail.is_visible_in_tree(), "sketch rail is visible")
	if rail == null:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var size: Vector2 = ctx.main.get_viewport().get_visible_rect().size
	var pos := Vector2(rail.get_global_rect().end.x + 30.0, size.y * 0.5)
	await _aim_pointer(ctx, pos)
	check(ctx.main.get_viewport().gui_get_hovered_control() == ctx.main.interaction,
			"the control under the pointer next to the rail is the viewport (got %s)" % str(
			ctx.main.get_viewport().gui_get_hovered_control()))
	await _pointer_click(ctx, pos, false)
	await process_frame
	check(sm.has_pending_draw_point(), "a Circle click next to the rail starts a circle")
	await _real_esc(ctx)
	check(not sm.has_pending_draw_point() and sm.active, "Esc drops that first point and keeps the sketch")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)


func _save_as_in_sketch(ctx: FilmContext) -> void:
	print("- File → Save As inside the sketch keeps the session")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "jaw sketch is open before Save As")
	var entities: int = sm.sketch.entity_ids().size()
	var path := "/tmp/sx-rung01-jaw-saveas.sxp"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var opened: bool = await _click_menu_item(ctx, "File", 3, "File → Save As")
	await process_frame
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "Save As opens a FileDialog")
	if dlg == null or not dlg.visible:
		return
	check(str(dlg.current_file).ends_with(".sxp"), "Save As suggests an .sxp name (got %s)" % dlg.current_file)
	for _i in 4:
		await process_frame
	print("  B13.12 Save As name")
	var name_edit := _dialog_name_edit(dlg)
	check(name_edit != null, "Save As filename LineEdit exists")
	var prefilled := str(name_edit.text) if name_edit != null else str(dlg.current_file)
	# WP7 selects the name on open; type without Ctrl+A so the typed string replaces it.
	await _x11_type(name_edit.get_viewport() if name_edit != null else dlg.get_viewport(), path)
	await process_frame
	var after_name := str(name_edit.text) if name_edit != null else str(dlg.current_file)
	check(after_name == path or after_name.ends_with(path.get_file()),
			"B13.12 typed name replaced the pre-filled name (got `%s`, was `%s`)" % [after_name, prefilled])
	check(prefilled == "" or not after_name.begins_with(prefilled) or after_name == path,
			"B13.12 name is not an append of the pre-filled value (got `%s`)" % after_name)
	var ok_btn := dlg.get_ok_button()
	if ok_btn != null:
		await _x11_click_embedded(ok_btn)
		await process_frame
		await process_frame
		await process_frame
	check(FileAccess.file_exists(path), "Save As wrote %s" % path)
	check(sm.active and ctx.main.sketch_chrome.visible, "the sketch session is still open after Save As")
	check(sm.sketch.entity_ids().size() == entities,
			"the sketch kept its %d entities (got %d)" % [entities, sm.sketch.entity_ids().size()])
	check(sm.tool == SketchMode.Tool.SELECT, "tool is Select after Save As")
	check(str(ctx.main.status_label.text).begins_with("Saved "),
			"status reads Saved <path> (got %s)" % ctx.main.status_label.text)
	var saved := SxDocument.new()
	var has_sketch := false
	if saved.load(path):
		for f in saved.graph_features():
			if str(f.get("type", "")) == "sketch":
				has_sketch = true
	check(has_sketch, "the saved file contains the sketch")
	if dlg.visible:
		dlg.hide()


func _real_esc(ctx: FilmContext) -> void:
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame


func _walk_empty_pixel(ctx: FilmContext) -> Vector2:
	var size: Vector2 = ctx.main.get_viewport().get_visible_rect().size
	for f in [Vector2(0.9, 0.19), Vector2(0.86, 0.75), Vector2(0.7, 0.15), Vector2(0.55, 0.81)]:
		var p: Vector2 = f * size
		var ray: Array = ctx.main.interaction._model_ray(p)
		if ctx.view.pick_info(ray[0], ray[1]).is_empty():
			return p
	return Vector2.INF


func _human_fillet_picks(ctx: FilmContext, body: String, neck_x: float) -> void:
	print("- fillet picks as a human: Top corner, wall click, press off the solid, Esc")
	await _ensure_body_selected(ctx, body)
	await _arm_fillet(ctx, 10.0)
	await _view_key(ctx, KEY_3)
	await _click_model(ctx, Vector3(neck_x - 0.3, 9.7, 10.0), "Top-view neck corner")
	check(ctx.view.selected_edges.size() == 1, "Top-view corner click arms one edge (got %d)" % ctx.view.selected_edges.size())
	check(str(ctx.main.status_label.text).contains("mm vertical"),
			"Top-view corner arms the vertical (got %s)" % ctx.main.status_label.text)
	var first: Array = ctx.view.selected_edges.duplicate()
	await _view_key(ctx, KEY_4)
	await _click_model(ctx, Vector3(100, 10, 5), "Back wall")
	check(not first.is_empty() and ctx.view.selected_edges.has(first[0])
			and ctx.view.selected_edges.size() <= first.size() + 1,
			"a wall click keeps the earlier pick (got %d)" % ctx.view.selected_edges.size())
	var after_wall: int = ctx.view.selected_edges.size()
	var empty := _walk_empty_pixel(ctx)
	check(empty != Vector2.INF, "found a pixel off the solid")
	if empty != Vector2.INF:
		await _aim_pointer(ctx, empty)
		await _pointer_click(ctx, empty, false)
		check(ctx.view.selected_edges.size() == after_wall,
				"a press off the solid keeps the set (got %d)" % ctx.view.selected_edges.size())
		check(str(ctx.main.status_label.text).contains("Missed the solid"),
				"the miss is named (got %s)" % ctx.main.status_label.text)
	await _esc_ends_pick(ctx)


## One Esc releases a focused radius field, the next ends the armed pick. A person
## presses Esc until the strip is quiet, so allow two and fail on a third.
func _esc_ends_pick(ctx: FilmContext) -> void:
	var presses := 0
	while ctx.main.ops_panel._pending != OpsPanel.Pending.NONE and presses < 3:
		await _real_esc(ctx)
		presses += 1
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.NONE and presses <= 2,
			"real Esc ends the armed fillet within two presses (%d)" % presses)


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
	await _push_key(edit.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	# WP3: StripRadius == panel after Enter applies the armed radius (10, then 1).
	# Assert here, not mid-type: SpinBox.value and the panel still hold the
	# previous number until Enter.
	var applied := spin.value
	if is_equal_approx(applied, 10.0) or is_equal_approx(applied, 1.0):
		print("  B13.8 Fillet radius %s" % _radius_digits(applied))
		_assert_strip_equals_panel(ctx, applied, _radius_digits(applied))
	# A refused radius re-arms the same edges. Esc cancels that pick so the
	# next Fillet click does not immediately re-commit leftover edges.
	if str(ctx.view.doc.last_graph_error()) != "":
		await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
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


func _recovery_open_profile_then_new(ctx: FilmContext) -> void:
	print("  recovery Exit: _x11_click_screen, no yield between down and up")
	await _recovery_ground_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "recovery ground sketch is open")
	await _zoom(ctx, Vector3(20, 15, 0), 80.0)
	await _recovery_select_tool(ctx, "Rectangle")
	await _recovery_click_uv(ctx, Vector2(0, 0), "Recovery rect A")
	await _recovery_click_uv(ctx, Vector2(40, 30), "Recovery rect B")
	await process_frame
	var n_lines := _count_real(sm, "line")
	check(n_lines >= 4, "recovery rectangle has four edges (got %d)" % n_lines)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(chrome != null and chrome.visible, "recovery finish bar is visible")
	var ex_btn: Button = chrome.extrude_button()
	check(ex_btn != null and ex_btn.is_visible_in_tree(), "recovery Extrude is visible")
	await _x11_click(ex_btn)
	await process_frame
	await process_frame
	await process_frame
	check(not ctx.main.sketch_mode.active, "recovery Extrude left sketch mode")
	check(ctx.view.doc.body_ids().size() >= 1, "recovery extrude created a body")
	var sketch_fid := _sketch_feature_id(ctx)
	check(sketch_fid != "", "recovery sketch is on the timeline")
	await _show_timeline(ctx)
	var row := _row_name_button(ctx.main.timeline, sketch_fid)
	check(row != null and row.is_visible_in_tree(), "recovery sketch row is visible")
	if row != null:
		await _x11_double_click(row)
		await process_frame
		await process_frame
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "timeline double-click reopened the recovery sketch")
	await _zoom(ctx, Vector3(20, 15, 0), 80.0)
	await _recovery_select_tool(ctx, "Select")
	var edge_mids: Array[Vector2] = _line_mids(sm)
	check(not edge_mids.is_empty(), "reopened recovery sketch has an edge")
	for mid in edge_mids:
		await _zoom(ctx, sm.to_model(mid), 50.0)
		await _recovery_click_uv(ctx, mid, "Select recovery edge")
		await process_frame
		if sm.selected.size() >= 1:
			break
	check(sm.selected.size() >= 1, "one recovery edge is selected (got %d)" % sm.selected.size())
	var before_n: int = sm.sketch.entity_ids().size() if sm.sketch != null else 0
	await _recovery_press_delete(ctx)
	await process_frame
	var after_n: int = sm.sketch.entity_ids().size() if sm.sketch != null else 0
	check(after_n < before_n, "Delete removed the selected recovery edge")
	_status_log.clear()
	await _recovery_click_exit(ctx)
	sm = ctx.main.sketch_mode
	var status_text := str(ctx.main.status_label.text)
	print("  recovery Exit status: %s" % status_text)
	check(not sm.active, "Exit Sketch after open profile is not active")
	check(not status_text.contains(FAILED_SKETCH),
			"recovery Exit status is not Failed to update sketch (got '%s')" % status_text)
	print("- recovery: File → New, then a ground circle")
	await _file_new(ctx)
	status_text = str(ctx.main.status_label.text)
	check(status_text.contains("New — empty part") or status_text == NEW_SENTENCE,
			"status is the New sentence (got '%s')" % status_text)
	check(not ctx.main.sketch_mode.active, "File → New leaves sketch_mode.active false")
	check(not status_text.contains(FAILED_SKETCH),
			"New status is not Failed to update sketch (got '%s')" % status_text)
	await _recovery_ground_sketch(ctx, Vector3(-40, 40, 0))
	sm = ctx.main.sketch_mode
	check(sm.active, "ground sketch started after File → New")
	var origin3: Vector3 = sm.to_model(Vector2.ZERO)
	await _zoom(ctx, origin3, 80.0)
	await _recovery_select_tool(ctx, "Circle")
	_status_log.clear()
	await _recovery_click_uv(ctx, Vector2(0, 0), "Recovery circle centre")
	await _recovery_click_uv(ctx, Vector2(8, 0), "Recovery circle rim")
	await process_frame
	status_text = str(ctx.main.status_label.text)
	check(status_text.contains("Circle") or _status_has("Circle"),
			"ground circle drawable after New (got '%s')" % status_text)


func _recovery_ground_sketch(ctx: FilmContext, ground := Vector3(22, 18, 0)) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		return
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	await _zoom(ctx, ground, 80.0)
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "Sketch control is visible")
	await _x11_click(sketch_btn)
	await process_frame
	sm = ctx.main.sketch_mode
	if sm != null and sm.active:
		return
	var screen := FilmUI.model_to_screen(ctx, ground)
	check(FilmUI.require_on_screen(ctx, screen, "ground pick"), "ground pick is on screen")
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame


func _recovery_select_tool(ctx: FilmContext, label: String) -> void:
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var b := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(b != null and b.is_visible_in_tree(), "%s tool is visible" % label)
	if b != null:
		await _x11_click(b)
		await process_frame


func _recovery_click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "recovery click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _recovery_click_exit(ctx: FilmContext) -> void:
	var btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	check(btn != null and btn.is_visible_in_tree(), "Exit Sketch button is visible")
	if btn == null:
		return
	var n: Node = btn
	while n != null:
		if n is ScrollContainer:
			(n as ScrollContainer).scroll_vertical = 0
			(n as ScrollContainer).ensure_control_visible(btn)
		n = n.get_parent()
	await process_frame
	await process_frame
	var r: Rect2 = btn.get_global_rect()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400 and (r.size.x < 8.0 or r.position.x < 1.0):
		await process_frame
		r = btn.get_global_rect()
	check(r.size.x > 8.0 and r.position.x > 1.0, "Exit Sketch clickable at %s" % r)
	var vp: Viewport = ctx.main.get_viewport()
	var pos := Vector2(r.position.x + 16.0, r.get_center().y)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null:
		var dim: Control = chrome.find_child("DimLineEdit", true, false) as Control
		if dim != null and dim.is_visible_in_tree():
			var dr: Rect2 = dim.get_global_rect()
			if dr.has_point(pos):
				pos = Vector2(r.position.x + 10.0, r.position.y + 10.0)
				if dr.has_point(pos):
					pos = Vector2(r.end.x - 8.0, r.position.y + 8.0)
	await _x11_click_screen(vp, pos)
	await process_frame
	await process_frame
	await process_frame


func _recovery_press_delete(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = KEY_DELETE
	ev.physical_keycode = KEY_DELETE
	ev.unicode = 0
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.selected.size() > 0:
		var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Delete")
		if chip != null and chip.is_visible_in_tree():
			await _x11_click(chip)


func _x11_double_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos, false)
	await _x11_click_screen(vp, pos, true)


func _sketch_feature_id(ctx: FilmContext) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			return str(f.get("id", ""))
	return ""


func _line_mids(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		out.append(((info["start"] as Vector2) + (info["end"] as Vector2)) * 0.5)
	return out


func _file_new(ctx: FilmContext) -> void:
	var opened: bool = await _click_menu_item(ctx, "File", 0, "File → New")
	check(opened, "File → New item was clicked at its popup rect")
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		if ok != null and ok.is_visible_in_tree():
			await _x11_click_embedded(ok)
		else:
			await FilmUI.click_control(ctx, dlg.get_ok_button(),
					FilmUICues.alert("OK", "Discard and make a new part"))
		await process_frame
	await process_frame


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
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
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


func _export_via_dialog(ctx: FilmContext, name: String, probe_survival: bool = false, bare: bool = false) -> String:
	var path := "/tmp/sx-rung01-%s" % name
	if bare:
		DirAccess.make_dir_recursive_absolute(BARE_EXPORT_DIR)
		path = BARE_EXPORT_DIR.path_join(name)
	if probe_survival:
		await _probe_export_dialog(ctx, path)
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
	if bare:
		print("  export: typed folder into Path field (no Enter), then bare filename %s" % name)
		await _export_bare_via_path_field(dlg, BARE_EXPORT_DIR, name)
	else:
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
	if bare:
		var home := OS.get_environment("HOME").strip_edges()
		var home_file := home.path_join(name)
		check(not _dirs_match(BARE_EXPORT_DIR, home), "bare export directory is not HOME")
		check(not (FileAccess.file_exists(home_file) and not FileAccess.file_exists(path)),
				"bare name did not land only in HOME")
	if dlg.visible:
		dlg.hide()
	return path if FileAccess.file_exists(path) else ""


func _probe_export_dialog(ctx: FilmContext, path: String) -> void:
	print("  File dialog: Cancel once, then WM_CLOSE_REQUEST")
	var opened: bool = await _click_menu_item(ctx, "File", 11, "File → Export 3MF (Cancel)")
	await process_frame
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "Export 3MF opens a FileDialog for Cancel")
	if dlg != null and dlg.visible:
		await _type_export_name(dlg, path)
		var cancel := dlg.get_cancel_button()
		check(cancel != null, "export Cancel button exists")
		if cancel != null:
			await _x11_click_embedded(cancel)
			await process_frame
			await process_frame
		check(ctx.main.is_inside_tree(), "main stays in the tree after Export Cancel")
		print("  note - script continues after Export Cancel")
	opened = await _click_menu_item(ctx, "File", 11, "File → Export 3MF (WM close)")
	await process_frame
	await process_frame
	dlg = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "Export 3MF reopens for WM_CLOSE_REQUEST")
	if dlg != null and dlg.visible:
		ctx.main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		await process_frame
		await process_frame
		check(ctx.main.is_inside_tree(), "main stays in the tree after WM_CLOSE_REQUEST")
		print("  note - script continues after WM_CLOSE_REQUEST")


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


func _dialog_path_edit(dlg: FileDialog) -> LineEdit:
	if dlg == null:
		return null
	var name_edit := _dialog_name_edit(dlg)
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit == null or edit == name_edit:
			continue
		return edit
	return null


func _export_bare_via_path_field(dlg: FileDialog, target_dir: String, name: String) -> void:
	var path_edit := _dialog_path_edit(dlg)
	check(path_edit != null, "Path LineEdit exists (not get_line_edit)")
	if path_edit == null:
		return
	await _x11_click_embedded(path_edit)
	await process_frame
	await _x11_select_all(path_edit.get_viewport())
	await process_frame
	await _x11_type(path_edit.get_viewport(), target_dir)
	await process_frame
	var typed_dir := str(path_edit.text).strip_edges()
	check(_dirs_match(typed_dir, target_dir),
			"Path field shows typed directory %s (got %s)" % [target_dir, typed_dir])
	check(not _dirs_match(str(dlg.current_dir), target_dir),
			"current_dir is still not the typed folder (got %s)" % dlg.current_dir)
	print("  path field before OK: %s  current_dir: %s" % [typed_dir, dlg.current_dir])
	var name_edit := _dialog_name_edit(dlg)
	check(name_edit != null, "filename LineEdit exists")
	if name_edit == null:
		return
	await _x11_click_embedded(name_edit)
	await process_frame
	await _x11_select_all(name_edit.get_viewport())
	await process_frame
	await _x11_type(name_edit.get_viewport(), name)
	await process_frame


func _type_export_name(dlg: FileDialog, path: String) -> void:
	var edit := _dialog_name_edit(dlg)
	check(edit != null, "Export 3MF name LineEdit exists")
	if edit == null:
		return
	await _x11_click_embedded(edit)
	await process_frame
	await _x11_type(edit.get_viewport(), path)
	await process_frame


func _norm_dir(p: String) -> String:
	return p.replace("\\", "/").trim_suffix("/")


func _dirs_match(a: String, b: String) -> bool:
	return _norm_dir(a) == _norm_dir(b)


func _dialog_dir(dlg: FileDialog) -> String:
	return _norm_dir(str(dlg.current_dir))


func _find_dir_up(dlg: FileDialog) -> Button:
	for c in dlg.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		var tip := str(b.tooltip_text).to_lower()
		var txt := str(b.text).to_lower()
		if tip.find("parent") >= 0 or txt == ".." or tip.find("up") >= 0:
			return b
	return null


func _list_dialog_names(dlg: FileDialog) -> PackedStringArray:
	var names := PackedStringArray()
	for c in dlg.find_children("*", "ItemList", true, false):
		var lst := c as ItemList
		if lst == null or not lst.is_visible_in_tree():
			continue
		for i in lst.item_count:
			names.append(lst.get_item_text(i))
	for c in dlg.find_children("*", "Tree", true, false):
		var tree := c as Tree
		if tree == null or not tree.is_visible_in_tree():
			continue
		var item := tree.get_root()
		if item == null:
			continue
		item = item.get_next_in_tree()
		while item != null:
			names.append(item.get_text(0))
			item = item.get_next_in_tree()
	return names


func _itemlist_vscroll(lst: ItemList) -> VScrollBar:
	for c in lst.find_children("*", "VScrollBar", true, false):
		var sb := c as VScrollBar
		if sb != null and sb.is_visible_in_tree():
			return sb
	return null


func _wheel_list(lst: Control, down: bool) -> void:
	var pos := lst.size * 0.5
	if lst.has_method("get_screen_position"):
		pos = lst.get_screen_position() + lst.size * 0.5
	var vp := root.get_viewport()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventMouseButton
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _click_dialog_row(dlg: FileDialog, needle: String) -> bool:
	var want := needle.to_lower()
	for c in dlg.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		if str(b.text).to_lower() == want:
			await _x11_click_embedded(b)
			await process_frame
			await process_frame
			return true
	for c in dlg.find_children("*", "ItemList", true, false):
		var lst := c as ItemList
		if lst == null or not lst.is_visible_in_tree():
			continue
		for i in lst.item_count:
			var text := lst.get_item_text(i)
			if text.to_lower() != want and not text.to_lower().ends_with("/" + want):
				continue
			lst.select(i)
			if lst.has_method("ensure_current_is_visible"):
				lst.ensure_current_is_visible()
			await process_frame
			await process_frame
			var sb := _itemlist_vscroll(lst)
			var rect: Rect2 = lst.get_item_rect(i)
			var center := rect.position + rect.size * 0.5
			if sb != null:
				center.y -= sb.value
			if center.y < 2.0 or center.y > lst.size.y - 2.0:
				for _w in 24:
					rect = lst.get_item_rect(i)
					center = rect.position + rect.size * 0.5
					if sb != null:
						center.y = rect.position.y + rect.size.y * 0.5 - sb.value
					if center.y >= 4.0 and center.y <= lst.size.y - 4.0:
						break
					await _wheel_list(lst, center.y > lst.size.y * 0.5)
					if sb != null:
						sb = _itemlist_vscroll(lst)
			await _x11_click_embedded_at(lst, center)
			await process_frame
			await _x11_click_embedded_at(lst, center, true)
			await process_frame
			await process_frame
			return true
	for c in dlg.find_children("*", "Tree", true, false):
		var tree := c as Tree
		if tree == null or not tree.is_visible_in_tree():
			continue
		var item := tree.get_root()
		if item == null:
			continue
		item = item.get_next_in_tree()
		while item != null:
			var text := item.get_text(0)
			if text.to_lower() == want or text.to_lower().ends_with("/" + want):
				tree.scroll_to_item(item)
				await process_frame
				var area: Rect2 = tree.get_item_area_rect(item)
				var local := area.position + area.size * 0.5
				await _x11_click_embedded_at(tree, local)
				await process_frame
				await _x11_click_embedded_at(tree, local, true)
				await process_frame
				await process_frame
				return true
			item = item.get_next_in_tree()
	return false


func _click_into_export_dir(dlg: FileDialog, target_dir: String) -> bool:
	var target := _norm_dir(target_dir)
	var folder := target.get_file()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		var here := _dialog_dir(dlg)
		if _dirs_match(here, target):
			return true
		if _dirs_match(here, "/tmp") or _dirs_match(here, target.get_base_dir()):
			if await _click_dialog_row(dlg, folder):
				await process_frame
				await process_frame
				continue
		elif _dirs_match(here, "/") or here == "":
			if await _click_dialog_row(dlg, "tmp"):
				await process_frame
				await process_frame
				continue
		elif here.begins_with(target + "/"):
			var up := _find_dir_up(dlg)
			if up != null:
				await _x11_click_embedded(up)
				await process_frame
				await process_frame
				continue
		else:
			if await _click_dialog_row(dlg, "tmp"):
				await process_frame
				await process_frame
				if _dirs_match(_dialog_dir(dlg), "/tmp") or _dirs_match(_dialog_dir(dlg), target):
					continue
			var up_btn := _find_dir_up(dlg)
			if up_btn != null:
				await _x11_click_embedded(up_btn)
				await process_frame
				await process_frame
				continue
		break
	check(false, "clicked into %s (now %s, rows %s)" % [
			target, _dialog_dir(dlg), ", ".join(_list_dialog_names(dlg))])
	return _dirs_match(_dialog_dir(dlg), target)


func _file_button(main) -> MenuButton:
	return _menu_button(main, "File")


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
	await _x11_click_screen(root.get_viewport(), screen)
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


func _pointer_click_at(vp: Viewport, pos: Vector2) -> void:
	await _push_mouse(vp, pos, MOUSE_BUTTON_LEFT, true)
	await _push_mouse(vp, pos, MOUSE_BUTTON_LEFT, false)


func _push_mouse(vp: Viewport, pos: Vector2, button: MouseButton, pressed: bool) -> void:
	if vp == null:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	if pressed and button == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(ev)
	await process_frame


func _keycode_for_char(ch: String) -> Key:
	var c := ch.unicode_at(0)
	if ch == "/":
		return KEY_SLASH
	if ch == "\\":
		return KEY_BACKSLASH
	if ch == "-":
		return KEY_MINUS
	if ch == "_":
		return KEY_UNDERSCORE
	if ch == ".":
		return KEY_PERIOD
	if c >= 48 and c <= 57:
		return (KEY_0 + (c - 48)) as Key
	if c >= 97 and c <= 122:
		return (KEY_A + (c - 97)) as Key
	if c >= 65 and c <= 90:
		return (KEY_A + (c - 65)) as Key
	return KEY_NONE


func _release_gui_focus(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null and chrome.has_method("release_dim_focus"):
		chrome.release_dim_focus()
	var vp: Viewport = ctx.main.get_viewport()
	var focus: Control = vp.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	await process_frame


func _dim_edit(ctx: FilmContext) -> LineEdit:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null:
		return null
	var named: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if named != null:
		return named
	if chrome._dim_spin == null:
		return null
	return chrome._dim_spin.get_line_edit()


func _spin_digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := str(edit.text).strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	return text.strip_edges()


func _distance_dim_index(sm: SketchMode) -> int:
	for i in sm.dimensions.size():
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != "distance":
			continue
		var ids: Array = dim.get("ids", [])
		if ids.size() >= 2:
			return i
	return -1


func _hud_w_edit(ix: ViewportInteraction) -> LineEdit:
	if ix == null or ix.transform_hud == null:
		return null
	var spin: SpinBox = ix.transform_hud._size_w
	if spin == null:
		return null
	return spin.get_line_edit()


func _type_hex_af_digits(ctx: FilmContext, sm: SketchMode, cam: Camera3D) -> void:
	check(sm.has_single_dof_preview(), "hex preview is active before typing 20")
	var dim := _dim_edit(ctx)
	check(dim != null, "dim LineEdit exists for hex AF")
	await _release_gui_focus(ctx)
	check(dim == null or not dim.has_focus(), "dim blank is not focused before KEY_2")
	var basis0: Basis = cam.global_basis
	var vp: Viewport = ctx.main.get_viewport()
	await _push_key(vp, KEY_2, 50)
	await _push_key(vp, KEY_0, 48)
	await process_frame
	var text := "" if dim == null else str(dim.text)
	check(text.contains("20"), "dim blank contains 20 after KEY_2 KEY_0 (got '%s')" % text)
	check(cam.global_basis.is_equal_approx(basis0),
			"camera basis unchanged after KEY_2 KEY_0")
	await _push_key(vp, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _assert_polygon_chips_clear(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var finish: Control = chrome.find_child("FinishBar", true, false)
	var variant: Control = chrome.find_child("VariantBar", true, false)
	check(finish != null and variant != null, "finish bar and polygon variant chips exist")
	if finish == null or variant == null:
		return
	check(finish.visible and variant.visible, "finish bar and polygon chips are visible before nut extrude")
	var fr := finish.get_global_rect()
	var vr := variant.get_global_rect()
	check(not fr.intersects(vr),
			"finish bar and polygon chips do not intersect at 1280×800 (finish %s variant %s)" % [
				str(fr), str(vr)])


func _empty_sketch_exit(ctx: FilmContext) -> void:
	print("- empty sketch Exit Sketch confirms")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "empty new sketch is active")
	if sm == null or not sm.active:
		return
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	check(exit_btn != null and exit_btn.is_visible_in_tree(), "Exit Sketch button is visible")
	if exit_btn == null:
		return
	await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
	await process_frame
	await process_frame
	var dlg: ConfirmationDialog = ctx.main._empty_sketch_dialog
	if dlg == null or not dlg.visible:
		for c in ctx.main.find_children("*", "ConfirmationDialog", true, false):
			var found := c as ConfirmationDialog
			if found != null and found.visible:
				dlg = found
				break
	check(dlg != null and dlg.visible, "empty Exit Sketch shows a confirm dialog")
	check(sm.active, "sketch stays active until confirm")
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		check(ok != null and ok.is_visible_in_tree(), "empty-sketch confirm control is visible")
		if ok != null:
			await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Confirm discard empty sketch"))
			await process_frame
			await process_frame
	check(not sm.active, "confirm turns sketch mode off")
	var status := str(ctx.main.status_label.text)
	check(status.contains("Empty sketch discarded") or status.contains("nothing was drawn"),
			"empty Exit Sketch status is explanatory (got %s)" % status)


func _esc_box_then_file_menu(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
	if ctx.view.selected_body != "":
		ctx.view.clear_selection()
		if ctx.main.has_method("_update_left_rail"):
			ctx.main._update_left_rail()
		await process_frame
	var box := FilmUI.find_palette_button(ctx.main, "box")
	check(box != null and box.is_visible_in_tree(), "Box palette button is visible for Esc")
	if box == null:
		return
	await FilmUI.click_control(ctx, box, FilmUICues.place_primitive("box"))
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._place_kind == "box", "palette Box armed place")
	var center := ix._screen_center()
	await _aim_pointer(ctx, center)
	await _pointer_click(ctx, center, false)
	await process_frame
	await process_frame
	check(ctx.view.selected_body != "", "placed box is selected")
	var w_edit := _hud_w_edit(ix)
	check(w_edit != null and w_edit.is_visible_in_tree(), "HUD W LineEdit is visible")
	if w_edit != null:
		await _click_control(w_edit)
		await process_frame
	var vp: Viewport = ctx.main.get_viewport()
	await _push_key(vp, KEY_ESCAPE, 0)
	await process_frame
	check(ctx.view.selected_body == "", "one Esc from HUD W cleared selected_body")
	check(ix.triball == null or (not ix.triball.active and not ix.triball.visible),
			"TriBall is inactive after HUD Esc")
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame
	await FilmUI.click_control(ctx, box, FilmUICues.place_primitive("box"))
	await process_frame
	check(ix._place_kind == "box", "palette Box armed place for File menu Esc")
	await _aim_pointer(ctx, center)
	await _pointer_click(ctx, center, false)
	await process_frame
	await process_frame
	check(ctx.view.selected_body != "", "box is selected again before File menu Esc")
	var file_btn := _menu_button(ctx.main, "File")
	check(file_btn != null, "File menu button exists for Esc")
	if file_btn == null:
		return
	await _click_control(file_btn)
	await process_frame
	await process_frame
	var popup: PopupMenu = file_btn.get_popup()
	var t_menu := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t_menu < 450:
		await process_frame
	check(popup != null and popup.visible, "File menu is open from a click")
	var esc_vp: Viewport = popup if popup != null else vp
	await _push_key(esc_vp, KEY_ESCAPE, 0)
	await process_frame
	if popup != null and popup.visible:
		# Headless embed: DisplayServer never focuses the popup, so the same
		# Esc is delivered on window_input (leftover 4 / WP4).
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		esc.echo = false
		popup.window_input.emit(esc)
		await process_frame
	check(popup == null or not popup.visible, "one Esc hides the File menu")
	check(ctx.view.selected_body == "", "one Esc from File menu clears the selection")


func _assert_contours_stay_on(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var n := 0
	if sm.sketch != null and sm.sketch.has_method("contour_count"):
		n = int(sm.sketch.contour_count())
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var chips: Array[CheckButton] = []
	var off := 0
	if chrome != null:
		for c in chrome.find_children("*", "CheckButton", true, false):
			var cb := c as CheckButton
			if cb != null and cb.visible and str(cb.text).is_valid_int():
				chips.append(cb)
				if not cb.button_pressed:
					off += 1
	check(n >= 1, "blank has a contour (count %d)" % n)
	# Chrome hides the bar when there is only one region. Multiple regions
	# still show numbered chips, all on (select every contour).
	if n > 1:
		check(chips.size() >= 1, "contour chips exist (count %d, chips %d)" % [n, chips.size()])
	check(off == 0, "contour chips stay on (%d off)" % off)


func _sketch_on_top(ctx: FilmContext, body: String, top: String, z_top: float, verify := true) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var host := Vector3(SHAFT_PICK_X, 0.0, z_top)
	await _view_key(ctx, KEY_3)
	await _push_key(vp, KEY_ESCAPE, 0)
	var screen := FilmUI.model_to_screen(ctx, host)
	if verify:
		check(FilmUI.require_on_screen(ctx, screen, "top face pick"), "top face pick is on screen")
	await _aim_pointer(ctx, screen)
	await _x11_click_screen(vp, screen)
	await process_frame
	if verify:
		check(not ctx.main.sketch_mode.active, "first top-face click does not reopen a sketch")
		check(ctx.view.selected_body == body, "first top-face click selects the body")
	await _x11_click_screen(vp, screen)
	await process_frame
	if verify:
		check(not ctx.main.sketch_mode.active, "second top-face click does not reopen a sketch")
		check(ctx.view.selected_face == top, "second top-face click selects the top face")
	var strip: Button = ctx.main.interaction._strip_sketch
	if verify:
		check(strip.is_visible_in_tree(), "selection strip offers Sketch")
	await FilmUI.click_control(ctx, strip, FilmUICues.toolbar_sketch())
	await process_frame
	await process_frame


func _ground_sketch(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "sketch session is open")


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
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
	else:
		cam.sketch_orientation_locked = true
		cam.yaw = 0.0
		cam.pitch = deg_to_rad(89.0)
		cam._look_at_content = true
		if ms != null:
			var up_w: Vector3 = ms.global_transform.basis * Vector3(0, 1, 0)
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
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


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom(ctx, sm.to_model(uv), size_mm)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen, false)


func _x11_click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _aim_pointer(ctx, screen)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _click_model(ctx: FilmContext, pt: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, pt)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen, false)
	await process_frame


func _right_click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _aim_pointer(ctx, screen)
	var vp: Viewport = ctx.main.get_viewport()
	await _push_mouse(vp, screen, MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(vp, screen, MOUSE_BUTTON_RIGHT, false)


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _aim_pointer(ctx, screen)


func _shaft_lines_via_chip(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	check(circs.size() == 2, "Shaft Lines needs two circles (got %d)" % circs.size())
	if circs.size() != 2:
		return
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _x11_click_uv(ctx, Vector2(100.0, 80.0), "Clear the selection on empty canvas")
	await process_frame
	check(sm.selected.is_empty(), "a click on empty canvas clears the sketch selection (got %d)" % sm.selected.size())
	for c in circs:
		var top: Vector2 = (c["center"] as Vector2) + Vector2(0.0, float(c["radius"]))
		await _x11_click_uv(ctx, top, "Select circle edge")
		await process_frame
	check(sm.selected.size() == 2, "two circle-edge clicks select both circles (got %d)" % sm.selected.size())
	_assert_chip_row_clear_of_rail(ctx)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "the Shaft Lines chip is visible after selecting both circles")
	if chip == null:
		return
	_status_log.clear()
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Shaft Lines"))
	await process_frame
	check(_status_has("Shaft lines: 2 added"), "status reports 2 shaft lines (got %s)" % ctx.main.status_label.text)
	print("  B13.11 Measure marks (Shaft Lines)")
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	check(mo == null or not mo.has_anchor(),
			"B13.11 after Shaft Lines measure_overlay.has_anchor() is false")


func _assert_shaft_lines_both_sides(sm: SketchMode) -> void:
	var mids: Array[float] = []
	if sm.sketch == null:
		check(false, "shaft lines exist before extrude")
		return
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var mid: Vector2 = ((info["start"] as Vector2) + (info["end"] as Vector2)) * 0.5
		mids.append(mid.y)
	check(mids.size() >= 2, "blank has two shaft lines (got %d)" % mids.size())
	if mids.size() < 2:
		return
	mids.sort()
	check(mids[0] < -5.0 and mids[mids.size() - 1] > 5.0,
			"shaft lines sit on both sides of the axis (%.3f .. %.3f)" % [
				mids[0], mids[mids.size() - 1]])


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String, second_click: bool) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, center, "Circle centre")
	await _hover_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text, second_click)


func _place_head_right_half(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var ix: ViewportInteraction = ctx.main.interaction
	var canvas := ix.get_global_rect()
	var screen := Vector2(maxf(641.0, canvas.position.x + canvas.size.x * 0.72), 400.0)
	if screen.x > canvas.end.x - 8.0:
		screen.x = canvas.position.x + canvas.size.x * 0.65
	check(screen.x > 640.0, "right-half click has screen x > 640 (got %.1f)" % screen.x)
	check(FilmUI.require_on_screen(ctx, screen, "right-half head"),
			"right-half head click is on screen")
	var vp: Viewport = ctx.main.get_viewport()
	var aim := InputEventMouseMotion.new()
	aim.position = screen
	aim.global_position = screen
	vp.push_input(aim)
	await process_frame
	print("  right-half head click: screen (%.1f, %.1f)" % [screen.x, screen.y])
	await _x11_click_screen(vp, screen)
	await process_frame
	await process_frame
	var hover_uv := HEAD
	if sm._tool_points.size() >= 1:
		hover_uv = sm._tool_points[0]
	await _hover_uv(ctx, hover_uv + Vector2(6, 0))
	await _type_dim(ctx, "22.5", true)
	var head_id := ""
	var head_uv := Vector2.ZERO
	var head_model := Vector3.ZERO
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var c: Vector2 = info["center"]
		if c.length() > 1.0:
			head_id = str(id)
			head_uv = c
			head_model = sm.to_model(head_uv)
	check(head_id != "", "right-half click committed a head circle")
	print("  measure: screen X=%.1f Y=%.1f → sketch UV (%.3f, %.3f) → model X=%.3f" % [
		screen.x, screen.y, head_uv.x, head_uv.y, head_model.x])
	check(head_model.x > 0.0,
			"right-half circle model X is positive (got %.3f)" % head_model.x)


func _smart_dim_centres(ctx: FilmContext, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	check(circs.size() == 2, "Smart Dimension needs two circles (got %d)" % circs.size())
	if circs.size() != 2:
		return
	var c1: Vector2 = circs[0]["center"]
	var c2: Vector2 = circs[1]["center"]
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _press_rail_label(ctx, "Smart Dim")
	await _zoom_uv(ctx, c1, 50.0)
	var s1 := FilmUI.model_to_screen(ctx, sm.to_model(c1))
	check(FilmUI.require_on_screen(ctx, s1, "Smart Dimension first centre"),
			"first centre is on screen")
	print("  Smart Dimension: _x11_click_screen first centre, no label click")
	await _x11_click_screen(ctx.main.get_viewport(), s1)
	await process_frame
	check(_status_has("Smart Dim: first pick set"), "the first centre pick says what to click next")
	await _zoom_uv(ctx, c2, 50.0)
	var s2 := FilmUI.model_to_screen(ctx, sm.to_model(c2))
	check(FilmUI.require_on_screen(ctx, s2, "Smart Dimension second centre"),
			"second centre is on screen")
	print("  Smart Dimension: _x11_click_screen second centre; popup must open without a label click")
	await _x11_click_screen(ctx.main.get_viewport(), s2)
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"dimension popup is visible after the second centre click, before any label click")
	print("  popup visible after second centre click (no label click)")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	var line: LineEdit = ix._dim_edit_line
	check(line != null, "popup line edit exists")
	await _x11_click(line)
	await _x11_type(line.get_viewport(), text)
	await _x11_enter(line.get_viewport())
	await process_frame
	await process_frame


func _draw_centre_rect(ctx: FilmContext, center: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	print("  B13.2 Jaw click 2 twice")
	var jaw := await _press_rail_label(ctx, "Jaw")
	check(jaw != null and jaw.is_visible_in_tree(), "the Jaw button is on the sketch rail")
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
			"Jaw selects Rectangle, Center Three Point (got tool %d variant %s)" % [int(sm.tool), sm.tool_variant])
	var jaw_chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	check(jaw_chip != null and jaw_chip.button_pressed,
			"the Center Three Point chip is highlighted after Jaw")
	var along := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var across := Vector2(-along.y, along.x)
	var before_n: int = sm.sketch.entity_ids().size()
	await _click_uv(ctx, center, "Jaw click 1 centre")
	await process_frame
	await _click_uv(ctx, center + along * 30.0, "Jaw click 2 long side")
	await process_frame
	var after2 := str(ctx.main.status_label.text)
	check(after2.contains("click 3") or after2 == SketchMode.JAW_AFTER_LONG,
			"B13.2 after click 2 the status names the next step (got `%s`)" % after2)
	await _click_uv(ctx, center + along * 30.0, "Jaw click 2 again")
	await process_frame
	var after_repeat := str(ctx.main.status_label.text)
	check(sm.sketch.entity_ids().size() == before_n,
			"B13.2 repeat click 2 does not commit a zero-width jaw (n=%d was %d)" % [
				sm.sketch.entity_ids().size(), before_n])
	check(after_repeat.contains("zero") or after_repeat == SketchMode.JAW_ZERO_WIDTH,
			"B13.2 status says the repeat did not commit (got `%s`)" % after_repeat)
	await _click_uv(ctx, center + across * 10.0, "Jaw click 3 half width")
	await process_frame
	check(str(ctx.main.status_label.text).begins_with("Jaw committed") or _status_has("Jaw committed"),
			"B13.2 click 3 commits (got `%s`)" % ctx.main.status_label.text)
	print("  B13.5 Tool status")
	for pair in [["Line", "Line"], ["Smart Dim", "Smart Dim"], ["Trim", "Trim"]]:
		await _press_rail_label(ctx, str(pair[0]))
		var st := str(ctx.main.status_label.text)
		check(st.begins_with(str(pair[1])),
				"B13.5 %s status starts with %s (got `%s`)" % [pair[0], pair[1], st])


func _draw_centreline(ctx: FilmContext, center: Vector2, along: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Centerline")
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Construction centreline"))
	var dir := along.normalized()
	await _zoom_uv(ctx, center - dir * 25.0, 70.0)
	await _x11_click_uv(ctx, center - dir * 25.0, "Centreline start")
	await _zoom_uv(ctx, center + dir * 25.0, 70.0)
	await _x11_click_uv(ctx, center + dir * 25.0, "Centreline end")


func _end_centreline_chain(ctx: FilmContext, at_uv: Vector2) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var done: Button = chrome.done_button() if chrome.has_method("done_button") else null
	if done != null and done.is_visible_in_tree():
		print("  end centreline chain: click Done")
		await _x11_click(done)
		await process_frame
		return
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(at_uv))
	print("  end centreline chain: right-click, no yield between down and up")
	await _x11_click_right_screen(ctx.main.get_viewport(), screen)
	await process_frame


## A chrome click leaves gui_get_hovered_control() on that LineEdit. Sketch
## clicks injected through Interaction._input are then dropped. Park the
## pointer on the sketch pixel first so the next click belongs to the canvas.
func _aim_pointer(ctx: FilmContext, screen: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame


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


func _assert_thin_off(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var feature: CheckButton = chrome.find_child("ThinFeature", true, false)
	check(feature != null and not feature.button_pressed, "Thin feature is off")
	check(chrome._thin_spin == null or not chrome._thin_spin.is_visible_in_tree(),
			"thin spin is hidden")


func _press_extrude(ctx: FilmContext, desc: String) -> void:
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Extrude", desc))
	await process_frame
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)


func _x11_click_screen(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
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


func _x11_click_right_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
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


func _x11_click_at(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	await _x11_click_screen(vp, pos, double_click)


## Embedded FileDialog only sees the click on the root viewport, in screen
## space (push_input on the dialog Window does not hit Cancel/OK/name).
## Same-burst X11 sequence as `_x11_click`.
func _x11_click_embedded(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + pos
	await _x11_click_at(root.get_viewport(), pos)


func _x11_click_embedded_at(ctrl: Control, local: Vector2, double_click: bool = false) -> void:
	var pos := local
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + local
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + ctrl.get_global_rect().position + local
		else:
			pos = ctrl.get_global_rect().position + local
	await _x11_click_screen(root.get_viewport(), pos, double_click)


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


## Extra unfocused burst. Nut 7.5 uses `_type_distance` (X11 click), not this.
func _type_unfocused_distance(ctx: FilmContext, digits: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome._extrude_spin.get_line_edit()
	await _release_gui_focus(ctx)
	check(edit == null or not edit.has_focus(), "Distance is not focused before %s" % digits)
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner == null or not (owner is LineEdit or owner is SpinBox),
			"no LineEdit/SpinBox focused before %s (got %s)" % [
				digits, owner.name if owner != null else "none"])
	var vp: Viewport = ctx.main.get_viewport()
	for i in digits.length():
		var ch := digits.unicode_at(i)
		var code := KEY_PERIOD if ch == 46 else ((KEY_0 + (ch - 48)) as Key)
		await _push_key(vp, code, ch)
	await process_frame
	var readout := ""
	var node: Label = chrome.find_child("ExtrudeReadout", true, false)
	if node != null:
		readout = str(node.text)
	check(readout.contains(digits), "readout contains %s (got %s)" % [digits, readout])


func _type_popup(ctx: FilmContext, edit: LineEdit, text: String) -> void:
	check(edit != null, "dimension popup LineEdit exists")
	if edit == null:
		return
	await _x11_click(edit)
	await _x11_type(edit.get_viewport(), text)
	await _x11_enter(edit.get_viewport())
	await process_frame


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		await _push_key(vp, _keycode_for_char(ch), ch.unicode_at(0))


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
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


func _double_click_control(ctx: FilmContext, ctrl: Control) -> void:
	FilmUI.ensure_control_visible(ctrl)
	await process_frame
	var center := ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, false)
	await process_frame
	center = ctrl.get_global_rect().get_center()
	await _pointer_click(ctx, center, true)


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
	await _aim_pointer(ctx, pos)
	await _pointer_click(ctx, pos, false)
	await process_frame
	return btn


func _preview_hex_uvs(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if sm == null or sm._preview_node == null or sm._preview_node.mesh == null:
		return out
	var mesh: Mesh = sm._preview_node.mesh
	if mesh.get_surface_count() < 1:
		return out
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return out
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return out
	var start := maxi(0, verts.size() - 12)
	for i in range(start, verts.size()):
		var d: Vector3 = verts[i] - sm.plane_origin
		var uv := Vector2(d.dot(sm.plane_x), d.dot(sm.plane_y))
		var dup := false
		for p in out:
			if p.distance_to(uv) <= 1e-5:
				dup = true
				break
		if not dup:
			out.append(uv)
	return out


func _preview_circumradius(sm: SketchMode, centre: Vector2) -> float:
	var best := 0.0
	for p in _preview_hex_uvs(sm):
		best = maxf(best, p.distance_to(centre))
	return best


func _assert_chip_row_clear_of_rail(ctx: FilmContext) -> void:
	print("  B13.3 Chip row")
	var rail: Control = ctx.main.sketch_toolbar
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(rail != null and chrome != null, "B13.3 rail and chrome exist")
	if rail == null or chrome == null:
		return
	var bar: Control = chrome._action_bar
	check(bar != null and bar.visible, "B13.3 action bar is visible")
	if bar == null:
		return
	var rail_r: Rect2 = rail.get_global_rect()
	var bar_r: Rect2 = bar.get_global_rect()
	var vp: Rect2 = ctx.main.get_viewport().get_visible_rect()
	check(not bar_r.intersects(rail_r),
			"B13.3 chip row does not overlap the left rail (chip %s rail %s)" % [str(bar_r), str(rail_r)])
	check(vp.has_point(bar_r.end) or vp.encloses(bar_r.grow(-0.5)),
			"B13.3 chip row ends inside the viewport (chip %s vp %s)" % [str(bar_r), str(vp)])


func _assert_both_circles_on_screen(ctx: FilmContext, via: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	check(circs.size() == 2, "B13.10 %s: two circles" % via)
	var vp: Rect2 = ctx.main.get_viewport().get_visible_rect().grow(-4.0)
	var rail: Control = ctx.main.sketch_toolbar
	var rail_r: Rect2 = rail.get_global_rect() if rail != null else Rect2()
	for c in circs:
		var center: Vector2 = c["center"]
		var r := float(c["radius"])
		var dirs: Array[Vector2] = [Vector2(r, 0.0), Vector2(-r, 0.0), Vector2(0.0, r), Vector2(0.0, -r)]
		for d in dirs:
			var uv: Vector2 = center + d
			var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
			var ok: bool = vp.has_point(screen) and not rail_r.has_point(screen)
			check(ok, "B13.10 %s: circle extreme %s on screen at %s" % [via, str(uv), str(screen)])


func _assert_trim_typed_labels(ctx: FilmContext) -> void:
	print("  B13.7 Trim typed values")
	var sm: SketchMode = ctx.main.sketch_mode
	var widths: Array = []
	var angles: Array = []
	var floor_id := str(sm._jaw_floor_id)
	var walls := {}
	for wid in sm._jaw_wall_ids:
		walls[str(wid)] = true
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var t := str(dim.get("type", ""))
		if t == "distance":
			var hit := floor_id != "" and floor_id != "0"
			if hit:
				hit = false
				for id in dim.get("ids", []):
					if str(id) == floor_id:
						hit = true
						break
			if hit or (floor_id == "" and sm._dimension_label_text(dim) == sm._format_dimension(20.0)):
				widths.append(dim)
		elif t == "angle":
			var hit_a := false
			for id in dim.get("ids", []):
				if walls.has(str(id)):
					hit_a = true
					break
			if hit_a:
				angles.append(dim)
			elif walls.is_empty():
				var at := sm._dimension_label_text(dim)
				if at == "45°" or at.begins_with("45"):
					angles.append(dim)
	check(widths.size() == 1, "B13.7 exactly one width label (got %d)" % widths.size())
	check(angles.size() == 1, "B13.7 exactly one angle label (got %d)" % angles.size())
	if not widths.is_empty():
		var wt := sm._dimension_label_text(widths[0])
		check(wt == "20" or wt == sm._format_dimension(20.0),
				"B13.7 width label reads 20 (got `%s`)" % wt)
	if not angles.is_empty():
		var at := sm._dimension_label_text(angles[0])
		check(at == "45°" or at.begins_with("45"),
				"B13.7 angle label reads 45° (got `%s`)" % at)
	var wall := _long_side_angle_deg(sm)
	check(absf(wall - 45.0) <= 0.01, "B13.7 measured wall angle is 45 ± 0.01° (got %.4f)" % wall)


func _assert_strip_equals_panel(ctx: FilmContext, want: float, tag: String) -> void:
	var spin: SpinBox = ctx.main.interaction.find_child("StripRadius", true, false)
	check(spin != null, "B13.8 %s StripRadius exists" % tag)
	if spin == null:
		return
	var panel: float = ctx.main.ops_panel.dressup_radius()
	check(is_equal_approx(spin.value, want) and is_equal_approx(panel, want),
			"B13.8 %s StripRadius equals panel Radius %s (strip %s panel %s)" % [
				tag, str(want), str(spin.value), str(panel)])


func _assert_view_popup_opaque(ctx: FilmContext) -> void:
	print("  B13.13 Popups")
	var hud: ViewHud = ctx.main.view_hud
	check(hud != null, "B13.13 View HUD exists")
	if hud == null:
		return
	var drop: Button = hud.find_child("ViewsDrop", true, false)
	check(drop != null and drop.is_visible_in_tree(), "B13.13 View ▼ is visible")
	if drop == null:
		return
	var pos := drop.get_global_rect().get_center()
	await _aim_pointer(ctx, pos)
	await _pointer_click(ctx, pos, false)
	await process_frame
	await process_frame
	var pop: PopupPanel = hud._views_popup
	check(pop != null and pop.visible, "B13.13 View ▼ popup is visible")
	if pop == null:
		return
	var sb: StyleBox = pop.get_theme_stylebox("panel", "PopupPanel")
	var alpha := 0.0
	if sb is StyleBoxFlat:
		alpha = (sb as StyleBoxFlat).bg_color.a
	check(sb is StyleBoxFlat and is_equal_approx(alpha, 1.0),
			"B13.13 View popup panel is opaque (alpha %.3f)" % alpha)
	if pop.visible:
		pop.hide()
		await process_frame


func _circle_motions_leave_no_marks(ctx: FilmContext) -> void:
	print("  B13.11 Measure marks (Circle over jaw)")
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	await _press_rail_label(ctx, "Circle")
	for k in 10:
		var uv: Vector2 = HEAD + JAW * (2.0 + float(k) * 1.5) + PERP * 4.0
		await _hover_uv(ctx, uv)
		await process_frame
		var marks := 0 if mo == null else mo.marks.size()
		check(mo == null or (not mo.has_anchor() and marks == 0),
				"B13.11 Circle motion %d leaves no measure marks (anchor=%s marks=%d)" % [
					k, str(mo.has_anchor() if mo != null else false), marks])
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)


func _place_hole_circle(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2.ZERO, "Hole centre on the Ø20")
	await _hover_uv(ctx, Vector2(6, 0))
	await _click_uv(ctx, Vector2(6, 0), "Hole radius")
	await process_frame
	var circ := _first_of(sm, "circle")
	check(circ != "", "hole circle exists")
	if circ == "":
		return
	var info: Dictionary = sm.sketch.entity_info(circ)
	var center: Vector2 = info["center"]
	check(center.length() <= 0.5, "hole centre is the Ø20 centre (got %s)" % center)
	var radius := float(info["radius"])
	await _press_rail_label(ctx, "Smart Dim")
	await _click_uv(ctx, center + Vector2(radius, 0.0), "Smart dimension the hole")
	await process_frame
	var di := _dim_index(sm, "diameter")
	check(di >= 0, "hole has a diameter label")
	if di < 0:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _edit_label(ctx, di, "10")
	info = sm.sketch.entity_info(circ)
	var solved := float(info.get("radius", -1.0)) * 2.0
	check(absf(solved - 10.0) <= TOL, "typed diameter 10 (got %.3f)" % solved)


func _edit_rect_labels(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var width_i := _dim_index_near(sm, "distance", 20.0)
	if width_i < 0:
		width_i = _dim_index_near(sm, "distance", 16.0)
	check(width_i >= 0, "jaw width label exists")
	if width_i >= 0:
		await _edit_label(ctx, width_i, "20")
	var ang_i := _dim_index(sm, "angle")
	check(ang_i >= 0, "jaw angle label exists")
	if ang_i >= 0:
		await _edit_label(ctx, ang_i, "45", "last")
	width_i = _dim_index_near(sm, "distance", 20.0)
	ang_i = _dim_index(sm, "angle")
	var width_shown := -1.0
	var ang_shown := -1.0
	if width_i >= 0:
		width_shown = float(sm._dimension_display_value(sm.dimensions[width_i]))
	if ang_i >= 0:
		ang_shown = absf(float(sm._dimension_display_value(sm.dimensions[ang_i])))
	check(absf(width_shown - 20.0) <= TOL, "jaw width label is 20 (got %.3f)" % width_shown)
	check(absf(ang_shown - 45.0) <= TOL, "jaw angle label is 45 (got %.3f)" % ang_shown)
	var orient := _long_side_angle_deg(sm)
	check(absf(orient - 45.0) <= TOL, "jaw long side is 45° (got %.3f)" % orient)
	var wall_dir := Vector2.ZERO
	var floor_dir := Vector2.ZERO
	var wall_len := -1.0
	var floor_len := INF
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		var L := d.length()
		if L > wall_len:
			wall_len = L
			wall_dir = d
		if L < floor_len and L > 0.5:
			floor_len = L
			floor_dir = d
	if wall_dir.length() > 1e-9:
		wall_dir = wall_dir.normalized()
	if floor_dir.length() > 1e-9:
		floor_dir = floor_dir.normalized()
	check(absf(wall_dir.dot(floor_dir)) <= sin(deg_to_rad(0.05)),
			"jaw floor is perpendicular to the wall")


func _edit_label(ctx: FilmContext, index: int, text: String, glyph: String = "first") -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[index])
	check(lp != null, "dimension label has a position")
	if lp == null:
		return
	await _zoom_uv(ctx, lp as Vector2, 50.0)
	var screen := _label_glyph_screen(ctx, index, glyph)
	check(FilmUI.require_on_screen(ctx, screen, "label %s glyph" % glyph),
			"label %s glyph is on screen" % glyph)
	await _aim_pointer(ctx, screen)
	await _pointer_click(ctx, screen, false)
	await process_frame
	await process_frame
	var ix = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"one click on the %s glyph opens the dimension editor" % glyph)
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	await _type_popup(ctx, ix._dim_edit_line, text)


## Screen centre of the first or last drawn glyph of a dimension label (never its centre).
func _label_glyph_screen(ctx: FilmContext, index: int, glyph: String) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: Camera3D = ctx.main.get_viewport().get_camera_3d()
	var dim: Dictionary = sm.dimensions[index]
	var lp: Variant = dim.get("label_pos", null)
	if lp == null:
		lp = sm._dimension_label_pos2(dim)
	var anchor := FilmUI.model_to_screen(ctx, sm.to_model(lp as Vector2))
	var k: float = sm._label_px_scale(cam)
	var rect: Rect2 = sm._dimension_label_rect(dim, anchor, k)
	var text := str(dim.get("label_text", sm._dimension_label_text(dim)))
	var one: Vector2 = sm._dimension_label_size_px(text.substr(0, 1) if glyph == "first" else text.substr(text.length() - 1)) * k
	var x := rect.position.x + one.x * 0.5 if glyph == "first" else rect.end.x - one.x * 0.5
	return Vector2(x, rect.get_center().y)


func _power_trim_shaft_click(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var click_uv := HEAD + JAW * 3.0 + PERP * 8.0
	await _zoom_uv(ctx, click_uv, 90.0)
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(click_uv))
	check(FilmUI.require_on_screen(ctx, screen, "shaft-side Power Trim"),
			"shaft-side Power Trim click is on screen")
	print("  Power Trim: _x11_click_screen on shaft side of offset cutter, no yield between down and up")
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame
	await _x11_click_screen(vp, screen)


func _pick_opposite_face(ctx: FilmContext, bottom: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var opp := chrome.opposite_face_button()
	check(opp != null and opp.is_visible_in_tree(), "Opposite face button is visible")
	if opp == null:
		return
	var vr := opp.get_global_rect()
	var vp_r := chrome.get_viewport().get_visible_rect()
	check(vr.intersects(vp_r) or vp_r.encloses(vr),
			"Opposite face is on screen (btn %s vp %s)" % [str(vr), str(vp_r)])
	await _x11_click(opp)
	await process_frame
	await process_frame
	check(str(chrome.up_to_face_id) == bottom,
			"Opposite face stored the bottom id (got %s want %s)" % [
				chrome.up_to_face_id, bottom])


func _head_centre_from_mesh(mesh: Array) -> Vector3:
	var verts: PackedVector3Array = mesh[0]
	if verts.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	var n := 0
	for v in verts:
		if absf(v.y) > 15.0:
			acc += v
			n += 1
	if n > 0:
		return acc / float(n)
	var mn := verts[0]
	var mx := verts[0]
	for v in verts:
		mn = Vector3(minf(mn.x, v.x), minf(mn.y, v.y), minf(mn.z, v.z))
		mx = Vector3(maxf(mx.x, v.x), maxf(mx.y, v.y), maxf(mx.z, v.z))
	return Vector3(mx.x - 22.5, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5)


func _assert_hex_flats(sm: SketchMode) -> void:
	var ys: Array[float] = []
	var on_x := false
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for p in [info["start"], info["end"]]:
			var v: Vector2 = p
			ys.append(v.y)
			if absf(v.y) <= 0.2 and absf(absf(v.x) - 20.0 / sqrt(3.0)) <= 0.2:
				on_x = true
	if ys.is_empty():
		check(false, "hex vertices")
		return
	ys.sort()
	check(absf(ys[0] + 10.0) <= 0.15 and absf(ys[ys.size() - 1] - 10.0) <= 0.15,
			"flats at y=±10 (%.3f .. %.3f)" % [ys[0], ys[ys.size() - 1]])
	check(on_x, "vertices on ±X")


func _assert_hex_not_pointer_af(sm: SketchMode) -> void:
	var ys: Array[float] = []
	if sm.sketch == null:
		check(false, "hex AF before extrude")
		return
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for p in [info["start"], info["end"]]:
			ys.append((p as Vector2).y)
	if ys.is_empty():
		check(false, "hex AF before extrude has vertices")
		return
	ys.sort()
	var af := ys[ys.size() - 1] - ys[0]
	check(absf(af - 10.4) > 0.3, "hex AF is not the pointer 10.4 before extrude (got %.3f)" % af)


func _first_of(sm: SketchMode, kind: String) -> String:
	if sm.sketch == null:
		return ""
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			return id
	return ""


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			out.append(info)
	out.sort_custom(func(a, b): return float(a["center"].x) < float(b["center"].x))
	return out


func _dim_index(sm: SketchMode, type_name: String) -> int:
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type_name:
			return i
	return -1


func _long_side_angle_deg(sm: SketchMode) -> float:
	var best_len := -1.0
	var best_deg := -1.0
	if sm.sketch == null:
		return best_deg
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		if d.length() > best_len:
			best_len = d.length()
			var deg := absf(rad_to_deg(d.angle()))
			deg = fmod(deg, 180.0)
			if deg > 90.0:
				deg = 180.0 - deg
			best_deg = deg
	return best_deg


func _count_real(sm: SketchMode, kind: String) -> int:
	var n := 0
	if sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n


func _non_datum_construction_ids(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	if sm == null or sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id):
			continue
		if sm._angle_datum_lines.has(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) != "line":
			continue
		out.append(str(id))
	return out


func _offset_construction_distance(sm: SketchMode, p: Vector2) -> float:
	var best := 0.0
	for id in _non_datum_construction_ids(sm):
		var info: Dictionary = sm.sketch.entity_info(id)
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		var ab := b - a
		var len := ab.length()
		var d := p.distance_to(a) if len < 1e-9 else absf((p - a).cross(ab)) / len
		if d > best:
			best = d
	return best


func _count_type(ctx: FilmContext, type: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == type:
			n += 1
	return n


func _dim_index_near(sm: SketchMode, type_name: String, value: float) -> int:
	var best := -1
	var best_d := 1.0
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != type_name:
			continue
		var shown := sm._dimension_display_value(dim)
		var d := absf(shown - value)
		if d < best_d:
			best_d = d
			best = i
	return best


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[0]


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var bb: Dictionary = ctx.view.doc.measure_bbox(f)
		if bb.is_empty():
			continue
		var fext: Vector3 = bb["max"] - bb["min"]
		var span := maxf(fext.x, fext.y)
		if fext.z > 0.5 and fext.z > span * 0.05:
			continue
		var z: float = bb["max"].z if z_sign > 0 else bb["min"].z
		var area := fext.x * fext.y
		var better := false
		if z_sign > 0:
			better = z > best_z + 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		else:
			better = z < best_z - 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		if better:
			best_z = z
			best_area = area
			best = f
	return best


func _extrude_with_end(ctx: FilmContext, end_name: String) -> Dictionary:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("end", "")) == end_name and str(parsed.get("op", "")) == "cut":
			return parsed
	return {}


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
	check(open, "pivot hole open at z=0.5/5/9.5")


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
	check(open, "jaw open through the depth")
	for z in [2.0, 5.0, 8.0]:
		var pa := _first_hit(mesh, h + axis * 10.0 + Vector3(0, 0, z), pv)
		var pb := _first_hit(mesh, h + axis * 10.0 + Vector3(0, 0, z), -pv)
		var g := pa + pb if pa >= 0.0 and pb >= 0.0 else -1.0
		check(g > 0.0 and absf(g - af) <= TOL, "jaw AF at z=%.0f is %.3f (want %.1f)" % [z, g, af])


func _load_mesh(doc: SxDocument, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
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
		var s := origin - a
		var u := s.dot(pvec) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := s.cross(e1)
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
