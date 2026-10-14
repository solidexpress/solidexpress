class_name SectionCap
extends Node2D
## Screen-space fill of the section cut.
##
## The body shader discards the near half and the back faces on the cut, so
## this canvas colour shows through. A 1 mm wall is about one pixel; each
## cut triangle is drawn as its screen rectangle plus a few pixels of pad.
## Canvas is not tonemapped, so the fill is SectionPlane.CAP_COLOUR exactly.


const PAD_PX := 16.0

var view: DocumentView

var _key := ""
var _polys: Array[PackedVector2Array] = []


func _process(_dt: float) -> void:
	if view == null or not view.section_enabled or view.doc == null:
		if not _polys.is_empty() or visible:
			_polys.clear()
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
	_polys.clear()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or view == null or view.doc == null:
		return
	if not view.doc.has_method("section_cap_mesh"):
		return
	var point := view.section_point()
	var normal := view.section_normal()
	for body_id in view.doc.body_ids():
		var built: ArrayMesh = view.doc.section_cap_mesh(str(body_id), point, normal)
		if built == null:
			continue
		for s in built.get_surface_count():
			var arrays: Array = built.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				continue
			var t := 0
			while t + 2 < idx.size():
				var poly := _screen_rect(cam, verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]])
				if poly.size() == 4:
					_polys.append(poly)
				t += 3


func _screen_rect(cam: Camera3D, a: Vector3, b: Vector3, c: Vector3) -> PackedVector2Array:
	var min_s := Vector2(INF, INF)
	var max_s := Vector2(-INF, -INF)
	for p in [a, b, c]:
		var world: Vector3 = view.to_global(p)
		if cam.is_position_behind(world):
			return PackedVector2Array()
		var s := _viewport_to_canvas(cam.unproject_position(world))
		min_s = min_s.min(s)
		max_s = max_s.max(s)
	min_s -= Vector2(PAD_PX, PAD_PX)
	max_s += Vector2(PAD_PX, PAD_PX)
	var poly := PackedVector2Array()
	poly.append(min_s)
	poly.append(Vector2(max_s.x, min_s.y))
	poly.append(max_s)
	poly.append(Vector2(min_s.x, max_s.y))
	return poly


func _viewport_to_canvas(screen: Vector2) -> Vector2:
	var xform := get_global_transform_with_canvas()
	if xform.determinant() == 0.0:
		return screen
	return xform.affine_inverse() * screen


func _draw() -> void:
	var colour := SectionPlane.CAP_COLOUR
	for poly in _polys:
		draw_colored_polygon(poly, colour)
