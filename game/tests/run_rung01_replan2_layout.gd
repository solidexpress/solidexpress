# Rung 1 replan 2 WP1 — variant chips stack under the finish bar.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan2_layout.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan2 WP1 layout")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan2_layout.gd")
	var banned := "." + "position ="
	check(not src.contains(banned), "test source does not assign a bar position")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	main._file_popup.id_pressed.emit(0)
	await process_frame
	await process_frame
	await _assert_polygon_stack(ctx, Vector2i(1280, 800))
	await _assert_polygon_stack(ctx, Vector2i(1366, 768))
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_polygon_stack(ctx: FilmContext, size: Vector2i) -> void:
	print("- polygon chips under finish bar at %dx%d" % [size.x, size.y])
	await FilmUI.ensure_test_viewport(ctx, size)
	var sm: SketchMode = ctx.main.sketch_mode
	if not sm.active:
		await FilmUI.enter_sketch(ctx)
		await process_frame
		await process_frame
	check(sm.active, "sketch session is open at %dx%d" % [size.x, size.y])
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(chrome != null and chrome.has_method("place_variant_row"),
			"place_variant_row is published")
	var rail_x := 56.0
	if ctx.main.sketch_toolbar != null and ctx.main.sketch_toolbar.visible:
		rail_x = ctx.main.sketch_toolbar.global_position.x + ctx.main.sketch_toolbar.size.x + 8.0
	chrome.place_variant_row(rail_x)
	await process_frame
	await process_frame
	var finish: Control = chrome.find_child("FinishBar", true, false)
	var variant: Control = chrome.find_child("VariantBar", true, false)
	check(finish != null and variant != null, "finish bar and variant bar exist")
	if finish == null or variant == null:
		return
	check(finish.visible and variant.visible, "both bars visible for Polygon")
	var fr := finish.get_global_rect()
	var vr := variant.get_global_rect()
	check(fr.size.x > 8.0 and fr.size.y > 8.0,
			"finish bar has size %s at %dx%d" % [str(fr.size), size.x, size.y])
	check(vr.size.x > 8.0 and vr.size.y > 8.0,
			"variant bar has size %s at %dx%d" % [str(vr.size), size.x, size.y])
	check(not fr.intersects(vr),
			"bars do not intersect at %dx%d (finish %s variant %s)" % [
				size.x, size.y, str(fr), str(vr)])
	check(vr.position.y >= fr.position.y + fr.size.y - 0.5,
			"variant bar is below the finish bar at %dx%d (variant y=%.1f finish bottom=%.1f)" % [
				size.x, size.y, vr.position.y, fr.position.y + fr.size.y])
	var vp := chrome.get_viewport().get_visible_rect()
	check(_contained(vp, fr),
			"finish bar inside viewport at %dx%d (bar %s vp %s)" % [
				size.x, size.y, str(fr), str(vp)])
	check(_contained(vp, vr),
			"variant bar inside viewport at %dx%d (bar %s vp %s)" % [
				size.x, size.y, str(vr), str(vp)])


func _contained(outer: Rect2, inner: Rect2, eps := 1.0) -> bool:
	return inner.position.x >= outer.position.x - eps \
			and inner.position.y >= outer.position.y - eps \
			and inner.end.x <= outer.end.x + eps \
			and inner.end.y <= outer.end.y + eps
