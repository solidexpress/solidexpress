class_name SketchConvertEdge
extends RefCounted
## One Convert click on a face sketch: the nearest boundary line becomes external.
## The click carries a context. This file does not read SketchMode.


const ADDED := "Convert: external line"
const NOT_ON_FACE := "Convert: edge is not on this face"
const NOT_LINE := "Convert: edge is not a straight line"

## A click this close to a boundary of the sketch face projects that edge.
const FACE_TOL := 3.5
## Farther than the face, this close to some other edge, is a refusal.
const OTHER_TOL := 12.0


class Context:
	var doc: SxDocument
	var view: DocumentView
	var plane: PlaneBasis
	var host_face_id := ""
	var support_host := ""
	var support_normal := Vector3.ZERO
	var ensure_feature: Callable
	var commit: Callable
	var status: Callable
	var fallback: Callable


var _ctx: Context


func _init(ctx: Context) -> void:
	_ctx = ctx


func click(uv: Vector2) -> void:
	var ctx := _ctx
	if ctx.doc == null or ctx.view == null:
		return
	if ctx.host_face_id == "" or ctx.support_host == "":
		ctx.fallback.call()
		return
	var fid := str(ctx.ensure_feature.call())
	if fid == "":
		return
	var body := str(ctx.view.body_of_feature(ctx.support_host))
	var face_edges := _face_edge_set(ctx, body)
	var lines: Dictionary = ctx.doc.get_edge_lines(body)
	var world := ctx.plane.to_world(uv)
	var on_face := _nearest(lines, face_edges, world, FACE_TOL, true)
	if on_face != "":
		var id := str(ctx.doc.sketch_add_external_edge(fid, on_face))
		if id == "":
			ctx.status.call(NOT_LINE)
			return
		ctx.commit.call("Convert")
		ctx.status.call(ADDED)
		return
	var other := _nearest(lines, face_edges, world, OTHER_TOL, false)
	if other != "":
		ctx.status.call(NOT_ON_FACE)
		return
	ctx.fallback.call()


func _face_edge_set(ctx: Context, body: String) -> Dictionary:
	var edges: PackedStringArray = ctx.doc.edges_of_face(ctx.host_face_id)
	if edges.is_empty() and body != "" and ctx.support_normal.length_squared() > 1e-8:
		var want := ctx.support_normal.normalized()
		var best: Dictionary = {}
		var best_dot := 0.7
		for face in ctx.view.faces_matching(body, want, 0.7):
			var d := (face["normal"] as Vector3).dot(want)
			if d > best_dot:
				best_dot = d
				best = face
		if not best.is_empty():
			ctx.host_face_id = str(best["id"])
			edges = ctx.doc.edges_of_face(ctx.host_face_id)
	var set := {}
	for id in edges:
		set[str(id)] = true
	return set


## `on_face` keeps edges in `face_edges`; otherwise it keeps every other edge.
func _nearest(lines: Dictionary, face_edges: Dictionary, world: Vector3,
		tol: float, on_face: bool) -> String:
	var best := ""
	var best_d := tol
	for edge_id in lines:
		var key := str(edge_id)
		if bool(face_edges.has(key)) != on_face:
			continue
		var pts: PackedVector3Array = lines[edge_id]
		for i in range(pts.size() - 1):
			var d := SketchGeom.point_segment_distance_3d(world, pts[i], pts[i + 1])
			if d < best_d:
				best_d = d
				best = key
	return best
