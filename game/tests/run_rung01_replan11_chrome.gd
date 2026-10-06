# Rung 1 replan 11 WP7 — Centerline chips stack under the Contours row.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan11_chrome.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan11 WP7 chrome stack")
	FilmUI.reset_fail_count()
	await test_centerline_clears_contours()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_centerline_clears_contours() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(50.0, 0.0, 10.0)
	var chrome: SketchContextChrome = main.sketch_chrome
	chrome.refresh_contours(sm.sketch)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await process_frame
	await process_frame
	var contour: Control = chrome._contour_bar
	var variant: Control = chrome._variant_bar
	var cr := contour.get_global_rect()
	var vr := variant.get_global_rect()
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	check(contour.visible, "contour bar is visible")
	check(variant.visible, "variant bar is visible")
	check(cr.size.y >= 20.0 and vr.size.y >= 20.0,
			"both bars have height >= 20 (contour %.1f variant %.1f)" % [cr.size.y, vr.size.y])
	check(not cr.intersects(vr),
			"contour and variant global rects do not intersect (contour %s variant %s)" % [str(cr), str(vr)])
	check(variant.global_position.y > contour.global_position.y + contour.size.y - 1.0,
			"variant bar is strictly below the contour bar (contour y=%.1f h=%.1f variant y=%.1f)" % [
				contour.global_position.y, contour.size.y, variant.global_position.y])
	main.queue_free()
	await process_frame
	await process_frame
