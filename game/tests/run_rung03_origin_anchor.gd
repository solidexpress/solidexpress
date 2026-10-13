# Rung 3 WP2 — a centre rectangle or circle drawn on the sketch origin is anchored.
# Click-built. On main the origin cases stay at DOF 2 after their two driving dims.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung03_origin_anchor.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const CENTRE_TOL := 0.05


func _init() -> void:
	status_echo = true
	print("rung03 origin anchor")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	await _case("centre rect at origin", _centre_rect_origin)
	await _case("centre circle at origin", _centre_circle_origin)
	await _case("centre rect offset", _centre_rect_offset)
	await _case("circle offset", _circle_offset)
	await _case("corner rect", _corner_rect)
	await _case("infer off circle", _infer_off_circle)
	await _case("infer off rect", _infer_off_rect)


func _centre_rect_origin(ctx: FilmContext) -> void:
	if not await _arm_rect(ctx, "Center"):
		return
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(60, 60))
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(_profile_lines(sm) == 4, "centre rect has four profile lines (got %d)" % _profile_lines(sm))
	var centre := _line_bbox_centre(sm)
	print("  rect centre %s dof before dims %s" % [str(centre), str(sm.last_dofs)])
	check(centre.distance_to(Vector2.ZERO) <= CENTRE_TOL, "centre rect is on the origin (got %s)" % str(centre))
	if not await _dim_line_to(ctx, Vector2(0, 60), "120"):
		return
	if not await _dim_line_to(ctx, Vector2(60, 40), "120"):
		return
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		print("  dim %d type=%s ids=%s label_pos=%s text=%s" % [
			i, str(dim.get("type", "")), str(dim.get("ids", [])),
			str(dim.get("label_pos", null)), sm._dimension_label_text(dim)])
	var label_rects: Array = sm.dimension_label_screen_rects()
	print("  dimension records %d screen rects %d" % [sm.dimensions.size(), label_rects.size()])
	check(sm.dimensions.size() == 2, "two dimension records (got %d)" % sm.dimensions.size())
	check(label_rects.size() == 2, "two dimension label rects (got %d)" % label_rects.size())
	check(_driving_sides(sm) == 2, "two driving side lengths (%d)" % _driving_sides(sm))
	_expect_dof(ctx, true, "centre rect origin after 120 and 120")
	check(_label_has(sm, "120"), "labels include 120 (%s)" % _label_texts(sm))
	check(_profile_lines(sm) == 4, "centre rect stays four profile lines (got %d)" % _profile_lines(sm))
	check(_outline_count(sm) == 1, "centre rect is one profile loop (got %d)" % _outline_count(sm))


func _centre_circle_origin(ctx: FilmContext) -> void:
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.CIRCLE)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.tool_variant == "center", "circle variant is center (got %s)" % sm.tool_variant)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(35, 0))
	await process_frame
	var circles := _circles(sm)
	check(circles.size() == 1, "one circle (got %d)" % circles.size())
	if circles.size() != 1:
		return
	var c: Vector2 = circles[0]["center"]
	print("  circle centre %s r %s" % [str(c), str(circles[0]["radius"])])
	check(c.distance_to(Vector2.ZERO) <= CENTRE_TOL, "circle centre is the origin (got %s)" % str(c))
	if not await _dim_diameter(ctx, c + Vector2(float(circles[0]["radius"]), 0.0), "70"):
		return
	_expect_dof(ctx, true, "centre circle origin after Ø70")
	check(_label_has(sm, "Ø70"), "label Ø70 (%s)" % _label_texts(sm))
	check(_circles(sm).size() == 1, "still one profile circle")
	check(_outline_count(sm) == 1, "centre circle is one profile loop (got %d)" % _outline_count(sm))


func _centre_rect_offset(ctx: FilmContext) -> void:
	if not await _arm_rect(ctx, "Center"):
		return
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(30, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(90, 60))
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var centre := _line_bbox_centre(sm)
	print("  offset rect centre %s" % str(centre))
	check(centre.distance_to(Vector2(30, 0)) <= CENTRE_TOL, "offset rect centre (30, 0) (got %s)" % str(centre))
	if not await _dim_line_to(ctx, Vector2(30, 60), "120"):
		return
	if not await _dim_line_to(ctx, Vector2(90, 30), "120"):
		return
	check(_driving_sides(sm) == 2, "offset rect has two driving sides (%d)" % _driving_sides(sm))
	_expect_dof(ctx, false, "offset centre rect stays unanchored")


func _circle_offset(ctx: FilmContext) -> void:
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(10, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(45, 0))
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var circles := _circles(sm)
	check(circles.size() == 1, "offset circle exists (got %d)" % circles.size())
	if circles.size() != 1:
		return
	var c: Vector2 = circles[0]["center"]
	print("  offset circle centre %s" % str(c))
	check(c.distance_to(Vector2(10, 0)) <= CENTRE_TOL, "offset circle centre (10, 0) (got %s)" % str(c))
	if not await _dim_diameter(ctx, c + Vector2(float(circles[0]["radius"]), 0.0), "70"):
		return
	_expect_dof(ctx, false, "offset circle stays unanchored")


func _corner_rect(ctx: FilmContext) -> void:
	if not await _arm_rect(ctx, "Corner"):
		return
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(100, 65))
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(_profile_lines(sm) == 4, "corner rect has four profile lines (got %d)" % _profile_lines(sm))
	if not await _dim_line_to(ctx, Vector2(50, 65), "100"):
		return
	if not await _dim_line_to(ctx, Vector2(100, 32.5), "65"):
		return
	_expect_dof(ctx, true, "corner rect (0,0)-(100,65) after 100 and 65")
	check(_label_has(sm, "100") and _label_has(sm, "65"), "labels 100 and 65 (%s)" % _label_texts(sm))


func _infer_off_circle(ctx: FilmContext) -> void:
	if not await _turn_infer_off(ctx):
		return
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(35, 0))
	await process_frame
	var circles := _circles(sm)
	check(circles.size() == 1, "infer-off circle exists (got %d)" % circles.size())
	if circles.size() != 1:
		return
	if not await _dim_diameter(ctx, Vector2(35, 0), "70"):
		return
	_expect_dof(ctx, false, "infer off centre circle stays unanchored")


func _infer_off_rect(ctx: FilmContext) -> void:
	if not await _turn_infer_off(ctx):
		return
	if not await _arm_rect(ctx, "Center"):
		return
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(60, 60))
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var centre := _line_bbox_centre(sm)
	print("  infer-off rect centre %s" % str(centre))
	check(centre.distance_to(Vector2.ZERO) <= 1.0, "infer off still draws the rect on the origin (got %s)" % str(centre))
	if not await _dim_line_to(ctx, Vector2(0, 60), "120"):
		return
	if not await _dim_line_to(ctx, Vector2(60, 40), "120"):
		return
	print("  dof chip '%s' last_dofs %s — infer off centre rect" % [_chip(ctx), str(sm.last_dofs)])
	# Without Infer the rectangle is not rectangular: main leaves 20 DOF.
	check(_chip(ctx) == "20" and int(sm.last_dofs) == 20,
			"infer off centre rect DOF unchanged from main (chip '%s' last_dofs %s)" % [
				_chip(ctx), str(sm.last_dofs)])


func _turn_infer_off(ctx: FilmContext) -> bool:
	var infer := ctx.main.find_child("InferToggle", true, false) as CheckBox
	check(infer != null and infer.is_visible_in_tree() and infer.button_pressed, "Infer starts on")
	if infer == null:
		return false
	await _x11_click(infer)
	await process_frame
	check(not ctx.main.sketch_mode.infer_enabled, "Infer is off")
	return not ctx.main.sketch_mode.infer_enabled


func _expect_dof(ctx: FilmContext, fully: bool, what: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var chip := _chip(ctx)
	print("  dof chip '%s' last_dofs %s — %s" % [chip, str(sm.last_dofs), what])
	if fully:
		check(chip == "OK" and int(sm.last_dofs) == 0,
				"%s DOF chip 0 (got '%s', last_dofs %s)" % [what, chip, str(sm.last_dofs)])
	else:
		check(chip == "2" and int(sm.last_dofs) == 2,
				"%s DOF stays 2 (got '%s', last_dofs %s)" % [what, chip, str(sm.last_dofs)])


func _arm_rect(ctx: FilmContext, variant: String) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	var chip := _variant_button(ctx, variant)
	check(chip != null and chip.is_visible_in_tree(), "%s variant chip is visible" % variant)
	if chip == null:
		return false
	if not await FilmUI.click_control(ctx, chip, FilmUICues.alert(variant, variant)):
		return false
	check(sm.tool_variant == variant.to_lower(), "rect variant %s (got %s)" % [variant, sm.tool_variant])
	return sm.tool_variant == variant.to_lower()


func _dim_line_to(ctx: FilmContext, mid: Vector2, text: String) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv(ctx, ctx.main.get_viewport(), mid)
	await process_frame
	await process_frame
	var di := _last_dim_index(sm, "distance")
	check(di >= 0, "distance dimension exists before typing %s" % text)
	if di < 0:
		return false
	return await _type_label(ctx, di, text)


func _dim_diameter(ctx: FilmContext, rim: Vector2, text: String) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv(ctx, ctx.main.get_viewport(), rim)
	await process_frame
	await process_frame
	var di := _last_dim_index(sm, "diameter")
	check(di >= 0, "diameter dimension exists before typing %s" % text)
	if di < 0:
		return false
	return await _type_label(ctx, di, text)


func _type_label(ctx: FilmContext, index: int, text: String) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[index])
	check(lp != null, "label %d has a position" % index)
	if lp == null:
		return false
	await _click_uv(ctx, ctx.main.get_viewport(), lp as Vector2)
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"dimension popup is visible for %s" % text)
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return false
	var line: LineEdit = ix._dim_edit_line
	await _x11_click(line)
	await _type_text(line.get_viewport(), text)
	await _push_key(line.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	return true


func _case(title: String, body: Callable) -> void:
	print("- " + title)
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector3(0, 0, 0), 280.0)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active and sm.infer_enabled, "%s starts in a ground sketch with Infer on" % title)
	if sm != null and sm.active:
		await body.call(ctx)
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _variant_button(ctx: FilmContext, text: String) -> Button:
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	if bar == null:
		return null
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _chip(ctx: FilmContext) -> String:
	if ctx.main.dof_label == null:
		return ""
	return str(ctx.main.dof_label.text)


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	if sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _line_bbox_centre(sm: SketchMode) -> Vector2:
	var have := false
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for key in ["start", "end"]:
			var p: Vector2 = info[key]
			if not have:
				lo = p
				hi = p
				have = true
			else:
				lo.x = minf(lo.x, p.x)
				lo.y = minf(lo.y, p.y)
				hi.x = maxf(hi.x, p.x)
				hi.y = maxf(hi.y, p.y)
	if not have:
		return Vector2(9999, 9999)
	return (lo + hi) * 0.5


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			info["id"] = str(id)
			out.append(info)
	return out


func _outline_count(sm: SketchMode) -> int:
	if sm.sketch == null or not sm.sketch.has_method("contour_outlines"):
		return -1
	return sm.sketch.contour_outlines().size()


func _last_dim_index(sm: SketchMode, type: String) -> int:
	var found := -1
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type:
			found = i
	return found


func _label_texts(sm: SketchMode) -> String:
	var parts: PackedStringArray = []
	for dim in sm.dimensions:
		parts.append(sm._dimension_label_text(dim))
	return ", ".join(parts)


func _label_has(sm: SketchMode, text: String) -> bool:
	return _label_count(sm, text) > 0


func _driving_sides(sm: SketchMode) -> int:
	var n := 0
	if sm.sketch == null:
		return 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		if str(info.get("type", "")) != "distance":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() < 2:
			continue
		if str(refs[0].get("entity", "")) == str(refs[1].get("entity", "")):
			n += 1
	return n


func _label_count(sm: SketchMode, text: String) -> int:
	var n := 0
	for dim in sm.dimensions:
		if sm._dimension_label_text(dim) == text:
			n += 1
	return n


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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	listen_status(main)
	return ctx
