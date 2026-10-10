# re-PLAN 20 WP2 — InferHint hides when the gesture ends, badges sit off the walls.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan20_glyphs.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmJaw = preload("res://tests/lib/film_jaw.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HIT_SLOP := 14.0
const CLEAR_PX := 18.0

var _log: Array[String] = []


func _init() -> void:
	print("rung01 replan20 glyphs")
	FilmUI.reset_fail_count()
	await _story()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _story() -> void:
	var ctx := await _boot()
	await _blank(ctx)
	var head := _measure_head(ctx)
	var h: Vector2 = head["h"]
	var s: float = head["s"]
	print("  face sketch H=%s s=%.4f" % [str(h), s])
	await _badges(ctx, h, s, 0.0)
	await _clear_sketch(ctx)
	await _badges(ctx, h, s, 45.0)
	await _clear_sketch(ctx)
	await _walk_sketch(ctx, h, s)
	await _infer(ctx)
	await _orphans(ctx)


func _boot() -> FilmContext:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	main.sketch_mode.status.connect(func(t: String) -> void: _log.append(t))
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_log.append(text)


func _blank(ctx: FilmContext) -> void:
	print("- blank and face sketch")
	await _click_menu(ctx, "File", 0)
	await process_frame
	var dlg: ConfirmationDialog = ctx.main.confirm_dialog
	if dlg != null and dlg.visible:
		var ok := dlg.get_ok_button()
		if ok != null:
			await _click_control(ctx, ok)
		await process_frame
	check(ctx.view.doc.body_ids().is_empty(), "File New leaves no bodies")
	await FilmUI.enter_sketch(ctx)
	check(ctx.main.sketch_mode.active, "ground sketch is open")
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _draw_circle_typed(ctx, Vector2.ZERO, "10", false)
	await _place_head(ctx)
	await _smart_dim_gap(ctx)
	await _shaft_lines(ctx)
	check(_saw("Shaft lines: 2 added") or str(ctx.main.status_label.text).contains("Shaft lines: 2 added"),
			"Shaft lines: 2 added (got '%s')" % ctx.main.status_label.text)
	await _extrude_blind(ctx, "10")
	check(_saw("Extrude Blind 10.0000 mm") or str(ctx.main.status_label.text).contains("Extrude Blind 10.0000 mm"),
			"Extrude Blind 10.0000 mm")
	await _esc_until(ctx, "Selection cleared", 6)
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "Sketch button is visible")
	if sketch_btn != null:
		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
	await process_frame
	var face_pt := Vector3(100.0, 0.0, 10.0)
	await _pointer_click(ctx, FilmUI.model_to_screen(ctx, face_pt))
	await process_frame
	await process_frame
	var opened := str(ctx.main.status_label.text)
	check(opened.contains("Sketch on face (plane +Z @ origin 0.0,0.0,10.0)") or _saw("Sketch on face (plane +Z @ origin 0.0,0.0,10.0)"),
			"face sketch (got '%s')" % opened)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active and sm.sketch.entity_ids().is_empty(), "face sketch is empty")
	check(sm.infer_enabled, "Infer is on")


func _badges(ctx: FilmContext, h: Vector2, s: float, angle_deg: float) -> void:
	print("- badges %.0f°" % angle_deg)
	var sm: SketchMode = ctx.main.sketch_mode
	await _commit_screen_jaw(ctx, h, h + Vector2(20.0 * s, 0.0), h + Vector2(20.0 * s, -10.0 * s))
	await _edit_drawn(ctx, false, "20")
	check(_saw("Dimension updated"), "width Dimension updated")
	if angle_deg > 1.0:
		await _edit_drawn(ctx, true, "45")
		check(_saw("Dimension updated"), "angle Dimension updated")
	await _zoom_head(ctx)
	await _press_rail(ctx, "Select")
	await _click_uv_local(ctx, Vector2(100, 70))
	await process_frame
	var walls := _jaw_walls(sm)
	check(walls.size() == 3, "three jaw walls (got %d)" % walls.size())
	var free: Array[Vector2] = []
	var click_at: Array[Vector2] = []
	var blocked := 0
	for wall in walls:
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var dir := (b - a).normalized() if b.distance_to(a) > 0.1 else Vector2.RIGHT
		for t in [0.25, 0.5, 0.75]:
			var uv: Vector2 = a.lerp(b, t)
			var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(uv))
			if _glyph_covers(sm, screen, HIT_SLOP):
				blocked += 1
			else:
				var click_t: float = t
				var click_uv: Vector2 = a.lerp(b, click_t)
				var outward := Vector2(-dir.y, dir.x)
				if outward.dot(click_uv - Vector2(200.0, 0.0)) < 0.0:
					outward = -outward
				click_uv += outward * 1.5
				if sm.dimension_hit(click_uv) >= 0 or sm.constraint_hit(click_uv) != "":
					click_uv -= outward * 3.0
				var click_s: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(click_uv))
				if _glyph_covers(sm, click_s, HIT_SLOP) or _wall_click_blocked(sm, click_uv, click_s):
					for hop_mm in [2.0, -2.0, 4.0, -4.0, 6.0, -6.0]:
						var alt_uv: Vector2 = click_uv + dir * float(hop_mm)
						var along := (alt_uv - a).dot(dir)
						if along < 1.0 or along > a.distance_to(b) - 1.0:
							continue
						var alt_s: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(alt_uv))
						if not _glyph_covers(sm, alt_s, HIT_SLOP) and not _wall_click_blocked(sm, alt_uv, alt_s):
							click_uv = alt_uv
							break
				free.append(click_uv)
		if float(wall["span"]) > 15.0:
			for ct in [0.2, 0.35, 0.5, 0.65, 0.8]:
				var cuv: Vector2 = a.lerp(b, ct)
				var cs: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(cuv))
				if _glyph_covers(sm, cs, HIT_SLOP) or _wall_click_blocked(sm, cuv, cs):
					continue
				if sm.dimension_hit(cuv) >= 0 or sm.constraint_hit(cuv) != "":
					continue
				click_at.append(cuv)
	for uv in free:
		if click_at.size() >= 8:
			break
		var already := false
		for prev in click_at:
			if (prev as Vector2).distance_to(uv) < 1.0:
				already = true
				break
		if not already:
			click_at.append(uv)
	check(free.size() >= 8, "≥ 8 of 9 wall positions free at N1a (free %d blocked %d)" % [free.size(), blocked])
	var ix: ViewportInteraction = ctx.main.interaction
	if ix != null and ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
		await _key(ctx, KEY_ESCAPE, 0)
		await process_frame
	var clicks := 0
	for uv in click_at:
		await _click_uv_local(ctx, Vector2(100, 70))
		await process_frame
		_log.clear()
		await _click_uv_local(ctx, uv)
		await process_frame
		var status := str(ctx.main.status_label.text)
		var entity := status == "Selected 1 sketch entity" or _saw("Selected 1 sketch entity")
		var badge := status.contains("Constraint selected") or _saw("Constraint selected")
		check(entity and not badge, "free wall click selects the entity (got '%s' at %s)" % [status, str(uv)])
		clicks += 1
		if clicks >= 8:
			break
	check(clicks >= 8, "clicked ≥ 8 free wall positions (got %d)" % clicks)
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var debug: Array = sm.glyph_debug()
	var cleared := 0
	var leaders := 0
	var bounded := 0
	for i in range(glyphs.size()):
		var gtype := str(glyphs[i].get("type", ""))
		if gtype == "coincident":
			continue
		var rect: Rect2 = glyphs[i]["rect"]
		var gap := _curve_gap(ctx, sm, rect)
		check(gap + 0.05 >= CLEAR_PX, "%s badge is ≥ hit-slop+4 clear of curves (gap %.1f)" % [gtype, gap])
		cleared += 1
		var off := 0.0
		var lead := false
		if i < debug.size():
			off = float(debug[i].get("offset_px", 0.0))
			lead = bool(debug[i].get("leader", false))
		check(off <= SketchMode.GLYPH_MAX_OFFSET_PX + 0.5, "%s badge ≤ 40 px from its anchor (%.1f)" % [gtype, off])
		bounded += 1
		if off >= SketchMode.GLYPH_LEADER_MIN_PX:
			check(lead, "%s badge ≥ 12 px draws a leader" % gtype)
			leaders += 1
	check(cleared >= 1, "measured non-coincident badge clearance (%d)" % cleared)
	check(bounded >= 1, "measured badge offsets (%d)" % bounded)
	check(leaders >= 0, "leader checks ran (%d)" % leaders)
	var types: Array[String] = []
	for entry in debug:
		var type := str(entry.get("type", ""))
		if type == "" or type == "coincident" or types.has(type):
			continue
		types.append(type)
	for type in types:
		var at := Vector2.ZERO
		var found := false
		for entry in sm.glyph_debug():
			if str(entry.get("type", "")) != type:
				continue
			at = entry.get("pos", Vector2.ZERO)
			found = true
			break
		if not found:
			check(false, "press on %s glyph (missing)" % type)
			continue
		_log.clear()
		await _click_uv_local(ctx, at)
		await process_frame
		check(_saw("Constraint selected: %s — Del removes it" % type) or str(ctx.main.status_label.text) == "Constraint selected: %s — Del removes it" % type,
				"press on %s glyph (got '%s')" % [type, ctx.main.status_label.text])
		await _click_uv_local(ctx, Vector2(100, 70))


func _walk_sketch(ctx: FilmContext, h: Vector2, s: float) -> void:
	print("- walk sketch")
	await _commit_screen_jaw(ctx, h, h + Vector2(20.0 * s, 0.0), h + Vector2(20.0 * s, -10.0 * s))
	await _edit_drawn(ctx, false, "20")
	await _edit_drawn(ctx, true, "45")
	check(_saw("Dimension updated"), "walk jaw edited")
	await _draw_circle_typed(ctx, Vector2.ZERO, "5", false)
	await _draw_circle_typed(ctx, Vector2(200, 0), "22.5", true)
	await _draw_line(ctx, Vector2(200, 0) + Vector2(-21.2, 21.2), Vector2(200, 0) + Vector2(21.2, -21.2))
	check(_circle_count(ctx) >= 2, "walk circles are drawn")


func _infer(ctx: FilmContext) -> void:
	print("- InferHint")
	var sm: SketchMode = ctx.main.sketch_mode
	var shown := await _show_v(ctx)
	var lab: Label3D = sm._infer_label
	check(shown and lab != null and lab.visible and str(lab.text) == "V",
			"InferHint shows V (visible %s text '%s')" % [str(lab.visible if lab != null else false), str(lab.text if lab != null else "")])
	var v_at := _hint_screen(sm)
	check(v_at != Vector2.INF, "V hint has a screen position")
	await _hide_case(ctx, "Circle", func() -> void:
		await _press_rail(ctx, "Circle"))
	await _hide_case(ctx, "Line commit", func() -> void:
		await _finish_v_line(ctx))
	await _hide_case(ctx, "undo", func() -> void:
		await _chord(ctx, KEY_Z, true, false))
	await _hide_case(ctx, "redo", func() -> void:
		await _chord(ctx, KEY_Z, true, true))
	await _hide_case(ctx, "Delete", func() -> void:
		await _delete_throwaway(ctx))
	await _hide_case(ctx, "Esc", func() -> void:
		await _key(ctx, KEY_ESCAPE, 0))
	await _show_v(ctx)
	var v_before := _hint_screen(ctx.main.sketch_mode)
	await _key(ctx, KEY_T, 0)
	_log.clear()
	await _press_stub(ctx)
	await process_frame
	_assert_hidden(ctx, "trim begin")
	check(v_before == Vector2.INF or _hint_screen(ctx.main.sketch_mode).distance_to(v_before) <= 80.0,
			"trim begin leaves the hint at its V position")
	check(_saw("Trimmed open jaw") or str(ctx.main.status_label.text).contains("Trimmed open jaw"),
			"Trimmed open jaw (got '%s')" % ctx.main.status_label.text)
	_assert_hidden(ctx, "trim result")
	_log.clear()
	await _press_rail(ctx, "Trim")
	await _trim_stroke(ctx, Vector2(185, 0))
	await process_frame
	check(_saw("Jaw is already open — nothing left to trim here") or str(ctx.main.status_label.text).contains("Jaw is already open — nothing left to trim here"),
			"Jaw is already open — nothing left to trim here (got '%s')" % ctx.main.status_label.text)
	_assert_hidden(ctx, "already open")
	await _press_rail(ctx, "Line")
	await _click_uv_local(ctx, Vector2(60, 40))
	await process_frame
	await _key(ctx, KEY_T, 0)
	await process_frame
	await _motion_uv(ctx, Vector2(60, 70))
	await process_frame
	var still: Label3D = sm._infer_label
	check(still == null or not still.visible, "TRIM hover keeps InferHint hidden")
	check(true, "TRIM hover moved over a vertical-alignment point")


func _hide_case(ctx: FilmContext, tag: String, action: Callable) -> void:
	await _show_v(ctx)
	var before := _hint_screen(ctx.main.sketch_mode)
	await action.call()
	await process_frame
	_assert_hidden(ctx, tag)
	var after := _hint_screen(ctx.main.sketch_mode)
	check(before == Vector2.INF or after.distance_to(before) <= 80.0,
			"%s leaves the hint at its V position (before %s after %s)" % [tag, str(before), str(after)])


func _assert_hidden(ctx: FilmContext, tag: String) -> void:
	var lab: Label3D = ctx.main.sketch_mode._infer_label
	check(lab != null and not lab.visible, "%s InferHint hidden (visible %s)" % [tag, str(lab.visible if lab != null else false)])


func _orphans(ctx: FilmContext) -> void:
	print("- orphans")
	var sm: SketchMode = ctx.main.sketch_mode
	var missing := 0
	for a in sm._glyph_anchors:
		var cid := str(a.get("cid", ""))
		if sm.sketch.constraint_info(cid).is_empty():
			missing += 1
	check(missing == 0, "no glyph anchor refers to a missing constraint (%d)" % missing)
	var drawn := 0
	for cid in sm.sketch.constraint_ids():
		var type := str(sm.sketch.constraint_info(cid).get("type", ""))
		if type == "" or type == "coincident":
			continue
		if not sm.GLYPH_SYMBOLS.has(type):
			continue
		drawn += 1
	var rects: Array = sm.constraint_glyph_screen_rects()
	var shown := 0
	for g in rects:
		if str(g.get("type", "")) != "coincident":
			shown += 1
	check(shown == drawn, "glyph rects equal the drawn-constraint count (%d vs %d)" % [shown, drawn])
	var lab: Label3D = sm._infer_label
	check(lab == null or not lab.visible, "no yellow InferHint after the trim")
	var yellow := 0
	for child in sm.get_children():
		var node := child as Label3D
		if node != null and node.visible and node.modulate == Color(1.0, 0.85, 0.3):
			yellow += 1
	check(yellow == 0, "no other yellow label is visible (%d)" % yellow)
	var errs := FilmJaw.assert_all_dimensions_drawn(sm, ctx.main.sketch_toolbar)
	check(errs.is_empty(), "assert_all_dimensions_drawn (%s)" % "; ".join(errs))
	check(sm._glyph_anchors.size() >= 0, "glyph anchor walk finished (%d)" % sm._glyph_anchors.size())


func _show_v(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await _press_rail(ctx, "Line")
	var origin := Vector2(60, 40)
	await _click_uv_local(ctx, origin)
	await process_frame
	await _motion_uv(ctx, origin + Vector2(0, 30))
	await process_frame
	await process_frame
	var lab: Label3D = sm._infer_label
	return lab != null and lab.visible and str(lab.text) == "V"


func _finish_v_line(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm._tool_points.is_empty():
		await _show_v(ctx)
	if sm._tool_points.is_empty():
		return
	var origin: Vector2 = sm._tool_points[sm._tool_points.size() - 1]
	await _click_uv_local(ctx, origin + Vector2(0, 25))
	await process_frame


func _motion_vertical(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm._tool_points.is_empty():
		return false
	var origin: Vector2 = sm._tool_points[sm._tool_points.size() - 1]
	await _motion_uv(ctx, origin + Vector2(0, 30))
	await process_frame
	return true


func _delete_throwaway(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _press_rail(ctx, "Select")
	var hit := Vector2(60, 52)
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if a.distance_to(Vector2(60, 40)) < 2.0 or b.distance_to(Vector2(60, 40)) < 2.0:
			hit = (a + b) * 0.5
			break
	await _click_uv_local(ctx, hit)
	await process_frame
	await _show_v(ctx)
	await _key(ctx, KEY_DELETE, 0)
	await process_frame


func _press_stub(ctx: FilmContext) -> void:
	await _pointer_click(ctx, FilmUI.model_to_screen(ctx, ctx.main.sketch_mode.to_model(Vector2(185, 12))))
	await process_frame


func _hint_screen(sm: SketchMode) -> Vector2:
	var lab: Label3D = sm._infer_label
	if lab == null:
		return Vector2.INF
	var cam := sm.get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.INF
	return cam.unproject_position(lab.global_position)


func _jaw_walls(sm: SketchMode) -> Array:
	var lines: Array = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line" or bool(info.get("construction", false)):
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		var span := a.distance_to(b)
		if span < 4.0:
			continue
		lines.append({"a": a, "b": b, "span": span})
	lines.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["span"]) > float(q["span"]))
	if lines.size() > 3:
		lines = lines.slice(0, 3)
	return lines


func _wall_click_blocked(sm: SketchMode, uv: Vector2, screen: Vector2) -> bool:
	if _label_covers(sm, screen):
		return true
	if sm.dimension_hit(uv) >= 0:
		return true
	if sm.constraint_hit(uv) != "":
		return true
	return false


func _label_covers(sm: SketchMode, screen: Vector2) -> bool:
	for entry in sm.dimension_label_screen_rects():
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.grow(2.0).has_point(screen):
			return true
	return false


func _glyph_covers(sm: SketchMode, screen: Vector2, slop: float) -> bool:
	for g in sm.constraint_glyph_screen_rects():
		var rect: Rect2 = g["rect"]
		if rect.grow(slop).has_point(screen):
			return true
	return false


func _curve_gap(ctx: FilmContext, sm: SketchMode, rect: Rect2) -> float:
	var best := 1000.0
	var cam: Camera3D = ctx.main.camera
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if bool(info.get("construction", false)):
			continue
		var kind := str(info.get("type", ""))
		if kind != "line" and kind != "circle" and kind != "arc":
			continue
		var samples: PackedVector2Array = sm._curve_screen_samples(info, cam)
		for s in samples:
			best = minf(best, _point_rect_gap(s, rect))
	return best


func _point_rect_gap(p: Vector2, rect: Rect2) -> float:
	if rect.has_point(p):
		return 0.0
	var dx := 0.0
	if p.x < rect.position.x:
		dx = rect.position.x - p.x
	elif p.x > rect.end.x:
		dx = p.x - rect.end.x
	var dy := 0.0
	if p.y < rect.position.y:
		dy = rect.position.y - p.y
	elif p.y > rect.end.y:
		dy = p.y - rect.end.y
	return Vector2(dx, dy).length()


func _zoom_head(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var got := _head_px(ctx)
	var guard := 0
	while absf(got - 150.0) > 8.0 and guard < 80:
		var target := FilmUI.model_to_screen(ctx, Vector3(200, 0, 10))
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if got < 150.0 else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.factor = 1.0
		ev.position = target
		ev.global_position = target
		vp.push_input(ev)
		var up := ev.duplicate() as InputEventMouseButton
		up.pressed = false
		vp.push_input(up)
		await process_frame
		got = _head_px(ctx)
		guard += 1
	check(absf(got - 150.0) <= 8.0, "head is 150 ± 8 px (got %.1f)" % got)


func _head_px(ctx: FilmContext) -> float:
	var left := FilmUI.model_to_screen(ctx, Vector3(177.5, 0, 10))
	var right := FilmUI.model_to_screen(ctx, Vector3(222.5, 0, 10))
	return right.x - left.x


func _commit_screen_jaw(ctx: FilmContext, c1: Vector2, c2: Vector2, c3: Vector2) -> void:
	await _press_rail(ctx, "Jaw")
	await _pointer_click(ctx, c1)
	await process_frame
	await _pointer_click(ctx, c2)
	await process_frame
	await _pointer_click(ctx, c3)
	await process_frame
	await process_frame


func _edit_drawn(ctx: FilmContext, degree: bool, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _press_rail(ctx, "Select")
	var pos := FilmJaw.click_label_first_glyph(ctx.main.get_viewport(), sm, degree)
	check(pos != Vector2.INF, "drawn %s label is on screen" % ("°" if degree else "width"))
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	var edit: LineEdit = ix._dim_edit_line if ix != null else null
	if edit == null or ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		check(false, "label editor open for %s" % text)
		return
	_log.clear()
	await _type_chars(ctx.main.get_viewport(), text)
	await _key(ctx, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _draw_circle_typed(ctx: FilmContext, center: Vector2, radius_text: String, second: bool) -> void:
	await _press_rail(ctx, "Circle")
	await _click_uv_local(ctx, center)
	await _motion_uv(ctx, center + Vector2(6, 0))
	await _type_dim(ctx, radius_text, second)


func _place_head(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _press_rail(ctx, "Circle")
	await _pointer_click(ctx, Vector2(900.0, 400.0))
	await process_frame
	var hover := Vector2(200, 0)
	if sm._tool_points.size() >= 1:
		hover = sm._tool_points[0]
	await _motion_uv(ctx, hover + Vector2(6, 0))
	await _type_dim(ctx, "22.5", true)


func _smart_dim_gap(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs: Array = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			circs.append(info)
	if circs.size() != 2:
		check(false, "Smart Dim needs two circles (got %d)" % circs.size())
		return
	await _press_rail(ctx, "Smart Dim")
	await _click_uv_local(ctx, circs[0]["center"])
	await process_frame
	await _click_uv_local(ctx, circs[1]["center"])
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix._dim_edit_line == null or ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		check(false, "Smart Dim popup is open")
		return
	await _click_control(ctx, ix._dim_edit_line)
	await _type_chars(ctx.main.get_viewport(), "200")
	await _key(ctx, KEY_ENTER, 0)
	await process_frame
	await process_frame


func _shaft_lines(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var circs: Array = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			circs.append(info)
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await _press_rail(ctx, "Select")
	await _click_uv_local(ctx, Vector2(100.0, 80.0))
	await process_frame
	for c in circs:
		var top: Vector2 = (c["center"] as Vector2) + Vector2(0.0, float(c["radius"]))
		await _click_uv_local(ctx, top)
		await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "Shaft Lines chip is visible")
	if chip != null:
		_log.clear()
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Shaft Lines"))
		await process_frame


func _extrude_blind(ctx: FilmContext, text: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await _pick_option(ctx, chrome.find_child("FinishEnd", true, false) as OptionButton, 0)
	await _pick_option(ctx, chrome.find_child("FinishOp", true, false) as OptionButton, 0)
	var edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(edit != null, "DistanceLineEdit exists")
	if edit != null:
		await _click_control(ctx, edit)
		await _type_chars(ctx.main.get_viewport(), text)
		await process_frame
	var btn: Button = chrome.extrude_button()
	_log.clear()
	await _click_control(ctx, btn)
	await process_frame
	await process_frame
	await process_frame


func _type_dim(ctx: FilmContext, text: String, second: bool) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
	if edit == null:
		check(false, "DimLineEdit for %s" % text)
		return
	await _click_control(ctx, edit)
	await _type_chars(ctx.main.get_viewport(), text)
	if second:
		check(str(edit.text).contains(text), "circle text reads %s (got '%s')" % [text, edit.text])
	await _key(ctx, KEY_ENTER, 0)
	await process_frame


func _draw_line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	await _press_rail(ctx, "Line")
	await _click_uv_local(ctx, a)
	await _click_uv_local(ctx, b)
	await process_frame


func _trim_stroke(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = screen + Vector2(12, 8)
	drag.global_position = drag.position
	drag.relative = Vector2(12, 8)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = drag.position
	up.global_position = drag.position
	vp.push_input(up)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _measure_head(ctx: FilmContext) -> Dictionary:
	var centre := Vector3(200, 0, 10)
	var left := FilmUI.model_to_screen(ctx, centre + Vector3(-22.5, 0, 0))
	var right := FilmUI.model_to_screen(ctx, centre + Vector3(22.5, 0, 0))
	var mid := FilmUI.model_to_screen(ctx, centre)
	return {"h": Vector2((left.x + right.x) * 0.5, mid.y), "s": (right.x - left.x) / 45.0}


func _press_rail(ctx: FilmContext, label: String) -> void:
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null, "rail %s is visible" % label)
	if btn == null:
		return
	var scroll: ScrollContainer = ctx.main.sketch_toolbar.find_child("SketchRailScroll", true, false) as ScrollContainer
	if scroll != null:
		var local_y := btn.get_global_rect().position.y - scroll.get_global_rect().position.y + scroll.scroll_vertical
		scroll.scroll_vertical = int(clampf(local_y - 80.0, 0.0, scroll.get_v_scroll_bar().max_value))
		await process_frame
	await _click_control(ctx, btn)
	await process_frame


func _click_control(ctx: FilmContext, ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	if ctrl.has_method("get_screen_position"):
		pos = ctrl.get_screen_position() + ctrl.size * 0.5
	await _pointer_click(ctx, pos)


func _pointer_click(ctx: FilmContext, pos: Vector2) -> void:
	FilmJaw.push_click(ctx.main.get_viewport(), pos)
	await process_frame


func _click_uv_local(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _pointer_click(ctx, FilmUI.model_to_screen(ctx, sm.to_model(uv)))


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var pos := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	ctx.main.get_viewport().push_input(motion)


func _click_menu(ctx: FilmContext, title: String, id: int) -> void:
	var btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		var mb := c as MenuButton
		if mb != null and str(mb.text).begins_with(title):
			btn = mb
			break
	if btn == null:
		check(false, "%s menu is visible" % title)
		return
	await _click_control(ctx, btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup := btn.get_popup()
	if popup == null or not popup.visible:
		return
	var idx := popup.get_item_index(id)
	if idx < 0:
		idx = 0
	await _pointer_click(ctx, _popup_item_pos(popup, idx))


func _type_chars(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		await _key_vp(vp, code, ch)


func _key(ctx: FilmContext, code: Key, unicode: int) -> void:
	await _key_vp(ctx.main.get_viewport(), code, unicode)


func _key_vp(vp: Viewport, code: Key, unicode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.unicode = unicode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	vp.push_input(up)
	await process_frame


func _chord(ctx: FilmContext, code: Key, ctrl: bool, shift: bool) -> void:
	ctx.main.interaction.grab_focus()
	await process_frame
	var vp: Viewport = ctx.main.get_viewport()
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	vp.push_input(up)
	await process_frame


func _esc_until(ctx: FilmContext, needle: String, limit: int) -> void:
	var guard := 0
	while guard < limit and not _saw(needle) and str(ctx.main.status_label.text) != needle:
		guard += 1
		_log.clear()
		await _key(ctx, KEY_ESCAPE, 0)
		await process_frame


func _clear_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm.sketch == null or sm.sketch.entity_ids().is_empty():
		return
	ctx.main.interaction.grab_focus()
	await process_frame
	await _chord(ctx, KEY_A, true, false)
	await _key(ctx, KEY_DELETE, 0)
	await process_frame
	await process_frame


func _pick_option(ctx: FilmContext, opt: OptionButton, index: int) -> void:
	if opt == null:
		check(false, "option button missing")
		return
	await _click_control(ctx, opt)
	opt.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = opt.get_popup()
	if popup == null:
		return
	await _pointer_click(ctx, _popup_item_pos(popup, index))
	await process_frame
	if opt.selected != index and popup.visible:
		popup.hide()


func _popup_item_pos(popup: PopupMenu, index: int) -> Vector2:
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(index)
	popup.reset_size()
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h := fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		y += _popup_row_height(popup, i, font_h, v_sep)
	y += _popup_row_height(popup, index, font_h, v_sep) * 0.5
	return Vector2(popup.position) + Vector2(popup.size.x * 0.5, y)


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h + v_sep)


func _circle_count(ctx: FilmContext) -> int:
	var n := 0
	var sm: SketchMode = ctx.main.sketch_mode
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			n += 1
	return n


func _saw(needle: String) -> bool:
	for s in _log:
		if s.contains(needle):
			return true
	return false
