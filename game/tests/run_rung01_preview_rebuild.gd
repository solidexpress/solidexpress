# Headless: timeline Distance preview of the wrench base extrude must show
# the same fully rebuilt solid that committing the edit keeps.
# Preview is typing 1, 4, Enter in the timeline Distance field
# (status "Preview: distance = 14.0"). A frame between the keys must not
# turn that into 4. Commit is the empty-viewport dismiss that keeps the edit.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_preview_rebuild.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL := 0.35
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const LONG_DISCARD := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 10.0
const T_NEW := 14.0

var _status_log: PackedStringArray = PackedStringArray()


func _init() -> void:
	print("rung01 preview rebuild: base distance 14 shows the committed wrench")
	var ctx := await _boot()
	var built := await _build_wrench(ctx)
	if built:
		await _preview_then_commit(ctx)
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	finish()


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	if ctx.main.timeline != null and ctx.main.timeline.property_panel != null:
		ctx.main.timeline.property_panel.status.connect(func(t: String) -> void:
			_status_log.append(t)
		)
	if ctx.main.has_method("_on_status"):
		pass
	return ctx


func _build_wrench(ctx: FilmContext) -> bool:
	print("- blank")
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is active")
	if sm == null or not sm.active:
		return false
	sm.snap_enabled = false
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	var tangent_x := HEAD.x - sqrt(22.5 * 22.5 - 100.0)
	sm.sketch.add_line(0.0, 10.0, tangent_x, 10.0)
	sm.sketch.add_line(0.0, -10.0, tangent_x, -10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc: SxDocument = ctx.view.doc
	if doc.body_ids().is_empty():
		check(false, "one body after the blank")
		return false
	var body := str(doc.body_ids()[0])

	print("- jaw cut")
	var top := _face_at(doc, body, 10.0)
	var bottom := _face_at(doc, body, 0.0)
	check(top != "" and bottom != "", "blank top and bottom faces")
	if top == "" or bottom == "":
		return false
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	if not sm.active:
		check(false, "jaw sketch is active")
		return false
	sm.snap_enabled = false
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_DIR * 30.0)
	sm.click(HEAD + JAW_ACROSS * 10.0)
	for i in sm.dimensions.size():
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) == "distance":
			sm.set_dimension_value(i, 20.0)
		elif str(dim.get("type", "")) == "angle":
			sm.set_dimension_value(i, 45.0)
	var cc := HEAD + JAW_DIR * 12.0
	sm.sketch.add_line((cc - JAW_ACROSS * 25.0).x, (cc - JAW_ACROSS * 25.0).y,
			(cc + JAW_ACROSS * 25.0).x, (cc + JAW_ACROSS * 25.0).y)
	sm.run_solve()
	var opened := sm.trim_at(LONG_DISCARD + JAW_ACROSS * 4.0)
	check(opened, "jaw trim opened the profile")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_finish_op("cut")
	chrome.set_finish_end("to_face")
	chrome.set_up_to_face(bottom)
	sm.finish_extrude(10.0, "cut", "to_face")
	await process_frame
	await process_frame
	check(doc.last_graph_error() == "", "jaw cut accepted (%s)" % doc.last_graph_error())
	if doc.body_ids().is_empty():
		return false
	body = str(doc.body_ids()[0])

	print("- grip slot")
	top = _face_at(doc, body, 10.0)
	if top == "":
		check(false, "top face after the jaw cut")
		return false
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	if not sm.active:
		check(false, "slot sketch is active")
		return false
	sm.snap_enabled = false
	sm.set_tool(SketchMode.Tool.SLOT)
	sm.slot_radius = 5.0
	sm.click(Vector2(18.5, 0.0))
	sm.click(Vector2(168.5, 0.0))
	chrome = ctx.main.sketch_chrome
	chrome.set_finish_op("cut")
	chrome.set_finish_end("blind")
	sm.finish_extrude(2.5, "cut", "blind")
	await process_frame
	await process_frame
	if doc.body_ids().is_empty():
		check(false, "slot cut kept a body")
		return false
	body = str(doc.body_ids()[0])

	print("- fillets")
	var host := ctx.view.feature_of_body(body)
	var neck_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	var neck := _neck_edges(doc, body, neck_x)
	check(neck.size() == 2, "two neck verticals (got %d)" % neck.size())
	if neck.size() == 2:
		doc.graph_add_fillet(host, neck, 10.0)
	for z_want in [10.0, 0.0, 7.5]:
		var face := _face_at(doc, body, z_want)
		if face == "":
			continue
		doc.graph_add_fillet(host, doc.edges_of_face(face), 1.0)
	check(str(doc.graph_warnings()).find("lost on rebuild") < 0,
			"build warnings have no lost edges (%s)" % str(doc.graph_warnings()))
	var before := _load_mesh(doc.get_mesh(body))
	check(_pivot_open(before, 10.0), "T=10 pivot is open before the edit")
	check(_jaw_open(before, 10.0), "T=10 jaw is open before the edit")
	return doc.body_ids().size() == 1 and neck.size() == 2


func _preview_then_commit(ctx: FilmContext) -> void:
	print("- preview distance 14")
	var doc: SxDocument = ctx.view.doc
	var boss := _boss_extrude_id(doc)
	check(boss != "", "base extrude is on the timeline")
	if boss == "":
		return
	ctx.main.show_timeline = true
	ctx.main.timeline.visible = true
	var panel: PropertyPanel = ctx.main.timeline.property_panel
	check(panel.open(boss), "property panel opens the base extrude")
	panel.focus_schema_key("distance")
	await process_frame
	var spin := panel._spin_for_key("distance")
	check(spin != null, "Distance spin exists")
	if spin == null:
		return
	var edit := spin.get_line_edit()
	check(edit != null, "Distance line edit exists")
	if edit == null:
		return
	# Real keys, the way the timeline walk types Distance: 1, then 4, then Enter.
	# A partial "1" must not rebuild the wrench before Enter.
	var vp := edit.get_viewport()
	await _push_key(vp, KEY_1, 49)
	check(is_equal_approx(_line_number(edit), 1.0),
			"first Distance key replaces the value (text '%s')" % edit.text)
	check(is_equal_approx(_feature_distance(doc), 10.0),
			"partial digit does not rebuild (distance %.3f)" % _feature_distance(doc))
	await _push_key(vp, KEY_4, 52)
	check(is_equal_approx(_line_number(edit), 14.0),
			"second Distance key appends (text '%s')" % edit.text)
	check(is_equal_approx(_feature_distance(doc), 10.0),
			"Distance waits for Enter (distance %.3f)" % _feature_distance(doc))
	await _push_key(vp, KEY_ENTER, 0)
	await process_frame
	await process_frame
	var status := " | ".join(_status_log)
	check(status.contains("Preview: distance = 14"), "status previews distance 14 (%s)" % status)
	check(status.find("lost on rebuild") < 0, "preview status has no lost on rebuild (%s)" % status)
	if doc.body_ids().is_empty():
		check(false, "body remains during preview")
		return
	var body := str(doc.body_ids()[0])
	var kernel := _load_mesh(doc.get_mesh(body))
	var node: MeshInstance3D = ctx.view.body_node(body)
	var shown := _load_mesh(node.mesh if node != null else null)
	check(node != null and node.mesh != null, "viewport has a preview mesh")
	_report_openings("kernel preview", kernel)
	_report_openings("viewport preview", shown)
	check(_pivot_open(shown, T_NEW), "preview mesh pivot hole is through at T=14")
	check(_jaw_open(shown, T_NEW), "preview mesh jaw opening is through at T=14")
	check(_same_openings(shown, kernel), "viewport preview mesh matches the kernel mesh")
	var preview_jaw := _jaw_hits(shown)
	var preview_pivot := _pivot_hits(shown)

	print("- commit (empty viewport keeps the edit)")
	panel.dismiss_keep_preview()
	await process_frame
	await process_frame
	ctx.view.refresh()
	var committed := _load_mesh(doc.get_mesh(body))
	var committed_node: MeshInstance3D = ctx.view.body_node(body)
	var committed_shown := _load_mesh(committed_node.mesh if committed_node != null else null)
	_report_openings("committed", committed_shown)
	check(_pivot_open(committed_shown, T_NEW), "committed mesh pivot hole is through at T=14")
	check(_jaw_open(committed_shown, T_NEW), "committed mesh jaw opening is through at T=14")
	check(_hits_match(preview_pivot, _pivot_hits(committed_shown), "pivot"),
			"preview pivot XY matches the committed pivot")
	check(_hits_match(preview_jaw, _jaw_hits(committed_shown), "jaw"),
			"preview jaw XY matches the committed jaw")
	check(_same_openings(shown, committed_shown),
			"preview openings match the committed openings")
	var ext := _extent(doc, body)
	check(absf(ext.z - T_NEW) <= TOL, "committed bbox Z is 14 (got %.3f)" % ext.z)


func _line_number(edit: LineEdit) -> float:
	var text := edit.text.strip_edges().replace(",", ".")
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3).strip_edges()
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2).strip_edges()
	if not text.is_valid_float():
		return NAN
	return float(text)


func _feature_distance(doc: SxDocument) -> float:
	var parsed = JSON.parse_string(_params_of(doc, _boss_extrude_id(doc)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return NAN
	return float(parsed.get("distance", NAN))


func _params_of(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("params", "{}"))
	return "{}"


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _report_openings(label: String, mesh: Array) -> void:
	var pivot := _pivot_open(mesh, T_NEW)
	var jaw := _jaw_open(mesh, T_NEW)
	print("  %s: pivot_through=%s jaw_through=%s tris=%d" % [
		label, str(pivot), str(jaw), _tri_count(mesh)])
	for z in [0.5, T_NEW * 0.5, T_NEW - 0.5]:
		var solid_pivot := _inside(mesh, Vector3(0, 0, z))
		if solid_pivot:
			print("    pivot SOLID at z=%.2f" % z)
	var s2 := sqrt(2.0) / 2.0
	var axis := Vector3(s2, s2, 0)
	var h := Vector3(200, 0, 0)
	for u in [3.0, 11.0, 18.0]:
		for z in [0.5, T_NEW * 0.5, T_NEW - 0.5]:
			var p: Vector3 = h + axis * u + Vector3(0, 0, z)
			if _inside(mesh, p):
				print("    jaw SOLID at u=%.1f z=%.2f (%.2f, %.2f)" % [u, z, p.x, p.y])


func _pivot_open(mesh: Array, thickness: float) -> bool:
	if mesh.is_empty():
		return false
	for z in [0.5, thickness * 0.5, thickness - 0.5]:
		if _inside(mesh, Vector3(0, 0, z)):
			return false
	return true


func _jaw_open(mesh: Array, thickness: float) -> bool:
	if mesh.is_empty():
		return false
	var s2 := sqrt(2.0) / 2.0
	var axis := Vector3(s2, s2, 0)
	var h := Vector3(200, 0, 0)
	for u in [3.0, 11.0, 18.0]:
		for z in [0.5, thickness * 0.5, thickness - 0.5]:
			if _inside(mesh, h + axis * u + Vector3(0, 0, z)):
				return false
	return true


func _pivot_hits(mesh: Array) -> Array:
	var out: Array = []
	for z in [0.5, T_NEW * 0.5, T_NEW - 0.5]:
		var origin := Vector3(0, 0, z)
		out.append(_gap(mesh, origin, Vector3(1, 0, 0)))
	return out


func _jaw_hits(mesh: Array) -> Array:
	var s2 := sqrt(2.0) / 2.0
	var axis := Vector3(s2, s2, 0)
	var across := Vector3(-s2, s2, 0)
	var h := Vector3(200, 0, 0)
	var out: Array = []
	for u in [3.0, 11.0, 18.0]:
		for z in [0.5, T_NEW * 0.5, T_NEW - 0.5]:
			out.append(_gap(mesh, h + axis * u + Vector3(0, 0, z), across))
	return out


## First-hit distances along +dir and -dir. Empty gaps are [-1, -1].
func _gap(mesh: Array, origin: Vector3, dir: Vector3) -> Vector2:
	if mesh.is_empty():
		return Vector2(-1, -1)
	return Vector2(_first_hit(mesh, origin, dir), _first_hit(mesh, origin, -dir))


func _hits_match(a: Array, b: Array, label: String) -> bool:
	if a.size() != b.size():
		print("  %s hit count %d vs %d" % [label, a.size(), b.size()])
		return false
	for i in a.size():
		var pa: Vector2 = a[i]
		var pb: Vector2 = b[i]
		if pa.x < 0.0 or pb.x < 0.0 or pa.y < 0.0 or pb.y < 0.0:
			print("  %s miss at %d preview=%s committed=%s" % [label, i, str(pa), str(pb)])
			return false
		if absf(pa.x - pb.x) > TOL or absf(pa.y - pb.y) > TOL:
			print("  %s XY drift at %d preview=%s committed=%s" % [label, i, str(pa), str(pb)])
			return false
	return true


func _same_openings(a: Array, b: Array) -> bool:
	return _pivot_open(a, T_NEW) == _pivot_open(b, T_NEW) and _jaw_open(a, T_NEW) == _jaw_open(b, T_NEW) \
			and _hits_match(_pivot_hits(a), _pivot_hits(b), "pair-pivot") \
			and _hits_match(_jaw_hits(a), _jaw_hits(b), "pair-jaw")


func _tri_count(mesh: Array) -> int:
	if mesh.is_empty():
		return 0
	var idx: PackedInt32Array = mesh[1]
	return idx.size() / 3


func _extent(doc: SxDocument, body: String) -> Vector3:
	var bb: Dictionary = doc.measure_bbox(body)
	if bb.is_empty():
		return Vector3.ZERO
	return bb["max"] - bb["min"]


func _face_at(doc: SxDocument, body: String, z_want: float) -> String:
	var best := ""
	var best_area := 20.0
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = bb["max"] - bb["min"]
		if ext.z > 0.05:
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		var mid_z := (mn.z + mx.z) * 0.5
		if absf(mid_z - z_want) > 0.2:
			continue
		var area := ext.x * ext.y
		if area > best_area:
			best_area = area
			best = str(fid)
	return best


func _neck_edges(doc: SxDocument, body: String, neck_x: float) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: Dictionary = doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		if absf(pts[0].z - pts[pts.size() - 1].z) < 5.0:
			continue
		if absf(mid.x - neck_x) < 1.5 and absf(absf(mid.y) - 10.0) < 0.8:
			out.append(str(eid))
	return out


func _boss_extrude_id(doc: SxDocument) -> String:
	for f in doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("op", "new")) == "new":
			return str(f.get("id", ""))
	return ""


func _load_mesh(mesh: ArrayMesh) -> Array:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	if mesh == null:
		return [verts, idx]
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if ii.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	return [verts, idx]


func _ray_hits(mesh: Array, origin: Vector3, dir: Vector3) -> Array[float]:
	var verts: PackedVector3Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	var d := dir.normalized()
	var hits: Array[float] = []
	var ntri := idx.size() / 3
	for t in ntri:
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var e1 := b - a
		var e2 := c - a
		var pvec := d.cross(e2)
		var det := e1.dot(pvec)
		if absf(det) < 1e-12:
			continue
		var inv := 1.0 / det
		var s := origin - a
		var u := s.dot(pvec) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := s.cross(e1)
		var v := d.dot(q) * inv
		if v < 0.0 or u + v > 1.0:
			continue
		var dist := e2.dot(q) * inv
		if dist > 1e-6:
			hits.append(dist)
	hits.sort()
	return hits


func _inside(mesh: Array, pt: Vector3) -> bool:
	if mesh.is_empty() or (mesh[0] as PackedVector3Array).is_empty():
		return false
	var votes := 0
	for d in [Vector3(1, 0.0123, 0.0071), Vector3(0.0091, 1, 0.0137), Vector3(0.0113, 0.0067, 1)]:
		if _ray_hits(mesh, pt, d).size() % 2 == 1:
			votes += 1
	return votes >= 2


func _first_hit(mesh: Array, origin: Vector3, dir: Vector3) -> float:
	var hits := _ray_hits(mesh, origin, dir)
	if hits.is_empty():
		return -1.0
	return hits[0]
