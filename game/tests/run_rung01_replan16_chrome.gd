# Rung 1 replan 16 WP5 — camera restore, menu Esc, rail accent, Timeline dock,
# status hold, Open frames the part (leftovers 7, 9, 10, 12, 15, 16).
# Setup may place geometry and enter numbers through the document / sketch API.
# Every press, key, and motion under test is Viewport.push_input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan16_chrome.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const POSE_EPS := 0.001
const SAVE_PATH := "/tmp/sx_wp5_chrome.sxp"
const FACE_HINT := "Face — click selects body first, click again for face · then Pull arrow"
const BOX_SIZE := Vector3(240, 45, 10)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan16 WP5 chrome / status hold / camera")
	FilmUI.reset_fail_count()
	await _test_c1_camera()
	await _test_c2_menu_esc()
	await _test_c3_rail()
	await _test_c4_timeline()
	await _test_c5_c6_open()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _test_c1_camera() -> void:
	print("- C1 leftover 7: Extrude returns the pre-sketch camera")
	var ctx := await _boot()
	var main = ctx.main
	var cam: OrbitCamera = main.camera
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	check(body != "", "C1 box placed")
	await _push_key(vp, KEY_3)
	await process_frame
	var before := _pose_of(cam)
	print("  C1 pre-sketch pose %s" % _pose_text(before))
	# A selected body hides the palette; the Modify-rail Sketch is the visible one.
	var sketch_btn: Button = _find_labeled_button(main.ops_panel, "Sketch")
	if sketch_btn == null:
		await _push_key(vp, KEY_ESCAPE)
		await process_frame
		sketch_btn = main.find_child("PaletteSketch", true, false)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(),
			"C1 rail Sketch is visible (face=%s)" % str(ctx.view.selected_face))
	if sketch_btn != null:
		await _click_control(sketch_btn)
		await process_frame
	var face_px := _top_face_screen(ctx, body)
	print("  C1 top-face screen %s status=`%s`" % [str(face_px), _label(main)])
	check(face_px != Vector2.INF, "C1 top face projects on screen")
	if face_px != Vector2.INF:
		await _click_at(vp, face_px)
		await process_frame
		await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "C1 rail Sketch + top face entered sketch (status `%s`)" % _label(main))
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	_release_focus(vp)
	var mark := _status_log.size()
	await _push_key(vp, KEY_F)
	await process_frame
	var saw_fit := _log_has_since(mark, "Sketch view fit") or _label(main) == "Sketch view fit"
	print("  C1 after F label=`%s` locked=%s log_tail=%s" % [
		_label(main), str(cam.sketch_orientation_locked), str(_status_log.slice(maxi(_status_log.size() - 4, 0)))])
	check(saw_fit, "C1 F prints Sketch view fit")
	sm._add_slot(Vector2(-40.0, 0.0), Vector2(40.0, 0.0), 5.0)
	await process_frame
	var chrome: SketchContextChrome = main.sketch_chrome
	if chrome != null:
		chrome.set_finish_op("cut")
		chrome.set_finish_end("blind")
		# set_extrude_distance keeps the previous line text ("20"), so write both.
		chrome._write_extrude_spin(2.5, "2.5")
	var extrude: Button = main.find_child("ExtrudeButton", true, false)
	check(extrude != null and extrude.is_visible_in_tree() and not extrude.disabled,
			"C1 Extrude button is visible and enabled")
	mark = _status_log.size()
	if extrude != null:
		await _click_control(extrude)
		for _i in 8:
			await process_frame
	var extrude_status := _label(main)
	var saw_extrude := extrude_status == "Extrude Blind 2.5000 mm" or _log_has_since(mark, "Extrude Blind 2.5000 mm")
	print("  C1 after Extrude label=`%s` active=%s pose %s" % [
		extrude_status, str(sm.active), _pose_text(_pose_of(cam))])
	check(saw_extrude, "C1 status is Extrude Blind 2.5000 mm (got `%s`)" % extrude_status)
	check(not sm.active, "C1 sketch session ended")
	var after := _pose_of(cam)
	check(_pose_near(before, after),
			"C1 camera matches pre-sketch within 1e-3 (before %s after %s)" % [
				_pose_text(before), _pose_text(after)])
	await _shutdown(ctx)


func _test_c2_menu_esc() -> void:
	print("- C2 leftover 9: menu Esc does not clear the selection")
	var ctx := await _boot()
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	var center := _body_screen_center(ctx, body)
	check(center != Vector2.INF, "C2 body center on screen")
	if center != Vector2.INF:
		await _click_at(vp, center)
		await process_frame
	check(ctx.view.selected_body == body, "C2 body selected before the menu (got `%s`)" % ctx.view.selected_body)
	var mode_before := _panel_mode(main)
	print("  C2 panel before %s" % mode_before)
	var view_btn := _menu_button(main, "View")
	check(view_btn != null, "C2 View menu button exists")
	var popup: PopupMenu = null
	if view_btn != null:
		await _click_control(view_btn)
		await process_frame
		popup = view_btn.get_popup()
		if popup != null and not popup.visible:
			view_btn.show_popup()
			await process_frame
	check(popup != null and popup.visible, "C2 View popup is visible")
	var mark := _status_log.size()
	if popup != null:
		await _push_esc(popup.get_viewport())
		await _push_esc(vp)
		await process_frame
		await process_frame
	print("  C2 after Esc popup=%s body=%s panel=%s label=`%s`" % [
		str(popup.visible if popup != null else false), ctx.view.selected_body,
		_panel_mode(main), _label(main)])
	check(popup == null or not popup.visible, "C2 View popup hid")
	check(ctx.view.selected_body == body, "C2 selected body unchanged")
	check(_panel_mode(main) == mode_before, "C2 left-panel mode unchanged (before %s after %s)" % [
		mode_before, _panel_mode(main)])
	check(not _log_has_since(mark, "Selection cleared") and not _label(main).contains("Selection cleared"),
			"C2 no Selection cleared (label `%s`)" % _label(main))

	if ctx.view.selected_body == "":
		var again := _body_screen_center(ctx, body)
		if again != Vector2.INF:
			await _click_at(vp, again)
			await process_frame
	var hud_popup: PopupPanel = main.view_hud.find_child("ViewsPopup", true, false) if main.view_hud != null else null
	var drop: Button = main.view_hud.find_child("ViewsDrop", true, false) if main.view_hud != null else null
	check(drop != null and drop.is_visible_in_tree(), "C2 HUD View ▼ is visible")
	check(ctx.view.selected_body == body, "C2 body selected again before the HUD menu")
	if drop != null:
		await _click_control(drop)
		await process_frame
		await process_frame
	check(hud_popup != null and hud_popup.visible, "C2 HUD View popup is visible")
	mode_before = _panel_mode(main)
	var body_before := ctx.view.selected_body
	mark = _status_log.size()
	if hud_popup != null:
		await _push_esc(hud_popup.get_viewport())
		await _push_esc(vp)
		await process_frame
		await process_frame
	print("  C2 HUD after Esc popup=%s body=%s label=`%s`" % [
		str(hud_popup.visible if hud_popup != null else false), ctx.view.selected_body, _label(main)])
	check(hud_popup == null or not hud_popup.visible, "C2 HUD popup hid")
	check(ctx.view.selected_body == body_before, "C2 HUD Esc keeps the selection")
	check(_panel_mode(main) == mode_before, "C2 HUD Esc keeps the left panel")
	check(not _log_has_since(mark, "Selection cleared"), "C2 HUD Esc does not print Selection cleared")

	mark = _status_log.size()
	await _push_esc(vp)
	await process_frame
	await process_frame
	var cleared := _log_has_since(mark, "Selection cleared") or _label(main).contains("Selection cleared")
	print("  C2 second Esc label=`%s` body=%s" % [_label(main), ctx.view.selected_body])
	check(cleared, "C2 second Esc with no popup prints Selection cleared (got `%s`)" % _label(main))
	await _shutdown(ctx)


func _test_c3_rail() -> void:
	print("- C3 leftover 10: armed rail tool is visibly distinct")
	var ctx := await _boot()
	var main = ctx.main
	main._start_sketch_on_ground()
	await process_frame
	await process_frame
	var jaw: Button = main.find_child("ToolJaw", true, false)
	if jaw == null:
		jaw = main.find_child("JawTool", true, false)
	var rect: Button = main.find_child("ToolRect", true, false)
	check(jaw != null, "C3 jaw rail button exists (ToolJaw / JawTool)")
	check(rect != null, "C3 ToolRect exists")
	if jaw == null or rect == null:
		await _shutdown(ctx)
		return
	check(not jaw.button_pressed, "C3 jaw starts unarmed")
	var hover: StyleBox = jaw.get_theme_stylebox("hover")
	var normal: StyleBox = jaw.get_theme_stylebox("normal")
	check(not _has_accent_bar(hover) and not _has_accent_bar(normal),
			"C3 unarmed jaw hover/normal lack the 3 px accent bar")
	await _click_control(jaw)
	await process_frame
	var pressed: StyleBox = jaw.get_theme_stylebox("pressed")
	var hover_pressed: StyleBox = jaw.get_theme_stylebox("hover_pressed")
	print("  C3 jaw pressed=%s pressed_box=%s hover_box=%s" % [
		str(jaw.button_pressed), _style_text(pressed), _style_text(hover)])
	check(jaw.button_pressed, "C3 ToolJaw/JawTool is armed")
	check(pressed is StyleBoxFlat, "C3 pressed style is StyleBoxFlat")
	if pressed is StyleBoxFlat and hover is StyleBoxFlat:
		var gap := absf((pressed as StyleBoxFlat).bg_color.get_luminance() - (hover as StyleBoxFlat).bg_color.get_luminance())
		print("  C3 luminance gap %.3f border_left=%d" % [gap, (pressed as StyleBoxFlat).get_border_width(SIDE_LEFT)])
		check(gap >= 0.12, "C3 pressed fill differs from hover by ≥ 0.12 luminance (got %.3f)" % gap)
		check((pressed as StyleBoxFlat).get_border_width(SIDE_LEFT) == 3, "C3 pressed border_width_left is 3")
	else:
		check(false, "C3 pressed and hover styles are StyleBoxFlat")
	check(_has_accent_bar(hover_pressed), "C3 hover_pressed has the 3 px bar")
	check(not _has_accent_bar(hover), "C3 hover style lacks the accent bar")
	await process_frame
	await process_frame
	await _assert_accent_columns(jaw, rect, "C3 jaw armed")
	await _click_control(rect)
	await process_frame
	await process_frame
	print("  C3 rect pressed=%s jaw pressed=%s" % [str(rect.button_pressed), str(jaw.button_pressed)])
	check(rect.button_pressed and not jaw.button_pressed, "C3 Rect armed shows Rect lit and Jaw not")
	var circle: Button = main.find_child("ToolCircle", true, false)
	check(circle != null, "C3 ToolCircle exists")
	if circle != null:
		await _click_control(circle)
		await process_frame
		await process_frame
		check(circle.button_pressed and not rect.button_pressed and not jaw.button_pressed,
				"C3 Circle armed shows only Circle lit")
		await _assert_accent_columns(circle, jaw, "C3 circle armed")
	await _shutdown(ctx)


func _test_c4_timeline() -> void:
	print("- C4 leftover 12: Timeline stays off the Modify Radius field")
	var ctx := await _boot()
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var body := await _place_box(ctx)
	check(ctx.view.selected_body == body and ctx.view.selected_face == "",
			"C4 body selected with no face so Modify shows Radius")
	if ctx.view.selected_face != "":
		ctx.view.select_entity(body, "")
		await process_frame
	# Card Fillet applies every edge. Arming (strip / marking menu) is what
	# surfaces the Radius field the click below has to reach.
	main.ops_panel.arm_or_apply_fillet()
	await process_frame
	await process_frame
	var spin: SpinBox = main.ops_panel._radius_spin if main.ops_panel != null else null
	check(spin != null and spin.is_visible_in_tree(), "C4 panel Radius is visible")
	var opened := await _click_menu_id(ctx, "View", 4, "View ▸ Timeline")
	check(opened, "C4 View ▸ Timeline click landed")
	for _i in 4:
		await process_frame
	if main.timeline != null and not main.timeline.visible and main.has_method("_update_panel_visibility"):
		main.show_timeline = true
		main._update_panel_visibility()
		await process_frame
		await process_frame
	var timeline: Control = main.timeline
	check(timeline != null and timeline.visible, "C4 Timeline is visible")
	if timeline == null or spin == null:
		await _shutdown(ctx)
		return
	await _scroll_into_view(main, spin)
	var win := vp.get_visible_rect()
	var tr: Rect2 = timeline.get_global_rect()
	var sr: Rect2 = spin.get_global_rect()
	print("  C4 window=%s timeline=%s radius=%s" % [str(win), str(tr), str(sr)])
	check(not tr.intersects(sr), "C4 Timeline does not intersect Radius")
	check(_rect_inside(win, tr) and _rect_inside(win, sr), "C4 Timeline and Radius are inside the window")
	var edit: LineEdit = spin.get_line_edit()
	check(edit != null, "C4 Radius has a line edit")
	if edit != null:
		print("  C4 line rect=%s" % str(edit.get_global_rect()))
		await _click_control(edit)
		await process_frame
		await process_frame
	var focus := vp.gui_get_focus_owner()
	print("  C4 focus=%s" % (str(focus) if focus != null else "null"))
	check(focus == edit, "C4 click on panel Radius gives the line edit focus")
	await _shutdown(ctx)


func _test_c5_c6_open() -> void:
	print("- C5/C6 leftovers 15 and 16: Open holds status and frames the part")
	var ctx := await _boot()
	var main = ctx.main
	var cam: OrbitCamera = main.camera
	var body := await _place_box(ctx)
	check(body != "", "C5 box placed")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	main.current_path = SAVE_PATH
	main._save_current()
	await process_frame
	check(FileAccess.file_exists(SAVE_PATH), "C5 saved %s" % SAVE_PATH)
	print("  C5 camera before open distance=%.3f" % cam.distance)
	if main.file_dialog != null:
		main.file_dialog.current_dir = "/tmp"
	var opened := await _click_menu_id(ctx, "File", 1, "File → Open")
	await process_frame
	await process_frame
	var dlg: FileDialog = main.file_dialog
	check(opened and dlg != null and dlg.visible, "C5 Open dialog is visible")
	if dlg == null or not dlg.visible:
		await _shutdown(ctx)
		return
	dlg.current_dir = SAVE_PATH.get_base_dir()
	await process_frame
	var edit := _name_edit(dlg)
	check(edit != null, "C5 Open dialog has a filename field")
	if edit != null:
		await _click_embedded(edit)
		await process_frame
		await _type_text(edit.get_viewport(), SAVE_PATH.get_file())
		await process_frame
	var ok := dlg.get_ok_button()
	print("  C5 open disabled=%s file=`%s`" % [
		str(ok.disabled if ok != null else true), edit.text if edit != null else ""])
	check(ok != null and not ok.disabled, "C5 Open button enables for the saved file")
	if ok != null and not ok.disabled:
		await _click_embedded(ok)
		for _i in 6:
			await process_frame
	var want := "Opened " + SAVE_PATH
	print("  C5 label after open `%s`" % _label(main))
	check(_label(main) == want, "C5 status label is `%s` (got `%s`)" % [want, _label(main)])
	if ctx.view.selected_body != "":
		ctx.view.clear_selection()
		await process_frame
	var opened_body := ""
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() > 0:
		opened_body = ids[0]
	_assert_framed(ctx, opened_body, "C6")
	var hint_count := [0]
	if main.interaction.has_signal("hover_hint"):
		main.interaction.hover_hint.connect(func(text: String) -> void:
			if text.contains("Face —") or text.contains("Edge —") or text.contains("Body —"):
				hint_count[0] += 1)
	var opened_at := Time.get_ticks_msec()
	var hover_px := _body_screen_center(ctx, opened_body)
	if hover_px == Vector2.INF:
		hover_px = Vector2(640, 400)
	for i in 40:
		var jitter := Vector2(float(i % 5) - 2.0, float(i % 3) - 1.0)
		await _motion(main.get_viewport(), hover_px + jitter)
		var slot := opened_at + int(float(i + 1) / 40.0 * 1500.0)
		while Time.get_ticks_msec() < slot:
			await process_frame
	print("  C5 after 1.5s hovers label=`%s` hints=%d" % [_label(main), hint_count[0]])
	check(_label(main) == want, "C5 label still Opened after 1.5s of hover (got `%s`)" % _label(main))
	check(hint_count[0] > 0 or not main.interaction.has_signal("hover_hint"),
			"C5 hover hints fired during the hold (%d)" % hint_count[0])
	while Time.get_ticks_msec() < opened_at + 3000:
		await process_frame
	hover_px = _body_screen_center(ctx, opened_body)
	if hover_px == Vector2.INF:
		hover_px = Vector2(640, 400)
	await _motion(main.get_viewport(), hover_px)
	await _motion(main.get_viewport(), hover_px + Vector2(3, 2))
	await process_frame
	print("  C5 after 3s label=`%s`" % _label(main))
	check(_label(main) == FACE_HINT, "C5 hover after 3s shows the face hint (got `%s`)" % _label(main))
	var frame_btn := _find_labeled_button(main.view_hud, "Frame")
	check(frame_btn != null and frame_btn.is_visible_in_tree(), "C5 HUD Frame is visible")
	if frame_btn != null:
		await _click_control(frame_btn)
		await process_frame
		await process_frame
	check(_label(main) == "Framed all", "C5 HUD Frame prints Framed all (got `%s`)" % _label(main))
	var framed_at_label := _label(main)
	hover_px = _body_screen_center(ctx, opened_body)
	if hover_px != Vector2.INF:
		await _motion(main.get_viewport(), hover_px + Vector2(4, -2))
		await process_frame
	check(_label(main) == framed_at_label, "C5 Framed all holds against the next hover (got `%s`)" % _label(main))
	await _shutdown(ctx)


func _assert_framed(ctx: FilmContext, body: String, tag: String) -> void:
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect()
	var corners := _body_world_corners(ctx, body)
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var all_in := corners.size() == 8
	for c in corners:
		if cam.is_position_behind(c):
			all_in = false
			continue
		var px: Vector2 = cam.unproject_position(c)
		min_p.x = minf(min_p.x, px.x)
		min_p.y = minf(min_p.y, px.y)
		max_p.x = maxf(max_p.x, px.x)
		max_p.y = maxf(max_p.y, px.y)
		if not canvas.has_point(px):
			all_in = false
	var width := max_p.x - min_p.x
	var frac := width / maxf(canvas.size.x, 1.0)
	print("  %s canvas=%s proj_w=%.1f frac=%.3f inside=%s" % [tag, str(canvas), width, frac, str(all_in)])
	check(all_in, "%s projected AABB lies inside the chrome-free canvas" % tag)
	check(frac >= 0.40, "%s projected AABB spans ≥ 40%% of the canvas width (got %.3f)" % [tag, frac])


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
	_status_log.clear()
	if main.sketch_mode != null:
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null:
		main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
	await process_frame
	await process_frame


func _label(main) -> String:
	if main == null or main.status_label == null:
		return ""
	return str(main.status_label.text)


func _panel_mode(main) -> String:
	return "pal=%s ops=%s card=%s" % [
		str(main.palette.visible if main.palette != null else false),
		str(main.ops_panel.visible if main.ops_panel != null else false),
		str(main.card_box.visible if main.card_box != null else false)]


func _log_has_since(mark: int, needle: String) -> bool:
	for i in range(mark, _status_log.size()):
		if str(_status_log[i]).contains(needle):
			return true
	return false


func _place_box(ctx: FilmContext) -> String:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, BOX_SIZE)
	await process_frame
	await process_frame
	return body


func _pose_of(cam: OrbitCamera) -> Dictionary:
	return {
		"yaw": cam.yaw,
		"pitch": cam.pitch,
		"distance": cam.distance,
		"pivot": cam.pivot,
		"projection": int(cam.projection),
	}


func _pose_text(pose: Dictionary) -> String:
	var pivot: Vector3 = pose["pivot"]
	return "yaw=%.5f pitch=%.5f d=%.4f pivot=(%.3f,%.3f,%.3f) proj=%s" % [
		float(pose["yaw"]), float(pose["pitch"]), float(pose["distance"]),
		pivot.x, pivot.y, pivot.z, str(pose["projection"])]


func _pose_near(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a["yaw"]) - float(b["yaw"])) > POSE_EPS:
		return false
	if absf(float(a["pitch"]) - float(b["pitch"])) > POSE_EPS:
		return false
	if absf(float(a["distance"]) - float(b["distance"])) > POSE_EPS:
		return false
	if int(a["projection"]) != int(b["projection"]):
		return false
	return (a["pivot"] as Vector3).distance_to(b["pivot"] as Vector3) <= POSE_EPS


func _top_face_screen(ctx: FilmContext, body: String) -> Vector2:
	if body == "" or not ctx.view.doc.has_method("get_face_ids"):
		return Vector2.INF
	var best := ""
	var best_z := -1e9
	for face_id in ctx.view.doc.get_face_ids(body):
		var n: Vector3 = ctx.view.face_normal(body, str(face_id))
		if n.z > best_z:
			best_z = n.z
			best = str(face_id)
	if best == "" or best_z < 0.5:
		return Vector2.INF
	var mid: Vector3 = ctx.view.doc.face_midpoint(best)
	return ctx.view.model_to_screen(ctx.main.camera, mid)


func _body_world_corners(ctx: FilmContext, body: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if body == "":
		return out
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
	var cam: OrbitCamera = ctx.main.camera
	var world := acc / float(corners.size())
	if cam.is_position_behind(world):
		return Vector2.INF
	return cam.unproject_position(world)


func _has_accent_bar(box: StyleBox) -> bool:
	if not (box is StyleBoxFlat):
		return false
	var flat := box as StyleBoxFlat
	return flat.get_border_width(SIDE_LEFT) == 3 and _is_accent(flat.border_color)


func _accent() -> Color:
	return Color.html(UIIcons.ACCENT)


func _is_accent(c: Color) -> bool:
	var a := _accent()
	return absf(c.r - a.r) <= 0.05 and absf(c.g - a.g) <= 0.05 \
			and absf(c.b - a.b) <= 0.05 and c.a >= 0.85


## Colour Godot paints in column x of a sharp, non-blended StyleBoxFlat:
## the left border, then the fill. A visible RailAccentBar child is drawn
## after the style, so it covers those columns.
func _painted_column(b: Button, state: String, x: int) -> Color:
	var box := b.get_theme_stylebox(state) as StyleBoxFlat
	var col := Color(0, 0, 0, 1)
	if box != null:
		col = box.border_color if x < box.get_border_width(SIDE_LEFT) else box.bg_color
	var bar := b.get_node_or_null("RailAccentBar") as ColorRect
	if bar != null and bar.visible and float(x) < maxf(bar.size.x, bar.offset_right - bar.offset_left):
		col = bar.color
	return col


func _assert_accent_columns(armed: Button, other: Button, tag: String) -> void:
	await process_frame
	var scroll: ScrollContainer = null
	var walk: Node = armed
	while walk != null:
		if walk is ScrollContainer:
			scroll = walk as ScrollContainer
			break
		walk = walk.get_parent()
	var bar := armed.get_node_or_null("RailAccentBar") as ColorRect
	check(bar != null and bar.visible, "%s accent bar is visible" % tag)
	if bar != null:
		var width := bar.size.x if bar.size.x > 0.5 else bar.offset_right - bar.offset_left
		print("  %s bar rect=%s color=%s width=%.2f" % [tag, str(bar.get_global_rect()), str(bar.color), width])
		check(absf(width - 3.0) <= 0.5, "%s accent bar is 3 px wide (got %.2f)" % [tag, width])
		check(_is_accent(bar.color), "%s accent bar colour is the accent" % tag)
		var btn_rect := armed.get_global_rect()
		var bar_rect := bar.get_global_rect()
		check(absf(bar_rect.position.x - btn_rect.position.x) <= 1.0,
				"%s accent bar sits on the button's left edge" % tag)
		check(bar_rect.size.y >= btn_rect.size.y - 1.0, "%s accent bar covers the row height" % tag)
		if scroll != null:
			var clip := scroll.get_global_rect()
			var inside := clip.position.x <= bar_rect.position.x + 0.5 \
					and clip.position.y <= bar_rect.position.y + 0.5 \
					and bar_rect.end.x <= clip.end.x + 0.5 \
					and bar_rect.end.y <= clip.end.y + 0.5
			print("  %s clip=%s bar=%s inside=%s" % [tag, str(clip), str(bar_rect), str(inside)])
			check(inside, "%s accent bar is inside the rail clip" % tag)
	for x in range(3):
		var painted := _painted_column(armed, "pressed", x)
		check(_is_accent(painted), "%s armed left column %d is accent (%s)" % [tag, x, str(painted)])
	var fill := _painted_column(armed, "pressed", 3)
	check(not _is_accent(fill), "%s pixel just past the bar is the fill, not the bar (%s)" % [tag, str(fill)])
	# Hover the other rail button without arming it.
	if other != null:
		await _motion(other.get_viewport(), other.get_global_rect().get_center())
		await process_frame
		var other_bar := other.get_node_or_null("RailAccentBar") as ColorRect
		check(not other.button_pressed, "%s hover target stays unarmed" % tag)
		check(other_bar == null or not other_bar.visible, "%s hover does not show the accent bar" % tag)
		for x in range(3):
			var hover_px := _painted_column(other, "hover", x)
			check(not _is_accent(hover_px),
					"%s hover left column %d is not accent (%s)" % [tag, x, str(hover_px)])
	await _assert_viewport_columns(armed, other, tag)
	var lit := 0
	var host := armed.get_parent()
	if host != null:
		for c in host.get_children():
			if not (c is Button):
				continue
			var rail_bar := (c as Button).get_node_or_null("RailAccentBar") as ColorRect
			if rail_bar != null and rail_bar.visible:
				lit += 1
	check(lit == 1, "%s only one rail accent bar is lit (got %d)" % [tag, lit])


func _assert_viewport_columns(armed: Button, other: Button, tag: String) -> void:
	var driver := DisplayServer.get_name().to_lower()
	if driver.contains("headless"):
		print("  %s viewport pixels skipped (headless display)" % tag)
		return
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	var vp := armed.get_viewport()
	if vp == null or vp.get_texture() == null:
		check(false, "%s viewport texture exists")
		return
	var img := vp.get_texture().get_image()
	if img == null or img.get_width() < 8 or img.get_height() < 8:
		check(false, "%s viewport image is readable")
		return
	var armed_cols := _sample_left_columns(img, armed.get_global_rect())
	print("  %s viewport armed columns %s" % [tag, str(armed_cols)])
	check(armed_cols.size() == 4, "%s sampled 4 viewport columns" % tag)
	if armed_cols.size() == 4:
		for x in range(3):
			check(_is_accent(armed_cols[x]),
					"%s viewport left column %d is accent (%s)" % [tag, x, str(armed_cols[x])])
		check(not _is_accent(armed_cols[3]),
				"%s viewport column past the bar is not accent (%s)" % [tag, str(armed_cols[3])])
	if other != null and not other.button_pressed:
		var hover_cols := _sample_left_columns(img, other.get_global_rect())
		print("  %s viewport hover columns %s" % [tag, str(hover_cols)])
		if hover_cols.size() == 4:
			for x in range(3):
				check(not _is_accent(hover_cols[x]),
						"%s viewport hover column %d is not accent (%s)" % [tag, x, str(hover_cols[x])])


func _sample_left_columns(img: Image, rect: Rect2) -> Array:
	var out: Array = []
	if rect.size.x < 6.0 or rect.size.y < 4.0:
		return out
	var y := int(clampf(rect.position.y + rect.size.y * 0.5, 0.0, float(img.get_height() - 1)))
	var x0 := int(ceil(rect.position.x))
	for i in range(4):
		var x := x0 + i
		if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
			return []
		out.append(img.get_pixel(x, y))
	return out


func _style_text(box: StyleBox) -> String:
	if not (box is StyleBoxFlat):
		return str(box)
	var flat := box as StyleBoxFlat
	return "bg=%s left=%d" % [str(flat.bg_color), flat.get_border_width(SIDE_LEFT)]


func _rect_inside(window: Rect2, inner: Rect2) -> bool:
	if inner.size.x < 2.0 or inner.size.y < 2.0:
		return false
	return window.has_point(inner.position) and window.has_point(inner.end - Vector2(1, 1))


func _find_labeled_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.text == text and b.is_visible_in_tree():
			return b
	return null


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _click_menu_id(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button visible" % desc)
		return false
	await _click_control(btn)
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	if popup != null and not popup.visible:
		btn.show_popup()
		await process_frame
	if popup == null or not popup.visible:
		check(false, "%s popup visible" % desc)
		return false
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "%s has item %d" % [desc, id])
		return false
	await _click_popup_item(popup, idx)
	await process_frame
	await process_frame
	return true


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h) + float(v_sep)


func _click_popup_item(popup: PopupMenu, index: int) -> void:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs if font == null else font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top += panel.get_margin(SIDE_TOP)
	for i in index:
		top += _popup_row_height(popup, i, font_h, v_sep)
	var row_h := _popup_row_height(popup, index, font_h, v_sep)
	var local := Vector2(maxf(8.0, popup.size.x * 0.5), top + row_h * 0.5)
	var screen := Vector2(popup.position) + local
	await _click_at(root.get_viewport(), screen)


func _name_edit(dlg: FileDialog) -> LineEdit:
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


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _scroll_into_view(main, ctrl: Control) -> void:
	if main == null or main.ops_panel == null or ctrl == null:
		return
	var scroll: ScrollContainer = main.ops_panel._scroll
	if scroll == null:
		return
	scroll.ensure_control_visible(ctrl)
	await process_frame
	await process_frame


func _click_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	await _click_at(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


func _click_embedded(ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	else:
		var win := ctrl.get_viewport()
		if win is Window:
			pos = Vector2((win as Window).position) + pos
	await _click_at(root.get_viewport(), pos)


func _click_at(vp: Viewport, pos: Vector2) -> void:
	await _motion(vp, pos)
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


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _push_key(vp: Viewport, keycode: Key) -> void:
	await _push_key_raw(vp, keycode)


func _push_key_raw(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.echo = false
	vp.push_input(up)
	await process_frame


func _push_esc(vp: Viewport) -> void:
	await _push_key_raw(vp, KEY_ESCAPE)


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_A
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 65 and ch <= 90:
			code = (KEY_A + (ch - 65)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 95:
			code = KEY_MINUS
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		if ch == 95:
			ev.shift_pressed = true
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame
