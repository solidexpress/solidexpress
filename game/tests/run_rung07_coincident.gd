# Rung 7 WP3 — coincident to an ellipse/circle is point-on-curve, not centre.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung07_coincident.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")
const SPAN := 90.0


func _init() -> void:
	print("rung07 coincident")
	FilmUI.reset_fail_count()
	var ctx := await SpannerFixture.boot(self, Vector2i(1280, 800))
	await _ellipse_case(ctx)
	await _handle_ellipse_case(ctx)
	await _circle_case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _ellipse_case(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	await _zoom(ctx, Vector3.ZERO, SPAN)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ellipse centre", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(0.0, SpannerFixture.mm("ELLIPSE_MAJ") * 0.5),
			"Ellipse major", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(SpannerFixture.mm("ELLIPSE_MIN") * 0.5, 0.0),
			"Ellipse minor", SPAN)
	var xj := SpannerFixture.x_jaw()
	var off := SpannerFixture.mm("JAW_OFF")
	var o_hi := SpannerFixture.world(xj, off)
	var i_hi := SpannerFixture.world(xj + SpannerFixture.mm("JAW_LEN"), off)
	await SpannerFixture.line(ctx, o_hi, i_hi, "jaw", SPAN)
	await _coincident_chip(ctx, sm, o_hi, SpannerFixture.world(20.0, 15.0), "jaw on ellipse")
	var line := _first_of(sm, "line")
	var ell := _first_of(sm, "ellipse")
	check(line != "" and ell != "", "jaw line and ellipse exist")
	if line == "" or ell == "":
		return
	var start: Vector2 = sm.sketch.entity_info(line).get("start", Vector2.ZERO)
	var centre: Vector2 = sm.sketch.entity_info(ell).get("center", Vector2.ZERO)
	check(start.distance_to(Vector2.ZERO) > 10.0, "jaw end is not at the origin (got %s)" % str(start))
	check(centre.distance_to(Vector2.ZERO) <= 0.3, "ellipse centre unmoved (got %s)" % str(centre))
	var on := sm.closest_on_entity(ell, start).distance_to(start)
	check(on <= 0.2, "jaw end sits on the ellipse (dist %.3f)" % on)


func _handle_ellipse_case(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm.active:
		await FilmUI.exit_sketch(ctx)
	await process_frame
	ctx.view.new_document()
	await process_frame
	await process_frame
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active for handle-on-C")
	await _zoom(ctx, Vector3.ZERO, SPAN)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Handle-C centre", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(0.0, SpannerFixture.mm("ELLIPSE_MAJ") * 0.5),
			"Handle-C major", SPAN)
	await FilmSteps.click_uv(ctx, SpannerFixture.world(SpannerFixture.mm("ELLIPSE_MIN") * 0.5, 0.0),
			"Handle-C minor", SPAN)
	var hit := SpannerFixture.handle_xy(true)[0]
	await SpannerFixture.line(ctx, Vector2(30, 10), Vector2(120, 10), "handle on C", SPAN)
	await _coincident_chip(ctx, sm, Vector2(30, 10), hit, "handle on C")
	var line := _handle_line(sm)
	var ell := _first_of(sm, "ellipse")
	if ell == "":
		ell = _first_of(sm, "elliptical_arc")
	check(line != "" and ell != "", "handle line and ellipse exist")
	if line == "" or ell == "":
		return
	var start: Vector2 = sm.sketch.entity_info(line).get("start", Vector2.ZERO)
	var endp: Vector2 = sm.sketch.entity_info(line).get("end", Vector2.ZERO)
	var left: Vector2 = start if start.x < endp.x else endp
	check(absf(left.y - 10.0) <= 0.4, "handle stays at y=10 (got %s)" % str(left))
	check(absf(left.x - hit.x) <= 0.8, "handle end at C hit (got %.3f want %.3f)" % [left.x, hit.x])
	var major := SpannerFixture.ellipse_major_uv()
	check(left.distance_to(major) > 15.0, "handle end is not the major-axis tip (got %s)" % str(left))
	var on := sm.closest_on_entity(ell, left).distance_to(left)
	check(on <= 0.3, "handle end sits on the ellipse (dist %.3f)" % on)


func _circle_case(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm.active:
		await FilmUI.exit_sketch(ctx)
	await process_frame
	ctx.view.new_document()
	await process_frame
	await process_frame
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active for Ø33")
	var center := SpannerFixture.mm("CENTER")
	var ring_r := SpannerFixture.mm("RING_D") * 0.5
	var half := SpannerFixture.mm("HANDLE_HALF")
	await _zoom(ctx, Vector3(center, 0, 0), 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmSteps.click_uv(ctx, Vector2(center, 0), "Circle centre", 80.0)
	await FilmSteps.click_uv(ctx, Vector2(center + ring_r, 0), "Circle rim", 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, Vector2(center + ring_r, 0), "Ø33 dim", 80.0)
	await FilmSteps.type_dim(ctx, str(int(SpannerFixture.mm("RING_D"))))
	await process_frame
	await SpannerFixture.line(ctx, Vector2(200, half), Vector2(230, half), "handle", SPAN)
	await _coincident_chip(ctx, sm, Vector2(230, half), Vector2(center, ring_r), "handle on Ø33", 80.0)
	var line := _handle_line(sm)
	var circ := _first_of(sm, "circle")
	check(line != "" and circ != "", "handle line and circle exist")
	if line == "" or circ == "":
		return
	var info_c: Dictionary = sm.sketch.entity_info(circ)
	var c: Vector2 = info_c.get("center", Vector2.ZERO)
	var r := float(info_c.get("radius", 0.0))
	var endp: Vector2 = sm.sketch.entity_info(line).get("end", Vector2.ZERO)
	var start: Vector2 = sm.sketch.entity_info(line).get("start", Vector2.ZERO)
	var hit := endp if endp.distance_to(c) < start.distance_to(c) else start
	check(hit.distance_to(c) > 8.0, "handle end is not at the circle centre (got %s)" % str(hit))
	check(absf(hit.distance_to(c) - r) <= 0.3, "handle end on Ø33 (dist %.3f r %.3f)" % [hit.distance_to(c), r])
	var left := c.x - sqrt(maxf(0.0, r * r - pow(hit.y - c.y, 2.0)))
	check(absf(hit.x - left) <= 0.3, "handle chord is the left Ø33 hit (got %.3f want %.3f)" % [hit.x, left])


func _coincident_chip(ctx: FilmContext, sm: SketchMode, a: Vector2, b: Vector2, desc: String, span: float = SPAN) -> void:
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, a, "%s first" % desc, span)
	await _zoom(ctx, Vector3(b.x, b.y, 0.0), span)
	var screen := FilmUI.sketch_uv_to_screen(ctx, b)
	if screen != Vector2.ZERO:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "%s second" % desc), false, MOUSE_BUTTON_LEFT, true)
	await process_frame
	check(sm.selected.size() == 2, "%s selected two entities (got %d)" % [desc, sm.selected.size()])
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Coincident")
	var more: MenuButton = null
	var more_id := -1
	if chip == null or not chip.is_visible_in_tree():
		var more_btn := FilmUI.find_button(ctx.main.sketch_chrome, "… More")
		if more_btn is MenuButton:
			more = more_btn as MenuButton
			var popup := more.get_popup()
			if popup != null:
				for i in popup.item_count:
					if str(popup.get_item_text(i)) == "Coincident":
						more_id = i
						break
	check((chip != null and chip.is_visible_in_tree()) or more_id >= 0, "Coincident chip is visible")
	if chip != null and chip.is_visible_in_tree():
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Coincident", desc))
	elif more != null and more_id >= 0:
		await FilmUI.activate_menu_id(ctx, more, more_id, FilmUICues.alert("Coincident", desc))
	await process_frame
	sm.run_solve()
	await process_frame


func _first_of(sm: SketchMode, kind: String) -> String:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			return str(id)
	return ""


func _handle_line(sm: SketchMode) -> String:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info.get("start", Vector2.ZERO)
		var b: Vector2 = info.get("end", Vector2.ZERO)
		if absf(0.5 * (a.y + b.y) - SpannerFixture.mm("HANDLE_HALF")) <= 2.0:
			return str(id)
	return ""
