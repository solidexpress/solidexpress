# Rung 3 WP7 — SectionPlane: HUD id, Top preset, cap colour, state, K.
# Click-built base box. On main, K cuts +X with no plane choice or cap.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung03_section.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung03 section")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await Tutor1Fixture.boot(self, ROOT_SIZE, _on_status_local, ["interaction"])
	check(root.size == ROOT_SIZE, "root is 1280×800")
	await _no_bodies_refuses(ctx)
	if not await _build_base(ctx):
		ctx.main.queue_free()
		return
	await _section_top_and_cap(ctx)
	await _k_restores_last_plane(ctx)
	await _k_default_plus_x(ctx)
	await _shell_last_thickness_and_k(ctx)
	ctx.main.queue_free()


func _no_bodies_refuses(ctx: FilmContext) -> void:
	print("- Section with no bodies refuses")
	var hud: ViewHud = ctx.main.view_hud
	var btn: Button = ctx.main.find_child("Section", true, false) as Button
	check(btn != null, "hud:Section button exists")
	check(str(btn.get_meta("sx_auto", "")) == "hud:Section", "Section has id hud:Section")
	check(ctx.view.doc.body_ids().is_empty(), "document starts empty")
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Section", "Section view"))
	await process_frame
	await process_frame
	check(not ctx.view.section_enabled, "section stays off with no bodies")
	check(not btn.button_pressed, "Section button unpressed after refuse")
	var status_text := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	check(status_text.contains("Section: no bodies"),
			"no-bodies status (got '%s')" % status_text)
	var popup: PopupMenu = ctx.main.find_child("SectionPlanePopup", true, false) as PopupMenu
	check(popup == null or not popup.visible, "plane popup not left open")
	hud.sync_from_view(ctx.view)


func _build_base(ctx: FilmContext) -> bool:
	print("- build 120×120×30 base")
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return false
	await _zoom(ctx, Vector3.ZERO, 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	var chip: Button = null
	if bar != null:
		for c in bar.get_children():
			if c is Button and (c as Button).text == "Center":
				chip = c
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center", "Center")):
		return false
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(60, 60))
	await FilmSteps.type_distance(ctx, "30")
	await FilmSteps.pick_finish(ctx, 0, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button() if ctx.main.sketch_chrome != null else null
	if ex == null:
		return false
	await _x11_click(ex)
	for _i in 10:
		await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(ids.size() == 1, "one body after extrude")
	return ids.size() == 1


func _section_top_and_cap(ctx: FilmContext) -> void:
	print("- hud:Section → popup:Top")
	await _push_key(ctx.main.get_viewport(), KEY_7, 0)
	await process_frame
	await process_frame
	var btn: Button = ctx.main.find_child("Section", true, false) as Button
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Section", "Section view"))
	await process_frame
	var popup: PopupMenu = ctx.main.find_child("SectionPlanePopup", true, false) as PopupMenu
	check(popup != null and popup.visible, "Section plane popup is open")
	if popup == null or not popup.visible:
		return
	var top_idx := -1
	for i in popup.item_count:
		if str(popup.get_item_text(i)) == "Top":
			top_idx = i
			break
	check(top_idx >= 0, "popup:Top item exists")
	if top_idx < 0:
		return
	await _click_popup_item(ctx, popup, top_idx)
	await process_frame
	await process_frame
	check(ctx.view.section_enabled, "section on after Top")
	check(str(ctx.view.section_plane_name) == "Top", "plane is Top")
	check(btn.button_pressed, "Section button pressed")
	var n := ctx.view.section_normal()
	check(absf(n.x) < 0.01 and absf(n.z) < 0.01 and absf(absf(n.y) - 1.0) < 0.01,
			"normal is ±Y (got %s)" % str(n))
	var cam: Camera3D = ctx.main.get_viewport().get_camera_3d()
	var cam_pos: Vector3 = cam.global_position if cam != null else Vector3(100, 100, 100)
	var cam_model: Vector3 = ctx.view.to_local(cam_pos)
	var kept := SectionPlane.kept_side(cam_model, Vector3.ZERO, Vector3(0, 1, 0))
	check(n.is_equal_approx(kept), "kept half is away from the camera")
	var status_text := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	var joined := " | ".join(_status_log)
	check(status_text.contains("Section Top") or joined.contains("Section Top"),
			"status names Top (got '%s' / '%s')" % [status_text, joined])
	await _assert_cap_pixels(ctx, true)
	# Second click turns off.
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Section", "Section off"))
	await process_frame
	await process_frame
	check(not ctx.view.section_enabled, "section off after second click")
	check(not btn.button_pressed, "Section button released")
	check(str(ctx.view.section_plane_name) == "Top", "plane name kept after clear")
	await _assert_cap_pixels(ctx, false)


func _k_restores_last_plane(ctx: FilmContext) -> void:
	print("- K restores last plane Top")
	var btn: Button = ctx.main.find_child("Section", true, false) as Button
	check(str(ctx.view.section_plane_name) == "Top", "last plane is Top before K")
	await _push_key(ctx.main.get_viewport(), KEY_K, 0)
	await process_frame
	await process_frame
	check(ctx.view.section_enabled, "K turns section on")
	check(str(ctx.view.section_plane_name) == "Top", "K keeps Top")
	var n := ctx.view.section_normal()
	check(absf(absf(n.y) - 1.0) < 0.01, "K Top normal ±Y")
	ctx.main.view_hud.sync_from_view(ctx.view)
	check(btn.button_pressed, "HUD button follows K on")
	await _push_key(ctx.main.get_viewport(), KEY_K, 0)
	await process_frame
	await process_frame
	check(not ctx.view.section_enabled, "K turns section off")
	ctx.main.view_hud.sync_from_view(ctx.view)
	check(not btn.button_pressed, "HUD button follows K off")


func _k_default_plus_x(ctx: FilmContext) -> void:
	print("- K with no named plane uses +X through AABB centre")
	ctx.view.section_plane_name = ""
	if ctx.view.section_enabled:
		ctx.view.clear_section_plane()
	await process_frame
	await _push_key(ctx.main.get_viewport(), KEY_K, 0)
	await process_frame
	await process_frame
	check(ctx.view.section_enabled, "default K enables section")
	check(str(ctx.view.section_plane_name) == "", "default K leaves plane name empty")
	var n := ctx.view.section_normal()
	check(n.is_equal_approx(Vector3(1, 0, 0)), "default normal +X (got %s)" % str(n))
	var p := ctx.view.section_point()
	check(absf(p.x) < 0.5 and absf(p.y) < 0.5 and absf(p.z - 15.0) < 1.0,
			"default point near AABB centre (got %s)" % str(p))
	await _push_key(ctx.main.get_viewport(), KEY_K, 0)
	await process_frame


func _shell_last_thickness_and_k(ctx: FilmContext) -> void:
	print("- shell 1 mm releases focus; refusal restores 1; K still toggles")
	if ctx.view.section_enabled:
		ctx.view.clear_section_plane()
		await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	check(not ids.is_empty(), "body exists for shell")
	if ids.is_empty():
		return
	var body := str(ids[0])
	var face := ""
	for fid in ctx.view.doc.get_face_ids(body):
		var n: Vector3 = ctx.view.face_normal(body, str(fid))
		if n.length_squared() < 1e-8:
			continue
		if n.normalized().dot(Vector3(0, 0, 1)) > 0.99:
			face = str(fid)
			break
	check(face != "", "planar top face for shell")
	if face == "":
		return
	await FilmUI.select_face(ctx, body, face)
	if ctx.view.selected_face != face:
		return
	var chip: Button = ctx.main.find_child("StripShell", true, false) as Button
	check(chip != null and chip.is_visible_in_tree(), "Shell chip is visible")
	if chip == null or not chip.is_visible_in_tree():
		return
	await _x11_click(chip)
	await process_frame
	var field: LineEdit = ctx.main.find_child("ThicknessLineEdit", true, false) as LineEdit
	check(field != null and field.is_visible_in_tree(), "thickness field is open")
	if field == null:
		return
	field.text = "1"
	field.text_submitted.emit("1")
	await process_frame
	await process_frame
	var joined := " | ".join(_status_log)
	check(joined.contains("Shell 1.0000 mm applied"), "shell 1 mm applied (got '%s')" % joined)
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	check(owner != field, "thickness field released focus (owner %s)" % str(owner))
	var was := ctx.view.section_enabled
	await _push_key(ctx.main.get_viewport(), KEY_K, 0)
	await process_frame
	await process_frame
	check(ctx.view.section_enabled != was, "K toggles section after shell")
	# The walk's L7 sample is this wall, after a real 1 mm shell, with Top on.
	if ctx.view.section_enabled:
		ctx.view.clear_section_plane()
		await process_frame
	await _push_key(ctx.main.get_viewport(), KEY_7, 0)
	await process_frame
	var btn_top: Button = ctx.main.find_child("Section", true, false) as Button
	await FilmUI.click_control(ctx, btn_top, FilmUICues.alert("Section", "Section view"))
	await process_frame
	var popup: PopupMenu = ctx.main.find_child("SectionPlanePopup", true, false) as PopupMenu
	if popup != null and popup.visible:
		var top_idx := -1
		for i in popup.item_count:
			if str(popup.get_item_text(i)) == "Top":
				top_idx = i
				break
		if top_idx >= 0:
			await _click_popup_item(ctx, popup, top_idx)
			await process_frame
			await process_frame
	check(ctx.view.section_enabled and str(ctx.view.section_plane_name) == "Top",
			"Top section on the 1 mm shell")
	await _assert_cap_pixels(ctx, true)
	var btn: Button = ctx.main.find_child("Section", true, false) as Button
	if btn != null and ctx.main.view_hud != null:
		ctx.main.view_hud.sync_from_view(ctx.view)
		check(btn.button_pressed == ctx.view.section_enabled, "HUD button follows K after shell")
	await _x11_click(chip)
	await process_frame
	field.text = "30"
	field.text_submitted.emit("30")
	await process_frame
	await process_frame
	check(field.text == "1", "refused 30 mm restores last thickness 1 (got '%s')" % field.text)


func _assert_cap_pixels(ctx: FilmContext, section_on: bool) -> void:
	var driver := DisplayServer.get_name().to_lower()
	if driver.contains("headless"):
		print("  cap pixels skipped (headless display)")
		return
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	var vp: Viewport = ctx.main.get_viewport()
	if vp == null or vp.get_texture() == null:
		check(false, "viewport texture exists for cap sample")
		return
	var img: Image = vp.get_texture().get_image()
	if img == null:
		check(false, "viewport image readable")
		return
	# Wall point on the cut. Iso (key 7) sits on model −Y, so the removed
	# half is negative Y — (0, +40, 15) is the kept body.
	var wall := FilmUI.model_to_screen(ctx, Vector3(-59.5, 0.0, 12.0))
	var removed := FilmUI.model_to_screen(ctx, Vector3(0.0, -40.0, 15.0))
	var wall_c := _sample(img, wall)
	var rem_c := _sample(img, removed)
	print("  wall pixel %s removed pixel %s" % [str(wall_c), str(rem_c)])
	if section_on:
		var cap := SectionPlane.CAP_COLOUR
		check(_near_colour(wall_c, cap, 6.0 / 255.0),
				"wall at cut is CAP_COLOUR (got %s want %s)" % [str(wall_c), str(cap)])
		# Removed half should be background-ish (dark clear), not body metal.
		check(wall_c.r + wall_c.g + wall_c.b > 0.2, "cap sample is lit")
		check(rem_c.r + rem_c.g + rem_c.b < wall_c.r + wall_c.g + wall_c.b,
				"removed half darker than cap")
	else:
		check(not _near_colour(wall_c, SectionPlane.CAP_COLOUR, 6.0 / 255.0),
				"wall is normal shading when section off")


func _sample(img: Image, screen: Vector2) -> Color:
	var x := clampi(int(screen.x), 0, img.get_width() - 1)
	var y := clampi(int(screen.y), 0, img.get_height() - 1)
	return img.get_pixel(x, y)


func _near_colour(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _click_popup_item(ctx: FilmContext, popup: PopupMenu, idx: int) -> void:
	# push_input on the popup never reaches Window._input_from_window, so the
	# row does not activate. The automation bridge forwards the click through
	# the embedder; that is the path the walk uses for popup:Top.
	var label := popup.get_item_text(idx)
	var bridge = ctx.main.get_node_or_null("AutomationBridge")
	var owned := false
	if bridge == null:
		bridge = load("res://scripts/automation_bridge.gd").new()
		bridge.name = "AutomationBridge"
		ctx.main.add_child(bridge)
		owned = true
	var res: Dictionary = await bridge._cmd_pointer({"target": "popup:%s" % label}, "click")
	print("  popup:%s %s" % [label, str(res)])
	if owned and is_instance_valid(bridge):
		bridge.queue_free()
	await process_frame


func _on_status_local(text: String) -> void:
	Tutor1Fixture.note(_status_log, text)
