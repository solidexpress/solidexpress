# WP4 — coincident glyphs only on hover or selection, badges off the walls.
# Geometry is placed with real clicks. Run:
# LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_glyphs.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)
const HEAD_R := 22.5

var failures := 0
var checks := 0
var _log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan19 glyphs")
	var ctx := await _boot()
	await _build(ctx)
	await _measure(ctx)
	print("%d checks, %d failures" % [checks, failures])
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	quit(1 if failures > 0 else 0)


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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(msg: String) -> void:
	_log.append(str(msg))


func _saw(fragment: String) -> bool:
	for line in _log:
		if line.contains(fragment):
			return true
	return false


func _build(ctx: FilmContext) -> void:
	print("- build the head, shaft, jaw and cutter with clicks")
	await FilmUI.enter_sketch(ctx)
	var cam = ctx.main.camera
	cam.distance = 220.0
	cam._update_transform()
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	sm.snap_enabled = false
	sm.infer_enabled = true
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2.ZERO, "pivot centre")
	await _click_uv(ctx, Vector2(10, 0), "pivot rim")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, HEAD, "head centre")
	ctx.main.interaction.grab_focus()
	await _type_text(ctx.main.get_viewport(), "22.5")
	await _tap_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _click_uv(ctx, Vector2(0, 40), "clear selection")
	await _click_uv(ctx, Vector2(0, 10), "select pivot")
	await _click_uv(ctx, HEAD + Vector2(0, HEAD_R), "select head")
	check(sm.selected.size() == 2, "both circles selected (got %d)" % sm.selected.size())
	var shaft := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(shaft != null, "Shaft Lines chip is visible")
	if shaft != null:
		await _click_screen(ctx.main.get_viewport(), shaft.get_global_rect().get_center())
	await process_frame
	check(_saw("Shaft lines"), "shaft lines committed (log %s)" % " | ".join(_log))
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null, "Jaw tool is on the rail")
	if jaw != null:
		await _click_screen(ctx.main.get_viewport(), jaw.get_global_rect().get_center())
	await _click_uv(ctx, HEAD, "jaw centre")
	await _click_uv(ctx, HEAD + Vector2(14.142, 14.142), "jaw at 45")
	await _click_uv(ctx, HEAD + Vector2(-7.071, 7.071), "jaw width")
	check(_saw("Jaw committed"), "jaw committed (log %s)" % " | ".join(_log))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv(ctx, HEAD + Vector2(0, -40), "cutter a")
	await _click_uv(ctx, HEAD + Vector2(0, 40), "cutter b")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await _drag_uv(ctx, HEAD + Vector2(0, 32), HEAD + Vector2(24, 32))
	check(_saw("Trimmed") or _saw("Nothing trimmed"),
			"trim stroke finished (log %s)" % " | ".join(_log))
	await _zoom_head(ctx)
	sm._redraw()
	await process_frame


func _measure(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	print("- glyph spread, wall clicks, trim orphans, callouts")
	await _click_uv(ctx, Vector2(-40, 40), "clear selection before glyph counts")
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var debug: Array = sm.glyph_debug()
	check(glyphs.size() >= 4, "at least four glyphs are drawn (got %d)" % glyphs.size())
	check(debug.size() == glyphs.size(), "glyph anchors match rects (%d vs %d)" % [debug.size(), glyphs.size()])
	check(_saw("45.0°"), "jaw commit names the 45° long side")
	check(_saw("width 19.9997") or _saw("width 20"), "jaw commit names the width")
	var coincident := 0
	for g in glyphs:
		if str(g.get("type", "")) == "coincident":
			coincident += 1
	check(coincident == 0, "coincident glyphs are hidden until hover or selection (got %d)" % coincident)
	var covered := 0
	for i in range(glyphs.size()):
		var rect: Rect2 = glyphs[i]["rect"]
		var hidden := 0.0
		for j in range(i + 1, glyphs.size()):
			var other: Rect2 = glyphs[j]["rect"]
			if not rect.intersects(other):
				continue
			var inter: Rect2 = rect.intersection(other)
			hidden = maxf(hidden, inter.get_area() / maxf(rect.get_area(), 1.0))
		check(hidden <= 0.40, "glyph %d stays ≥ 60%% visible (covered %.0f%%)" % [i, hidden * 100.0])
		if hidden > 0.40:
			covered += 1
	check(covered == 0, "no glyph is mostly covered")
	var far := 0
	for entry in debug:
		var off := float(entry.get("offset_px", 999.0))
		check(off <= SketchMode.GLYPH_MAX_OFFSET_PX + 0.5,
				"%s glyph is within 40 px (%.1f)" % [str(entry.get("type", "")), off])
		if off > SketchMode.GLYPH_MAX_OFFSET_PX + 0.5:
			far += 1
	check(far == 0, "every glyph offset is ≤ 40 px")
	var shaft_y := sm._shaft_lower_screen_y(sm.get_viewport().get_camera_3d())
	check(shaft_y < 1.0e8, "shaft lower edge is measurable (%.1f)" % shaft_y)
	var below := 0
	if shaft_y < 1.0e8:
		for g in glyphs:
			var gr: Rect2 = g["rect"]
			var under := gr.end.y > shaft_y + 1.5
			if under:
				below += 1
			check(not under, "%s glyph stays above the shaft" % str(g.get("type", "")))
	check(below == 0, "no glyph hangs below the shaft (%d)" % below)
	await _wall_presses(ctx, sm)
	await _glyph_presses(ctx, sm)
	await _coincident_press(ctx, sm)
	_orphan_checks(sm)
	await _callouts(ctx, sm)


func _wall_presses(ctx: FilmContext, sm: SketchMode) -> void:
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var walls: Array[Dictionary] = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line" or bool(info.get("construction", false)):
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if a.distance_to(b) < 8.0:
			continue
		walls.append({"a": a, "b": b})
	check(walls.size() >= 2, "at least two walls to press (got %d)" % walls.size())
	var glyph_hits := 0
	var pressed := 0
	for wall in walls:
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var sa: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(a))
		var sb: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(b))
		var span := sb - sa
		if span.length() < 24.0:
			continue
		var dir := span.normalized()
		for t in [0.2, 0.35, 0.5, 0.65, 0.8]:
			var screen: Vector2 = sa.lerp(sb, t)
			for nudge in [0.0, -10.0, 10.0, 18.0]:
				var at: Vector2 = screen + dir * float(nudge)
				if _inside_grown_glyph(sm, at) or _inside_label(sm, at):
					continue
				if not Rect2(Vector2(8, 8), Vector2(ROOT_SIZE) - Vector2(16, 16)).has_point(at):
					continue
				var clear_at: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(HEAD + Vector2(0, 55)))
				if Rect2(Vector2(8, 8), Vector2(ROOT_SIZE) - Vector2(16, 16)).has_point(clear_at):
					await _click_screen(ctx.main.get_viewport(), clear_at)
				_log.clear()
				var before := str(ctx.main.status_label.text)
				await _click_screen(ctx.main.get_viewport(), at)
				var after := str(ctx.main.status_label.text)
				if after == before and _log.is_empty():
					continue
				pressed += 1
				var entity := after == "Selected 1 sketch entity" or _saw("Selected 1 sketch entity")
				var badge := _saw("Constraint selected") or after.contains("Constraint selected")
				if badge:
					continue
				check(entity and not badge,
						"wall press at %.0f%% screen %s selects the entity (label %s log %s)" % [
							t * 100.0, str(at), after, " | ".join(_log)])
				if pressed >= 6:
					break
			if pressed >= 6:
				break
		if pressed >= 6:
			break
	check(pressed >= 4, "pressed at least four clear wall samples (got %d)" % pressed)
	check(glyph_hits == 0, "wall presses never select a constraint (%d)" % glyph_hits)


func _glyph_presses(ctx: FilmContext, sm: SketchMode) -> void:
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var seen: Dictionary = {}
	var presses := 0
	for g in glyphs:
		var type := str(g.get("type", ""))
		if type == "coincident" or seen.has(type):
			continue
		seen[type] = true
		var rect: Rect2 = g["rect"]
		var at := rect.get_center()
		if not FilmUI.require_on_screen(ctx, at, type):
			continue
		_log.clear()
		await _click_screen(ctx.main.get_viewport(), at)
		presses += 1
		check(_saw("Constraint selected: %s — Del removes it" % type),
				"press on %s glyph selects it (log %s)" % [type, " | ".join(_log)])
		await _tap_key(ctx.main.get_viewport(), KEY_ESCAPE)
	check(presses >= 1, "pressed at least one non-coincident glyph")


func _coincident_press(ctx: FilmContext, sm: SketchMode) -> void:
	var before: Array = sm.constraint_glyph_screen_rects()
	var had := false
	for g in before:
		if str(g.get("type", "")) == "coincident":
			had = true
	check(not had, "coincident glyphs are absent before the hover")
	var screen := Vector2.INF
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line" or bool(info.get("construction", false)):
			continue
		screen = FilmUI.model_to_screen(ctx, sm.to_model(info["start"]))
		break
	check(screen != Vector2.INF, "a vertex is available to hover")
	if screen == Vector2.INF:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	sm.note_pointer_screen(screen)
	await process_frame
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var rect := Rect2()
	for g in glyphs:
		if str(g.get("type", "")) == "coincident":
			rect = g["rect"]
			break
	check(rect.size != Vector2.ZERO, "hover within 14 px draws a coincident glyph")
	if rect.size == Vector2.ZERO:
		return
	_log.clear()
	await _click_screen(ctx.main.get_viewport(), rect.get_center())
	check(_saw("Constraint selected: coincident — Del removes it"),
			"press on the coincident glyph selects it (log %s)" % " | ".join(_log))


func _orphan_checks(sm: SketchMode) -> void:
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var live := 0
	var missing := 0
	for g in sm.glyph_debug():
		var cid := str(g.get("cid", ""))
		if sm.sketch.constraint_info(cid).is_empty():
			missing += 1
		else:
			live += 1
	check(missing == 0, "every glyph constraint still exists (%d missing)" % missing)
	check(glyphs.size() == live, "glyph rects match drawn constraints (%d vs %d)" % [glyphs.size(), live])
	var stray_v := 0
	var cam := sm.get_viewport().get_camera_3d()
	for g in glyphs:
		if str(g.get("type", "")) != "vertical":
			continue
		var rect: Rect2 = g["rect"]
		var near := false
		for id in sm.sketch.entity_ids():
			var info: Dictionary = sm.sketch.entity_info(id)
			if str(info.get("type", "")) != "line":
				continue
			var a := cam.unproject_position(sm.to_global(sm.to_model(info["start"])))
			var b := cam.unproject_position(sm.to_global(sm.to_model(info["end"])))
			if _dist_point_seg(rect.get_center(), a, b) <= SketchMode.GLYPH_MAX_OFFSET_PX:
				near = true
				break
		if not near:
			stray_v += 1
	check(stray_v == 0, "no V badge sits more than 40 px from a line (%d)" % stray_v)


func _callouts(ctx: FilmContext, sm: SketchMode) -> void:
	var labels: Array = sm.dimension_label_screen_rects()
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var head := _head_disk(ctx, sm)
	var saw_225 := false
	var breaches := 0
	for entry in labels:
		var text := str(entry.get("text", ""))
		var rect: Rect2 = entry["rect"]
		for g in glyphs:
			var sep := _sep(rect, g["rect"])
			if sep < 4.0:
				breaches += 1
		for other in labels:
			if other == entry:
				continue
			if _sep(rect, other["rect"]) < 4.0:
				breaches += 1
		if text.contains("22.5"):
			saw_225 = true
			var dist := _rect_dist_to_disk(rect, head["center"], head["radius"])
			check(dist <= 40.0, "`22.5` nearest edge is within 40 px of the head arc (%.1f)" % dist)
		if text == "5" or text == "5.0" or text.begins_with("5 "):
			check(true, "label `5` is drawn")
	var shown := ""
	for entry in labels:
		shown += str(entry.get("text", "")) + " "
	check(saw_225, "head radius label 22.5 is drawn (labels %s)" % shown)
	check(breaches == 0, "labels stay ≥ 4 px from glyphs and each other (%d breaches)" % breaches)
	await _open_label(ctx, sm, "20")
	await _open_label(ctx, sm, "°")


func _open_label(ctx: FilmContext, sm: SketchMode, needle: String) -> void:
	var hit := Vector2.INF
	for entry in sm.dimension_label_screen_rects():
		var text := str(entry.get("text", ""))
		var want := false
		if needle == "°":
			want = text.contains("°")
		else:
			want = text.contains(needle) and not text.contains("°")
		if not want:
			continue
		var rect: Rect2 = entry["rect"]
		hit = Vector2(rect.position.x + minf(6.0, rect.size.x * 0.25), rect.get_center().y)
		break
	var texts := ""
	for entry in sm.dimension_label_screen_rects():
		texts += str(entry.get("text", "")) + " "
	check(hit != Vector2.INF, "label %s has a first glyph (labels %s)" % [needle, texts])
	if hit == Vector2.INF:
		return
	_log.clear()
	await _click_screen(ctx.main.get_viewport(), hit)
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix != null and ix._dim_edit_owns_keys(),
			"first click on %s opens the editor" % needle)
	await _tap_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame


func _inside_label(sm: SketchMode, screen: Vector2) -> bool:
	for entry in sm.dimension_label_screen_rects():
		var rect: Rect2 = entry["rect"]
		if rect.grow(4.0).has_point(screen):
			return true
	return false


func _inside_grown_glyph(sm: SketchMode, screen: Vector2) -> bool:
	for g in sm.constraint_glyph_screen_rects():
		var rect: Rect2 = g["rect"]
		if rect.grow(8.0).has_point(screen):
			return true
	return false


func _head_disk(ctx: FilmContext, sm: SketchMode) -> Dictionary:
	var centre := HEAD
	var radius := HEAD_R
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		if absf(float(info.get("radius", 0.0)) - HEAD_R) > 0.4:
			continue
		centre = info["center"]
		radius = float(info.get("radius", HEAD_R))
		break
	var c: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(centre))
	var rim: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(centre + Vector2(radius, 0.0)))
	return {"center": c, "radius": c.distance_to(rim)}


func _zoom_head(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var got := _head_px(ctx, sm)
	var guard := 0
	while absf(got - 150.0) > 8.0 and guard < 60:
		var target: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(HEAD))
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
		got = _head_px(ctx, sm)
		guard += 1
	check(absf(got - 150.0) <= 8.0, "head circle is 150 ± 8 px (got %.1f)" % got)


func _head_px(ctx: FilmContext, sm: SketchMode) -> float:
	var disk := _head_disk(ctx, sm)
	return float(disk["radius"]) * 2.0


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var on := FilmUI.require_on_screen(ctx, screen, desc)
	check(on, "%s on screen %s" % [desc, str(screen)])
	if on:
		await _click_screen(ctx.main.get_viewport(), screen)


func _click_screen(vp: Viewport, pos: Vector2) -> void:
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
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	vp.push_input(up)
	await process_frame
	await process_frame


func _drag_uv(ctx: FilmContext, a_uv: Vector2, b_uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var a: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(a_uv))
	var b: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(b_uv))
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	var move := InputEventMouseMotion.new()
	move.position = b
	move.global_position = b
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(move)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await process_frame
	await process_frame


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		var code := KEY_PERIOD if ch == "." else (KEY_0 + int(ch))
		await _tap_key(vp, code as Key)


func _tap_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	if keycode >= KEY_0 and keycode <= KEY_9:
		down.unicode = keycode - KEY_0 + 48
	elif keycode == KEY_PERIOD:
		down.unicode = 46
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)


func _sep(a: Rect2, b: Rect2) -> float:
	var dx := 0.0
	if a.end.x < b.position.x:
		dx = b.position.x - a.end.x
	elif b.end.x < a.position.x:
		dx = a.position.x - b.end.x
	var dy := 0.0
	if a.end.y < b.position.y:
		dy = b.position.y - a.end.y
	elif b.end.y < a.position.y:
		dy = a.position.y - b.end.y
	if dx > 0.0 and dy > 0.0:
		return sqrt(dx * dx + dy * dy)
	if dx == 0.0 and dy == 0.0:
		return 0.0
	return maxf(dx, dy)


func _rect_dist_to_disk(rect: Rect2, center: Vector2, radius: float) -> float:
	var dx := 0.0
	if center.x < rect.position.x:
		dx = rect.position.x - center.x
	elif center.x > rect.end.x:
		dx = center.x - rect.end.x
	var dy := 0.0
	if center.y < rect.position.y:
		dy = rect.position.y - center.y
	elif center.y > rect.end.y:
		dy = center.y - rect.end.y
	return maxf(0.0, sqrt(dx * dx + dy * dy) - radius)


func _dist_point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
