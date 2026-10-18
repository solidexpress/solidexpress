## Click-built combination spanner (rung 7). PART millimetres from the checker.
class_name SpannerFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

const SPAN_HEAD := 90.0
const SPAN_RING := 80.0
const SPAN_HANDLE := 160.0

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


static func click(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	await FilmSteps.click_uv(ctx, uv, desc, 0.0)


static func line(ctx: FilmContext, a: Vector2, b: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click(ctx, a, "%s start" % desc)
	await click(ctx, b, "%s end" % desc)
	await FilmUI.end_line_chain(ctx)


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


static func set_handle_construction(sm: SketchMode, on: bool) -> void:
	if sm == null or sm.sketch == null:
		return
	var half := mm("HANDLE_HALF")
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if absf(a.y - half) <= 0.3 and absf(b.y - half) <= 0.3:
			sm.sketch.set_construction(id, on)
		elif absf(a.y + half) <= 0.3 and absf(b.y + half) <= 0.3:
			sm.sketch.set_construction(id, on)


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


static func contour_at(sm: SketchMode, uv: Vector2) -> int:
	if sm == null or sm.sketch == null or not sm.sketch.has_method("region_at"):
		return -1
	return int(sm.sketch.region_at(uv.x, uv.y))


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
