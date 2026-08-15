# Print-first Form strip: Analyze / Orient via visible chips (print-first.md).
# Run: tools/godot/godot --headless --path game --script tests/run_print_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("print-first Form strip tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	# Ensure a real-sized viewport so FilmUI clicks are on-screen in headless runs.
	FilmUI.ensure_test_viewport(ctx)

	await test_analyze_thin_plate(ctx, main)
	await test_orient_tall_box(ctx, main)
	await test_hole_changes_digest(ctx, main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_analyze_thin_plate(ctx: FilmContext, main) -> void:
	print("- Analyze flags a 1.2 mm plate")
	main.view.new_document()
	main.view.doc.add_box(20, 20, 1.2, Vector3.ZERO)
	main.view.doc.set_print_min_wall(2.0)
	await ctx.after_regen()
	check(main.print_strip != null and not main.print_strip.visible, "strip hidden in Model")
	main._on_mode_menu(5)
	await FilmUI.wait_frames(self, 2)
	check(main.print_strip.visible, "Form shows the print strip")
	await FilmUI.click_button(ctx, "Analyze")
	var r: Dictionary = main.view.doc.print_analyze("")
	check(not bool(r.get("wall_ok", true)), "wall_ok is false")
	check(str(r.get("digest", "")).findn("thin") >= 0, "digest says thin")
	main._on_mode_menu(0)


func test_orient_tall_box(ctx: FilmContext, main) -> void:
	print("- Orient lays an 80 mm box on the bed")
	main.view.new_document()
	main.view.doc.add_box(10, 10, 80, Vector3.ZERO)
	await ctx.after_regen()
	main._on_mode_menu(5)
	await FilmUI.wait_frames(self, 2)
	var before: Dictionary = main.view.doc.print_analyze("")
	await FilmUI.click_button(ctx, "Orient")
	var after: Dictionary = main.view.doc.print_analyze("")
	check(float(before.get("height", 0)) > 70.0, "starts ~80 mm high")
	check(float(after.get("height", 99)) < 12.0, "height drops to ~10 mm")
	check(main.view.print_preview_enabled, "Form preview applies print rotation")
	main._on_mode_menu(0)


func test_hole_changes_digest(ctx: FilmContext, main) -> void:
	print("- Analyze digest changes after a real hole")
	main.view.new_document()
	var id: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 10))
	main.view.select_entity(id, "")
	await ctx.after_regen()
	main._on_mode_menu(5)
	await FilmUI.wait_frames(self, 2)
	var before: Dictionary = main.view.doc.print_analyze(id)
	main.ops_panel._hole_diameter.value = 6.0
	main.ops_panel._hole_depth.value = 0.0
	check(main.ops_panel._apply_hole(), "hole applied")
	var after: Dictionary = main.view.doc.print_analyze(id)
	check(str(after.get("digest", "")) != str(before.get("digest", "")),
		"digest is not byte-identical after the hole")
	main._on_mode_menu(0)
