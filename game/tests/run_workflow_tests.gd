# Common-workflow tests: build canonical parts end-to-end the way a user
# would (palette, selection, ops panel, sketch mode), assert on resulting
# geometry, and count the user gestures each part needs. Gesture ceilings are
# generous — they catch regressions without over-optimizing for these parts.
# UI gaps (steps impossible without direct doc calls) are recorded per part.
# Run: tools/godot/godot --headless --path game --script tests/run_workflow_tests.gd
extends SceneTree

var failures := 0
var checks := 0

var _gestures := 0
var _gaps: Array[String] = []
var _report: Array = []

var main
var view: DocumentView
var ops: OpsPanel
var sk: SketchMode


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


# n = user gestures this step would take (clicks, key presses, drags).
func gesture(n: int) -> void:
	_gestures += n


func gap(what: String) -> void:
	_gaps.append(what)


func begin_workflow(name: String) -> void:
	print("- " + name)
	_gestures = 0
	_gaps = []
	view.new_document()


func end_workflow(name: String, ceiling: int) -> void:
	check(_gestures <= ceiling, "%s within gesture ceiling (%d <= %d)" % [name, _gestures, ceiling])
	_report.append({"name": name, "gestures": _gestures, "ceiling": ceiling, "gaps": _gaps.duplicate()})


func _init() -> void:
	print("workflow tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	view = main.view
	ops = main.ops_panel
	sk = main.sketch_mode

	workflow_chamfered_plate()
	workflow_hole_corner_inset()
	workflow_mounting_block()
	workflow_bracket()
	workflow_hollow_box()
	workflow_washer()
	workflow_flanged_cylinder()
	workflow_funnel()
	workflow_bolt_blank()
	workflow_spring()
	workflow_pipe_elbow()
	workflow_ribbed_plate()
	workflow_bearing_block()
	workflow_pin_and_plate_instance()

	print("\ngesture audit:")
	for r in _report:
		var gaps_txt: String = "" if r["gaps"].is_empty() else "  GAPS: " + ", ".join(r["gaps"])
		print("  %-28s %2d / ceiling %2d%s" % [r["name"], r["gestures"], r["ceiling"], gaps_txt])

	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _volume(body: String) -> float:
	return view.doc.body_volume(body)


func _only_body() -> String:
	var ids: PackedStringArray = view.doc.body_ids()
	return ids[0] if ids.size() == 1 else ""


## 1. Chamfered plate with holes at the 4 corners.
func workflow_chamfered_plate() -> void:
	begin_workflow("chamfered plate, 4 corner holes")
	# Plate 100 x 80 x 10. Place HUD can size at insert; this suite still seeds via graph.
	var fid: String = view.doc.graph_add_primitive("box", 100, 80, 10, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	var body := view.body_of_feature(fid)
	check(body != "", "plate created")
	check(absf(_volume(body) - 80000.0) < 1.0, "plate volume 80000")

	# Chamfer the 4 vertical edges (all-edges chamfer is flaky on snapshot re-exec).
	var vert_edges: Array[String] = []
	for eid in view.doc.get_edge_ids(body):
		var bb: Dictionary = view.doc.measure_bbox(eid)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if absf(mx.z - mn.z) > 5.0 and absf(mx.x - mn.x) < 0.2 and absf(mx.y - mn.y) < 0.2:
			vert_edges.append(eid)
	check(vert_edges.size() >= 4, "found vertical edges (%d)" % vert_edges.size())
	view.select_entity(body, "")
	view.selected_edges.assign(vert_edges.slice(0, 4))
	view.selected_edge = vert_edges[0]
	gesture(1)
	ops._radius_spin.value = 2.0
	gesture(1)
	ops._chamfer_all()
	gesture(1)
	var vol_chamfer := _volume(body)
	check(vol_chamfer > 76000.0 and vol_chamfer < 80000.0,
		"chamfer removed material (vol %.0f)" % vol_chamfer)

	# 4 corner holes via Place-hole commit path (magnet-friendly positions).
	var top_face := ""
	for face_id in view.doc.get_face_ids(body):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 10.0) < 0.5:
			top_face = face_id
			break
	check(top_face != "", "top face found")
	view.select_entity(body, top_face)
	gesture(1)
	ops._hole_diameter.value = 6.0
	ops._hole_depth.value = 12.0
	gesture(1)
	var hole_positions := [Vector3(15, 15, 10), Vector3(85, 15, 10), Vector3(15, 65, 10), Vector3(85, 65, 10)]
	for pos in hole_positions:
		check(ops._commit_hole(body, top_face, pos), "hole at %s" % str(pos))
		gesture(2)  # Place hole… + click
	# Wave 6.2: hole Ø = nominal + hole_compensation (default 0.2) → Ø6.2
	var d := 6.0 + 0.2
	var expected_drop := 4.0 * PI * (0.5 * d) * (0.5 * d) * 10.0
	var drop := vol_chamfer - _volume(body)
	check(absf(drop - expected_drop) < expected_drop * 0.05,
		"holes removed ~%.0f mm^3 (got %.0f)" % [expected_drop, drop])
	end_workflow("chamfered plate", 16)


## 1b. Place hole… near a corner insets by inferred edge distance (not on the vertex).
func workflow_hole_corner_inset() -> void:
	begin_workflow("hole corner inset from Ø/thickness/material")
	check(OpsPanel.material_softness("TPU") > OpsPanel.material_softness("Tool Steel"),
		"TPU softer than tool steel")
	var soft_thick := OpsPanel.suggested_hole_inset(6.0, 30.0, "TPU")
	var hard_thin := OpsPanel.suggested_hole_inset(6.0, 5.0, "Tool Steel")
	var big_hole := OpsPanel.suggested_hole_inset(12.0, 10.0, "PLA")
	var small_hole := OpsPanel.suggested_hole_inset(4.0, 10.0, "PLA")
	check(soft_thick > hard_thin + 1.0,
		"soft+thick inset %.1f > hard+thin %.1f" % [soft_thick, hard_thin])
	check(big_hole > small_hole,
		"bigger Ø insets more (%.1f > %.1f)" % [big_hole, small_hole])

	var fid: String = view.doc.graph_add_primitive("box", 100, 80, 10, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	var body := view.body_of_feature(fid)
	check(body != "", "plate created")
	var top_face := ""
	for face_id in view.doc.get_face_ids(body):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 10.0) < 0.5:
			top_face = face_id
			break
	check(top_face != "", "top face found")
	view.select_entity(body, top_face)
	gesture(1)
	ops._hole_inset_manual = false
	ops._hole_diameter.value = 6.0
	ops._sync_hole_inset_default()
	gesture(1)
	var inset: float = ops._hole_inset.value
	check(inset >= 6.0 and inset <= 14.0, "default inset sensible (%.1f)" % inset)

	# Near-corner click → inset from both edges; far click stays free.
	var placed: Vector3 = ops._hole_place_position(body, top_face, Vector3(2, 2, 10))
	check(absf(placed.x - inset) < 0.75 and absf(placed.y - inset) < 0.75,
		"corner snap insets to (%.1f,%.1f) want ~%.1f" % [placed.x, placed.y, inset])
	var free_pt: Vector3 = ops._hole_place_position(body, top_face, Vector3(40, 40, 10))
	check(free_pt.distance_to(Vector3(40, 40, 10)) < 0.5,
		"far click places freely at (40,40)")
	check(ops._commit_hole(body, top_face, placed), "inset hole committed")
	gesture(2)
	end_workflow("hole corner inset", 6)


## 1c. Mounting block 100×60×30 + Ø20 center through-hole (study howto).
## Reports click-path vs keyboard-path gesture counts against dual ceilings.
func workflow_mounting_block() -> void:
	var expected_vol := 180000.0 - PI * 100.0 * 30.0
	var click_gestures := 0
	var kb_gestures := 0

	# --- Click path: Box + size fields + place + face + Ø + Apply hole button ---
	begin_workflow("mounting block (click)")
	var fid: String = view.doc.graph_add_primitive("box", 100, 60, 30, Vector3.ZERO)
	view.graph_changed()
	gesture(1)  # Box palette
	gesture(3)  # size W/H/D fields
	gesture(1)  # click ground
	var body := view.body_of_feature(fid)
	check(body != "", "click path: box body")
	var top_face := _top_face_at_z(body, 30.0)
	check(top_face != "", "click path: top face")
	view.select_entity(body, top_face)
	gesture(2)  # body then face (or re-click to refine to face)
	ops._hole_diameter.value = 20.0
	ops._hole_depth.value = 0.0
	gesture(1)  # set Ø (Depth left at 0 = through)
	ops._apply_hole()
	gesture(1)  # Apply hole button / strip Hole
	check(absf(_volume(body) - expected_vol) < expected_vol * 0.02,
		"click path volume ~%.0f (got %.0f)" % [expected_vol, _volume(body)])
	click_gestures = _gestures
	end_workflow("mounting block (click)", 10)

	# --- Keyboard path: same place; type Ø; O applies hole ---
	begin_workflow("mounting block (keyboard)")
	fid = view.doc.graph_add_primitive("box", 100, 60, 30, Vector3.ZERO)
	view.graph_changed()
	gesture(1)  # Box
	gesture(3)  # type three size values
	gesture(1)  # place
	body = view.body_of_feature(fid)
	check(body != "", "kb path: box body")
	top_face = _top_face_at_z(body, 30.0)
	check(top_face != "", "kb path: top face")
	view.select_entity(body, top_face)
	gesture(1)  # refine to face (body already selected after place)
	ops._hole_diameter.value = 20.0
	ops._hole_depth.value = 0.0
	gesture(1)  # type Ø + Enter (Depth stays 0)
	var key := InputEventKey.new()
	key.keycode = KEY_O
	key.pressed = true
	check(main.interaction._gui_key(key), "kb path: O applies hole")
	gesture(1)  # O
	check(absf(_volume(body) - expected_vol) < expected_vol * 0.02,
		"kb path volume ~%.0f (got %.0f)" % [expected_vol, _volume(body)])
	kb_gestures = _gestures
	end_workflow("mounting block (keyboard)", 8)

	print("  mounting block click %d / kb %d / ceilings 10,8" % [click_gestures, kb_gestures])
	check(kb_gestures <= click_gestures,
		"keyboard path ≤ click path (%d <= %d)" % [kb_gestures, click_gestures])


func _top_face_at_z(body: String, z: float) -> String:
	for face_id in view.doc.get_face_ids(body):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - z) < 0.5:
			return face_id
	return ""


## 2. L-bracket: sketch profile, extrude, fillet the inner vertical edge.
func workflow_bracket() -> void:
	begin_workflow("L-bracket with inner fillet")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	gesture(1)
	sk.set_tool(SketchMode.Tool.LINE)
	gesture(1)
	for p in [Vector2(0, 0), Vector2(60, 0), Vector2(60, 20), Vector2(20, 20),
			Vector2(20, 50), Vector2(0, 50), Vector2(0, 0)]:
		sk.click(p)
	gesture(7)
	sk.end_chain()
	gesture(1)
	sk.finish_extrude(30.0, "new")
	gesture(2)  # distance + button
	var body := _only_body()
	check(body != "", "bracket body created")
	check(absf(_volume(body) - 54000.0) < 540.0, "L volume ~54000 (got %.0f)" % _volume(body))

	# Find the concave inner vertical edge at (20, 20): bbox is a point column.
	var inner := ""
	for eid in view.doc.get_edge_ids(body):
		var bb: Dictionary = view.doc.measure_bbox(eid)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if mn.distance_to(Vector3(20, 20, 0)) < 0.5 and mx.distance_to(Vector3(20, 20, 30)) < 0.5:
			inner = eid
			break
	check(inner != "", "inner vertical edge found")
	view.select_edge(body, inner)
	gesture(2)  # click body, click edge
	ops._radius_spin.value = 3.0
	gesture(1)
	ops._fillet_all()  # selected edge only
	gesture(1)
	# Concave fillet ADDS material: (r^2 - pi r^2/4) * L
	var added := (9.0 - PI * 9.0 / 4.0) * 30.0
	check(absf(_volume(body) - (54000.0 + added)) < 60.0,
		"inner fillet added ~%.0f mm^3 (vol %.0f)" % [added, _volume(body)])
	end_workflow("L-bracket", 20)


## 3. Hollow box: shell a cube through its top face.
func workflow_hollow_box() -> void:
	begin_workflow("hollow box (shell)")
	view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 50))
	gesture(2)
	var body := _only_body()
	check(body != "", "box created")
	# Box is selected after insert; one more click from above refines to top face.
	view.select_ray(Vector3(0, 0, 200), Vector3(0, 0, -1))
	gesture(1)
	check(view.selected_face != "", "top face selected")
	ops._thickness_spin.value = 2.0
	gesture(1)
	ops._shell()
	gesture(1)
	# 50^3 with 2mm walls, open top: outer - inner(46 x 46 x 48).
	var expected := 125000.0 - 46.0 * 46.0 * 48.0
	check(absf(_volume(body) - expected) < expected * 0.05,
		"shelled volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("hollow box", 8)


## 4. Washer: revolve a rectangle offset from the sketch Y axis.
func workflow_washer() -> void:
	begin_workflow("washer (revolve)")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	gesture(1)
	sk.set_tool(SketchMode.Tool.RECT)
	gesture(1)
	# Snap off: at this small scale the axis-snap would collapse the rect.
	sk.set_snap(false)
	sk.click(Vector2(10, 0))
	sk.click(Vector2(14, 4))
	sk.set_snap(true)
	gesture(2)
	sk.finish_revolve(TAU, "new")
	gesture(1)
	var body := _only_body()
	check(body != "", "washer body created")
	var expected := PI * (14.0 * 14.0 - 10.0 * 10.0) * 4.0
	check(absf(_volume(body) - expected) < expected * 0.02,
		"washer volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("washer", 8)


## 5. Flanged cylinder: shaft + flange disc fused via the armed boolean flow.
func workflow_flanged_cylinder() -> void:
	begin_workflow("flanged cylinder (fuse)")
	view.insert_primitive("cylinder", Vector3.ZERO, Vector3(50, 50, 50))  # r25 h50
	gesture(2)
	var shaft := _only_body()
	check(shaft != "", "shaft created")
	var ffid: String = view.doc.graph_add_primitive("cylinder", 40, 10, 0, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("flange radius not settable at insert (needs property panel)")
	var flange := view.body_of_feature(ffid)
	check(flange != "", "flange created")

	view.select_entity(shaft, "")
	gesture(1)
	ops._arm_boolean("fuse")
	gesture(1)
	view.select_entity(flange, "")  # armed flow consumes this click
	gesture(1)
	check(view.doc.body_ids().size() == 1, "fuse consumed the tool body")
	var expected := PI * 625.0 * 50.0 + PI * 1600.0 * 10.0 - PI * 625.0 * 10.0
	check(absf(_volume(shaft) - expected) < expected * 0.02,
		"fused volume ~%.0f (got %.0f)" % [expected, _volume(shaft)])
	end_workflow("flanged cylinder", 10)


## 6. Funnel: loft between two circles on parallel planes.
func workflow_funnel() -> void:
	begin_workflow("funnel (loft)")
	var bottom := SxSketch.new()
	bottom.add_circle(0, 0, 30.0)
	var bfid: String = view.doc.graph_add_sketch(bottom)
	gesture(4)  # ideal: sketch + tool + 2 clicks
	var top := SxSketch.new()
	top.set_plane(Vector3(0, 0, 60), Vector3(1, 0, 0), Vector3(0, 1, 0))
	top.add_circle(0, 0, 8.0)
	var tfid: String = view.doc.graph_add_sketch(top)
	gesture(5)  # ideal: plane pick + sketch + tool + 2 clicks
	var lfid: String = view.doc.graph_add_loft(PackedStringArray([bfid, tfid]), true)
	view.graph_changed()
	gesture(1)
	check(lfid != "", "loft feature created")
	var body := view.body_of_feature(lfid)
	check(body != "", "loft body exists")
	# Cone frustum: pi h/3 (R^2 + R r + r^2)
	var expected := PI * 60.0 / 3.0 * (900.0 + 240.0 + 64.0)
	check(absf(_volume(body) - expected) < expected * 0.03,
		"funnel volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("funnel", 12)


func _uuid4() -> String:
	var b := PackedByteArray()
	b.resize(16)
	for i in 16:
		b[i] = randi() % 256
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## Write a minimal .sxp whose timeline is a single helix_sweep feature (no BREP
## bodies). Caller must graph_regenerate() after load to materialize geometry.
## Needed because SxDocument has no graph_add_helix binding yet.
func _write_helix_sxp(path: String, profile_r: float, radius: float, pitch: float,
		turns: float) -> void:
	var fid := _uuid4()
	var bid := _uuid4()
	var features := {
		"variables": {},
		"timeline": [{
			"id": fid,
			"name": "Spring",
			"type": "helix_sweep",
			"suppressed": false,
			"params": {
				"profile_radius": profile_r,
				"axis_point": [0.0, 0.0, 0.0],
				"axis_dir": [0.0, 0.0, 1.0],
				"radius": radius,
				"pitch": pitch,
				"turns": turns,
				"left_handed": false,
			},
			"output_body": bid,
		}],
	}
	var manifest := {"format": "sxp", "version": 1, "bodies": []}
	var z := ZIPPacker.new()
	check(z.open(path) == OK, "helix sxp zip opened")
	z.start_file("manifest.json")
	z.write_file(JSON.stringify(manifest, "\t").to_utf8_buffer())
	z.close_file()
	z.start_file("features.json")
	z.write_file(JSON.stringify(features, "\t").to_utf8_buffer())
	z.close_file()
	z.start_file("datums.json")
	z.write_file(JSON.stringify({"planes": [], "axes": [], "points": []}).to_utf8_buffer())
	z.close_file()
	z.start_file("instances.json")
	z.write_file("[]".to_utf8_buffer())
	z.close_file()
	z.close()


## 7. Bolt blank: cylinder shaft + hex head fused.
func workflow_bolt_blank() -> void:
	begin_workflow("bolt blank (shaft + hex head)")
	var sfid: String = view.doc.graph_add_primitive("cylinder", 5, 30, 0, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("primitive dimensions not settable at insert (needs property panel)")
	var shaft := view.body_of_feature(sfid)
	check(shaft != "", "shaft created")

	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	gesture(1)
	sk.polygon_sides = 6
	gesture(1)
	sk.set_tool(SketchMode.Tool.POLYGON)
	gesture(1)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(8, 0))
	gesture(2)
	sk.finish_extrude(6.0, "new")
	gesture(2)
	var head := ""
	for id in view.doc.body_ids():
		if id != shaft:
			head = id
			break
	check(head != "", "hex head body created")

	view.select_entity(shaft, "")
	gesture(1)
	ops._arm_boolean("fuse")
	gesture(1)
	view.select_entity(head, "")
	gesture(1)
	check(view.doc.body_ids().size() == 1, "fuse consumed the hex head")
	# hex area = 3*sqrt(3)/2 * R^2 with R=8; overlap = shaft through head height.
	var hex_area := 3.0 * sqrt(3.0) / 2.0 * 64.0
	var expected := PI * 25.0 * 30.0 + hex_area * 6.0 - PI * 25.0 * 6.0
	check(absf(_volume(shaft) - expected) < expected * 0.03,
		"bolt fused volume ~%.0f (got %.0f)" % [expected, _volume(shaft)])
	end_workflow("bolt blank", 16)


## 8. Spring: helix_sweep profile r=2, helix r=15, pitch=8, 5 turns.
func workflow_spring() -> void:
	begin_workflow("spring (helix sweep)")
	check(view.doc.has_method("graph_add_helix"), "graph_add_helix binding present")
	var hfid: String = view.doc.graph_add_helix(2.0, 15.0, 8.0, 5.0, false,
			Vector3.ZERO, Vector3(0, 0, 1))
	check(hfid != "", "helix feature created")
	view.graph_changed()
	gesture(2)  # Insert → Helix Spring
	var body := view.body_of_feature(hfid)
	check(body != "", "spring body created")
	# Tube volume along helix length: (pi r^2) * turns * sqrt((2 pi R)^2 + pitch^2)
	var expected := (PI * 4.0) * (5.0 * sqrt(pow(2.0 * PI * 15.0, 2.0) + 8.0 * 8.0))
	check(absf(_volume(body) - expected) < expected * 0.10,
		"spring volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("spring", 8)


## 9. Pipe elbow: circle swept along an L-path via Path feature.
func workflow_pipe_elbow() -> void:
	begin_workflow("pipe elbow (sweep)")
	# Rails as two open sketches → Path → profile sweep (UI path covered by
	# run_sketch_to_3d_ui_tests.gd; this workflow asserts the associative Path API).
	var rail_a := SxSketch.new()
	rail_a.add_line(0, 0, 0, 40)
	var fa: String = view.doc.graph_add_sketch(rail_a)
	gesture(4)
	var rail_b := SxSketch.new()
	rail_b.add_line(0, 40, 30, 40)
	var fb: String = view.doc.graph_add_sketch(rail_b)
	gesture(3)
	var path_fid: String = view.doc.graph_add_path(PackedStringArray([fa, fb]), "join_endpoints")
	view.graph_changed()
	gesture(2)
	check(path_fid != "", "path feature from merged rails")

	var profile := SxSketch.new()
	profile.add_circle(0, 0, 5.0)
	var sk_fid: String = view.doc.graph_add_sketch(profile)
	gesture(3)
	var sw_fid: String = view.doc.graph_add_sweep_along_path(sk_fid, path_fid)
	view.graph_changed()
	gesture(1)
	check(sw_fid != "", "sweep along path feature created")
	var body := view.body_of_feature(sw_fid)
	check(body != "", "elbow body exists")
	var expected := PI * 25.0 * 70.0
	check(absf(_volume(body) - expected) < expected * 0.15,
		"elbow volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("pipe elbow", 13)


## 10. Ribbed plate: plate + single rib fused.
func workflow_ribbed_plate() -> void:
	begin_workflow("ribbed plate")
	var pfid: String = view.doc.graph_add_primitive("box", 80, 60, 6, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("primitive dimensions not settable at insert (needs property panel)")
	var plate := view.body_of_feature(pfid)
	check(plate != "", "plate created")
	var rfid: String = view.doc.graph_add_primitive("box", 4, 60, 18, Vector3(38, 0, 0))
	view.graph_changed()
	gesture(2)
	gap("rib dimensions/position not settable at insert (needs property panel)")
	var rib := view.body_of_feature(rfid)
	check(rib != "", "rib created")

	view.select_entity(plate, "")
	gesture(1)
	ops._arm_boolean("fuse")
	gesture(1)
	view.select_entity(rib, "")
	gesture(1)
	check(view.doc.body_ids().size() == 1, "fuse consumed the rib")
	# Plate 80*60*6; rib above plate top adds 4*60*12 (overlap 4*60*6).
	var expected := 80.0 * 60.0 * 6.0 + 4.0 * 60.0 * 12.0
	check(absf(_volume(plate) - expected) < expected * 0.01,
		"ribbed volume ~%.0f (got %.0f)" % [expected, _volume(plate)])
	end_workflow("ribbed plate", 10)


## 11. Bearing block: box with counterbore through-hole from top face center.
func workflow_bearing_block() -> void:
	begin_workflow("bearing block (counterbore)")
	var bfid: String = view.doc.graph_add_primitive("box", 60, 40, 30, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("primitive dimensions not settable at insert (needs property panel)")
	var body := view.body_of_feature(bfid)
	check(body != "", "block created")
	var vol0 := _volume(body)

	# Box spans 0..60, 0..40, 0..30 — top-face center is (30, 20, 30).
	view.select_ray(Vector3(30, 20, 200), Vector3(0, 0, -1))
	gesture(1)
	view.select_ray(Vector3(30, 20, 200), Vector3(0, 0, -1))
	gesture(1)
	check(view.selected_face != "", "top face selected")
	ops._hole_type.selected = 1  # Counterbore
	gesture(1)
	ops._hole_diameter.value = 10.0
	gesture(1)
	ops._hole_depth.value = 0.0  # through
	gesture(1)
	check(ops._apply_hole(), "counterbore apply returned true")
	gesture(1)
	var drop := vol0 - _volume(body)
	var through_min := PI * 25.0 * 30.0
	check(drop >= through_min and drop <= through_min + 3000.0,
		"counterbore drop in [%.0f, %.0f] (got %.0f)" % [through_min, through_min + 3000.0, drop])
	end_workflow("bearing block", 12)


## 12. Plate + pin, with an instance of the pin at an offset.
func workflow_pin_and_plate_instance() -> void:
	begin_workflow("pin and plate instance")
	var pfid: String = view.doc.graph_add_primitive("box", 60, 60, 8, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("primitive dimensions not settable at insert (needs property panel)")
	check(view.body_of_feature(pfid) != "", "plate created")
	var pin_fid: String = view.doc.graph_add_primitive("cylinder", 4, 20, 0, Vector3(15, 15, 8))
	view.graph_changed()
	gesture(2)
	gap("pin dimensions/position not settable at insert (needs property panel)")
	var pin := view.body_of_feature(pin_fid)
	check(pin != "", "pin created")

	view.select_entity(pin, "")
	gesture(1)
	ops._inst_ox.value = 30.0
	gesture(1)
	ops._inst_oy.value = 0.0
	gesture(1)
	ops._inst_oz.value = 0.0
	gesture(1)
	ops._place_instance()
	gesture(1)
	var listed: Array = view.doc.instance_list()
	check(listed.size() == 1, "instance_list has 1")
	var iid: String = listed[0]["id"]
	check(view.instance_node(iid) != null, "instance node exists")
	end_workflow("pin and plate instance", 14)
