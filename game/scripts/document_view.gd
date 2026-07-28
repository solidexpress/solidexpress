class_name DocumentView
extends Node3D
## View-model bridging SxDocument (kernel, Z-up) to the scene tree.
## Lives under ModelSpace (rotated so kernel +Z is world up). One
## MeshInstance3D child per body; one ArrayMesh surface per B-rep face,
## surface index order matching get_face_ids().

signal document_changed
signal selection_changed(body_id: String, face_id: String)
## Exact B-rep hit from the latest select_ray (even when selection is unchanged).
## Used by armed ops (hole place, pattern direction) that need the pick point.
signal picked(body_id: String, face_id: String, point: Vector3)
## Emitted when section clipping is enabled or cleared (world bg, HUD, etc.).
signal section_changed(enabled: bool)

const BODY_COLOR := Color(0.72, 0.74, 0.78)
## Cold brushed-metal defaults so canyon HDRI reflections read on bodies.
const BODY_METALLIC := 0.92
const BODY_ROUGHNESS := 0.35
const SELECTED_BODY_COLOR := Color(0.55, 0.68, 0.9)
const SELECTED_FACE_COLOR := Color(1.0, 0.62, 0.15)
const HOVER_BODY_COLOR := Color(0.78, 0.84, 0.92)
const HOVER_FACE_COLOR := Color(0.95, 0.82, 0.45)
const MATE_ANCHOR_COLOR := Color(0.35, 0.85, 0.45)
const EDGE_COLOR := Color(0.12, 0.13, 0.16)
const DATUM_PLANE_COLOR := Color(0.35, 0.55, 0.85, 0.22)
const DATUM_AXIS_COLOR := Color(0.85, 0.35, 0.2)
const DATUM_POINT_COLOR := Color(0.2, 0.7, 0.45)

enum DisplayMode { SHADED, SHADED_EDGES, WIREFRAME }

var doc: SxDocument = SxDocument.new()
## Selection-set helpers (toggle / clear / query). DocumentView keeps owning
## the arrays below for public API stability.
var _selection := SelectionService.new()
## Primary (most recent) selection — single-select API, kept for panels/tests.
var selected_body := ""
var selected_face := ""
var selected_edge := ""
## Multi-select sets (Ctrl+click). Always contain the primary selection too:
## whole bodies, individual faces, and individual edges respectively.
var selected_bodies: Array[String] = []
var selected_faces: Array[String] = []
var selected_edges: Array[String] = []
## Selected component instance (viewport click on an instance mesh).
var selected_instance := ""
## Last successful select_ray hit (model space). Empty body means no pick yet.
var last_pick_body := ""
var last_pick_face := ""
var last_pick_point := Vector3.ZERO
## Pre-selection hover (distinct from selected materials).
var hovered_body := ""
var hovered_face := ""
var hovered_edge := ""
var display_mode := DisplayMode.SHADED_EDGES
## True while a section (clipping) plane is active on body meshes.
## Edge overlay lines are not clipped in v1.
var section_enabled := false
## Body ids currently hidden from view / picking (id -> true).
var hidden_bodies := {}
## Body ids remembered by Copy/Cut for Paste (cut clones may be hidden).
var _clipboard_bodies: Array[String] = []
## Pastes since last copy — scales the XY offset so each paste lands further away.
var _clipboard_paste_count := 0
## True when clipboard holds cut materializations (hidden until first paste).
var _clipboard_cut := false

const EDGE_PICK_TOLERANCE := 2.5  # model units (mm)
const DATUM_PLANE_HALF := 20.0  # ~40 unit square
const DATUM_AXIS_HALF_LEN := 100.0
const DATUM_POINT_RADIUS := 1.5

var _body_nodes := {}  # body_id -> MeshInstance3D
var _datum_nodes := {}  # datum_id -> Node3D
var _instance_nodes := {}  # instance_id -> MeshInstance3D
var _face_ids := {}    # body_id -> PackedStringArray
var _body_materials := {}  # body_id -> ShaderMaterial (tinted by body color)
var _instance_materials := {}  # instance_id -> Material
var _edge_highlight: MeshInstance3D
var _selection_corners: MeshInstance3D
## SketchPadOverlay — typed loosely to avoid class_name cycle with DocumentView.
var sketch_pads: Node3D
var path_overlay: Node3D
## Sketch feature currently being edited (hides that yellow pad); "" = none.
var _editing_sketch_fid := ""
var _base_material: ShaderMaterial
var _selected_body_material: ShaderMaterial
var _selected_face_material: ShaderMaterial
var _hover_body_material: ShaderMaterial
var _hover_face_material: ShaderMaterial
var _mate_anchor_material: ShaderMaterial
## First face of an armed mate pick — stays tinted green until the second
## pick so users can see the anchor (AssemblyPanel sets/clears this).
var mate_anchor_face := "":
	set(v):
		mate_anchor_face = v
		_apply_selection_materials()
var _edge_material: StandardMaterial3D
var _selected_edge_material: StandardMaterial3D
var _hover_edge_material: StandardMaterial3D
var _selected_edge_overlay: StandardMaterial3D
var _wireframe_hidden_material: StandardMaterial3D
var _datum_plane_material: StandardMaterial3D
var _datum_axis_material: StandardMaterial3D
var _datum_point_material: StandardMaterial3D
var _body_shader: Shader
var _section_shader: Shader
var _section_point := Vector3.ZERO
var _section_normal := Vector3.RIGHT


func _ready() -> void:
	_body_shader = _make_body_shader()
	_base_material = _make_material(BODY_COLOR)
	_selected_body_material = _make_material(SELECTED_BODY_COLOR)
	_selected_face_material = _make_material(SELECTED_FACE_COLOR, 0.45)
	_hover_body_material = _make_material(HOVER_BODY_COLOR)
	_hover_face_material = _make_material(HOVER_FACE_COLOR, 0.2)
	_mate_anchor_material = _make_material(MATE_ANCHOR_COLOR, 0.45)
	_edge_material = StandardMaterial3D.new()
	_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_material.albedo_color = EDGE_COLOR
	_selected_edge_material = StandardMaterial3D.new()
	_selected_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selected_edge_material.albedo_color = SELECTED_BODY_COLOR
	_hover_edge_material = StandardMaterial3D.new()
	_hover_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_edge_material.albedo_color = HOVER_FACE_COLOR
	_hover_edge_material.no_depth_test = true
	_selected_edge_overlay = StandardMaterial3D.new()
	_selected_edge_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selected_edge_overlay.albedo_color = SELECTED_FACE_COLOR
	_selected_edge_overlay.no_depth_test = true
	_wireframe_hidden_material = StandardMaterial3D.new()
	_wireframe_hidden_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wireframe_hidden_material.albedo_color = Color(0, 0, 0, 0)
	_datum_plane_material = StandardMaterial3D.new()
	_datum_plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_datum_plane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_datum_plane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_datum_plane_material.albedo_color = DATUM_PLANE_COLOR
	_datum_axis_material = StandardMaterial3D.new()
	_datum_axis_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_datum_axis_material.albedo_color = DATUM_AXIS_COLOR
	_datum_point_material = StandardMaterial3D.new()
	_datum_point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_datum_point_material.albedo_color = DATUM_POINT_COLOR
	_section_shader = _make_section_shader()
	_edge_highlight = MeshInstance3D.new()
	_edge_highlight.name = "EdgeHighlight"
	_edge_highlight.material_override = _selected_edge_overlay
	add_child(_edge_highlight)
	sketch_pads = SketchPadOverlay.new()
	sketch_pads.name = "SketchPads"
	sketch_pads.view = self
	add_child(sketch_pads)
	path_overlay = PathOverlay.new()
	path_overlay.name = "PathOverlay"
	path_overlay.view = self
	add_child(path_overlay)
	var corner_mat := StandardMaterial3D.new()
	corner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	corner_mat.albedo_color = Color(0.15, 0.55, 1.0)
	corner_mat.no_depth_test = true
	_selection_corners = MeshInstance3D.new()
	_selection_corners.name = "SelectionCorners"
	_selection_corners.material_override = corner_mat
	add_child(_selection_corners)
	refresh()


## Front faces full albedo; back faces darker so hole/shell interiors read.
## Must stay fully opaque (no ALPHA write): translucent body materials force
## Godot's transparent pass and turn a boolean hole into a slideshow on orbit.
func _make_body_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(0.72, 0.74, 0.78, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.92;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float emission_energy : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	if (albedo_color.a < 0.01) {
		discard;
	}
	bool back = !FRONT_FACING;
	ALBEDO = albedo_color.rgb * (back ? 0.55 : 1.0);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = albedo_color.rgb * emission_energy;
}
"""
	return s


func _make_material(color: Color, emission_energy: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _body_shader
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("metallic", BODY_METALLIC)
	m.set_shader_parameter("roughness", BODY_ROUGHNESS)
	m.set_shader_parameter("emission_energy", emission_energy)
	return m


func _make_section_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(0.72, 0.74, 0.78, 1.0);
uniform vec3 section_point = vec3(0.0);
uniform vec3 section_normal = vec3(1.0, 0.0, 0.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.92;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 2.0) = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Discard the half-space in front of the section plane.
	if (dot(world_position - section_point, section_normal) > 0.0) {
		discard;
	}
	// Wireframe mode hides solid faces via transparent albedo.
	if (albedo_color.a < 0.01) {
		discard;
	}
	bool back = !FRONT_FACING;
	ALBEDO = albedo_color.rgb * (back ? 0.55 : 1.0);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission_color.rgb * emission_energy;
}
"""
	return s


func _make_section_material(albedo: Color, emission: Color = Color(0, 0, 0), emission_energy: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _section_shader
	m.set_shader_parameter("albedo_color", albedo)
	m.set_shader_parameter("section_point", _section_point)
	m.set_shader_parameter("section_normal", _section_normal)
	m.set_shader_parameter("metallic", BODY_METALLIC)
	m.set_shader_parameter("roughness", BODY_ROUGHNESS)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	return m


## Enable section-view clipping. Fragments with
## `dot(world_pos - point, normal) > 0` are discarded on body meshes.
## Edge overlay lines are left unclipped in v1.
func set_section_plane(point: Vector3, normal: Vector3) -> void:
	_section_point = point
	_section_normal = normal.normalized() if normal.length_squared() > 1e-12 else Vector3.RIGHT
	section_enabled = true
	_apply_selection_materials()
	section_changed.emit(true)


## Disable section-view clipping and restore body ShaderMaterials.
func clear_section_plane() -> void:
	section_enabled = false
	_apply_selection_materials()
	section_changed.emit(false)


func set_display_mode(mode: int) -> void:
	display_mode = mode
	_apply_selection_materials()


func cycle_display_mode() -> int:
	set_display_mode((display_mode + 1) % 3)
	return display_mode


# --- creation (palette drop / click-to-place) ---

## Default edge length (mm) for palette primitives — sized for the close 0.1 mm grid view.
const DEFAULT_PRIMITIVE_MM := 5.0


## Default footprint/height used when the place HUD has not overridden sizes.
static func default_primitive_size(kind: String) -> Vector3:
	var s := DEFAULT_PRIMITIVE_MM
	match kind:
		"box":
			return Vector3(s, s, s)
		"cylinder":
			return Vector3(s, s, s)  # W=H=diameter, D=height
		"sphere":
			return Vector3(s, s, s)  # diameter
		"cone":
			return Vector3(s, 0.0, s)  # bottom Ø, top Ø (0 = apex), height
		"torus":
			return Vector3(s * 1.2, s * 0.32, s * 0.32)  # major Ø, tube Ø
		_:
			return Vector3(s, s, s)


## Insert a palette primitive sitting on a floor through `world_point`.
## Default: world XY floor, height along +Z. Pass `sit_normal` / `plane_x` to
## place on an active plane (height along sit_normal, footprint along plane_x/y).
## Optional `size` (W,H,D mm) overrides the default; see `default_primitive_size`.
func insert_primitive(kind: String, world_point: Vector3, size := Vector3.ZERO,
		sit_normal := Vector3(0, 0, 1), plane_x := Vector3(1, 0, 0)) -> String:
	var p := world_point
	var s := size if size.x > 0.0 else default_primitive_size(kind)
	var n := sit_normal.normalized()
	if n.length_squared() < 1e-12:
		n = Vector3(0, 0, 1)
	var x := plane_x - n * plane_x.dot(n)
	if x.length_squared() < 1e-12:
		x = n.cross(Vector3(0, 0, 1))
		if x.length_squared() < 1e-12:
			x = Vector3.RIGHT
	x = x.normalized()
	var y := n.cross(x).normalized()
	var origin := p
	var a := 0.0
	var b := 0.0
	var c := 0.0
	match kind:
		"box":
			a = s.x
			b = s.y
			c = s.z
			origin = p - x * (s.x * 0.5) - y * (s.y * 0.5)
		"cylinder":
			# a=radius, b=height — HUD W/H are diameter; D is height.
			a = s.x * 0.5
			b = s.z
			c = 0.0
			origin = p
		"sphere":
			a = s.x * 0.5
			b = 0.0
			c = 0.0
			origin = p + n * (s.x * 0.5)
		"cone":
			# a=bottom radius, b=top radius, c=height
			a = s.x * 0.5
			b = s.y * 0.5
			c = s.z
			origin = p
		"torus":
			a = s.x * 0.5
			b = s.y * 0.5
			c = 0.0
			origin = p + n * (s.y * 0.5)
		_:
			push_error("unknown primitive kind: " + kind)
			return ""
	var fid := doc.graph_add_primitive(kind, a, b, c, origin)
	if fid == "":
		return ""
	# Stamp orientation when not the default Z-up / +X frame (regen rebuilds).
	var needs_frame := not n.is_equal_approx(Vector3(0, 0, 1)) \
			or not x.is_equal_approx(Vector3(1, 0, 0))
	if needs_frame:
		var params := _feature_params_by_id(fid)
		if not params.is_empty():
			params["origin"] = _vec3_to_param(origin)
			params["z_dir"] = _vec3_to_param(n)
			params["x_dir"] = _vec3_to_param(x)
			doc.graph_set_params(fid, JSON.stringify(params))
	var id := body_of_feature(fid)
	_after_mutation()
	if id != "":
		select_entity(id, "")
	return id


# --- feature graph helpers ---

func body_of_feature(fid: String) -> String:
	if fid == "":
		return ""
	for f in doc.graph_features():
		if f["id"] == fid:
			return f["output_body"]
	return ""


func feature_of_body(body_id: String) -> String:
	for f in doc.graph_features():
		if f["output_body"] == body_id:
			return f["id"]
	return ""


## Feature dict for the body, or {} when it is not a timeline feature.
func feature_info(body_id: String) -> Dictionary:
	var fid := feature_of_body(body_id)
	if fid == "":
		return {}
	for f in doc.graph_features():
		if f["id"] == fid:
			return f
	return {}


## Parsed params of a body's owning feature, or {}.
func feature_params(body_id: String) -> Dictionary:
	var info := feature_info(body_id)
	if info.is_empty():
		return {}
	var parsed = JSON.parse_string(info.get("params", "{}"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## True when the body is a resizable timeline primitive.
func is_primitive_body(body_id: String) -> bool:
	var info := feature_info(body_id)
	return not info.is_empty() and str(info.get("type", "")) == "primitive"


## True when the body is an import_step / import_stl feature (uniform scale).
func is_import_body(body_id: String) -> bool:
	var info := feature_info(body_id)
	if info.is_empty():
		return false
	var t := str(info.get("type", ""))
	return t == "import_step" or t == "import_stl"


## True when W×H×D (or uniform scale) can be edited on the selection.
func is_scalable_body(body_id: String) -> bool:
	return is_primitive_body(body_id) or is_import_body(body_id)


## Combined selection AABB in model space: {min, max, size, center} or {}.
func selection_bbox() -> Dictionary:
	var ids: Array[String] = []
	for b in selected_bodies:
		ids.append(b)
	if ids.is_empty() and selected_body != "":
		ids.append(selected_body)
	if ids.is_empty():
		return {}
	var mn := Vector3(1e12, 1e12, 1e12)
	var mx := Vector3(-1e12, -1e12, -1e12)
	var any := false
	for id in ids:
		var bb: Dictionary = doc.measure_bbox(id)
		if bb.is_empty():
			continue
		any = true
		mn = mn.min(bb["min"])
		mx = mx.max(bb["max"])
	if not any:
		return {}
	return {"min": mn, "max": mx, "size": mx - mn, "center": (mn + mx) * 0.5}


## Resize a primitive body so its AABB becomes `new_min`..`new_max`.
## Returns false when the body is not a primitive or the edit fails.
## Cylinders / cones honor optional `z_dir` so end-face stretches change length
## after a rotate, instead of rewriting an upright Z-axis solid.
func resize_primitive_aabb(body_id: String, new_min: Vector3, new_max: Vector3) -> bool:
	if not is_primitive_body(body_id):
		return false
	var info := feature_info(body_id)
	var params := feature_params(body_id)
	if params.is_empty():
		return false
	var size := new_max - new_min
	if size.x < 0.1 or size.y < 0.1 or size.z < 0.1:
		return false
	var kind := str(params.get("kind", "box"))
	match kind:
		"box":
			params["a"] = size.x
			params["b"] = size.y
			params["c"] = size.z
			params["origin"] = [new_min.x, new_min.y, new_min.z]
		"cylinder":
			_apply_cyl_cone_aabb_params(params, size, new_min, new_max, false)
		"sphere":
			var r2 := minf(size.x, minf(size.y, size.z)) * 0.5
			params["a"] = r2
			params["origin"] = [new_min.x + r2, new_min.y + r2, new_min.z + r2]
		"cone":
			_apply_cyl_cone_aabb_params(params, size, new_min, new_max, true)
		"torus":
			params["a"] = size.x * 0.5
			params["b"] = size.z * 0.5
			params["origin"] = [new_min.x + size.x * 0.5, new_min.y + size.y * 0.5,
					new_min.z + size.z * 0.5]
		_:
			return false
	var keep := body_id
	if not doc.graph_set_params(info["id"], JSON.stringify(params)):
		return false
	_after_mutation()
	select_entity(keep, "")
	return true


static func _param_vec3(params: Dictionary, key: String, fallback: Vector3) -> Vector3:
	if not params.has(key):
		return fallback
	var v = params[key]
	if typeof(v) != TYPE_ARRAY and typeof(v) != TYPE_PACKED_FLOAT32_ARRAY \
			and typeof(v) != TYPE_PACKED_FLOAT64_ARRAY:
		return fallback
	if v.size() < 3:
		return fallback
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


static func _vec3_to_param(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Map a world AABB onto cylinder/cone params using `z_dir` (default +Z).
static func _apply_cyl_cone_aabb_params(params: Dictionary, size: Vector3,
		new_min: Vector3, new_max: Vector3, is_cone: bool) -> void:
	var z := _param_vec3(params, "z_dir", Vector3(0, 0, 1))
	if z.length_squared() < 1e-12:
		z = Vector3(0, 0, 1)
	else:
		z = z.normalized()
	var axis := _dominant_axis(z)
	var height: float = size[axis]
	var r_a := size[(axis + 1) % 3]
	var r_b := size[(axis + 2) % 3]
	var r := minf(r_a, r_b) * 0.5
	params["a"] = r
	if is_cone:
		params["b"] = float(params.get("b", 0.0))
		params["c"] = height
	else:
		params["b"] = height
	var center := (new_min + new_max) * 0.5
	var origin := center - z * (height * 0.5)
	params["origin"] = _vec3_to_param(origin)
	params["z_dir"] = _vec3_to_param(z)
	if not params.has("x_dir"):
		var x := Vector3(1, 0, 0) if absf(z.dot(Vector3(1, 0, 0))) < 0.9 else Vector3(0, 0, -1)
		x = (x - z * x.dot(z)).normalized()
		params["x_dir"] = _vec3_to_param(x)


static func _dominant_axis(v: Vector3) -> int:
	if absf(v.x) >= absf(v.y) and absf(v.x) >= absf(v.z):
		return 0
	if absf(v.y) >= absf(v.x) and absf(v.y) >= absf(v.z):
		return 1
	return 2


## Re-read cylinder/cone radius+height+origin from the live body AABB so a prior
## push/pull (or any BREP edit) does not get wiped by the next parametric regen.
func _sync_cyl_cone_params_from_body(body_id: String, params: Dictionary) -> void:
	var kind := str(params.get("kind", ""))
	if kind != "cylinder" and kind != "cone":
		return
	var bb: Dictionary = doc.measure_bbox(body_id)
	if bb.is_empty():
		return
	_apply_cyl_cone_aabb_params(params, bb["max"] - bb["min"], bb["min"], bb["max"],
			kind == "cone")


func graph_changed() -> void:
	clear_selection()
	_after_mutation()


## Boolean two bodies. Timeline-owned bodies get a graph Boolean feature so later
## primitive edits / regenerates keep the cut (tool stays consumed). Free bodies
## use the imperative boolean_op path.
func boolean_bodies(target: String, tool: String, op: String) -> bool:
	if target == "" or tool == "" or target == tool:
		return false
	var target_fid := feature_of_body(target)
	var tool_fid := feature_of_body(tool)
	if target_fid != "" and tool_fid != "":
		var fid := doc.graph_add_boolean(op, target_fid, tool_fid)
		if fid == "":
			return false
		_after_mutation()
		return true
	if not doc.boolean_op(target, tool, op, false):
		return false
	_after_mutation()
	return true


# --- selection ---

## Ray in model space. Returns true on hit. With `additive` (Shift/Ctrl+click) the
## hit entity is toggled into the multi-select sets instead of replacing the
## selection: a face (or edge) when the hit body is already selected, else
## the whole body. Hidden bodies are skipped (pick-through).
func select_ray(origin: Vector3, direction: Vector3, additive := false) -> bool:
	var hit: Dictionary = _pick_visible(origin, direction)
	if hit.is_empty():
		if not additive:
			clear_selection()
		return false
	_record_pick(hit["body"], hit["face"], hit["point"])
	if additive:
		_toggle_hit(hit)
		return true
	# First click on a body selects the body; clicking again refines to an
	# edge (when the hit point is within tolerance of one) or the hit face.
	# A third click on the same face collapses back to the body. Armed ops
	# (hole place, etc.) already received `picked` above with the hit point.
	if selected_body == hit["body"]:
		var edge := _edge_near_point(hit["body"], hit["point"])
		if edge != "" and edge != selected_edge:
			select_edge(hit["body"], edge)
			return true
		if selected_face != hit["face"]:
			select_entity(hit["body"], hit["face"])
			return true
	select_entity(hit["body"], "")
	return true


func _record_pick(body_id: String, face_id: String, point: Vector3) -> void:
	last_pick_body = body_id
	last_pick_face = face_id
	last_pick_point = point
	picked.emit(body_id, face_id, point)


## Kernel pick that advances past hidden bodies so the next solid can be hit.
func _pick_visible(origin: Vector3, direction: Vector3) -> Dictionary:
	var d := direction.normalized() if direction.length_squared() > 1e-12 else direction
	var o := origin
	for _i in range(32):
		var hit: Dictionary = doc.pick(o, d)
		if hit.is_empty():
			return {}
		if not hidden_bodies.has(hit["body"]):
			return hit
		var pt: Vector3 = hit["point"]
		o = pt + d * 0.05
	return {}


func _toggle_hit(hit: Dictionary) -> void:
	var body: String = hit["body"]
	var body_selected := _selection.body_selected(selected_body, selected_bodies, body)
	# In a multi-body set, ctrl+click on a member deselects it (SolidWorks
	# behavior); refinement to faces/edges applies to single-body selections.
	if selected_bodies.size() > 1 and selected_bodies.has(body):
		selected_bodies.erase(body)
	elif body_selected:
		# Refine within an already-selected body: edge first, then face.
		var edge := _edge_near_point(body, hit["point"])
		if edge != "":
			_selection.toggle_in(selected_edges, edge)
		else:
			_selection.toggle_in(selected_faces, hit["face"])
		# Keep the body's whole-body tint only if it has no sub-selection left.
		if selected_faces.is_empty() and selected_edges.is_empty():
			if not selected_bodies.has(body):
				selected_bodies.append(body)
		else:
			selected_bodies.erase(body)
	else:
		_selection.toggle_in(selected_bodies, body)
	_sync_primary_from_sets()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


## Primary selection mirrors the most recently added set entry so existing
## single-select consumers (panels, cards) keep working during multi-select.
func _sync_primary_from_sets() -> void:
	if not selected_edges.is_empty():
		selected_edge = selected_edges.back()
		selected_body = _owner_body_of(selected_edge)
		selected_face = ""
	elif not selected_faces.is_empty():
		selected_face = selected_faces.back()
		selected_edge = ""
		selected_body = _owner_body_of(selected_face)
	elif not selected_bodies.is_empty():
		selected_body = selected_bodies.back()
		selected_face = ""
		selected_edge = ""
	else:
		selected_body = ""
		selected_face = ""
		selected_edge = ""


func _owner_body_of(subshape_id: String) -> String:
	for body_id in _face_ids:
		var faces: PackedStringArray = _face_ids[body_id]
		if faces.has(subshape_id):
			return body_id
	# Not a face: check edges per body.
	for body_id in _body_nodes:
		var lines: Dictionary = doc.get_edge_lines(body_id)
		if lines.has(subshape_id):
			return body_id
	return selected_body


## Number of selected entities across all sets (0 when nothing selected).
func selection_size() -> int:
	return _selection.selection_count(
		selected_bodies, selected_faces, selected_edges, selected_body)


## Closest edge of `body_id` to a model-space point, "" when none in tolerance.
func _edge_near_point(body_id: String, point: Vector3) -> String:
	var lines: Dictionary = doc.get_edge_lines(body_id)
	var best_id := ""
	var best_d := EDGE_PICK_TOLERANCE
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		for i in range(pts.size() - 1):
			var d := _point_segment_distance3(point, pts[i], pts[i + 1])
			if d < best_d:
				best_d = d
				best_id = edge_id
	return best_id


## Closest point on any edge of `body_id` to `point` (no pick tolerance).
## Returns `point` unchanged when the body has no edge polylines.
func closest_edge_point(body_id: String, point: Vector3) -> Vector3:
	var lines: Dictionary = doc.get_edge_lines(body_id)
	var best := point
	var best_d := INF
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		for i in range(pts.size() - 1):
			var q := _closest_point_on_segment3(point, pts[i], pts[i + 1])
			var d := point.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best = q
	return best


## Snap candidates for tap-measure / planting the X: corners, edge midpoints,
## and face (surface) midpoints. Nearest Euclidean wins.
func measure_snap_candidates(body_id: String) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	var bb: Dictionary = doc.measure_bbox(body_id)
	if not bb.is_empty():
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		for x in [mn.x, mx.x]:
			for y in [mn.y, mx.y]:
				for z in [mn.z, mx.z]:
					candidates.append(Vector3(x, y, z))
	var lines: Dictionary = doc.get_edge_lines(body_id)
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.is_empty():
			continue
		candidates.append(pts[0])
		if pts.size() > 1:
			candidates.append(pts[pts.size() - 1])
			candidates.append(_polyline_midpoint(pts))
	for face_id in doc.get_face_ids(body_id):
		candidates.append(doc.face_midpoint(face_id))
	return candidates


func _polyline_midpoint(pts: PackedVector3Array) -> Vector3:
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector3.ZERO
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if total < 1e-12:
		return pts[0]
	var half := total * 0.5
	var acc := 0.0
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= half:
			var t := 0.0 if seg < 1e-12 else (half - acc) / seg
			return pts[i].lerp(pts[i + 1], t)
		acc += seg
	return pts[pts.size() - 1]


## Closest measure snap (corner / edge mid / surface mid) to `point`.
func closest_measure_snap(body_id: String, point: Vector3) -> Vector3:
	var candidates := measure_snap_candidates(body_id)
	if candidates.is_empty():
		return closest_edge_point(body_id, point)
	var best: Vector3 = candidates[0]
	var best_d := point.distance_squared_to(best)
	for i in range(1, candidates.size()):
		var c: Vector3 = candidates[i]
		var d := point.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best


## Closest corner to `point` — AABB corners plus edge endpoints (vertices).
## Used when planting / replanting the measure X so it snaps to corners.
## Prefer `closest_measure_snap` for full corner + mid + surface snap.
func closest_corner_point(body_id: String, point: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	var bb: Dictionary = doc.measure_bbox(body_id)
	if not bb.is_empty():
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		for x in [mn.x, mx.x]:
			for y in [mn.y, mx.y]:
				for z in [mn.z, mx.z]:
					candidates.append(Vector3(x, y, z))
	var lines: Dictionary = doc.get_edge_lines(body_id)
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.is_empty():
			continue
		candidates.append(pts[0])
		if pts.size() > 1:
			candidates.append(pts[pts.size() - 1])
	if candidates.is_empty():
		return closest_edge_point(body_id, point)
	var best: Vector3 = candidates[0]
	var best_d := point.distance_squared_to(best)
	for i in range(1, candidates.size()):
		var c: Vector3 = candidates[i]
		var d := point.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best


## Foot of the perpendicular from `from` onto `body_id` (closest surface point).
## Falls back to closest edge point when the kernel query fails.
func closest_surface_point(body_id: String, from: Vector3) -> Vector3:
	var r: Dictionary = doc.closest_point_on(body_id, from)
	if not r.is_empty() and r.has("point_b"):
		return r["point_b"] as Vector3
	return closest_edge_point(body_id, from)


func _point_segment_distance3(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(_closest_point_on_segment3(p, a, b))


func _closest_point_on_segment3(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t


func select_edge(body_id: String, edge_id: String) -> void:
	selected_body = body_id
	selected_face = ""
	selected_edge = edge_id
	selected_bodies.clear()
	selected_faces.clear()
	selected_edges.assign([edge_id] if edge_id != "" else [])
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func pick_info(origin: Vector3, direction: Vector3) -> Dictionary:
	return _pick_visible(origin, direction)


## Select every visible body whose screen AABB matches `rect`.
## `crossing=false` (window): AABB must be fully inside the rect.
## `crossing=true`: AABB intersects the rect (partial capture counts).
## With `additive` false, replaces the selection; with true, unions into
## `selected_bodies`. Primary selection syncs to the last body in the set.
func select_in_rect(rect: Rect2, camera: Camera3D, model_space: Node3D,
		additive := false, crossing := false) -> void:
	var band := rect.abs()
	var hits: Array[String] = []
	for id in _body_nodes:
		if hidden_bodies.has(id):
			continue
		var scr: Rect2 = body_screen_aabb(id, camera, model_space)
		if scr.size == Vector2.ZERO:
			continue
		var ok := band.encloses(scr) if not crossing else band.intersects(scr)
		if ok:
			hits.append(id)
	if not additive:
		selected_bodies.assign(hits)
		selected_faces.clear()
		selected_edges.clear()
	else:
		for id in hits:
			if not selected_bodies.has(id):
				selected_bodies.append(id)
	_sync_primary_from_sets()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


## Axis-aligned screen rect covering the body's mesh AABB, or zero-size if behind.
## `model_space` is unused (kept for call-site symmetry with pad picks).
func body_screen_aabb(body_id: String, camera: Camera3D, _model_space: Node3D = null) -> Rect2:
	var node: MeshInstance3D = _body_nodes.get(body_id)
	if node == null or node.mesh == null or camera == null:
		return Rect2()
	var aabb := node.get_aabb()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var any := false
	for i in range(8):
		var world: Vector3 = node.to_global(aabb.get_endpoint(i))
		if camera.is_position_behind(world):
			continue
		var s: Vector2 = camera.unproject_position(world)
		mn = mn.min(s)
		mx = mx.max(s)
		any = true
	if not any:
		return Rect2()
	return Rect2(mn, mx - mn)


## Feature similarity key for Select Similar (primitive kind or feature type).
func body_similarity_key(body_id: String) -> String:
	var info := feature_info(body_id)
	if info.is_empty():
		return ""
	var t := str(info.get("type", ""))
	if t == "primitive":
		return "primitive:%s" % str(feature_params(body_id).get("kind", ""))
	return t


## Expand selection to every visible body sharing a similarity key with the
## current selection (or primary body). Returns how many bodies were added.
func select_similar() -> int:
	var seeds: Array[String] = []
	for b in selected_bodies:
		seeds.append(b)
	if seeds.is_empty() and selected_body != "":
		seeds.append(selected_body)
	if seeds.is_empty():
		return 0
	var keys := {}
	for b in seeds:
		var k := body_similarity_key(b)
		if k != "":
			keys[k] = true
	if keys.is_empty():
		return 0
	var added := 0
	for id in _body_nodes:
		if hidden_bodies.has(id) or selected_bodies.has(id):
			continue
		if keys.has(body_similarity_key(id)):
			selected_bodies.append(id)
			added += 1
	if added > 0:
		selected_faces.clear()
		selected_edges.clear()
		_sync_primary_from_sets()
		_apply_selection_materials()
		_highlight_edge()
		selection_changed.emit(selected_body, selected_face)
	return added


# --- visibility (hide / isolate) ---

func set_body_hidden(id: String, hidden: bool) -> void:
	if id == "":
		return
	if hidden:
		hidden_bodies[id] = true
		_remove_body_from_selection(id)
	else:
		hidden_bodies.erase(id)
	_apply_selection_materials()


## Hide every body not in `ids`. Empty `ids` unhides all (same as unhide_all).
func isolate(ids: Array) -> void:
	if ids.is_empty():
		unhide_all()
		return
	for body_id in _body_nodes.keys():
		if ids.has(body_id):
			hidden_bodies.erase(body_id)
		else:
			hidden_bodies[body_id] = true
			_remove_body_from_selection(body_id)
	_apply_selection_materials()


func unhide_all() -> void:
	if hidden_bodies.is_empty():
		_apply_selection_materials()
		return
	hidden_bodies.clear()
	_apply_selection_materials()


func _remove_body_from_selection(body_id: String) -> void:
	selected_bodies.erase(body_id)
	var drop_faces: Array[String] = []
	for f in selected_faces:
		if _owner_body_of(f) == body_id:
			drop_faces.append(f)
	for f in drop_faces:
		selected_faces.erase(f)
	var drop_edges: Array[String] = []
	for e in selected_edges:
		if _owner_body_of(e) == body_id:
			drop_edges.append(e)
	for e in drop_edges:
		selected_edges.erase(e)
	_sync_primary_from_sets()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func select_entity(body_id: String, face_id: String) -> void:
	selected_body = body_id
	selected_face = face_id
	selected_edge = ""
	selected_bodies.assign([body_id] if body_id != "" and face_id == "" else [])
	selected_faces.assign([face_id] if face_id != "" else [])
	selected_edges.clear()
	if selected_instance != "":
		selected_instance = ""
		_apply_instance_highlight()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


## Select every face on a body (multi-face selection; body stays primary).
func select_all_faces(body_id: String) -> int:
	if body_id == "":
		return 0
	var faces: PackedStringArray = _face_ids.get(body_id, PackedStringArray())
	if faces.is_empty():
		faces = doc.get_face_ids(body_id)
	if faces.is_empty():
		return 0
	selected_body = body_id
	selected_face = faces[0]
	selected_edge = ""
	selected_bodies.clear()
	selected_faces.clear()
	selected_edges.clear()
	for f in faces:
		selected_faces.append(f)
	if selected_instance != "":
		selected_instance = ""
		_apply_instance_highlight()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)
	return selected_faces.size()


## Select every body in the document (whole-body multi-select).
func select_all_bodies() -> int:
	var bodies: PackedStringArray = doc.body_ids()
	selected_faces.clear()
	selected_edges.clear()
	selected_edge = ""
	selected_face = ""
	selected_bodies.clear()
	for b in bodies:
		if not hidden_bodies.has(b):
			selected_bodies.append(b)
	selected_body = selected_bodies[0] if not selected_bodies.is_empty() else ""
	if selected_instance != "":
		selected_instance = ""
		_apply_instance_highlight()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, "")
	return selected_bodies.size()


## Uniform scale for an import_step / import_stl body. Returns false on miss.
func set_import_scale(body_id: String, scale: float) -> bool:
	if not is_import_body(body_id) or scale <= 0.0:
		return false
	var info := feature_info(body_id)
	var params := feature_params(body_id)
	if info.is_empty() or params.is_empty():
		return false
	params["scale"] = scale
	var keep := body_id
	if not doc.graph_set_params(info["id"], JSON.stringify(params)):
		return false
	_after_mutation()
	select_entity(keep, "")
	return true


## Feature id for an import body, or "".
func import_feature_id(body_id: String) -> String:
	if not is_import_body(body_id):
		return ""
	return feature_of_body(body_id)


## Select a component instance (clears body/face/edge selection).
func select_instance(instance_id: String) -> void:
	select_entity("", "")
	selected_instance = instance_id
	_apply_instance_highlight()
	selection_changed.emit("", "")


func _apply_instance_highlight() -> void:
	for id in _instance_nodes:
		var node: MeshInstance3D = _instance_nodes[id]
		if node == null:
			continue
		if str(id) == selected_instance:
			node.material_override = _make_material(SELECTED_BODY_COLOR)
		else:
			node.material_override = _instance_materials.get(id)


## First component instance whose transformed mesh AABB the ray hits.
## Returns {} or {id, point, distance}. Instances have no kernel B-rep of
## their own, so this is a view-side AABB test (good enough for drag).
func pick_instance(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_t := INF
	var d := direction.normalized() if direction.length_squared() > 1e-12 else direction
	for id in _instance_nodes:
		var node: MeshInstance3D = _instance_nodes[id]
		if node == null or node.mesh == null or not node.visible:
			continue
		var inv := node.transform.affine_inverse()
		var t := _ray_aabb_t(inv * origin, (inv.basis * d).normalized(), node.mesh.get_aabb())
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {
				"id": str(id),
				"point": origin + d * t,
				"distance": t,
			}
	return best


## Slab-test ray/AABB intersection distance, or -1.0 on miss.
static func _ray_aabb_t(origin: Vector3, dir: Vector3, aabb: AABB) -> float:
	var t_min := 0.0
	var t_max := INF
	for axis in 3:
		var o := origin[axis]
		var d := dir[axis]
		var lo: float = aabb.position[axis]
		var hi: float = aabb.position[axis] + aabb.size[axis]
		if absf(d) < 1e-12:
			if o < lo or o > hi:
				return -1.0
			continue
		var t0 := (lo - o) / d
		var t1 := (hi - o) / d
		if t0 > t1:
			var tmp := t0
			t0 = t1
			t1 = tmp
		t_min = maxf(t_min, t0)
		t_max = minf(t_max, t1)
		if t_min > t_max:
			return -1.0
	return t_min


func clear_selection() -> void:
	_selection.clear_sets(selected_bodies, selected_faces, selected_edges)
	select_entity("", "")


## Pre-highlight under the pointer. Distinct from selection colors.
## Pass empty strings to clear. No-op when the hover target is unchanged.
func set_hover(body_id: String, face_id: String = "", edge_id: String = "") -> void:
	if body_id == hovered_body and face_id == hovered_face and edge_id == hovered_edge:
		return
	hovered_body = body_id
	hovered_face = face_id
	hovered_edge = edge_id
	_apply_selection_materials()
	_highlight_edge()


func clear_hover() -> void:
	set_hover("", "", "")


## Card markdown of the innermost selected entity ("" if nothing selected).
func selection_card() -> String:
	if selected_edge != "":
		var md := doc.card_markdown(selected_edge)
		if md != "":
			return md
		return "## Edge\n`%s`\nlength %.2f mm" % [selected_edge, doc.measure_edge_length(selected_edge)]
	if selected_face != "":
		return doc.card_markdown(selected_face)
	if selected_body != "":
		return doc.card_markdown(selected_body)
	return ""


## Outward normal (model space) of the selected face, from its tessellation.
func selected_face_normal() -> Vector3:
	return face_normal(selected_body, selected_face)


## Unit direction along an edge polyline (first→last). ZERO if missing/degenerate.
func edge_direction(body_id: String, edge_id: String) -> Vector3:
	if body_id == "" or edge_id == "":
		return Vector3.ZERO
	var lines: Dictionary = doc.get_edge_lines(body_id)
	if not lines.has(edge_id):
		return Vector3.ZERO
	var pts: PackedVector3Array = lines[edge_id]
	if pts.size() < 2:
		return Vector3.ZERO
	var d: Vector3 = pts[pts.size() - 1] - pts[0]
	if d.length_squared() < 1e-12:
		return Vector3.ZERO
	return d.normalized()


## Midpoint of an edge polyline, or ZERO if missing.
func edge_midpoint(body_id: String, edge_id: String) -> Vector3:
	if body_id == "" or edge_id == "":
		return Vector3.ZERO
	var lines: Dictionary = doc.get_edge_lines(body_id)
	if not lines.has(edge_id):
		return Vector3.ZERO
	var pts: PackedVector3Array = lines[edge_id]
	if pts.is_empty():
		return Vector3.ZERO
	return _polyline_midpoint(pts)


func body_center(body_id: String) -> Vector3:
	var node: MeshInstance3D = _body_nodes.get(body_id)
	if node == null:
		return Vector3.ZERO
	var aabb := node.get_aabb()
	return aabb.get_center()


# --- editing ---

func move_selected(delta: Vector3) -> bool:
	if selected_body == "":
		return false
	# Live BREP translate — never regenerate on move (regen would rebuild
	# primitives and undo booleans / pull / other committed shape edits).
	if not doc.translate_body(selected_body, delta):
		return false
	_nudge_related_placements(selected_body, delta)
	_after_mutation()
	return true


## Rotate the selected body about `axis_point` along `axis_dir` by `angle` (rad).
func rotate_selected(axis_point: Vector3, axis_dir: Vector3, angle: float) -> bool:
	if selected_body == "":
		return false
	if absf(angle) < 1e-12 or axis_dir.length_squared() < 1e-12:
		return true
	if not doc.rotate_body(selected_body, axis_point, axis_dir, angle):
		return false
	_transform_related_placements(selected_body, axis_point, Basis(axis_dir.normalized(), angle))
	_after_mutation()
	return true


## Feature ids whose placement should track a move/rotate of `body_id`: the body
## owner plus boolean tools (and their placements) that cut/fuse into it.
func _related_feature_ids(body_id: String) -> Array[String]:
	var out: Array[String] = []
	var fid := feature_of_body(body_id)
	if fid == "":
		return out
	out.append(fid)
	for f in doc.graph_features():
		var p = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(p) != TYPE_DICTIONARY:
			continue
		if str(f.get("type", "")) == "boolean" and str(p.get("target", "")) == fid:
			var tool_fid := str(p.get("tool", ""))
			if tool_fid != "" and not out.has(tool_fid):
				out.append(tool_fid)
		elif str(p.get("target", "")) == fid:
			# Hole / fillet / etc. store world positions that must track the body.
			var child := str(f.get("id", ""))
			if child != "" and not out.has(child):
				out.append(child)
	return out


func _nudge_related_placements(body_id: String, delta: Vector3) -> void:
	for fid in _related_feature_ids(body_id):
		_nudge_feature_placement(fid, delta)


func _transform_related_placements(body_id: String, axis_point: Vector3, R: Basis) -> void:
	for fid in _related_feature_ids(body_id):
		_transform_feature_placement(fid, axis_point, R)


func _feature_record(fid: String) -> Dictionary:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return f
	return {}


func _feature_params_by_id(fid: String) -> Dictionary:
	var f := _feature_record(fid)
	if f.is_empty():
		return {}
	var parsed = JSON.parse_string(str(f.get("params", "{}")))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _write_feature_params_quiet(fid: String, params: Dictionary) -> bool:
	return doc.graph_set_params_no_regen(fid, JSON.stringify(params))


func _nudge_feature_placement(fid: String, delta: Vector3) -> void:
	var params := _feature_params_by_id(fid)
	if params.is_empty():
		return
	if params.has("origin"):
		params["origin"] = _vec3_to_param(_param_vec3(params, "origin", Vector3.ZERO) + delta)
	if params.has("position"):
		params["position"] = _vec3_to_param(_param_vec3(params, "position", Vector3.ZERO) + delta)
	_write_feature_params_quiet(fid, params)


func _transform_feature_placement(fid: String, axis_point: Vector3, R: Basis) -> void:
	var rec := _feature_record(fid)
	var params := _feature_params_by_id(fid)
	if params.is_empty():
		return
	if params.has("origin"):
		var o := _param_vec3(params, "origin", Vector3.ZERO)
		params["origin"] = _vec3_to_param(axis_point + R * (o - axis_point))
	if params.has("position"):
		var p := _param_vec3(params, "position", Vector3.ZERO)
		params["position"] = _vec3_to_param(axis_point + R * (p - axis_point))
	# Primitives always keep an axis frame so later stretch/regen stay oriented.
	var is_prim := str(rec.get("type", "")) == "primitive"
	if is_prim or params.has("z_dir") or params.has("x_dir"):
		var z0 := _param_vec3(params, "z_dir", Vector3(0, 0, 1))
		var x0 := _param_vec3(params, "x_dir", Vector3(1, 0, 0))
		if z0.length_squared() < 1e-12:
			z0 = Vector3(0, 0, 1)
		if x0.length_squared() < 1e-12:
			x0 = Vector3(1, 0, 0)
		var new_z := (R * z0).normalized()
		var new_x := (R * x0).normalized()
		new_x = (new_x - new_z * new_x.dot(new_z)).normalized()
		if new_x.length_squared() < 1e-12:
			var hint := Vector3(1, 0, 0) if absf(new_z.dot(Vector3(1, 0, 0))) < 0.9 \
					else Vector3(0, 0, -1)
			new_x = (hint - new_z * hint.dot(new_z)).normalized()
		params["z_dir"] = _vec3_to_param(new_z)
		params["x_dir"] = _vec3_to_param(new_x)
	if params.has("direction"):
		params["direction"] = _vec3_to_param(
				(R * _param_vec3(params, "direction", Vector3(0, 0, 1))).normalized())
	_write_feature_params_quiet(fid, params)


func push_pull_selected(distance: float) -> bool:
	if selected_face == "":
		return false
	var face := selected_face
	var body := selected_body
	var fid := feature_of_body(body)
	var ok: bool
	if fid != "":
		ok = doc.graph_add_push_pull(fid, face, distance) != ""
	else:
		ok = doc.push_pull(face, distance)
	if ok and is_primitive_body(body) and fid == "":
		# Bake pull into cylinder/cone params without rebuilding (keeps length).
		# Graph push-pull already records the edit on the timeline.
		var info := feature_info(body)
		var params := feature_params(body)
		if not info.is_empty() and not params.is_empty():
			_sync_cyl_cone_params_from_body(body, params)
			_write_feature_params_quiet(info["id"], params)
	_after_mutation()
	if ok:
		# Face ids are reassigned after a shape change (naming v0); keep the
		# body selected so the user can continue working.
		select_entity(body, "")
	return ok


## Delete every selected body. Timeline-owned bodies remove their feature
## (fails if later features depend on it); free bodies delete directly.
func delete_selected() -> bool:
	var ids: Array[String] = []
	for b in selected_bodies:
		if b != "" and not ids.has(b):
			ids.append(b)
	if selected_body != "" and not ids.has(selected_body):
		ids.append(selected_body)
	if ids.is_empty():
		return false
	var any := _delete_body_ids(ids)
	clear_selection()
	_after_mutation()
	return any


func _delete_body_ids(ids: Array[String]) -> bool:
	var any := false
	for body_id in ids:
		var fid := feature_of_body(body_id)
		var ok: bool
		if fid != "":
			ok = doc.graph_remove(fid)
		else:
			ok = doc.delete_body(body_id)
		if ok:
			any = true
			hidden_bodies.erase(body_id)
	return any


## True when Paste / Paste Special have something to place.
func has_clipboard() -> bool:
	_prune_clipboard()
	return not _clipboard_bodies.is_empty()


func _prune_clipboard() -> void:
	var live := {}
	for id in doc.body_ids():
		live[id] = true
	var keep: Array[String] = []
	for id in _clipboard_bodies:
		if live.has(id):
			keep.append(id)
	_clipboard_bodies = keep
	if _clipboard_bodies.is_empty():
		_clipboard_cut = false


## Drop hidden cut orphans when starting a fresh copy/cut.
func _discard_cut_orphans() -> void:
	if not _clipboard_cut:
		return
	var orphans: Array[String] = []
	for id in _clipboard_bodies:
		if hidden_bodies.has(id):
			orphans.append(id)
	if not orphans.is_empty():
		_delete_body_ids(orphans)
		_after_mutation()
	_clipboard_bodies.clear()
	_clipboard_cut = false
	_clipboard_paste_count = 0


## Remember currently selected bodies for paste. Returns how many were copied.
func copy_selection() -> int:
	_discard_cut_orphans()
	var ids: Array[String] = []
	for b in selected_bodies:
		ids.append(b)
	if ids.is_empty() and selected_body != "":
		ids.append(selected_body)
	_clipboard_bodies.clear()
	_clipboard_paste_count = 0
	_clipboard_cut = false
	var live := {}
	for id in doc.body_ids():
		live[id] = true
	for id in ids:
		if live.has(id) and not _clipboard_bodies.has(id):
			_clipboard_bodies.append(id)
	return _clipboard_bodies.size()


## Cut = copy + remove. Materializes independent clones (hidden) so Paste works
## after the originals are gone. Returns how many landed on the clipboard.
func cut_selection() -> int:
	var n := copy_selection()
	if n == 0:
		return 0
	var sources: Array[String] = _clipboard_bodies.duplicate()
	var clones: Array[String] = []
	for id in sources:
		var bb0: Dictionary = doc.measure_bbox(id)
		if bb0.is_empty():
			continue
		# Pattern once, then snap the clone back onto the source pose.
		var made: PackedStringArray = doc.linear_pattern(id, Vector3(1, 0, 0), 1.0, 2)
		if made.is_empty():
			continue
		var c: String = made[0]
		var bb1: Dictionary = doc.measure_bbox(c)
		if not bb1.is_empty():
			doc.translate_body(c, bb0["min"] - bb1["min"])
		var src_name := doc.body_name(id)
		if src_name != "":
			doc.rename_body(c, src_name)
		clones.append(c)
	if clones.is_empty():
		_clipboard_bodies.clear()
		return 0
	_delete_body_ids(sources)
	for c in clones:
		set_body_hidden(c, true)
	_clipboard_bodies = clones
	_clipboard_cut = true
	_clipboard_paste_count = 0
	clear_selection()
	_after_mutation()
	return clones.size()


## Default Paste step: 20% of combined AABB on the ground plane (XY).
func clipboard_paste_step() -> Vector3:
	_prune_clipboard()
	if _clipboard_bodies.is_empty():
		return Vector3(10, 10, 0)
	var mn := Vector3(1e12, 1e12, 1e12)
	var mx := Vector3(-1e12, -1e12, -1e12)
	var any := false
	for id in _clipboard_bodies:
		var bb: Dictionary = doc.measure_bbox(id)
		if bb.is_empty():
			continue
		any = true
		mn = mn.min(bb["min"])
		mx = mx.max(bb["max"])
	if not any:
		return Vector3(10, 10, 0)
	var size: Vector3 = mx - mn
	var step := Vector3(size.x * 0.2, size.y * 0.2, 0.0)
	if step.length_squared() < 1e-8:
		step = Vector3(1.0, 1.0, 0.0)
	return step


## Paste clipboard bodies. When `offset` is omitted (NaN sentinel), uses the
## stepped 20% ground-plane delta. Cut bodies are revealed on first paste.
## Returns the new (or revealed) body ids; selection is set to them.
func paste_clipboard(offset := Vector3(NAN, NAN, NAN)) -> Array[String]:
	_prune_clipboard()
	if _clipboard_bodies.is_empty():
		return []

	var use_custom := not is_nan(offset.x)
	var step := offset if use_custom else clipboard_paste_step()
	if not use_custom:
		_clipboard_paste_count += 1
		step = step * float(_clipboard_paste_count)
	elif _clipboard_cut:
		# First paste after cut with an explicit offset — still a "first" paste.
		pass
	else:
		_clipboard_paste_count += 1

	if _clipboard_cut:
		var revealed: Array[String] = []
		for id in _clipboard_bodies:
			set_body_hidden(id, false)
			if step.length_squared() > 1e-12:
				doc.translate_body(id, step)
			revealed.append(id)
		_clipboard_cut = false
		_clipboard_paste_count = 1 if use_custom else _clipboard_paste_count
		selected_body = revealed[revealed.size() - 1]
		selected_face = ""
		selected_edge = ""
		selected_bodies.assign(revealed)
		selected_faces.clear()
		selected_edges.clear()
		if selected_instance != "":
			selected_instance = ""
			_apply_instance_highlight()
		_after_mutation()
		selection_changed.emit(selected_body, selected_face)
		return revealed

	var sources: Array[String] = _clipboard_bodies.duplicate()
	var spacing := step.length()
	if spacing < 1e-8:
		# In-place paste: still need distinct bodies — nudge then snap via pattern+translate.
		spacing = 1.0
		step = Vector3(1, 0, 0)
	var direction := step / spacing

	var created: Array[String] = []
	for id in sources:
		var made: PackedStringArray = doc.linear_pattern(id, direction, spacing, 2)
		if made.size() > 0:
			var c: String = made[0]
			# When custom offset was not a pure step from pattern origin, snap.
			if use_custom:
				var bb0: Dictionary = doc.measure_bbox(id)
				var bb1: Dictionary = doc.measure_bbox(c)
				if not bb0.is_empty() and not bb1.is_empty():
					doc.translate_body(c, (bb0["min"] + offset) - bb1["min"])
			created.append(c)
	if created.is_empty():
		return []
	selected_body = created[created.size() - 1]
	selected_face = ""
	selected_edge = ""
	selected_bodies.assign(created)
	selected_faces.clear()
	selected_edges.clear()
	if selected_instance != "":
		selected_instance = ""
		_apply_instance_highlight()
	_after_mutation()
	selection_changed.emit(selected_body, selected_face)
	return created


func set_selection_alias(text: String) -> void:
	var target := selected_face if selected_face != "" else selected_body
	if target != "":
		doc.set_card_alias(target, text)


func set_selection_notes(text: String) -> void:
	var target := selected_face if selected_face != "" else selected_body
	if target != "":
		doc.set_card_notes(target, text)


func undo() -> bool:
	var ok := doc.undo()
	clear_selection()
	_after_mutation()
	return ok


func redo() -> bool:
	var ok := doc.redo()
	clear_selection()
	_after_mutation()
	return ok


func save(path: String) -> bool:
	return doc.save(path)


func load_from(path: String) -> bool:
	var ok := doc.load(path)
	clear_selection()
	hidden_bodies.clear()
	_clipboard_bodies.clear()
	_clipboard_paste_count = 0
	_clipboard_cut = false
	_after_mutation()
	return ok


func new_document() -> void:
	doc = SxDocument.new()
	clear_selection()
	hidden_bodies.clear()
	_clipboard_bodies.clear()
	_clipboard_paste_count = 0
	_clipboard_cut = false
	_after_mutation()


# --- rendering ---

func refresh() -> void:
	var live := {}
	for body_id in doc.body_ids():
		live[body_id] = true
		_rebuild_body(body_id)
	for body_id in _body_nodes.keys().duplicate():
		if not live.has(body_id):
			_body_nodes[body_id].queue_free()
			_body_nodes.erase(body_id)
			_face_ids.erase(body_id)
			_body_materials.erase(body_id)
			hidden_bodies.erase(body_id)
	_refresh_datums()
	_refresh_instances()
	refresh_sketch_pads(_editing_sketch_fid)
	refresh_path_overlay()
	# refresh() rebuilds meshes; surface overrides must be reapplied or bodies
	# keep Godot's default matte white (films call refresh without _after_mutation).
	_apply_selection_materials()
	_highlight_edge()


## Rebuild yellow sketch pads. Pass editing_fid to hide that pad while editing.
func refresh_sketch_pads(editing_fid: String = "") -> void:
	_editing_sketch_fid = editing_fid
	if sketch_pads != null and sketch_pads.has_method("refresh"):
		sketch_pads.call("refresh", doc, editing_fid)


func refresh_path_overlay() -> void:
	if path_overlay != null and path_overlay.has_method("refresh"):
		path_overlay.call("refresh", doc)


## Face normal from tessellation (model space), or ZERO if unknown.
func face_normal(body_id: String, face_id: String) -> Vector3:
	if body_id == "" or face_id == "":
		return Vector3.ZERO
	var node: MeshInstance3D = _body_nodes.get(body_id)
	var faces: PackedStringArray = _face_ids.get(body_id, PackedStringArray())
	var idx := faces.find(face_id)
	if node == null or idx < 0 or node.mesh == null:
		return Vector3.ZERO
	if idx >= node.mesh.get_surface_count():
		return Vector3.ZERO
	var arrays: Array = node.mesh.surface_get_arrays(idx)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0] if normals.size() > 0 else Vector3.ZERO


func body_node(body_id: String) -> MeshInstance3D:
	return _body_nodes.get(body_id)


func datum_node(datum_id: String) -> Node3D:
	return _datum_nodes.get(datum_id)


func instance_node(instance_id: String) -> MeshInstance3D:
	return _instance_nodes.get(instance_id)


func _refresh_datums() -> void:
	var live := {}
	for d in doc.datum_list():
		var id: String = d["id"]
		live[id] = true
		_rebuild_datum(d)
	for id in _datum_nodes.keys().duplicate():
		if not live.has(id):
			_datum_nodes[id].queue_free()
			_datum_nodes.erase(id)


func _rebuild_datum(d: Dictionary) -> void:
	var id: String = d["id"]
	var kind: String = d["kind"]
	var node: Node3D = _datum_nodes.get(id)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Datum_" + id.left(8)
		add_child(node)
		_datum_nodes[id] = node
	var mi := node as MeshInstance3D
	match kind:
		"plane":
			mi.mesh = _make_datum_plane_mesh(d)
			mi.material_override = _datum_plane_material
			mi.transform = Transform3D.IDENTITY
		"axis":
			mi.mesh = _make_datum_axis_mesh(d)
			mi.material_override = _datum_axis_material
			mi.transform = Transform3D.IDENTITY
		"point":
			var sphere := SphereMesh.new()
			sphere.radius = DATUM_POINT_RADIUS
			sphere.height = DATUM_POINT_RADIUS * 2.0
			sphere.radial_segments = 12
			sphere.rings = 6
			mi.mesh = sphere
			mi.material_override = _datum_point_material
			var pos: Vector3 = d["position"]
			mi.transform = Transform3D(Basis.IDENTITY, pos)
		_:
			mi.mesh = null


func _make_datum_plane_mesh(d: Dictionary) -> ArrayMesh:
	var origin: Vector3 = d["origin"]
	var normal: Vector3 = d["normal"]
	var x_dir: Vector3 = d["x_dir"]
	var y_dir := normal.cross(x_dir).normalized()
	if y_dir.length_squared() < 1e-12:
		y_dir = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		y_dir = normal.cross(y_dir).normalized()
	x_dir = y_dir.cross(normal).normalized()
	var hx := x_dir * DATUM_PLANE_HALF
	var hy := y_dir * DATUM_PLANE_HALF
	var c0 := origin - hx - hy
	var c1 := origin + hx - hy
	var c2 := origin + hx + hy
	var c3 := origin - hx + hy
	var verts := PackedVector3Array([c0, c1, c2, c0, c2, c3])
	var norms := PackedVector3Array()
	for _i in range(6):
		norms.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_datum_axis_mesh(d: Dictionary) -> ImmediateMesh:
	var point: Vector3 = d["point"]
	var direction: Vector3 = d["direction"].normalized()
	var a := point - direction * DATUM_AXIS_HALF_LEN
	var b := point + direction * DATUM_AXIS_HALF_LEN
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	return im


# Instances reuse the source body's ArrayMesh with a node-local transform.
# Display modes / section shader are skipped in v1 (except WIREFRAME mesh hide).
func _refresh_instances() -> void:
	var live := {}
	for inst in doc.instance_list():
		var id: String = inst["id"]
		live[id] = true
		_rebuild_instance(inst)
	for id in _instance_nodes.keys().duplicate():
		if not live.has(id):
			_instance_nodes[id].queue_free()
			_instance_nodes.erase(id)
			_instance_materials.erase(id)
			if selected_instance == str(id):
				selected_instance = ""


func _rebuild_instance(inst: Dictionary) -> void:
	var id: String = inst["id"]
	var source: String = inst["source_body"]
	var node: MeshInstance3D = _instance_nodes.get(id)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Instance_" + id.left(8)
		add_child(node)
		_instance_nodes[id] = node
	# Prefer sharing the already-tessellated body mesh; fall back to get_mesh.
	var src_node: MeshInstance3D = _body_nodes.get(source)
	if src_node != null and src_node.mesh != null:
		node.mesh = src_node.mesh
	else:
		node.mesh = doc.get_mesh(source)
	var translation: Vector3 = inst["translation"]
	var axis: Vector3 = inst["rotation_axis"]
	var angle_deg: float = inst["rotation_angle_deg"]
	var basis := Basis.IDENTITY
	if axis.length_squared() > 1e-12 and absf(angle_deg) > 1e-9:
		basis = Basis(axis.normalized(), deg_to_rad(angle_deg))
	node.transform = Transform3D(basis, translation)
	var tint: Color = doc.get_body_color(source).lightened(0.28)
	_instance_materials[id] = _make_material(tint)
	node.material_override = _make_material(SELECTED_BODY_COLOR) \
			if id == selected_instance else _instance_materials[id]
	# WIREFRAME: hide solid mesh (no instance edge overlay in v1).
	node.visible = display_mode != DisplayMode.WIREFRAME


func _after_mutation() -> void:
	refresh()
	_apply_selection_materials()
	_highlight_edge()
	document_changed.emit()


func _rebuild_body(body_id: String) -> void:
	var node: MeshInstance3D = _body_nodes.get(body_id)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Body_" + body_id.left(8)
		add_child(node)
		_body_nodes[body_id] = node
		var edges := MeshInstance3D.new()
		edges.name = "Edges"
		node.add_child(edges)
	node.transform = Transform3D.IDENTITY
	node.mesh = doc.get_mesh(body_id)
	_face_ids[body_id] = doc.get_face_ids(body_id)
	_body_materials[body_id] = _make_material(doc.get_body_color(body_id))
	_rebuild_edges(node.get_node("Edges") as MeshInstance3D, body_id)
	var shown := not hidden_bodies.has(body_id)
	node.visible = shown
	var edges_child: MeshInstance3D = node.get_node_or_null("Edges") as MeshInstance3D
	if edges_child != null:
		edges_child.visible = shown and display_mode != DisplayMode.SHADED


func _rebuild_edges(edge_node: MeshInstance3D, body_id: String) -> void:
	var lines: Dictionary = doc.get_edge_lines(body_id)
	var im := ImmediateMesh.new()
	var have_any := false
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.size() < 2:
			continue
		if not have_any:
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			have_any = true
		for i in range(pts.size() - 1):
			im.surface_add_vertex(pts[i])
			im.surface_add_vertex(pts[i + 1])
	if have_any:
		im.surface_end()
	edge_node.mesh = im
	edge_node.material_override = _edge_material


func _highlight_edge() -> void:
	# Selected edges win; otherwise show the hovered edge.
	var targets: Array[String] = selected_edges.duplicate()
	if targets.is_empty() and selected_edge != "":
		targets.append(selected_edge)
	var use_hover := targets.is_empty() and hovered_edge != ""
	if use_hover:
		targets.append(hovered_edge)
	if targets.is_empty():
		_edge_highlight.mesh = null
		return
	var im := ImmediateMesh.new()
	var have_any := false
	for body_id in _body_nodes:
		var lines: Dictionary = doc.get_edge_lines(body_id)
		for edge_id in targets:
			if not lines.has(edge_id):
				continue
			var pts: PackedVector3Array = lines[edge_id]
			if pts.size() < 2:
				continue
			if not have_any:
				im.surface_begin(Mesh.PRIMITIVE_LINES)
				have_any = true
			for i in range(pts.size() - 1):
				im.surface_add_vertex(pts[i])
				im.surface_add_vertex(pts[i + 1])
	if have_any:
		im.surface_end()
		_edge_highlight.mesh = im
		_edge_highlight.material_override = _hover_edge_material if use_hover \
				else _selected_edge_overlay
	else:
		_edge_highlight.mesh = null


func _apply_selection_materials() -> void:
	for body_id in _body_nodes:
		var node: MeshInstance3D = _body_nodes[body_id]
		var faces: PackedStringArray = _face_ids.get(body_id, PackedStringArray())
		var body_selected: bool = body_id == selected_body or selected_bodies.has(body_id)
		var whole_body_selected: bool = selected_bodies.has(body_id) \
			or (body_id == selected_body and selected_face == "" and selected_edge == "")
		var base: ShaderMaterial = _body_materials.get(body_id, _base_material)
		var body_shown := not hidden_bodies.has(body_id)
		node.visible = body_shown
		var edges: MeshInstance3D = node.get_node_or_null("Edges") as MeshInstance3D
		if edges != null:
			edges.visible = body_shown and display_mode != DisplayMode.SHADED
			if display_mode == DisplayMode.WIREFRAME and body_selected:
				edges.material_override = _selected_edge_material
			else:
				edges.material_override = _edge_material
		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var face_here := faces[i] if i < faces.size() else ""
			var face_selected: bool = face_here != "" \
				and (face_here == selected_face or selected_faces.has(face_here))
			var face_hovered: bool = face_here != "" and face_here == hovered_face \
				and not face_selected
			var body_hovered: bool = body_id == hovered_body and hovered_face == "" \
				and hovered_edge == "" and not whole_body_selected and not face_selected
			var mat: Material
			if display_mode == DisplayMode.WIREFRAME:
				if section_enabled:
					mat = _make_section_material(Color(0, 0, 0, 0))
				else:
					mat = _wireframe_hidden_material
			elif face_selected:
				if section_enabled:
					mat = _make_section_material(
						SELECTED_FACE_COLOR, SELECTED_FACE_COLOR, 0.35
					)
				else:
					mat = _selected_face_material
			elif face_here != "" and face_here == mate_anchor_face:
				mat = _mate_anchor_material
			elif whole_body_selected:
				if section_enabled:
					mat = _make_section_material(SELECTED_BODY_COLOR)
				else:
					mat = _selected_body_material
			elif face_hovered:
				if section_enabled:
					mat = _make_section_material(HOVER_FACE_COLOR)
				else:
					mat = _hover_face_material
			elif body_hovered:
				if section_enabled:
					mat = _make_section_material(HOVER_BODY_COLOR)
				else:
					mat = _hover_body_material
			else:
				if section_enabled:
					var c: Color = base.get_shader_parameter("albedo_color")
					mat = _make_section_material(c)
				else:
					mat = base
			node.set_surface_override_material(i, mat)
	# Instances: v1 skips section/display shading; only honor WIREFRAME hide.
	for iid in _instance_nodes:
		var inode: MeshInstance3D = _instance_nodes[iid]
		inode.visible = display_mode != DisplayMode.WIREFRAME
		if _instance_materials.has(iid):
			inode.material_override = _instance_materials[iid]
	_rebuild_selection_corners()


## Draw an AABB frame + corner brackets around the current selection.
func _rebuild_selection_corners() -> void:
	if _selection_corners == null:
		return
	var ids: Array[String] = []
	for b in selected_bodies:
		ids.append(b)
	if ids.is_empty() and selected_body != "":
		ids.append(selected_body)
	if ids.is_empty():
		_selection_corners.mesh = null
		return
	var mn := Vector3(1e12, 1e12, 1e12)
	var mx := Vector3(-1e12, -1e12, -1e12)
	var any := false
	for id in ids:
		var bb: Dictionary = doc.measure_bbox(id)
		if bb.is_empty():
			continue
		any = true
		mn = mn.min(bb["min"])
		mx = mx.max(bb["max"])
	if not any:
		_selection_corners.mesh = null
		return
	# Slight pad so brackets sit outside the solid.
	var pad := (mx - mn).length() * 0.02 + 0.5
	mn -= Vector3(pad, pad, pad)
	mx += Vector3(pad, pad, pad)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
		Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
		Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
	]
	# Full wire AABB
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	for e in edges:
		im.surface_add_vertex(corners[e[0]])
		im.surface_add_vertex(corners[e[1]])
	# Corner brackets: short ticks along each axis from every corner.
	var tick := (mx - mn) * 0.12
	tick = Vector3(maxf(tick.x, 2.0), maxf(tick.y, 2.0), maxf(tick.z, 2.0))
	for c in corners:
		var sx := 1.0 if c.x > (mn.x + mx.x) * 0.5 else -1.0
		var sy := 1.0 if c.y > (mn.y + mx.y) * 0.5 else -1.0
		var sz := 1.0 if c.z > (mn.z + mx.z) * 0.5 else -1.0
		im.surface_add_vertex(c)
		im.surface_add_vertex(c + Vector3(-sx * tick.x, 0, 0))
		im.surface_add_vertex(c)
		im.surface_add_vertex(c + Vector3(0, -sy * tick.y, 0))
		im.surface_add_vertex(c)
		im.surface_add_vertex(c + Vector3(0, 0, -sz * tick.z))
	im.surface_end()
	_selection_corners.mesh = im
