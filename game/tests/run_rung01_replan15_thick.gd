# Headless wrench: edit the base extrude 10 → 14.
# Neck fillets are two vertical edges (not a whole face). Their midpoints move
# with thickness; the rebuild must re-resolve them and keep top-face sketches
# on the new top so the slot stays 2.5 deep. Export must pass thick 7/7.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan15_thick.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL := 0.2
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const LONG_DISCARD := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 10.0

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
	print("rung01 thick rebuild: neck fillets and top-face sketches at T=14")
	var ctx := await _boot()
	var built := await _build_wrench(ctx)
	if built:
		await _edit_thickness(ctx)
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


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
	check(doc.body_ids().size() == 1, "one body after the blank (got %d)" % doc.body_ids().size())
	if doc.body_ids().is_empty():
		return false
	var body := str(doc.body_ids()[0])
	var ext := _extent(doc, body)
	check(absf(ext.x - 232.5) <= TOL and absf(ext.y - 45.0) <= TOL and absf(ext.z - 10.0) <= TOL,
			"blank bbox 232.5 × 45 × 10 (got %.3f × %.3f × %.3f)" % [ext.x, ext.y, ext.z])

	print("- jaw cut")
	var top := _face_at(doc, body, 10.0)
	var bottom := _face_at(doc, body, 0.0)
	check(top != "" and bottom != "", "blank top and bottom faces")
	if top == "" or bottom == "":
		return false
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "jaw sketch is active")
	if not sm.active:
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
	check(opened, "jaw trim opened the profile (status %s)" % str(ctx.main.status_label.text))
	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile is closed")
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
	check(top != "", "top face after the jaw cut")
	if top == "":
		return false
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and sm.support_host != "", "slot sketch is anchored to the host face")
	if not sm.active:
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
	check(doc.last_graph_error() == "", "slot cut accepted (%s)" % doc.last_graph_error())
	if doc.body_ids().is_empty():
		return false
	body = str(doc.body_ids()[0])

	print("- fillets")
	var host := ctx.view.feature_of_body(body)
	var neck_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
	var neck := _neck_edges(doc, body, neck_x)
	check(neck.size() == 2, "two neck verticals (got %d)" % neck.size())
	if neck.size() == 2:
		var nf := doc.graph_add_fillet(host, neck, 10.0)
		check(nf != "", "neck R10 fillet created (%s)" % doc.last_graph_error())
	# Each fillet remints face ids, so the next face is resolved after the previous apply.
	for spec in [["top", 10.0], ["bottom", 0.0], ["slot floor", 7.5]]:
		var face := _face_at(doc, body, float(spec[1]))
		check(face != "", "%s face found at z=%.1f" % [spec[0], float(spec[1])])
		if face == "":
			continue
		var added := doc.graph_add_fillet(host, doc.edges_of_face(face), 1.0)
		check(added != "", "%s R1 fillet created (%s)" % [spec[0], doc.last_graph_error()])
	check(str(doc.graph_warnings()).find("lost on rebuild") < 0,
			"build warnings have no lost edges (%s)" % str(doc.graph_warnings()))
	return doc.body_ids().size() == 1 and neck.size() == 2


func _edit_thickness(ctx: FilmContext) -> void:
	print("- distance 10 → 14")
	var doc: SxDocument = ctx.view.doc
	var boss := _boss_extrude_id(doc)
	check(boss != "", "base extrude is on the timeline")
	if boss == "":
		return
	var params = JSON.parse_string(_params_of(doc, boss))
	check(typeof(params) == TYPE_DICTIONARY, "base extrude params parse")
	if typeof(params) != TYPE_DICTIONARY:
		return
	params["distance"] = 14.0
	var ok := doc.graph_set_params(boss, JSON.stringify(params))
	check(ok, "thickness 14 accepted (%s)" % doc.last_graph_error())
	var warns := str(doc.graph_warnings())
	check(warns.find("lost on rebuild") < 0, "T=14 rebuild has no lost fillet edges (%s)" % warns)
	var zs := _sketch_plane_zs(doc)
	var anchored := 0
	for z in zs:
		if absf(float(z) - 14.0) <= TOL:
			anchored += 1
	check(anchored >= 2, "jaw and slot sketches sit on z=14 (planes %s)" % str(zs))
	if doc.body_ids().is_empty():
		check(false, "body remains after the thickness edit")
		return
	var body := str(doc.body_ids()[0])
	var ext := _extent(doc, body)
	check(absf(ext.z - 14.0) <= TOL, "bbox Z is 14 (got %.3f)" % ext.z)
	var path := "/tmp/sx-rung01-thick-rebuild.3mf"
	var exported := doc.export_3mf_for_body(body, path)
	check(exported and FileAccess.file_exists(path), "exported T=14 3MF")
	if not exported:
		return
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_rung01.py")
	var output: Array = []
	var code := OS.execute("python3", PackedStringArray([checker, "thick", path, "14"]), output, true)
	var text := "\n".join(output)
	print(text)
	check(code == 0 and text.contains("7/7"), "check_rung01.py thick 7/7 (exit %d)" % code)


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


func _params_of(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("params", "{}"))
	return "{}"


func _sketch_plane_zs(doc: SxDocument) -> Array:
	var zs: Array = []
	for f in doc.graph_features():
		if str(f.get("type", "")) != "sketch":
			continue
		var sk: SxSketch = doc.graph_get_sketch(str(f.get("id", "")))
		if sk == null:
			continue
		var info: Dictionary = sk.plane_info()
		var origin: Vector3 = info.get("origin", Vector3.ZERO)
		zs.append(snappedf(origin.z, 0.01))
	return zs
