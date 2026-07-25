# Phase C exit: associative Convert Entities + dangling detection.
# Run: tools/godot/godot --headless --path game --script tests/run_convert_entities_tests.gd
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
	print("convert entities tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_project_line_api(main)
	test_convert_selected_edges(main)
	test_dangling_external(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_project_line_api(main) -> void:
	print("- project_line_edge binding")
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	var id: String = sm.project_edge_line(Vector3(0, 0, 0), Vector3(30, 0, 0), "edge-test-1")
	check(id != "", "projected entity id")
	check(sm.sketch.is_external(id), "marked external")
	sm.exit_sketch()


func test_convert_selected_edges(main) -> void:
	print("- Convert tool projects selected box edges")
	var doc: SxDocument = main.view.doc
	var box_fid: String = doc.graph_add_primitive("box", 40.0, 30.0, 10.0, Vector3.ZERO)
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == box_fid:
			body = str(f.get("output_body", ""))
	if body == "":
		print("  skip convert UI — no body")
		return
	var edges: PackedStringArray = doc.get_edge_ids(body)
	check(edges.size() >= 4, "box has edges")
	main.view.select_entity(body, "")
	main.view.selected_edges.clear()
	for i in range(mini(4, edges.size())):
		main.view.selected_edges.append(edges[i])
	main._start_sketch()
	var sm: SketchMode = main.sketch_mode
	var n: int = sm.convert_selected_edges()
	check(n >= 1, "converted at least one edge")
	sm.exit_sketch()


func test_dangling_external(main) -> void:
	print("- mark dangling when edge ids disappear")
	var sk := SxSketch.new()
	var id: String = sk.project_line_edge(Vector3(0, 0, 0), Vector3(10, 0, 0), "gone-edge")
	check(sk.is_external(id), "external before dangling")
	var n: int = sk.mark_dangling_external(PackedStringArray())
	check(n == 1, "one dangling marked")
	check(sk.is_construction(id), "dangling becomes construction")
