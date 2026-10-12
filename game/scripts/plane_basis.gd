class_name PlaneBasis
extends RefCounted
## One sketch frame: world = frame * Vector3(u, v, 0).
## Callers read origin, x, y, and normal; they do not rebuild the axes.

var frame := Transform3D.IDENTITY

var origin: Vector3:
	get:
		return frame.origin

var x: Vector3:
	get:
		return frame.basis.x

var y: Vector3:
	get:
		return frame.basis.y

## Third column is x × y, including when that opposes a face normal passed in.
var normal: Vector3:
	get:
		return frame.basis.z

## |n × Z|² below this is the old near-horizontal cutoff (a top face a few
## degrees off ±Z must keep the world-XY axes).
const _Z_PARALLEL_SQ := 0.04


static func for_face(normal: Vector3, origin: Vector3) -> PlaneBasis:
	var n := normal.normalized()
	var axis_x: Vector3
	var axis_y: Vector3
	var z := Vector3(0, 0, 1)
	if n.cross(z).length_squared() < _Z_PARALLEL_SQ:
		# Today's top/bottom basis: world +X, then n × x.
		var hx := Vector3.RIGHT
		axis_x = (hx - n * hx.dot(n)).normalized()
		axis_y = n.cross(axis_x).normalized()
	else:
		# Screen up is world up. x = y × n so x × y = n.
		axis_y = (z - n * z.dot(n)).normalized()
		axis_x = axis_y.cross(n).normalized()
	return from_axes(origin, axis_x, axis_y)


static func from_axes(origin: Vector3, x: Vector3, y: Vector3) -> PlaneBasis:
	var basis := PlaneBasis.new()
	var n := x.cross(y)
	if n.length_squared() > 0.0:
		n = n.normalized()
	basis.frame = Transform3D(Basis(x, y, n), origin)
	return basis


func to_world(uv: Vector2) -> Vector3:
	return frame * Vector3(uv.x, uv.y, 0.0)


func to_uv(world: Vector3) -> Vector2:
	var local := frame.affine_inverse() * world
	return Vector2(local.x, local.y)
