# Headless tests for OrbitCamera zoom-toward-cursor.
# Run: tools/godot/godot --headless --path game --script tests/run_camera_tests.gd
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
	print("orbit camera zoom tests")
	root.size = Vector2i(800, 600)
	var cam := OrbitCamera.new()
	cam.name = "OrbitCamera"
	root.add_child(cam)
	await process_frame
	await process_frame
	check(is_equal_approx(cam.distance, OrbitCamera.DEFAULT_DISTANCE),
		"empty scene starts at DEFAULT_DISTANCE (%.1f mm)" % OrbitCamera.DEFAULT_DISTANCE)

	test_zoom_at_center(cam)
	test_zoom_off_center_moves_pivot(cam)
	test_repeated_zoom_converges(cam)
	test_distance_clamp(cam)
	test_orthographic_zoom(cam)
	test_zero_viewport_guard()
	test_scroll_gestures_gated(cam)
	test_nav_presets_and_fit(cam)
	await test_zoom_extents_and_zoom_out_recenter()

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _reset_cam(cam: OrbitCamera) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.pivot = Vector3.ZERO
	cam.distance = 400.0
	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(40.0)
	cam._update_transform()


func test_zoom_at_center(cam: OrbitCamera) -> void:
	print("- zoom on projected pivot leaves pivot ~unchanged")
	_reset_cam(cam)
	# Pivot is framed low on screen (VIEW_PIVOT_Y_BIAS); zoom at its projection.
	var pivot_screen := cam.unproject_position(cam.pivot)
	var pivot_before := cam.pivot
	cam.zoom_at(pivot_screen, 0.9)
	check(cam.pivot.distance_to(pivot_before) < 1e-3, "pivot-screen zoom-in pivot unchanged")
	check(is_equal_approx(cam.distance, 400.0 * 0.9), "pivot-screen zoom-in scales distance")
	cam.zoom_at(cam.unproject_position(cam.pivot), 1.0 / 0.9)
	check(cam.pivot.distance_to(pivot_before) < 1e-3, "pivot-screen zoom-out pivot unchanged")
	check(is_equal_approx(cam.distance, 400.0), "pivot-screen zoom-out restores distance")


func test_zoom_off_center_moves_pivot(cam: OrbitCamera) -> void:
	print("- zoom-in off-center moves pivot toward anchor")
	_reset_cam(cam)
	var screen := Vector2(root.size.x * 0.8, root.size.y * 0.3)
	var anchor_before := cam._zoom_anchor(screen)
	var pivot_before := cam.pivot
	var to_anchor := anchor_before - pivot_before
	check(to_anchor.length() > 1.0, "off-center screen has non-trivial anchor offset")
	cam.zoom_at(screen, 0.9)
	var expected := pivot_before + (1.0 - 0.9) * to_anchor
	check(cam.pivot.distance_to(expected) < 1e-2, "pivot shifted by (1-k)*to_anchor")
	var moved_toward := (cam.pivot - pivot_before).dot(to_anchor.normalized())
	check(moved_toward > 0.0, "pivot moved toward anchor on zoom-in")
	check(is_equal_approx(cam.distance, 400.0 * 0.9), "off-center zoom scales distance")


func test_repeated_zoom_converges(cam: OrbitCamera) -> void:
	print("- repeated zoom-in converges toward anchor / MIN_DISTANCE")
	_reset_cam(cam)
	var screen := Vector2(root.size.x * 0.75, root.size.y * 0.25)
	var first_anchor := cam._zoom_anchor(screen)
	var prev_dist_to_anchor := cam.pivot.distance_to(first_anchor)
	for i in 80:
		cam.zoom_at(screen, 0.9)
	check(is_equal_approx(cam.distance, OrbitCamera.MIN_DISTANCE), "distance clamped at MIN_DISTANCE")
	check(cam.pivot.distance_to(first_anchor) < prev_dist_to_anchor, "pivot closer to original anchor region")
	# Further zooms at the same point should not push distance below MIN.
	var d_at_min := cam.distance
	cam.zoom_at(screen, 0.9)
	check(is_equal_approx(cam.distance, d_at_min), "further zoom stays at MIN_DISTANCE")


func test_distance_clamp(cam: OrbitCamera) -> void:
	print("- zoom respects MIN/MAX distance clamp")
	_reset_cam(cam)
	var center := root.size * 0.5
	cam.distance = OrbitCamera.MIN_DISTANCE
	cam._update_transform()
	cam.zoom_at(center, 0.9)
	check(is_equal_approx(cam.distance, OrbitCamera.MIN_DISTANCE), "cannot zoom below MIN_DISTANCE")

	cam.distance = OrbitCamera.MAX_DISTANCE
	cam._update_transform()
	cam.zoom_at(center, 1.0 / 0.9)
	check(is_equal_approx(cam.distance, OrbitCamera.MAX_DISTANCE), "cannot zoom above MAX_DISTANCE")


func test_orthographic_zoom(cam: OrbitCamera) -> void:
	print("- zoom toward cursor works in orthographic")
	_reset_cam(cam)
	cam.toggle_projection()
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "projection is orthographic")
	var screen := Vector2(root.size.x * 0.2, root.size.y * 0.7)
	var pivot_before := cam.pivot
	var anchor := cam._zoom_anchor(screen)
	var to_anchor := anchor - pivot_before
	check(to_anchor.length() > 1.0, "ortho off-center anchor offset non-trivial")
	var dist_before := cam.distance
	cam.zoom_at(screen, 0.9)
	check(is_equal_approx(cam.distance, dist_before * 0.9), "ortho zoom scales distance")
	var expected := pivot_before + (1.0 - 0.9) * to_anchor
	check(cam.pivot.distance_to(expected) < 1e-2, "ortho pivot shifted toward anchor")
	# size tracks distance in ortho.
	var expected_size := 2.0 * cam.distance * tan(deg_to_rad(cam.fov) / 2.0)
	check(is_equal_approx(cam.size, expected_size), "ortho size matches distance")


func test_zero_viewport_guard() -> void:
	print("- missing / zero viewport defaults anchor to pivot (no shift)")
	# Headless Godot clamps Window size to a minimum (~64), so size (0,0) cannot
	# be forced via root.size. An orphan camera has no viewport → same guard path.
	var orphan := OrbitCamera.new()
	orphan.pivot = Vector3(10.0, 20.0, 30.0)
	orphan.distance = 400.0
	orphan.yaw = 0.0
	orphan.pitch = 0.0
	orphan._update_transform()
	check(
		orphan._zoom_anchor(Vector2(100, 100)).is_equal_approx(orphan.pivot),
		"anchor defaults to pivot without viewport"
	)
	var pivot_before := orphan.pivot
	orphan.zoom_at(Vector2(100, 100), 0.9)
	check(orphan.pivot.is_equal_approx(pivot_before), "no pivot shift without viewport")
	check(is_equal_approx(orphan.distance, 400.0 * 0.9), "distance still scales without viewport")
	orphan.free()


func test_scroll_gestures_gated(cam: OrbitCamera) -> void:
	print("- wheel / pan ignored when allow_scroll_gestures=false")
	_reset_cam(cam)
	var yaw0 := cam.yaw
	var dist0 := cam.distance
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(25, 0)
	check(not cam.is_nav_event(pan, false), "pan gesture not nav over scroll UI")
	check(not cam.handle_input(pan, false), "pan gesture not handled over scroll UI")
	check(is_equal_approx(cam.yaw, yaw0), "yaw unchanged after blocked pan")

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(100, 100)
	check(not cam.is_nav_event(wheel, false), "wheel not nav over scroll UI")
	check(not cam.handle_input(wheel, false), "wheel not handled over scroll UI")
	check(is_equal_approx(cam.distance, dist0), "distance unchanged after blocked wheel")

	check(cam.is_nav_event(pan, true), "pan gesture is nav when scroll allowed")
	check(cam.handle_input(pan, true), "pan gesture handled when scroll allowed")
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changes when pan allowed")

	# Pinch-zoom must keep working even when pan/wheel are gated for docks.
	_reset_cam(cam)
	dist0 = cam.distance
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.1  # pinch out → zoom in
	check(cam.is_nav_event(pinch, false), "magnify is nav even over scroll UI")
	check(cam.handle_input(pinch, false), "magnify handled even over scroll UI")
	check(cam.distance < dist0, "pinch-out zooms in (distance %.1f → %.1f)" % [dist0, cam.distance])

	# Ctrl+pan is a Linux fallback when MagnifyGesture is absent (XWayland).
	_reset_cam(cam)
	dist0 = cam.distance
	var ctrl_pan := InputEventPanGesture.new()
	ctrl_pan.ctrl_pressed = true
	ctrl_pan.delta = Vector2(0, -40)  # drag up → zoom in
	check(cam.is_nav_event(ctrl_pan, false), "ctrl+pan is nav even over scroll UI")
	check(cam.handle_input(ctrl_pan, false), "ctrl+pan zoom handled")
	check(cam.distance < dist0, "ctrl+pan zooms in (distance %.1f → %.1f)" % [dist0, cam.distance])


func test_nav_presets_and_fit(cam: OrbitCamera) -> void:
	print("- nav presets + selection fit helpers")
	check(cam._want_pan(false) == true, "SX: middle / 3-finger grip = pan")
	check(cam._want_pan(true) == false, "SX: Shift+middle = orbit")
	check(cam._want_alt_pan(false) == false, "SX: Alt-drag orbits")
	check(cam._want_alt_pan(true) == true, "SX: Alt+Shift pans")
	cam.nav_preset = OrbitCamera.NavPreset.FUSION
	check(cam._want_pan(false) == true, "Fusion: middle without shift = pan")
	check(cam._want_pan(true) == false, "Fusion: Shift+middle = orbit")
	check(cam._want_alt_pan(false) == true, "Fusion: Alt matches middle (pan)")
	cam.nav_preset = OrbitCamera.NavPreset.SOLIDWORKS
	check(cam._want_pan(false) == false, "SW: middle = orbit")
	check(cam._want_pan(true) == true, "SW: Shift+middle = pan")
	check(cam._want_alt_pan(false) == false, "SW: Alt-drag orbits")
	cam.nav_preset = OrbitCamera.NavPreset.SOLIDEXPRESS

	# Shift+two-finger pans; plain two-finger still orbits.
	_reset_cam(cam)
	var pivot0 := cam.pivot
	var yaw0 := cam.yaw
	var shift_pan := InputEventPanGesture.new()
	shift_pan.shift_pressed = true
	shift_pan.delta = Vector2(20, 0)
	check(cam.handle_input(shift_pan, true), "Shift+pan gesture handled")
	check(cam.pivot.distance_to(pivot0) > 1e-4, "Shift+two-finger pans pivot")
	check(is_equal_approx(cam.yaw, yaw0), "Shift+two-finger does not orbit")

	_reset_cam(cam)
	yaw0 = cam.yaw
	pivot0 = cam.pivot
	var orbit_pan := InputEventPanGesture.new()
	orbit_pan.delta = Vector2(20, 0)
	check(cam.handle_input(orbit_pan, true), "two-finger pan gesture handled")
	check(absf(cam.yaw - yaw0) > 1e-4, "two-finger drag orbits")
	check(cam.pivot.is_equal_approx(pivot0), "two-finger drag does not pan")

	# Middle-drag pans under SX (3-finger grip on clickfinger trackpads).
	_reset_cam(cam)
	pivot0 = cam.pivot
	yaw0 = cam.yaw
	var mid := InputEventMouseMotion.new()
	mid.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	mid.relative = Vector2(30, 0)
	check(cam.handle_input(mid, true), "middle-drag handled")
	check(cam.pivot.distance_to(pivot0) > 1e-4, "SX middle-drag pans")
	check(is_equal_approx(cam.yaw, yaw0), "SX middle-drag does not orbit")

	# Double-middle is claimed as a nav event.
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_MIDDLE
	dbl.pressed = true
	dbl.double_click = true
	dbl.position = Vector2(100, 100)
	check(cam.is_nav_event(dbl, true), "double-middle is a nav event")
	check(cam.handle_input(dbl, true), "double-middle handled (empty scene fit)")

	# frame_selection returns false without a selection/view.
	check(not cam.frame_selection(), "frame_selection false without selection")


func test_zoom_extents_and_zoom_out_recenter() -> void:
	print("- zoom extents centers look + frustum-fits; zoom-out recenters")
	var main_script: GDScript = load("res://scripts/main.gd") as GDScript
	var main: Node = main_script.new()
	root.add_child(main)
	await process_frame
	await process_frame
	var cam: OrbitCamera = main.camera
	var view: DocumentView = main.view
	view.new_document()
	var body: String = view.insert_primitive("box", Vector3(50, 0, 0))
	check(body != "", "inserted box for framing")
	await process_frame

	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(40.0)
	cam.distance = 2000.0
	cam.pivot = Vector3(500, 200, -300)
	cam._look_at_content = false
	cam._update_transform()

	cam.frame_contents()
	check(cam._look_at_content, "frame_contents enables centered look-at")
	check(cam.pivot.distance_to(Vector3(50, 0, 0)) < 30.0,
		"frame_contents recenters pivot near body (got %s)" % cam.pivot)
	check(cam.distance < 500.0, "frame_contents pulls distance in (got %.1f)" % cam.distance)

	# Pivot should project near viewport center when look-at-content is on.
	var pivot_screen: Vector2 = cam.unproject_position(cam.pivot)
	var center := Vector2(root.size) * 0.5
	check(pivot_screen.distance_to(center) < 40.0,
		"framed pivot near screen center (got %s vs %s)" % [pivot_screen, center])

	# Drift pivot off-model, zoom out repeatedly — soft recenter should pull back.
	cam.pivot = Vector3(800, 0, 0)
	cam.distance = cam._fit_distance_for_world_aabb(cam._visible_contents_aabb()) * 3.0
	cam._update_transform()
	var dist_to_body_before := cam.pivot.distance_to(Vector3(50, 0, 0))
	for i in 12:
		cam.zoom_at(Vector2(root.size.x * 0.9, root.size.y * 0.1), 1.12)
	check(cam.pivot.distance_to(Vector3(50, 0, 0)) < dist_to_body_before,
		"zoom-out nudges pivot toward content")
	var fit_d := cam._fit_distance_for_world_aabb(cam._visible_contents_aabb())
	check(cam.distance <= fit_d * OrbitCamera.ZOOM_OUT_MAX_FIT_MULT + 1.0,
		"zoom-out soft-capped relative to fit distance")

	main.queue_free()
	await process_frame
