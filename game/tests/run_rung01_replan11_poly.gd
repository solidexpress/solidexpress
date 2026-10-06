# Rung 1 replan 11 WP8 — typed across-flats hex stays horizontal.
# Boot main, FilmUI.enter_sketch, select Polygon (default variant is across_flats).
# The GUI nut row (A14) uses this path: centre click, type AF 20 with the pointer
# off the X axis. Export is not required; the Y extent check is the nut AF.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_poly.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan11 WP8 typed hex flats horizontal")
	FilmUI.reset_fail_count()
	await test_typed_and_dragged_hex()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_typed_and_dragged_hex() -> void:
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	sm.set_tool(SketchMode.Tool.POLYGON)
	check(sm.tool_variant == "across_flats",
			"sketch_mode.tool_variant == across_flats after set_tool(POLYGON) on a fresh sketch (got %s)" % sm.tool_variant)

	print("-- typed AF 20 with pointer at 20°")
	sm.snap_enabled = false
	sm.click(Vector2(0, 0))
	sm.hover(Vector2(18, 7))
	_status_log.clear()
	sm.commit_at_length(20.0)
	var typed_status := _joined_status()
	check(typed_status.contains("flats horizontal") and typed_status.contains("20"),
			"typed AF 20 status contains flats horizontal and 20 (log: %s)" % typed_status)

	var typed := _polygon_lines(sm)
	var has_flat := false
	for info in typed:
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.y - b.y) <= 1e-3 and absf(absf(a.y) - 10.0) <= 0.05:
			has_flat = true
			break
	check(has_flat, "typed AF 20 has a horizontal flat at |y| ≈ 10")

	var box := _bbox(typed)
	var x_span := box.z - box.x
	var y_span := box.w - box.y
	var expect_x := 20.0 / sqrt(3.0) * 2.0
	check(absf(x_span - expect_x) <= 0.05,
			"typed AF 20 X extent is across-corners %.4f ± 0.05 (got %.4f)" % [expect_x, x_span])
	check(absf(y_span - 20.0) <= 0.05,
			"typed AF 20 Y extent is 20 ± 0.05 (got %.4f)" % y_span)

	print("-- dragged second point at 10°")
	var after_typed: PackedStringArray = sm.sketch.entity_ids()
	var drag_c := Vector2(80.0, 0.0)
	var drag_p := drag_c + Vector2.from_angle(deg_to_rad(10.0)) * 20.0
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.click(drag_c)
	_status_log.clear()
	sm.click(drag_p)
	var dragged := _polygon_lines(sm, after_typed)
	var all_hv60 := true
	var drag_flat := false
	for info in dragged:
		var a2: Vector2 = info["start"]
		var b2: Vector2 = info["end"]
		var folded := _folded_edge_deg(a2, b2)
		if folded > 0.5 and absf(folded - 60.0) > 0.5:
			all_hv60 = false
		if absf(a2.y - b2.y) <= 1e-3:
			drag_flat = true
	check(all_hv60 and drag_flat,
			"dragged 10° hex snaps: every edge within 0.5° of horizontal or 60°, and |dy|<=1e-3 on one edge")
	var drag_status := _joined_status()
	check(drag_status.contains("flats horizontal"),
			"dragged status contains flats horizontal (log: %s)" % drag_status)

	print("-- vertex variant at 10° does not snap")
	var after_drag: PackedStringArray = sm.sketch.entity_ids()
	var vtx_c := Vector2(160.0, 0.0)
	var vtx_p := vtx_c + Vector2.from_angle(deg_to_rad(10.0)) * 20.0
	sm.set_tool_variant("vertex")
	sm.click(vtx_c)
	sm.click(vtx_p)
	var vertex_lines := _polygon_lines(sm, after_drag)
	var unsnapped := false
	for info in vertex_lines:
		var folded_v := _folded_edge_deg(info["start"], info["end"])
		if folded_v > 1.0 and absf(folded_v - 60.0) > 1.0:
			unsnapped = true
			break
	check(unsnapped,
			"vertex variant at 10° does not snap (some edge > 1° from 0° and 60°)")
	sm.set_tool_variant("across_flats")
	sm.snap_enabled = true
	await _shutdown(main)


func _polygon_lines(sm: SketchMode, skip: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var skip_set := {}
	for id in skip:
		skip_set[id] = true
	var out: Array[Dictionary] = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if skip_set.has(id):
			continue
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		out.append(info)
	return out


func _bbox(lines: Array[Dictionary]) -> Vector4:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for info in lines:
		for p in [info["start"], info["end"]]:
			var v: Vector2 = p
			min_x = minf(min_x, v.x)
			min_y = minf(min_y, v.y)
			max_x = maxf(max_x, v.x)
			max_y = maxf(max_y, v.y)
	return Vector4(min_x, min_y, max_x, max_y)


func _folded_edge_deg(a: Vector2, b: Vector2) -> float:
	var d: Vector2 = b - a
	if d.length_squared() < 1e-12:
		return 0.0
	var deg := absf(rad_to_deg(d.angle()))
	if deg > 90.0:
		deg = 180.0 - deg
	return deg


func _joined_status() -> String:
	if _status_log.is_empty():
		return ""
	return " | ".join(_status_log)


func _boot():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return main


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(main) -> void:
	main.queue_free()
	await process_frame
	await process_frame
