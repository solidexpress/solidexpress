extends SceneTree
## Rung 1 replan 11 WP1. Run:
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_views.gd

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
	print("rung01 replan11 WP1 views and end-on pick")
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	var cam: OrbitCamera = main.camera
	await _tap(main, KEY_4)
	check(absf(wrapf(cam.yaw - PI, -PI, PI)) < 0.05, "key 4 is Back yaw (got %.3f)" % cam.yaw)
	check(absf(cam.pitch) < 0.05, "key 4 pitch is 0")
	await _tap(main, KEY_6)
	check(absf(wrapf(cam.yaw - deg_to_rad(-90.0), -PI, PI)) < 0.05, "key 6 is Left yaw")
	await _tap(main, KEY_8)
	check(absf(cam.pitch - deg_to_rad(-90.0)) < 0.01, "key 8 is Bottom pitch")
	await _tap(main, KEY_3)
	check(absf(cam.pitch - deg_to_rad(90.0)) < 0.01, "key 3 still Top")
	var before_pitch := cam.pitch
	var before_yaw := cam.yaw
	cam._orbit_by(0.0, 40.0)
	check(absf(cam.pitch - before_pitch) > 0.05 or absf(wrapf(cam.yaw - before_yaw, -PI, PI)) > 0.2,
			"vertical orbit off Top moves the camera")
	var hud = main.view_hud
	var word = hud.find_child("ViewWord", true, false)
	check(word is Button, "View word is a button")
	if word is Button:
		(word as Button).pressed.emit()
	await process_frame
	check(hud._views_popup.visible, "View menu opened")
	check(hud._views_drop_btn.text == "▼", "chevron text is ▼")
	var labels: Array = []
	for c in hud._views_list.get_children():
		if c is Button:
			labels.append(str(c.text))
	check(labels.has("Back") and labels.has("Left") and labels.has("Bottom"),
			"menu lists Back Left Bottom (got %s)" % str(labels))
	hud._views_popup.hide()
	var body: String = main.view.insert_primitive("box", Vector3(0, 0, 0))
	await process_frame
	await _tap(main, KEY_3)
	var vertical := _vertical_edge(main.view, body)
	var corner := _top_of(main.view, body, vertical) + Vector3(0.3, 0.3, 0.0)
	var picked = main.view.edge_near_point(body, corner, 2.5, cam)
	check(picked == vertical, "top-view corner picks the vertical edge (got %s want %s)" % [picked, vertical])
	var dir = main.view.edge_direction(body, picked)
	check(absf(dir.z) > 0.9, "picked edge is vertical")
	main.queue_free()
	await process_frame

func _tap(main, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	main.camera.handle_input(ev)
	await process_frame

func _vertical_edge(view, body: String) -> String:
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) >= 5.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			return str(id)
	return ""

func _top_of(view, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return pts[0] if pts[0].z > pts[pts.size() - 1].z else pts[pts.size() - 1]
