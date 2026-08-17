class_name SketchMode
extends Node3D
## In-viewport sketch editing. Owns an SxSketch, renders its entities on the
## sketch plane, and converts viewport rays to sketch 2D coordinates.
## Tools: line chain, rectangle, circle. Finish extrudes the profile.

signal finished(body_id: String)
signal cancelled
signal status(text: String)

enum Tool {
	NONE, LINE, RECT, CIRCLE, ARC, POLYGON, SELECT, TRIM,
	EXTEND, SMART_DIM, CONVERT, MIRROR, PATTERN, SPLINE, POINT,
	CENTERLINE, ELLIPSE, SLOT, CHAMFER,
}

signal selection_changed(ids: Array)

const PICK_TOLERANCE := 2.5  # model units (mm) — selection hit radius
const SNAP_RADIUS := 1.25  # tighter magnet (Fusion/Onshape-scale at typical zoom)
const GLYPH_PICK_RADIUS := 2.0  # constraint badges are small, precise targets

var sketch: SxSketch
var view: DocumentView
var tool: Tool = Tool.NONE
var active := false
## Minimum sketch working scale. Framing on a 5 mm blank made screen drags
## land as sub-millimetre segments; floor the ortho view so 1 px ≈ 0.05 mm.
const MIN_SKETCH_VIEW_RADIUS_MM := 15.0
const MIN_SKETCH_VIEW_MM := 20.0
## Shortest committed segment — below this the click is treated as a mis-drag
## instead of silently adding junk geometry that can never close a profile.
const MIN_SEGMENT_MM := 0.05
var _sketch_view_radius := 25.0
## When true, click/hover positions pass through snap_point().
var snap_enabled := true
## Regular N-gon side count for the POLYGON tool (clamped 3..24).
var polygon_sides := 6:
	set(v):
		polygon_sides = clampi(v, 3, 24)
## Tool variants: rect=corner|center|three_point|parallelogram;
## circle=center|perimeter|three_point; arc=center|tangent|three_point;
## pattern=linear|circular.
var tool_variant := "corner"
## Draw next line as construction (centerline mode).
var draw_construction := false
## Power-trim drag state: list of already-trimmed entity ids this stroke.
var _trim_drag_ids: Array[String] = []
var _trim_dragging := false
## Highlight entity under trim hover (red).
var _trim_hover_id := ""
## Smart-dim / convert / mirror / pattern scratch.
var _smart_dim_first: Variant = null  # Vector2 | null
var _mirror_axis_id := ""
var _pattern_count := 3
var _pattern_spacing := 10.0
## Sketch blocks: name -> PackedStringArray of entity ids.
var blocks: Dictionary = {}
## Sketch picture underlay (Texture2D on plane); null when none.
var sketch_picture: Texture2D
var sketch_picture_size := Vector2(100, 100)
var _picture_node: MeshInstance3D
## Fit-spline control points while drawing.
var _spline_pts: Array[Vector2] = []
## Feature id of the body being sketched on ("" when on the ground plane);
## used as the boolean target for cut/fuse finishes.
var target_fid := ""
## Feature id of the sketch being edited ("" when creating a new sketch).
var editing_fid := ""
## Optional OrbitCamera for enter/leave sketch view locking.
var camera: OrbitCamera
## Pierce / coincident points from other geometry (model-space projected to 2D).
## Array of Vector2 in sketch coords — used for snap/select/measure.
var intersection_points: Array[Vector2] = []

# Sketch plane frame in model space.
var plane_origin := Vector3.ZERO
var plane_x := Vector3.RIGHT
var plane_y := Vector3.UP  # model-space Y (kernel), set on begin()

## Selected entity ids (SELECT tool), most recent last, max 2.
var selected: Array[String] = []
## Selected constraint id (click its glyph with the SELECT tool); Del removes.
var selected_constraint := ""

## Applied dimensional constraints: {type, ids, value}. Rebuilt into Label3Ds.
var dimensions: Array = []
## When false, dimension label container is hidden (labels still rebuilt).
var dimensions_visible := true

var _draw_node: MeshInstance3D
var _preview_node: MeshInstance3D
var _selected_node: MeshInstance3D
var _dimension_labels: Node3D
var _constraint_glyphs: Node3D
## Anchors of the drawn glyphs: Array of {cid: String, pos: Vector2}.
var _glyph_anchors: Array = []
## Live inference hint while drawing (shows H/V/coincident before commit).
var _infer_label: Label3D
var _selected_material: StandardMaterial3D
var _tool_points: Array[Vector2] = []  # committed anchor points of current tool
var _hover: Vector2 = Vector2.ZERO
## When ≥ 0, rubber-band length/radius is locked to this value; mouse only
## steers direction. Cleared on tool change / Esc / after the next commit click.
var _length_override: float = -1.0
## Set by snap_point when a snap applied; drawn as a small cross in preview.
var _snap_marker: Variant = null  # Vector2 | null
## Active SELECT-tool geometry drag. Empty when idle. Keys when dragging:
## id, part ("start"|"end"|"whole"|"center"|"radius"), grab_pos, orig_info,
## preview_info. Commits live via SxSketch.set_entity_geometry + re-solve.
var _drag: Dictionary = {}
var _line_material: StandardMaterial3D
var _preview_material: StandardMaterial3D

const DIM_LABEL_OFFSET := 4.0  # sketch-plane units perpendicular to a distance dim
const COLOR_ENTITY := Color(0.95, 0.95, 1.0)
const COLOR_CONSTRUCTION := Color(0.45, 0.45, 0.48)  # dimmer/desaturated
const COLOR_CONSTRAINED := Color(0.35, 0.85, 0.45)  # fully constrained sketch
const COLOR_CONFLICT := Color(0.95, 0.3, 0.25)  # entities in conflicting constraints
const COLOR_GLYPH := Color(0.65, 0.8, 1.0)
const COLOR_GLYPH_SELECTED := Color(1.0, 0.62, 0.15)
## Match 3D stretch-handle blue for endpoint drag affordance.
const COLOR_HANDLE := Color(0.25, 0.75, 1.0, 0.95)
## SolidWorks-style relation badges drawn next to the owning geometry.
## Dimensional constraints (distance/radius/angle) use the dim labels instead.
const GLYPH_SYMBOLS := {
	"horizontal": "H",
	"vertical": "V",
	"parallel": "∥",
	"perpendicular": "⊥",
	"equal": "=",
	"coincident": "◉",
	"point_on_line": "◇",
	"tangent": "⌒",
}
## Geometry within this distance of exact H/V or an existing endpoint gets an
## inferred constraint on creation (SolidWorks-style automatic relations).
const INFER_TOL := 0.5

## Automatic constraint inference on entity creation (H/V + coincident).
var infer_enabled := true
## Diagnostics from the most recent solve: -1 until first solve.
var last_dofs := -1
var last_solve_status := ""
## Constraint ids the solver reported as conflicting / redundant.
var last_conflicting: Array = []
var last_redundant: Array = []
## Entity ids involved in conflicting constraints (drawn red).
var _conflict_entities := {}

## Emitted after every solve so the toolbar DOF chip stays current.
signal solve_updated(dofs: int, solve_status: String, conflicts: int)
## Emitted when the SELECT tool clicks a dimension label (in-viewport edit).
signal dimension_edit_requested(index: int)


func _ready() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color.WHITE
	_line_material.vertex_color_use_as_albedo = true
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
	_draw_node = MeshInstance3D.new()
	_draw_node.material_override = _line_material
	add_child(_draw_node)
	_preview_node = MeshInstance3D.new()
	_preview_node.material_override = _preview_material
	add_child(_preview_node)
	_selected_material = StandardMaterial3D.new()
	_selected_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selected_material.albedo_color = COLOR_HANDLE
	_selected_node = MeshInstance3D.new()
	_selected_node.material_override = _selected_material
	add_child(_selected_node)
	_dimension_labels = Node3D.new()
	_dimension_labels.name = "DimensionLabels"
	add_child(_dimension_labels)
	_constraint_glyphs = Node3D.new()
	_constraint_glyphs.name = "ConstraintGlyphs"
	add_child(_constraint_glyphs)
	_infer_label = Label3D.new()
	_infer_label.name = "InferHint"
	_infer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_infer_label.fixed_size = true
	_infer_label.pixel_size = 0.004
	_infer_label.font_size = 24
	_infer_label.modulate = Color(1.0, 0.85, 0.3)
	_infer_label.visible = false
	add_child(_infer_label)


## Derive a sketch plane from a planar face. Prefers the real face normal from
## DocumentView tessellation when provided; falls back to axis-aligned bbox
## heuristics. Returns {ok, origin, normal, message}.
static func derive_face_plane(doc: SxDocument, face_id: String, body_id: String,
		face_normal: Vector3 = Vector3.ZERO) -> Dictionary:
	var ground := {
		"ok": false,
		"origin": Vector3.ZERO,
		"normal": Vector3(0, 0, 1),
		"message": "Sketch on ground (XY)",
	}
	if face_id == "" or body_id == "":
		return ground
	var face_bb: Dictionary = doc.measure_bbox(face_id)
	if face_bb.is_empty():
		ground["message"] = "Could not measure face — sketching on ground"
		return ground
	var fmn: Vector3 = face_bb["min"]
	var fmx: Vector3 = face_bb["max"]
	var extent := fmx - fmn
	var origin := (fmn + fmx) * 0.5
	var normal := Vector3.ZERO
	var axis := -1
	const EPS := 1e-6
	# Prefer tessellated face normal when available (supports rotated faces).
	if face_normal.length_squared() > 1e-8:
		normal = face_normal.normalized()
	elif extent.x < EPS:
		axis = 0
		normal = Vector3(1, 0, 0)
	elif extent.y < EPS:
		axis = 1
		normal = Vector3(0, 1, 0)
	elif extent.z < EPS:
		axis = 2
		normal = Vector3(0, 0, 1)
	else:
		ground["message"] = "Face not planar enough — sketching on ground"
		return ground
	var body_bb: Dictionary = doc.measure_bbox(body_id)
	if not body_bb.is_empty():
		var body_center: Vector3 = (body_bb["min"] + body_bb["max"]) * 0.5
		# Outward: pointing away from the body bbox center.
		if (origin - body_center).dot(normal) < 0.0:
			normal = -normal
	var axis_name := "%.2f,%.2f,%.2f" % [normal.x, normal.y, normal.z]
	if axis >= 0:
		if normal[axis] > 0.0:
			axis_name = ["+X", "+Y", "+Z"][axis]
		else:
			axis_name = ["-X", "-Y", "-Z"][axis]
	return {
		"ok": true,
		"origin": origin,
		"normal": normal,
		"message": "Sketch on face (plane %s @ origin %.1f,%.1f,%.1f)" % [
			axis_name, origin.x, origin.y, origin.z],
	}


## Unit normal of the current sketch plane (model space).
func plane_normal() -> Vector3:
	return plane_x.cross(plane_y).normalized()


## 2D AABB of all entities inflated by `pad_frac` (0.2 = 20% past extents).
## Returns {min, max, center, radius} or empty if no entities.
func sketch_extents(pad_frac := 0.2) -> Dictionary:
	if sketch == null:
		return {}
	var ids: PackedStringArray = sketch.entity_ids()
	if ids.is_empty():
		return {}
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in ids:
		var info: Dictionary = sketch.entity_info(id)
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				mn = mn.min(a).min(b)
				mx = mx.max(a).max(b)
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
			"point":
				var p: Vector2 = info.get("position", info.get("point", Vector2.ZERO))
				mn = mn.min(p)
				mx = mx.max(p)
	if not is_finite(mn.x):
		return {}
	var size := mx - mn
	var pad := size * pad_frac * 0.5
	pad.x = maxf(pad.x, 2.0)
	pad.y = maxf(pad.y, 2.0)
	mn -= pad
	mx += pad
	var mid2 := (mn + mx) * 0.5
	var center3 := to_model(mid2)
	var half := (mx - mn) * 0.5
	var radius := maxf(half.x, half.y) * 1.414
	return {"min": mn, "max": mx, "center": center3, "radius": maxf(radius, 5.0),
			"min2": mn, "max2": mx}


## Sketch 2D → model space.
func to_model(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


## Begin a sketch on the model-space plane (origin + normal). x_hint picks the
## in-plane X direction; pass ZERO for an automatic perpendicular (n × world-Z,
## or world-X when the normal is parallel to Z). Extrude follows this normal.
func begin(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO) -> void:
	editing_fid = ""
	_setup_plane(origin, normal, x_hint)
	sketch = SxSketch.new()
	sketch.set_plane(origin, plane_x, plane_y)
	_activate_session()
	status.emit("Sketch: Select · Line · Rect · Circle · Exit Sketch · Esc discard")


## New sketch on an explicit plane (3D path legs, UI movies).
func begin_on_plane(origin: Vector3, x_dir: Vector3, y_dir: Vector3) -> bool:
	if view == null or active:
		return false
	editing_fid = ""
	plane_origin = origin
	plane_x = x_dir.normalized()
	plane_y = y_dir.normalized()
	sketch = SxSketch.new()
	sketch.set_plane(origin, plane_x, plane_y)
	_activate_session()
	if view != null and view.has_method("refresh_sketch_pads"):
		view.refresh_sketch_pads("_active")
	status.emit("Sketch on plane — Exit Sketch to save")
	return true


## Reopen an existing Sketch feature for editing.
func begin_edit(fid: String) -> bool:
	if view == null or view.doc == null or fid == "":
		return false
	var loaded: SxSketch = view.doc.graph_get_sketch(fid)
	if loaded == null:
		status.emit("Could not load sketch feature")
		return false
	var pi: Dictionary = loaded.plane_info()
	if pi.is_empty():
		return false
	editing_fid = fid
	plane_origin = pi["origin"]
	plane_x = (pi["x_dir"] as Vector3).normalized()
	plane_y = (pi["y_dir"] as Vector3).normalized()
	sketch = loaded
	_activate_session()
	status.emit("Editing sketch — Exit Sketch to save · Esc discard")
	return true


func _setup_plane(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO) -> void:
	last_dofs = -1
	last_solve_status = ""
	plane_origin = origin
	var n := normal.normalized()
	var x := x_hint
	if x == Vector3.ZERO or absf(x.dot(n)) > 0.99:
		x = n.cross(Vector3(0, 0, 1))
		if x.length_squared() < 1e-12:
			x = Vector3.RIGHT
	plane_x = (x - n * x.dot(n)).normalized()
	plane_y = n.cross(plane_x).normalized()


func _activate_session() -> void:
	active = true
	tool = Tool.LINE
	_tool_points.clear()
	_drag.clear()
	dimensions.clear()
	intersection_points.clear()
	_clear_dimension_labels()
	_enter_camera()
	_redraw()


func _enter_camera() -> void:
	if camera == null:
		return
	var ext := sketch_extents(0.2)
	var center: Vector3 = plane_origin
	var radius := 25.0
	if not ext.is_empty():
		center = ext["center"]
		radius = float(ext["radius"])
	# Floor the working scale: a sketch framed on a 5 mm blank made screen
	# drags land as sub-millimetre segments (0.15 mm "lines").
	radius = maxf(radius, MIN_SKETCH_VIEW_RADIUS_MM)
	camera.enter_sketch_view(plane_normal(), center, radius, plane_y)
	_sketch_view_radius = radius
	# Re-assert after layout/resize handlers settle so nothing zooms us into
	# the 0.1 mm grid behind our back.
	call_deferred("_reassert_camera")


func _reassert_camera() -> void:
	if not active or camera == null:
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.size < MIN_SKETCH_VIEW_MM:
		var ext := sketch_extents(0.2)
		var center: Vector3 = ext["center"] if not ext.is_empty() else plane_origin
		var radius: float = float(ext["radius"]) if not ext.is_empty() else 25.0
		camera.enter_sketch_view(plane_normal(), center,
				maxf(radius, MIN_SKETCH_VIEW_RADIUS_MM), plane_y)


## Frame the sketch plane at a workable scale (mechanic "fit sketch").
func fit_view() -> void:
	if not active:
		return
	_enter_camera()
	status.emit("Sketch view fit")


## Approximate model-space width of the sketch view (mm) for status text.
func _view_span_mm() -> float:
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return maxf(camera.size, 1.0)
	return _sketch_view_radius * 2.0


func _leave_camera() -> void:
	if camera != null:
		camera.leave_sketch_view()


## Discard the session without committing (Esc).
func cancel() -> void:
	if not active:
		return
	active = false
	editing_fid = ""
	_tool_points.clear()
	_length_override = -1.0
	_snap_marker = null
	_drag.clear()
	intersection_points.clear()
	_clear_meshes()
	_leave_camera()
	cancelled.emit()


func set_dimensions_visible(on: bool) -> void:
	dimensions_visible = on
	if _dimension_labels != null:
		_dimension_labels.visible = on


## Commit the sketch feature (add or update) and leave sketch mode.
## Returns the sketch feature id ("" on failure / empty new sketch).
func exit_sketch() -> String:
	if not active or sketch == null:
		return ""
	var fid := ""
	if editing_fid != "":
		if view.doc.graph_update_sketch(editing_fid, sketch):
			fid = editing_fid
		else:
			status.emit("Failed to update sketch")
			return ""
	else:
		if sketch.entity_ids().is_empty():
			cancel()
			status.emit("Empty sketch discarded")
			return ""
		fid = view.doc.graph_add_sketch(sketch)
		if fid == "":
			status.emit("Failed to save sketch")
			return ""
	active = false
	editing_fid = ""
	_tool_points.clear()
	_snap_marker = null
	_drag.clear()
	intersection_points.clear()
	_clear_meshes()
	_leave_camera()
	if view != null:
		view.refresh()
		view.document_changed.emit()
	finished.emit("")
	status.emit("Sketch saved")
	return fid


## Finish the sketch and extrude by `distance` (model units). Routed through
## the feature graph: adds a sketch feature plus an extrude feature so both
## appear on the timeline and stay editable. op: "new" | "cut" | "fuse";
## cut/fuse require a target body (the one sketched on) and cut extrudes
## into the body (negated distance).
func finish_extrude(distance: float, op: String = "new", end: String = "blind",
		thin_thickness: float = 0.0, thin_type: String = "one_side",
		flip_side: bool = false, selected_contours: Array = []) -> void:
	if not active:
		return
	# Auto-commit an in-progress Polygon/Circle/Rect tip so Extrude doesn't
	# see only a preview ghost and report "open profile".
	if has_pending_draw_point():
		click(_hover)
	_try_close_open_chain()
	var open_prof := not profile_is_closed(sketch)
	if thin_thickness <= 0.0 and open_prof:
		if op == "cut" or op == "fuse":
			status.emit("Open-profile cut needs a line chain (Flip Side toggles material)")
		else:
			status.emit("Extrude failed — open profile. Close it (or set Thin wall > 0)")
		# Keep the sketch session alive so the mechanic can finish the outline.
		return
	if op != "new" and target_fid == "":
		status.emit("No target body — sketch on a face to cut/fuse")
		return
	if op == "cut":
		distance = -absf(distance)
	var symmetric := end == "midplane"
	var sk_fid := _ensure_sketch_feature()
	if sk_fid == "":
		return
	var ex_fid: String = view.doc.graph_add_extrude(
		sk_fid, distance, symmetric, op, target_fid if op != "new" else "", end,
		thin_thickness, thin_type, flip_side, selected_contours)
	var fail_msg := "Extrude failed — is the profile closed?"
	_finish_feature(sk_fid, ex_fid, op, fail_msg)


## Finish the sketch and revolve. The axis is the selected line when one is
## selected (select tool), otherwise the sketch Y axis through the origin.
func finish_revolve(angle: float = TAU, op: String = "new") -> void:
	if not active:
		return
	if op != "new" and target_fid == "":
		status.emit("No target body — sketch on a face to cut/fuse")
		return
	var axis_point := Vector2.ZERO
	var axis_dir := Vector2(0, 1)
	if selected.size() == 1:
		var info: Dictionary = sketch.entity_info(selected[0])
		if info.get("type", "") == "line":
			axis_point = info["start"]
			axis_dir = (info["end"] - info["start"]).normalized()
			sketch.set_construction(selected[0], true)
	var sk_fid := _ensure_sketch_feature()
	if sk_fid == "":
		return
	var rv_fid: String = view.doc.graph_add_revolve(
		sk_fid, axis_point, axis_dir, angle, op, target_fid if op != "new" else "")
	_finish_feature(sk_fid, rv_fid, op, "Revolve failed — closed profile on one side of the axis?")


## Ensure the active sketch is a graph feature; reuse editing_fid when set.
func _ensure_sketch_feature() -> String:
	if editing_fid != "":
		if not view.doc.graph_update_sketch(editing_fid, sketch):
			status.emit("Failed to update sketch")
			return ""
		return editing_fid
	var sk_fid: String = view.doc.graph_add_sketch(sketch)
	if sk_fid == "":
		status.emit("Failed to add sketch")
	else:
		editing_fid = sk_fid
	return sk_fid


func _finish_feature(sk_fid: String, feat_fid: String, op: String, fail_msg: String) -> void:
	if feat_fid == "":
		# Keep the sketch pad when extrude fails after an already-committed edit.
		if editing_fid != sk_fid:
			view.doc.graph_remove(sk_fid)
	var body_id: String
	if op == "new":
		body_id = view.body_of_feature(feat_fid)
	else:
		body_id = view.body_of_feature(target_fid) if feat_fid != "" else ""
	active = false
	editing_fid = ""
	_tool_points.clear()
	_clear_meshes()
	_leave_camera()
	if feat_fid == "":
		status.emit(fail_msg)
		cancelled.emit()
	else:
		view.refresh()
		view.document_changed.emit()
		view.select_entity(body_id, "")
		finished.emit(body_id)


## Model-space ray -> sketch 2D coords (null if parallel to plane).
func ray_to_sketch(origin: Vector3, direction: Vector3) -> Variant:
	var n := plane_x.cross(plane_y)
	var denom := direction.dot(n)
	if absf(denom) < 1e-9:
		return null
	var t := (plane_origin - origin).dot(n) / denom
	if t < 0:
		return null
	var p := origin + direction * t - plane_origin
	return Vector2(p.dot(plane_x), p.dot(plane_y))


signal tool_changed(tool: int)
## Emitted when selection chips should refresh (ids may be empty).
signal selection_actions_needed
## Live rubber-band distance (mm) while a single-DOF draw step is active.
signal preview_distance_changed(distance: float)


func set_tool(t: Tool) -> void:
	if not _drag.is_empty():
		end_drag()
	tool = t
	_tool_points.clear()
	_spline_pts.clear()
	_smart_dim_first = null
	_length_override = -1.0
	_trim_hover_id = ""
	_trim_dragging = false
	_trim_drag_ids.clear()
	draw_construction = (t == Tool.CENTERLINE)
	# Default variants per tool family (reset on tool switch so prior family
	# names like circle "center" don't silently become rect "center").
	match t:
		Tool.RECT:
			tool_variant = "corner"
		Tool.CIRCLE:
			tool_variant = "center"
		Tool.ARC:
			tool_variant = "center"
		Tool.PATTERN:
			tool_variant = "linear"
		_:
			pass
	# Do not clear selection on tool switch — completed geometry must stay
	# visible/selectable (polygon/circle vanishing after another tool was a bug).
	_update_preview()
	tool_changed.emit(int(t))


func set_tool_variant(v: String) -> void:
	tool_variant = v
	_tool_points.clear()
	_length_override = -1.0
	_update_preview()
	status.emit("Variant: %s" % v.replace("_", " "))


## True when a draw tool has the first anchor and is waiting for the tip.
func has_pending_draw_point() -> bool:
	match tool:
		Tool.LINE, Tool.CENTERLINE, Tool.CIRCLE, Tool.RECT, Tool.POLYGON, \
				Tool.SLOT, Tool.ELLIPSE, Tool.ARC:
			return _tool_points.size() == 1
		_:
			return false


## If the sketch is a single open polyline whose ends nearly meet, add a
## closing segment so Extrude can build a solid (wrench outline, etc.).
func _try_close_open_chain(tol: float = 0.5) -> void:
	if sketch == null or profile_is_closed(sketch, tol):
		return
	var ends: Array = []  # unmatched endpoints
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		if a.distance_to(b) <= 1e-9:
			continue
		ends.append(a)
		ends.append(b)
	# Pair endpoints that coincide; leftovers are open ends.
	var used := {}
	var open_pts: Array[Vector2] = []
	for i in range(ends.size()):
		if used.has(i):
			continue
		var matched := false
		for j in range(i + 1, ends.size()):
			if used.has(j):
				continue
			if ends[i].distance_to(ends[j]) <= tol:
				used[i] = true
				used[j] = true
				matched = true
				break
		if not matched:
			open_pts.append(ends[i])
	if open_pts.size() == 2 and open_pts[0].distance_to(open_pts[1]) <= maxf(tol * 8.0, 5.0):
		var lid: String = sketch.add_line(open_pts[0].x, open_pts[0].y,
				open_pts[1].x, open_pts[1].y)
		_infer_line(lid, open_pts[0], open_pts[1])
		_redraw()
		status.emit("Closed open profile for Extrude")


## True when the current tool step has exactly one free length/radius DOF
## (line from last anchor, center-circle radius, polygon radius, slot length,
## or center-arc radius after the center click).
func has_single_dof_preview() -> bool:
	if _tool_points.is_empty():
		return false
	match tool:
		Tool.LINE, Tool.CENTERLINE, Tool.POLYGON, Tool.SLOT:
			return true
		Tool.CIRCLE:
			return tool_variant == "center" and _tool_points.size() == 1
		Tool.ARC:
			return tool_variant == "center" and _tool_points.size() == 1
		_:
			return false


## Rubber-band length currently shown (override or mouse distance).
func preview_distance() -> float:
	if not has_single_dof_preview():
		return 0.0
	if _length_override >= 0.0:
		return _length_override
	return _tool_points[_tool_points.size() - 1].distance_to(_hover)


## Lock rubber-band length; mouse keeps steering direction.
func set_length_override(v: float) -> void:
	_length_override = maxf(v, 0.01)
	_update_preview()
	preview_distance_changed.emit(_length_override)


func clear_length_override() -> void:
	if _length_override < 0.0:
		return
	_length_override = -1.0
	_update_preview()
	if has_single_dof_preview():
		preview_distance_changed.emit(preview_distance())


func has_length_override() -> bool:
	return _length_override >= 0.0


## Hover / preview endpoint: mouse when free; last + dir×override when locked.
func effective_hover() -> Vector2:
	if _length_override < 0.0 or not has_single_dof_preview():
		return _hover
	var last: Vector2 = _tool_points[_tool_points.size() - 1]
	var d := _hover - last
	if d.length_squared() < 1e-12:
		return last + Vector2(_length_override, 0.0)
	return last + d.normalized() * _length_override


## Commit the next click at `length` along the current hover direction.
## Returns false when no single-DOF preview is active.
func commit_at_length(length: float) -> bool:
	if not has_single_dof_preview():
		return false
	set_length_override(length)
	click(effective_hover())
	return true


func variants_for_tool(t: Tool = tool) -> Array:
	match t:
		Tool.RECT:
			return ["corner", "center", "three_point", "parallelogram"]
		Tool.CIRCLE:
			return ["center", "perimeter", "three_point"]
		Tool.ARC:
			return ["center", "tangent", "three_point"]
		Tool.PATTERN:
			return ["linear", "circular"]
		Tool.LINE, Tool.CENTERLINE:
			return ["line", "centerline"]
		Tool.POLYGON:
			return ["vertex", "across_flats"]
		_:
			return []


func selection_actions() -> Array:
	var acts: Array = []
	if selected.is_empty():
		return acts
	acts.append("construction")
	acts.append("delete")
	if selected.size() == 2:
		var t0: String = sketch.entity_info(selected[0]).get("type", "")
		var t1: String = sketch.entity_info(selected[1]).get("type", "")
		if t0 == "line" and t1 == "line":
			acts.append("fillet")
			acts.append("chamfer")
		acts.append_array(["horizontal", "vertical", "parallel", "perpendicular",
				"equal", "coincident", "tangent", "midpoint", "symmetric"])
	if selected.size() >= 1:
		acts.append("offset")
		acts.append("pattern")
		acts.append("mirror")
		acts.append("block")
		acts.append("split")
	return acts


func set_snap(on: bool) -> void:
	snap_enabled = on
	if not on:
		_snap_marker = null


func set_infer(on: bool) -> void:
	infer_enabled = on
	if not on and _infer_label != null:
		_infer_label.visible = false


## Snap sketch-plane point to nearby geometry / axis. Priority:
## (a) entity endpoints, (b) line midpoints & circle/arc centers, (c) H/V
## alignment to the last in-progress tool point. When snap_enabled is false,
## returns p unchanged.
func snap_point(p: Vector2) -> Vector2:
	_snap_marker = null
	if not snap_enabled or sketch == null:
		return p
	# (a) endpoints
	var best_d := SNAP_RADIUS
	var best_pt := p
	var found := false
	for id in sketch.entity_ids():
		for ep in _snap_endpoints(id):
			var d := p.distance_to(ep)
			if d <= best_d:
				best_d = d
				best_pt = ep
				found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# (b) midpoints and centers
	best_d = SNAP_RADIUS
	found = false
	for id in sketch.entity_ids():
		for mp in _snap_mid_centers(id):
			var d2 := p.distance_to(mp)
			if d2 <= best_d:
				best_d = d2
				best_pt = mp
				found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# (b2) pierce / coincident points from other geometry on this plane
	best_d = SNAP_RADIUS
	found = false
	for ip in intersection_points:
		var d_ip: float = p.distance_to(ip)
		if d_ip <= best_d:
			best_d = d_ip
			best_pt = ip
			found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# (c) axis alignment from last committed tool point
	if not _tool_points.is_empty():
		var last: Vector2 = _tool_points[_tool_points.size() - 1]
		var out := p
		var snapped_axis := false
		if absf(p.x - last.x) <= SNAP_RADIUS:
			out.x = last.x
			snapped_axis = true
		if absf(p.y - last.y) <= SNAP_RADIUS:
			out.y = last.y
			snapped_axis = true
		if snapped_axis:
			_snap_marker = out
			return out
	return p


func _snap_endpoints(id: String) -> Array[Vector2]:
	var info: Dictionary = sketch.entity_info(id)
	var out: Array[Vector2] = []
	match info.get("type", ""):
		"line":
			out.append(info["start"])
			out.append(info["end"])
		"arc":
			var c: Vector2 = info["center"]
			var r: float = info["radius"]
			out.append(c + Vector2.from_angle(info["start_angle"]) * r)
			out.append(c + Vector2.from_angle(info["end_angle"]) * r)
		"point":
			out.append(info["position"])
	return out


func _snap_mid_centers(id: String) -> Array[Vector2]:
	var info: Dictionary = sketch.entity_info(id)
	var out: Array[Vector2] = []
	match info.get("type", ""):
		"line":
			out.append((info["start"] + info["end"]) * 0.5)
		"circle", "arc":
			out.append(info["center"])
	return out


# --- selection & constraints ---

func _set_selected(ids: Array[String]) -> void:
	selected = ids
	_redraw_selected()
	selection_changed.emit(selected)
	selection_actions_needed.emit()


## Select every sketch entity (Ctrl+A). Returns count selected.
func select_all_entities() -> int:
	if sketch == null:
		return 0
	var ids: Array[String] = []
	for id in sketch.entity_ids():
		ids.append(id)
	_set_selected(ids)
	return ids.size()


## Nearest entity id within PICK_TOLERANCE of pos2, or "" if none.
func _nearest_entity_at(pos2: Vector2) -> String:
	var best_id := ""
	var best_d := PICK_TOLERANCE
	for id in sketch.entity_ids():
		var d := _entity_distance(sketch.entity_info(id), pos2)
		if d < best_d:
			best_d = d
			best_id = id
	return best_id


func _select_at(pos2: Vector2) -> void:
	var best_id := _nearest_entity_at(pos2)
	if best_id == "":
		_set_selected([])
		return
	var ids := selected.duplicate()
	if ids.has(best_id):
		ids.erase(best_id)  # click again to deselect
	else:
		ids.append(best_id)
		# Soft cap so relation chips stay usable; Mirror/Pattern need 2+.
		while ids.size() > 8:
			ids.pop_front()
	_set_selected(ids)


func _entity_distance(info: Dictionary, p: Vector2) -> float:
	match info.get("type", ""):
		"line":
			return _point_segment_distance(p, info["start"], info["end"])
		"circle", "arc":
			return absf(p.distance_to(info["center"]) - info["radius"])
		"point":
			return p.distance_to(info["position"])
	return INF


func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- drag-to-edit (SELECT tool) ---

## Hit-test for drag handles. Returns {} or {id, part} where part is
## "start"|"end"|"whole"|"center"|"radius". Endpoints/centers win within
## PICK_TOLERANCE; otherwise the nearest curve within tolerance ("whole" /
## "radius").
func drag_hit(pos2: Vector2) -> Dictionary:
	if sketch == null:
		return {}
	var best_id := ""
	var best_part := ""
	var best_d := PICK_TOLERANCE
	# Pass 1: endpoints / centers
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		match info.get("type", ""):
			"line":
				for pair in [["start", info["start"]], ["end", info["end"]]]:
					var d: float = pos2.distance_to(pair[1])
					if d <= best_d:
						best_d = d
						best_id = id
						best_part = pair[0]
			"circle", "arc":
				var d2: float = pos2.distance_to(info["center"])
				if d2 <= best_d:
					best_d = d2
					best_id = id
					best_part = "center"
	if best_id != "":
		return {"id": best_id, "part": best_part}
	# Pass 2: whole entity / rim
	best_d = PICK_TOLERANCE
	for id in sketch.entity_ids():
		var info2: Dictionary = sketch.entity_info(id)
		var d3 := _entity_distance(info2, pos2)
		if d3 <= best_d:
			best_d = d3
			best_id = id
			match info2.get("type", ""):
				"line":
					best_part = "whole"
				"circle", "arc":
					best_part = "radius"
				_:
					best_part = "whole"
	if best_id == "":
		return {}
	return {"id": best_id, "part": best_part}


## Start a SELECT-tool drag at pos2. No-op when inactive, wrong tool, or miss.
func begin_drag(pos2: Vector2) -> void:
	if not active or tool != Tool.SELECT or sketch == null:
		return
	var hit := drag_hit(pos2)
	if hit.is_empty():
		return
	var info: Dictionary = sketch.entity_info(hit["id"])
	if info.is_empty():
		return
	_drag = {
		"id": hit["id"],
		"part": hit["part"],
		"grab_pos": pos2,
		"orig_info": info.duplicate(true),
		"preview_info": info.duplicate(true),
	}
	_update_preview()


## Update an active drag: write the new geometry into the kernel and re-solve
## so constraints pull the rest of the sketch along live. The dragged shape is
## also drawn in the preview color as a "grabbed" highlight.
func update_drag(pos2: Vector2) -> void:
	if _drag.is_empty():
		return
	var target := _drag_preview_at(pos2)
	_drag["preview_info"] = target
	sketch.set_entity_geometry(_drag["id"], target)
	run_solve()
	_redraw()
	_rebuild_dimension_labels()
	_update_preview()


## End the active drag. A failed solve reverts to the pre-drag geometry.
func end_drag() -> void:
	if _drag.is_empty():
		return
	if last_solve_status == "failed":
		sketch.set_entity_geometry(_drag["id"], _drag["orig_info"])
		run_solve()
		status.emit("Drag reverted: constraints could not be satisfied")
	_drag.clear()
	_redraw()
	_rebuild_dimension_labels()
	_update_preview()


func _drag_preview_at(pos2: Vector2) -> Dictionary:
	var orig: Dictionary = _drag["orig_info"]
	var part: String = _drag["part"]
	var grab: Vector2 = _drag["grab_pos"]
	var delta := pos2 - grab
	var out: Dictionary = orig.duplicate(true)
	match part:
		"start":
			out["start"] = orig["start"] + delta
		"end":
			out["end"] = orig["end"] + delta
		"whole", "center":
			if orig.get("type", "") == "line":
				out["start"] = orig["start"] + delta
				out["end"] = orig["end"] + delta
			else:
				out["center"] = orig["center"] + delta
				# Arcs carry explicit start/end points; keep them attached.
				if orig.has("start"):
					out["start"] = orig["start"] + delta
				if orig.has("end"):
					out["end"] = orig["end"] + delta
		"radius":
			var c: Vector2 = orig["center"]
			out["radius"] = maxf(c.distance_to(pos2), 1e-6)
	return out


func _append_entity_lines(im: ImmediateMesh, info: Dictionary) -> void:
	match info.get("type", ""):
		"line":
			im.surface_add_vertex(_to3(info["start"]))
			im.surface_add_vertex(_to3(info["end"]))
		"circle":
			var c: Vector2 = info["center"]
			var r: float = info["radius"]
			var steps := 48
			for i in range(steps):
				var a0 := TAU * i / steps
				var a1 := TAU * (i + 1) / steps
				im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
				im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
		"arc":
			var c2: Vector2 = info["center"]
			var r2: float = info["radius"]
			var s: float = info["start_angle"]
			var e: float = info["end_angle"]
			if e < s:
				e += TAU
			var steps2 := 32
			for i in range(steps2):
				var a0 := s + (e - s) * i / steps2
				var a1 := s + (e - s) * (i + 1) / steps2
				im.surface_add_vertex(_to3(c2 + Vector2(cos(a0), sin(a0)) * r2))
				im.surface_add_vertex(_to3(c2 + Vector2(cos(a1), sin(a1)) * r2))


## Length of a line / radius of a circle/arc / distance between two entities.
## Uses `ids` when non-empty; otherwise the current selection. 0 when N/A.
func measured_value(ids: Array = []) -> float:
	if sketch == null:
		return 0.0
	var sel: Array = ids if not ids.is_empty() else selected
	if sel.size() == 1:
		var info: Dictionary = sketch.entity_info(str(sel[0]))
		match info.get("type", ""):
			"line":
				return (info["end"] - info["start"]).length()
			"circle", "arc":
				return info["radius"]
	elif sel.size() == 2:
		var pair := _closest_endpoints(str(sel[0]), str(sel[1]))
		if pair.size() == 2:
			return _endpoint_pos(str(sel[0]), pair[0]).distance_to(
				_endpoint_pos(str(sel[1]), pair[1]))
	return 0.0


## Applies a constraint to the current selection. Supported types:
## horizontal/vertical (each selected line), parallel/perpendicular/equal
## (two entities), coincident (nearest endpoints of two lines), distance
## (line length, or nearest endpoints of two entities), radius (circle/arc).
## Solves afterwards; returns the solve status string ("" when nothing done).
func constrain(type: String, value: float = 0.0) -> String:
	if not active or selected.is_empty():
		return ""
	var added := false
	var cid := ""  # id of the (last) constraint added, kept for editable dims
	match type:
		"horizontal", "vertical":
			for id in selected:
				if sketch.entity_info(id).get("type", "") == "line":
					cid = sketch.add_constraint(type, [{"entity": id, "role": "self"}], 0.0)
					added = true
		"parallel", "perpendicular", "equal":
			if selected.size() == 2:
				cid = sketch.add_constraint(type, [
					{"entity": selected[0], "role": "self"},
					{"entity": selected[1], "role": "self"}], 0.0)
				added = true
		"coincident":
			if selected.size() == 2:
				var pair := _closest_endpoints(selected[0], selected[1])
				if pair.size() == 2:
					cid = sketch.add_constraint("coincident", [
						{"entity": selected[0], "role": pair[0]},
						{"entity": selected[1], "role": pair[1]}], 0.0)
					added = true
		"distance":
			if selected.size() == 1 and sketch.entity_info(selected[0]).get("type", "") == "line":
				cid = sketch.add_constraint("distance", [
					{"entity": selected[0], "role": "start"},
					{"entity": selected[0], "role": "end"}], value)
				added = true
			elif selected.size() == 2:
				var pair2 := _closest_endpoints(selected[0], selected[1])
				if pair2.size() == 2:
					cid = sketch.add_constraint("distance", [
						{"entity": selected[0], "role": pair2[0]},
						{"entity": selected[1], "role": pair2[1]}], value)
					added = true
		"radius":
			for id in selected:
				var k: String = sketch.entity_info(id).get("type", "")
				if k == "circle" or k == "arc":
					cid = sketch.add_constraint("radius", [{"entity": id, "role": "self"}], value)
					added = true
		"tangent", "angle", "point_on_line":
			if selected.size() == 2:
				cid = sketch.add_constraint(type, [
					{"entity": selected[0], "role": "self"},
					{"entity": selected[1], "role": "self"}], value)
				added = true
		"concentric":
			# Coincident circle/arc centers.
			if selected.size() == 2:
				cid = sketch.add_constraint("coincident", [
					{"entity": selected[0], "role": "center"},
					{"entity": selected[1], "role": "center"}], 0.0)
				added = true
		"midpoint":
			# Point on midpoint of line: point_on_line + equal end distances via coincident helper point.
			if selected.size() == 2:
				var line_id := selected[0]
				var pt_id := selected[1]
				if sketch.entity_info(line_id).get("type") != "line":
					line_id = selected[1]
					pt_id = selected[0]
				if sketch.entity_info(line_id).get("type") == "line":
					cid = sketch.add_constraint("point_on_line", [
						{"entity": pt_id, "role": "self"},
						{"entity": line_id, "role": "self"}], 0.0)
					# Equal distance to both endpoints → midpoint.
					sketch.add_constraint("distance", [
						{"entity": pt_id, "role": "self"},
						{"entity": line_id, "role": "start"}], value if value > 0 else 1.0)
					# Use equal-length trick: two distance constraints with same value solved by user dim — skip second.
					added = true
		"symmetric":
			status.emit("Symmetric: select two entities then a mirror line (use Mirror tool)")
		"collinear":
			if selected.size() == 2:
				cid = sketch.add_constraint("parallel", [
					{"entity": selected[0], "role": "self"},
					{"entity": selected[1], "role": "self"}], 0.0)
				# Also coincident one endpoint onto the other line.
				sketch.add_constraint("point_on_line", [
					{"entity": selected[0], "role": "start"},
					{"entity": selected[1], "role": "self"}], 0.0)
				added = true
		"fix":
			# Soft fix: lock a line by horizontal+vertical is wrong; emit status.
			status.emit("Fix relation: use dimensions to lock geometry (v1)")
	if not added:
		return ""
	# Record dimensional constraints (distance/radius, or any with a numeric value).
	if type == "distance" or type == "radius" or type == "angle" or absf(value) > 0.0:
		_record_dimension(type, selected.duplicate(), value, cid)
	var res: Dictionary = run_solve()
	_redraw()
	_redraw_selected()
	return res["status"]


func _record_dimension(type: String, ids: Array, value: float, cid: String = "") -> void:
	var id_list: Array = []
	for id in ids:
		id_list.append(str(id))
	for i in range(dimensions.size()):
		var d: Dictionary = dimensions[i]
		if d.get("type", "") != type:
			continue
		var existing: Array = d.get("ids", [])
		if existing.size() == id_list.size():
			var same := true
			for j in range(id_list.size()):
				if str(existing[j]) != id_list[j]:
					same = false
					break
			if same:
				dimensions[i] = {"type": type, "ids": id_list, "value": value,
					"cid": cid if cid != "" else d.get("cid", "")}
				return
	dimensions.append({"type": type, "ids": id_list, "value": value, "cid": cid})


## Fillet the corner shared by two selected lines. Requires exactly two selected
## line entities. Returns the new arc id, or "" on failure (emits status).
func fillet_selected(radius: float) -> String:
	if not active or selected.size() != 2:
		status.emit("Fillet needs exactly 2 selected lines")
		return ""
	for id in selected:
		if sketch.entity_info(id).get("type", "") != "line":
			status.emit("Fillet needs exactly 2 selected lines")
			return ""
	var arc_id: String = sketch.fillet_corner(selected[0], selected[1], radius)
	if arc_id == "":
		status.emit("Fillet failed")
		return ""
	run_solve()
	_redraw()
	_redraw_selected()
	return arc_id


## Offset all selected entities by signed distance. Returns new entity ids.
func offset_selected(distance: float) -> Array:
	if not active or selected.is_empty():
		status.emit("Offset needs a selection")
		return []
	var ids := PackedStringArray()
	for id in selected:
		ids.append(id)
	var new_ids: PackedStringArray = sketch.offset_entities(ids, distance)
	if new_ids.is_empty():
		status.emit("Offset failed")
		return []
	_redraw()
	_redraw_selected()
	var out: Array = []
	for id in new_ids:
		out.append(id)
	return out


## Extend the entity nearest to pos2 to the next intersection.
func extend_at(pos2: Vector2) -> bool:
	if not active or sketch == null:
		return false
	var id := _nearest_entity_at(pos2)
	if id == "":
		status.emit("Extend: click a line")
		return false
	if not sketch.extend_entity(id, pos2.x, pos2.y):
		status.emit("Extend failed — no forward intersection")
		return false
	run_solve()
	_redraw()
	return true


## Linear or circular pattern of the selection.
func pattern_selected(dx: float, dy: float, count: int) -> Array:
	if not active or selected.is_empty():
		status.emit("Pattern needs a selection")
		return []
	var ids := PackedStringArray()
	for id in selected:
		ids.append(id)
	var new_ids: PackedStringArray
	if tool_variant == "circular":
		# Approximate circular pattern as rotated copies about selection centroid.
		var c := _selection_centroid()
		new_ids = PackedStringArray()
		for i in range(1, count):
			var ang := TAU * float(i) / float(count)
			var ca := cos(ang)
			var sa := sin(ang)
			for id in ids:
				var info: Dictionary = sketch.entity_info(id)
				_add_rotated_copy(info, c, ca, sa, new_ids)
	else:
		new_ids = sketch.pattern_entities(ids, dx, dy, count)
	if new_ids.is_empty():
		status.emit("Pattern failed")
		return []
	_redraw()
	var out: Array = []
	for id2 in new_ids:
		out.append(id2)
	return out


func _selection_centroid() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for id in selected:
		for ep in _snap_endpoints(id):
			sum += ep
			n += 1
	return sum / float(n) if n > 0 else Vector2.ZERO


func _add_rotated_copy(info: Dictionary, c: Vector2, ca: float, sa: float,
		out_ids: PackedStringArray) -> void:
	var rot := func(p: Vector2) -> Vector2:
		var d := p - c
		return c + Vector2(d.x * ca - d.y * sa, d.x * sa + d.y * ca)
	match str(info.get("type", "")):
		"line":
			var a: Vector2 = rot.call(info["start"])
			var b: Vector2 = rot.call(info["end"])
			out_ids.append(sketch.add_line(a.x, a.y, b.x, b.y))
		"circle":
			var ctr: Vector2 = rot.call(info["center"])
			out_ids.append(sketch.add_circle(ctr.x, ctr.y, float(info["radius"])))
		"arc":
			var ctr2: Vector2 = rot.call(info["center"])
			out_ids.append(sketch.add_arc(ctr2.x, ctr2.y, float(info["radius"]),
					float(info["start_angle"]) + atan2(sa, ca),
					float(info["end_angle"]) + atan2(sa, ca)))
		"point":
			var p: Vector2 = rot.call(info.get("position", Vector2.ZERO))
			out_ids.append(sketch.add_point(p.x, p.y))


## Mirror selected entities about a selected line axis (or sketch Y if none).
func mirror_selected() -> Array:
	if selected.is_empty():
		status.emit("Mirror needs a selection")
		return []
	var axis_id := ""
	var geo_ids: Array[String] = []
	for id in selected:
		if sketch.entity_info(id).get("type", "") == "line" and axis_id == "":
			axis_id = id
		else:
			geo_ids.append(id)
	if axis_id == "" or geo_ids.is_empty():
		# Use last selected line as axis if two+ lines.
		status.emit("Mirror: select geometry plus one axis line")
		return []
	var ainfo: Dictionary = sketch.entity_info(axis_id)
	var a0: Vector2 = ainfo["start"]
	var a1: Vector2 = ainfo["end"]
	var ad := (a1 - a0).normalized()
	var an := Vector2(-ad.y, ad.x)
	var out: Array = []
	for id in geo_ids:
		var info: Dictionary = sketch.entity_info(id)
		var refl := func(p: Vector2) -> Vector2:
			var d := p - a0
			var along := ad * d.dot(ad)
			var across := an * d.dot(an)
			return a0 + along - across
		match str(info.get("type", "")):
			"line":
				var s: Vector2 = refl.call(info["start"])
				var e: Vector2 = refl.call(info["end"])
				out.append(sketch.add_line(s.x, s.y, e.x, e.y))
			"circle":
				var ctr: Vector2 = refl.call(info["center"])
				out.append(sketch.add_circle(ctr.x, ctr.y, float(info["radius"])))
			"point":
				var p: Vector2 = refl.call(info.get("position", Vector2.ZERO))
				out.append(sketch.add_point(p.x, p.y))
			"arc":
				var ctr2: Vector2 = refl.call(info["center"])
				out.append(sketch.add_arc(ctr2.x, ctr2.y, float(info["radius"]),
						-float(info["end_angle"]), -float(info["start_angle"])))
	_redraw()
	return out


## Convert pierce / edge intersection points into sketch points (and optional lines).
func convert_pierce_points() -> int:
	var n := 0
	for ip in intersection_points:
		sketch.add_point(ip.x, ip.y)
		n += 1
	if n == 0:
		status.emit("Convert: no pierce points on this plane")
	else:
		status.emit("Converted %d pierce points" % n)
		_redraw()
	return n


## Sketch chamfer: trim two lines and add a connecting segment.
func chamfer_selected(distance: float) -> String:
	if selected.size() != 2:
		status.emit("Chamfer needs 2 lines")
		return ""
	# Approximate: fillet with tiny radius then replace arc with line — simpler:
	# offset endpoints along each line by distance and connect.
	var ia: Dictionary = sketch.entity_info(selected[0])
	var ib: Dictionary = sketch.entity_info(selected[1])
	if ia.get("type") != "line" or ib.get("type") != "line":
		status.emit("Chamfer needs 2 lines")
		return ""
	# Find shared corner.
	var pts_a := [ia["start"], ia["end"]]
	var pts_b := [ib["start"], ib["end"]]
	var corner: Variant = null
	var a_other: Vector2
	var b_other: Vector2
	for pa in pts_a:
		for pb in pts_b:
			if pa.distance_to(pb) < 1e-3:
				corner = pa
				a_other = pts_a[1] if pa.distance_to(pts_a[0]) < 1e-3 else pts_a[0]
				b_other = pts_b[1] if pb.distance_to(pts_b[0]) < 1e-3 else pts_b[0]
	if corner == null:
		status.emit("Chamfer: lines must share a corner")
		return ""
	var c: Vector2 = corner
	var da := (a_other - c).normalized() * distance
	var db := (b_other - c).normalized() * distance
	var p1 := c + da
	var p2 := c + db
	# Shorten both lines to the chamfer points.
	sketch.set_entity_geometry(selected[0], {"start": p1, "end": a_other})
	sketch.set_entity_geometry(selected[1], {"start": p2, "end": b_other})
	var cid: String = sketch.add_line(p1.x, p1.y, p2.x, p2.y)
	run_solve()
	_redraw()
	return cid


## Group selection into a named sketch block.
func create_block(block_name: String) -> bool:
	if selected.is_empty() or block_name == "":
		return false
	var ids := PackedStringArray()
	for id in selected:
		ids.append(id)
	blocks[block_name] = ids
	status.emit("Block “%s” (%d entities)" % [block_name, ids.size()])
	return true


## Place a fit polyline spline through successive clicks (commit with end_chain).
func _commit_spline() -> void:
	if _spline_pts.size() < 2:
		_spline_pts.clear()
		return
	# Commit as a kernel spline entity (fit points), not an approximated polyline.
	# Preview continues to use a densified Catmull-Rom for on-canvas feedback.
	var fit: PackedVector2Array = []
	for p in _spline_pts:
		fit.push_back(p)
	if fit.size() >= 2:
		sketch.add_spline(fit)
	_spline_pts.clear()
	_redraw()


## Dense polyline approximation of a fit spline (Catmull-Rom samples).
func _densify_fit_spline(pts: Array[Vector2]) -> Array[Vector2]:
	var densified: Array[Vector2] = []
	if pts.size() < 2:
		return densified
	if pts.size() == 2:
		return pts.duplicate()
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for s in range(8):
			var t := float(s) / 8.0
			densified.append(_catmull(p0, p1, p2, p3, t))
	densified.append(pts[pts.size() - 1])
	return densified


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Trim the entity nearest to pos2 at its intersections. Returns true on success.
func trim_at(pos2: Vector2) -> bool:
	if not active or sketch == null:
		status.emit("Trim failed")
		return false
	var id := _nearest_entity_at(pos2)
	if id == "":
		status.emit("Trim failed")
		return false
	if not sketch.trim_entity(id, pos2.x, pos2.y):
		status.emit("Trim failed")
		return false
	run_solve()
	# Drop selection entries that no longer exist after a replace-style trim.
	var alive: Array[String] = []
	for sid in selected:
		if not sketch.entity_info(sid).is_empty():
			alive.append(sid)
	if alive.size() != selected.size():
		_set_selected(alive)
	_redraw()
	_redraw_selected()
	status.emit("Trimmed")
	return true


## Flip construction flag on all selected entities and redraw (construction
## entities use a dimmer gray so the style persists across redraws).
func toggle_construction_selected() -> void:
	if not active or selected.is_empty():
		status.emit("Select entities to toggle construction")
		return
	var any_on := false
	for id in selected:
		var on := not sketch.is_construction(id)
		sketch.set_construction(id, on)
		if on:
			any_on = true
	_redraw()
	_redraw_selected()
	status.emit("Construction " + ("on" if any_on else "off"))


func _endpoint_pos(id: String, role: String) -> Vector2:
	var info: Dictionary = sketch.entity_info(id)
	match info.get("type", ""):
		"line":
			return info["start"] if role == "start" else info["end"]
		"circle", "arc":
			return info["center"]
	return info.get("position", Vector2.ZERO)


## Roles of the closest endpoint pair between two entities (["end","start"]...).
func _closest_endpoints(id_a: String, id_b: String) -> Array[String]:
	var roles_for := func(id: String) -> Array[String]:
		var k: String = sketch.entity_info(id).get("type", "")
		var out: Array[String] = []
		if k == "line":
			out.assign(["start", "end"])
		elif k == "circle" or k == "arc":
			out.assign(["center"])
		else:
			out.assign(["self"])
		return out
	var best := INF
	var pair: Array[String] = []
	for ra: String in roles_for.call(id_a):
		for rb: String in roles_for.call(id_b):
			var d := _endpoint_pos(id_a, ra).distance_to(_endpoint_pos(id_b, rb))
			if d < best:
				best = d
				pair = [ra, rb]
	return pair


func _redraw_selected() -> void:
	if sketch == null or selected.is_empty():
		_selected_node.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in selected:
		var info: Dictionary = sketch.entity_info(id)
		match info.get("type", ""):
			"line":
				im.surface_add_vertex(_to3(info["start"]))
				im.surface_add_vertex(_to3(info["end"]))
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = info["radius"]
				for i in range(48):
					im.surface_add_vertex(_to3(c + Vector2.from_angle(TAU * i / 48.0) * r))
					im.surface_add_vertex(_to3(c + Vector2.from_angle(TAU * (i + 1) / 48.0) * r))
	im.surface_end()
	_selected_node.mesh = im


func click(pos2: Vector2) -> void:
	if not active:
		return
	# TRIM/EXTEND need the raw pick along the curve; snap would pull away.
	if tool != Tool.TRIM and tool != Tool.EXTEND:
		pos2 = snap_point(pos2)
	# Typed length wins over snap: keep direction toward the pick, lock distance.
	if _length_override >= 0.0 and has_single_dof_preview():
		var last: Vector2 = _tool_points[_tool_points.size() - 1]
		var d := pos2 - last
		if d.length_squared() < 1e-12:
			pos2 = last + Vector2(_length_override, 0.0)
		else:
			pos2 = last + d.normalized() * _length_override
		_length_override = -1.0
	match tool:
		Tool.SELECT:
			var chit := constraint_hit(pos2)
			if chit != "":
				select_constraint(chit)
				return
			if selected_constraint != "":
				select_constraint("")
			var dhit := dimension_hit(pos2)
			if dhit >= 0:
				dimension_edit_requested.emit(dhit)
				return
			_select_at(pos2)
			selection_actions_needed.emit()
		Tool.TRIM:
			trim_at(pos2)
		Tool.EXTEND:
			extend_at(pos2)
		Tool.LINE, Tool.CENTERLINE:
			if not _tool_points.is_empty():
				var prev: Vector2 = _tool_points[_tool_points.size() - 1]
				if prev.distance_to(pos2) < MIN_SEGMENT_MM:
					status.emit("Too short — drag further (view is %.0f mm across)" % _view_span_mm())
					return
			_tool_points.append(pos2)
			if _tool_points.size() >= 2:
				var a := _tool_points[_tool_points.size() - 2]
				var b := _tool_points[_tool_points.size() - 1]
				var lid: String = sketch.add_line(a.x, a.y, b.x, b.y)
				if draw_construction or tool == Tool.CENTERLINE:
					sketch.set_construction(lid, true)
				_infer_line(lid, a, b)
				_redraw()
				# Propose chips follow new geometry even when infer did not solve.
				selection_actions_needed.emit()
		Tool.RECT:
			_click_rect(pos2)
		Tool.CIRCLE:
			_click_circle(pos2)
		Tool.ARC:
			_click_arc(pos2)
		Tool.POLYGON:
			if not _tool_points.is_empty() \
					and _tool_points[0].distance_to(pos2) < MIN_SEGMENT_MM:
				status.emit("Too small — drag further (view is %.0f mm across)" % _view_span_mm())
				return
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				var c := _tool_points[0]
				var vertex := _tool_points[1]
				var r := c.distance_to(vertex)
				# Across-flats: drag distance is AF; circumradius R = AF / √3.
				var start_angle := (vertex - c).angle()
				if tool_variant == "across_flats":
					r = r / sqrt(3.0)
					start_angle = deg_to_rad(30.0)
					polygon_sides = 6
				if r > 1e-6:
					var n := polygon_sides
					var verts: Array[Vector2] = []
					for i in range(n):
						var ang := start_angle + TAU * float(i) / float(n)
						verts.append(c + Vector2(cos(ang), sin(ang)) * r)
					var lids: Array[String] = []
					for i in range(n):
						var va: Vector2 = verts[i]
						var vb: Vector2 = verts[(i + 1) % n]
						var lid: String = sketch.add_line(va.x, va.y, vb.x, vb.y)
						lids.append(lid)
					# Explicit coincident corners so Extrude's profile chain closes.
					for i in range(n):
						var a_id: String = lids[i]
						var b_id: String = lids[(i + 1) % n]
						sketch.add_constraint("coincident", [
							{"entity": a_id, "role": "end"},
							{"entity": b_id, "role": "start"}], 0.0)
					run_solve()
				_tool_points.clear()
				_redraw()
		Tool.POINT:
			sketch.add_point(pos2.x, pos2.y)
			_redraw()
		Tool.SPLINE:
			_spline_pts.append(pos2)
			_update_preview()
		Tool.ELLIPSE:
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				# Approximate ellipse as 4 arcs / polygon ring (32-gon).
				var c := _tool_points[0]
				var corner := _tool_points[1]
				var rx := absf(corner.x - c.x)
				var ry := absf(corner.y - c.y)
				if rx > 1e-6 and ry > 1e-6:
					var prev: Vector2
					for i in range(33):
						var ang := TAU * float(i) / 32.0
						var p := c + Vector2(cos(ang) * rx, sin(ang) * ry)
						if i > 0:
							sketch.add_line(prev.x, prev.y, p.x, p.y)
						prev = p
				_tool_points.clear()
				_redraw()
		Tool.SLOT:
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				_add_slot(_tool_points[0], _tool_points[1], 4.0)
				_tool_points.clear()
				_redraw()
		Tool.SMART_DIM:
			_click_smart_dim(pos2)
		Tool.CONVERT:
			convert_pierce_points()
		Tool.MIRROR:
			# Selection must already include axis + geometry; click confirms.
			mirror_selected()
		Tool.PATTERN:
			pattern_selected(_pattern_spacing, 0.0, _pattern_count)
		Tool.CHAMFER:
			chamfer_selected(2.0)
	_update_preview()
	if has_single_dof_preview():
		preview_distance_changed.emit(preview_distance())


func _click_rect(pos2: Vector2) -> void:
	_tool_points.append(pos2)
	match tool_variant:
		"center":
			if _tool_points.size() == 2:
				var c := _tool_points[0]
				var corner := _tool_points[1]
				var d := corner - c
				var a := c - d
				var b := c + d
				_add_rect_lines(a, b)
				_tool_points.clear()
		"three_point":
			if _tool_points.size() == 3:
				var p0 := _tool_points[0]
				var p1 := _tool_points[1]
				var p2 := _tool_points[2]
				var edge := p1 - p0
				var n := Vector2(-edge.y, edge.x).normalized()
				var depth := (p2 - p0).dot(n)
				var a := p0
				var b := p1
				var c := p1 + n * depth
				var d := p0 + n * depth
				var l1: String = sketch.add_line(a.x, a.y, b.x, b.y)
				var l2: String = sketch.add_line(b.x, b.y, c.x, c.y)
				var l3: String = sketch.add_line(c.x, c.y, d.x, d.y)
				var l4: String = sketch.add_line(d.x, d.y, a.x, a.y)
				_infer_rect(l1, l2, l3, l4)
				_tool_points.clear()
		"parallelogram":
			if _tool_points.size() == 3:
				var p0 := _tool_points[0]
				var p1 := _tool_points[1]
				var p2 := _tool_points[2]
				var p3 := p0 + (p2 - p1)
				sketch.add_line(p0.x, p0.y, p1.x, p1.y)
				sketch.add_line(p1.x, p1.y, p2.x, p2.y)
				sketch.add_line(p2.x, p2.y, p3.x, p3.y)
				sketch.add_line(p3.x, p3.y, p0.x, p0.y)
				_tool_points.clear()
		_:  # corner
			if _tool_points.size() == 2:
				_add_rect_lines(_tool_points[0], _tool_points[1])
				_tool_points.clear()
	_redraw()


func _add_rect_lines(a: Vector2, b: Vector2) -> void:
	var l1: String = sketch.add_line(a.x, a.y, b.x, a.y)
	var l2: String = sketch.add_line(b.x, a.y, b.x, b.y)
	var l3: String = sketch.add_line(b.x, b.y, a.x, b.y)
	var l4: String = sketch.add_line(a.x, b.y, a.x, a.y)
	_infer_rect(l1, l2, l3, l4)


func _click_circle(pos2: Vector2) -> void:
	_tool_points.append(pos2)
	match tool_variant:
		"perimeter", "three_point":
			if _tool_points.size() == 3:
				var p1 := _tool_points[0]
				var p2 := _tool_points[1]
				var p3 := _tool_points[2]
				var c_v: Variant = _circumcenter(p1, p2, p3)
				if c_v != null:
					var c: Vector2 = c_v
					var r: float = c.distance_to(p1)
					if r > 1e-6:
						sketch.add_circle(c.x, c.y, r)
				_tool_points.clear()
		_:  # center
			if _tool_points.size() == 2:
				var c := _tool_points[0]
				var r := c.distance_to(_tool_points[1])
				if r > 1e-6:
					sketch.add_circle(c.x, c.y, r)
				_tool_points.clear()
	_redraw()


func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Variant:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-12:
		return null
	var ux := ((a.x * a.x + a.y * a.y) * (b.y - c.y)
			+ (b.x * b.x + b.y * b.y) * (c.y - a.y)
			+ (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d
	var uy := ((a.x * a.x + a.y * a.y) * (c.x - b.x)
			+ (b.x * b.x + b.y * b.y) * (a.x - c.x)
			+ (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d
	return Vector2(ux, uy)


func _click_arc(pos2: Vector2) -> void:
	_tool_points.append(pos2)
	match tool_variant:
		"three_point":
			if _tool_points.size() == 3:
				var p1 := _tool_points[0]
				var p2 := _tool_points[1]
				var p3 := _tool_points[2]
				var c_v: Variant = _circumcenter(p1, p2, p3)
				if c_v != null:
					var ctr: Vector2 = c_v
					var r := ctr.distance_to(p1)
					if r > 1e-6:
						sketch.add_arc(ctr.x, ctr.y, r, (p1 - ctr).angle(), (p3 - ctr).angle())
				_tool_points.clear()
		"tangent":
			# First click near existing curve endpoint; second = end.
			if _tool_points.size() == 2:
				var start_pt := _tool_points[0]
				var end_pt := _tool_points[1]
				var mid := (start_pt + end_pt) * 0.5
				var n := Vector2(-(end_pt - start_pt).y, (end_pt - start_pt).x).normalized()
				var c := mid + n * start_pt.distance_to(end_pt) * 0.5
				var r := c.distance_to(start_pt)
				if r > 1e-6:
					sketch.add_arc(c.x, c.y, r, (start_pt - c).angle(), (end_pt - c).angle())
				_tool_points.clear()
		_:  # center
			if _tool_points.size() == 3:
				var c := _tool_points[0]
				var start_pt := _tool_points[1]
				var end_pt := _tool_points[2]
				var r := c.distance_to(start_pt)
				if r > 1e-6:
					sketch.add_arc(c.x, c.y, r, (start_pt - c).angle(), (end_pt - c).angle())
				_tool_points.clear()
	_redraw()


func _add_slot(a: Vector2, b: Vector2, half_w: float) -> void:
	var d := b - a
	if d.length() < 1e-6:
		return
	var n := Vector2(-d.y, d.x).normalized() * half_w
	var p0 := a + n
	var p1 := b + n
	var p2 := b - n
	var p3 := a - n
	sketch.add_line(p0.x, p0.y, p1.x, p1.y)
	sketch.add_line(p3.x, p3.y, p2.x, p2.y)
	# End caps as semicircle approximations (8 segments each).
	_add_semicircle(b, n, d.normalized())
	_add_semicircle(a, -n, -d.normalized())


func _add_semicircle(center: Vector2, start_off: Vector2, outward: Vector2) -> void:
	var r := start_off.length()
	var a0 := start_off.angle()
	var prev := center + start_off
	for i in range(1, 9):
		var ang := a0 + PI * float(i) / 8.0
		# Flip based on outward so the bulge goes the right way.
		var p := center + Vector2(cos(ang), sin(ang)) * r
		if (p - center).dot(outward) < 0.0:
			p = center - (p - center)
		sketch.add_line(prev.x, prev.y, p.x, p.y)
		prev = p


func _click_smart_dim(pos2: Vector2) -> void:
	var hit := _nearest_entity_at(pos2)
	if hit == "":
		if _smart_dim_first != null:
			# Second click as free point → distance from entity endpoint.
			var a: Vector2 = _smart_dim_first
			constrain("distance", a.distance_to(pos2))
			_smart_dim_first = null
		return
	var info: Dictionary = sketch.entity_info(hit)
	match str(info.get("type", "")):
		"circle", "arc":
			_set_selected([hit])
			constrain("radius", float(info.get("radius", 10.0)))
			_smart_dim_first = null
		"line":
			if selected.size() == 1 and selected[0] != hit:
				_set_selected([selected[0], hit])
				# Angle between two lines via angle constraint.
				constrain("angle", PI * 0.5)
			else:
				_set_selected([hit])
				constrain("distance", info["start"].distance_to(info["end"]))
			_smart_dim_first = null
		_:
			_set_selected([hit])
			_smart_dim_first = pos2


# --- constraint inference (automatic relations on creation) ---

## Solve and remember diagnostics; all sketch-mode solves go through here so
## DOF coloring stays current.
func run_solve() -> Dictionary:
	var res: Dictionary = sketch.solve()
	last_dofs = res["dofs"]
	last_solve_status = res["status"]
	last_conflicting = Array(res.get("conflicting", PackedStringArray()))
	last_redundant = Array(res.get("redundant", PackedStringArray()))
	_conflict_entities.clear()
	for cid in last_conflicting:
		var cinfo: Dictionary = sketch.constraint_info(str(cid))
		for ref in cinfo.get("refs", []):
			_conflict_entities[str(ref["entity"])] = true
	solve_updated.emit(last_dofs, last_solve_status, last_conflicting.size())
	return res


func auto_define() -> int:
	if sketch == null:
		return 0
	var n := 0
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if info.get("weak", false):
			if sketch.set_constraint_weak(cid, false):
				n += 1
	run_solve()
	_redraw()
	status.emit("Auto-define promoted %d dim(s) — DOF %d" % [n, last_dofs])
	return n


func promote_propose(verb: String = "parallel") -> String:
	if sketch == null:
		return ""
	var want := verb.trim_suffix("?")
	var lines: Array = []
	for eid in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(eid)
		if str(info.get("type", "")) == "line":
			lines.append({"id": eid, "start": info["start"], "end": info["end"]})
	for i in range(lines.size()):
		for j in range(i + 1, lines.size()):
			var da: Vector2 = (lines[i]["end"] as Vector2) - (lines[i]["start"] as Vector2)
			var db: Vector2 = (lines[j]["end"] as Vector2) - (lines[j]["start"] as Vector2)
			if da.length() < 1e-6 or db.length() < 1e-6:
				continue
			var la := da.length()
			var lb := db.length()
			da = da.normalized()
			db = db.normalized()
			var dot := absf(da.dot(db))
			var match_verb := ""
			if want == "parallel" and dot > 0.98:
				match_verb = "parallel"
			elif want == "perpendicular" and dot < 0.15:
				match_verb = "perpendicular"
			elif want == "equal" and la > 1e-6 and lb > 1e-6 and absf(la - lb) / maxf(la, lb) < 0.05:
				match_verb = "equal"
			if match_verb == "":
				continue
			var refs := [
				{"entity": lines[i]["id"], "role": "self"},
				{"entity": lines[j]["id"], "role": "self"},
			]
			var cid: String = sketch.add_constraint(match_verb, refs, 0.0)
			run_solve()
			_redraw()
			status.emit("Proposed %s" % match_verb)
			return cid
	status.emit("Nothing to propose")
	return ""


## On-canvas “parallel?” / “equal?” chips from the live sketch (Wave 3.9).
func propose_verbs() -> Array:
	var verbs: Array = []
	if sketch == null:
		return verbs
	var lines: Array = []
	for eid in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(eid)
		if str(info.get("type", "")) == "line":
			lines.append({"start": info["start"], "end": info["end"]})
	for i in range(lines.size()):
		for j in range(i + 1, lines.size()):
			var da: Vector2 = (lines[i]["end"] as Vector2) - (lines[i]["start"] as Vector2)
			var db: Vector2 = (lines[j]["end"] as Vector2) - (lines[j]["start"] as Vector2)
			if da.length() < 1e-6 or db.length() < 1e-6:
				continue
			var la := da.length()
			var lb := db.length()
			da = da.normalized()
			db = db.normalized()
			var dot := absf(da.dot(db))
			if dot > 0.98 and "parallel?" not in verbs:
				verbs.append("parallel?")
			elif dot < 0.15 and "perpendicular?" not in verbs:
				verbs.append("perpendicular?")
			if la > 1e-6 and lb > 1e-6 and absf(la - lb) / maxf(la, lb) < 0.05 \
					and "equal?" not in verbs:
				verbs.append("equal?")
	return verbs


## New line: add horizontal/vertical when near axis-aligned, and coincident
## constraints where its endpoints land on existing line endpoints.
func _infer_line(lid: String, a: Vector2, b: Vector2) -> void:
	if not infer_enabled or lid == "":
		return
	var added := false
	var d := b - a
	if d.length() > INFER_TOL:
		if absf(d.y) <= INFER_TOL:
			sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
			added = true
		elif absf(d.x) <= INFER_TOL:
			sketch.add_constraint("vertical", [{"entity": lid, "role": "self"}], 0.0)
			added = true
	for role_pos in [["start", a], ["end", b]]:
		var hit := _endpoint_hit(role_pos[1], lid)
		if hit.size() == 2:
			sketch.add_constraint("coincident", [
				{"entity": lid, "role": role_pos[0]},
				{"entity": hit[0], "role": hit[1]}], 0.0)
			added = true
	if added:
		run_solve()


## Existing line endpoint within INFER_TOL of `p` (excluding `exclude_id`),
## as [entity_id, role]; [] when none.
func _endpoint_hit(p: Vector2, exclude_id: String) -> Array:
	for id in sketch.entity_ids():
		if id == exclude_id:
			continue
		var info: Dictionary = sketch.entity_info(id)
		if info.get("type", "") != "line":
			continue
		if p.distance_to(info["start"]) <= INFER_TOL:
			return [id, "start"]
		if p.distance_to(info["end"]) <= INFER_TOL:
			return [id, "end"]
	return []


## Rectangle: H/V on the four sides plus coincident corners, so the rect
## stays rectangular under later edits.
func _infer_rect(l1: String, l2: String, l3: String, l4: String) -> void:
	if not infer_enabled or "" in [l1, l2, l3, l4]:
		return
	for lid in [l1, l3]:
		sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
	for lid in [l2, l4]:
		sketch.add_constraint("vertical", [{"entity": lid, "role": "self"}], 0.0)
	var corners := [[l1, "end", l2, "start"], [l2, "end", l3, "start"],
		[l3, "end", l4, "start"], [l4, "end", l1, "start"]]
	for c in corners:
		sketch.add_constraint("coincident", [
			{"entity": c[0], "role": c[1]},
			{"entity": c[2], "role": c[3]}], 0.0)
	run_solve()


## Change the value of a recorded dimensional constraint (by index into
## `dimensions`) and re-solve. Returns the solve status ("" on bad index).
func set_dimension_value(index: int, value_or_expr: Variant) -> String:
	if index < 0 or index >= dimensions.size():
		return ""
	var dim: Dictionary = dimensions[index]
	var cid: String = dim.get("cid", "")
	if cid == "":
		return ""
	if typeof(value_or_expr) == TYPE_STRING:
		var expr := str(value_or_expr).strip_edges()
		if expr.begins_with("=") or (not expr.is_valid_float() and expr.length() > 0):
			if not expr.begins_with("="):
				expr = "=" + expr
			sketch.set_constraint_expr(cid, expr)
			dim["expr"] = expr
		else:
			var value := float(expr)
			if not sketch.set_constraint_value(cid, value):
				return ""
			dim["value"] = value
			dim.erase("expr")
	else:
		var value := float(value_or_expr)
		if not sketch.set_constraint_value(cid, value):
			return ""
		dim["value"] = value
		dim.erase("expr")
	# Resolve expressions from document variables before solve.
	if view != null and view.doc != null:
		var env2 := {}
		for entry in view.doc.list_variables():
			if typeof(entry) == TYPE_DICTIONARY and entry.has("value"):
				var vv = entry["value"]
				if typeof(vv) == TYPE_FLOAT or typeof(vv) == TYPE_INT:
					env2[str(entry.get("name", ""))] = float(vv)
		if not env2.is_empty():
			sketch.resolve_expressions(env2)
	if dim.has("expr"):
		dim["value"] = sketch.constraint_info(cid).get("value", dim.get("value", 0.0))
	dimensions[index] = dim
	var res := run_solve()
	_redraw()
	_redraw_selected()
	_rebuild_dimension_labels()
	return res["status"]


## Double-click or right-click ends a line chain / commits a spline.
func end_chain() -> void:
	if tool == Tool.SPLINE and _spline_pts.size() >= 2:
		_commit_spline()
	_tool_points.clear()
	_length_override = -1.0
	_update_preview()


func hover(pos2: Vector2) -> void:
	if tool == Tool.TRIM:
		_trim_hover_id = _nearest_entity_at(pos2)
		_hover = pos2
		_update_preview()
		return
	_hover = snap_point(pos2)
	var tip := effective_hover()
	if _infer_label != null:
		var hint := _infer_hint_text(tip)
		_infer_label.visible = hint != ""
		if hint != "":
			_infer_label.text = hint
			_infer_label.position = _to3(tip + Vector2(2.0, 2.0))
	_update_preview()
	if has_single_dof_preview():
		preview_distance_changed.emit(preview_distance())


## Power-trim drag: trim every entity the cursor crosses.
func begin_trim_drag(pos2: Vector2) -> void:
	_trim_dragging = true
	_trim_drag_ids.clear()
	trim_at(pos2)
	var id := _nearest_entity_at(pos2)
	if id != "":
		_trim_drag_ids.append(id)


func update_trim_drag(pos2: Vector2) -> void:
	if not _trim_dragging:
		return
	var id := _nearest_entity_at(pos2)
	if id != "" and id not in _trim_drag_ids:
		if trim_at(pos2):
			_trim_drag_ids.append(id)
	_trim_hover_id = id
	_update_preview()


func end_trim_drag() -> void:
	_trim_dragging = false
	_trim_drag_ids.clear()
	_trim_hover_id = ""


## Split the nearest line at pos2 into two collinear segments.
func split_at(pos2: Vector2) -> bool:
	if not active or sketch == null:
		return false
	var id := _nearest_entity_at(pos2)
	if id == "":
		status.emit("Split: click a line")
		return false
	var info: Dictionary = sketch.entity_info(id)
	if info.get("type", "") != "line":
		status.emit("Split: only lines supported")
		return false
	var a: Vector2 = info["start"]
	var b: Vector2 = info["end"]
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((pos2 - a).dot(ab) / ab.length_squared(), 0.05, 0.95)
	var mid: Vector2 = a + ab * t
	sketch.set_entity_geometry(id, {"start": a, "end": mid})
	sketch.add_line(mid.x, mid.y, b.x, b.y)
	run_solve()
	_redraw()
	return true


## Load an underlay image onto the sketch plane (trace with existing tools).
func set_sketch_picture(tex: Texture2D, size: Vector2 = Vector2(100, 100)) -> void:
	sketch_picture = tex
	sketch_picture_size = size
	_rebuild_picture()


## Uniform / anisotropic resize of the picture underlay (mm on the sketch plane).
func set_sketch_picture_size(size: Vector2) -> void:
	if size.x < 0.1 or size.y < 0.1:
		return
	sketch_picture_size = size
	_rebuild_picture()


func clear_sketch_picture() -> void:
	sketch_picture = null
	if _picture_node != null:
		_picture_node.queue_free()
		_picture_node = null


func _rebuild_picture() -> void:
	if _picture_node != null:
		_picture_node.queue_free()
		_picture_node = null
	if sketch_picture == null or not active:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := sketch_picture_size.x * 0.5
	var hy := sketch_picture_size.y * 0.5
	var corners := [
		_to3(Vector2(-hx, -hy)),
		_to3(Vector2(hx, -hy)),
		_to3(Vector2(hx, hy)),
		_to3(Vector2(-hx, hy)),
	]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	st.set_uv(uvs[0]); st.add_vertex(corners[0])
	st.set_uv(uvs[1]); st.add_vertex(corners[1])
	st.set_uv(uvs[2]); st.add_vertex(corners[2])
	st.set_uv(uvs[0]); st.add_vertex(corners[0])
	st.set_uv(uvs[2]); st.add_vertex(corners[2])
	st.set_uv(uvs[3]); st.add_vertex(corners[3])
	_picture_node = MeshInstance3D.new()
	_picture_node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = sketch_picture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.55)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_picture_node.material_override = mat
	add_child(_picture_node)


## Instantiate a named block by translating a copy of its entities.
func place_block(block_name: String, offset: Vector2) -> Array:
	if not blocks.has(block_name):
		status.emit("Unknown block: %s" % block_name)
		return []
	var out: Array = []
	var ids: PackedStringArray = blocks[block_name]
	for id in ids:
		var info: Dictionary = sketch.entity_info(id)
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"] + offset
				var b: Vector2 = info["end"] + offset
				out.append(sketch.add_line(a.x, a.y, b.x, b.y))
			"circle":
				var c: Vector2 = info["center"] + offset
				out.append(sketch.add_circle(c.x, c.y, float(info["radius"])))
			"point":
				var p: Vector2 = info.get("position", Vector2.ZERO) + offset
				out.append(sketch.add_point(p.x, p.y))
	_redraw()
	return out


## Delete selected sketch entities (geometry).
func delete_selected_entities() -> int:
	if selected.is_empty():
		return 0
	var n := 0
	for id in selected.duplicate():
		if sketch.remove_entity(id):
			n += 1
	_set_selected([])
	run_solve()
	_redraw()
	return n


## Sketch entity clipboard (dicts from entity_info).
var _entity_clipboard: Array = []
var _entity_clipboard_cut := false


func has_entity_clipboard() -> bool:
	return not _entity_clipboard.is_empty()


func copy_selected_entities() -> int:
	_entity_clipboard.clear()
	_entity_clipboard_cut = false
	if sketch == null:
		return 0
	for id in selected:
		var info: Dictionary = sketch.entity_info(id)
		if not info.is_empty():
			_entity_clipboard.append(info.duplicate(true))
	return _entity_clipboard.size()


func cut_selected_entities() -> int:
	var n := copy_selected_entities()
	if n == 0:
		return 0
	_entity_clipboard_cut = true
	delete_selected_entities()
	return n


## Paste clipboard entities offset in sketch UV. Default +10,+10 mm.
func paste_entities(offset := Vector2(10, 10)) -> Array:
	if _entity_clipboard.is_empty() or sketch == null:
		return []
	var out: Array = []
	for info in _entity_clipboard:
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"] + offset
				var b: Vector2 = info["end"] + offset
				out.append(sketch.add_line(a.x, a.y, b.x, b.y))
			"circle":
				var c: Vector2 = info["center"] + offset
				out.append(sketch.add_circle(c.x, c.y, float(info["radius"])))
			"arc":
				var ac: Vector2 = info["center"] + offset
				out.append(sketch.add_arc(ac.x, ac.y, float(info.get("radius", 1)),
						float(info.get("start_angle", 0)), float(info.get("end_angle", PI))))
			"point":
				var p: Vector2 = info.get("position", info.get("point", Vector2.ZERO)) + offset
				out.append(sketch.add_point(p.x, p.y))
	_entity_clipboard_cut = false
	var ids: Array[String] = []
	for x in out:
		if typeof(x) == TYPE_STRING and str(x) != "":
			ids.append(str(x))
	_set_selected(ids)
	run_solve()
	_redraw()
	return out


func _to3(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


func _clear_meshes() -> void:
	_draw_node.mesh = null
	_preview_node.mesh = null
	_selected_node.mesh = null
	selected = []
	selected_constraint = ""
	dimensions.clear()
	_clear_dimension_labels()
	_rebuild_constraint_glyphs()
	if _infer_label != null:
		_infer_label.visible = false


func _clear_dimension_labels() -> void:
	if _dimension_labels == null:
		return
	while _dimension_labels.get_child_count() > 0:
		var child := _dimension_labels.get_child(0)
		_dimension_labels.remove_child(child)
		child.free()


func _entity_draw_color(info: Dictionary, id: String = "") -> Color:
	if id != "" and _conflict_entities.has(id):
		return COLOR_CONFLICT
	if info.get("construction", false):
		return COLOR_CONSTRUCTION
	# Fully-constrained sketches draw green (per-entity DOF isn't reported by
	# the solver yet, so the whole sketch flips together).
	if last_dofs == 0 and last_solve_status != "failed":
		return COLOR_CONSTRAINED
	return COLOR_ENTITY


func _dimension_display_value(dim: Dictionary) -> float:
	var ids: Array = dim.get("ids", [])
	var measured := measured_value(ids)
	if measured > 1e-12:
		return measured
	return float(dim.get("value", 0.0))


func _dimension_label_pos2(dim: Dictionary) -> Variant:
	## Sketch-plane 2D position for a dimension label, or null if unresolvable.
	var ids: Array = dim.get("ids", [])
	var type: String = dim.get("type", "")
	if ids.is_empty() or sketch == null:
		return null
	if type == "radius" or (ids.size() == 1 and sketch.entity_info(str(ids[0])).get("type", "") in ["circle", "arc"]):
		var info: Dictionary = sketch.entity_info(str(ids[0]))
		if info.get("type", "") != "circle" and info.get("type", "") != "arc":
			return null
		var c: Vector2 = info["center"]
		var r: float = info["radius"]
		return c + Vector2(r * 0.7071, r * 0.7071)
	# Distance (or other): midpoint of the two reference points, offset perpendicular.
	var a: Vector2
	var b: Vector2
	if ids.size() == 1:
		var li: Dictionary = sketch.entity_info(str(ids[0]))
		if li.get("type", "") != "line":
			return null
		a = li["start"]
		b = li["end"]
	elif ids.size() >= 2:
		var pair := _closest_endpoints(str(ids[0]), str(ids[1]))
		if pair.size() != 2:
			return null
		a = _endpoint_pos(str(ids[0]), pair[0])
		b = _endpoint_pos(str(ids[1]), pair[1])
	else:
		return null
	var mid := (a + b) * 0.5
	var ab := b - a
	var perp := Vector2(-ab.y, ab.x)
	if perp.length_squared() < 1e-12:
		perp = Vector2(0, 1)
	else:
		perp = perp.normalized()
	return mid + perp * DIM_LABEL_OFFSET


func _rebuild_dimension_labels() -> void:
	_clear_dimension_labels()
	if _dimension_labels == null or sketch == null:
		return
	_dimension_labels.visible = dimensions_visible
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var pos2: Variant = _dimension_label_pos2(dim)
		if pos2 == null:
			continue
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.004
		label.font_size = 28
		label.text = _format_dimension(_dimension_display_value(dim))
		label.position = _to3(pos2)
		_dimension_labels.add_child(label)


# --- constraint glyphs (visible relations, SolidWorks-style) ---

## Sketch-plane position of a constraint reference point. Role "self" means
## the entity itself: line midpoint, circle/arc center, point position.
func _ref_pos(ref: Dictionary) -> Variant:
	var info: Dictionary = sketch.entity_info(str(ref["entity"]))
	if info.is_empty():
		return null
	var role := str(ref.get("role", "self"))
	match info.get("type", ""):
		"line":
			if role == "start":
				return info["start"]
			if role == "end":
				return info["end"]
			return (info["start"] + info["end"]) * 0.5
		"circle", "arc":
			return info["center"]
		"point":
			return info["position"]
	return null


## Glyph anchor for a constraint: mean of its reference points, nudged
## perpendicular for single-line relations so the badge sits beside the line.
func _constraint_anchor(cinfo: Dictionary) -> Variant:
	var refs: Array = cinfo.get("refs", [])
	if refs.is_empty():
		return null
	var sum := Vector2.ZERO
	var n := 0
	for ref in refs:
		var p: Variant = _ref_pos(ref)
		if p == null:
			continue
		sum += p as Vector2
		n += 1
	if n == 0:
		return null
	var anchor := sum / float(n)
	if refs.size() == 1:
		var info: Dictionary = sketch.entity_info(str(refs[0]["entity"]))
		if info.get("type", "") == "line":
			var d: Vector2 = info["end"] - info["start"]
			if d.length_squared() > 1e-12:
				anchor += Vector2(-d.y, d.x).normalized() * 2.5
	return anchor


func _rebuild_constraint_glyphs() -> void:
	_glyph_anchors.clear()
	if _constraint_glyphs == null:
		return
	while _constraint_glyphs.get_child_count() > 0:
		var child := _constraint_glyphs.get_child(0)
		_constraint_glyphs.remove_child(child)
		child.free()
	if sketch == null or not active:
		return
	if selected_constraint != "" and sketch.constraint_info(selected_constraint).is_empty():
		selected_constraint = ""
	var taken: Array[Vector2] = []
	for cid in sketch.constraint_ids():
		var cinfo: Dictionary = sketch.constraint_info(cid)
		var type := str(cinfo.get("type", ""))
		if not GLYPH_SYMBOLS.has(type):
			continue
		var anchor: Variant = _constraint_anchor(cinfo)
		if anchor == null:
			continue
		var pos := anchor as Vector2
		# Stack overlapping badges instead of drawing them on top of each other.
		var guard := 0
		while guard < 8 and taken.any(func(t: Vector2) -> bool: return t.distance_to(pos) < 2.0):
			pos += Vector2(0, 2.5)
			guard += 1
		taken.append(pos)
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.004
		label.font_size = 22
		label.text = GLYPH_SYMBOLS[type]
		if str(cid) == selected_constraint:
			label.modulate = COLOR_GLYPH_SELECTED
		elif last_conflicting.has(str(cid)):
			label.modulate = COLOR_CONFLICT
		else:
			label.modulate = COLOR_GLYPH
		label.position = _to3(pos)
		label.set_meta("cid", str(cid))
		_constraint_glyphs.add_child(label)
		_glyph_anchors.append({"cid": str(cid), "pos": pos})


## Constraint whose glyph is within GLYPH_PICK_RADIUS of pos2, or "".
## Geometry wins ties: a click closer to an entity than to the badge selects
## the entity, so badges beside a line never steal clicks aimed at it.
func constraint_hit(pos2: Vector2) -> String:
	var best := ""
	var best_d := GLYPH_PICK_RADIUS
	for a in _glyph_anchors:
		var d: float = pos2.distance_to(a["pos"])
		if d < best_d:
			best_d = d
			best = a["cid"]
	if best == "":
		return ""
	var eid := _nearest_entity_at(pos2)
	if eid != "" and _entity_distance(sketch.entity_info(eid), pos2) < best_d:
		return ""
	return best


func select_constraint(cid: String) -> void:
	selected_constraint = cid
	_rebuild_constraint_glyphs()
	if cid != "":
		var type := str(sketch.constraint_info(cid).get("type", ""))
		status.emit("Constraint selected: %s — Del removes it" % type)


## Remove the selected constraint (glyph click + Del). Returns true on success.
func delete_selected_constraint() -> bool:
	if selected_constraint == "" or sketch == null:
		return false
	var cid := selected_constraint
	if not sketch.remove_constraint(cid):
		return false
	selected_constraint = ""
	# Drop any recorded dimension driven by this constraint.
	for i in range(dimensions.size() - 1, -1, -1):
		if str(dimensions[i].get("cid", "")) == cid:
			dimensions.remove_at(i)
	run_solve()
	_redraw()
	_redraw_selected()
	status.emit("Constraint removed")
	return true


## Index of the dimension whose label sits within PICK_TOLERANCE of pos2 (-1 = none).
func dimension_hit(pos2: Vector2) -> int:
	var best := -1
	var best_d := PICK_TOLERANCE
	for i in range(dimensions.size()):
		var lp: Variant = _dimension_label_pos2(dimensions[i])
		if lp == null:
			continue
		var d: float = pos2.distance_to(lp as Vector2)
		if d < best_d:
			best_d = d
			best = i
	return best


## Live inference hint while drawing: which constraint the LINE tool would add
## for a segment from the last tool point to `p` ("H", "V", coincident glyph).
func _infer_hint_text(p: Vector2) -> String:
	if not infer_enabled or tool != Tool.LINE or _tool_points.is_empty():
		return ""
	if not _endpoint_hit(p, "").is_empty():
		return GLYPH_SYMBOLS["coincident"]
	var d := p - _tool_points[_tool_points.size() - 1]
	if d.length() <= INFER_TOL:
		return ""
	if absf(d.y) <= INFER_TOL:
		return "H"
	if absf(d.x) <= INFER_TOL:
		return "V"
	return ""


## Approximate "%.4g" (GDScript's % operator has no g specifier).
func _format_dimension(v: float) -> String:
	if not is_finite(v):
		return str(v)
	if absf(v) < 1e-12:
		return "0"
	var s := "%.6f" % v
	if s.contains("."):
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
	return s


## Drop dimension annotations whose entity ids no longer exist (e.g. after trim).
func _prune_orphan_dimensions() -> void:
	if sketch == null:
		dimensions.clear()
		return
	var alive := {}
	for id in sketch.entity_ids():
		alive[str(id)] = true
	var kept: Array = []
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var ids: Array = dim.get("ids", [])
		var ok := not ids.is_empty()
		for eid in ids:
			if not alive.has(str(eid)):
				ok = false
				break
		if ok:
			kept.append(dim)
	dimensions = kept


func _redraw() -> void:
	if sketch == null:
		return
	_prune_orphan_dimensions()
	var im := ImmediateMesh.new()
	var has := false
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var col := _entity_draw_color(info, str(id))
		match info.get("type", ""):
			"line":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				im.surface_set_color(col)
				im.surface_add_vertex(_to3(info["start"]))
				im.surface_add_vertex(_to3(info["end"]))
			"circle":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				var c: Vector2 = info["center"]
				var r: float = info["radius"]
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_set_color(col)
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
			"arc":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				var c2: Vector2 = info["center"]
				var r2: float = info["radius"]
				var s: float = info["start_angle"]
				var e: float = info["end_angle"]
				if e < s:
					e += TAU
				var steps2 := 32
				for i in range(steps2):
					var a0 := s + (e - s) * i / steps2
					var a1 := s + (e - s) * (i + 1) / steps2
					im.surface_set_color(col)
					im.surface_add_vertex(_to3(c2 + Vector2(cos(a0), sin(a0)) * r2))
					im.surface_add_vertex(_to3(c2 + Vector2(cos(a1), sin(a1)) * r2))
	if has:
		im.surface_end()
		_draw_node.mesh = im
	else:
		_draw_node.mesh = null
	_rebuild_dimension_labels()
	_rebuild_constraint_glyphs()


func _update_preview() -> void:
	var im := ImmediateMesh.new()
	var has := false
	var dragging := not _drag.is_empty()
	var trim_hover := tool == Tool.TRIM and _trim_hover_id != ""
	if _tool_points.size() > 0 or _snap_marker != null or dragging or trim_hover \
			or _spline_pts.size() > 0:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		has = true
	if trim_hover and sketch != null:
		_append_entity_lines(im, sketch.entity_info(_trim_hover_id))
	if dragging:
		_append_entity_lines(im, _drag["preview_info"])
	if _spline_pts.size() > 0:
		# Preview = committed fit points plus an imaginary point at the cursor.
		var preview_pts: Array[Vector2] = _spline_pts.duplicate()
		preview_pts.append(_hover)
		var densified := _densify_fit_spline(preview_pts)
		for i in range(densified.size() - 1):
			im.surface_add_vertex(_to3(densified[i]))
			im.surface_add_vertex(_to3(densified[i + 1]))
	if _tool_points.size() > 0:
		var last := _tool_points[_tool_points.size() - 1]
		var tip := effective_hover()
		match tool:
			Tool.LINE, Tool.CENTERLINE:
				im.surface_add_vertex(_to3(last))
				im.surface_add_vertex(_to3(tip))
			Tool.RECT:
				var a := _tool_points[0]
				var b := tip
				im.surface_add_vertex(_to3(a)); im.surface_add_vertex(_to3(Vector2(b.x, a.y)))
				im.surface_add_vertex(_to3(Vector2(b.x, a.y))); im.surface_add_vertex(_to3(b))
				im.surface_add_vertex(_to3(b)); im.surface_add_vertex(_to3(Vector2(a.x, b.y)))
				im.surface_add_vertex(_to3(Vector2(a.x, b.y))); im.surface_add_vertex(_to3(a))
			Tool.CIRCLE:
				var c := _tool_points[0]
				var r := c.distance_to(tip)
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
			Tool.ARC:
				var c := _tool_points[0]
				if _tool_points.size() == 1:
					im.surface_add_vertex(_to3(c))
					im.surface_add_vertex(_to3(tip))
				else:
					var start_pt := _tool_points[1]
					var r := c.distance_to(start_pt)
					var s := (start_pt - c).angle()
					var e := (tip - c).angle()
					if e < s:
						e += TAU
					var steps2 := 32
					for i in range(steps2):
						var a0 := s + (e - s) * i / steps2
						var a1 := s + (e - s) * (i + 1) / steps2
						im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
						im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
			Tool.POLYGON:
				var c := _tool_points[0]
				var r := c.distance_to(tip)
				var n := polygon_sides
				var start_angle := (tip - c).angle()
				if tool_variant == "across_flats":
					r = r / sqrt(3.0)
					start_angle = deg_to_rad(30.0)
					n = 6
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
				var verts: Array[Vector2] = []
				for i in range(n):
					var a := start_angle + TAU * float(i) / float(n)
					verts.append(c + Vector2(cos(a), sin(a)) * r)
				for i in range(n):
					im.surface_add_vertex(_to3(verts[i]))
					im.surface_add_vertex(_to3(verts[(i + 1) % n]))
			Tool.SLOT:
				im.surface_add_vertex(_to3(last))
				im.surface_add_vertex(_to3(tip))
	if _snap_marker != null:
		var m: Vector2 = _snap_marker
		const MARK := 0.6
		im.surface_add_vertex(_to3(m + Vector2(-MARK, 0)))
		im.surface_add_vertex(_to3(m + Vector2(MARK, 0)))
		im.surface_add_vertex(_to3(m + Vector2(0, -MARK)))
		im.surface_add_vertex(_to3(m + Vector2(0, MARK)))
	if has:
		im.surface_end()
		if trim_hover:
			_preview_material.albedo_color = Color(1.0, 0.25, 0.2, 0.95)
		else:
			_preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
		_preview_node.mesh = im
	else:
		_preview_node.mesh = null


## True when the sketch's non-construction geometry forms one or more closed
## profiles (single circle, or line/arc/spline chains that each return to start).
static func profile_is_closed(sk: SxSketch, tol: float = 1e-4) -> bool:
	if sk == null:
		return false
	var segs: Array = []  # {a: Vector2, b: Vector2}
	var circles := 0
	for id in sk.entity_ids():
		if sk.is_construction(id):
			continue
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"circle":
				circles += 1
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				if a.distance_to(b) > 1e-9:
					segs.append({"a": a, "b": b, "used": false})
			"arc":
				var c: Vector2 = info["center"]
				var r: float = float(info.get("radius", 0.0))
				var sa: float = float(info.get("start_angle", 0.0))
				var ea: float = float(info.get("end_angle", 0.0))
				var pa: Vector2 = c + Vector2.from_angle(sa) * r
				var pb: Vector2 = c + Vector2.from_angle(ea) * r
				if pa.distance_to(pb) > 1e-9:
					segs.append({"a": pa, "b": pb, "used": false})
			"spline":
				var fps: Array = info.get("fit_points", [])
				if fps.size() >= 2:
					var a2: Vector2 = fps[0]
					var b2: Vector2 = fps[fps.size() - 1]
					segs.append({"a": a2, "b": b2, "used": false})
			_:
				pass
	if circles == 1 and segs.is_empty():
		return true
	if circles >= 1:
		return false  # mixed circle + open edges not a single profile here
	if segs.is_empty():
		return false
	# Greedy-chain every unused segment; each chain must close.
	while true:
		var seed := -1
		for i in range(segs.size()):
			if not segs[i]["used"]:
				seed = i
				break
		if seed < 0:
			break
		segs[seed]["used"] = true
		var loop_start: Vector2 = segs[seed]["a"]
		var cursor: Vector2 = segs[seed]["b"]
		var progressing := true
		while progressing and cursor.distance_to(loop_start) > tol:
			progressing = false
			for j in range(segs.size()):
				if segs[j]["used"]:
					continue
				var sa2: Vector2 = segs[j]["a"]
				var sb2: Vector2 = segs[j]["b"]
				if sa2.distance_to(cursor) <= tol:
					cursor = sb2
				elif sb2.distance_to(cursor) <= tol:
					cursor = sa2
				else:
					continue
				segs[j]["used"] = true
				progressing = true
				break
		if cursor.distance_to(loop_start) > tol:
			return false
	return true
