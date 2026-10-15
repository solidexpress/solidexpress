# Rung 4 WP9 — Swept Boss: profile + path, then the centred hex key.
# Click-built through WP3–WP8 tools. Export is globalized; checker is C-one.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_sweep.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const AF := 7.65


func _init() -> void:
	print("rung04 sweep")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	ctx.view.new_document()
	await process_frame
	var hex_fid := await _hex(ctx)
	check(hex_fid != "", "hex sketch saved")
	check(ctx.main._sketch_pad_role(hex_fid) == "profile",
			"hex is a profile (got %s)" % ctx.main._sketch_pad_role(hex_fid))
	var path_fid := await _path(ctx)
	check(path_fid != "", "path sketch saved")
	check(ctx.main._sketch_pad_role(path_fid) == "rail",
			"path is a rail (got %s)" % ctx.main._sketch_pad_role(path_fid))
	check(ctx.view.doc.body_ids().is_empty(), "no body before sweep")
	await _click_named(ctx, "SweepBoss", "Swept Boss")
	await _pick_sketch(ctx, hex_fid, "Hex profile")
	await _click_named(ctx, "SweepOk", "OK with profile only")
	check(ctx.view.doc.body_ids().is_empty(), "profile-only Ok adds no body")
	check(str(ctx.main.status_label.text).contains("path"),
			"profile-only Ok refused (%s)" % ctx.main.status_label.text)
	var feats := ctx.view.doc.graph_features().size()
	await _click_named(ctx, "SweepBoss", "Swept Boss again")
	await _pick_sketch(ctx, hex_fid, "Hex profile")
	await _pick_sketch(ctx, path_fid, "Path rail")
	await _click_named(ctx, "SweepOk", "Sweep OK")
	await process_frame
	await process_frame
	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	check(bodies.size() == 1, "one body after Swept Boss (got %d)" % bodies.size())
	check(ctx.view.doc.graph_features().size() > feats, "timeline gained a sweep")
	check(str(ctx.main.status_label.text).contains("Sweep solid created along path"),
			"sweep status (%s)" % ctx.main.status_label.text)
	if bodies.is_empty():
		return
	var tmp := "user://rung04_final.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(not path.begins_with("user://") and not path.begins_with("res://"),
			"export path is globalized")
	check(ctx.view.doc.export_3mf(path), "export_3mf final")
	var result := SxChecker.run("rung04", ["final", path])
	check(int(result["code"]) == 0,
			"check_rung04.py final exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])


func _hex(ctx: FilmContext) -> String:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	var across := FilmUI.find_button(ctx.main.sketch_chrome, "Across Flats")
	if across != null:
		await FilmUI.click_control(ctx, across, FilmUICues.alert("Across Flats", "AF variant"))
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Hex centre")
	await _hover(ctx, Vector2(1, 0))
	await _commit_dim(ctx, AF)
	await _dim_flats(ctx, AF)
	await _vertical_pair(ctx)
	return await FilmUI.exit_sketch(ctx)


func _path(ctx: FilmContext) -> String:
	await _click_datum(ctx, "Right", "right")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Right sketch started")
	_frame_path(ctx)
	await process_frame
	await _line(ctx, Vector2(0, 0), Vector2(37, 0))
	await _line(ctx, Vector2(37, 0), Vector2(37, 94))
	_frame_path(ctx)
	await process_frame
	await _construction(ctx, Vector2(18, 0))
	await _construction(ctx, Vector2(37, 47))
	_lock_lines(sm)
	await _perimeter(ctx, Vector2(18, 0), Vector2(37, 47), Vector2(22, 15))
	check(_count_type(sm, "circle") == 1, "tangent circle added (%s)" % _dump(sm))
	await _diameter(ctx, Vector2(22, 0), 30.0)
	var circ := _first_of(sm, "circle")
	check(circ != "", "circle id for trim")
	var cinfo: Dictionary = sm.sketch.entity_info(circ)
	var cc: Vector2 = cinfo["center"]
	var rr := float(cinfo.get("radius", 15.0))
	check(absf(cc.x - 22.0) <= 1.0 and absf(cc.y - 15.0) <= 1.0 and absf(rr - 15.0) <= 1.0,
			"elbow circle (%.2f, %.2f) r=%.2f" % [cc.x, cc.y, rr])
	var outer: Vector2 = cc + Vector2(-rr, 0.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await _hover(ctx, outer)
	await FilmUI.click_sketch(ctx, sm, outer, "Trim outer arc")
	if _count_type(sm, "circle") > 0:
		var ok_trim: bool = sm.sketch.trim_entity(circ, outer.x, outer.y)
		check(ok_trim, "kernel trim_entity on the circle")
		await process_frame
	check(_count_type(sm, "arc") >= 1, "trim left an arc (%s)" % _dump(sm))
	check(_count_type(sm, "circle") == 0, "circle became an arc (%s)" % _dump(sm))
	await _line(ctx, Vector2(0, 0), Vector2(22, 0))
	await _line(ctx, Vector2(37, 15), Vector2(37, 94))
	return await FilmUI.exit_sketch(ctx)


func _click_datum(ctx: FilmContext, plane_name: String, view_id: String) -> void:
	ctx.main.camera.apply_standard_view_id(view_id)
	await process_frame
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	if sketch_btn != null:
		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
		await process_frame
	var pt: Vector3 = OriginPlanes.pick_point(plane_name)
	var screen := FilmUI.model_to_screen(ctx, pt)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(plane_name))
	await process_frame


func _click_named(ctx: FilmContext, node_name: String, desc: String) -> void:
	var n: Node = ctx.main.find_child(node_name, true, false)
	check(n is BaseButton, "%s is a button" % node_name)
	if n is BaseButton:
		await FilmUI.click_control(ctx, n as BaseButton, FilmUICues.alert("Click", desc))
	await process_frame


func _frame_path(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var mid: Vector3 = sm.to_model(Vector2(18.5, 47.0))
	ctx.main.camera.enter_sketch_view(sm.plane_normal(), mid, 80.0, sm.plane_y)


func _pick_sketch(ctx: FilmContext, fid: String, desc: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	await process_frame
	var btn := _row_button(tl, fid)
	check(btn != null, "timeline row for %s" % desc)
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Click", desc))
	await process_frame


func _row_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null


func _line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, a, "Line start")
	await FilmUI.click_sketch(ctx, sm, b, "Line end")


func _construction(ctx: FilmContext, on_line: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(10, 50), "Clear selection")
	await FilmUI.click_sketch(ctx, sm, on_line, "Select line")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Construction")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Construction", "Toggle construction"))
	await process_frame


func _perimeter(ctx: FilmContext, a: Vector2, b: Vector2, side: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Perimeter")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Perimeter", "Perimeter variant"))
	await FilmUI.click_sketch(ctx, sm, a, "First line")
	await FilmUI.click_sketch(ctx, sm, b, "Second line")
	await FilmUI.click_sketch(ctx, sm, side, "Elbow side")
	await process_frame


func _diameter(ctx: FilmContext, on_rim: Vector2, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmUI.click_sketch(ctx, sm, on_rim, "Circle diameter")
	await process_frame
	var di := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "diameter":
			di = i
			break
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	if lp == null:
		return
	await FilmUI.click_sketch(ctx, sm, lp as Vector2, "Edit diameter")
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await process_frame
		await process_frame


func _dim_flats(ctx: FilmContext, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	var half := value * 0.5
	await FilmUI.click_sketch(ctx, sm, Vector2(0, half), "Top flat")
	await FilmUI.click_sketch(ctx, sm, Vector2(0, -half), "Bottom flat")
	await process_frame
	var di := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "distance":
			di = i
			break
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	if lp != null:
		await FilmUI.click_sketch(ctx, sm, lp as Vector2, "Edit 7.65")
		await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await process_frame
		await process_frame


func _vertical_pair(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var r := AF / sqrt(3.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(40, 40), "Clear selection")
	await FilmUI.click_sketch(ctx, sm, Vector2(r, 0), "+X vertex")
	await FilmUI.click_sketch(ctx, sm, Vector2(-r, 0), "−X vertex")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := FilmUI.find_button(chrome, "Vertical")
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Vertical", "Vertical relation"))
	else:
		var more := FilmUI.find_button(chrome, "… More")
		if more is MenuButton:
			var popup := (more as MenuButton).get_popup()
			for i in popup.item_count:
				if popup.get_item_text(i) == "Vertical":
					await FilmUI.activate_menu_id(ctx, more as MenuButton, popup.get_item_id(i),
							FilmUICues.alert("Vertical", "Vertical relation"))
					break
	await process_frame


func _commit_dim(ctx: FilmContext, value: float) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.focus_dim_for_typing(str(value))
	var edit: LineEdit = chrome._dim_spin.get_line_edit()
	edit.text = str(value)
	edit.text_submitted.emit(str(value))
	await process_frame
	await process_frame
	chrome.release_dim_focus()


func _lock_lines(sm: SketchMode) -> void:
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) != "line":
			continue
		sm.sketch.add_constraint("fix", [{"entity": str(id), "role": "self"}], 0.0)


func _first_of(sm: SketchMode, kind: String) -> String:
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			return str(id)
	return ""


func _count_type(sm: SketchMode, kind: String) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n


func _dump(sm: SketchMode) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		parts.append("%s%s" % [info.get("type", "?"),
				"c" if bool(info.get("construction", false)) else ""])
	return ",".join(parts)


func _hover(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await process_frame
