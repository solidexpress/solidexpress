class_name TriBallGizmo
extends Node3D
## One viewport tool: rotate-copy about a primary handle (IronCAD TriBall feel).
## Math lives here — viewport_interaction only forwards drag events.

signal copy_committed(count: int, angle_rad: float)
signal status(text: String)

var view: DocumentView
var origin := Vector3.ZERO
var axis := Vector3.UP
var active := false
var _dragging := false
var _start_angle := 0.0
var _angle := 0.0
var _copies := 6
var _mesh: ImmediateMesh
var _inst: MeshInstance3D


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_inst = MeshInstance3D.new()
	_inst.mesh = _mesh
	_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inst)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.95)
	mat.no_depth_test = true
	_inst.material_override = mat
	visible = false


func begin(at: Vector3, around: Vector3, copies: int = 6) -> void:
	origin = at
	axis = around.normalized() if around.length() > 1e-6 else Vector3.UP
	_copies = maxi(2, copies)
	_angle = 0.0
	active = true
	visible = true
	_rebuild()
	status.emit("TriBall — drag the ring to rotate-copy")


func cancel() -> void:
	active = false
	_dragging = false
	visible = false
	_mesh.clear_surfaces()


func begin_drag(hit: Vector3) -> void:
	if not active:
		return
	_dragging = true
	_start_angle = _angle_of(hit)


func update_drag(hit: Vector3) -> void:
	if not _dragging:
		return
	_angle = _wrap(_angle_of(hit) - _start_angle)
	_rebuild()


func end_drag() -> int:
	if not _dragging:
		return 0
	_dragging = false
	var n := _copies
	copy_committed.emit(n, _angle)
	status.emit("TriBall — %d copies about the ring" % n)
	return n


func current_angle() -> float:
	return _angle


func _angle_of(hit: Vector3) -> float:
	var v := hit - origin
	var radial := v - axis * v.dot(axis)
	if radial.length() < 1e-6:
		return 0.0
	var ref := axis.cross(Vector3.RIGHT)
	if ref.length() < 1e-6:
		ref = axis.cross(Vector3.FORWARD)
	ref = ref.normalized()
	var bit := axis.cross(ref).normalized()
	return atan2(radial.normalized().dot(bit), radial.normalized().dot(ref))


func _wrap(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if not active:
		return
	var r := 12.0
	var segs := 48
	var ref := axis.cross(Vector3.RIGHT)
	if ref.length() < 1e-6:
		ref = axis.cross(Vector3.FORWARD)
	ref = ref.normalized()
	var bit := axis.cross(ref).normalized()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in segs:
		var t0 := TAU * float(i) / float(segs)
		var t1 := TAU * float(i + 1) / float(segs)
		_mesh.surface_add_vertex(origin + (ref * cos(t0) + bit * sin(t0)) * r)
		_mesh.surface_add_vertex(origin + (ref * cos(t1) + bit * sin(t1)) * r)
	_mesh.surface_add_vertex(origin)
	_mesh.surface_add_vertex(origin + axis * r)
	var handle := origin + (ref * cos(_angle) + bit * sin(_angle)) * r
	_mesh.surface_add_vertex(origin)
	_mesh.surface_add_vertex(handle)
	_mesh.surface_end()
