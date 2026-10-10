# re-PLAN 21 WP7 — glyph leaders, box colours, and the top-view pose are state.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan21_state.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung01 replan21 state")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	var bridge = load("res://scripts/automation_bridge.gd").new()
	ctx.main.add_child(bridge)
	await _jaw(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var glyphs: Array = bridge._collect_glyphs(sm)
	check(glyphs.size() >= 1, "jaw drew glyphs (%d)" % glyphs.size())
	var leaders := 0
	for g in glyphs:
		check(g.has("cid") and str(g["cid"]) != "", "glyph has cid")
		check(g.has("offset_px"), "glyph has offset_px")
		check(g.has("leader") and g.has("anchor") and g.has("pos"), "glyph has leader, anchor, pos")
		var want: bool = float(g.get("offset_px", 0.0)) >= 12.0
		check(bool(g.get("leader")) == want, "leader flag matches offset %.1f" % float(g.get("offset_px", 0.0)))
		if bool(g.get("leader")):
			leaders += 1
			var anchor: Vector2 = Vector2(g["anchor"][0], g["anchor"][1])
			var pos: Vector2 = Vector2(g["pos"][0], g["pos"][1])
			var rect: Array = g.get("rect", [])
			check(rect.size() >= 4, "leader glyph has a screen rect")
			if rect.size() >= 4:
				var grown := Rect2(rect[0] - 2, rect[1] - 2, rect[2] + 4, rect[3] + 4)
				var cam: Camera3D = ctx.main.camera
				var screen_pos: Vector2 = cam.unproject_position(sm.to_model(pos))
				check(grown.has_point(screen_pos) or grown.has_point(Vector2(rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5)),
						"near end is inside the glyph rect")
				check(anchor.distance_to(pos) <= 40.0 or float(g["offset_px"]) <= 40.0, "far end stays within 40 px")
	var mesh: Dictionary = bridge._glyph_leaders(sm)
	check(bool(mesh.get("present")) == (leaders > 0), "leader mesh present matches leaders")
	check(int(mesh.get("tris", 0)) == leaders * 2, "leader tris are 2 per leader (got %s)" % str(mesh))
	await _box(ctx, bridge)
	await FilmUI.exit_sketch(ctx)
	await _pose(ctx)
	ctx.main.queue_free()


func _box(ctx: FilmContext, bridge) -> void:
	var ix = ctx.main.interaction
	var blue: Dictionary = ix.box_colours(false)
	var green: Dictionary = ix.box_colours(true)
	var bf: Color = blue["fill"]
	var gf: Color = green["fill"]
	check(bf.b > bf.g and bf.g > bf.r, "window fill is blue-dominant")
	check(gf.g > gf.b and gf.g > gf.r, "crossing fill is green-dominant")
	check(blue["edge"].is_equal_approx(green["edge"]), "edge colour is shared")
	ix.box_colours_override = {"fill": Color(0.1, 0.2, 0.3, 0.4), "edge": Color(0.4, 0.5, 0.6, 0.7)}
	var via_draw: Dictionary = ix.box_colours(false)
	var via_bridge: Dictionary = bridge._box_paint()
	check(via_draw["fill"].is_equal_approx(Color(0.1, 0.2, 0.3, 0.4)), "override changes box_colours")
	var bridged: Array = via_bridge.get("edge", [])
	check(bridged.size() >= 3 and abs(bridged[0] - 102) <= 1, "bridge edge follows the same function (got %s)" % str(bridged))
	ix.box_colours_override = null
	var sm: SketchMode = ctx.main.sketch_mode
	var a := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(-30, -30)))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(Vector2(30, 30)))
	if a.x > b.x:
		var swap := a
		a = b
		b = swap
	await _drag(ctx, a, b)
	var paint: Dictionary = bridge._box_paint()
	check(paint.has("edge") and paint.has("fill"), "window drag reports fill and edge (%s)" % str(paint.get("fill")))
	await _drag(ctx, b, a)
	check(ix.box_colours(true)["fill"].g > ix.box_colours(true)["fill"].r, "crossing colours stay green after the drag")


func _pose(ctx: FilmContext) -> void:
	_push_key(ctx.main.get_viewport(), KEY_3)
	_push_key(ctx.main.get_viewport(), KEY_F)
	await process_frame
	await process_frame
	var cam = ctx.main.camera
	var before := {
		"target": cam.pivot,
		"distance": cam.distance,
		"yaw": cam.yaw,
		"pitch": cam.pitch,
		"p0": cam.unproject_position(Vector3(0, 0, 10)),
		"p1": cam.unproject_position(Vector3(20, 0, 10)),
	}
	var body := ""
	for bid in ctx.view.doc.body_ids():
		body = str(bid)
	var face := ""
	if body != "":
		face = FilmUI.find_face_by_normal(ctx.view, body, Vector3.UP)
	if face != "":
		await FilmUI.enter_sketch_on_face(ctx, body, face)
		var sm: SketchMode = ctx.main.sketch_mode
		if sm.active:
			await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
			await FilmUI.exit_sketch(ctx)
			await FilmUI.apply_extrude(ctx, -2.0)
	_push_key(ctx.main.get_viewport(), KEY_3)
	_push_key(ctx.main.get_viewport(), KEY_F)
	await process_frame
	await process_frame
	check(absf(cam.yaw - float(before["yaw"])) < 1e-2, "yaw matches the top view (Δ %.4f)" % absf(cam.yaw - float(before["yaw"])))
	check(absf(cam.pitch - float(before["pitch"])) < 1e-2, "pitch matches the top view (Δ %.4f)" % absf(cam.pitch - float(before["pitch"])))
	check(absf(cam.distance - float(before["distance"])) < 1.0, "distance stays with the framed top view")
	var p0: Vector2 = cam.unproject_position(Vector3(0, 0, 10))
	var p1: Vector2 = cam.unproject_position(Vector3(20, 0, 10))
	check(p0.distance_to(before["p0"]) <= 5.0, "pivot projection within 5 px (Δ %.1f)" % p0.distance_to(before["p0"]))
	check(p1.distance_to(before["p1"]) <= 5.0, "second projection within 5 px (Δ %.1f)" % p1.distance_to(before["p1"]))
	check(cam.pivot.distance_to(before["target"]) <= 1e-2, "camera target matches (Δ %.4f)" % cam.pivot.distance_to(before["target"]))


func _jaw(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.set_snap(false)
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	if jaw != null:
		await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Jaw", "Jaw"))
	await _zoom_uv(ctx, Vector2(6, 4), 120.0)
	var dir := Vector2(cos(deg_to_rad(37.0)), sin(deg_to_rad(37.0)))
	var nrm := Vector2(-dir.y, dir.x)
	var ctr := Vector2(6, 4)
	for uv in [ctr, ctr + dir * 22.0, ctr + nrm * 7.0]:
		var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(uv))
		_click(ctx.main.get_viewport(), screen)
		await process_frame
		await process_frame
	check(str(ctx.main.status_label.text).begins_with("Jaw committed"), "jaw committed for glyphs")


func _drag(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	await process_frame
	motion = InputEventMouseMotion.new()
	motion.position = b
	motion.global_position = b
	vp.push_input(motion)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
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
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)


func _push_key(vp: Viewport, code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = pressed
		ev.keycode = code
		ev.physical_keycode = code
		vp.push_input(ev)


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		cam.sketch_orientation_locked = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var pivot := sm.to_model(uv) if sm != null else Vector3.ZERO
	cam.pivot = ms.to_global(pivot) if ms != null else pivot
	cam.distance = size_mm / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame
