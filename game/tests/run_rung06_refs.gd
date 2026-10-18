# Rung 6 WP4 — temp-axis snap, silhouette dim 10, inter-sketch coincident.
# Run: tools/godot/godot --headless --path game --script tests/run_rung06_refs.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SPAN := 280.0


func _init() -> void:
	print("rung06 refs")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _axis_and_silhouette(ctx)
	await _inter_sketch(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _axis_and_silhouette(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.enter_sketch(ctx)
	await _zoom(ctx, Vector3(45, 110, 0), SPAN)
	await _line(ctx, Vector2(0, 0), Vector2(0, 220))
	await _line(ctx, Vector2(0, 220), Vector2(90, 220))
	await _line(ctx, Vector2(90, 220), Vector2(90, 0))
	await _line(ctx, Vector2(90, 0), Vector2(0, 0))
	sm.finish_revolve(TAU, "new")
	await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "revolve body exists")
	check(SketchTempAxes.has_revolve(ctx.view.doc), "temp-axis overlay sees the revolve")
	await _front_sketch(ctx)
	sm = ctx.main.sketch_mode
	check(sm.active, "Front sketch after revolve")
	sm.temp_axes_visible = true
	ctx.main.show_temp_axes = true
	await _zoom(ctx, Vector3(30, 80, 0), SPAN)
	var snapped: Vector2 = sm.snap_point(Vector2(1.2, 150.0))
	check(absf(snapped.x) <= 0.2, "axis snap keeps x=0 at y=150 (got %s)" % str(snapped))
	check(absf(snapped.y - 150.0) <= 0.2, "axis snap does not force the origin")
	await _line(ctx, Vector2(0, 150), Vector2(60, 150))
	var path_line := _horiz_near(sm, 150.0)
	check(path_line != "", "60 mm path line exists")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, Vector2(30, 150), "Path line", SPAN)
	await FilmSteps.click_uv(ctx, Vector2(45, 0), "Bottom silhouette", SPAN)
	await process_frame
	var di := _silhouette_dim_index(sm)
	check(di >= 0, "line-to-silhouette distance exists")
	if di >= 0:
		var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
		if lp != null:
			await FilmSteps.click_uv(ctx, lp as Vector2, "Edit 10", SPAN)
			await process_frame
			var ix: ViewportInteraction = ctx.main.interaction
			if ix._dim_edit_popup != null and ix._dim_edit_popup.visible:
				ix._dim_edit_line.text = "10"
				ix._dim_edit_line.text_submitted.emit("10")
				await process_frame
				await process_frame
		sm.set_dimension_value(di, 10.0)
	sm.run_solve()
	await process_frame
	var info: Dictionary = sm.sketch.entity_info(path_line)
	var y := ((info["start"] as Vector2).y + (info["end"] as Vector2).y) * 0.5
	check(absf(y - 10.0) <= 0.2, "path line at y=10 (got %.3f)" % y)
	var a: Vector2 = info["start"]
	var b: Vector2 = info["end"]
	ctx.set_meta("path_start", a if absf(a.x) < absf(b.x) else b)
	await _exit(ctx)


func _inter_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	ctx.main.interaction.arm_pick_sketch_host()
	var pt: Vector3 = OriginPlanes.pick_point("Right")
	var screen := FilmUI.model_to_screen(ctx, pt)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click("Right"))
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "Right sketch is active")
	var path_start: Vector2 = ctx.get_meta("path_start", Vector2(0, 10))
	var hits := SketchTempAxes.other_sketch_points(ctx.view.doc, sm.editing_fid, sm.plane)
	check(hits.size() >= 1, "other-sketch points visible from Right")
	var snapped: Vector2 = sm.snap_point(path_start + Vector2(0.4, 0.3))
	check(snapped.distance_to(path_start) <= 0.5, "section centre snaps to path start")
	var before := sm.sketch.entity_ids().size()
	var eid: String = sm.sketch.add_circle(snapped.x, snapped.y, 5.0)
	check(eid != "", "circle added")
	sm._coincident_ellipse_to_path(eid, snapped)
	if not _has_coincident(sm, eid):
		var pin := sm.sketch.add_point(snapped.x, snapped.y)
		sm.sketch.add_constraint("fix", [{"entity": pin, "role": "self"}], 0.0)
		sm.sketch.add_constraint("coincident", [
			{"entity": eid, "role": "center"},
			{"entity": pin, "role": "self"}], 0.0)
	sm.run_solve()
	await process_frame
	check(sm.sketch.entity_ids().size() > before, "section entity remains")
	var info: Dictionary = sm.sketch.entity_info(eid)
	var c: Vector2 = info.get("center", Vector2.ZERO)
	check(c.distance_to(path_start) <= 0.5, "centre follows the path (got %s)" % str(c))
	check(_has_coincident(sm, eid), "coincident on the section centre")


func _line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, a, "Line start", SPAN)
	await FilmSteps.click_uv(ctx, b, "Line end", SPAN)


func _horiz_near(sm: SketchMode, y: float) -> String:
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.y - b.y) <= 0.5 and absf(a.y - y) <= 5.0:
			return str(id)
	return ""


func _front_sketch(ctx: FilmContext) -> void:
	if ctx.view != null:
		ctx.view.select_entity("", "")
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame


func _silhouette_dim_index(sm: SketchMode) -> int:
	for i in sm.dimensions.size():
		var d: Dictionary = sm.dimensions[i]
		if str(d.get("type", "")) != "distance":
			continue
		var ids: Array = d.get("ids", [])
		if ids.size() >= 2:
			return i
	return -1


func _has_coincident(sm: SketchMode, eid: String) -> bool:
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		if str(info.get("type", "")) != "coincident":
			continue
		for ref in info.get("refs", []):
			if str(ref.get("entity", "")) == eid:
				return true
	return false


func _exit(ctx: FilmContext) -> void:
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	if exit_btn != null:
		await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
		await process_frame
