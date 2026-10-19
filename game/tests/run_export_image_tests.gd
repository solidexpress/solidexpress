# WP-V1: View Shop/Scenic/Solid/Transparent + File → Export Image (PNG alpha).
# Run: tools/godot/godot --headless --path game --script tests/run_export_image_tests.gd
extends "res://tests/lib/sx_suite.gd"

const ViewportExport = preload("res://scripts/viewport_export.gd")


func _init() -> void:
	print("export image / backdrop tests")
	test_fixture_alpha_composite()

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_menus(main)
	test_shop_default(main)
	test_transparent_keeps_lights(main)
	await test_export_spanner_png(main)
	await test_screenshot_alpha(main)

	finish()


func test_fixture_alpha_composite() -> void:
	print("- fixture PNG has alpha and composites on white with no charcoal")
	var img := ViewportExport.make_alpha_fixture(80, 45)
	check(img.get_format() == Image.FORMAT_RGBA8, "fixture is RGBA8")
	check(img.get_pixel(0, 0).a < 0.01, "fixture corner is alpha 0")
	check(img.get_pixel(40, 22).a > 0.9, "fixture body is opaque")
	var path := OS.get_user_data_dir() + "/sx_v1_fixture.png"
	check(img.save_png(path) == OK, "fixture PNG written")
	check(ViewportExport.has_real_alpha_channel(path), "fixture PNG colour type 6")
	check(ViewportExport.composites_without_charcoal(img),
			"fixture composites on white with no charcoal plate")
	var plate := ViewportExport.composite_on_white(img)
	check(plate.get_pixel(0, 0).is_equal_approx(Color.WHITE),
			"alpha-0 corner composites to white")
	check(not ViewportExport.is_charcoal(plate.get_pixel(0, 0)),
			"composited corner is not Shop charcoal")
	DirAccess.remove_absolute(path)


func test_menus(main) -> void:
	print("- View backdrop + File → Export Image")
	var labels: Dictionary = main.file_menu_id_labels()
	check(labels.get(17, "") == "Export Image...", "File menu id 17 is Export Image...")
	if main._file_popup != null:
		var idx: int = main._file_popup.get_item_index(17)
		check(idx >= 0 and main._file_popup.get_item_text(idx) == "Export Image...",
				"popup lists Export Image...")
	var popup: PopupMenu = main._view_popup
	check(popup != null, "View menu exists")
	check(popup.get_item_index(9) >= 0 and popup.get_item_text(popup.get_item_index(9)) == "Shop",
			"View → Shop")
	check(popup.get_item_index(5) >= 0 and popup.get_item_text(popup.get_item_index(5)) == "Scenic",
			"View → Scenic")
	check(popup.get_item_index(10) >= 0 and popup.get_item_text(popup.get_item_index(10)).begins_with("Solid"),
			"View → Solid…")
	check(popup.get_item_index(11) >= 0 and popup.get_item_text(popup.get_item_index(11)) == "Transparent",
			"View → Transparent")


func test_shop_default(main) -> void:
	print("- Shop is the default backdrop")
	check(main.view_backdrop == main.ViewBackdrop.SHOP, "default backdrop is Shop")
	check(not main.show_scenic_bg, "scenic flag off")
	var e: Environment = main._world_env.environment
	check(e.background_mode == Environment.BG_COLOR, "Shop uses BG_COLOR")
	check(e.background_color.is_equal_approx(ViewportExport.SHOP_BG),
			"Shop clear is charcoal (0.16, 0.17, 0.20)")


func test_transparent_keeps_lights(main) -> void:
	print("- Transparent: alpha 0 clear, KeyLight + IBL kept")
	main.set_view_backdrop("transparent")
	var e: Environment = main._world_env.environment
	check(main.view_backdrop == main.ViewBackdrop.TRANSPARENT, "backdrop is Transparent")
	check(e.background_mode == Environment.BG_COLOR, "Transparent uses BG_COLOR")
	check(e.background_color.a < 0.01, "Transparent clear alpha is 0")
	check(e.sky != null, "IBL sky stays loaded")
	check(e.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "IBL reflections stay")
	var sun := main.get_node_or_null("KeyLight") as DirectionalLight3D
	if sun == null:
		for c in main.get_children():
			if c is DirectionalLight3D:
				sun = c
				break
	check(sun != null and sun.visible and sun.light_energy > 0.01, "KeyLight stays on")
	main.set_view_backdrop("shop")
	check(main.view_backdrop == main.ViewBackdrop.SHOP, "restore Shop")


func test_export_spanner_png(main) -> void:
	print("- exported spanner PNG has real alpha, no charcoal plate")
	var id: String = ""
	if main.view.has_method("insert_open_end_blank"):
		id = main.view.insert_open_end_blank()
	if id == "":
		id = main.view.insert_primitive("box", Vector3.ZERO)
	check(id != "", "spanner / body inserted")
	if main.camera != null:
		main.camera.apply_standard_view_id("iso")
	main.set_view_backdrop("transparent")
	await process_frame
	await process_frame
	var path := OS.get_user_data_dir() + "/sx_v1_spanner.png"
	var ok: bool = await main.export_image(path)
	check(ok, "export_image wrote PNG")
	check(FileAccess.file_exists(path), "PNG exists")
	check(ViewportExport.has_real_alpha_channel(path),
			"exported PNG has a real alpha channel (colour type 6)")
	var img := Image.new()
	check(img.load(path) == OK, "PNG loads")
	check(img.get_format() == Image.FORMAT_RGBA8 or img.detect_alpha() != Image.ALPHA_NONE,
			"loaded image carries alpha")
	check(ViewportExport.composites_without_charcoal(img),
			"composites on white with no charcoal plate")
	var plate := ViewportExport.composite_on_white(img)
	check(not ViewportExport.is_charcoal(plate.get_pixel(0, 0)),
			"composited corner is not Shop charcoal")
	check(plate.get_pixel(0, 0).r > 0.9 and plate.get_pixel(0, 0).g > 0.9,
			"alpha-0 / punched corner composites near white")
	# Chrome is restored after the grab.
	var ui: Node = main.get_node_or_null("UI")
	check(ui != null, "UI layer still present")
	var status: Node = main.get_node_or_null("UI/StatusBar")
	check(status == null or status.visible, "status bar restored after export")
	main.set_view_backdrop("shop")
	DirAccess.remove_absolute(path)


func test_screenshot_alpha(main) -> void:
	print("- automation screenshot shares Export Image alpha path")
	if main.view.doc.body_ids().is_empty():
		main.view.insert_primitive("box", Vector3.ZERO)
	main.set_view_backdrop("transparent")
	var bridge = load("res://scripts/automation_bridge.gd").new()
	bridge.name = "SxAutomation"
	main.add_child(bridge)
	await process_frame
	var path := OS.get_user_data_dir() + "/sx_v2_screenshot.png"
	var reply: Dictionary = await bridge._cmd_screenshot({"path": path})
	check(not reply.has("error"), "screenshot command ok (%s)" % str(reply.get("error", "")))
	check(FileAccess.file_exists(path), "screenshot PNG exists")
	check(ViewportExport.has_real_alpha_channel(path),
			"screenshot PNG has a real alpha channel (colour type 6)")
	var img := Image.new()
	check(img.load(path) == OK, "screenshot PNG loads")
	check(ViewportExport.composites_without_charcoal(img),
			"screenshot composites on white with no charcoal plate")
	main.set_view_backdrop("shop")
	DirAccess.remove_absolute(path)
	bridge.queue_free()
