# Headless tests for pliers-style revolute motion: concentric mate leaves a
# rotational DOF; dragging an instance rotates about that axis; solve preserves
# the angle. Also covers instance↔instance mates and extrude Through All / Midplane.
# Run: tools/godot/godot --headless --path game --script tests/run_pliers_motion_tests.gd
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
	print("pliers motion / revolute DOF tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_revolute_axis_api(main)
	await test_revolute_drag_changes_angle(main)
	await test_instance_to_instance_mate(main)
	test_extrude_midplane_and_through_all(main)
	await test_pliers_mvp_assembly(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _cyl_face(doc: SxDocument, body: String) -> String:
	for fid in doc.get_face_ids(body):
		# Cylindrical faces have equal x/y extents and taller z (axis-aligned).
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var sx: float = absf(bb["max"].x - bb["min"].x)
		var sy: float = absf(bb["max"].y - bb["min"].y)
		var sz: float = absf(bb["max"].z - bb["min"].z)
		if absf(sx - sy) < 0.2 and sz > sx * 0.5:
			return fid
	return ""


func test_revolute_axis_api(main) -> void:
	print("- instance_revolute_axis after concentric mate")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	# Pin-in-hole with 1 mm radial clearance (hole r=5, pin r=4).
	var block: String = doc.add_box(40, 40, 40, Vector3.ZERO)
	var bore: String = doc.add_cylinder(5, 40, Vector3(20, 20, 0))
	check(doc.boolean_op(block, bore, "cut", false), "bore block")
	var pin: String = doc.add_cylinder(4, 25, Vector3(80, 0, 0))
	var iid: String = doc.add_instance(pin, Vector3(80, 0, 0), Vector3(0, 0, 1), 0.0, "Pin-1")
	var hf := _cyl_face(doc, block)
	var pf := _cyl_face(doc, pin)
	check(hf != "" and pf != "", "cylindrical faces found")
	var mid: String = doc.add_mate("concentric", "", hf, iid, pf, 1.0, false, "pin")
	check(mid != "", "concentric mate added")
	check(doc.solve_mates(), "solve concentric")
	var ax: Dictionary = doc.instance_revolute_axis(iid)
	check(bool(ax.get("ok", false)), "revolute axis ok")
	var dir: Vector3 = ax["dir"]
	check(absf(absf(dir.z) - 1.0) < 1e-3, "revolute axis along Z (dir %s)" % str(dir))
	check(not bool(doc.instance_revolute_axis("nope").get("ok", false)),
		"unknown instance has no revolute axis")


func test_revolute_drag_changes_angle(main) -> void:
	print("- revolute drag rotates instance about pin axis")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var doc: SxDocument = view.doc
	# Jaw-like block with a hole: use a box instance concentric to a ground pin.
	var pin: String = doc.add_cylinder(3, 30, Vector3.ZERO)
	var jaw: String = doc.add_box(40, 12, 8, Vector3(100, 0, 0))
	# Bore a hole through the jaw via boolean with a temp cylinder at local origin.
	var bore: String = doc.add_cylinder(3.2, 20, Vector3(100, 0, -5))
	check(doc.boolean_op(jaw, bore, "cut", false), "bore jaw hole")
	var iid: String = doc.add_instance(jaw, Vector3(50, 0, 11), Vector3(0, 0, 1), 0.0, "Jaw-1")
	var pin_face := _cyl_face(doc, pin)
	var hole_face := _cyl_face(doc, jaw)
	check(pin_face != "" and hole_face != "", "pin + hole faces")
	# Radial tolerance 0.2 mm matches hole r=3.2 vs pin r=3.
	check(doc.add_mate("concentric", "", pin_face, iid, hole_face, 0.2, false, "") != "",
		"concentric jaw to pin")
	check(doc.solve_mates(), "initial solve")
	view.refresh()
	await process_frame

	var angle0: float = float(doc.instance_list()[0]["rotation_angle_deg"])
	# Drive a revolute drag via the same path as the UI.
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	vi._drag_instance_id = iid
	vi._instance_start_xform = view.instance_node(iid).transform
	vi._revolute_active = true
	var ax: Dictionary = doc.instance_revolute_axis(iid)
	vi._revolute_axis_point = ax["point"]
	vi._revolute_axis_dir = (ax["dir"] as Vector3).normalized()
	vi._revolute_start_angle = 0.0
	vi._revolute_angle = deg_to_rad(35.0)
	var inode = view.instance_node(iid)
	inode.transform = Transform3D(
		Basis(Quaternion(vi._revolute_axis_dir, vi._revolute_angle)) * vi._instance_start_xform.basis,
		vi._rotate_point_about_axis(vi._instance_start_xform.origin,
			vi._revolute_axis_point, vi._revolute_axis_dir, vi._revolute_angle))
	var rot: Array = vi._instance_rotation_from_xform(inode.transform)
	check(doc.set_instance_transform(iid, inode.transform.origin, rot[0], rot[1]),
		"commit revolved transform")
	check(doc.solve_mates(), "solve preserves revolute")
	var angle1: float = float(doc.instance_list()[0]["rotation_angle_deg"])
	check(absf(angle1 - angle0) > 10.0,
		"angle changed after revolute (%.1f → %.1f)" % [angle0, angle1])
	vi._revolute_active = false
	vi._drag_instance_id = ""


func test_instance_to_instance_mate(main) -> void:
	print("- instance↔instance concentric mate")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := AssemblyPanel.new()
	panel.view = view
	main.add_child(panel)
	await process_frame

	# Block-with-hole instance ↔ pin instance (enclosure + 1 mm radial tolerance).
	var block: String = doc.add_box(40, 40, 20, Vector3.ZERO)
	var bore: String = doc.add_cylinder(5, 20, Vector3(20, 20, 0))
	check(doc.boolean_op(block, bore, "cut", false), "bore for instance mate")
	var pin: String = doc.add_cylinder(4, 20, Vector3(60, 0, 0))
	var ia: String = doc.add_instance(block, Vector3(0, 0, 0), Vector3(0, 0, 1), 0.0, "A-1")
	var ib: String = doc.add_instance(pin, Vector3(40, 20, 0), Vector3(0, 0, 1), 0.0, "B-1")
	view.refresh()
	panel.refresh_lists()
	var fa := _cyl_face(doc, block)
	var fb := _cyl_face(doc, pin)
	check(fa != "" and fb != "", "faces for instance mate")
	for i in panel._type_option.item_count:
		if panel._type_option.get_item_text(i) == "concentric":
			panel._type_option.select(i)
			break
	panel._offset_spin.value = 1.0
	panel._arm_mate()
	view.select_instance(ia)
	view.select_entity(block, fa)
	view.select_instance(ib)
	view.select_entity(pin, fb)
	check(doc.mate_list().size() == 1, "instance↔instance mate created")
	var m: Dictionary = doc.mate_list()[0]
	check(str(m["instance_a"]) == ia, "instance_a is first instance")
	check(str(m["instance_b"]) == ib, "instance_b is second instance")
	check(doc.solve_mates(), "instance↔instance solve")
	panel.queue_free()


func test_extrude_midplane_and_through_all(main) -> void:
	print("- extrude Midplane + Through All cut")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var sk := SxSketch.new()
	sk.set_plane(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0))
	# 20×20 square centered at origin on XY (extrude along Z via plane normal).
	sk.add_line(-10, -10, 10, -10)
	sk.add_line(10, -10, 10, 10)
	sk.add_line(10, 10, -10, 10)
	sk.add_line(-10, 10, -10, -10)
	var sk_fid: String = doc.graph_add_sketch(sk)
	check(sk_fid != "", "sketch feature")
	var mid_fid: String = doc.graph_add_extrude(sk_fid, 20.0, true, "new", "", "midplane")
	check(mid_fid != "", "midplane extrude")
	view.graph_changed()
	var body := view.body_of_feature(mid_fid)
	check(body != "", "midplane body")
	var bb: Dictionary = doc.measure_bbox(body)
	check(absf(bb["min"].z + 10.0) < 0.5 and absf(bb["max"].z - 10.0) < 0.5,
		"midplane spans ±10 in Z (got [%.1f, %.1f])" % [bb["min"].z, bb["max"].z])

	# Through-all cut: circle on top, cut through the block.
	var sk2 := SxSketch.new()
	sk2.set_plane(Vector3(0, 0, 10), Vector3(1, 0, 0), Vector3(0, 1, 0))
	sk2.add_circle(0, 0, 4.0)
	var sk2_fid: String = doc.graph_add_sketch(sk2)
	var cut_fid: String = doc.graph_add_extrude(
		sk2_fid, -5.0, false, "cut", mid_fid, "through_all")
	check(cut_fid != "", "through_all cut feature")
	view.graph_changed()
	var vol: float = doc.body_volume(body)
	var expected_drop := PI * 16.0 * 20.0
	var solid := 20.0 * 20.0 * 20.0
	check(absf(vol - (solid - expected_drop)) < expected_drop * 0.08,
		"through-all cut volume ~%.0f (got %.0f)" % [solid - expected_drop, vol])


func _planar_face_z(doc: SxDocument, body: String, z: float) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		if absf(bb["min"].z - z) < 0.2 and absf(bb["max"].z - z) < 0.2:
			return fid
	return ""


func test_pliers_mvp_assembly(main) -> void:
	print("- pliers MVP: two jaws + pin, concentric + coincident, drag angle")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var doc: SxDocument = view.doc

	var pin: String = doc.add_cylinder(3, 24, Vector3.ZERO)
	var jaw: String = doc.add_box(50, 14, 8, Vector3(120, 0, 0))
	var bore: String = doc.add_cylinder(3.2, 20, Vector3(120, 0, -5))
	check(doc.boolean_op(jaw, bore, "cut", false), "jaw bore")
	var vol0: float = doc.body_volume(jaw)

	var jaw_a: String = doc.add_instance(jaw, Vector3(30, 0, 4), Vector3(0, 0, 1), 0.0, "Jaw-A")
	var jaw_b: String = doc.add_instance(jaw, Vector3(30, 0, 4), Vector3(0, 0, 1), 25.0, "Jaw-B")
	var pin_face := _cyl_face(doc, pin)
	var hole_face := _cyl_face(doc, jaw)
	var jaw_bottom := _planar_face_z(doc, jaw, 0.0)
	var jaw_top := _planar_face_z(doc, jaw, 8.0)
	check(pin_face != "" and hole_face != "", "pin + hole faces")
	check(jaw_bottom != "" and jaw_top != "", "jaw planar faces")

	# Radial tolerance 0.2 mm (hole r=3.2 − pin r=3); axial face gap 0.5 mm so
	# the jaws do not kiss — physical hinges need clearance on both axes.
	check(doc.add_mate("concentric", "", pin_face, jaw_a, hole_face, 0.2, false, "A-pin") != "",
		"concentric Jaw-A → pin")
	check(doc.add_mate("concentric", "", pin_face, jaw_b, hole_face, 0.2, false, "B-pin") != "",
		"concentric Jaw-B → pin")
	check(doc.add_mate("plane_coincident", jaw_a, jaw_top, jaw_b, jaw_bottom, 0.5, false, "faces") != "",
		"plane_coincident Jaw-A top ↔ Jaw-B bottom (0.5 mm gap)")
	check(doc.solve_mates(), "pliers mates solve")
	view.refresh()
	await process_frame

	var ax_a: Dictionary = doc.instance_revolute_axis(jaw_a)
	var ax_b: Dictionary = doc.instance_revolute_axis(jaw_b)
	check(bool(ax_a.get("ok", false)) and bool(ax_b.get("ok", false)), "both jaws have revolute DOF")

	var angle_b0: float = 0.0
	for inst in doc.instance_list():
		if str(inst["id"]) == jaw_b:
			angle_b0 = float(inst["rotation_angle_deg"])
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	var inode = view.instance_node(jaw_b)
	check(inode != null, "Jaw-B instance node exists")
	if inode == null:
		return
	vi._drag_instance_id = jaw_b
	vi._instance_start_xform = inode.transform
	vi._revolute_active = true
	vi._revolute_axis_point = ax_b["point"]
	vi._revolute_axis_dir = (ax_b["dir"] as Vector3).normalized()
	vi._revolute_angle = deg_to_rad(40.0)
	inode.transform = Transform3D(
		Basis(Quaternion(vi._revolute_axis_dir, vi._revolute_angle)) * vi._instance_start_xform.basis,
		vi._rotate_point_about_axis(vi._instance_start_xform.origin,
			vi._revolute_axis_point, vi._revolute_axis_dir, vi._revolute_angle))
	var rot: Array = vi._instance_rotation_from_xform(inode.transform)
	check(doc.set_instance_transform(jaw_b, inode.transform.origin, rot[0], rot[1]),
		"commit Jaw-B revolute drag")
	check(doc.solve_mates(), "solve after drag")
	var angle_b1: float = angle_b0
	for inst in doc.instance_list():
		if str(inst["id"]) == jaw_b:
			angle_b1 = float(inst["rotation_angle_deg"])
	check(absf(angle_b1 - angle_b0) > 10.0,
		"Jaw-B angle changed (%.1f → %.1f)" % [angle_b0, angle_b1])
	check(absf(doc.body_volume(jaw) - vol0) < 1e-3, "jaw volume stable after motion")
	vi._revolute_active = false
	vi._drag_instance_id = ""
