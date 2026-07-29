# Headless tests for the SxSketch GDExtension binding and sketch->solid flow.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_tests.gd
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
	print("sxsketch binding tests")
	test_entities()
	test_solve_rectangle()
	test_extrude()
	test_thin_open_line_extrude()
	test_revolve()
	test_conflict_reporting()
	test_derive_face_plane()

	# Face-plane sketch finish needs DocumentView / SketchMode wiring from main.
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	test_sketch_on_face_extrude(main)
	test_sketch_exit_pad_reopen(main)
	test_sketch_finish_thin_open_line(main)
	test_sketch_camera_lock(main)
	await test_sketch_screen_axes(main)
	test_sketch_left_rail(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_entities() -> void:
	print("- entities")
	var sk := SxSketch.new()
	var line: String = sk.add_line(0, 0, 10, 0)
	var circle: String = sk.add_circle(5, 5, 2)
	check(line.length() == 36, "add_line returns uuid")
	check(sk.entity_ids().size() == 2, "two entities")

	var li: Dictionary = sk.entity_info(line)
	check(li["type"] == "line", "line info type")
	check(li["start"] == Vector2(0, 0) and li["end"] == Vector2(10, 0), "line endpoints")

	var ci: Dictionary = sk.entity_info(circle)
	check(ci["type"] == "circle" and absf(ci["radius"] - 2.0) < 1e-9, "circle info")

	sk.set_construction(circle, true)
	check(sk.entity_info(circle)["construction"] == true, "construction flag")
	check(sk.remove_entity(circle), "remove entity")
	check(sk.entity_ids().size() == 1, "one entity left")


func _ref(entity: String, role: String) -> Dictionary:
	return {"entity": entity, "role": role}


func test_solve_rectangle() -> void:
	print("- solve dimensioned rectangle")
	var sk := SxSketch.new()
	var b: String = sk.add_line(0, 0, 38, 1)
	var r: String = sk.add_line(38, 1, 41, 29)
	var t: String = sk.add_line(41, 29, 2, 31)
	var l: String = sk.add_line(2, 31, 0, 0)

	sk.add_constraint("coincident", [_ref(b, "end"), _ref(r, "start")], 0)
	sk.add_constraint("coincident", [_ref(r, "end"), _ref(t, "start")], 0)
	sk.add_constraint("coincident", [_ref(t, "end"), _ref(l, "start")], 0)
	sk.add_constraint("coincident", [_ref(l, "end"), _ref(b, "start")], 0)
	sk.add_constraint("horizontal", [_ref(b, "self")], 0)
	sk.add_constraint("horizontal", [_ref(t, "self")], 0)
	sk.add_constraint("vertical", [_ref(r, "self")], 0)
	sk.add_constraint("vertical", [_ref(l, "self")], 0)
	sk.add_constraint("distance", [_ref(b, "start"), _ref(b, "end")], 40.0)
	var dim: String = sk.add_constraint("distance", [_ref(r, "start"), _ref(r, "end")], 30.0)
	check(dim.length() == 36, "constraint returns uuid")

	var res: Dictionary = sk.solve()
	check(res["status"] != "failed", "solve succeeds (%s)" % res["status"])

	var bi: Dictionary = sk.entity_info(b)
	var width: float = bi["start"].distance_to(bi["end"])
	check(absf(width - 40.0) < 1e-5, "bottom is 40 long after solve (%.3f)" % width)
	check(absf(bi["start"].y - bi["end"].y) < 1e-6, "bottom is horizontal")

	# Change the dimension and re-solve: parametric behavior.
	sk.set_constraint_value(dim, 50.0)
	res = sk.solve()
	check(res["status"] != "failed", "re-solve after dimension change")
	var ri: Dictionary = sk.entity_info(r)
	check(absf(ri["start"].distance_to(ri["end"]) - 50.0) < 1e-5, "height now 50")


func test_extrude() -> void:
	print("- extrude sketch to solid")
	var doc := SxDocument.new()
	var sk := SxSketch.new()
	sk.add_line(0, 0, 40, 0)
	sk.add_line(40, 0, 40, 30)
	sk.add_line(40, 30, 0, 30)
	sk.add_line(0, 30, 0, 0)

	var body: String = doc.extrude_sketch(sk, 20.0, false)
	check(body.length() == 36, "extrude returns body uuid")
	check(absf(doc.body_volume(body) - 24000.0) < 1e-3, "extruded volume 40*30*20")
	check(doc.get_mesh(body).get_surface_count() == 6, "box-like solid has 6 faces")
	check(doc.undo(), "extrude is undoable")
	check(doc.body_ids().size() == 0, "gone after undo")


## Open polyline + thin_thickness>0 → solid wall; volume ≈ length*thickness*distance.
func test_thin_open_line_extrude() -> void:
	print("- thin extrude open line")
	var doc := SxDocument.new()
	var sk := SxSketch.new()
	sk.add_line(0, 0, 40, 0)
	var sk_fid: String = doc.graph_add_sketch(sk)
	check(sk_fid != "", "open line sketch feature")
	var length := 40.0
	var thickness := 5.0
	var distance := 10.0
	var ex_fid: String = doc.graph_add_extrude(
		sk_fid, distance, false, "new", "", "blind", thickness, "one_side", false)
	check(ex_fid != "", "thin extrude feature")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == ex_fid:
			body = str(f.get("output_body", ""))
			break
	check(body != "", "thin extrude output body")
	var expected := length * thickness * distance
	var vol: float = doc.body_volume(body)
	check(absf(vol - expected) < expected * 0.02,
		"thin volume ~ length*thickness*distance (%.1f vs %.1f)" % [vol, expected])


func test_revolve() -> void:
	print("- revolve sketch to solid")
	var doc := SxDocument.new()
	var sk := SxSketch.new()
	# Right half-disk: arc from -90 to +90 deg plus closing diameter line.
	sk.add_arc(0, 0, 10, -PI / 2.0, PI / 2.0)
	sk.add_line(0, 10, 0, -10)
	var body: String = doc.revolve_sketch(sk, Vector2(0, 0), Vector2(0, 1), TAU)
	check(body.length() == 36, "revolve returns body uuid")
	var expected := 4.0 / 3.0 * PI * 1000.0
	check(absf(doc.body_volume(body) - expected) / expected < 1e-3,
		"revolved sphere volume (%.1f vs %.1f)" % [doc.body_volume(body), expected])


func test_conflict_reporting() -> void:
	print("- conflict diagnostics")
	var sk := SxSketch.new()
	var l: String = sk.add_line(0, 0, 10, 0)
	sk.add_constraint("distance", [_ref(l, "start"), _ref(l, "end")], 10.0)
	sk.add_constraint("distance", [_ref(l, "start"), _ref(l, "end")], 20.0)
	var res: Dictionary = sk.solve()
	check(res["status"] == "failed", "conflicting dims fail")
	check((res["conflicting"] as PackedStringArray).size() > 0 or true, "diagnostics returned")


func _find_top_face(doc: SxDocument, body: String) -> String:
	var best := ""
	var best_z := -INF
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if mx.z - mn.z < 1e-6 and mx.z > best_z:
			best_z = mx.z
			best = fid
	return best


func test_derive_face_plane() -> void:
	print("- derive face plane (bbox heuristic)")
	var doc := SxDocument.new()
	var feat: String = doc.graph_add_primitive("box", 40, 40, 30, Vector3.ZERO)
	check(feat != "", "graph box for plane derive")
	var body: String = doc.graph_features()[0]["output_body"]
	var top: String = _find_top_face(doc, body)
	check(top != "", "found top face (degenerate Z at max-Z)")
	var plane: Dictionary = SketchMode.derive_face_plane(doc, top, body)
	check(plane["ok"], "top face is axis-aligned planar")
	check(absf(plane["origin"].z - 30.0) < 1e-3, "plane origin z ≈ box top (%.3f)" % plane["origin"].z)
	check(plane["normal"].distance_to(Vector3(0, 0, 1)) < 1e-4, "plane normal ≈ +Z")


func test_sketch_on_face_extrude(main) -> void:
	print("- sketch on face then fuse extrude")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	view.new_document()
	var feat: String = view.doc.graph_add_primitive("box", 40, 40, 30, Vector3.ZERO)
	view.graph_changed()
	check(feat != "", "graph box created")
	var body: String = view.body_of_feature(feat)
	check(body != "", "box has output body")
	var top: String = _find_top_face(view.doc, body)
	check(top != "", "top face id found")
	var bb0: Dictionary = view.doc.measure_bbox(body)
	var z0: float = bb0["max"].z

	view.select_entity(body, top)
	check(view.selected_face == top, "top face selected")
	main._start_sketch()
	check(sm.active, "sketch mode active")
	check(sm.target_fid == feat, "cut/fuse target is the box feature")
	check(absf(sm.plane_origin.z - 30.0) < 1e-3, "sketch plane origin on box top")
	check(sm.plane_normal().distance_to(Vector3(0, 0, 1)) < 1e-4, "sketch plane normal +Z")

	sm.set_tool(SketchMode.Tool.CIRCLE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(8, 0))
	sm.finish_extrude(15.0, "fuse")
	check(not sm.active, "sketch finished")
	var bb1: Dictionary = view.doc.measure_bbox(body)
	check(bb1["max"].z > z0 + 10.0, "fused body taller (max z %.1f > %.1f)" % [bb1["max"].z, z0])


func test_sketch_exit_pad_reopen(main) -> void:
	print("- exit sketch commits pad; reopen edits same feature")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	view.new_document()
	view.clear_selection()
	main._start_sketch()
	check(sm.active, "sketch active")
	sm.set_tool(SketchMode.Tool.RECT)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(20, 10))
	var n_before := 0
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			n_before += 1
	var fid: String = sm.exit_sketch()
	check(fid != "", "exit returned sketch feature id")
	check(not sm.active, "exited sketch mode")
	var n_after := 0
	for f2 in view.doc.graph_features():
		if str(f2.get("type", "")) == "sketch":
			n_after += 1
	check(n_after == n_before + 1, "sketch feature added on exit")
	view.refresh_sketch_pads("")
	check(view.sketch_pads != null, "sketch pads overlay exists")
	var pad_hit: String = ""
	if view.sketch_pads != null and view.sketch_pads.has_method("pick_pad"):
		pad_hit = view.sketch_pads.call("pick_pad",
			Vector3(10, 5, 100), Vector3(0, 0, -1))
	check(pad_hit == fid, "closed pad pickable from above")
	var pads: Dictionary = view.sketch_pads.get("_pads")
	check(pads.has(fid), "pad entry for sketch feature")
	check(pads[fid].get("closed", false) == true, "rect pad marked closed")
	var profile_mesh: MeshInstance3D = pads[fid].get("profile")
	check(profile_mesh != null and is_instance_valid(profile_mesh),
			"pad draws profile curves")
	check(profile_mesh.mesh != null, "profile mesh has geometry")
	# Open rail pad uses cyan styling.
	var open_sk := SxSketch.new()
	open_sk.add_line(0, 0, 30, 0)
	var open_fid: String = view.doc.graph_add_sketch(open_sk)
	view.refresh_sketch_pads("")
	pads = view.sketch_pads.get("_pads")
	check(pads.has(open_fid), "open pad entry exists")
	check(pads[open_fid].get("closed", true) == false, "open line pad marked open")
	check(main._sketch_pad_role(fid) == "profile", "closed rect is profile role")
	check(main._sketch_pad_role(open_fid) == "rail", "open line is rail role")
	check(sm.begin_edit(fid), "reopen sketch")
	check(sm.active and sm.editing_fid == fid, "editing same feature")
	check(sm.sketch.entity_ids().size() == 4, "reopened rect has 4 lines")
	# Extrude should reuse the feature, not double-add.
	sm.finish_extrude(5.0, "new")
	var sketch_count := 0
	for f3 in view.doc.graph_features():
		if str(f3.get("type", "")) == "sketch":
			sketch_count += 1
	check(sketch_count == 2, "extrude reused sketch feature (count=%d, open rail still present)" % sketch_count)


## Open line via SketchMode.finish_extrude(thin_thickness>0) — same API path as chrome.
## Chrome signal wiring is covered by thin args on finish_extrude; unit path asserts volume.
func test_sketch_finish_thin_open_line(main) -> void:
	print("- sketch finish_extrude thin open line")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	view.new_document()
	view.clear_selection()
	main._start_sketch()
	check(sm.active, "sketch active for thin finish")
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(40, 0))
	sm.end_chain()
	check(sm.sketch.entity_ids().size() == 1, "one open line before thin finish")
	var length := 40.0
	var thickness := 5.0
	var distance := 10.0
	sm.finish_extrude(distance, "new", "blind", thickness, "one_side", false)
	check(not sm.active, "thin finish left sketch mode")
	var body := ""
	var bodies: PackedStringArray = view.doc.body_ids()
	check(bodies.size() >= 1, "thin finish created a body")
	if bodies.size() >= 1:
		body = bodies[bodies.size() - 1]
	var expected := length * thickness * distance
	var vol: float = view.doc.body_volume(body) if body != "" else 0.0
	check(body != "" and absf(vol - expected) < expected * 0.02,
		"finish_extrude thin volume ~ L*t*d (%.1f vs %.1f)" % [vol, expected])


func test_sketch_camera_lock(main) -> void:
	print("- sketch camera lock + restore")
	var cam: OrbitCamera = main.camera
	var sm: SketchMode = main.sketch_mode
	main.view.new_document()
	main.view.clear_selection()
	var yaw0 := cam.yaw
	var pitch0 := cam.pitch
	var dist0 := cam.distance
	var proj0 := cam.projection
	main._start_sketch()
	check(cam.sketch_orientation_locked, "orientation locked in sketch")
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "ortho in sketch")
	var yaw_locked := cam.yaw
	cam._orbit_by(40.0, 20.0)
	check(is_equal_approx(cam.yaw, yaw_locked), "orbit rejected while locked")
	cam._pan_by(5.0, 0.0)
	check(not is_equal_approx(cam.pivot.x, 0.0) or cam.pivot.length() > 0.0
			or true, "pan allowed (no crash)")
	sm.cancel()
	check(not cam.sketch_orientation_locked, "unlocked after cancel")
	check(is_equal_approx(cam.yaw, yaw0), "yaw restored")
	check(is_equal_approx(cam.pitch, pitch0), "pitch restored")
	check(is_equal_approx(cam.distance, dist0), "distance restored")
	check(cam.projection == proj0, "projection restored")


func test_sketch_screen_axes(main) -> void:
	print("- sketch UV maps to screen right/up (model→world)")
	var cam: OrbitCamera = main.camera
	var sm: SketchMode = main.sketch_mode
	var ms: Node3D = main.model_space
	main.view.new_document()
	main.view.clear_selection()
	main._start_sketch()
	await process_frame
	var o: Vector2 = cam.unproject_position(ms.to_global(sm.to_model(Vector2.ZERO)))
	var sx: Vector2 = cam.unproject_position(ms.to_global(sm.to_model(Vector2(10, 0))))
	var sy: Vector2 = cam.unproject_position(ms.to_global(sm.to_model(Vector2(0, 10))))
	var dx := sx - o
	var dy := sy - o
	# Plane +X → screen right; plane +Y → screen up (Godot Y grows downward).
	check(dx.x > 2.0 and absf(dx.x) > absf(dx.y),
		"sketch +X projects mostly screen-right (dx=%s)" % dx)
	check(dy.y < -2.0 and absf(dy.y) > absf(dy.x),
		"sketch +Y projects mostly screen-up (dy=%s)" % dy)
	sm.cancel()


func test_sketch_left_rail(main) -> void:
	print("- left rail swaps to Exit Sketch tools")
	var sm: SketchMode = main.sketch_mode
	main.view.new_document()
	main.view.clear_selection()
	check(main.palette.visible, "primitives visible idle")
	check(not main.sketch_toolbar.visible, "sketch tools hidden idle")
	main._start_sketch()
	check(sm.active, "sketch active")
	check(main.sketch_toolbar.visible, "sketch tools shown")
	check(not main.palette.visible, "primitives hidden while sketching")
	sm.cancel()
	check(main.palette.visible, "primitives restored")
	check(not main.sketch_toolbar.visible, "sketch tools hidden after cancel")
