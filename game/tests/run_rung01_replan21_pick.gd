# re-PLAN 21 WP5 — an end-on vertical edge beats the line that shares its pixel.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan21_pick.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung01 replan21 pick")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	var built: Dictionary = _build_wrench(ctx.view.doc)
	check(bool(built.get("ok", false)), "wrench body built (%s)" % str(built.get("why", "")))
	if not bool(built.get("ok", false)):
		return
	ctx.view.graph_changed()
	await process_frame
	var body: String = str(built["body"])
	var necks := _necks(ctx.view, body, float(built["x_neck"]))
	check(necks.size() >= 2, "two vertical neck edges (got %d)" % necks.size())
	_push_key_local(ctx.main.get_viewport(), KEY_3, false)
	_push_key_local(ctx.main.get_viewport(), KEY_F, false)
	await _frames(3)
	var cam: OrbitCamera = ctx.main.camera
	print("- red step: near point z and visibility in Top view")
	for neck in necks:
		var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
		var pts: PackedVector3Array = lines[neck["id"]]
		var screen: Vector2 = ctx.view.model_to_screen(cam, neck["mid"])
		var near: Dictionary = ctx.view._polyline_screen_nearest(cam, screen, pts)
		var vis: bool = ctx.view._edge_point_visible(cam, near["point"])
		var first_z := pts[0].z if pts.size() > 0 else -1.0
		print("PICK-RED y=%.2f first.z=%.3f near.z=%.3f visible=%s len=%.2f" % [neck["y"], first_z, near["point"].z, str(vis), neck["length"]])
		check(vis, "top view neck y=%.1f sample is visible (near.z=%.3f first.z=%.3f)" % [neck["y"], near["point"].z, first_z])
	for key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7]:
		_push_key_local(ctx.main.get_viewport(), key, false)
		await create_timer(0.4).timeout
		_push_key_local(ctx.main.get_viewport(), KEY_F, false)
		await create_timer(0.4).timeout
		for neck in necks:
			var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
			var pts: PackedVector3Array = lines[neck["id"]]
			var origin: Vector2 = ctx.view.model_to_screen(cam, neck["mid"])
			var near: Dictionary = ctx.view._polyline_screen_nearest(cam, origin, pts)
			var silhouette: bool = ctx.view._edge_point_visible(cam, near["point"]) and float(near["px"]) <= 2.0
			if not silhouette:
				var hidden := ctx.view.edge_near_screen(body, cam, origin, 12.0)
				check(hidden != str(neck["id"]), "view %s neck y=%.0f hidden midpoint is not picked through the body (got %s)" % [key, neck["y"], hidden])
				continue
			for jx in [-2, 0, 2]:
				for jy in [-2, 0, 2]:
					var at := origin + Vector2(jx, jy)
					var picked := ctx.view.edge_near_screen(body, cam, at, 12.0)
					var info := _edge_info(ctx.view, body, picked)
					var ok := absf(info.x) > 0.8 and info.y > 8.0 and info.y < 14.0
					check(ok, "view %s neck y=%.0f jitter %d,%d picks a vertical (dir.z=%.2f len=%.1f id=%s)" % [key, neck["y"], jx, jy, info.x, info.y, picked])
					if jx == 0 and jy == 0 and key == KEY_3:
						await _arm(ctx, body)
						_click(ctx.main.get_viewport(), at)
						await _frames(2)
						var status := str(ctx.main.status_label.text)
						check(status.contains("10.0 mm vertical") or status.contains("vertical"), "click status is the vertical (%s)" % status)
						_push_key_local(ctx.main.get_viewport(), KEY_ESCAPE, false)
						_push_key_local(ctx.main.get_viewport(), KEY_ESCAPE, false)
						await _frames(1)
	await _junction(ctx, body, float(built["x_neck"]))
	ctx.main.queue_free()


func _edge_info(view: DocumentView, body: String, edge_id: String) -> Vector2:
	if edge_id == "":
		return Vector2.ZERO
	var dir := view.edge_direction(body, edge_id)
	var lines: Dictionary = view.doc.get_edge_lines(body)
	var pts: PackedVector3Array = lines.get(edge_id, PackedVector3Array())
	var length := 0.0
	if pts.size() >= 2:
		length = pts[0].distance_to(pts[pts.size() - 1])
	return Vector2(dir.z, length)


func _junction(ctx: FilmContext, body: String, x_neck: float) -> void:
	_push_key_local(ctx.main.get_viewport(), KEY_3, false)
	_push_key_local(ctx.main.get_viewport(), KEY_F, false)
	await _frames(2)
	var cam: OrbitCamera = ctx.main.camera
	var neck := Vector3(x_neck, 10.0, 10.0)
	var along := Vector3(x_neck - 20.0, 10.0, 10.0)
	var neck_s: Vector2 = ctx.view.model_to_screen(cam, neck)
	var along_s: Vector2 = ctx.view.model_to_screen(cam, along)
	var dir := along_s - neck_s
	if dir.length() < 1.0:
		check(false, "junction has a screen direction")
		return
	dir = dir.normalized()
	var at: Vector2 = neck_s + dir * 12.0
	var picked := ctx.view.edge_near_screen(body, cam, at, 12.0)
	var info := _edge_info(ctx.view, body, picked)
	check(info.y > 20.0 and absf(info.x) < 0.5, "12 px from the junction stays on the long line (len=%.1f dir.z=%.2f)" % [info.y, info.x])
	var vertical := ctx.view.edge_near_screen(body, cam, neck_s, 12.0)
	var vinfo := _edge_info(ctx.view, body, vertical)
	check(absf(vinfo.x) > 0.8 and vinfo.y > 8.0 and vinfo.y < 14.0, "the junction pixel itself is the vertical")


func _necks(view: DocumentView, body: String, x_neck: float) -> Array:
	var out: Array = []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var delta: Vector3 = pts[pts.size() - 1] - pts[0]
		var length := delta.length()
		if length < 1e-6:
			continue
		var dir := delta / length
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(dir.z) > 0.8 and length > 8.0 and length < 14.0 and absf(mid.x - x_neck) < 3.0:
			out.append({"id": str(eid), "mid": mid, "y": mid.y, "length": length, "first_z": pts[0].z})
	return out


func _build_wrench(doc: SxDocument) -> Dictionary:
	var dx := sqrt(22.5 * 22.5 - 100.0)
	var xhit := 200.0 - dx
	var ang := atan2(10.0, -dx)
	var sk := SxSketch.new()
	sk.add_arc(0, 0, 10.0, PI / 2.0, 3.0 * PI / 2.0)
	sk.add_line(0, -10, xhit, -10)
	sk.add_arc(200.0, 0, 22.5, -ang, ang)
	sk.add_line(xhit, 10, 0, 10)
	var sk_fid: String = doc.graph_add_sketch(sk)
	if sk_fid == "":
		return {"ok": false, "why": doc.last_graph_error()}
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	if ex_fid == "":
		return {"ok": false, "why": doc.last_graph_error()}
	var body := ""
	for f in doc.graph_features():
		if str(f["id"]) == ex_fid:
			body = str(f["output_body"])
	return {"ok": body != "", "body": body, "x_neck": xhit, "why": ""}


func _arm(ctx: FilmContext, body: String) -> void:
	if ctx.view.selected_body == "":
		ctx.view.select_entity(body, "")
		await process_frame
	if ctx.main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		ctx.main.ops_panel.arm_or_apply_fillet()
		await process_frame


func _boot() -> FilmContext:
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
	return ctx


func _click(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)


func _push_key_local(vp: Viewport, code: Key, shift: bool) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = pressed
		ev.keycode = code
		ev.physical_keycode = code
		ev.shift_pressed = shift
		vp.push_input(ev)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
