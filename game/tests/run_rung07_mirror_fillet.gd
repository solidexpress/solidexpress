# Rung 7 WP8 — Feature Mirror replays Fillet3 onto the mirrored recess.
# Stub plate + blind cut + R3, then origin Front of Fillet + Cut.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung07_mirror_fillet.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const PipeFixture = preload("res://tests/lib/pipe_fixture.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")

const PLATE_X := 80.0
const PLATE_HALF_Y := 20.0
const PLATE_T := 20.0
const CUT_D := 8.0
const POCKET := Rect2(20.0, -8.0, 40.0, 16.0)


func _init() -> void:
	print("rung07 mirror fillet")
	FilmUI.reset_fail_count()
	var ctx := await SpannerFixture.boot(self, Vector2i(1280, 800))
	listen_status(ctx.main)
	if ctx.main.ops_panel != null and ctx.main.ops_panel.has_signal("status") \
			and not ctx.main.ops_panel.status.is_connected(_on_status):
		ctx.main.ops_panel.status.connect(_on_status)
	status_echo = true
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	await _stub(ctx)
	if failures > 0:
		return
	await _fillet_corners(ctx)
	if failures > 0:
		return
	await _select_body(ctx)
	await _show_timeline(ctx)
	await _mirror(ctx)
	check(ctx.view.doc.body_ids().size() == 1, "one body after fillet mirror")
	var note := str(ctx.main.status_label.text).to_lower()
	check(not note.contains("skipped fillet"), "Fillet3 was not skipped (got '%s')" %
			ctx.main.status_label.text)
	var plus := _hit_z(ctx, Vector3(40, 0, 30), Vector3(0, 0, -1))
	var minus := _hit_z(ctx, Vector3(40, 0, -30), Vector3(0, 0, 1))
	print("  pocket hits z+ %.3f  z- %.3f" % [plus, minus])
	check(absf(plus - 2.0) <= 0.5, "+Z pocket empty (hit z=%.3f)" % plus)
	check(absf(minus + 2.0) <= 0.5, "−Z pocket empty (hit z=%.3f)" % minus)
	var body := SpannerFixture.only_body(ctx)
	var vol := float(ctx.view.doc.measure_mass(body).get("volume", -1.0))
	var plate := PLATE_X * PLATE_HALF_Y * 2.0 * PLATE_T
	var one_pocket := POCKET.size.x * POCKET.size.y * CUT_D
	var two_sharp := plate - 2.0 * one_pocket
	print("  volume %.1f  two-sharp %.1f  one-face %.1f" % [vol, two_sharp, plate - one_pocket])
	check(vol < plate - one_pocket - 1000.0, "second pocket was cut (got %.1f, one-face %.1f)" %
			[vol, plate - one_pocket])
	check(vol > two_sharp + 80.0, "R3 add-back on both faces (got %.1f vs two-sharp %.1f)" %
			[vol, two_sharp])


func _stub(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	_rect(sm, Rect2(0.0, -PLATE_HALF_Y, PLATE_X, PLATE_HALF_Y * 2.0))
	sm.finish_extrude(PLATE_T, "new", "midplane")
	for _i in 12:
		await process_frame
	check(not sm.active, "plate extruded")
	var body := SpannerFixture.only_body(ctx)
	var face := SpannerFixture.face_by_normal(ctx.view, body, Vector3(0, 0, 1), PLATE_T * 0.5)
	check(face != "", "plate +Z face")
	if face == "":
		return
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	sm = ctx.main.sketch_mode
	check(sm.active, "face sketch is active")
	_rect(sm, POCKET)
	sm.finish_extrude(CUT_D, "cut", "blind")
	for _i in 12:
		await process_frame
	check(not sm.active, "cut closed the sketch")
	var plus := _hit_z(ctx, Vector3(40, 0, 30), Vector3(0, 0, -1))
	var minus := _hit_z(ctx, Vector3(40, 0, -30), Vector3(0, 0, 1))
	print("  one-face hits z+ %.3f  z- %.3f" % [plus, minus])
	check(absf(plus - 2.0) <= 0.5, "one-face +Z pocket (hit z=%.3f)" % plus)
	check(absf(minus + 10.0) <= 0.5, "one-face −Z still solid (hit z=%.3f)" % minus)


func _fillet_corners(ctx: FilmContext) -> void:
	var body := SpannerFixture.only_body(ctx)
	var host := ctx.view.feature_of_body(body)
	check(host != "", "feature of the plate")
	var corners := PackedStringArray()
	for p in [Vector2(20, 8), Vector2(60, 8), Vector2(20, -8), Vector2(60, -8)]:
		for eid in SpannerFixture.z_edges_near(ctx.view.doc, body, p, CUT_D, 2.0):
			if not corners.has(eid):
				corners.append(eid)
	check(corners.size() >= 4, "pocket Z-edges (got %d)" % corners.size())
	var fid := ctx.view.doc.graph_add_fillet(host, corners, 3.0)
	check(fid != "", "Fillet R3")
	ctx.view.graph_changed()
	if ctx.main.timeline != null:
		ctx.main.timeline.refresh()
	for _i in 8:
		await process_frame
	check(fid != "", "Fillet R3 applied")


func _mirror(ctx: FilmContext) -> void:
	print("- origin Front of Fillet + Cut")
	await _arm_features(ctx)
	await FilmSteps.click_mirror_datum(ctx, "Front")
	var mf = ctx.main.ops_panel._mirror_features
	check(mf != null and mf.has_plane, "Front datum set the plane")
	if mf != null and mf.has_plane:
		check(mf.plane_point.is_equal_approx(Vector3.ZERO), "plane point is origin")
		check(mf.plane_normal.is_equal_approx(Vector3(0, 0, 1)), "plane normal is +Z")
	await _show_timeline(ctx)
	if ctx.main.timeline != null:
		ctx.main.timeline.refresh()
		await process_frame
	var fillet := _last_row(ctx, "fillet")
	var cut := _last_row(ctx, "extrude")
	check(fillet != null, "fillet timeline row")
	check(cut != null, "cut timeline row")
	if fillet == null or cut == null:
		return
	await _click_row(ctx, fillet, false)
	await _click_row(ctx, cut, true)
	var ok := PipeFixture.find_auto(ctx.main, "mirror:Ok") as Button
	check(ok != null and ok.is_visible_in_tree(), "mirror:Ok is visible")
	if ok == null:
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Mirror OK Fillet+Cut"))
	for _i in 16:
		await process_frame
	check(str(ctx.main.status_label.text).contains("Mirrored"),
			"status names Mirror (got '%s')" % ctx.main.status_label.text)


func _hit_z(ctx: FilmContext, origin: Vector3, dir: Vector3) -> float:
	var hit: Dictionary = ctx.view.pick_info(origin, dir)
	if hit.is_empty() or not (hit.get("point") is Vector3):
		return INF
	return float((hit["point"] as Vector3).z)


func _rect(sm: SketchMode, r: Rect2) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x
	var y1 := r.position.y + r.size.y
	sm.sketch.add_line(x0, y0, x1, y0)
	sm.sketch.add_line(x1, y0, x1, y1)
	sm.sketch.add_line(x1, y1, x0, y1)
	sm.sketch.add_line(x0, y1, x0, y0)


func _arm_features(ctx: FilmContext) -> void:
	await _select_body(ctx)
	var arm := PipeFixture.find_auto(ctx.main, "mirror:Features") as BaseButton
	check(arm != null and arm.is_visible_in_tree(), "mirror:Features is visible")
	if arm == null:
		return
	await FilmUI.click_control(ctx, arm, FilmUICues.alert("Features", "Feature Mirror"))
	await process_frame
	await process_frame


func _last_row(ctx: FilmContext, ftype: String) -> Control:
	var last: Control = null
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != ftype:
			continue
		var name := str(f.get("name", ""))
		var btn := PipeFixture.find_auto(ctx.main, "timeline:row:%s" % name) as Control
		if btn != null:
			last = btn
	return last


func _click_row(ctx: FilmContext, btn: Control, shift: bool) -> void:
	FilmUI.ensure_control_visible(btn)
	await FilmUI.wait_frames(ctx.tree, 1)
	if shift:
		_hold_shift(true)
		await process_frame
	await FilmUI.click_control(ctx, btn as BaseButton, FilmUICues.alert(
			"Shift+Click" if shift else "Click", "timeline row"))
	if shift:
		_hold_shift(false)
		await process_frame


func _hold_shift(held: bool) -> void:
	var ke := InputEventKey.new()
	ke.keycode = KEY_SHIFT
	ke.physical_keycode = KEY_SHIFT
	ke.pressed = held
	ke.shift_pressed = held
	Input.parse_input_event(ke)


func _select_body(ctx: FilmContext) -> void:
	var body := SpannerFixture.only_body(ctx)
	if body == "":
		return
	if ctx.view.selected_body != body or ctx.view.selected_face != "":
		ctx.view.select_entity(body, "")
		if ctx.main.has_method("_update_left_rail"):
			ctx.main._update_left_rail()
		await process_frame


func _show_timeline(ctx: FilmContext) -> void:
	if ctx.main.timeline != null and ctx.main.timeline.visible:
		ctx.main.timeline.refresh()
		await process_frame
		return
	var view_btn := FilmUI.find_button(ctx.main, "View") as MenuButton
	check(view_btn != null and view_btn.is_visible_in_tree(), "View menu is visible")
	if view_btn == null:
		return
	await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline"))
	await process_frame
	if ctx.main.has_method("_update_panel_visibility"):
		ctx.main._update_panel_visibility()
	await process_frame
	check(ctx.main.timeline != null and ctx.main.timeline.visible, "Timeline is visible")
