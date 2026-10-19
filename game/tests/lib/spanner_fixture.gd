## Click-built combination spanner (rung 7). PART millimetres from the checker.
class_name SpannerFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")
const _FilmActorBoot = preload("res://tests/lib/film_actor.gd")

const SPAN_HEAD := 90.0
const SPAN_RING := 80.0
const SPAN_HANDLE := 160.0
## Ellipse–handle contacts (walk handle_xy). Not a second PART table.
const HANDLE_OPEN_X_HI := 22.944
const HANDLE_OPEN_X_LO := 23.929
const TRIM_OPEN_LOCAL := Vector2(-24.73, 4.0)

static var _part: Dictionary = {}


static func part() -> Dictionary:
	if not _part.is_empty():
		return _part
	var result := SxChecker.run("rung07", ["params"])
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) == TYPE_DICTIONARY:
		_part = parsed
	return _part


static func mm(key: String) -> float:
	var table: Variant = part().get("PART", {})
	if typeof(table) != TYPE_DICTIONARY:
		return 0.0
	return float(table.get(key, 0.0))


static func deg() -> float:
	return mm("ANGLE_DEG")


static func world(xp: float, yp: float) -> Vector2:
	var a := deg_to_rad(deg())
	return Vector2(xp * cos(a) - yp * sin(a), xp * sin(a) + yp * cos(a))


static func x_jaw() -> float:
	var b := mm("ELLIPSE_MIN") * 0.5
	var a := mm("ELLIPSE_MAJ") * 0.5
	var off := mm("JAW_OFF")
	return -b * sqrt(1.0 - (off / a) * (off / a))


static func boot(tree: SceneTree, viewport: Vector2i) -> FilmContext:
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
	return ctx


static func click(ctx: FilmContext, uv: Vector2, desc: String, span: float = 0.0) -> void:
	await FilmSteps.click_uv(ctx, uv, desc, span)


static func line(ctx: FilmContext, a: Vector2, b: Vector2, desc: String, span: float = 0.0) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click(ctx, a, "%s start" % desc, span)
	await click(ctx, b, "%s end" % desc, span)
	await FilmUI.end_line_chain(ctx)


static func count_type(sm: SketchMode, kind: String) -> int:
	if sm == null or sm.sketch == null:
		return 0
	var n := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n


static func shift_click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.sketch_uv_to_screen(ctx, uv)
	if screen == Vector2.ZERO:
		screen = FilmUI.model_to_screen(ctx, sm.to_model(uv))
	if not FilmUI.require_on_screen(ctx, screen, desc):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", desc), false,
			MOUSE_BUTTON_LEFT, true)


static func confirm_mirror(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.MIRROR)
	await click(ctx, uv, "confirm mirror")


static func contour_by_area(sm: SketchMode, want: float, tol: float) -> int:
	if sm == null or sm.sketch == null or not sm.sketch.has_method("contour_outlines"):
		return -1
	var best := -1
	var best_gap := tol + 1.0
	var rows: Array = sm.sketch.contour_outlines()
	for i in rows.size():
		var area := absf(float(rows[i].get("area", 0.0)))
		var gap := absf(area - want)
		if gap < best_gap:
			best_gap = gap
			best = i
	if best_gap > tol:
		return -1
	return best


static func first_sketch(doc: SxDocument) -> String:
	for f in doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			return str(f.get("id", ""))
	return ""


static func only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


static func dump_contours(sm: SketchMode) -> String:
	if sm == null or sm.sketch == null or not sm.sketch.has_method("contour_outlines"):
		return "no outlines"
	var rows: Array = sm.sketch.contour_outlines()
	var bits: PackedStringArray = PackedStringArray()
	for i in rows.size():
		var d: Dictionary = rows[i]
		var area := float(d.get("area", 0.0))
		var mn: Vector2 = d.get("min", Vector2.ZERO)
		var sz: Vector2 = d.get("size", Vector2.ZERO)
		bits.append("#%d area=%.1f min=%s size=%s" % [i, area, str(mn), str(sz)])
	return "n=%d %s" % [rows.size(), " | ".join(bits)]


## 12-point hole: union of two AF hexes, 24-gon star (named Polygon clicks
## leave overlapping wires that split into 12 leftover triangles).
static func add_twelve_point(sm: SketchMode, ctr: Vector2, af: float) -> void:
	if sm == null or sm.sketch == null:
		return
	var outer := af / sqrt(3.0)
	var inner := (af * 0.5) / cos(deg_to_rad(15.0))
	var pts: Array[Vector2] = []
	for k in 24:
		var ang := deg_to_rad(float(k) * 15.0)
		var radius := outer if (k % 2) == 0 else inner
		pts.append(ctr + Vector2(cos(ang), sin(ang)) * radius)
	# Opposite winding to the circle so the star is a hole, not a second pad.
	for i in 24:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 23) % 24]
		sm.sketch.add_line(a.x, a.y, b.x, b.y)


static func face_by_normal(view, body: String, want: Vector3, plane: Variant = null) -> String:
	if view == null or body == "":
		return ""
	var faces: Array = []
	for fid in view.doc.get_face_ids(body):
		var n: Vector3 = view.face_normal(body, str(fid))
		var pick: Vector3 = FacePick.point(view.doc, str(fid))
		faces.append({"id": str(fid), "normal": n, "pick": pick, "centre": pick})
	var hit: Dictionary = FacePick.match_normal(faces, want, plane)
	return str(hit.get("id", ""))


static func z_edges_near(doc: SxDocument, body: String, xy: Vector2, want_len: float,
		tol := 2.5) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if body == "" or not doc.has_method("get_edge_lines"):
		return out
	var lines: Dictionary = doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[pts.size() - 1]
		var chord := a.distance_to(b)
		if absf(chord - want_len) > 0.6:
			continue
		if absf(a.x - b.x) > 0.6 or absf(a.y - b.y) > 0.6:
			continue
		var mid := Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
		if mid.distance_to(xy) <= tol:
			out.append(str(eid))
	return out


static func digits(key: String) -> String:
	var v := mm(key)
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(v)


static func jaw_outer(upper: bool) -> Vector2:
	return world(x_jaw(), mm("JAW_OFF") if upper else -mm("JAW_OFF"))


static func jaw_inner(upper: bool) -> Vector2:
	return world(x_jaw() + mm("JAW_LEN"), mm("JAW_OFF") if upper else -mm("JAW_OFF"))


static func throat() -> Vector2:
	var off := mm("JAW_OFF")
	var r15 := mm("R15")
	var cx := (x_jaw() + mm("JAW_LEN")) - sqrt(r15 * r15 - off * off)
	return world(cx + r15, 0.0)


static func ellipse_major() -> Vector2:
	return world(0.0, mm("ELLIPSE_MAJ") * 0.5)


static func ellipse_minor() -> Vector2:
	return world(mm("ELLIPSE_MIN") * 0.5, 0.0)


static func jaw_tip_uv(upper: bool) -> Vector2:
	if upper:
		return ellipse_major()
	return world(0.0, -mm("ELLIPSE_MAJ") * 0.5)


static func axis_17() -> Vector2:
	return world(40.0, 0.0)


static func ring_centre() -> Vector2:
	return Vector2(mm("CENTER"), 0.0)


static func trim_opening() -> Vector2:
	return world(TRIM_OPEN_LOCAL.x, TRIM_OPEN_LOCAL.y)


static func handle_xy(upper: bool) -> PackedVector2Array:
	var half := mm("HANDLE_HALF")
	var ring := mm("CENTER") - sqrt(maxf(0.0, pow(mm("RING_D") * 0.5, 2.0) - half * half))
	if upper:
		return PackedVector2Array([Vector2(HANDLE_OPEN_X_HI, half), Vector2(ring, half)])
	return PackedVector2Array([Vector2(HANDLE_OPEN_X_LO, -half), Vector2(ring, -half)])


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


## WalkUI07.sketch_on_datum: Sketch, then the named origin plane.
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
	if FilmUI.is_on_screen(ctx, screen):
		await FilmActor.of(ctx).aim(screen, FilmUICues.sketch_click(plane_name))
	var ix = ctx.main.interaction
	var named := false
	if ix != null and ix.has_method("try_named_sketch_datum"):
		named = bool(ix.try_named_sketch_datum(plane_name))
	if not named:
		if not FilmUI.require_on_screen(ctx, screen, plane_name):
			if pads != null:
				pads.visible = pads_was_visible
			return
		await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(plane_name))
	await FilmUI.wait_frames(ctx.tree, 4)
	if pads != null:
		pads.visible = pads_was_visible
	var sm_now: SketchMode = ctx.main.sketch_mode
	if sm_now == null or not sm_now.active:
		FilmUI._fail("%s sketch did not start" % plane_name)


static func ellipse3(ctx: FilmContext, centre: Vector2, major: Vector2, minor: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	if FilmUI.fail_count > 0:
		return
	await click(ctx, centre, "Ellipse centre", SPAN_HEAD)
	await click(ctx, major, "Ellipse major", SPAN_HEAD)
	await click(ctx, minor, "Ellipse minor", SPAN_HEAD)
	await FilmUI.wait_frames(ctx.tree, 2)


static func centerline(ctx: FilmContext, a: Vector2, b: Vector2, desc: String) -> void:
	await FilmSteps.press_rail(ctx, "Line")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.pick_variant(ctx, "Centerline")
	if FilmUI.fail_count > 0:
		return
	await click(ctx, a, "%s start" % desc, SPAN_HEAD)
	await click(ctx, b, "%s end" % desc, SPAN_HEAD)
	await FilmUI.end_line_chain(ctx)


static func place_af_hex(ctx: FilmContext, centre: Vector2, vertex: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.pick_variant(ctx, "Across Flats")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps._snap_off_if_visible(ctx)
	await click(ctx, centre, "AF hex centre", SPAN_RING)
	await click(ctx, vertex, "AF hex vertex", SPAN_RING)
	await FilmUI.wait_frames(ctx.tree, 2)


static func place_vertex_hex(ctx: FilmContext, centre: Vector2, vertex: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.pick_variant(ctx, "Vertex")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps._snap_off_if_visible(ctx)
	await click(ctx, centre, "Vertex hex centre", SPAN_RING)
	await click(ctx, vertex, "Vertex hex vertex", SPAN_RING)
	await FilmUI.wait_frames(ctx.tree, 2)


static func trim_at(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	if FilmUI.fail_count > 0:
		return
	await FilmSteps._snap_off_if_visible(ctx)
	await click(ctx, uv, desc, 0.0)
	await FilmUI.wait_frames(ctx.tree, 2)


static func constrain(ctx: FilmContext, name: String, first: Vector2, second: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await click(ctx, first, "%s first" % name, 0.0)
	await shift_click_uv(ctx, second, "%s second" % name)
	await FilmUI.wait_frames(ctx.tree, 2)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := FilmUI.find_button(chrome, name) if chrome != null else null
	if btn != null and btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, btn, FilmUICues.alert(name, name))
		return
	var more := FilmUI.find_button(chrome, "… More") if chrome != null else null
	if more is MenuButton:
		var popup := (more as MenuButton).get_popup()
		for i in popup.item_count:
			if popup.get_item_text(i) == name:
				await FilmUI.activate_menu_id(ctx, more as MenuButton, popup.get_item_id(i),
						FilmUICues.alert(name, name))
				return
	await FilmUI.marking_verb(ctx, name)


static func sketch_front_c(ctx: FilmContext) -> void:
	await ellipse3(ctx, Vector2.ZERO, ellipse_major(), ellipse_minor())
	if FilmUI.fail_count > 0:
		return
	await centerline(ctx, Vector2(-40, 0), Vector2(80, 0), "CL")
	if FilmUI.fail_count > 0:
		return
	await centerline(ctx, Vector2.ZERO, axis_17(), "17°")
	if FilmUI.fail_count > 0:
		return
	await FilmSteps._snap_off_if_visible(ctx)
	var o_hi := jaw_outer(true)
	var i_hi := jaw_inner(true)
	await line(ctx, o_hi, i_hi, "upper jaw", SPAN_HEAD)
	if FilmUI.fail_count > 0:
		return
	await constrain(ctx, "Parallel", axis_17(), (o_hi + i_hi) * 0.5)
	if FilmUI.fail_count > 0:
		return
	await constrain(ctx, "Coincident", o_hi, jaw_tip_uv(true))
	if FilmUI.fail_count > 0:
		return
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.SELECT)
	await click(ctx, axis_17(), "mirror axis", SPAN_HEAD)
	await shift_click_uv(ctx, (o_hi + i_hi) * 0.5, "jaw")
	await confirm_mirror(ctx, jaw_outer(false))
	await FilmUI.wait_frames(ctx.tree, 2)
	if count_type(ctx.main.sketch_mode, "line") < 2:
		await line(ctx, jaw_outer(false), jaw_inner(false), "lower jaw", SPAN_HEAD)
	await FilmSteps.three_point_arc(ctx, jaw_inner(false), throat(), jaw_inner(true), SPAN_HEAD)
	if FilmUI.fail_count > 0:
		return
	await trim_at(ctx, trim_opening(), "Trim opening")
	await constrain(ctx, "Coincident", jaw_outer(true), jaw_tip_uv(true))
	await constrain(ctx, "Coincident", jaw_outer(false), jaw_tip_uv(false))


static func sketch_ring_and_hexes(ctx: FilmContext) -> void:
	var c := ring_centre()
	var rad := mm("RING_D") * 0.5
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	if FilmUI.fail_count > 0:
		return
	await click(ctx, c, "Ø33 centre", SPAN_HANDLE)
	await click(ctx, c + Vector2(rad, 0.0), "Ø33 rim", SPAN_RING)
	var af := mm("HEX_AF")
	var r_v := af / sqrt(3.0)
	await place_af_hex(ctx, c, Vector2(c.x, c.y + r_v))
	if FilmUI.fail_count > 0:
		return
	var ang := deg_to_rad(30.0)
	await place_vertex_hex(ctx, c, Vector2(c.x + r_v * cos(ang), c.y + r_v * sin(ang)))
	if FilmUI.fail_count > 0:
		return
	await _trim_hex_leftovers(ctx)


static func sketch_handle(ctx: FilmContext) -> void:
	var hi := handle_xy(true)
	var lo := handle_xy(false)
	await FilmSteps._snap_off_if_visible(ctx)
	await line(ctx, hi[0], hi[1], "handle", SPAN_HANDLE)
	if FilmUI.fail_count > 0:
		return
	await constrain(ctx, "Horizontal", hi[0], hi[1])
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.SELECT)
	await click(ctx, Vector2(50, 0), "handle axis", SPAN_HANDLE)
	await shift_click_uv(ctx, (hi[0] + hi[1]) * 0.5, "handle")
	await confirm_mirror(ctx, Vector2(100, -30))
	await FilmUI.wait_frames(ctx.tree, 2)
	if _line_at_y(ctx.main.sketch_mode, -mm("HANDLE_HALF")) == 0:
		await line(ctx, lo[0], lo[1], "handle copy", SPAN_HANDLE)
		await constrain(ctx, "Horizontal", lo[0], lo[1])
	for uv in [Vector2(18, 10), Vector2(18, -10), Vector2(232, 10), Vector2(232, -10)]:
		await trim_at(ctx, uv, "Trim handle overflow")


static func set_contours(ctx: FilmContext, keep: PackedStringArray) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		FilmUI._fail("no sketch for contours")
		return
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null and chrome.has_method("refresh_contours"):
		chrome.refresh_contours(sm.sketch)
	await FilmUI.wait_frames(ctx.tree, 2)
	var chips := _contour_chips(ctx)
	if chips.is_empty():
		return
	var outlines: Array = sm.sketch.contour_outlines() if sm.sketch.has_method("contour_outlines") else []
	for i in chips.size():
		var chip: CheckButton = chips[i]
		var want := _contour_wanted(keep, outlines[i] if i < outlines.size() else {})
		if chip.button_pressed == want:
			continue
		if not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Contour", "region %d" % (i + 1))):
			return
		await FilmUI.wait_frames(ctx.tree, 1)


static func pencil_edit_sketch(ctx: FilmContext) -> void:
	var view_btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		if str((c as MenuButton).text) == "View":
			view_btn = c as MenuButton
			break
	if view_btn != null and (ctx.main.timeline == null or not ctx.main.timeline.visible):
		await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline"))
		await FilmUI.wait_frames(ctx.tree, 2)
	var pencil: Button = null
	var tl: Node = ctx.main.timeline
	if tl != null:
		for c in tl.find_children("*", "Button", true, false):
			var auto := str(c.get_meta("sx_auto", ""))
			if auto.begins_with("timeline:pencil:sketch"):
				pencil = c as Button
				break
	if pencil == null or not pencil.is_visible_in_tree():
		FilmUI._fail("sketch pencil is hidden")
		return
	await FilmUI.click_control(ctx, pencil, FilmUICues.edit_pad())
	await FilmUI.wait_frames(ctx.tree, 4)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("sketch did not reopen")


static func fillet_z_at(ctx: FilmContext, radius_key: String, xys: Array) -> void:
	await _select_only_body(ctx)
	if FilmUI.fail_count > 0:
		return
	await FilmSteps.arm_fillet(ctx, mm(radius_key))
	if FilmUI.fail_count > 0:
		return
	for xy in xys:
		var pt := Vector3(float(xy.x), float(xy.y), 0.0)
		await FilmActor.of(ctx).zoom_to(pt, 80.0, "Frame neck")
		var screen := FilmUI.model_to_screen(ctx, pt)
		if not FilmUI.require_on_screen(ctx, screen, "neck edge"):
			return
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Neck edge"))
		await FilmUI.wait_frames(ctx.tree, 2)
	await FilmSteps.commit_fillet(ctx)
	await ctx.after_regen()


static func convert_handle_outline(ctx: FilmContext) -> void:
	var z := mm("HANDLE_T") * 0.5
	for xy in [
		Vector2(28, 18), Vector2(28, -18), Vector2(215, 16), Vector2(215, -16),
		Vector2(23, 14), Vector2(23, -14), Vector2(226.9, 14), Vector2(226.9, -14),
		Vector2(120, 10), Vector2(120, -10),
	]:
		if FilmUI.fail_count > 0:
			return
		await FilmSteps.convert_edge(ctx, Vector3(xy.x, xy.y, z))


static func draw_recess_racetrack(ctx: FilmContext) -> void:
	await FilmSteps._snap_off_if_visible(ctx)
	var x0 := 40.0
	var x1 := 215.0
	var y := 5.5
	await line(ctx, Vector2(x0, y), Vector2(x1, y), "recess top", SPAN_HANDLE)
	await line(ctx, Vector2(x1, y), Vector2(x1, -y), "recess end", SPAN_HANDLE)
	await line(ctx, Vector2(x1, -y), Vector2(x0, -y), "recess bot", SPAN_HANDLE)
	await line(ctx, Vector2(x0, -y), Vector2(x0, y), "recess start", SPAN_HANDLE)


static func feature_mirror_front(ctx: FilmContext, names: Array) -> void:
	await _select_only_body(ctx)
	var view_btn: MenuButton = null
	for c in ctx.main.find_children("*", "MenuButton", true, false):
		if str((c as MenuButton).text) == "View":
			view_btn = c as MenuButton
			break
	if view_btn != null and (ctx.main.timeline == null or not ctx.main.timeline.visible):
		await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline"))
		await FilmUI.wait_frames(ctx.tree, 2)
	var arm := find_auto(ctx.main, "mirror:Features") as BaseButton
	if arm == null or not arm.is_visible_in_tree():
		FilmUI._fail("mirror:Features is hidden")
		return
	if not await FilmUI.click_control(ctx, arm, FilmUICues.alert("Features", "Feature Mirror")):
		return
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmSteps.click_mirror_datum(ctx, "Front")
	if FilmUI.fail_count > 0:
		return
	for i in names.size():
		var name := str(names[i])
		var row := find_auto(ctx.main, "timeline:row:%s" % name) as BaseButton
		if row == null or not row.is_visible_in_tree():
			FilmUI._fail("timeline:row:%s is hidden" % name)
			return
		FilmUI.ensure_control_visible(row)
		if i == 0:
			if not await FilmUI.click_control(ctx, row, FilmUICues.alert("Click", "timeline row")):
				return
		else:
			await FilmUI.viewport_click(ctx, FilmUI.control_screen_center(row),
					FilmUICues.alert("Shift+Click", "timeline row"), false, MOUSE_BUTTON_LEFT, true)
		await FilmUI.wait_frames(ctx.tree, 1)
	var ok := find_auto(ctx.main, "mirror:Ok") as Button
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("mirror:Ok is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Mirror OK"))
	await FilmUI.wait_frames(ctx.tree, 8)
	await ctx.after_regen()


static func last_name_of_type(doc: SxDocument, kind: String) -> String:
	var name := ""
	for f in doc.graph_features():
		if str(f.get("type", "")) == kind:
			name = str(f.get("name", ""))
	return name


static func feature_names_csv(doc: SxDocument) -> String:
	var names := PackedStringArray()
	for f in doc.graph_features():
		names.append(str(f.get("name", "")))
	return ", ".join(names)


static func _clear_selection(ctx: FilmContext) -> void:
	if ctx.view != null:
		ctx.view.select_entity("", "")
	await ctx.tree.process_frame


static func _select_only_body(ctx: FilmContext) -> void:
	var body := only_body(ctx)
	if body == "":
		FilmUI._fail("need one body")
		return
	await FilmActor.of(ctx).view_key(KEY_7, "Iso")
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		FilmUI._fail("body has no bbox")
		return
	var mid: Vector3 = ((bb["min"] as Vector3) + (bb["max"] as Vector3)) * 0.5
	await FilmActor.of(ctx).zoom_to(mid, 280.0, "Frame body")
	var screen := FilmUI.model_to_screen(ctx, mid)
	if not FilmUI.require_on_screen(ctx, screen, "body"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select body"))
	await FilmUI.wait_frames(ctx.tree, 2)


static func _contour_chips(ctx: FilmContext) -> Array:
	var out: Array = []
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var bar: Node = chrome.find_child("ContourBar", true, false) if chrome != null else null
	if bar == null:
		return out
	for c in bar.get_children():
		if c is CheckButton and (c as CheckButton).is_visible_in_tree():
			out.append(c)
	return out


static func _contour_wanted(keep: PackedStringArray, row: Dictionary) -> bool:
	var mn: Vector2 = row.get("min", Vector2.ZERO)
	var sz: Vector2 = row.get("size", Vector2.ZERO)
	var cx := mn.x + sz.x * 0.5
	var long_side := maxf(sz.x, sz.y)
	var short_side := minf(sz.x, sz.y)
	for token in keep:
		if token == "c" and absf(cx) < 50.0 and long_side > 40.0 and long_side < 80.0:
			return true
		if token == "ring" and absf(cx - mm("CENTER")) < 25.0 and long_side >= 30.0 and short_side >= 20.0:
			return true
		if token == "handle" and long_side > 80.0:
			return true
		if token == "recess" and long_side > 80.0 and long_side < 200.0 and short_side >= 6.0 and short_side <= 16.0:
			return true
	return false


static func _line_at_y(sm: SketchMode, y: float) -> int:
	var n := 0
	if sm == null or sm.sketch == null:
		return 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info.get("start", Vector2.ZERO)
		var b: Vector2 = info.get("end", Vector2.ZERO)
		if absf(a.y - y) <= 0.6 and absf(b.y - y) <= 0.6:
			n += 1
	return n


static func _trim_hex_leftovers(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		return
	var c := ring_centre()
	var mids: Array[Vector2] = []
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info.get("start", Vector2.ZERO)
		var b: Vector2 = info.get("end", Vector2.ZERO)
		var mid := (a + b) * 0.5
		if absf(mid.x - c.x) > 18.0 or absf(mid.y - c.y) > 18.0:
			continue
		var dist := mid.distance_to(c)
		var length := a.distance_to(b)
		if dist > 4.0 and dist <= 12.6 and length > 2.0:
			mids.append(mid)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await FilmSteps._snap_off_if_visible(ctx)
	for mid in mids:
		await click(ctx, mid, "Trim hex leftover", SPAN_RING)
