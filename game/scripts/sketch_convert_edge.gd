class_name SketchConvertEdge
extends RefCounted
## One Convert click on a face sketch: the nearest boundary edge becomes external.
## The click carries a context. This file does not read SketchMode.


const PROJECTORS := {
	"line": "Convert: external line",
	"circle": "Convert: external circle",
	"arc": "Convert: external arc",
	"spline": "Convert: external spline",
}
const NOT_ON_FACE := "Convert: edge is not on this face"
const NOT_SUPPORTED := "Convert: edge type not supported (line, circle, arc, or spline)"
const SILHOUETTE := "Convert: silhouette"

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
	## Session pulls the graph sketch (where the external entity landed) back
	## into the editor sketch. Offset and Convert share this one hook.
	var adopt: Callable
	## Optional: used to name the Convert status from the entity type.
	var sketch: SxSketch


var _ctx: Context


func _init(ctx: Context) -> void:
	_ctx = ctx


## Origin-plane sketches (Front / Top / Right through the origin) always
## project a silhouette, even when a leftover host face is remembered.
func _origin_plane() -> bool:
	var plane = _ctx.plane if _ctx != null else null
	if plane == null:
		return false
	if plane.origin.length() > 0.75:
		return false
	var n: Vector3 = plane.normal.abs()
	return n.x > 0.95 or n.y > 0.95 or n.z > 0.95


## Returns the new (or existing) external entity id, or "" on refusal / miss.
func click(uv: Vector2) -> String:
	var ctx := _ctx
	if ctx.doc == null or ctx.view == null:
		return ""
	if ctx.host_face_id == "" or ctx.support_host == "" or _origin_plane():
		var sid := _origin_silhouette(uv)
		if sid != "":
			return sid
		if ctx.host_face_id == "" or ctx.support_host == "":
			ctx.fallback.call()
			return ""
	var fid := str(ctx.ensure_feature.call())
	if fid == "":
		return ""
	var body := str(ctx.view.body_of_feature(ctx.support_host))
	var face_edges := _face_edge_set(ctx, body)
	var lines: Dictionary = ctx.doc.get_edge_lines(body)
	# Distance is in the sketch plane. A circle on a parallel face (the root,
	# 25 mm below) is still "near" the click; a 3D gap would hide it.
	var on_face := _nearest(lines, face_edges, ctx.plane, uv, FACE_TOL, true)
	if on_face != "":
		var id := str(ctx.doc.sketch_add_external_edge(fid, on_face))
		if id == "":
			ctx.status.call(NOT_SUPPORTED)
			return ""
		# The kernel writes the external entity onto the graph sketch. The
		# editor still holds the pre-convert copy until the session adopts it.
		if ctx.adopt.is_valid():
			ctx.adopt.call()
		ctx.commit.call("Convert")
		ctx.status.call(_added_status(id, lines, on_face))
		return id
	var other := _nearest(lines, face_edges, ctx.plane, uv, OTHER_TOL, false)
	if other != "":
		ctx.status.call(NOT_ON_FACE)
		return ""
	ctx.fallback.call()
	return ""


## Origin-plane pick: project the nearest body edge (silhouette / pierce).
func _origin_silhouette(uv: Vector2) -> String:
	var ctx := _ctx
	if ctx.doc == null or ctx.plane == null:
		return ""
	var fid := str(ctx.ensure_feature.call())
	if fid == "":
		return ""
	var best_id := ""
	var best_d := OTHER_TOL
	var best_lines: Dictionary = {}
	for body_id in ctx.doc.body_ids():
		var lines: Dictionary = ctx.doc.get_edge_lines(body_id)
		for edge_id in lines:
			var d := _edge_uv_distance(lines[edge_id], ctx.plane, uv)
			if d < best_d:
				best_d = d
				best_id = str(edge_id)
				best_lines = lines
	if best_id == "":
		return ""
	var id := str(ctx.doc.sketch_add_external_edge(fid, best_id))
	if id == "":
		ctx.status.call(NOT_SUPPORTED)
		return ""
	if ctx.adopt.is_valid():
		ctx.adopt.call()
	ctx.commit.call("Convert")
	if str(_entity_kind(id)) == "spline":
		ctx.status.call(PROJECTORS.spline)
	else:
		ctx.status.call(SILHOUETTE)
	return id


func _edge_uv_distance(pts: PackedVector3Array, plane: PlaneBasis, uv: Vector2) -> float:
	if pts.size() < 2:
		return INF
	var best := INF
	for i in range(pts.size() - 1):
		var a: Vector2 = plane.to_uv(pts[i])
		var b: Vector2 = plane.to_uv(pts[i + 1])
		var d := _seg_dist(uv, a, b)
		if d < best:
			best = d
	return best


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _entity_kind(id: String) -> String:
	if _ctx == null or _ctx.sketch == null or id == "":
		return ""
	return str(_ctx.sketch.entity_info(id).get("type", ""))


func _added_status(id: String, lines: Dictionary, edge_id: String) -> String:
	var kind := _entity_kind(id)
	if PROJECTORS.has(kind):
		return str(PROJECTORS[kind])
	return str(PROJECTORS.get(_edge_kind(lines, edge_id), PROJECTORS.line))


func _edge_kind(lines: Dictionary, edge_id: String) -> String:
	var pts: PackedVector3Array = lines.get(edge_id, PackedVector3Array())
	if pts.size() <= 2:
		return "line"
	if pts.size() >= 8 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.2:
		return "circle"
	if pts.size() >= 4:
		return "arc"
	return "line"


## The sketch's face. Adding the sketch feature retires the id the session
## stored, and the view mesh still names the other cap, so the kernel
## midpoint on the sketch plane is the host.
func _face_edge_set(ctx: Context, body: String) -> Dictionary:
	if not _face_on_plane(ctx, ctx.host_face_id):
		ctx.host_face_id = _resolve_host_face(ctx, body)
	var edges := PackedStringArray()
	if ctx.host_face_id != "":
		edges = ctx.doc.edges_of_face(ctx.host_face_id)
	if edges.is_empty():
		ctx.host_face_id = _resolve_host_face(ctx, body)
		edges = ctx.doc.edges_of_face(ctx.host_face_id)
	var set := {}
	for id in edges:
		set[str(id)] = true
	return set


func _face_on_plane(ctx: Context, face_id: String) -> bool:
	if face_id == "" or ctx.doc == null or not ctx.doc.has_method("face_midpoint"):
		return false
	var mid: Variant = ctx.doc.face_midpoint(face_id)
	if not (mid is Vector3):
		return false
	var n := ctx.plane.normal
	if n.length_squared() < 1e-12:
		return false
	return absf(Plane(n, ctx.plane.origin).distance_to(mid as Vector3)) <= 0.75


func _resolve_host_face(ctx: Context, body: String) -> String:
	if body == "" or ctx.doc == null or not ctx.doc.has_method("get_face_ids"):
		return ctx.host_face_id
	var n := ctx.plane.normal
	if n.length_squared() < 1e-8:
		n = ctx.support_normal
	if n.length_squared() < 1e-8:
		return ctx.host_face_id
	var origin := ctx.plane.origin
	var plane := Plane(n.normalized(), origin)
	var best_id := ctx.host_face_id
	var best_gap := 1.0e9
	for face_id in ctx.doc.get_face_ids(body):
		var fid := str(face_id)
		var mid: Variant = ctx.doc.face_midpoint(fid)
		if not (mid is Vector3):
			continue
		var gap := absf(plane.distance_to(mid as Vector3))
		if gap < best_gap:
			best_gap = gap
			best_id = fid
	return best_id


## `on_face` keeps edges in `face_edges`; otherwise it keeps every other edge.
## Distance is measured in the sketch plane, so a parallel circle still counts.
func _nearest(lines: Dictionary, face_edges: Dictionary, plane: PlaneBasis, uv: Vector2,
		tol: float, on_face: bool) -> String:
	var best := ""
	var best_d := tol
	for edge_id in lines:
		var key := str(edge_id)
		if bool(face_edges.has(key)) != on_face:
			continue
		var pts: PackedVector3Array = lines[edge_id]
		for i in range(pts.size() - 1):
			var d := SketchGeom.point_segment_distance(
					uv, plane.to_uv(pts[i]), plane.to_uv(pts[i + 1]))
			if d < best_d:
				best_d = d
				best = key
	return best

