class_name SectionCap
extends Node2D
## Screen-space fill of the section cut. The body shader only discards the
## near half; a 1 mm shell has no face on the plane, so the wall sample
## would miss. These triangles are the solid ∩ plane, drawn in
## SectionPlane.CAP_COLOUR (canvas, so the tonemapper does not recolor them).


## A 1 mm wall is about two pixels at the walk's zoom. Pad so the pixel
## that contains the sample (not only the exact projected point) is filled.
const PAD_PX := 3.0

var view: DocumentView

var _key := ""
## Model-space triangles. Projected at draw time so an orbit stays aligned.
var _model: Array[PackedVector3Array] = []


func _ready() -> void:
	# Overlay only. Clicks pass through to the viewport.
	pass


func _process(_dt: float) -> void:
	if view == null or not view.section_enabled or view.doc == null:
		if not _model.is_empty() or visible:
			_model.clear()
			_key = ""
			visible = false
			queue_redraw()
		return
	visible = true
	var key := "%s|%s|%s" % [view.doc.revision(), view.section_point(), view.section_normal()]
	if key != _key:
		_key = key
		_rebuild()
	queue_redraw()


func _rebuild() -> void:
	_model.clear()
	if not view.doc.has_method("section_cap_mesh"):
		return
	var point := view.section_point()
	var normal := view.section_normal()
	for body_id in view.doc.body_ids():
		var mesh: ArrayMesh = view.doc.section_cap_mesh(str(body_id), point, normal)
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				continue
			var t := 0
			while t + 2 < idx.size():
				var tri := PackedVector3Array()
				tri.append(verts[idx[t]])
				tri.append(verts[idx[t + 1]])
				tri.append(verts[idx[t + 2]])
				_model.append(tri)
				t += 3


func _draw() -> void:
	var colour := SectionPlane.CAP_COLOUR
	for tri in _model:
		if tri.size() < 3:
			continue
		var poly := _project_triangle(tri[0], tri[1], tri[2])
		if poly.size() < 3:
			continue
		draw_colored_polygon(_expand(poly[0], poly[1], poly[2], PAD_PX), colour)


func _project_triangle(a: Vector3, b: Vector3, c: Vector3) -> PackedVector2Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or view == null:
		return PackedVector2Array()
	var out := PackedVector2Array()
	for p in [a, b, c]:
		var world: Vector3 = view.to_global(p)
		if cam.is_position_behind(world):
			return PackedVector2Array()
		out.append(cam.unproject_position(world))
	return out


## Offset each edge outward by `pad` pixels so a sample inside a thin wall
## still lands in a filled pixel.
func _expand(a: Vector2, b: Vector2, c: Vector2, pad: float) -> PackedVector2Array:
	var pts: Array[Vector2] = [a, b, c]
	var mid := (a + b + c) / 3.0
	var lines: Array = []
	for i in 3:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % 3]
		var edge := q - p
		if edge.length_squared() < 1e-8:
			return PackedVector2Array([a, b, c])
		var n := Vector2(edge.y, -edge.x).normalized()
		if n.dot(mid - (p + q) * 0.5) > 0.0:
			n = -n
		lines.append([p + n * pad, edge])
	var out := PackedVector2Array()
	for i in 3:
		var prev: Array = lines[(i + 2) % 3]
		var here: Array = lines[i]
		out.append(_line_hit(prev[0], prev[1], here[0], here[1]))
	return out


func _line_hit(p: Vector2, d: Vector2, q: Vector2, e: Vector2) -> Vector2:
	var den := d.x * e.y - d.y * e.x
	if absf(den) < 1e-8:
		return p
	var s := ((q.x - p.x) * e.y - (q.y - p.y) * e.x) / den
	return p + d * s
