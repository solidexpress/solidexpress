# Sweep and loft smoke tests with spline geometry; assert closed solids (volume), not open shells.
# Run: tools/godot/godot --headless --path game --script tests/run_sweep_loft_solid_tests.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("sweep/loft solid tests (splines)")
	test_sweep_catmull_path_solid()
	test_sweep_along_path_join_spline_3d()
	test_sweep_along_path_bridge_spline()
	test_sweep_path_merge_spline_rail_solid()
	test_sweep_single_rail_path_solid()
	test_loft_spline_profiles_solid()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _catmull2(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _catmull3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _densify_open_2d(control: Array) -> Array[Vector2]:
	var densified: Array[Vector2] = []
	if control.size() < 2:
		return densified
	if control.size() == 2:
		densified.append(control[0])
		densified.append(control[1])
		return densified
	for i in range(control.size() - 1):
		var p0: Vector2 = control[maxi(i - 1, 0)]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[i + 1]
		var p3: Vector2 = control[mini(i + 2, control.size() - 1)]
		for s in range(8):
			var t := float(s) / 8.0
			densified.append(_catmull2(p0, p1, p2, p3, t))
	densified.append(control[control.size() - 1])
	return densified


func _densify_open_3d(control: Array) -> PackedVector3Array:
	var path := PackedVector3Array()
	if control.size() < 2:
		return path
	if control.size() == 2:
		path.append(control[0])
		path.append(control[1])
		return path
	for i in range(control.size() - 1):
		var p0: Vector3 = control[maxi(i - 1, 0)]
		var p1: Vector3 = control[i]
		var p2: Vector3 = control[i + 1]
		var p3: Vector3 = control[mini(i + 2, control.size() - 1)]
		for s in range(8):
			var t := float(s) / 8.0
			path.append(_catmull3(p0, p1, p2, p3, t))
	path.append(control[control.size() - 1])
	return path


func _polyline_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	return length


func _add_open_spline_sketch(sk: SxSketch, control: Array) -> void:
	var pts := PackedVector2Array()
	for p in control:
		pts.append(p as Vector2)
	sk.add_spline(pts)


func _add_closed_spline_profile(sk: SxSketch, radius: float, segments: int = 8) -> void:
	var control: Array = []
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		control.append(Vector2(cos(ang) * radius, sin(ang) * radius))
	control.append(control[0])
	control.append(control[1])
	var pts := _densify_open_2d(control)
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) > 1e-6:
			sk.add_line(a.x, a.y, b.x, b.y)
	var first: Vector2 = pts[0]
	var last: Vector2 = pts[pts.size() - 1]
	if first.distance_to(last) > 1e-6:
		sk.add_line(last.x, last.y, first.x, first.y)


func _output_body(doc: SxDocument, feature_id: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == feature_id:
			return str(f.get("output_body", ""))
	return ""


func _path_length_from_path_feature(doc: SxDocument, path_fid: String) -> float:
	for f in doc.graph_features():
		if str(f.get("id", "")) != path_fid:
			continue
		var parsed: Variant = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			return 0.0
		var path_arr: Array = parsed.get("path", [])
		if path_arr.size() < 2:
			return 0.0
		var length := 0.0
		var prev := Vector3(
			float(path_arr[0][0]), float(path_arr[0][1]), float(path_arr[0][2]))
		for i in range(1, path_arr.size()):
			var p := Vector3(
				float(path_arr[i][0]), float(path_arr[i][1]), float(path_arr[i][2]))
			length += prev.distance_to(p)
			prev = p
		return length
	return 0.0

func _path_points_from_path_feature(doc: SxDocument, path_fid: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for f in doc.graph_features():
		if str(f.get("id", "")) != path_fid:
			continue
		var parsed: Variant = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			return out
		var path_arr: Array = parsed.get("path", [])
		for pt in path_arr:
			out.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
		return out
	return out


func _assert_solid_volume(doc: SxDocument, body_id: String, expected: float, rel_tol: float, label: String) -> void:
	check(body_id != "", "%s: feature produced output_body" % label)
	var vol: float = doc.body_volume(body_id)
	check(vol > 0.0, "%s: volume > 0" % label)
	check(absf(vol - expected) / expected < rel_tol,
		"%s: volume ~%.0f (got %.0f, expected %.0f)" % [label, expected, vol, expected])
	check(vol > expected * 0.35, "%s: volume large enough to be a solid fill" % label)
	var mp: Dictionary = doc.measure_mass(body_id)
	if mp.has("volume"):
		check(absf(float(mp["volume"]) - vol) < 1e-3, "%s: measure_mass volume matches body_volume" % label)


func test_sweep_catmull_path_solid() -> void:
	print("-- sweep along 3D Catmull path")
	var doc := SxDocument.new()
	var profile := SxSketch.new()
	const R := 2.0
	profile.add_circle(0, 0, R)
	var prof_fid: String = doc.graph_add_sketch(profile)
	check(prof_fid != "", "profile sketch")

	var ctrl := [
		Vector3(0, 0, 0),
		Vector3(0, 0, 18),
		Vector3(22, 0, 24),
		Vector3(35, 6, 28),
	]
	var path := _densify_open_3d(ctrl)
	check(path.size() >= 4, "spline path has dense samples")
	var sw_fid: String = doc.graph_add_sweep(prof_fid, path)
	check(sw_fid != "", "sweep feature")
	var body := _output_body(doc, sw_fid)
	var expected := PI * R * R * _polyline_length(path)
	_assert_solid_volume(doc, body, expected, 0.18, "sweep catmull")


func test_sweep_along_path_join_spline_3d() -> void:
	print("-- sweep along path (spline rail + vertical leg, UI merge join)")
	var doc := SxDocument.new()
	var sk_a := SxSketch.new()
	_add_open_spline_sketch(sk_a, [Vector2(0, 0), Vector2(8, 4), Vector2(20, 0)])
	var fid_a: String = doc.graph_add_sketch(sk_a)
	var sk_b := SxSketch.new()
	sk_b.set_plane(Vector3(20, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	sk_b.add_line(0, 0, 0, 30)
	var fid_b: String = doc.graph_add_sketch(sk_b)
	var path_fid: String = doc.graph_add_path(PackedStringArray([fid_a, fid_b]), "join_endpoints")
	check(path_fid != "", "path feature")
	var profile := SxSketch.new()
	const R := 2.0
	profile.add_circle(0, 0, R)
	var prof_fid: String = doc.graph_add_sketch(profile)
	var sw_fid: String = doc.graph_add_sweep_along_path(prof_fid, path_fid)
	check(sw_fid != "", "sweep along path feature")
	var body := _output_body(doc, sw_fid)
	var vol: float = doc.body_volume(body)
	check(vol > 400.0, "3d path sweep solid volume (got %.0f)" % vol)


func test_sweep_along_path_bridge_spline() -> void:
	print("-- sweep along path (merge spline / bridge_spline)")
	var doc := SxDocument.new()
	var sk_a := SxSketch.new()
	_add_open_spline_sketch(sk_a, [Vector2(0, 0), Vector2(12, 6), Vector2(28, 1)])
	var fid_a: String = doc.graph_add_sketch(sk_a)
	var sk_b := SxSketch.new()
	sk_b.add_line(28, 1, 45, -2)
	var fid_b: String = doc.graph_add_sketch(sk_b)
	var path_fid: String = doc.graph_add_path(PackedStringArray([fid_a, fid_b]), "bridge_spline")
	check(path_fid != "", "bridge_spline path")
	var profile := SxSketch.new()
	profile.add_circle(0, 0, 2)
	var prof_fid: String = doc.graph_add_sketch(profile)
	var sw_fid: String = doc.graph_add_sweep_along_path(prof_fid, path_fid)
	check(sw_fid != "", "sweep along bridge path")
	var body := _output_body(doc, sw_fid)
	check(doc.body_volume(body) > 300.0, "bridge_spline sweep solid")


func test_sweep_path_merge_spline_rail_solid() -> void:
	print("-- sweep from path merge (open spline rail)")
	var doc := SxDocument.new()

	var sk_a := SxSketch.new()
	_add_open_spline_sketch(sk_a, [Vector2(0, 0), Vector2(10, 5), Vector2(25, 2)])
	var fid_a: String = doc.graph_add_sketch(sk_a)

	var sk_b := SxSketch.new()
	sk_b.add_line(25, 2, 40, -2)
	var fid_b: String = doc.graph_add_sketch(sk_b)
	check(fid_a != "" and fid_b != "", "path rail sketches")

	var path_fid: String = doc.graph_add_path(PackedStringArray([fid_a, fid_b]), "join_endpoints")
	check(path_fid != "", "graph_add_path join_endpoints")
	var path_pts := _path_points_from_path_feature(doc, path_fid)
	check(path_pts.size() >= 4, "merged path has dense spline samples")

	var profile := SxSketch.new()
	const R := 2.0
	_add_closed_spline_profile(profile, R)
	var prof_fid: String = doc.graph_add_sketch(profile)
	var sw_fid: String = doc.graph_add_sweep_along_path(prof_fid, path_fid)
	check(sw_fid != "", "sweep along merged path")
	var body := _output_body(doc, sw_fid)
	var vol: float = doc.body_volume(body)
	check(vol > 350.0, "coplanar merged spline path sweep solid (got %.0f)" % vol)


func test_sweep_single_rail_path_solid() -> void:
	print("-- sweep along single-rail Path")
	var doc := SxDocument.new()
	var rail := SxSketch.new()
	rail.add_line(0, 0, 40, 0)
	var rail_fid: String = doc.graph_add_sketch(rail)
	var path_fid: String = doc.graph_add_path(PackedStringArray([rail_fid]), "join_endpoints")
	check(path_fid != "", "single-sketch Path")
	var profile := SxSketch.new()
	profile.add_circle(0, 0, 2)
	var prof_fid: String = doc.graph_add_sketch(profile)
	var sw_fid: String = doc.graph_add_sweep_along_path(prof_fid, path_fid)
	check(sw_fid != "", "sweep along single-rail Path")
	var body := _output_body(doc, sw_fid)
	var vol: float = doc.body_volume(body)
	check(vol > 400.0, "single-rail Path sweep solid (got %.0f)" % vol)


func test_loft_spline_profiles_solid() -> void:
	print("-- loft between closed spline profiles")
	var doc := SxDocument.new()

	var bottom := SxSketch.new()
	_add_closed_spline_profile(bottom, 10.0)
	var bottom_fid: String = doc.graph_add_sketch(bottom)
	check(bottom_fid != "", "loft bottom sketch")

	var top := SxSketch.new()
	top.set_plane(Vector3(0, 0, 30), Vector3(1, 0, 0), Vector3(0, 1, 0))
	_add_closed_spline_profile(top, 5.0)
	var top_fid: String = doc.graph_add_sketch(top)
	check(top_fid != "", "loft top sketch")

	var loft_fids := PackedStringArray([bottom_fid, top_fid])
	var loft_fid: String = doc.graph_add_loft(loft_fids, true)
	check(loft_fid != "", "loft feature")
	var body := _output_body(doc, loft_fid)

	const A1 := PI * 100.0
	const A2 := PI * 25.0
	const H := 30.0
	var expected := H / 3.0 * (A1 + A2 + sqrt(A1 * A2))
	_assert_solid_volume(doc, body, expected, 0.12, "loft spline frustum")