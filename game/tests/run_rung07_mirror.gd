# Rung 7 WP4 — Mirror Entities adds Symmetric between original and copy.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung07_mirror.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")
const SPAN := 80.0


func _init() -> void:
	print("rung07 mirror")
	FilmUI.reset_fail_count()
	var ctx := await SpannerFixture.boot(self, Vector2i(1280, 800))
	listen_status(ctx.main)
	status_echo = true
	await _case(ctx)
	await _empty_refuses(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	await _zoom(ctx, Vector3.ZERO, SPAN)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, Vector2(-40, 0), "axis start", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(40, 0), "axis end", SPAN)
	await FilmUI.end_line_chain(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, Vector2(-20, 10), "handle start", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(20, 10), "handle end", SPAN)
	await FilmUI.end_line_chain(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(0, 0), "axis", SPAN)
	var screen := FilmUI.sketch_uv_to_screen(ctx, Vector2(0, 10))
	if screen != Vector2.ZERO:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "handle"), false, MOUSE_BUTTON_LEFT, true)
	await process_frame
	check(sm.selected.size() == 2, "axis + handle selected (got %d)" % sm.selected.size())
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.MIRROR)
	await FilmSteps.click_uv(ctx, Vector2(5, 5), "confirm mirror", SPAN)
	await process_frame
	var copies := _lines_at_y(sm, -10.0)
	check(copies.size() == 1, "copy at y=-10 (got %d)" % copies.size())
	if copies.size() == 1:
		var info: Dictionary = sm.sketch.entity_info(copies[0])
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		check(absf(a.y + 10.0) <= 0.2 and absf(b.y + 10.0) <= 0.2, "copy y=-10 ± 0.2 (got %s %s)" % [str(a), str(b)])
	var n_sym := _count_type(sm, "symmetric")
	check(n_sym >= 1, "Symmetric constraint exists (got %d)" % n_sym)
	var hi := _lines_at_y(sm, 10.0)
	var axis_ids := _lines_at_y(sm, 0.0)
	if hi.size() == 1 and copies.size() == 1 and not axis_ids.is_empty():
		var axis := axis_ids[0]
		sm.sketch.add_constraint("fix", [{"entity": axis, "role": "self"}], 0.0)
		sm.sketch.add_constraint("horizontal", [{"entity": hi[0], "role": "self"}], 0.0)
		var dim := sm.sketch.add_constraint("distance", [
			{"entity": hi[0], "role": "start"},
			{"entity": axis, "role": "self"}], 10.0)
		sm.run_solve()
		sm.sketch.set_constraint_value(dim, 12.0)
		sm.run_solve()
		await process_frame
		var after: Dictionary = sm.sketch.entity_info(copies[0])
		var ys := [float(after["start"].y), float(after["end"].y)]
		check(absf(ys[0] + 12.0) <= 0.3 and absf(ys[1] + 12.0) <= 0.3,
				"solve keeps the copy mirrored (got %s)" % str(after))


func _empty_refuses(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(0, 30), "empty", SPAN)
	await process_frame
	var mark := status_log.size()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.MIRROR)
	await FilmSteps.click_uv(ctx, Vector2(0, 30), "empty mirror", SPAN)
	await process_frame
	var note := " ".join(status_log.slice(mark))
	if note.strip_edges() == "":
		note = str(ctx.main.status_label.text)
	check(note.contains("Mirror needs a selection"), "empty Mirror refuses (got '%s')" % note)


func _lines_at_y(sm: SketchMode, y: float) -> Array[String]:
	var out: Array[String] = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.y - y) <= 0.4 and absf(b.y - y) <= 0.4:
			out.append(str(id))
	return out


func _count_type(sm: SketchMode, kind: String) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		if str(sm.sketch.constraint_info(cid).get("type", "")) == kind:
			n += 1
	return n
