# After an Extrude that consumes a sketch, the camera frames a new body and
# no sketch overlay lines stay up in part mode. Regression for sx-037:
# chunk 1 A5 left the empty-scene orbit inside the blank (red X / arcs),
# and chunk 3 left the jaw sketch's yellow strokes on the solid after the
# Up To Surface cut.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game \
#   --script tests/run_extrude_frame_tests.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)



func _init() -> void:
	print("extrude frames the new body and hides sketch overlay lines")
	var ctx := await _boot()
	await _test_blank_extrude(ctx)
	await _test_cut_hides_overlay(ctx)
	await _test_unconsumed_sketch_still_draws(ctx)
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	finish()


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
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	return ctx


func _test_blank_extrude(ctx: FilmContext) -> void:
	print("- blank extrude frames the body")
	var main = ctx.main
	var cam: OrbitCamera = main.camera
	main.view.new_document()
	await process_frame
	# Empty-scene pose. This is what leave_sketch_view restores on File → New.
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.pivot = Vector3.ZERO
	cam.distance = OrbitCamera.DEFAULT_DISTANCE
	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(40.0)
	cam._look_at_content = false
	cam._update_transform()
	check(is_equal_approx(cam.distance, OrbitCamera.DEFAULT_DISTANCE),
			"pre-sketch distance is the empty-scene default")

	main._start_sketch_on_ground()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	if sm == null or not sm.active:
		return
	var sk: SxSketch = sm.sketch
	sk.add_circle(0.0, 0.0, 10.0)
	sk.add_circle(200.0, 0.0, 22.5)
	# Shaft lines of the wrench blank: parallel to the centre line, tangent
	# to the small circle, ending on the large one.
	var tangent_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	sk.add_line(0.0, 10.0, tangent_x, 10.0)
	sk.add_line(0.0, -10.0, tangent_x, -10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame

	check(not sm.active, "sketch session ended")
	check(main.view.doc.body_ids().size() == 1, "one body after Extrude")
	var body := ""
	if not main.view.doc.body_ids().is_empty():
		body = str(main.view.doc.body_ids()[0])
	var bb: Dictionary = main.view.doc.measure_bbox(body) if body != "" else {}
	check(not bb.is_empty(), "body bbox exists")
	if bb.is_empty():
		return
	var ext: Vector3 = bb["max"] - bb["min"]
	check(ext.x > 100.0 and ext.z > 5.0,
			"blank is a long solid (%.1f × %.1f × %.1f)" % [ext.x, ext.y, ext.z])

	var inside := _bbox_inside_viewport(main, bb)
	check(inside["ok"],
			"whole body bbox projects inside the viewport (outside=%d behind=%d)" % [
				int(inside["outside"]), int(inside["behind"])])
	var span: float = float(inside["span"])
	var vp_w: float = float(inside["vp_w"])
	check(vp_w > 1.0 and span >= vp_w * 0.25,
			"framed body spans the view (%.0f px of %.0f)" % [span, vp_w])

	var lines := _sketch_overlay_lines(main)
	check(lines.is_empty(),
			"no sketch-overlay lines after the new Extrude (got %s)" % str(lines))


## Face sketch + cut. Same rule as the jaw Up To Surface commit: once the
## extrude exists, its sketch strokes are gone in part mode.
func _test_cut_hides_overlay(ctx: FilmContext) -> void:
	print("- cut extrude hides the consumed sketch")
	var main = ctx.main
	var doc = main.view.doc
	if doc.body_ids().is_empty():
		check(false, "cut test has the blank body")
		return
	var body := str(doc.body_ids()[0])
	var top := _face_at(doc, body, 10.0)
	check(top != "", "blank has a top face for the cut sketch")
	if top == "":
		return
	var before := _count_type(doc, "extrude")
	main._start_sketch_on_face(top, body)
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "face sketch is open")
	if sm == null or not sm.active:
		return
	# Circle plus a closed square — the strokes the jaw cut left in yellow.
	sm.sketch.add_circle(40.0, 0.0, 4.0)
	sm.sketch.add_line(80.0, -6.0, 96.0, -6.0)
	sm.sketch.add_line(96.0, -6.0, 96.0, 6.0)
	sm.sketch.add_line(96.0, 6.0, 80.0, 6.0)
	sm.sketch.add_line(80.0, 6.0, 80.0, -6.0)
	sm.finish_extrude(5.0, "cut", "blind")
	await process_frame
	await process_frame
	check(not sm.active, "cut sketch session ended")
	check(_count_type(doc, "extrude") == before + 1,
			"cut added an extrude feature (%d -> %d)" % [before, _count_type(doc, "extrude")])
	var lines := _sketch_overlay_lines(main)
	check(lines.is_empty(),
			"no sketch-overlay lines after the cut Extrude (got %s)" % str(lines))


## A sketch that is saved but not yet consumed by a feature still draws.
func _test_unconsumed_sketch_still_draws(ctx: FilmContext) -> void:
	print("- an unused sketch still draws its profile")
	var main = ctx.main
	main._start_sketch_on_ground()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	check(sm != null and sm.active, "unused sketch is open")
	if sm == null or not sm.active:
		return
	sm.sketch.add_circle(0.0, 40.0, 3.0)
	var fid := sm.exit_sketch()
	await process_frame
	check(fid != "", "unused sketch was saved")
	check(not sm.active, "unused sketch left part mode")
	var pads: Dictionary = main.view.sketch_pads.get("_pads")
	var profile: MeshInstance3D = pads.get(fid, {}).get("profile")
	check(profile != null and is_instance_valid(profile) and profile.visible and profile.mesh != null,
			"unused sketch still draws profile lines")
	var leaked: Array[String] = []
	for pad_fid in pads:
		if str(pad_fid) == fid:
			continue
		var entry: Dictionary = pads[pad_fid]
		for key in ["mesh", "edge", "profile"]:
			var node = entry.get(key)
			if node is MeshInstance3D and is_instance_valid(node) and (node as MeshInstance3D).mesh != null:
				leaked.append("%s:%s" % [str(pad_fid), key])
	check(leaked.is_empty(),
			"consumed sketches stay hidden beside the unused one (got %s)" % str(leaked))


func _face_at(doc, body: String, z: float) -> String:
	for f in doc.get_face_ids(body):
		var m: Vector3 = doc.face_midpoint(f)
		var bb: Dictionary = doc.measure_bbox(f)
		if bb.is_empty():
			continue
		var ext: Vector3 = bb["max"] - bb["min"]
		if absf(m.z - z) < 0.05 and ext.z < 0.05:
			return str(f)
	return ""


func _count_type(doc, kind: String) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == kind:
			n += 1
	return n


## Model-space AABB corners through model_space, same transform Frame uses.
func _bbox_inside_viewport(main, bb: Dictionary) -> Dictionary:
	var cam: OrbitCamera = main.camera
	var vp := cam.get_viewport().get_visible_rect()
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
		Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
		Vector3(mn.x, mx.y, mx.z), Vector3(mx.x, mx.y, mx.z),
	]
	var ms: Node3D = main.model_space
	var outside := 0
	var behind := 0
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for c in corners:
		var world: Vector3 = ms.to_global(c) if ms != null else c
		if cam.is_position_behind(world):
			behind += 1
			continue
		var px: Vector2 = cam.unproject_position(world)
		min_p = min_p.min(px)
		max_p = max_p.max(px)
		# One pixel of slack for projection rounding.
		if px.x < vp.position.x - 1.0 or px.y < vp.position.y - 1.0 \
				or px.x > vp.end.x + 1.0 or px.y > vp.end.y + 1.0:
			outside += 1
	return {
		"ok": outside == 0 and behind == 0,
		"outside": outside,
		"behind": behind,
		"span": max_p.x - min_p.x,
		"vp_w": vp.size.x,
	}


## Live sketch strokes plus any pad mesh (fill, rim, profile). A consumed
## sketch draws none of them in part mode.
func _sketch_overlay_lines(main) -> Array[String]:
	var hits: Array[String] = []
	var sm: SketchMode = main.sketch_mode
	if sm != null:
		_collect_sketch_meshes(sm, hits)
	var pads = main.view.sketch_pads
	if pads != null:
		for child in pads.get_children():
			if not (child is MeshInstance3D):
				continue
			var mi := child as MeshInstance3D
			if mi.visible and mi.mesh != null:
				hits.append(str(mi.name))
	return hits


func _collect_sketch_meshes(node: Node, hits: Array[String]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.visible and mi.mesh != null:
			hits.append(str(mi.name) if mi.name != "" else "MeshInstance3D")
	for child in node.get_children():
		_collect_sketch_meshes(child, hits)
