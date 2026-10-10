# L6: Shaft Lines after a centre-to-centre Smart Dim must not add the redundant
# point-on-circle that PlaneGCS reports next to the tangent. Badges stay blue.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan15_shaftbadges.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 shaft lines after centre dimension — no redundant badges")
	await _boot_and_run()
	finish()


func _boot_and_run() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active and sm.sketch != null, "ground sketch is open")
	if sm.sketch == null:
		await _shutdown(ctx)
		return
	var a := _add_sized_circle(sm, Vector2.ZERO, 10.0)
	var b := _add_sized_circle(sm, Vector2(200.0, 0.0), 22.5)
	check(a != "" and b != "", "Ø20 at the origin and Ø45 on +X")
	sm._set_selected([a, b])
	sm._smart_dim_between({"entity": a, "role": "center"}, {"entity": b, "role": "center"})
	var idx := sm._distance_dim_index_for(a, b)
	check(idx >= 0, "centre-to-centre dimension exists")
	if idx >= 0:
		sm.set_dimension_value(idx, 200.0)
	var gap := (sm.sketch.entity_info(a)["center"] as Vector2).distance_to(
			sm.sketch.entity_info(b)["center"] as Vector2)
	check(absf(gap - 200.0) < 0.05, "centre distance is 200 (got %.3f)" % gap)
	check(sm.last_redundant.is_empty() and sm.last_conflicting.is_empty(),
			"before Shaft Lines the centre dim is clean (redundant %s conflicting %s)" % [
				str(sm.last_redundant), str(sm.last_conflicting)])
	sm._set_selected([a, b])
	var added := sm.shaft_lines_selected()
	check(added == 2, "Shaft Lines adds 2 lines (got %d)" % added)
	check(_status_has("Shaft lines: 2 added"), "status reports 2 lines added")
	_assert_clean(sm, "immediately after Shaft Lines")
	# The chip's last solve is inside inference. Solve once more the way a
	# later extrude does, then read badges off that result.
	sm.run_solve()
	sm._redraw()
	_assert_clean(sm, "after Shaft Lines")
	_assert_geometry(sm)
	check(SketchMode.profile_is_closed(sm.sketch), "the web closes the profile")
	await _shutdown(ctx)


func _add_sized_circle(sm: SketchMode, center: Vector2, radius: float) -> String:
	var id: String = sm.sketch.add_circle(center.x, center.y, radius)
	if id == "":
		return ""
	var cid: String = sm.sketch.add_constraint("radius", [{"entity": id, "role": "self"}], radius)
	sm._record_dimension("radius", [id], radius, cid)
	return id


func _assert_clean(sm: SketchMode, when: String) -> void:
	check(sm.last_solve_status == "success" or sm.last_solve_status == "converged",
			"%s: solve succeeded (got %s, dofs %d)" % [when, sm.last_solve_status, sm.last_dofs])
	check(sm.last_dofs >= 0, "%s: solver dofs are not negative (got %d)" % [when, sm.last_dofs])
	check(sm.last_redundant.is_empty(),
			"%s: 0 redundant constraints (got %s)" % [when, str(sm.last_redundant)])
	check(sm.last_conflicting.is_empty(),
			"%s: 0 conflicting constraints (got %s)" % [when, str(sm.last_conflicting)])
	check(sm.selected_constraint == "",
			"%s: no constraint left selected" % when)
	var glyphs: Node3D = sm._constraint_glyphs
	check(glyphs != null and glyphs.get_child_count() > 0, "%s: constraint glyphs exist" % when)
	if glyphs == null:
		return
	var saw_h := false
	var saw_error := false
	for child in glyphs.get_children():
		var lab := child as Label3D
		if lab == null:
			continue
		if lab.text == "H":
			saw_h = true
		var bad := lab.modulate.is_equal_approx(SketchMode.COLOR_CONFLICT) \
				or lab.modulate.is_equal_approx(SketchMode.COLOR_GLYPH_SELECTED)
		if bad:
			saw_error = true
		check(not bad, "%s: glyph '%s' is not red/orange (got %s)" % [when, lab.text, str(lab.modulate)])
		check(lab.modulate.is_equal_approx(SketchMode.COLOR_GLYPH),
				"%s: glyph '%s' is the blue badge colour" % [when, lab.text])
	check(saw_h, "%s: a blue H badge is still drawn" % when)
	check(not saw_error, "%s: no red/orange badge" % when)
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		var col: Color = sm._entity_draw_color(info, str(id))
		check(not col.is_equal_approx(SketchMode.COLOR_CONFLICT),
				"%s: %s is not drawn as a conflict" % [when, str(info.get("type", ""))])


func _assert_geometry(sm: SketchMode) -> void:
	var ys: Array[float] = []
	var near_on_circle := 0
	var tangents := 0
	var perps := 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(cid)
		var kind := str(info.get("type", ""))
		if kind == "tangent":
			tangents += 1
		elif kind == "perpendicular":
			perps += 1
		elif kind == "distance":
			if _distance_is_tangent_contact(sm, info):
				near_on_circle += 1
	check(tangents == 2, "both shaft lines keep a tangent (got %d)" % tangents)
	check(perps >= 2, "each tangent contact is pinned perpendicular (got %d)" % perps)
	check(near_on_circle == 0,
			"no point-on-circle distance at the tangent contact (got %d)" % near_on_circle)
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		ys.append(a.y)
		check(absf(a.y - b.y) < 1e-2, "shaft line stays horizontal (y %.3f vs %.3f)" % [a.y, b.y])
		var far_x := maxf(a.x, b.x)
		check(absf(far_x - 179.844) < 0.05, "shaft line meets the Ø45 (far x %.3f)" % far_x)
	ys.sort()
	check(ys.size() == 2 and ys[0] < -5.0 and ys[1] > 5.0,
			"shaft lines sit on both sides (got %s)" % str(ys))


## The redundant constraint was a distance from the shaft contact to the small
## circle's centre, equal to that circle's radius. The far end on the Ø45 is
## a real on-circle distance and must stay.
func _distance_is_tangent_contact(sm: SketchMode, info: Dictionary) -> bool:
	var refs: Array = info.get("refs", [])
	if refs.size() < 2:
		return false
	var line_id := ""
	var line_role := ""
	var circle_id := ""
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var eid := str(ref.get("entity", ""))
		var role := str(ref.get("role", ""))
		var einfo: Dictionary = sm.sketch.entity_info(eid)
		var kind := str(einfo.get("type", ""))
		if kind == "line" and (role == "start" or role == "end"):
			line_id = eid
			line_role = role
		elif kind == "circle" and role == "center":
			circle_id = eid
	if line_id == "" or circle_id == "":
		return false
	var cinfo: Dictionary = sm.sketch.entity_info(circle_id)
	if float(cinfo.get("radius", 0.0)) > 15.0:
		return false
	var linfo: Dictionary = sm.sketch.entity_info(line_id)
	if sm.sketch.is_construction(line_id):
		return false
	var p: Vector2 = linfo["start"] if line_role == "start" else linfo["end"]
	var c: Vector2 = cinfo["center"]
	return p.distance_to(c) < 15.0


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
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame
