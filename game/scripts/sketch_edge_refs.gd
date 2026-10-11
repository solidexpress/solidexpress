class_name SketchEdgeRefs
extends RefCounted
## Convert on a face sketch: one click, one external construction line.
## SmartDimIntent is the (kind, kind) → constraint table SketchMode applies.


const ADDED := "Convert: external line"
const NOT_ON_FACE := "Convert: edge is not on this face"
const NOT_LINE := "Convert: edge is not a straight line"

## A click this close to a boundary of the sketch face projects that edge.
const FACE_TOL := 3.5
## Farther than the face, this close to some other edge, is a refusal.
const OTHER_TOL := 12.0

## channel|kind_a|kind_b → {form, label_anchor, ...}. A missing row is not a case.
const _ROWS := {
	"single|line|": {
		"form": "line_length", "label_anchor": "mid", "also": "angle_to_horizontal",
	},
	"single|external_line|": {
		"form": "line_length", "label_anchor": "mid", "also": "angle_to_horizontal",
	},
	"single|circle|": {"form": "diameter", "label_anchor": "rim"},
	"single|arc|": {"form": "diameter", "label_anchor": "rim"},
	"between|circle_center|circle_center": {"form": "centres", "label_anchor": "mid"},
	"between|circle_center|arc_center": {"form": "centres", "label_anchor": "mid"},
	"between|arc_center|circle_center": {"form": "centres", "label_anchor": "mid"},
	"between|arc_center|arc_center": {"form": "centres", "label_anchor": "mid"},
	"between|circle_center|line": {
		"form": "point_line", "point": "a", "label_anchor": "mid",
	},
	"between|circle_center|external_line": {
		"form": "point_line", "point": "a", "label_anchor": "mid",
	},
	"between|arc_center|line": {
		"form": "point_line", "point": "a", "label_anchor": "mid",
	},
	"between|arc_center|external_line": {
		"form": "point_line", "point": "a", "label_anchor": "mid",
	},
	"between|line|circle_center": {
		"form": "point_line", "point": "b", "label_anchor": "mid",
	},
	"between|external_line|circle_center": {
		"form": "point_line", "point": "b", "label_anchor": "mid",
	},
	"between|line|arc_center": {
		"form": "point_line", "point": "b", "label_anchor": "mid",
	},
	"between|external_line|arc_center": {
		"form": "point_line", "point": "b", "label_anchor": "mid",
	},
	"between|line|line": {"form": "angle", "label_anchor": "vertex"},
	"between|line|external_line": {"form": "angle", "label_anchor": "vertex"},
	"between|external_line|line": {"form": "angle", "label_anchor": "vertex"},
	"between|external_line|external_line": {"form": "angle", "label_anchor": "vertex"},
	"selection|line|line": {"form": "angle", "label_anchor": "vertex"},
	"selection|line|external_line": {"form": "angle", "label_anchor": "vertex"},
	"selection|external_line|line": {"form": "angle", "label_anchor": "vertex"},
	"selection|external_line|external_line": {"form": "angle", "label_anchor": "vertex"},
	"selection|circle|external_line": {
		"form": "point_line", "point": "a", "point_role": "center", "label_anchor": "mid",
	},
	"selection|arc|external_line": {
		"form": "point_line", "point": "a", "point_role": "center", "label_anchor": "mid",
	},
	"selection|external_line|circle": {
		"form": "point_line", "point": "b", "point_role": "center", "label_anchor": "mid",
	},
	"selection|external_line|arc": {
		"form": "point_line", "point": "b", "point_role": "center", "label_anchor": "mid",
	},
}


static func resolve(channel: String, kind_a: String, kind_b: String) -> Dictionary:
	var key := "%s|%s|%s" % [channel, kind_a, kind_b]
	if not _ROWS.has(key):
		return {}
	return (_ROWS[key] as Dictionary).duplicate()


static func convert_click(mode: SketchMode, uv: Vector2) -> void:
	if mode == null or mode.sketch == null or mode.view == null or mode.view.doc == null:
		return
	if mode.host_face_id == "" or mode.support_host == "":
		mode.convert_pierce_points()
		return
	var fid := mode._ensure_sketch_feature()
	if fid == "":
		return
	var body := mode.view.body_of_feature(mode.support_host)
	var face_edges := _face_edge_set(mode, body)
	var lines: Dictionary = mode.view.doc.get_edge_lines(body)
	var world := mode.plane.to_world(uv)
	var on_face := _nearest(lines, face_edges, world, FACE_TOL, true)
	if on_face != "":
		var id: String = mode.view.doc.sketch_add_external_edge(fid, on_face)
		if id == "":
			mode.status.emit(NOT_LINE)
			return
		mode._undo_note("Convert")
		mode.run_solve()
		mode._redraw()
		mode.status.emit(ADDED)
		return
	var other := _nearest(lines, face_edges, world, OTHER_TOL, false)
	if other != "":
		mode.status.emit(NOT_ON_FACE)
		return
	mode.convert_pierce_points()


static func _face_edge_set(mode: SketchMode, body: String) -> Dictionary:
	var edges: PackedStringArray = mode.view.doc.edges_of_face(mode.host_face_id)
	if edges.is_empty() and body != "" and mode.support_normal.length_squared() > 1e-8:
		var want := mode.support_normal.normalized()
		var best: Dictionary = {}
		var best_dot := 0.7
		for face in mode.view.faces_matching(body, want, 0.7):
			var d := (face["normal"] as Vector3).dot(want)
			if d > best_dot:
				best_dot = d
				best = face
		if not best.is_empty():
			mode.host_face_id = str(best["id"])
			edges = mode.view.doc.edges_of_face(mode.host_face_id)
	var set := {}
	for id in edges:
		set[str(id)] = true
	return set


## `on_face` keeps edges in `face_edges`; otherwise it keeps every other edge.
static func _nearest(lines: Dictionary, face_edges: Dictionary, world: Vector3,
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
