# Jaw dimension labels: the hit rect is where the glyphs are drawn, and a
# click there with Jaw still armed opens the editor (sx-036 A8 / #164).
# Setup may use the sketch API. Every click and key under test is a real
# Viewport.push_input event.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_jaw_label_hit.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const CTR := Vector2(30.0, 5.0)
const HALF_LEN := 22.0
const HALF_W := 10.0
## Walk zoom: the jaw's long side is about 140 px, and the callouts must stay
## beside that jaw rather than under the menu bar.
const SPAN_PX := 140.0
const NEAR_PX := 160.0

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 jaw label hit (A8)")
	var ctx := await _boot()
	await _commit_jaw(ctx)
	await _zoom_span(ctx, SPAN_PX)
	await _assert_placement(ctx, "at ~140 px")
	await _assert_armed_clicks(ctx)
	await _assert_select_click(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	# Larger on-screen span is zoom in; smaller is zoom out. The editor must
	# be closed first or it eats the wheel.
	await _zoom_span(ctx, SPAN_PX * 1.35)
	await _assert_placement(ctx, "after zoom in")
	await _zoom_span(ctx, SPAN_PX * 0.85)
	await _assert_placement(ctx, "after zoom out")
	await _assert_armed_clicks(ctx)
	if ctx.main != null:
		ctx.main.queue_free()
	await process_frame
	finish()


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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _commit_jaw(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is active")
	if sm == null or not sm.active:
		return
	sm.snap_enabled = false
	var jaw: Button = ctx.main.find_child("JawTool", true, false)
	check(jaw != null and jaw.is_visible_in_tree(), "Jaw tool button is visible")
	if jaw == null:
		return
	await _x11_click_screen(jaw.get_viewport(), jaw.get_global_rect().get_center())
	await process_frame
	check(sm.is_jaw_armed(), "Jaw is armed")
	var dir := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var perp := Vector2(-dir.y, dir.x)
	await _click_uv(ctx, CTR)
	await process_frame
	await _click_uv(ctx, CTR + dir * HALF_LEN)
	await process_frame
	await _click_uv(ctx, CTR + perp * HALF_W)
	await process_frame
	await process_frame
	var committed := false
	for line in _status_log:
		if str(line).begins_with("Jaw committed"):
			committed = true
	check(committed, "Jaw committed (log tail %s)" % str(_status_log.slice(maxi(_status_log.size() - 4, 0))))
	check(sm.is_jaw_armed(), "Jaw stays armed after commit")


func _assert_placement(ctx: FilmContext, tag: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null:
		check(false, "%s sketch still open" % tag)
		return
	await process_frame
	await process_frame
	var width_drawn := _drawn_label(sm, "20")
	var angle_drawn := _drawn_label(sm, "45°")
	check(not width_drawn.is_empty(), "%s width label is drawn" % tag)
	check(not angle_drawn.is_empty(), "%s angle label is drawn" % tag)
	if width_drawn.is_empty() or angle_drawn.is_empty():
		_dump_labels(sm, tag)
		return
	_assert_one_label(ctx, sm, tag, "20", width_drawn, _feature_screen(ctx, sm, "distance"))
	_assert_one_label(ctx, sm, tag, "45°", angle_drawn, _feature_screen(ctx, sm, "angle"))
	var wr: Rect2 = width_drawn["rect"]
	var ar: Rect2 = angle_drawn["rect"]
	check(not wr.intersects(ar),
			"%s width and angle glyphs do not cover each other (%s vs %s)" % [tag, str(wr), str(ar)])


func _assert_one_label(ctx: FilmContext, sm: SketchMode, tag: String, needle: String,
		drawn: Dictionary, feature: Vector2) -> void:
	var rect: Rect2 = drawn["rect"]
	var glyph: Vector2 = drawn["glyph"]
	var centre: Vector2 = drawn["centre"]
	var api := _api_rect(sm, needle)
	print("  %s `%s` drawn %s glyph %s api %s feature %s" % [
			tag, needle, str(rect), str(glyph), str(api), str(feature)])
	check(api.size.x > 1.0, "%s `%s` has a hit rect" % [tag, needle])
	if api.size.x > 1.0:
		check(centre.distance_to(api.get_center()) <= 1.5,
				"%s `%s` hit centre matches the drawn centre (%.1f px)" % [
					tag, needle, centre.distance_to(api.get_center())])
		check(api.grow(1.5).has_point(glyph),
				"%s `%s` first glyph is inside the hit rect" % [tag, needle])
	check(_fully_inside(rect),
			"%s `%s` is fully inside the viewport below the menu (%s)" % [tag, needle, str(rect)])
	if feature != Vector2.INF:
		check(centre.distance_to(feature) <= NEAR_PX,
				"%s `%s` sits next to its dimension (%.0f px, limit %d)" % [
					tag, needle, centre.distance_to(feature), NEAR_PX])
	var ray: Array = ctx.main.interaction._model_ray(glyph)
	var uv: Variant = sm.ray_to_sketch(ray[0], ray[1])
	var hit := -1
	if uv != null:
		hit = sm.dimension_hit(uv, true)
	var want := _dim_index(sm, needle)
	check(uv != null and hit == want and want >= 0,
			"%s `%s` rect-only dimension_hit is that label (hit %d want %d)" % [
				tag, needle, hit, want])


func _assert_armed_clicks(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		check(false, "sketch alive for the armed click")
		return
	if not sm.is_jaw_armed():
		var jaw: Button = ctx.main.find_child("JawTool", true, false)
		if jaw != null:
			await _x11_click_screen(jaw.get_viewport(), jaw.get_global_rect().get_center())
			await process_frame
	check(sm.is_jaw_armed(), "Jaw is armed for the glyph clicks")
	var n_ent := sm.sketch.entity_ids().size()
	await _click_label(ctx, sm, "20", n_ent)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix == null or not ix._dim_edit_owns_keys(), "Esc closes the width editor")
	check(sm.active, "Esc after the width editor keeps the sketch")
	await _click_label(ctx, sm, "45°", n_ent)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	check(ix == null or not ix._dim_edit_owns_keys(), "Esc closes the angle editor")
	check(sm.sketch.entity_ids().size() == n_ent, "entity count unchanged after both label clicks")
	check(sm.is_jaw_armed(), "Jaw is still armed after the label clicks")


func _assert_select_click(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var select_btn: Button = ctx.main.find_child("SelectTool", true, false)
	if select_btn == null:
		select_btn = _button_by_text(ctx.main, "Select")
	check(select_btn != null and select_btn.is_visible_in_tree(), "Select tool button is visible")
	if select_btn == null or sm == null or sm.sketch == null:
		return
	await _x11_click_screen(select_btn.get_viewport(), select_btn.get_global_rect().get_center())
	await process_frame
	check(sm.tool == SketchMode.Tool.SELECT, "Select is armed")
	var n_ent := sm.sketch.entity_ids().size()
	var n := _status_log.size()
	await _click_label(ctx, sm, "20", n_ent)
	var cleared := false
	for i in range(n, _status_log.size()):
		if str(_status_log[i]).contains("selection cleared"):
			cleared = true
	check(not cleared, "Select click on the drawn width glyph does not clear the selection")


func _click_label(ctx: FilmContext, sm: SketchMode, needle: String, n_ent: int) -> void:
	var drawn := _drawn_label(sm, needle)
	check(not drawn.is_empty(), "drawn `%s` glyph is available to click" % needle)
	if drawn.is_empty():
		return
	var glyph: Vector2 = drawn["glyph"]
	var n := _status_log.size()
	await _x11_click_screen(ctx.main.get_viewport(), glyph)
	await process_frame
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	var popup_up := ix != null and ix._dim_edit_popup != null and ix._dim_edit_popup.visible
	check(popup_up, "click on drawn `%s` first glyph opens the dimension editor" % needle)
	check(sm.sketch != null and sm.sketch.entity_ids().size() == n_ent,
			"entity count unchanged after `%s`" % needle)
	var started := false
	for i in range(n, _status_log.size()):
		if str(_status_log[i]).begins_with("Jaw — centre set"):
			started = true
	check(not started, "`%s` click does not start a new Jaw" % needle)


func _drawn_label(sm: SketchMode, needle: String) -> Dictionary:
	var cam := sm.get_viewport().get_camera_3d()
	if cam == null or sm._dimension_labels == null:
		return {}
	var k := sm._label_px_scale(cam)
	var font: Font = ThemeDB.fallback_font
	for child in sm._dimension_labels.get_children():
		if not (child is Label3D):
			continue
		var lab := child as Label3D
		if not _label_matches(lab.text, needle):
			continue
		var anchor := cam.unproject_position(lab.global_position)
		var size := Vector2(
				font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.font_size).x,
				font.get_height(lab.font_size)) * k
		var centre := anchor + Vector2(lab.offset.x * k, -lab.offset.y * k)
		var rect := Rect2(centre - size * 0.5, size)
		return {
			"rect": rect,
			"centre": centre,
			"text": lab.text,
			"glyph": Vector2(rect.position.x + minf(6.0, rect.size.x * 0.25), rect.get_center().y),
		}
	return {}


func _api_rect(sm: SketchMode, needle: String) -> Rect2:
	for entry in sm.dimension_label_screen_rects():
		if _label_matches(str(entry.get("text", "")), needle):
			return entry["rect"]
	return Rect2()


func _feature_screen(ctx: FilmContext, sm: SketchMode, type: String) -> Vector2:
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY or str(dim.get("type", "")) != type:
			continue
		if not sm._is_jaw_callout(dim):
			continue
		var ids: Array = dim.get("ids", [])
		if ids.is_empty() or sm.sketch == null:
			continue
		if type == "distance":
			var winfo: Dictionary = sm.sketch.entity_info(str(ids[0]))
			if str(winfo.get("type", "")) != "line":
				continue
			var mid: Vector2 = (winfo["start"] + winfo["end"]) * 0.5
			return FilmUI.model_to_screen(ctx, sm.to_model(mid))
		var vertex := Vector2.INF
		for id in ids:
			var ainfo: Dictionary = sm.sketch.entity_info(str(id))
			if str(ainfo.get("type", "")) != "line":
				continue
			if sm.sketch.is_construction(str(id)):
				vertex = (ainfo["start"] + ainfo["end"]) * 0.5
		if vertex == Vector2.INF:
			vertex = CTR
		return FilmUI.model_to_screen(ctx, sm.to_model(vertex))
	return Vector2.INF


func _dim_index(sm: SketchMode, needle: String) -> int:
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		var text := str(dim.get("label_text", ""))
		if text == "":
			text = sm._dimension_label_text(dim)
		if _label_matches(text, needle):
			return i
	return -1


func _label_matches(text: String, needle: String) -> bool:
	if text == needle:
		return true
	var raw := text.trim_suffix("°")
	var want := needle.trim_suffix("°")
	return want.is_valid_float() and raw.is_valid_float() \
			and absf(float(raw) - float(want)) <= 0.05 \
			and text.ends_with("°") == needle.ends_with("°")


func _fully_inside(rect: Rect2) -> bool:
	var top := ChromeDock.top_inset + 2.0
	var bottom := float(ROOT_SIZE.y) - ChromeDock.bottom_inset - 2.0
	return rect.position.x >= 2.0 and rect.position.y >= top \
			and rect.end.x <= float(ROOT_SIZE.x) - 2.0 and rect.end.y <= bottom \
			and rect.size.x > 2.0 and rect.size.y > 2.0


func _span_px(ctx: FilmContext) -> float:
	var sm: SketchMode = ctx.main.sketch_mode
	var dir := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var a := FilmUI.model_to_screen(ctx, sm.to_model(CTR - dir * HALF_LEN))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(CTR + dir * HALF_LEN))
	return a.distance_to(b)


func _zoom_span(ctx: FilmContext, want_px: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var target := FilmUI.model_to_screen(ctx, sm.to_model(CTR))
	var got := _span_px(ctx)
	var guard := 0
	while got > 1.0 and absf(got - want_px) > 10.0 and guard < 40:
		var zoom_in := got < want_px
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.factor = 1.0
		ev.position = target
		ev.global_position = target
		vp.push_input(ev)
		await process_frame
		got = _span_px(ctx)
		target = FilmUI.model_to_screen(ctx, sm.to_model(CTR))
		guard += 1
	print("  zoomed jaw span to %.1f px (want %.0f) in %d notches" % [got, want_px, guard])
	check(got >= want_px * 0.75 and got <= want_px * 1.25,
			"jaw span is about %.0f px (got %.1f)" % [want_px, got])


func _dump_labels(sm: SketchMode, tag: String) -> void:
	var texts: Array[String] = []
	if sm._dimension_labels != null:
		for child in sm._dimension_labels.get_children():
			if child is Label3D:
				texts.append((child as Label3D).text)
	print("  %s labels: %s" % [tag, str(texts)])


func _button_by_text(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text and (node as Button).is_visible_in_tree():
		return node as Button
	for child in node.get_children():
		var found := _button_by_text(child, text)
		if found != null:
			return found
	return null


func _click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
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


func _push_key(vp: Viewport, code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.pressed = pressed
		ev.echo = false
		vp.push_input(ev)
		await process_frame
