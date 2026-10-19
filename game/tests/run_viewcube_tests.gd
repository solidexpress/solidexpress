# Headless tests for ViewWidget: each face and iso-corner clicks the matching view.
# Run: tools/godot/godot --headless --path game --script tests/run_viewcube_tests.gd
extends "res://tests/lib/sx_suite.gd"


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

	test_size(widget)
	test_click_each_face(cam, widget)
	test_click_each_corner(cam, widget)
	test_zone_at_visible(cam, widget)
	test_click_zone_top(cam, widget)
	await test_named_views(cam)

	finish()


func test_size(widget: ViewWidget) -> void:
	print("- ViewCube is 70–90 px")
	check(widget.WIDGET_SIZE >= 70.0 and widget.WIDGET_SIZE <= 90.0,
			"WIDGET_SIZE is 70–90 (got %.0f)" % widget.WIDGET_SIZE)
	check(widget.size.x >= 70.0 and widget.size.x <= 90.0, "drawn width in range")
	check(widget.size.y >= 70.0 and widget.size.y <= 90.0, "drawn height in range")


func test_click_each_face(cam: OrbitCamera, widget: ViewWidget) -> void:
	print("- click each face to the correct view")
	var faces := ["front", "back", "left", "right", "top", "bottom"]
	for z in faces:
		cam.yaw = deg_to_rad(-20.0)
		cam.pitch = deg_to_rad(15.0)
		cam._update_transform()
		widget.click_zone(z)
		var spec: Dictionary = OrbitCamera.standard_view_by_id(z)
		check(not spec.is_empty(), "%s is a standard view" % z)
		var want_yaw := deg_to_rad(float(spec["yaw"]))
		var want_pitch := deg_to_rad(float(spec["pitch"]))
		check(absf(wrapf(cam.yaw - want_yaw, -PI, PI)) < 0.02,
				"%s yaw (got %.1f want %.1f)" % [z, rad_to_deg(cam.yaw), float(spec["yaw"])])
		check(absf(cam.pitch - want_pitch) < 0.02,
				"%s pitch (got %.1f want %.1f)" % [z, rad_to_deg(cam.pitch), float(spec["pitch"])])


func test_click_each_corner(cam: OrbitCamera, widget: ViewWidget) -> void:
	print("- click each iso corner to the correct view")
	for c in ViewWidget.CORNERS:
		var z: String = str(c["id"])
		cam.yaw = 0.0
		cam.pitch = 0.0
		cam._update_transform()
		widget.click_zone(z)
		var want_yaw := deg_to_rad(float(c["yaw"]))
		var want_pitch := deg_to_rad(float(c["pitch"]))
		check(absf(wrapf(cam.yaw - want_yaw, -PI, PI)) < 0.02,
				"%s yaw (got %.1f want %.1f)" % [z, rad_to_deg(cam.yaw), float(c["yaw"])])
		check(absf(cam.pitch - want_pitch) < 0.02,
				"%s pitch (got %.1f want %.1f)" % [z, rad_to_deg(cam.pitch), float(c["pitch"])])
	# KEY_7 alias still lands Front-Top-Left iso.
	widget.click_zone("iso")
	check(absf(wrapf(cam.yaw - deg_to_rad(-35.0), -PI, PI)) < 0.02, "iso alias yaw -35")
	check(absf(cam.pitch - deg_to_rad(40.0)) < 0.02, "iso alias pitch +40")


func test_zone_at_visible(cam: OrbitCamera, widget: ViewWidget) -> void:
	print("- zone_at hits visible faces and corners")
	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(40.0)
	cam._update_transform()
	widget.queue_redraw()
	check(widget.zone_at(widget.hit_pos("front")) == "front"
			or widget.zone_at(widget.hit_pos("left")) in ["left", "front", "top", "iso_ftl"],
			"iso pose hits a visible face/corner")
	check(widget.zone_at(widget.hit_pos("iso_ftl")) == "iso_ftl", "FTL corner hit")
	check(widget.zone_at(Vector2(-1, -1)) == "", "outside -> empty")
	check(widget.zone_at(Vector2(widget.size.x + 5, widget.size.y + 5)) == "", "far outside -> empty")
	# Orient to Front and the front face centre is Front.
	cam.yaw = 0.0
	cam.pitch = 0.0
	cam._update_transform()
	check(widget.zone_at(widget.hit_pos("front")) == "front", "front-on: centre is Front")


func test_click_zone_top(cam: OrbitCamera, widget: ViewWidget) -> void:
	print("- click_zone top (snap)")
	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(40.0)
	cam._update_transform()
	widget.click_zone("top")
	check(absf(cam.pitch - deg_to_rad(90.0)) < 0.01, "top pitch is +90° (KEY_3)")
	check(absf(wrapf(cam.yaw, -PI, PI)) < 0.02, "top yaw near 0")


func test_named_views(cam: OrbitCamera) -> void:
	print("- named views save / restore / persist")
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
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "beta projection restored")

	check(cam.remove_named_view("alpha"), "remove alpha works")
	check(not cam.named_view_list().has("alpha"), "alpha gone from list")
	check(cam.named_view_list().has("beta"), "beta still present")

	cam._look_at_content = true
	cam.yaw = 0.4
	cam.pitch = 0.2
	cam.distance = 250.0
	cam.pivot = Vector3(10, 20, 30)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam._update_transform()
	cam.save_named_view("alpha")

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

	check(cam2.remove_named_view("alpha"), "cleanup remove alpha")
	check(cam2.remove_named_view("beta"), "cleanup remove beta")
	check(cam2.named_view_list().is_empty(), "cleanup leaves empty list")
	cam.remove_named_view("alpha")
	cam.remove_named_view("beta")
	check(cam.named_view_list().is_empty(), "first camera also empty after cleanup")
