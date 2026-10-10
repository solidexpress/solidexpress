# Rung 1 replan 17 WP1 — constraint glyphs sit on their geometry, and a hovered
# contour fill is clearly stronger than an included one.
# Setup may use the sketch API. Every press, motion and wheel under test is a
# real Viewport.push_input event.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan17_glyphs.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(36.0, 0.0)
const HEAD_R := 22.5
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan17 WP1 glyphs and contour fill")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	await _test_g1(ctx)
	await _fresh_sketch(ctx)
	await _test_g2(ctx)
	await _fresh_sketch(ctx)
	await _test_g4_g3(ctx)
	await _fresh_sketch(ctx)
	await _test_g5(ctx)
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


func _fresh_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		sm.cancel()
		await process_frame
		await process_frame
	_status_log.clear()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	if ctx.main.sketch_mode != null:
		ctx.main.sketch_mode.snap_enabled = false


func _const_f(sm: SketchMode, name: String, fallback: float) -> float:
	var consts: Dictionary = sm.get_script().get_script_constant_map()
	if consts.has(name):
		return float(consts[name])
	return fallback


func _test_g1(ctx: FilmContext) -> void:
	print("-- G1 coincident on an arc end anchors at that end")
	await _fresh_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active and sm.sketch != null, "G1 sketch is active")
	if sm == null or sm.sketch == null:
		return
	var arc_id: String = sm.sketch.add_arc(0.0, 0.0, 10.0, 0.0, PI * 0.5)
	var line_id: String = sm.sketch.add_line(10.0, 0.0, 40.0, 0.0)
	check(arc_id != "" and line_id != "", "G1 arc and line exist")
	var cid: String = sm.sketch.add_constraint("coincident", [
		{"entity": line_id, "role": "start"},
		{"entity": arc_id, "role": "start"}], 0.0)
	check(cid != "", "G1 coincident constraint exists")
	var ainfo: Dictionary = sm.sketch.entity_info(arc_id)
	var arc_pt: Vector2 = ainfo["start"]
	var centre: Vector2 = ainfo["center"]
	var line_pt: Vector2 = sm.sketch.entity_info(line_id)["start"]
	var old_mean: Vector2 = (centre + line_pt) * 0.5
	var anchor: Variant = sm._constraint_anchor(sm.sketch.constraint_info(cid))
	var dist := INF
	if anchor is Vector2:
		dist = (anchor as Vector2).distance_to(arc_pt)
	print("  G1 anchor=%s arc-start=%s centre-mean=%s dist-to-start=%.6f" % [
			str(anchor), str(arc_pt), str(old_mean), dist])
	check(anchor is Vector2 and dist < 1e-6,
			"G1 anchor equals the arc start within 1e-6 mm (got %s, start %s, centre-mean %s)" % [
				str(anchor), str(arc_pt), str(old_mean)])


func _test_g2(ctx: FilmContext) -> void:
	print("-- G2 tangent anchors sit on the shaft contact")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active and sm.sketch != null, "G2 sketch is active")
	if sm == null or sm.sketch == null:
		return
	var pivot: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var head: String = sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	check(pivot != "" and head != "", "G2 pivot r10 and head r22.5 exist")
	sm._set_selected([pivot, head])
	var added := sm.shaft_lines_selected()
	check(added == 2, "G2 shaft_lines_selected adds 2 lines (got %d)" % added)
	sm._redraw()
	await process_frame
	var tangents := 0
	var on_geom := 0
	for cid in sm.sketch.constraint_ids():
		var cinfo: Dictionary = sm.sketch.constraint_info(cid)
		if str(cinfo.get("type", "")) != "tangent":
			continue
		tangents += 1
		var parts := _tangent_refs(sm, cinfo)
		var anchor: Variant = sm._constraint_anchor(cinfo)
		if not (anchor is Vector2) or parts.is_empty():
			print("  G2 tangent %s anchor=%s parts=%s" % [cid, str(anchor), str(parts)])
			continue
		var p: Vector2 = anchor
		var line_info: Dictionary = parts["line"]
		var circ_info: Dictionary = parts["circ"]
		var ld := _dist_to_line(p, line_info["start"], line_info["end"])
		var c: Vector2 = circ_info["center"]
		var r := float(circ_info.get("radius", 0.0))
		var rim := absf(p.distance_to(c) - r)
		print("  G2 tangent %s anchor=%s line-dist=%.4f rim=%.4f r=%.3f" % [cid, str(p), ld, rim, r])
		if ld < 0.05 and rim < 0.05:
			on_geom += 1
	check(tangents >= 2, "G2 at least two tangent constraints (got %d)" % tangents)
	check(tangents > 0 and on_geom == tangents,
			"G2 every tangent anchor is within 0.05 mm of its line and its circle rim (%d/%d)" % [
				on_geom, tangents])


func _test_g4_g3(ctx: FilmContext) -> void:
	print("-- G4/G3 jaw trim at ~150 px: leaders, cap, label gap")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active and sm.sketch != null, "G4 sketch is active")
	if sm == null or sm.sketch == null:
		return
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
	check(lid != "", "G4 plain Line cutter exists")
	sm.run_solve()
	sm.fit_view()
	await process_frame
	await process_frame
	await _arm_tool(ctx, "ToolTrim")
	check(sm.tool == SketchMode.Tool.TRIM, "G4 Trim is armed")
	_status_log.clear()
	var outer: Vector2 = HEAD + JAW_DIR * 30.0
	await _drag_between(ctx, outer + JAW_DIR * 4.0, outer - JAW_DIR * 4.0)
	check(_status_has("Trimmed open jaw"),
			"G4 real Trim drag → Trimmed open jaw (log tail %s)" % _tail())
	await _zoom_head(ctx, 150.0)
	await process_frame
	await process_frame
	sm._redraw()
	await process_frame

	var max_off := _const_f(sm, "GLYPH_MAX_OFFSET_PX", 40.0)
	var leader_min := _const_f(sm, "GLYPH_LEADER_MIN_PX", 12.0)
	var gap_px := _const_f(sm, "GLYPH_LABEL_GAP_PX", 4.0)
	var has_debug: bool = sm.has_method("glyph_debug")
	check(has_debug, "G3 glyph_debug exists")
	var entries: Array = sm.glyph_debug() if has_debug else []
	print("  G3 glyph_debug count=%d" % entries.size())
	var over := 0
	var leader_needed := 0
	var leader_ok := 0
	var max_seen := 0.0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var off := float(entry.get("offset_px", 9999.0))
		max_seen = maxf(max_seen, off)
		if off > max_off + 0.5:
			over += 1
			print("  G3 over cap cid=%s type=%s offset=%.2f" % [
					str(entry.get("cid", "")), str(entry.get("type", "")), off])
		if off >= leader_min:
			leader_needed += 1
			if bool(entry.get("leader", false)):
				leader_ok += 1
	var leaders := _glyph_leaders(sm)
	print("  G3 max offset %.2f leaders-needed=%d leaders-flagged=%d GlyphLeaders=%s" % [
			max_seen, leader_needed, leader_ok, str(leaders != null)])
	check(has_debug and not entries.is_empty() and over == 0,
			"G3 every glyph offset_px <= %.1f (max %.2f, over %d, n=%d)" % [
				max_off + 0.5, max_seen, over, entries.size()])
	check(has_debug and leader_needed > 0 and leader_ok == leader_needed and leaders != null,
			"G3 offsets >= %.1f have leader and GlyphLeaders exists (%d/%d, node=%s)" % [
				leader_min, leader_ok, leader_needed, str(leaders != null)])

	var labels: Array = sm.dimension_label_screen_rects()
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var saw5 := false
	var saw_head := false
	var closest := INF
	var close_pair := ""
	var too_close := 0
	var limit := gap_px - 0.5
	for entry in labels:
		var text := str(entry.get("text", ""))
		if text == "5":
			saw5 = true
		if text == "22.5":
			saw_head = true
		var lr: Rect2 = entry["rect"]
		for g in glyphs:
			var sep := _rect_separation(lr, g["rect"])
			if sep < closest:
				closest = sep
				close_pair = "%s vs %s" % [text, str(g.get("type", ""))]
			if sep < limit:
				too_close += 1
				print("  G4 gap %.2f px between `%s` %s and %s %s" % [
						sep, text, str(lr), str(g.get("type", "")), str(g["rect"])])
	print("  G4 labels=%d glyphs=%d closest=%.2f (%s) limit=%.2f" % [
			labels.size(), glyphs.size(), closest, close_pair, limit])
	check(saw5 and saw_head, "G4 labels include `5` and `22.5`")
	check(not glyphs.is_empty() and too_close == 0,
			"G4 no glyph rect within %.2f px of a dimension label (closest %.2f %s, breaches %d)" % [
				limit, closest, close_pair, too_close])


func _test_g5(ctx: FilmContext) -> void:
	print("-- G5 hovered contour fill is clearly stronger")
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(sm != null and sm.active and sm.sketch != null, "G5 sketch is active")
	if sm == null or sm.sketch == null or chrome == null:
		return
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.sketch.add_circle(80, 10, 6)
	sm._redraw()
	await process_frame
	await process_frame
	var chips := _chips(chrome)
	check(chrome._contour_bar != null and chrome._contour_bar.visible and chips.size() == 2,
			"G5 two contour chips (n=%d)" % chips.size())
	if chips.size() < 2:
		return
	var vp: Viewport = ctx.main.get_viewport()
	await _hover_screen(vp, chips[1].get_global_rect().get_center())
	var both: Dictionary = sm.contour_highlight_state()
	var both_fills: Array = both.get("fills", [])
	var b0 := float(both_fills[0]) if both_fills.size() > 0 else -1.0
	var b1 := float(both_fills[1]) if both_fills.size() > 1 else -1.0
	print("  G5 both-on fills=%s" % str(both_fills))
	check(both_fills.size() >= 2 and b1 - b0 >= 0.45,
			"G5 included vs hovered fill differs by >= 0.45 (got %.3f - %.3f)" % [b1, b0])
	await _x11_click_screen(vp, chips[0].get_global_rect().get_center())
	await process_frame
	chips = _chips(chrome)
	check(chips.size() >= 2, "G5 chips still present after skipping region 1")
	if chips.size() < 2:
		return
	await _hover_screen(vp, chips[1].get_global_rect().get_center())
	var st: Dictionary = sm.contour_highlight_state()
	var fills: Array = st.get("fills", [])
	var f0 := float(fills[0]) if fills.size() > 0 else -1.0
	var f1 := float(fills[1]) if fills.size() > 1 else -1.0
	var skipped := -1.0
	for i in range(fills.size()):
		if not chrome._selected_contours.has(i):
			skipped = float(fills[i])
	print("  G5 fills=%s focus=%s tag=%s skipped=%s selected=%s" % [
			str(fills), str(st.get("focus", "")), str(st.get("tag", "")),
			str(skipped), str(chrome._selected_contours)])
	check(fills.size() >= 2 and f1 - f0 >= 0.45,
			"G5 fills[1] - fills[0] >= 0.45 (got %.3f - %.3f)" % [f1, f0])
	check(skipped == 0.0, "G5 skipped region fill == 0 (got %s)" % str(skipped))
	check(str(st.get("tag", "")) == "2", "G5 tag == 2 (got %s)" % str(st.get("tag")))


func _tangent_refs(sm: SketchMode, cinfo: Dictionary) -> Dictionary:
	var line_info := {}
	var circ_info := {}
	for ref in cinfo.get("refs", []):
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = sm.sketch.entity_info(str(ref.get("entity", "")))
		var kind := str(info.get("type", ""))
		if kind == "line":
			line_info = info
		elif kind == "circle" or kind == "arc":
			circ_info = info
	if line_info.is_empty() or circ_info.is_empty():
		return {}
	return {"line": line_info, "circ": circ_info}


func _dist_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len := ab.length()
	if len < 1e-9:
		return p.distance_to(a)
	return absf((p - a).cross(ab)) / len


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


func _glyph_leaders(sm: SketchMode) -> Node:
	var root := sm._constraint_glyphs
	if root == null:
		return null
	return root.find_child("GlyphLeaders", true, false)


func _chips(chrome: SketchContextChrome) -> Array:
	var out: Array = []
	if chrome == null or chrome._contour_bar == null:
		return out
	for c in chrome._contour_bar.get_children():
		if c is CheckButton and (c as Control).visible:
			out.append(c)
	return out


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


func _arm_tool(ctx: FilmContext, node_name: String) -> void:
	var btn: Button = ctx.main.find_child(node_name, true, false)
	check(btn != null and btn.is_visible_in_tree(), "%s button is visible" % node_name)
	if btn == null:
		return
	await _x11_click_screen(btn.get_viewport(), btn.get_global_rect().get_center())
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


func _hover_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	await process_frame


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


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _tail() -> String:
	return str(_status_log.slice(maxi(_status_log.size() - 6, 0)))
