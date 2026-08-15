extends SceneTree
#
# Wave 6.3: see-the-print paint toggles + bed ghost visibility
# Run: tools/godot/godot --headless --path game --script tests/run_see_the_print_tests.gd
#
var failures := 0
var checks := 0
#
func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)
#
func _init() -> void:
	print("see-the-print tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Switch to Form mode so the strip is visible.
	main._on_mode_menu(5)  # Form
	await process_frame
	# Locate the strip and toggles
	var strip = main.print_strip
	check(strip != null and strip.visible, "Print strip visible in Form")
	var thick = strip.find_child("ThicknessPaint", true, false) as CheckBox
	var over = strip.find_child("OverhangPaint", true, false) as CheckBox
	var bed = strip.find_child("BedGhost", true, false) as CheckBox
	check(thick != null, "Thickness paint toggle exists")
	check(over != null, "Overhang paint toggle exists")
	check(bed != null, "Bed ghost toggle exists")
	# Bed ghost node in the world (under ModelSpace)
	check(main.bed_ghost != null, "bed ghost node exists")
	check(not main.bed_ghost.visible, "bed ghost hidden by default")
	# Toggle on and confirm it shows (Form-only gate applied by main)
	if bed != null:
		bed.button_pressed = true
		bed.toggled.emit(true)
		await process_frame
		check(main.bed_ghost.visible, "bed ghost shows when toggled on")
		# Toggle off
		bed.button_pressed = false
		bed.toggled.emit(false)
		await process_frame
		check(not main.bed_ghost.visible, "bed ghost hides when toggled off")
	# Summarize
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
