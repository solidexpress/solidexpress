## The kernel-built candlestick the rung-6 suites share.
## Boot, PART millimetres, revolve/path/ellipse builders, and WalkUI06 click builders.
class_name CandlestickFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")
const _FilmActorBoot = preload("res://tests/lib/film_actor.gd")

## Locked rim from WalkUI06 / the rung-6 plan (checker clips y ≥ 0 at x = 108.998).
const R60_TAN := Vector2(97.861, 20.517)
const R12_BULGE := Vector2(111.999, 8.125)
const R12_CLIP := Vector2(108.998, 0.0)

static var _part: Dictionary = {}


static func part() -> Dictionary:
	if not _part.is_empty():
		return _part
	var result := SxChecker.run("rung06", ["params"])
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) == TYPE_DICTIONARY:
		_part = parsed
	return _part


static func mm(key: String) -> float:
	var table: Variant = part().get("PART", {})
	if typeof(table) != TYPE_DICTIONARY:
		return 0.0
	return float(table.get(key, 0.0))


static func boot(tree: SceneTree, viewport: Vector2i, on_status: Callable = Callable(),
		sources: Array = []) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = tree
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, viewport)
	if on_status.is_valid():
		for source in sources:
			var node: Node = main.get(str(source))
			if node != null and node.has_signal("status") and not node.status.is_connected(on_status):
				node.status.connect(on_status)
	return ctx


static func find_auto(node: Node, id: String) -> Node:
	if node == null:
		return null
	if str(node.get_meta("sx_auto", "")) == id:
		return node
	for c in node.get_children():
		var hit := find_auto(c, id)
		if hit != null:
			return hit
	return null


static func click_named(host: Object, ctx: FilmContext, node_name: String, desc: String) -> void:
	if node_name == "SweepBoss":
		ctx.view.clear_selection()
		ctx.main._update_left_rail()
		await ctx.tree.process_frame
	var n: Node = ctx.main.find_child(node_name, true, false)
	host.check(n is BaseButton, "%s is a button" % node_name)
	if n is BaseButton:
		await FilmUI.click_control(ctx, n as BaseButton, FilmUICues.alert("Click", desc))
	await ctx.tree.process_frame


static func pick_sketch(host: Object, ctx: FilmContext, fid: String, desc: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await ctx.tree.process_frame
	var row: Control = tl._rows.get(fid)
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str(child.text) != "":
				btn = child
				break
	host.check(btn != null, "timeline row for %s" % desc)
	if btn != null:
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Click", desc))
	await ctx.tree.process_frame


static func last_arc(sm: SketchMode) -> String:
	var last := ""
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "arc":
			last = str(id)
	return last


static func line_count(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


static func draw_line(ctx: FilmContext, a: Vector2, b: Vector2, span: float = 0.0) -> void:
	await FilmSteps.press_rail(ctx, "Line")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.click_uv(ctx, a, "Line start", span)
	await FilmSteps.click_uv(ctx, b, "Line end", span)


## CCW arc from `start` to `end` that contains `through`. Endpoints are then
## written back so they match the joining lines (float32 angle round-trip
## otherwise opens the loop past profile_face's 1e-6 join).
static func _arc_through(sk, c: Vector2, r: float, start: Vector2, end: Vector2,
		through: Vector2) -> String:
	var sa := (start - c).angle()
	var ea := (end - c).angle()
	var ta := (through - c).angle()
	var ea1 := ea
	while ea1 <= sa + 1.0e-9:
		ea1 += TAU
	var t := ta
	while t < sa - 1.0e-9:
		t += TAU
	var eid: String
	if t <= ea1 + 1.0e-9:
		eid = str(sk.add_arc(c.x, c.y, r, sa, ea1))
	else:
		var sa2 := ea
		var ea2 := sa
		while ea2 <= sa2 + 1.0e-9:
			ea2 += TAU
		eid = str(sk.add_arc(c.x, c.y, r, sa2, ea2))
	if eid == "":
		return ""
	var info: Dictionary = sk.entity_info(eid)
	var ast: Vector2 = info.get("start", start)
	if ast.distance_to(start) <= ast.distance_to(end):
		sk.set_entity_geometry(eid, {"start": start, "end": end})
	else:
		sk.set_entity_geometry(eid, {"start": end, "end": start})
	return eid


static func add_revolve_profile(sk) -> void:
	var h := mm("H")
	var top_r := mm("TOP_R")
	var r10 := mm("R10")
	var upper := mm("UPPER")
	var r20 := mm("R20")
	var lower := mm("LOWER")
	var r60 := mm("R60")
	var base_r := mm("BASE_R")
	var stem_x := top_r + r10
	var r10_y := h - r10
	var r20_top := r10_y - upper
	var r20_c := r20_top - r20
	var r20_bot := r20_c - r20
	var r60_y := r20_bot - lower
	sk.add_line(0.0, 0.0, 0.0, h)
	sk.add_line(0.0, h, top_r, h)
	_arc_through(sk, Vector2(top_r, r10_y), r10, Vector2(stem_x, r10_y), Vector2(top_r, h),
			Vector2(top_r + r10 * 0.7, h - r10 * 0.3))
	sk.add_line(stem_x, r10_y, stem_x, r20_top)
	_arc_through(sk, Vector2(stem_x, r20_c), r20, Vector2(stem_x, r20_bot), Vector2(stem_x, r20_top),
			Vector2(stem_x + r20, r20_c))
	sk.add_line(stem_x, r20_bot, stem_x, r60_y)
	var c60 := Vector2(base_r, r60_y)
	var c12 := Vector2(99.499, 8.125)
	var d := c60.distance_to(c12)
	var tanp: Vector2 = c60 + (c12 - c60) * (r60 / d)
	var r12 := c12.distance_to(tanp)
	var clip := Vector2(c12.x + sqrt(maxf(0.0, r12 * r12 - c12.y * c12.y)), 0.0)
	_arc_through(sk, c60, r60, Vector2(stem_x, r60_y), tanp, Vector2(base_r, 20.0))
	_arc_through(sk, c12, r12, tanp, clip, Vector2(c12.x + r12, c12.y))
	sk.add_line(clip.x, clip.y, 0.0, 0.0)


static func add_path(sk) -> void:
	var y := mm("PATH_Y")
	var p60 := mm("PATH_60")
	var r150 := mm("PATH_R150")
	sk.add_line(0.0, y, p60, y)
	var c150 := Vector2(p60, y + r150)
	var c20 := Vector2(167.113, 86.333)
	var dir: Vector2 = (c20 - c150).normalized()
	var tanp: Vector2 = c150 + dir * r150
	var r20 := c20.distance_to(tanp)
	var hook_end := Vector2(150.634, 75.0)
	_arc_through(sk, c150, r150, Vector2(p60, y), tanp, Vector2(150.0, 40.0))
	_arc_through(sk, c20, r20, tanp, hook_end, Vector2(c20.x + r20, c20.y))


static func add_ellipse(sk) -> String:
	return str(sk.add_ellipse(0.0, mm("PATH_Y"), mm("ELLIPSE_MAJ") * 0.5, mm("ELLIPSE_MIN") * 0.5, 0.0))


## WalkUI06.sketch_on_datum: clear faces, then Sketch, then the named origin plane.
static func click_datum(ctx: FilmContext, plane_name: String, view_id: String) -> void:
	await _clear_selection(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
		if FilmUI.fail_count > 0:
			return
	ctx.main.camera.apply_standard_view_id(view_id)
	await ctx.tree.process_frame
	var pads = ctx.view.sketch_pads if ctx.view != null else null
	var pads_was_visible := false
	if pads != null:
		pads_was_visible = pads.visible
		pads.visible = false
	var sketch_btn: BaseButton = FilmUI.find_palette_sketch_button(ctx.main) as BaseButton
	if not await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch()):
		if pads != null:
			pads.visible = pads_was_visible
		return
	await ctx.tree.process_frame
	var pt: Vector3 = OriginPlanes.pick_point(plane_name)
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.require_on_screen(ctx, screen, plane_name):
		if pads != null:
			pads.visible = pads_was_visible
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(plane_name))
	await FilmUI.wait_frames(ctx.tree, 4)
	if pads != null:
		pads.visible = pads_was_visible


## WalkUI06.temp_axes_on: click Temporary Axes only when status says they are off.
static func click_temp_axes(ctx: FilmContext) -> void:
	var status := ""
	if ctx.main.status_label != null:
		status = str(ctx.main.status_label.text)
	if "Temporary Axes off" not in status:
		return
	var btn := find_auto(ctx.main, "menu:TemporaryAxes") as BaseButton
	if btn == null or not btn.is_visible_in_tree():
		btn = ctx.main.find_child("TemporaryAxes", true, false) as BaseButton
	if btn == null or not btn.is_visible_in_tree():
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Temporary Axes", "Temporary Axes"))
	await ctx.tree.process_frame


## Walk profile: 20 / 220 / 90, Tangent R10, 3-point R20, R60, R12.50 clip to y = 0.
static func draw_profile(ctx: FilmContext) -> void:
	var h := mm("H")
	var top_r := mm("TOP_R")
	var r10 := mm("R10")
	var upper := mm("UPPER")
	var r20 := mm("R20")
	var lower := mm("LOWER")
	var stem_x := top_r + r10
	var r10_y := h - r10
	var r20_top := r10_y - upper
	var r20_c := r20_top - r20
	var r20_bot := r20_c - r20
	var r60_y := r20_bot - lower
	await _frame_uv(ctx, Vector2(40.0, h * 0.5), 360.0)
	await draw_line(ctx, Vector2(0, 0), Vector2(0, h))
	if FilmUI.fail_count > 0:
		return
	await draw_line(ctx, Vector2(0, h), Vector2(top_r, h))
	if FilmUI.fail_count > 0:
		return
	await draw_line(ctx, R12_CLIP, Vector2(0, 0))
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.tangent_arc(ctx, Vector2(top_r, h), Vector2(stem_x, r10_y), 0.0)
	if FilmUI.fail_count > 0:
		return
	await draw_line(ctx, Vector2(stem_x, r10_y), Vector2(stem_x, r20_top))
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.three_point_arc(ctx, Vector2(stem_x, r20_top), Vector2(stem_x + r20, r20_c),
			Vector2(stem_x, r20_bot), 0.0)
	if FilmUI.fail_count > 0:
		return
	await draw_line(ctx, Vector2(stem_x, r20_bot), Vector2(stem_x, r60_y))
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.tangent_arc(ctx, Vector2(stem_x, r60_y), R60_TAN, 0.0)
	if FilmUI.fail_count > 0:
		return
	await _frame_uv(ctx, R12_BULGE, 80.0)
	await _connecting_rim(ctx, _arc_end_near(ctx, R60_TAN), true)
	if FilmUI.fail_count > 0:
		return
	await _trim_below_ground(ctx)


static func revolve_360(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _frame_uv(ctx, Vector2(0, mm("H") * 0.5), 360.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(0, mm("H") * 0.5), "Revolve axis", 0.0)
	await FilmUI.apply_revolve(ctx, TAU, "new")
	await ctx.after_regen()
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)


## Walk path: 60 at y=10, Tangent R150 to (183.6, 75), 3-point R20 hook.
static func draw_path(ctx: FilmContext) -> void:
	var y := mm("PATH_Y")
	var p60 := mm("PATH_60")
	var hook_start := Vector2(183.6, 75.0)
	var hook_bulge := Vector2(187.11, 86.33)
	var hook_end := Vector2(150.63, 75.0)
	await _frame_uv(ctx, Vector2(90.0, 50.0), 360.0)
	await draw_line(ctx, Vector2(0, y), Vector2(p60, y))
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.tangent_arc(ctx, Vector2(p60, y), hook_start, 0.0)
	if FilmUI.fail_count > 0:
		return
	var outer := _arc_end_near(ctx, hook_start)
	await FilmSteps.three_point_arc(ctx, outer, hook_bulge, hook_end, 0.0)


## Walk A25: ellipse centre (0, 10), major 17.5, minor to (0, 15).
static func draw_section_ellipse(ctx: FilmContext) -> void:
	var y := mm("PATH_Y")
	var maj := mm("ELLIPSE_MAJ") * 0.5
	var minr := mm("ELLIPSE_MIN") * 0.5
	await _frame_uv(ctx, Vector2(0, y), 80.0)
	await FilmSteps.ellipse3(ctx, Vector2(0, y), Vector2(maj, y), Vector2(0, y + minr))


## WalkUI06.pick_top_disc: +Y disc at H, area ~π×20², then Sketch on that face.
static func cut_top_disc(ctx: FilmContext) -> void:
	await _clear_selection(ctx)
	var body := FilmSteps.only_body(ctx)
	if body == "":
		FilmUI._fail("cut needs one body")
		return
	var face := _top_disc_face(ctx, body)
	if face == "":
		FilmUI._fail("no Ø30 top disc")
		return
	await FilmActor.of(ctx).view_key(KEY_3)
	await FilmActor.of(ctx).zoom_to(Vector3(10.0, mm("H"), 0.0), 80.0, "Frame top disc")
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	if FilmUI.fail_count > 0:
		return
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("top-disc sketch did not start")
		return
	await FilmSteps.press_rail(ctx, "Circle")
	if FilmUI.fail_count > 0:
		return
	var rad := mm("CUT_D") * 0.5
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø30 centre", 0.0)
	await FilmSteps.click_uv(ctx, Vector2(rad, 0), "Ø30 rim", 0.0)
	await FilmSteps.draft_cut(ctx, mm("CUT_H"), mm("CUT_DRAFT_DEG"))


static func _top_disc_face(ctx: FilmContext, body: String) -> String:
	var h := mm("H")
	var want_area := PI * mm("TOP_R") * mm("TOP_R")
	var best := ""
	var best_err := 1.0e9
	for face in ctx.view.faces_matching(body, Vector3(0, 1, 0), 0.85):
		var id := str(face.get("id", ""))
		var c: Vector3 = face.get("centre", Vector3.ZERO)
		if absf(c.y - h) > 6.0:
			continue
		var area := float(ctx.view.doc.measure_face_area(id))
		if area < 400.0 or area > 2500.0:
			continue
		var err := absf(area - want_area)
		if err < best_err:
			best_err = err
			best = id
	return best


static func _arc_end_near(ctx: FilmContext, hint: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		return hint
	var eid := last_arc(sm)
	if eid == "":
		return hint
	var info: Dictionary = sm.sketch.entity_info(eid)
	var a: Vector2 = info.get("start", hint)
	var b: Vector2 = info.get("end", hint)
	if a.distance_to(hint) <= b.distance_to(hint):
		return a
	return b


static func _connecting_rim(ctx: FilmContext, start: Vector2, snap_end: bool = true) -> void:
	await FilmSteps.press_rail(ctx, "Arc")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.pick_variant(ctx, "Three Point")
	if FilmUI.fail_count > 0:
		return
	await _set_snap(ctx, true)
	await FilmSteps.click_uv(ctx, start, "R60 end", 0.0)
	await _set_snap(ctx, false)
	await FilmSteps.click_uv(ctx, R12_BULGE, "R12 bulge", 0.0)
	await _set_snap(ctx, snap_end)
	await FilmSteps.click_uv(ctx, R12_CLIP, "R12 clip", 0.0)
	await _set_snap(ctx, false)
	await FilmUI.wait_frames(ctx.tree, 1)


static func _trim_below_ground(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		return
	var eid := last_arc(sm)
	if eid == "":
		return
	var info: Dictionary = sm.sketch.entity_info(eid)
	var c: Vector2 = info.get("center", Vector2.ZERO)
	var r := float(info.get("radius", 0.0))
	var sa := float(info.get("start_angle", 0.0))
	var ea := float(info.get("end_angle", 0.0))
	var span := ea - sa
	while span <= 1.0e-9:
		span += TAU
	var mid: Vector2 = c + Vector2.from_angle(sa + span * 0.5) * r
	if mid.y >= -0.2:
		return
	await FilmSteps.press_rail(ctx, "Trim")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.click_uv(ctx, mid, "Trim toe", 0.0)


static func _frame_uv(ctx: FilmContext, uv: Vector2, span: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null:
		return
	await FilmActor.of(ctx).zoom_to(sm.to_model(uv), span, "Frame sketch")


static func _clear_selection(ctx: FilmContext) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	for _i in 3:
		await SxInput.push_key(vp, KEY_ESCAPE)
		await ctx.tree.process_frame
	if ctx.view != null:
		ctx.view.clear_selection()
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
	await ctx.tree.process_frame


static func _set_snap(ctx: FilmContext, on: bool) -> void:
	var snap := find_auto(ctx.main, "rail:Snap") as BaseButton
	if snap == null or not snap.is_visible_in_tree():
		snap = ctx.main.find_child("SnapToggle", true, false) as BaseButton
	if snap == null or not snap.is_visible_in_tree():
		return
	if snap.button_pressed == on:
		return
	await FilmUI.click_control(ctx, snap, FilmUICues.alert("Snap", "Snap %s" % ("on" if on else "off")))
	await ctx.tree.process_frame
