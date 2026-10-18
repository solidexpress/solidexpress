## The kernel-built candlestick the rung-6 suites share.
## Boot, PART millimetres, revolve/path/ellipse builders. Each suite keeps its checks.
class_name CandlestickFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

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


static func draw_line(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmSteps.click_uv(ctx, a, "Line start", 280.0)
	await FilmSteps.click_uv(ctx, b, "Line end", 280.0)


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


static func click_datum(ctx: FilmContext, plane_name: String, view_id: String) -> void:
	ctx.main.camera.apply_standard_view_id(view_id)
	await ctx.tree.process_frame
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	if not await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch()):
		return
	await ctx.tree.process_frame
	var pt: Vector3 = OriginPlanes.pick_point(plane_name)
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.require_on_screen(ctx, screen, plane_name):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(plane_name))
	await FilmUI.wait_frames(ctx.tree, 4)


static func click_temp_axes(ctx: FilmContext) -> void:
	var btn := find_auto(ctx.main, "menu:TemporaryAxes") as BaseButton
	if btn == null or not btn.is_visible_in_tree():
		btn = ctx.main.find_child("TemporaryAxes", true, false) as BaseButton
	if btn == null or not btn.is_visible_in_tree():
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Temporary Axes", "Temporary Axes"))
	await ctx.tree.process_frame


static func draw_profile(ctx: FilmContext) -> void:
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
	var c60 := Vector2(base_r, r60_y)
	var c12 := Vector2(99.499, 8.125)
	var d := c60.distance_to(c12)
	var tanp: Vector2 = c60 + (c12 - c60) * (r60 / d)
	var r12 := c12.distance_to(tanp)
	var clip := Vector2(c12.x + sqrt(maxf(0.0, r12 * r12 - c12.y * c12.y)), 0.0)
	var span := 320.0
	await draw_line(ctx, Vector2(0, 0), Vector2(0, h))
	await draw_line(ctx, Vector2(0, h), Vector2(top_r, h))
	await FilmSteps.tangent_arc(ctx, Vector2(top_r, h), Vector2(stem_x, r10_y), span)
	await draw_line(ctx, Vector2(stem_x, r10_y), Vector2(stem_x, r20_top))
	await FilmSteps.three_point_arc(ctx, Vector2(stem_x, r20_top), Vector2(stem_x + r20, r20_c),
			Vector2(stem_x, r20_bot), span)
	await draw_line(ctx, Vector2(stem_x, r20_bot), Vector2(stem_x, r60_y))
	await FilmSteps.three_point_arc(ctx, Vector2(stem_x, r60_y), Vector2(base_r, 20.0), tanp, span)
	await FilmSteps.three_point_arc(ctx, tanp, Vector2(c12.x + r12, c12.y), clip, span)
	await draw_line(ctx, clip, Vector2(0, 0))


static func revolve_360(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(0, mm("H") * 0.5), "Revolve axis", 320.0)
	await FilmUI.apply_revolve(ctx, TAU, "new")
	await ctx.after_regen()
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)


static func draw_path(ctx: FilmContext) -> void:
	var y := mm("PATH_Y")
	var p60 := mm("PATH_60")
	var r150 := mm("PATH_R150")
	var c150 := Vector2(p60, y + r150)
	var c20 := Vector2(167.113, 86.333)
	var dir: Vector2 = (c20 - c150).normalized()
	var tanp: Vector2 = c150 + dir * r150
	var r20 := c20.distance_to(tanp)
	var hook_end := Vector2(150.634, 75.0)
	var span := 280.0
	await draw_line(ctx, Vector2(0, y), Vector2(p60, y))
	await FilmSteps.tangent_arc(ctx, Vector2(p60, y), tanp, span)
	await FilmSteps.three_point_arc(ctx, tanp, Vector2(c20.x + r20, c20.y), hook_end, span)


static func draw_section_ellipse(ctx: FilmContext) -> void:
	var y := mm("PATH_Y")
	var maj := mm("ELLIPSE_MAJ") * 0.5
	var minr := mm("ELLIPSE_MIN") * 0.5
	await FilmSteps.ellipse3(ctx, Vector2(0, y), Vector2(maj, y), Vector2(0, y + minr))


static func cut_top_disc(ctx: FilmContext) -> void:
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 1, 0), KEY_3, mm("H"))
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.press_rail(ctx, "Circle")
	if FilmUI.fail_count > 0:
		return
	var rad := mm("CUT_D") * 0.5
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "Ø30 centre", 80.0)
	await FilmSteps.click_uv(ctx, Vector2(rad, 0), "Ø30 rim", 80.0)
	await FilmSteps.draft_cut(ctx, mm("CUT_H"), mm("CUT_DRAFT_DEG"))
