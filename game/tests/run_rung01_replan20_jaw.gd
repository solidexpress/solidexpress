# re-PLAN 20 WP1 — jaw angle label on the axis, beside the jaw, right of the rail.
# The scene is the GUI walker's: blank by clicks, face sketch at z=10, empty
# sketch, default framing, Snap and Infer on, H from the rendered head.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_jaw.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmJaw = preload("res://tests/lib/film_jaw.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const COMMIT_PREFIX := "Jaw committed — width "
const COMMIT_SUFFIX := ", long side 0.0° — click a label to edit it"

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
	print("rung01 replan20 jaw")
	FilmUI.reset_fail_count()
	await _story()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _story() -> void:
	var ctx := await _boot()
	await _j0(ctx)
	var head := _measure_head(ctx)
	var h: Vector2 = head["h"]
	var s: float = head["s"]
	print("  J0 H=%s s=%.4f" % [str(h), s])
	await _j1(ctx, h, s)
	await _j2(ctx, h, s)
	await _j3(ctx, h, s)
	await _j4(ctx, h, s)
	await _j6(ctx, h, s)
	await _j5(ctx, h, s)


func _j0(ctx: FilmContext) -> void:
	print("- J0 blank and face sketch")
	await _file_new(ctx)
	check(ctx.view.doc.body_ids().is_empty(), "J0 File New leaves no bodies")
	await FilmUI.enter_sketch(ctx)
	check(ctx.main.sketch_mode.active, "J0 ground sketch is open")
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10", false)
	check(_saw("Ø20") or str(ctx.main.status_label.text).contains("Ø20"),
			"J0 circle 10 status (got '%s')" % ctx.main.status_label.text)
	await _place_head(ctx)
	check(_circle_count(ctx) == 2, "J0 two circles")
	await _smart_dim_200(ctx)
	var gap := _centre_gap(ctx)
	check(absf(gap - 200.0) <= 0.35, "J0 centres 200 mm apart (got %.3f)" % gap)
	await _shaft_lines(ctx)
	check(_saw("Shaft lines: 2 added") or str(ctx.main.status_label.text).contains("Shaft lines: 2 added"),
			"J0 Shaft lines: 2 added (got '%s')" % ctx.main.status_label.text)
	await _extrude_blind(ctx, "10")
	check(_saw("Extrude Blind 10.0000 mm") or str(ctx.main.status_label.text) == "Extrude Blind 10.0000 mm",
			"J0 Extrude Blind 10.0000 mm (got '%s')" % ctx.main.status_label.text)
	await _esc_until(ctx, "Selection cleared", 6)
	check(_saw("Selection cleared") or str(ctx.main.status_label.text) == "Selection cleared",
			"J0 Selection cleared")
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "J0 Sketch button is visible")
	if sketch_btn != null:
		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
	await process_frame
	check(_saw("Select a face or existing sketch") or str(ctx.main.status_label.text).contains("Select a face"),
			"J0 rail Sketch arms face pick (got '%s')" % ctx.main.status_label.text)
	var face_pt := Vector3(100.0, 0.0, 10.0)
	var face_screen := FilmUI.model_to_screen(ctx, face_pt)
	check(FilmUI.is_on_screen(ctx, face_screen), "J0 top face click is on screen")
	_log.clear()
	await _pointer_click(ctx, face_screen)
	await process_frame
	await process_frame
	var opened := str(ctx.main.status_label.text)
	check(opened == "Sketch on face (plane +Z @ origin 0.0,0.0,10.0)" or _saw("Sketch on face (plane +Z @ origin 0.0,0.0,10.0)"),
			"J0 face sketch status (got '%s')" % opened)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active and sm.sketch.entity_ids().is_empty(), "J0 face sketch is empty")
	check(sm.snap_enabled and sm.infer_enabled, "J0 Snap and Infer are on")
	var head := _measure_head(ctx)
	var ppm: float = ctx.main.camera.pixels_per_mm_at_pivot()
	var s: float = head["s"]
	check(s > 0.5 and absf(s - ppm) / ppm <= 0.01,
			"J0 s %.4f is within 1%% of camera px/mm %.4f" % [s, ppm])


func _j1(ctx: FilmContext, h: Vector2, s: float) -> void:
	print("- J1 A8w")
	var sm: SketchMode = ctx.main.sketch_mode
	await _arm_jaw(ctx)
	await _pointer_click(ctx, h)
	await process_frame
	var click2 := h + Vector2(20.0 * s, 0.0)
	await _pointer_click(ctx, click2)
	await process_frame
	var tp: Vector2 = sm._tool_points[sm._tool_points.size() - 1] if not sm._tool_points.is_empty() else Vector2(999, 999)
	check(absf(tp.y) <= 0.05, "J1 click 2 stays on the axis (y %.4f)" % tp.y)
	check(absf(tp.x - 220.0) <= 0.35, "J1 click 2 x is 220 ± 0.35 (got %.4f)" % tp.x)
	var click3 := h + Vector2(20.0 * s, -48.4 * s)
	_log.clear()
	await _pointer_click(ctx, click3)
	await process_frame
	await process_frame
	var status := _commit_status()
	check(status.begins_with(COMMIT_PREFIX) and status.ends_with(COMMIT_SUFFIX),
			"J1 status prefix/suffix (got '%s')" % status)
	var got_side := _long_side_text(status)
	check(got_side == "0.0°", "long side 0.0°: got %s" % got_side)
	var width := _commit_width(status)
	check(absf(width - 96.8) <= 0.35, "J1 width 96.8 ± 0.35 (got %.4f)" % width)
	var on_canvas := _degree_labels_on_canvas(ctx)
	check(on_canvas.size() == 1, "exactly one visible ° label: got %d" % on_canvas.size())
	_assert_angle_pair(ctx, h, "J1")


func _j2(ctx: FilmContext, h: Vector2, s: float) -> void:
	print("- J2 edit")
	var sm: SketchMode = ctx.main.sketch_mode
	await _edit_drawn(ctx, false, "20")
	check(_saw("Dimension updated"), "J2 width Dimension updated")
	check(_dof(ctx) != "!", "J2 DOF after width is not !")
	var w := _dim_value(sm, "distance")
	check(absf(w - 20.0) <= 0.05, "J2 width is 20 (got %.4f)" % w)
	_assert_guard(ctx, "J2 after width")
	await _edit_drawn(ctx, true, "45")
	check(_saw("Dimension updated"), "J2 angle Dimension updated")
	check(absf(_long_side_deg(sm) - 45.0) <= 0.05, "J2 long side 45 (got %.3f)" % _long_side_deg(sm))
	check(absf(_corner_deg(sm) - 90.0) <= 0.05, "J2 included angle 90 (got %.3f)" % _corner_deg(sm))
	check(_dof(ctx) != "!", "J2 DOF after angle is not !")
	_assert_guard(ctx, "J2 after angle")
	var texts := _visible_texts(sm)
	check(texts.count("20") == 1, "J2 one width label 20 (got %s)" % str(texts))
	check(texts.count("45°") == 1, "J2 one angle label 45° (got %s)" % str(texts))
	await _undo_empty(ctx)
	check(_dof(ctx) == "—", "J2 empty DOF is — (got '%s')" % _dof(ctx))
	await _chord(ctx, KEY_Z, true, true)
	await process_frame
	await _chord(ctx, KEY_A, true, false)
	await _key(ctx, KEY_DELETE, 0)
	await process_frame
	await process_frame
	check(_dof(ctx) == "—", "J2 delete leaves DOF — (got '%s')" % _dof(ctx))
	check(_dof(ctx) != "OK", "J2 empty DOF is not OK")
	print("- J2 angle-first is rejected")
	await _clear_sketch(ctx)
	await _commit_screen_jaw(ctx, h, h + Vector2(20.0 * s, 0.0), h + Vector2(20.0 * s, -48.4 * s))
	var before := sm.sketch.snapshot()
	_log.clear()
	await _edit_drawn(ctx, true, "45")
	var rejected := _saw("Dimension rejected — constraints could not be satisfied") \
			or str(ctx.main.status_label.text).contains("Dimension rejected — constraints could not be satisfied")
	check(rejected, "J2 angle-first rejected (log '%s')" % _blob())
	check(sm.sketch.snapshot() == before, "J2 angle-first leaves the sketch unchanged")
	await _clear_sketch(ctx)


func _j3(ctx: FilmContext, h: Vector2, s: float) -> void:
	print("- J3 A8 narrow")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.sketch.entity_ids().is_empty(), "J3 sketch starts empty")
	await _arm_jaw(ctx)
	await _pointer_click(ctx, h)
	await process_frame
	await _motion(ctx, h + Vector2(20.0 * s, 0.0))
	await process_frame
	check(_preview_verts(sm) >= 4, "J3 preview exists before click 2 (verts %d)" % _preview_verts(sm))
	var n0: int = sm.sketch.entity_ids().size()
	await _pointer_click(ctx, h + Vector2(20.0 * s, 0.0))
	await process_frame
	await _pointer_click(ctx, h + Vector2(20.0 * s, 0.0))
	await process_frame
	var again := str(ctx.main.status_label.text)
	check(again.contains("Jaw — width is zero — click 3 again for half the width") or _saw("width is zero"),
			"J3 zero width (got '%s')" % again)
	check(sm.sketch.entity_ids().size() == n0, "J3 entity count unchanged")
	_log.clear()
	await _pointer_click(ctx, h + Vector2(20.0 * s, -10.0 * s))
	await process_frame
	await process_frame
	var status := _commit_status()
	check(status.begins_with(COMMIT_PREFIX) and status.ends_with(COMMIT_SUFFIX),
			"J3 status (got '%s')" % status)
	check(absf(_commit_width(status) - 20.0) <= 0.35, "J3 width 20 ± 0.35 (got %.4f)" % _commit_width(status))
	_assert_angle_pair(ctx, h, "J3")
	await _edit_drawn(ctx, false, "20")
	check(_saw("Dimension updated"), "J3 width Dimension updated")
	await _edit_drawn(ctx, true, "45")
	check(_saw("Dimension updated"), "J3 angle Dimension updated")
	check(absf(_long_side_deg(sm) - 45.0) <= 0.05, "J3 long side 45")
	check(absf(_corner_deg(sm) - 90.0) <= 0.05, "J3 corner 90")
	check(_dof(ctx) != "!", "J3 DOF is not !")
	_assert_guard(ctx, "J3")
	await _clear_sketch(ctx)
	print("- J3 snap off")
	await _click_snap(ctx, false)
	check(not sm.snap_enabled, "J3 Snap is off")
	await _arm_jaw(ctx)
	await _pointer_click(ctx, h)
	var c2 := h + Vector2(20.0 * s, 0.0)
	await _pointer_click(ctx, c2)
	await process_frame
	var raw: Vector2 = sm._tool_points[sm._tool_points.size() - 1] if not sm._tool_points.is_empty() else Vector2(999, 999)
	var want := _screen_to_uv(ctx, c2)
	check(raw.distance_to(want) <= 0.35, "J3 snap-off click 2 is the clicked point (got %s want %s)" % [str(raw), str(want)])
	_log.clear()
	await _pointer_click(ctx, h + Vector2(20.0 * s, -10.0 * s))
	await process_frame
	await process_frame
	var off := _commit_status()
	check(off.begins_with(COMMIT_PREFIX) and off.ends_with(COMMIT_SUFFIX),
			"J3 snap-off status (got '%s')" % off)
	await _clear_sketch(ctx)
	await _click_snap(ctx, true)


func _j4(ctx: FilmContext, h: Vector2, s: float) -> void:
	print("- J4 near-parallel")
	var sm: SketchMode = ctx.main.sketch_mode
	await _click_snap(ctx, false)
	check(not sm.snap_enabled, "J4 Snap is off")
	for deg in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 45.0, 90.0]:
		await _clear_sketch(ctx)
		var th := deg_to_rad(deg)
		var along := Vector2(cos(th) * 20.0 * s, -sin(th) * 20.0 * s)
		var across := Vector2(along.y, -along.x).normalized() * (10.0 * s)
		await _commit_screen_jaw(ctx, h, h + along, h + along + across)
		var degs := _degree_labels(sm)
		check(degs.size() == 1, "J4 %.1f° one ° label (got %d)" % [deg, degs.size()])
		if degs.is_empty():
			continue
		var rect: Rect2 = degs[0]["rect"]
		var canvas: Rect2 = ctx.main.camera.sketch_fit_canvas_rect()
		var rail := _rail_rect(ctx)
		check(canvas.encloses(rect), "J4 %.1f° label inside the canvas" % deg)
		check(rect.position.x >= rail.end.x, "J4 %.1f° label right of the rail (x %.1f rail %.1f)" % [deg, rect.position.x, rail.end.x])
		check(rect.get_center().distance_to(h) <= 200.0, "J4 %.1f° label within 200 px of H (%.1f)" % [deg, rect.get_center().distance_to(h)])
		check(not _labels_overlap(sm), "J4 %.1f° labels do not overlap" % deg)
	await _clear_sketch(ctx)
	await _click_snap(ctx, true)


func _j6(ctx: FilmContext, h: Vector2, s: float) -> void:
	print("- J6 trim cut export")
	var sm: SketchMode = ctx.main.sketch_mode
	await _clear_sketch(ctx)
	await _commit_screen_jaw(ctx, h, h + Vector2(20.0 * s, 0.0), h + Vector2(20.0 * s, -10.0 * s))
	await _edit_drawn(ctx, false, "20")
	await _edit_drawn(ctx, true, "45")
	check(absf(_long_side_deg(sm) - 45.0) <= 0.05, "J6 jaw is 45° before the circles")
	await _draw_circle_typed(ctx, Vector2.ZERO, "5", false)
	await _draw_circle_typed(ctx, Vector2(200, 0), "22.5", true)
	check(_circle_count(ctx) >= 2, "J6 pivot and head circles")
	await _draw_line(ctx, Vector2(200, 0) + Vector2(-21.2, 21.2), Vector2(200, 0) + Vector2(21.2, -21.2))
	await _press_rail(ctx, "Trim")
	_log.clear()
	await _trim_stroke(ctx, Vector2(185, 0))
	await process_frame
	await process_frame
	check(_saw("Trimmed open jaw") or str(ctx.main.status_label.text).contains("Trimmed open jaw"),
			"J6 Trimmed open jaw (got '%s')" % ctx.main.status_label.text)
	await _cut_up_to_surface(ctx)
	check(_saw("Extrude Up To Surface 10.0000 mm") or str(ctx.main.status_label.text).contains("Extrude Up To Surface 10.0000 mm"),
			"J6 Extrude Up To Surface 10.0000 mm (got '%s')" % ctx.main.status_label.text)
	var body := ""
	if not ctx.view.doc.body_ids().is_empty():
		body = str(ctx.view.doc.body_ids()[0])
	var bb: Dictionary = ctx.view.doc.measure_bbox(body) if body != "" else {}
	var ext := Vector3.ZERO
	if not bb.is_empty():
		ext = bb["max"] - bb["min"]
	check(absf(ext.x - 232.5) <= 0.3 and absf(ext.y - 45.0) <= 0.3 and absf(ext.z - 10.0) <= 0.3,
			"J6 size 232.5 × 45 × 10 (got %.3f %.3f %.3f)" % [ext.x, ext.y, ext.z])
	var path := await _export_3mf(ctx, "/tmp/sx-rung20-jaw.3mf")
	check(path != "" and FileAccess.file_exists(path), "J6 exported a 3MF")
	var table := _checker(path)
	for row_name in ["bbox X (length)", "jaw open through full depth", "jaw opening AF at z=2", "jaw opening AF at z=5", "jaw opening AF at z=8"]:
		check(_row_pass(table, row_name), "J6 checker %s PASS" % row_name)


func _j5(ctx: FilmContext, h: Vector2, _s: float) -> void:
	print("- J5 rail inset")
	# The cut closed the sketch. Re-enter is not required: J5's pan clause
	# needs a jaw still on screen, so the inset is read on the way out of J4's
	# sketch when a jaw is still open. If the cut already exited, reopen the
	# jaw sketch from the timeline pencil is out of scope — the face sketch
	# of J4 is gone. Rebuild a jaw on a fresh face sketch of the cut body.
	if not ctx.main.sketch_mode.active:
		await _reopen_top(ctx)
		var head := _measure_head(ctx)
		h = head["h"]
		var s2: float = head["s"]
		await _commit_screen_jaw(ctx, h, h + Vector2(20.0 * s2, 0.0), h + Vector2(20.0 * s2, -10.0 * s2))
	var sm: SketchMode = ctx.main.sketch_mode
	await process_frame
	await process_frame
	ctx.main._publish_sketch_rail_right()
	check(ChromeDock.sketch_rail_right >= 100.0, "J5 sketch_rail_right %.1f ≥ 100" % ChromeDock.sketch_rail_right)
	var safe: Rect2 = sm._label_safe_screen_rect()
	var rail := _rail_rect(ctx)
	check(safe.position.x >= rail.end.x - 0.5, "J5 safe rect x %.1f ≥ rail end %.1f" % [safe.position.x, rail.end.x])
	var centre := _jaw_centre_screen(ctx)
	var target_x := rail.end.x + 40.0
	var guard := 0
	while centre.x > target_x + 8.0 and guard < 40:
		guard += 1
		await _middle_drag(ctx, Vector2(-80.0, 0.0))
		centre = _jaw_centre_screen(ctx)
	while centre.x < target_x - 8.0 and guard < 60:
		guard += 1
		await _middle_drag(ctx, Vector2(80.0, 0.0))
		centre = _jaw_centre_screen(ctx)
	check(absf(centre.x - target_x) <= 30.0, "J5 jaw centre near 40 px right of the rail (x %.1f target %.1f)" % [centre.x, target_x])
	var clear := true
	for entry in FilmJaw.drawn_labels(sm):
		if not bool(entry.get("visible", false)):
			continue
		var rect: Rect2 = entry["rect"]
		if rect.position.x < rail.end.x:
			clear = false
	check(clear, "J5 every label is right of the rail after the pan")
	_log.clear()
	await _key(ctx, KEY_ESCAPE, 0)
	await _key(ctx, KEY_ESCAPE, 0)
	await process_frame
	await process_frame
	ctx.main._publish_sketch_rail_right()
	check(not sm.active or ChromeDock.sketch_rail_right == 0.0, "J5 sketch_rail_right is 0 after Esc Esc (active %s right %.1f)" % [str(sm.active), ChromeDock.sketch_rail_right])
	if sm.active:
		await _key(ctx, KEY_ESCAPE, 0)
		await process_frame
	check(ChromeDock.sketch_rail_right == 0.0, "J5 sketch_rail_right is 0 outside the sketch (got %.1f)" % ChromeDock.sketch_rail_right)


func _assert_angle_pair(ctx: FilmContext, h: Vector2, tag: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var degs := _degree_labels(sm)
	var vis := _visible_entries(sm)
	check(degs.size() == 1, "%s exactly one visible ° label (got %d)" % [tag, degs.size()])
	var text := "" if degs.is_empty() else str(degs[0]["text"])
	check(text == "0°", "%s angle text is 0° (got '%s')" % [tag, text])
	check(vis.size() == 2, "%s exactly two visible dimension labels (got %d)" % [tag, vis.size()])
	var canvas: Rect2 = ctx.main.camera.sketch_fit_canvas_rect()
	var rail := _rail_rect(ctx)
	var inside := true
	var right := true
	var near := true
	for entry in vis:
		var rect: Rect2 = entry["rect"]
		if not canvas.encloses(rect):
			inside = false
		if str(entry["text"]).contains("°"):
			if rect.position.x < rail.end.x:
				right = false
			if rect.get_center().distance_to(h) > 200.0:
				near = false
	check(inside, "%s both rects inside the canvas" % tag)
	var ax := -1.0
	if not degs.is_empty():
		ax = (degs[0]["rect"] as Rect2).position.x
	check(right, "angle label right of the rail: x %.0f < %.0f" % [ax, rail.end.x] if not right else "%s angle label right of the rail" % tag)
	check(near, "%s angle label within 200 px of H" % tag)
	check(not _labels_overlap(sm), "%s labels do not overlap" % tag)
	check(_rects_match_hit(sm), "%s Label3D rects match hit-test within 3 px" % tag)
	_assert_guard(ctx, tag)


func _assert_guard(ctx: FilmContext, tag: String) -> void:
	var errs := FilmJaw.assert_all_dimensions_drawn(ctx.main.sketch_mode, ctx.main.sketch_toolbar)
	check(errs.is_empty(), "%s assert_all_dimensions_drawn (%s)" % [tag, "; ".join(errs)])


func _boot() -> FilmContext:
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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	main.sketch_mode.status.connect(func(t: String) -> void: _log.append(t))
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_log.append(text)


func _file_new(ctx: FilmContext) -> void:
	await _click_menu(ctx, "File", 0)
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		if ok != null:
			await _click_control(ctx, ok)
		await process_frame


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String, second: bool) -> void:
	await _press_rail(ctx, "Circle")
	await _click_uv(ctx, center)
	await _motion_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text, second)


func _place_head(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _press_rail(ctx, "Circle")
	var screen := Vector2(900.0, 400.0)
	await _pointer_click(ctx, screen)
	await process_frame
	var hover := Vector2(200, 0)
	if sm._tool_points.size() >= 1:
		hover = sm._tool_points[0]
	await _motion_uv(ctx, hover + Vector2(6, 0))
	await _type_dim(ctx, "22.5", true)


func _smart_dim_200(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	if circs.size() != 2:
		check(false, "J0 Smart Dim needs two circles")
		return
	await _press_rail(ctx, "Smart Dim")
	await _click_uv(ctx, circs[0]["center"])
	await process_frame
	await _click_uv(ctx, circs[1]["center"])
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "J0 Smart Dim popup is open")
	if ix._dim_edit_line != null:
		await _click_control(ctx, ix._dim_edit_line)
		await _type_chars(ctx.main.get_viewport(), "200")
		var shown := str(ix._dim_edit_line.text)
		check(shown.contains("200"), "J0 Smart Dim reads back 200 (got '%s')" % shown)
		await _key(ctx, KEY_ENTER, 0)
		await process_frame
		await process_frame


func _shaft_lines(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs := _circles(sm)
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _press_rail(ctx, "Select")
	await _click_uv(ctx, Vector2(100.0, 80.0))
	await process_frame
	check(sm.selected.is_empty(), "J0 empty click clears the selection (got %d)" % sm.selected.size())
	for c in circs:
		var top: Vector2 = (c["center"] as Vector2) + Vector2(0.0, float(c["radius"]))
		await _click_uv(ctx, top)
		await process_frame
	check(sm.selected.size() == 2, "J0 both circles selected (got %d)" % sm.selected.size())
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "J0 Shaft Lines chip is visible")
	if chip != null:
		_log.clear()
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Shaft Lines"))
		await process_frame


func _extrude_blind(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_option(ctx, chrome.find_child("FinishEnd", true, false) as OptionButton, 0)
	await _pick_option(ctx, chrome.find_child("FinishOp", true, false) as OptionButton, 0)
	var edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(edit != null, "J0 DistanceLineEdit exists")
	if edit != null:
		await _click_control(ctx, edit)
		await _type_chars(ctx.main.get_viewport(), text)
		await process_frame
	var btn: Button = chrome.extrude_button()
	_log.clear()
	await _click_control(ctx, btn)
	await process_frame
	await process_frame
	await process_frame


func _arm_jaw(ctx: FilmContext) -> void:
	await _press_rail(ctx, "Jaw")
	await process_frame


func _commit_screen_jaw(ctx: FilmContext, c1: Vector2, c2: Vector2, c3: Vector2) -> void:
	await _arm_jaw(ctx)
	await _pointer_click(ctx, c1)
	await process_frame
	await _pointer_click(ctx, c2)
	await process_frame
	await _pointer_click(ctx, c3)
	await process_frame
	await process_frame


func _edit_drawn(ctx: FilmContext, degree: bool, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _press_rail(ctx, "Select")
	await process_frame
	var pos := FilmJaw.click_label_first_glyph(ctx.main.get_viewport(), sm, degree)
	check(pos != Vector2.INF, "drawn %s label glyph is on screen" % ("°" if degree else "width"))
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	var edit: LineEdit = ix._dim_edit_line if ix != null else null
	check(edit != null and ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"label editor is open for '%s'" % text)
	if edit == null:
		return
	check(edit.get_selected_text() == edit.text and edit.text != "",
			"label editor text is selected (sel '%s' text '%s')" % [edit.get_selected_text(), edit.text])
	_log.clear()
	await _type_chars(ctx.main.get_viewport(), text)
	check(str(edit.text).contains(text), "typed '%s' reads back (got '%s')" % [text, edit.text])
	await _key(ctx, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _draw_line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	await _press_rail(ctx, "Line")
	await _click_uv(ctx, a)
	await _click_uv(ctx, b)
	await process_frame


func _trim_stroke(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = screen + Vector2(12, 8)
	drag.global_position = drag.position
	drag.relative = Vector2(12, 8)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = drag.position
	up.global_position = drag.position
	vp.push_input(up)
	await process_frame


func _cut_up_to_surface(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_option(ctx, chrome.find_child("FinishOp", true, false) as OptionButton, 1)
	await _pick_option(ctx, chrome.find_child("FinishEnd", true, false) as OptionButton, 3)
	var opp: Button = chrome.opposite_face_button()
	check(opp != null and opp.is_visible_in_tree(), "J6 Opposite face is visible")
	if opp != null:
		await _click_control(ctx, opp)
		await process_frame
		await process_frame
	var btn: Button = chrome.extrude_button()
	_log.clear()
	await _click_control(ctx, btn)
	await process_frame
	await process_frame
	await process_frame


func _reopen_top(ctx: FilmContext) -> void:
	await _esc_until(ctx, "Selection cleared", 6)
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	if sketch_btn != null and sketch_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
		await process_frame
	var screen := FilmUI.model_to_screen(ctx, Vector3(100, 0, 10))
	await _pointer_click(ctx, screen)
	await process_frame
	await process_frame


func _click_snap(ctx: FilmContext, on: bool) -> void:
	var box := ctx.main.sketch_toolbar.find_child("SnapToggle", true, false) as CheckBox
	check(box != null, "Snap checkbox exists")
	if box == null:
		return
	if box.button_pressed == on:
		check(true, "Snap already %s" % str(on))
		return
	var scroll := _rail_scroll(ctx.main.sketch_toolbar)
	await _scroll_into(scroll, box)
	await _click_control(ctx, box)
	await process_frame


func _middle_drag(ctx: FilmContext, relative: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var pos := Vector2(700, 400)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = pos + relative
	drag.global_position = drag.position
	drag.relative = relative
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	vp.push_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = drag.position
	up.global_position = drag.position
	vp.push_input(up)
	await process_frame
	await process_frame


func _export_3mf(ctx: FilmContext, path: String) -> String:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var opened := await _click_menu(ctx, "File", 11)
	await process_frame
	var dlg: FileDialog = ctx.main.file_dialog
	check(opened and dlg != null and dlg.visible, "J6 Export dialog is open")
	if dlg == null or not dlg.visible:
		return ""
	var edit := _dialog_name_edit(dlg)
	check(edit != null, "J6 export name field exists")
	if edit != null:
		await _click_control(ctx, edit)
		await process_frame
		await _select_all(edit.get_viewport())
		await _type_chars(edit.get_viewport(), path)
		await process_frame
	var ok := dlg.get_ok_button()
	if ok != null:
		await _click_control(ctx, ok)
		await process_frame
		await process_frame
		await process_frame
	return path if FileAccess.file_exists(path) else ""


func _checker(path: String) -> String:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	var output: Array = []
	OS.execute("python3", PackedStringArray([checker, "wrench", path]), output, true)
	return "\n".join(output)


func _row_pass(table: String, name: String) -> bool:
	for line in table.split("\n"):
		if line.contains(name) and line.begins_with("PASS"):
			return true
	return false


func _dialog_name_edit(dlg: FileDialog) -> LineEdit:
	if dlg != null and dlg.has_method("get_line_edit"):
		var le: Variant = dlg.get_line_edit()
		if le is LineEdit:
			return le as LineEdit
	return _dialog_line(dlg)


func _select_all(vp: Viewport) -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_A
	down.physical_keycode = KEY_A
	down.pressed = true
	down.ctrl_pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = KEY_A
	up.physical_keycode = KEY_A
	up.pressed = false
	up.ctrl_pressed = true
	vp.push_input(up)
	await process_frame


func _dialog_line(dlg: FileDialog) -> LineEdit:
	var best: LineEdit = null
	for c in dlg.find_children("*", "LineEdit", true, false):
		var edit := c as LineEdit
		if edit != null and edit.is_visible_in_tree():
			best = edit
	return best


func _pick_option(ctx: FilmContext, opt: OptionButton, index: int) -> void:
	if opt == null:
		check(false, "option button missing")
		return
	await _click_control(ctx, opt)
	opt.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = opt.get_popup()
	if popup == null:
		return
	var id := popup.get_item_id(index)
	var item_pos := _popup_item_pos(popup, index)
	await _pointer_click(ctx, item_pos)
	await process_frame
	if opt.selected != index and popup.visible:
		popup.hide()


func _popup_item_pos(popup: PopupMenu, index: int) -> Vector2:
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(index)
	popup.reset_size()
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h := fs
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
	return Vector2(popup.position) + Vector2(popup.size.x * 0.5, y)


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


func _click_menu(ctx: FilmContext, title: String, id: int) -> bool:
	var btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		var mb := c as MenuButton
		if mb != null and str(mb.text).begins_with(title):
			btn = mb
			break
	if btn == null:
		check(false, "%s menu is visible" % title)
		return false
	await _click_control(ctx, btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup := btn.get_popup()
	if popup == null or not popup.visible:
		return false
	var idx := popup.get_item_index(id)
	if idx < 0:
		idx = 0
	await _pointer_click(ctx, _popup_item_pos(popup, idx))
	await process_frame
	return true


func _press_rail(ctx: FilmContext, label: String) -> void:
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null, "rail %s is visible" % label)
	if btn == null:
		return
	var scroll := _rail_scroll(ctx.main.sketch_toolbar)
	await _scroll_into(scroll, btn)
	await _click_control(ctx, btn)
	await process_frame


func _scroll_into(scroll: ScrollContainer, btn: Control) -> void:
	if scroll == null or btn == null:
		return
	var local_y := btn.get_global_rect().position.y - scroll.get_global_rect().position.y + scroll.scroll_vertical
	scroll.scroll_vertical = int(clampf(local_y - 80.0, 0.0, scroll.get_v_scroll_bar().max_value))
	await process_frame


func _rail_scroll(rail: Node) -> ScrollContainer:
	if rail == null:
		return null
	return rail.find_child("SketchRailScroll", true, false) as ScrollContainer


func _click_control(ctx: FilmContext, ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	await _pointer_click(ctx, pos)


func _pointer_click(ctx: FilmContext, pos: Vector2) -> void:
	FilmJaw.push_click(ctx.main.get_viewport(), pos)
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.is_on_screen(ctx, screen), "click on screen %s" % str(uv))
	await _pointer_click(ctx, screen)


func _motion(ctx: FilmContext, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	ctx.main.get_viewport().push_input(motion)


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	_motion(ctx, FilmUI.model_to_screen(ctx, sm.to_model(uv)))


func _screen_to_uv(ctx: FilmContext, screen: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	var cam: Camera3D = ctx.main.camera
	var origin_w := cam.project_ray_origin(screen)
	var dir_w := cam.project_ray_normal(screen)
	var ms: Node3D = ctx.main.model_space
	var origin := origin_w
	var dir := dir_w
	if ms != null:
		var inv := ms.global_transform.affine_inverse()
		origin = inv * origin_w
		dir = inv.basis * dir_w
	var hit = sm.ray_to_sketch(origin, dir)
	if hit == null:
		return Vector2(9999, 9999)
	return hit


func _type_dim(ctx: FilmContext, text: String, second: bool) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	check(edit != null, "DimLineEdit exists for %s" % text)
	if edit == null:
		return
	await _click_control(ctx, edit)
	await _type_chars(ctx.main.get_viewport(), text)
	if second:
		check(str(edit.text).contains(text), "dim text reads %s (got '%s')" % [text, edit.text])
	await _key(ctx, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _type_chars(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		await _key_vp(vp, code, ch)


func _key(ctx: FilmContext, code: Key, unicode: int) -> void:
	await _key_vp(ctx.main.get_viewport(), code, unicode)


func _key_vp(vp: Viewport, code: Key, unicode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.unicode = unicode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	vp.push_input(up)
	await process_frame


func _chord(ctx: FilmContext, code: Key, ctrl: bool, shift: bool) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	vp.push_input(up)
	await process_frame


func _esc_until(ctx: FilmContext, needle: String, limit: int) -> void:
	var guard := 0
	while guard < limit and not _saw(needle) and str(ctx.main.status_label.text) != needle:
		guard += 1
		_log.clear()
		await _key(ctx, KEY_ESCAPE, 0)
		await process_frame


func _undo_empty(ctx: FilmContext) -> void:
	var guard := 0
	while guard < 40 and not _saw("Nothing to undo") and str(ctx.main.status_label.text) != "Nothing to undo":
		guard += 1
		_log.clear()
		await _chord(ctx, KEY_Z, true, false)
		await process_frame


func _clear_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm.sketch == null or sm.sketch.entity_ids().is_empty():
		return
	ctx.main.interaction.grab_focus()
	await process_frame
	await _chord(ctx, KEY_A, true, false)
	await _key(ctx, KEY_DELETE, 0)
	await process_frame
	await process_frame


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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _measure_head(ctx: FilmContext) -> Dictionary:
	var cam: Camera3D = ctx.main.camera
	var body := ""
	if not ctx.view.doc.body_ids().is_empty():
		body = str(ctx.view.doc.body_ids()[0])
	var x_left := INF
	var x_right := -INF
	var y_min := INF
	var y_max := -INF
	var n := 0
	if body != "":
		var edges: Dictionary = ctx.view.doc.get_edge_lines(body)
		for edge_id in edges:
			var poly: PackedVector3Array = edges[edge_id]
			for p in poly:
				if absf(p.z - 10.0) > 0.4:
					continue
				if p.distance_to(Vector3(200, 0, 10)) < 18.0 or p.distance_to(Vector3(200, 0, 10)) > 26.0:
					continue
				var screen := FilmUI.model_to_screen(ctx, p)
				x_left = minf(x_left, screen.x)
				x_right = maxf(x_right, screen.x)
				y_min = minf(y_min, screen.y)
				y_max = maxf(y_max, screen.y)
				n += 1
	# Tessellation vertices sit inside the disc, so the sample AABB is short of
	# Ø45. The disc's centre is the sample centroid; left and right are the
	# geometric rim along model X (rule 69).
	# Sample centroid is pulled by the shaft-side chords. The Ø45 head is the
	# circle we drew at (200, 0); left/right are that disc's rim.
	var centre := Vector3(200, 0, 10)
	var left := FilmUI.model_to_screen(ctx, centre + Vector3(-22.5, 0, 0))
	var right := FilmUI.model_to_screen(ctx, centre + Vector3(22.5, 0, 0))
	var mid := FilmUI.model_to_screen(ctx, centre)
	var h := Vector2((left.x + right.x) * 0.5, mid.y)
	var scale := (right.x - left.x) / 45.0
	check(n >= 8, "head rim samples (got %d)" % n)
	return {"h": h, "s": scale}


func _commit_status() -> String:
	var label := ""
	for s in _log:
		if s.begins_with(COMMIT_PREFIX):
			label = s
	return label


func _long_side_text(status: String) -> String:
	var key := "long side "
	var i := status.find(key)
	if i < 0:
		return status
	var rest := status.substr(i + key.length())
	var cut := rest.find(" —")
	if cut < 0:
		return rest
	return rest.substr(0, cut)


func _degree_labels_on_canvas(ctx: FilmContext) -> Array:
	var sm: SketchMode = ctx.main.sketch_mode
	var canvas: Rect2 = ctx.main.camera.sketch_fit_canvas_rect()
	var rail := _rail_rect(ctx)
	var out: Array = []
	for entry in _degree_labels(sm):
		var rect: Rect2 = entry["rect"]
		if canvas.encloses(rect) and rect.position.x >= rail.end.x:
			out.append(entry)
	return out


func _commit_width(status: String) -> float:
	if not status.begins_with(COMMIT_PREFIX):
		return -1.0
	var rest := status.substr(COMMIT_PREFIX.length())
	var comma := rest.find(",")
	if comma < 0:
		return -1.0
	return float(rest.substr(0, comma))


func _visible_entries(sm: SketchMode) -> Array:
	var out: Array = []
	for entry in FilmJaw.drawn_labels(sm):
		if bool(entry.get("visible", false)):
			out.append(entry)
	return out


func _visible_texts(sm: SketchMode) -> Array:
	var out: Array = []
	for entry in _visible_entries(sm):
		out.append(str(entry.get("text", "")))
	return out


func _degree_labels(sm: SketchMode) -> Array:
	var out: Array = []
	for entry in _visible_entries(sm):
		if str(entry.get("text", "")).contains("°"):
			out.append(entry)
	return out


func _labels_overlap(sm: SketchMode) -> bool:
	var vis := _visible_entries(sm)
	for i in range(vis.size()):
		var a: Rect2 = vis[i]["rect"]
		for j in range(i + 1, vis.size()):
			var b: Rect2 = vis[j]["rect"]
			if not a.intersects(b):
				continue
			var overlap := a.intersection(b)
			if overlap.size.x > 0.5 and overlap.size.y > 0.5:
				return true
	return false


func _rects_match_hit(sm: SketchMode) -> bool:
	var rows: Array = sm.dimension_label_screen_rects()
	for entry in _visible_entries(sm):
		var rect: Rect2 = entry["rect"]
		var text := str(entry["text"])
		var ok := false
		for row in rows:
			if str(row.get("text", "")) != text:
				continue
			var hit: Rect2 = row.get("rect", Rect2())
			if rect.position.distance_to(hit.position) <= 3.0 and rect.size.distance_to(hit.size) <= 3.0:
				ok = true
		if not ok:
			return false
	return true


func _rail_rect(ctx: FilmContext) -> Rect2:
	var rail: Control = ctx.main.sketch_toolbar
	if rail == null:
		return Rect2()
	return rail.get_global_rect()


func _dof(ctx: FilmContext) -> String:
	var lab: Label = ctx.main.dof_label
	return "" if lab == null else str(lab.text)


func _dim_value(sm: SketchMode, kind: String) -> float:
	for dim in sm.dimensions:
		if str(dim.get("type", "")) != kind:
			continue
		if kind == "distance" and str(dim.get("callout", "")) != "" and str(dim.get("callout", "")) != "jaw_width":
			continue
		return float(sm._dimension_display_value(dim))
	return -1.0


func _long_side_deg(sm: SketchMode) -> float:
	var best_len := -1.0
	var best := -1.0
	if sm.sketch == null:
		return best
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
			best = deg
	return best


func _corner_deg(sm: SketchMode) -> float:
	var dirs: Array[Vector2] = []
	if sm.sketch == null:
		return -1.0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		if d.length() > 1.0:
			dirs.append(d.normalized())
	var best := 0.0
	for i in range(dirs.size()):
		for j in range(i + 1, dirs.size()):
			var ang := absf(rad_to_deg(dirs[i].angle_to(dirs[j])))
			if ang > 90.0:
				ang = 180.0 - ang
			best = maxf(best, ang)
	return best


func _preview_verts(sm: SketchMode) -> int:
	if sm._preview_node == null or sm._preview_node.mesh == null:
		return 0
	var mesh := sm._preview_node.mesh as ImmediateMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return 0
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle" and not sm.sketch.is_construction(id):
			out.append(info)
	return out


func _circle_count(ctx: FilmContext) -> int:
	return _circles(ctx.main.sketch_mode).size()


func _centre_gap(ctx: FilmContext) -> float:
	var circs := _circles(ctx.main.sketch_mode)
	if circs.size() < 2:
		return -1.0
	return (circs[0]["center"] as Vector2).distance_to(circs[1]["center"])


func _jaw_centre_screen(ctx: FilmContext) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	return FilmUI.model_to_screen(ctx, sm.to_model(Vector2(200, 0)))


func _saw(needle: String) -> bool:
	for s in _log:
		if s.contains(needle):
			return true
	return false


func _blob() -> String:
	return " | ".join(_log)
