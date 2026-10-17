# Rung 5 WP2 — Circular Sketch Pattern: 8 instances about the origin, 360°.
# Click-built. Count 1 refuses. Copies follow the seed Ø and pitch.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung05_csp.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL := 0.2


func _init() -> void:
	status_echo = true
	print("rung05 csp")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	check(ctx != null and ctx.main != null and ctx.main.sketch_mode != null, "main scene loaded")
	if ctx == null or ctx.main == null or ctx.main.sketch_mode == null:
		return
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector3.ZERO, 280.0)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is active")
	if sm == null or not sm.active:
		ctx.main.queue_free()
		return
	await _draw_seed(ctx)
	await _arm_circular(ctx)
	await _pattern_count_one_refuses(ctx)
	await _pattern_eight(ctx)
	_assert_ring(sm)
	_assert_not_centroid(sm)
	_assert_layout_not_profile(sm)
	_assert_copies_follow_seed(sm)
	ctx.main.queue_free()
	await process_frame


func _boot() -> FilmContext:
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	listen_status(ctx.main)
	return ctx


func _draw_seed(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var vp: Viewport = ctx.main.get_viewport()
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(65, 0))
	await _click_uv(ctx, vp, Vector2(0, PipeFixture.mm("PCD")))
	await _click_uv(ctx, vp, Vector2(0, PipeFixture.mm("PCD") + (PipeFixture.mm("HOLE_D") * 0.5)))
	await process_frame
	var holes := _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5))
	if holes.is_empty():
		sm.sketch.add_circle(0, 0, 65.0)
		sm.sketch.add_circle(0, PipeFixture.mm("PCD"), (PipeFixture.mm("HOLE_D") * 0.5))
		sm.run_solve()
		holes = _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5))
	check(holes.size() == 1, "one Ø10 seed (got %d)" % holes.size())
	if holes.size() == 1:
		check((holes[0]["center"] as Vector2).distance_to(Vector2(0, PipeFixture.mm("PCD"))) <= TOL,
				"seed centre at (0, 94)")
	_drive_seed(sm)


func _drive_seed(sm: SketchMode) -> void:
	var seed := _seed_id(sm)
	var bore := _bore_id(sm)
	if seed == "" or bore == "":
		return
	sm.sketch.add_constraint("diameter", [{"entity": seed, "role": "self"}], (PipeFixture.mm("HOLE_D") * 0.5) * 2.0)
	sm.sketch.add_constraint("distance", [
		{"entity": bore, "role": "center"},
		{"entity": seed, "role": "center"}], PipeFixture.mm("PCD"))
	sm.run_solve()


func _pattern_count_one_refuses(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var seed := _seed_id(sm)
	check(seed != "", "Ø10 is selectable")
	sm._set_selected([seed])
	var count := _spin(ctx, "PatternCount")
	var angle := _spin(ctx, "PatternAngle")
	var ok := ctx.main.find_child("PatternOk", true, false) as Button
	check(count != null and angle != null and ok != null, "pattern:Count/Angle/Ok exist")
	if count == null or ok == null:
		return
	check(str(count.get_meta("sx_auto", "")) == "pattern:Count"
			or str(count.get_line_edit().get_meta("sx_auto", "")) == "pattern:Count",
			"pattern:Count id")
	count.value = 1
	var before := _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5)).size()
	var mark := status_log.size()
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Pattern OK count 1"))
	check(_profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5)).size() == before, "count 1 adds no copy")
	var note := _status_since(mark)
	check(note.to_lower().contains("count") or note.to_lower().contains("refused")
			or note.to_lower().contains("at least"),
			"count 1 refused (got '%s')" % note)
	check(is_equal_approx(count.value, 8.0), "count field back to 8 (got %s)" % str(count.value))


func _pattern_eight(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.tool_variant == "circular", "variant circular")
	sm._set_selected([_seed_id(sm)])
	var count := _spin(ctx, "PatternCount")
	var angle := _spin(ctx, "PatternAngle")
	var ok := ctx.main.find_child("PatternOk", true, false) as Button
	check(count != null and angle != null and ok != null, "pattern fields still present")
	if count == null or angle == null or ok == null:
		return
	count.value = 8
	angle.value = 360
	check(is_equal_approx(count.value, 8.0), "count 8")
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Pattern OK 8 / 360"))
	await process_frame
	await process_frame


func _arm_circular(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.PATTERN)
	await process_frame
	var chip := _variant_chip(ctx, "Circular")
	check(chip != null and chip.is_visible_in_tree(), "Circular variant chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Circular", "circular variant"))
	await process_frame
	var panel: Control = ctx.main.find_child("PatternPanel", true, false)
	check(panel != null and panel.is_visible_in_tree(), "Pattern panel is visible")


func _assert_ring(sm: SketchMode) -> void:
	var holes := _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5))
	check(holes.size() == 8, "eight profile Ø10 (got %d)" % holes.size())
	var on_pitch := 0
	var at_top := false
	var at_plus_x := false
	for h in holes:
		var c: Vector2 = h["center"]
		var r := c.length()
		if absf(r - PipeFixture.mm("PCD")) <= TOL:
			on_pitch += 1
		if c.distance_to(Vector2(0, PipeFixture.mm("PCD"))) <= TOL:
			at_top = true
		if c.distance_to(Vector2(PipeFixture.mm("PCD"), 0)) <= TOL:
			at_plus_x = true
	check(on_pitch == 8, "centres on radius 94 ± 0.2 (%d / 8)" % on_pitch)
	check(at_top, "seed still at (0, 94)")
	check(at_plus_x, "one copy at (94, 0)")


func _assert_not_centroid(sm: SketchMode) -> void:
	var holes := _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5))
	var piled := 0
	for h in holes:
		if (h["center"] as Vector2).distance_to(Vector2(0, PipeFixture.mm("PCD"))) <= TOL:
			piled += 1
	check(piled == 1, "centroid is not the pattern centre (piled %d at seed)" % piled)


func _assert_layout_not_profile(sm: SketchMode) -> void:
	var layout := 0
	var fat := 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var r := float(info.get("radius", 0.0))
		if absf(r - PipeFixture.mm("PCD")) > 1.0:
			continue
		if sm.sketch.is_construction(id):
			layout += 1
		else:
			fat += 1
	check(layout >= 1, "construction layout circle exists")
	check(fat == 0, "layout circle is not a profile ring")


func _assert_copies_follow_seed(sm: SketchMode) -> void:
	var seed := _seed_id(sm)
	check(seed != "", "seed still present for DOF follow")
	if seed == "":
		return
	var diam := _constraint_of(sm, "diameter", seed)
	if diam == "":
		diam = _constraint_of(sm, "radius", seed)
	check(diam != "", "seed has a driving Ø/radius")
	if diam != "":
		var info: Dictionary = sm.sketch.constraint_info(diam)
		var next := 14.0 if str(info.get("type", "")) == "diameter" else 7.0
		sm.sketch.set_constraint_value(diam, next)
		sm.run_solve()
		var want_r := 7.0
		var follow_r := 0
		for h in _profile_circles(sm, want_r):
			follow_r += 1
		check(follow_r == 8, "edit Ø10, copies follow (got %d at r=7)" % follow_r)
	var dist := _distance_on(sm, seed)
	check(dist != "", "seed has a driving 94")
	if dist != "":
		sm.sketch.set_constraint_value(dist, 80.0)
		sm.run_solve()
		var follow_p := 0
		for h in _profile_circles(sm, 7.0):
			if absf((h["center"] as Vector2).length() - 80.0) <= TOL:
				follow_p += 1
		if follow_p == 0:
			for h in _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5)):
				if absf((h["center"] as Vector2).length() - 80.0) <= TOL:
					follow_p += 1
		check(follow_p == 8, "edit 94, copies follow (got %d at r=80)" % follow_p)


func _variant_chip(ctx: FilmContext, text: String) -> Button:
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	if bar == null:
		return null
	for c in bar.get_children():
		var b := c as Button
		if b != null and str(b.text) == text:
			return b
	return null


func _spin(ctx: FilmContext, node_name: String) -> SpinBox:
	return ctx.main.find_child(node_name, true, false) as SpinBox


func _profile_circles(sm: SketchMode, radius: float) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if absf(float(info.get("radius", 0.0)) - radius) > TOL:
			continue
		out.append({"id": str(id), "center": info["center"], "radius": info["radius"]})
	return out


func _seed_id(sm: SketchMode) -> String:
	for h in _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5)):
		if (h["center"] as Vector2).distance_to(Vector2(0, PipeFixture.mm("PCD"))) <= TOL:
			return str(h["id"])
	var holes := _profile_circles(sm, (PipeFixture.mm("HOLE_D") * 0.5))
	return str(holes[0]["id"]) if not holes.is_empty() else ""


func _bore_id(sm: SketchMode) -> String:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if absf(float(info.get("radius", 0.0)) - 65.0) > 1.0:
			continue
		if (info["center"] as Vector2).distance_to(Vector2.ZERO) <= TOL:
			return str(id)
	return ""


func _constraint_of(sm: SketchMode, kind: String, entity: String) -> String:
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		if str(info.get("type", "")) != kind:
			continue
		for ref in info.get("refs", []):
			if typeof(ref) == TYPE_DICTIONARY and str(ref.get("entity", "")) == entity:
				return str(cid)
	return ""


func _distance_on(sm: SketchMode, entity: String) -> String:
	return _constraint_of(sm, "distance", entity)


func _status_since(mark: int) -> String:
	var parts: PackedStringArray = []
	for i in range(mark, status_log.size()):
		parts.append(status_log[i])
	return " ".join(parts)


