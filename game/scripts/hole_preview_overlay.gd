class_name HolePreviewOverlay
extends Node3D
## Viewport rings for Hole Wizard / Place hole pending points.
## Mounted under ModelSpace by ViewportInteraction.

var _rings: Array[MeshInstance3D] = []
var _radius_mm := 3.0


func clear() -> void:
	for r in _rings:
		if is_instance_valid(r):
			r.queue_free()
	_rings.clear()


func set_radius(mm: float) -> void:
	_radius_mm = maxf(0.5, mm)


func set_points(points: PackedVector3Array) -> void:
	clear()
	for p in points:
		_rings.append(_make_ring(p))


func add_point(p: Vector3) -> void:
	_rings.append(_make_ring(p))


func _make_ring(center: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := 24
	for i in range(n + 1):
		var a := TAU * float(i) / float(n)
		im.surface_add_vertex(center + Vector3(cos(a) * _radius_mm, sin(a) * _radius_mm, 0.05))
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.85, 1.0)
	mi.material_override = mat
	add_child(mi)
	return mi
