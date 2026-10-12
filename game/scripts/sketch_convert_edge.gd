class_name SketchConvertEdge
extends RefCounted
## One Convert click on a face sketch: the nearest boundary edge becomes external.
## The click carries a context. This file does not read SketchMode.


const PROJECTORS := {
	"line": "Convert: external line",
	"circle": "Convert: external circle",
}
const NOT_ON_FACE := "Convert: edge is not on this face"
const NOT_SUPPORTED := "Convert: edge type not supported (line or circle)"

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
			ctx.status.call(NOT_SUPPORTED)
			return
		ctx.commit.call("Convert")
		ctx.status.call(_added_status(lines, on_face))
		return
	var other := _nearest(lines, face_edges, world, OTHER_TOL, false)
	if other != "":
		ctx.status.call(NOT_ON_FACE)
		return
	ctx.fallback.call()


func _added_status(lines: Dictionary, edge_id: String) -> String:
	var kind := _edge_kind(lines, edge_id)
	return str(PROJECTORS.get(kind, PROJECTORS.line))


func _edge_kind(lines: Dictionary, edge_id: String) -> String:
	var pts: PackedVector3Array = lines.get(edge_id, PackedVector3Array())
	if pts.size() <= 2:
		return "line"
	if pts.size() >= 8 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.2:
		return "circle"
	return "line"


func _face_edge_set(ctx: Context, body: String) -> Dictionary:
	ctx.host_face_id = _resolve_host_face(ctx, body)
	var edges: PackedStringArray = ctx.doc.edges_of_face(ctx.host_face_id)
	var set := {}
	for id in edges:
		set[str(id)] = true
	return set


func _resolve_host_face(ctx: Context, body: String) -> String:
	if body == "" or ctx.support_normal.length_squared() < 1e-8:
		return ctx.host_face_id
	var want := ctx.support_normal.normalized()
	var origin := ctx.plane.origin
	var best_id := ctx.host_face_id
	var best_gap := 1.0e9
	for face in ctx.view.faces_matching(body, want, 0.7):
		var fid := str(face["id"])
		var n: Vector3 = face["normal"] as Vector3
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		var pick := FacePick.point(ctx.doc, fid)
		var gap := absf(FacePick.plane_offset(n, pick) - FacePick.plane_offset(n, origin))
		if gap < best_gap:
			best_gap = gap
			best_id = fid
	return best_id


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
