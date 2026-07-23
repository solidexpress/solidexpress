class_name SketchPadOverlay
extends Node3D
## Yellow translucent pads for committed Sketch features (extents + 20%).
## Thin fill + high-reflection rim + profile curves; clickable when not editing.

## Fill is deliberately thin (1/10 of the previous 0.28 alpha).
const PAD_COLOR := Color(1.0, 0.9, 0.2, 0.028)
const EDGE_COLOR := Color(1.0, 0.95, 0.55, 1.0)
## Opaque profile so the 2D shape reads clearly on the pad in 3D.
const PROFILE_COLOR := Color(0.98, 0.78, 0.08, 1.0)
const CONSTRUCTION_COLOR := Color(0.85, 0.7, 0.25, 0.45)
const PAD_FRAC := 0.2
## Rim half-width in sketch-plane units (mm); ~1/3 of the original 0.35.
const EDGE_HALF := 0.35 / 3.0
## Profile curve half-width in sketch-plane units (mm) — world-space so it stays readable when orbiting.
const PROFILE_HALF := 0.28

## DocumentView (avoid typed cycle).
var view: Node
## fid -> {mesh, edge, profile, origin, x, y, min2, max2, normal}
var _pads: Dictionary = {}
var _mat: StandardMaterial3D
var _edge_mat: StandardMaterial3D
var _profile_mat: StandardMaterial3D
## Feature id currently being edited (hide that pad); "" = show all.
var _hidden_fid := ""


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = PAD_COLOR
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	_edge_mat = StandardMaterial3D.new()
	_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_edge_mat.albedo_color = EDGE_COLOR
	_edge_mat.metallic = 1.0
	_edge_mat.roughness = 0.08
	_edge_mat.metallic_specular = 1.0
	_edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_edge_mat.rim_enabled = true
	_edge_mat.rim = 0.85
	_edge_mat.rim_tint = 0.4

	_profile_mat = StandardMaterial3D.new()
	_profile_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_profile_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_profile_mat.albedo_color = Color.WHITE
	_profile_mat.vertex_color_use_as_albedo = true
	_profile_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_profile_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED


## Rebuild pads from graph sketch features. Pass editing_fid to hide that pad
## (use a non-empty sentinel like "_active" for a brand-new session).
func refresh(doc: SxDocument, editing_fid: String = "") -> void:
	_hidden_fid = editing_fid
	_clear()
	if doc == null:
		return
	for feat in doc.graph_features():
		if str(feat.get("type", "")) != "sketch":
			continue
		var fid: String = str(feat.get("id", ""))
		if fid == "" or fid == editing_fid:
			continue
		var sk: SxSketch = doc.graph_get_sketch(fid)
		if sk == null or sk.entity_ids().is_empty():
			continue
		_add_pad(fid, sk)


func _clear() -> void:
	for fid in _pads.keys():
		var entry: Dictionary = _pads[fid]
		for key in ["mesh", "edge", "profile"]:
			var mesh: MeshInstance3D = entry.get(key)
			if mesh != null and is_instance_valid(mesh):
				mesh.queue_free()
	_pads.clear()


func _add_pad(fid: String, sk: SxSketch) -> void:
	var pi: Dictionary = sk.plane_info()
	if pi.is_empty():
		return
	var origin: Vector3 = pi["origin"]
	var x_dir: Vector3 = (pi["x_dir"] as Vector3).normalized()
	var y_dir: Vector3 = (pi["y_dir"] as Vector3).normalized()
	var normal: Vector3 = (pi["normal"] as Vector3).normalized()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in sk.entity_ids():
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				mn = mn.min(a).min(b)
				mx = mx.max(a).max(b)
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
			"point":
				var p: Vector2 = info["position"]
				mn = mn.min(p)
				mx = mx.max(p)
			_:
				pass
	if not is_finite(mn.x):
		return
	var size := mx - mn
	var pad := size * PAD_FRAC * 0.5
	pad.x = maxf(pad.x, 2.0)
	pad.y = maxf(pad.y, 2.0)
	mn -= pad
	mx += pad
	# Slight offset along normal so pad sits above the face.
	var lift := normal * 0.05
	var corners := [
		origin + x_dir * mn.x + y_dir * mn.y + lift,
		origin + x_dir * mx.x + y_dir * mn.y + lift,
		origin + x_dir * mx.x + y_dir * mx.y + lift,
		origin + x_dir * mn.x + y_dir * mx.y + lift,
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(PAD_COLOR)
	# Two triangles (both windings via CULL_DISABLED).
	st.add_vertex(corners[0])
	st.add_vertex(corners[1])
	st.add_vertex(corners[2])
	st.add_vertex(corners[0])
	st.add_vertex(corners[2])
	st.add_vertex(corners[3])
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _mat
	mesh.name = "SketchPad_%s" % fid.substr(0, 8)
	add_child(mesh)

	var edge := _make_edge_mesh(corners, normal)
	edge.name = "SketchPadEdge_%s" % fid.substr(0, 8)
	add_child(edge)

	var profile := _make_profile_mesh(sk, origin, x_dir, y_dir, normal)
	if profile != null:
		profile.name = "SketchPadProfile_%s" % fid.substr(0, 8)
		add_child(profile)

	_pads[fid] = {
		"mesh": mesh,
		"edge": edge,
		"profile": profile,
		"origin": origin,
		"x": x_dir,
		"y": y_dir,
		"normal": normal,
		"min2": mn,
		"max2": mx,
	}


## Reflective rim: thin quads around the pad perimeter (screen-stable width in mm).
## Odd-numbered sides extend by full line thickness so corners overlap cleanly
## instead of leaving a jagged notch where ribbons meet.
func _make_edge_mesh(corners: Array, normal: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Lift the rim a hair above the fill so it wins depth without z-fight.
	var rim_lift := normal * 0.01
	var thickness := EDGE_HALF * 2.0
	for i in range(4):
		var a: Vector3 = corners[i] + rim_lift
		var b: Vector3 = corners[(i + 1) % 4] + rim_lift
		var along := (b - a)
		if along.length_squared() < 1e-12:
			continue
		var dir := along.normalized()
		# Edges 1 and 3 overlap even edges at corners by one full thickness.
		if i % 2 == 1:
			a -= dir * thickness
			b += dir * thickness
		var outward := dir.cross(normal).normalized()
		# Keep the rim centered on the boundary.
		var o0 := a + outward * EDGE_HALF
		var o1 := b + outward * EDGE_HALF
		var i0 := a - outward * EDGE_HALF
		var i1 := b - outward * EDGE_HALF
		st.set_normal(normal)
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(i1)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _edge_mat
	return mesh


## Draw the sketch's lines / circles / arcs on the pad so the profile is readable in 3D.
func _make_profile_mesh(sk: SxSketch, origin: Vector3, x_dir: Vector3, y_dir: Vector3,
		normal: Vector3) -> MeshInstance3D:
	var lift := normal * 0.07
	var to3 := func(p: Vector2) -> Vector3:
		return origin + x_dir * p.x + y_dir * p.y + lift

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has := false
	for id in sk.entity_ids():
		var info: Dictionary = sk.entity_info(id)
		var col := CONSTRUCTION_COLOR if bool(info.get("construction", false)) else PROFILE_COLOR
		match str(info.get("type", "")):
			"line":
				has = true
				_add_profile_seg(st, to3.call(info["start"]), to3.call(info["end"]),
						normal, col)
			"circle":
				has = true
				var c: Vector2 = info["center"]
				var r: float = float(info["radius"])
				var steps := 48
				for i in range(steps):
					var a0 := TAU * float(i) / float(steps)
					var a1 := TAU * float(i + 1) / float(steps)
					_add_profile_seg(st,
							to3.call(c + Vector2(cos(a0), sin(a0)) * r),
							to3.call(c + Vector2(cos(a1), sin(a1)) * r),
							normal, col)
			"arc":
				has = true
				var c2: Vector2 = info["center"]
				var r2: float = float(info["radius"])
				var s: float = float(info["start_angle"])
				var e: float = float(info["end_angle"])
				if e < s:
					e += TAU
				var steps2 := 32
				for i in range(steps2):
					var a0 := s + (e - s) * float(i) / float(steps2)
					var a1 := s + (e - s) * float(i + 1) / float(steps2)
					_add_profile_seg(st,
							to3.call(c2 + Vector2(cos(a0), sin(a0)) * r2),
							to3.call(c2 + Vector2(cos(a1), sin(a1)) * r2),
							normal, col)
			"point":
				has = true
				var pt: Vector2 = info["position"]
				const MARK := 0.8
				_add_profile_seg(st, to3.call(pt + Vector2(-MARK, 0)),
						to3.call(pt + Vector2(MARK, 0)), normal, col)
				_add_profile_seg(st, to3.call(pt + Vector2(0, -MARK)),
						to3.call(pt + Vector2(0, MARK)), normal, col)
			_:
				pass
	if not has:
		return null
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _profile_mat
	return mesh


func _add_profile_seg(st: SurfaceTool, a: Vector3, b: Vector3, normal: Vector3,
		col: Color) -> void:
	var along := b - a
	if along.length_squared() < 1e-12:
		return
	var sideways := along.cross(normal).normalized() * PROFILE_HALF
	var i0 := a - sideways
	var i1 := b - sideways
	var o0 := a + sideways
	var o1 := b + sideways
	st.set_normal(normal)
	st.set_color(col)
	st.add_vertex(i0)
	st.add_vertex(o0)
	st.add_vertex(o1)
	st.add_vertex(i0)
	st.add_vertex(o1)
	st.add_vertex(i1)


## Ray-pick a sketch pad. When several pads stack in depth (face-hosted over
## ground), prefer the hit closest to that pad's own center — not merely the
## nearest plane — so a click aimed at a back pad still resolves correctly.
func pick_pad(ray_origin: Vector3, ray_dir: Vector3) -> String:
	var best_score := INF
	var best_fid := ""
	for fid in _pads:
		var e: Dictionary = _pads[fid]
		var n: Vector3 = e["normal"]
		var denom := ray_dir.dot(n)
		if absf(denom) < 1e-9:
			continue
		var origin: Vector3 = e["origin"]
		var t := (origin - ray_origin).dot(n) / denom
		if t < 0.0:
			continue
		var hit: Vector3 = ray_origin + ray_dir * t
		var local := hit - origin
		var u := local.dot(e["x"] as Vector3)
		var v := local.dot(e["y"] as Vector3)
		var mn2: Vector2 = e["min2"]
		var mx2: Vector2 = e["max2"]
		if u < mn2.x or u > mx2.x or v < mn2.y or v > mx2.y:
			continue
		var center := (mn2 + mx2) * 0.5
		var extent := (mx2 - mn2).length()
		var radial := Vector2(u, v).distance_to(center)
		# Normalize by pad size; tiny depth bias so equal scores prefer nearer.
		var score := radial / maxf(extent, 1.0) + t * 1e-4
		if score < best_score:
			best_score = score
			best_fid = fid
	return best_fid


## Pads whose screen AABB matches `rect` (window vs crossing, same as bodies).
func pads_in_rect(rect: Rect2, camera: Camera3D, model_space: Node3D, crossing := false) -> Array[String]:
	var band := rect.abs()
	var out: Array[String] = []
	if camera == null:
		return out
	for fid in _pads:
		var scr := pad_screen_aabb(fid, camera, model_space)
		if scr.size == Vector2.ZERO:
			continue
		var ok := band.encloses(scr) if not crossing else band.intersects(scr)
		if ok:
			out.append(fid)
	return out


## Screen AABB of a pad's plane extents (min2/max2 corners).
func pad_screen_aabb(fid: String, camera: Camera3D, model_space: Node3D) -> Rect2:
	if not _pads.has(fid) or camera == null:
		return Rect2()
	var e: Dictionary = _pads[fid]
	var origin: Vector3 = e["origin"]
	var x: Vector3 = e["x"]
	var y: Vector3 = e["y"]
	var mn2: Vector2 = e["min2"]
	var mx2: Vector2 = e["max2"]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var any := false
	for u in [mn2.x, mx2.x]:
		for v in [mn2.y, mx2.y]:
			var model: Vector3 = origin + x * u + y * v
			var world: Vector3 = model_space.to_global(model) if model_space != null else model
			if camera.is_position_behind(world):
				continue
			var s: Vector2 = camera.unproject_position(world)
			mn = mn.min(s)
			mx = mx.max(s)
			any = true
	if not any:
		return Rect2()
	return Rect2(mn, mx - mn)
