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
	CENTERLINE, ELLIPSE, SLOT, CHAMFER, OFFSET,
}

signal selection_changed(ids: Array)

## Set by main from SketchContextChrome; owns the Offset panel and click path.
var offset_ui: SketchOffset
## Circular Sketch Pattern panel (Count / Angle / Ok). Linear still uses click.
var pattern_ui: SketchCircularPattern
const _SketchVertical := preload("res://scripts/sketch_vertical.gd")
const _SketchHorizontal := preload("res://scripts/sketch_horizontal.gd")
const _BooleanTarget := preload("res://scripts/boolean_target.gd")
const _FaceLabelPark := preload("res://scripts/face_label_park.gd")
const _SketchSplineEdit := preload("res://scripts/sketch_spline_edit.gd")

const PICK_TOLERANCE := 2.5  # model units (mm) — selection hit radius
## Thin lines are a pixel wide. At the jaw-head zoom (~3 px/mm) 2.5 mm is
## under a finger-width, so a click on a shaft line misses. Grow the hit
## radius with the view, capped so a zoomed-out part does not select everything.
const PICK_SCREEN_PX := 14.0
const PICK_TOLERANCE_MAX_MM := 8.0
## Circle/arc Select: the inner half of the disk is fill (lesson 2 hole);
## the rim band is the outer half plus pick_tol (A12 Vertical).
const STROKE_FILL_FRAC := 0.5
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
## Fit vs control-polygon handles, comb, tangent pins (WP-S2).
var spline_edit := _SketchSplineEdit.new()
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

# Sketch plane frame in model space. Outside readers use the properties.
var plane: PlaneBasis = PlaneBasis.from_axes(Vector3.ZERO, Vector3.RIGHT, Vector3.UP)
var plane_origin: Vector3:
	get:
		return plane.origin
var plane_x: Vector3:
	get:
		return plane.x
var plane_y: Vector3:
	get:
		return plane.y

## Selected entity ids (SELECT tool), most recent last, max 2.
var selected: Array[String] = []
## Parallel to `selected`. "self" is the whole line; "start"/"end" is an endpoint.
var selected_roles: Array[String] = []
## Selected constraint id (click its glyph with the SELECT tool); Del removes.
var selected_constraint := ""
## Shift/Ctrl/Meta from the live pointer event. `push_input` keys do not update
## `Input.is_key_pressed`; A12 still has to add the second circle.
var _pointer_additive := false

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
var _dimension_geom: MeshInstance3D
var _constraint_glyphs: Node3D
## Anchors of the drawn glyphs: Array of {cid: String, pos: Vector2}.
var _glyph_anchors: Array = []
## Last pointer in viewport pixels, for the 14 px coincident hover.
var _pointer_screen := Vector2.INF
var _coincident_sig := ""
## Coincident glyphs the pointer is already on, so a click can land after
## the badge has been nudged off its vertex.
var _coincident_keep: Dictionary = {}
## Live inference hint while drawing (shows H/V/coincident before commit).
var _infer_label: Label3D
var _selected_material: StandardMaterial3D
var _tool_points: Array[Vector2] = []  # committed anchor points of current tool
var _hover: Vector2 = Vector2.ZERO
## View → Temporary Axes. Default on; overlay only with a revolve body.
var temp_axes_visible := true
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
const COLOR_ENTITY := Color(0.25, 0.55, 1.0)
const COLOR_CONSTRUCTION := Color(0.45, 0.45, 0.48)  # dimmer/desaturated
const COLOR_CONSTRAINED := Color(0.92, 0.94, 0.96)  # fully defined, near-white on charcoal
const COLOR_CONFLICT := Color(0.95, 0.3, 0.25)  # entities in conflicting constraints
const COLOR_GLYPH := Color(0.20, 0.72, 0.38)
const COLOR_DIM_DRIVEN := Color(0.55, 0.58, 0.62)
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
## Screen de-stack: a glyph stays within the cap of its anchor and grows a
## leader once it has moved. Badges separate from each other and stay above
## the shaft first; dimension labels then keep this gap from the badges.
const GLYPH_FONT_PX := 16
const GLYPH_MAX_OFFSET_PX := 40.0
## Coincident badges appear only for a selected vertex, a selected coincident
## constraint, or the vertex under the pointer.
const COINCIDENT_HOVER_PX := 14.0
## Keep the mark inside the 14 px vertex hover so its leader cannot cross a
## neighbouring ⊥ / ∥ badge (N26). SELECT still prefers the nearer of the
## endpoint and the badge, so a vertex press picks the entity.
const COINCIDENT_LEADER_CAP := 13.5
const GLYPH_LEADER_MIN_PX := 12.0
const GLYPH_LABEL_GAP_PX := 12.0
## Full-circle radius text stays this many pixels outside the rim, and never
## farther than GLYPH_MAX_OFFSET_PX, so Ø / radius callouts stay on the circle.
const CIRCLE_LABEL_RIM_GAP_PX := 10.0
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
## Set when constrain() already named a conflict or redundant relation.
var last_relation_note := ""
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
	_contour_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contour_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_contour_tag.visible = false
	_contour_tags.add_child(_contour_tag)
	_dimension_labels = Node3D.new()
	_dimension_labels.name = "DimensionLabels"
	add_child(_dimension_labels)
	_dimension_geom = MeshInstance3D.new()
	_dimension_geom.name = "DimensionGeometry"
	var dim_mat := StandardMaterial3D.new()
	dim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dim_mat.vertex_color_use_as_albedo = true
	dim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dim_mat.no_depth_test = true
	dim_mat.render_priority = 2
	dim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dim_mat.albedo_color = Color.WHITE
	_dimension_geom.material_override = dim_mat
	add_child(_dimension_geom)
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
	return plane.normal


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
				var uv := plane.to_uv(Vector3(x, y, z))
				mn = mn.min(uv)
				mx = mx.max(uv)
	if not is_finite(mn.x):
		return {}
	return {"min": mn, "max": mx}


## Sketch 2D → model space.
func to_model(p: Vector2) -> Vector3:
	return plane.to_world(p)


func _clear_support() -> void:
	support_host = ""
	support_normal = Vector3.ZERO
	support_side = ""
	host_face_id = ""


func _feature_params_dict(fid: String) -> Dictionary:
	if view == null or view.doc == null or fid == "":
		return {}
	for f in view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
		return {}
	return {}


## Host/face/normal stored on a committed face sketch (`_write_sketch_support`).
func _support_from_feature(fid: String) -> Dictionary:
	var params := _feature_params_dict(fid)
	var host := str(params.get("support_host", ""))
	if host == "":
		return {}
	var n: Variant = params.get("support_normal", [0, 0, 0])
	var normal := Vector3.ZERO
	if n is Array and n.size() >= 3:
		normal = Vector3(float(n[0]), float(n[1]), float(n[2]))
	return {
		"host": host,
		"normal": normal,
		"side": str(params.get("support_side", "max")),
		"face": str(params.get("host_face", "")),
	}


func _adopt_support(support: Dictionary) -> void:
	_clear_support()
	if support.is_empty():
		target_fid = ""
		return
	support_host = str(support.get("host", ""))
	support_normal = support.get("normal", Vector3.ZERO)
	support_side = str(support.get("side", "max"))
	host_face_id = str(support.get("face", ""))
	target_fid = support_host


## Cut/fuse target: the live session, then the saved host, then the host face,
## then the only body in the part (jaw cut after a pencil reopen).
func _boolean_target_fid() -> String:
	return _BooleanTarget.resolve(self)


## True when `face_id`'s midpoint sits on the active sketch plane.
func face_lies_on_plane(face_id: String) -> bool:
	if face_id == "" or view == null or view.doc == null:
		return false
	if not view.doc.has_method("face_midpoint"):
		return false
	var mid: Variant = view.doc.face_midpoint(face_id)
	if not (mid is Vector3):
		return false
	var n := plane.normal
	if n.length_squared() < 1e-12:
		return false
	return absf(Plane(n, plane.origin).distance_to(mid as Vector3)) <= 0.75


## Begin a sketch on the model-space plane (origin + normal). The in-plane
## axes come from PlaneBasis.for_face.
## Extrude follows this normal.
func begin(origin: Vector3, normal: Vector3, support: Dictionary = {}) -> void:
	editing_fid = ""
	_clear_support()
	if not support.is_empty():
		support_host = str(support.get("host", ""))
		support_normal = support.get("normal", Vector3.ZERO)
		support_side = str(support.get("side", "max"))
		host_face_id = str(support.get("face", ""))
	_setup_plane(origin, normal)
	sketch = SxSketch.new()
	sketch.set_plane(plane.origin, plane_x, plane_y)
	_activate_session()
	status.emit("Sketch: Select · Line · Rect · Circle · Exit Sketch · Esc discard")


## New sketch on an explicit plane (3D path legs, UI movies).
func begin_on_plane(origin: Vector3, x_dir: Vector3, y_dir: Vector3) -> bool:
	if view == null or active:
		return false
	editing_fid = ""
	_clear_support()
	plane = PlaneBasis.from_axes(origin, x_dir.normalized(), y_dir.normalized())
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
	plane = PlaneBasis.from_axes(
			pi["origin"],
			(pi["x_dir"] as Vector3).normalized(),
			(pi["y_dir"] as Vector3).normalized())
	sketch = loaded
	_edit_baseline = loaded.snapshot() if loaded.has_method("snapshot") else ""
	# Pencil/timeline reopen must put Cut back on the body this sketch sat on.
	# Exit clears host_face_id so the selection card does not cover the rail.
	_adopt_support(_support_from_feature(fid))
	_activate_session()
	if announce:
		status.emit("Editing sketch — Exit Sketch to save · Esc discard")
	return true


func _setup_plane(origin: Vector3, normal: Vector3) -> void:
	last_dofs = -1
	last_solve_status = ""
	plane = PlaneBasis.for_face(normal, origin)


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
	# Publish the chip before the first redraw. Restoring stays true so this
	# solve does not pop relation chips; the label still updates.
	refresh_dof_state()
	# The activation solve reprints parameters. Re-take the baseline after that
	# solve so a no-op reopen compares against the solved sketch, not the
	# pre-solve digits.
	if editing_fid != "" and sketch != null and sketch.has_method("snapshot"):
		_edit_baseline = sketch.snapshot()
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
		_rebuild_constraint_glyphs()
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
		if sketch.has_method("snapshot") and _snapshots_equal(sketch.snapshot(), _edit_baseline):
			fid = editing_fid
			_end_sketch_session()
			# The dimension edit already wrote the graph. Refresh the body
			# mesh without a second undo snapshot.
			if view != null:
				view.graph_changed()
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
		flip_side: bool = false, selected_contours: Array = [],
		draft_deg: float = 0.0, draft_inward: bool = true) -> void:
	if not active:
		return
	var distance_refusal := _extrude_distance_refusal(distance, end)
	if distance_refusal != "":
		_refuse_extrude(distance_refusal)
		return
	if absf(draft_deg) >= 75.0:
		_refuse_extrude("Draft angle too large")
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
	if host_face_id == "" and sketch != null and sketch.has_method("contour_count"):
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
	# Seal rewrites circle+chord bosses into arcs, which reshuffles region
	# indices. Only do that when every contour is going out (empty = all, or
	# the caller passed a full index list). A subset pick (spanner heads, then
	# handle) must keep the pre-seal faces so those indices still match.
	if wanted_all or selected_contours.is_empty():
		_drop_circles_concentric_with_jaw_arcs()
		_seal_tangent_bosses()
	_reweld_jaw_profile()
	_weld_nearby_curve_joints()
	if wanted_all:
		selected_contours = []
	var open_prof := not profile_is_closed(sketch)
	if thin_thickness <= 0.0 and open_prof and selected_contours.is_empty():
		if op == "cut" or op == "fuse":
			_refuse_extrude(_chain_breaker_status())
		else:
			_refuse_extrude(_open_profile_status())
		return
	var cut_tgt := _boolean_target_fid()
	if op != "new" and cut_tgt == "":
		_refuse_extrude("No target body — sketch on a face to cut/fuse")
		return
	if cut_tgt != "":
		target_fid = cut_tgt
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
		thin_thickness, thin_type, flip_side, selected_contours, to_face_id,
		draft_deg, draft_inward)
	if ex_fid == "" and _graph_error_text().contains("Thin wall"):
		_refuse_extrude(_graph_error_text())
		return
	# Kernel now refuses an open-shell or zero-volume Cut as "boolean failed"
	# instead of committing it. Name that the same as the rollback path so
	# an off-body contour is inspectable.
	if ex_fid == "" and op == "cut" and _graph_error_text().contains("boolean failed"):
		_refuse_extrude(_cut_refusal(vol_before, vol_before))
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


## Blind and mid-plane read the typed distance. Zero never reaches the kernel.
const _EXTRUDE_DISTANCE_ENDS := ["blind", "midplane"]


func _extrude_distance_refusal(distance: float, end: String) -> String:
	if not _EXTRUDE_DISTANCE_ENDS.has(end):
		return ""
	if is_zero_approx(distance):
		return "Distance must be a positive number"
	return ""


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
	var cut_tgt := _boolean_target_fid()
	if op != "new" and cut_tgt == "":
		status.emit("No target body — sketch on a face to cut/fuse")
		return
	if cut_tgt != "":
		target_fid = cut_tgt
	# Close a dangling line chain. Do not weld arc ends onto neighbours —
	# that pulls them off the circle and GC_MakeArcOfCircle then skips the
	# rim (candlestick R12.5), which is the open-loop refuse.
	_try_close_open_chain()
	var axis_point := Vector2.ZERO
	var axis_dir := Vector2(0, 1)
	if selected.size() == 1:
		var info: Dictionary = sketch.entity_info(selected[0])
		if info.get("type", "") == "line":
			axis_point = info["start"]
			axis_dir = (info["end"] - info["start"]).normalized()
			# Keep the line in the profile. Marking it construction drops the
			# closing side of a revolve-about-itself sketch (candlestick 220).
	var sk_fid := _ensure_sketch_feature()
	if sk_fid == "":
		return
	var rv_fid: String = view.doc.graph_add_revolve(
		sk_fid, axis_point, axis_dir, angle, op, target_fid if op != "new" else "")
	_finish_feature(sk_fid, rv_fid, op, "Revolve failed — closed profile on one side of the axis?")


func _write_sketch_support(fid: String) -> void:
	if support_host == "" or view == null or view.doc == null:
		return
	var params := _feature_params_dict(fid)
	params["support_host"] = support_host
	params["support_normal"] = [support_normal.x, support_normal.y, support_normal.z]
	params["support_side"] = support_side if support_side != "" else "max"
	if host_face_id != "":
		params["host_face"] = host_face_id
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


## sketch_add_external_edge writes the graph copy. Put that profile back into
## the editor sketch without replacing the object Offset still holds.
func _adopt_converted_sketch() -> void:
	if editing_fid == "" or sketch == null or view == null or view.doc == null:
		return
	if not view.doc.has_method("graph_get_sketch"):
		return
	var loaded: SxSketch = view.doc.graph_get_sketch(editing_fid)
	if loaded == null or not loaded.has_method("snapshot") or not sketch.has_method("restore"):
		return
	sketch.restore(loaded.snapshot())


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
	_hide_infer_hint()
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
	return SketchToolSpec.undo_label_for(self)


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
	var full := id_sig + "|" + _contour_geom_sig() + "|" + host_face_id
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
	var n := plane.x.cross(plane.y)
	var denom := direction.dot(n)
	if absf(denom) < 1e-9:
		return null
	var t := (plane.origin - origin).dot(n) / denom
	if t < 0:
		return null
	return plane.to_uv(origin + direction * t)


signal tool_changed(tool: int)
## Emitted after set_tool_variant. The chip row re-highlights the active chip.
signal tool_variant_changed
## Emitted when selection chips should refresh (ids may be empty).
signal selection_actions_needed
## Live rubber-band distance (mm) while a single-DOF draw step is active.
signal preview_distance_changed(distance: float)


func _hide_infer_hint() -> void:
	if _infer_label != null:
		_infer_label.visible = false


func set_tool(t: Tool) -> void:
	# Re-arming a tool spends the "next Esc leaves" promise. The tool-drop
	# rung applies again until a new pending point is dropped.
	_hide_infer_hint()
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
	# Convert / Offset Esc drops the tool. A leftover Smart Dim selection
	# would spend that key on "selection cleared" and leave the tool armed.
	# A single leftover entity makes the next Smart Dim a BETWEEN/angle
	# (rung 3 two 120s). Two-circle selection must stay so the chip row
	# still shows (replan12 chiprow).
	_arm_clear_selection(t)
	# Default variants per tool family (reset on tool switch so prior family
	# names like circle "center" don't silently become rect "center").
	var spec := SketchToolSpec.of(int(t))
	if spec.sets_default_variant:
		tool_variant = spec.default_variant_of(self)
	if t == Tool.PATTERN and pattern_ui != null:
		pattern_ui.reset_centre()
		pattern_ui.count = int(SketchCircularPattern.SPEC["count"])
		pattern_ui.angle_deg = float(SketchCircularPattern.SPEC["angle_deg"])
	# Do not clear selection on tool switch — completed geometry must stay
	# visible/selectable (polygon/circle vanishing after another tool was a bug).
	_snap_marker = null
	_update_preview()
	tool_changed.emit(int(t))
	var hint := tool_arm_hint(t)
	if hint != "":
		status.emit(hint)


const ARM_CLEAR := {
	Tool.CONVERT: "always",
	Tool.OFFSET: "always",
	Tool.SMART_DIM: "if_one",
	Tool.MIRROR: "keep",
}


func _arm_clear_selection(t: Tool) -> void:
	var mode := str(ARM_CLEAR.get(t, "keep"))
	if mode != "always" and not (mode == "if_one" and selected.size() == 1):
		return
	_set_selected([])
	if selected_constraint != "":
		select_constraint("")


## One-line status when a rail tool (or shortcut) is armed. Empty = keep the
## previous line. Slot must say `Slot —` so a walker can tell it actually armed.
func tool_arm_hint(t: Tool) -> String:
	return SketchToolSpec.of(int(t)).arm_hint


func is_jaw_armed() -> bool:
	return _jaw_armed


## Rail "Jaw" button: Rectangle tool, Center Three Point variant.
func start_jaw_tool() -> void:
	_arming_jaw = true
	set_tool(Tool.RECT)
	set_tool_variant("center_three_point")


func set_tool_variant(v: String) -> void:
	_hide_infer_hint()
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
	if tool == Tool.ARC and v == "three_point":
		return "Arc · Three Point — click the start, the bulge, then the end"
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
		Tool.LINE, Tool.CENTERLINE, Tool.POLYGON, Tool.SLOT:
			return _tool_points.size() == 1
		Tool.CIRCLE:
			if tool_variant == "three_point" or tool_variant == "perimeter":
				return not _tool_points.is_empty()
			return _tool_points.size() == 1
		Tool.ARC:
			# Centre and three-point are three clicks; tangent is two. Any
			# collected point means the rest of the gesture must place, not
			# open a dimension editor that sits on the next click.
			return not _tool_points.is_empty()
		Tool.ELLIPSE:
			return _tool_points.size() == 1 or _tool_points.size() == 2
		_:
			return false


## Draw / trim tools place on the model. Overlays (ViewCube) must not snap
## the camera or swallow that click. Select / Smart Dim still use the cube.
func places_on_model() -> bool:
	if not active:
		return false
	match tool:
		Tool.LINE, Tool.CENTERLINE, Tool.ARC, Tool.CIRCLE, Tool.RECT, \
		Tool.POLYGON, Tool.SLOT, Tool.ELLIPSE, Tool.MIRROR, Tool.TRIM, \
		Tool.EXTEND, Tool.SPLINE, Tool.POINT:
			return true
		_:
			return has_pending_draw_point()


## Esc with a first anchor placed: drop the anchor and keep the sketch session.
func cancel_pending_draw() -> void:
	_hide_infer_hint()
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
	return SketchToolSpec.of(int(tool)).numeric_for(self)


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
const POLYGON_CENTRE_SET := "Polygon — centre set, click a vertex or type the size"
const JAW_AFTER_CENTRE := "Jaw — centre set, click 2 end of the long side"
const JAW_AFTER_LONG := "Jaw — long side set, click 3 half the width"
const JAW_ZERO_WIDTH := "Jaw — width is zero — click 3 again for half the width"
const JAW_ZERO_LONG := "Jaw — long side is zero — click 2 again for the end of the long side"


func variants_for_tool(t: Tool = tool) -> Array:
	# SolidWorks rectangle flyout (corner first) lives on the Rect row.
	return SketchToolSpec.of(int(t)).variants_of(self)


func selection_actions() -> Array:
	var acts: Array = []
	if selected.is_empty():
		return acts
	acts.append("construction")
	acts.append("delete")
	if selected.size() == 1 and _SketchVertical.offers(sketch, selected, selected_roles):
		acts.append("vertical")
	if selected.size() == 1 and sketch.entity_info(selected[0]).get("type", "") == "spline":
		acts.append("spline_fit")
		acts.append("spline_poles")
		acts.append("spline_comb")
	if selected.size() == 2:
		# Endpoint pair first so Vertical/Horizontal stay on the chip row
		# instead of … More (a More click would drop the selection).
		if _endpoint_pick():
			acts.append("horizontal")
			acts.append("vertical")
		var t0: String = sketch.entity_info(selected[0]).get("type", "")
		var t1: String = sketch.entity_info(selected[1]).get("type", "")
		if (t0 == "circle" or t0 == "arc") and (t1 == "circle" or t1 == "arc"):
			acts.append("shaft_lines")
		# Two circle centres: Vertical sits next to Shaft Lines, not in More.
		if _SketchVertical.offers(sketch, selected, selected_roles) and not acts.has("vertical"):
			acts.append("vertical")
		if t0 == "line" and t1 == "line":
			acts.append("fillet")
			acts.append("chamfer")
		for v in ["horizontal", "vertical", "parallel", "perpendicular",
				"equal", "coincident", "tangent", "midpoint", "symmetric"]:
			if not acts.has(v):
				acts.append(v)
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
		# A Ø150 rim click is 75 mm from the origin; a view-scaled snap
		# must not pull it onto the centre (Smart Dim would wait for a
		# second pick instead of emitting diameter).
		if d2 <= best_d and not _snap_blocked_by_curve(p, mp):
			best_d = d2
			best_pt = mp
			found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# Other visible sketches (path start when the ellipse is on Right).
	best_d = rad
	found = false
	if view != null and view.doc != null:
		for op in SketchTempAxes.other_sketch_points(view.doc, editing_fid, plane):
			var d3 := p.distance_to(op)
			if d3 <= best_d:
				best_d = d3
				best_pt = op
				found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# Revolve axis: x = 0 at any Y (not only the origin).
	var axis_pt := SketchTempAxes.snap_y_axis(p, rad)
	if axis_pt != p:
		_snap_marker = axis_pt
		return axis_pt
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
	for row in _kernel_plane_circles():
		out.append(plane.to_uv(row["center"] as Vector3))
	return out


func _kernel_plane_circles() -> Array:
	if view == null or view.doc == null or plane == null:
		return []
	if not view.doc.has_method("circles_on_plane"):
		return []
	return view.doc.circles_on_plane(plane.origin, plane.x, plane.y)


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
		"ellipse":
			if info.has("major_start"):
				out.append(info["major_start"])
			if info.has("major_end"):
				out.append(info["major_end"])
			if info.has("minor_start"):
				out.append(info["minor_start"])
			if info.has("minor_end"):
				out.append(info["minor_end"])
		"elliptical_arc":
			if info.has("start"):
				out.append(info["start"])
			if info.has("end"):
				out.append(info["end"])
		"point":
			out.append(info["position"])
	return out


func _snap_mid_centers(id: String) -> Array[Vector2]:
	var info: Dictionary = sketch.entity_info(id)
	var out: Array[Vector2] = []
	match info.get("type", ""):
		"line":
			out.append((info["start"] + info["end"]) * 0.5)
		"circle", "arc", "ellipse", "elliptical_arc":
			out.append(info["center"])
	return out


# --- selection & constraints ---

func _set_selected(ids: Array[String]) -> void:
	var picks: Array = []
	for id in ids:
		picks.append({"id": id, "role": "self"})
	_set_picks(picks)


func _set_picks(picks: Array) -> void:
	var ids: Array[String] = []
	selected_roles.clear()
	for pick in picks:
		ids.append(str(pick.get("id", "")))
		selected_roles.append(str(pick.get("role", "self")))
	selected = ids
	_redraw_selected()
	_rebuild_constraint_glyphs()
	selection_changed.emit(selected)
	selection_actions_needed.emit()


func _role_at(index: int) -> String:
	if index < 0 or index >= selected_roles.size():
		return "self"
	return selected_roles[index]


func _ref_at(index: int) -> Dictionary:
	return {"entity": selected[index], "role": _role_at(index)}


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


## Nearest non-construction entity. Construction geometry loses a tie.
func _nearest_profile_entity_at(pos2: Vector2) -> String:
	var best_id := ""
	var best_d := _pick_tolerance()
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if bool(info.get("construction", false)):
			continue
		var d := _entity_distance(info, pos2)
		if d < best_d:
			best_d = d
			best_id = str(id)
	return best_id


## Power Trim: a line under the pointer wins a close race against an
## ellipse/arc. Overflow clicks sit a few millimetres inside the C; picking
## the remaining elliptical arc would eat the pad instead of the handle.
func _nearest_trim_entity_at(pos2: Vector2) -> String:
	var best_id := ""
	var best_d := _pick_tolerance()
	var best_line := ""
	var best_line_d := _pick_tolerance()
	const TRIM_CURVE_MM := 3.0
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if bool(info.get("construction", false)):
			continue
		var kind := str(info.get("type", ""))
		var d := _entity_distance(info, pos2)
		if kind == "line":
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			d = SketchGeom.trim_line_pick_distance(pos2, a, b, 3.0, 25.0,
					_point_on_trim_curve(a), _point_on_trim_curve(b))
			if d < best_line_d:
				best_line_d = d
				best_line = str(id)
		elif kind == "ellipse" or kind == "elliptical_arc":
			# Interior of the C pad is not a trim hit on the remaining arc.
			# The handle overflow at (18, ±10) sits inside that pad.
			if d > TRIM_CURVE_MM or (pos2.x > 5.0 and absf(pos2.y) <= 12.0):
				continue
		if d < best_d:
			best_d = d
			best_id = str(id)
	if best_line != "" and best_line != best_id and best_line_d <= best_d + 2.0:
		var k := str(sketch.entity_info(best_id).get("type", ""))
		# Only the C elliptical pad: overflow clicks sit on the remaining
		# ellipse. Jaw trim is a circle/arc and must keep winning over walls.
		if k == "ellipse" or k == "elliptical_arc":
			return best_line
	if best_line != "" and best_id == "":
		return best_line
	return best_id


func _point_on_trim_curve(p: Vector2, tol := 0.08) -> bool:
	if sketch == null:
		return false
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "ellipse" and kind != "elliptical_arc" \
				and kind != "circle" and kind != "arc":
			continue
		if _entity_distance(info, p) <= tol:
			return true
	return false


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


## Shift-select at a line-curve vertex is the curve. Construction CL through
## the C must not win: the handle end sits on the elliptical arc, and picking
## the line again would toggle it off.
func _additive_entity_at(pos2: Vector2) -> Dictionary:
	if sketch == null:
		return {}
	var best_id := _nearest_profile_entity_at(pos2)
	if best_id == "":
		return {}
	var role := _endpoint_role_at(best_id, pos2)
	var has_line := false
	for id in selected:
		if sketch.is_construction(id):
			continue
		if str(sketch.entity_info(id).get("type", "")) == "line":
			has_line = true
			break
	if not has_line:
		return {"id": best_id, "role": role}
	var curve_id := ""
	var curve_d := _pick_tolerance()
	for id in sketch.entity_ids():
		if sketch.is_construction(id) or selected.has(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if not _is_curve_kind(str(info.get("type", ""))):
			continue
		var d := _entity_distance(info, pos2)
		if d < curve_d:
			curve_d = d
			curve_id = str(id)
	if curve_id != "":
		return {"id": curve_id, "role": "self"}
	return {"id": best_id, "role": role}


func _select_at(pos2: Vector2) -> void:
	var best_id := _nearest_entity_at(pos2)
	var region_idx := _region_index_at(pos2)
	# Stroke vs fill: a 0.75 mm rim is Vertical (A12); the interior of a
	# Ø10 is a cut-region click (lesson 2). Zoomed-out pick_tol is wider.
	var on_stroke := best_id != "" and _on_stroke(best_id, pos2)
	# Additive is selection arithmetic. A region fill is a finish gesture
	# and must not run under Shift (A12 second circle).
	if _additive_pick():
		var hit := _additive_entity_at(pos2)
		if not hit.is_empty():
			toggle_pick_entity(str(hit["id"]), str(hit["role"]))
		return
	if region_idx >= 0 and not on_stroke:
		_set_selected([])
		_apply_region_pick(region_idx)
		return
	if best_id == "":
		_set_selected([])
		return
	toggle_pick_entity(best_id, _endpoint_role_at(best_id, pos2))


## Pointer additive from the mouse *press*. The release event may omit
## Shift even while the key is still down (automation mouse-up).
func set_pointer_additive(on: bool) -> void:
	_pointer_additive = on


func _additive_pick() -> bool:
	return _pointer_additive \
			or Input.is_key_pressed(KEY_SHIFT) \
			or Input.is_key_pressed(KEY_CTRL) \
			or Input.is_key_pressed(KEY_META)


## Jitter-release of a SELECT drag. A stroke grab stays an entity pick.
## Shift keeps a fill grab so the second circle is added (A12) instead of
## a region click that clears the first.
func keep_drag_pick(on_stroke: bool) -> bool:
	if drag_entity_id() == "":
		return false
	return on_stroke or _additive_pick()


## Drop the geometry drag and resolve it as a SELECT pick.
## Additive never toggles the grab off: a Shift fill that hit-tested the
## already-selected Ø130 would otherwise empty the list (A12 Vertical).
func commit_select_drag(release_uv: Vector2) -> void:
	var grabbed := drag_entity_id()
	var role := drag_pick_role()
	var keep := keep_drag_pick(drag_on_stroke())
	var additive := _additive_pick()
	cancel_drag()
	if additive:
		if grabbed != "":
			pick_entity(grabbed, true, role, false)
		var at := _nearest_profile_entity_at(release_uv)
		if at != "" and at != grabbed:
			pick_entity(at, true, _endpoint_role_at(at, release_uv), false)
		return
	if keep:
		# SmartDim leaves both circles selected. Toggle would drop the Ø130
		# (A12). Isolate it when it is already one of several; a new id still
		# adds so two unshifted circle clicks keep Shaft Lines (rung 1 A4).
		if selected.size() > 1 and selected.has(grabbed):
			pick_entity(grabbed, false, role, false)
		else:
			toggle_pick_entity(grabbed, role)
	else:
		click(release_uv)


## Stroke width for Select: rim vs region fill. Lines stay 0.75 mm.
func _stroke_mm() -> float:
	return minf(0.75, _pick_tolerance() * 0.35)


func _on_stroke(id: String, pos2: Vector2) -> bool:
	if sketch == null or id == "":
		return false
	var info: Dictionary = sketch.entity_info(id)
	var kind := str(info.get("type", ""))
	if kind == "circle" or kind == "arc":
		var centre: Vector2 = info["center"]
		var radius := float(info.get("radius", 0.0))
		var dc := pos2.distance_to(centre)
		if dc < radius * STROKE_FILL_FRAC:
			return false
		return absf(dc - radius) < _pick_tolerance()
	return _entity_distance(info, pos2) < _stroke_mm()


## Entity id under an in-progress SELECT drag, or "".
func drag_entity_id() -> String:
	return str(_drag.get("id", "")) if not _drag.is_empty() else ""


## True when the SELECT drag grabbed the curve, not a circle's interior.
func drag_on_stroke() -> bool:
	if _drag.is_empty():
		return false
	var grab: Vector2 = _drag.get("grab_pos", Vector2.ZERO)
	return _on_stroke(str(_drag.get("id", "")), grab)


## Endpoint role for a SELECT drag, or "self" for a whole entity / rim.
func drag_pick_role() -> String:
	if _drag.is_empty():
		return "self"
	var part := str(_drag.get("part", "whole"))
	if part == "start" or part == "end":
		return part
	return "self"


## Toggle one entity on the SELECT list (circle click after a jittered drag).
func toggle_pick_entity(id: String, role: String = "self") -> void:
	pick_entity(id, true, role, true)


## SELECT a grabbed entity. additive keeps others; replace=false clears first.
## toggle_off removes an already-selected id (plain click on it).
func pick_entity(id: String, additive: bool = false, role: String = "self",
		toggle_off: bool = false) -> void:
	if not active or id == "":
		return
	if not additive:
		_set_picks([{"id": id, "role": role}])
		return
	var picks: Array = []
	for i in selected.size():
		picks.append(_ref_at(i))
	var existing := -1
	for i in picks.size():
		if str(picks[i]["entity"]) == id and str(picks[i]["role"]) == role:
			existing = i
			break
	if existing >= 0:
		if toggle_off:
			picks.remove_at(existing)
		else:
			return
	else:
		picks.append({"entity": id, "role": role})
		while picks.size() > 8:
			picks.pop_front()
	var stored: Array = []
	for pick in picks:
		stored.append({"id": pick["entity"], "role": pick["role"]})
	_set_picks(stored)


func _region_index_at(uv: Vector2) -> int:
	if sketch == null or view == null or view.doc == null:
		return -1
	if host_face_id != "" and view.doc.has_method("sketch_region_at"):
		return int(view.doc.sketch_region_at(sketch, host_face_id, uv.x, uv.y))
	if sketch.has_method("region_at"):
		return int(sketch.region_at(uv.x, uv.y))
	return -1


func _apply_region_pick(idx: int) -> void:
	var chrome := _sketch_chrome()
	if chrome != null and chrome.has_method("pick_region"):
		chrome.pick_region(idx)
	IntentResolver.apply_finish(chrome, host_face_id, target_fid)
	status.emit("Region %d — %s %s" % [
		idx + 1,
		IntentResolver.finish_op(host_face_id, target_fid).capitalize(),
		"Through All" if IntentResolver.finish_end(host_face_id, target_fid) == "through_all" else "Blind",
	])
	var included: Array = [idx]
	if chrome != null:
		included = chrome._selected_contours.duplicate()
		if not included.has(idx):
			included.append(idx)
	set_contour_highlight(included, idx)


## A click nearer an endpoint than the line midpoint stores that endpoint.
## Arc / ellipse major-axis ends are the same: the R20 hook and the 35 mm ellipse.
func _endpoint_pick() -> bool:
	for i in selected.size():
		if _role_at(i) != "self":
			return true
	return false


func _is_point_pair(refs: Array) -> bool:
	if refs.size() != 2:
		return false
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			return false
		var role := str(ref.get("role", "self"))
		if role != "start" and role != "end":
			return false
	return true


func _endpoint_pairs(info: Dictionary) -> Array:
	var kind := str(info.get("type", ""))
	var out: Array = []
	if kind == "line" or kind == "arc" or kind == "spline":
		if info.has("start"):
			out.append(["start", info["start"]])
		if info.has("end"):
			out.append(["end", info["end"]])
	elif kind == "ellipse":
		if info.has("major_start"):
			out.append(["start", info["major_start"]])
		if info.has("major_end"):
			out.append(["end", info["major_end"]])
	elif kind == "elliptical_arc":
		if info.has("start"):
			out.append(["start", info["start"]])
		if info.has("end"):
			out.append(["end", info["end"]])
	return out


func _endpoint_role_at(id: String, pos2: Vector2) -> String:
	var info: Dictionary = sketch.entity_info(id)
	var ends: Array = _endpoint_pairs(info)
	if ends.is_empty():
		return "self"
	var best_role := "self"
	var best_d := INF
	for pair in ends:
		var d: float = pos2.distance_to(pair[1])
		if d < best_d:
			best_d = d
			best_role = str(pair[0])
	if str(info.get("type", "")) == "line":
		var a: Vector2 = ends[0][1]
		var b: Vector2 = ends[1][1] if ends.size() > 1 else a
		if best_d < pos2.distance_to((a + b) * 0.5):
			return best_role
		return "self"
	if best_d <= _pick_tolerance():
		return best_role
	return "self"


## Ellipse centre landed on another sketch's endpoint: pin it there.
func _coincident_ellipse_to_path(eid: String, centre: Vector2) -> void:
	if sketch == null or view == null or view.doc == null or eid == "":
		return
	var rad := _snap_radius()
	var best := {}
	var best_d := rad
	for hit in SketchTempAxes.other_sketch_hits(view.doc, editing_fid, plane):
		var d: float = centre.distance_to(hit["uv"])
		if d < best_d:
			best_d = d
			best = hit
	if best.is_empty():
		return
	var uv: Vector2 = best["uv"]
	var pid: String = sketch.add_point(uv.x, uv.y)
	if pid == "":
		return
	sketch.set_construction(pid, true)
	sketch.add_constraint("fix", [{"entity": pid, "role": "self"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": eid, "role": "center"},
		{"entity": pid, "role": "self"}], 0.0)


## True when `p` sits on a circle/arc/ellipse curve closer than `centre`.
func _snap_blocked_by_curve(p: Vector2, centre: Vector2) -> bool:
	var to_c := p.distance_to(centre)
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "circle" and kind != "arc" and kind != "ellipse" and kind != "elliptical_arc":
			continue
		if _entity_distance(info, p) + 1.0e-6 < to_c:
			return true
	return false


func _entity_distance(info: Dictionary, p: Vector2) -> float:
	match info.get("type", ""):
		"line":
			return SketchGeom.point_segment_distance(p, info["start"], info["end"])
		"circle", "arc":
			return absf(p.distance_to(info["center"]) - info["radius"])
		"ellipse", "elliptical_arc":
			return SketchEllipse.distance(info, p)
		"point":
			return p.distance_to(info["position"])
	return INF


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
		"ellipse", "elliptical_arc":
			return SketchEllipse.closest(info, pos2)
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
	# Pass 1: endpoints / centers. A vertex click must stay an endpoint
	# (rung 4 hex Vertical), even when the line body is equally close.
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		match info.get("type", ""):
			"line", "arc", "ellipse", "elliptical_arc":
				for pair in _endpoint_pairs(info):
					var d: float = pos2.distance_to(pair[1])
					if d <= best_d:
						best_d = d
						best_id = id
						best_part = pair[0]
			"spline":
				var sh: Dictionary = spline_edit.hit(info, pos2, best_d)
				if not sh.is_empty():
					best_d = pos2.distance_to(_spline_handle_pos(info, str(sh["part"])))
					best_id = id
					best_part = str(sh["part"])
			"circle":
				pass
		if str(info.get("type", "")) == "circle" or str(info.get("type", "")) == "arc":
			var d2: float = pos2.distance_to(info["center"])
			var d_curve := absf(d2 - float(info.get("radius", 0.0)))
			# Centre handle only when nearer the centre than the rim.
			# pick_tol is often larger than a Ø10, so a rim click must
			# not become a centre grab (A12 Vertical).
			# Arc ends already won in pass 1 when the click is on a vertex.
			if d2 <= best_d and d2 < d_curve:
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
		"orig_snap": sketch.snapshot(),
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
		_restore_drag_snapshot()
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
		_restore_drag_snapshot()
		run_solve()
		status.emit("Drag reverted: constraints could not be satisfied")
	_drag.clear()
	_redraw()
	_rebuild_dimension_labels()
	_update_preview()


func _restore_drag_snapshot() -> void:
	if sketch == null:
		return
	var snap: String = str(_drag.get("orig_snap", ""))
	if snap != "" and sketch.restore(snap):
		return
	var orig: Dictionary = _drag.get("orig_info", {})
	if orig.has("params"):
		sketch.set_entity_geometry(_drag["id"], {"params": orig["params"]})
	else:
		sketch.set_entity_geometry(_drag["id"], orig)


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
		_:
			if orig.get("type", "") == "spline":
				return _SketchSplineEdit.apply_drag(orig, part, pos2)
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
		"ellipse", "elliptical_arc":
			var pts_e := SketchEllipse.polyline(info, 64)
			for i in range(pts_e.size() - 1):
				im.surface_add_vertex(_to3(pts_e[i]))
				im.surface_add_vertex(_to3(pts_e[i + 1]))
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
		"spline":
			var poly: Array = info.get("polyline", info.get("fit_points", []))
			for i in range(poly.size() - 1):
				im.surface_add_vertex(_to3(poly[i] as Vector2))
				im.surface_add_vertex(_to3(poly[i + 1] as Vector2))


func _append_spline_edit_lines(im: ImmediateMesh, info: Dictionary) -> void:
	var mark := 1.2
	if spline_edit.mode == _SketchSplineEdit.MODE_FIT:
		for fp in info.get("fit_points", []):
			var p: Vector2 = fp as Vector2
			im.surface_add_vertex(_to3(p + Vector2(-mark, 0)))
			im.surface_add_vertex(_to3(p + Vector2(mark, 0)))
			im.surface_add_vertex(_to3(p + Vector2(0, -mark)))
			im.surface_add_vertex(_to3(p + Vector2(0, mark)))
	else:
		var poles: Array = info.get("poles", [])
		for i in range(poles.size() - 1):
			im.surface_add_vertex(_to3(poles[i] as Vector2))
			im.surface_add_vertex(_to3(poles[i + 1] as Vector2))
		for pv in poles:
			var q: Vector2 = pv as Vector2
			im.surface_add_vertex(_to3(q + Vector2(-mark, -mark)))
			im.surface_add_vertex(_to3(q + Vector2(mark, mark)))
			im.surface_add_vertex(_to3(q + Vector2(-mark, mark)))
			im.surface_add_vertex(_to3(q + Vector2(mark, -mark)))
	var st: Vector2 = info.get("start", Vector2.ZERO) as Vector2
	var et: Vector2 = info.get("end", Vector2.ZERO) as Vector2
	var ts: Vector2 = info.get("start_tangent", Vector2.ZERO) as Vector2
	var te: Vector2 = info.get("end_tangent", Vector2.ZERO) as Vector2
	im.surface_add_vertex(_to3(st))
	im.surface_add_vertex(_to3(st + ts))
	im.surface_add_vertex(_to3(et))
	im.surface_add_vertex(_to3(et + te))
	if spline_edit.comb_on and sketch != null:
		var sid := str(info.get("id", selected[0] if not selected.is_empty() else ""))
		if sid == "" and not selected.is_empty():
			sid = selected[0]
		if sketch.has_method("spline_comb"):
			for tooth in sketch.spline_comb(sid, 32, 8.0):
				im.surface_add_vertex(_to3(tooth["at"]))
				im.surface_add_vertex(_to3(tooth["tip"]))


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


func _constraint_relation_name(type_str: String) -> String:
	if type_str == "symmetric":
		return "Symmetric (mirror)"
	if type_str == "":
		return ""
	return type_str.replace("_", " ").capitalize()


func _join_relation_names(names: PackedStringArray) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var s := names[0]
	for i in range(1, names.size()):
		if i == names.size() - 1:
			s += ", and " + names[i]
		else:
			s += ", " + names[i]
	return s


func _named_relations(ids: Array) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if sketch == null:
		return names
	for cid in ids:
		var t := str(sketch.constraint_info(str(cid)).get("type", ""))
		var n := _constraint_relation_name(t)
		if n != "" and not names.has(n):
			names.append(n)
	return names


func _relation_conflict_message() -> String:
	var names := _named_relations(last_conflicting)
	if names.is_empty():
		return "Relation did not stick"
	return "Conflicts with " + _join_relation_names(names)


func _relation_redundant_message() -> String:
	var names := _named_relations(last_redundant)
	if names.is_empty():
		return "Redundant relation"
	return "Redundant: " + _join_relation_names(names)


## Applies a constraint to the current selection. Supported types:
## horizontal/vertical (each selected line), parallel/perpendicular/equal
## (two entities), coincident (nearest endpoints of two lines), distance
## (line length, or nearest endpoints of two entities), radius (circle/arc).
## Solves afterwards; returns the solve status string ("" when nothing done).
func constrain(type: String, value: float = 0.0) -> String:
	last_relation_note = ""
	if not active or selected.is_empty():
		return ""
	var added := false
	var cid := ""  # id of the (last) constraint added, kept for editable dims
	match type:
		"horizontal", "vertical":
			if type == "vertical":
				cid = _SketchVertical.apply(sketch, selected, selected_roles)
				added = cid != ""
				if not added:
					if _endpoint_pick() and selected.size() != 2:
						status.emit("Vertical needs two endpoints")
					return ""
			else:
				cid = _SketchHorizontal.apply(sketch, selected, selected_roles)
				added = cid != ""
				if not added:
					if _endpoint_pick() and selected.size() != 2:
						status.emit("Horizontal needs two endpoints")
					return ""
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
			if not added:
				# Handle end on the C: both picks land on the strip, so the
				# ellipse never joins the selection. Weld the end to the curve.
				cid = _coincident_line_to_curve()
				added = cid != ""
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
				var r0 := "self"
				var r1 := "self"
				if type == "tangent":
					var pair_t := _closest_endpoints(selected[0], selected[1])
					if pair_t.size() == 2:
						r0 = pair_t[0]
						r1 = pair_t[1]
				cid = sketch.add_constraint(type, [
					{"entity": selected[0], "role": r0},
					{"entity": selected[1], "role": r1}], value)
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
		# leave last_solve_status on the previous good solve. Name the
		# diagnose() conflict set before the rollback clears it.
		last_relation_note = _relation_conflict_message()
		if sketch.has_method("remove_constraint"):
			sketch.remove_constraint(cid)
		for i in range(dimensions.size() - 1, -1, -1):
			if str(dimensions[i].get("cid", "")) == cid:
				dimensions.remove_at(i)
		res = run_solve()
		status.emit(last_relation_note)
		_redraw()
		_redraw_selected()
		return "failed"
	# Only name a leftover as redundant when the constraint just added is in
	# that set. A prior Tangent leftover must not overwrite "Vertical".
	if cid != "" and last_redundant.has(cid):
		last_relation_note = _relation_redundant_message()
		status.emit(last_relation_note)
	_redraw()
	_redraw_selected()
	return res["status"]


## Line directions are defined mod 180°. Fold into (−90°, 90°] and then take
## the unsigned angle from the horizontal, so a wall read from the other end
## (−135° or 135°) records 45° and a label never carries a minus.
func _normalize_jaw_angle_rad(rad: float) -> float:
	var deg := rad_to_deg(rad)
	while deg <= -180.0:
		deg += 360.0
	while deg > 180.0:
		deg -= 360.0
	if deg > 90.0:
		deg -= 180.0
	elif deg <= -90.0:
		deg += 180.0
	if deg < 0.0:
		deg = -deg
	return deg_to_rad(deg)


func _jaw_angle_from_direction(dir: Vector2) -> float:
	if dir.length_squared() < 1e-12:
		return 0.0
	return rad_to_deg(_normalize_jaw_angle_rad(Vector2(1, 0).angle_to(dir)))


func _ids_are_jaw_angle(ids: Array) -> bool:
	if sketch == null:
		return false
	var saw_datum := false
	var saw_wall := false
	for id in ids:
		var info: Dictionary = sketch.entity_info(str(id))
		if str(info.get("type", "")) != "line":
			continue
		if sketch.is_construction(str(id)):
			var d: Vector2 = info["end"] - info["start"]
			if absf(d.y) <= maxf(1e-4, absf(d.x) * 1e-3):
				saw_datum = true
		else:
			saw_wall = true
	return saw_datum and saw_wall


func _dimension_is_jaw_angle(dim: Dictionary) -> bool:
	if str(dim.get("callout", "")) == "jaw_angle":
		return true
	if str(dim.get("type", "")) != "angle":
		return false
	return _ids_are_jaw_angle(dim.get("ids", []))


func _num_close(a: float, b: float, tol: float) -> bool:
	var diff := absf(a - b)
	var scale := maxf(absf(a), absf(b))
	return diff <= tol or (scale > 0.0 and diff <= tol * scale)


## True when two sketch snapshots are the same feature: same entities and
## constraints in order, parameters and values within `tol` (absolute or relative).
func _snapshots_equal(a: String, b: String, tol: float = 1e-9) -> bool:
	if a == b:
		return true
	if a == "" or b == "":
		return false
	var pa = JSON.parse_string(a)
	var pb = JSON.parse_string(b)
	if typeof(pa) != TYPE_DICTIONARY or typeof(pb) != TYPE_DICTIONARY:
		return false
	var ea: Array = pa.get("entities", [])
	var eb: Array = pb.get("entities", [])
	if ea.size() != eb.size():
		return false
	for i in ea.size():
		var ae: Dictionary = ea[i]
		var be: Dictionary = eb[i]
		if str(ae.get("id", "")) != str(be.get("id", "")):
			return false
		if str(ae.get("type", "")) != str(be.get("type", "")):
			return false
		if bool(ae.get("construction", false)) != bool(be.get("construction", false)):
			return false
		if bool(ae.get("external", false)) != bool(be.get("external", false)):
			return false
		if str(ae.get("projected_from", "")) != str(be.get("projected_from", "")):
			return false
		var ap: Array = ae.get("params", [])
		var bp: Array = be.get("params", [])
		if ap.size() != bp.size():
			return false
		for j in ap.size():
			if int(ap[j]) != int(bp[j]):
				return false
	var ca: Array = pa.get("constraints", [])
	var cb: Array = pb.get("constraints", [])
	if ca.size() != cb.size():
		return false
	for i in ca.size():
		var ac: Dictionary = ca[i]
		var bc: Dictionary = cb[i]
		if str(ac.get("id", "")) != str(bc.get("id", "")):
			return false
		if str(ac.get("type", "")) != str(bc.get("type", "")):
			return false
		if bool(ac.get("driving", true)) != bool(bc.get("driving", true)):
			return false
		if not _num_close(float(ac.get("value", 0.0)), float(bc.get("value", 0.0)), tol):
			return false
		var ra: Array = ac.get("refs", [])
		var rb: Array = bc.get("refs", [])
		if ra.size() != rb.size():
			return false
		for j in ra.size():
			if str(ra[j].get("entity", "")) != str(rb[j].get("entity", "")):
				return false
			if str(ra[j].get("role", "self")) != str(rb[j].get("role", "self")):
				return false
	var ppa: Array = pa.get("params", [])
	var ppb: Array = pb.get("params", [])
	if ppa.size() != ppb.size():
		return false
	for i in ppa.size():
		if not _num_close(float(ppa[i]), float(ppb[i]), tol):
			return false
	return true


func _record_dimension(type: String, ids: Array, value: float, cid: String = "",
		callout: String = "") -> void:
	if type == "angle" and callout == "jaw_angle":
		value = _normalize_jaw_angle_rad(value)
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
## Same kernel OFFSETTERS table as rail:Offset (chip:Offset path).
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
	run_solve()
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
	if tool_variant == "circular":
		return apply_circular_pattern()
	if not active or selected.is_empty():
		status.emit("Pattern needs a selection")
		return []
	var ids := PackedStringArray()
	for id in selected:
		ids.append(id)
	var new_ids: PackedStringArray = sketch.pattern_entities(ids, dx, dy, count)
	if new_ids.is_empty():
		status.emit("Pattern failed")
		return []
	_undo_note("Pattern")
	_redraw()
	var out: Array = []
	for id2 in new_ids:
		out.append(id2)
	return out


## 8-about-origin (SPEC) circular pattern. Count includes the seed.
func apply_circular_pattern() -> Array:
	if not active:
		return []
	if pattern_ui != null:
		pattern_ui.pull_fields()
	var n := int(pattern_ui.count) if pattern_ui != null else 8
	var ang_deg := float(pattern_ui.angle_deg) if pattern_ui != null else 360.0
	var c: Vector2 = pattern_ui.centre if pattern_ui != null else Vector2.ZERO
	if selected.is_empty():
		status.emit(SketchCircularPattern.REFUSALS["empty"])
		return []
	if n < 2:
		status.emit(SketchCircularPattern.REFUSALS["count"])
		if pattern_ui != null:
			pattern_ui.restore_count_default()
		return []
	if is_zero_approx(ang_deg):
		status.emit(SketchCircularPattern.REFUSALS["angle"])
		return []
	var ids := PackedStringArray()
	var kinds: Array = pattern_ui.kinds() if pattern_ui != null else ["circle"]
	for id in selected:
		var kind := str(sketch.entity_info(id).get("type", ""))
		if kind in kinds:
			ids.append(id)
	if ids.is_empty():
		status.emit(SketchCircularPattern.REFUSALS["empty"])
		return []
	if not sketch.has_method("circular_pattern_entities"):
		status.emit(SketchCircularPattern.REFUSALS["failed"])
		return []
	var new_ids: PackedStringArray = sketch.circular_pattern_entities(
			ids, c.x, c.y, n, deg_to_rad(ang_deg))
	if new_ids.is_empty():
		status.emit(SketchCircularPattern.REFUSALS["failed"])
		return []
	_undo_note("Pattern")
	run_solve()
	_redraw()
	status.emit(SketchCircularPattern.APPLIED % n)
	var out: Array = []
	for id2 in new_ids:
		out.append(id2)
	return out


## Mirror selected entities about a selected line axis (or sketch Y if none).
## A construction line in the set is the axis — the 17° jaw copy and the
## handle copy about the CL both pick that way, and an ellipse under the
## axis click must not steal the axis role.
func mirror_selected() -> Array:
	if selected.is_empty():
		status.emit("Mirror needs a selection")
		return []
	var axis_id := _axis_line_in_selection()
	var geo_ids: Array[String] = []
	for id in selected:
		if id != axis_id:
			geo_ids.append(id)
	if axis_id == "" or geo_ids.is_empty():
		status.emit("Mirror: select geometry plus one axis line")
		return []
	var packed := PackedStringArray()
	for id in geo_ids:
		packed.append(id)
	var copied: PackedStringArray = sketch.mirror_entities(packed, axis_id)
	var out: Array = []
	for i in range(copied.size()):
		out.append(copied[i])
	if not out.is_empty():
		_undo_note("Mirror")
		run_solve()
	elif geo_ids.size() > 0:
		status.emit("Mirror: select geometry plus one axis line")
	_redraw()
	return out


func _axis_line_in_selection() -> String:
	var construction := ""
	var first_line := ""
	for id in selected:
		if str(sketch.entity_info(id).get("type", "")) != "line":
			continue
		if first_line == "":
			first_line = id
		if sketch.is_construction(id) and construction == "":
			construction = id
	return construction if construction != "" else first_line


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
	# Commit as a kernel spline entity (fit points). Preview samples the same
	# GeomAPI_Interpolate curve.
	var fit: PackedVector2Array = []
	for p in _spline_pts:
		fit.push_back(p)
	if fit.size() >= 2:
		sketch.add_spline(fit)
	_spline_pts.clear()
	_redraw()


func spline_handle_mode() -> String:
	return spline_edit.mode


func set_spline_handle_mode(mode: String) -> void:
	spline_edit.set_mode(mode)
	_redraw()
	_update_preview()
	if selected.size() == 1:
		var info: Dictionary = sketch.entity_info(selected[0])
		if info.get("type", "") == "spline":
			status.emit(_SketchSplineEdit.property_label(info) + " — " + spline_edit.mode)


func toggle_spline_comb() -> bool:
	var on := spline_edit.toggle_comb()
	_redraw()
	_update_preview()
	status.emit("Curvature comb " + ("on" if on else "off"))
	return on


func spline_property_label() -> String:
	if sketch == null or selected.size() != 1:
		return ""
	var info: Dictionary = sketch.entity_info(selected[0])
	if info.get("type", "") != "spline":
		return ""
	return _SketchSplineEdit.property_label(info)


func _spline_handle_pos(info: Dictionary, part: String) -> Vector2:
	if part.begins_with("fit:"):
		var fits: Array = info.get("fit_points", [])
		var i := int(part.substr(4))
		if i >= 0 and i < fits.size():
			return fits[i]
	elif part.begins_with("pole:"):
		var poles: Array = info.get("poles", [])
		var j := int(part.substr(5))
		if j >= 0 and j < poles.size():
			return poles[j]
	elif part == "tan_start":
		return (info.get("start", Vector2.ZERO) as Vector2) + (info.get("start_tangent", Vector2.ZERO) as Vector2)
	elif part == "tan_end":
		return (info.get("end", Vector2.ZERO) as Vector2) + (info.get("end_tangent", Vector2.ZERO) as Vector2)
	return Vector2.ZERO


## Dense polyline of the kernel interpolating spline (same curve as the solid).
func _densify_fit_spline(pts: Array[Vector2]) -> Array[Vector2]:
	var densified: Array[Vector2] = []
	if pts.size() < 2:
		return densified
	var fit := PackedVector2Array()
	for p in pts:
		fit.append(p)
	if sketch != null and sketch.has_method("interpolate_spline"):
		var sampled: PackedVector2Array = sketch.interpolate_spline(fit, maxi(16, pts.size() * 8))
		for i in range(sampled.size()):
			densified.append(sampled[i])
		if densified.size() >= 2:
			return densified
	return pts.duplicate()


## Trim the entity nearest to pos2 at its intersections. Returns true on success.
## A construction centreline within 40 mm opens the jaw on the clicked side.
## Kernel trim uses a construction cutter only when solid hits are fewer than two.
func trim_at(pos2: Vector2) -> bool:
	if not active or sketch == null:
		status.emit("Trim failed")
		return false
	if _trim_open_jaw(pos2):
		return true
	var id := _nearest_trim_entity_at(pos2)
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
	var pre_lines := _snapshot_line_geometry()
	run_solve()
	# Hex trim around the ring must not DogLeg the C jaws 240 mm away.
	# Only when the C (ellipse) is present — a wrench jaw has no ellipse,
	# and restoring distant lines there leaves extra glyphs / 22.5 callouts.
	# Skip only the trimmed entity: a click-radius skip also ignored the C
	# jaws when Power Trim ran on the handle overflow next to them.
	if _profile_has_type("elliptical_arc") or _profile_has_type("ellipse"):
		_restore_untrimmed_line_drift(pre_lines, id)
		_weld_nearby_curve_joints(0.8)
	_drop_stale_dimensions()
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
		var d := SketchGeom.point_line_distance(p, a, b)
		if d > best_d:
			continue
		if SketchGeom.point_segment_distance(p, a, b) > max_dist + a.distance_to(b):
			continue
		best_d = d
		best = {"id": id, "a": a, "b": b}
	return best


## Model-edge circles on this sketch plane (centre + radius), for jaw trim
## when the Ø45 rim was not redrawn as a sketch circle.
func _model_circles() -> Array:
	var out: Array = []
	for row in _kernel_plane_circles():
		var r := float(row.get("radius", 0.0))
		if r < 0.4:
			continue
		out.append({
			"center": plane.to_uv(row["center"] as Vector3),
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
	if SketchGeom.point_line_distance(c, a, b) > JAW_CUTTER_MAX_RIM_FRACTION * r:
		return false
	return SketchGeom.point_segment_distance(c, a, b) <= r + 1.0


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
			best_d = SketchGeom.point_line_distance(info["center"], a, b)
	for mc in _model_circles():
		var r2 := float(mc["radius"])
		if r2 > best_r:
			best_r = r2
			best_d = SketchGeom.point_line_distance(mc["center"], a, b)
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
		# Shaft Lines carry a tangent pin and are ~200 mm. A 20 mm jaw wall
		# may also pick up Tangent to the head circle; those stay walls.
		if _entity_has_constraint(id, "tangent") and L > 80.0:
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
			var d := SketchGeom.point_segment_distance(pos2, a, b)
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
		if SketchGeom.point_segment_distance(pos2, s["a"], s["b"]) <= PICK_TOLERANCE * 2.0:
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


## True when Power Trim is aimed at an ellipse / remaining elliptical arc.
func _ellipse_under_trim(pos2: Vector2) -> bool:
	if sketch == null:
		return false
	var hit := _nearest_entity_at(pos2)
	if hit == "":
		return false
	var kind := str(sketch.entity_info(hit).get("type", ""))
	return kind == "ellipse" or kind == "elliptical_arc"


## Click on one side of a construction centreline: drop that half, keep the
## other, close it with a floor on the cutter and the keep-side arc of the
## circle centred on the cutter. The Ø10 (centre far from the cutter) stays.
func _profile_has_type(kind: String) -> bool:
	if sketch == null:
		return false
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) == kind:
			return true
	return false


func _trim_open_jaw(pos2: Vector2) -> bool:
	# Jaw mouth trim is two long parallel walls plus a centreline. A tangent
	# path circle (hex key) is ordinary trim-to-closest, not this opener.
	# An ellipse under the pointer is the spanner C, not a wrench-jaw opener.
	if _ellipse_under_trim(pos2):
		return false
	# Spanner C is an elliptical arc; the pliers jaw opener has none. With
	# the C present, Power Trim at Ø33 is hex 12-point, not a mouth cut.
	if _profile_has_type("elliptical_arc") or _profile_has_type("ellipse"):
		return false
	var sides := _jaw_long_sides()
	if sides.size() != 2:
		return false
	# C jaws at the origin plus a CL through Ø33 at x=240 used to steal hex
	# Power Trim: the opener saw the 17° pair as walls and Ø33 as the head.
	var near_wall := false
	for side in sides:
		var wa: Vector2 = side["a"]
		var wb: Vector2 = side["b"]
		if SketchGeom.point_segment_distance(pos2, wa, wb) <= 40.0:
			near_wall = true
			break
	if not near_wall:
		return false
	# After the mouth is open the cutter is gone. A later Trim on the walls
	# must not fall through to kernel trim (that reports a plain "Trimmed").
	if _jaw_ids_alive():
		_hide_infer_hint()
		status.emit("Jaw is already open — nothing left to trim here")
		return true
	var cutter := _jaw_cutter_for_click(pos2)
	if cutter.is_empty():
		return false
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
		# Shaft lines (longer than the cutter) sit entirely on one side of a
		# head-mouth cutter. They are not the discarded jaw half.
		var shaft_like := side_dir.length() > a.distance_to(b) * 1.25
		if is_cap:
			# Caps stay off the wall list even when a slight skew puts their
			# endpoints on opposite sides of the cutter.
			if (s_disc or absf(ss) <= EPS) and (e_disc or absf(es) <= EPS) and (s_disc or e_disc):
				if not shaft_like:
					to_delete.append(id)
			elif s_keep and e_keep and not shaft_like:
				to_delete.append(id)
			continue
		if (s_disc or absf(ss) <= EPS) and (e_disc or absf(es) <= EPS) and (s_disc or e_disc):
			if not shaft_like:
				to_delete.append(id)
			continue
		if s_keep and e_keep:
			if not shaft_like:
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
		if str(dim.get("callout", "")) == "jaw_width":
			jaw_width = float(dim.get("value", 0.0))
			have_width = true
			break
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
		jaw_width = walls[0]["hit"].distance_to(walls[1]["hit"])
	jaw_width = snappedf(jaw_width, 0.01)
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
	if not _entity_has_constraint(str(walls[0]["id"]), "parallel"):
		sketch.add_constraint("parallel", [
			{"entity": str(walls[0]["id"]), "role": "self"},
			{"entity": str(walls[1]["id"]), "role": "self"}], 0.0)
	var ang := jaw_angle
	# The rectangle already drives this wall. A second angle is a second 45°
	# and a redundant solve. Keep the one the user edited; it is the one
	# Save restores. Add a constraint only when the wall has none.
	var ang_cid := ""
	for cid in sketch.constraint_ids():
		var cinfo: Dictionary = sketch.constraint_info(str(cid))
		if cinfo.is_empty() or str(cinfo.get("type", "")) != "angle":
			continue
		for ref in cinfo.get("refs", []):
			if typeof(ref) == TYPE_DICTIONARY and wall_ids.has(str(ref.get("entity", ""))):
				ang_cid = str(cid)
				break
		if ang_cid != "":
			break
	if ang_cid == "":
		var hx: String = sketch.add_line(cc.x - 8.0, cc.y, cc.x + 8.0, cc.y)
		sketch.set_construction(hx, true)
		_angle_datum_lines[hx] = true
		sketch.add_constraint("horizontal", [{"entity": hx, "role": "self"}], 0.0)
		ang_cid = sketch.add_constraint("angle", [
			{"entity": hx, "role": "self"},
			{"entity": str(walls[0]["id"]), "role": "self"}], ang)
		_record_dimension("angle", [hx, str(walls[0]["id"])], _normalize_jaw_angle_rad(ang), ang_cid, "jaw_angle")
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "circle" or sketch.is_construction(id):
			continue
		if (info["center"] as Vector2).distance_to(Vector2.ZERO) > 1.0:
			continue
		var hole_r := float(info.get("radius", 1.0))
		if not _entity_has_constraint(id, "radius"):
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
	_drop_stale_dimensions()
	_coincident_keep.clear()
	_set_selected([])
	_redraw()
	_redraw_selected()
	_trim_jaw_done_in_drag = true
	_hide_infer_hint()
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
	# CCW from the wall-matched ends is the long way around the head when the
	# mouth is the short cap. That bulge cuts the head down to the wall tips
	# (231×31 instead of 232.5×45). Keep the minor sweep, and retarget the
	# coincident roles so the next solve does not flip the bulge back.
	var ang := _jaw_ccw_angles(center, s0, s1)
	var sweep := wrapf(ang.y - ang.x, 0.0, TAU)
	if sweep > PI:
		ang = _jaw_ccw_angles(center, s1, s0)
		var swapped: Vector2 = s0
		s0 = s1
		s1 = swapped
	sketch.set_entity_geometry(arc_id, {
		"start": s0,
		"end": s1,
		"start_angle": ang.x,
		"end_angle": ang.y,
	})
	_rebind_arc_wall_ends(arc_id, walls)


## Point each arc end at the wall tip it actually sits on. A minor-sweep swap
## changes which end is start; leaving the old coincident roles makes the
## next solve walk the bulge the long way around the head.
func _rebind_arc_wall_ends(arc_id: String, walls: Array) -> void:
	if sketch == null or walls.size() != 2 or not sketch.has_method("constraint_ids"):
		return
	var ainfo: Dictionary = sketch.entity_info(arc_id)
	if ainfo.is_empty():
		return
	var start: Vector2 = ainfo["start"]
	var endp: Vector2 = ainfo["end"]
	var ids: PackedStringArray = sketch.constraint_ids()
	for cid in ids:
		var info: Dictionary = sketch.constraint_info(str(cid))
		if info.is_empty() or str(info.get("type", "")) != "coincident":
			continue
		var refs: Array = info.get("refs", [])
		var names_end := false
		for ref in refs:
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			if str(ref.get("entity", "")) == arc_id and str(ref.get("role", "")) in ["start", "end"]:
				names_end = true
				break
		if names_end:
			sketch.remove_constraint(str(cid))
	var w0 := str(walls[0]["id"])
	var w1 := str(walls[1]["id"])
	var e0: Vector2 = sketch.entity_info(w0)["end"]
	var start_on_w0 := start.distance_to(e0) <= endp.distance_to(e0)
	sketch.add_constraint("coincident", [
		{"entity": arc_id, "role": "start" if start_on_w0 else "end"},
		{"entity": w0, "role": "end"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": arc_id, "role": "end" if start_on_w0 else "start"},
		{"entity": w1, "role": "end"}], 0.0)


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
## Snap line ends onto nearby arc / elliptical-arc ends so a 0.05 mm gap
## (the open-profile weld) does not leave the C or handle strip open.
func _weld_nearby_curve_joints(tol: float = 0.05) -> void:
	if sketch == null:
		return
	var curves: Array = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind != "arc" and kind != "elliptical_arc":
			continue
		if not info.has("start") or not info.has("end"):
			continue
		curves.append({"id": id, "a": info["start"], "b": info["end"]})
	if curves.is_empty():
		return
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		var ns := s
		var ne := e
		var changed := false
		for curve in curves:
			if s.distance_to(curve["a"]) <= tol and s.distance_to(curve["a"]) > 1e-9:
				ns = curve["a"]
				changed = true
			elif s.distance_to(curve["b"]) <= tol and s.distance_to(curve["b"]) > 1e-9:
				ns = curve["b"]
				changed = true
			if e.distance_to(curve["a"]) <= tol and e.distance_to(curve["a"]) > 1e-9:
				ne = curve["a"]
				changed = true
			elif e.distance_to(curve["b"]) <= tol and e.distance_to(curve["b"]) > 1e-9:
				ne = curve["b"]
				changed = true
		if changed:
			sketch.set_entity_geometry(id, {"start": ns, "end": ne})


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
				# Stadium bosses (wrench Ø45 chord + Ø20 tangent). A lone
				# chord (spanner handle on Ø33, far end on the ellipse) stays
				# a circle so the ring remains a hole.
				if not _far_end_on_other_circle(other, c, circles, 0.05):
					continue
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


## True when `other` lies on a different circle than `self_c` (the far boss
## of a two-circle stadium). Chord hits whose far end is not on a circle
## (handle on Ø33) must not seal.
func _far_end_on_other_circle(other: Vector2, self_c: Vector2, circles: Array, tol: float) -> bool:
	for circ in circles:
		if typeof(circ) != TYPE_DICTIONARY:
			continue
		var oc: Vector2 = circ["c"]
		if oc.distance_to(self_c) <= tol:
			continue
		if absf(other.distance_to(oc) - float(circ["r"])) <= tol:
			return true
	return false


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


## Kept for jaw-cutter replacement. Do not call from Line/Centerline commit:
## rung 7 needs the horizontal CL and the 17° construction together.
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


## When a new centreline is a jaw cutter, drop the previous leftover cutter
## (along-jaw or an earlier offset). Angle-datum lines and the rung 7 CL / 17°
## construction are not cutter candidates, so they stay.
func _drop_replaced_jaw_cutter_construction(keep_id: String) -> void:
	if sketch == null or keep_id == "":
		return
	var sides := _jaw_long_sides()
	if sides.size() != 2:
		return
	var keep_info: Dictionary = sketch.entity_info(keep_id)
	if str(keep_info.get("type", "")) != "line":
		return
	if not _line_is_jaw_cutter_candidate(keep_info["start"], keep_info["end"], sides):
		return
	var drop: Array[String] = []
	for id in sketch.entity_ids():
		if id == keep_id or _angle_datum_lines.has(id):
			continue
		if not sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		if _line_is_jaw_cutter_candidate(info["start"], info["end"], sides):
			drop.append(id)
	for id in drop:
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
		"arc":
			if role == "start" and info.has("start"):
				return info["start"]
			if role == "end" and info.has("end"):
				return info["end"]
			return info["center"]
		"ellipse":
			if role == "start" and info.has("major_start"):
				return info["major_start"]
			if role == "end" and info.has("major_end"):
				return info["major_end"]
			return info.get("center", Vector2.ZERO)
		"elliptical_arc":
			if role == "start" and info.has("start"):
				return info["start"]
			if role == "end" and info.has("end"):
				return info["end"]
			return info.get("center", Vector2.ZERO)
		"circle":
			return info["center"]
		"spline":
			var fits: Array = info.get("fit_points", [])
			if role == "start" and not fits.is_empty():
				return fits[0]
			if role == "end" and not fits.is_empty():
				return fits[fits.size() - 1]
			return info.get("start", Vector2.ZERO)
	return info.get("position", Vector2.ZERO)


func _is_curve_kind(kind: String) -> bool:
	return kind == "circle" or kind == "arc" or kind == "ellipse" or kind == "elliptical_arc"


func _point_roles_for(id: String) -> Array[String]:
	var k: String = sketch.entity_info(id).get("type", "")
	var out: Array[String] = []
	if k == "line":
		out.assign(["start", "end"])
	elif k == "point":
		out.assign(["self"])
	elif k == "spline":
		out.assign(["start", "end"])
	elif _is_curve_kind(k):
		out.assign(["center"])
	else:
		out.assign(["self"])
	return out


## Roles of the closest endpoint pair between two entities (["end","start"]...).
## A curve Self is point-on-curve when that hit is closer than the centre.
func _closest_endpoints(id_a: String, id_b: String) -> Array[String]:
	var ka: String = sketch.entity_info(id_a).get("type", "")
	var kb: String = sketch.entity_info(id_b).get("type", "")
	if _is_curve_kind(ka) != _is_curve_kind(kb):
		var curve_id := id_a if _is_curve_kind(ka) else id_b
		var other_id := id_b if _is_curve_kind(ka) else id_a
		var centre := _endpoint_pos(curve_id, "center")
		var best := INF
		var best_role := ""
		var on_curve := false
		for role: String in _point_roles_for(other_id):
			var p := _endpoint_pos(other_id, role)
			var d_curve := closest_on_entity(curve_id, p).distance_to(p)
			if d_curve < best:
				best = d_curve
				best_role = role
				on_curve = d_curve + 1.0e-6 < p.distance_to(centre)
		if best_role == "":
			var none: Array[String] = []
			return none
		var curve_role := "self" if on_curve else "center"
		var roles: Array[String] = []
		if _is_curve_kind(ka):
			roles.assign([curve_role, best_role])
		else:
			roles.assign([best_role, curve_role])
		return roles
	var best := INF
	var pair: Array[String] = []
	for ra: String in _point_roles_for(id_a):
		for rb: String in _point_roles_for(id_b):
			var d := _endpoint_pos(id_a, ra).distance_to(_endpoint_pos(id_b, rb))
			if d < best:
				best = d
				pair = [ra, rb]
	return pair


## Coincident with only a strip selected: weld each end that already sits on
## a circle / arc / ellipse (handle-C at y=±10, handle-Ø33 at the chord).
func _coincident_line_to_curve() -> String:
	if sketch == null:
		return ""
	const ON_CURVE_MM := 1.25
	var cid := ""
	for id in selected:
		if sketch.is_construction(id):
			continue
		if str(sketch.entity_info(id).get("type", "")) != "line":
			continue
		for role: String in ["start", "end"]:
			var p := _endpoint_pos(id, role)
			var curve_id := ""
			var best_d := ON_CURVE_MM
			for oid in sketch.entity_ids():
				if oid == id or sketch.is_construction(oid):
					continue
				var info: Dictionary = sketch.entity_info(oid)
				if not _is_curve_kind(str(info.get("type", ""))):
					continue
				var d := _entity_distance(info, p)
				if d < best_d:
					best_d = d
					curve_id = str(oid)
			if curve_id == "":
				continue
			cid = sketch.add_constraint("coincident", [
				{"entity": id, "role": role},
				{"entity": curve_id, "role": "self"}], 0.0)
	return cid


func _redraw_selected() -> void:
	if sketch == null or selected.is_empty():
		_selected_node.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var any := false
	for id in selected:
		var info: Dictionary = sketch.entity_info(id)
		if info.is_empty():
			continue
		_append_entity_lines(im, info)
		if info.get("type", "") == "spline":
			_append_spline_edit_lines(im, info)
		any = true
	if not any:
		_selected_node.mesh = null
		return
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
const CONTOUR_TAG_CLEAR_PX := 4.0


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
	var tag := ""
	if _contour_tag != null and _contour_tag.visible:
		tag = _contour_tag.text
	return {
		"count": _contour_fill_alphas.size(),
		"included": _contour_included.duplicate(),
		"focus": _contour_focus,
		"fills": _contour_fill_alphas.duplicate(),
		"outlines": _contour_outline_count,
		"tag": tag,
	}


var _contour_tag_leader := false
var _contour_tag_leader_from := Vector2.ZERO


## Interior point with the most screen clearance to every contour outline.
## A tag that cannot clear its own outline by 4 px sits outside, with a leader.
func _contour_tag_anchor(region: Dictionary, text: String) -> Vector2:
	var centre: Vector2 = region["center"]
	_contour_tag_leader = false
	_contour_tag_leader_from = centre
	var holes: Array = region.get("holes", [])
	var outer: PackedVector2Array = region["outer"]
	if camera == null or not is_inside_tree():
		return centre
	var tris := _contour_fill_triangles(outer, holes)
	var candidates: Array[Vector2] = []
	var i := 0
	while i + 2 < tris.size():
		candidates.append((tris[i] + tris[i + 1] + tris[i + 2]) / 3.0)
		i += 3
	if candidates.is_empty():
		candidates.append(centre)
	var loops := _all_contour_loops()
	var best := candidates[0]
	var best_clear := -1.0
	for c in candidates:
		var rect := _contour_tag_screen_rect(c, text)
		var clear := _loops_screen_clearance(loops, rect)
		if clear > best_clear:
			best_clear = clear
			best = c
	if best_clear + 0.01 >= CONTOUR_TAG_CLEAR_PX:
		return best
	return _contour_tag_outside(outer, text, loops, centre)


func _all_contour_loops() -> Array:
	var loops: Array = []
	for region in _contour_regions():
		if typeof(region) != TYPE_DICTIONARY:
			continue
		loops.append(region.get("outer", PackedVector2Array()))
		for hole in region.get("holes", []):
			loops.append(hole)
	return loops


func _contour_tag_outside(outer: PackedVector2Array, text: String, loops: Array,
		centre: Vector2) -> Vector2:
	var ppm := 1.0
	if camera != null and camera.has_method("pixels_per_mm_at_pivot"):
		ppm = maxf(float(camera.pixels_per_mm_at_pivot()), 0.05)
	var probe := _contour_tag_screen_rect(centre, text)
	var reach := (maxf(probe.size.x, probe.size.y) * 0.5 + CONTOUR_TAG_CLEAR_PX + 2.0) / ppm
	var best := centre
	var best_score := INF
	var n := outer.size()
	for i in n:
		var a: Vector2 = outer[i]
		var b: Vector2 = outer[(i + 1) % n]
		var edge := b - a
		if edge.length_squared() < 1e-8:
			continue
		var mid := (a + b) * 0.5
		var nrm := Vector2(-edge.y, edge.x).normalized()
		if (mid + nrm).distance_to(centre) < (mid - nrm).distance_to(centre):
			nrm = -nrm
		for step in [1.0, 1.5, 2.2]:
			var opt: Vector2 = mid + nrm * reach * step
			if outer.size() >= 3 and Geometry2D.is_point_in_polygon(opt, outer):
				continue
			var rect := _contour_tag_screen_rect(opt, text)
			var clear := _loops_screen_clearance(loops, rect)
			if clear + 0.01 < CONTOUR_TAG_CLEAR_PX:
				continue
			var score := opt.distance_to(centre)
			if score < best_score:
				best_score = score
				best = opt
				_contour_tag_leader_from = mid
	_contour_tag_leader = true
	if best_score >= INF * 0.5:
		var fallback := centre
		if n >= 2:
			var a0: Vector2 = outer[0]
			var b0: Vector2 = outer[1]
			var mid0 := (a0 + b0) * 0.5
			var edge0 := b0 - a0
			var nrm0 := Vector2(-edge0.y, edge0.x).normalized() if edge0.length_squared() > 1e-8 else Vector2.UP
			if (mid0 + nrm0).distance_to(centre) < (mid0 - nrm0).distance_to(centre):
				nrm0 = -nrm0
			fallback = mid0 + nrm0 * reach
			_contour_tag_leader_from = mid0
		return fallback
	return best


func _contour_tag_screen_rect(anchor: Vector2, text: String) -> Rect2:
	var sp := camera.unproject_position(to_global(_to3(anchor)))
	var size := _dimension_label_size_px(text) * _label_px_scale(camera)
	return Rect2(sp - size * 0.5, size)

func _loops_screen_clearance(loops: Array, rect: Rect2) -> float:
	var best := 1e9
	for loop in loops:
		var poly: PackedVector2Array = loop
		if poly.size() < 2:
			continue
		for j in poly.size():
			var a := _sketch_point_screen(poly[j])
			var b := _sketch_point_screen(poly[(j + 1) % poly.size()])
			best = minf(best, SketchGeom.segment_rect_distance(a, b, rect))
	return best


func _sketch_point_screen(p: Vector2) -> Vector2:
	return camera.unproject_position(to_global(_to3(p)))


func _contour_regions() -> Array:
	if sketch == null:
		return []
	var sig := _contour_geom_sig() + "|" + host_face_id
	if _contour_cache_sig != sig:
		if host_face_id != "" and view != null and view.doc != null \
				and view.doc.has_method("sketch_region_outlines"):
			_contour_cache = view.doc.sketch_region_outlines(sketch, host_face_id)
		elif sketch.has_method("contour_outlines"):
			_contour_cache = sketch.contour_outlines()
		else:
			_contour_cache = []
		_contour_cache_sig = sig
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
		_contour_tag.set_meta("leader", false)
	var regions := _contour_regions()
	var show := not _contour_included.is_empty() or _contour_bar_visible()
	if sketch == null or regions.is_empty() or not show:
		if _contour_node != null:
			_contour_node.mesh = null
		return
	if _contour_node == null:
		for i in regions.size():
			var on := _contour_is_on(i)
			var focused := i == _contour_focus
			var fill_alpha := 0.0
			if on:
				fill_alpha = CONTOUR_FOCUS_ALPHA if focused else CONTOUR_FILL_ALPHA
			_contour_fill_alphas.append(fill_alpha)
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
	var tag_text := ""
	var tag_uv := Vector2.ZERO
	var draw_tag := false
	if _contour_focus >= 0 and _contour_focus < regions.size() and _contour_tag != null:
		var focused_region: Dictionary = regions[_contour_focus]
		tag_text = str(_contour_focus + 1)
		tag_uv = _contour_tag_anchor(focused_region, tag_text)
		draw_tag = true
		if _contour_tag_leader:
			var leader_col: Color = CONTOUR_COLORS[_contour_focus % CONTOUR_COLORS.size()]
			leader_col.a = 1.0
			lines.append(_contour_tag_leader_from)
			lines.append(tag_uv)
			line_cols.append(leader_col)
			line_cols.append(leader_col)
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
	if draw_tag and _contour_tag != null:
		_contour_tag.text = tag_text
		_contour_tag.position = _to3(tag_uv)
		_contour_tag.modulate = CONTOUR_COLORS[_contour_focus % CONTOUR_COLORS.size()]
		_contour_tag.set_meta("leader", _contour_tag_leader)
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
	# An in-progress Jaw (click 2 already down) must place click 3 too. The
	# 8 px pad around a shaft "22.5" covers the half-width point, and opening
	# that editor drops the gesture.
	var place_point := tool == Tool.LINE or tool == Tool.CENTERLINE \
			or tool == Tool.ARC \
			or tool == Tool.MIRROR \
			or has_pending_draw_point()
	var dhit_raw := -1
	if not place_point:
		dhit_raw = dimension_hit(pos2, tool != Tool.SELECT and tool != Tool.SMART_DIM)
	# A stacked Ø45 radius label walks onto the top rim. Select still picks
	# that circle; the editor opens only when the click is not on its rim.
	# A typed radius commits through click(_hover). A callout under that
	# hover must not open the editor and drop the circle.
	# A 22 px / 6 mm halo around a callout used to steal a click that was
	# already on a curve. At 1280×800 the upper shaft line's midpoint sits
	# in that halo, so Select opened a broken editor and reported no
	# entities. The text rect still opens the editor. The curve wins when
	# the pointer is on it and only the halo matches.
	if dhit_raw >= 0 and _length_override < 0.0 and _dimension_claims_click(pos2, dhit_raw):
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
			# A badge parked beside a short edge can cover the vertex. The nearer
			# target wins: the endpoint when the click is on it, the badge when
			# the click is on the badge. Coincident uses the same rule so a hex
			# vertex press still picks the point (Vertical), while n21 clicks
			# the published glyph centre.
			var chit := constraint_hit(select_pos)
			if chit != "" and not _endpoint_nearer_than_glyph(select_pos, chit):
				select_constraint(chit)
				return
			if selected_constraint != "":
				select_constraint("")
			var dhit := dimension_hit(select_pos)
			if dhit >= 0 and _dimension_claims_click(select_pos, dhit):
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
				var lid: String = sketch.add_line(a.x, a.y, b.x, b.y)
				remember_numeric(a.distance_to(b))
				if as_centreline:
					sketch.set_construction(lid, true)
					# One leftover jaw cutter at a time (along-jaw then the
					# offset retry). Keep the rung 7 CL + 17° — those are not
					# jaw-cutter candidates.
					_drop_replaced_jaw_cutter_construction(lid)
					# Two-point centreline: do not extend the next click.
					_tool_points.clear()
				_infer_line(lid, a, b)
				_hide_infer_hint()
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
			if _tool_points.size() == 1:
				status.emit(POLYGON_CENTRE_SET)
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
						PolygonPose.regularize(sketch, lids)
						if c.length() <= SketchOriginAnchor.ORIGIN_PIN_TOL:
							SketchOriginAnchor.apply(sketch, lids, "polygon.af", c)
							PolygonPose.inscribed_circle(sketch, lids)
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
			if _tool_points.size() == 3:
				var eid := SketchEllipse.build(sketch, _tool_points[0], _tool_points[1], _tool_points[2])
				if eid != "":
					_coincident_ellipse_to_path(eid, _tool_points[0])
					var info: Dictionary = sketch.entity_info(eid)
					remember_numeric(float(info.get("rx", 0.0)) * 2.0)
					run_solve()
				else:
					status.emit("Ellipse: major and minor must be positive")
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
			_convert_edge_click(pos2)
		Tool.OFFSET:
			_offset_click(pos2)
		Tool.MIRROR:
			# Selection must already include axis + geometry; click confirms.
			mirror_selected()
		Tool.PATTERN:
			if tool_variant == "circular":
				_pattern_centre_click(pos2)
			else:
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
				var had := {}
				for existing in sketch.entity_ids():
					had[str(existing)] = true
				_add_rect_lines(a, b)
				if infer_enabled:
					var added: Array[String] = []
					for existing in sketch.entity_ids():
						if not had.has(str(existing)):
							added.append(str(existing))
					SketchOriginAnchor.apply(sketch, added, "rect.center", c)
					run_solve()
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
				var tangent := tool_variant == "perimeter" \
						and SketchCircleTangent.two_lines(sketch, p1, p2, _pick_tolerance())
				if tangent:
					_place_tangent_circle(p1, p2, p3)
				else:
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
					if infer_enabled and circ_id != "":
						SketchOriginAnchor.apply(sketch, [circ_id], "circle.center", c)
						run_solve()
					if typed and circ_id != "":
						var rcid: String = sketch.add_constraint(
								"radius", [{"entity": circ_id, "role": "self"}], r)
						_record_dimension("radius", [circ_id], r, rcid)
				_tool_points.clear()
	_redraw()


## Two line picks and a side click. A zero inset adds no circle.
func _place_tangent_circle(p1: Vector2, p2: Vector2, side: Vector2) -> void:
	var circ_id := SketchCircleTangent.build(sketch, p1, p2, side, _pick_tolerance())
	if circ_id == "":
		status.emit("Circle refused")
		return
	var r := float(sketch.entity_info(circ_id).get("radius", 0.0))
	circle_radius = r
	_last_commit_text = "Tangent circle Ø%.4f" % (r * 2.0)
	status.emit(_last_commit_text)
	run_solve()


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
				var aid := SketchTangentArc.add_three_point(
						sketch, p1, p2, p3, _snap_radius())
				if aid != "":
					var info: Dictionary = sketch.entity_info(aid)
					remember_numeric(float(info.get("radius", 0.0)))
					run_solve()
				_tool_points.clear()
		"tangent":
			# First click near existing curve endpoint; second = end.
			if _tool_points.size() == 2:
				var start_pt := _tool_points[0]
				var end_pt := _tool_points[1]
				var aid := SketchTangentArc.build(sketch, start_pt, end_pt, _snap_radius())
				if aid != "":
					var info: Dictionary = sketch.entity_info(aid)
					remember_numeric(float(info.get("radius", 0.0)))
					run_solve()
				else:
					# Empty-space two clicks still make a free arc (no host).
					var chord := end_pt - start_pt
					var r_free := chord.length() * 0.5
					if r_free > 1e-6:
						var mid := (start_pt + end_pt) * 0.5
						var n := Vector2(-chord.y, chord.x).normalized()
						var c := mid + n * r_free
						remember_numeric(r_free)
						sketch.add_arc(c.x, c.y, r_free, (start_pt - c).angle(), (end_pt - c).angle())
					else:
						status.emit("Tangent Arc: radius must be positive")
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
	_hide_infer_hint()
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
	_hide_infer_hint()
	if not active or sketch == null:
		return ""
	# Convert / Offset / Pattern Esc drops the tool. A leftover selection
	# would spend that key on "selection cleared" and leave the panel armed.
	if tool == Tool.CONVERT or tool == Tool.OFFSET or tool == Tool.PATTERN:
		set_tool(Tool.SELECT)
		return "Tool dropped — Esc again exits the sketch"
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


func _convert_edge_click(uv: Vector2) -> void:
	_convert_silhouette_at(uv)


## Project a silhouette / pierce edge at `uv`. Returns the new entity id.
func _convert_silhouette_at(uv: Vector2) -> String:
	if sketch == null or view == null or view.doc == null:
		return ""
	var ctx := SketchConvertEdge.Context.new()
	ctx.doc = view.doc
	ctx.view = view
	ctx.plane = plane
	ctx.sketch = sketch
	ctx.host_face_id = host_face_id
	ctx.support_host = support_host
	ctx.support_normal = support_normal
	ctx.ensure_feature = _ensure_sketch_feature
	ctx.adopt = _adopt_converted_sketch
	ctx.commit = func(label: String) -> void:
		_undo_note(label)
		run_solve()
		_redraw()
	ctx.status = func(text: String) -> void:
		status.emit(text)
	ctx.fallback = convert_pierce_points
	var id := SketchConvertEdge.new(ctx).click(uv)
	host_face_id = ctx.host_face_id
	return id


func _offset_click(uv: Vector2) -> void:
	if offset_ui == null or sketch == null or view == null or view.doc == null:
		return
	var ctx := SketchOffset.Context.new()
	ctx.doc = view.doc
	ctx.view = view
	ctx.plane = plane
	ctx.sketch = sketch
	ctx.host_face_id = host_face_id
	ctx.support_host = support_host
	ctx.support_normal = support_normal
	ctx.ensure_feature = _ensure_sketch_feature
	ctx.adopt = _adopt_converted_sketch
	ctx.nearest_entity = _nearest_entity_at
	ctx.pick_tol = _pick_tolerance()
	ctx.selected = selected.duplicate()
	ctx.commit = func(label: String) -> void:
		_undo_note(label)
		run_solve()
		_redraw()
	ctx.status = func(text: String) -> void:
		status.emit(text)
	offset_ui.click(ctx, uv)
	host_face_id = ctx.host_face_id


func _pattern_centre_click(uv: Vector2) -> void:
	if pattern_ui == null or sketch == null:
		return
	if pattern_ui.pick_centre(sketch, uv, _pick_tolerance()):
		status.emit("Pattern centre at (%.4f, %.4f)" % [pattern_ui.centre.x, pattern_ui.centre.y])
	else:
		status.emit("Pattern centre is the origin")


func _smart_dim_kind(ref: Dictionary) -> SmartDimTable.End:
	var id := str(ref.get("entity", ""))
	if id == "" or sketch == null:
		return null
	var role := str(ref.get("role", "self"))
	# An arc/line vertex is a point. BETWEEN + a line is then point_line
	# (candlestick path vertical 65 from the R150 end to the 60 mm line).
	if role == "start" or role == "end":
		return SmartDimTable.end_for("circle", "center", false)
	var info: Dictionary = sketch.entity_info(id)
	return SmartDimTable.end_for(str(info.get("type", "")), role, sketch.is_external(id))


func _click_smart_dim(pos2: Vector2) -> void:
	# Two already-selected lines: the click confirms angle or flat-to-flat.
	# Empty space or a re-click on one of them must not start a lone length.
	# Circle + line after centre-to-flat must not take this path — the next
	# click on the circle centre starts a new pending (rung 2 face edges 40).
	if selected.size() == 2 and _smart_dim_pending.is_empty():
		var t0 := str(sketch.entity_info(selected[0]).get("type", ""))
		var t1 := str(sketch.entity_info(selected[1]).get("type", ""))
		if t0 == "line" and t1 == "line":
			var hit_sel := _nearest_profile_entity_at(pos2)
			if hit_sel == "":
				hit_sel = _nearest_entity_at(pos2)
			if hit_sel == "" or hit_sel == str(selected[0]) or hit_sel == str(selected[1]):
				var a_ref := {"entity": selected[0], "role": "self"}
				var b_ref := {"entity": selected[1], "role": "self"}
				if _dispatch_smart_dim(SmartDimTable.Channel.SELECTION, a_ref, b_ref):
					_smart_dim_first = null
					return
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
	# Construction (the incircle) shares the flat's tangent point. The profile
	# line is the dimension the click asked for.
	var hit := _nearest_profile_entity_at(pos2)
	if hit == "":
		hit = _nearest_entity_at(pos2)
	if hit == "":
		var first := _smart_dim_pending
		if first.is_empty() and selected.size() == 1:
			first = {"entity": selected[0], "role": "self"}
		if not first.is_empty():
			var sid := _convert_silhouette_at(pos2)
			if sid != "":
				var second := {"entity": sid, "role": "self"}
				if _dispatch_smart_dim(SmartDimTable.Channel.BETWEEN, first, second):
					_smart_dim_pending.clear()
					_smart_dim_first = null
					return
			if not _smart_dim_pending.is_empty():
				status.emit(SMART_DIM_MISS_HINT)
				return
		_smart_dim_first = null
		return
	var hit_role := "self"
	if str(sketch.entity_info(hit).get("type", "")) == "arc":
		var ep := _endpoint_role_at(hit, pos2)
		if ep == "start" or ep == "end":
			hit_role = ep
	var hit_ref := {"entity": hit, "role": hit_role}
	if not _smart_dim_pending.is_empty():
		if str(_smart_dim_pending["entity"]) == hit \
				and str(_smart_dim_pending.get("role", "self")) == hit_role \
				and str(sketch.entity_info(hit).get("type", "")) in ["circle", "arc"]:
			status.emit(SMART_DIM_SAME_HINT)
			return
		var second := hit_ref
		if SmartDimTable.resolve(SmartDimTable.Channel.BETWEEN, _smart_dim_kind(_smart_dim_pending),
				_smart_dim_kind(hit_ref)).is_empty():
			var as_center := {"entity": hit, "role": "center"}
			if not SmartDimTable.resolve(SmartDimTable.Channel.BETWEEN, _smart_dim_kind(_smart_dim_pending),
					_smart_dim_kind(as_center)).is_empty():
				second = as_center
		if not _dispatch_smart_dim(SmartDimTable.Channel.BETWEEN, _smart_dim_pending, second):
			_set_selected([hit])
			_smart_dim_first = pos2
			_smart_dim_pending.clear()
			return
		_smart_dim_pending.clear()
		_smart_dim_first = null
		return
	# First pick on an arc vertex waits for the second pick. Curve clicks
	# still emit radius immediately (SINGLE ROUND).
	if hit_role == "start" or hit_role == "end":
		_smart_dim_pending = hit_ref
		_set_selected([hit])
		status.emit(SMART_DIM_PICK_HINT)
		_smart_dim_first = null
		return
	if selected.size() == 1 and str(selected[0]) != hit:
		var sel_ref := {"entity": selected[0], "role": "self"}
		if _dispatch_smart_dim(SmartDimTable.Channel.SELECTION, sel_ref, hit_ref):
			_smart_dim_first = null
			return
	var single := SmartDimTable.resolve(SmartDimTable.Channel.SINGLE, _smart_dim_kind(hit_ref))
	if single.is_empty():
		_set_selected([hit])
		_smart_dim_first = pos2
		_smart_dim_pending.clear()
		return
	if str(sketch.entity_info(hit).get("type", "")) == "ellipse":
		single["ellipse_axis"] = SketchEllipse.axis_at(sketch.entity_info(hit), pos2)
	_apply_smart_dim_single(hit_ref, single)
	_smart_dim_first = null


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
	_dispatch_smart_dim(SmartDimTable.Channel.BETWEEN, a, b)


func _dispatch_smart_dim(channel: SmartDimTable.Channel, a: Dictionary, b: Dictionary) -> bool:
	var ida := str(a.get("entity", ""))
	var idb := str(b.get("entity", ""))
	if ida == "" or idb == "":
		return false
	var hint := "parallel" if _lines_parallel(ida, idb) else ""
	var intent := SmartDimTable.resolve(channel, _smart_dim_kind(a), _smart_dim_kind(b), hint)
	if intent.is_empty():
		return false
	_set_selected([ida, idb])
	match str(intent.get("form", "")):
		"point_line":
			_apply_point_line_dim(a, b, intent)
		"parallel_distance":
			_apply_parallel_distance_dim(ida, idb, intent)
		"centres":
			_apply_centre_distance_dim(ida, idb, intent)
		"angle":
			_apply_angle_dim(ida, idb, intent)
		_:
			return false
	return true


func _drop_solo_line_length(entity_id: String) -> void:
	if sketch == null or entity_id == "":
		return
	var drop: Array[String] = []
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(str(cid))
		if str(info.get("type", "")) != "distance":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() != 2:
			continue
		var only := true
		for ref in refs:
			if typeof(ref) != TYPE_DICTIONARY or str(ref.get("entity", "")) != entity_id:
				only = false
		if only:
			drop.append(str(cid))
	for cid in drop:
		sketch.remove_constraint(cid)
	for i in range(dimensions.size() - 1, -1, -1):
		var ids: Array = dimensions[i].get("ids", [])
		if ids.size() == 1 and str(ids[0]) == entity_id and str(dimensions[i].get("type", "")) == "distance":
			dimensions.remove_at(i)


func _lines_parallel(ida: String, idb: String) -> bool:
	if _constraint_joins("parallel", ida, idb):
		return true
	var ia: Dictionary = sketch.entity_info(ida)
	var ib: Dictionary = sketch.entity_info(idb)
	if str(ia.get("type", "")) != "line" or str(ib.get("type", "")) != "line":
		return false
	var da: Vector2 = ia["end"] - ia["start"]
	var db: Vector2 = ib["end"] - ib["start"]
	if da.length_squared() < 1e-12 or db.length_squared() < 1e-12:
		return false
	return absf(da.cross(db)) <= 1e-4 * da.length() * db.length()


func _constraint_joins(kind: String, ida: String, idb: String) -> bool:
	if sketch == null or ida == "" or idb == "" or ida == idb:
		return false
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(str(cid))
		if str(info.get("type", "")) != kind:
			continue
		var hit_a := false
		var hit_b := false
		for ref in info.get("refs", []):
			if typeof(ref) != TYPE_DICTIONARY:
				continue
			var eid := str(ref.get("entity", ""))
			hit_a = hit_a or eid == ida
			hit_b = hit_b or eid == idb
		if hit_a and hit_b:
			return true
	return false


func _apply_parallel_distance_dim(ida: String, idb: String, intent: Dictionary) -> void:
	# The first line click armed a length. The flat-to-flat distance replaces it
	# so the hex keeps one driving dimension.
	_drop_solo_line_length(ida)
	_drop_solo_line_length(idb)
	var ia: Dictionary = sketch.entity_info(ida)
	var ib: Dictionary = sketch.entity_info(idb)
	var dist := SketchGeom.point_line_distance(ia["start"], ib["start"], ib["end"])
	var cid: String = sketch.add_constraint("distance", [
		{"entity": ida, "role": "start"},
		{"entity": idb, "role": "self"}], dist)
	var ids := [ida, idb]
	_record_dimension("distance", ids, dist, cid, "parallel_distance")
	_tag_label_anchor(intent, ids)
	_last_commit_text = "flat-to-flat %.4f" % dist
	status.emit(_last_commit_text)
	_undo_note("Dimension")
	run_solve()
	_redraw()


func _apply_smart_dim_single(ref: Dictionary, intent: Dictionary) -> void:
	_smart_dim_pending.clear()
	match str(intent.get("form", "")):
		"line_length":
			_apply_line_length_dim(ref, intent)
		"diameter":
			_apply_diameter_dim(ref, intent)
		"radius":
			_apply_radius_dim(ref, intent)


func _apply_line_length_dim(ref: Dictionary, intent: Dictionary) -> void:
	var hit := str(ref.get("entity", ""))
	var info: Dictionary = sketch.entity_info(hit)
	_set_selected([hit])
	constrain("distance", info["start"].distance_to(info["end"]))
	_tag_label_anchor(intent, [hit])
	# An axis-locked side (a rectangle's H/V) already has its angle. A second
	# angle-to-horizontal fights that lock and the length dim does not stick.
	if str(intent.get("also", "")) == "angle_to_horizontal" and not _line_locked_axis(hit):
		var mid: Vector2 = (info["start"] + info["end"]) * 0.5
		_add_angle_to_horizontal(hit, mid)
		run_solve()
		_redraw()


func _apply_diameter_dim(ref: Dictionary, intent: Dictionary) -> void:
	var hit := str(ref.get("entity", ""))
	var info: Dictionary = sketch.entity_info(hit)
	if str(info.get("type", "")) == "ellipse":
		var axis := str(intent.get("ellipse_axis", "major"))
		var a_role := "start" if axis == "major" else "minor_start"
		var b_role := "end" if axis == "major" else "minor_end"
		var a: Vector2 = info.get("major_start" if axis == "major" else "minor_start", Vector2.ZERO)
		var b: Vector2 = info.get("major_end" if axis == "major" else "minor_end", Vector2.ZERO)
		var cid := str(sketch.add_constraint("distance", [
			{"entity": hit, "role": a_role},
			{"entity": hit, "role": b_role}], a.distance_to(b)))
		if cid != "":
			_record_dimension("distance", [hit], a.distance_to(b), cid)
		run_solve()
		_redraw()
		_tag_label_anchor(intent, [hit])
		return
	_drop_size_constraints(hit, "radius")
	_set_selected([hit])
	constrain("diameter", float(info.get("radius", 5.0)) * 2.0)
	_tag_label_anchor(intent, [hit])


func _apply_radius_dim(ref: Dictionary, intent: Dictionary) -> void:
	var hit := str(ref.get("entity", ""))
	var info: Dictionary = sketch.entity_info(hit)
	_drop_size_constraints(hit, "diameter")
	_set_selected([hit])
	constrain("radius", float(info.get("radius", 5.0)))
	_tag_label_anchor(intent, [hit])


## A typed radius and a diameter are the same size twice. Smart Dim on a
## full circle keeps diameter; on an arc it keeps radius.
func _drop_size_constraints(entity_id: String, type: String) -> void:
	if sketch == null or entity_id == "":
		return
	var drop: Array[String] = []
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(str(cid))
		if str(info.get("type", "")) != type:
			continue
		for ref in info.get("refs", []):
			if str(ref.get("entity", "")) == entity_id:
				drop.append(str(cid))
				break
	for cid in drop:
		sketch.remove_constraint(cid)
	for i in range(dimensions.size() - 1, -1, -1):
		var dim: Dictionary = dimensions[i]
		if str(dim.get("type", "")) != type:
			continue
		var ids: Array = dim.get("ids", [])
		if not ids.is_empty() and str(ids[0]) == entity_id:
			dimensions.remove_at(i)


func _apply_point_line_dim(a: Dictionary, b: Dictionary, intent: Dictionary) -> void:
	var point: Dictionary = a if str(intent.get("point", "a")) == "a" else b
	var line: Dictionary = b if str(intent.get("point", "a")) == "a" else a
	if str(intent.get("point_role", "")) != "":
		point = point.duplicate()
		point["role"] = str(intent["point_role"])
	var line_id := str(line.get("entity", ""))
	var pref := _point_xy(point)
	var li: Dictionary = sketch.entity_info(line_id)
	var dist := SketchGeom.point_line_distance(pref, li["start"], li["end"])
	var cid: String = sketch.add_constraint("distance", [
		{"entity": str(point["entity"]), "role": str(point.get("role", "center"))},
		{"entity": line_id, "role": "self"}], dist)
	var ids := [str(point["entity"]), line_id]
	_record_dimension("distance", ids, dist, cid, "point_line")
	_tag_label_anchor(intent, ids)
	_last_commit_text = "centre-to-flat %.4f" % dist
	status.emit(_last_commit_text)
	_undo_note("Dimension")
	run_solve()
	_redraw()


func _apply_centre_distance_dim(ida: String, idb: String, intent: Dictionary) -> void:
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
	_tag_label_anchor(intent, [ida, idb])
	# A failed solve reverts the constraint. Do not open a popup on a
	# stale index — only emit when that centre distance is still live.
	var idx := _distance_dim_index_for(ida, idb)
	if idx >= 0:
		_emit_dimension_edit(idx)


func _apply_angle_dim(ida: String, idb: String, intent: Dictionary) -> void:
	constrain("angle", _lines_signed_angle(ida, idb))
	_tag_label_anchor(intent, [ida, idb])


func _tag_label_anchor(intent: Dictionary, ids: Array) -> void:
	var anchor := str(intent.get("label_anchor", ""))
	if anchor == "":
		return
	for i in range(dimensions.size() - 1, -1, -1):
		var dim: Dictionary = dimensions[i]
		var have: Array = dim.get("ids", [])
		if have.size() != ids.size():
			continue
		var same := true
		for j in ids.size():
			if str(have[j]) != str(ids[j]):
				same = false
				break
		if not same:
			continue
		dim["label_anchor"] = anchor
		dimensions[i] = dim
		return


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


# --- constraint inference (automatic relations on creation) ---

## Toolbar DOF chip for the live profile. Empty (no entities) emits dofs < 0,
## which the chip shows as "—". Anything drawn is solved, including a sketch
## just opened for edit or reloaded after part-level undo/redo.
func refresh_dof_state() -> void:
	if sketch == null or sketch.entity_ids().is_empty():
		last_dofs = -1
		last_solve_status = ""
		last_conflicting.clear()
		last_redundant.clear()
		_conflict_entities.clear()
		solve_updated.emit(-1, "", 0)
		return
	run_solve()


## Solve and remember diagnostics; all sketch-mode solves go through here so
## DOF coloring stays current.
func run_solve() -> Dictionary:
	# An empty profile is not "fully constrained". The chip shows "—", never "OK".
	if sketch == null or sketch.entity_ids().is_empty():
		last_dofs = -1
		last_solve_status = ""
		last_conflicting.clear()
		last_redundant.clear()
		_conflict_entities.clear()
		solve_updated.emit(-1, "", 0)
		return {"dofs": -1, "status": "", "residual": 0.0, "conflicting": PackedStringArray(), "redundant": PackedStringArray()}
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


## Centre-distance dims use the circle.center rule. Draw-time calls are the
## other caller; both go through SketchOriginAnchor so this is not a second pin.
func _pin_circle_at_sketch_origin(id: String, center: Vector2) -> void:
	SketchOriginAnchor.apply(sketch, [id], "circle.center", center)


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
		var kind := str(info.get("type", ""))
		if kind != "line" and kind != "arc" and kind != "elliptical_arc":
			continue
		var row := {"start": info["start"], "end": info["end"]}
		if info.has("start_angle"):
			row["start_angle"] = info["start_angle"]
		if info.has("end_angle"):
			row["end_angle"] = info["end_angle"]
		out[id] = row
	return out


## DogLeg's other horizontal-tangent solution sits on the far side of a
## locked circle. Put those lines back so `_seal_tangent_bosses` still sees
## one hit on each side of the shaft.
## Put back profile lines whose midpoint was far from `click` if solve moved
## them. Trim+solve of the 12-point at x=240 was translating the C jaws.
func _restore_untrimmed_line_drift(before: Dictionary, trimmed_id: String) -> void:
	if sketch == null or before.is_empty():
		return
	for id in before.keys():
		if str(id) == trimmed_id:
			continue
		var prev: Dictionary = before[id]
		var s0: Vector2 = prev["start"]
		var e0: Vector2 = prev["end"]
		var info: Dictionary = sketch.entity_info(str(id))
		var kind := str(info.get("type", ""))
		if info.is_empty() or (kind != "line" and kind != "arc" and kind != "elliptical_arc"):
			continue
		var s1: Vector2 = info["start"]
		var e1: Vector2 = info["end"]
		if s0.distance_to(s1) <= 0.5 and e0.distance_to(e1) <= 0.5:
			continue
		sketch.set_entity_geometry(str(id), prev)


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
			"arc", "elliptical_arc":
				var pa: Vector2 = info["start"] if info.has("start") else info["center"]
				var pb: Vector2 = info["end"] if info.has("end") else info["center"]
				if pa.distance_to(pb) > 1e-9:
					ends.append(pa)
					ends.append(pb)
					segs.append({"a": pa, "b": pb})
			_:
				pass
	const TOL := 0.05
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
	_pin_rect_corner_at_origin([l1, l2, l3, l4])
	run_solve()


## A corner rectangle that starts on the sketch origin is fully defined once
## its two side lengths are driving. Without this pin the profile still has
## two translational degrees of freedom and a later length edit slides it.
func _pin_rect_corner_at_origin(line_ids: Array) -> void:
	if sketch == null:
		return
	var best_id := ""
	var best_role := ""
	var best := ORIGIN_PIN_TOL * ORIGIN_PIN_TOL
	for lid in line_ids:
		var info: Dictionary = sketch.entity_info(str(lid))
		if str(info.get("type", "")) != "line":
			continue
		for role in ["start", "end"]:
			var p: Vector2 = info[role]
			var d := p.length_squared()
			if d <= best:
				best = d
				best_id = str(lid)
				best_role = role
	if best_id == "":
		return
	var origin := sketch.add_point(0.0, 0.0)
	if origin == "":
		return
	sketch.set_construction(origin, true)
	sketch.add_constraint("fix", [{"entity": origin, "role": "self"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": origin, "role": "self"},
		{"entity": best_id, "role": best_role}], 0.0)


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
	var recorded := _normalize_jaw_angle_rad(ang) if callout == "jaw_angle" else ang
	_record_dimension("angle", [xid, line_id], recorded, cid, callout)


func _line_locked_axis(line_id: String) -> bool:
	if sketch == null or line_id == "":
		return false
	for cid in sketch.constraint_ids():
		var info: Dictionary = sketch.constraint_info(str(cid))
		var kind := str(info.get("type", ""))
		if kind != "horizontal" and kind != "vertical":
			continue
		for ref in info.get("refs", []):
			if str(ref.get("entity", "")) == line_id:
				return true
	return false


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
	# Radius constraints store the radius. A diameter constraint stores the
	# diameter. The label and the editor both speak that stored value.
	return value


## Change the value of a recorded dimensional constraint (by index into
## `dimensions`) and re-solve. Returns the solve status ("" on bad index).
## Move a driving dimension in steps of at most 25 % so a wide jaw does not
## jump onto another solver branch. A failed step restores the snapshot.
func _commit_dimension_stepwise(index: int, dim: Dictionary, cid: String, target: float) -> bool:
	var previous := target
	if sketch.has_method("constraint_info"):
		previous = float(sketch.constraint_info(cid).get("value", target))
	var snap := sketch.snapshot() if sketch.has_method("snapshot") else ""
	var dims_before: Array = dimensions.duplicate(true)
	var cur := previous
	var guard := 0
	while guard < 48:
		guard += 1
		var room := 0.25 * maxf(absf(cur), 1.0)
		var step := target
		if absf(target - cur) > room + 1e-6:
			step = clampf(target, cur - room, cur + room)
		if not sketch.set_constraint_value(cid, step):
			_reject_dimension_step(snap, dims_before)
			return false
		dim["value"] = step
		dim.erase("expr")
		dimensions[index] = dim
		_keep_angle_dims_driving()
		var res := run_solve()
		if str(res.get("status", "")) == "failed":
			_reject_dimension_step(snap, dims_before)
			return false
		cur = step
		if absf(target - cur) <= 1e-4:
			break
	if str(dim.get("type", "")) == "distance":
		_restore_driving_angles()
	return true


func _reject_dimension_step(snap: String, dims_before: Array) -> void:
	if snap != "" and sketch != null and sketch.has_method("restore"):
		sketch.restore(snap)
	dimensions = dims_before
	run_solve()
	_redraw()
	_redraw_selected()
	_rebuild_dimension_labels()
	status.emit("Dimension rejected — constraints could not be satisfied")


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
			if not _commit_dimension_stepwise(index, dim, cid, value):
				return "failed"
			dim = dimensions[index]
	else:
		var value := _dimension_value_for_solver(dim, float(value_or_expr))
		if not _commit_dimension_stepwise(index, dim, cid, value):
			return "failed"
		dim = dimensions[index]
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
		# The graph already has this profile. Exit must not push a second
		# identical snapshot, or one Undo lands on the edit instead of before it.
		if sketch.has_method("snapshot"):
			_edit_baseline = sketch.snapshot()
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
## (type, sorted ids, value rounded to 1e-4). Display text is not a key:
## two driving lengths that both read "120" are two labels.
func _dimension_records_from_sketch() -> Array:
	var out: Array = []
	if sketch == null:
		return out
	var seen_fact := {}
	for cid in sketch.constraint_ids():
		var rec := _dimension_record_from_cid(str(cid))
		if rec.is_empty():
			continue
		var key := _dimension_fact_key(rec)
		if seen_fact.has(key):
			continue
		seen_fact[key] = true
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
	var value := float(info.get("value", 0.0))
	var rec := {
		"type": t,
		"ids": ids,
		"value": value,
		"cid": cid,
	}
	if t == "angle" and _ids_are_jaw_angle(ids):
		rec["callout"] = "jaw_angle"
		rec["value"] = _normalize_jaw_angle_rad(value)
	return rec


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
			if str(merged.get("callout", "")) == "jaw_angle":
				merged["value"] = _normalize_jaw_angle_rad(float(rec["value"]))
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
	_hide_infer_hint()
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


func note_pointer_screen(screen: Vector2) -> void:
	_pointer_screen = screen
	_sync_coincident_glyphs()


func hover(pos2: Vector2) -> void:
	if camera != null and is_inside_tree():
		_pointer_screen = camera.unproject_position(to_global(to_model(pos2)))
	if tool == Tool.TRIM:
		_trim_hover_id = _nearest_trim_entity_at(pos2)
		_hover = pos2
		_hide_infer_hint()
		_update_preview()
		_sync_coincident_glyphs()
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
	_sync_coincident_glyphs()
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
	_hide_infer_hint()
	_free_trim_trail()
	_trim_dragging = true
	_trim_jaw_done_in_drag = false
	_trim_drag_ids.clear()
	_trim_trail_pts.append(pos2)
	_rebuild_trim_trail()
	trim_at(pos2)
	var id := _nearest_trim_entity_at(pos2)
	if id != "":
		_trim_drag_ids.append(id)


func update_trim_drag(pos2: Vector2) -> void:
	if _trim_dragging:
		_trim_trail_pts.append(pos2)
		_rebuild_trim_trail()
	if not _trim_dragging or _trim_jaw_done_in_drag:
		return
	var id := _nearest_trim_entity_at(pos2)
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
	_hide_infer_hint()
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
		var p: PackedFloat64Array = info.get("params", PackedFloat64Array())
		match str(info.get("type", "")):
			"line":
				if p.size() >= 4:
					out.append(sketch.add_line(p[0] + offset.x, p[1] + offset.y,
							p[2] + offset.x, p[3] + offset.y))
				else:
					var a: Vector2 = info["start"] + offset
					var b: Vector2 = info["end"] + offset
					out.append(sketch.add_line(a.x, a.y, b.x, b.y))
			"circle":
				if p.size() >= 3:
					out.append(sketch.add_circle(p[0] + offset.x, p[1] + offset.y, p[2]))
				else:
					var c: Vector2 = info["center"] + offset
					out.append(sketch.add_circle(c.x, c.y, float(info["radius"])))
			"arc":
				if p.size() >= 5:
					out.append(sketch.add_arc(p[0] + offset.x, p[1] + offset.y, p[2], p[3], p[4]))
				else:
					var ac: Vector2 = info["center"] + offset
					out.append(sketch.add_arc(ac.x, ac.y, float(info.get("radius", 1)),
							float(info.get("start_angle", 0)), float(info.get("end_angle", PI))))
			"point":
				if p.size() >= 2:
					out.append(sketch.add_point(p[0] + offset.x, p[1] + offset.y))
				else:
					var pt: Vector2 = info.get("position", info.get("point", Vector2.ZERO)) + offset
					out.append(sketch.add_point(pt.x, pt.y))
			"ellipse":
				if p.size() >= 5:
					out.append(sketch.add_ellipse(p[0] + offset.x, p[1] + offset.y, p[2], p[3], p[4]))
				else:
					var ec: Vector2 = info.get("center", Vector2.ZERO) + offset
					out.append(sketch.add_ellipse(ec.x, ec.y, float(info.get("rx", 1)),
							float(info.get("ry", 1)), float(info.get("angle", 0))))
			"spline":
				var fits := PackedVector2Array()
				if p.size() >= 5:
					var n := int(p[0])
					for i in range(n):
						fits.append(Vector2(p[1 + 2 * i] + offset.x, p[2 + 2 * i] + offset.y))
				else:
					for fp in info.get("fit_points", []):
						fits.append((fp as Vector2) + offset)
				if fits.size() >= 2:
					out.append(sketch.add_spline(fits))
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
	return plane.to_world(p)


func _clear_meshes() -> void:
	_draw_node.mesh = null
	_preview_node.mesh = null
	_snap_marker = null
	_sync_pick_marker()
	_selected_node.mesh = null
	if _dimension_geom != null:
		_dimension_geom.mesh = null
		_dimension_geom.visible = false
	if _contour_node != null:
		_contour_node.mesh = null
	if _contour_tag != null:
		_contour_tag.visible = false
		_contour_tag.text = ""
		_contour_tag.set_meta("leader", false)
	_contour_fill_alphas = []
	_contour_outline_count = 0
	selected = []
	selected_roles.clear()
	selected_constraint = ""
	dimensions.clear()
	_clear_dimension_labels()
	_rebuild_constraint_glyphs()
	if _infer_label != null:
		_infer_label.visible = false


func _clear_dimension_labels() -> void:
	_free_direct_child("CircleLabelLeaders")
	if _dimension_labels == null:
		return
	while _dimension_labels.get_child_count() > 0:
		var child := _dimension_labels.get_child(0)
		_dimension_labels.remove_child(child)
		child.free()


func _free_direct_child(node_name: String) -> void:
	var node := get_node_or_null(node_name)
	if node == null:
		return
	remove_child(node)
	node.free()


func _entity_draw_color(info: Dictionary, id: String = "") -> Color:
	if id != "" and _conflict_entities.has(id):
		return COLOR_CONFLICT
	if info.get("construction", false):
		return COLOR_CONSTRUCTION
	# Fully-constrained sketches draw near-white (per-entity DOF isn't reported
	# by the solver yet, so the whole sketch flips together).
	if last_dofs == 0 and last_solve_status != "failed":
		return COLOR_CONSTRAINED
	return COLOR_ENTITY


func _point_line_label_value(ids: Array) -> float:
	var line_id := ""
	var point_id := ""
	for id in ids:
		var info: Dictionary = sketch.entity_info(str(id))
		if str(info.get("type", "")) == "line" and line_id == "":
			line_id = str(id)
		elif point_id == "":
			point_id = str(id)
	if line_id == "" or point_id == "":
		return -1.0
	var li: Dictionary = sketch.entity_info(line_id)
	var p := _point_xy({"entity": point_id, "role": "center"})
	return SketchGeom.point_line_distance(p, li["start"], li["end"])


func _dimension_display_value(dim: Dictionary) -> float:
	var type := str(dim.get("type", ""))
	var ids: Array = dim.get("ids", [])
	# Angle and diameter must win over measured_value: two lines report the
	# endpoint gap, and a circle reports radius, neither of which is the dim.
	if type == "angle" and ids.size() >= 2 and sketch != null:
		var signed := _lines_signed_angle(str(ids[0]), str(ids[1]))
		if _dimension_is_jaw_angle(dim):
			return rad_to_deg(_normalize_jaw_angle_rad(signed))
		return rad_to_deg(signed)
	if type == "diameter" and not ids.is_empty() and sketch != null:
		var dinfo: Dictionary = sketch.entity_info(str(ids[0]))
		if str(dinfo.get("type", "")) in ["circle", "arc"]:
			return float(dinfo.get("radius", 0.0)) * 2.0
	# A radius constraint stays a radius on a full circle and on an arc
	# (the pivot hole is 5, the wrench head is 22.5). Diameter constraints
	# are the ones that read Ø.
	if str(dim.get("callout", "")) == "point_line" and ids.size() >= 2 and sketch != null:
		var p2l := _point_line_label_value(ids)
		if p2l >= 0.0:
			return p2l
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
			var hit := _line_line_intersect(ia["start"], ia["end"] - ia["start"], ib["start"], ib["end"] - ib["start"])
			var da: Vector2 = (ia["end"] - ia["start"]).normalized()
			var db: Vector2 = (ib["end"] - ib["start"]).normalized()
			var bis := da + db
			if bis.length_squared() < 1e-8:
				bis = Vector2(-da.y, da.x)
			var off := bis.normalized() * (DIM_LABEL_OFFSET * 2.0)
			# A shallow angle meets the datum far from the jaw. Park the
			# label at the datum start, the same place parallel lines use.
			var p0: Vector2 = ia["start"]
			var p1: Vector2 = ia["end"]
			var datum_len := p0.distance_to(p1)
			var mid := (p0 + p1) * 0.5
			var anchor: Vector2 = hit
			if datum_len > 1e-6 and hit.distance_to(mid) > 2.0 * datum_len:
				anchor = p0
			return anchor + off
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
	var kind := str(dim.get("type", ""))
	if kind == "diameter":
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


func _rebuild_dimension_labels() -> void:
	_clear_dimension_labels()
	if _dimension_labels == null or sketch == null:
		return
	_sync_missing_radius_records()
	_dimension_labels.visible = dimensions_visible
	# Save re-entry holds the camera and the live callouts. Re-resolving the
	# overlap at the restored zoom still slides 20 and 45° by a few pixels
	# (the live clamp is not a fixed point of a fresh pass).
	var preserve := _label_restack_hold != 0 and _label_restack_hold == _camera_reassert_gen
	var taken: Array[Vector2] = []
	var all_stable := true
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
		var stable := prev_pos is Vector2 and (prev_pos as Vector2).distance_to(pos) < 0.5 \
				and dim.has("label_stack")
		if preserve and stable:
			var kept_text := _dimension_label_text(dim)
			if str(dim.get("type", "")) == "angle":
				var kept_shown := snappedf(_dimension_display_value(dim), 0.01)
				kept_text = _format_dimension(kept_shown) + "°"
			dim["label_text"] = kept_text
			dimensions[i] = dim
			continue
		all_stable = false
		var stack := 0
		if stable:
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
	if not (preserve and all_stable):
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
	_rebuild_dimension_geometry()


## Witness lines, dimension line, and filled arrows in the sketch plane.
func _rebuild_dimension_geometry() -> void:
	if _dimension_geom == null or sketch == null:
		return
	if not active:
		_dimension_geom.mesh = null
		_dimension_geom.visible = false
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var im := ImmediateMesh.new()
	var started := false
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var ids: Array = dim.get("ids", [])
		if ids.is_empty():
			continue
		var col := COLOR_CONSTRAINED if last_dofs == 0 and last_solve_status != "failed" else COLOR_ENTITY
		if not bool(dim.get("driving", true)):
			col = COLOR_DIM_DRIVEN
		var a: Variant = _dim_witness_a(dim)
		var b: Variant = _dim_witness_b(dim)
		if a == null or b == null:
			continue
		var pa: Vector2 = a
		var pb: Vector2 = b
		if not started:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		if cam != null:
			_append_leader_ribbon(im, cam, pa, pb, 2.0, col)
			_append_dim_arrow(im, cam, pa, pb, col)
			_append_dim_arrow(im, cam, pb, pa, col)
		var gap := 1.6
		var n := (pb - pa).orthogonal().normalized()
		if n.length_squared() < 1e-12:
			continue
		var lp: Variant = dim.get("label_pos", null)
		if lp is Vector2:
			var side: Vector2 = lp as Vector2
			if (side - pa).dot(n) < 0.0:
				n = -n
		if cam != null:
			_append_leader_ribbon(im, cam, pa, pa + n * gap, 1.5, col)
			_append_leader_ribbon(im, cam, pb, pb + n * gap, 1.5, col)
	if started:
		im.surface_end()
	_dimension_geom.mesh = im if started else null
	_dimension_geom.visible = dimensions_visible and active


func _dim_witness_a(dim: Dictionary) -> Variant:
	var ids: Array = dim.get("ids", [])
	if ids.is_empty() or sketch == null:
		return null
	var info: Dictionary = sketch.entity_info(str(ids[0]))
	var kind := str(info.get("type", ""))
	if kind == "line":
		return info.get("start")
	if kind == "circle" or kind == "arc":
		return info.get("center")
	if kind == "ellipse":
		return info.get("major_start") if str(dim.get("type", "")) != "minor" else info.get("minor_start")
	if info.has("position"):
		return info.get("position")
	return info.get("start")


func _dim_witness_b(dim: Dictionary) -> Variant:
	var ids: Array = dim.get("ids", [])
	if ids.is_empty() or sketch == null:
		return null
	if ids.size() >= 2:
		var info_b: Dictionary = sketch.entity_info(str(ids[1]))
		if info_b.has("position"):
			return info_b.get("position")
		if info_b.has("end"):
			return info_b.get("end")
		if info_b.has("center"):
			return info_b.get("center")
	var info: Dictionary = sketch.entity_info(str(ids[0]))
	var kind := str(info.get("type", ""))
	if kind == "line":
		return info.get("end")
	if kind == "circle":
		var c: Vector2 = info.get("center", Vector2.ZERO)
		return c + Vector2(float(info.get("radius", 0.0)), 0.0)
	if kind == "arc":
		return info.get("end")
	if kind == "ellipse":
		return info.get("major_end")
	return info.get("end")


func _append_dim_arrow(im: ImmediateMesh, cam: Camera3D, tip: Vector2, from_pt: Vector2, col: Color) -> void:
	var dir := (tip - from_pt)
	if dir.length_squared() < 1e-8:
		return
	dir = dir.normalized()
	var n := Vector2(-dir.y, dir.x)
	var head := 2.2
	var left := tip - dir * head + n * (head * 0.45)
	var right := tip - dir * head - n * (head * 0.45)
	var lift := plane_normal() * 0.35
	im.surface_set_color(col)
	im.surface_add_vertex(_to3(tip) + lift)
	im.surface_add_vertex(_to3(left) + lift)
	im.surface_add_vertex(_to3(right) + lift)


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


## Select on a circle's own diameter/radius: the curve wins when it is
## nearer than the letters or tied (A12 −X rim). A click on the letters
## still opens the editor.
func _radius_label_on_own_rim(index: int, pos2: Vector2) -> bool:
	if tool != Tool.SELECT or index < 0 or index >= dimensions.size():
		return false
	var dim: Dictionary = dimensions[index]
	if not _full_circle_dimension(dim):
		return false
	var ids: Array = dim.get("ids", [])
	if ids.is_empty():
		return false
	var eid := str(ids[0])
	if _nearest_entity_at(pos2) != eid:
		return false
	var lp: Variant = _dimension_label_pos2(dim)
	if lp != null:
		var to_letters := pos2.distance_to(lp as Vector2)
		var to_curve := _entity_distance(sketch.entity_info(eid), pos2)
		if to_letters < to_curve:
			return false
	return true


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
		if _seated_curve_dimension(dim) or _is_slot_cap_radius(dim):
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
	_seat_full_circle_labels(cam, k)
	_open_label_glyph_gap(cam, k)
	_nudge_labels_off_leaders(cam, k)
	_rebuild_circle_label_leaders(cam)
	_park_labels_outside_host_face(cam, k)


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


## Shift a callout off a glyph leader by at most 36 screen px total, so a
## rebuild cannot walk the text off the canvas.
func _nudge_labels_off_leaders(cam: Camera3D, k: float) -> void:
	if k < 1e-6:
		return
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
			continue
		if _seated_curve_dimension(dim) or _is_slot_cap_radius(dim):
			continue
		var clamp_off := Vector2.ZERO
		var raw: Variant = dim.get("label_clamp", Vector2.ZERO)
		if raw is Vector2:
			clamp_off = raw
		var screen_off := Vector2(clamp_off.x * k, -clamp_off.y * k).length()
		if screen_off >= 36.0:
			continue
		var rect := _projected_label_rect(dim, cam, k)
		var push := Vector2.ZERO
		for a in _glyph_anchors:
			if float(a.get("offset_px", 0.0)) < GLYPH_LEADER_MIN_PX:
				continue
			var sa := cam.unproject_position(to_global(to_model(a["anchor"])))
			var sb := cam.unproject_position(to_global(to_model(a["pos"])))
			if not _leader_crosses_rect(sa, sb, rect):
				continue
			var dir := sb - sa
			if dir.length_squared() < 1.0:
				continue
			var n := Vector2(-dir.y, dir.x).normalized()
			var side := 1.0 if n.dot(rect.get_center() - (sa + sb) * 0.5) >= 0.0 else -1.0
			push += n * side * 12.0
		if push.length_squared() < 0.25:
			continue
		var room := 36.0 - screen_off
		if push.length() > room:
			push = push.normalized() * room
		var next := _projected_label_rect(dim, cam, k)
		# Predict the shift: offset x grows with +screen.x / k, y with -screen.y / k.
		next.position += push
		var safe := _label_safe_screen_rect()
		if not safe.encloses(next):
			continue
		clamp_off += Vector2(push.x / k, -push.y / k)
		dim["label_clamp"] = clamp_off
		dimensions[i] = dim


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
	var gap := GLYPH_LABEL_GAP_PX
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
	var left := maxf(4.0, ChromeDock.sketch_rail_right)
	var right_margin := 4.0
	var rect := Rect2(left, top, maxf(vp.x - left - right_margin, 32.0), maxf(vp.y - top - bottom, 32.0))
	# The chrome canvas is tighter than the window on the right. A label that
	# only clears the window edge still hangs off the canvas (5° / 10° jaws).
	if camera != null and camera.has_method("sketch_fit_canvas_rect"):
		var canvas: Rect2 = camera.sketch_fit_canvas_rect()
		if canvas.size.x > 32.0 and canvas.size.y > 32.0 and rect.intersects(canvas):
			rect = rect.intersection(canvas)
			# A label flush with the canvas edge fails encloses() on float error.
			if rect.size.x > 4.0 and rect.size.y > 4.0:
				rect = Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2))
	return rect


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


## Radius/diameter on a full circle, or on the head arc left after a jaw trim.
## Slot-cap radii stay on their own placement.
func _seated_curve_dimension(dim: Dictionary) -> bool:
	if _full_circle_dimension(dim):
		return true
	if sketch == null or _is_slot_cap_radius(dim):
		return false
	var ids: Array = dim.get("ids", [])
	if ids.size() != 1:
		return false
	var t := str(dim.get("type", ""))
	if t != "radius" and t != "diameter":
		return false
	var info: Dictionary = sketch.entity_info(str(ids[0]))
	if str(info.get("type", "")) != "arc":
		return false
	return float(info.get("radius", 0.0)) >= 10.0


func _curve_center_radius(dim: Dictionary) -> Variant:
	var ids: Array = dim.get("ids", [])
	if ids.is_empty() or sketch == null:
		return null
	var info: Dictionary = sketch.entity_info(str(ids[0]))
	var kind := str(info.get("type", ""))
	if kind != "circle" and kind != "arc":
		return null
	if not info.has("center"):
		return null
	return {"center": info["center"], "radius": float(info.get("radius", 0.0))}


## Park a circle or head-arc radius/diameter just outside its rim. A millimetre
## stack walks `22.5` a hundred pixels off the head; the callout has to stay
## on the circle, with a leader when it is not touching the rim.
## Face-sketch callouts sit in the margin. The obstacle is the host face's
## screen box; each label takes the shortest step that puts its centre outside.
func _park_labels_outside_host_face(cam: Camera3D, k: float) -> void:
	_FaceLabelPark.park(self, cam, k)


## Screen box of the body this face sketch sits on, in the same space as labels.
func _host_face_screen_rect(cam: Camera3D) -> Rect2:
	var host := _host_body_uv_aabb()
	if host.is_empty():
		return Rect2()
	var mn: Vector2 = host["min"]
	var mx: Vector2 = host["max"]
	var box := Rect2()
	var any := false
	for uv in [mn, Vector2(mx.x, mn.y), mx, Vector2(mn.x, mx.y)]:
		var screen := cam.unproject_position(to_global(to_model(uv)))
		if not any:
			box = Rect2(screen, Vector2.ZERO)
			any = true
		else:
			box = box.expand(screen)
	return box


func _seat_full_circle_labels(cam: Camera3D, k: float) -> void:
	if k < 1e-6 or sketch == null:
		return
	var shaft_y := _shaft_lower_screen_y(cam)
	var glyphs: Array[Rect2] = []
	for g in constraint_glyph_screen_rects():
		if typeof(g) != TYPE_DICTIONARY:
			continue
		# Coincident badges appear only while the pointer is on them. Seating
		# the circle callout against that hover pile walks `22.5` off the rim
		# between a label click and the next save.
		if str(g.get("type", "")) == "coincident":
			continue
		glyphs.append(g["rect"] as Rect2)
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY or not _seated_curve_dimension(dim):
			continue
		var curve: Variant = _curve_center_radius(dim)
		if curve == null:
			continue
		var info: Dictionary = curve
		dim["label_stack"] = 0
		dim["label_clamp"] = Vector2.ZERO
		dimensions[i] = dim
		var c: Vector2 = info["center"]
		var radius := float(info.get("radius", 0.0))
		var c_s := cam.unproject_position(to_global(to_model(c)))
		var rim_s := cam.unproject_position(to_global(to_model(c + Vector2(radius, 0.0))))
		var radius_px := c_s.distance_to(rim_s)
		var natural := _projected_label_anchor(dim, cam)
		var prefer := natural - c_s
		if prefer.length_squared() < 1.0:
			prefer = Vector2(0.0, 1.0)
		prefer = prefer.normalized()
		var rect0 := _projected_label_rect(dim, cam, k)
		var half := rect0.size * 0.5
		var best_dir := prefer
		var best_gap := CIRCLE_LABEL_RIM_GAP_PX
		var best_score := INF
		for step in 16:
			var ang := TAU * float(step) / 16.0
			var dir := Vector2(cos(ang), sin(ang))
			var gap := CIRCLE_LABEL_RIM_GAP_PX
			var guard := 0
			var trial := Rect2()
			var hits := true
			while guard < 5:
				var along := half.x * absf(dir.x) + half.y * absf(dir.y)
				var centre := c_s + dir * (radius_px + gap + along)
				trial = Rect2(centre - half, rect0.size)
				hits = _circle_label_trial_hits(trial, i, cam, k, glyphs, shaft_y)
				if not hits or gap >= 34.0:
					break
				gap += 6.0
				guard += 1
			var score := dir.distance_to(prefer) * 6.0
			var near := _label_glyph_separation(trial, glyphs)
			if hits:
				score += 80.0 + maxf(GLYPH_LABEL_GAP_PX - near, 0.0) * 40.0
			elif near < GLYPH_LABEL_GAP_PX:
				score += (GLYPH_LABEL_GAP_PX - near) * 40.0
			score += maxf(gap - CIRCLE_LABEL_RIM_GAP_PX, 0.0) * 0.15
			if score < best_score:
				best_score = score
				best_dir = dir
				best_gap = gap
		var along_best := half.x * absf(best_dir.x) + half.y * absf(best_dir.y)
		var seated := c_s + best_dir * (radius_px + best_gap + along_best)
		var delta := seated - natural
		dim["label_clamp"] = Vector2(delta.x / k, -delta.y / k)
		dim["label_stack"] = 0
		dimensions[i] = dim


func _label_glyph_separation(rect: Rect2, glyphs: Array[Rect2]) -> float:
	var best := INF
	for gr in glyphs:
		best = minf(best, _rect_separation(rect, gr))
	return best


func _rect_separation(a: Rect2, b: Rect2) -> float:
	var dx := 0.0
	if a.end.x < b.position.x:
		dx = b.position.x - a.end.x
	elif b.end.x < a.position.x:
		dx = a.position.x - b.end.x
	var dy := 0.0
	if a.end.y < b.position.y:
		dy = b.position.y - a.end.y
	elif b.end.y < a.position.y:
		dy = a.position.y - b.end.y
	if dx > 0.0 and dy > 0.0:
		return sqrt(dx * dx + dy * dy)
	if dx == 0.0 and dy == 0.0:
		return 0.0
	return maxf(dx, dy)


## Labels that are still grazing a badge slide away. Seated radius callouts
## stay on the circle; the seat search owns their gap.
func _open_label_glyph_gap(cam: Camera3D, k: float) -> void:
	if k < 1e-6:
		return
	var min_gap := GLYPH_LABEL_GAP_PX
	for _pass in 8:
		var glyphs: Array[Rect2] = []
		for g in constraint_glyph_screen_rects():
			if typeof(g) == TYPE_DICTIONARY:
				glyphs.append(g["rect"] as Rect2)
		var moved := false
		for i in range(dimensions.size()):
			var dim: Dictionary = dimensions[i]
			if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
				continue
			if _seated_curve_dimension(dim):
				continue
			var rect := _projected_label_rect(dim, cam, k)
			var push := Vector2.ZERO
			for gr in glyphs:
				var sep := _rect_separation(rect, gr)
				if sep >= min_gap:
					continue
				var away := rect.get_center() - gr.get_center()
				if away.length_squared() < 1.0:
					away = Vector2(0.0, -1.0)
				push += away.normalized() * (min_gap - sep + 1.5)
			if push.length_squared() < 0.25:
				continue
			var clamp_off := Vector2.ZERO
			var raw: Variant = dim.get("label_clamp", Vector2.ZERO)
			if raw is Vector2:
				clamp_off = raw
			var trial_off := clamp_off + Vector2(push.x / k, -push.y / k)
			dim["label_clamp"] = trial_off
			dimensions[i] = dim
			var trial := _projected_label_rect(dim, cam, k)
			var blocked := false
			for j in range(dimensions.size()):
				if j == i:
					continue
				var other: Dictionary = dimensions[j]
				if typeof(other) != TYPE_DICTIONARY or other.get("label_pos", null) == null:
					continue
				if trial.intersects(_projected_label_rect(other, cam, k)):
					blocked = true
					break
			if blocked or not _label_safe_screen_rect().encloses(trial):
				dim["label_clamp"] = clamp_off
				dimensions[i] = dim
				continue
			moved = true
		if not moved:
			break
	_clamp_dimension_labels_into_view(cam, k)


func _circle_label_trial_hits(trial: Rect2, index: int, cam: Camera3D, k: float,
		glyphs: Array[Rect2], shaft_y: float) -> bool:
	if _glyph_below_part(trial, shaft_y):
		return true
	var safe := _label_safe_screen_rect()
	if not safe.encloses(trial):
		return true
	for j in range(dimensions.size()):
		if j == index:
			continue
		var other: Dictionary = dimensions[j]
		if typeof(other) != TYPE_DICTIONARY or other.get("label_pos", null) == null:
			continue
		if trial.intersects(_projected_label_rect(other, cam, k)):
			return true
	for gr in glyphs:
		if trial.intersects(gr.grow(GLYPH_LABEL_GAP_PX)):
			return true
	return false


func _rebuild_circle_label_leaders(cam: Camera3D) -> void:
	_free_direct_child("CircleLabelLeaders")
	if cam == null or sketch == null or not active:
		return
	var k := _label_px_scale(cam)
	var im := ImmediateMesh.new()
	var any := false
	var col := Color(0.92, 0.94, 0.98, 0.85)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY or not _seated_curve_dimension(dim):
			continue
		if dim.get("label_pos", null) == null:
			continue
		var curve: Variant = _curve_center_radius(dim)
		if curve == null:
			continue
		var info: Dictionary = curve
		var c: Vector2 = info["center"]
		var radius := float(info.get("radius", 0.0))
		var c_s := cam.unproject_position(to_global(to_model(c)))
		var radius_px := c_s.distance_to(cam.unproject_position(to_global(to_model(c + Vector2(radius, 0.0)))))
		var rect := _projected_label_rect(dim, cam, k)
		var centre := rect.get_center()
		var away := centre - c_s
		if away.length_squared() < 1.0:
			continue
		var dir := away.normalized()
		var rim_s := c_s + dir * radius_px
		var half := rect.size * 0.5
		var along := half.x * absf(dir.x) + half.y * absf(dir.y)
		var edge_s := centre - dir * along
		if rim_s.distance_to(edge_s) < 2.0:
			continue
		_append_leader_ribbon(im, cam, _sketch_from_screen(cam, rim_s, c),
				_sketch_from_screen(cam, edge_s, c), 1.4, col)
		any = true
	if not any:
		return
	im.surface_end()
	var leaders := MeshInstance3D.new()
	leaders.name = "CircleLabelLeaders"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color.WHITE
	leaders.mesh = im
	leaders.material_override = mat
	add_child(leaders)


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
	# Label3D draws one em. get_height() adds leading, so the hit box is
	# taller than the ink and a legal pack fails the overlap check.
	var em := float(GLYPH_FONT_PX)
	var raw := Vector2(
			font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em)).x,
			em)
	var side := maxf(raw.x, raw.y)
	return Vector2(side, side) * k


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


## Screen pixel → sketch plane, using the anchor's own projection so a 40 px
## nudge lands on the pixel the layout chose. A ray that misses the plane
## (or comes back on a different pixel) must not leave the badge on the pile.
func _sketch_from_screen(cam: Camera3D, screen: Vector2, anchor_sketch: Vector2) -> Vector2:
	var origin_s := cam.unproject_position(to_global(to_model(anchor_sketch)))
	var x_s := cam.unproject_position(to_global(to_model(anchor_sketch + Vector2(1.0, 0.0)))) - origin_s
	var y_s := cam.unproject_position(to_global(to_model(anchor_sketch + Vector2(0.0, 1.0)))) - origin_s
	var delta := screen - origin_s
	var det := x_s.x * y_s.y - x_s.y * y_s.x
	if absf(det) < 1e-4:
		var hit: Variant = _sketch_at_screen(cam, screen)
		if hit is Vector2:
			return hit
		return anchor_sketch
	var dx := (delta.x * y_s.y - delta.y * y_s.x) / det
	var dy := (x_s.x * delta.y - x_s.y * delta.x) / det
	return anchor_sketch + Vector2(dx, dy)


## Screen Y of the shaft's lower edge (Y grows downward). INF when the sketch
## has no long near-horizontal wall to measure.
func _shaft_lower_screen_y(cam: Camera3D) -> float:
	if sketch == null:
		return INF
	var best := -INF
	var found := false
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a := cam.unproject_position(to_global(to_model(info["start"])))
		var b := cam.unproject_position(to_global(to_model(info["end"])))
		var span := a.distance_to(b)
		if span < 36.0:
			continue
		if absf(a.y - b.y) > maxf(8.0, span * 0.18):
			continue
		var y := (a.y + b.y) * 0.5
		if y > best:
			best = y
			found = true
	return best if found else INF


func _glyph_below_part(rect: Rect2, shaft_y: float) -> bool:
	if shaft_y > 1.0e8:
		return false
	return rect.end.y > shaft_y + 1.5


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


## Start a leader just past a badge that sits on its constraint point.
## The runner samples t = i/8 and ignores points within 10 px of the start,
## so keep advancing the start until that test is clear. Leave at least 4 px
## of ribbon or the mesh drops while the leader flag stays on.
func _leader_clear_start(anchor: Vector2, centre: Vector2, others: Array[Rect2]) -> Vector2:
	var start := anchor
	if anchor.distance_to(centre) < 12.0:
		return anchor
	for _pass in range(6):
		var span := start.distance_to(centre)
		if span < 6.0:
			break
		var blocked := start
		var saw := false
		for i in range(1, 8):
			var p := start.lerp(centre, float(i) / 8.0)
			# Match the walker's 14 px vertex dead-zone. A 10 px skip still
			# left the ribbon inside the coincident badge at the anchor.
			if start.distance_to(p) < 14.0:
				continue
			for rect in others:
				if rect.grow(1.0).has_point(p):
					blocked = p
					saw = true
					break
		if not saw:
			break
		var dir := centre - start
		if dir.length_squared() < 1.0:
			break
		var next := blocked + dir.normalized() * 2.0
		if start.distance_to(next) < 0.5:
			break
		if next.distance_to(centre) < 4.0:
			break
		start = next
	return start


func _leader_crosses_rect(anchor: Vector2, centre: Vector2, rect: Rect2) -> bool:
	if anchor == Vector2.INF or rect.size == Vector2.ZERO:
		return false
	# The badge centre is the end of the leader. Samples stop at 7/8, so a
	# 15 px leader (every sample inside the 14 px anchor skip) used to count
	# as clear while its badge sat inside a neighbour.
	if anchor.distance_to(centre) >= 14.0 and rect.has_point(centre):
		return true
	# Skip the anchor neighbourhood (it sits on the curve, often under the
	# badge that names that vertex).
	for i in range(1, 8):
		var p := anchor.lerp(centre, float(i) / 8.0)
		if anchor.distance_to(p) < 14.0:
			continue
		if rect.has_point(p):
			return true
	return false


func _glyph_block_score(rect: Rect2, centre: Vector2, placed: Array[Rect2],
		labels: Array[Rect2], cam: Camera3D, shaft_y: float = INF,
		anchor_screen: Vector2 = Vector2.INF, penalize_curves: bool = true) -> float:
	var score := 0.0
	for prev in placed:
		var frac := _glyph_overlap_fraction(rect, prev)
		# A foreign centre inside this badge steals the click (parallel
		# reads as horizontal). That outranks a curve touch. Label
		# clearance stays soft — dimension text moves after the glyphs do.
		score += frac * 40.0
		if rect.has_point(prev.get_center()) or prev.has_point(centre):
			score += 200000.0 + frac * 1000.0
		elif frac > 0.16:
			score += 8000.0 + (frac - 0.16) * 4000.0
	for lr in labels:
		var sep := _rect_separation(rect, lr)
		if sep + 0.01 < GLYPH_LABEL_GAP_PX:
			score += 50000.0 + (GLYPH_LABEL_GAP_PX - sep) * 80.0
	# Hanging off the part outranks a stolen click and a curve touch.
	if _glyph_below_part(rect, shaft_y):
		score += 500000.0 + (rect.end.y - shaft_y) * 40.0
	if _sketch_at_screen(cam, centre) == null:
		score += 40.0
	if penalize_curves:
		score += _glyph_curve_penalty(rect, anchor_screen, cam)
	# The leader is the segment from the anchor to the badge. A badge that
	# clears its neighbours can still draw that segment through a label or
	# another badge.
	if anchor_screen != Vector2.INF:
		for prev in placed:
			if _leader_crosses_rect(anchor_screen, centre, prev):
				score += 90000.0
		for lr in labels:
			if _leader_crosses_rect(anchor_screen, centre, lr):
				score += 12000.0
	return score


## Screen centre of a glyph pushed off the pile, the labels, and the curves.
func _separate_glyph_screen(natural: Vector2, size: Vector2, placed: Array[Rect2],
		labels: Array[Rect2], cam: Camera3D, shaft_y: float = INF,
		penalize_curves: bool = true) -> Vector2:
	var best := natural
	var best_score := INF
	var radii: Array[float] = [0.0]
	var fine := 5.0
	while fine <= GLYPH_MAX_OFFSET_PX + 0.01:
		radii.append(minf(fine, GLYPH_MAX_OFFSET_PX))
		fine += 5.0
	for radius in radii:
		var count := 1 if radius < 1.0 else 32
		for i in range(count):
			var centre := natural
			if radius >= 1.0:
				var ang := TAU * float(i) / float(count)
				centre = natural + Vector2(cos(ang), sin(ang)) * radius
			var rect := Rect2(centre - size * 0.5, size)
			var score := _glyph_block_score(rect, centre, placed, labels, cam, shaft_y, natural, penalize_curves)
			if score < best_score - 0.01:
				best_score = score
				best = centre
	var guard := 0
	while guard < 16:
		guard += 1
		var rect := Rect2(best - size * 0.5, size)
		var worst := 0.0
		var worst_prev := Rect2()
		for prev in placed:
			var frac := _glyph_overlap_fraction(rect, prev)
			if frac > worst:
				worst = frac
				worst_prev = prev
		var below := _glyph_below_part(rect, shaft_y)
		if worst <= 0.16 and not below:
			break
		var away := Vector2.UP
		if worst > 0.12:
			away = best - worst_prev.get_center()
		elif below:
			away = Vector2(0.0, -1.0)
		if away.length_squared() < 1.0:
			away = Vector2(0.0, -1.0)
		var nudged := best + away.normalized() * 4.0
		if nudged.distance_to(natural) > GLYPH_MAX_OFFSET_PX:
			nudged = natural + (nudged - natural).normalized() * GLYPH_MAX_OFFSET_PX
		var nrect := Rect2(nudged - size * 0.5, size)
		var nscore := _glyph_block_score(nrect, nudged, placed, labels, cam, shaft_y, natural, penalize_curves)
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
		"point_on_line", "parallel", "perpendicular", "equal", "horizontal", "vertical":
			# Two endpoints: the badge sits between them (the mean below).
			# A line still sits beside the line. Two centres stay hidden (T14).
			if not (str(cinfo.get("type", "")) == "vertical" and _is_point_pair(refs)):
				var line_info := _line_ref_info(refs)
				if not line_info.is_empty():
					return _nudge_off_line(line_info)
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
			return _nudge_off_line(info)
	return anchor


func _line_ref_info(refs: Array) -> Dictionary:
	var construction := {}
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
		if str(info.get("type", "")) != "line":
			continue
		if bool(info.get("construction", false)):
			construction = info
		else:
			return info
	return construction


func _sketch_centroid() -> Vector2:
	if sketch == null:
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var n := 0
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		if kind == "line" and not bool(info.get("construction", false)):
			sum += ((info["start"] as Vector2) + (info["end"] as Vector2)) * 0.5
			n += 1
		elif info.has("center"):
			sum += info["center"] as Vector2
			n += 1
	if n == 0:
		return Vector2.ZERO
	return sum / float(n)


## Midpoint of a wall, pushed to the side farther from the sketch centroid so
## the badge clears the wall instead of sitting in the corner cluster.
func _nudge_off_line(info: Dictionary) -> Vector2:
	var a: Vector2 = info["start"]
	var b: Vector2 = info["end"]
	var mid := (a + b) * 0.5
	var d := b - a
	if d.length_squared() < 1e-12:
		return mid
	var nrm := Vector2(-d.y, d.x).normalized()
	var step := _badge_clear_mm()
	var interior := _sketch_centroid()
	if (mid + nrm * step).distance_to(interior) < (mid - nrm * step).distance_to(interior):
		nrm = -nrm
	if _badge_below_shaft(mid + nrm * step) and not _badge_below_shaft(mid - nrm * step):
		nrm = -nrm
	if bool(info.get("construction", false)):
		var best := a + nrm * step
		var best_score := INF
		for end in [a, b]:
			for sgn in [1.0, -1.0]:
				var opt: Vector2 = end + nrm * sgn * step
				var score := -opt.distance_to(interior)
				if _badge_below_shaft(opt):
					score += 100000.0
				if score < best_score:
					best = opt
					best_score = score
		return best
	return mid + nrm * step


func _badge_below_shaft(sketch_pos: Vector2) -> bool:
	if camera == null or not is_inside_tree():
		return false
	var shaft_y := _shaft_lower_screen_y(camera)
	if shaft_y > 1.0e8:
		return false
	var screen := camera.unproject_position(to_global(to_model(sketch_pos)))
	var half := _glyph_symbol_size_px("horizontal", _label_px_scale(camera)).y * 0.5
	return screen.y + half > shaft_y + 1.5


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


func _constraint_refs_endpoints(cinfo: Dictionary) -> bool:
	var n := 0
	for ref in cinfo.get("refs", []):
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var role := str(ref.get("role", "self"))
		if role == "start" or role == "end":
			n += 1
	return n >= 2


func _place_one_glyph(cid: String, cam: Camera3D, k: float, label_rects: Array[Rect2],
		shaft_y: float, placed: Array[Rect2], taken: Array[Vector2], pending: Array,
		batch_pending: Array) -> void:
	var cinfo: Dictionary = sketch.constraint_info(cid)
	var type := str(cinfo.get("type", ""))
	if not GLYPH_SYMBOLS.has(type):
		return
	# A centre-to-centre horizontal has no line to sit beside. Drawing it
	# would plant a badge between the circles (T14's stray mark). Two-point
	# Horizontal on arc ends (the R20 hook) still draws.
	if (type == "horizontal" or type == "vertical") and not _constraint_refs_a_line(cinfo) \
			and not _constraint_refs_endpoints(cinfo):
		return
	var anchor: Variant = _constraint_anchor(cinfo)
	if anchor == null:
		return
	var anchor_sketch := anchor as Vector2
	var pos := anchor_sketch
	var offset_px := 0.0
	var centre := Vector2.ZERO
	var natural := Vector2.ZERO
	var size := Vector2.ZERO
	if cam != null:
		# De-stack in pixels. A 2.5 mm step is ~8 px at a 150 px head,
		# smaller than the badge, so the pile survives a millimetre nudge.
		size = _glyph_symbol_size_px(type, k)
		natural = cam.unproject_position(to_global(to_model(anchor_sketch)))
		# A coincident mark names a vertex. Pushing it off every curve
		# walks it onto the radius callout.
		var on_curve := type != "coincident"
		centre = _separate_glyph_screen(natural, size, placed, label_rects, cam, shaft_y, on_curve)
		offset_px = natural.distance_to(centre)
		placed.append(Rect2(centre - size * 0.5, size))
		pos = _sketch_from_screen(cam, centre, anchor_sketch)
	else:
		var guard := 0
		while guard < 8 and taken.any(func(t: Vector2) -> bool: return t.distance_to(pos) < 2.0):
			pos += Vector2(0, 2.5)
			guard += 1
		taken.append(pos)
	var item := {
		"cid": cid,
		"type": type,
		"anchor": anchor_sketch,
		"pos": pos,
		"natural": natural,
		"centre": centre,
		"size": size,
		"offset_px": offset_px,
	}
	pending.append(item)
	batch_pending.append(item)


## Keep each badge's reprojected screen distance at or under the 40 px cap.
## `centre` is chosen in screen space; storing it through the sketch plane
## and reading it back is not an exact inverse under perspective.
func _cap_glyph_leader_span(items: Array, cam: Camera3D) -> void:
	var limit := GLYPH_MAX_OFFSET_PX - 0.5
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var anchor: Vector2 = item["anchor"]
		var centre: Vector2 = item["centre"]
		var origin := cam.unproject_position(to_global(to_model(anchor)))
		var delta := centre - origin
		if delta.length() > limit:
			centre = origin + delta.normalized() * limit
			item["centre"] = centre
		var pos := _sketch_from_screen(cam, centre, anchor)
		var back := cam.unproject_position(to_global(to_model(pos)))
		var got := origin.distance_to(back)
		if got > GLYPH_MAX_OFFSET_PX and got > 1.0:
			pos = anchor + (pos - anchor) * (limit / got)
			back = cam.unproject_position(to_global(to_model(pos)))
			got = origin.distance_to(back)
		item["pos"] = pos
		item["offset_px"] = got


func _rebuild_constraint_glyphs() -> void:
	_refresh_coincident_keep()
	# A click moves the pointer from the vertex onto the badge, which drops
	# the other hover marks and rebuilds. Repair would then slide the badge
	# the pointer is already on. Pin that centre so the click still lands.
	var pinned_coincident := _pinned_coincident_centres()
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
	var shaft_y := _shaft_lower_screen_y(cam) if cam != null else INF
	var placed: Array[Rect2] = []
	var taken: Array[Vector2] = []
	var pending: Array = []
	# Coincident badges appear and disappear with hover and selection.
	# Lay the stable badges down first so that flicker cannot move the
	# glyph a click already aimed at.
	var stable_ids: Array[String] = []
	var coincident_ids: Array[String] = []
	for cid in sketch.constraint_ids():
		var cinfo: Dictionary = sketch.constraint_info(cid)
		var type := str(cinfo.get("type", ""))
		if not GLYPH_SYMBOLS.has(type):
			continue
		if type == "coincident" and not _coincident_glyph_visible(str(cid), cinfo):
			continue
		if type == "coincident":
			coincident_ids.append(str(cid))
		else:
			stable_ids.append(str(cid))
	for batch in [stable_ids, coincident_ids]:
		var batch_pending: Array = []
		for cid in batch:
			_place_one_glyph(str(cid), cam, k, label_rects, shaft_y, placed, taken, pending, batch_pending)
		if cam != null and batch == stable_ids and batch_pending.size() > 1:
			_relax_glyph_layout(batch_pending, label_rects, cam, shaft_y)
			placed.clear()
			for item in batch_pending:
				var size: Vector2 = item["size"]
				var centre: Vector2 = item["centre"]
				if size == Vector2.ZERO:
					continue
				placed.append(Rect2(centre - size * 0.5, size))
	if cam != null and pending.size() > 1:
		# Coincident marks appear only while a vertex is selected. They are
		# placed after the stable badges so a hover cannot slide those.
		# Repair keeps each coincident leader inside 40 px and off the
		# wall glyphs (a 15 px parallel leader was ending inside one).
		_repair_coincident_glyphs(pending, label_rects, cam, shaft_y)
	if cam != null:
		_restore_pinned_coincident(pending, pinned_coincident, cam)
		_clamp_coincident_leaders(pending, cam)
		# Screen→sketch is a local linearisation. A badge parked on the 40 px
		# cap can reproject a fraction past it, which is what the walk rejects.
		_cap_glyph_leader_span(pending, cam)
	for item in pending:
		var gtype := str(item["type"])
		var gcid := str(item["cid"])
		var gpos: Vector2 = item["pos"]
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.004
		label.font_size = GLYPH_FONT_PX
		label.no_depth_test = true
		label.render_priority = 3
		label.text = GLYPH_SYMBOLS[gtype]
		if gcid == selected_constraint:
			label.modulate = COLOR_GLYPH_SELECTED
		elif last_conflicting.has(gcid):
			label.modulate = COLOR_CONFLICT
		else:
			label.modulate = COLOR_GLYPH
		label.position = _to3(gpos) + plane_normal() * 0.25
		label.set_meta("cid", gcid)
		if gtype != "coincident":
			var pad := MeshInstance3D.new()
			pad.name = "GlyphPad"
			var quad := QuadMesh.new()
			# 14×14 px at Label3D.pixel_size 0.004 (survey #4 green squares).
			quad.size = Vector2(0.056, 0.056)
			pad.mesh = quad
			var pad_mat := StandardMaterial3D.new()
			pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			pad_mat.no_depth_test = true
			pad_mat.albedo_color = COLOR_GLYPH if gcid != selected_constraint else COLOR_GLYPH_SELECTED
			if last_conflicting.has(gcid):
				pad_mat.albedo_color = COLOR_CONFLICT
			pad.material_override = pad_mat
			pad.position = label.position - plane_normal() * 0.02
			_constraint_glyphs.add_child(pad)
		_constraint_glyphs.add_child(label)
		_glyph_anchors.append({
			"cid": gcid,
			"pos": gpos,
			"type": gtype,
			"anchor": item["anchor"],
			"offset_px": float(item["offset_px"]),
		})
	var lead := false
	for a in _glyph_anchors:
		if float(a.get("offset_px", 0.0)) >= GLYPH_LEADER_MIN_PX:
			lead = true
			break
	if lead and cam != null:
		var leaders := MeshInstance3D.new()
		leaders.name = "GlyphLeaders"
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var col := COLOR_GLYPH
		col.a = 0.9
		for a in _glyph_anchors:
			if float(a.get("offset_px", 0.0)) < GLYPH_LEADER_MIN_PX:
				continue
			var from_sketch: Vector2 = a["anchor"]
			var to_sketch: Vector2 = a["pos"]
			var sa := cam.unproject_position(to_global(to_model(from_sketch)))
			var sb := cam.unproject_position(to_global(to_model(to_sketch)))
			var others: Array[Rect2] = []
			for b in _glyph_anchors:
				if b == a:
					continue
				var bc: Vector2 = cam.unproject_position(to_global(to_model(b["pos"])))
				var bsize := _glyph_symbol_size_px(str(b.get("type", "")), k)
				others.append(Rect2(bc - bsize * 0.5, bsize))
			var start := _leader_clear_start(sa, sb, others)
			if start.distance_to(sa) > 0.5:
				from_sketch = _sketch_from_screen(cam, start, from_sketch)
				a["anchor"] = from_sketch
			_append_leader_ribbon(im, cam, from_sketch, to_sketch, 1.6, col)
		im.surface_end()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color.WHITE
		leaders.mesh = im
		leaders.material_override = mat
		_constraint_glyphs.add_child(leaders)
	_coincident_sig = _coincident_visibility_sig()


func _sync_coincident_glyphs() -> void:
	var sig := _coincident_visibility_sig()
	if sig == _coincident_sig:
		return
	_rebuild_constraint_glyphs()


func _coincident_visibility_sig() -> String:
	if sketch == null or not active:
		return ""
	var ids: PackedStringArray = []
	for cid in sketch.constraint_ids():
		var cinfo: Dictionary = sketch.constraint_info(cid)
		if str(cinfo.get("type", "")) != "coincident":
			continue
		if _coincident_glyph_visible(str(cid), cinfo):
			ids.append(str(cid))
	ids.sort()
	return "|".join(ids)


func _pinned_coincident_centres() -> Dictionary:
	var out := {}
	if _pointer_screen == Vector2.INF or not is_inside_tree():
		return out
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return out
	var k := _label_px_scale(cam)
	for a in _glyph_anchors:
		if str(a.get("type", "")) != "coincident":
			continue
		var rect := _glyph_screen_rect(a["pos"], "coincident", cam, k)
		if rect.has_point(_pointer_screen):
			out[str(a.get("cid", ""))] = rect.get_center()
	return out


func _restore_pinned_coincident(items: Array, pinned: Dictionary, cam: Camera3D) -> void:
	if pinned.is_empty() or cam == null:
		return
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var cid := str(it.get("cid", ""))
		if not pinned.has(cid):
			continue
		var centre: Vector2 = pinned[cid]
		var anchor: Vector2 = it["anchor"]
		var natural: Vector2 = it["natural"]
		it["centre"] = centre
		it["offset_px"] = natural.distance_to(centre)
		it["pos"] = _sketch_from_screen(cam, centre, anchor)
		items[i] = it


## Keep a coincident leader inside the 14 px vertex hover after projection.
func _clamp_coincident_leaders(items: Array, cam: Camera3D) -> void:
	for i in range(items.size()):
		var it: Dictionary = items[i]
		if str(it.get("type", "")) != "coincident":
			continue
		var natural: Vector2 = it["natural"]
		var centre: Vector2 = it["centre"]
		var anchor: Vector2 = it["anchor"]
		var span := natural.distance_to(centre)
		if span > COINCIDENT_LEADER_CAP and span > 0.5:
			centre = natural + (centre - natural) * (COINCIDENT_LEADER_CAP / span)
		var pos: Vector2 = _sketch_from_screen(cam, centre, anchor)
		var landed := cam.unproject_position(to_global(to_model(pos)))
		var got := natural.distance_to(landed)
		if got > COINCIDENT_LEADER_CAP and got > 0.5:
			centre = natural + (centre - natural) * (13.0 / got)
			pos = _sketch_from_screen(cam, centre, anchor)
		it["centre"] = centre
		it["offset_px"] = natural.distance_to(centre)
		it["pos"] = pos
		items[i] = it


func _pointer_on_glyph(cid: String) -> bool:
	if cid == "" or _pointer_screen == Vector2.INF or not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var k := _label_px_scale(cam)
	for a in _glyph_anchors:
		if str(a.get("cid", "")) != cid:
			continue
		var rect := _glyph_screen_rect(a["pos"], str(a.get("type", "")), cam, k)
		if rect.has_point(_pointer_screen):
			return true
	return false


func _refresh_coincident_keep() -> void:
	var next: Dictionary = {}
	if _pointer_screen != Vector2.INF and is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var k := _label_px_scale(cam)
			for a in _glyph_anchors:
				if str(a.get("type", "")) != "coincident":
					continue
				var rect := _glyph_screen_rect(a["pos"], "coincident", cam, k)
				if rect.has_point(_pointer_screen):
					next[str(a.get("cid", ""))] = true
	_coincident_keep = next


func _coincident_glyph_visible(cid: String, cinfo: Dictionary) -> bool:
	if cid != "" and _coincident_keep.has(cid):
		return true
	# The pointer can move from the vertex onto the badge in one click.
	# Keep is only refreshed while rebuilding, so a badge more than the
	# hover radius from its vertex would hide before that click lands.
	if cid != "" and _pointer_on_glyph(cid):
		return true
	if cid != "" and cid == selected_constraint:
		return true
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for ref in cinfo.get("refs", []):
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = sketch.entity_info(str(ref.get("entity", "")))
		var kind := str(info.get("type", ""))
		var role := str(ref.get("role", "self"))
		if kind == "line" and role != "start" and role != "end":
			continue
		if (kind == "circle" or kind == "arc") and role != "start" and role != "end" and role != "center":
			continue
		var pos: Variant = _ref_pos(ref)
		if not (pos is Vector2):
			continue
		var p: Vector2 = pos
		if _point_on_selected_vertex(p):
			return true
		if cam != null and _pointer_screen != Vector2.INF:
			var screen := cam.unproject_position(to_global(to_model(p)))
			if screen.distance_to(_pointer_screen) <= COINCIDENT_HOVER_PX:
				return true
	return false


func _point_on_selected_vertex(p: Vector2) -> bool:
	if sketch == null:
		return false
	for id in selected:
		var info: Dictionary = sketch.entity_info(str(id))
		if info.is_empty():
			continue
		var pts: Array[Vector2] = []
		match str(info.get("type", "")):
			"line":
				pts = [info["start"], info["end"]]
			"point":
				pts = [info["position"]]
			"circle":
				if info.has("center"):
					pts = [info["center"]]
			"arc":
				if info.has("start"):
					pts.append(info["start"])
				if info.has("end"):
					pts.append(info["end"])
		for v in pts:
			if p.distance_to(v) <= 0.05:
				return true
	return false


func _glyph_curve_penalty(rect: Rect2, anchor_screen: Vector2, cam: Camera3D) -> float:
	if sketch == null or cam == null:
		return 0.0
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if info.is_empty() or bool(info.get("construction", false)):
			continue
		var kind := str(info.get("type", ""))
		if kind != "line" and kind != "circle" and kind != "arc":
			continue
		for s in _curve_screen_samples(info, cam):
			var gap := SketchGeom.point_rect_distance(s, rect)
			var need := PICK_SCREEN_PX + 4.0
			if gap + 0.01 < need:
				return 80000.0 + (need - gap) * 100.0
	return 0.0


## Perpendicular offset that keeps a 25.6 px badge ≥ hit-slop + 4 px off a wall,
## capped at GLYPH_MAX_OFFSET_PX.
func _badge_clear_mm() -> float:
	var ppm := 1.0
	if camera != null and camera.has_method("pixels_per_mm_at_pivot"):
		ppm = maxf(float(camera.pixels_per_mm_at_pivot()), 0.05)
	var k := 1.0
	if camera != null:
		k = _label_px_scale(camera)
	var side := 16.0 * k
	for type in ["horizontal", "vertical", "parallel", "perpendicular", "equal"]:
		side = maxf(side, _glyph_symbol_size_px(type, k).x)
	var need_px := side * 0.5 + PICK_SCREEN_PX + 4.0 + 2.0
	return minf(need_px / ppm, GLYPH_MAX_OFFSET_PX / ppm)


func _curve_screen_samples(info: Dictionary, cam: Camera3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	match str(info.get("type", "")):
		"line":
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			var sa := cam.unproject_position(to_global(to_model(a)))
			var sb := cam.unproject_position(to_global(to_model(b)))
			out.append(sa)
			var dist := sa.distance_to(sb)
			var n := maxi(int(ceil(dist / 8.0)), 1)
			for i in range(1, n):
				out.append(sa.lerp(sb, float(i) / float(n)))
			out.append(sb)
		"circle", "arc":
			var c: Vector2 = info["center"]
			var r: float = float(info.get("radius", 0.0))
			var a0 := 0.0
			var a1 := TAU
			if str(info.get("type", "")) == "arc":
				a0 = float(info.get("start_angle", 0.0))
				a1 = float(info.get("end_angle", TAU))
				if a1 < a0:
					a1 += TAU
			for i in 24:
				var ang := lerpf(a0, a1, float(i) / 23.0)
				out.append(cam.unproject_position(to_global(to_model(c + Vector2.from_angle(ang) * r))))
	return out


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


## True when the click is on a line endpoint and that point is nearer than
## the constraint badge. The badge still wins a click on its own centre.
func _endpoint_nearer_than_glyph(pos2: Vector2, glyph_id: String) -> bool:
	var id := _nearest_entity_at(pos2)
	if id == "":
		return false
	var role := _endpoint_role_at(id, pos2)
	if role != "start" and role != "end":
		return false
	var info: Dictionary = sketch.entity_info(id)
	var ep: Vector2 = info["end"] if role == "end" else info["start"]
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return true
	var click_s := cam.unproject_position(to_global(to_model(pos2)))
	var ep_s := cam.unproject_position(to_global(to_model(ep)))
	var glyph_s := click_s
	for a in _glyph_anchors:
		if str(a.get("cid", "")) != glyph_id:
			continue
		glyph_s = cam.unproject_position(to_global(to_model(a["pos"])))
		break
	return click_s.distance_to(ep_s) < click_s.distance_to(glyph_s)


## Constraint whose drawn glyph rect contains pos2, or "".
## The badge wins over the entity under it. A press that misses the rect
## still selects the curve. Without a camera, fall back to GLYPH_PICK_RADIUS.
func constraint_hit(pos2: Vector2) -> String:
	if sketch == null:
		return ""
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var screen := cam.unproject_position(to_global(to_model(pos2)))
		var best := ""
		var best_d := INF
		var k := _label_px_scale(cam)
		for a in _glyph_anchors:
			var type := str(a.get("type", ""))
			var rect := _glyph_screen_rect(a["pos"], type, cam, k)
			if not rect.has_point(screen):
				continue
			var d := screen.distance_to(rect.get_center())
			if d < best_d:
				best_d = d
				best = str(a.get("cid", ""))
		return best
	var best2 := ""
	var best_mm := GLYPH_PICK_RADIUS
	for a in _glyph_anchors:
		var d2: float = pos2.distance_to(a["pos"])
		if d2 < best_mm:
			best_mm = d2
			best2 = str(a.get("cid", ""))
	return best2


## Slide coincident badges off stable glyphs and off each other. Stable
## badges stay put. The leader stays inside 40 px: at 1280×800 the vertex
## is close to the shaft, and stepping past the cap is what the walk rejects.
func _repair_coincident_glyphs(items: Array, labels: Array[Rect2], cam: Camera3D,
		shaft_y: float) -> void:
	for _pass in 8:
		var moved := false
		for i in range(items.size()):
			var it: Dictionary = items[i]
			if str(it.get("type", "")) != "coincident":
				continue
			var size: Vector2 = it["size"]
			if size == Vector2.ZERO:
				continue
			var natural: Vector2 = it["natural"]
			var centre: Vector2 = it["centre"]
			var anchor: Vector2 = it["anchor"]
			var cost := _coincident_place_cost(items, i, natural, centre, size, labels, shaft_y)
			if cost < 1.0:
				continue
			var best := centre
			var best_cost := cost
			var radii: Array[float] = [0.0, 6.0, 12.0, COINCIDENT_LEADER_CAP]
			for radius in radii:
				var count := 1 if radius < 1.0 else 48
				for k in count:
					var trial := natural
					if radius >= 1.0:
						var ang := TAU * float(k) / float(count)
						trial = natural + Vector2(cos(ang), sin(ang)) * radius
					var c := _coincident_place_cost(items, i, natural, trial, size, labels, shaft_y)
					if c < best_cost - 0.5:
						best_cost = c
						best = trial
			if best.distance_to(centre) <= 0.5:
				continue
			it["centre"] = best
			it["offset_px"] = natural.distance_to(best)
			it["pos"] = _sketch_from_screen(cam, best, anchor)
			items[i] = it
			moved = true
		if not moved:
			break


func _coincident_place_cost(items: Array, index: int, natural: Vector2, centre: Vector2,
		size: Vector2, labels: Array[Rect2], shaft_y: float) -> float:
	var rect := Rect2(centre - size * 0.5, size)
	var dist := natural.distance_to(centre)
	var cost := 0.0
	if dist > COINCIDENT_LEADER_CAP + 0.5:
		cost += 2000000.0 + (dist - COINCIDENT_LEADER_CAP) * 40.0
	# A badge on the vertex covers the pick (Vertical / hex AF). Sit just
	# outside GLYPH_LEADER_MIN_PX so n21 still has a leader to click.
	if dist < GLYPH_LEADER_MIN_PX:
		cost += 50000.0 + (GLYPH_LEADER_MIN_PX - dist) * 200.0
	for j in range(items.size()):
		if j == index:
			continue
		var other: Dictionary = items[j]
		var os: Vector2 = other["size"]
		if os == Vector2.ZERO:
			continue
		var oc: Vector2 = other["centre"]
		var orect := Rect2(oc - os * 0.5, os)
		if orect.has_point(centre) or rect.has_point(oc):
			cost += 1000000.0
		else:
			var frac := _glyph_overlap_fraction(rect, orect)
			if frac > 0.16:
				cost += 100000.0 + frac * 1000.0
			elif frac > 0.0:
				cost += frac * 80.0
		if dist >= GLYPH_LEADER_MIN_PX and _leader_crosses_rect(natural, centre, orect):
			cost += 500000.0
		var onat: Vector2 = other["natural"]
		var ooff := onat.distance_to(oc)
		if ooff >= GLYPH_LEADER_MIN_PX and _leader_crosses_rect(onat, oc, rect):
			cost += 500000.0
	for lr in labels:
		var sep := _rect_separation(rect, lr)
		if sep + 0.01 < GLYPH_LABEL_GAP_PX:
			cost += 2000.0 + (GLYPH_LABEL_GAP_PX - sep) * 8.0
		if dist >= GLYPH_LEADER_MIN_PX and _leader_crosses_rect(natural, centre, lr):
			cost += 4000.0
	if _glyph_below_part(rect, shaft_y):
		cost += 8000.0 + (rect.end.y - shaft_y) * 20.0
	# A 38 px badge centred on the vertex covers the short jaw wall at
	# 1920×1200, so every wall sample selects the constraint. Sit off the line.
	cost += _coincident_line_penalty(rect)
	return cost


func _coincident_line_penalty(rect: Rect2) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if sketch == null or cam == null:
		return 0.0
	var worst := 0.0
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		if info.is_empty() or bool(info.get("construction", false)):
			continue
		if str(info.get("type", "")) != "line":
			continue
		for s in _curve_screen_samples(info, cam):
			var gap := SketchGeom.point_rect_distance(s, rect)
			if gap + 0.01 < 4.0:
				worst = maxf(worst, 90000.0 + (4.0 - gap) * 100.0)
	return worst


func _relax_glyph_layout(items: Array, labels: Array[Rect2], cam: Camera3D,
		shaft_y: float) -> void:
	for _pass in 10:
		var moved := false
		for i in items.size():
			var it: Dictionary = items[i]
			var natural: Vector2 = it["natural"]
			var size: Vector2 = it["size"]
			var centre: Vector2 = it["centre"]
			if size == Vector2.ZERO:
				continue
			var others: Array[Rect2] = []
			for j in items.size():
				if j == i:
					continue
				var oc: Vector2 = items[j]["centre"]
				var os: Vector2 = items[j]["size"]
				others.append(Rect2(oc - os * 0.5, os))
			var rect := Rect2(centre - size * 0.5, size)
			var on_curve := str(it.get("type", "")) != "coincident"
			var score := _glyph_block_score(rect, centre, others, labels, cam, shaft_y, natural, on_curve)
			if score < 1.0:
				continue
			var better := _separate_glyph_screen(natural, size, others, labels, cam, shaft_y, on_curve)
			if better.distance_to(centre) <= 0.5:
				continue
			it["centre"] = better
			it["offset_px"] = natural.distance_to(better)
			it["pos"] = _sketch_from_screen(cam, better, it["anchor"])
			items[i] = it
			moved = true
		if not moved:
			break
	_repel_glyph_items(items, cam, shaft_y)
	_uncross_glyph_leaders(items, labels, cam, shaft_y)


## Swing a leader off other badges without moving the badge onto a wall.
func _uncross_glyph_leaders(items: Array, labels: Array[Rect2], cam: Camera3D,
		shaft_y: float) -> void:
	for _pass in 4:
		var moved := false
		for i in range(items.size()):
			var it: Dictionary = items[i]
			var size: Vector2 = it["size"]
			var natural: Vector2 = it["natural"]
			var centre: Vector2 = it["centre"]
			if size == Vector2.ZERO:
				continue
			var obstacles: Array[Rect2] = []
			for j in range(items.size()):
				if j == i:
					continue
				var os: Vector2 = items[j]["size"]
				if os == Vector2.ZERO:
					continue
				var oc: Vector2 = items[j]["centre"]
				obstacles.append(Rect2(oc - os * 0.5, os))
			for lr in labels:
				obstacles.append(lr)
			if not _leader_crosses_any(natural, centre, obstacles):
				continue
			var cur_curve := _glyph_curve_penalty(Rect2(centre - size * 0.5, size), natural, cam)
			var best := centre
			var best_rank := 1000000.0
			for radius in [12.0, 20.0, 28.0, 36.0, 40.0]:
				for k in 32:
					var ang := TAU * float(k) / 32.0
					var trial: Vector2 = natural + Vector2(cos(ang), sin(ang)) * radius
					var rect := Rect2(trial - size * 0.5, size)
					if _glyph_below_part(rect, shaft_y):
						continue
					var curve := _glyph_curve_penalty(rect, natural, cam)
					if curve > cur_curve + 1.0:
						continue
					if _leader_crosses_any(natural, trial, obstacles):
						continue
					var rank := curve + trial.distance_to(centre) * 0.1
					if rank < best_rank:
						best_rank = rank
						best = trial
			if best.distance_to(centre) <= 0.5:
				if _nudge_crossed_badges(items, i, cam, shaft_y):
					moved = true
				continue
			it["centre"] = best
			it["offset_px"] = natural.distance_to(best)
			it["pos"] = _sketch_from_screen(cam, best, it["anchor"])
			items[i] = it
			moved = true
		if not moved:
			break


## Slide a badge the leader cuts through, perpendicular to that leader,
## staying off the wall. Returns true when the leader is clear afterwards.
func _nudge_crossed_badges(items: Array, leader_i: int, cam: Camera3D,
		shaft_y: float) -> bool:
	var src: Dictionary = items[leader_i]
	var natural: Vector2 = src["natural"]
	var centre: Vector2 = src["centre"]
	var dir := centre - natural
	if dir.length_squared() < 4.0:
		return false
	dir = dir.normalized()
	var normal := Vector2(-dir.y, dir.x)
	var moved := false
	for j in range(items.size()):
		if j == leader_i:
			continue
		var other: Dictionary = items[j]
		var os: Vector2 = other["size"]
		if os == Vector2.ZERO:
			continue
		var oc: Vector2 = other["centre"]
		var orect := Rect2(oc - os * 0.5, os)
		if not _leader_crosses_rect(natural, centre, orect):
			continue
		var onat: Vector2 = other["natural"]
		var cur_curve := _glyph_curve_penalty(orect, onat, cam)
		var best := oc
		var best_rank := 1000000.0
		for dist in [8.0, 16.0, 24.0, 32.0]:
			for sgn in [-1.0, 1.0]:
				var trial: Vector2 = oc + normal * sgn * dist
				if trial.distance_to(onat) > GLYPH_MAX_OFFSET_PX:
					var delta := trial - onat
					trial = onat + delta.normalized() * GLYPH_MAX_OFFSET_PX
				var rect := Rect2(trial - os * 0.5, os)
				if _glyph_below_part(rect, shaft_y):
					continue
				var curve := _glyph_curve_penalty(rect, onat, cam)
				if curve > cur_curve + 1.0:
					continue
				if _leader_crosses_rect(natural, centre, rect):
					continue
				var rank := curve + trial.distance_to(oc) * 0.1
				if rank < best_rank:
					best_rank = rank
					best = trial
		if best.distance_to(oc) <= 0.5:
			continue
		other["centre"] = best
		other["offset_px"] = onat.distance_to(best)
		other["pos"] = _sketch_from_screen(cam, best, other["anchor"])
		items[j] = other
		moved = true
	return moved


func _leader_crosses_any(anchor: Vector2, centre: Vector2, obstacles: Array[Rect2]) -> bool:
	for rect in obstacles:
		if _leader_crosses_rect(anchor, centre, rect):
			return true
	return false


## Push overlapping badges apart inside the 40 px cap, and lift any badge
## whose box crosses the shaft's lower edge.
func _repel_glyph_items(items: Array, cam: Camera3D, shaft_y: float) -> void:
	for _pass in 28:
		var moved := false
		for i in range(items.size()):
			var it: Dictionary = items[i]
			var size: Vector2 = it["size"]
			var centre: Vector2 = it["centre"]
			if size == Vector2.ZERO:
				continue
			var rect := Rect2(centre - size * 0.5, size)
			var push := Vector2.ZERO
			if _glyph_below_part(rect, shaft_y):
				push.y -= (rect.end.y - shaft_y) + 2.0
			for j in range(items.size()):
				if j == i:
					continue
				var other: Dictionary = items[j]
				var oc: Vector2 = other["centre"]
				var os: Vector2 = other["size"]
				var orect := Rect2(oc - os * 0.5, os)
				var frac := _glyph_overlap_fraction(rect, orect)
				if frac <= 0.16:
					continue
				var away := centre - oc
				if away.length_squared() < 1.0:
					away = Vector2(cos(float(i) * 0.9), sin(float(i) * 0.9))
				push += away.normalized() * (4.0 + frac * 10.0)
			if push.length_squared() < 0.25:
				continue
			var next := _clamp_glyph_centre(centre + push, it["natural"], size, shaft_y)
			if next.distance_to(centre) <= 0.4:
				continue
			var next_rect := Rect2(next - size * 0.5, size)
			if str(it.get("type", "")) != "coincident" \
					and _glyph_curve_penalty(next_rect, it["natural"], cam) > _glyph_curve_penalty(rect, it["natural"], cam) + 1.0:
				continue
			it["centre"] = next
			it["offset_px"] = (it["natural"] as Vector2).distance_to(next)
			it["pos"] = _sketch_from_screen(cam, next, it["anchor"])
			items[i] = it
			moved = true
		if not moved:
			break


func _clamp_glyph_centre(centre: Vector2, natural: Vector2, size: Vector2, shaft_y: float) -> Vector2:
	var delta := centre - natural
	if delta.length() > GLYPH_MAX_OFFSET_PX:
		delta = delta.normalized() * GLYPH_MAX_OFFSET_PX
	var clamped := natural + delta
	if shaft_y > 1.0e8:
		return clamped
	var limit := shaft_y - size.y * 0.5 - 1.5
	if clamped.y <= limit:
		return clamped
	# Highest point of the cap at this x. If that still hangs below the
	# shaft, slide toward the anchor (the cap's top) until it clears.
	var room := GLYPH_MAX_OFFSET_PX * GLYPH_MAX_OFFSET_PX - delta.x * delta.x
	var y_lo := natural.y - sqrt(maxf(room, 0.0))
	if y_lo <= limit:
		clamped.y = limit
		return clamped
	var top := natural + Vector2(0.0, -GLYPH_MAX_OFFSET_PX)
	if top.y <= limit:
		return top
	return clamped


## 1 px-ish ribbon in screen space. GL compatibility drops PRIMITIVE_LINES.
func _append_leader_ribbon(im: ImmediateMesh, cam: Camera3D, a_sketch: Vector2,
		b_sketch: Vector2, width_px: float, col: Color) -> void:
	var sa := cam.unproject_position(to_global(to_model(a_sketch)))
	var sb := cam.unproject_position(to_global(to_model(b_sketch)))
	if sa.distance_to(sb) < 1.5:
		return
	var dir := (sb - sa).normalized()
	var n := Vector2(-dir.y, dir.x) * (width_px * 0.5)
	var p0 := _sketch_from_screen(cam, sa + n, a_sketch)
	var p1 := _sketch_from_screen(cam, sa - n, a_sketch)
	var p2 := _sketch_from_screen(cam, sb - n, b_sketch)
	var p3 := _sketch_from_screen(cam, sb + n, b_sketch)
	var lift := plane_normal() * 0.35
	var v0 := _to3(p0) + lift
	var v1 := _to3(p1) + lift
	var v2 := _to3(p2) + lift
	var v3 := _to3(p3) + lift
	im.surface_set_color(col)
	im.surface_add_vertex(v0)
	im.surface_add_vertex(v1)
	im.surface_add_vertex(v2)
	im.surface_add_vertex(v0)
	im.surface_add_vertex(v2)
	im.surface_add_vertex(v3)


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
## True when this click should open the dimension editor.
## Select on a circle's own diameter/radius stacked on the rim picks the
## curve (A12). Letters and the label anchor still open the editor otherwise.
## Draw tools keep the rect-only hit they already asked for.
func _dimension_claims_click(pos2: Vector2, hit: int) -> bool:
	if hit < 0:
		return false
	if _radius_label_on_own_rim(hit, pos2):
		return false
	# The letters, and the label anchor itself, open the editor. A headless
	# viewport clamps the drawn rect off that anchor; the anchor is still the
	# point dimension_hit reports and the point a click on the value uses.
	if _dimension_text_contains(pos2, hit) or _dimension_anchor_contains(pos2, hit):
		return true
	# dimension_hit still includes an 8 px pad and a 22 px halo. At 1280×800
	# that halo covers the upper shaft line, and on a 7.65 mm hex it covers
	# the opposite flat. Select and Smart Dim keep the entity under the pointer.
	if (tool == Tool.SELECT or tool == Tool.SMART_DIM) and entity_at(pos2) != "":
		return false
	return true


## Screen distance from the click to the unclamped label anchor.
## Wide enough for a click on the anchor, short of the 8 px text pad.
const DIM_ANCHOR_SLOP_PX := 4.0


func _dimension_anchor_contains(pos2: Vector2, hit: int) -> bool:
	if hit < 0 or hit >= dimensions.size():
		return false
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		var dim0: Dictionary = dimensions[hit]
		var lp0: Variant = dim0.get("label_pos", null)
		if lp0 == null:
			lp0 = _dimension_label_pos2(dim0)
		return lp0 is Vector2 and pos2.distance_to(lp0) <= 0.5
	var dim: Dictionary = dimensions[hit]
	var lp: Variant = dim.get("label_pos", null)
	if lp == null:
		lp = _dimension_label_pos2(dim)
	if not (lp is Vector2):
		return false
	var sp: Vector2 = cam.unproject_position(_dimension_label_world(lp as Vector2))
	var screen := cam.unproject_position(to_global(to_model(pos2)))
	return screen.distance_to(sp) <= DIM_ANCHOR_SLOP_PX


func _dimension_text_contains(pos2: Vector2, hit: int) -> bool:
	if hit < 0 or hit >= dimensions.size():
		return false
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return true
	var dim: Dictionary = dimensions[hit]
	var lp: Variant = dim.get("label_pos", null)
	if lp == null:
		lp = _dimension_label_pos2(dim)
	if lp == null:
		return false
	var sp: Vector2 = cam.unproject_position(_dimension_label_world(lp as Vector2))
	var rect := _dimension_label_rect(dim, sp, _label_px_scale(cam))
	var screen := cam.unproject_position(to_global(to_model(pos2)))
	return rect.has_point(screen)


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
			var gap := SketchGeom.point_rect_distance(screen, rect)
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
			"ellipse", "elliptical_arc":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				var pts_e := SketchEllipse.polyline(info, 64)
				for i in range(pts_e.size() - 1):
					im.surface_set_color(col)
					im.surface_add_vertex(_to3(pts_e[i]))
					im.surface_add_vertex(_to3(pts_e[i + 1]))
	if temp_axes_visible and view != null and view.doc != null \
			and SketchTempAxes.has_revolve(view.doc):
		var dashes := SketchTempAxes.dashes(plane, -400.0, 400.0)
		if dashes.size() >= 2:
			if not has:
				im.surface_begin(Mesh.PRIMITIVE_LINES)
				has = true
			for i in range(0, dashes.size() - 1, 2):
				im.surface_set_color(SketchTempAxes.COLOR)
				im.surface_add_vertex(dashes[i])
				im.surface_add_vertex(dashes[i + 1])
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
		# A pointer still on the centre used to draw nothing (and surface_end
		# with zero vertices). Keep a 1.5 mm half-length and half-width.
		if along.length() < JAW_PREVIEW_MIN_HALF_W_MM:
			along = Vector2(JAW_PREVIEW_MIN_HALF_W_MM, 0.0) if along.length() <= 1e-6 \
					else along.normalized() * JAW_PREVIEW_MIN_HALF_W_MM
		half_w = maxf(along.length() * JAW_PREVIEW_ASPECT, JAW_PREVIEW_MIN_HALF_W_MM)
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
			Tool.ELLIPSE:
				var c := _tool_points[0]
				if _tool_points.size() == 1:
					im.surface_add_vertex(_to3(c))
					im.surface_add_vertex(_to3(tip))
				else:
					var posed := SketchEllipse.pose(c, _tool_points[1], tip)
					if posed.is_empty():
						im.surface_add_vertex(_to3(c))
						im.surface_add_vertex(_to3(tip))
					else:
						posed["type"] = "ellipse"
						_append_entity_lines(im, posed)
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
## Default chain tolerance matches contour_faces (0.05 mm). Callers that pass a
## looser tol (auto-close at 0.5 mm) keep that tolerance.
static func profile_is_closed(sk: SxSketch, tol: float = 0.05) -> bool:
	if sk == null:
		return false
	var segs: Array = []  # {a: Vector2, b: Vector2}
	var circs: Array = []  # {c: Vector2, r: float}
	var closed_prims := 0
	for id in sk.entity_ids():
		if sk.is_construction(id):
			continue
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"circle":
				circs.append({"c": info["center"], "r": float(info.get("radius", 0.0))})
				closed_prims += 1
			"ellipse":
				closed_prims += 1
			"elliptical_arc":
				var pea: Vector2 = info["start"] if info.has("start") else info["center"]
				var peb: Vector2 = info["end"] if info.has("end") else info["center"]
				if pea.distance_to(peb) > 1e-9:
					segs.append({"a": pea, "b": peb, "used": false})
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
		return closed_prims > 0
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
