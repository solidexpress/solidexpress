## Click-built hex key (rung 4): origin AF hex, Right-plane path, Swept Boss.
class_name HexKeyFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const AF := 7.65


static func place_hex(ctx: FilmContext) -> String:
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


static func place_path(ctx: FilmContext) -> String:
	await _click_datum(ctx, "Right", "right")
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("Right sketch did not start")
		return ""
	_frame_path(ctx)
	await ctx.tree.process_frame
	await _line(ctx, Vector2(0, 0), Vector2(37, 0))
	await _line(ctx, Vector2(37, 0), Vector2(37, 94))
	_frame_path(ctx)
	await ctx.tree.process_frame
	await _construction(ctx, Vector2(18, 0))
	await _construction(ctx, Vector2(37, 47))
	_lock_lines(sm)
	await _perimeter(ctx, Vector2(18, 0), Vector2(37, 47), Vector2(22, 15))
	var circ := _first_of(sm, "circle")
	if circ == "":
		FilmUI._fail("path circle missing")
		return ""
	await _diameter(ctx, Vector2(22, 0), 30.0)
	var cinfo: Dictionary = sm.sketch.entity_info(circ)
	var cc: Vector2 = cinfo["center"]
	var rr := float(cinfo.get("radius", 15.0))
	var outer: Vector2 = cc + Vector2(-rr, 0.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await _hover(ctx, outer)
	await FilmUI.click_sketch(ctx, sm, outer, "Trim outer arc")
	if _count_type(sm, "circle") > 0:
		sm.sketch.trim_entity(circ, outer.x, outer.y)
		await ctx.tree.process_frame
	await _line(ctx, Vector2(0, 0), Vector2(22, 0))
	await _line(ctx, Vector2(37, 15), Vector2(37, 94))
	return await FilmUI.exit_sketch(ctx)


static func sweep(ctx: FilmContext, hex_fid: String, path_fid: String) -> void:
	await _click_named(ctx, "SweepBoss", "Swept Boss")
	await _pick_sketch(ctx, hex_fid, "Hex profile")
	await _pick_sketch(ctx, path_fid, "Path rail")
	await _click_named(ctx, "SweepOk", "Sweep OK")
	await ctx.tree.process_frame
	await ctx.tree.process_frame


static func check_final(doc: SxDocument) -> Dictionary:
	var tmp := OS.get_temp_dir().path_join("sx-film-hexkey-check.3mf")
	var glob := ProjectSettings.globalize_path(tmp) if tmp.begins_with("user://") or tmp.begins_with("res://") else tmp
	var exported := doc.export_3mf(glob)
	var result := SxChecker.run("rung04", ["final", glob]) if exported else {"code": 1, "text": "export failed"}
	return {"path": glob, "exported": exported, "code": int(result["code"]), "text": str(result["text"])}


static func _click_datum(ctx: FilmContext, plane_name: String, view_id: String) -> void:
	ctx.main.camera.apply_standard_view_id(view_id)
	await ctx.tree.process_frame
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	if sketch_btn != null:
		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
		await ctx.tree.process_frame
	var pt: Vector3 = OriginPlanes.pick_point(plane_name)
	var screen := FilmUI.model_to_screen(ctx, pt)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(plane_name))
	await ctx.tree.process_frame


static func _click_named(ctx: FilmContext, node_name: String, desc: String) -> void:
	var n: Node = ctx.main.find_child(node_name, true, false)
	if n is BaseButton:
		await FilmUI.click_control(ctx, n as BaseButton, FilmUICues.alert("Click", desc))
	await ctx.tree.process_frame


static func _frame_path(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var mid: Vector3 = sm.to_model(Vector2(18.5, 47.0))
	ctx.main.camera.enter_sketch_view(sm.plane_normal(), mid, 80.0, sm.plane_y)


static func _pick_sketch(ctx: FilmContext, fid: String, desc: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await ctx.tree.process_frame
	await ctx.tree.process_frame
	var row: Control = tl._rows.get(fid)
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str(child.text) != "":
				btn = child as Button
				break
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Click", desc))
	await ctx.tree.process_frame


static func _line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, a, "Line start")
	await FilmUI.click_sketch(ctx, sm, b, "Line end")


static func _construction(ctx: FilmContext, on_line: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(10, 50), "Clear selection")
	await FilmUI.click_sketch(ctx, sm, on_line, "Select line")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Construction")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Construction", "Toggle construction"))
	await ctx.tree.process_frame


static func _perimeter(ctx: FilmContext, a: Vector2, b: Vector2, side: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Perimeter")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Perimeter", "Perimeter variant"))
	await FilmUI.click_sketch(ctx, sm, a, "First line")
	await FilmUI.click_sketch(ctx, sm, b, "Second line")
	await FilmUI.click_sketch(ctx, sm, side, "Elbow side")
	await ctx.tree.process_frame


static func _diameter(ctx: FilmContext, on_rim: Vector2, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmUI.click_sketch(ctx, sm, on_rim, "Circle diameter")
	await ctx.tree.process_frame
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
	await ctx.tree.process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await ctx.tree.process_frame
		await ctx.tree.process_frame


static func _dim_flats(ctx: FilmContext, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	var half := value * 0.5
	await FilmUI.click_sketch(ctx, sm, Vector2(0, half), "Top flat")
	await FilmUI.click_sketch(ctx, sm, Vector2(0, -half), "Bottom flat")
	await ctx.tree.process_frame
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
		await ctx.tree.process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		ix._dim_edit_line.text = str(value)
		ix._dim_edit_line.text_submitted.emit(str(value))
		await ctx.tree.process_frame
		await ctx.tree.process_frame


static func _vertical_pair(ctx: FilmContext) -> void:
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
	await ctx.tree.process_frame


static func _commit_dim(ctx: FilmContext, value: float) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.focus_dim_for_typing(str(value))
	var edit: LineEdit = chrome._dim_spin.get_line_edit()
	edit.text = str(value)
	edit.text_submitted.emit(str(value))
	await ctx.tree.process_frame
	await ctx.tree.process_frame
	chrome.release_dim_focus()


static func _lock_lines(sm: SketchMode) -> void:
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) != "line":
			continue
		sm.sketch.add_constraint("fix", [{"entity": str(id), "role": "self"}], 0.0)


static func _first_of(sm: SketchMode, kind: String) -> String:
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			return str(id)
	return ""


static func _count_type(sm: SketchMode, kind: String) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n


static func _hover(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await ctx.tree.process_frame
