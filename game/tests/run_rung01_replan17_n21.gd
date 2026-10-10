# N21 / N26 / N1a — glyph press selects the constraint, badges de-overlap,
# stay on the part, and the head radius label stays on its circle.
# Setup may use the sketch API. Every press and wheel under test is a real
# Viewport.push_input event at the glyph rect the layout code publishes.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan17_n21.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(36.0, 0.0)
const HEAD_R := 22.5
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan17 N21 glyph pick and spread")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	await _test_n21(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	if ctx.main != null and is_instance_valid(ctx.main):
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
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _test_n21(ctx: FilmContext) -> void:
	print("-- N21/N26/N1a trimmed jaw at ~150 px")
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active and sm.sketch != null, "sketch is active")
	if sm == null or sm.sketch == null:
		return
	sm.snap_enabled = false
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_DIR * 30.0)
	sm.click(HEAD + JAW_ACROSS * 10.0)
	var mid: Vector2 = HEAD + JAW_DIR * 12.0
	var lid: String = sm.sketch.add_line(
			(mid - JAW_ACROSS * 25.0).x, (mid - JAW_ACROSS * 25.0).y,
			(mid + JAW_ACROSS * 25.0).x, (mid + JAW_ACROSS * 25.0).y)
	check(lid != "", "plain Line cutter exists")
	sm.run_solve()
	sm.fit_view()
	await process_frame
	await process_frame
	await _arm_tool(ctx, "ToolTrim")
	check(sm.tool == SketchMode.Tool.TRIM, "Trim is armed")
	_status_log.clear()
	var outer: Vector2 = HEAD + JAW_DIR * 30.0
	await _drag_between(ctx, outer + JAW_DIR * 4.0, outer - JAW_DIR * 4.0)
	check(_status_has("Trimmed open jaw"),
			"real Trim drag → Trimmed open jaw (log tail %s)" % _tail())
	await _zoom_head(ctx, 150.0)
	await process_frame
	await process_frame
	sm._redraw()
	await process_frame

	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var ids: Array = dim.get("ids", [])
		var et := ""
		if not ids.is_empty():
			et = str(sm.sketch.entity_info(str(ids[0])).get("type", ""))
		print("  dim type=%s text=%s stack=%s clamp=%s entity=%s full=%s" % [
				str(dim.get("type", "")), str(dim.get("label_text", "")),
				str(dim.get("label_stack", "")), str(dim.get("label_clamp", "")),
				et, str(sm._full_circle_dimension(dim))])
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var entries: Array = sm.glyph_debug() if sm.has_method("glyph_debug") else []
	print("  glyphs=%d debug=%d engine-shaft=%.1f" % [
			glyphs.size(), entries.size(), sm._shaft_lower_screen_y(sm.get_viewport().get_camera_3d())])
	for g in glyphs:
		print("  glyph %s %s" % [str(g.get("type", "")), str(g["rect"])])
	check(glyphs.size() >= 4, "at least four constraint glyphs are drawn (got %d)" % glyphs.size())
	var worst := _worst_overlap(glyphs)
	print("  worst glyph overlap %.3f" % worst)
	check(worst < 0.40, "glyph rects overlap by < 40%% of the smaller (got %.1f%%)" % (worst * 100.0))

	var max_off := 0.0
	var over_cap := 0
	var leader_needed := 0
	var leader_ok := 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var off := float(entry.get("offset_px", 9999.0))
		max_off = maxf(max_off, off)
		if off > SketchMode.GLYPH_MAX_OFFSET_PX + 0.5:
			over_cap += 1
		if off >= SketchMode.GLYPH_LEADER_MIN_PX:
			leader_needed += 1
			if bool(entry.get("leader", false)):
				leader_ok += 1
	var leaders := _glyph_leaders(sm)
	var leader_span := _mesh_span(leaders)
	print("  max offset %.2f leaders-needed=%d flagged=%d span=%.2f" % [
			max_off, leader_needed, leader_ok, leader_span])
	check(over_cap == 0 and not entries.is_empty(),
			"every badge is within 40 px of its anchor (max %.2f, over %d)" % [max_off, over_cap])
	check(leader_needed > 0 and leader_ok == leader_needed and leaders != null and leader_span > 0.4,
			"badges pushed ≥ 12 px have a visible leader (%d/%d, span %.2f)" % [
				leader_ok, leader_needed, leader_span])

	var shaft_y := _shaft_lower_screen_y(ctx, sm)
	print("  shaft lower edge screen y %.1f" % shaft_y)
	check(shaft_y < 1.0e8, "shaft lower edge is measurable")
	var below := 0
	if shaft_y < 1.0e8:
		for g in glyphs:
			var rect: Rect2 = g["rect"]
			if rect.end.y > shaft_y + 1.5:
				below += 1
				print("  badge %s bottom %.1f below shaft %.1f" % [
						str(g.get("type", "")), rect.end.y, shaft_y])
	check(below == 0, "no badge extends below the shaft's lower edge (%d)" % below)

	var gap_limit := 4.0
	var too_close := 0
	var closest := INF
	var saw_225 := false
	var head_dist := INF
	var head_screen := _head_disk(ctx, sm)
	for entry in sm.dimension_label_screen_rects():
		var text := str(entry.get("text", ""))
		var lr: Rect2 = entry["rect"]
		for g in glyphs:
			var sep := _rect_separation(lr, g["rect"])
			closest = minf(closest, sep)
			if sep < gap_limit:
				too_close += 1
				print("  gap %.2f between `%s` and %s" % [sep, text, str(g.get("type", ""))])
		if text == "22.5":
			saw_225 = true
			head_dist = _rect_dist_to_disk(lr, head_screen["center"], head_screen["radius"])
			print("  22.5 rect %s dist-to-head-disk %.2f" % [str(lr), head_dist])
	print("  closest label/glyph gap %.2f" % closest)
	check(too_close == 0, "every label stays ≥ 4 px from every glyph (breaches %d, closest %.2f)" % [
			too_close, closest])
	check(closest >= 8.0, "label-to-glyph margin is more than a 4 px graze (closest %.2f)" % closest)
	check(saw_225, "head radius label `22.5` is drawn")
	check(head_dist <= 40.0, "`22.5` is within 40 px of the head circle (got %.1f)" % head_dist)
	var circle_leaders := sm.find_child("CircleLabelLeaders", true, false)
	var circle_span := _mesh_span(circle_leaders)
	check(circle_leaders != null and circle_span > 0.2,
			"full-circle labels have a visible leader (span %.2f)" % circle_span)

	await _arm_tool(ctx, "ToolSelect")
	check(sm.tool == SketchMode.Tool.SELECT, "Select is armed")
	var on_entity := 0
	var kinds: Array[String] = ["horizontal", "parallel", "coincident"]
	if _glyph_rect_of_type(glyphs, "tangent").size != Vector2.ZERO:
		kinds.append("tangent")
	for kind in kinds:
		if kind == "coincident":
			await _hover_coincident_vertex(ctx, sm)
		glyphs = sm.constraint_glyph_screen_rects()
		var rect := _glyph_rect_of_type(glyphs, kind)
		check(rect.size != Vector2.ZERO, "a %s glyph is drawn" % kind)
		if rect.size == Vector2.ZERO:
			continue
		# The drawn centre is the point constraint_hit ranks first when two
		# badges still share a corner. An entity sample can sit closer to the
		# neighbour's centre and select the wrong constraint.
		var at := rect.get_center()
		var covered := _entity_point_in_rect(ctx, sm, rect) != Vector2.INF
		if covered:
			on_entity += 1
		_status_log.clear()
		await _press_screen(ctx.main.get_viewport(), at)
		await process_frame
		await process_frame
		var needle := "Constraint selected: %s" % kind
		var picked := _status_has(needle)
		print("  press %s at %s on-entity=%s log %s" % [kind, str(at), str(covered), _tail()])
		check(picked, "left press on %s glyph selects it (`%s`, log %s)" % [kind, needle, _tail()])
	check(on_entity > 0, "at least one pressed glyph rect covers sketch geometry (%d)" % on_entity)


func _glyph_rect_of_type(glyphs: Array, kind: String) -> Rect2:
	for g in glyphs:
		if str(g.get("type", "")) == kind:
			return g["rect"]
	return Rect2()


func _entity_point_in_rect(ctx: FilmContext, sm: SketchMode, rect: Rect2) -> Vector2:
	var samples: Array[Vector2] = [rect.get_center()]
	for i in 5:
		for j in 5:
			samples.append(rect.position + rect.size * Vector2(float(i) / 4.0, float(j) / 4.0))
	for s in samples:
		if not rect.has_point(s):
			continue
		var uv: Variant = _screen_to_uv(ctx, s)
		if uv is Vector2 and sm._nearest_entity_at(uv) != "":
			return s
	return Vector2.INF


func _screen_to_uv(ctx: FilmContext, screen: Vector2) -> Variant:
	var sm: SketchMode = ctx.main.sketch_mode
	var ray: Array = ctx.main.interaction._model_ray(screen)
	return sm.ray_to_sketch(ray[0], ray[1])


func _head_disk(ctx: FilmContext, sm: SketchMode) -> Dictionary:
	var centre := HEAD
	var radius := HEAD_R
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if absf(float(info.get("radius", 0.0)) - HEAD_R) <= 0.3:
			centre = info["center"]
			radius = float(info.get("radius", HEAD_R))
			break
	var c := FilmUI.model_to_screen(ctx, sm.to_model(centre))
	var rim := FilmUI.model_to_screen(ctx, sm.to_model(centre + Vector2(radius, 0.0)))
	return {"center": c, "radius": c.distance_to(rim)}


func _shaft_lower_screen_y(ctx: FilmContext, sm: SketchMode) -> float:
	var best := -INF
	var found := false
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a := FilmUI.model_to_screen(ctx, sm.to_model(info["start"]))
		var b := FilmUI.model_to_screen(ctx, sm.to_model(info["end"]))
		var span := a.distance_to(b)
		if span < 36.0:
			continue
		if absf(a.y - b.y) > maxf(8.0, span * 0.18):
			continue
		var y := (a.y + b.y) * 0.5
		if y > best:
			best = y
			found = true
	return best if found else INF


func _worst_overlap(glyphs: Array) -> float:
	var worst := 0.0
	for i in range(glyphs.size()):
		for j in range(i + 1, glyphs.size()):
			var a: Rect2 = glyphs[i]["rect"]
			var b: Rect2 = glyphs[j]["rect"]
			if not a.intersects(b):
				continue
			var inter: Rect2 = a.intersection(b)
			var area := maxf(inter.size.x, 0.0) * maxf(inter.size.y, 0.0)
			var smaller := minf(a.size.x * a.size.y, b.size.x * b.size.y)
			if smaller > 1e-6:
				worst = maxf(worst, area / smaller)
	return worst


func _rect_separation(a: Rect2, b: Rect2) -> float:
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


func _glyph_leaders(sm: SketchMode) -> Node:
	if sm._constraint_glyphs == null:
		return null
	return sm._constraint_glyphs.find_child("GlyphLeaders", true, false)


func _mesh_span(node: Node) -> float:
	if node == null or not (node is MeshInstance3D):
		return 0.0
	var mesh: Mesh = (node as MeshInstance3D).mesh
	if mesh == null:
		return 0.0
	return mesh.get_aabb().size.length()


func _head_px(ctx: FilmContext) -> float:
	var sm: SketchMode = ctx.main.sketch_mode
	var centre := HEAD
	var radius := HEAD_R
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		if absf(float(info.get("radius", 0.0)) - HEAD_R) <= 0.3:
			centre = info["center"]
			radius = float(info.get("radius", HEAD_R))
			break
	var a := FilmUI.model_to_screen(ctx, sm.to_model(centre + Vector2(radius, 0.0)))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(centre - Vector2(radius, 0.0)))
	return a.distance_to(b)


func _zoom_head(ctx: FilmContext, want_px: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var got := _head_px(ctx)
	var guard := 0
	while absf(got - want_px) > 10.0 and guard < 48:
		var centre := HEAD
		for id in sm.sketch.entity_ids():
			var info: Dictionary = sm.sketch.entity_info(id)
			var kind := str(info.get("type", ""))
			if kind != "circle" and kind != "arc":
				continue
			if absf(float(info.get("radius", 0.0)) - HEAD_R) <= 0.3:
				centre = info["center"]
				break
		var target := FilmUI.model_to_screen(ctx, sm.to_model(centre))
		var zoom_in := got < want_px
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.factor = 1.0
		ev.position = target
		ev.global_position = target
		vp.push_input(ev)
		await process_frame
		got = _head_px(ctx)
		guard += 1
	print("  zoomed Ø45 head to %.1f px (want %.0f ± 10) in %d notches" % [got, want_px, guard])
	check(absf(got - want_px) <= 10.0, "Ø45 head projects to 150 ± 10 px (got %.1f)" % got)


func _hover_coincident_vertex(ctx: FilmContext, sm: SketchMode) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		if bool(info.get("construction", false)):
			continue
		var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(info["start"]))
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		motion.global_position = screen
		vp.push_input(motion)
		sm.note_pointer_screen(screen)
		await process_frame
		return


func _arm_tool(ctx: FilmContext, node_name: String) -> void:
	var btn: Button = ctx.main.find_child(node_name, true, false)
	check(btn != null and btn.is_visible_in_tree(), "%s button is visible" % node_name)
	if btn == null:
		return
	await _press_screen(btn.get_viewport(), btn.get_global_rect().get_center())
	await process_frame


func _drag_between(ctx: FilmContext, from_uv: Vector2, to_uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var a := FilmUI.model_to_screen(ctx, sm.to_model(from_uv))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(to_uv))
	check(FilmUI.require_on_screen(ctx, a, "trim drag start"), "trim drag start on screen %s" % str(a))
	check(FilmUI.require_on_screen(ctx, b, "trim drag end"), "trim drag end on screen %s" % str(b))
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
	for i in range(1, 9):
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / 8.0)
		m.global_position = m.position
		vp.push_input(m)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await process_frame
	await process_frame


func _press_screen(vp: Viewport, pos: Vector2) -> void:
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


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _tail() -> String:
	return str(_status_log.slice(maxi(_status_log.size() - 6, 0)))
