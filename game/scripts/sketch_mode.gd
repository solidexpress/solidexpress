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
## Thin lines are a pixel wide. At the jaw-head zoom (~3 px/mm) 2.5 mm is
## under a finger-width, so a click on a shaft line misses. Grow the hit
## radius with the view, capped so a zoomed-out part does not select everything.
const PICK_SCREEN_PX := 14.0
const PICK_TOLERANCE_MAX_MM := 8.0
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
const MIN_SEGMENT_MM := 0.5
var _sketch_view_radius := 25.0
## Invalidates a pending `_reassert_camera` after Save restores the live pose.
var _camera_reassert_gen := 0
## Save bumps this so apply_pose's view_changed does not restack at the
## restored zoom before reapply has put the live stacks back.
var _label_restack_hold := 0
## When true, click/hover positions pass through snap_point().
var snap_enabled := true
## When true, end_chain / Done / Esc auto-adds a closing segment if ends are near.
var _auto_close := true
## Regular N-gon side count for the POLYGON tool (clamped 3..24).
var polygon_sides := 6:
	set(v):
		polygon_sides = clampi(v, 3, 24)
## Tool variants: rect=corner|center|three_point|center_three_point|parallelogram
## (SolidWorks rectangle flyout; Corner is the default and the first chip);
## circle=center|perimeter|three_point; arc=center|tangent|three_point;
## pattern=linear|circular. Polygon uses tool_variant too; the last polygon
## choice is kept in `_polygon_variant` so Circle/Rect can reset their own
## names and Polygon still comes back as across-flats (or vertex, if chosen).
var tool_variant := "corner"
var _polygon_variant := "across_flats"
## True while the rail Jaw button is the armed rect tool. Jaw has one gesture
## and shows no variant chips. Rect, when Jaw is not armed, shows all five in
## SolidWorks flyout order (Corner first).
var _jaw_armed := false
var _arming_jaw := false
## Construction +X used only as an angle datum. Jaw trim must not pick these
## as the cutter — they pass through the rectangle centre and sit closer to
## the trim click than the real centreline.
var _angle_datum_lines: Dictionary = {}
## Jaw floor / walls / keep-side arc from the last successful Power Trim.
## Re-welded after the extrude-time solve so 1e-6 joints survive DogLeg.
var _jaw_floor_id := ""
var _jaw_arc_id := ""
var _jaw_wall_ids: Array[String] = []
## Draw next line as construction (centerline mode).
var draw_construction := false
## Power-trim drag state: list of already-trimmed entity ids this stroke.
var _trim_drag_ids: Array[String] = []
var _trim_dragging := false
## Faint red polyline of a Power Trim drag. Freed when the drag ends.
var _trim_trail: MeshInstance3D
var _trim_trail_pts: PackedVector2Array
var _trim_jaw_done_in_drag := false
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
## Straight-slot cap radius (mm). The dim blank sets this before the first
## centre click; the rubber-band after that click is the centre distance.
const DEFAULT_SLOT_RADIUS := 5.0
var slot_radius := DEFAULT_SLOT_RADIUS
## Circle radius shown in the dim blank. Separate from slot_radius so a Slot
## radius of 5 does not become the next Circle's starting Radius.
const DEFAULT_CIRCLE_RADIUS := 10.0
var circle_radius := DEFAULT_CIRCLE_RADIUS
## Last committed length / AF / c-c for each numeric field. Missing key means
## the blank is empty. Never copy one tool's number into another field.
var _tool_numeric: Dictionary = {}
## Smart Dimension first pick when it is a centre/point rather than a curve.
var _smart_dim_pending: Dictionary = {}
## True after an Esc dropped a pending draw point and the status said the
## next Esc leaves. A click or a tool change clears it. Without this, a
## sketch that already holds geometry inserts "Tool dropped" between that
## promise and the exit (Circle centre, then Esc, Esc).
var _esc_exit_promised := false
## Set when Extrude refuses and keeps the sketch. The next Esc is the exit
## ladder (`… — Esc again exits the sketch`), not a chain / field press.
var _refusal_esc_ladder := false
## Feature id of the body being sketched on ("" when on the ground plane);
## used as the boolean target for cut/fuse finishes.
var target_fid := ""
var support_host := ""
var support_normal := Vector3.ZERO
var support_side := ""
## Face the session was opened on. Cleared when the session ends so part mode
## does not keep that face's selection card over the rail.
var host_face_id := ""
## Feature id of the sketch being edited ("" when creating a new sketch).
var editing_fid := ""
## Kernel snapshot at begin_edit. An Exit with no change skips the graph write.
var _edit_baseline := ""
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
## Snap / pick cross. Hidden after Smart Dim so a centre pick does not leave a dot.
var _pick_marker: MeshInstance3D
var _selected_node: MeshInstance3D
var _contour_node: MeshInstance3D
var _contour_fill_material: StandardMaterial3D
var _contour_line_material: StandardMaterial3D
var _contour_tags: Node3D
var _contour_tag: Label3D
var _contour_included: Array = []
var _contour_focus := -1
var _contour_cache: Array = []
var _contour_cache_sig := "\u0001"
var _contour_fill_alphas: Array = []
var _contour_outline_count := 0
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
var _point_from_length := false
## Last named commit sentence (polygon AF, circle radius, centre-to-flat).
## Empty means the caller should keep a generic length status.
var _last_commit_text := ""
## Set by snap_point when a snap applied; drawn as a small cross in preview.
var _snap_marker: Variant = null  # Vector2 | null
## Active SELECT-tool geometry drag. Empty when idle. Keys when dragging:
## id, part ("start"|"end"|"whole"|"center"|"radius"), grab_pos, orig_info,
## preview_info. Commits live via SxSketch.set_entity_geometry + re-solve.
var _drag: Dictionary = {}
## In-sketch undo: snapshots of the kernel sketch plus the dimension records.
## Not document history — Exit Sketch is the only write to the feature graph.
const UNDO_STACK_MAX := 100
var _undo_stack: Array = []  # {json, dimensions, label} = state before the op
var _redo_stack: Array = []
var _undo_head := ""
var _undo_head_dims: Array = []
var _undo_label := ""
var _undo_restoring := false
var _undo_parked: Dictionary = {}
var _undo_merge_frame := -1
var _undo_drag_open := false
var _line_material: StandardMaterial3D
var _preview_material: StandardMaterial3D

const DIM_LABEL_OFFSET := 4.0  # sketch-plane units perpendicular to a distance dim
const DIM_LABEL_FONT := 18  # Label3D font px (fixed_size: screen size follows the window, not the zoom)
const DIM_LABEL_PIXEL := 0.004  # Label3D.pixel_size
const DIM_LABEL_PAD_PX := 8.0  # extra screen px around the text that still count as a click
const DIM_LABEL_STACK_MM := 14.0  # labels anchored closer than this stack upward on screen
const DIM_LABEL_STACK_PX := 28.0  # Label3D offset px between stacked labels (> the 18 px font)
## Jaw width / angle callouts stay beside the segment. More than a couple of
## screen steps walks the text off the jaw (sx-036 A8: 45° under the menu).
const JAW_LABEL_MAX_STACK := 2
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
## Screen de-stack: a glyph stays within the cap of its anchor, grows a leader
## once it has moved, and yields to dimension labels by this gap.
const GLYPH_MAX_OFFSET_PX := 40.0
const GLYPH_LEADER_MIN_PX := 12.0
const GLYPH_LABEL_GAP_PX := 4.0
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
	_pick_marker = MeshInstance3D.new()
	_pick_marker.name = "PickMarker"
	_pick_marker.visible = false
	_pick_marker.material_override = _preview_material
	add_child(_pick_marker)
	_selected_material = StandardMaterial3D.new()
	_selected_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selected_material.albedo_color = COLOR_HANDLE
	_selected_node = MeshInstance3D.new()
	_selected_node.material_override = _selected_material
	add_child(_selected_node)
	_contour_fill_material = StandardMaterial3D.new()
	_contour_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_contour_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_contour_fill_material.albedo_color = Color.WHITE
	_contour_fill_material.vertex_color_use_as_albedo = true
	_contour_fill_material.no_depth_test = false
	_contour_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_contour_fill_material.render_priority = -2
	_contour_line_material = StandardMaterial3D.new()
	_contour_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_contour_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_contour_line_material.albedo_color = Color.WHITE
	_contour_line_material.vertex_color_use_as_albedo = true
	_contour_line_material.no_depth_test = false
	_contour_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_contour_line_material.render_priority = -1
	_contour_node = MeshInstance3D.new()
	_contour_node.name = "ContourHighlight"
	_contour_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contour_node)
	_contour_tags = Node3D.new()
	_contour_tags.name = "ContourTags"
	add_child(_contour_tags)
	_contour_tag = Label3D.new()
	_contour_tag.name = "ContourTag"
	_contour_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_contour_tag.fixed_size = true
	_contour_tag.pixel_size = DIM_LABEL_PIXEL
	_contour_tag.font_size = DIM_LABEL_FONT
	_contour_tag.no_depth_test = true
	_contour_tag.visible = false
	_contour_tags.add_child(_contour_tag)
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
	# Axis-aligned plate: one bbox extent is tiny. DocumentView.face_normal
	# returns only the first triangle, which after a boolean can be a sliver
	# and would spin a top-face sketch onto a side plane.
	var min_axis := 0
	var min_ext := extent.x
	if extent.y < min_ext:
		min_ext = extent.y
		min_axis = 1
	if extent.z < min_ext:
		min_ext = extent.z
		min_axis = 2
	var max_ext := maxf(extent.x, maxf(extent.y, extent.z))
	var axis_flat := max_ext > EPS and min_ext <= maxf(1e-4, max_ext * 0.02)
	if axis_flat:
		axis = min_axis
		normal[axis] = 1.0
	elif face_normal.length_squared() > 1e-8:
		normal = face_normal.normalized()
	else:
		ground["message"] = "Face not planar enough — sketching on ground"
		return ground
	var body_bb: Dictionary = doc.measure_bbox(body_id)
	if not body_bb.is_empty():
		var body_center: Vector3 = (body_bb["min"] + body_bb["max"]) * 0.5
		# Outward: pointing away from the body bbox center.
		if (origin - body_center).dot(normal) < 0.0:
			normal = -normal
	# Face sketch: sketch (0,0) is the part origin projected onto the plane,
	# so a top-face sketch snaps the Ø20 centre (part origin) at (0,0).
	var face_point := origin
	origin = Vector3.ZERO - normal * (Vector3.ZERO - face_point).dot(normal)
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


static func _support_side(doc: SxDocument, body_id: String, face_id: String,
		normal: Vector3) -> String:
	var n := normal.normalized()
	var face_bb: Dictionary = doc.measure_bbox(face_id)
	if face_bb.is_empty():
		return "max"
	var face_c: Vector3 = (face_bb["min"] + face_bb["max"]) * 0.5
	var face_off := face_c.dot(n)
	var max_off := face_off
	var min_off := face_off
	for fid in doc.get_face_ids(body_id):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var c: Vector3 = (bb["min"] + bb["max"]) * 0.5
		var off := c.dot(n)
		max_off = maxf(max_off, off)
		min_off = minf(min_off, off)
	if absf(face_off - max_off) <= absf(face_off - min_off):
		return "max"
	return "min"


## Unit normal of the current sketch plane (model space).
func plane_normal() -> Vector3:
	return plane_x.cross(plane_y).normalized()


## 2D AABB of all entities inflated by `pad_frac` (0.2 = 20% past extents).
## Returns {min, max, center, radius} or empty when there is nothing to fit.
## An empty ground sketch stays empty (the caller uses a small default).
## Face sketches — including an empty one just opened on a face — keep the
## part origin (0,0) and the host body so entry / F / Frame show the whole
## face, not a 25 mm window on the origin that hides the far end.
func sketch_extents(pad_frac := 0.2) -> Dictionary:
	if sketch == null:
		return {}
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var have := false
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				mn = mn.min(a).min(b)
				mx = mx.max(a).max(b)
				have = true
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
				have = true
			"point":
				var p: Vector2 = info.get("position", info.get("point", Vector2.ZERO))
				mn = mn.min(p)
				mx = mx.max(p)
				have = true
	if target_fid != "" or support_host != "":
		if not have:
			mn = Vector2.ZERO
			mx = Vector2.ZERO
			have = true
		else:
			mn = mn.min(Vector2.ZERO)
			mx = mx.max(Vector2.ZERO)
		var host := _host_body_uv_aabb()
		if not host.is_empty():
			mn = mn.min(host["min"])
			mx = mx.max(host["max"])
			have = true
	if not have or not is_finite(mn.x):
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
			"half_x": half.x, "half_y": half.y, "min2": mn, "max2": mx}


## Projected 2D AABB of the body this face sketch sits on, in sketch UV.
func _host_body_uv_aabb() -> Dictionary:
	if view == null or view.doc == null:
		return {}
	var body := ""
	if target_fid != "" and view.has_method("body_of_feature"):
		body = view.body_of_feature(target_fid)
	if body == "" and view.selected_body != "":
		body = view.selected_body
	if body == "" and view.doc.body_ids().size() == 1:
		body = view.doc.body_ids()[0]
	if body == "":
		return {}
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return {}
	var bmin: Vector3 = bb["min"]
	var bmax: Vector3 = bb["max"]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for x in [bmin.x, bmax.x]:
		for y in [bmin.y, bmax.y]:
			for z in [bmin.z, bmax.z]:
				var rel := Vector3(x, y, z) - plane_origin
				var uv := Vector2(rel.dot(plane_x), rel.dot(plane_y))
				mn = mn.min(uv)
				mx = mx.max(uv)
	if not is_finite(mn.x):
		return {}
	return {"min": mn, "max": mx}


## Sketch 2D → model space.
func to_model(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


func _clear_support() -> void:
	support_host = ""
	support_normal = Vector3.ZERO
	support_side = ""
	host_face_id = ""


## True when `face_id`'s midpoint sits on the active sketch plane.
func face_lies_on_plane(face_id: String) -> bool:
	if face_id == "" or view == null or view.doc == null:
		return false
	if not view.doc.has_method("face_midpoint"):
		return false
	var mid: Variant = view.doc.face_midpoint(face_id)
	if not (mid is Vector3):
		return false
	var n := plane_normal()
	if n.length_squared() < 1e-12:
		return false
	return absf(((mid as Vector3) - plane_origin).dot(n)) <= 0.75


## Begin a sketch on the model-space plane (origin + normal). x_hint picks the
## in-plane X direction; pass ZERO for an automatic perpendicular (n × world-Z,
## or world-X when the normal is parallel to Z). Extrude follows this normal.
func begin(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO,
		support: Dictionary = {}) -> void:
	editing_fid = ""
	_clear_support()
	if not support.is_empty():
		support_host = str(support.get("host", ""))
		support_normal = support.get("normal", Vector3.ZERO)
		support_side = str(support.get("side", "max"))
		host_face_id = str(support.get("face", ""))
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
	_clear_support()
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
## `announce` is false when Save re-enters the same session: that path must
## not print "Editing sketch" again (the pencil click is the only time).
func begin_edit(fid: String, announce: bool = true) -> bool:
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
	_edit_baseline = loaded.snapshot() if loaded.has_method("snapshot") else ""
	_clear_support()
	_activate_session()
	if announce:
		status.emit("Editing sketch — Exit Sketch to save · Esc discard")
	return true


func _setup_plane(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO) -> void:
	last_dofs = -1
	last_solve_status = ""
	plane_origin = origin
	var n := normal.normalized()
	var x := x_hint
	if x == Vector3.ZERO or absf(x.dot(n)) > 0.99:
		# A top/bottom face whose tessellated normal is a fraction of a degree
		# off ±Z makes n × Z a random in-plane axis, so sketch (200, 0) misses
		# the head. Treat near-horizontal planes as world-XY.
		x = n.cross(Vector3(0, 0, 1))
		if x.length_squared() < 0.04:
			x = Vector3.RIGHT
	plane_x = (x - n * x.dot(n)).normalized()
	plane_y = n.cross(plane_x).normalized()


func _activate_session() -> void:
	active = true
	tool = Tool.LINE
	_esc_exit_promised = false
	_refusal_esc_ladder = false
	_tool_points.clear()
	_drag.clear()
	_smart_dim_pending.clear()
	_last_commit_text = ""
	_jaw_floor_id = ""
	_jaw_arc_id = ""
	_jaw_wall_ids.clear()
	dimensions.clear()
	intersection_points.clear()
	_clear_dimension_labels()
	_restore_dimensions_from_sketch()
	var adopted := _try_adopt_parked_undo()
	_undo_restoring = true
	_enter_camera()
	_redraw()
	if not adopted:
		_reset_undo_history()
	else:
		_undo_head_dims = dimensions.duplicate(true)
	_undo_restoring = false
	_undo_label = ""
	_undo_merge_frame = -1
	_undo_drag_open = false


func _enter_camera() -> void:
	if camera == null:
		return
	camera.sketch_fit = fit_view
	_apply_sketch_frame(sketch_extents(0.2))
	if not camera.view_changed.is_connected(_on_sketch_camera_moved):
		camera.view_changed.connect(_on_sketch_camera_moved)
	# Re-assert after layout/resize handlers settle so nothing zooms us into
	# the 0.1 mm grid behind our back.
	_camera_reassert_gen += 1
	var gen := _camera_reassert_gen
	_reassert_camera_if.call_deferred(gen)


## Drop a pending fit-view reassert (Save restores the live camera pose).
## Also hold restack until reapply_dimension_records so apply_pose cannot
## grow fit-view stacks onto 20 / 45° at 150 px (N1b).
func keep_current_view() -> void:
	_camera_reassert_gen += 1
	_label_restack_hold = _camera_reassert_gen


func _reassert_camera_if(gen: int) -> void:
	if gen != _camera_reassert_gen:
		return
	if not active or camera == null:
		return
	# The first fit runs inside begin(), before the sketch rail is shown.
	# Refit once layout has settled so the whole face lands in the canvas
	# that is actually left of the rail, not the pre-rail column.
	_apply_sketch_frame(sketch_extents(0.2))


func _reassert_camera() -> void:
	if not active or camera == null:
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.size < MIN_SKETCH_VIEW_MM:
		_apply_sketch_frame(sketch_extents(0.2))


## Fit half-extents into the chrome canvas. A wide sketch used to be framed
## as a circle of radius max(half)*1.414 inside the shorter canvas side, which
## left the profile in a loose band of the window.
func _apply_sketch_frame(ext: Dictionary) -> void:
	if camera == null:
		return
	var center: Vector3 = plane_origin
	var hx := 25.0
	var hy := 25.0
	if not ext.is_empty():
		center = ext["center"]
		hx = float(ext.get("half_x", 25.0))
		hy = float(ext.get("half_y", 25.0))
	# Floor the working scale: a sketch framed on a 5 mm blank made screen
	# drags land as sub-millimetre segments (0.15 mm "lines").
	hx = maxf(hx, MIN_SKETCH_VIEW_RADIUS_MM)
	hy = maxf(hy, MIN_SKETCH_VIEW_RADIUS_MM)
	_sketch_view_radius = maxf(hx, hy)
	if camera.has_method("frame_sketch_rect"):
		camera.frame_sketch_rect(plane_normal(), center, hx, hy, plane_y)
	else:
		camera.enter_sketch_view(plane_normal(), center, _sketch_view_radius, plane_y)


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
		if camera.view_changed.is_connected(_on_sketch_camera_moved):
			camera.view_changed.disconnect(_on_sketch_camera_moved)
		camera.sketch_fit = Callable()
		camera.leave_sketch_view()


## Re-stack labels at the current zoom. Pixel offsets that were resolved at
## fit-view overlap again when the head is ~150 px (N1a / N1b).
func _on_sketch_camera_moved() -> void:
	if not active or _undo_restoring or sketch == null:
		return
	var hold := _label_restack_hold != 0 and _label_restack_hold == _camera_reassert_gen
	if not hold and not dimensions.is_empty() and _dimension_labels != null:
		_resolve_label_overlaps()
		var li := 0
		for dim in dimensions:
			if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
				continue
			if li >= _dimension_labels.get_child_count():
				break
			var lab := _dimension_labels.get_child(li) as Label3D
			if lab != null:
				lab.offset = _dimension_label_offset_px(dim)
				lab.position = _to3(dim["label_pos"] as Vector2) + plane_normal() * 0.2
			li += 1
	# Glyph badges are a fixed pixel size. Restack them in screen space whenever
	# the zoom changes, or a 2.5 mm step stays an 8 px pile at a 150 px head.
	_rebuild_constraint_glyphs()


## Discard the session without committing (Esc).
func cancel() -> void:
	if not active:
		return
	_undo_parked.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	active = false
	editing_fid = ""
	_edit_baseline = ""
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
		if sketch.has_method("snapshot") and sketch.snapshot() == _edit_baseline:
			fid = editing_fid
			_end_sketch_session()
			status.emit("Sketch saved")
			return fid
		if view.doc.graph_update_sketch(editing_fid, sketch):
			fid = editing_fid
		else:
			# Graph already rolled back to the last good snapshot. Reload that
			# profile, then leave so a failed regenerate cannot trap the session.
			_reload_editing_sketch()
			_end_sketch_session()
			_emit_discard_status()
			return ""
	else:
		if sketch.entity_ids().is_empty():
			cancel()
			status.emit("Empty sketch discarded — nothing was drawn")
			return ""
		fid = view.doc.graph_add_sketch(sketch)
		if fid == "":
			status.emit("Failed to save sketch" + _graph_error_suffix())
			return ""
		_write_sketch_support(fid)
		# Park undo against the feature Save is about to reopen.
		editing_fid = fid
	_end_sketch_session()
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
	# Auto-commit an in-progress Polygon/Circle/Rect/Slot tip so Extrude
	# doesn't see only a preview ghost and report "open profile". Pass the
	# live hover: click() snaps that pick for direction, then locks the
	# typed length. Passing effective_hover() here would snap the already
	# scaled tip onto projected model points and steer the arm the wrong way.
	if has_pending_draw_point():
		click(_hover)
	_try_close_open_chain()
	# Two circles plus tangents split into a holed face. Replace each boss
	# the lines land on with its outer arc so the blank extrudes solid.
	# Selecting every contour means "all regions". Seal rewrites the bosses,
	# so those pre-seal indices are no longer the post-seal faces — pass an
	# empty list and the kernel keeps every region.
	var wanted_all := false
	if sketch != null and sketch.has_method("contour_count"):
		var before_seal := int(sketch.contour_count())
		if before_seal > 0 and selected_contours.size() >= before_seal:
			wanted_all = true
	# Solve first so tangent / on-circle constraints pull endpoints onto the
	# circles. Lock sized circles so that solve cannot translate a typed Ø20
	# off the origin or change radii. DogLeg may still jump a horizontal
	# tangent to the far side of a locked Ø20 — put that line back, weld,
	# then seal. The 1e-6 profile check then sees a closed wire.
	if sketch != null:
		_lock_sized_circles()
		_weld_on_circle_endpoints()
		var pre_solve := _snapshot_line_geometry()
		run_solve()
		_restore_flipped_shaft_lines(pre_solve)
		_weld_on_circle_endpoints()
		_sync_tangent_pins()
		_reweld_jaw_profile()
	# Drop the leftover redrawn Ø45 before seal. Trim that missed the 15%
	# gate left that full circle; seal would turn it into a second cap and
	# the 1e-6 jaw joints would then fail.
	_drop_circles_concentric_with_jaw_arcs()
	_seal_tangent_bosses()
	_reweld_jaw_profile()
	if wanted_all:
		selected_contours = []
	var open_prof := not profile_is_closed(sketch)
	if thin_thickness <= 0.0 and open_prof:
		if op == "cut" or op == "fuse":
			_refuse_extrude(_chain_breaker_status())
		else:
			_refuse_extrude(_open_profile_status())
		return
	if op != "new" and target_fid == "":
		_refuse_extrude("No target body — sketch on a face to cut/fuse")
		return
	if op == "cut":
		distance = -absf(distance)
	# Up To Surface with nothing picked must not extrude the host face.
	# Do not read view.selected_face — that face is the sketch itself.
	if end == "to_face" and _up_to_face_id() == "":
		_refuse_extrude("Up To Surface needs a face")
		return
	var symmetric := end == "midplane"
	var sk_fid := _ensure_sketch_feature()
	if sk_fid == "":
		arm_refusal_exit_ladder()
		_reassert_camera()
		return
	var vol_before := _body_volume(view.body_of_feature(target_fid)) if op == "cut" else -1.0
	var to_face_id := _up_to_face_id() if end == "to_face" else ""
	var ex_fid: String = view.doc.graph_add_extrude(
		sk_fid, distance, symmetric, op, target_fid if op != "new" else "", end,
		thin_thickness, thin_type, flip_side, selected_contours, to_face_id)
	if ex_fid == "" and _graph_error_text().contains("Thin wall"):
		_refuse_extrude(_graph_error_text())
		return
	if ex_fid != "" and op == "cut" and vol_before > 0.0:
		var vol_after := _body_volume(view.body_of_feature(target_fid))
		var refuse := _cut_refusal(vol_before, vol_after)
		if refuse != "":
			view.doc.graph_remove(ex_fid)
			view.refresh()
			_refuse_extrude(refuse)
			return
	if ex_fid != "" and op != "new":
		var open_reason := _open_shell_reason(view.body_of_feature(target_fid))
		if open_reason != "":
			view.doc.graph_remove(ex_fid)
			view.refresh()
			_refuse_extrude(_open_shell_refusal(op, open_reason))
			return
	var fail_msg := "Extrude failed — is the profile closed?"
	_finish_feature(sk_fid, ex_fid, op, fail_msg)


## Refusal kept the sketch open. Say why, and make the next Esc the exit ladder.
func _refuse_extrude(msg: String) -> void:
	if msg != "":
		status.emit(msg)
	arm_refusal_exit_ladder()
	_reassert_camera()


const CUT_MAX_REMOVED_FRACTION := 0.5
const CUT_MIN_REMOVED_MM3 := 1e-3


func _body_volume(body_id: String) -> float:
	if body_id == "" or view == null or view.doc == null:
		return -1.0
	return float(view.doc.measure_mass(body_id).get("volume", -1.0))


## "" when the body exports as a closed mesh, else the kernel's own
## "3MF mesh is open (bad/total edges not shared twice)" sentence. Uses the
## exporter's check so the refusal and a later File > Export agree.
func _open_shell_reason(body_id: String) -> String:
	if body_id == "" or view == null or view.doc == null:
		return ""
	if not view.doc.has_method("export_3mf_for_body"):
		return ""
	var dir := OS.get_cache_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("sx-open-shell-probe.3mf")
	var ok: bool = view.doc.export_3mf_for_body(body_id, path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if ok:
		return ""
	var err := str(view.doc.last_export_error())
	return err if err.contains("mesh is open") else ""


func _open_shell_refusal(op: String, reason: String) -> String:
	var counts := reason.substr(reason.find("(")) if reason.contains("(") else ""
	var verb := "cut" if op == "cut" else "fused"
	return "%s left an open shell %s. Nothing was %s — the contour overlaps or sits on the body's own edge. Fix the contour and try again." % [
			"Cut" if op == "cut" else "Fuse", counts, verb]


## Named refusal for a cut that boolean-succeeded but wrecked the body.
## Empty string = accept.
func _cut_refusal(before: float, after: float) -> String:
	if after < 0.0:
		return "Cut removed the whole body — the sketch contour is not inside the face. Fix the contour or pick Selected Contours."
	var removed := before - after
	if removed <= CUT_MIN_REMOVED_MM3:
		return "Cut removed nothing — the contour does not reach the body. Check the contour and the Up To Surface face."
	if removed > before * CUT_MAX_REMOVED_FRACTION:
		return "Cut would remove %d%% of the body — the contour covers most of it. Nothing was cut." % int(round(100.0 * removed / before))
	return ""


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


func _write_sketch_support(fid: String) -> void:
	if support_host == "" or view == null or view.doc == null:
		return
	var params := {}
	for f in view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			params = parsed
		break
	params["support_host"] = support_host
	params["support_normal"] = [support_normal.x, support_normal.y, support_normal.z]
	params["support_side"] = support_side if support_side != "" else "max"
	view.doc.graph_set_params_no_regen(fid, JSON.stringify(params))


## Ensure the active sketch is a graph feature; reuse editing_fid when set.
func _ensure_sketch_feature() -> String:
	if editing_fid != "":
		if not view.doc.graph_update_sketch(editing_fid, sketch):
			# Keep the session so the person can keep drawing; Exit can still leave.
			_reload_editing_sketch()
			return ""
		return editing_fid
	var sk_fid: String = view.doc.graph_add_sketch(sketch)
	if sk_fid == "":
		status.emit("Failed to add sketch" + _graph_error_suffix())
	else:
		editing_fid = sk_fid
		_write_sketch_support(sk_fid)
	return sk_fid


## Replace the in-memory sketch with the graph's last accepted profile.
func _reload_editing_sketch() -> bool:
	if editing_fid == "" or view == null or view.doc == null:
		return false
	if not view.doc.has_method("graph_get_sketch"):
		return false
	var loaded: SxSketch = view.doc.graph_get_sketch(editing_fid)
	if loaded == null:
		return false
	sketch = loaded
	_restore_dimensions_from_sketch()
	return true


## Same cleanup a successful Exit uses. Always leaves `active` false.
func _end_sketch_session() -> void:
	_park_undo_history()
	active = false
	editing_fid = ""
	_edit_baseline = ""
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


func _undo_note(label: String) -> void:
	_undo_label = label


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


## True while undo() / redo() is applying a snapshot. Selection-chip refresh
## during that window must hide relation suggestions instead of rebuilding them.
func is_undo_restoring() -> bool:
	return _undo_restoring


func undo() -> String:
	if _undo_stack.is_empty() or sketch == null:
		return ""
	var entry: Dictionary = _undo_stack.pop_back()
	_redo_stack.append(_undo_current_entry(str(entry.get("label", ""))))
	return _restore_undo_entry(entry)


func redo() -> String:
	if _redo_stack.is_empty() or sketch == null:
		return ""
	var entry: Dictionary = _redo_stack.pop_back()
	_undo_stack.append(_undo_current_entry(str(entry.get("label", ""))))
	return _restore_undo_entry(entry)


func _undo_current_entry(label: String) -> Dictionary:
	return {
		"json": _undo_head,
		"dimensions": _undo_head_dims.duplicate(true),
		"label": label,
	}


func _restore_undo_entry(entry: Dictionary) -> String:
	var json := str(entry.get("json", ""))
	var dims: Array = entry.get("dimensions", [])
	_undo_restoring = true
	if json != "" and sketch.has_method("restore"):
		sketch.restore(json)
	dimensions = dims.duplicate(true)
	_tool_points.clear()
	_set_selected([])
	selected_constraint = ""
	_jaw_floor_id = ""
	_jaw_arc_id = ""
	_jaw_wall_ids.clear()
	_drag.clear()
	_trim_dragging = false
	if sketch.entity_ids().is_empty():
		last_dofs = -1
		last_solve_status = ""
		solve_updated.emit(-1, "", 0)
	else:
		run_solve()
	_redraw()
	_undo_head = json
	if _undo_head == "" and sketch.has_method("snapshot"):
		_undo_head = sketch.snapshot()
	_undo_head_dims = dimensions.duplicate(true)
	_undo_restoring = false
	_undo_label = ""
	_undo_drag_open = false
	_undo_merge_frame = -1
	return str(entry.get("label", ""))


func _reset_undo_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_set_undo_head_from_live()


func _set_undo_head_from_live() -> void:
	if sketch != null and sketch.has_method("snapshot"):
		_undo_head = sketch.snapshot()
	else:
		_undo_head = ""
	_undo_head_dims = dimensions.duplicate(true)


func _park_undo_history() -> void:
	_undo_parked = {
		"fid": editing_fid,
		"undo": _undo_stack.duplicate(true),
		"redo": _redo_stack.duplicate(true),
		"head_json": _undo_head,
		"head_dims": _undo_head_dims.duplicate(true),
		"frame": Engine.get_process_frames(),
	}
	_undo_stack.clear()
	_redo_stack.clear()


func _try_adopt_parked_undo() -> bool:
	if _undo_parked.is_empty():
		return false
	var parked: Dictionary = _undo_parked.duplicate(true)
	_undo_parked.clear()
	if Engine.get_process_frames() != int(parked.get("frame", -1)):
		return false
	var pfid := str(parked.get("fid", ""))
	if pfid != "" and pfid != editing_fid:
		return false
	if sketch == null:
		return false
	# Save reloads the feature. The snapshot string often differs after that
	# round-trip even though this is the same session. Dropping the stacks
	# on that mismatch made Ctrl+Z say "Nothing to undo" after Save As.
	_undo_stack = parked.get("undo", []).duplicate(true)
	_redo_stack = parked.get("redo", []).duplicate(true)
	var parked_dims: Array = parked.get("head_dims", [])
	dimensions = _merge_dimension_records(
			_dimension_records_from_sketch(), parked_dims)
	_set_undo_head_from_live()
	_undo_label = ""
	return true


func _undo_tool_label() -> String:
	if _jaw_armed:
		return "Jaw"
	match tool:
		Tool.LINE, Tool.CENTERLINE:
			return "Line"
		Tool.CIRCLE:
			return "Circle"
		Tool.RECT:
			return "Rect"
		Tool.POLYGON:
			return "Polygon"
		Tool.SLOT:
			return "Slot"
		Tool.ARC:
			return "Arc"
		Tool.SPLINE:
			return "Spline"
		Tool.POINT:
			return "Point"
		Tool.ELLIPSE:
			return "Ellipse"
		Tool.CHAMFER:
			return "Chamfer"
		Tool.TRIM:
			return "Trim"
		Tool.EXTEND:
			return "Extend"
		Tool.SMART_DIM:
			return "Dimension"
		Tool.CONVERT:
			return "Convert"
		Tool.MIRROR:
			return "Mirror"
		Tool.PATTERN:
			return "Pattern"
		Tool.SELECT:
			return "Edit"
		_:
			return "Edit"


func _capture_undo_if_changed() -> void:
	if sketch == null or _undo_restoring:
		return
	if not sketch.has_method("snapshot"):
		return
	var json: String = sketch.snapshot()
	if json == _undo_head:
		return
	var frame := Engine.get_process_frames()
	var dragging := not _drag.is_empty() or _trim_dragging
	var merge := false
	if not _undo_stack.is_empty():
		if _undo_merge_frame == frame:
			merge = true
		elif _undo_drag_open:
			merge = true
	if merge:
		_undo_head = json
		_undo_head_dims = dimensions.duplicate(true)
		_undo_label = ""
		if not dragging:
			_undo_drag_open = false
		return
	var label := _undo_label
	if label == "":
		label = _undo_tool_label()
	_undo_stack.append({
		"json": _undo_head,
		"dimensions": _undo_head_dims.duplicate(true),
		"label": label,
	})
	if _undo_stack.size() > UNDO_STACK_MAX:
		_undo_stack.remove_at(0)
	_redo_stack.clear()
	_undo_head = json
	_undo_head_dims = dimensions.duplicate(true)
	_undo_label = ""
	_undo_merge_frame = frame
	_undo_drag_open = dragging


func _emit_discard_status() -> void:
	var err := _graph_error_text()
	if err == "":
		status.emit("Sketch edit discarded")
	else:
		status.emit("Sketch edit discarded — " + err)


func _graph_error_text() -> String:
	if view == null or view.doc == null or not view.doc.has_method("last_graph_error"):
		return ""
	return str(view.doc.last_graph_error()).strip_edges()


func _graph_error_suffix() -> String:
	var err := _graph_error_text()
	if err == "":
		return ""
	return " — " + err


func _up_to_face_id() -> String:
	var chrome := _sketch_chrome()
	if chrome == null:
		return ""
	return str(chrome.up_to_face_id).strip_edges()


## Signed sketch-plane → Up To Surface face depth (mm). NAN when the face is
## missing or has no midpoint. Status uses this instead of the Blind spinbox.
func up_to_surface_depth() -> float:
	var face_id := _up_to_face_id()
	if face_id == "" or view == null or view.doc == null:
		return NAN
	if not view.doc.has_method("face_midpoint"):
		return NAN
	var n := plane_normal()
	if n.length_squared() < 1e-12:
		return NAN
	n = n.normalized()
	var mid: Variant = view.doc.face_midpoint(face_id)
	if not (mid is Vector3):
		return NAN
	return absf(((mid as Vector3) - plane_origin).dot(n))


var _contour_sig := ""
var _contour_id_sig := ""


func _sync_contour_bar() -> void:
	# The finish bar only listed contours at session start, so a three-region
	# blank never offered Selected Contours until the next New.
	# Geometry is part of the signature: a Smart Dim moves a circle without
	# changing entity ids, and the filled disc must follow.
	var ids: PackedStringArray = sketch.entity_ids()
	var id_sig := ",".join(ids)
	var full := id_sig + "|" + _contour_geom_sig()
	if full == _contour_sig:
		return
	var ids_changed := id_sig != _contour_id_sig
	_contour_id_sig = id_sig
	_contour_sig = full
	if ids_changed:
		var chrome := _sketch_chrome()
		if chrome != null:
			chrome.refresh_contours(sketch)
	_redraw_contour_highlight()


func _contour_geom_sig() -> String:
	if sketch == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var ty := str(info.get("type", ""))
		match ty:
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				parts.append("%s:L:%.3f,%.3f,%.3f,%.3f" % [id, a.x, a.y, b.x, b.y])
			"circle", "arc":
				var c: Vector2 = info["center"]
				parts.append("%s:%s:%.3f,%.3f,%.3f" % [
					id, ty, c.x, c.y, float(info.get("radius", 0.0))])
			"point":
				var p: Vector2 = info.get("position", info.get("point", Vector2.ZERO))
				parts.append("%s:P:%.3f,%.3f" % [id, p.x, p.y])
			_:
				parts.append("%s:%s" % [id, ty])
	return "|".join(parts)


func _sketch_chrome() -> SketchContextChrome:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.find_child("SketchContextChrome", true, false) as SketchContextChrome


## Copy a stashed Up To Surface face onto the new extrude. The finish signal
## arity does not carry the id; the chrome object does.
func _store_up_to_face(ex_fid: String) -> void:
	if ex_fid == "" or view == null or view.doc == null:
		return
	var chrome := _sketch_chrome()
	if chrome == null:
		return
	var face_id := str(chrome.up_to_face_id).strip_edges()
	if face_id == "":
		return
	var params: Dictionary = {}
	for f in view.doc.graph_features():
		if str(f.get("id", "")) == ex_fid:
			var parsed = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(parsed) == TYPE_DICTIONARY:
				params = parsed
			break
	if params.is_empty():
		return
	params["to_face"] = face_id
	if not view.doc.graph_set_params(ex_fid, JSON.stringify(params)):
		status.emit("Up To Surface face was not stored" + _graph_error_suffix())


func _finish_feature(sk_fid: String, feat_fid: String, op: String, fail_msg: String) -> void:
	if feat_fid == "":
		# Kernel rejected the feature. Keep the sketch feature and the session
		# so the next attempt does not start over, and surface last_graph_error.
		_refuse_extrude(fail_msg + _graph_error_suffix())
		return
	_store_up_to_face(feat_fid)
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
	view.refresh()
	view.document_changed.emit()
	view.select_entity(body_id, "")
	finished.emit(body_id)
	# The pose restored above is the view from before the sketch. On a new
	# part that pose is still the empty-scene orbit (~15 mm), which sits
	# inside a blank the size of the wrench. Frame the new body the way F
	# does. Cuts and fuses keep the restored pose (the part was already in
	# view). Do not emit "Framed …" — the Extrude sentence owns the status.
	if op == "new":
		_frame_new_body()


## Fit the body just created. Selection is the new body; fall back to all.
func _frame_new_body() -> void:
	if camera == null:
		return
	if camera.frame_selection():
		return
	camera.frame_contents()


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
## Emitted after set_tool_variant. The chip row re-highlights the active chip.
signal tool_variant_changed
## Emitted when selection chips should refresh (ids may be empty).
signal selection_actions_needed
## Live rubber-band distance (mm) while a single-DOF draw step is active.
signal preview_distance_changed(distance: float)


func set_tool(t: Tool) -> void:
	# Re-arming a tool spends the "next Esc leaves" promise. The tool-drop
	# rung applies again until a new pending point is dropped.
	_esc_exit_promised = false
	if not _drag.is_empty():
		end_drag()
	_jaw_armed = _arming_jaw and t == Tool.RECT
	_arming_jaw = false
	tool = t
	_tool_points.clear()
	_spline_pts.clear()
	_smart_dim_first = null
	_smart_dim_pending.clear()
	_length_override = -1.0
	_trim_hover_id = ""
	_trim_dragging = false
	_trim_drag_ids.clear()
	_free_trim_trail()
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
		Tool.POLYGON:
			tool_variant = _polygon_variant
		_:
			pass
	# Do not clear selection on tool switch — completed geometry must stay
	# visible/selectable (polygon/circle vanishing after another tool was a bug).
	_snap_marker = null
	_update_preview()
	tool_changed.emit(int(t))
	var hint := tool_arm_hint(t)
	if hint != "":
		status.emit(hint)


## One-line status when a rail tool (or shortcut) is armed. Empty = keep the
## previous line. Slot must say `Slot —` so a walker can tell it actually armed.
func tool_arm_hint(t: Tool) -> String:
	match t:
		Tool.SELECT:
			return "Select — click geometry, or a dimension label to edit it"
		Tool.LINE:
			return "Line — click 2 points (or type a length)"
		Tool.ARC:
			return "Arc — click the centre, then the start, then the end"
		Tool.CIRCLE:
			return "Circle — click the centre, then the rim (or type a radius)"
		Tool.RECT:
			return "Rect — click 1 first corner, click 2 the opposite corner"
		Tool.POLYGON:
			return "Polygon — click the centre, then a vertex (or type the size)"
		Tool.ELLIPSE:
			return "Ellipse — click the centre, then a corner of the box"
		Tool.SLOT:
			return "Slot — type the radius, click the first centre, then the second (or type the length)"
		Tool.SPLINE:
			return "Spline — click fit points; Done / Esc / right-click to finish"
		Tool.POINT:
			return "Point — click to place a sketch point"
		Tool.TRIM:
			return "Trim — drag across entities to trim them"
		Tool.EXTEND:
			return "Extend — click a segment to extend it to the next"
		Tool.SMART_DIM:
			return "Smart Dim — click geometry to dimension it"
		Tool.CONVERT:
			return "Convert — click to convert pierce points"
		Tool.MIRROR:
			return "Mirror — select geometry and a mirror axis, then click"
		Tool.PATTERN:
			return "Pattern — select geometry, then a linear or circular variant"
		Tool.CENTERLINE:
			return "Centerline — click 2 points (construction, never part of the profile)"
		_:
			return ""


func is_jaw_armed() -> bool:
	return _jaw_armed


## Rail "Jaw" button: Rectangle tool, Center Three Point variant.
func start_jaw_tool() -> void:
	_arming_jaw = true
	set_tool(Tool.RECT)
	set_tool_variant("center_three_point")


func set_tool_variant(v: String) -> void:
	tool_variant = v
	if tool == Tool.POLYGON and (v == "across_flats" or v == "vertex"):
		_polygon_variant = v
	if _jaw_armed and v != "center_three_point":
		_jaw_armed = false
		tool_changed.emit(int(tool))
	_tool_points.clear()
	_length_override = -1.0
	_update_preview()
	status.emit(_variant_arm_hint(v))
	tool_variant_changed.emit()


## Chip-variant arm sentence. Jaw keeps JAW_HINT; Circle Three Point is the
## listed distinct gesture; every other variant re-emits the tool sentence so
## the status still names the armed tool. The `Variant: %s` form stays as the
## fallback for a tool with no arm hint (byte-identical existing emit).
func _variant_arm_hint(v: String) -> String:
	if v == "center_three_point":
		return JAW_HINT
	if tool == Tool.CIRCLE and v == "three_point":
		return "Circle · Three Point — click 3 points on the rim"
	var hint := tool_arm_hint(tool)
	if hint != "":
		return hint
	return "Variant: %s" % v.replace("_", " ")


## True when a draw tool has the first anchor and is waiting for the tip.
func has_pending_draw_point() -> bool:
	match tool:
		Tool.RECT:
			if tool_variant == "center_three_point" or tool_variant == "three_point" \
					or tool_variant == "parallelogram":
				return _tool_points.size() >= 1
			return _tool_points.size() == 1
		Tool.LINE, Tool.CENTERLINE, Tool.CIRCLE, Tool.POLYGON, \
				Tool.SLOT, Tool.ELLIPSE, Tool.ARC:
			return _tool_points.size() == 1
		_:
			return false


## Esc with a first anchor placed: drop the anchor and keep the sketch session.
func cancel_pending_draw() -> void:
	_tool_points.clear()
	_length_override = -1.0
	_update_preview()


## A stationary mouse-up lands on the anchor that the press just stored.
## That is not a second point: keep the anchor so the next click can finish
## the segment. A real second point closer than MIN_SEGMENT_MM is rejected
## without clearing the first anchor.
func reject_tiny_draw(pos2: Vector2) -> void:
	if _tool_points.is_empty():
		return
	var prev: Vector2 = _tool_points[_tool_points.size() - 1]
	var dist := prev.distance_to(pos2)
	if dist < 1e-4:
		return
	if dist < MIN_SEGMENT_MM:
		status.emit("Too short — drag further (view is %.0f mm across)" % _view_span_mm())
		_update_preview()
		return
	click(pos2)


## If the sketch is a single open polyline whose ends nearly meet, add a
## closing segment so Extrude can build a solid (wrench outline, etc.).
## When `force`, connect the two open ends regardless of distance (Done/Esc).
## Never "closes" a lone segment (that would only duplicate the same edge).
func _try_close_open_chain(tol: float = 0.5, force: bool = false) -> void:
	if sketch == null or profile_is_closed(sketch, tol):
		return
	var ends: Array = []  # unmatched endpoints
	var line_count := 0
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
		line_count += 1
		ends.append(a)
		ends.append(b)
	if line_count < 2:
		return
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
	if open_pts.size() == 2 and (force \
			or open_pts[0].distance_to(open_pts[1]) <= maxf(tol * 8.0, 5.0)):
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


## Digits type into the dim blank, not Extrude Distance. Slot and Circle
## radius are typed as soon as the tool is armed, before the first centre.
func wants_dim_length_keys() -> bool:
	if not active:
		return false
	if has_single_dof_preview():
		return true
	return tool == Tool.SLOT or tool == Tool.CIRCLE


## Rubber-band length currently shown (override or mouse distance).
func preview_distance() -> float:
	if not has_single_dof_preview():
		return 0.0
	if _length_override >= 0.0:
		return _length_override
	if tool == Tool.POLYGON and tool_variant == "across_flats":
		return _tool_points[0].distance_to(_polygon_pointer_tip(_tool_points[0], _hover))
	return _tool_points[_tool_points.size() - 1].distance_to(_hover)


## Lock rubber-band length; mouse keeps steering direction.
func set_length_override(v: float) -> void:
	_length_override = maxf(v, 0.01)
	if tool == Tool.CIRCLE:
		circle_radius = _length_override
	elif tool == Tool.SLOT and not has_single_dof_preview():
		slot_radius = _length_override
	else:
		remember_numeric(_length_override)
	_update_preview()
	preview_distance_changed.emit(_length_override)


## Dim-blank identity. Slot radius and Slot c-c are different fields.
func numeric_field_key() -> String:
	match tool:
		Tool.LINE:
			return "line"
		Tool.CENTERLINE:
			return "centerline"
		Tool.CIRCLE:
			return "circle"
		Tool.SLOT:
			return "slot_cc" if has_single_dof_preview() else "slot_radius"
		Tool.ARC:
			return "arc"
		Tool.POLYGON:
			return "polygon:" + tool_variant
		Tool.ELLIPSE:
			return "ellipse"
		_:
			return "tool:%d" % int(tool)


## This field's own number, or -1 when the blank should be empty.
func own_numeric() -> float:
	if tool == Tool.CIRCLE:
		return circle_radius
	if tool == Tool.SLOT and not has_single_dof_preview():
		return slot_radius
	var key := numeric_field_key()
	if _tool_numeric.has(key):
		return float(_tool_numeric[key])
	return -1.0


func remember_numeric(v: float, key: String = "") -> void:
	if is_nan(v) or is_inf(v) or v < 0.01:
		return
	if key == "":
		key = numeric_field_key()
	_tool_numeric[key] = v


## File → New / Open. Tool numbers belong to the document that set them.
func reset_tool_numerics() -> void:
	circle_radius = DEFAULT_CIRCLE_RADIUS
	slot_radius = DEFAULT_SLOT_RADIUS
	_tool_numeric.clear()
	_length_override = -1.0


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
		if tool == Tool.POLYGON and _tool_points.size() == 1:
			return _polygon_pointer_tip(_tool_points[0], _hover)
		return _hover
	var last: Vector2 = _tool_points[_tool_points.size() - 1]
	var d := _hover - last
	if d.length_squared() < 1e-12:
		return last + Vector2(_length_override, 0.0)
	return last + d.normalized() * _length_override


## Commit the next click at `length` along the current hover direction.
## Returns false when no single-DOF preview is active, or when `length` is
## below MIN_SEGMENT_MM (typed arm must not sneak a 0.01 mm segment through).
func commit_at_length(length: float) -> bool:
	if not has_single_dof_preview():
		return false
	if length < MIN_SEGMENT_MM:
		status.emit("Too short")
		return false
	set_length_override(length)
	# Pass the live hover so click() snaps the pointer for direction, then
	# locks `length`. click(effective_hover()) would snap the scaled tip.
	click(_hover)
	return not has_length_override()


## Sentence from the last polygon-AF / circle / centre-to-flat / slot commit.
func last_commit_text() -> String:
	return _last_commit_text


## Slot stadium readback. Four decimals so a rubber-band 150.3466 is visible.
func slot_cc_status(cc: float, typed: bool = false) -> String:
	return "Slot c-c %.4f R%.4f%s" % [cc, slot_radius, " — typed" if typed else ""]


## Slot c-c readback for a recorded dimension, or "" if it is not a slot stadium.
func slot_cc_status_for_dim(index: int) -> String:
	if sketch == null or index < 0 or index >= dimensions.size():
		return ""
	return slot_cc_status_for_record(dimensions[index])


## Same readback from a dimension record captured before a label rebuild.
## #154 collapses duplicate label texts and reindexes `dimensions` inside
## set_dimension_value, so the index the editor held can point at another dim.
func slot_cc_status_for_record(dim: Dictionary) -> String:
	if sketch == null or dim.is_empty():
		return ""
	if str(dim.get("type", "")) != "distance":
		return ""
	var ids: Array = dim.get("ids", [])
	if ids.size() != 2:
		return ""
	var r := -1.0
	for id in ids:
		var info: Dictionary = sketch.entity_info(str(id))
		if str(info.get("type", "")) != "arc":
			return ""
		r = float(info.get("radius", 0.0))
	if r <= 0.0:
		r = slot_radius
	return "Slot c-c %.4f R%.4f" % [float(dim.get("value", 0.0)), r]


## True when this session is a new sketch with no entities yet.
func is_empty_new_sketch() -> bool:
	return active and editing_fid == "" and sketch != null \
			and sketch.entity_ids().is_empty()


const JAW_HINT := "Jaw — click 1 centre, click 2 end of the long side, click 3 half the width"
const JAW_PREVIEW_ASPECT := 0.4
const JAW_PREVIEW_MIN_HALF_W_MM := 1.5
const CIRCLE_CENTRE_SET := "Circle — centre set, click the rim or type a radius"
const JAW_AFTER_CENTRE := "Jaw — centre set, click 2 end of the long side"
const JAW_AFTER_LONG := "Jaw — long side set, click 3 half the width"
const JAW_ZERO_WIDTH := "Jaw — width is zero — click 3 again for half the width"
const JAW_ZERO_LONG := "Jaw — long side is zero — click 2 again for the end of the long side"


func variants_for_tool(t: Tool = tool) -> Array:
	match t:
		Tool.RECT:
			if _jaw_armed:
				return []
			# SolidWorks rectangle flyout: Corner, Center, 3 Point Corner,
			# 3 Point Center, Parallelogram. Corner is the default (first).
			return ["corner", "center", "three_point", "center_three_point", "parallelogram"]
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
		if (t0 == "circle" or t0 == "arc") and (t1 == "circle" or t1 == "arc"):
			acts.append("shaft_lines")
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


## Two circles selected, one larger: add the two shaft lines of the handout.
## Each line runs parallel to the centre line, tangent to the smaller circle
## at its top or bottom and ending where it meets the larger circle on the
## side nearer the small one. Both go through _infer_line, the same path a
## hand-drawn shaft line takes, so they get the tangent constraint on the small
## circle, the on-circle constraint on the large one, and the flip guard.
## Returns the number of lines added.
func shaft_lines_selected() -> int:
	if sketch == null or selected.size() != 2:
		status.emit("Shaft lines: select two circles first")
		return 0
	var ia: Dictionary = sketch.entity_info(selected[0])
	var ib: Dictionary = sketch.entity_info(selected[1])
	for info in [ia, ib]:
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			status.emit("Shaft lines: select two circles first")
			return 0
	var small: Dictionary = ia
	var large: Dictionary = ib
	if float(ia["radius"]) > float(ib["radius"]):
		small = ib
		large = ia
	var cs: Vector2 = small["center"]
	var cl: Vector2 = large["center"]
	var rs := float(small["radius"])
	var rl := float(large["radius"])
	var d := cs.distance_to(cl)
	if rl - rs <= 1e-4:
		status.emit("Shaft lines: the two circles are the same size")
		return 0
	if d <= rl:
		status.emit("Shaft lines: the small circle must sit outside the large one")
		return 0
	var u := (cl - cs) / d
	var perp := Vector2(-u.y, u.x)
	var neck := d - sqrt(rl * rl - rs * rs)
	var added := 0
	var lids: Array[String] = []
	var geos: Array[Dictionary] = []
	for side in [1.0, -1.0]:
		var off := perp * (rs * float(side))
		var pa := cs + off
		var pb := cs + off + u * neck
		var lid: String = sketch.add_line(pa.x, pa.y, pb.x, pb.y)
		if lid == "":
			continue
		# pin_tangent: the centre-distance already carries a horizontal, so a
		# point-on-circle at the tangent contact duplicates the tangent and
		# the typed radius (PlaneGCS reports that as redundant / conflicting).
		_infer_line(lid, pa, pb, true)
		lids.append(lid)
		geos.append({"start": pa, "end": pb})
		added += 1
	# The second line's solve can drag the first onto the same side. Put both
	# back on the constructed sides (no extra Fix: Fix + H conflicts on A3).
	_pin_shaft_line_pair(lids, geos)
	if added > 0:
		_undo_note("Shaft lines")
	status.emit("Shaft lines: %d added" % added)
	_redraw()
	return added


## The second line's solve can drag the first onto the same side. Put both
## back on the constructed sides without adding Fix (Fix + H conflicts on A3).
func _pin_shaft_line_pair(lids: Array[String], geos: Array[Dictionary]) -> void:
	if lids.is_empty():
		return
	for i in lids.size():
		sketch.set_entity_geometry(lids[i], geos[i])
	_weld_on_circle_endpoints()
	_sync_tangent_pins()


func set_snap(on: bool) -> void:
	snap_enabled = on
	if not on:
		_snap_marker = null


func set_infer(on: bool) -> void:
	infer_enabled = on
	if not on and _infer_label != null:
		_infer_label.visible = false


## Snap radius grows with the ortho view so a 232 mm part can still hit the
## origin. Never tighter than SNAP_RADIUS.
func _snap_radius() -> float:
	var span := _view_span_mm()
	return clampf(maxf(SNAP_RADIUS, span * 0.02), SNAP_RADIUS, maxf(SNAP_RADIUS, span * 0.08))


## Snap sketch-plane point to nearby geometry / axis. Priority:
## (a) entity endpoints, (b) line midpoints, circle/arc centers, sketch (0,0)
## and projected circular-edge centres, (c) H/V alignment to the last
## in-progress tool point. When snap_enabled is false, returns p unchanged.
func snap_point(p: Vector2) -> Vector2:
	_snap_marker = null
	if not snap_enabled or sketch == null:
		return p
	var rad := _snap_radius()
	# (a) endpoints
	var best_d := rad
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
	# (b) midpoints, sketch centres, part origin, projected arc centres
	best_d = rad
	found = false
	var centers: Array[Vector2] = [Vector2.ZERO]
	centers.append_array(_model_circle_centers())
	for id in sketch.entity_ids():
		for mp in _snap_mid_centers(id):
			centers.append(mp)
	for ip in intersection_points:
		centers.append(ip)
	for mp in centers:
		var d2 := p.distance_to(mp)
		if d2 <= best_d:
			best_d = d2
			best_pt = mp
			found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# Tangent contact before H/V. A horizontal chord already on the circle
	# (the wrench blank) must still take the axis snap — projecting onto the
	# rim first walks that click off y = constant and the blank stops being
	# three contours.
	var tang: Variant = _snap_line_tangent(p)
	if tang != null:
		_snap_marker = tang
		return tang
	# (c) axis alignment from last committed tool point
	if not _tool_points.is_empty():
		var last: Vector2 = _tool_points[_tool_points.size() - 1]
		var out := p
		var snapped_axis := false
		if absf(p.x - last.x) <= rad:
			out.x = last.x
			snapped_axis = true
		if absf(p.y - last.y) <= rad:
			out.y = last.y
			snapped_axis = true
		if snapped_axis:
			_snap_marker = out
			return out
	# Near the rim, not a tangent and not on an axis.
	var circ: Variant = _snap_line_on_circle(p)
	if circ != null:
		_snap_marker = circ
		return circ
	return p


func _line_snap_armed() -> bool:
	return (tool == Tool.LINE or tool == Tool.CENTERLINE) and sketch != null


## Tangent contact from the anchored end. Empty until the line tool has an
## anchor, and only when the cursor is within the snap radius of a contact.
func _snap_line_tangent(p: Vector2) -> Variant:
	if not _line_snap_armed() or _tool_points.is_empty():
		return null
	var anchor: Vector2 = _tool_points[_tool_points.size() - 1]
	var best_d := _snap_radius()
	var best: Variant = null
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		var c: Vector2 = info["center"]
		var r: float = float(info.get("radius", 0.0))
		for t in _circle_tangent_points(anchor, c, r):
			var d := p.distance_to(t)
			if d <= best_d:
				best_d = d
				best = t
	return best


## Project onto a circumference when the cursor is within the snap radius of
## the rim. Used for the first click (no anchor) and for a free end that is
## not a tangent and not on an axis.
func _snap_line_on_circle(p: Vector2) -> Variant:
	if not _line_snap_armed():
		return null
	var rad := _snap_radius()
	var best_d := rad
	var best: Variant = null
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		var c: Vector2 = info["center"]
		var r: float = float(info.get("radius", 0.0))
		if r < 1e-6:
			continue
		var dist := p.distance_to(c)
		if dist < 1e-9 or absf(dist - r) > rad:
			continue
		var proj := c + (p - c) * (r / dist)
		var d := p.distance_to(proj)
		if d <= best_d:
			best_d = d
			best = proj
	return best


## External tangents from `anchor` to the circle. Empty when the anchor is
## inside or on the circle (no real tangent).
func _circle_tangent_points(anchor: Vector2, c: Vector2, r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if r < 1e-6:
		return out
	var v := anchor - c
	var dist := v.length()
	if dist <= r + 1e-4:
		return out
	var theta := acos(clampf(r / dist, -1.0, 1.0))
	var u := v / dist
	out.append(c + u.rotated(theta) * r)
	out.append(c + u.rotated(-theta) * r)
	return out


## Circle/arc centres of body edges that lie on this sketch plane (the Ø20
## and Ø45 rims of a face sketch). refresh_sketch_intersections only stores
## edge pierces, so snap reads these directly.
func _model_circle_centers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if view == null or view.doc == null or not view.doc.has_method("get_edge_lines"):
		return out
	var n := plane_normal()
	for body_id in view.doc.body_ids():
		var edges: Dictionary = view.doc.get_edge_lines(body_id)
		for edge_id in edges:
			var poly: PackedVector3Array = edges[edge_id]
			var c3: Variant = _circle_center_of_poly(poly)
			if c3 == null:
				continue
			var center3: Vector3 = c3
			if absf((center3 - plane_origin).dot(n)) > 0.75:
				continue
			var on := center3 - n * (center3 - plane_origin).dot(n)
			var rel := on - plane_origin
			out.append(Vector2(rel.dot(plane_x), rel.dot(plane_y)))
	return out


func _circle_center_of_poly(poly: PackedVector3Array) -> Variant:
	if poly.size() < 12:
		return null
	var centroid: Variant = _centroid_if_circle(poly)
	if centroid != null:
		return centroid
	# A rim split by the shaft tangents is an arc. Its vertex average is not
	# the centre, so fit the circle through the two ends and the midpoint.
	var n := poly.size()
	var a: Vector3 = poly[0]
	var b: Vector3 = poly[n / 2]
	var c: Vector3 = poly[n - 1]
	if a.distance_to(c) < 1e-3:
		c = poly[maxi(n - 2, 1)]
	if a.distance_to(c) < 1e-3 or a.distance_to(b) < 1e-3:
		return null
	var ab := b - a
	var ac := c - a
	var abxac := ab.cross(ac)
	var denom := 2.0 * abxac.length_squared()
	if denom < 1e-8:
		return null
	var center := a + (abxac.cross(ab) * ac.length_squared() + ac.cross(abxac) * ab.length_squared()) / denom
	var radius := center.distance_to(a)
	if radius < 0.4:
		return null
	var max_err := 0.0
	for p in poly:
		max_err = maxf(max_err, absf(p.distance_to(center) - radius))
	if max_err > maxf(0.35, radius * 0.08):
		return null
	return center


func _centroid_if_circle(poly: PackedVector3Array) -> Variant:
	var c := Vector3.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	var r := 0.0
	for p in poly:
		r += p.distance_to(c)
	r /= float(poly.size())
	if r < 0.4:
		return null
	var max_err := 0.0
	for p in poly:
		max_err = maxf(max_err, absf(p.distance_to(c) - r))
	if max_err > maxf(0.35, r * 0.08):
		return null
	return c


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


## Public pick used by the viewport marquee press (empty canvas starts a box).
func entity_at(pos2: Vector2) -> String:
	if sketch == null:
		return ""
	return _nearest_entity_at(pos2)


## Window or crossing select in screen pixels. Returns the selection size.
## Window: every sample inside `rect`. Crossing: any sample inside, or a
## consecutive sample pair that crosses the rectangle. No 8-entity cap.
func select_in_screen_rect(rect: Rect2, crossing: bool, additive: bool) -> int:
	if sketch == null or camera == null:
		return 0
	var ids: Array[String] = []
	if additive:
		ids = selected.duplicate()
	for id in sketch.entity_ids():
		var sid := str(id)
		if ids.has(sid):
			continue
		var info: Dictionary = sketch.entity_info(sid)
		var pts := _entity_screen_samples(info)
		if pts.is_empty():
			continue
		var hit := false
		if crossing:
			for p in pts:
				if rect.has_point(p):
					hit = true
					break
			if not hit and _samples_cross_rect(pts, rect, str(info.get("type", "")) == "circle"):
				hit = true
		else:
			hit = true
			for p in pts:
				if not rect.has_point(p):
					hit = false
					break
		if hit:
			ids.append(sid)
	_set_selected(ids)
	return ids.size()


func _entity_screen_samples(info: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if camera == null:
		return out
	match str(info.get("type", "")):
		"line":
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			var sa := camera.unproject_position(to_global(to_model(a)))
			var sb := camera.unproject_position(to_global(to_model(b)))
			out.append(sa)
			var dist := sa.distance_to(sb)
			var n := int(ceil(dist / 8.0))
			for i in range(1, n):
				out.append(sa.lerp(sb, float(i) / float(n)))
			out.append(sb)
		"circle":
			var c: Vector2 = info["center"]
			var r: float = info["radius"]
			for i in 48:
				var ang := TAU * float(i) / 48.0
				var p := c + Vector2.from_angle(ang) * r
				out.append(camera.unproject_position(to_global(to_model(p))))
		"arc":
			var c2: Vector2 = info["center"]
			var r2: float = info["radius"]
			var a0: float = info["start_angle"]
			var a1: float = info["end_angle"]
			if a1 < a0:
				a1 += TAU
			for i in 48:
				var ang2 := lerpf(a0, a1, float(i) / 47.0)
				var p2 := c2 + Vector2.from_angle(ang2) * r2
				out.append(camera.unproject_position(to_global(to_model(p2))))
		"point":
			var pt: Vector2 = info["position"]
			out.append(camera.unproject_position(to_global(to_model(pt))))
	return out


func _samples_cross_rect(pts: PackedVector2Array, rect: Rect2, wrap: bool) -> bool:
	var n := pts.size()
	if n < 2:
		return false
	var pairs := n if wrap else n - 1
	for i in pairs:
		if _segment_crosses_rect(pts[i], pts[(i + 1) % n], rect):
			return true
	return false


## True when the segment intersects the rectangle (Liang-Barsky).
func _segment_crosses_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var dx := b.x - a.x
	var dy := b.y - a.y
	var t0 := 0.0
	var t1 := 1.0
	var p := PackedFloat64Array([-dx, dx, -dy, dy])
	var q := PackedFloat64Array([
		a.x - rect.position.x,
		rect.end.x - a.x,
		a.y - rect.position.y,
		rect.end.y - a.y,
	])
	for i in 4:
		if absf(p[i]) < 1e-9:
			if q[i] < 0.0:
				return false
		else:
			var t := q[i] / p[i]
			if p[i] < 0.0:
				if t > t1:
					return false
				t0 = maxf(t0, t)
			else:
				if t < t0:
					return false
				t1 = minf(t1, t)
	return t0 <= t1


## Hit radius in sketch millimetres: at least PICK_TOLERANCE, widened to
## PICK_SCREEN_PX at the current ortho scale, never past PICK_TOLERANCE_MAX_MM.
func _pick_tolerance() -> float:
	var tol := PICK_TOLERANCE
	if camera != null and camera.has_method("pixels_per_mm_at_pivot"):
		var ppm := float(camera.pixels_per_mm_at_pivot())
		if ppm > 1e-4:
			tol = maxf(tol, minf(PICK_SCREEN_PX / ppm, PICK_TOLERANCE_MAX_MM))
	return tol


## Nearest entity id within the pick radius of pos2, or "" if none.
func _nearest_entity_at(pos2: Vector2) -> String:
	var best_id := ""
	var best_d := _pick_tolerance()
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


## Closest sketch-plane point on `eid` to `pos2` (the measure ✕ sits here).
func closest_on_entity(eid: String, pos2: Vector2) -> Vector2:
	if sketch == null or eid == "":
		return pos2
	var info: Dictionary = sketch.entity_info(eid)
	match str(info.get("type", "")):
		"line":
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			var ab := b - a
			var t := 0.0 if ab.length_squared() < 1e-12 else clampf((pos2 - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			return a + ab * t
		"circle", "arc":
			var c: Vector2 = info["center"]
			var r := float(info.get("radius", 0.0))
			var d := pos2 - c
			if d.length_squared() < 1e-12 or r < 1e-9:
				return c + Vector2(r, 0.0)
			return c + d.normalized() * r
		"point":
			return info["position"]
	return pos2


# --- drag-to-edit (SELECT tool) ---

## Hit-test for drag handles. Returns {} or {id, part} where part is
## "start"|"end"|"whole"|"center"|"radius". Endpoints/centers win within
## the pick radius; otherwise the nearest curve within that radius ("whole" /
## "radius").
func drag_hit(pos2: Vector2) -> Dictionary:
	if sketch == null:
		return {}
	var best_id := ""
	var best_part := ""
	var best_d := _pick_tolerance()
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
	best_d = _pick_tolerance()
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


## Drop a drag that was only pointer jitter and put the entity back.
## A Select click inside CLICK_SLOP must not bake that motion.
func cancel_drag() -> void:
	if _drag.is_empty():
		return
	if sketch != null:
		sketch.set_entity_geometry(_drag["id"], _drag["orig_info"])
		run_solve()
	_drag.clear()
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
		"diameter":
			for id in selected:
				var kd: String = sketch.entity_info(id).get("type", "")
				if kd == "circle" or kd == "arc":
					cid = sketch.add_constraint("diameter", [{"entity": id, "role": "self"}], value)
					added = true
		"tangent", "angle", "point_on_line":
			if selected.size() == 2:
				cid = sketch.add_constraint(type, [
					{"entity": selected[0], "role": "self"},
					{"entity": selected[1], "role": "self"}], value)
				added = true
		"concentric":
			if selected.size() == 2:
				cid = sketch.add_constraint("concentric", [
					{"entity": selected[0], "role": "center"},
					{"entity": selected[1], "role": "center"}], 0.0)
				added = true
		"midpoint":
			# Point is the midpoint of a line (ConstraintType::Midpoint).
			if selected.size() == 2:
				var line_id := selected[0]
				var pt_id := selected[1]
				if sketch.entity_info(line_id).get("type") != "line":
					line_id = selected[1]
					pt_id = selected[0]
				if sketch.entity_info(line_id).get("type") == "line":
					var pt_role := "center" if sketch.entity_info(pt_id).get("type", "") in ["circle", "arc"] else "self"
					cid = sketch.add_constraint("midpoint", [
						{"entity": pt_id, "role": pt_role},
						{"entity": line_id, "role": "self"}], 0.0)
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
	if type == "distance" or type == "radius" or type == "diameter" or type == "angle":
		_undo_note("Dimension")
	# Record dimensional constraints (distance/radius, or any with a numeric value).
	if type == "distance" or type == "radius" or type == "diameter" or type == "angle" or absf(value) > 0.0:
		_record_dimension(type, selected.duplicate(), value, cid)
	var res: Dictionary = run_solve()
	if str(res.get("status", "")) == "failed" and cid != "":
		# Same as a failed drag: drop the relation that did not stick and
		# leave last_solve_status on the previous good solve.
		if sketch.has_method("remove_constraint"):
			sketch.remove_constraint(cid)
		for i in range(dimensions.size() - 1, -1, -1):
			if str(dimensions[i].get("cid", "")) == cid:
				dimensions.remove_at(i)
		res = run_solve()
		status.emit("Relation did not stick")
	_redraw()
	_redraw_selected()
	return res["status"]


func _record_dimension(type: String, ids: Array, value: float, cid: String = "",
		callout: String = "") -> void:
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
				var kept_callout := callout if callout != "" else str(d.get("callout", ""))
				var rec := {"type": type, "ids": id_list, "value": value,
					"cid": cid if cid != "" else d.get("cid", "")}
				if kept_callout != "":
					rec["callout"] = kept_callout
				dimensions[i] = rec
				return
	var fresh := {"type": type, "ids": id_list, "value": value, "cid": cid}
	if callout != "":
		fresh["callout"] = callout
	dimensions.append(fresh)


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
	_undo_note("Fillet")
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
	_undo_note("Offset")
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
	_undo_note("Extend")
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
	_undo_note("Pattern")
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
	if not out.is_empty():
		_undo_note("Mirror")
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
		_undo_note("Convert")
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
	_undo_note("Chamfer")
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
## A construction centreline within 40 mm opens the jaw on the clicked side
## (kernel trim ignores construction geometry).
func trim_at(pos2: Vector2) -> bool:
	if not active or sketch == null:
		status.emit("Trim failed")
		return false
	if _trim_open_jaw(pos2):
		return true
	var id := _nearest_entity_at(pos2)
	if id == "":
		status.emit("Trim failed — nothing under the pointer: click on a line or arc")
		return false
	# trim_entity returns false when nothing crosses, and can return true while
	# leaving the snapshot unchanged. Either way the sketch did not change:
	# do not solve (that nudges nodes) and do not push an undo entry.
	var before := ""
	if sketch.has_method("snapshot"):
		before = sketch.snapshot()
	var trimmed := sketch.trim_entity(id, pos2.x, pos2.y)
	var after := before
	if sketch.has_method("snapshot"):
		after = sketch.snapshot()
	if not trimmed or (before != "" and after == before):
		status.emit("Nothing trimmed — no crossing at that point")
		return false
	_undo_note("Trim")
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


func _nearest_construction_line(p: Vector2, max_dist: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_dist
	for id in sketch.entity_ids():
		if not sketch.is_construction(id):
			continue
		if _angle_datum_lines.has(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		var d := _point_line_distance(p, a, b)
		if d > best_d:
			continue
		if _point_segment_distance(p, a, b) > max_dist + a.distance_to(b):
			continue
		best_d = d
		best = {"id": id, "a": a, "b": b}
	return best


## Model-edge circles on this sketch plane (centre + radius), for jaw trim
## when the Ø45 rim was not redrawn as a sketch circle.
func _model_circles() -> Array:
	var out: Array = []
	if view == null or view.doc == null or not view.doc.has_method("get_edge_lines"):
		return out
	var n := plane_normal()
	for body_id in view.doc.body_ids():
		var edges: Dictionary = view.doc.get_edge_lines(body_id)
		for edge_id in edges:
			var poly: PackedVector3Array = edges[edge_id]
			var fitted: Variant = _circle_center_of_poly(poly)
			if fitted == null:
				continue
			var c3: Vector3 = fitted
			var r := 0.0
			for pt in poly:
				r += pt.distance_to(c3)
			r /= float(poly.size())
			if r < 0.4:
				continue
			if absf((c3 - plane_origin).dot(n)) > 0.75:
				continue
			var on := c3 - n * (c3 - plane_origin).dot(n)
			var rel := on - plane_origin
			out.append({
				"center": Vector2(rel.dot(plane_x), rel.dot(plane_y)),
				"radius": r,
			})
	return out


func _lock_projected_circle(center2: Vector2, radius: float) -> String:
	if sketch == null or radius <= 1e-6 or not sketch.has_method("project_circle_edge"):
		return ""
	var id: String = sketch.project_circle_edge(to_model(center2), radius, "wp2-anchor")
	if id == "":
		return ""
	sketch.set_construction(id, true)
	return id


func _line_cross_cutter(s: Vector2, e: Vector2, origin_a: Vector2, normal: Vector2) -> Vector2:
	var ss := (s - origin_a).dot(normal)
	var es := (e - origin_a).dot(normal)
	var denom := ss - es
	if absf(denom) < 1e-12:
		return s
	return s.lerp(e, ss / denom)


func _line_line_intersect(p0: Vector2, d0: Vector2, p1: Vector2, d1: Vector2) -> Vector2:
	var det := d0.x * d1.y - d0.y * d1.x
	if absf(det) < 1e-12:
		return p0
	var delta := p1 - p0
	var t := (delta.x * d1.y - delta.y * d1.x) / det
	return p0 + d0 * t


## Move each wall/cutter hit along its wall onto the line through the cap
## centre along the cutter. Width is unchanged for parallel jaw sides.
func _snap_jaw_hits_through_centre(walls: Array, cc: Vector2, cutter_dir: Vector2) -> void:
	if walls.size() != 2 or cutter_dir.length_squared() < 1e-12:
		return
	var cd := cutter_dir.normalized()
	for w in walls:
		var hit: Vector2 = w["hit"]
		var keep: Vector2 = w["keep"]
		var wd: Vector2 = keep - hit
		if wd.length_squared() < 1e-12:
			wd = keep - cc
		if wd.length_squared() < 1e-12:
			continue
		w["hit"] = _line_line_intersect(hit, wd, cc, cd)


func _ray_circle_point(origin: Vector2, direction: Vector2, center: Vector2, radius: float) -> Vector2:
	var dir := direction
	if dir.length_squared() < 1e-12:
		return origin
	dir = dir.normalized()
	var f := origin - center
	var b := 2.0 * f.dot(dir)
	var c := f.dot(f) - radius * radius
	var disc := b * b - 4.0 * c
	if disc < 0.0:
		return origin
	var sdisc := sqrt(disc)
	var t1 := (-b - sdisc) * 0.5
	var t2 := (-b + sdisc) * 0.5
	var t := t1 if t1 > 1e-6 else t2
	if t2 > 1e-6 and (t <= 1e-6 or t2 < t):
		t = t2
	if t <= 1e-6:
		return origin
	return origin + dir * t


func _add_keep_side_arc(center: Vector2, radius: float, p0: Vector2, p1: Vector2, keep_dir: Vector2) -> String:
	var a0 := (p0 - center).angle()
	var a1 := (p1 - center).angle()
	var mid := (a0 + a1) * 0.5
	if a1 < a0:
		mid += PI
	if Vector2.from_angle(mid).dot(keep_dir) < 0.0:
		var swap := a0
		a0 = a1
		a1 = swap
	var arc_id: String = sketch.add_arc(center.x, center.y, radius, a0, a1)
	_set_arc_ends(arc_id, center, radius, a0, a1)
	return arc_id


func _dirs_within_deg(a: Vector2, b: Vector2, deg: float) -> bool:
	if a.length_squared() < 1e-12 or b.length_squared() < 1e-12:
		return false
	return absf(a.normalized().dot(b.normalized())) >= cos(deg_to_rad(deg))


func _longest_profile_dir() -> Vector2:
	var best := Vector2.ZERO
	var best_len := 0.0
	if sketch == null:
		return best
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var d: Vector2 = info["end"] - info["start"]
		var L := d.length()
		if L > best_len:
			best_len = L
			best = d
	return best


## Cutter line is within 15% of the radius of the centre, and the segment
## overlaps the circle. Replaces the 1.0 mm best_cd gate that missed Ø45.
func _circle_meets_cutter(c: Vector2, r: float, a: Vector2, b: Vector2) -> bool:
	if r < 1e-6:
		return false
	if _point_line_distance(c, a, b) > 0.15 * r:
		return false
	return _point_segment_distance(c, a, b) <= r + 1.0


## Largest circle whose disc the cutter line crosses well inside the rim:
## sketch circles first, then the solid's head edge. {} when none.
func _jaw_cap_circle(a: Vector2, b: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_r := 0.0
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var c: Vector2 = info["center"]
		var r := float(info.get("radius", 0.0))
		if _jaw_cutter_crosses_disc(c, r, a, b) and r > best_r:
			best = {"id": id, "center": c, "radius": r}
			best_r = r
	if not best.is_empty():
		return best
	for mc in _model_circles():
		var c2: Vector2 = mc["center"]
		var r2 := float(mc["radius"])
		if _jaw_cutter_crosses_disc(c2, r2, a, b) and r2 > best_r:
			best = {"id": "", "center": c2, "radius": r2}
			best_r = r2
	return best


const JAW_CUTTER_MAX_RIM_FRACTION := 0.9


func _jaw_cutter_crosses_disc(c: Vector2, r: float, a: Vector2, b: Vector2) -> bool:
	if r < 1e-6:
		return false
	if _point_line_distance(c, a, b) > JAW_CUTTER_MAX_RIM_FRACTION * r:
		return false
	return _point_segment_distance(c, a, b) <= r + 1.0


func _jaw_no_cap_status(a: Vector2, b: Vector2) -> String:
	var best_r := 0.0
	var best_d := INF
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var r := float(info.get("radius", 0.0))
		if r > best_r:
			best_r = r
			best_d = _point_line_distance(info["center"], a, b)
	for mc in _model_circles():
		var r2 := float(mc["radius"])
		if r2 > best_r:
			best_r = r2
			best_d = _point_line_distance(mc["center"], a, b)
	if best_r < 1e-6:
		return "Trim failed — no head circle: redraw the Ø45 head circle on this sketch"
	return "Trim failed — the centreline is %.1f mm from the Ø%.0f head centre (limit %.1f mm): draw it closer to the head centre" % [
			best_d, best_r * 2.0, JAW_CUTTER_MAX_RIM_FRACTION * best_r]


## Two similar-length parallel profile lines that are not collinear.
## A long regular-Line cutter must not steal the jaw direction from the walls.
func _jaw_long_sides() -> Array:
	if sketch == null:
		return []
	var lines: Array = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		var d := b - a
		var L := d.length()
		if L < 1.0:
			continue
		lines.append({"id": id, "a": a, "b": b, "len": L, "dir": d})
	var best: Array = []
	var best_score := 0.0
	for i in range(lines.size()):
		for j in range(i + 1, lines.size()):
			var li: Dictionary = lines[i]
			var lj: Dictionary = lines[j]
			var di: Vector2 = li["dir"]
			var dj: Vector2 = lj["dir"]
			if not _dirs_within_deg(di, dj, 2.0):
				continue
			var n := Vector2(-di.y, di.x)
			if n.length_squared() < 1e-12:
				continue
			n = n.normalized()
			if absf(((lj["a"] as Vector2) - (li["a"] as Vector2)).dot(n)) < 1.0:
				continue
			var l1 := float(li["len"])
			var l2 := float(lj["len"])
			var mx := maxf(l1, l2)
			if mx < 1e-6:
				continue
			var score := minf(l1, l2) * (minf(l1, l2) / mx)
			if score > best_score:
				best_score = score
				best = [li, lj]
	return best


func _jaw_profile_dir() -> Vector2:
	var sides := _jaw_long_sides()
	if sides.size() == 2:
		return (sides[0]["b"] as Vector2) - (sides[0]["a"] as Vector2)
	return _longest_profile_dir()


## Proper segment-segment intersection, or null.
func _segment_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	var r := b - a
	var s := d - c
	var denom := r.x * s.y - r.y * s.x
	if absf(denom) < 1e-9:
		return null
	var t := ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / denom
	var u := ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / denom
	if t < -1e-4 or t > 1.0 + 1e-4 or u < -1e-4 or u > 1.0 + 1e-4:
		return null
	return a + r * t


func _cutter_crosses_both_sides(a: Vector2, b: Vector2, sides: Array) -> bool:
	if sides.size() != 2:
		return false
	return _segment_intersect(a, b, sides[0]["a"], sides[0]["b"]) != null \
			and _segment_intersect(a, b, sides[1]["a"], sides[1]["b"]) != null


## True when the cutter crosses the interior of both long sides (not a cap
## that only meets them at the rectangle corners).
func _cutter_crosses_both_side_interiors(a: Vector2, b: Vector2, sides: Array) -> bool:
	if sides.size() != 2:
		return false
	return _side_interior_hit(a, b, sides[0]["a"], sides[0]["b"]) \
			and _side_interior_hit(a, b, sides[1]["a"], sides[1]["b"])


func _side_interior_hit(cut_a: Vector2, cut_b: Vector2, side_a: Vector2, side_b: Vector2) -> bool:
	var r := cut_b - cut_a
	var s := side_b - side_a
	var denom := r.x * s.y - r.y * s.x
	if absf(denom) < 1e-9:
		return false
	var t := ((side_a.x - cut_a.x) * s.y - (side_a.y - cut_a.y) * s.x) / denom
	var u := ((side_a.x - cut_a.x) * r.y - (side_a.y - cut_a.y) * r.x) / denom
	return t >= -1e-4 and t <= 1.0 + 1e-4 and u > 0.02 and u < 0.98


func _jaw_aabb_expanded(sides: Array, pad: float) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for s in sides:
		mn = mn.min(s["a"]).min(s["b"])
		mx = mx.max(s["a"]).max(s["b"])
	return Rect2(mn - Vector2(pad, pad), (mx - mn) + Vector2(pad, pad) * 2.0)


## True when this line is a jaw cutter candidate: crosses both long sides,
## or runs along the jaw inside the jaw box.
func _line_is_jaw_cutter_candidate(a: Vector2, b: Vector2, sides: Array) -> bool:
	if sides.size() != 2:
		return false
	var dir: Vector2 = sides[0]["b"] - sides[0]["a"]
	if _cutter_crosses_both_sides(a, b, sides):
		return true
	var mid := (a + b) * 0.5
	return _dirs_within_deg(b - a, dir, 2.0) and _jaw_aabb_expanded(sides, 2.0).has_point(mid)


func _jaw_cutter_for_click(pos2: Vector2) -> Dictionary:
	var sides := _jaw_long_sides()
	var jaw_dir := _jaw_profile_dir()
	var best: Dictionary = {}
	var best_d := INF
	var side_ids := {}
	for s in sides:
		side_ids[str(s["id"])] = true
	if sides.size() == 2:
		for id in sketch.entity_ids():
			if _angle_datum_lines.has(id) or side_ids.has(str(id)):
				continue
			var info: Dictionary = sketch.entity_info(id)
			if str(info.get("type", "")) != "line":
				continue
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			if jaw_dir.length_squared() > 1e-8 and _dirs_within_deg(b - a, jaw_dir, 2.0):
				continue
			var is_con := sketch.is_construction(id)
			if is_con:
				if not _cutter_crosses_both_sides(a, b, sides):
					continue
			elif not _cutter_crosses_both_side_interiors(a, b, sides):
				continue
			var d := _point_segment_distance(pos2, a, b)
			if d < best_d:
				best_d = d
				best = {"id": id, "a": a, "b": b}
	if not best.is_empty() and _jaw_click_reaches_cutter(pos2, best_d, sides):
		return best
	return _nearest_construction_line(pos2, 40.0)


func _jaw_click_reaches_cutter(pos2: Vector2, cutter_d: float, sides: Array) -> bool:
	if cutter_d <= 40.0:
		return true
	if sides.size() != 2:
		return false
	for s in sides:
		if _point_segment_distance(pos2, s["a"], s["b"]) <= PICK_TOLERANCE * 2.0:
			return true
	return _jaw_aabb_expanded(sides, 8.0).has_point(pos2)


## When the pointer is on the cutter, discard the shaft-side cap (closer to
## the origin) so a drag across the line still opens the wrench jaw.
func _jaw_discard_side_on_cutter(origin_a: Vector2, normal: Vector2) -> float:
	var sides := _jaw_long_sides()
	if sides.size() != 2:
		return 0.0
	var jaw_dir: Vector2 = (sides[0]["b"] as Vector2) - (sides[0]["a"] as Vector2)
	var across := Vector2(-jaw_dir.y, jaw_dir.x)
	var side_ids := {}
	for s in sides:
		side_ids[str(s["id"])] = true
	var best_dist := INF
	var best_sign := 0.0
	for id in sketch.entity_ids():
		if sketch.is_construction(id) or side_ids.has(str(id)):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		if not _dirs_within_deg(e - s, across, 15.0):
			continue
		var ss := (s - origin_a).dot(normal)
		var es := (e - origin_a).dot(normal)
		if ss * es < 0.0:
			continue
		var d := ((s + e) * 0.5).length()
		if d < best_dist:
			best_dist = d
			best_sign = 1.0 if (ss + es) > 0.0 else -1.0
	return best_sign


## Click on one side of a construction centreline: drop that half, keep the
## other, close it with a floor on the cutter and the keep-side arc of the
## circle centred on the cutter. The Ø10 (centre far from the cutter) stays.
func _trim_open_jaw(pos2: Vector2) -> bool:
	var cutter := _jaw_cutter_for_click(pos2)
	if cutter.is_empty():
		return false
	if _jaw_ids_alive():
		status.emit("Jaw is already open — nothing left to trim here")
		return true
	var a: Vector2 = cutter["a"]
	var b: Vector2 = cutter["b"]
	var dir := b - a
	if dir.length() < 1e-6:
		return false
	dir = dir.normalized()
	var normal := Vector2(-dir.y, dir.x)
	const EPS := 0.05
	const CAP_DEG := 2.0
	var long_dir := _jaw_profile_dir()
	if long_dir.length_squared() > 1e-8 and _dirs_within_deg(dir, long_dir, CAP_DEG):
		status.emit("Trim failed — the construction line nearest your click runs along the jaw (from %.1f,%.1f to %.1f,%.1f); draw a centreline across the jaw or delete the along-jaw line" % [a.x, a.y, b.x, b.y])
		return true
	var cap := _jaw_cap_circle(a, b)
	if cap.is_empty():
		if sketch.is_construction(str(cutter["id"])):
			status.emit(_jaw_no_cap_status(a, b))
			return true
		return false
	var side := (pos2 - a).dot(normal)
	if absf(side) < 1e-4:
		side = _jaw_discard_side_on_cutter(a, normal)
	if absf(side) < 1e-4:
		# Pointer is on the cutter: do not kernel-trim the line (that shortens
		# it and then the jaw can no longer open). A later sample of the same
		# Power Trim stroke still opens the jaw once it leaves the line.
		return true
	var discard := 1.0 if side > 0.0 else -1.0
	var cc: Vector2 = cap["center"]
	# The mouth is the side of the cutter away from the head centre (the stub
	# past the rim). Dragging Trim across that stub must cut the same opening
	# as dragging the shaft side. A cutter through the centre keeps the click.
	var center_side := (cc - a).dot(normal)
	if absf(center_side) > 0.05:
		discard = 1.0 if center_side > 0.0 else -1.0
	var keep_dir := normal * (-discard)
	var cr: float = float(cap["radius"])
	var circ_id: String = str(cap["id"])
	var to_delete: Array[String] = []
	var walls: Array = []
	for id in sketch.entity_ids():
		if id == str(cutter["id"]) or sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		var side_dir := e - s
		var is_cap := _dirs_within_deg(side_dir, dir, CAP_DEG)
		var ss := (s - a).dot(normal)
		var es := (e - a).dot(normal)
		var s_disc := ss * discard > EPS
		var e_disc := es * discard > EPS
		var s_keep := ss * discard < -EPS
		var e_keep := es * discard < -EPS
		if is_cap:
			# Caps stay off the wall list even when a slight skew puts their
			# endpoints on opposite sides of the cutter.
			if (s_disc or absf(ss) <= EPS) and (e_disc or absf(es) <= EPS) and (s_disc or e_disc):
				to_delete.append(id)
			elif s_keep and e_keep:
				to_delete.append(id)
			continue
		if (s_disc or absf(ss) <= EPS) and (e_disc or absf(es) <= EPS) and (s_disc or e_disc):
			to_delete.append(id)
			continue
		if s_keep and e_keep:
			to_delete.append(id)
			continue
		if not ((s_disc and e_keep) or (e_disc and s_keep) or (absf(ss) <= EPS and e_keep) \
				or (absf(es) <= EPS and s_keep)):
			continue
		var hit := _line_cross_cutter(s, e, a, normal)
		var keep_pt: Vector2 = s if ss * discard < es * discard else e
		walls.append({"id": id, "hit": hit, "keep": keep_pt})
	if walls.size() != 2:
		status.emit("Trim failed — the construction line nearest your click runs along the jaw (from %.1f,%.1f to %.1f,%.1f); draw a centreline across the jaw or delete the along-jaw line" % [a.x, a.y, b.x, b.y])
		return true
	# Typed width/angle win over the geometry the snap is about to move.
	# Capture from the live records that name the short side / a wall+datum;
	# if the jaw was never labelled, round the current measure to 1e-4.
	var wall_ids := {}
	for w in walls:
		wall_ids[str(w["id"])] = true
	var drop_ids := {}
	for id in to_delete:
		drop_ids[str(id)] = true
	var jaw_width := 0.0
	var have_width := false
	var jaw_angle := 0.0
	var have_angle := false
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var dtype := str(dim.get("type", ""))
		var dids: Array = dim.get("ids", [])
		if dtype == "distance" and not have_width:
			for id in dids:
				if drop_ids.has(str(id)):
					jaw_width = float(dim.get("value", 0.0))
					have_width = true
					break
		elif dtype == "angle" and not have_angle:
			var names_wall := false
			var names_datum := false
			for id in dids:
				if wall_ids.has(str(id)):
					names_wall = true
				if _angle_datum_lines.has(str(id)):
					names_datum = true
			if names_wall or names_datum:
				jaw_angle = float(dim.get("value", 0.0))
				have_angle = true
	if not have_width:
		jaw_width = snappedf(walls[0]["hit"].distance_to(walls[1]["hit"]), 1e-4)
	if not have_angle:
		var md: Vector2 = walls[0]["keep"] - walls[0]["hit"]
		if md.length_squared() < 1e-12:
			md = keep_dir
		jaw_angle = snappedf(Vector2(1, 0).angle_to(md), 1e-4)
	if jaw_width < 0.1:
		jaw_width = 10.0
	var wall_along := Vector2.from_angle(jaw_angle)
	if wall_along.dot(keep_dir) < 0.0:
		wall_along = -wall_along
	# An offset cutter (leftover retry, >15% of radius) still caps on this
	# circle. The midpoint constraint wants the floor through `cc`; apply
	# that geometrically so DogLeg cannot leave the floor on the offset
	# line (checker u=3 / floor-from-u=10).
	_snap_jaw_hits_through_centre(walls, cc, dir)
	for w in walls:
		var hit: Vector2 = w["hit"]
		var keep: Vector2 = _ray_circle_point(hit, wall_along, cc, cr)
		w["keep"] = keep
		sketch.set_entity_geometry(str(w["id"]), {"start": hit, "end": keep})
	for id in to_delete:
		sketch.remove_entity(id)
	var h0: Vector2 = walls[0]["hit"]
	var h1: Vector2 = walls[1]["hit"]
	var k0: Vector2 = walls[0]["keep"]
	var k1: Vector2 = walls[1]["keep"]
	var w0: Vector2 = walls[0]["keep"] - walls[0]["hit"]
	if w0.length_squared() > 1e-8:
		var fdir := Vector2(-w0.y, w0.x).normalized()
		var across: Vector2 = walls[1]["hit"] - walls[0]["hit"]
		if fdir.dot(across) < 0.0:
			fdir = -fdir
		var half := jaw_width * 0.5
		if half < 0.1:
			half = 10.0
		h0 = cc - fdir * half
		h1 = cc + fdir * half
		walls[0]["hit"] = h0
		walls[1]["hit"] = h1
		for w in walls:
			var hit2: Vector2 = w["hit"]
			var keep2: Vector2 = _ray_circle_point(hit2, wall_along, cc, cr)
			w["keep"] = keep2
			sketch.set_entity_geometry(str(w["id"]), {"start": hit2, "end": keep2})
		k0 = walls[0]["keep"]
		k1 = walls[1]["keep"]
	var floor_id: String = sketch.add_line(h0.x, h0.y, h1.x, h1.y)
	var arc_id := _add_keep_side_arc(cc, cr, k0, k1, keep_dir)
	_weld_jaw_profile(floor_id, walls, arc_id)
	_jaw_floor_id = floor_id
	_jaw_arc_id = arc_id
	_jaw_wall_ids.clear()
	for w in walls:
		_jaw_wall_ids.append(str(w["id"]))
	if circ_id != "":
		sketch.remove_entity(circ_id)
	var anchor := _lock_projected_circle(cc, cr)
	if anchor != "":
		sketch.add_constraint("concentric", [
			{"entity": arc_id, "role": "center"},
			{"entity": anchor, "role": "center"}], 0.0)
	var arc_rad_cid: String = sketch.add_constraint(
			"radius", [{"entity": arc_id, "role": "self"}], cr)
	_record_dimension("radius", [arc_id], cr, arc_rad_cid)
	var width := jaw_width
	var dist_cid: String = sketch.add_constraint("distance", [
		{"entity": floor_id, "role": "start"},
		{"entity": floor_id, "role": "end"}], width)
	_record_dimension("distance", [floor_id], width, dist_cid, "jaw_width")
	sketch.add_constraint("midpoint", [
		{"entity": arc_id, "role": "center"},
		{"entity": floor_id, "role": "self"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": str(walls[0]["id"]), "role": "start"},
		{"entity": floor_id, "role": "start"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": str(walls[1]["id"]), "role": "start"},
		{"entity": floor_id, "role": "end"}], 0.0)
	var ainfo: Dictionary = sketch.entity_info(arc_id)
	var a_start: Vector2 = ainfo["start"]
	var w0_role := "start" if k0.distance_to(a_start) <= k1.distance_to(a_start) else "end"
	var w1_role := "end" if w0_role == "start" else "start"
	sketch.add_constraint("coincident", [
		{"entity": str(walls[0]["id"]), "role": "end"},
		{"entity": arc_id, "role": w0_role}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": str(walls[1]["id"]), "role": "end"},
		{"entity": arc_id, "role": w1_role}], 0.0)
	sketch.add_constraint("perpendicular", [
		{"entity": str(walls[0]["id"]), "role": "self"},
		{"entity": floor_id, "role": "self"}], 0.0)
	sketch.add_constraint("parallel", [
		{"entity": str(walls[0]["id"]), "role": "self"},
		{"entity": str(walls[1]["id"]), "role": "self"}], 0.0)
	var hx: String = sketch.add_line(cc.x - 8.0, cc.y, cc.x + 8.0, cc.y)
	sketch.set_construction(hx, true)
	sketch.add_constraint("horizontal", [{"entity": hx, "role": "self"}], 0.0)
	var ang := jaw_angle
	var ang_cid: String = sketch.add_constraint("angle", [
		{"entity": hx, "role": "self"},
		{"entity": str(walls[0]["id"]), "role": "self"}], ang)
	_record_dimension("angle", [hx, str(walls[0]["id"])], ang, ang_cid, "jaw_angle")
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "circle" or sketch.is_construction(id):
			continue
		if (info["center"] as Vector2).distance_to(Vector2.ZERO) > 1.0:
			continue
		var hole_r := float(info.get("radius", 1.0))
		var hole_cid: String = sketch.add_constraint(
				"radius", [{"entity": id, "role": "self"}], hole_r)
		_record_dimension("radius", [id], hole_r, hole_cid)
		var oanchor := _lock_projected_circle(Vector2.ZERO, maxf(hole_r, 1.0))
		if oanchor != "":
			sketch.add_constraint("concentric", [
				{"entity": id, "role": "center"},
				{"entity": oanchor, "role": "center"}], 0.0)
	_drop_stale_dimensions()
	# One label per fact: drop any other floor-width or wall-angle record
	# that survived because a wall kept its id.
	var kept_dims: Array = []
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var keep_type := str(dim.get("type", ""))
		var keep_ids: Array = dim.get("ids", [])
		var keep_cid := str(dim.get("cid", ""))
		if keep_type == "distance":
			var names_floor := false
			for id in keep_ids:
				if str(id) == floor_id:
					names_floor = true
					break
			if names_floor and keep_cid != dist_cid:
				continue
		elif keep_type == "angle":
			var names_keep_wall := false
			for id in keep_ids:
				if wall_ids.has(str(id)):
					names_keep_wall = true
					break
			if names_keep_wall and keep_cid != ang_cid:
				continue
		kept_dims.append(dim)
	dimensions = kept_dims
	var cutter_id := str(cutter["id"])
	if cutter_id != "" and not sketch.is_construction(cutter_id) \
			and not sketch.entity_info(cutter_id).is_empty():
		sketch.remove_entity(cutter_id)
	run_solve()
	var winfo: Dictionary = sketch.entity_info(str(walls[0]["id"]))
	var finfo: Dictionary = sketch.entity_info(floor_id)
	if not winfo.is_empty() and not finfo.is_empty():
		var wd: Vector2 = (winfo["end"] as Vector2) - (winfo["start"] as Vector2)
		var fd: Vector2 = (finfo["end"] as Vector2) - (finfo["start"] as Vector2)
		if wd.length_squared() > 1e-12 and fd.length_squared() > 1e-12:
			if absf(wd.normalized().dot(fd.normalized())) > 0.0009:
				run_solve()
	_weld_jaw_profile(floor_id, walls, arc_id)
	_undo_note("Trim")
	_redraw()
	_redraw_selected()
	_trim_jaw_done_in_drag = true
	status.emit("Trimmed open jaw")
	return true


## CCW sweep from start to end, in (0, 2π]. The profile builder uses that
## sweep as the bulge, so the angles have to name the same points.
func _jaw_ccw_angles(center: Vector2, p_start: Vector2, p_end: Vector2) -> Vector2:
	var sa := (p_start - center).angle()
	var ea := (p_end - center).angle()
	var sweep := wrapf(ea - sa, 0.0, TAU)
	if sweep < 1e-6:
		sweep = TAU
	return Vector2(sa, sa + sweep)


## Arc start/end and the wall/floor corners must be the same points. Angle
## reconstruction in float32 drifts past the 1e-6 wire tolerance.
func _weld_jaw_profile(floor_id: String, walls: Array, arc_id: String) -> void:
	if sketch == null or arc_id == "" or floor_id == "" or walls.size() != 2:
		return
	var ainfo: Dictionary = sketch.entity_info(arc_id)
	if ainfo.is_empty():
		return
	var pa: Vector2 = ainfo["start"]
	var pb: Vector2 = ainfo["end"]
	var w0: Vector2 = walls[0]["keep"]
	var w1: Vector2 = walls[1]["keep"]
	var s0 := pa if w0.distance_to(pa) + w1.distance_to(pb) <= w0.distance_to(pb) + w1.distance_to(pa) else pb
	var s1 := pb if s0 == pa else pa
	var h0: Vector2 = walls[0]["hit"]
	var h1: Vector2 = walls[1]["hit"]
	sketch.set_entity_geometry(str(walls[0]["id"]), {"start": h0, "end": s0})
	sketch.set_entity_geometry(str(walls[1]["id"]), {"start": h1, "end": s1})
	sketch.set_entity_geometry(floor_id, {"start": h0, "end": h1})
	var center: Vector2 = ainfo["center"]
	var ang := _jaw_ccw_angles(center, s0, s1)
	sketch.set_entity_geometry(arc_id, {
		"start": s0,
		"end": s1,
		"start_angle": ang.x,
		"end_angle": ang.y,
	})


## Delete a leftover full circle that is concentric with a jaw arc trim
## already added (same centre and radius within 0.5 mm). The arc is the cap.
## The Ø10 hole at the origin is not concentric with that arc.
func _drop_circles_concentric_with_jaw_arcs() -> void:
	if sketch == null:
		return
	var arcs: Array = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "arc":
			continue
		arcs.append({
			"c": info["center"],
			"r": float(info.get("radius", 0.0)),
		})
	if arcs.is_empty():
		return
	var to_drop: Array[String] = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var c: Vector2 = info["center"]
		var r := float(info.get("radius", 0.0))
		for arc in arcs:
			if c.distance_to(arc["c"]) <= 0.5 and absf(r - float(arc["r"])) <= 0.5:
				to_drop.append(id)
				break
	for id in to_drop:
		sketch.remove_entity(id)


## Re-weld the last trimmed jaw after an extrude-time solve. Float drift
## from DogLeg can open the 1e-6 joints between the floor, walls, and arc.
func _reweld_jaw_profile() -> void:
	if sketch == null:
		return
	_discover_jaw_entities()
	if _jaw_floor_id == "" or _jaw_arc_id == "" or _jaw_wall_ids.size() != 2:
		return
	if sketch.entity_info(_jaw_floor_id).is_empty() \
			or sketch.entity_info(_jaw_arc_id).is_empty():
		return
	var finfo: Dictionary = sketch.entity_info(_jaw_floor_id)
	var walls: Array = []
	for wid in _jaw_wall_ids:
		var winfo: Dictionary = sketch.entity_info(wid)
		if winfo.is_empty() or str(winfo.get("type", "")) != "line":
			return
		var s: Vector2 = winfo["start"]
		var e: Vector2 = winfo["end"]
		var f0: Vector2 = finfo["start"]
		var f1: Vector2 = finfo["end"]
		var s_floor := minf(s.distance_to(f0), s.distance_to(f1))
		var e_floor := minf(e.distance_to(f0), e.distance_to(f1))
		var hit := s if s_floor <= e_floor else e
		var keep := e if s_floor <= e_floor else s
		walls.append({"id": wid, "hit": hit, "keep": keep})
	_weld_jaw_profile(_jaw_floor_id, walls, _jaw_arc_id)


## Recover floor / wall / arc ids when trim stored them, or find the only
## non-construction jaw loop (one arc, two walls on its ends, one floor).
func _discover_jaw_entities() -> void:
	if sketch == null:
		return
	if _jaw_ids_alive():
		return
	_jaw_floor_id = ""
	_jaw_arc_id = ""
	_jaw_wall_ids.clear()
	var arc_id := ""
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		if str(sketch.entity_info(id).get("type", "")) == "arc":
			arc_id = id
			break
	if arc_id == "":
		return
	var ainfo: Dictionary = sketch.entity_info(arc_id)
	var a0: Vector2 = ainfo["start"]
	var a1: Vector2 = ainfo["end"]
	var walls: Array[String] = []
	var floor_id := ""
	for id in sketch.entity_ids():
		if sketch.is_construction(id) or id == arc_id:
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		var on_arc := s.distance_to(a0) <= 0.5 or s.distance_to(a1) <= 0.5 \
				or e.distance_to(a0) <= 0.5 or e.distance_to(a1) <= 0.5
		if on_arc:
			walls.append(id)
		else:
			# Candidate floor: both ends near the non-arc ends of the walls.
			if floor_id == "":
				floor_id = id
	if walls.size() != 2:
		return
	if floor_id == "" or not _line_joins_walls(floor_id, walls):
		floor_id = _find_floor_for_walls(walls)
	if floor_id == "":
		return
	_jaw_arc_id = arc_id
	_jaw_floor_id = floor_id
	_jaw_wall_ids = walls


func _jaw_ids_alive() -> bool:
	if sketch == null or _jaw_floor_id == "" or _jaw_arc_id == "" \
			or _jaw_wall_ids.size() != 2:
		return false
	if sketch.entity_info(_jaw_floor_id).is_empty():
		return false
	if sketch.entity_info(_jaw_arc_id).is_empty():
		return false
	for wid in _jaw_wall_ids:
		if sketch.entity_info(wid).is_empty():
			return false
	return true


func _line_joins_walls(floor_id: String, walls: Array[String]) -> bool:
	var finfo: Dictionary = sketch.entity_info(floor_id)
	if finfo.is_empty():
		return false
	var f0: Vector2 = finfo["start"]
	var f1: Vector2 = finfo["end"]
	var hits := 0
	for wid in walls:
		var winfo: Dictionary = sketch.entity_info(wid)
		if winfo.is_empty():
			continue
		var s: Vector2 = winfo["start"]
		var e: Vector2 = winfo["end"]
		if s.distance_to(f0) <= 0.5 or s.distance_to(f1) <= 0.5 \
				or e.distance_to(f0) <= 0.5 or e.distance_to(f1) <= 0.5:
			hits += 1
	return hits == 2


func _find_floor_for_walls(walls: Array[String]) -> String:
	if walls.size() != 2:
		return ""
	var ends: Array[Vector2] = []
	for wid in walls:
		var winfo: Dictionary = sketch.entity_info(wid)
		if winfo.is_empty():
			return ""
		ends.append(winfo["start"])
		ends.append(winfo["end"])
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		if walls.has(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		var s_hit := false
		var e_hit := false
		for p in ends:
			if s.distance_to(p) <= 0.5:
				s_hit = true
			if e.distance_to(p) <= 0.5:
				e_hit = true
		if s_hit and e_hit:
			return id
	return ""


## Names the entity that still opens the wire. One sentence with
## `breaks the chain` so a refused cut is inspectable.
func _chain_breaker_status() -> String:
	var p: Variant = _open_profile_point()
	var breaker_id := ""
	var breaker_type := "entity"
	if p is Vector2:
		var pt: Vector2 = p
		var best := 1.0e9
		for id in sketch.entity_ids():
			if sketch.is_construction(id):
				continue
			var info: Dictionary = sketch.entity_info(id)
			var kind := str(info.get("type", ""))
			var pts: Array = []
			match kind:
				"line", "arc":
					pts = [info.get("start", Vector2.ZERO), info.get("end", Vector2.ZERO)]
				_:
					continue
			for q in pts:
				if typeof(q) != TYPE_VECTOR2:
					continue
				var d := pt.distance_to(q)
				if d < best:
					best = d
					breaker_id = id
					breaker_type = kind
		if breaker_id != "":
			return "%s at (%.1f, %.1f) breaks the chain — delete or trim it" % [
				breaker_type.capitalize(), pt.x, pt.y]
		return "open profile at (%.1f, %.1f) breaks the chain" % [pt.x, pt.y]
	return "open profile breaks the chain"


## Lines that end on a circle turn that circle into a hole when the planar
## split also uses it as the outer cap. Keep the outer arc — the cap away
## from the lines — and drop the full circle so the boss stays solid.
func _seal_tangent_bosses() -> void:
	if sketch == null:
		return
	var circles: Array = []
	var lines: Array = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		match str(info.get("type", "")):
			"circle":
				circles.append({
					"id": id,
					"c": info["center"],
					"r": float(info.get("radius", 0.0)),
				})
			"line":
				lines.append({
					"id": id,
					"a": info["start"],
					"b": info["end"],
				})
	if circles.is_empty() or lines.size() < 2:
		return
	for circ in circles:
		var c: Vector2 = circ["c"]
		var rad: float = float(circ["r"])
		if rad < 1e-6:
			continue
		var hits: Array = []
		for ln in lines:
			for role in ["a", "b"]:
				var p: Vector2 = ln[role]
				if absf(p.distance_to(c) - rad) > 0.05:
					continue
				var other: Vector2 = ln["b"] if role == "a" else ln["a"]
				hits.append({
					"p": p,
					"other": other,
					"line": str(ln["id"]),
					"role": "start" if role == "a" else "end",
				})
		if hits.size() < 2:
			continue
		var h0: Dictionary = hits[0]
		var h1: Dictionary = hits[1]
		var best: float = (h0["p"] as Vector2).distance_to(h1["p"])
		for i in range(hits.size()):
			for j in range(i + 1, hits.size()):
				var d: float = (hits[i]["p"] as Vector2).distance_to(hits[j]["p"])
				if d > best:
					best = d
					h0 = hits[i]
					h1 = hits[j]
		var shaft: Vector2 = ((h0["other"] as Vector2) + (h1["other"] as Vector2)) * 0.5
		var away := c - shaft
		if away.length_squared() < 1e-8:
			away = Vector2.RIGHT
		var through := c + away.normalized() * rad
		var p0: Vector2 = h0["p"]
		var p1: Vector2 = h1["p"]
		var a0 := (p0 - c).angle()
		var a1 := (p1 - c).angle()
		var at := (through - c).angle()
		if not _angle_in_sweep(a0, a1, at):
			var swap := a0
			a0 = a1
			a1 = swap
			var sp: Vector2 = p0
			p0 = p1
			p1 = sp
			var sh: Dictionary = h0
			h0 = h1
			h1 = sh
		var arc_id: String = sketch.add_arc(c.x, c.y, rad, a0, a1)
		_set_arc_ends(arc_id, c, rad, a0, a1)
		var ainfo: Dictionary = sketch.entity_info(arc_id)
		var as_: Vector2 = ainfo["start"]
		var ae: Vector2 = ainfo["end"]
		var l0: Dictionary = sketch.entity_info(str(h0["line"]))
		var l1: Dictionary = sketch.entity_info(str(h1["line"]))
		if str(h0["role"]) == "start":
			sketch.set_entity_geometry(str(h0["line"]), {"start": as_, "end": l0["end"]})
		else:
			sketch.set_entity_geometry(str(h0["line"]), {"start": l0["start"], "end": as_})
		l1 = sketch.entity_info(str(h1["line"]))
		if str(h1["role"]) == "start":
			sketch.set_entity_geometry(str(h1["line"]), {"start": ae, "end": l1["end"]})
		else:
			sketch.set_entity_geometry(str(h1["line"]), {"start": l1["start"], "end": ae})
		sketch.add_constraint("radius", [{"entity": arc_id, "role": "self"}], rad)
		sketch.add_constraint("coincident", [
			{"entity": str(h0["line"]), "role": str(h0["role"])},
			{"entity": arc_id, "role": "start"}], 0.0)
		sketch.add_constraint("coincident", [
			{"entity": str(h1["line"]), "role": str(h1["role"])},
			{"entity": arc_id, "role": "end"}], 0.0)
		sketch.remove_entity(str(circ["id"]))


func _angle_in_sweep(start: float, end_a: float, target: float) -> bool:
	var sweep := fposmod(end_a - start, TAU)
	var rel := fposmod(target - start, TAU)
	return rel <= sweep + 1e-4


func _drop_stale_dimensions() -> void:
	var live := {}
	for id in sketch.entity_ids():
		live[str(id)] = true
	var kept: Array = []
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var ok := true
		for id in dim.get("ids", []):
			if not live.has(str(id)):
				ok = false
				break
		if ok:
			kept.append(dim)
	dimensions = kept


## A new centreline replaces the previous cutter. Datum diagonal and
## datum +X (`_angle_datum_lines`) stay.
func _delete_other_non_datum_construction_lines() -> void:
	if sketch == null:
		return
	var to_drop: Array[String] = []
	for id in sketch.entity_ids():
		if not sketch.is_construction(id):
			continue
		if _angle_datum_lines.has(id):
			continue
		if str(sketch.entity_info(id).get("type", "")) != "line":
			continue
		to_drop.append(id)
	for id in to_drop:
		sketch.remove_entity(id)


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
	var removed := 0
	if any_on:
		var sides := _jaw_long_sides()
		if sides.size() == 2:
			var drop: Array[String] = []
			for id in sketch.entity_ids():
				if id in selected:
					continue
				if not sketch.is_construction(id) or _angle_datum_lines.has(id):
					continue
				var info: Dictionary = sketch.entity_info(id)
				if str(info.get("type", "")) != "line":
					continue
				if _line_is_jaw_cutter_candidate(info["start"], info["end"], sides):
					# Only drop when the line we just turned on is itself a jaw candidate.
					var turned_on_is_candidate := false
					for sel in selected:
						if not sketch.is_construction(sel):
							continue
						var si: Dictionary = sketch.entity_info(sel)
						if str(si.get("type", "")) != "line":
							continue
						if _line_is_jaw_cutter_candidate(si["start"], si["end"], sides):
							turned_on_is_candidate = true
					if turned_on_is_candidate:
						drop.append(id)
			for id in drop:
				sketch.remove_entity(id)
				removed += 1
	if removed > 0:
		status.emit("Removed %d jaw construction line(s) — one cutter at a time" % removed)
	else:
		status.emit("Construction " + ("on" if any_on else "off"))
	_redraw()
	_redraw_selected()


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


const CONTOUR_COLORS := [
	Color(0.20, 0.65, 1.00),
	Color(1.00, 0.55, 0.15),
	Color(0.35, 0.85, 0.45),
	Color(0.85, 0.40, 0.90),
]
const CONTOUR_FILL_ALPHA := 0.20
const CONTOUR_FOCUS_ALPHA := 0.70
const CONTOUR_OFF_COLOR := Color(0.55, 0.55, 0.55, 0.8)
const CONTOUR_LIFT_MM := 0.05


func set_contour_highlight(included: Array, focus: int = -1) -> void:
	_contour_included = included.duplicate()
	_contour_focus = focus
	_redraw_contour_highlight()


func contour_label(index: int) -> String:
	var regions := _contour_regions()
	var n := regions.size()
	if index < 0 or index >= n:
		return "Contour %d of %d" % [index + 1, n]
	var region: Dictionary = regions[index]
	var sz: Vector2 = region["size"]
	var c: Vector2 = region["center"]
	return "Contour %d of %d — %.1f × %.1f mm at (%.1f, %.1f)" % [
		index + 1, n, sz.x, sz.y, c.x, c.y]


func contour_highlight_state() -> Dictionary:
	var live := _contour_node != null and _contour_node.mesh != null
	var tag := ""
	if _contour_tag != null and _contour_tag.visible:
		tag = _contour_tag.text
	return {
		"count": _contour_fill_alphas.size() if live else 0,
		"included": _contour_included.duplicate(),
		"focus": _contour_focus if live else -1,
		"fills": _contour_fill_alphas.duplicate() if live else [],
		"outlines": _contour_outline_count if live else 0,
		"tag": tag,
	}


func _contour_regions() -> Array:
	if sketch == null or not sketch.has_method("contour_outlines"):
		return []
	if _contour_cache_sig != _contour_sig:
		_contour_cache = sketch.contour_outlines()
		_contour_cache_sig = _contour_sig
	return _contour_cache


func _contour_bar_visible() -> bool:
	var chrome := _sketch_chrome()
	return chrome != null and chrome._contour_bar != null and chrome._contour_bar.visible


func _contour_is_on(index: int) -> bool:
	for x in _contour_included:
		if int(x) == index:
			return true
	return false


func _redraw_contour_highlight() -> void:
	_contour_fill_alphas = []
	_contour_outline_count = 0
	if _contour_tag != null:
		_contour_tag.visible = false
		_contour_tag.text = ""
	if _contour_node == null:
		return
	var regions := _contour_regions()
	if sketch == null or not _contour_bar_visible() or regions.size() < 2:
		_contour_node.mesh = null
		_contour_focus = -1
		return
	var tris := PackedVector2Array()
	var tri_cols := PackedColorArray()
	var lines := PackedVector2Array()
	var line_cols := PackedColorArray()
	for i in regions.size():
		var region: Dictionary = regions[i]
		var on := _contour_is_on(i)
		var focused := i == _contour_focus
		var base: Color = CONTOUR_COLORS[i % CONTOUR_COLORS.size()]
		var fill_alpha := 0.0
		if on:
			fill_alpha = CONTOUR_FOCUS_ALPHA if focused else CONTOUR_FILL_ALPHA
		_contour_fill_alphas.append(fill_alpha)
		var outer: PackedVector2Array = region["outer"]
		var holes: Array = region["holes"]
		if on and fill_alpha > 0.0 and outer.size() >= 3:
			var fill := Color(base.r, base.g, base.b, fill_alpha)
			for p in _contour_fill_triangles(outer, holes):
				tris.append(p)
				tri_cols.append(fill)
		var outline_col := base if on else CONTOUR_OFF_COLOR
		outline_col.a = 1.0 if on else CONTOUR_OFF_COLOR.a
		if _append_outline(lines, line_cols, outer, outline_col):
			_contour_outline_count += 1
		for hole in holes:
			if _append_outline(lines, line_cols, hole, outline_col):
				_contour_outline_count += 1
		if focused:
			_append_outline(lines, line_cols, _inset_loop(outer, 0.35), outline_col)
			_append_outline(lines, line_cols, _inset_loop(outer, 0.70), outline_col)
			for hole in holes:
				_append_outline(lines, line_cols, _inset_loop(hole, 0.35), outline_col)
				_append_outline(lines, line_cols, _inset_loop(hole, 0.70), outline_col)
	if tris.is_empty() and lines.is_empty():
		_contour_node.mesh = null
		return
	# ArrayMesh so fills and outlines stay separate surfaces (vertex colours).
	# The sketch lines stay ImmediateMesh; this overlay only needs a static mesh.
	var mesh := ArrayMesh.new()
	var lift := plane_normal() * CONTOUR_LIFT_MM
	if tris.size() >= 3:
		var verts := PackedVector3Array()
		for p in tris:
			verts.append(_to3(p) + lift)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = tri_cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _contour_fill_material)
	if lines.size() >= 2:
		var lverts := PackedVector3Array()
		for p in lines:
			lverts.append(_to3(p) + lift)
		var larrays: Array = []
		larrays.resize(Mesh.ARRAY_MAX)
		larrays[Mesh.ARRAY_VERTEX] = lverts
		larrays[Mesh.ARRAY_COLOR] = line_cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, larrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _contour_line_material)
	_contour_node.mesh = mesh
	if _contour_focus >= 0 and _contour_focus < regions.size() and _contour_tag != null:
		var centre: Vector2 = regions[_contour_focus]["center"]
		_contour_tag.text = str(_contour_focus + 1)
		_contour_tag.position = _to3(centre)
		_contour_tag.modulate = CONTOUR_COLORS[_contour_focus % CONTOUR_COLORS.size()]
		_contour_tag.visible = true


func _append_outline(lines: PackedVector2Array, cols: PackedColorArray,
		loop: PackedVector2Array, col: Color) -> bool:
	if loop.size() < 2:
		return false
	for i in loop.size():
		lines.append(loop[i])
		lines.append(loop[(i + 1) % loop.size()])
		cols.append(col)
		cols.append(col)
	return true


func _inset_loop(loop: PackedVector2Array, dist: float) -> PackedVector2Array:
	if loop.size() < 3:
		return PackedVector2Array()
	var c := Vector2.ZERO
	for p in loop:
		c += p
	c /= float(loop.size())
	var out := PackedVector2Array()
	for p in loop:
		var d: Vector2 = c - p
		if d.length() > dist * 1.5:
			out.append(p + d.normalized() * dist)
		else:
			out.append(p)
	return out


func _contour_fill_triangles(outer: PackedVector2Array, holes: Array) -> PackedVector2Array:
	var polys: Array = _contour_polygons(outer, holes)
	var tris := PackedVector2Array()
	for poly in polys:
		var loop: PackedVector2Array = poly
		tris.append_array(_triangulate_loop(loop))
	return tris


func _contour_polygons(outer: PackedVector2Array, holes: Array) -> Array:
	if holes.is_empty():
		return [outer]
	var acc := outer
	for hole in holes:
		var hole_loop: PackedVector2Array = hole
		var clipped: Array = Geometry2D.clip_polygons(acc, hole_loop)
		var kept: Array = []
		for p in clipped:
			var poly: PackedVector2Array = p
			if Geometry2D.is_polygon_clockwise(poly):
				continue
			kept.append(poly)
		var kept_area := 0.0
		for p in kept:
			kept_area += absf(_loop_area(p))
		var base := absf(_loop_area(acc))
		var hole_area := absf(_loop_area(hole_loop))
		if kept.is_empty() or kept_area > base - hole_area * 0.5:
			acc = _bridge_hole(acc, hole_loop)
		else:
			return kept
	return [acc]


func _bridge_hole(outer: PackedVector2Array, hole: PackedVector2Array) -> PackedVector2Array:
	var h := hole.duplicate()
	if Geometry2D.is_polygon_clockwise(outer) == Geometry2D.is_polygon_clockwise(h):
		h.reverse()
	var bi := 0
	var hi := 0
	var best := INF
	for i in outer.size():
		for j in h.size():
			var d: float = outer[i].distance_squared_to(h[j])
			if d < best:
				best = d
				bi = i
				hi = j
	var result := PackedVector2Array()
	for i in outer.size():
		result.append(outer[(bi + i) % outer.size()])
	result.append(outer[bi])
	for i in h.size():
		result.append(h[(hi + i) % h.size()])
	result.append(h[hi])
	return result


func _triangulate_loop(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	var idx := Geometry2D.triangulate_polygon(poly)
	var src := poly
	if idx.is_empty():
		src = poly.duplicate()
		src.reverse()
		idx = Geometry2D.triangulate_polygon(src)
	var tris := PackedVector2Array()
	for t in range(0, idx.size(), 3):
		tris.append(src[idx[t]])
		tris.append(src[idx[t + 1]])
		tris.append(src[idx[t + 2]])
	return tris


func _loop_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	var n := poly.size()
	if n < 3:
		return 0.0
	for i in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func click(pos2: Vector2) -> void:
	if not active:
		return
	# A new pick means the user kept drawing. The next Esc is the normal
	# ladder again, not the exit promised by the previous point drop or by
	# an Extrude refusal.
	_esc_exit_promised = false
	_refusal_esc_ladder = false
	# Select hit-tests the real cursor. Snapping first pulls a shaft-line
	# click onto a nearby centre or endpoint and the line reads as a miss.
	var select_pos := pos2
	_point_from_length = false
	_last_commit_text = ""
	# A dimension label sits a few millimetres off the geometry. Snapping first
	# pulls that click onto the line and the in-sketch editor never opens.
	# Jaw / Trim / SMART_DIM stay armed after a commit; a click on the first
	# glyph must open the editor instead of starting a new gesture. Draw tools
	# use the on-screen text rect only — the 22 px / 6 mm halo would steal a
	# Jaw click 2 near a typed-circle radius label.
	# Line and Centerline still place the point: the jaw-width "20" label sits
	# on the 45° ray, and #164's rect hit ate the centreline's second click.
	var place_point := tool == Tool.LINE or tool == Tool.CENTERLINE
	var dhit_raw := -1
	if not place_point:
		dhit_raw = dimension_hit(pos2, tool != Tool.SELECT and tool != Tool.SMART_DIM)
	# A stacked Ø45 radius label walks onto the top rim. Select still picks
	# that circle; the editor opens only when the click is not on its rim.
	if dhit_raw >= 0 and not _radius_label_on_own_rim(dhit_raw, pos2):
		_emit_dimension_edit(dhit_raw)
		return
	# TRIM/EXTEND need the raw pick along the curve; snap would pull away.
	if tool != Tool.TRIM and tool != Tool.EXTEND:
		pos2 = snap_point(pos2)
	# Typed length wins over the cursor: keep the (snapped) pick's direction
	# and lock the distance. Do not write the pick into _hover — finish_extrude
	# and the next rubber-band still need the live pointer — and do not snap
	# the already-scaled tip (that pulls a 150 mm slot onto 3D pierce points).
	_point_from_length = false
	if _length_override >= 0.0 and has_single_dof_preview():
		_point_from_length = true
		if _length_override < MIN_SEGMENT_MM:
			status.emit("Too short")
			return
		var last: Vector2 = _tool_points[_tool_points.size() - 1]
		var d := pos2 - last
		if d.length_squared() < 1e-12:
			pos2 = last + Vector2(_length_override, 0.0)
		else:
			pos2 = last + d.normalized() * _length_override
		_length_override = -1.0
	elif tool == Tool.POLYGON and _tool_points.size() == 1 and not _point_from_length:
		pos2 = _polygon_pointer_tip(_tool_points[0], pos2)
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
				_emit_dimension_edit(dhit)
				return
			_select_at(select_pos)
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
				var as_centreline := draw_construction or tool == Tool.CENTERLINE
				if as_centreline:
					_delete_other_non_datum_construction_lines()
				var lid: String = sketch.add_line(a.x, a.y, b.x, b.y)
				remember_numeric(a.distance_to(b))
				if as_centreline:
					sketch.set_construction(lid, true)
					# Two-point centreline: do not extend the next click.
					_tool_points.clear()
				_infer_line(lid, a, b)
				if as_centreline:
					_drop_stale_dimensions()
				_redraw()
				# Propose chips follow new geometry even when infer did not solve.
				selection_actions_needed.emit()
				if as_centreline:
					status.emit("Centerline added — construction, not part of the profile")
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
				var drag := c.distance_to(vertex)
				# Across-flats is always flats-horizontal (start angle 0), in
				# preview and on commit. The drag/typed length is the AF.
				if tool_variant == "across_flats":
					polygon_sides = 6
				var verts := _polygon_ring_vertices(c, vertex)
				if verts.size() >= 3:
					var n := verts.size()
					var lids: Array[String] = []
					for i in range(n):
						var va: Vector2 = verts[i]
						var vb: Vector2 = verts[(i + 1) % n]
						var lid: String = sketch.add_line(va.x, va.y, vb.x, vb.y)
						lids.append(lid)
					_weld_loop(lids)
					for i in range(n):
						var a_id: String = lids[i]
						var b_id: String = lids[(i + 1) % n]
						sketch.add_constraint("coincident", [
							{"entity": a_id, "role": "end"},
							{"entity": b_id, "role": "start"}], 0.0)
					if tool_variant == "across_flats":
						for lid in lids:
							var einfo: Dictionary = sketch.entity_info(lid)
							var ed: Vector2 = einfo["end"] - einfo["start"]
							if absf(ed.y) <= 1e-6 and absf(ed.x) > 1e-6:
								sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
					run_solve()
					_weld_loop(lids)
					remember_numeric(drag)
					if tool_variant == "across_flats":
						_last_commit_text = "Polygon AF %.4f — flats horizontal" % drag
						status.emit(_last_commit_text)
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
				remember_numeric(maxf(rx, ry))
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
				var cc := _tool_points[0].distance_to(_tool_points[1])
				remember_numeric(cc, "slot_cc")
				_add_slot(_tool_points[0], _tool_points[1], slot_radius)
				_last_commit_text = slot_cc_status(cc, _point_from_length)
				status.emit(_last_commit_text)
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
		"center_three_point":
			# Click 1 = centre, click 2 = long-side direction and half-length,
			# click 3 = half-width (perpendicular distance from the axis).
			# Repeat click 2 must not commit: camera/snap noise sits well above
			# 1e-6 mm and still prints width 0.0000. Same floor as a line.
			var npts := _tool_points.size()
			if npts == 1:
				status.emit(JAW_AFTER_CENTRE)
			elif npts == 2:
				if _tool_points[0].distance_to(_tool_points[1]) < MIN_SEGMENT_MM:
					_tool_points.remove_at(1)
					status.emit(JAW_ZERO_LONG)
				else:
					status.emit(JAW_AFTER_LONG)
			elif npts >= 3:
				var ctr: Vector2 = _tool_points[0]
				var along: Vector2 = _tool_points[1] - ctr
				if along.length() < MIN_SEGMENT_MM:
					_tool_points.resize(1)
					status.emit(JAW_ZERO_LONG)
				else:
					var dir := along.normalized()
					var half_len := along.length()
					var nrm := Vector2(-dir.y, dir.x)
					var half_w := absf((_tool_points[2] - ctr).dot(nrm))
					var near_click2 := _tool_points[2].distance_to(_tool_points[1]) \
							< MIN_SEGMENT_MM
					if half_w < MIN_SEGMENT_MM or near_click2:
						_tool_points.resize(2)
						status.emit(JAW_ZERO_WIDTH)
					else:
						var u := dir * half_len
						var v := nrm * half_w
						var ra := ctr - u - v
						var rb := ctr + u - v
						var rc := ctr + u + v
						var rd := ctr - u + v
						var q1: String = sketch.add_line(ra.x, ra.y, rb.x, rb.y)
						var q2: String = sketch.add_line(rb.x, rb.y, rc.x, rc.y)
						var q3: String = sketch.add_line(rc.x, rc.y, rd.x, rd.y)
						var q4: String = sketch.add_line(rd.x, rd.y, ra.x, ra.y)
						var qids: Array[String] = [q1, q2, q3, q4]
						_weld_loop(qids)
						_constrain_quad(q1, q2, q3, q4, false)
						var pt: String = sketch.add_point(ctr.x, ctr.y)
						# Short side drives the jaw width. Long side is an angle
						# to a construction +X through the centre. Construction
						# stays out of the profile.
						_add_centre_rect_dimensions(q1, q2, q3, ctr, pt)
						_undo_note("Jaw")
						status.emit("Jaw committed — width %.4f, long side %.1f° — click a label to edit it" % [
								half_w * 2.0, fposmod(rad_to_deg(dir.angle()), 180.0)])
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
						circle_radius = r
				_tool_points.clear()
		_:  # center
			if _tool_points.size() == 1:
				status.emit(CIRCLE_CENTRE_SET)
			elif _tool_points.size() == 2:
				var c := _tool_points[0]
				var r := c.distance_to(_tool_points[1])
				if r > 1e-6:
					var typed := _point_from_length
					var circ_id: String = sketch.add_circle(c.x, c.y, r)
					circle_radius = r
					_last_commit_text = "Circle r=%.4f (Ø%.4f)" % [r, r * 2.0]
					status.emit(_last_commit_text)
					if typed and circ_id != "":
						var rcid: String = sketch.add_constraint(
								"radius", [{"entity": circ_id, "role": "self"}], r)
						_record_dimension("radius", [circ_id], r, rcid)
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
						remember_numeric(r)
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
					remember_numeric(r)
					sketch.add_arc(c.x, c.y, r, (start_pt - c).angle(), (end_pt - c).angle())
				_tool_points.clear()
		_:  # center
			if _tool_points.size() == 3:
				var c := _tool_points[0]
				var start_pt := _tool_points[1]
				var end_pt := _tool_points[2]
				var r := c.distance_to(start_pt)
				if r > 1e-6:
					remember_numeric(r)
					sketch.add_arc(c.x, c.y, r, (start_pt - c).angle(), (end_pt - c).angle())
				_tool_points.clear()
	_redraw()


func _add_slot(a: Vector2, b: Vector2, half_w: float) -> void:
	var d := b - a
	if d.length() < 1e-6 or half_w < 1e-6:
		return
	_undo_note("Slot")
	var r := half_w
	var n := Vector2(-d.y, d.x).normalized() * r
	var p_top_a := a + n
	var p_top_b := b + n
	var p_bot_a := a - n
	var p_bot_b := b - n
	var top: String = sketch.add_line(p_top_a.x, p_top_a.y, p_top_b.x, p_top_b.y)
	var bot: String = sketch.add_line(p_bot_a.x, p_bot_a.y, p_bot_b.x, p_bot_b.y)
	var out_b := d.normalized()
	var out_a := -out_b
	# CCW semicircle through the outward direction: start = outward-90°, end = outward+90°.
	var cap_b: String = sketch.add_arc(b.x, b.y, r, out_b.angle() - PI * 0.5, out_b.angle() + PI * 0.5)
	var cap_a: String = sketch.add_arc(a.x, a.y, r, out_a.angle() - PI * 0.5, out_a.angle() + PI * 0.5)
	sketch.add_constraint("radius", [{"entity": cap_a, "role": "self"}], r)
	sketch.add_constraint("radius", [{"entity": cap_b, "role": "self"}], r)
	var dist_cid: String = sketch.add_constraint("distance", [
		{"entity": cap_a, "role": "center"},
		{"entity": cap_b, "role": "center"}], a.distance_to(b))
	_record_dimension("distance", [cap_a, cap_b], a.distance_to(b), dist_cid)
	_record_dimension("radius", [cap_a], r, "")
	run_solve()
	# Arc rules can drift the caps; put the four joints back on the circles.
	_weld_slot(top, bot, cap_a, cap_b, a, b, r)
	# Keep the joints through the extrude re-solve (1e-6 wire tolerance).
	sketch.add_constraint("coincident", [
		{"entity": top, "role": "start"},
		{"entity": cap_a, "role": "start"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": top, "role": "end"},
		{"entity": cap_b, "role": "end"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": bot, "role": "start"},
		{"entity": cap_a, "role": "end"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": bot, "role": "end"},
		{"entity": cap_b, "role": "start"}], 0.0)


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


const SMART_DIM_PICK_HINT := "Smart Dim: first pick set — click the second circle's centre or edge (Esc drops it)"
const SMART_DIM_MISS_HINT := "Smart Dim: nothing there — first pick kept, click the second circle's centre or edge (Esc drops it)"
const SMART_DIM_SAME_HINT := "Smart Dim: pick a different circle — first pick kept"


## True while Smart Dim holds a first centre pick and waits for the second.
func has_pending_dim_pick() -> bool:
	return tool == Tool.SMART_DIM and not _smart_dim_pending.is_empty()


## The status line just told the user the next Esc leaves the sketch.
func promise_next_esc_exits() -> void:
	_esc_exit_promised = true


## Extrude refused and left the sketch open. The next Esc must be the exit
## ladder, not `Chain ended` or a silent focus release.
func arm_refusal_exit_ladder() -> void:
	_refusal_esc_ladder = true


## One status for the Esc that follows a refusal, or "" when that ladder is
## not armed. Ends an open line chain in the same press and promises the
## following Esc leaves.
func take_refusal_exit_ladder() -> String:
	if not _refusal_esc_ladder or not active:
		return ""
	_refusal_esc_ladder = false
	if has_length_override():
		clear_length_override()
	if has_pending_draw_point():
		cancel_pending_draw()
		promise_next_esc_exits()
		return "First point dropped — Esc again exits the sketch"
	if has_open_chain():
		end_chain()
	if not selected.is_empty():
		_set_selected([])
		if tool != Tool.SELECT and tool != Tool.NONE:
			set_tool(Tool.SELECT)
		promise_next_esc_exits()
		return "Selection cleared — Esc again exits the sketch"
	if tool != Tool.SELECT and tool != Tool.NONE:
		set_tool(Tool.SELECT)
	promise_next_esc_exits()
	return "Tool dropped — Esc again exits the sketch"


## Esc rungs between "drop a pending point" and leaving the sketch: clear a
## selection, then drop a draw tool back to Select once the sketch holds
## geometry. Returns the status to show, or "" when nothing is left to drop.
## The caller then saves a sketch that has committed geometry and cancels
## only an empty one.
##
## A pending-point drop already promised the next Esc leaves. A live
## selection still spends the key first (the promise stays armed), so a
## Select click after a hover measure cannot exit on the same Esc.
func esc_keep_sketch() -> String:
	if not active or sketch == null:
		return ""
	# A selection (entity or constraint glyph) always spends this Esc.
	# Honouring the exit promise first left the sketch on the same key that
	# should have cleared a Select click made after a hover measure.
	if not selected.is_empty() or selected_constraint != "":
		if not selected.is_empty():
			_set_selected([])
		if selected_constraint != "":
			select_constraint("")
		return "Selection cleared — Esc again exits the sketch"
	if _esc_exit_promised:
		_esc_exit_promised = false
		return ""
	if tool != Tool.SELECT and tool != Tool.NONE and not sketch.entity_ids().is_empty():
		set_tool(Tool.SELECT)
		return "Tool dropped — Esc again exits the sketch"
	return ""


## Esc with a first Smart Dim pick: drop the pick and keep the sketch session.
func cancel_pending_dim_pick() -> void:
	_smart_dim_pending.clear()
	_smart_dim_first = null
	_set_selected([])


func _click_smart_dim(pos2: Vector2) -> void:
	var center_ref := _center_ref_near(pos2)
	if not center_ref.is_empty():
		if not _smart_dim_pending.is_empty():
			if str(_smart_dim_pending["entity"]) == str(center_ref["entity"]):
				status.emit(SMART_DIM_SAME_HINT)
				return
			_smart_dim_between(_smart_dim_pending, center_ref)
			_smart_dim_pending.clear()
		else:
			_smart_dim_pending = center_ref
			_set_selected([str(center_ref["entity"])])
			status.emit(SMART_DIM_PICK_HINT)
		_smart_dim_first = null
		return
	var hit := _nearest_entity_at(pos2)
	if hit == "":
		if not _smart_dim_pending.is_empty():
			status.emit(SMART_DIM_MISS_HINT)
			return
		_smart_dim_first = null
		return
	var info: Dictionary = sketch.entity_info(hit)
	match str(info.get("type", "")):
		"circle", "arc":
			if not _smart_dim_pending.is_empty():
				if str(_smart_dim_pending["entity"]) == hit:
					status.emit(SMART_DIM_SAME_HINT)
					return
				_smart_dim_between(_smart_dim_pending, {"entity": hit, "role": "center"})
				_smart_dim_pending.clear()
			else:
				_set_selected([hit])
				constrain("diameter", float(info.get("radius", 5.0)) * 2.0)
			_smart_dim_first = null
		"line":
			if not _smart_dim_pending.is_empty():
				_smart_dim_between(_smart_dim_pending, {"entity": hit, "role": "self"})
				_smart_dim_pending.clear()
			elif selected.size() == 1 and selected[0] != hit \
					and sketch.entity_info(selected[0]).get("type", "") == "line":
				_set_selected([selected[0], hit])
				constrain("angle", _lines_signed_angle(selected[0], hit))
			else:
				_set_selected([hit])
				constrain("distance", info["start"].distance_to(info["end"]))
				var mid: Vector2 = (info["start"] + info["end"]) * 0.5
				_add_angle_to_horizontal(hit, mid)
				run_solve()
				_redraw()
			_smart_dim_first = null
		_:
			_set_selected([hit])
			_smart_dim_first = pos2
			_smart_dim_pending.clear()


## Click nearer a circle/arc centre than its curve → that centre, else {}.
func _center_ref_near(pos2: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := _snap_radius()
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		var c: Vector2 = info["center"]
		var d := pos2.distance_to(c)
		var curve := _entity_distance(info, pos2)
		if d < curve and d <= best_d:
			best_d = d
			best = {"entity": id, "role": "center"}
	return best


func _lines_signed_angle(id_a: String, id_b: String) -> float:
	var ia: Dictionary = sketch.entity_info(id_a)
	var ib: Dictionary = sketch.entity_info(id_b)
	var da: Vector2 = ia["end"] - ia["start"]
	var db: Vector2 = ib["end"] - ib["start"]
	if da.length_squared() < 1e-12 or db.length_squared() < 1e-12:
		return PI * 0.5
	return da.angle_to(db)


func _smart_dim_between(a: Dictionary, b: Dictionary) -> void:
	var ida := str(a.get("entity", ""))
	var idb := str(b.get("entity", ""))
	if ida == "" or idb == "":
		return
	var ta := str(sketch.entity_info(ida).get("type", ""))
	var tb := str(sketch.entity_info(idb).get("type", ""))
	_set_selected([ida, idb])
	var line_id := ""
	var pt := {}
	if tb == "line" and ta != "line":
		line_id = idb
		pt = a
	elif ta == "line" and tb != "line":
		line_id = ida
		pt = b
	if line_id != "" and not pt.is_empty():
		var pref := _point_xy(pt)
		var li: Dictionary = sketch.entity_info(line_id)
		var dist := _point_line_distance(pref, li["start"], li["end"])
		var cid: String = sketch.add_constraint("distance", [
			{"entity": str(pt["entity"]), "role": str(pt.get("role", "center"))},
			{"entity": line_id, "role": "self"}], dist)
		_record_dimension("distance", [str(pt["entity"]), line_id], dist, cid)
		_last_commit_text = "centre-to-flat %.4f" % dist
		status.emit(_last_commit_text)
		_undo_note("Dimension")
		run_solve()
		_redraw()
		return
	if (ta == "circle" or ta == "arc") and (tb == "circle" or tb == "arc"):
		var ca: Vector2 = sketch.entity_info(ida)["center"]
		var cb: Vector2 = sketch.entity_info(idb)["center"]
		_pin_circle_at_sketch_origin(ida, ca)
		_pin_circle_at_sketch_origin(idb, cb)
		var dxy: Vector2 = cb - ca
		# Nearly level centres stay level when the distance is driven, without
		# a construction line or a coincident dot inside either circle (T14).
		if absf(dxy.x) > 1e-9 and absf(dxy.y) <= tan(deg_to_rad(2.0)) * absf(dxy.x) \
				and not _centers_share_horizontal(ida, idb):
			sketch.add_constraint("horizontal", [
				{"entity": ida, "role": "center"},
				{"entity": idb, "role": "center"}], 0.0)
		_snap_marker = null
		constrain("distance", ca.distance_to(cb))
		# A failed solve reverts the constraint. Do not open a popup on a
		# stale index — only emit when that centre distance is still live.
		var idx := _distance_dim_index_for(ida, idb)
		if idx >= 0:
			_emit_dimension_edit(idx)
		return
	if ta == "line" and tb == "line":
		constrain("angle", _lines_signed_angle(ida, idb))


## Open the in-viewport editor now, and again next frame. A click that hits
## a label while the popup is already up dismisses that popup on mouse-up;
## the deferred emit puts it back so a label click still leaves it visible.
func _emit_dimension_edit(index: int) -> void:
	if index < 0:
		return
	dimension_edit_requested.emit(index)
	_reemit_dimension_edit.call_deferred(index)


func _reemit_dimension_edit(index: int) -> void:
	if index < 0 or index >= dimensions.size():
		return
	if str(dimensions[index].get("cid", "")) == "":
		return
	dimension_edit_requested.emit(index)


func _distance_dim_index_for(ida: String, idb: String) -> int:
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if str(dim.get("type", "")) != "distance":
			continue
		if str(dim.get("cid", "")) == "":
			continue
		var ids: Array = dim.get("ids", [])
		if ids.size() < 2:
			continue
		var a := str(ids[0])
		var b := str(ids[1])
		if (a == ida and b == idb) or (a == idb and b == ida):
			return i
	return -1


func _point_xy(ref: Dictionary) -> Vector2:
	var info: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
	var role := str(ref.get("role", "self"))
	match str(info.get("type", "")):
		"line":
			return info["start"] if role == "start" else info["end"]
		"circle", "arc":
			return info["center"]
		"point":
			return info.get("position", Vector2.ZERO)
	return Vector2.ZERO


func _point_line_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len := ab.length()
	if len < 1e-9:
		return p.distance_to(a)
	return absf((p - a).cross(ab)) / len


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
## `pin_tangent` (Shaft Lines): a tangent plus a point-on-circle of the same
## radius is one equation twice, and PlaneGCS paints that as a redundant /
## conflicting H. Pin the contact with a construction radius perpendicular
## to the line instead of the extra distance.
func _infer_line(lid: String, a: Vector2, b: Vector2, pin_tangent: bool = false) -> void:
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
		else:
			var tang_id := _infer_tangent_at(lid, role_pos[1], d)
			if tang_id != "":
				added = true
				if pin_tangent:
					_pin_tangent_contact(lid, str(role_pos[0]), tang_id, role_pos[1])
				elif _infer_on_circle(lid, str(role_pos[0]), role_pos[1]):
					added = true
			elif _infer_on_circle(lid, str(role_pos[0]), role_pos[1]):
				added = true
	if added:
		# Snap contacts onto the circles before DogLeg runs — otherwise a
		# horizontal tangent has two solutions (y=+r and y=-r) and the solver
		# can jump to the far side of a typed Ø20.
		_weld_on_circle_endpoints(lid)
		var info0: Dictionary = sketch.entity_info(lid)
		run_solve()
		var flipped := false
		var info1: Dictionary = sketch.entity_info(lid)
		if not info0.is_empty() and not info1.is_empty():
			var mid_click := (a + b) * 0.5
			var mid1: Vector2 = ((info1["start"] as Vector2) + (info1["end"] as Vector2)) * 0.5
			if absf(mid_click.y) > 1.0 and mid_click.y * mid1.y < 0.0:
				flipped = true
				sketch.set_entity_geometry(lid, {
					"start": info0["start"],
					"end": info0["end"],
				})
		_weld_on_circle_endpoints(lid)
		_sync_tangent_pins()
		# Pin a restored horizontal tangent so a later Extrude solve cannot
		# jump it to the far side again. Shaft Lines must not: Fix plus the
		# horizontal is the redundant lock that paints the H badge red, and
		# the pair pin already puts both lines back on their constructed sides.
		if flipped and not pin_tangent and not _entity_has_constraint(lid, "fix"):
			sketch.add_constraint("fix", [{"entity": lid, "role": "self"}], 0.0)


## Endpoint lying on a circle, with the segment perpendicular to the radius,
## is a line–circle tangent (the shaft lines on the Ø20). A secant that merely
## ends on a larger circle is left alone. Returns the circle id, or "".
func _infer_tangent_at(lid: String, p: Vector2, seg: Vector2) -> String:
	if seg.length() <= INFER_TOL:
		return ""
	var dir := seg.normalized()
	for id in sketch.entity_ids():
		if id == lid:
			continue
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		var c: Vector2 = info["center"]
		var r: float = float(info.get("radius", 0.0))
		if absf(p.distance_to(c) - r) > INFER_TOL:
			continue
		var radial := p - c
		if radial.length() <= 1e-6:
			continue
		if absf(radial.normalized().dot(dir)) > 0.2:
			continue
		# Typed radius already lives on this circle. Lock centre + radius so
		# the tangent solve may slide contact but must not move the boss.
		_lock_sized_circle(id)
		sketch.add_constraint("tangent", [
			{"entity": lid, "role": "self"},
			{"entity": id, "role": "self"}], 0.0)
		return id
	return ""


func _infer_on_circle(lid: String, role: String, p: Vector2) -> bool:
	for id in sketch.entity_ids():
		if id == lid:
			continue
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc":
			continue
		var c: Vector2 = info["center"]
		var r: float = float(info.get("radius", 0.0))
		if absf(p.distance_to(c) - r) > INFER_TOL:
			continue
		_lock_sized_circle(id)
		sketch.add_constraint("distance", [
			{"entity": lid, "role": role},
			{"entity": id, "role": "center"}], r)
		return true
	return false


## Shaft Lines: keep the tangent, and pin the contact with a construction
## radius perpendicular to the line. A point-on-circle distance of the same
## radius is the same equation as the tangent once the contact is the foot of
## the perpendicular, so PlaneGCS reports one redundant and paints the H
## badges red. The far end (on the larger circle, not tangent) still gets
## `_infer_on_circle`.
func _pin_tangent_contact(lid: String, role: String, circle_id: String, p: Vector2) -> void:
	if sketch == null or lid == "" or circle_id == "" or _shaft_has_tangent_pin(lid, role):
		return
	var info: Dictionary = sketch.entity_info(circle_id)
	if info.is_empty():
		return
	var c: Vector2 = info["center"]
	var helper: String = sketch.add_line(c.x, c.y, p.x, p.y)
	if helper == "":
		return
	sketch.set_construction(helper, true)
	sketch.add_constraint("coincident", [
		{"entity": circle_id, "role": "center"},
		{"entity": helper, "role": "start"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": lid, "role": role},
		{"entity": helper, "role": "end"}], 0.0)
	sketch.add_constraint("perpendicular", [
		{"entity": helper, "role": "self"},
		{"entity": lid, "role": "self"}], 0.0)


func _shaft_has_tangent_pin(lid: String, role: String) -> bool:
	if sketch == null:
		return false
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "coincident":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() != 2:
			continue
		var hit := false
		var other := ""
		for ref in refs:
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			if str(ref.get("entity", "")) == lid and str(ref.get("role", "")) == role:
				hit = true
			else:
				other = str(ref.get("entity", ""))
		if not hit or other == "":
			continue
		if sketch.is_construction(other):
			return true
	return false


## Construction radii added by `_pin_tangent_contact` follow the shaft endpoint
## after a flip restore. Other construction lines (centre dimension) are left
## alone.
func _sync_tangent_pins() -> void:
	if sketch == null:
		return
	for id in sketch.entity_ids():
		if not sketch.is_construction(str(id)):
			continue
		var info: Dictionary = sketch.entity_info(str(id))
		if str(info.get("type", "")) != "line":
			continue
		var bound := _tangent_pin_binding(str(id))
		if bound.is_empty():
			continue
		var cinfo: Dictionary = sketch.entity_info(str(bound["circle"]))
		var linfo: Dictionary = sketch.entity_info(str(bound["shaft"]))
		if cinfo.is_empty() or linfo.is_empty():
			continue
		var c: Vector2 = cinfo["center"]
		var p: Vector2 = linfo["start"] if str(bound["role"]) == "start" else linfo["end"]
		sketch.set_entity_geometry(str(id), {"start": c, "end": p})


func _tangent_pin_binding(helper_id: String) -> Dictionary:
	var circle_id := ""
	var shaft_id := ""
	var shaft_role := ""
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "coincident":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() != 2:
			continue
		var mine: Dictionary = {}
		var other: Dictionary = {}
		if str(refs[0].get("entity", "")) == helper_id:
			mine = refs[0]
			other = refs[1]
		elif str(refs[1].get("entity", "")) == helper_id:
			mine = refs[1]
			other = refs[0]
		else:
			continue
		var oid := str(other.get("entity", ""))
		var oinfo: Dictionary = sketch.entity_info(oid)
		var kind := str(oinfo.get("type", ""))
		if str(mine.get("role", "")) == "start" and str(other.get("role", "")) == "center" \
				and (kind == "circle" or kind == "arc"):
			circle_id = oid
		elif str(mine.get("role", "")) == "end" and kind == "line" \
				and str(other.get("role", "")) in ["start", "end"]:
			shaft_id = oid
			shaft_role = str(other.get("role", ""))
	if circle_id == "" or shaft_id == "":
		return {}
	return {"circle": circle_id, "shaft": shaft_id, "role": shaft_role}


## True when `entity_id` already has a constraint of `type_name`.
func _entity_has_constraint(entity_id: String, type_name: String) -> bool:
	if sketch == null or entity_id == "":
		return false
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != type_name:
			continue
		for ref in info.get("refs", []):
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			if str(ref.get("entity", "")) == entity_id:
				return true
	return false


## Lock a circle that already has a radius so a later tangent solve cannot
## translate its centre or change that radius. Contact may still slide.
func _lock_sized_circle(id: String) -> void:
	if sketch == null or id == "":
		return
	var info: Dictionary = sketch.entity_info(id)
	if str(info.get("type", "")) != "circle":
		return
	var r := float(info.get("radius", 0.0))
	if r <= 1e-6:
		return
	if _entity_has_constraint(id, "fix"):
		return
	# A3 already pins the bosses (coincident, or a centre-to-centre distance).
	# A second Fix makes one shaft tangent redundant and paints the H badge.
	if _entity_has_constraint(id, "coincident"):
		return
	if _entity_has_constraint(id, "distance"):
		return
	# Centre only. A full Fix also locks the radius and duplicates the driving
	# radius dimension.
	sketch.add_constraint("fix", [{"entity": id, "role": "center"}], 0.0)


const ORIGIN_PIN_TOL := 0.5


## True when a two-point horizontal already ties these centres together.
func _centers_share_horizontal(ida: String, idb: String) -> bool:
	if sketch == null:
		return false
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "horizontal":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() < 2:
			continue
		var a := str(refs[0].get("entity", ""))
		var b := str(refs[1].get("entity", ""))
		if (a == ida and b == idb) or (a == idb and b == ida):
			return true
	return false


func _pin_circle_at_sketch_origin(id: String, center: Vector2) -> void:
	if center.length() > ORIGIN_PIN_TOL:
		return
	var anchor := _origin_anchor_point()
	if anchor == "":
		# A distance between two circles is free to slide along the sketch.
		# Lock a centre that is already on the origin so the pair stays put.
		# A full Fix also locks the radius. A centre-only Fix does not, and
		# it adds no point and no construction line (T14).
		if not _entity_has_constraint(id, "fix"):
			sketch.add_constraint("fix", [{"entity": id, "role": "center"}], 0.0)
		return
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "coincident":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() == 2 and str(refs[0].get("entity", "")) == id and str(refs[1].get("entity", "")) == anchor:
			return
	sketch.add_constraint("coincident", [
		{"entity": id, "role": "center"},
		{"entity": anchor, "role": "self"}], 0.0)


func _origin_anchor_point() -> String:
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) == "point" and sketch.is_construction(id) \
				and _entity_has_constraint(id, "fix"):
			return id
	# Smart Dim between two circles must not invent a construction point at
	# the origin (T14). Pin only when that point already exists; otherwise
	# the centre-only Fix is used.
	return ""


## Lock every sized circle (typed radius on the wrench bosses).
func _lock_sized_circles() -> void:
	if sketch == null:
		return
	for id in sketch.entity_ids():
		_lock_sized_circle(id)


## Snap inference-marked on-circle endpoints onto the circle so the 1e-6
## chain and `_seal_tangent_bosses` (0.05 mm) both see a closed wire.
func _weld_on_circle_endpoints(line_id: String = "") -> void:
	if sketch == null:
		return
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(cid)
		if str(info.get("type", "")) != "distance":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() < 2:
			continue
		var lid := ""
		var role := ""
		var circ := ""
		for ref in refs:
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			var eid := str(ref.get("entity", ""))
			var rle := str(ref.get("role", ""))
			var einfo: Dictionary = sketch.entity_info(eid)
			var kind := str(einfo.get("type", ""))
			if kind == "line" and (rle == "start" or rle == "end"):
				lid = eid
				role = rle
			elif (kind == "circle" or kind == "arc") and (rle == "center" or rle == "self"):
				circ = eid
		if lid == "" or circ == "":
			continue
		if line_id != "" and lid != line_id:
			continue
		var linfo: Dictionary = sketch.entity_info(lid)
		var cinfo: Dictionary = sketch.entity_info(circ)
		if linfo.is_empty() or cinfo.is_empty():
			continue
		var c: Vector2 = cinfo["center"]
		var rad := float(cinfo.get("radius", 0.0))
		if rad < 1e-6:
			continue
		var p: Vector2 = linfo["start"] if role == "start" else linfo["end"]
		var d := p - c
		var welded: Vector2 = c + Vector2(rad, 0.0) if d.length_squared() < 1e-16 \
				else c + d.normalized() * rad
		if p.distance_to(welded) < 1e-12:
			continue
		if role == "start":
			sketch.set_entity_geometry(lid, {"start": welded, "end": linfo["end"]})
		else:
			sketch.set_entity_geometry(lid, {"start": linfo["start"], "end": welded})


## Line id → {start, end} for the current sketch.
func _snapshot_line_geometry() -> Dictionary:
	var out := {}
	if sketch == null:
		return out
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		out[id] = {"start": info["start"], "end": info["end"]}
	return out


## DogLeg's other horizontal-tangent solution sits on the far side of a
## locked circle. Put those lines back so `_seal_tangent_bosses` still sees
## one hit on each side of the shaft.
func _restore_flipped_shaft_lines(before: Dictionary) -> void:
	if sketch == null or before.is_empty():
		return
	var circs: Array = []
	for cid in sketch.entity_ids():
		var cinfo: Dictionary = sketch.entity_info(cid)
		if str(cinfo.get("type", "")) == "circle":
			circs.append({"c": cinfo["center"], "r": float(cinfo.get("radius", 0.0))})
	for id in before.keys():
		var prev: Dictionary = before[id]
		var info: Dictionary = sketch.entity_info(str(id))
		if info.is_empty() or str(info.get("type", "")) != "line":
			continue
		var s0: Vector2 = prev["start"]
		var e0: Vector2 = prev["end"]
		var s1: Vector2 = info["start"]
		var e1: Vector2 = info["end"]
		var mid0 := (s0 + e0) * 0.5
		var mid1 := (s1 + e1) * 0.5
		if absf(mid0.y) > 1.0 and mid0.y * mid1.y < 0.0:
			sketch.set_entity_geometry(str(id), {"start": s0, "end": e0})
			continue
		# Keep an on-circle end on that circle when solve slides it off.
		if (_endpoint_on_a_circle(s0, circs, 0.05) and not _endpoint_on_a_circle(s1, circs, 0.05)) \
				or (_endpoint_on_a_circle(e0, circs, 0.05) and not _endpoint_on_a_circle(e1, circs, 0.05)):
			sketch.set_entity_geometry(str(id), {"start": s0, "end": e0})
	_sync_tangent_pins()


func _endpoint_on_a_circle(p: Vector2, circs: Array, tol: float) -> bool:
	for circ in circs:
		if absf(p.distance_to(circ["c"]) - float(circ["r"])) <= tol:
			return true
	return false


## Status for a still-open extrude. Names the open vertex; does not offer
## Thin wall or Insert Box as the way to finish the blank.
func _open_profile_status() -> String:
	var p: Variant = _open_profile_point()
	if p is Vector2:
		var v: Vector2 = p
		return "Extrude failed — open profile at (%.1f, %.1f). Close that vertex." % [v.x, v.y]
	return "Extrude failed — open profile at (0.0, 0.0). Close that vertex."


## A degree-1 endpoint, or a tangent contact on a circle that does not yet
## close the wire (only one hit). Null when the sketch is empty.
func _open_profile_point() -> Variant:
	if sketch == null:
		return null
	var ends: Array[Vector2] = []
	var circs: Array = []
	var segs: Array = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		match str(info.get("type", "")):
			"circle":
				circs.append({"c": info["center"], "r": float(info.get("radius", 0.0))})
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				if a.distance_to(b) > 1e-9:
					ends.append(a)
					ends.append(b)
					segs.append({"a": a, "b": b})
			"arc":
				var pa: Vector2 = info["start"] if info.has("start") else info["center"]
				var pb: Vector2 = info["end"] if info.has("end") else info["center"]
				if pa.distance_to(pb) > 1e-9:
					ends.append(pa)
					ends.append(pb)
					segs.append({"a": pa, "b": pb})
			_:
				pass
	const TOL := 1e-6
	var used := {}
	var unmatched: Array[Vector2] = []
	for i in range(ends.size()):
		if used.has(i):
			continue
		var matched := false
		for j in range(i + 1, ends.size()):
			if used.has(j):
				continue
			if ends[i].distance_to(ends[j]) <= TOL:
				used[i] = true
				used[j] = true
				matched = true
				break
		if not matched:
			unmatched.append(ends[i])
	for p in unmatched:
		if _circle_hit_count_at(p, circs, segs, maxf(TOL, 1e-4)) < 2:
			return p
	if not unmatched.is_empty():
		return unmatched[0]
	return null


static func _circle_hit_count_at(p: Vector2, circs: Array, segs: Array, tol: float) -> int:
	var best := -1
	var best_err := tol
	for i in range(circs.size()):
		if typeof(circs[i]) != TYPE_DICTIONARY:
			continue
		var err := absf(p.distance_to(circs[i]["c"]) - float(circs[i]["r"]))
		if err <= best_err:
			best_err = err
			best = i
	if best < 0:
		return 0
	var c: Vector2 = circs[best]["c"]
	var r := float(circs[best]["r"])
	var n := 0
	for s in segs:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if absf((s["a"] as Vector2).distance_to(c) - r) <= tol:
			n += 1
		if absf((s["b"] as Vector2).distance_to(c) - r) <= tol:
			n += 1
	return n


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


## Centre-3-pt rectangle: driving width on the short side, and an angle from
## the long side to a construction line along sketch +X through the centre.
## `opp_long_id` is the opposite long side; a construction diagonal pins the
## centre so a later width edit cannot flatten the driving angle.
func _add_centre_rect_dimensions(long_id: String, short_id: String, opp_long_id: String,
		ctr: Vector2, pt_id: String) -> void:
	if sketch == null:
		return
	var short_info: Dictionary = sketch.entity_info(short_id)
	if str(short_info.get("type", "")) == "line":
		var a: Vector2 = short_info["end"]
		var b: Vector2 = short_info["start"]
		var width := a.distance_to(b)
		if width > 1e-6:
			var cid: String = sketch.add_constraint("distance", [
				{"entity": short_id, "role": "start"},
				{"entity": short_id, "role": "end"}], width)
			_record_dimension("distance", [short_id], width, cid, "jaw_width")
	if pt_id != "" and long_id != "" and opp_long_id != "":
		var ia: Dictionary = sketch.entity_info(long_id)
		var ic: Dictionary = sketch.entity_info(opp_long_id)
		if str(ia.get("type", "")) == "line" and str(ic.get("type", "")) == "line":
			var ra: Vector2 = ia["start"]
			var rc: Vector2 = ic["start"]
			var diag: String = sketch.add_line(ra.x, ra.y, rc.x, rc.y)
			if diag != "":
				sketch.set_construction(diag, true)
				_angle_datum_lines[diag] = true
				sketch.add_constraint("coincident", [
					{"entity": long_id, "role": "start"},
					{"entity": diag, "role": "start"}], 0.0)
				sketch.add_constraint("coincident", [
					{"entity": opp_long_id, "role": "start"},
					{"entity": diag, "role": "end"}], 0.0)
				sketch.add_constraint("midpoint", [
					{"entity": pt_id, "role": "self"},
					{"entity": diag, "role": "self"}], 0.0)
		sketch.add_constraint("fix", [{"entity": pt_id, "role": "self"}], 0.0)
	_add_angle_to_horizontal(long_id, ctr, pt_id, "jaw_angle")
	run_solve()


## Construction +X through `through`, plus a driving angle to `line_id`.
## The construction line stays construction so it is not part of the profile.
## `pt_id` when set is kept on that line (the rectangle centre).
func _add_angle_to_horizontal(line_id: String, through: Vector2, pt_id: String = "",
		callout: String = "") -> void:
	if sketch == null or line_id == "" or _line_has_angle_dim(line_id):
		return
	var info: Dictionary = sketch.entity_info(line_id)
	if str(info.get("type", "")) != "line":
		return
	var span: float = (info["end"] - info["start"]).length()
	var half := maxf(span * 0.75, 15.0)
	var a := through + Vector2(-half, 0.0)
	var b := through + Vector2(half, 0.0)
	var xid: String = sketch.add_line(a.x, a.y, b.x, b.y)
	if xid == "":
		return
	sketch.set_construction(xid, true)
	_angle_datum_lines[xid] = true
	sketch.add_constraint("horizontal", [{"entity": xid, "role": "self"}], 0.0)
	if pt_id == "":
		pt_id = sketch.add_point(through.x, through.y)
	if pt_id != "":
		sketch.add_constraint("point_on_line", [
			{"entity": pt_id, "role": "self"},
			{"entity": xid, "role": "self"}], 0.0)
	var ang := _lines_signed_angle(xid, line_id)
	var cid: String = sketch.add_constraint("angle", [
		{"entity": xid, "role": "self"},
		{"entity": line_id, "role": "self"}], ang, true)
	_record_dimension("angle", [xid, line_id], ang, cid, callout)


func _line_has_angle_dim(line_id: String) -> bool:
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "angle":
			continue
		for id in dim.get("ids", []):
			if str(id) == line_id:
				return true
	return false


## Closed quad: coincident corners, parallel opposite sides, perpendicular
## neighbours. Axis-aligned rects also get H/V. Rotated centre-rects must not.
func _constrain_quad(l1: String, l2: String, l3: String, l4: String, axis_aligned: bool) -> void:
	if "" in [l1, l2, l3, l4]:
		return
	var ids: Array[String] = [l1, l2, l3, l4]
	_weld_loop(ids)
	for i in 4:
		sketch.add_constraint("coincident", [
			{"entity": ids[i], "role": "end"},
			{"entity": ids[(i + 1) % 4], "role": "start"}], 0.0)
	sketch.add_constraint("parallel", [
		{"entity": l1, "role": "self"}, {"entity": l3, "role": "self"}], 0.0)
	sketch.add_constraint("parallel", [
		{"entity": l2, "role": "self"}, {"entity": l4, "role": "self"}], 0.0)
	sketch.add_constraint("perpendicular", [
		{"entity": l1, "role": "self"}, {"entity": l2, "role": "self"}], 0.0)
	if axis_aligned:
		for lid in [l1, l3]:
			sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
		for lid in [l2, l4]:
			sketch.add_constraint("vertical", [{"entity": lid, "role": "self"}], 0.0)
	run_solve()
	_weld_loop(ids)


## Copy each edge's end onto the next edge's start so contour_faces (1e-6)
## sees one wire even when a later solve only partially converges.
func _weld_loop(ids: Array) -> void:
	if sketch == null or ids.size() < 2:
		return
	for i in ids.size():
		var a_id := str(ids[i])
		var b_id := str(ids[(i + 1) % ids.size()])
		var ia: Dictionary = sketch.entity_info(a_id)
		var ib: Dictionary = sketch.entity_info(b_id)
		if ia.get("type", "") != "line" or ib.get("type", "") != "line":
			continue
		sketch.set_entity_geometry(b_id, {"start": ia["end"], "end": ib["end"]})


func _weld_slot(top: String, bot: String, cap_a: String, cap_b: String,
		a: Vector2, b: Vector2, r: float) -> void:
	var d := b - a
	if d.length() < 1e-9:
		return
	var n := Vector2(-d.y, d.x).normalized() * r
	sketch.set_entity_geometry(top, {"start": a + n, "end": b + n})
	sketch.set_entity_geometry(bot, {"start": a - n, "end": b - n})
	var out_b := d.normalized()
	var out_a := -out_b
	_set_arc_ends(cap_b, b, r, out_b.angle() - PI * 0.5, out_b.angle() + PI * 0.5)
	_set_arc_ends(cap_a, a, r, out_a.angle() - PI * 0.5, out_a.angle() + PI * 0.5)
	var ainfo: Dictionary = sketch.entity_info(cap_a)
	var binfo: Dictionary = sketch.entity_info(cap_b)
	if not ainfo.is_empty() and not binfo.is_empty():
		sketch.set_entity_geometry(top, {"start": ainfo["start"], "end": binfo["end"]})
		sketch.set_entity_geometry(bot, {"start": ainfo["end"], "end": binfo["start"]})


func _set_arc_ends(id: String, c: Vector2, r: float, sa: float, ea: float) -> void:
	sketch.set_entity_geometry(id, {
		"center": c,
		"radius": r,
		"start_angle": sa,
		"end_angle": ea,
		"start": c + Vector2.from_angle(sa) * r,
		"end": c + Vector2.from_angle(ea) * r,
	})


## PlaneGCS stores angles in radians. The label and the edit popup speak degrees,
## so a typed 45 (larger than π) is degrees. Smaller numbers stay radians.
func _dimension_value_for_solver(dim: Dictionary, value: float) -> float:
	if str(dim.get("type", "")) == "angle" and absf(value) > PI:
		return deg_to_rad(value)
	return value


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
			var value := _dimension_value_for_solver(dim, float(expr))
			if not sketch.set_constraint_value(cid, value):
				return ""
			dim["value"] = value
			dim.erase("expr")
	else:
		var value := _dimension_value_for_solver(dim, float(value_or_expr))
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
	_undo_note("Dimension")
	# The centre pick cross is not a sketch point. Drop it when the value lands.
	_snap_marker = null
	_sync_pick_marker()
	# A width edit must not drop the centre-rect angle to a reference dim.
	_keep_angle_dims_driving()
	var res := run_solve()
	if str(dim.get("type", "")) == "distance":
		_restore_driving_angles()
	# The sketch is already a feature (reopened, or saved by a previous extrude).
	# Push it back so the cut/extrude downstream rebuilds.
	if editing_fid != "" and view != null and view.doc != null:
		if not view.doc.graph_update_sketch(editing_fid, sketch):
			if _reload_editing_sketch():
				_redraw()
				_redraw_selected()
				_rebuild_dimension_labels()
				return res["status"]
			_end_sketch_session()
			_emit_discard_status()
			return ""
	_redraw()
	_redraw_selected()
	_rebuild_dimension_labels()
	return res["status"]


## Angle-to-horizontal on a centre-3-pt rectangle stays driving when a
## distance (jaw width) is the value that just changed.
func _keep_angle_dims_driving() -> void:
	if sketch == null:
		return
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "angle":
			continue
		var acid := str(dim.get("cid", ""))
		if acid == "":
			continue
		sketch.set_constraint_driving(acid, true)


func _restore_driving_angles() -> void:
	_keep_angle_dims_driving()
	if sketch == null:
		return
	var need := false
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "angle":
			continue
		var acid := str(dim.get("cid", ""))
		if acid == "":
			continue
		var ids: Array = dim.get("ids", [])
		if ids.size() < 2:
			continue
		var want := float(dim.get("value", 0.0))
		var got := _lines_signed_angle(str(ids[0]), str(ids[1]))
		var err := absf(got - want)
		err = minf(err, absf(err - TAU))
		if err > deg_to_rad(0.05):
			sketch.set_constraint_value(acid, want)
			need = true
	if need:
		run_solve()


## Driving dims live in the kernel once the sketch is a feature. Reopening a
## session (begin / begin_edit) rebuilds the label list from those constraints.
func _restore_dimensions_from_sketch() -> void:
	if sketch == null:
		return
	var prior: Array = dimensions.duplicate(true)
	dimensions = _merge_dimension_records(_dimension_records_from_sketch(), prior)
	_rebuild_dimension_labels()


## One label record per dimensional constraint, deduped by
## (type, sorted ids, value rounded to 1e-4) then by display text.
func _dimension_records_from_sketch() -> Array:
	var out: Array = []
	if sketch == null:
		return out
	var seen_fact := {}
	var seen_text := {}
	for cid in sketch.constraint_ids():
		var rec := _dimension_record_from_cid(str(cid))
		if rec.is_empty():
			continue
		var key := _dimension_fact_key(rec)
		if seen_fact.has(key):
			continue
		var text := _dimension_label_text(rec)
		if text != "" and seen_text.has(text):
			continue
		seen_fact[key] = true
		if text != "":
			seen_text[text] = true
		out.append(rec)
	return out


func _dimension_record_from_cid(cid: String) -> Dictionary:
	if sketch == null or cid == "":
		return {}
	var info: Dictionary = sketch.constraint_info(cid)
	var t := str(info.get("type", ""))
	if t != "distance" and t != "radius" and t != "diameter" and t != "angle":
		return {}
	var refs: Array = info.get("refs", [])
	var ids: Array = []
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var eid := str(ref.get("entity", ""))
		if eid != "" and eid not in ids:
			ids.append(eid)
	if ids.is_empty():
		return {}
	# Construction projected-circle anchors are not user dimensions.
	if (t == "radius" or t == "diameter") and sketch.is_construction(str(ids[0])):
		return {}
	return {
		"type": t,
		"ids": ids,
		"value": float(info.get("value", 0.0)),
		"cid": cid,
	}


func _dimension_fact_key(dim: Dictionary) -> String:
	var ids: Array = []
	for id in dim.get("ids", []):
		ids.append(str(id))
	ids.sort()
	return "%s|%s|%.4f" % [str(dim.get("type", "")), ",".join(ids),
			snappedf(float(dim.get("value", 0.0)), 0.0001)]


## Keep Smart Dim / Jaw / Trim fields (label_text, cid, drag override) when
## the same constraint is rebuilt. `kept` wins by cid, then by fact key.
func _merge_dimension_records(built: Array, kept: Array) -> Array:
	var by_cid := {}
	var by_key := {}
	for dim in kept:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var cid := str(dim.get("cid", ""))
		if cid != "":
			by_cid[cid] = dim
		by_key[_dimension_fact_key(dim)] = dim
	var out: Array = []
	var used := {}
	for rec in built:
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var cid := str(rec.get("cid", ""))
		var keep: Variant = null
		if cid != "" and by_cid.has(cid):
			keep = by_cid[cid]
		elif by_key.has(_dimension_fact_key(rec)):
			keep = by_key[_dimension_fact_key(rec)]
		if keep != null:
			var merged: Dictionary = (keep as Dictionary).duplicate(true)
			merged["type"] = rec["type"]
			merged["ids"] = rec["ids"]
			merged["value"] = rec["value"]
			merged["cid"] = cid
			out.append(merged)
			if cid != "":
				used[cid] = true
		else:
			out.append(rec)
			if cid != "":
				used[cid] = true
	return out


## Re-apply the live label list after Save's exit / begin_edit cycle.
func reapply_dimension_records(kept: Array) -> void:
	if sketch == null:
		return
	dimensions = _merge_dimension_records(_dimension_records_from_sketch(), kept)
	_rebuild_dimension_labels()
	_label_restack_hold = 0


func _sync_missing_radius_records() -> void:
	if sketch == null:
		return
	# Label every dimensional constraint the kernel already has. Do not add
	# new radius constraints here — that makes Shaft Lines / infer conflict.
	dimensions = _merge_dimension_records(_dimension_records_from_sketch(), dimensions)


## Double-click or right-click ends a line chain / commits a spline.
func end_chain() -> void:
	if tool == Tool.SPLINE and _spline_pts.size() >= 2:
		_commit_spline()
	elif _auto_close and (tool == Tool.LINE or tool == Tool.CENTERLINE):
		# Explicit end: close open polyline even when ends are far apart.
		_try_close_open_chain(0.5, true)
	_tool_points.clear()
	_length_override = -1.0
	_update_preview()


func set_auto_close(on: bool) -> void:
	_auto_close = on


func has_open_chain() -> bool:
	return (tool == Tool.LINE or tool == Tool.CENTERLINE) and _tool_points.size() >= 1


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
	# One point down: the rubber-band is the across-flats size, and the flats
	# stay horizontal no matter where the pointer sits.
	if tool == Tool.POLYGON and tool_variant == "across_flats" and _tool_points.size() == 1:
		var af := _tool_points[0].distance_to(effective_hover())
		if af >= 0.05:
			status.emit("Polygon AF %.4f — flats horizontal — click to place (or type the size)" % af)


## Power-trim drag: trim every entity the cursor crosses.
func begin_trim_drag(pos2: Vector2) -> void:
	_free_trim_trail()
	_trim_dragging = true
	_trim_jaw_done_in_drag = false
	_trim_drag_ids.clear()
	_trim_trail_pts.append(pos2)
	_rebuild_trim_trail()
	trim_at(pos2)
	var id := _nearest_entity_at(pos2)
	if id != "":
		_trim_drag_ids.append(id)


func update_trim_drag(pos2: Vector2) -> void:
	if _trim_dragging:
		_trim_trail_pts.append(pos2)
		_rebuild_trim_trail()
	if not _trim_dragging or _trim_jaw_done_in_drag:
		return
	var id := _nearest_entity_at(pos2)
	if id != "" and id not in _trim_drag_ids:
		if trim_at(pos2):
			_trim_drag_ids.append(id)
	_trim_hover_id = id
	_update_preview()


func end_trim_drag() -> void:
	_trim_dragging = false
	_trim_jaw_done_in_drag = false
	_trim_drag_ids.clear()
	_trim_hover_id = ""
	_free_trim_trail()
	if _preview_material != null:
		_preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
	_update_preview()


func _rebuild_trim_trail() -> void:
	var node := _trim_trail_node()
	node.visible = true
	if _trim_trail_pts.size() < 2:
		node.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(_trim_trail_pts.size() - 1):
		im.surface_add_vertex(_to3(_trim_trail_pts[i]))
		im.surface_add_vertex(_to3(_trim_trail_pts[i + 1]))
	im.surface_end()
	node.mesh = im


func _trim_trail_node() -> MeshInstance3D:
	if _trim_trail != null and is_instance_valid(_trim_trail):
		return _trim_trail
	var node := MeshInstance3D.new()
	node.name = "TrimDragTrail"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.25, 0.2, 0.35)
	mat.no_depth_test = true
	node.material_override = mat
	add_child(node)
	_trim_trail = node
	return node


func _free_trim_trail() -> void:
	_trim_trail_pts = PackedVector2Array()
	if _trim_trail != null and is_instance_valid(_trim_trail):
		_trim_trail.visible = false
		_trim_trail.mesh = null
		_trim_trail.queue_free()
		_trim_trail = null


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
	if n > 0:
		_undo_note("Delete")
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
	if not ids.is_empty():
		_undo_note("Paste")
	_set_selected(ids)
	run_solve()
	_redraw()
	return out


func _to3(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


func _clear_meshes() -> void:
	_draw_node.mesh = null
	_preview_node.mesh = null
	_snap_marker = null
	_sync_pick_marker()
	_selected_node.mesh = null
	if _contour_node != null:
		_contour_node.mesh = null
	if _contour_tag != null:
		_contour_tag.visible = false
		_contour_tag.text = ""
	_contour_fill_alphas = []
	_contour_outline_count = 0
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
	var type := str(dim.get("type", ""))
	var ids: Array = dim.get("ids", [])
	# Angle and diameter must win over measured_value: two lines report the
	# endpoint gap, and a circle reports radius, neither of which is the dim.
	if type == "angle" and ids.size() >= 2 and sketch != null:
		return rad_to_deg(_lines_signed_angle(str(ids[0]), str(ids[1])))
	if type == "diameter" and not ids.is_empty() and sketch != null:
		var dinfo: Dictionary = sketch.entity_info(str(ids[0]))
		if str(dinfo.get("type", "")) in ["circle", "arc"]:
			return float(dinfo.get("radius", 0.0)) * 2.0
	var measured := measured_value(ids)
	if measured > 1e-12:
		return measured
	if type == "angle":
		return rad_to_deg(float(dim.get("value", 0.0)))
	return float(dim.get("value", 0.0))


## Another arc of the same radius, far enough to be the other slot cap.
func _slot_sibling_center(info: Dictionary) -> Variant:
	if sketch == null or str(info.get("type", "")) != "arc":
		return null
	var c: Vector2 = info["center"]
	var r := float(info.get("radius", 0.0))
	if r < 1e-6:
		return null
	for id in sketch.entity_ids():
		var other: Dictionary = sketch.entity_info(id)
		if str(other.get("type", "")) != "arc":
			continue
		var oc: Vector2 = other["center"]
		if oc.distance_to(c) <= 1e-3:
			continue
		if absf(float(other.get("radius", 0.0)) - r) > 1e-3:
			continue
		if oc.distance_to(c) > r * 2.0:
			return oc
	return null


## Slot-cap radius sits beside the stadium, 4 mm outside the body.
func _slot_cap_radius_pos(info: Dictionary) -> Variant:
	var sib: Variant = _slot_sibling_center(info)
	if sib == null:
		return null
	var c: Vector2 = info["center"]
	var axis: Vector2 = (sib as Vector2) - c
	if axis.length_squared() < 1e-12:
		return null
	var perp := Vector2(-axis.y, axis.x).normalized()
	var r := float(info.get("radius", 0.0))
	return c + perp * (r + DIM_LABEL_OFFSET)


## Radius callout on a slot cap. The overlap resolver must not walk it.
func _is_slot_cap_radius(dim: Dictionary) -> bool:
	if sketch == null or str(dim.get("type", "")) != "radius":
		return false
	var ids: Array = dim.get("ids", [])
	if ids.size() != 1:
		return false
	return _slot_sibling_center(sketch.entity_info(str(ids[0]))) != null


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
		var r: float = float(info.get("radius", 0.0))
		var reach := r + DIM_LABEL_OFFSET
		# Slot cap radius sits beside the stadium, not off the outer end of
		# cap A. Still outside the body and within 1.5r+6 of the slot AABB.
		if str(info.get("type", "")) == "arc":
			var slot_pos: Variant = _slot_cap_radius_pos(info)
			if slot_pos != null:
				return slot_pos
		# Keep-side jaw arc: sit on the remaining metal, away from the 20 / 45°
		# cluster in the opening. Full circles sit below the centre so a head
		# Ø45 label is not in the 45° jaw click fan.
		if str(info.get("type", "")) == "arc":
			var sa := float(info.get("start_angle", 0.0))
			var ea := float(info.get("end_angle", sa + PI))
			if ea < sa:
				ea += TAU
			return c + Vector2.from_angle((sa + ea) * 0.5) * reach
		return c + Vector2(0.0, -reach)
	if type == "angle" and ids.size() >= 2:
		var ia: Dictionary = sketch.entity_info(str(ids[0]))
		var ib: Dictionary = sketch.entity_info(str(ids[1]))
		if str(ia.get("type", "")) == "line" and str(ib.get("type", "")) == "line":
			var hit = _line_line_intersect(ia["start"], ia["end"] - ia["start"], ib["start"], ib["end"] - ib["start"])
			if hit != null:
				var da: Vector2 = (ia["end"] - ia["start"]).normalized()
				var db: Vector2 = (ib["end"] - ib["start"]).normalized()
				var bis := da + db
				if bis.length_squared() < 1e-8:
					bis = Vector2(-da.y, da.x)
				return (hit as Vector2) + bis.normalized() * (DIM_LABEL_OFFSET * 2.0)
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


func _dimension_label_text(dim: Dictionary) -> String:
	var shown := snappedf(_dimension_display_value(dim), 0.0001)
	var text := _format_dimension(shown)
	if str(dim.get("type", "")) == "diameter":
		text = "Ø" + text
	if str(dim.get("type", "")) == "angle":
		text = text + "°"
	return text


## Screen px per Label3D font px for a fixed_size label seen by `cam`.
func _label_px_scale(cam: Camera3D) -> float:
	var h := cam.get_viewport().get_visible_rect().size.y
	var k := DIM_LABEL_PIXEL * h * 0.5
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		k /= tan(deg_to_rad(cam.fov) * 0.5)
	return k


func _dimension_label_size_px(text: String) -> Vector2:
	var font: Font = ThemeDB.fallback_font
	return Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, DIM_LABEL_FONT).x,
			font.get_height(DIM_LABEL_FONT))


## Label3D.offset in font pixels. fixed_size turns one font pixel into `k`
## screen pixels (see `_label_px_scale`); +Y is camera-up, so screen Y flips.
func _dimension_label_offset_px(dim: Dictionary) -> Vector2:
	var stack := float(dim.get("label_stack", 0))
	var clamp_off := Vector2.ZERO
	var raw: Variant = dim.get("label_clamp", Vector2.ZERO)
	if raw is Vector2:
		clamp_off = raw
	return Vector2(clamp_off.x, stack * DIM_LABEL_STACK_PX + clamp_off.y)


## World position of a dimension label, matching the Label3D we draw.
func _dimension_label_world(pos: Vector2) -> Vector3:
	return to_global(_to3(pos) + plane_normal() * 0.2)


## Screen rectangle of the drawn text. `anchor` is the projected label origin.
func _dimension_label_rect(dim: Dictionary, anchor: Vector2, k: float) -> Rect2:
	var text := str(dim.get("label_text", ""))
	if text == "":
		text = _dimension_label_text(dim)
	var size := _dimension_label_size_px(text) * k
	var off := _dimension_label_offset_px(dim)
	# Same shift Label3D applies: offset font-px × k, Y up in the label.
	var centre := anchor + Vector2(off.x * k, -off.y * k)
	return Rect2(centre - size * 0.5, size)


func _rect_gap(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func _rebuild_dimension_labels() -> void:
	_clear_dimension_labels()
	if _dimension_labels == null or sketch == null:
		return
	_sync_missing_radius_records()
	_dimension_labels.visible = dimensions_visible
	var taken: Array[Vector2] = []
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var pos2: Variant = _dimension_label_pos2(dim)
		if pos2 == null:
			continue
		var pos := pos2 as Vector2
		# Save re-entry: keep the live stack when the geometry did not move.
		# Recomputing from mm-proximity at 150 px parks 45° on 20 (N1b).
		var prev_pos: Variant = dim.get("label_pos", null)
		var stack := 0
		var reuse := prev_pos != null and typeof(prev_pos) == TYPE_VECTOR2 \
				and (prev_pos as Vector2).distance_to(pos) < 0.5 \
				and dim.has("label_stack")
		if reuse:
			stack = int(dim["label_stack"])
		else:
			for t in taken:
				if t.distance_to(pos) < DIM_LABEL_STACK_MM:
					stack += 1
		taken.append(pos)
		var text := _dimension_label_text(dim)
		if str(dim.get("type", "")) == "angle":
			# 45.0001° from a 45° degree constraint is the same label.
			var shown := snappedf(_dimension_display_value(dim), 0.01)
			text = _format_dimension(shown) + "°"
		dim["label_pos"] = pos
		dim["label_stack"] = stack
		dim["label_text"] = text
		dimensions[i] = dim
	_rebuild_constraint_glyphs()
	_resolve_label_overlaps()
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if dim.get("label_pos", null) == null:
			continue
		var pos: Vector2 = dim["label_pos"]
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = DIM_LABEL_PIXEL
		label.font_size = DIM_LABEL_FONT
		label.outline_size = 4
		label.no_depth_test = true
		label.render_priority = 2
		label.outline_render_priority = 1
		label.offset = _dimension_label_offset_px(dim)
		label.text = str(dim.get("label_text", ""))
		label.position = _to3(pos) + plane_normal() * 0.2
		_dimension_labels.add_child(label)


## True for a radius/diameter on a full circle (not a jaw arc).
func _full_circle_dimension(dim: Dictionary) -> bool:
	if sketch == null:
		return false
	var ids: Array = dim.get("ids", [])
	if ids.size() != 1:
		return false
	if str(sketch.entity_info(str(ids[0])).get("type", "")) != "circle":
		return false
	var t := str(dim.get("type", ""))
	return t == "radius" or t == "diameter"


## Jaw width and the 45° long-side angle. These sit on the opening, so a
## millimetre stack walks them to the top of the view (sx-036 A8).
func _is_jaw_callout(dim: Dictionary) -> bool:
	var tag := str(dim.get("callout", ""))
	if tag == "jaw_width" or tag == "jaw_angle":
		return true
	if sketch == null:
		return false
	var t := str(dim.get("type", ""))
	var ids: Array = dim.get("ids", [])
	if t == "angle":
		return _is_jaw_angle_ids(ids)
	if t == "distance":
		return _is_jaw_width_ids(ids)
	return false


func _is_jaw_angle_ids(ids: Array) -> bool:
	if sketch == null or ids.size() < 2:
		return false
	var profile := ""
	var datum := ""
	for id in ids:
		var info: Dictionary = sketch.entity_info(str(id))
		if str(info.get("type", "")) != "line":
			return false
		if sketch.is_construction(str(id)):
			datum = str(id)
		else:
			profile = str(id)
	if profile == "" or datum == "":
		return false
	var dinfo: Dictionary = sketch.entity_info(datum)
	var d: Vector2 = dinfo["end"] - dinfo["start"]
	# The jaw datum is the construction +X through the centre.
	return d.length_squared() > 1e-8 and absf(d.y) <= maxf(0.05 * absf(d.x), 1e-3)


func _is_jaw_width_ids(ids: Array) -> bool:
	if sketch == null or ids.size() != 1:
		return false
	var lid := str(ids[0])
	var info: Dictionary = sketch.entity_info(lid)
	if str(info.get("type", "")) != "line" or sketch.is_construction(lid):
		return false
	var w: Vector2 = info["end"] - info["start"]
	if w.length_squared() < 1e-8:
		return false
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if not _is_jaw_angle_ids(dim.get("ids", [])):
			continue
		var profile := ""
		for id in dim.get("ids", []):
			if not sketch.is_construction(str(id)):
				profile = str(id)
				break
		if profile == "":
			continue
		var pinfo: Dictionary = sketch.entity_info(profile)
		if str(pinfo.get("type", "")) != "line":
			continue
		var p: Vector2 = pinfo["end"] - pinfo["start"]
		if p.length_squared() < 1e-8:
			continue
		var ang := absf(rad_to_deg(w.angle_to(p)))
		ang = minf(ang, absf(180.0 - ang))
		if absf(ang - 90.0) > 8.0:
			continue
		if _segments_share_endpoint(info, pinfo):
			return true
	return false


func _segments_share_endpoint(a: Dictionary, b: Dictionary) -> bool:
	var pts: Array[Vector2] = [a["start"], a["end"]]
	for q in [b["start"], b["end"]]:
		for p in pts:
			if p.distance_to(q) <= 0.5:
				return true
	return false


## Select click on a circle's own radius label that has been stacked onto the rim.
func _radius_label_on_own_rim(index: int, pos2: Vector2) -> bool:
	if tool != Tool.SELECT or index < 0 or index >= dimensions.size():
		return false
	var dim: Dictionary = dimensions[index]
	if not _full_circle_dimension(dim):
		return false
	var ids: Array = dim.get("ids", [])
	if ids.is_empty():
		return false
	return _nearest_entity_at(pos2) == str(ids[0])


## Nudge labels (never glyphs) along the label_stack axis until no label
## rect intersects another label or a constraint glyph. Deterministic by
## dimension index so a rebuild yields the same layout.
func _resolve_label_overlaps() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var k := _label_px_scale(cam)
	var glyphs: Array[Rect2] = []
	for g in constraint_glyph_screen_rects():
		if typeof(g) == TYPE_DICTIONARY:
			glyphs.append(g["rect"] as Rect2)
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
			continue
		# Full-circle radius text is anchored just below the rim. Stacking it
		# upward (#164, 28 px per step) walks the Ø45 label onto the top rim
		# that Shaft Lines clicks. Leave it on the anchor.
		if _full_circle_dimension(dim) or _is_slot_cap_radius(dim):
			dim["label_stack"] = 0
			dimensions[i] = dim
			continue
		# A previous frame's clamp must not shift the overlap test.
		dim["label_clamp"] = Vector2.ZERO
		# Jaw callouts ignore the millimetre seed. That seed stacks every
		# anchor within 14 mm, which at a 140 px head is enough to park 20
		# and 45° under the menu bar while the hit rect stays on the segment.
		var jaw := _is_jaw_callout(dim)
		var stack := 0 if jaw else int(dim.get("label_stack", 0))
		var guard := 0
		while guard < 16:
			if jaw and stack > JAW_LABEL_MAX_STACK:
				stack = JAW_LABEL_MAX_STACK
				break
			dim["label_stack"] = stack
			dimensions[i] = dim
			if not _label_rect_hits(dim, i, cam, k, glyphs):
				break
			# Past the cap, a sideways nudge keeps the callout on the jaw.
			# Another upward step is what parked 45° under the menu.
			if jaw and stack >= JAW_LABEL_MAX_STACK:
				break
			stack += 1
			guard += 1
		dim["label_stack"] = stack
		dimensions[i] = dim
	_clamp_dimension_labels_into_view(cam, k)
	_separate_capped_jaw_labels(cam, k, glyphs)
	_clamp_dimension_labels_into_view(cam, k)


func _label_rect_hits(dim: Dictionary, index: int, cam: Camera3D, k: float,
		glyphs: Array[Rect2]) -> bool:
	var rect := _projected_label_rect(dim, cam, k)
	for gr in glyphs:
		if rect.intersects(gr.grow(GLYPH_LABEL_GAP_PX)):
			return true
	for j in range(dimensions.size()):
		if j == index:
			continue
		var other: Dictionary = dimensions[j]
		if typeof(other) != TYPE_DICTIONARY or other.get("label_pos", null) == null:
			continue
		if rect.intersects(_projected_label_rect(other, cam, k)):
			return true
	return false


## Jaw callouts that still overlap at the stack cap slide sideways, in
## Label3D offset pixels, so the drawn glyph and the hit rect move together.
func _separate_capped_jaw_labels(cam: Camera3D, k: float, glyphs: Array[Rect2]) -> void:
	if k < 1e-6:
		return
	var guard := 0
	while guard < 8:
		guard += 1
		var moved := false
		for i in range(dimensions.size()):
			var dim: Dictionary = dimensions[i]
			if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
				continue
			if not _is_jaw_callout(dim):
				continue
			if not _label_rect_hits(dim, i, cam, k, glyphs):
				continue
			var rect := _projected_label_rect(dim, cam, k)
			var push := _jaw_side_push_px(rect, i, cam, k, glyphs)
			if absf(push) < 0.5:
				continue
			var clamp_off := Vector2.ZERO
			var raw: Variant = dim.get("label_clamp", Vector2.ZERO)
			if raw is Vector2:
				clamp_off = raw
			clamp_off.x += push / k
			dim["label_clamp"] = clamp_off
			dimensions[i] = dim
			moved = true
		if not moved:
			break


func _jaw_side_push_px(rect: Rect2, index: int, cam: Camera3D, k: float,
		glyphs: Array[Rect2]) -> float:
	var gap := 4.0
	var push_right := 0.0
	var push_left := 0.0
	var obstacles: Array[Rect2] = []
	for gr in glyphs:
		obstacles.append(gr)
	# Only earlier labels. The later callout slides on its own pass so the
	# pair does not chase each other across the jaw.
	for j in range(index):
		var other: Dictionary = dimensions[j]
		if typeof(other) != TYPE_DICTIONARY or other.get("label_pos", null) == null:
			continue
		obstacles.append(_projected_label_rect(other, cam, k))
	for ob in obstacles:
		if not rect.intersects(ob):
			continue
		push_right = maxf(push_right, ob.end.x + gap - rect.position.x)
		push_left = minf(push_left, ob.position.x - gap - rect.end.x)
	if push_right <= 0.0 and push_left >= 0.0:
		return 0.0
	var safe := _label_safe_screen_rect()
	if push_right > 0.0 and rect.end.x + push_right <= safe.end.x:
		return push_right
	if push_left < 0.0 and rect.position.x + push_left >= safe.position.x:
		return push_left
	if push_right > 0.0:
		return push_right
	return push_left


func _projected_label_anchor(dim: Dictionary, cam: Camera3D) -> Vector2:
	var lp: Vector2 = dim["label_pos"]
	return cam.unproject_position(_dimension_label_world(lp))


## Pull any label whose text would clip the menu / window edge back inside.
## The nudge is stored in Label3D offset pixels so draw and pick share it.
func _label_safe_screen_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 800)
	var top := ChromeDock.top_inset + 2.0
	var bottom := ChromeDock.bottom_inset + 2.0
	var margin := 4.0
	return Rect2(margin, top, maxf(vp.x - margin * 2.0, 32.0), maxf(vp.y - top - bottom, 32.0))


func _clamp_dimension_labels_into_view(cam: Camera3D, k: float) -> void:
	if k < 1e-6:
		return
	var safe := _label_safe_screen_rect()
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
			continue
		var rect := _projected_label_rect(dim, cam, k)
		var delta := Vector2.ZERO
		if rect.size.y <= safe.size.y:
			if rect.position.y < safe.position.y:
				delta.y += safe.position.y - rect.position.y
			elif rect.end.y > safe.end.y:
				delta.y -= rect.end.y - safe.end.y
		if rect.size.x <= safe.size.x:
			if rect.position.x < safe.position.x:
				delta.x += safe.position.x - rect.position.x
			elif rect.end.x > safe.end.x:
				delta.x -= rect.end.x - safe.end.x
		if delta != Vector2.ZERO:
			dim["label_clamp"] = Vector2(delta.x / k, -delta.y / k)
			dimensions[i] = dim


func _projected_label_rect(dim: Dictionary, cam: Camera3D, k: float) -> Rect2:
	return _dimension_label_rect(dim, _projected_label_anchor(dim, cam), k)


## Viewport-pixel rectangles of every drawn dimension label.
func dimension_label_screen_rects() -> Array:
	var out: Array = []
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return out
	var k := _label_px_scale(cam)
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var lp: Variant = dim.get("label_pos", null)
		if lp == null:
			lp = _dimension_label_pos2(dim)
		if lp == null:
			continue
		var work: Dictionary = dim.duplicate(true)
		work["label_pos"] = lp
		var text := str(work.get("label_text", ""))
		if text == "":
			text = _dimension_label_text(work)
			work["label_text"] = text
		out.append({
			"text": text,
			"rect": _projected_label_rect(work, cam, k),
			"index": i,
		})
	return out


func _glyph_symbol_size_px(type: String, k: float) -> Vector2:
	var font: Font = ThemeDB.fallback_font
	var symbol := str(GLYPH_SYMBOLS.get(type, type))
	return Vector2(
			font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x,
			font.get_height(22)) * k


func _glyph_screen_rect(pos: Vector2, type: String, cam: Camera3D, k: float) -> Rect2:
	var size := _glyph_symbol_size_px(type, k)
	var centre := cam.unproject_position(to_global(to_model(pos)))
	return Rect2(centre - size * 0.5, size)


## Inverse of the glyph projection: screen pixel → sketch plane.
func _sketch_at_screen(cam: Camera3D, screen: Vector2) -> Variant:
	var inv := global_transform.affine_inverse()
	var origin: Vector3 = inv * cam.project_ray_origin(screen)
	var direction: Vector3 = inv.basis * cam.project_ray_normal(screen)
	return ray_to_sketch(origin, direction)


func _label_rects_for_glyphs(cam: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var k := _label_px_scale(cam)
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
			continue
		out.append(_projected_label_rect(dim, cam, k))
	return out


func _glyph_overlap_fraction(a: Rect2, b: Rect2) -> float:
	if not a.intersects(b):
		return 0.0
	var inter := a.intersection(b)
	var area := maxf(inter.size.x, 0.0) * maxf(inter.size.y, 0.0)
	var smaller := minf(a.size.x * a.size.y, b.size.x * b.size.y)
	if smaller <= 1e-6:
		return 0.0
	return area / smaller


## 0 when the badge is clear of other glyphs, labels, and sketch geometry.
func _glyph_block_score(rect: Rect2, centre: Vector2, placed: Array[Rect2],
		labels: Array[Rect2], cam: Camera3D) -> float:
	var score := 0.0
	for prev in placed:
		var frac := _glyph_overlap_fraction(rect, prev)
		# A small term so the search prefers the least overlap. Above 20% it
		# outweighs sitting on the curve, which the 40 px cap cannot spread.
		score += frac * 8.0
		if frac > 0.20:
			score += 50.0 + (frac - 0.20) * 100.0
	for lr in labels:
		var lg := lr.grow(GLYPH_LABEL_GAP_PX)
		if rect.intersects(lg):
			var inter := rect.intersection(lg)
			score += 80.0 + maxf(inter.size.x, 0.0) * maxf(inter.size.y, 0.0)
	# No on-curve penalty. With the offset capped at 40 px that penalty put
	# every badge on the same ring and they overlapped. Labels and other
	# badges still push a glyph off its vertex.
	if _sketch_at_screen(cam, centre) == null:
		score += 40.0
	return score


## Screen centre of a glyph pushed off the pile, the labels, and the curves.
func _separate_glyph_screen(natural: Vector2, size: Vector2, placed: Array[Rect2],
		labels: Array[Rect2], cam: Camera3D) -> Vector2:
	var step := maxf(size.x, size.y) + 2.0
	var best := natural
	var best_score := INF
	var max_ring := maxi(1, floori(GLYPH_MAX_OFFSET_PX / step))
	var radii: Array[float] = [0.0]
	var fine := 4.0
	while fine <= GLYPH_MAX_OFFSET_PX + 0.01:
		radii.append(minf(fine, GLYPH_MAX_OFFSET_PX))
		fine += 4.0
	for ring in range(1, max_ring + 1):
		var capped := minf(step * float(ring), GLYPH_MAX_OFFSET_PX)
		if not radii.has(capped):
			radii.append(capped)
	for radius in radii:
		var count := 1 if radius < 1.0 else 24
		for i in range(count):
			var centre := natural
			if radius >= 1.0:
				var ang := TAU * float(i) / float(count)
				centre = natural + Vector2(cos(ang), sin(ang)) * radius
			var rect := Rect2(centre - size * 0.5, size)
			var score := _glyph_block_score(rect, centre, placed, labels, cam)
			if score < best_score:
				best_score = score
				best = centre
	var guard := 0
	while guard < 12:
		guard += 1
		var rect := Rect2(best - size * 0.5, size)
		var worst := 0.0
		var worst_prev := Rect2()
		for prev in placed:
			var frac := _glyph_overlap_fraction(rect, prev)
			if frac > worst:
				worst = frac
				worst_prev = prev
		if worst <= 0.12:
			break
		var away := best - worst_prev.get_center()
		if away.length_squared() < 1.0:
			away = Vector2(1.0, 0.0)
		var nudged := best + away.normalized() * 3.0
		if nudged.distance_to(natural) > GLYPH_MAX_OFFSET_PX:
			nudged = natural + (nudged - natural).normalized() * GLYPH_MAX_OFFSET_PX
		var nscore := _glyph_block_score(Rect2(nudged - size * 0.5, size), nudged, placed, labels, cam)
		if nscore <= best_score + 0.01:
			best = nudged
			best_score = nscore
		else:
			break
	return best


## Viewport-pixel rectangles of every drawn constraint glyph.
func constraint_glyph_screen_rects() -> Array:
	var out: Array = []
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return out
	var k := _label_px_scale(cam)
	for a in _glyph_anchors:
		var type := str(a.get("type", ""))
		if type == "" and sketch != null:
			type = str(sketch.constraint_info(str(a.get("cid", ""))).get("type", ""))
		out.append({
			"type": type,
			"rect": _glyph_screen_rect(a["pos"] as Vector2, type, cam, k),
		})
	return out


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
		"arc":
			if role == "start" and info.has("start"):
				return info["start"]
			if role == "end" and info.has("end"):
				return info["end"]
			return info["center"]
		"circle":
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
	match str(cinfo.get("type", "")):
		"tangent":
			var line_info: Dictionary = {}
			var circ_info: Dictionary = {}
			for ref in refs:
				if typeof(ref) != TYPE_DICTIONARY:
					continue
				var info: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
				var kind := str(info.get("type", ""))
				if kind == "line":
					line_info = info
				elif kind == "circle" or kind == "arc":
					circ_info = info
			if not line_info.is_empty() and not circ_info.is_empty():
				var contact: Variant = _tangent_contact(line_info, circ_info)
				if contact != null:
					return contact
		"point_on_line":
			return _ref_pos(refs[0])
		"parallel", "perpendicular", "equal":
			var p: Variant = _ref_pos(refs[0])
			if p == null:
				return null
			var nudged: Vector2 = p
			var einfo: Dictionary = sketch.entity_info(str(refs[0].get("entity", "")))
			if str(einfo.get("type", "")) == "line":
				var d: Vector2 = einfo["end"] - einfo["start"]
				if d.length_squared() > 1e-12:
					nudged += Vector2(-d.y, d.x).normalized() * 2.5
			return nudged
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


func _tangent_contact(line: Dictionary, circ: Dictionary) -> Variant:
	var a: Vector2 = line["start"]
	var ab: Vector2 = (line["end"] as Vector2) - a
	if ab.length_squared() < 1e-12:
		return null
	var c: Vector2 = circ["center"]
	var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t


func _constraint_refs_a_line(cinfo: Dictionary) -> bool:
	for ref in cinfo.get("refs", []):
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var einfo: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
		if str(einfo.get("type", "")) == "line":
			return true
	return false


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
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var k := _label_px_scale(cam) if cam != null else 1.0
	var label_rects: Array[Rect2] = _label_rects_for_glyphs(cam) if cam != null else []
	var placed: Array[Rect2] = []
	var taken: Array[Vector2] = []
	for cid in sketch.constraint_ids():
		var cinfo: Dictionary = sketch.constraint_info(cid)
		var type := str(cinfo.get("type", ""))
		if not GLYPH_SYMBOLS.has(type):
			continue
		# A centre-to-centre horizontal has no line to sit beside. Drawing it
		# would plant a badge between the circles (T14's stray mark).
		if (type == "horizontal" or type == "vertical") and not _constraint_refs_a_line(cinfo):
			continue
		var anchor: Variant = _constraint_anchor(cinfo)
		if anchor == null:
			continue
		var pos := anchor as Vector2
		var anchor_sketch := pos
		var offset_px := 0.0
		if cam != null:
			# De-stack in pixels. A 2.5 mm step is ~8 px at a 150 px head,
			# smaller than the badge, so the pile survives a millimetre nudge.
			var size := _glyph_symbol_size_px(type, k)
			var natural := cam.unproject_position(to_global(to_model(pos)))
			var centre := _separate_glyph_screen(natural, size, placed, label_rects, cam)
			offset_px = natural.distance_to(centre)
			placed.append(Rect2(centre - size * 0.5, size))
			var back: Variant = _sketch_at_screen(cam, centre)
			if back != null:
				pos = back
		else:
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
		_glyph_anchors.append({
			"cid": str(cid),
			"pos": pos,
			"type": type,
			"anchor": anchor_sketch,
			"offset_px": offset_px,
		})
	var lead := false
	for a in _glyph_anchors:
		if float(a.get("offset_px", 0.0)) >= GLYPH_LEADER_MIN_PX:
			lead = true
			break
	if lead:
		var leaders := MeshInstance3D.new()
		leaders.name = "GlyphLeaders"
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var col := COLOR_GLYPH
		col.a = 0.6
		for a in _glyph_anchors:
			if float(a.get("offset_px", 0.0)) < GLYPH_LEADER_MIN_PX:
				continue
			im.surface_set_color(col)
			im.surface_add_vertex(_to3(a["anchor"]))
			im.surface_add_vertex(_to3(a["pos"]))
		im.surface_end()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color.WHITE
		leaders.mesh = im
		leaders.material_override = mat
		_constraint_glyphs.add_child(leaders)


func glyph_debug() -> Array:
	var out: Array = []
	for a in _glyph_anchors:
		var off := float(a.get("offset_px", 0.0))
		var anchor: Vector2 = a.get("anchor", Vector2.ZERO)
		var pos: Vector2 = a.get("pos", Vector2.ZERO)
		out.append({
			"cid": str(a.get("cid", "")),
			"type": str(a.get("type", "")),
			"offset_px": off,
			"leader": off >= GLYPH_LEADER_MIN_PX,
			"anchor": anchor,
			"pos": pos,
		})
	return out


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
	_undo_note("Delete")
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


## Index of the dimension whose label text is under pos2 (-1 = none). The test is
## the label's screen rectangle plus DIM_LABEL_PAD_PX; the 22 px circle around
## the stored anchor and the 6 mm sketch-space radius stay as fallbacks.
## `rect_only` skips the halo so an armed Jaw/Trim click on nearby geometry
## is not stolen by a typed-circle radius label.
func dimension_hit(pos2: Vector2, rect_only: bool = false) -> int:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var screen := Vector2(INF, INF)
	var k := 0.0
	if cam != null:
		screen = cam.unproject_position(to_global(to_model(pos2)))
		k = _label_px_scale(cam)
	var rect_hit := -1
	var rect_gap := INF
	var rect_centre_d := INF
	var anchor_hit := -1
	var best_px := 22.0
	var mm_hit := -1
	var best_mm := 6.0
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		var lp: Variant = dim.get("label_pos", null)
		if lp == null:
			lp = _dimension_label_pos2(dim)
		if lp == null:
			continue
		var p: Vector2 = lp
		if cam != null:
			var sp := cam.unproject_position(_dimension_label_world(p))
			var rect := _dimension_label_rect(dim, sp, k)
			var gap := _rect_gap(rect, screen)
			var centre_d := screen.distance_to(rect.get_center())
			if gap <= DIM_LABEL_PAD_PX and (gap < rect_gap - 0.01
					or (absf(gap - rect_gap) <= 0.01 and centre_d < rect_centre_d)):
				rect_hit = i
				rect_gap = gap
				rect_centre_d = centre_d
			if not rect_only:
				var dpx := screen.distance_to(sp)
				if dpx < best_px:
					best_px = dpx
					anchor_hit = i
		if not rect_only:
			var dmm := pos2.distance_to(p)
			if dmm < best_mm:
				best_mm = dmm
				mm_hit = i
	if rect_hit >= 0:
		return rect_hit
	if rect_only:
		return -1
	if anchor_hit >= 0:
		return anchor_hit
	return mm_hit


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
	# A commit that ends the session has already dropped the strokes. A late
	# redraw must not put the construction overlay back on the solid.
	if not active:
		_clear_meshes()
		return
	if sketch == null:
		return
	_sync_contour_bar()
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
	_capture_undo_if_changed()


func _append_preview_seg(im: ImmediateMesh, a: Vector2, b: Vector2) -> void:
	im.surface_add_vertex(_to3(a))
	im.surface_add_vertex(_to3(b))


func _append_jaw_preview(im: ImmediateMesh, tip: Vector2) -> void:
	if _tool_points.is_empty():
		return
	var ctr: Vector2 = _tool_points[0]
	var along: Vector2
	var half_w: float
	if _tool_points.size() == 1:
		along = tip - ctr
		if along.length() <= 1e-6:
			return
		half_w = along.length() * JAW_PREVIEW_ASPECT
	else:
		along = _tool_points[1] - ctr
		if along.length() <= 1e-6:
			_append_preview_seg(im, ctr, tip)
			return
		var n0 := Vector2(-along.y, along.x).normalized()
		half_w = maxf(absf((tip - ctr).dot(n0)), JAW_PREVIEW_MIN_HALF_W_MM)
	var dir := along.normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var u := dir * along.length()
	var v := nrm * half_w
	var ra := ctr - u - v
	var rb := ctr + u - v
	var rc := ctr + u + v
	var rd := ctr - u + v
	_append_preview_seg(im, ra, rb)
	_append_preview_seg(im, rb, rc)
	_append_preview_seg(im, rc, rd)
	_append_preview_seg(im, rd, ra)


func _append_slot_preview(im: ImmediateMesh, a: Vector2, b: Vector2, r: float) -> void:
	var d := b - a
	if d.length() < 1e-6 or r < 1e-6:
		im.surface_add_vertex(_to3(a))
		im.surface_add_vertex(_to3(b))
		return
	var n := Vector2(-d.y, d.x).normalized() * r
	_append_entity_lines(im, {"type": "line", "start": a + n, "end": b + n})
	_append_entity_lines(im, {"type": "line", "start": a - n, "end": b - n})
	var out_b := d.normalized()
	var out_a := -out_b
	_append_entity_lines(im, {
		"type": "arc", "center": b, "radius": r,
		"start_angle": out_b.angle() - PI * 0.5,
		"end_angle": out_b.angle() + PI * 0.5,
	})
	_append_entity_lines(im, {
		"type": "arc", "center": a, "radius": r,
		"start_angle": out_a.angle() - PI * 0.5,
		"end_angle": out_a.angle() + PI * 0.5,
	})


## Pointer -> the across-flats "tip" `_polygon_ring_vertices` expects: its
## distance from the centre is the AF, so the circumscribed circle passes
## through the pointer. A typed length bypasses this (effective_hover()).
func _polygon_pointer_tip(c: Vector2, p: Vector2) -> Vector2:
	if tool_variant != "across_flats":
		return p
	return c + (p - c) * sqrt(3.0)


## Across-flats is always a flats-horizontal hex (start angle 0). The drag
## length is the across-flats size; the vertex variant keeps the pointer angle.
func _polygon_ring_vertices(c: Vector2, tip: Vector2) -> Array[Vector2]:
	var drag := c.distance_to(tip)
	var n := polygon_sides
	var radius := drag
	var start_angle := (tip - c).angle() if drag > 1e-9 else 0.0
	if tool_variant == "across_flats":
		n = 6
		radius = drag / sqrt(3.0)
		start_angle = 0.0
	var verts: Array[Vector2] = []
	if n < 3 or radius < 1e-9:
		return verts
	for i in range(n):
		var a := start_angle + TAU * float(i) / float(n)
		verts.append(c + Vector2(cos(a), sin(a)) * radius)
	return verts


## Live across-flats / vertex ring. Empty until the centre click is down.
func polygon_preview_vertices() -> Array[Vector2]:
	if tool != Tool.POLYGON or _tool_points.is_empty():
		return []
	return _polygon_ring_vertices(_tool_points[0], effective_hover())


func _update_preview() -> void:
	# Smart Dim's centre pick is a status sentence, not a drawn cross.
	if tool == Tool.SMART_DIM:
		_snap_marker = null
	var im := ImmediateMesh.new()
	var has := false
	var dragging := not _drag.is_empty()
	var trim_hover := tool == Tool.TRIM and _trim_hover_id != ""
	if _tool_points.size() > 0 or dragging or trim_hover or _spline_pts.size() > 0:
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
				if tool_variant == "center_three_point":
					_append_jaw_preview(im, tip)
				else:
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
				var verts := _polygon_ring_vertices(c, tip)
				var r := c.distance_to(verts[0]) if not verts.is_empty() else 0.0
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
				var n := verts.size()
				for i in range(n):
					im.surface_add_vertex(_to3(verts[i]))
					im.surface_add_vertex(_to3(verts[(i + 1) % n]))
			Tool.SLOT:
				_append_slot_preview(im, last, tip, slot_radius)
	if has:
		im.surface_end()
		if trim_hover:
			_preview_material.albedo_color = Color(1.0, 0.25, 0.2, 0.95)
		else:
			_preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
		_preview_node.mesh = im
	else:
		_preview_node.mesh = null
	_sync_pick_marker()


## Cross at the snap point. Smart Dim never shows it: a centre pick is not a
## sketch point, and the cross used to stay inside the first circle (T14).
func _sync_pick_marker() -> void:
	if _pick_marker == null:
		return
	var show := _snap_marker != null and tool != Tool.SMART_DIM
	if not show:
		_pick_marker.visible = false
		_pick_marker.mesh = null
		return
	var m: Vector2 = _snap_marker
	const MARK := 0.6
	var cross := ImmediateMesh.new()
	cross.surface_begin(Mesh.PRIMITIVE_LINES)
	cross.surface_add_vertex(_to3(m + Vector2(-MARK, 0)))
	cross.surface_add_vertex(_to3(m + Vector2(MARK, 0)))
	cross.surface_add_vertex(_to3(m + Vector2(0, -MARK)))
	cross.surface_add_vertex(_to3(m + Vector2(0, MARK)))
	cross.surface_end()
	_pick_marker.mesh = cross
	_pick_marker.visible = true


## True when the sketch's non-construction geometry forms one or more closed
## profiles (circles, closed chains, or open chains whose ends lie on a circle).
## Default chain tolerance matches contour_faces (1e-6). Callers that pass a
## looser tol (auto-close at 0.5 mm) keep that tolerance.
static func profile_is_closed(sk: SxSketch, tol: float = 1e-6) -> bool:
	if sk == null:
		return false
	var segs: Array = []  # {a: Vector2, b: Vector2}
	var circs: Array = []  # {c: Vector2, r: float}
	for id in sk.entity_ids():
		if sk.is_construction(id):
			continue
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"circle":
				circs.append({"c": info["center"], "r": float(info.get("radius", 0.0))})
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				if a.distance_to(b) > 1e-9:
					segs.append({"a": a, "b": b, "used": false})
			"arc":
				# Chain the stored endpoints. Rebuilding them from angles in
				# float32 misses the line corners by more than the wire tol.
				var pa: Vector2 = info["start"] if info.has("start") else info["center"]
				var pb: Vector2 = info["end"] if info.has("end") else info["center"]
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
	if segs.is_empty():
		return not circs.is_empty()
	# Ends of an open chain may lie on a circle (kernel planar-split, 1e-4).
	var on_tol := maxf(tol, 1e-4)
	# Greedy-chain every unused segment. A chain is closed, or both ends sit
	# on some circle (tangent lines between the wrench bosses).
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
		if cursor.distance_to(loop_start) <= tol:
			continue
		# Ends on a circle close the chain only when that circle is a
		# two-hit connector (both shaft tangents). One tangent is still open.
		if _point_on_any_circle(loop_start, circs, on_tol) \
				and _point_on_any_circle(cursor, circs, on_tol) \
				and _circle_hit_count_at(loop_start, circs, segs, on_tol) >= 2 \
				and _circle_hit_count_at(cursor, circs, segs, on_tol) >= 2:
			continue
		return false
	return true


static func _point_on_any_circle(p: Vector2, circs: Array, tol: float) -> bool:
	for c in circs:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var center: Vector2 = c["c"]
		if absf(p.distance_to(center) - float(c["r"])) <= tol:
			return true
	return false
