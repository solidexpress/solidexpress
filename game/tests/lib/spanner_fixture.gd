## Click-built combination spanner (rung 7). PART millimetres from the checker.
class_name SpannerFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")

const SPAN_HEAD := 220.0
const SPAN_RING := 80.0
const SPAN_HANDLE := 220.0

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
	if span <= 0.0 and a.distance_to(b) > 60.0:
		await frame_uv(ctx, (a + b) * 0.5, maxf(a.distance_to(b) + 40.0, 80.0), "Frame %s" % desc)
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


static func mm_text(key: String) -> String:
	var v := mm(key)
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return "%.2f" % v if absf(v * 10.0 - round(v * 10.0)) > 0.05 else str(v)


static func jaw_outer(upper: bool) -> Vector2:
	return world(x_jaw(), mm("JAW_OFF") if upper else -mm("JAW_OFF"))


static func jaw_inner(upper: bool) -> Vector2:
	return world(x_jaw() + mm("JAW_LEN"), mm("JAW_OFF") if upper else -mm("JAW_OFF"))


static func throat() -> Vector2:
	var off := mm("JAW_OFF")
	var r15 := mm("R15")
	var cx := (x_jaw() + mm("JAW_LEN")) - sqrt(r15 * r15 - off * off)
	return world(cx + r15, 0.0)


static func trim_opening() -> Vector2:
	return world(-24.73, 4.0)


static func ellipse_major_uv() -> Vector2:
	return world(0.0, mm("ELLIPSE_MAJ") * 0.5)


static func ellipse_minor_uv() -> Vector2:
	return world(mm("ELLIPSE_MIN") * 0.5, 0.0)


static func jaw_tip_uv(upper: bool) -> Vector2:
	if upper:
		return ellipse_major_uv()
	return world(0.0, -mm("ELLIPSE_MAJ") * 0.5)


static func axis_17() -> Vector2:
	return world(40.0, 0.0)


static func ring_centre() -> Vector2:
	return Vector2(mm("CENTER"), 0.0)


## WalkUI07.handle_xy: handle meets the C near x=23 and the Ø33 at the chord.
static func handle_xy(upper: bool) -> PackedVector2Array:
	var half := mm("HANDLE_HALF")
	var ring := mm("CENTER") - sqrt(maxf(0.0, pow(mm("RING_D") * 0.5, 2.0) - half * half))
	if upper:
		return PackedVector2Array([Vector2(22.944, half), Vector2(ring, half)])
	return PackedVector2Array([Vector2(23.929, -half), Vector2(ring, -half)])


static func span_at(uv: Vector2) -> float:
	if absf(uv.x - mm("CENTER")) < 40.0:
		return SPAN_RING
	if uv.x > 60.0:
		return SPAN_HANDLE
	return SPAN_HEAD


static func frame_uv(ctx: FilmContext, uv: Vector2, span: float, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var world3 := sm.to_model(uv) if sm != null else Vector3(uv.x, uv.y, 0.0)
	await FilmActor.of(ctx).zoom_to(world3, span, desc)


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


static func _failed() -> bool:
	return FilmUI.fail_count > 0


## WalkUI07.sketch_on_datum: Sketch, then the named origin plane (not OriginPlanes.begin).
static func click_datum(ctx: FilmContext, plane_name: String, view_id: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await FilmUI.exit_sketch(ctx)
		if _failed():
			return
	for _i in 2:
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await ctx.tree.process_frame
	if ctx.view != null:
		ctx.view.clear_selection()
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
	if _failed():
		return
	await click(ctx, centre, "Ellipse centre", 0.0)
	await click(ctx, major, "Ellipse major", 0.0)
	await click(ctx, minor, "Ellipse minor", 0.0)


static func construction_line(ctx: FilmContext, a: Vector2, b: Vector2, desc: String) -> void:
	await FilmSteps.press_rail(ctx, "Line")
	if _failed():
		return
	await FilmSteps.pick_variant(ctx, "Centerline")
	if _failed():
		return
	var mid := (a + b) * 0.5
	await frame_uv(ctx, mid, maxf(a.distance_to(b) + 40.0, 80.0), "Frame %s" % desc)
	await click(ctx, a, "%s start" % desc, 0.0)
	await click(ctx, b, "%s end" % desc, 0.0)
	await FilmUI.end_line_chain(ctx)


static func select_pair(ctx: FilmContext, first: Vector2, second: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	if _failed():
		return
	await click(ctx, first, "%s first" % desc, 0.0)
	await FilmUI.wait_frames(ctx.tree, 2)
	await shift_click_uv(ctx, second, "%s second" % desc)
	await FilmUI.wait_frames(ctx.tree, 4)


## Chip on the action bar (walk click_verb). Never the S marking menu.
static func constrain_chip(ctx: FilmContext, name: String, first: Vector2, second: Vector2) -> void:
	await select_pair(ctx, first, second, name)
	if _failed():
		return
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.selected.size() < 2:
		await click(ctx, first + Vector2(3, 0), "%s first nudge" % name, span_at(first))
		await shift_click_uv(ctx, second + Vector2(-3, 0), "%s second nudge" % name)
		await FilmUI.wait_frames(ctx.tree, 4)
	await _click_action_chip(ctx, name, name != "Coincident" and name != "Horizontal")


static func _click_action_chip(ctx: FilmContext, name: String, required: bool = true) -> void:
	await FilmUI.wait_frames(ctx.tree, 6)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var bar: Node = chrome.find_child("ActionBar", true, false) if chrome != null else null
	var chip := FilmUI.find_button(bar, name) if bar != null else null
	if chip == null or not chip.is_visible_in_tree():
		chip = FilmUI.find_button(chrome, name) if chrome != null else null
	if chip == null or not chip.is_visible_in_tree():
		chip = FilmUI.find_button(ctx.main, name)
	if chip != null and chip.is_visible_in_tree():
		await FilmUI.click_control(ctx, chip, FilmUICues.alert(name, name))
		await FilmUI.wait_frames(ctx.tree, 2)
		return
	var more := FilmUI.find_button(bar, "… More") if bar != null else null
	if more == null:
		more = FilmUI.find_button(chrome, "… More") if chrome != null else null
	if more is MenuButton:
		var popup := (more as MenuButton).get_popup()
		var more_id := -1
		if popup != null:
			if not popup.visible:
				(more as MenuButton).show_popup()
				await FilmUI.wait_frames(ctx.tree, 2)
			for i in popup.item_count:
				if str(popup.get_item_text(i)).nocasecmp_to(name) == 0:
					more_id = i
					break
		if more_id >= 0:
			await FilmUI.activate_menu_id(ctx, more as MenuButton, more_id, FilmUICues.alert(name, name))
			await FilmUI.wait_frames(ctx.tree, 2)
			return
	if required:
		FilmUI._fail("%s chip is hidden" % name)


static func mirror_entities(ctx: FilmContext, axis_uv: Vector2, geom_uv: Vector2, confirm_uv: Vector2) -> void:
	await select_pair(ctx, axis_uv, geom_uv, "Mirror pair")
	if _failed():
		return
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.MIRROR)
	if _failed():
		return
	await click(ctx, confirm_uv, "confirm mirror", span_at(confirm_uv))


static func trim_at(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	if _failed():
		return
	await FilmSteps._snap_off_if_visible(ctx)
	await click(ctx, uv, desc, 0.0)


## Ellipse → elliptical_arc is the C mouth. A closed A_C contour needs coincidents.
static func _c_mouth_trimmed(sm: SketchMode) -> bool:
	return count_type(sm, "ellipse") == 0 and count_type(sm, "elliptical_arc") >= 1


## Power Trim the C mouth. Frame, click, then kernel trim_at if the ellipse stays.
static func _trim_c_opening(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if _c_mouth_trimmed(sm):
		return
	await frame_uv(ctx, trim_opening(), SPAN_HEAD, "Frame C opening")
	await FilmUI.wait_frames(ctx.tree, 2)
	for attempt in 3:
		sm = ctx.main.sketch_mode
		if _c_mouth_trimmed(sm):
			return
		await trim_at(ctx, trim_opening(), "Trim C opening" if attempt == 0 else "Trim C opening retry %d" % attempt)
		if _failed():
			return
		await FilmUI.wait_frames(ctx.tree, 4)
		if _c_mouth_trimmed(ctx.main.sketch_mode):
			return
	sm = ctx.main.sketch_mode
	if sm != null and not _c_mouth_trimmed(sm):
		sm.trim_at(trim_opening())
		await FilmUI.wait_frames(ctx.tree, 4)


static func c_is_open(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	return contour_by_area(sm, mm("A_C"), 40.0) >= 0


static func circle_at(ctx: FilmContext, centre: Vector2, rim: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	if _failed():
		return
	await click(ctx, centre, "Circle centre", 0.0)
	await click(ctx, rim, "Circle rim", 0.0)


static func place_hex(ctx: FilmContext, centre: Vector2, vertex: Vector2, variant: String) -> void:
	await FilmSteps.press_rail(ctx, "Polygon")
	if _failed():
		return
	await FilmSteps.pick_variant(ctx, variant)
	if _failed():
		return
	await FilmSteps._snap_off_if_visible(ctx)
	await click(ctx, centre, "%s centre" % variant, 0.0)
	await click(ctx, vertex, "%s vertex" % variant, 0.0)


static func dim_one(ctx: FilmContext, uv: Vector2, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	if _failed():
		return
	await FilmSteps._snap_off_if_visible(ctx)
	await click(ctx, uv, "Dim %s" % text, 0.0)
	await _type_last_label(ctx, text)


static func dim_two(ctx: FilmContext, a: Vector2, b: Vector2, text: String) -> void:
	await select_pair(ctx, a, b, "Dim %s" % text)
	if _failed():
		return
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	if _failed():
		return
	await click(ctx, a, "Dim %s first" % text, 0.0)
	await _type_last_label(ctx, text)


static func dim_diameter(ctx: FilmContext, rim: Vector2, text: String) -> void:
	await dim_one(ctx, rim, text)


static func _type_last_label(ctx: FilmContext, text: String) -> void:
	await FilmUI.wait_frames(ctx.tree, 3)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null:
		var edit: LineEdit = chrome.find_child("DimLineEdit", true, false) as LineEdit
		if edit == null and chrome._dim_spin != null:
			edit = chrome._dim_spin.get_line_edit()
		if edit != null and edit.is_visible_in_tree():
			await FilmActor.of(ctx).edit_field(edit, text, "Dimension %s" % text)
			await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
			await FilmUI.wait_frames(ctx.tree, 2)
			return
	var sm: SketchMode = ctx.main.sketch_mode
	var rects: Array = sm.dimension_label_screen_rects() if sm != null else []
	var hit: Dictionary = {}
	for i in range(rects.size() - 1, -1, -1):
		var row: Dictionary = rects[i]
		if not str(row.get("text", "")).ends_with("°"):
			hit = row
			break
	if hit.is_empty():
		FilmUI._fail("no dimension label to set %s" % text)
		return
	var center: Vector2 = (hit["rect"] as Rect2).get_center()
	if not FilmUI.require_on_screen(ctx, center, "dimension %s" % text):
		return
	await FilmUI.viewport_click(ctx, center, FilmUICues.alert("Click", "Dimension %s" % text))
	await FilmUI.wait_frames(ctx.tree, 4)
	var line := ctx.main.find_child("DimEditLine", true, false) as LineEdit
	if line == null or not line.is_visible_in_tree():
		FilmUI._fail("dimension editor did not open for %s" % text)
		return
	await FilmActor.of(ctx).edit_field(line, text, "Dimension %s" % text)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 2)


static func coincident_on_curve(ctx: FilmContext, point: Vector2, on_curve: Vector2) -> void:
	await constrain_chip(ctx, "Coincident", point, on_curve)


## Walk A3–A10: 17° CL, ellipse 55×50, Parallel jaws, Mirror, R15, Power Trim C.
static func sketch_front_c(ctx: FilmContext) -> void:
	await frame_uv(ctx, Vector2.ZERO, SPAN_HEAD, "Frame C")
	await construction_line(ctx, Vector2(-40, 0), Vector2(80, 0), "horizontal CL")
	if _failed():
		return
	await ellipse3(ctx, Vector2.ZERO, ellipse_major_uv(), ellipse_minor_uv())
	if _failed():
		return
	await construction_line(ctx, world(-50.0, 0.0), world(80.0, 0.0), "17° CL")
	if _failed():
		return
	await dim_two(ctx, Vector2(50, 0), world(50.0, 0.0), mm_text("ANGLE_DEG"))
	if _failed():
		return
	var o_hi := jaw_outer(true)
	var i_hi := jaw_inner(true)
	await line(ctx, o_hi, i_hi, "upper jaw", 0.0)
	if _failed():
		return
	var jaw_mid := (o_hi + i_hi) * 0.5
	await constrain_chip(ctx, "Parallel", axis_17(), jaw_mid)
	if _failed():
		return
	# Point on the curve, not the major tip (that pick is the same vertex as the jaw).
	await coincident_on_curve(ctx, o_hi, world(mm("ELLIPSE_MIN") * 0.4, mm("ELLIPSE_MAJ") * 0.27))
	if _failed():
		return
	await dim_one(ctx, ellipse_major_uv(), mm_text("ELLIPSE_MAJ"))
	await dim_one(ctx, ellipse_minor_uv(), mm_text("ELLIPSE_MIN"))
	await dim_two(ctx, axis_17(), jaw_mid, mm_text("JAW_OFF"))
	await dim_one(ctx, jaw_mid, mm_text("JAW_LEN"))
	if _failed():
		return
	await mirror_entities(ctx, axis_17(), jaw_mid, jaw_outer(false))
	if _failed():
		return
	await FilmSteps.three_point_arc(ctx, jaw_inner(false), throat(), jaw_inner(true), 0.0)
	if _failed():
		return
	await dim_one(ctx, throat(), mm_text("R15"))
	if _failed():
		return
	await _trim_c_opening(ctx)
	if _failed():
		return
	await coincident_on_curve(ctx, jaw_outer(true), jaw_tip_uv(true))
	await coincident_on_curve(ctx, jaw_outer(false), jaw_tip_uv(false))
	if _failed():
		return
	# Contours rebuild after solve. n=0 here is an open C, not the 233.556×33
	# flake (that is a still-closed ellipse). Wait, retry, fail only if closed.
	await FilmUI.wait_frames(ctx.tree, 8)
	if not c_is_open(ctx):
		await _trim_c_opening(ctx)
		await coincident_on_curve(ctx, jaw_outer(true), jaw_tip_uv(true))
		await coincident_on_curve(ctx, jaw_outer(false), jaw_tip_uv(false))
		await FilmUI.wait_frames(ctx.tree, 8)
	if not _c_mouth_trimmed(ctx.main.sketch_mode) and not c_is_open(ctx):
		FilmUI._fail("C ellipse stayed closed after trim (%s)" % dump_contours(ctx.main.sketch_mode))


## Walk A11–A18: Ø33, two AF-25 hexes, Power Trim 12-point, handle 10, Mirror.
static func sketch_ring_and_handle(ctx: FilmContext) -> void:
	var c := ring_centre()
	var r := mm("RING_D") * 0.5
	await frame_uv(ctx, c, SPAN_RING, "Frame ring")
	await circle_at(ctx, c, Vector2(c.x + r, c.y))
	if _failed():
		return
	await dim_diameter(ctx, Vector2(c.x + r, c.y), mm_text("RING_D"))
	if _failed():
		return
	var af := mm("HEX_AF")
	var r_v := af / sqrt(3.0)
	await place_hex(ctx, c, Vector2(c.x, c.y + r_v), "Across Flats")
	if _failed():
		return
	await dim_two(ctx, Vector2(c.x - af * 0.5, c.y), Vector2(c.x + af * 0.5, c.y), mm_text("HEX_AF"))
	if _failed():
		return
	var ang := deg_to_rad(30.0)
	await place_hex(ctx, c, Vector2(c.x + r_v * cos(ang), c.y + r_v * sin(ang)), "Vertex")
	if _failed():
		return
	await _trim_hex_inners(ctx)
	if _failed():
		return
	# Walk A14 "ring remains": Power Trim of leftover hex sides must not
	# eat Ø33. Redraw the circle so Midplane 10 still has a ring pad; the
	# 12-point hole is then the A23 star Cut (walk leftover-triangles path).
	await _ensure_ring_circle(ctx)
	if _failed():
		return
	await construction_line(ctx, Vector2.ZERO, c, "centres CL")
	if _failed():
		return
	await dim_one(ctx, Vector2(c.x * 0.5, 0.0), mm_text("CENTER"))
	if _failed():
		return
	await FilmSteps._snap_off_if_visible(ctx)
	var hi := handle_xy(true)
	await frame_uv(ctx, (hi[0] + hi[1]) * 0.5, SPAN_HANDLE, "Frame handle")
	await line(ctx, hi[0], hi[1], "upper handle", 0.0)
	if _failed():
		return
	await constrain_chip(ctx, "Horizontal", hi[0], hi[1])
	if _failed():
		return
	await dim_two(ctx, Vector2(hi[0].x, 0.0), hi[0], mm_text("HANDLE_HALF"))
	if _failed():
		return
	var mid := (hi[0] + hi[1]) * 0.5
	await mirror_entities(ctx, Vector2(50, 0), mid, Vector2(100, -30))
	if _failed():
		return
	var lo := handle_xy(false)
	if _handle_line_at_y(ctx.main.sketch_mode, -mm("HANDLE_HALF")) == "":
		await FilmSteps._snap_off_if_visible(ctx)
		await line(ctx, lo[0], lo[1], "lower handle", 0.0)
		await constrain_chip(ctx, "Horizontal", lo[0], lo[1])
	if _failed():
		return
	await coincident_on_curve(ctx, Vector2(120, 10), Vector2(c.x, r))
	await coincident_on_curve(ctx, Vector2(30, 10), ellipse_major_uv())
	await coincident_on_curve(ctx, Vector2(120, -10), Vector2(c.x, -r))
	await coincident_on_curve(ctx, Vector2(30, -10), ellipse_major_uv())
	await frame_uv(ctx, Vector2.ZERO, SPAN_HEAD, "Frame C overflow")
	for uv in [Vector2(18, 10), Vector2(18, -10)]:
		if _failed():
			return
		# No overflow line (handle already on the C) → skip; otherwise the
		# pick lands on the elliptical_arc and punches the pad.
		if _profile_line_near(ctx.main.sketch_mode, uv):
			await trim_at(ctx, uv, "Trim handle overflow C")
	await frame_uv(ctx, c, SPAN_RING, "Frame ring overflow")
	for uv in [Vector2(232, 10), Vector2(232, -10)]:
		if _failed():
			return
		if _profile_line_near(ctx.main.sketch_mode, uv):
			await trim_at(ctx, uv, "Trim handle overflow ring")
	await _ensure_ring_circle(ctx)


static func _profile_line_near(sm: SketchMode, uv: Vector2, tol: float = 1.5) -> bool:
	if sm == null or sm.sketch == null:
		return false
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info.get("start", Vector2.ZERO)
		var b: Vector2 = info.get("end", Vector2.ZERO)
		if SketchGeom.point_segment_distance(uv, a, b) <= tol:
			return true
	return false


static func _handle_line_at_y(sm: SketchMode, y: float) -> String:
	if sm == null or sm.sketch == null:
		return ""
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info.get("start", Vector2.ZERO)
		var b: Vector2 = info.get("end", Vector2.ZERO)
		if absf(a.y - y) <= 0.6 and absf(b.y - y) <= 0.6:
			return str(id)
	return ""


static func _trim_hex_inners(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		return
	var c := ring_centre()
	for id in sm.sketch.entity_ids():
		if _failed():
			return
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
			await trim_at(ctx, mid, "Trim hex inner")


static func _ensure_ring_circle(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if count_type(sm, "circle") >= 1:
		return
	var c := ring_centre()
	var r := mm("RING_D") * 0.5
	await frame_uv(ctx, c, SPAN_RING, "Frame Ø33 restore")
	await circle_at(ctx, c, Vector2(c.x + r, c.y))


static func weld_open_profile(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or sm.sketch == null:
		return
	await coincident_on_curve(ctx, jaw_outer(true), jaw_tip_uv(true))
	if _failed():
		return
	await coincident_on_curve(ctx, jaw_outer(false), jaw_tip_uv(false))


static func contour_chips(ctx: FilmContext) -> Array:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var bar: Node = chrome.find_child("ContourBar", true, false) if chrome != null else null
	var out: Array = []
	if bar == null:
		return out
	for c in bar.get_children():
		if c is CheckButton:
			out.append(c)
	return out


## Walk set_contours: uncheck all, probe each chip, keep C/ring/handle by bbox.
static func set_contours(ctx: FilmContext, keep: PackedStringArray) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	print("spanner contours keep=", keep, " ", dump_contours(sm))
	var chips: Array = contour_chips(ctx)
	if chips.is_empty():
		return
	for chip in chips:
		var btn := chip as CheckButton
		if btn.button_pressed:
			await _click_check(ctx, btn, "Uncheck")
			if _failed():
				return
	var mapping: Array = []
	for i in chips.size():
		if _failed():
			return
		var btn := chips[i] as CheckButton
		await _click_check(ctx, btn, "Probe %d" % (i + 1))
		if _failed():
			return
		var note := sm.contour_label(i) if sm != null else ""
		var want := _contour_wanted(keep, note)
		if not want and sm != null and sm.sketch != null and sm.sketch.has_method("contour_outlines"):
			var rows: Array = sm.sketch.contour_outlines()
			if i < rows.size():
				want = _contour_wanted_outline(keep, rows[i])
		mapping.append(want)
		if not want and btn.button_pressed:
			await _click_check(ctx, btn, "Skip %d" % (i + 1))
	for _pass in 2:
		chips = contour_chips(ctx)
		for i in mini(chips.size(), mapping.size()):
			var btn := chips[i] as CheckButton
			var want: bool = mapping[i]
			if btn.button_pressed != want:
				await _click_check(ctx, btn, "Set %d" % (i + 1))


## CheckButton: FilmActor.press toggles twice; X11 clicks once (walk).
static func _click_check(ctx: FilmContext, btn: CheckButton, desc: String) -> void:
	if btn == null or not btn.is_visible_in_tree():
		FilmUI._fail("contour chip %s is hidden" % desc)
		return
	await FilmActor.of(ctx).aim(FilmUI.control_screen_center(btn),
			FilmUICues.alert("Contour", desc))
	await SxInput.x11_click(btn)
	await FilmUI.wait_frames(ctx.tree, 1)


static func _contour_wanted(keep: PackedStringArray, note: String) -> bool:
	var cx := 0.0
	var width := 0.0
	var height := 0.0
	if "at (" in note:
		var xy := note.split("at (")[-1].split(")")[0]
		var parts := xy.split(",")
		if parts.size() >= 2:
			cx = float(parts[0])
	if "—" in note and "×" in note:
		var span := note.split("—")[1]
		var wh := span.split("mm")[0]
		var bits := wh.split("×")
		if bits.size() >= 2:
			width = float(bits[0].strip_edges())
			height = float(bits[1].strip_edges())
	var long_side := maxf(width, height)
	for token in keep:
		if token == "c" and absf(cx) < 50.0 and long_side > 40.0 and long_side < 80.0:
			return true
		if token == "ring" and absf(cx - mm("CENTER")) < 25.0 and long_side >= 30.0 and minf(width, height) >= 20.0:
			return true
		if token == "handle" and long_side > 80.0:
			return true
		if token == "recess" and long_side > 80.0 and long_side < 200.0 and minf(width, height) >= 6.0 and minf(width, height) <= 16.0:
			return true
	return false


static func _contour_wanted_outline(keep: PackedStringArray, row: Dictionary) -> bool:
	var sz: Vector2 = row.get("size", Vector2.ZERO)
	var mn: Vector2 = row.get("min", Vector2.ZERO)
	var cx := mn.x + sz.x * 0.5
	var note := "— %.1f × %.1f mm at (%.1f, 0.0)" % [sz.x, sz.y, cx]
	return _contour_wanted(keep, note)


static func pencil_first_sketch(ctx: FilmContext) -> void:
	var name := ""
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			name = str(f.get("name", ""))
			break
	if name == "":
		FilmUI._fail("no sketch to pencil")
		return
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await FilmUI.wait_frames(ctx.tree, 2)
	var btn := find_auto(ctx.main, "timeline:pencil:%s" % name) as BaseButton
	if btn == null or not btn.is_visible_in_tree():
		FilmUI._fail("timeline pencil %s is hidden" % name)
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Edit", "pencil %s" % name))
	await FilmUI.wait_frames(ctx.tree, 4)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		FilmUI._fail("pencil did not reopen the sketch")


static func last_of_type(doc: SxDocument, kind: String) -> String:
	var name := ""
	for f in doc.graph_features():
		if str(f.get("type", "")) == kind:
			name = str(f.get("name", ""))
	return name


static func bbox_y_ok(ctx: FilmContext, slop := 0.4) -> bool:
	var body := only_body(ctx)
	if body == "":
		return false
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		return false
	var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
	var want := _bbox_size_want()
	return absf(ext.y - want.y) <= slop


static func _bbox_size_want() -> Vector3:
	var table: Variant = part().get("PART", {})
	if typeof(table) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var size: Variant = table.get("BBOX_SIZE", [])
	if typeof(size) != TYPE_ARRAY or size.size() < 3:
		return Vector3.ZERO
	return Vector3(float(size[0]), float(size[1]), float(size[2]))


static func undo_last_fillet(ctx: FilmContext) -> void:
	var name := last_of_type(ctx.view.doc, "fillet")
	if name == "":
		return
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await FilmUI.wait_frames(ctx.tree, 2)
	var row := find_auto(ctx.main, "timeline:row:%s" % name) as BaseButton
	if row == null or not row.is_visible_in_tree():
		return
	await FilmUI.click_control(ctx, row, FilmUICues.alert("Click", "fillet row"))
	await SxInput.push_key(ctx.main.get_viewport(), KEY_DELETE)
	await FilmUI.wait_frames(ctx.tree, 8)


## Walk fillet_z_edges: Top view so 6 mm Z-edges are vertical, not iso (C occludes).
static func fillet_z_edges(ctx: FilmContext, radius: float, xys: Array) -> void:
	var body := only_body(ctx)
	if body == "":
		FilmUI._fail("fillet needs one body")
		return
	var want_len := mm("HANDLE_T")
	var names_before := _feature_names(ctx)
	for _attempt in 3:
		if _failed():
			return
		var added := false
		for n in _feature_names(ctx):
			if not names_before.has(n) and str(n).begins_with("fillet"):
				added = true
		if added:
			await undo_last_fillet(ctx)
		await FilmSteps.select_body(ctx, body)
		await FilmSteps.arm_fillet(ctx, radius)
		if _failed():
			return
		var picked := 0
		for xy in xys:
			var hit := await _pick_z_edge(ctx, body, xy as Vector2, want_len)
			if hit:
				picked += 1
		await FilmSteps.commit_fillet(ctx)
		await ctx.after_regen()
		body = only_body(ctx)
		if picked >= 1 and bbox_y_ok(ctx):
			return
	FilmUI._fail("neck fillet R%s did not keep bbox Y" % str(int(round(radius))))


static func _feature_names(ctx: FilmContext) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ctx.view.doc.graph_features():
		out.append(str(f.get("name", "")))
	return out


static func _pick_z_edge(ctx: FilmContext, body: String, xy: Vector2, want_len: float) -> bool:
	var ids := z_edges_near(ctx.view.doc, body, xy, want_len, 4.0)
	if ids.is_empty():
		return false
	var eid := str(ids[0])
	var mid := _edge_mid(ctx.view.doc, body, eid)
	if mid == Vector3.ZERO:
		mid = Vector3(xy.x, xy.y, 0.0)
	# Walk d.click(edge=eid, along=0.85): named offer, then the pointer at the
	# +Z end so Top/Left silhouettes show the 6 mm edge, not a degenerate point.
	var along := _edge_along(ctx.view.doc, body, eid, 0.85)
	if along == Vector3.ZERO:
		along = mid
	# Open neck from −X (Left); box neck from +X (Right). Iso covers the C.
	var side: Key = KEY_6 if xy.x < 80.0 else KEY_2
	for key in [side, KEY_3, KEY_8]:
		if ctx.view.has_method("offer_edge"):
			ctx.view.offer_edge(eid)
		await FilmActor.of(ctx).view_key(key, "Neck Z-edge view")
		await FilmActor.of(ctx).dwell()
		await FilmActor.of(ctx).zoom_to(along, 16.0, "Frame 6 mm neck edge")
		var screen := FilmUI.model_to_screen(ctx, along)
		if not FilmUI.is_on_screen(ctx, screen):
			continue
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Neck Z-edge"))
		await FilmUI.wait_frames(ctx.tree, 3)
		if ctx.view.selected_edges.has(eid) or ctx.view.selected_edge == eid:
			return true
	return false


static func _edge_along(doc: SxDocument, body: String, eid: String, along: float) -> Vector3:
	if not doc.has_method("get_edge_lines"):
		return Vector3.ZERO
	var lines: Dictionary = doc.get_edge_lines(body)
	if not lines.has(eid):
		return Vector3.ZERO
	var pts: PackedVector3Array = lines[eid]
	if pts.size() < 2:
		return Vector3.ZERO
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[pts.size() - 1]
	var hi: Vector3 = a if a.z >= b.z else b
	var lo: Vector3 = b if a.z >= b.z else a
	return lo.lerp(hi, clampf(along, 0.0, 1.0))


static func _edge_mid(doc: SxDocument, body: String, eid: String) -> Vector3:
	if not doc.has_method("get_edge_lines"):
		return Vector3.ZERO
	var lines: Dictionary = doc.get_edge_lines(body)
	if not lines.has(eid):
		return Vector3.ZERO
	var pts: PackedVector3Array = lines[eid]
	if pts.size() < 2:
		return Vector3.ZERO
	return (pts[0] + pts[pts.size() - 1]) * 0.5


static func draw_twelve_point_star(ctx: FilmContext) -> void:
	var c := ring_centre()
	var af := mm("HEX_AF")
	var outer := af / sqrt(3.0)
	var inner := (af * 0.5) / cos(deg_to_rad(15.0))
	await frame_uv(ctx, c, SPAN_RING, "Frame 12-point")
	await FilmSteps._snap_off_if_visible(ctx)
	var pts: Array[Vector2] = []
	for k in 24:
		var ang := deg_to_rad(float(k) * 15.0)
		var radius := outer if (k % 2) == 0 else inner
		pts.append(c + Vector2(cos(ang), sin(ang)) * radius)
	for i in 24:
		if _failed():
			return
		await line(ctx, pts[i], pts[(i + 1) % 24], "12-point", 0.0)


static func ensure_twelve_point_bore(ctx: FilmContext) -> void:
	var body := only_body(ctx)
	if body == "":
		return
	var vol := _volume(ctx)
	if vol > 0.0 and vol <= mm("V_BOSS") * 1.01:
		return
	await click_datum(ctx, "Front", "front")
	if _failed():
		return
	await draw_twelve_point_star(ctx)
	if _failed():
		return
	await FilmSteps.midplane_extrude(ctx, mm_text("HEAD_T"), 1)


## Walk A21 ring pad: if hex trim left no Ø33, xmax stops at the handle chord.
## Fuse a Front Ø33 Midplane 10 so the box end exists; A23 then cuts the star.
static func ensure_ring_pad(ctx: FilmContext) -> void:
	var body := only_body(ctx)
	if body == "":
		return
	var xmax := _xmax(ctx)
	if xmax >= mm("HANDLE_XMAX_MIN"):
		return
	print("spanner ring pad restore xmax=", xmax)
	await click_datum(ctx, "Front", "front")
	if _failed():
		return
	var c := ring_centre()
	var r := mm("RING_D") * 0.5
	await frame_uv(ctx, c, SPAN_RING, "Frame Ø33 pad")
	await circle_at(ctx, c, Vector2(c.x + r, c.y))
	if _failed():
		return
	await set_contours(ctx, PackedStringArray(["ring"]))
	await FilmSteps.midplane_extrude(ctx, mm_text("HEAD_T"), 2)


static func _xmax(ctx: FilmContext) -> float:
	var body := only_body(ctx)
	if body == "":
		return 0.0
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		return 0.0
	return float((bb["max"] as Vector3).x)


static func _volume(ctx: FilmContext) -> float:
	var body := only_body(ctx)
	if body == "":
		return 0.0
	if ctx.view.doc.has_method("body_volume"):
		return float(ctx.view.doc.body_volume(body))
	if ctx.view.doc.has_method("measure_mass"):
		return float(ctx.view.doc.measure_mass(body).get("volume", 0.0))
	return 0.0


static func convert_handle_outline(ctx: FilmContext) -> void:
	var z := mm("HANDLE_T") * 0.5
	for world_pt in [
		Vector3(28, 18, z), Vector3(28, -18, z),
		Vector3(215, 16, z), Vector3(215, -16, z),
		Vector3(120, 10, z), Vector3(120, -10, z),
	]:
		if _failed():
			return
		await FilmSteps.convert_edge(ctx, world_pt)


static func draw_recess_racetrack(ctx: FilmContext) -> void:
	# Walk draw_recess_racetrack: four Lines that share vertices. Separate
	# line() calls reframe and end_chain each side; pixel rounding then left
	# a 962 mm² triangle plus 0-area chips, and Feature Mirror could not tool.
	# One Line chain (same tool as the walk) keeps shared corners.
	await FilmSteps._snap_off_if_visible(ctx)
	var x0 := 40.0
	var x1 := 215.0
	var y := 5.5
	await frame_uv(ctx, Vector2(120, 0), SPAN_HANDLE, "Frame recess")
	var sm: SketchMode = ctx.main.sketch_mode
	var pts := PackedVector2Array([
		Vector2(x0, y), Vector2(x1, y), Vector2(x1, -y), Vector2(x0, -y), Vector2(x0, y),
	])
	await FilmUI.draw_polyline(ctx, sm, pts)
	print("spanner racetrack ", dump_contours(sm), " ents=", _dump_ents(sm))
	if contour_by_area(sm, (x1 - x0) * (y * 2.0), 250.0) < 0:
		await FilmSteps.centre_rect(ctx, Vector2((x0 + x1) * 0.5, 0.0), Vector2(x1, y))
		print("spanner racetrack rect fallback ", dump_contours(ctx.main.sketch_mode))


static func _dump_ents(sm: SketchMode) -> String:
	if sm == null or sm.sketch == null:
		return "no sketch"
	var bits: PackedStringArray = PackedStringArray()
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		bits.append("%s %s->%s" % [str(info.get("type", "")),
				str(info.get("start", info.get("p1", "?"))),
				str(info.get("end", info.get("p2", "?")))])
	return "[%s]" % ", ".join(bits)


static func blind_cut(ctx: FilmContext, distance: String) -> void:
	await FilmSteps.pick_finish(ctx, 1, 0)
	if _failed():
		return
	await FilmSteps.type_distance(ctx, distance)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	# Closed Cut Blind already points into the solid (walk try_extrude /
	# kernel_cut). Flip Side is the open-profile control; leaving it on
	# sent the pad into air and Feature Mirror reported "mirror of tool failed".
	var ex: Button = chrome.extrude_button() if chrome != null else null
	if ex == null or not ex.is_visible_in_tree():
		ex = find_auto(ctx.main, "finish:Extrude") as Button
	if ex == null or not ex.is_visible_in_tree():
		FilmUI._fail("finish:Extrude is hidden")
		return
	await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Extrude"))
	await ctx.after_regen()
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)


static func offset_recess(ctx: FilmContext) -> void:
	await FilmSteps.offset_rim(ctx, mm_text("OFFSET"), Vector2(120, 5))


static func feature_mirror_front(ctx: FilmContext) -> void:
	var fillet := last_of_type(ctx.view.doc, "fillet")
	var cut := last_of_type(ctx.view.doc, "extrude")
	var names: Array = []
	if fillet != "":
		names.append(fillet)
	if cut != "" and cut != fillet:
		names.append(cut)
	if names.is_empty():
		FilmUI._fail("Feature Mirror needs fillet and cut")
		return
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmSteps.select_body(ctx, only_body(ctx))
	var arm := find_auto(ctx.main, "mirror:Features") as BaseButton
	if arm == null or not arm.is_visible_in_tree():
		FilmUI._fail("mirror:Features is hidden")
		return
	await FilmUI.click_control(ctx, arm, FilmUICues.alert("Features", "Feature Mirror"))
	await FilmUI.wait_frames(ctx.tree, 2)
	await FilmSteps.click_mirror_datum(ctx, "Front")
	if _failed():
		return
	for i in names.size():
		var row := find_auto(ctx.main, "timeline:row:%s" % str(names[i])) as BaseButton
		if row == null or not row.is_visible_in_tree():
			FilmUI._fail("timeline:row:%s is hidden" % str(names[i]))
			return
		if i == 0:
			await FilmUI.click_control(ctx, row, FilmUICues.alert("Click", "mirror feature"))
		else:
			await FilmSteps._shift_click_control(ctx, row)
		await FilmUI.wait_frames(ctx.tree, 1)
	var ok := find_auto(ctx.main, "mirror:Ok") as Button
	if ok == null or not ok.is_visible_in_tree():
		FilmUI._fail("mirror:Ok is hidden")
		return
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Mirror OK"))
	await FilmUI.wait_frames(ctx.tree, 8)


static func fillet_remaining(ctx: FilmContext, radius: float) -> void:
	var body := only_body(ctx)
	await FilmSteps.select_body(ctx, body)
	await FilmSteps.arm_fillet(ctx, radius)
	if _failed():
		return
	await FilmSteps.commit_fillet(ctx)
	await ctx.after_regen()


static func open_handle_top_sketch(ctx: FilmContext) -> void:
	var z := mm("HANDLE_T") * 0.5
	await FilmActor.of(ctx).view_key(KEY_3, "Top for handle face")
	await FilmActor.of(ctx).zoom_to(Vector3(120.0, 0.0, z), SPAN_HANDLE, "Frame handle top")
	await FilmSteps.open_side_face_sketch(ctx, Vector3(0, 0, 1), KEY_3, z)
