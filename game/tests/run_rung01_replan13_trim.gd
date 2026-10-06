# Rung 1 replan 13 WP2 — Power Trim keeps the typed jaw width and angle, one label per fact.
# Template: run_rung01_replan11_trim.gd (_boot). Jaw is built through the product path
# so the dimension records exist (start_jaw_tool + three clicks + set_dimension_value).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan13_trim.gd
extends SceneTree

const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
## The walk's Power Trim click: 3 mm along the jaw and 8 mm across it, on the shaft side of the cutter.
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan13 WP2 trim typed width/angle")
	await test_typed_20_45()
	await test_typed_15_30_with_hole()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _jaw_dir_for(deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(deg))


func _jaw_across_for(deg: float) -> Vector2:
	var d := _jaw_dir_for(deg)
	return Vector2(-d.y, d.x)


func _shaft_side(deg: float) -> Vector2:
	return HEAD + _jaw_dir_for(deg) * 3.0 + _jaw_across_for(deg) * 8.0


func _dim_index(sm: SketchMode, type: String) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == type:
			return i
	return -1


func _floor_distance_dims(sm: SketchMode) -> Array:
	var out: Array = []
	var floor_id := str(sm._jaw_floor_id)
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "distance":
			continue
		for id in dim.get("ids", []):
			if str(id) == floor_id:
				out.append(dim)
				break
	return out


func _wall_angle_dims(sm: SketchMode) -> Array:
	var walls := {}
	for wid in sm._jaw_wall_ids:
		walls[str(wid)] = true
	var out: Array = []
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "angle":
			continue
		for id in dim.get("ids", []):
			if walls.has(str(id)):
				out.append(dim)
				break
	return out


func _user_value(sm: SketchMode, dim: Dictionary) -> float:
	# Typed / recorded constraint value (mm, or degrees for angles). Not the
	# live measured geometry — that is what leftover 4 used to write back.
	var v := float(dim.get("value", 0.0))
	if str(dim.get("type", "")) == "angle":
		if absf(v) <= PI:
			return rad_to_deg(v)
	return v


func _fold_deg_to_90(deg: float) -> float:
	var a := absf(deg)
	a = absf(fposmod(a, 180.0))
	if a > 90.0:
		a = 180.0 - a
	return a


func _wall_angle_vs_x(sm: SketchMode) -> float:
	if sm._jaw_wall_ids.is_empty():
		return INF
	var info: Dictionary = sm.sketch.entity_info(str(sm._jaw_wall_ids[0]))
	if info.is_empty():
		return INF
	var d: Vector2 = (info["end"] as Vector2) - (info["start"] as Vector2)
	if d.length_squared() < 1e-12:
		return INF
	return _fold_deg_to_90(rad_to_deg(d.angle()))


func _walls_parallel_deg(sm: SketchMode) -> float:
	if sm._jaw_wall_ids.size() < 2:
		return INF
	var a: Dictionary = sm.sketch.entity_info(str(sm._jaw_wall_ids[0]))
	var b: Dictionary = sm.sketch.entity_info(str(sm._jaw_wall_ids[1]))
	if a.is_empty() or b.is_empty():
		return INF
	var da: Vector2 = ((a["end"] as Vector2) - (a["start"] as Vector2)).normalized()
	var db: Vector2 = ((b["end"] as Vector2) - (b["start"] as Vector2)).normalized()
	var ang := absf(rad_to_deg(da.angle_to(db)))
	return minf(ang, 180.0 - ang)


func _floor_length(sm: SketchMode) -> float:
	var info: Dictionary = sm.sketch.entity_info(str(sm._jaw_floor_id))
	if info.is_empty():
		return -1.0
	return (info["end"] as Vector2).distance_to(info["start"] as Vector2)


func _labels_overlap(main, sm: SketchMode) -> bool:
	sm._rebuild_dimension_labels()
	var cam: Camera3D = main.camera
	if cam == null:
		return false
	var k := sm._label_px_scale(cam)
	var rects: Array[Rect2] = []
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var pos_v: Variant = dim.get("label_pos", null)
		if pos_v == null:
			continue
		var world: Vector3 = sm.to_model(pos_v as Vector2)
		var ms: Node3D = main.model_space
		if ms != null:
			world = ms.to_global(world)
		var anchor: Vector2 = cam.unproject_position(world)
		rects.append(sm._dimension_label_rect(dim, anchor, k))
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				return true
	return false


func _add_cutter(sm: SketchMode, deg: float, offset: float = 12.0) -> void:
	var along := _jaw_dir_for(deg)
	var across := _jaw_across_for(deg)
	var cc := HEAD + along * offset
	var c0 := cc - across * 25.0
	var c1 := cc + across * 25.0
	var id: String = sm.sketch.add_line(c0.x, c0.y, c1.x, c1.y)
	sm.sketch.set_construction(id, true)
	sm.run_solve()


func _commit_jaw(sm: SketchMode, width: float, angle_deg: float) -> void:
	var along := _jaw_dir_for(angle_deg)
	var across := _jaw_across_for(angle_deg)
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + along * 30.0)
	sm.click(HEAD + across * (width * 0.5))
	var di := _dim_index(sm, "distance")
	var ai := _dim_index(sm, "angle")
	check(di >= 0 and ai >= 0, "jaw commit recorded width and angle dims (d=%d a=%d n=%d)" % [di, ai, sm.dimensions.size()])
	if di >= 0:
		sm.set_dimension_value(di, width)
	if ai >= 0:
		sm.set_dimension_value(ai, angle_deg)


func _assert_trim_dims(main, sm: SketchMode, width: float, angle_deg: float, tag: String) -> void:
	var dists: Array = _floor_distance_dims(sm)
	var angs: Array = _wall_angle_dims(sm)
	check(dists.size() == 1, "%s exactly one distance names the jaw floor (got %d of %d dims, texts=%s)" % [
			tag, dists.size(), sm.dimensions.size(), _dim_texts(sm)])
	check(angs.size() == 1, "%s exactly one angle names a jaw wall (got %d, texts=%s)" % [
			tag, angs.size(), _dim_texts(sm)])
	if not dists.is_empty():
		var dv := _user_value(sm, dists[0])
		var dt := sm._dimension_label_text(dists[0])
		var want_w := sm._format_dimension(width)
		check(absf(dv - width) <= 1e-6, "%s floor distance value is %s within 1e-6 (got %.6f)" % [tag, str(width), dv])
		check(dt == want_w, "%s floor label text is exactly `%s` (got `%s`)" % [tag, want_w, dt])
	if not angs.is_empty():
		var av := _user_value(sm, angs[0])
		var at := sm._dimension_label_text(angs[0])
		var want_a := sm._format_dimension(angle_deg) + "°"
		check(absf(av - angle_deg) <= 1e-6, "%s wall angle value is %s within 1e-6 (got %.6f)" % [tag, str(angle_deg), av])
		check(at == want_a, "%s wall label text is exactly `%s` (got `%s`)" % [tag, want_a, at])
	var flen := _floor_length(sm)
	check(absf(flen - width) <= 1e-3, "%s floor length is %s ± 1e-3 (got %.6f from entity_info)" % [tag, str(width), flen])
	var wdeg := _wall_angle_vs_x(sm)
	check(absf(wdeg - angle_deg) <= 0.01, "%s wall vs +X is %s ± 0.01° from entity_info (got %.4f)" % [tag, str(angle_deg), wdeg])
	var pdeg := _walls_parallel_deg(sm)
	check(pdeg <= 0.01, "%s walls are parallel within 0.01° (got %.4f)" % [tag, pdeg])


func _dim_texts(sm: SketchMode) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		parts.append("%s=%s" % [str(dim.get("type", "")), sm._dimension_label_text(dim)])
	return ", ".join(parts)


func test_typed_20_45() -> void:
	print("-- product-path jaw 20 / 45°, then Power Trim")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	_commit_jaw(sm, 20.0, 45.0)
	_add_cutter(sm, 45.0)
	_status_log.clear()
	sm.trim_at(SHAFT_SIDE)
	check(_last_status() == "Trimmed open jaw", "status stays Trimmed open jaw (got `%s` log=%s)" % [_last_status(), str(_status_log)])
	check(not _status_has("Dimension updated"), "Dimension updated is not re-emitted (log=%s)" % str(_status_log))
	_assert_trim_dims(main, sm, 20.0, 45.0, "20/45")
	var d0: Array = _floor_distance_dims(sm)
	var a0: Array = _wall_angle_dims(sm)
	var dv0 := _user_value(sm, d0[0]) if not d0.is_empty() else INF
	var av0 := _user_value(sm, a0[0]) if not a0.is_empty() else INF
	sm.run_solve()
	var d1: Array = _floor_distance_dims(sm)
	var a1: Array = _wall_angle_dims(sm)
	var dv1 := _user_value(sm, d1[0]) if not d1.is_empty() else INF
	var av1 := _user_value(sm, a1[0]) if not a1.is_empty() else INF
	check(absf(dv1 - dv0) <= 1e-9 and absf(av1 - av0) <= 1e-9,
			"re-solve holds the typed values (distance %.9f→%.9f angle %.9f→%.9f)" % [dv0, dv1, av0, av1])
	_status_log.clear()
	sm.trim_at(SHAFT_SIDE)
	check(_status_has("Jaw is already open"), "a second trim_at says the jaw is already open (log=%s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "trimmed Jaw profile is closed")
	check(sm.last_conflicting.is_empty(), "last_conflicting empty (got %s last_dofs=%s status=%s)" % [
			str(sm.last_conflicting), str(sm.last_dofs), str(sm.last_solve_status)])
	check(not _labels_overlap(main, sm), "dimension label rectangles do not overlap")
	await _shutdown(main)


func test_typed_15_30_with_hole() -> void:
	print("-- A9 geometry: Ø5 at origin, typed 15 / 30°")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	_commit_jaw(sm, 15.0, 30.0)
	_add_cutter(sm, 30.0)
	_status_log.clear()
	sm.trim_at(_shaft_side(30.0))
	check(_last_status() == "Trimmed open jaw", "15/30 status stays Trimmed open jaw (got `%s`)" % _last_status())
	_assert_trim_dims(main, sm, 15.0, 30.0, "15/30")
	await _shutdown(main)


func _boot():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.view.clear_selection()
	main._start_sketch()
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return main


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _shutdown(main) -> void:
	main.queue_free()
	await process_frame
	await process_frame
