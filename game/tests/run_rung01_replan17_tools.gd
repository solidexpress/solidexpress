# Rung 1 replan 17 WP2 — Jaw preview shape, polygon pointer on a vertex, DOF chip after undo.
# Presses, motion and keys under test go through Viewport.push_input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan17_tools.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const EMPTY_CHIP := "—"
const JAW_AXIS_DEG := 37.0
const JAW_HALF_LEN := 24.0
const PREVIEW_MIN_HALF_W := 1.5

var _log: Array[String] = []


func _init() -> void:
	print("rung01 replan17 WP2 tools")
	FilmUI.reset_fail_count()
	await _run()
	finish()


func _on_status(msg: String) -> void:
	_log.append(str(msg))


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _fresh_sketch(ctx: FilmContext) -> SketchMode:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		sm.cancel()
		await process_frame
		await process_frame
	await FilmUI.enter_sketch(ctx)
	sm = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch is active")
	sm.set_snap(false)
	await _zoom_uv(ctx, Vector2.ZERO, 160.0)
	return sm


func _uv_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	return FilmUI.model_to_screen(ctx, sm.to_model(uv))


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		check(false, "click target exists")
		return
	await _x11_click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center())


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s on screen at %s" % [desc, str(screen)])
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var screen := _uv_screen(ctx, uv)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	await process_frame
	await process_frame


func _push_key(vp: Viewport, keycode: Key, ctrl: bool, shift: bool, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.unicode = unicode
		ev.pressed = pressed
		ev.echo = false
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		vp.push_input(ev)
		await process_frame


func _type_digits(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_0 + (ch - 48)
		await _push_key(vp, code as Key, false, false, ch)


func _drop_field_focus(ctx: FilmContext) -> void:
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner is SpinBox:
		await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.SELECT)
		await process_frame


## A centre click arms the dim blank at its minimum (0.01) and keeps it focused,
## so a canvas press reads that number and commits it instead of the pointer.
## Ctrl+A then Backspace clears the focused line. An empty blank is not a float,
## so the next press takes SketchMode.click() and the pointer-to-AF mapping.
func _clear_focused_dim_blank(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var owner: Control = vp.gui_get_focus_owner()
	check(owner is LineEdit, "P1 dim blank is focused before the vertex click")
	await _push_key(vp, KEY_A, true, false)
	await _push_key(vp, KEY_BACKSPACE, false, false)
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float, bias: Vector2 = Vector2.ZERO) -> void:
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
	var pivot := sm.to_model(uv + bias) if sm != null else Vector3.ZERO
	cam.pivot = ms.to_global(pivot) if ms != null else pivot
	cam.distance = size_mm / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame


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
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) > 0.05:
			segs.append([a, b])
		i += 2
	return segs


func _seg_axis_aligned(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= 0.4 or absf(a.y - b.y) <= 0.4


func _seg_centre(segs: Array) -> Vector2:
	var acc := Vector2.ZERO
	if segs.is_empty():
		return acc
	for seg in segs:
		acc += seg[0]
	return acc / float(segs.size())


func _entity_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return 0
	return sm.sketch.entity_ids().size()


func _format_dofs(sm: SketchMode) -> String:
	if sm.last_conflicting.size() > 0 or sm.last_solve_status == "failed":
		return "!"
	if sm.last_dofs == 0:
		return "OK"
	return "%d" % sm.last_dofs


func _status_label(ctx: FilmContext) -> String:
	return str(ctx.main.status_label.text)


func _arm_jaw(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null and jaw.is_visible_in_tree(), "Jaw is on the sketch rail")
	await _x11_click(jaw)
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
			"Jaw arms Center Three Point (tool %d variant %s)" % [int(sm.tool), sm.tool_variant])


func _test_jaw(ctx: FilmContext) -> void:
	print("- J1 J2 Jaw preview is the jaw shape")
	var sm := await _fresh_sketch(ctx)
	await _arm_jaw(ctx)
	var dir := Vector2(cos(deg_to_rad(JAW_AXIS_DEG)), sin(deg_to_rad(JAW_AXIS_DEG)))
	var nrm := Vector2(-dir.y, dir.x)
	var ctr := Vector2(8.0, -4.0)
	var tip := ctr + dir * JAW_HALF_LEN
	await _zoom_uv(ctx, ctr, 120.0)
	await _click_uv(ctx, ctr, "Jaw click 1")
	check(sm._tool_points.size() == 1, "J1 click 1 stored the centre (n=%d)" % sm._tool_points.size())
	await _motion_uv(ctx, tip)
	var segs := _preview_segs(sm)
	check(segs.size() == 4, "J1 preview has exactly 4 segments (got %d)" % segs.size())
	var aligned := 0
	for seg in segs:
		if _seg_axis_aligned(seg[0], seg[1]):
			aligned += 1
	check(aligned == 0, "J1 no segment is axis-aligned on a 37° axis (aligned %d)" % aligned)
	var mid := _seg_centre(segs)
	check(mid.distance_to(ctr) <= 0.05,
			"J1 rectangle centre is the click-1 point (got %s want %s)" % [str(mid), str(ctr)])

	var before := _entity_count(sm)
	await _click_uv(ctx, tip, "Jaw click 2")
	check(sm._tool_points.size() == 2, "J2 click 2 kept centre and long side (n=%d)" % sm._tool_points.size())
	await _motion_uv(ctx, tip)
	segs = _preview_segs(sm)
	check(segs.size() == 4, "J2 pointer on the axis still draws 4 segments (got %d)" % segs.size())
	var parallel := 0
	var across := 0
	var across_len := -1.0
	for seg in segs:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var sdir := (b - a).normalized()
		var length := a.distance_to(b)
		if absf(sdir.dot(dir)) > 0.97:
			parallel += 1
		elif absf(sdir.dot(nrm)) > 0.97:
			across += 1
			across_len = length
	check(parallel == 2 and across == 2,
			"J2 two edges parallel to the axis and two across (parallel %d across %d)" % [parallel, across])
	check(absf(across_len - 2.0 * PREVIEW_MIN_HALF_W) <= 0.05,
			"J2 across edge is 2 * min half-width (got %.4f want %.4f)" % [across_len, 2.0 * PREVIEW_MIN_HALF_W])
	_log.clear()
	await _click_uv(ctx, tip, "Jaw repeat click 2")
	var refused := _last()
	if refused == "":
		refused = _status_label(ctx)
	check(refused == SketchMode.JAW_ZERO_WIDTH,
			"J2 repeat click 2 prints zero width (got `%s`)" % refused)
	check(_entity_count(sm) == before, "J2 repeat click 2 leaves the entity count unchanged")
	var click3 := ctr + nrm * 8.0
	await _click_uv(ctx, click3, "Jaw click 3")
	var committed := _last()
	if not committed.begins_with("Jaw committed — width"):
		committed = _status_label(ctx)
	check(committed.begins_with("Jaw committed — width"),
			"J2 click 3 commits (got `%s`)" % committed)


func _af_text(dist: float) -> String:
	return "%.4f" % (sqrt(3.0) * dist)


func _test_polygon(ctx: FilmContext) -> void:
	print("- P1 P2 polygon pointer sits on a vertex; typed AF 20 unchanged")
	var sm := await _fresh_sketch(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool == SketchMode.Tool.POLYGON and sm.tool_variant == "across_flats",
			"Polygon across-flats is armed (variant %s)" % sm.tool_variant)
	var centre := Vector2.ZERO
	# Bearing 110° at 40 mm is toward the top of the screen. Bias the pivot
	# up so that click stays on the canvas, below the top chrome.
	await _zoom_uv(ctx, centre, 180.0, Vector2(0.0, 36.0))
	await _click_uv(ctx, centre, "Polygon centre")
	check(sm._tool_points.size() == 1, "P1 centre click is down (n=%d)" % sm._tool_points.size())
	var dists: Array[float] = [20.0, 30.0, 40.0]
	var bearings: Array[float] = [20.0, 70.0, 110.0]
	var live_af := ""
	for i in dists.size():
		var dist := dists[i]
		var deg := bearings[i]
		var aim := centre + Vector2.from_angle(deg_to_rad(deg)) * dist
		await _motion_uv(ctx, aim)
		var hover: Vector2 = sm._hover
		var got := centre.distance_to(hover)
		check(absf(got - dist) <= 0.5,
				"P1 pointer distance is %.0f mm (hover %.4f)" % [dist, got])
		var verts := sm.polygon_preview_vertices()
		check(verts.size() == 6, "P1 preview has 6 vertices at %.0f mm / %.0f° (got %d)" % [dist, deg, verts.size()])
		var on_circle := true
		var at_zero := false
		var radius := got
		for v in verts:
			if absf(v.distance_to(centre) - radius) > 0.05:
				on_circle = false
			if v.distance_to(centre + Vector2(radius, 0.0)) <= 0.05:
				at_zero = true
		check(on_circle, "P1 every preview vertex lies on |pointer-centre| at %.0f° (r=%.4f)" % [deg, radius])
		check(at_zero, "P1 one vertex is at bearing 0 at %.0f°" % deg)
		var af := _af_text(got)
		var want := "Polygon AF %s — flats horizontal — click to place (or type the size)" % af
		var line := _status_label(ctx)
		check(line == want, "P1 hover status at %.0f mm (got `%s`)" % [dist, line])
		check(absf(sm.preview_distance() - sqrt(3.0) * got) <= 0.02,
				"P1 preview distance is the across-flats size (got %.4f)" % sm.preview_distance())
		live_af = af
	var before := _entity_count(sm)
	var aim := centre + Vector2.from_angle(deg_to_rad(110.0)) * 40.0
	await _clear_focused_dim_blank(ctx)
	await _motion_uv(ctx, aim)
	live_af = _af_text(centre.distance_to(sm._hover))
	await _click_uv(ctx, aim, "Polygon vertex click")
	check(_entity_count(sm) > before, "P1 second click commits the hex")
	var commit := sm.last_commit_text()
	check(commit == "Polygon AF %s — flats horizontal" % live_af,
			"P1 commit status matches the hover AF (got `%s`)" % commit)
	var flat_horiz := 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(str(cid))
		if str(info.get("type", "")) != "horizontal":
			continue
		for ref in info.get("refs", []):
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			var eid := str(ref.get("entity", ""))
			var einfo: Dictionary = sm.sketch.entity_info(eid)
			if str(einfo.get("type", "")) != "line":
				continue
			var ed: Vector2 = einfo["end"] - einfo["start"]
			if absf(ed.y) <= 1e-3 and absf(ed.x) > 1e-3:
				flat_horiz += 1
				break
	check(flat_horiz == 2, "P1 horizontal constraints sit on the two flat edges (got %d)" % flat_horiz)

	print("- P2 typed 20")
	var skip := {}
	for sid in sm.sketch.entity_ids():
		skip[str(sid)] = true
	var c2 := Vector2(70.0, 6.0)
	await _zoom_uv(ctx, c2, 80.0)
	await _click_uv(ctx, c2, "Typed polygon centre")
	await _motion_uv(ctx, c2 + Vector2(12.0, 9.0))
	var vp: Viewport = ctx.main.get_viewport()
	await _type_digits(vp, "20")
	await _push_key(vp, KEY_ENTER, false, false)
	await process_frame
	var typed := sm.last_commit_text()
	if typed == "":
		typed = _status_label(ctx)
	check(typed == "Polygon AF 20.0000 — flats horizontal" or _status_label(ctx) == "Polygon AF 20.0000 — flats horizontal",
			"P2 typed 20 commits Polygon AF 20.0000 — flats horizontal (got `%s` / label `%s`)" % [typed, _status_label(ctx)])
	var min_y := INF
	var max_y := -INF
	var n_lines := 0
	for id in sm.sketch.entity_ids():
		if skip.has(str(id)) or sm.sketch.is_construction(id):
			continue
		var einfo: Dictionary = sm.sketch.entity_info(id)
		if str(einfo.get("type", "")) != "line":
			continue
		n_lines += 1
		for key in ["start", "end"]:
			var p: Vector2 = einfo[key]
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
	var af_meas := max_y - min_y
	check(n_lines == 6 and absf(af_meas - 20.0) <= 0.01,
			"P2 hex across flats is 20.000 ± 0.01 (got %.4f, lines %d)" % [af_meas, n_lines])


func _undo_until_empty(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var saw := false
	for _i in 8:
		await _drop_field_focus(ctx)
		_log.clear()
		await _push_key(vp, KEY_Z, true, false)
		var line := _status_label(ctx)
		if line == "":
			line = _last()
		if line == "Nothing to undo":
			saw = true
			break
	check(saw, "Ctrl+Z reaches Nothing to undo (label `%s`)" % _status_label(ctx))


func _test_dof(ctx: FilmContext) -> void:
	print("- D1 DOF chip after undo")
	var sm := await _fresh_sketch(ctx)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _zoom_uv(ctx, Vector2(20.0, 10.0), 120.0)
	await _click_uv(ctx, Vector2(4.0, 6.0), "Line start")
	await _click_uv(ctx, Vector2(36.0, 18.0), "Line end")
	check(_entity_count(sm) > 0, "D1 line click added an entity")
	await _undo_until_empty(ctx)
	check(ctx.main.dof_label.text == EMPTY_CHIP,
			"D1 empty sketch chip is — (got `%s`)" % ctx.main.dof_label.text)
	await _drop_field_focus(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_Z, true, true)
	check(ctx.main.dof_label.text == _format_dofs(sm),
			"D1 redo chip matches last_dofs (chip `%s` dofs %d status `%s`)" % [
				ctx.main.dof_label.text, sm.last_dofs, sm.last_solve_status])

	sm = await _fresh_sketch(ctx)
	await _arm_jaw(ctx)
	var dir := Vector2(cos(deg_to_rad(JAW_AXIS_DEG)), sin(deg_to_rad(JAW_AXIS_DEG)))
	var nrm := Vector2(-dir.y, dir.x)
	var ctr := Vector2(6.0, 4.0)
	await _zoom_uv(ctx, ctr, 120.0)
	await _click_uv(ctx, ctr, "DOF jaw centre")
	await _click_uv(ctx, ctr + dir * 22.0, "DOF jaw long side")
	await _click_uv(ctx, ctr + nrm * 7.0, "DOF jaw width")
	check(_last().begins_with("Jaw committed — width") or _status_label(ctx).begins_with("Jaw committed — width"),
			"D1 jaw committed before undo (got `%s`)" % _status_label(ctx))
	await _drop_field_focus(ctx)
	var before := str(ctx.main.dof_label.text)
	_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_Z, true, false)
	var undo_line := _status_label(ctx)
	check(undo_line == "Undo: Jaw", "D1 Undo: Jaw (got `%s`)" % undo_line)
	check(ctx.main.dof_label.text == EMPTY_CHIP,
			"D1 Undo: Jaw chip is — (got `%s`)" % ctx.main.dof_label.text)
	await _push_key(ctx.main.get_viewport(), KEY_Z, true, true)
	var redo_line := _status_label(ctx)
	check(redo_line == "Redo: Jaw", "D1 Redo: Jaw (got `%s`)" % redo_line)
	check(ctx.main.dof_label.text == before,
			"D1 Redo: Jaw restores the chip (before `%s` now `%s`)" % [before, ctx.main.dof_label.text])
	check(ctx.main.dof_label.text == _format_dofs(sm),
			"D1 redo chip matches last_dofs (chip `%s` formatted `%s`)" % [
				ctx.main.dof_label.text, _format_dofs(sm)])


func _run() -> void:
	var ctx := await _boot()
	await _test_jaw(ctx)
	await _test_polygon(ctx)
	await _test_dof(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	ctx.main.queue_free()
	await process_frame
	await process_frame
