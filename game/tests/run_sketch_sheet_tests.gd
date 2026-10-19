# WP-V7: light sketch sheet only if rung-6 blue is unreadable on charcoal.
# COLOR_ENTITY (0.25, 0.55, 1.0) is the P6 readable-blue; films stay charcoal.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_sheet_tests.gd
extends "res://tests/lib/sx_suite.gd"

const ViewportExport = preload("res://scripts/viewport_export.gd")


func _init() -> void:
	print("sketch sheet readability (VS #2 hold)")
	test_blue_readable_on_charcoal()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await test_shop_stays_charcoal_in_sketch(main)
	finish()


func test_blue_readable_on_charcoal() -> void:
	print("- rung-6 blue vs Shop charcoal")
	var blue: Color = SketchMode.COLOR_ENTITY
	var charcoal: Color = FilmPresentation.FLAT_BG
	check(blue.is_equal_approx(Color(0.25, 0.55, 1.0)),
			"COLOR_ENTITY is rung-6 blue (0.25, 0.55, 1.0)")
	check(charcoal.is_equal_approx(Color(0.16, 0.17, 0.20)),
			"FLAT_BG stays charcoal (films un-restyled)")
	var contrast := _srgb_contrast(blue, charcoal)
	# P6 chose this blue as readable on charcoal. Skip the light sheet.
	check(contrast >= 2.2,
			"blue/charcoal contrast %.2f — skip light sketch sheet" % contrast)
	print("  skip light sketch sheet (contrast %.2f, P6 decision 13)" % contrast)


func test_shop_stays_charcoal_in_sketch(main) -> void:
	print("- Shop charcoal while sketching")
	main.set_view_backdrop("shop")
	main._start_sketch()
	await process_frame
	check(main.sketch_mode != null and main.sketch_mode.active, "sketch session active")
	var e: Environment = main._world_env.environment
	check(e.background_mode == Environment.BG_COLOR, "sketch uses BG_COLOR")
	check(e.background_color.is_equal_approx(ViewportExport.SHOP_BG),
			"sketch sheet stays Shop charcoal, not #F4F5F9")
	check(FilmPresentation.scenic_is_flat(main), "films still see charcoal Shop")
	main.sketch_mode.exit_sketch()


func _srgb_contrast(a: Color, b: Color) -> float:
	var la := _lin(a)
	var lb := _lin(b)
	var hi := maxf(la, lb)
	var lo := minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


func _lin(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
