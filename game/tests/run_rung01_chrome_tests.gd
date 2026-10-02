# Rung 1 WP1 — empty part, one Esc, TriBall does not eat the next click,
# hex pocket panel, AF/resize clamp, move stays available.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_chrome_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0
var checks := 0


func check(c: bool, w: String) -> void:
	checks += 1
	if c:
		print("  ok   - " + w)
	else:
		failures += 1
		printerr("  FAIL - " + w)


func _init() -> void:
	print("rung01 chrome (WP1)")
	FilmUI.reset_fail_count()
	await test_empty_new_and_one_esc()
	await test_pocket_clicks_open_hex()
	await test_clearance_zero_af_20()
	await test_af14_near_edge_and_resize()
	await test_move_twice_after_af()
	await test_typed_xy()
	check(FilmUI.fail_count == 0, "FilmUI reported no missing controls")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _boot() -> Array:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)
	return [main, ctx]


func _file_new(main) -> void:
	var popup: PopupMenu = main._file_popup
	popup.id_pressed.emit(0)
	await process_frame
	await process_frame


func _plate(main, size: Vector3) -> String:
	var id: String = main.view.insert_primitive("box", Vector3.ZERO, size)
	main.camera.frame_contents()
	await process_frame
	await process_frame
	return id


func _top(view, id: String) -> String:
	var best := ""
	var best_z := -1e9
	for face_id in view.doc.get_face_ids(id):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if mid.z > best_z:
			best_z = mid.z
			best = face_id
	return best


func _hex_params(view) -> Dictionary:
	for f in view.doc.graph_features():
		if str(f.get("type")) != "hole":
			continue
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if p is Dictionary and str(p.get("type")) == "hex":
			return p
	return {}


func _hex_pos(hp: Dictionary) -> Vector3:
	var a = hp.get("position", [0, 0, 0])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _pair_width(doc, origin: Vector3, axis: Vector3) -> float:
	var a: Dictionary = doc.pick(origin, axis)
	var b: Dictionary = doc.pick(origin, -axis)
	if a.is_empty() or b.is_empty():
		return -1.0
	return float(a["distance"]) + float(b["distance"])


func _af_at(doc, pos: Vector3, z: float) -> float:
	var o := Vector3(pos.x, pos.y, z)
	var wx := _pair_width(doc, o, Vector3(1, 0, 0))
	var wy := _pair_width(doc, o, Vector3(0, 1, 0))
	if wx < 0.0 or wy < 0.0:
		return -1.0
	return minf(wx, wy)


func _vertices_on_plate(pos: Vector3, af: float, bb: Dictionary) -> bool:
	var r := af / sqrt(3.0)
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	for i in range(6):
		var th := deg_to_rad(30.0 + 60.0 * float(i))
		var vx := pos.x + r * cos(th)
		var vy := pos.y + r * sin(th)
		if vx < mn.x - 0.15 or vx > mx.x + 0.15:
			return false
		if vy < mn.y - 0.15 or vy > mx.y + 0.15:
			return false
	return true


func _press_esc(ix) -> void:
	ix.grab_focus()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ev.echo = false
	ix._input(ev)


func test_empty_new_and_one_esc() -> void:
	print("- File New is empty; one Esc clears a selected body")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _file_new(main)
	check(main.view.doc.body_ids().is_empty(), "body_ids empty after New")
	check(main.interaction.triball == null or not main.interaction.triball.active,
			"TriBall inactive after New")
	var mid := FilmUI.model_to_screen(ctx, Vector3(0, 0, 0))
	await FilmUI.viewport_click(ctx, mid, {"keys": "Click", "desc": "empty viewport"})
	var tb = main.interaction.triball
	check(tb == null or not tb._dragging, "next click is not a ring drag")
	check(tb == null or not tb.active, "click did not arm TriBall")
	var id: String = await _plate(main, Vector3(40, 40, 8))
	var top := _top(main.view, id)
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx,
			main.view.doc.face_midpoint(top)), {"keys": "Click", "desc": "select plate"})
	check(main.view.selected_body != "", "plate selected")
	_press_esc(main.interaction)
	await process_frame
	check(main.view.selected_body == "", "one Esc clears selection")
	check(main.interaction.triball == null or not main.interaction.triball.active,
			"TriBall still inactive")
	var before := str(main.status_label.text)
	_press_esc(main.interaction)
	await process_frame
	check(main.view.selected_body == "", "second Esc leaves selection clear")
	check(not str(main.status_label.text).contains("TriBall"),
			"second Esc does not cancel TriBall again (status %s, was %s)" % [
				main.status_label.text, before])
	main.queue_free()
	await process_frame


func _place_hex(main, ctx: FilmContext, id: String, at: Vector3) -> void:
	var insert: MenuButton = main.find_child("InsertMenu", true, false)
	insert.get_popup().id_pressed.emit(22)
	await process_frame
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, at),
			{"keys": "Click", "desc": "place hex"})
	await process_frame
	await process_frame


func test_pocket_clicks_open_hex() -> void:
	print("- Pocket void and rim open Type / Diameter / Depth")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _file_new(main)
	var id: String = await _plate(main, Vector3(80, 80, 8))
	await _place_hex(main, ctx, id, Vector3(10, 0, 8))
	var hp := _hex_params(main.view)
	check(not hp.is_empty(), "hex placed from Insert menu")
	var pos := _hex_pos(hp)
	var ops = main.ops_panel
	# Void: ray through the axis misses the solid.
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, pos),
			{"keys": "Click", "desc": "pocket void"})
	await process_frame
	check(ops._hole_type != null and ops._hole_type.selected == 3, "void Type = hex")
	check(ops._hole_diam_expr != null and str(ops._hole_diam_expr.text).contains("jaw_af"),
			"void Diameter contains jaw_af (%s)" % (
				ops._hole_diam_expr.text if ops._hole_diam_expr != null else ""))
	check(ops._hole_depth != null and is_equal_approx(ops._hole_depth.value, 0.0),
			"void Depth = 0")
	check(not str(main.status_label.text).contains("Selection cleared"),
			"void click status is not Selection cleared (%s)" % main.status_label.text)
	check(ops._selected_hole_fid != "", "void click selects the hole, not only Box")
	var af: float = main.view.evaluated_param_number(hp.get("diameter", 10.0), 10.0)
	var r: float = af / sqrt(3.0)
	var rim := pos + Vector3(r * 1.08, 0, 0)
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, rim),
			{"keys": "Click", "desc": "hex rim"})
	await process_frame
	check(ops._hole_type != null and ops._hole_type.selected == 3, "rim Type = hex")
	check(ops._hole_diam_expr != null and str(ops._hole_diam_expr.text).contains("jaw_af"),
			"rim Diameter contains jaw_af")
	check(ops._hole_depth != null and is_equal_approx(ops._hole_depth.value, 0.0),
			"rim Depth = 0")
	check(not str(main.status_label.text).contains("Selection cleared"),
			"rim click status is not Selection cleared (%s)" % main.status_label.text)
	check(ops._selected_hole_fid != "", "rim click keeps the hole feature")
	main.queue_free()
	await process_frame


func test_clearance_zero_af_20() -> void:
	print("- clearance 0 and diameter 20, still through")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _file_new(main)
	var id: String = await _plate(main, Vector3(80, 80, 8))
	await _place_hex(main, ctx, id, Vector3(0, 0, 8))
	var pos0 := _hex_pos(_hex_params(main.view))
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, pos0),
			{"keys": "Click", "desc": "open pocket"})
	await process_frame
	main.view.doc.set_variable("clearance", "0")
	var expr: LineEdit = main.ops_panel._hole_diam_expr
	check(expr != null, "Diameter field exists")
	if expr != null:
		expr.text = "=20"
		expr.text_submitted.emit("=20")
	await process_frame
	await process_frame
	var hp := _hex_params(main.view)
	var pos := _hex_pos(hp)
	var af_mid := _af_at(main.view.doc, pos, 4.0)
	check(af_mid > 0.0 and absf(af_mid - 20.0) <= 0.2,
			"cut AF 20 ± 0.2 at mid (got %.3f)" % af_mid)
	var bb: Dictionary = main.view.doc.measure_bbox(id)
	var z0: float = bb["min"].z
	var z1: float = bb["max"].z
	var af_lo := _af_at(main.view.doc, pos, z0 + 0.35)
	var af_hi := _af_at(main.view.doc, pos, z1 - 0.35)
	check(af_lo > 0.0 and absf(af_lo - 20.0) <= 0.2, "open at plate min (AF %.3f)" % af_lo)
	check(af_hi > 0.0 and absf(af_hi - 20.0) <= 0.2, "open at plate max (AF %.3f)" % af_hi)
	var down: Dictionary = main.view.doc.pick(Vector3(pos.x, pos.y, z1 + 20.0), Vector3(0, 0, -1))
	check(down.is_empty(), "vertical ray through the hex does not hit a floor")
	main.queue_free()
	await process_frame


func test_af14_near_edge_and_resize() -> void:
	print("- AF 14 near the short edge stays on the face; resize W too")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _file_new(main)
	# 120 x 36 plate. Short edges are ±Y. AF 14 needs ~16 mm, so it fits if clamped.
	var id: String = await _plate(main, Vector3(120, 36, 8))
	await _place_hex(main, ctx, id, Vector3(20, -16, 8))
	var pos0 := _hex_pos(_hex_params(main.view))
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(0, 0, 8)),
			{"keys": "Click", "desc": "select plate off the pocket"})
	var jaw: Button = main.find_child("StripJaw14", true, false)
	check(jaw != null and jaw.is_visible_in_tree(), "Jaw AF 14 chip visible")
	if jaw != null:
		jaw.pressed.emit()
	await process_frame
	await process_frame
	var hp := _hex_params(main.view)
	var pos := _hex_pos(hp)
	var af: float = main.view.evaluated_param_number(hp.get("diameter", 14.0), 14.0)
	var bb: Dictionary = main.view.doc.measure_bbox(id)
	var err := str(main.view.doc.last_graph_error())
	var on_face := _vertices_on_plate(pos, af, bb)
	var notch_free := false
	if err != "":
		var wall: Dictionary = main.view.doc.pick(
				Vector3(pos.x, bb["min"].y - 8.0, 4.0), Vector3(0, 1, 0))
		notch_free = not wall.is_empty() and absf(float(wall["point"].y) - bb["min"].y) < 0.4
	check(on_face or (err != "" and notch_free),
			"AF 14 stays on face (on=%s err=%s pos=%s af=%.2f)" % [on_face, err, pos, af])
	if on_face:
		check(is_equal_approx(af, 14.3) or absf(af - 14.0) < 0.5,
				"diameter followed jaw_af 14 (got %.2f)" % af)
	# Resize W through the HUD while the body is selected.
	if main.view.selected_body == "":
		await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(-40, 0, 8)),
				{"keys": "Click", "desc": "reselect plate"})
	var hud = main.interaction.transform_hud
	check(hud != null and hud._size_w != null, "W field exists")
	if hud != null and main.view.selected_body != "":
		hud._size_w.value = 80.0
		await process_frame
		await process_frame
		hp = _hex_params(main.view)
		pos = _hex_pos(hp)
		af = main.view.evaluated_param_number(hp.get("diameter", af), af)
		bb = main.view.doc.measure_bbox(id)
		check(_vertices_on_plate(pos, af, bb),
				"after resize W, hex stays on face (pos %s bb %s..%s)" % [pos, bb.get("min"), bb.get("max")])
	main.queue_free()
	await process_frame


func test_move_twice_after_af() -> void:
	print("- Move, change AF, move again; Z stays on the entry face")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _file_new(main)
	var id: String = await _plate(main, Vector3(100, 80, 8))
	await _place_hex(main, ctx, id, Vector3(0, 0, 8))
	var pos0 := _hex_pos(_hex_params(main.view))
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, pos0),
			{"keys": "Click", "desc": "select pocket"})
	await process_frame
	var move_btn: Button = main.ops_panel.find_child("Move", true, false)
	if move_btn == null:
		move_btn = _button_with_text(main.ops_panel, "Move")
	check(move_btn != null and move_btn.is_visible_in_tree(), "Move button visible")
	if move_btn != null:
		await FilmUI.click_control(ctx, move_btn, {"keys": "Move", "desc": "arm hole move"})
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(18, 6, 8)),
			{"keys": "Click", "desc": "first move"})
	await process_frame
	var pos1 := _hex_pos(_hex_params(main.view))
	check(absf(pos1.z - 8.0) < 0.2, "first move Z on entry face (%.2f)" % pos1.z)
	check(Vector2(pos1.x, pos1.y).distance_to(Vector2(pos0.x, pos0.y)) > 1.0,
			"first move changed XY")
	# Pocket click reselects without relocating, so the AF chip is on the strip.
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, pos1),
			{"keys": "Click", "desc": "reselect pocket"})
	await process_frame
	var jaw: Button = main.find_child("StripJaw14", true, false)
	check(jaw != null and jaw.is_visible_in_tree(), "AF chip visible after move")
	if jaw != null:
		jaw.pressed.emit()
	await process_frame
	await process_frame
	var pos_af := _hex_pos(_hex_params(main.view))
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, Vector3(-16, 10, 8)),
			{"keys": "Click", "desc": "second move"})
	await process_frame
	var pos2 := _hex_pos(_hex_params(main.view))
	check(absf(pos2.z - 8.0) < 0.2, "second move Z on entry face (%.2f)" % pos2.z)
	check(Vector2(pos2.x, pos2.y).distance_to(Vector2(pos_af.x, pos_af.y)) > 1.0,
			"second move changed XY after AF (%.1f,%.1f -> %.1f,%.1f)" % [
				pos_af.x, pos_af.y, pos2.x, pos2.y])
	var through: Dictionary = main.view.doc.pick(Vector3(pos2.x, pos2.y, 30.0), Vector3(0, 0, -1))
	check(through.is_empty(), "still through after the second move")
	main.queue_free()
	await process_frame


func test_typed_xy() -> void:
	print("- Typed X/Y on the open hole keeps Z")
	var booted = await _boot()
	var main = booted[0]
	var ctx: FilmContext = booted[1]
	await _file_new(main)
	await _plate(main, Vector3(80, 80, 8))
	await _place_hex(main, ctx, "", Vector3(0, 0, 8))
	var pos0 := _hex_pos(_hex_params(main.view))
	await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx, pos0),
			{"keys": "Click", "desc": "open hole"})
	await process_frame
	var sx: SpinBox = main.ops_panel.find_child("HolePosX", true, false)
	var sy: SpinBox = main.ops_panel.find_child("HolePosY", true, false)
	check(sx != null and sy != null, "X/Y fields exist")
	if sx != null and sy != null:
		sx.value = 12.0
		sy.value = -6.0
		await process_frame
		await process_frame
		var pos := _hex_pos(_hex_params(main.view))
		check(absf(pos.x - 12.0) < 0.15 and absf(pos.y - (-6.0)) < 0.15,
				"typed X/Y applied (got %.2f, %.2f)" % [pos.x, pos.y])
		check(absf(pos.z - pos0.z) < 0.15, "typed X/Y kept Z (%.2f)" % pos.z)
	main.queue_free()
	await process_frame


func _button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and node.is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _button_with_text(c, text)
		if found != null:
			return found
	return null
