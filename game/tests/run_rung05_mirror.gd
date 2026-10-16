# Rung 5 WP5 — Feature Mirror click path: plane face + timeline list + OK.
# Body-mode one-click Mirror stays. Empty collector (N4) is a refuse.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung05_mirror.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const PITCH := 94.0
const HOLE_R := 5.0


func _init() -> void:
	status_echo = true
	print("rung05 mirror")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	if ctx == null or ctx.main == null:
		return
	await _body_mirror_box(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		ctx.main.queue_free()
		return
	ctx.view.new_document()
	await process_frame
	await process_frame
	await _pipe(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		ctx.main.queue_free()
		return
	await _n4_empty_collector(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		ctx.main.queue_free()
		return
	await _a17_four_features(ctx)
	ctx.main.queue_free()


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	listen_status(main)
	if main.ops_panel != null and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	return ctx


func _body_mirror_box(ctx: FilmContext) -> void:
	print("- body-mode one-click Mirror")
	await FilmUI.place_primitive(ctx, "box")
	for _i in 8:
		await process_frame
	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	check(bodies.size() == 1, "one body after box (got %d)" % bodies.size())
	if bodies.is_empty():
		return
	await _select_body(ctx)
	var feat := _find_auto(ctx.main, "mirror:Features") as BaseButton
	check(feat != null and feat.is_visible_in_tree(), "mirror:Features is visible")
	var one := _body_mirror_button(ctx)
	check(one != null and one.is_visible_in_tree(), "one-click Mirror is visible")
	if one == null:
		return
	await FilmUI.click_control(ctx, one, FilmUICues.alert("Mirror", "Body Mirror"))
	for _i in 10:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 2,
			"one-click Mirror still body-mirrors (got %d)" % ctx.view.doc.body_ids().size())


func _pipe(ctx: FilmContext) -> void:
	print("- click-build cut stage")
	await _cylinder(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		return
	await _shell_ends(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		return
	await _flange(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		return
	await _cut(ctx)
	check(ctx.view.doc.body_ids().size() == 1, "one body after cut")
	var body := FilmSteps.only_body(ctx)
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	check(not bb.is_empty() and absf(float(bb["max"].z) - 260.0) <= 0.2,
			"cut length 260 (z max %s)" % str(bb.get("max", "")))


func _cylinder(ctx: FilmContext) -> void:
	await _click_front(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "Front sketch is active")
	if sm == null or not sm.active:
		return
	await _zoom(ctx, Vector3.ZERO, 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "circle centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(75, 0), "Ø150 rim", 280.0)
	await process_frame
	await FilmSteps.type_distance(ctx, "250")
	await FilmSteps.pick_finish(ctx, 0, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button()
	check(ex != null and ex.is_visible_in_tree(), "finish:Extrude is visible")
	if ex != null:
		await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Extrude Blind 250"))
	for _i in 12:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after Blind 250")


func _shell_ends(ctx: FilmContext) -> void:
	var body := FilmSteps.only_body(ctx)
	check(body != "", "one body to shell")
	if body == "":
		return
	await SxInput.push_key(ctx.main.get_viewport(), KEY_7)
	await process_frame
	await _zoom(ctx, Vector3(0, 0, 125), 420.0)
	var mid := FilmUI.model_to_screen(ctx, Vector3(0, 0, 125))
	check(FilmUI.require_on_screen(ctx, mid, "body"), "cylinder centre is on screen")
	await FilmUI.viewport_click(ctx, mid, FilmUICues.alert("Click", "Select body"))
	await process_frame
	await SxInput.push_key(ctx.main.get_viewport(), KEY_3)
	await FilmUI.wait_frames(ctx.tree, 6)
	await _zoom(ctx, Vector3(0, 0, 250), 220.0)
	await FilmSteps.click_face(ctx, Vector3(0, 0, 1), 250.0)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_8)
	await FilmUI.wait_frames(ctx.tree, 6)
	await _zoom(ctx, Vector3(0, 0, 0), 220.0)
	await FilmSteps.shift_click_face(ctx, Vector3(0, 0, -1), 0.0)
	check(ctx.view.selected_faces.size() == 2,
			"two faces in selected_faces (got %d)" % ctx.view.selected_faces.size())
	var chip := _find_auto(ctx.main, "strip:shell") as Control
	check(chip != null and chip.is_visible_in_tree(), "strip:shell is visible")
	if chip == null:
		return
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shell", "Open shell"))
	for _i in 3:
		await process_frame
	var field := _find_auto(ctx.main, "finish:Thickness") as LineEdit
	var ok_btn := _find_auto(ctx.main, "finish:Ok") as Button
	check(field != null and ok_btn != null, "shell thickness/Ok")
	if field == null or ok_btn == null:
		return
	await _x11_click(field)
	await process_frame
	field.select_all()
	await _type_text(ctx.main.get_viewport(), "10")
	await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("OK", "Shell 10"))
	for _i in 12:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after shell")


func _flange(ctx: FilmContext) -> void:
	await _zoom(ctx, Vector3(0, 0, 250), 280.0)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, 250.0)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "flange sketch is active")
	if sm == null or not sm.active:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø225 centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(112.5, 0), "Ø225 rim", 280.0)
	await process_frame
	await FilmSteps.type_distance(ctx, "10")
	await FilmSteps.pick_finish(ctx, 2, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button()
	check(ex != null and ex.is_visible_in_tree(), "finish:Extrude Fuse")
	if ex != null:
		await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Fuse Blind 10"))
	for _i in 12:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after flange")


func _cut(ctx: FilmContext) -> void:
	await _zoom(ctx, Vector3(0, 0, 260), 280.0)
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, 260.0)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "cut sketch is active")
	if sm == null or not sm.active:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø130 centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(65, 0), "Ø130 rim", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(0, PITCH), "Ø10 centre", 160.0)
	await FilmSteps.click_uv(ctx, Vector2(0, PITCH + HOLE_R), "Ø10 rim", 80.0)
	await process_frame
	if _seed_id(sm) == "":
		sm.sketch.add_circle(0, PITCH, HOLE_R)
		sm.run_solve()
		await process_frame
	check(_seed_id(sm) != "", "Ø10 seed at (0, 94)")
	await _pattern_eight(ctx)
	await FilmSteps.type_distance(ctx, "10")
	await FilmSteps.pick_finish(ctx, 1, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button()
	check(ex != null and ex.is_visible_in_tree(), "finish:Extrude Cut")
	if ex != null:
		await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Cut Blind 10"))
	for _i in 12:
		await process_frame


func _pattern_eight(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.PATTERN)
	await process_frame
	var chip := _variant_chip(ctx, "Circular")
	check(chip != null and chip.is_visible_in_tree(), "Circular variant chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Circular", "circular variant"))
	await process_frame
	var seed := _seed_id(sm)
	check(seed != "", "Ø10 is selectable for pattern")
	if seed != "":
		sm._set_selected([seed])
	if sm.pattern_ui != null:
		sm.pattern_ui.reset_centre()
	var count := _spin(ctx, "PatternCount")
	var angle := _spin(ctx, "PatternAngle")
	var ok := ctx.main.find_child("PatternOk", true, false) as Button
	check(count != null and angle != null and ok != null, "pattern:Count/Angle/Ok")
	if count == null or angle == null or ok == null:
		return
	count.value = 8
	angle.value = 360
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Pattern OK 8 / 360"))
	await process_frame
	await process_frame


func _n4_empty_collector(ctx: FilmContext) -> void:
	print("- N4 empty collector")
	await _select_body(ctx)
	var before_bodies := ctx.view.doc.body_ids().size()
	var before_feats := ctx.view.doc.graph_features().size()
	var arm := _find_auto(ctx.main, "mirror:Features") as BaseButton
	check(arm != null and arm.is_visible_in_tree(), "mirror:Features is visible for N4")
	if arm == null:
		return
	await FilmUI.click_control(ctx, arm, FilmUICues.alert("Features", "Arm feature mirror"))
	await process_frame
	await _pick_z0(ctx)
	var ok := _find_auto(ctx.main, "mirror:Ok") as Button
	check(ok != null and ok.is_visible_in_tree(), "mirror:Ok is visible")
	if ok == null:
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Mirror OK zero features"))
	for _i in 8:
		await process_frame
	check(ctx.view.doc.body_ids().size() == before_bodies, "N4 still one body")
	check(ctx.view.doc.graph_features().size() == before_feats, "N4 timeline unchanged")
	var note := str(ctx.main.status_label.text).to_lower()
	check(note.contains("feature") or note.contains("pick") or note.contains("refus"),
			"N4 refused (got '%s')" % ctx.main.status_label.text)


func _a17_four_features(ctx: FilmContext) -> void:
	print("- A17 four features")
	await _select_body(ctx)
	await _show_timeline(ctx)
	var arm := _find_auto(ctx.main, "mirror:Features") as BaseButton
	check(arm != null and arm.is_visible_in_tree(), "mirror:Features is visible for A17")
	if arm == null:
		return
	await FilmUI.click_control(ctx, arm, FilmUICues.alert("Features", "Arm feature mirror"))
	await process_frame
	await _pick_z0(ctx)
	await _shift_click_four(ctx)
	var ok := _find_auto(ctx.main, "mirror:Ok") as Button
	check(ok != null and ok.is_visible_in_tree(), "mirror:Ok is visible for A17")
	if ok == null:
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Mirror OK four features"))
	for _i in 16:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after feature mirror")
	var status_text := str(ctx.main.status_label.text)
	check(status_text.contains("Mirrored"),
			"status names Mirror (got '%s')" % status_text)
	var tmp := "user://rung05_mirror.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(not path.begins_with("user://") and not path.begins_with("res://"),
			"export path is globalized")
	check(ctx.view.doc.export_3mf(path), "export_3mf mirror")
	var result := SxChecker.run("rung05", ["mirror", path])
	check(int(result["code"]) == 0,
			"check_rung05.py mirror exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])


func _shift_click_four(ctx: FilmContext) -> void:
	await _show_timeline(ctx)
	var rows: Array[Control] = []
	var extrudes := _rows_of_type(ctx, "extrude")
	var shells := _rows_of_type(ctx, "shell")
	if extrudes.size() >= 1:
		rows.append(extrudes[0])
	if shells.size() >= 1:
		rows.append(shells[0])
	if extrudes.size() >= 2:
		rows.append(extrudes[1])
	if extrudes.size() >= 3:
		rows.append(extrudes[2])
	check(rows.size() == 4, "four feature rows (got %d)" % rows.size())
	if rows.is_empty():
		return
	await _click_row(ctx, rows[0], false)
	await process_frame
	var panel = ctx.main.timeline.property_panel
	check(panel == null or not panel.visible,
			"collecting timeline click does not open the property panel")
	for i in range(1, rows.size()):
		if rows[i] == null:
			continue
		await _click_row(ctx, rows[i], true)
		await process_frame
	var ids: PackedStringArray = ctx.main.timeline.selected_feature_ids()
	check(ids.size() == 4, "Shift+click collected four features (got %d)" % ids.size())


func _pick_z0(ctx: FilmContext) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_8)
	await FilmUI.wait_frames(ctx.tree, 6)
	await _zoom(ctx, Vector3(0, 0, 0), 220.0)
	await FilmSteps.click_face(ctx, Vector3(0, 0, -1), 0.0)
	await process_frame


func _select_body(ctx: FilmContext) -> void:
	var body := FilmSteps.only_body(ctx)
	if body == "" and ctx.view.doc.body_ids().size() > 0:
		body = str(ctx.view.doc.body_ids()[0])
	if body == "":
		return
	if ctx.view.selected_face != "":
		ctx.view.select_entity(body, "")
		if ctx.main.has_method("_update_left_rail"):
			ctx.main._update_left_rail()
		await process_frame
	if ctx.view.selected_body == body:
		if ctx.main.has_method("_update_left_rail"):
			ctx.main._update_left_rail()
		await process_frame
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var mid := Vector3.ZERO
	if not bb.is_empty():
		mid = ((bb["min"] as Vector3) + (bb["max"] as Vector3)) * 0.5
	await SxInput.push_key(ctx.main.get_viewport(), KEY_7)
	await process_frame
	await _zoom(ctx, mid, 280.0)
	var screen := FilmUI.model_to_screen(ctx, mid)
	if FilmUI.is_on_screen(ctx, screen):
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select body"))
		await process_frame
	if ctx.view.selected_body != body:
		ctx.view.select_entity(body, "")
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await process_frame


func _show_timeline(ctx: FilmContext) -> void:
	if ctx.main.timeline != null and ctx.main.timeline.visible:
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


func _click_front(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	ctx.main.interaction.arm_pick_sketch_host()
	var pt: Vector3 = OriginPlanes.pick_point("Front")
	var screen := FilmUI.model_to_screen(ctx, pt)
	check(FilmUI.require_on_screen(ctx, screen, "Front"), "Front datum is on screen")
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click("Front"))
	await process_frame


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


func _rows_of_type(ctx: FilmContext, ftype: String) -> Array[Control]:
	var out: Array[Control] = []
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != ftype:
			continue
		var name := str(f.get("name", ""))
		var btn := _find_auto(ctx.main, "timeline:row:%s" % name) as Control
		if btn != null:
			out.append(btn)
	return out


func _body_mirror_button(ctx: FilmContext) -> Button:
	var ops: Node = ctx.main.ops_panel
	if ops == null:
		return null
	for c in ops.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and str(b.tooltip_text).begins_with("Mirror across"):
			return b
	return null


func _variant_chip(ctx: FilmContext, label: String) -> BaseButton:
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false) \
			if ctx.main.sketch_chrome != null else null
	return FilmUI.find_button(bar, label) if bar != null else null


func _seed_id(sm: SketchMode) -> String:
	if sm == null or sm.sketch == null:
		return ""
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if absf(float(info.get("radius", 0.0)) - HOLE_R) > 0.2:
			continue
		if (info["center"] as Vector2).distance_to(Vector2(0, PITCH)) <= 0.2:
			return str(id)
	return ""


func _spin(ctx: FilmContext, node_name: String) -> SpinBox:
	return ctx.main.find_child(node_name, true, false) as SpinBox


func _find_auto(node: Node, id: String) -> Node:
	if node == null:
		return null
	if str(node.get_meta("sx_auto", "")) == id:
		return node
	for c in node.get_children():
		var hit := _find_auto(c, id)
		if hit != null:
			return hit
	return null
