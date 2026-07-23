# Headless tests for ViewWidget hit zones + OrbitCamera named views / animate_to.
# Run: tools/godot/godot --headless --path game --script tests/run_viewcube_tests.gd
extends SceneTree

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
	print("viewcube / named view tests")
	root.size = Vector2i(800, 600)

	var cam := OrbitCamera.new()
	cam.name = "OrbitCamera"
	root.add_child(cam)

	var widget := ViewWidget.new()
	widget.name = "ViewWidget"
	widget.camera = cam
	widget.snap = true
	root.add_child(widget)

	await process_frame
	await process_frame

	test_zone_hits(widget)
	test_click_zone_top(cam, widget)
	await test_named_views(cam)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _cell_center(widget: ViewWidget, col: int, row: int) -> Vector2:
	var cell_w := widget.size.x / 3.0
	var cell_h := widget.size.y / 3.0
	return Vector2((col + 0.5) * cell_w, (row + 0.5) * cell_h)


func test_zone_hits(widget: ViewWidget) -> void:
	print("- zone_at hits all 7 zones")
	check(widget.zone_at(_cell_center(widget, 1, 1)) == "front", "center -> front")
	check(widget.zone_at(_cell_center(widget, 1, 0)) == "top", "north -> top")
	check(widget.zone_at(_cell_center(widget, 1, 2)) == "bottom", "south -> bottom")
	check(widget.zone_at(_cell_center(widget, 0, 1)) == "left", "west -> left")
	check(widget.zone_at(_cell_center(widget, 2, 1)) == "right", "east -> right")
	check(widget.zone_at(_cell_center(widget, 0, 0)) == "iso", "NW -> iso")
	check(widget.zone_at(_cell_center(widget, 0, 2)) == "back", "SW -> back")
	check(widget.zone_at(Vector2(-1, -1)) == "", "outside -> empty")
	check(widget.zone_at(Vector2(widget.size.x + 5, widget.size.y + 5)) == "", "far outside -> empty")


func test_click_zone_top(cam: OrbitCamera, widget: ViewWidget) -> void:
	print("- click_zone top (snap)")
	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(40.0)
	cam._update_transform()
	widget.click_zone("top")
	# KEY_3 / standard top uses pitch ≈ +89° (+1.55 rad).
	check(absf(cam.pitch - deg_to_rad(89.0)) < 0.02, "top pitch near +1.55 (KEY_3)")
	check(absf(wrapf(cam.yaw, -PI, PI)) < 0.02, "top yaw near 0")


func test_named_views(cam: OrbitCamera) -> void:
	print("- named views save / restore / persist")
	# Clean slate for this run.
	for existing in cam.named_view_list():
		cam.remove_named_view(existing)
	check(cam.named_view_list().is_empty(), "starts with empty named views")

	cam.yaw = 0.4
	cam.pitch = 0.2
	cam.distance = 250.0
	cam.pivot = Vector3(10, 20, 30)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam._update_transform()
	cam.save_named_view("alpha")

	cam.yaw = -0.8
	cam.pitch = -0.3
	cam.distance = 500.0
	cam.pivot = Vector3(-5, 0, 8)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam._update_transform()
	cam.save_named_view("beta")

	var listed := cam.named_view_list()
	check(listed.has("alpha") and listed.has("beta"), "list contains alpha and beta")
	check(listed.size() == 2, "list size is 2")

	# Mutate away from both saved states.
	cam.yaw = 1.5
	cam.pitch = 0.5
	cam.distance = 100.0
	cam.pivot = Vector3.ZERO
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam._update_transform()

	check(cam.restore_named_view("alpha"), "restore alpha returns true")
	check(is_equal_approx(cam.yaw, 0.4), "alpha yaw restored")
	check(is_equal_approx(cam.pitch, 0.2), "alpha pitch restored")
	check(is_equal_approx(cam.distance, 250.0), "alpha distance restored")
	check(cam.pivot.is_equal_approx(Vector3(10, 20, 30)), "alpha pivot restored")

	check(cam.restore_named_view("beta"), "restore beta returns true")
	check(is_equal_approx(cam.yaw, -0.8), "beta yaw restored")
	check(is_equal_approx(cam.pitch, -0.3), "beta pitch restored")
	check(is_equal_approx(cam.distance, 500.0), "beta distance restored")
	check(cam.pivot.is_equal_approx(Vector3(-5, 0, 8)), "beta pivot restored")
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "beta projection restored")

	check(cam.remove_named_view("alpha"), "remove alpha works")
	check(not cam.named_view_list().has("alpha"), "alpha gone from list")
	check(cam.named_view_list().has("beta"), "beta still present")

	# Re-save alpha so both exist on disk for reload check.
	cam._look_at_content = true
	cam.yaw = 0.4
	cam.pitch = 0.2
	cam.distance = 250.0
	cam.pivot = Vector3(10, 20, 30)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam._update_transform()
	cam.save_named_view("alpha")

	# Fresh instance must reload from user://views.cfg in _ready.
	var cam2 := OrbitCamera.new()
	cam2.name = "OrbitCameraReload"
	root.add_child(cam2)
	await process_frame
	var reloaded := cam2.named_view_list()
	check(reloaded.has("alpha") and reloaded.has("beta"), "fresh camera reloads persisted views")
	check(cam2.restore_named_view("beta"), "reloaded restore beta")
	check(is_equal_approx(cam2.yaw, -0.8), "reloaded beta yaw")
	check(is_equal_approx(cam2.distance, 500.0), "reloaded beta distance")
	check(cam2.restore_named_view("alpha"), "reloaded restore alpha")
	check(is_equal_approx(cam2.distance, 250.0), "reloaded alpha distance (zoom)")
	check(cam2._look_at_content, "reloaded alpha look_at_content")

	# Cleanup.
	check(cam2.remove_named_view("alpha"), "cleanup remove alpha")
	check(cam2.remove_named_view("beta"), "cleanup remove beta")
	check(cam2.named_view_list().is_empty(), "cleanup leaves empty list")
	# Sync first camera's in-memory dict (disk already empty).
	cam.remove_named_view("alpha")
	cam.remove_named_view("beta")
	check(cam.named_view_list().is_empty(), "first camera also empty after cleanup")
