# re-PLAN 19 WP8 — the first fillet pick stays on the near edge out to 12 px,
# and a thickness rebuild does not warn that recovered edges were lost.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_fillet_pick.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan19 fillet pick")
	FilmUI.reset_fail_count()
	await _case_picks()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case_picks() -> void:
	print("- wrench fillet picks in Top view")
	var ctx := await _boot()
	var built: Dictionary = _build_wrench(ctx.view.doc)
	check(bool(built.get("ok", false)), "wrench body built (%s)" % str(built.get("why", "")))
	if not bool(built.get("ok", false)):
		await _shutdown(ctx)
		return
	ctx.view.graph_changed()
	await _frames(2)
	var body: String = str(built["body"])
	var neck_x: float = float(built["x_neck"])
	var ex_fid: String = str(built["extrude"])
	ctx.view.select_entity(body, "")
	await process_frame
	_push_key(ctx.main.get_viewport(), KEY_3, false)
	await process_frame
	_push_key(ctx.main.get_viewport(), KEY_F, false)
	await _frames(2)
	check(str(ctx.main.status_label.text).contains("Framed"),
			"Top view framed (got '%s')" % str(ctx.main.status_label.text))
	var cam: OrbitCamera = ctx.main.camera
	var neck := Vector3(neck_x, 10.0, 10.0)
	var neck_screen: Vector2 = cam.unproject_position(neck)
	var inward: Vector2 = cam.unproject_position(Vector3(neck_x - 8.0, 0.0, 10.0))
	var dir := inward - neck_screen
	check(dir.length() > 1.0, "neck vertical has an inward screen direction")
	if dir.length() < 1.0:
		await _shutdown(ctx)
		return
	dir = dir.normalized()
	var bare: Array[int] = []
	for px in [2, 5, 8, 11]:
		await _arm(ctx, body)
		var at: Vector2 = neck_screen + dir * float(px)
		_click_screen(ctx.main.get_viewport(), at)
		await _frames(2)
		var status := str(ctx.main.status_label.text)
		check(status.begins_with("Fillet: 1 edge(s) —"),
				"%d px from the neck is one edge (got '%s')" % [px, status])
		check(not status.contains("13 edge(s)"), "%d px never takes 13 edges" % px)
		bare.append(ctx.view.selected_edges.size())
		_push_key(ctx.main.get_viewport(), KEY_ESCAPE, false)
		await _frames(2)
	check(bare == [1, 1, 1, 1], "each near press selected one edge (got %s)" % str(bare))

	var head := Vector3(200.0, 0.0, 10.0)
	# Top view looks along Y, so the inset has to move in X to show on screen.
	var rim := Vector3(222.5, 0.0, 10.0)
	var zoomed := await _zoom_head_clear(cam, head, rim, 40.0)
	check(zoomed, "head centre is at least 40 px from the rim")
	for px in [14, 20, 30]:
		await _arm(ctx, body)
		var at := _screen_at_clearance(ctx.view, body, cam, head, rim, float(px))
		var nearest := _nearest_edge_px(ctx.view, body, cam, at)
		check(absf(nearest - float(px)) <= 1.5,
				"%d px sample is %.1f px from the nearest edge" % [px, nearest])
		check(ctx.view.edge_near_screen(body, cam, at, 12.0) == "",
				"%d px sample is outside the 12 px edge band" % px)
		_click_screen(ctx.main.get_viewport(), at)
		await _frames(2)
		var status := str(ctx.main.status_label.text)
		var n := _edge_count(status)
		check(n >= 6, "%d px inside the top face takes %d edges (got '%s')" % [px, n, status])
		check(not _lists_zero_line(status), "%d px status has no 0.0 mm line" % px)
		_push_key(ctx.main.get_viewport(), KEY_ESCAPE, false)
		await _frames(2)

	print("- face already selected, then the corner")
	ctx.view.clear_selection()
	await process_frame
	var face_at: Vector2 = cam.unproject_position(head)
	_click_screen(ctx.main.get_viewport(), face_at)
	await _frames(2)
	_click_screen(ctx.main.get_viewport(), face_at)
	await _frames(2)
	check(ctx.view.selected_face != "", "two real clicks pre-select a face")
	neck_screen = cam.unproject_position(neck)
	inward = cam.unproject_position(Vector3(neck_x - 8.0, 0.0, 10.0))
	dir = inward - neck_screen
	if dir.length() > 1.0:
		dir = dir.normalized()
	await _arm(ctx, body)
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES,
			"arming does not apply the pre-selected face")
	check(ctx.view.selected_edges.is_empty(), "pre-selected face is not an edge set")
	var corner: Vector2 = neck_screen + dir * 8.0
	_click_screen(ctx.main.get_viewport(), corner)
	await _frames(2)
	var corner_status := str(ctx.main.status_label.text)
	check(corner_status.begins_with("Fillet: 1 edge(s) —"),
			"pre-selected face still picks one edge (got '%s')" % corner_status)
	check(not corner_status.contains("13 edge(s)"), "pre-selected face is not the 13-edge loop")

	print("- thickness 14 keeps recovered fillet edges")
	_push_key(ctx.main.get_viewport(), KEY_ENTER, false)
	await _frames(3)
	check(_count_fillet(ctx) >= 1, "Enter applies the corner fillet")
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await _frames(2)
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await _frames(2)
	var btn := _row_name_button(tl, ex_fid)
	check(btn != null and btn.is_visible_in_tree(), "extrude row is visible")
	if btn != null:
		var pos: Vector2 = btn.get_global_rect().get_center()
		_click_screen(ctx.main.get_viewport(), pos)
		_click_screen(ctx.main.get_viewport(), pos, true)
		await _frames(4)
		var edit := _distance_edit(tl)
		check(edit != null and edit.has_focus(), "Distance field is focused for T14")
		if edit != null:
			_push_key(ctx.main.get_viewport(), KEY_1, false)
			_push_key(ctx.main.get_viewport(), KEY_4, false)
			await process_frame
			_push_key(ctx.main.get_viewport(), KEY_ENTER, false)
			await _frames(4)
	var warns := str(ctx.view.doc.graph_warnings())
	check(warns.find("edges lost on rebuild") < 0,
			"T14 warnings have no edges lost on rebuild (%s)" % warns)
	await _shutdown(ctx)


func _arm(ctx: FilmContext, body: String) -> void:
	if ctx.view.selected_body == "":
		ctx.view.select_entity(body, "")
		await process_frame
	if ctx.main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:
		ctx.main.ops_panel.arm_or_apply_fillet()
		await _frames(2)
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet is armed")


func _zoom_head_clear(cam: OrbitCamera, head: Vector3, rim: Vector3, want: float) -> bool:
	for _i in 8:
		var clearance := cam.unproject_position(head).distance_to(cam.unproject_position(rim))
		if clearance >= want:
			return true
		cam.distance = maxf(cam.distance * 0.7, 8.0)
		cam._update_transform()
		await process_frame
	var clearance := cam.unproject_position(head).distance_to(cam.unproject_position(rim))
	return clearance >= want


func _screen_at_clearance(view: DocumentView, body: String, cam: OrbitCamera,
		head: Vector3, rim: Vector3, target: float) -> Vector2:
	var center: Vector2 = cam.unproject_position(head)
	var edge_s: Vector2 = cam.unproject_position(rim)
	var lo := 0.0
	var hi := 0.98
	for _i in 18:
		var mid := (lo + hi) * 0.5
		var at: Vector2 = center.lerp(edge_s, mid)
		var nearest := _nearest_edge_px(view, body, cam, at)
		if nearest > target:
			lo = mid
		else:
			hi = mid
	return center.lerp(edge_s, (lo + hi) * 0.5)


func _nearest_edge_px(view: DocumentView, body: String, cam: OrbitCamera, screen: Vector2) -> float:
	var best := 1e9
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for eid in lines.keys():
		best = minf(best, view.edge_screen_distance(body, str(eid), cam, screen))
	return best


func _lists_zero_line(status: String) -> bool:
	return status.contains("— 0.0 mm") or status.contains(", 0.0 mm")


func _edge_count(status: String) -> int:
	var head := "Fillet: "
	if not status.begins_with(head):
		return -1
	var rest := status.substr(head.length())
	var sp := rest.find(" ")
	if sp < 0:
		return -1
	return int(rest.substr(0, sp))


func _count_fillet(ctx: FilmContext) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


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
		return {"ok": false, "why": "sketch feature failed: " + doc.last_graph_error()}
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	if ex_fid == "":
		return {"ok": false, "why": "extrude failed: " + doc.last_graph_error()}
	var body := ""
	for f in doc.graph_features():
		if str(f["id"]) == ex_fid:
			body = str(f["output_body"])
	if body == "":
		return {"ok": false, "why": "extrude has no body"}
	var slot := SxSketch.new()
	slot.set_plane(Vector3(0, 0, 10), Vector3(1, 0, 0), Vector3(0, 1, 0))
	slot.add_line(13.5, -5, 173.5, -5)
	slot.add_line(173.5, -5, 173.5, 5)
	slot.add_line(173.5, 5, 13.5, 5)
	slot.add_line(13.5, 5, 13.5, -5)
	var slot_fid: String = doc.graph_add_sketch(slot)
	var cut: String = doc.graph_add_extrude(slot_fid, -2.5, false, "cut", ex_fid, "blind")
	if cut == "":
		return {"ok": false, "why": "slot cut failed: " + doc.last_graph_error()}
	return {"ok": true, "body": body, "extrude": ex_fid, "x_neck": xhit, "why": ""}


func _distance_edit(tl: TimelinePanel) -> LineEdit:
	if tl.property_panel == null or not tl.property_panel.visible:
		return null
	var spin := tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	if spin == null:
		return null
	return spin.get_line_edit()


func _row_name_button(tl: TimelinePanel, fid: String) -> Button:
	var row: Control = tl._rows.get(fid)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button and str(child.text) != "":
			return child
	return null


func _click_screen(vp: Viewport, pos: Vector2, double_click := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = double_click
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)


func _push_key(vp: Viewport, code: Key, shift: bool) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = code
	down.physical_keycode = code
	down.shift_pressed = shift
	if code >= KEY_0 and code <= KEY_9:
		down.unicode = code
	vp.push_input(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = code
	up.physical_keycode = code
	up.shift_pressed = shift
	vp.push_input(up)


func _frames(n: int) -> void:
	for _i in n:
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
	check(root.size == ROOT_SIZE, "root is %s (got %s)" % [ROOT_SIZE, root.size])
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	await _frames(2)
	if ctx.main != null:
		ctx.main.queue_free()
	await process_frame
