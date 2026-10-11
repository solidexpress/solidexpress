# Rung 2 WP2 — face sketches are upright (PlaneBasis).
# Builds a 100×60×50 box by clicks, then opens a sketch on each face.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung02_plane_basis.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const UV_TOL := 1.0

# Today's ±Z basis, pinned from main's _setup_plane (n × Z falls back to +X).
const PIN_POS_Z_X := Vector3(1, 0, 0)
const PIN_POS_Z_Y := Vector3(0, 1, 0)
const PIN_NEG_Z_X := Vector3(1, 0, 0)
const PIN_NEG_Z_Y := Vector3(0, -1, 0)
const _FACE_ORIGIN := {
	"+X": "100.0,0.0,0.0",
	"-X": "0.0,0.0,0.0",
	"+Y": "0.0,60.0,0.0",
	"-Y": "0.0,0.0,0.0",
	"+Z": "0.0,0.0,50.0",
	"-Z": "0.0,0.0,0.0",
}



func _init() -> void:
	status_echo = true
	print("rung02 plane basis")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	await _build_box(ctx)
	if failures > 0:
		ctx.main.queue_free()
		return
	await _face(ctx, Vector3(1, 0, 0), KEY_2, Vector3(100, 20, 30), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector2(20, 30))
	await _face(ctx, Vector3(-1, 0, 0), KEY_6, Vector3(0, 20, 30), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector2(-20, 30))
	await _face(ctx, Vector3(0, 1, 0), KEY_4, Vector3(20, 60, 30), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector2(-20, 30))
	await _face(ctx, Vector3(0, -1, 0), KEY_1, Vector3(20, 0, 30), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector2(20, 30))
	await _face(ctx, Vector3(0, 0, 1), KEY_3, Vector3(20, 30, 50), PIN_POS_Z_X, PIN_POS_Z_Y, Vector2(20, 30))
	await _face(ctx, Vector3(0, 0, -1), KEY_8, Vector3(20, 30, 0), PIN_NEG_Z_X, PIN_NEG_Z_Y, Vector2(20, -30))
	ctx.main.queue_free()


func _build_box(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(50, 30, 0), 160.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(100, 60))
	await process_frame
	var lines := 0
	if sm.sketch != null:
		for id in sm.sketch.entity_ids():
			if str(sm.sketch.entity_info(id).get("type", "")) == "line":
				lines += 1
	check(lines == 4, "rect is four lines (got %d)" % lines)
	var dist := FilmUI.distance_edit(ctx)
	check(dist != null and dist.is_visible_in_tree(), "Distance field is visible")
	if dist != null:
		await _x11_click(dist)
		await _type_text(dist.get_viewport(), "50")
		await process_frame
	var ex: Button = ctx.main.sketch_chrome.extrude_button() if ctx.main.sketch_chrome != null else null
	check(ex != null and ex.is_visible_in_tree(), "Extrude button is visible")
	if ex != null:
		await _x11_click(ex)
	for _i in 8:
		await process_frame
	_note_status(ctx)
	var body := _only_body(ctx)
	check(body != "", "extrude made one body")
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var sz: Vector3 = bb["max"] - bb["min"]
	check(sz.distance_to(Vector3(100, 60, 50)) < 0.2, "box is 100×60×50 (got %s)" % str(sz))


func _face(ctx: FilmContext, normal: Vector3, view_key: Key, world: Vector3, want_x: Vector3, want_y: Vector3, want_uv: Vector2) -> void:
	var tag := _tag(normal)
	if ctx.main.sketch_mode.active:
		await _leave_sketch(ctx)
	await _push_key(ctx.main.get_viewport(), view_key, 0)
	await process_frame
	await process_frame
	var body := _only_body(ctx)
	var face := FilmUI.find_face_by_normal(ctx.view, body, normal)
	check(face != "", "%s face exists" % tag)
	if face == "":
		return
	var pick_pt: Vector3 = FilmUI.face_pick_point(ctx.view, body, face)
	if pick_pt == Vector3.INF:
		pick_pt = world
	var screen := FilmUI.model_to_screen(ctx, pick_pt)
	check(FilmUI.require_on_screen(ctx, screen, tag), "%s face point is on screen" % tag)
	# First click on a body selects the body; the next click drills to the face.
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select %s face" % tag))
	await process_frame
	if ctx.view.selected_face != face:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Drill %s face" % tag))
		await process_frame
	check(ctx.view.selected_face == face, "%s face selected (got %s)" % [tag, ctx.view.selected_face])
	await _push_key(ctx.main.get_viewport(), view_key, 0)
	await process_frame
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Sketch") if strip != null else null
	check(chip != null and chip.is_visible_in_tree(), "%s Sketch chip is visible" % tag)
	if chip == null:
		return
	await FilmUI.click_control(ctx, chip, FilmUICues.toolbar_sketch())
	for _i in 4:
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	_note_status(ctx)
	var face_status := "Sketch on face (plane %s @ origin %s)" % [tag, _FACE_ORIGIN[tag]]
	check(sm.active and _status_has(face_status), "%s sketch is active (%s)" % [tag, face_status])
	if not sm.active or sm.sketch == null:
		return
	var pi: Dictionary = sm.sketch.plane_info()
	var px: Vector3 = (pi["x_dir"] as Vector3).normalized()
	var py: Vector3 = (pi["y_dir"] as Vector3).normalized()
	print("  %s plane x=%s y=%s origin=%s" % [tag, str(px), str(py), str(sm.plane_origin)])
	check(px.distance_to(want_x) < 1e-4 and py.distance_to(want_y) < 1e-4,
			"%s basis x=%s y=%s (want %s %s)" % [tag, str(px), str(py), str(want_x), str(want_y)])
	check(sm.plane_x.distance_to(want_x) < 1e-4 and sm.plane_y.distance_to(want_y) < 1e-4,
			"%s SketchMode axes match the sketch plane" % tag)
	var round_uv := Vector2(12.5, -7.25)
	var round_back := sm.plane.to_uv(sm.plane.to_world(round_uv))
	check(round_back.distance_to(round_uv) < 1e-4,
			"%s to_uv(to_world) round-trips (got %s)" % [tag, str(round_back)])
	var rel := world - sm.plane_origin
	var expected := Vector2(rel.dot(want_x), rel.dot(want_y))
	check(expected.distance_to(want_uv) <= 0.05,
			"%s origin offset leaves sketch %s (got %s, origin %s)" % [tag, str(want_uv), str(expected), str(sm.plane_origin)])
	var click_at := FilmUI.model_to_screen(ctx, world)
	check(FilmUI.require_on_screen(ctx, click_at, tag + " sketch"), "%s sketch point is on screen" % tag)
	await FilmUI.viewport_click(ctx, click_at, FilmUICues.sketch_click("%s sketch point" % tag))
	await process_frame
	var recorded := Vector2(INF, INF)
	if sm._tool_points.size() >= 1:
		recorded = sm._tool_points[0]
	print("  %s click recorded %s (want %s)" % [tag, str(recorded), str(expected)])
	check(recorded.distance_to(expected) <= UV_TOL,
			"%s click records %s (got %s)" % [tag, str(expected), str(recorded)])
	await _leave_sketch(ctx)


func _leave_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	if sm.active:
		await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
		await process_frame
	_note_status(ctx)


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])




func _tag(n: Vector3) -> String:
	if n.x > 0.5:
		return "+X"
	if n.x < -0.5:
		return "-X"
	if n.y > 0.5:
		return "+Y"
	if n.y < -0.5:
		return "-Y"
	if n.z > 0.5:
		return "+Z"
	return "-Z"


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
	listen_status(main)
	return ctx


func _status_has(text: String) -> bool:
	return status_log.has(text)




func _note_status(ctx: FilmContext) -> void:
	if ctx.main != null and ctx.main.status_label != null:
		var text := str(ctx.main.status_label.text)
		if text != "" and (status_log.is_empty() or status_log[status_log.size() - 1] != text):
			status_log.append(text)
			print("  status: " + text)
