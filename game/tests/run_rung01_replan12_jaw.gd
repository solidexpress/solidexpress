# Rung 1 replan 12 follow-up — Jaw (Center Three Point) on a face sketch: per-click
# status, long-side then outline preview, degenerate click-3 message, Jaw chips.
# Real events: Viewport.push_input (motion, press, release), never sm.click / ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_jaw.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)

var failures := 0
var checks := 0
var _log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 Jaw face-sketch clicks")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


func _on_status(msg: String) -> void:
	_log.append(str(msg))


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


func _push_motion(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	await process_frame


func _model_to_uv(sm: SketchMode, model: Vector3) -> Vector2:
	var rel := model - sm.plane_origin
	return Vector2(rel.dot(sm.plane_x), rel.dot(sm.plane_y))


func _uv_screen(ctx: FilmContext, sm: SketchMode, uv: Vector2) -> Vector2:
	return FilmUI.model_to_screen(ctx, sm.to_model(uv))


func _preview_uvs(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if sm._preview_node == null or sm._preview_node.mesh == null:
		return out
	var mesh := sm._preview_node.mesh as ImmediateMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return out
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for v in verts:
		var rel: Vector3 = v - sm.plane_origin
		out.append(Vector2(rel.dot(sm.plane_x), rel.dot(sm.plane_y)))
	return out


func _preview_segs(sm: SketchMode) -> Array:
	var pts := _preview_uvs(sm)
	var segs: Array = []
	var i := 0
	while i + 1 < pts.size():
		segs.append([pts[i], pts[i + 1]])
		i += 2
	return segs


func _seg_is_axis_aligned(a: Vector2, b: Vector2, tol: float = 0.4) -> bool:
	return absf(a.x - b.x) <= tol or absf(a.y - b.y) <= tol


func _has_long_side_preview(sm: SketchMode, ctr: Vector2, tip: Vector2) -> bool:
	var along := tip - ctr
	if along.length() < 1.0:
		return false
	var dir := along.normalized()
	for seg in _preview_segs(sm):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		if a.distance_to(b) < 1.0:
			continue
		if _seg_is_axis_aligned(a, b):
			continue
		var sdir := (b - a).normalized()
		if absf(sdir.dot(dir)) > 0.97 \
				and (a.distance_to(ctr) < 1.5 or b.distance_to(ctr) < 1.5):
			return true
	return false


func _has_axis_aligned_box_preview(sm: SketchMode) -> bool:
	var hv := 0
	var diag := 0
	for seg in _preview_segs(sm):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		if a.distance_to(b) < 0.5:
			continue
		if _seg_is_axis_aligned(a, b):
			hv += 1
		else:
			diag += 1
	return hv >= 3 and diag == 0


func _has_jaw_outline_preview(sm: SketchMode, ctr: Vector2, along_pt: Vector2, tip: Vector2) -> bool:
	var along := along_pt - ctr
	if along.length() < 1.0:
		return false
	var dir := along.normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var half_w := absf((tip - ctr).dot(nrm))
	if half_w < 0.5:
		return false
	var side := 0
	var across := 0
	for seg in _preview_segs(sm):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d := b - a
		if d.length() < 0.5:
			continue
		var sdir := d.normalized()
		if absf(sdir.dot(dir)) > 0.97:
			side += 1
		elif absf(sdir.dot(nrm)) > 0.97:
			across += 1
	return side >= 2 and across >= 2


func _chip_names(main: Node) -> Array[String]:
	var out: Array[String] = []
	var bar: Node = main.sketch_chrome.find_child("VariantBar", true, false)
	if bar == null:
		return out
	for c in bar.get_children():
		var b := c as Button
		if b != null:
			out.append(b.text)
	return out


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func _longest_profile_dir(sm: SketchMode) -> Vector2:
	var best := Vector2.ZERO
	var best_len := 0.0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		if d.length() > best_len:
			best_len = d.length()
			best = d
	return best


func _folded_deg(d: Vector2) -> float:
	if d.length_squared() < 1e-12:
		return 0.0
	var deg := absf(rad_to_deg(d.angle()))
	if deg > 90.0:
		deg = 180.0 - deg
	return deg


func _top_face(view: DocumentView, body: String) -> String:
	return FilmUI.find_face_by_normal(view, body, Vector3(0, 0, 1))


func _frame_head(ctx: FilmContext, sm: SketchMode, model: Vector3) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var ms: Node3D = ctx.main.model_space
	cam.sketch_orientation_locked = true
	cam.pivot = ms.to_global(model) if ms != null else model
	cam.distance = 90.0 / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame


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

	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var body: String = ctx.view.selected_body
	if body == "":
		var ids: PackedStringArray = ctx.view.doc.body_ids()
		if ids.size() > 0:
			body = ids[ids.size() - 1]
	var face := _top_face(ctx.view, body)
	check(body != "" and face != "", "blank extruded, +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	check(sm.active, "face sketch is active")
	check(absf(sm.plane_origin.z - 10.0) < 0.5,
			"sketch on the blank top face (origin z=%.3f)" % sm.plane_origin.z)

	var head_uv := _model_to_uv(sm, Vector3(HEAD.x, HEAD.y, 10.0))
	await _frame_head(ctx, sm, sm.to_model(head_uv))
	var along := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var across := Vector2(-along.y, along.x)
	var p1 := head_uv
	var p2 := head_uv + along * 30.0
	var p3 := head_uv + across * 10.0
	var s1 := _uv_screen(ctx, sm, p1)
	var s2 := _uv_screen(ctx, sm, p2)
	var s3 := _uv_screen(ctx, sm, p3)
	check(FilmUI.require_on_screen(ctx, s1, "jaw centre"), "click 1 (centre) is on screen at %s" % str(s1))
	check(FilmUI.require_on_screen(ctx, s2, "jaw long side"), "click 2 (long side) is on screen at %s" % str(s2))
	check(FilmUI.require_on_screen(ctx, s3, "jaw half width"), "click 3 (half width) is on screen at %s" % str(s3))

	sm.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	var jaw := FilmUI.find_sketch_tool_button(main, "Jaw")
	check(jaw != null and jaw.is_visible_in_tree(), "Jaw is on the sketch rail")
	await _push_click(jaw.get_global_rect().get_center())
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
			"Jaw arms Rectangle, Center Three Point (got tool %d variant %s)" % [int(sm.tool), sm.tool_variant])
	check(_last() == SketchMode.JAW_HINT, "armed status is JAW_HINT (got `%s`)" % _last())
	check(_chip_names(main) == ["Center Three Point"],
			"Jaw chips are only Center Three Point (got %s)" % str(_chip_names(main)))

	await _push_click(s1)
	check(_last() == SketchMode.JAW_AFTER_CENTRE,
			"click 1 status is centre-set (got `%s`)" % _last())
	check(sm._tool_points.size() == 1, "click 1 stored the centre (n=%d)" % sm._tool_points.size())
	await _push_motion(s2)
	check(not _has_axis_aligned_box_preview(sm),
			"after click 1 the preview is not an axis-aligned box (segs=%s)" % str(_preview_segs(sm)))
	check(_has_long_side_preview(sm, p1, p2),
			"after click 1 the preview is the long-side line")

	await _push_click(s2)
	check(_last() == SketchMode.JAW_AFTER_LONG,
			"click 2 status is long-side-set (got `%s`)" % _last())
	check(sm._tool_points.size() == 2, "click 2 kept the centre and long-side (n=%d)" % sm._tool_points.size())
	await _push_motion(s3)
	check(not _has_axis_aligned_box_preview(sm),
			"after click 2 the preview is not an axis-aligned box")
	check(_has_jaw_outline_preview(sm, p1, p2, p3),
			"after click 2 the preview is the jaw outline")

	var before_lines := _profile_lines(sm)
	await _push_click(s2)
	check(_last() == SketchMode.JAW_ZERO_WIDTH,
			"degenerate click 3 reports zero width (got `%s`)" % _last())
	check(sm._tool_points.size() == 2,
			"degenerate click 3 keeps clicks 1–2 (n=%d)" % sm._tool_points.size())
	check(_profile_lines(sm) == before_lines,
			"degenerate click 3 does not commit a jaw (lines %d)" % _profile_lines(sm))

	await _push_click(s3)
	check(_last().begins_with("Jaw committed — width "),
			"click 3 commits with the jaw status (got `%s`)" % _last())
	check(_last().contains("click a label to edit it"),
			"commit status tells the walker to click a label")
	check(_profile_lines(sm) == before_lines + 4,
			"committed jaw has four profile lines (got %d, was %d)" % [_profile_lines(sm), before_lines])
	check(sm._tool_points.is_empty(), "tool points clear after a successful commit")

	var ang_i := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "angle":
			ang_i = i
			break
	check(ang_i >= 0, "committed jaw has an angle dimension")
	if ang_i >= 0:
		sm.set_dimension_value(ang_i, 45.0)
		await process_frame
		var wall := _folded_deg(_longest_profile_dir(sm))
		check(absf(wall - 45.0) <= 0.05,
				"angle dim 45 constrains the long side to 45° ± 0.05° (got %.4f)" % wall)

	main.queue_free()
	await process_frame
	await process_frame
