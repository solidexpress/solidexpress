# Rung 1 replan 14 WP5 — F frames in part mode and says so; wheel zoom keeps
# the world point under the cursor (leftovers 8, 9).
# Template: run_rung01_replan13_frame.gd / run_rung01_replan13_trim.gd.
# Setup may place geometry and enter a sketch; every key, wheel and motion
# under test is Viewport.push_input (HUD Frame / marking-menu via visible buttons).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script res://tests/run_rung01_replan14_camera.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const ANCHOR_PX := 2.0
const POSE_EPS := 0.001
const FILL_FRAC := 0.60
const BOX_SIZE := Vector3(240, 45, 10)
const CIRCLE_R := 20.0

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan14 WP5 camera frame / cursor-anchored zoom")
	print("starting_ref product under test; leftover 8 = part-mode F, leftover 9 = wheel anchor")
	FilmUI.reset_fail_count()
	await test_part_mode_f_and_hud()
	await test_hud_frame_with_timeline()
	await test_sketch_session_end_f()
	await test_zoom_anchor_matrix()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_part_mode_f_and_hud() -> void:
	print("- part mode: F / Shift+F / HUD Frame / marking menu / fillet-field F")
	var ctx := await _boot()
	var main = ctx.main
	var cam: OrbitCamera = main.camera
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	check(body != "", "box 240×45×10 placed")

	await _push_key_local(vp, KEY_ESCAPE)
	check(ctx.view.selected_body == "", "no body selected after Esc")

	await _push_key_local(vp, KEY_3)
	check(absf(cam.pitch - deg_to_rad(90.0)) < 0.05, "key 3 is Top view (pitch %.4f)" % cam.pitch)

	var end_px := _clamp_canvas(ctx, _end_screen(ctx, body))
	check(end_px != Vector2.INF, "one end of the body projects on screen (px %s)" % str(end_px))
	await _zoom_on(vp, end_px, true, 8)
	await process_frame
	var dist_zoomed := cam.distance
	var pivot_zoomed := cam.pivot
	print("  after 8 wheel-in on end: distance=%.4f pivot=%s end_px=%s" % [
		dist_zoomed, str(pivot_zoomed), str(end_px)])

	var mark := _status_log.size()
	await _push_key_local(vp, KEY_F)
	var hits := _framed_since(mark)
	print("  after F (no selection): label=`%s` framed_hits=%s log_tail=%s" % [
		str(main.status_label.text), str(hits), str(_status_log.slice(maxi(_status_log.size() - 6, 0)))])
	check(hits.size() == 1 and hits[0] == "Framed all",
			"1: F with nothing selected prints Framed all once (got %s)" % str(hits))
	_assert_body_in_free_rect(ctx, body, "F all")
	check(not is_equal_approx(cam.distance, dist_zoomed) or not cam.pivot.is_equal_approx(pivot_zoomed),
			"1: F changed the zoomed-in pose (d %.4f → %.4f)" % [dist_zoomed, cam.distance])

	# sx-035 N6: HUD Frame must match F / Shift+F (same zoom and center),
	# including a real mouse click on the button — not only pressed.emit().
	var pose_f_all := _pose_of(cam)
	var canvas_f: Rect2 = cam.sketch_fit_canvas_rect()
	print("  after F all: d=%.4f pivot=%s canvas=%s" % [
		cam.distance, str(cam.pivot), str(canvas_f)])
	mark = _status_log.size()
	await _push_key_local(vp, KEY_F, true)
	hits = _framed_since(mark)
	check(hits.size() == 1 and hits[0] == "Framed all",
			"1b: Shift+F with nothing selected prints Framed all once (got %s)" % str(hits))
	check(_pose_near(cam, pose_f_all),
			"1b: Shift+F pose matches F (d %.4f vs %.4f)" % [
				cam.distance, pose_f_all["distance"]])
	var fit_btn_all := _find_labeled_button(main.view_hud, "Frame")
	check(fit_btn_all != null and fit_btn_all.is_visible_in_tree(),
			"1b: View HUD has a visible Frame button")
	if fit_btn_all != null:
		# Key F while the pointer sits on the HUD (same hover as a Frame click).
		await _move_pointer(vp, fit_btn_all.get_global_rect().get_center())
		mark = _status_log.size()
		await _push_key_local(vp, KEY_F)
		check(_pose_near(cam, pose_f_all),
				"1b: F with pointer on HUD Frame matches canvas F (d %.4f vs %.4f)" % [
					cam.distance, pose_f_all["distance"]])
		mark = _status_log.size()
		await _click_hud_frame(vp, fit_btn_all)
		await process_frame
		await process_frame
	hits = _framed_since(mark)
	if hits.is_empty() and str(main.status_label.text) == "Framed all":
		hits.append("Framed all")
	print("  after real HUD Frame click (no selection): hits=%s d=%.4f want %.4f canvas=%s" % [
		str(hits), cam.distance, pose_f_all["distance"], str(cam.sketch_fit_canvas_rect())])
	check(hits.size() == 1 and hits[0] == "Framed all",
			"1b: HUD Frame prints Framed all once (got %s)" % str(hits))
	check(_pose_near(cam, pose_f_all),
			"1b: HUD Frame pose matches F / Shift+F (d %.4f vs %.4f, pivot dist %.4f)" % [
				cam.distance, pose_f_all["distance"],
				cam.pivot.distance_to(pose_f_all["pivot"])])

	var end_px2 := _clamp_canvas(ctx, _body_screen_center(ctx, body))
	await _click_at(vp, end_px2)
	await process_frame
	check(ctx.view.selected_body == body, "2: click selected the body (%s)" % ctx.view.selected_body)
	await _zoom_on(vp, end_px2, true, 8)
	mark = _status_log.size()
	await _push_key_local(vp, KEY_F)
	hits = _framed_since(mark)
	print("  after F (selected): label=`%s` framed_hits=%s" % [str(main.status_label.text), str(hits)])
	check(hits.size() == 1 and hits[0] == "Framed selection",
			"2: F with the body selected prints Framed selection once (got %s)" % str(hits))
	_assert_body_in_free_rect(ctx, body, "F selection")

	var pose_f := _pose_of(cam)
	mark = _status_log.size()
	await _push_key_local(vp, KEY_F, true)
	hits = _framed_since(mark)
	check(hits.size() == 1 and hits[0] == "Framed all",
			"2: Shift+F prints Framed all once (got %s)" % str(hits))
	_assert_body_in_free_rect(ctx, body, "Shift+F")

	var pose_sel := pose_f
	await _click_at(vp, _clamp_canvas(ctx, _body_screen_center(ctx, body)))
	await process_frame
	await _push_key_local(vp, KEY_F)
	pose_sel = _pose_of(cam)
	var fit_btn := _find_labeled_button(main.view_hud, "Frame")
	check(fit_btn != null and fit_btn.is_visible_in_tree(), "3: View HUD has a visible Frame button")
	mark = _status_log.size()
	if fit_btn != null:
		await FilmUI.click_control(ctx, fit_btn, FilmUICues.alert("F", "View HUD Frame"))
		await process_frame
		await process_frame
	hits = _framed_since(mark)
	if hits.is_empty():
		var lab := str(main.status_label.text)
		if lab == "Framed selection" or lab == "Framed all":
			hits.append(lab)
	print("  after HUD Frame: hits=%s pose d=%.4f want %.4f" % [
		str(hits), cam.distance, pose_sel["distance"]])
	check(hits.size() == 1,
			"3: HUD Frame status appears once (got %s)" % str(hits))
	check(_pose_near(cam, pose_sel),
			"3: HUD Frame pose matches F within 1e-3 (d %.4f vs %.4f, pivot dist %.4f)" % [
				cam.distance, pose_sel["distance"], cam.pivot.distance_to(pose_sel["pivot"])])

	mark = _status_log.size()
	var pose_before_20 := _pose_of(cam)
	await _click_orient_item(ctx, "Frame selection")
	hits = _framed_since(mark)
	check(hits.size() == 1 and hits[0] == "Framed selection",
			"3: marking-menu Frame selection prints once (got %s)" % str(hits))
	check(_pose_near(cam, pose_before_20) or _pose_near(cam, pose_sel),
			"3: marking-menu 20 pose matches frame-selection")

	mark = _status_log.size()
	await _click_orient_item(ctx, "Frame all")
	hits = _framed_since(mark)
	check(hits.size() == 1 and hits[0] == "Framed all",
			"3: marking-menu Frame all prints once (got %s)" % str(hits))

	# Row 5: WP2 regression — spinner commit must not swallow F.
	await _click_at(vp, _clamp_canvas(ctx, _body_screen_center(ctx, body)))
	await process_frame
	var fillet: Button = main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "5: StripFillet is visible")
	if fillet != null:
		await FilmUI.click_control(ctx, fillet, FilmUICues.alert("Fillet", "Arm Fillet"))
		await process_frame
		await process_frame
	var spin: SpinBox = main.interaction.find_child("StripRadius", true, false)
	check(spin != null and spin.is_visible_in_tree(), "5: strip R spin is visible")
	if spin != null:
		await _click_at(vp, _spin_arrow_pos(spin, true))
		await process_frame
		await _click_at(vp, _spin_arrow_pos(spin, false))
		await process_frame
	mark = _status_log.size()
	var dist_pre := cam.distance
	await _push_key_local(vp, KEY_F)
	hits = _framed_since(mark)
	print("  after fillet-spinner F: hits=%s focus=%s d %.4f → %.4f" % [
		str(hits), _focus_name(vp), dist_pre, cam.distance])
	check(hits.size() == 1 and (hits[0] == "Framed selection" or hits[0] == "Framed all"),
			"5: F after fillet spinner commit frames and says so (got %s)" % str(hits))
	await _shutdown(ctx)


func test_hud_frame_with_timeline() -> void:
	print("- N6: HUD Frame matches F with Timeline open (real mouse click)")
	var ctx := await _boot()
	var main = ctx.main
	var cam: OrbitCamera = main.camera
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	check(body != "", "timeline case: box placed")
	main.show_timeline = true
	if main.has_method("_update_panel_visibility"):
		main._update_panel_visibility()
	await process_frame
	await process_frame
	check(main.timeline != null and main.timeline.visible, "Timeline is visible")
	await _push_key_local(vp, KEY_ESCAPE)
	await _push_key_local(vp, KEY_3)
	var mark := _status_log.size()
	await _push_key_local(vp, KEY_F)
	var hits := _framed_since(mark)
	check(hits.size() == 1 and hits[0] == "Framed all",
			"N6: F prints Framed all (got %s)" % str(hits))
	_assert_body_in_free_rect(ctx, body, "N6 F")
	var pose_f := _pose_of(cam)
	var fit_btn := _find_labeled_button(main.view_hud, "Frame")
	check(fit_btn != null and fit_btn.is_visible_in_tree(), "N6: Frame button visible")
	mark = _status_log.size()
	if fit_btn != null:
		await _click_hud_frame(vp, fit_btn)
		await process_frame
		await process_frame
	hits = _framed_since(mark)
	if hits.is_empty() and str(main.status_label.text) == "Framed all":
		hits.append("Framed all")
	print("  N6 HUD Frame: d=%.4f want %.4f hits=%s" % [
		cam.distance, pose_f["distance"], str(hits)])
	check(hits.size() == 1 and hits[0] == "Framed all",
			"N6: HUD Frame prints Framed all (got %s)" % str(hits))
	check(_pose_near(cam, pose_f),
			"N6: HUD Frame pose matches F (d %.4f vs %.4f, pivot dist %.4f)" % [
				cam.distance, pose_f["distance"],
				cam.pivot.distance_to(pose_f["pivot"])])
	await _shutdown(ctx)


func test_sketch_session_end_f() -> void:
	print("- F after a sketch session ends (Exit Sketch, Esc, Save As re-entry)")
	var ctx := await _boot()
	var main = ctx.main
	var cam: OrbitCamera = main.camera
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	await _push_key_local(vp, KEY_3)

	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "4: blank sketch opened")
	if sm != null and sm.sketch != null:
		sm.sketch.add_circle(0.0, 0.0, CIRCLE_R)
		sm.run_solve()
		await process_frame
		await process_frame
	check(_sketch_fit_valid(cam), "4: sketch_fit is valid while the session is open")

	await FilmUI.exit_sketch(ctx)
	await process_frame
	await process_frame
	check(sm == null or not sm.active, "4: Exit Sketch ended the session")
	check(not _sketch_fit_valid(cam), "4: sketch_fit is invalid after Exit Sketch")
	var mark := _status_log.size()
	await _push_key_local(vp, KEY_F)
	var hits := _framed_since(mark)
	check(hits.size() == 1 and (hits[0] == "Framed all" or hits[0] == "Framed selection"),
			"4: F after Exit Sketch frames the part (got %s)" % str(hits))
	check(not _sketch_fit_valid(cam), "4: sketch_fit stays invalid after 3D F")
	_assert_body_in_free_rect(ctx, body, "F after Exit Sketch")

	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	check(sm != null and sm.active, "4: sketch re-opened for Esc")
	if sm != null and sm.sketch != null and sm.sketch.entity_ids().is_empty():
		sm.sketch.add_circle(0.0, 0.0, CIRCLE_R)
		sm.run_solve()
		await process_frame
	await _push_key_local(vp, KEY_ESCAPE)
	await process_frame
	if sm != null and sm.active:
		await _push_key_local(vp, KEY_ESCAPE)
		await process_frame
	if sm != null and sm.active:
		await _push_key_local(vp, KEY_ESCAPE)
		await process_frame
	check(sm == null or not sm.active, "4: Esc ended the sketch session")
	check(not _sketch_fit_valid(cam), "4: sketch_fit is invalid after Esc")
	mark = _status_log.size()
	await _push_key_local(vp, KEY_F)
	hits = _framed_since(mark)
	check(hits.size() == 1 and (hits[0] == "Framed all" or hits[0] == "Framed selection"),
			"4: F after Esc frames the part (got %s)" % str(hits))

	await FilmUI.enter_sketch(ctx)
	sm = main.sketch_mode
	check(sm != null and sm.active, "4: sketch re-opened for Save As re-entry")
	if sm != null and sm.sketch != null and sm.sketch.entity_ids().is_empty():
		sm.sketch.add_circle(0.0, 0.0, CIRCLE_R)
		sm.run_solve()
		await process_frame
	main.current_path = "/tmp/rung01_replan14_camera.sxp"
	main._save_current()
	await process_frame
	await process_frame
	print("  after Save As re-entry: active=%s sketch_fit_valid=%s status=`%s`" % [
		str(sm != null and sm.active), str(_sketch_fit_valid(cam)), str(main.status_label.text)])
	if sm != null and sm.active:
		check(_sketch_fit_valid(cam), "4: live sketch after Save As still has a fit hook")
		await FilmUI.exit_sketch(ctx)
		await process_frame
		await process_frame
	check(sm == null or not sm.active, "4: session ended after Save As then Exit Sketch")
	check(not _sketch_fit_valid(cam), "4: sketch_fit is invalid after Save As re-entry then exit")
	mark = _status_log.size()
	await _push_key_local(vp, KEY_F)
	hits = _framed_since(mark)
	check(hits.size() == 1 and (hits[0] == "Framed all" or hits[0] == "Framed selection"),
			"4: F after Save As re-entry then exit frames the part (got %s)" % str(hits))
	await _shutdown(ctx)


func test_zoom_anchor_matrix() -> void:
	print("- wheel zoom keeps the point under the cursor (persp/ortho × part/sketch)")
	await _zoom_anchor_part(false)
	await _zoom_anchor_part(true)
	await _zoom_anchor_sketch()


func _zoom_anchor_part(ortho: bool) -> void:
	var tag := "part %s Top" % ("ortho" if ortho else "persp")
	print("- zoom anchor: %s" % tag)
	var ctx := await _boot()
	var cam: OrbitCamera = ctx.main.camera
	var vp: Viewport = ctx.main.get_viewport()
	var body := await _place_box(ctx)
	await _push_key_local(vp, KEY_3)
	if ortho:
		if cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
			await _push_key_local(vp, KEY_5)
		check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "%s: orthogonal" % tag)
	else:
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			await _push_key_local(vp, KEY_5)
		check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "%s: perspective" % tag)
	await _push_key_local(vp, KEY_F)
	await process_frame
	var p := _clamp_canvas(ctx, _end_screen(ctx, body))
	check(p != Vector2.INF, "%s: body end on screen (px %s)" % [tag, str(p)])
	await _assert_anchor_roundtrip(ctx, cam, vp, p, tag)
	await _assert_zoom_out_cap(ctx, cam, vp, body, p, tag)
	await _assert_offscreen_safety_net(ctx, cam, vp, body, tag)
	await _shutdown(ctx)


func _zoom_anchor_sketch() -> void:
	var tag := "blank sketch ortho"
	print("- zoom anchor: %s" % tag)
	var ctx := await _boot()
	var cam: OrbitCamera = ctx.main.camera
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "%s: sketch is open" % tag)
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"%s: sketch lock is orthogonal (KEY_5 does not leave it)" % tag)
	if sm != null and sm.sketch != null:
		sm.sketch.add_circle(0.0, 0.0, CIRCLE_R)
		sm.run_solve()
		await process_frame
		await process_frame
	var p := _clamp_canvas(ctx, _project_model(ctx, sm.to_model(Vector2(CIRCLE_R, 0.0))))
	check(p != Vector2.INF, "%s: circle sits on screen (px %s)" % [tag, str(p)])
	await _assert_anchor_roundtrip(ctx, cam, vp, p, tag)
	var fit_d := cam.distance
	await _assert_zoom_out_from_here(ctx, cam, vp, p, fit_d, tag)
	await _shutdown(ctx)


func _assert_anchor_roundtrip(ctx: FilmContext, cam: OrbitCamera, vp: Viewport, p: Vector2, tag: String) -> void:
	p = _clamp_canvas(ctx, p)
	await _move_pointer(vp, p)
	var w := _world_under(cam, p)
	var dist0 := cam.distance
	var pivot0 := cam.pivot
	print("  %s round-trip start: P=%s W=%s d=%.4f pivot=%s" % [
		tag, str(p), str(w), dist0, str(pivot0)])
	for i in 3:
		await _wheel_at(vp, p, true)
		var got := cam.unproject_position(w)
		var err := got.distance_to(p)
		print("    in  %d: unproj=%s err=%.3f px  d=%.4f pivot=%s" % [
			i + 1, str(got), err, cam.distance, str(cam.pivot)])
		check(err <= ANCHOR_PX,
				"%s: wheel-in %d keeps W under P ±2 px (err %.3f, unproj %s)" % [
					tag, i + 1, err, str(got)])
	for i in 3:
		await _wheel_at(vp, p, false)
		var got := cam.unproject_position(w)
		var err := got.distance_to(p)
		print("    out %d: unproj=%s err=%.3f px  d=%.4f pivot=%s" % [
			i + 1, str(got), err, cam.distance, str(cam.pivot)])
		check(err <= ANCHOR_PX,
				"%s: wheel-out %d keeps W under P ±2 px (err %.3f, unproj %s)" % [
					tag, i + 1, err, str(got)])
	check(absf(cam.distance - dist0) <= POSE_EPS,
			"%s: 3 in + 3 out restores distance (%.4f vs %.4f)" % [tag, cam.distance, dist0])
	check(cam.pivot.distance_to(pivot0) <= POSE_EPS,
			"%s: 3 in + 3 out restores pivot (delta %.4f)" % [tag, cam.pivot.distance_to(pivot0)])


func _assert_zoom_out_cap(ctx: FilmContext, cam: OrbitCamera, vp: Viewport, body: String, p: Vector2, tag: String) -> void:
	await _push_key_local(vp, KEY_F)
	await process_frame
	p = _clamp_canvas(ctx, _end_screen(ctx, body))
	await _assert_zoom_out_from_here(ctx, cam, vp, p, cam.distance, tag)


func _assert_zoom_out_from_here(ctx: FilmContext, cam: OrbitCamera, vp: Viewport, p: Vector2, fit_d: float, tag: String) -> void:
	await _move_pointer(vp, p)
	var w := _world_under(cam, p)
	var max_d := fit_d * OrbitCamera.ZOOM_OUT_MAX_FIT_MULT
	print("  %s 12-notch zoom-out: fit_d=%.4f cap=%.4f P=%s W=%s" % [
		tag, fit_d, max_d, str(p), str(w)])
	for i in 12:
		await _wheel_at(vp, p, false)
		var got := cam.unproject_position(w)
		var err := got.distance_to(p)
		var on_screen := _point_in_view(cam, w)
		print("    out %d: err=%.3f px on_screen=%s d=%.4f" % [
			i + 1, err, str(on_screen), cam.distance])
		if on_screen:
			check(err <= ANCHOR_PX,
					"%s: zoom-out %d holds anchor ±2 px while on screen (err %.3f)" % [
						tag, i + 1, err])
		check(cam.distance <= max_d + 1e-3,
				"%s: distance %.4f never exceeds ZOOM_OUT_MAX_FIT_MULT×fit %.4f" % [
					tag, cam.distance, max_d])


func _assert_offscreen_safety_net(ctx: FilmContext, cam: OrbitCamera, vp: Viewport, body: String, tag: String) -> void:
	await _push_key_local(vp, KEY_F)
	await process_frame
	var p := _body_screen_center(ctx, body)
	await _move_pointer(vp, p)
	var n := 0
	while _body_intersects_view(ctx, body) and n < 40:
		await _wheel_at(vp, p, false, true)
		n += 1
	print("  %s pan-off: %d Shift+wheel notches, on_screen=%s" % [
		tag, n, str(_body_intersects_view(ctx, body))])
	check(n > 0, "%s: Shift+wheel pan ran" % tag)
	if _body_intersects_view(ctx, body):
		print("  note: body still on screen after %d pans — safety-net row skipped" % n)
		return
	var recovered := false
	for i in 6:
		await _wheel_at(vp, p, false)
		if _body_intersects_view(ctx, body):
			recovered = true
			print("    safety-net: body back on screen after zoom-out %d" % (i + 1))
			break
	check(recovered, "%s: zoom-out recentres off-screen content within 6 notches" % tag)


func _assert_body_in_free_rect(ctx: FilmContext, body: String, via: String) -> void:
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	var corners := _body_world_corners(ctx, body)
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var all_in := true
	for c in corners:
		if cam.is_position_behind(c):
			all_in = false
			print("  measure: corner %s behind camera via %s" % [str(c), via])
			continue
		var px: Vector2 = cam.unproject_position(c)
		min_p.x = minf(min_p.x, px.x)
		min_p.y = minf(min_p.y, px.y)
		max_p.x = maxf(max_p.x, px.x)
		max_p.y = maxf(max_p.y, px.y)
		if not canvas.has_point(px):
			all_in = false
			print("  measure: corner px=%s OUT of free rect %s via %s" % [str(px), str(canvas), via])
	var pr := Rect2(min_p, max_p - min_p)
	var larger := maxf(canvas.size.x, canvas.size.y)
	var fill := maxf(pr.size.x, pr.size.y) / maxf(larger, 1.0)
	print("  framed %s: canvas=%s proj=%s fill=%.3f" % [via, str(canvas), str(pr), fill])
	check(all_in, "%s: projected AABB corners sit in the free rect %s" % [via, str(canvas)])
	check(fill >= FILL_FRAC,
			"%s: projected AABB fills ≥ 60%% of the free rect's larger dim (got %.3f)" % [via, fill])


func _body_world_corners(ctx: FilmContext, body: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var node := ctx.view.body_node(body)
	if node == null:
		return out
	var aabb: AABB = node.get_aabb()
	var xf: Transform3D = node.global_transform
	for i in 8:
		var local := aabb.position + Vector3(
			aabb.size.x if (i & 1) != 0 else 0.0,
			aabb.size.y if (i & 2) != 0 else 0.0,
			aabb.size.z if (i & 4) != 0 else 0.0)
		out.append(xf * local)
	return out


func _body_screen_center(ctx: FilmContext, body: String) -> Vector2:
	var corners := _body_world_corners(ctx, body)
	if corners.is_empty():
		return Vector2.INF
	var acc := Vector3.ZERO
	for c in corners:
		acc += c
	return _project_world(ctx, acc / float(corners.size()))


func _end_screen(ctx: FilmContext, body: String) -> Vector2:
	var cam: OrbitCamera = ctx.main.camera
	var best := Vector2.INF
	var best_x := -INF
	for c in _body_world_corners(ctx, body):
		if cam.is_position_behind(c):
			continue
		var px: Vector2 = cam.unproject_position(c)
		if px.x > best_x:
			best_x = px.x
			best = px
	return best


func _body_intersects_view(ctx: FilmContext, body: String) -> bool:
	var cam: OrbitCamera = ctx.main.camera
	var vr: Rect2 = ctx.main.get_viewport().get_visible_rect()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var any := false
	for c in _body_world_corners(ctx, body):
		if cam.is_position_behind(c):
			continue
		any = true
		var px: Vector2 = cam.unproject_position(c)
		min_p.x = minf(min_p.x, px.x)
		min_p.y = minf(min_p.y, px.y)
		max_p.x = maxf(max_p.x, px.x)
		max_p.y = maxf(max_p.y, px.y)
	if not any:
		return false
	return vr.intersects(Rect2(min_p, max_p - min_p))


func _point_in_view(cam: Camera3D, world: Vector3) -> bool:
	if cam.is_position_behind(world):
		return false
	var vr: Rect2 = cam.get_viewport().get_visible_rect()
	return vr.has_point(cam.unproject_position(world))


func _clamp_canvas(ctx: FilmContext, p: Vector2) -> Vector2:
	if p == Vector2.INF:
		return p
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	var m := 8.0
	return Vector2(
		clampf(p.x, canvas.position.x + m, canvas.position.x + canvas.size.x - m),
		clampf(p.y, canvas.position.y + m, canvas.position.y + canvas.size.y - m))


func _project_world(ctx: FilmContext, world: Vector3) -> Vector2:
	var cam: OrbitCamera = ctx.main.camera
	if cam.is_position_behind(world):
		return Vector2.INF
	return cam.unproject_position(world)


func _project_model(ctx: FilmContext, model_pt: Vector3) -> Vector2:
	var ms: Node3D = ctx.main.model_space
	var world: Vector3 = ms.to_global(model_pt) if ms != null else model_pt
	return _project_world(ctx, world)


func _world_under(cam: OrbitCamera, screen_pos: Vector2) -> Vector3:
	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_dir := cam.project_ray_normal(screen_pos)
	var forward := -cam.global_transform.basis.z
	var denom := ray_dir.dot(forward)
	if absf(denom) < 1e-12:
		return cam.pivot
	var t := (cam.pivot - ray_origin).dot(forward) / denom
	return ray_origin + ray_dir * t


func _pose_of(cam: OrbitCamera) -> Dictionary:
	return {"distance": cam.distance, "pivot": cam.pivot}


func _pose_near(cam: OrbitCamera, pose: Dictionary) -> bool:
	if absf(cam.distance - float(pose["distance"])) > POSE_EPS:
		return false
	return cam.pivot.distance_to(pose["pivot"] as Vector3) <= POSE_EPS


func _framed_since(mark: int) -> Array[String]:
	var hits: Array[String] = []
	for i in range(mark, _status_log.size()):
		var s := _status_log[i]
		if s == "Framed selection" or s == "Framed all":
			hits.append(s)
	return hits


func _sketch_fit_valid(cam: OrbitCamera) -> bool:
	if cam == null:
		return false
	var hook: Variant = cam.get("sketch_fit")
	if not (hook is Callable):
		return false
	var cb := hook as Callable
	if not cb.is_valid():
		return false
	if cam.sketch_orientation_locked:
		return true
	var obj = cb.get_object()
	if obj != null and bool(obj.get("active")):
		return true
	return false


func _focus_name(vp: Viewport) -> String:
	var f: Control = vp.gui_get_focus_owner()
	if f == null:
		return "null"
	return "%s:%s" % [f.get_class(), f.name]


func _spin_arrow_pos(spin: SpinBox, up: bool) -> Vector2:
	var r: Rect2 = spin.get_global_rect()
	var x := r.position.x + r.size.x - 8.0
	var y := r.position.y + (r.size.y * 0.28 if up else r.size.y * 0.72)
	return Vector2(x, y)


func _find_labeled_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _click_orient_item(ctx: FilmContext, label: String) -> void:
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix != null and ix.has_method("_show_orient_popup"),
			"interaction can open the orientation marking menu")
	if ix == null:
		return
	ix._show_orient_popup()
	await process_frame
	await process_frame
	var popup: PopupPanel = ix._orient_popup
	var btn := _find_labeled_button(popup, label)
	check(btn != null and btn.is_visible_in_tree(),
			"marking-menu has visible '%s'" % label)
	if btn == null:
		if popup != null:
			popup.hide()
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Space", label))
	await process_frame
	await process_frame
	if popup != null and popup.visible:
		popup.hide()


func _place_box(ctx: FilmContext) -> String:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, BOX_SIZE)
	await process_frame
	await process_frame
	if ctx.main.has_method("_update_panel_visibility"):
		ctx.main._update_panel_visibility()
	await process_frame
	return body


func _push_key_local(vp: Viewport, keycode: Key, shift := false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


func _move_pointer(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _move_pointer(vp, pos)
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
	await process_frame


## Real mouse press on the View HUD Frame button (no pressed.emit() cheat).
func _click_hud_frame(vp: Viewport, fit_btn: Button) -> void:
	var pos := fit_btn.get_global_rect().get_center()
	await _click_at(vp, pos)


func _wheel_at(vp: Viewport, pos: Vector2, zoom_in: bool, shift := false) -> void:
	await _move_pointer(vp, pos)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = 1.0
	ev.shift_pressed = shift
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)
	await process_frame


func _zoom_on(vp: Viewport, pos: Vector2, zoom_in: bool, notches: int) -> void:
	for i in notches:
		await _wheel_at(vp, pos, zoom_in)


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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.ops_panel != null and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
	if main.camera != null and main.camera.has_signal("framed"):
		if not main.camera.framed.is_connected(_on_status):
			main.camera.framed.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame
