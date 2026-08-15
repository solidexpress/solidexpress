class_name PrintBedGhost
extends Node3D
## Semi-transparent printer bed outline on the ground plane (model XY).
## Default size 220×220 mm; call set_bed_size to change.
#
var bed_x_mm: float = 220.0
var bed_y_mm: float = 220.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
#
func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "BedGhostMesh"
	add_child(_mesh)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.25, 0.7, 1.0, 0.12)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _mat
	_rebuild()
	visible = false
	# Model XY is the ground plane (Z-up kernel mapped to Y-up world by ModelSpace).
	transform = Transform3D.IDENTITY
#
func set_bed_size(x_mm: float, y_mm: float) -> void:
	bed_x_mm = maxf(1.0, x_mm)
	bed_y_mm = maxf(1.0, y_mm)
	_rebuild()
#
func _rebuild() -> void:
	var hx := bed_x_mm * 0.5
	var hy := bed_y_mm * 0.5
	var c0 := Vector3(-hx, 0, -hy)
	var c1 := Vector3(hx, 0, -hy)
	var c2 := Vector3(hx, 0, hy)
	var c3 := Vector3(-hx, 0, hy)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Outer rectangle
	im.surface_add_vertex(c0); im.surface_add_vertex(c1)
	im.surface_add_vertex(c1); im.surface_add_vertex(c2)
	im.surface_add_vertex(c2); im.surface_add_vertex(c3)
	im.surface_add_vertex(c3); im.surface_add_vertex(c0)
	# Center cross
	im.surface_add_vertex(Vector3(0, 0, -hy)); im.surface_add_vertex(Vector3(0, 0, hy))
	im.surface_add_vertex(Vector3(-hx, 0, 0)); im.surface_add_vertex(Vector3(hx, 0, 0))
	im.surface_end()
	_mesh.mesh = im
