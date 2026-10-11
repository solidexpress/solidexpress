# Rung 2 WP5 — face-boundary edges as external lines, then point-line Smart Dim.
# Click-built 100×60×50 box, R10 on the four Z edges so the +X face's left
# boundary is y = 10. Right view, Sketch, rail Convert, then Ø10 / 25 / 40.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung02_face_edges.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const CENTRE_TOL := 0.01

var _status_log: Array[String] = []


func _init() -> void:
	print("rung02 face edges")
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
	_fillet_z_edges(ctx)
	if failures > 0:
		ctx.main.queue_free()
		return
	if not await _open_face_sketch(ctx):
		ctx.main.queue_free()
		return
	await _zoom(ctx, Vector3(100, 30, 25), 90.0)
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	check(sm.tool == SketchMode.Tool.CONVERT and _status_log.has("Convert — click an edge of this face"),
			"rail Convert is armed")
	var before := _entity_count(sm)
	await _project_click(ctx, Vector3(100, 10, 25), "Left edge y=10")
	await _project_click(ctx, Vector3(100, 30, 0), "Bottom edge z=0")
	_note_status(ctx)
	var externals := _external_lines(sm)
	print("  entities %d external %d" % [_entity_count(sm), externals.size()])
	_dump_entities(sm)
	check(externals.size() == 2 and _status_log.has("Convert: external line"),
			"two external lines (got %d)" % externals.size())
	var constructed := 0
	for id in externals:
		if sm.sketch.is_construction(id):
			constructed += 1
	check(constructed == 2, "both external lines are construction (got %d)" % constructed)
	if externals.size() != 2:
		ctx.main.queue_free()
		return
	await _circle_and_dims(ctx)
	await _refuse_foreign_edge(ctx)
	await _esc_disarms(ctx)
	ctx.main.queue_free()


func _circle_and_dims(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(35, 40))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(43, 40))
	await process_frame
	var circles := _circles(sm)
	check(circles.size() == 1, "one circle (got %d)" % circles.size())
	if circles.size() != 1:
		return
	print("  circle placed %s r=%s" % [str(circles[0]["center"]), str(circles[0]["radius"])])
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	var circle_id := str(circles[0]["id"])
	var center: Vector2 = circles[0]["center"]
	# On the curve, not the centre: a centre click only arms the second pick.
	var rim := center + Vector2(float(circles[0]["radius"]), 0.0)
	await _click_uv(ctx, ctx.main.get_viewport(), rim)
	await process_frame
	var di := _dim_index(sm, "diameter")
	check(di >= 0, "diameter dimension exists")
	if di < 0 or not await _type_label(ctx, di, "10"):
		return
	check(_label_has(sm, "Ø10"), "drawn label Ø10 (%s)" % _label_texts(sm))
	var left := _line_near_world(ctx, Vector3(100, 10, 25))
	var bottom := _line_near_world(ctx, Vector3(100, 30, 0))
	check(left != "" and bottom != "" and left != bottom, "left and bottom lines are distinct")
	if left == "" or bottom == "":
		return
	await _dim_circle_to_line(ctx, circle_id, left, "25")
	await _dim_circle_to_line(ctx, circle_id, bottom, "40")
	check(_label_has(sm, "25"), "drawn label 25 (%s)" % _label_texts(sm))
	check(_label_has(sm, "40"), "drawn label 40 (%s)" % _label_texts(sm))
	var chip := str(ctx.main.dof_label.text) if ctx.main.dof_label != null else ""
	print("  dof chip '%s' last_dofs %s" % [chip, str(sm.last_dofs)])
	check(int(sm.last_dofs) == 0, "DOF is 0 (got %s, chip '%s')" % [str(sm.last_dofs), chip])
	circles = _circles(sm)
	if circles.is_empty():
		check(false, "circle remains")
		return
	var c: Vector2 = circles[0]["center"]
	var world: Vector3 = sm.plane_origin + sm.plane_x * c.x + sm.plane_y * c.y
	print("  circle uv %s world %s origin %s" % [str(c), str(world), str(sm.plane_origin)])
	check(c.distance_to(Vector2(35, 40)) <= CENTRE_TOL, "sketch centre (35, 40) (got %s)" % str(c))
	check(world.distance_to(Vector3(100, 35, 40)) <= CENTRE_TOL,
			"world centre (100, 35, 40) (got %s)" % str(world))
	var extras := _non_profile_extras(sm)
	print("  extras %s" % str(extras))
	check(extras == 0, "no helper entity besides the two external lines (got %d)" % extras)


func _dim_circle_to_line(ctx: FilmContext, circle_id: String, line_id: String, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var info: Dictionary = sm.sketch.entity_info(circle_id)
	# Centre first (arms the point), then the external line: Distance(centre, line).
	await _click_uv(ctx, ctx.main.get_viewport(), info["center"])
	await process_frame
	var li: Dictionary = sm.sketch.entity_info(line_id)
	var mid: Vector2 = (li["start"] + li["end"]) * 0.5
	await _click_uv(ctx, ctx.main.get_viewport(), mid)
	await process_frame
	var di := _dim_index_for(sm, circle_id, line_id)
	check(di >= 0, "distance dimension to the edge exists before typing %s" % text)
	if di < 0:
		return
	await _type_label(ctx, di, text)


func _refuse_foreign_edge(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var n0 := _external_lines(sm).size()
	var spot := _foreign_spot(ctx)
	print("  foreign spot %s" % str(spot))
	check(spot != Vector3.INF, "a non-face edge has a click point")
	if spot == Vector3.INF:
		return
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	var mark := _status_log.size()
	await _project_click(ctx, spot, "Edge not on the sketch face")
	_note_status(ctx)
	var refused := _status_since(mark)
	print("  refused: %s" % refused)
	check(_external_lines(sm).size() == n0, "foreign edge adds no external (got %d)" % _external_lines(sm).size())
	check(refused.contains("Convert: edge is not on this face"),
			"foreign edge is refused with a status (got '%s')" % refused)


func _esc_disarms(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	# A live selection spends the first Esc (rung 1 ladder). Convert is the next.
	if not sm.selected.is_empty() or sm.selected_constraint != "":
		await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
		await process_frame
		check(sm.active, "Esc on a selection keeps the sketch")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	check(sm.tool == SketchMode.Tool.CONVERT, "Convert armed before Esc")
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	_note_status(ctx)
	print("  esc tool %s active %s" % [str(sm.tool), str(sm.active)])
	check(sm.active, "one Esc keeps the sketch")
	check(sm.tool == SketchMode.Tool.SELECT, "one Esc disarms Convert (got %s)" % str(sm.tool))


func _foreign_spot(ctx: FilmContext) -> Vector3:
	var sm: SketchMode = ctx.main.sketch_mode
	var body := _body(ctx)
	var face_ids := {}
	for id in ctx.view.doc.edges_of_face(sm.host_face_id):
		face_ids[str(id)] = true
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	var best := Vector3.INF
	var best_score := INF
	for id in lines:
		if face_ids.has(str(id)):
			continue
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		var on_plane: Vector3 = _on_sketch_plane(sm, mid)
		var face_d := _nearest_face_edge_distance(lines, face_ids, on_plane)
		var gap := mid.distance_to(on_plane)
		# The click lands on the sketch plane. It must be nearer this edge
		# than any boundary of the sketch face, and still close enough to pick.
		if face_d < 4.0 or gap > 12.0 or gap > face_d:
			continue
		if gap < best_score:
			best_score = gap
			best = on_plane
	return best


func _on_sketch_plane(sm: SketchMode, world: Vector3) -> Vector3:
	var rel := world - sm.plane_origin
	var u := rel.dot(sm.plane_x)
	var v := rel.dot(sm.plane_y)
	return sm.plane_origin + sm.plane_x * u + sm.plane_y * v


func _nearest_face_edge_distance(lines: Dictionary, face_ids: Dictionary, point: Vector3) -> float:
	var best := INF
	for id in lines:
		if not face_ids.has(str(id)):
			continue
		var pts: PackedVector3Array = lines[id]
		for i in range(pts.size() - 1):
			best = minf(best, SketchGeom.point_segment_distance_3d(point, pts[i], pts[i + 1]))
	return best


func _open_face_sketch(ctx: FilmContext) -> bool:
	await _push_key(ctx.main.get_viewport(), KEY_2, 0)
	await process_frame
	await process_frame
	var body := _body(ctx)
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(1, 0, 0))
	check(face != "", "+X face exists")
	if face == "":
		return false
	var pick_pt: Vector3 = FilmUI.face_pick_point(ctx.view, body, face)
	if pick_pt == Vector3.INF:
		pick_pt = Vector3(100, 30, 25)
	var screen := FilmUI.model_to_screen(ctx, pick_pt)
	check(FilmUI.require_on_screen(ctx, screen, "+X"), "+X face point is on screen")
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select +X face"))
	await process_frame
	if ctx.view.selected_face != face:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Drill +X face"))
		await process_frame
	check(ctx.view.selected_face == face, "+X face selected")
	await _push_key(ctx.main.get_viewport(), KEY_2, 0)
	await process_frame
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Sketch") if strip != null else null
	check(chip != null and chip.is_visible_in_tree(), "Sketch chip is visible")
	if chip == null:
		return false
	await FilmUI.click_control(ctx, chip, FilmUICues.toolbar_sketch())
	for _i in 4:
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "face sketch is active")
	if not sm.active or sm.sketch == null:
		return false
	var pi: Dictionary = sm.sketch.plane_info()
	var px: Vector3 = (pi["x_dir"] as Vector3).normalized()
	var py: Vector3 = (pi["y_dir"] as Vector3).normalized()
	print("  plane x=%s y=%s origin=%s" % [str(px), str(py), str(sm.plane_origin)])
	check(px.distance_to(Vector3(0, 1, 0)) < 1e-4 and py.distance_to(Vector3(0, 0, 1)) < 1e-4,
			"upright basis x=+Y y=+Z")
	return true


func _build_box(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(50, 30, 0), 160.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(100, 60))
	await process_frame
	var dist := _distance_edit(ctx)
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
	var body := _body(ctx)
	check(body != "", "extrude made one body")
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var sz: Vector3 = bb["max"] - bb["min"]
	check(sz.distance_to(Vector3(100, 60, 50)) < 0.2, "box is 100×60×50 (got %s)" % str(sz))


func _fillet_z_edges(ctx: FilmContext) -> void:
	var body := _body(ctx)
	var fid := ctx.view.feature_of_body(body)
	var edges := PackedStringArray()
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) > 5.0 and absf(d.x) < 0.5 and absf(d.y) < 0.5:
			edges.append(str(id))
	check(edges.size() == 4, "four Z edges to fillet (got %d)" % edges.size())
	if edges.size() != 4 or fid == "":
		return
	var added := ctx.view.doc.graph_add_fillet(fid, edges, 10.0)
	check(added != "", "fillet feature added (%s)" % ctx.view.doc.last_graph_error())
	ctx.view.graph_changed()
	await process_frame
	await process_frame


func _project_click(ctx: FilmContext, model: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, model)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s is on screen" % desc)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))
	await process_frame


func _type_label(ctx: FilmContext, index: int, text: String) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[index])
	check(lp != null, "label %d has a position" % index)
	if lp == null:
		return false
	await _click_uv(ctx, ctx.main.get_viewport(), lp as Vector2)
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"dimension popup is visible for label %d" % index)
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return false
	var line: LineEdit = ix._dim_edit_line
	await _x11_click(line)
	await _type_text(line.get_viewport(), text)
	await _push_key(line.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	return true


func _line_near_world(ctx: FilmContext, world: Vector3) -> String:
	var sm: SketchMode = ctx.main.sketch_mode
	var rel := world - sm.plane_origin
	var uv := Vector2(rel.dot(sm.plane_x), rel.dot(sm.plane_y))
	var best := ""
	var best_d := 2.0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_external(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d := SketchGeom.point_segment_distance(uv, info["start"], info["end"])
		if d < best_d:
			best_d = d
			best = str(id)
	return best


func _external_lines(sm: SketchMode) -> Array[String]:
	var out: Array[String] = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if sm.sketch.is_external(id) and str(info.get("type", "")) == "line":
			out.append(str(id))
	return out


func _non_profile_extras(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind == "circle":
			continue
		if kind == "line" and sm.sketch.is_external(id):
			continue
		n += 1
	return n


func _circles(sm: SketchMode) -> Array:
	var out: Array = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			info["id"] = str(id)
			out.append(info)
	return out


func _entity_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return 0
	return sm.sketch.entity_ids().size()


func _dump_entities(sm: SketchMode) -> void:
	if sm.sketch == null:
		return
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		print("  ent %s type=%s ext=%s con=%s" % [
			str(id).substr(0, 8), str(info.get("type", "")),
			str(sm.sketch.is_external(id)), str(sm.sketch.is_construction(id))])


func _dim_index(sm: SketchMode, type: String) -> int:
	for i in range(sm.dimensions.size()):
		if str(sm.dimensions[i].get("type", "")) == type:
			return i
	return -1


func _dim_index_for(sm: SketchMode, a: String, b: String) -> int:
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != "distance":
			continue
		var ids: Array = dim.get("ids", [])
		if ids.size() < 2:
			continue
		var ia := str(ids[0])
		var ib := str(ids[1])
		if (ia == a and ib == b) or (ia == b and ib == a):
			return i
	return -1


func _label_texts(sm: SketchMode) -> String:
	var parts: PackedStringArray = []
	for dim in sm.dimensions:
		parts.append(sm._dimension_label_text(dim))
	return ", ".join(parts)


func _label_has(sm: SketchMode, text: String) -> bool:
	for dim in sm.dimensions:
		if sm._dimension_label_text(dim) == text:
			return true
	return false


func _body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


func _distance_edit(ctx: FilmContext) -> LineEdit:
	var chrome = ctx.main.sketch_chrome
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


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


func _note_status(ctx: FilmContext) -> void:
	if ctx.main != null and ctx.main.status_label != null:
		var text := str(ctx.main.status_label.text)
		if text != "" and (_status_log.is_empty() or _status_log[_status_log.size() - 1] != text):
			_status_log.append(text)
			print("  status: " + text)
