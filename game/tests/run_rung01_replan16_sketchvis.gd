# Rung 1 replan 16 WP4 — sketch labels, glyphs, polygon flats, honest Trim.
# Setup may use the sketch API. Every press, key, motion and wheel under test
# is a real Viewport.push_input event.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan16_sketchvis.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(36.0, 0.0)
const HEAD_R := 22.5
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const POLY_CENTRE := "Polygon — centre set, click a vertex or type the size"
const POLY_LIVE := "^Polygon AF \\d+\\.\\d{4} — flats horizontal — click to place \\(or type the size\\)$"
const POLY_COMMIT := "Polygon AF 20.0000 — flats horizontal"
const NOTHING_TRIMMED := "Nothing trimmed — no crossing at that point"

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan16 WP4 sketch visuals")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	await _test_v1_v2(ctx)
	await _fresh_sketch(ctx)
	await _test_v3(ctx)
	await _fresh_sketch(ctx)
	await _test_v4(ctx)
	await _fresh_sketch(ctx)
	await _test_v5(ctx)
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
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
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


func _test_v1_v2(ctx: FilmContext) -> void:
	print("-- V1/V2 jaw labels and glyphs at ~150 px")
	await _fresh_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "V1 sketch is active")
	if sm == null or not sm.active:
		return
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_DIR * 30.0)
	sm.click(HEAD + JAW_ACROSS * 10.0)
	var across := JAW_ACROSS
	var mid: Vector2 = HEAD + JAW_DIR * 12.0
	var lid: String = sm.sketch.add_line(
			(mid - across * 25.0).x, (mid - across * 25.0).y,
			(mid + across * 25.0).x, (mid + across * 25.0).y)
	check(lid != "", "V1 plain Line cutter exists")
	sm.run_solve()
	sm.fit_view()
	await process_frame
	await process_frame
	await _arm_tool(ctx, "ToolTrim")
	check(sm.tool == SketchMode.Tool.TRIM, "V1 Trim is armed")
	_status_log.clear()
	var outer: Vector2 = HEAD + JAW_DIR * 30.0
	await _drag_between(ctx, outer + JAW_DIR * 4.0, outer - JAW_DIR * 4.0)
	check(_status_has("Trimmed open jaw"),
			"V1 real Trim drag → Trimmed open jaw (log tail %s)" % _tail())
	await _zoom_head(ctx, 150.0)
	await process_frame
	await process_frame
	var texts: Array[String] = []
	var label_rects: Array[Rect2] = []
	for entry in sm.dimension_label_screen_rects():
		texts.append(str(entry.get("text", "")))
		label_rects.append(entry["rect"])
	texts.sort()
	print("  V1 label texts %s" % str(texts))
	var want: Array[String] = ["20", "22.5", "45°", "5"]
	check(texts == want, "V1 label texts sorted are %s (got %s)" % [str(want), str(texts)])
	var label_hit := false
	for i in range(label_rects.size()):
		for j in range(i + 1, label_rects.size()):
			if label_rects[i].intersects(label_rects[j]):
				label_hit = true
	check(not label_hit, "V1 no two label rects intersect")
	var glyphs: Array = sm.constraint_glyph_screen_rects()
	var glyph_hit := false
	for lr in label_rects:
		for g in glyphs:
			if lr.intersects(g["rect"]):
				glyph_hit = true
	check(not glyph_hit, "V1 no label rect intersects a constraint glyph (%d glyphs)" % glyphs.size())
	var safe: Rect2 = sm._label_safe_screen_rect()
	var outside := false
	for lr in label_rects:
		if not safe.encloses(lr):
			outside = true
			print("  V1 label outside safe %s vs %s" % [str(lr), str(safe)])
	check(not outside and not label_rects.is_empty(), "V1 every label rect is inside the safe screen rect")
	var worst := _worst_glyph_overlap(glyphs)
	print("  V2 worst glyph overlap fraction %.3f (%d glyphs)" % [worst, glyphs.size()])
	check(glyphs.size() >= 2, "V2 at least two constraint glyphs are drawn")
	check(worst <= 0.20, "V2 pairwise glyph overlap ≤ 20%% of the smaller glyph (got %.1f%%)" % (worst * 100.0))
	await _arm_tool(ctx, "ToolSelect")
	check(sm.tool == SketchMode.Tool.SELECT, "V2 Select is armed")
	var glyph_at := _farthest_glyph_centre(glyphs)
	check(glyph_at != Vector2.INF, "V2 a glyph centre is available to click")
	if glyph_at != Vector2.INF:
		_status_log.clear()
		await _x11_click_screen(ctx.main.get_viewport(), glyph_at)
		await process_frame
		await process_frame
		var picked := _status_has("Constraint selected:")
		print("  V2 glyph click log %s" % _tail())
		check(picked, "V2 Select click on a glyph selects its constraint (log %s)" % _tail())


func _test_v3(ctx: FilmContext) -> void:
	print("-- V3 slot radius label sits on the slot")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "V3 sketch is active")
	if sm == null or not sm.active:
		return
	sm.slot_radius = 5.0
	sm.set_tool(SketchMode.Tool.SLOT)
	var a := Vector2(0.0, 0.0)
	sm.click(a)
	await _motion_uv(ctx, a + Vector2(40.0, 0.0))
	await process_frame
	_status_log.clear()
	await _type_text(ctx.main.get_viewport(), "150")
	await _push_key_local(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	sm.fit_view()
	await process_frame
	var box := _geometry_aabb(sm)
	print("  V3 slot aabb %s" % str(box))
	var limit := 1.5 * 5.0 + 6.0
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var shown := str(dim.get("label_text", ""))
		if shown != "5" and shown != "150":
			continue
		print("  V3 dim `%s` pos=%s stack=%s clamp=%s" % [
				shown, str(dim.get("label_pos", null)), str(dim.get("label_stack", 0)),
				str(dim.get("label_clamp", Vector2.ZERO))])
	var saw5 := false
	var saw150 := false
	for entry in sm.dimension_label_screen_rects():
		var text := str(entry.get("text", ""))
		if text != "5" and text != "150":
			continue
		var rect: Rect2 = entry["rect"]
		var uv: Variant = _screen_to_uv(ctx, rect.get_center())
		var dist := INF
		if uv != null:
			dist = _dist_to_rect(uv, box)
		print("  V3 label `%s` centre uv %s dist-to-aabb %.3f (limit %.1f)" % [text, str(uv), dist, limit])
		var near := uv != null and dist <= limit + 1e-3
		check(near, "V3 label `%s` centre is within %.1f mm of the slot AABB (got %.3f)" % [text, limit, dist])
		if text == "5":
			saw5 = true
		if text == "150":
			saw150 = true
	check(saw5, "V3 a `5` label is drawn")
	check(saw150, "V3 a `150` label is drawn")


func _test_v4(ctx: FilmContext) -> void:
	print("-- V4 polygon across-flats preview is flats-horizontal")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "V4 sketch is active")
	if sm == null or not sm.active:
		return
	await _arm_tool(ctx, "ToolPolygon")
	check(sm.tool == SketchMode.Tool.POLYGON, "V4 Polygon is armed")
	check(sm.tool_variant == "across_flats", "V4 variant is across_flats (got %s)" % sm.tool_variant)
	var centre := Vector2(8.0, 6.0)
	_status_log.clear()
	await _click_uv_local(ctx, centre)
	await process_frame
	await process_frame
	var before := str(ctx.main.status_label.text)
	print("  V4 status before first move: %s" % before)
	check(before == POLY_CENTRE, "V4 before the first move status is the centre-set sentence (got `%s`)" % before)
	var live_re := RegEx.new()
	live_re.compile(POLY_LIVE)
	var degs: Array[float] = [20.0, 70.0, 110.0]
	for deg in degs:
		var tip := centre + Vector2.from_angle(deg_to_rad(deg)) * 16.0
		await _motion_uv(ctx, tip)
		await process_frame
		var verts := _preview_vertices(sm)
		var pairs := _equal_y_pairs(verts)
		var line := str(ctx.main.status_label.text)
		print("  V4 move %.0f° verts=%d equal-y-pairs=%d status=%s" % [deg, verts.size(), pairs, line])
		check(pairs >= 2, "V4 at %.0f° preview has ≥ 2 equal-y vertex pairs (got %d, verts %s)" % [deg, pairs, str(verts)])
		check(_horizontal_flat(verts), "V4 at %.0f° preview has a horizontal flat (consecutive equal y)" % deg)
		check(live_re.search(line) != null, "V4 at %.0f° status matches the live AF sentence (got `%s`)" % [deg, line])
	await _type_text(ctx.main.get_viewport(), "20")
	await process_frame
	await process_frame
	var preview: Array[Vector2] = _preview_vertices(sm)
	print("  V4 typed preview %s" % str(preview))
	await _push_key_local(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var committed_line := ""
	for s in _status_log:
		if s == POLY_COMMIT:
			committed_line = s
	if committed_line == "":
		committed_line = str(ctx.main.status_label.text)
	print("  V4 commit status `%s`" % committed_line)
	check(committed_line == POLY_COMMIT or _status_has(POLY_COMMIT),
			"V4 Enter commits `%s` (got `%s`)" % [POLY_COMMIT, committed_line])
	var committed := _committed_vertices(sm)
	print("  V4 committed %s" % str(committed))
	check(_verts_match(preview, committed, 1e-2),
			"V4 committed vertices equal the preview (preview %s commit %s)" % [str(preview), str(committed)])


func _test_v5(ctx: FilmContext) -> void:
	print("-- V5 trim of a cutter that misses the jaw")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "V5 sketch is active")
	if sm == null or not sm.active:
		return
	sm.sketch.add_circle(HEAD.x, HEAD.y, HEAD_R)
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_DIR * 30.0)
	sm.click(HEAD + JAW_ACROSS * 10.0)
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(-20.0, 70.0))
	sm.click(Vector2(30.0, 70.0))
	sm.fit_view()
	await process_frame
	await _arm_tool(ctx, "ToolTrim")
	check(sm.tool == SketchMode.Tool.TRIM, "V5 Trim is armed")
	var before := ""
	if sm.sketch.has_method("snapshot"):
		before = sm.sketch.snapshot()
	_status_log.clear()
	await _drag_between(ctx, Vector2(-12.0, 70.0), Vector2(22.0, 70.0))
	var after := ""
	if sm.sketch.has_method("snapshot"):
		after = sm.sketch.snapshot()
	print("  V5 status log %s" % str(_status_log))
	print("  V5 label `%s`" % str(ctx.main.status_label.text))
	check(_status_has(NOTHING_TRIMMED),
			"V5 status is `%s` (log %s)" % [NOTHING_TRIMMED, _tail()])
	var bare := false
	for s in _status_log:
		if s == "Trimmed":
			bare = true
	check(not bare, "V5 never says bare Trimmed")
	check(before != "" and before == after, "V5 sketch.snapshot() is identical before and after the drag")
	_status_log.clear()
	await _push_chord(ctx.main.get_viewport(), KEY_Z, true)
	await process_frame
	await process_frame
	var undo_line := str(ctx.main.status_label.text)
	print("  V5 Ctrl+Z status `%s`" % undo_line)
	check(undo_line != "Undo: Trim" and not undo_line.begins_with("Undo: Trim"),
			"V5 Ctrl+Z is the previous action, not Undo: Trim (got `%s`)" % undo_line)


func _preview_vertices(sm: SketchMode) -> Array[Vector2]:
	if sm.has_method("polygon_preview_vertices"):
		var got: Variant = sm.polygon_preview_vertices()
		if got is Array:
			var out: Array[Vector2] = []
			for p in got:
				out.append(p)
			return out
	check(false, "polygon_preview_vertices() is missing")
	return []


func _horizontal_flat(verts: Array[Vector2]) -> bool:
	if verts.size() < 2:
		return false
	for i in range(verts.size()):
		var a: Vector2 = verts[i]
		var b: Vector2 = verts[(i + 1) % verts.size()]
		if absf(a.y - b.y) <= 1e-3 and a.distance_to(b) > 1e-3:
			return true
	return false


func _equal_y_pairs(verts: Array[Vector2]) -> int:
	var n := 0
	for i in range(verts.size()):
		for j in range(i + 1, verts.size()):
			if absf(verts[i].y - verts[j].y) <= 1e-3:
				n += 1
	return n


func _committed_vertices(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for key in ["start", "end"]:
			var p: Vector2 = info[key]
			var seen := false
			for q in out:
				if p.distance_to(q) <= 1e-2:
					seen = true
					break
			if not seen:
				out.append(p)
	return out


func _verts_match(a: Array[Vector2], b: Array[Vector2], tol: float) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	var used := {}
	for p in a:
		var found := false
		for i in range(b.size()):
			if used.has(i):
				continue
			if p.distance_to(b[i]) <= tol:
				used[i] = true
				found = true
				break
		if not found:
			return false
	return true


func _geometry_aabb(sm: SketchMode) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		match str(info.get("type", "")):
			"line":
				mn = mn.min(info["start"]).min(info["end"])
				mx = mx.max(info["start"]).max(info["end"])
			"arc", "circle":
				var c: Vector2 = info["center"]
				var r := float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
	if mn.x > mx.x:
		return Rect2()
	return Rect2(mn, mx - mn)


func _dist_to_rect(p: Vector2, box: Rect2) -> float:
	var dx := 0.0
	var dy := 0.0
	if p.x < box.position.x:
		dx = box.position.x - p.x
	elif p.x > box.end.x:
		dx = p.x - box.end.x
	if p.y < box.position.y:
		dy = box.position.y - p.y
	elif p.y > box.end.y:
		dy = p.y - box.end.y
	return sqrt(dx * dx + dy * dy)


func _screen_to_uv(ctx: FilmContext, screen: Vector2) -> Variant:
	var sm: SketchMode = ctx.main.sketch_mode
	var ray: Array = ctx.main.interaction._model_ray(screen)
	return sm.ray_to_sketch(ray[0], ray[1])


func _worst_glyph_overlap(glyphs: Array) -> float:
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


func _farthest_glyph_centre(glyphs: Array) -> Vector2:
	if glyphs.is_empty():
		return Vector2.INF
	var mean := Vector2.ZERO
	for g in glyphs:
		mean += (g["rect"] as Rect2).get_center()
	mean /= float(glyphs.size())
	var best := Vector2.INF
	var best_d := -1.0
	for g in glyphs:
		var c: Vector2 = (g["rect"] as Rect2).get_center()
		var d := c.distance_to(mean)
		if d > best_d:
			best_d = d
			best = c
	return best


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
		var centre := _head_centre(sm)
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


func _head_centre(sm: SketchMode) -> Vector2:
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		if absf(float(info.get("radius", 0.0)) - HEAD_R) <= 0.3:
			return info["center"]
	return HEAD


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


func _click_uv_local(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_0 + (ch - 48)
		await _push_key_local(vp, code, ch)


func _push_key_local(vp: Viewport, code: int, unicode: int = 0) -> void:
	await _push_chord(vp, code, false, unicode)


func _push_chord(vp: Viewport, code: int, ctrl: bool, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.unicode = unicode
		ev.pressed = pressed
		ev.echo = false
		ev.ctrl_pressed = ctrl
		vp.push_input(ev)
		await process_frame


func _status_has(needle: String) -> bool:
	if needle == "":
		return false
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _tail() -> String:
	return str(_status_log.slice(maxi(_status_log.size() - 6, 0)))
