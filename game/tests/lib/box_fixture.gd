## The 100×60×50 validation box shared by the rung-2 suites.
## Click path for the solid; kernel fillet and bbox queries are allowed here.
class_name BoxFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")

const SIZE := Vector3(100, 60, 50)
const _Z_SPAN := 5.0
const _XY_SLACK := 0.5


static func build_box(ctx: FilmContext, after_rect: Callable = Callable(), note: Callable = Callable()) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	_check(ctx, sm != null and sm.active, "ground sketch is open")
	await SxInput.zoom(ctx, Vector3(50, 30, 0), 160.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await SxInput.click_uv(ctx.tree, ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await SxInput.click_uv(ctx.tree, ctx, ctx.main.get_viewport(), Vector2(100, 60))
	await ctx.tree.process_frame
	await _call(after_rect, ctx)
	var dist := FilmUI.distance_edit(ctx)
	_check(ctx, dist != null and dist.is_visible_in_tree(), "Distance field is visible")
	if dist != null:
		await SxInput.x11_click(dist)
		await SxInput.type_text(dist.get_viewport(), "50")
		await ctx.tree.process_frame
	var ex: Button = ctx.main.sketch_chrome.extrude_button() if ctx.main.sketch_chrome != null else null
	_check(ctx, ex != null and ex.is_visible_in_tree(), "Extrude button is visible")
	if ex != null:
		await SxInput.x11_click(ex)
	for _i in 8:
		await ctx.tree.process_frame
	await _call(note, ctx)
	var body := only_body(ctx)
	_check(ctx, body != "", "extrude made one body")
	if body == "":
		return
	var sz := bbox(ctx)
	_check(ctx, sz.distance_to(SIZE) < 0.2, "box is 100×60×50 (got %s)" % str(sz))


static func fillet_z_edges(ctx: FilmContext, radius: float) -> void:
	var body := only_body(ctx)
	var fid := ctx.view.feature_of_body(body)
	var edges := PackedStringArray()
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		if _is_z_edge(pts[pts.size() - 1] - pts[0]):
			edges.append(str(id))
	_check(ctx, edges.size() == 4, "four Z edges to fillet (got %d)" % edges.size())
	if edges.size() != 4 or fid == "":
		return
	var added := ctx.view.doc.graph_add_fillet(fid, edges, radius)
	_check(ctx, added != "", "fillet feature added (%s)" % ctx.view.doc.last_graph_error())
	ctx.view.graph_changed()
	await ctx.tree.process_frame
	await ctx.tree.process_frame


static func only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


static func bbox(ctx: FilmContext) -> Vector3:
	var body := only_body(ctx)
	if body == "":
		return Vector3.ZERO
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		return Vector3.ZERO
	return bb["max"] - bb["min"]


static func _is_z_edge(delta: Vector3) -> bool:
	return absf(delta.z) > _Z_SPAN and absf(delta.x) < _XY_SLACK and absf(delta.y) < _XY_SLACK


static func _check(ctx: FilmContext, cond: bool, what: String) -> void:
	ctx.tree.call("check", cond, what)


static func _call(fn: Callable, ctx: FilmContext) -> void:
	if fn.is_valid():
		await fn.call(ctx)
