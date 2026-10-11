class_name PlaneBasis
extends RefCounted
## Face-sketch frame: origin, x, y, normal.
## Built once from the face normal; SketchMode does not recompute the axes.

var origin: Vector3
var x: Vector3
var y: Vector3
var normal: Vector3

## |n × Z|² below this is the old near-horizontal cutoff (a top face a few
## degrees off ±Z must keep the world-XY axes).
const _Z_PARALLEL_SQ := 0.04


static func for_face(normal: Vector3, origin: Vector3) -> PlaneBasis:
	var basis := PlaneBasis.new()
	var n := normal.normalized()
	basis.origin = origin
	basis.normal = n
	var z := Vector3(0, 0, 1)
	if n.cross(z).length_squared() < _Z_PARALLEL_SQ:
		# Today's top/bottom basis: world +X, then n × x.
		var hx := Vector3.RIGHT
		basis.x = (hx - n * hx.dot(n)).normalized()
		basis.y = n.cross(basis.x).normalized()
	else:
		# Screen up is world up. x = y × n so x × y = n.
		basis.y = (z - n * z.dot(n)).normalized()
		basis.x = basis.y.cross(n).normalized()
	return basis
