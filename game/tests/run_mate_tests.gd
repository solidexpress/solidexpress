# Headless tests for assembly mate bindings: add/list/remove/solve through
# SxDocument, with the viewport picking up moved instances.
# Run: tools/godot/godot --headless --path game --script tests/run_mate_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("mate tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_plane_mate(main)
	test_bad_mate(main)
	test_drawing_export(main)

	finish()


## Face of `body` whose bbox center matches a predicate; "" when none.
func _face_where(doc: SxDocument, body: String, pred: Callable) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if not bb.is_empty() and pred.call(bb):
			return fid
	return ""


func test_plane_mate(main) -> void:
	print("- plane coincident mate stacks instance on base")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	var inst: String = doc.add_instance(block, Vector3(50, 50, 90), Vector3(0, 0, 1), 45.0, "Blk-1")
	check(inst != "", "instance placed")

	# Base top: planar face at z = 20. Block bottom: face at z = 0.
	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z) < 1e-6 and absf(bb["max"].z) < 1e-6)
	check(base_top != "", "base top face found")
	check(block_bottom != "", "block bottom face found")

	var mid: String = doc.add_mate("plane_coincident", "", base_top, inst, block_bottom, 0.0, false, "on base")
	check(mid != "", "mate added")
	check(doc.mate_list().size() == 1, "mate listed")
	check(doc.solve_mates(), "mates solve")

	# Block source spans z 0..30, so the placement's tz must equal the base
	# top plane (20) once the bottom face is mated onto it.
	var placed: Dictionary = doc.instance_list()[0]
	check(absf(placed["translation"].z - 20.0) < 1e-4,
		"instance dropped to base top (tz %.2f)" % placed["translation"].z)
	view.refresh()
	check(view.instance_node(inst) != null, "instance node rendered after solve")

	check(doc.remove_mate(mid), "mate removed")
	check(doc.mate_list().is_empty(), "mate list empty")


func test_bad_mate(main) -> void:
	print("- invalid mates rejected")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var body: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	check(doc.add_mate("plane_coincident", "", "", body, "", 0.0, false, "bad") == "",
		"body id rejected as instance_b")
	check(doc.add_mate("nonsense", "", "", "", "", 0.0, false, "bad") == "",
		"unknown type rejected")


func test_drawing_export(main) -> void:
	print("- three-view drawing SVG export")
	var view: DocumentView = main.view
	view.new_document()
	view.doc.add_box(40, 30, 20, Vector3.ZERO)
	var path := OS.get_user_data_dir() + "/drawing_test.svg"
	check(view.doc.export_drawing_svg(path, 1.0), "export succeeds")
	var svg := FileAccess.get_file_as_string(path)
	check(svg.contains("<svg"), "svg header present")
	check(svg.contains("FRONT") and svg.contains("TOP") and svg.contains("RIGHT"),
		"three labeled views")
	DirAccess.remove_absolute(path)
