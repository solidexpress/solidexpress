# Rung 1 replan 11 WP6 — one click edits an angle label; trim floor is perpendicular.
# Reuses the jaw builder from run_rung01_replan10_trim.gd (_build_jaw, offset 12)
# with JAW_DIR rotated 0.3° from 45° so the 89.71° floor is visible on b3161bba.
# Validation: trim_at, dimension_hit, _emit_dimension_edit, _apply_dim_edit.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_dim.gd
extends SceneTree

const HEAD := Vector2(200.0, 0.0)


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
	print("rung01 replan11 WP6 dim / perpendicular floor")
	await test_one_click_angle_and_perp_floor()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _jaw_dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(45.3))


func _jaw_across() -> Vector2:
	var d := _jaw_dir()
	return Vector2(-d.y, d.x)


## Ø10 hole at the origin, Ø45 head at HEAD, the 20 mm wide Jaw rectangle at
## 45.3 degrees, and the perpendicular cutter centreline `offset` mm along the
## jaw from the head centre. Copied from run_rung01_replan10_trim.gd.
func _build_jaw(sm: SketchMode, offset: float, hole_c: Vector2) -> void:
	var sk = sm.sketch
	var jaw_dir := _jaw_dir()
	var jaw_across := _jaw_across()
	sk.add_circle(hole_c.x, hole_c.y, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - jaw_dir * 30.0 - jaw_across * 10.0
	var p1 := HEAD + jaw_dir * 30.0 - jaw_across * 10.0
	var p2 := HEAD + jaw_dir * 30.0 + jaw_across * 10.0
	var p3 := HEAD - jaw_dir * 30.0 + jaw_across * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + jaw_dir * offset
	var c0 := cc - jaw_across * 25.0
	var c1 := cc + jaw_across * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()


func _shaft_side() -> Vector2:
	return HEAD + _jaw_dir() * 3.0 + _jaw_across() * 8.0


func _dim_index(sm: SketchMode, type: String) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == type:
			return i
	return -1


func _entity_dir(sm: SketchMode, id: String) -> Vector2:
	var info: Dictionary = sm.sketch.entity_info(id)
	if info.is_empty():
		return Vector2.ZERO
	return (info["end"] as Vector2) - (info["start"] as Vector2)


func _folded_to_horizontal_deg(d: Vector2) -> float:
	if d.length_squared() < 1e-12:
		return 0.0
	var deg := absf(rad_to_deg(d.angle()))
	if deg > 90.0:
		deg = 180.0 - deg
	return deg


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func test_one_click_angle_and_perp_floor() -> void:
	print("-- trim at 12 mm, then one-click edit the angle to 45")
	var main = await _boot()
	var sm: SketchMode = main.sketch_mode
	var ix: ViewportInteraction = main.interaction
	_build_jaw(sm, 12.0, Vector2.ZERO)
	_status_log.clear()
	sm.trim_at(_shaft_side())
	sm.set_tool(SketchMode.Tool.SMART_DIM)

	var wall_id := "" if sm._jaw_wall_ids.is_empty() else str(sm._jaw_wall_ids[0])
	var floor_id := sm._jaw_floor_id
	var wd := _entity_dir(sm, wall_id)
	var fd := _entity_dir(sm, floor_id)
	var abs_dot := 1.0
	if wd.length_squared() > 1e-12 and fd.length_squared() > 1e-12:
		abs_dot = absf(wd.normalized().dot(fd.normalized()))
	check(abs_dot <= 0.0009, "after trim, wall-0 · floor abs(dot) ≤ sin(0.05°) (got %.6f)" % abs_dot)

	var ang_i := _dim_index(sm, "angle")
	var ang_lp: Variant = null
	if ang_i >= 0:
		ang_lp = sm.dimensions[ang_i].get("label_pos", null)
	check(ang_i >= 0 and ang_lp != null and sm.dimension_hit(ang_lp) == ang_i,
			"dimension_hit at stored angle label_pos returns the angle index (i=%d lp=%s hit=%d)" % [
				ang_i, str(ang_lp), sm.dimension_hit(ang_lp) if ang_lp != null else -1])

	var nudged: Vector2 = Vector2.ZERO
	if ang_lp != null:
		nudged = (ang_lp as Vector2) + Vector2(0, 2.5)
	check(ang_i >= 0 and ang_lp != null and sm.dimension_hit(nudged) == ang_i,
			"dimension_hit at label_pos + (0, 2.5) still returns the angle index (hit=%d)" % [
				sm.dimension_hit(nudged) if ang_lp != null else -1])

	sm._emit_dimension_edit(ang_i)
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"one _emit_dimension_edit makes DimEditPopup visible")

	var shown := 0.0 if ang_i < 0 else sm._dimension_display_value(sm.dimensions[ang_i])
	var line_text := "" if ix._dim_edit_line == null else ix._dim_edit_line.text.strip_edges()
	var shown_txt := String.num(shown, 3)
	check(line_text != "" and line_text != "0" and line_text.begins_with(shown_txt),
			"DimEditLine.text starts with the displayed degrees (text=%s shown=%s)" % [line_text, shown_txt])

	await process_frame
	await process_frame
	var selected := "" if ix._dim_edit_line == null else ix._dim_edit_line.get_selected_text()
	check(selected.length() > 0, "DimEditLine has a selection after two idle frames (sel=%s)" % selected)

	_status_log.clear()
	ix._apply_dim_edit("45")
	check(_status_has("Dimension updated"), "submitting 45 emits Dimension updated (log: %s)" % str(_status_log))

	wd = _entity_dir(sm, wall_id)
	var wall_h := _folded_to_horizontal_deg(wd)
	check(absf(wall_h - 45.0) <= 0.05, "wall-to-horizontal is 45° ± 0.05° (got %.4f)" % wall_h)

	fd = _entity_dir(sm, floor_id)
	var abs_dot_after := 1.0
	if wd.length_squared() > 1e-12 and fd.length_squared() > 1e-12:
		abs_dot_after = absf(wd.normalized().dot(fd.normalized()))
	check(abs_dot_after <= 0.0009, "after 45°, wall-to-floor included angle is 90° ± 0.05° (abs(dot)=%.6f)" % abs_dot_after)

	var dist_i := _dim_index(sm, "distance")
	var dist_lp: Variant = null
	if dist_i >= 0:
		dist_lp = sm.dimensions[dist_i].get("label_pos", null)
	check(dist_i >= 0 and dist_lp != null and sm.dimension_hit(dist_lp) >= 0,
			"linear width label_pos returns a non-negative dimension_hit (i=%d hit=%d)" % [
				dist_i, sm.dimension_hit(dist_lp) if dist_lp != null else -1])

	_status_log.clear()
	var width_txt := "1"
	if dist_i >= 0:
		width_txt = String.num(sm._dimension_display_value(sm.dimensions[dist_i]), 3)
		ix._show_dim_edit(dist_i)
	ix._apply_dim_edit(width_txt)
	check(_status_has("Dimension updated"),
			"submitting the width's current value still returns Dimension updated (log: %s)" % str(_status_log))
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
	main.interaction.status.connect(_on_status)
	return main


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(main) -> void:
	main.queue_free()
	await process_frame
	await process_frame
