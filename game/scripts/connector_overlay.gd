class_name ConnectorOverlay
extends Node3D
## Hover glyphs for implicit mate connectors (Onshape-style). Not a dock.

var view: DocumentView
var _mesh: ImmediateMesh
var _inst: MeshInstance3D
var _hover_face := ""
var _hover_instance := ""


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_inst = MeshInstance3D.new()
	_inst.mesh = _mesh
	_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inst)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.75, 1.0, 0.9)
	mat.no_depth_test = true
	_inst.material_override = mat


func set_hover(instance_id: String, face_id: String) -> void:
	_hover_instance = instance_id
	_hover_face = face_id
	_rebuild()


func clear_hover() -> void:
	_hover_face = ""
	_hover_instance = ""
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if view == null or view.doc == null or _hover_face == "":
		return
	var c: Dictionary = view.doc.implicit_connector(_hover_instance, _hover_face)
	if c.is_empty():
		return
	var o: Vector3 = c.get("origin", Vector3.ZERO)
	var z: Vector3 = c.get("z_dir", Vector3.UP)
	var x: Vector3 = c.get("x_dir", Vector3.RIGHT)
	if z.length() < 1e-6:
		return
	z = z.normalized()
	x = x.normalized()
	var y := z.cross(x).normalized()
	var s := 4.0
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_axis(o, o + z * s)
	_add_axis(o, o + x * s * 0.6)
	_add_axis(o, o + y * s * 0.6)
	_mesh.surface_end()


func _add_axis(a: Vector3, b: Vector3) -> void:
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(b)


## True while a connector glyph is drawn (hover is showing a real frame).
func showing() -> bool:
	return _mesh != null and _mesh.get_surface_count() > 0


func hovered_face() -> String:
	return _hover_face
