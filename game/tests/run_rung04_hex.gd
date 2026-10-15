# Rung 4 WP4 — origin AF hex, one driving 7.65, construction inscribed circle.
# Click-built. Commit pose stays flats-horizontal until Vertical.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_hex.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const AF := 7.65


func _init() -> void:
	print("rung04 hex")
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
	await _origin_hex(ctx)
	await _off_origin(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _origin_hex(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await _place_hex(ctx, Vector2.ZERO, AF)
	check(str(sm._last_commit_text).begins_with("Polygon AF"),
			"commit status stays the AF sentence (%s)" % sm._last_commit_text)
	var lines := _profile_lines(sm)
	check(lines.size() == 6, "profile loop is six lines (got %d)" % lines.size())
	check(sm.sketch.contour_count() == 1, "one profile contour")
	var circ := _construction_circle(sm)
	check(not circ.is_empty(), "construction inscribed circle")
	if not circ.is_empty():
		var r := float(sm.sketch.entity_info(circ)["radius"])
		check(absf(r - AF * 0.5) <= 0.02, "circle radius 3.825 (got %.4f)" % r)
	check(_driving_distances(sm) == 0, "no driving distance before Smart Dim")
	await _dim_flats(ctx, AF)
	check(_driving_distances(sm) == 1, "one driving distance (got %d)" % _driving_distances(sm))
	var labelled := _distance_value(sm)
	check(absf(labelled - AF) <= 0.02, "label 7.65 (got %.4f)" % labelled)
	await _vertical_pair(ctx)
	check(sm.last_dofs == 0, "DOF 0 (got %d)" % sm.last_dofs)
	var pts := _profile_points(sm)
	var span_x := _axis(pts, "X") - _axis(pts, "x")
	check(absf(span_x - AF) <= 0.05, "X extent 7.65 (got %.4f)" % span_x)
	var pair := _axis_pair(pts)
	check(pair, "vertices on ±Y")
	check(_profile_lines(sm).size() == 6, "profile still six lines after Vertical")
	var circ2 := _construction_circle(sm)
	check(not circ2.is_empty(), "circle remains construction")
	if not circ2.is_empty():
		check(bool(sm.sketch.entity_info(circ2).get("construction", false)), "circle is construction")


func _off_origin(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm.active:
		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
		if exit_btn != null:
			await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
			await process_frame
	ctx.view.new_document()
	await process_frame
	await FilmUI.enter_sketch(ctx)
	sm = ctx.main.sketch_mode
	await _place_hex(ctx, Vector2(30, 0), AF)
	var anchored := false
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			anchored = true
	check(not anchored, "centre at (30, 0) is not anchored")


func _place_hex(ctx: FilmContext, centre: Vector2, af: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	var across := FilmUI.find_button(ctx.main.sketch_chrome, "Across Flats")
	if across != null:
		await FilmUI.click_control(ctx, across, FilmUICues.alert("Across Flats", "AF variant"))
	await FilmUI.click_sketch(ctx, sm, centre, "Hex centre")
	await _hover(ctx, centre + Vector2(1, 0))
	await _commit_dim(ctx, af)


func _dim_flats(ctx: FilmContext, value: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	var half := value * 0.5
	await FilmUI.click_sketch(ctx, sm, Vector2(0, half), "Top flat")
	await FilmUI.click_sketch(ctx, sm, Vector2(0, -half), "Bottom flat")
	await process_frame
	var di := _distance_index(sm)
	check(di >= 0, "flat-to-flat dimension exists")
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
	# Flats-horizontal vertices sit on ±X until this relation.
	await FilmUI.click_sketch(ctx, sm, Vector2(r, 0), "+X vertex")
	await FilmUI.click_sketch(ctx, sm, Vector2(-r, 0), "−X vertex")
	await _click_vertical(ctx)


func _click_vertical(ctx: FilmContext) -> void:
	await process_frame
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


func _hover(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await process_frame


func _profile_lines(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "line" and not bool(info.get("construction", false)):
			out.append(str(id))
	return out


func _profile_points(sm: SketchMode) -> Array:
	var out: Array = []
	for id in _profile_lines(sm):
		var info: Dictionary = sm.sketch.entity_info(id)
		out.append(info["start"])
		out.append(info["end"])
	return out


func _construction_circle(sm: SketchMode) -> String:
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle" and bool(info.get("construction", false)):
			return str(id)
	return ""


func _driving_distances(sm: SketchMode) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		if str(info.get("type", "")) != "distance":
			continue
		if not bool(info.get("driving", true)):
			continue
		if str(info.get("expr", "")) == "pose-lock":
			continue
		n += 1
	return n


func _distance_index(sm: SketchMode) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "distance":
			return i
	return -1


func _distance_value(sm: SketchMode) -> float:
	var i := _distance_index(sm)
	if i < 0:
		return -1.0
	return float(sm.dimensions[i].get("value", -1.0))


func _axis(pts: Array, which: String) -> float:
	var use_y := which == "y" or which == "Y"
	var want_max := which == "X" or which == "Y"
	var best := 0.0
	var first := true
	for p in pts:
		var v: float = (p as Vector2).y if use_y else (p as Vector2).x
		if first or (want_max and v > best) or (not want_max and v < best):
			best = v
			first = false
	return best


func _axis_pair(pts: Array) -> bool:
	var r := AF / sqrt(3.0)
	var hit := 0
	for p in pts:
		var v: Vector2 = p
		if absf(v.x) <= 0.2 and absf(absf(v.y) - r) <= 0.2:
			hit += 1
	return hit >= 2
