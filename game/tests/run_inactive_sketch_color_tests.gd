# WP-V4: inactive closed sketches are SW-grey, not gold pads.
# Run: tools/godot/godot --headless --path game --script tests/run_inactive_sketch_color_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("inactive sketch colour (VS #14)")
	test_constants()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	test_open_stays_cyan(main)
	finish()


func test_constants() -> void:
	print("- closed pad/profile are grey, not gold")
	var grey := Color(0.55, 0.58, 0.62)
	check(SketchPadOverlay.PROFILE_COLOR_CLOSED.is_equal_approx(Color(grey.r, grey.g, grey.b, 1.0)),
			"PROFILE_COLOR_CLOSED is grey (0.55, 0.58, 0.62)")
	check(not SketchPadOverlay.PROFILE_COLOR_CLOSED.is_equal_approx(Color(0.98, 0.78, 0.08, 1.0)),
			"PROFILE_COLOR_CLOSED is not gold")
	check(absf(SketchPadOverlay.PAD_COLOR_CLOSED.a - 0.03) < 0.005, "pad fill alpha stays ~0.03")
	check(SketchPadOverlay.PAD_COLOR_CLOSED.r < 0.7 and SketchPadOverlay.PAD_COLOR_CLOSED.g < 0.7,
			"pad fill is grey, not gold")
	check(SketchPadOverlay.EDGE_COLOR_CLOSED.r < 0.75, "closed edge is not gold")
	check(PathOverlay.PATH_COLOR.b > 0.8, "open path overlay stays cyan")


func test_open_stays_cyan(main) -> void:
	print("- open profile colour stays cyan")
	check(SketchPadOverlay.PROFILE_COLOR_OPEN.is_equal_approx(Color(0.35, 0.88, 1.0, 1.0)),
			"open profiles stay cyan")
	check(main.view != null, "document view present")
