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
	var ctx := await _boot()
	if not await _build_boss(ctx):
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


func _build_boss(ctx: FilmContext) -> bool:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	if sm == null or not sm.active:
		return false
	await _zoom(ctx, Vector3.ZERO, 280.0)
	if not await _arm_rect_center(ctx):
		return false
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(60, 60))
	await process_frame
	if not await _extrude(ctx, "30", 0):
		return false
	var base := _volume(ctx)
	print("  base volume %s" % str(base))
	check(absf(base - 432000.0) < 5.0, "base volume 432000 (got %s)" % str(base))
	if absf(base - 432000.0) >= 5.0:
		return false
	if not await _open_z_face(ctx, 30.0):
		return false
	sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(35, 0))
	await process_frame
	if not await _extrude(ctx, "25", 2):
		return false
	var boss := _volume(ctx)
	print("  boss volume %s" % str(boss))
	check(absf(boss - 528211.3) < 5.0, "boss volume 528211 (got %s)" % str(boss))
	return absf(boss - 528211.3) < 5.0


func _convert_rim(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var body := _only_body(ctx)
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
	await _click_model(ctx, Vector3(35, 0, 55), "boss rim")
	var added := _status_since(mark)
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
	await _click_model(ctx, Vector3(35.0 + FACE_BAND + 2.5, 0, 55), "root circle")
	var refused := _status_since(mark)
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
	await _click_model(ctx, Vector3(35.0 + FACE_BAND + 2.5, 0, 30), "z=55 rim")
	var refused := _status_since(mark)
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
	var body := _only_body(ctx)
	check(body != "", "one body before the z=%.0f sketch" % z)
	if body == "":
		return false
	var face := _face_at_z(ctx, body, z)
	check(face != "", "face at z=%.0f" % z)
	if face == "":
		return false
	var pick := FacePick.point(ctx.view.doc, face)
	print("  z=%.0f face %s pick %s" % [z, face, str(pick)])
	check(pick != Vector3.ZERO, "pick point on z=%.0f" % z)
	if ctx.view.selected_bodies.is_empty() and ctx.view.selected_face == "":
		await _click_model(ctx, Vector3(50, 0, 15), "select body")
	await _click_model(ctx, pick, "select z=%.0f face" % z)
	if ctx.view.selected_face != face:
		await _click_model(ctx, pick, "drill z=%.0f face" % z)
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
	return sm.active and sm.sketch != null


func _face_at_z(ctx: FilmContext, body: String, z: float) -> String:
	var best := ""
	var best_gap := 1.0
	var want := Vector3(0, 0, 1)
	for face_id in ctx.view.doc.get_face_ids(body):
		var fid := str(face_id)
		var n := ctx.view.face_normal(body, fid)
		if n.length_squared() < 1e-8 or n.normalized().dot(want) < 0.99:
			continue
		var off := FacePick.plane_offset(n, FacePick.point(ctx.view.doc, fid))
		var gap := absf(off - z)
		if gap < best_gap:
			best_gap = gap
			best = fid
	return best


func _arm_rect_center(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	var chip: Button = null
	if bar != null:
		for c in bar.get_children():
			var b := c as Button
			if b != null and b.text == "Center":
				chip = b
	check(chip != null and chip.is_visible_in_tree(), "Center variant chip is visible")
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center", "Center")):
		return false
	return sm.tool_variant == "center"


func _click_model(ctx: FilmContext, model: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, model)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s is on screen" % desc)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))
	await process_frame


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


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


func _volume(ctx: FilmContext) -> float:
	var body := _only_body(ctx)
	if body == "":
		return -1.0
	var mass: Dictionary = ctx.view.doc.measure_mass(body)
	return float(mass.get("volume", -1.0))


func _status_since(mark: int) -> String:
	if mark >= _status_log.size():
		return ""
	return " | ".join(_status_log.slice(mark))


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
	if main.sketch_mode != null:
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null:
		main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	if text == "":
		return
	_status_log.append(text)
	print("  status: " + text)

