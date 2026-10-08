# Rung 1 replan 12 WP4/WP5 — fillet picks through the real pointer path: end-on corner pick,
# face click while armed, press off the solid, status text.
# Real events: Viewport.push_input (motion, press, release), never ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_pick.gd
extends SceneTree

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
	print("rung01 replan12 WP4/WP5 fillet picks")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _push_key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _vertical_edges(view: DocumentView, body: String) -> Array:
	var out := []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) >= 5.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			out.append(str(id))
	return out


func _top_of(view: DocumentView, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return pts[0] if pts[0].z > pts[pts.size() - 1].z else pts[pts.size() - 1]


func _mid_of(view: DocumentView, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return (pts[0] + pts[pts.size() - 1]) * 0.5


func _top_long_edges(view: DocumentView, body: String) -> Array:
	var out := []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(d.x) >= 40.0 and absf(d.y) < 0.3 and absf(d.z) < 0.3 and mid.z > 5.0:
			out.append(str(id))
	return out


func _tap(main, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	main.camera.handle_input(ev)
	await process_frame
	await process_frame


func _arm(main, body: String) -> void:
	main.view.select_entity(body, "")
	main.ops_panel.set_dressup_radius(1.0)
	main.ops_panel.arm_or_apply_fillet()
	await process_frame
	await process_frame


func _st(main) -> String:
	return str(main.status_label.text)


func _fillet_count(view: DocumentView) -> int:
	var n := 0
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


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
	var view: DocumentView = main.view
	var ops = main.ops_panel
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	var verts := _vertical_edges(view, body)
	check(verts.size() == 4, "box has 4 vertical edges (got %d)" % verts.size())
	var bb: Dictionary = view.doc.measure_bbox(body)
	var centre: Vector3 = (bb["min"] + bb["max"]) * 0.5

	# 1. Top view: a click on the projected corner arms the vertical, not a top line.
	await _arm(main, body)
	await _tap(main, KEY_3)
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet is armed")
	var corner := _top_of(view, body, verts[0])
	var cs := FilmUI.model_to_screen(ctx, corner)
	var inward := (FilmUI.model_to_screen(ctx, centre) - cs).normalized() * 3.0
	await _push_click(cs + inward)
	check(view.selected_edges.size() == 1 and verts.has(str(view.selected_edges[0])),
			"Top-view corner click arms a vertical edge (edges %s)" % str(view.selected_edges))
	check(_st(main).contains("10.0 mm vertical"), "status names `10.0 mm vertical` (got `%s`)" % _st(main))

	# 2. Iso: a wall click far from any edge while armed keeps the set and says why.
	await _tap(main, KEY_1)
	var armed_before: Array = view.selected_edges.duplicate()
	var first_armed := str(armed_before[0]) if armed_before.size() > 0 else ""
	# Wall interior: middle of the −Y wall, found by a ray through the screen centre of that wall.
	var wall_mid := Vector3(centre.x, bb["min"].y, centre.z)
	var ws := FilmUI.model_to_screen(ctx, wall_mid)
	var on_screen := FilmUI.is_on_screen(ctx, ws)
	check(on_screen, "−Y wall centre is on screen (%s)" % str(ws))
	await _push_click(ws)
	check(view.selected_edges.size() == armed_before.size() and view.selected_edges.has(first_armed),
			"a face click far from every edge keeps the armed set (edges %s)" % str(view.selected_edges))
	check(_st(main).contains("No edge near click"), "refusal is named (got `%s`)" % _st(main))

	# 3. A face click within 14 px of another edge adds that edge and keeps the first.
	var other: String = ""
	for v in verts:
		if v != first_armed:
			var s := FilmUI.model_to_screen(ctx, _mid_of(view, body, v))
			if FilmUI.is_on_screen(ctx, s) and absf(_mid_of(view, body, v).y - bb["min"].y) < 0.5:
				other = v
				break
	check(other != "", "found another vertical on the −Y wall")
	if other != "":
		var os := FilmUI.model_to_screen(ctx, _mid_of(view, body, other))
		await _push_click(os + Vector2(6.0, 0.0) * (1.0 if os.x < ws.x else -1.0))
		check(view.selected_edges.size() == 2 and view.selected_edges.has(first_armed)
				and view.selected_edges.has(other),
				"a wall click within 14 px of a second vertical adds it and keeps the first (edges %s)" % str(view.selected_edges))

		# 4. A press off the solid keeps the set and the panel; a silhouette edge within 10 px is toggled.
		var set_before: Array = view.selected_edges.duplicate()
		var empty := Vector2(60.0, 700.0)
		await _push_click(empty)
		check(view.selected_edges.size() == set_before.size(), "an empty press keeps both edges (edges %s)" % str(view.selected_edges))
		check(ops.visible, "an empty press keeps the ops panel visible")
		check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "an empty press keeps Fillet armed")
		check(_st(main).contains("Missed the solid"), "a real miss is named (got `%s`)" % _st(main))

		# 5. Remove an edge: the status names its length and kind.
		await _push_click(FilmUI.model_to_screen(ctx, _mid_of(view, body, other)) + Vector2(2.0, 0.0))
		check(_st(main).contains("removed 10.0 mm vertical") or _st(main).contains("removed"),
				"re-click status names the removed edge (got `%s`)" % _st(main))
		check(_st(main).contains("removed 10.0 mm"), "the removed edge has its length (got `%s`)" % _st(main))
		await _push_click(FilmUI.model_to_screen(ctx, _mid_of(view, body, other)) + Vector2(2.0, 0.0))
		check(view.selected_edges.size() == 2, "the edge is back in the set (%d)" % view.selected_edges.size())

		# 6. Enter applies both and the applied text stays in the status bar.
		var before_fillets := _fillet_count(view)
		await _push_key(KEY_ENTER)
		check(_fillet_count(view) == before_fillets + 1, "Enter adds one fillet feature (%d → %d)" % [before_fillets, _fillet_count(view)])
		check(_st(main).begins_with("Fillet 2 edges 1.00 applied"), "status is `Fillet 2 edges 1.00 applied …` (got `%s`)" % _st(main))
		check(not _st(main).contains("Feature created"), "the applied text is not overwritten by `Feature created`")

	# 7. A press just off a silhouette edge picks it (within 10 px), and from nothing armed a face click still takes the face.
	var body2: String = view.insert_primitive("box", Vector3(100, 0, 0), Vector3(20, 20, 10))
	await process_frame
	var bb2: Dictionary = view.doc.measure_bbox(body2)
	var centre2: Vector3 = (bb2["min"] + bb2["max"]) * 0.5
	await _arm(main, body2)
	await _tap(main, KEY_1)
	var right_edge := ""
	var right_x := -INF
	for v in _vertical_edges(view, body2):
		var sx := FilmUI.model_to_screen(ctx, _mid_of(view, body2, v)).x
		if sx > right_x:
			right_x = sx
			right_edge = v
	var sil := FilmUI.model_to_screen(ctx, _mid_of(view, body2, right_edge)) + Vector2(5.0, 0.0)
	await _push_click(sil)
	check(view.selected_edges.size() == 1 and view.selected_edges.has(right_edge),
			"a press 5 px off the silhouette picks that edge (edges %s)" % str(view.selected_edges))
	ops.cancel_pending_pick()
	view.clear_selection()
	await _arm(main, body2)
	await _tap(main, KEY_1)
	var face_pt := Vector3(centre2.x, bb2["min"].y, centre2.z)
	await _push_click(FilmUI.model_to_screen(ctx, face_pt))
	check(view.selected_edges.size() == 4, "with nothing armed a face click takes the face's 4 edges (got %d)" % view.selected_edges.size())

	# 8. An edge hidden behind a wall is never snapped to from the camera side.
	view.clear_selection()
	await _tap(main, KEY_7)
	var cam: Camera3D = main.camera.get_node("Camera3D") if main.camera.has_node("Camera3D") else get_root().get_camera_3d()
	var far_edge := ""
	var far_d := -INF
	for v in _vertical_edges(view, body2):
		var d: float = (view.to_global(_mid_of(view, body2, v)) - cam.global_position).length()
		if d > far_d:
			far_d = d
			far_edge = v
	var snapped := ""
	if view.has_method("edge_near_screen") and view.has_method("model_to_screen"):
		var hidden_screen: Vector2 = view.call("model_to_screen", cam, _mid_of(view, body2, far_edge))
		snapped = str(view.call("edge_near_screen", body2, cam, hidden_screen, 14.0))
	check(view.has_method("edge_near_screen") and snapped != far_edge,
			"the far vertical edge hidden behind the box is not snapped to")

	# 9. Esc ends an armed fillet and its edge set in one press; the body stays selected.
	ops.cancel_pending_pick()
	await _arm(main, body2)
	await _tap(main, KEY_3)
	var esc_corner := FilmUI.model_to_screen(ctx, _top_of(view, body2, _vertical_edges(view, body2)[0]))
	var esc_in := (FilmUI.model_to_screen(ctx, centre2) - esc_corner).normalized() * 3.0
	await _push_click(esc_corner + esc_in)
	check(view.selected_edges.size() >= 1, "an edge is armed before Esc (%d)" % view.selected_edges.size())
	await _push_key(KEY_ESCAPE)
	check(ops._pending == OpsPanel.Pending.NONE, "one real Esc ends the armed fillet")
	check(view.selected_edges.is_empty() and view.selected_edge == "", "Esc drops the picked edges")
	check(view.selected_body == body2, "Esc keeps the body selected")
	check(_st(main).contains("Edge pick cancelled"), "status says the pick was cancelled (got `%s`)" % _st(main))

	# 10. Re-click of a picked long edge toggles it off even when a same-length
	# twin is slightly closer (thin pad, face-hit inward of the edge).
	var thin: String = view.insert_primitive("box", Vector3(200, 0, 0), Vector3(50, 5, 10))
	await process_frame
	var top_longs := _top_long_edges(view, thin)
	check(top_longs.size() == 2, "thin box has two top 50 mm edges (got %d)" % top_longs.size())
	if top_longs.size() == 2:
		ops.cancel_pending_pick()
		await _arm(main, thin)
		await _tap(main, KEY_3)
		var a: String = top_longs[0]
		var b: String = top_longs[1]
		var mid_a := _mid_of(view, thin, a)
		var mid_b := _mid_of(view, thin, b)
		await _push_click(FilmUI.model_to_screen(ctx, mid_a))
		var picked := ""
		if view.selected_edges.size() == 1:
			picked = str(view.selected_edges[0])
		# #204 exact top view can land on either of the two 50 mm edges.
		check(view.selected_edges.size() == 1 and (picked == a or picked == b),
				"Top-view click arms one 50 mm edge (got %s)" % str(view.selected_edges))
		var mid_picked: Vector3 = mid_a if picked == a else mid_b
		var mid_other: Vector3 = mid_b if picked == a else mid_a
		var between := mid_picked.lerp(mid_other, 0.52)
		await _push_click(FilmUI.model_to_screen(ctx, between))
		check(picked == "" or not view.selected_edges.has(picked),
				"re-click near the picked edge removes it (edges %s)" % str(view.selected_edges))
		check(not view.selected_edges.has(a) and not view.selected_edges.has(b),
				"the same-length twin was not added (edges %s)" % str(view.selected_edges))
		check(_st(main).contains("removed"), "status names the removal (got `%s`)" % _st(main))
		check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "toggle-off keeps Fillet armed")

	main.queue_free()
	await process_frame
	await process_frame
