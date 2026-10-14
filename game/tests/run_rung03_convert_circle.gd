# Rung 3 WP4 — Convert projects the boss rim and refuses the other circle.
# Click-built base + Ø70 boss. On main the rim click does not report
# "Convert: external circle".
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung03_convert_circle.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const ROOT_SIZE := Vector2i(1280, 800)
## Host edges accept inside this; other edges refuse inside SketchConvertEdge.OTHER_TOL.
const FACE_BAND := 3.5

var _status_log: Array[String] = []


func _init() -> void:
	print("rung03 convert circle")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await Tutor1Fixture.boot(self, ROOT_SIZE, _on_status, ["sketch_mode", "interaction"])
	check(root.size == ROOT_SIZE, "root is 1280×800")
	if not await Tutor1Fixture.build_boss(self, ctx, _check_base):
		ctx.main.queue_free()
		return
	if not await _open_z_face(ctx, 55.0):
		ctx.main.queue_free()
		return
	await _convert_rim(ctx)
	await FilmUI.exit_sketch(ctx)
	if not await _open_z_face(ctx, 30.0):
		ctx.main.queue_free()
		return
	await _refuse_other_rim(ctx)
	ctx.main.queue_free()


func _convert_rim(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var body := Tutor1Fixture.only_body(ctx)
	for face_id in ctx.view.doc.get_face_ids(body):
		var fid := str(face_id)
		var n := ctx.view.face_normal(body, fid)
		if n.length_squared() < 1e-8 or n.normalized().dot(Vector3(0, 0, 1)) < 0.99:
			continue
		var pick := FacePick.point(ctx.view.doc, fid)
		print("  +Z face %s edges %d plane %.2f pick %s" % [
			fid, ctx.view.doc.edges_of_face(fid).size(),
			FacePick.plane_offset(n, pick), str(pick)])
	print("  host %s" % sm.host_face_id.substr(0, 8))
	check(absf(sm.plane_origin.z - 55.0) < 0.5, "sketch is on z=55 (got %s)" % str(sm.plane_origin))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	check(sm.tool == SketchMode.Tool.CONVERT, "rail Convert is armed")
	print("  host after arm %s edges %d" % [
		sm.host_face_id, ctx.view.doc.edges_of_face(sm.host_face_id).size()])
	var mark := _status_log.size()
	await Tutor1Fixture.click_model(self, ctx, Vector3(35, 0, 55), "boss rim")
	var added := Tutor1Fixture.status_since(_status_log, mark)
	print("  rim status: %s" % added)
	var circles := _external_circles(sm)
	print("  external circles %d" % circles.size())
	check(added.contains("Convert: external circle"),
			"rim converts to an external circle (got '%s')" % added)
	check(circles.size() == 1, "sketch lists one external circle (got %d)" % circles.size())
	if circles.size() == 1:
		var c: Vector2 = circles[0]["center"]
		var r: float = float(circles[0]["radius"])
		print("  circle centre %s r %s" % [str(c), str(r)])
		check(c.distance_to(Vector2.ZERO) <= 0.05, "external circle centre is the origin (got %s)" % str(c))
		check(absf(r - 35.0) <= 0.05, "external circle r = 35 (got %s)" % str(r))
	# The root is the same plan circle as the rim, 25 mm below the sketch.
	# Outside FACE_TOL the host rim is not taken; inside OTHER_TOL the root is refused.
	var before := _external_circles(sm).size()
	mark = _status_log.size()
	await Tutor1Fixture.click_model(self, ctx, Vector3(35.0 + FACE_BAND + 2.5, 0, 55), "root circle")
	var refused := Tutor1Fixture.status_since(_status_log, mark)
	print("  root status: %s" % refused)
	check(_external_circles(sm).size() == before, "root click adds no entity (got %d)" % _external_circles(sm).size())
	check(refused.contains("Convert: edge is not on this face"),
			"root circle is refused (got '%s')" % refused)


func _refuse_other_rim(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	print("  z30 origin %s" % str(sm.plane_origin))
	check(absf(sm.plane_origin.z - 30.0) < 0.5, "sketch is on z=30 (got %s)" % str(sm.plane_origin))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	var before := _entity_count(sm)
	var mark := _status_log.size()
	await Tutor1Fixture.click_model(self, ctx, Vector3(35.0 + FACE_BAND + 2.5, 0, 30), "z=55 rim")
	var refused := Tutor1Fixture.status_since(_status_log, mark)
	print("  z55 rim status: %s" % refused)
	check(_entity_count(sm) == before, "z=55 rim adds no entity (got %d)" % _entity_count(sm))
	check(refused.contains("Convert: edge is not on this face"),
			"z=30 sketch refuses the z=55 rim (got '%s')" % refused)


func _extrude(ctx: FilmContext, distance: String, op_index: int) -> bool:
	await FilmSteps.type_distance(ctx, distance)
	await FilmSteps.pick_finish(ctx, op_index, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button() if ctx.main.sketch_chrome != null else null
	check(ex != null and ex.is_visible_in_tree(), "Extrude button is visible")
	if ex == null:
		return false
	await _x11_click(ex)
	for _i in 10:
		await process_frame
	var text := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	print("  extrude op %d dist %s -> %s" % [op_index, distance, text])
	check(text.contains("Extrude"), "extrude status (got '%s')" % text)
	return text.contains("Extrude")


func _open_z_face(ctx: FilmContext, z: float) -> bool:
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	await process_frame
	var body := Tutor1Fixture.only_body(ctx)
	check(body != "", "one body before the z=%.0f sketch" % z)
	if body == "":
		return false
	var face := Tutor1Fixture.face_at_z(ctx, body, z)
	check(face != "", "face at z=%.0f" % z)
	if face == "":
		return false
	var pick := FacePick.point(ctx.view.doc, face)
	print("  z=%.0f face %s pick %s" % [z, face, str(pick)])
	check(pick != Vector3.ZERO, "pick point on z=%.0f" % z)
	if ctx.view.selected_bodies.is_empty() and ctx.view.selected_face == "":
		await Tutor1Fixture.click_model(self, ctx, Vector3(50, 0, 15), "select body")
	await Tutor1Fixture.click_model(self, ctx, pick, "select z=%.0f face" % z)
	if ctx.view.selected_face != face:
		await Tutor1Fixture.click_model(self, ctx, pick, "drill z=%.0f face" % z)
	check(ctx.view.selected_face == face, "z=%.0f face selected (got %s)" % [z, ctx.view.selected_face])
	if ctx.view.selected_face != face:
		return false
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Sketch") if strip != null else null
	check(chip != null and chip.is_visible_in_tree(), "Sketch chip is visible")
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.toolbar_sketch()):
		return false
	for _i in 4:
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "face sketch is active")
	if sm.active:
		_check_face_sketch_look(ctx, sm)
	return sm.active and sm.sketch != null


## Kernel look of the live camera. ModelSpace is Rx(-90), so a top view's
## world look is (0,-1,0) and its kernel look is (0,0,-1).
func _check_face_sketch_look(ctx: FilmContext, sm: SketchMode) -> void:
	var cam: OrbitCamera = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam == null or ms == null:
		check(false, "camera and model space exist for the face sketch")
		return
	var inv: Transform3D = ms.global_transform.affine_inverse()
	var pos_m: Vector3 = inv * cam.global_position
	var piv_m: Vector3 = inv * cam.pivot
	var delta := piv_m - pos_m
	var look := Vector3.ZERO
	if delta.length_squared() > 1e-8:
		look = delta.normalized()
	var world := cam.pivot - cam.global_position
	if world.length_squared() > 1e-8:
		world = world.normalized()
	print("  plane.normal %s yaw %.4f pitch %.4f world_look %s model_look %s" % [
		str(sm.plane_normal()), cam.yaw, cam.pitch, str(world), str(look)])
	check(look.distance_to(Vector3(0.0, 0.0, -1.0)) <= 1e-2,
			"face sketch looks down -Z (got %s)" % str(look))


func _external_circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if sm.sketch.is_external(id) and str(info.get("type", "")) == "circle":
			info["id"] = str(id)
			out.append(info)
	return out


func _entity_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return 0
	return sm.sketch.entity_ids().size()


func _on_status(text: String) -> void:
	Tutor1Fixture.note(_status_log, text)


func _check_base(ctx: FilmContext) -> bool:
	var base := Tutor1Fixture.volume(ctx)
	print("  base volume %s" % str(base))
	check(absf(base - 432000.0) < 5.0, "base volume 432000 (got %s)" % str(base))
	return absf(base - 432000.0) < 5.0

