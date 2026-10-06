extends SceneTree
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_fillet_err.gd

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
	print("rung01 replan11 WP2 fillet error strings")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var doc = main.view.doc
	# Feature-graph box. Direct add_box() has no feature id, so graph_add_fillet cannot target it.
	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 10, 10))
	await process_frame
	var fid := main.view.feature_of_body(body)
	check(fid != "", "box has a feature id")
	var edges: PackedStringArray = doc.get_edge_ids(body)
	check(edges.size() >= 1, "box has edges")
	var long_id := ""
	var best_len := 0.0
	for e in edges:
		var L := float(doc.measure_edge_length(e))
		if L > best_len:
			best_len = L
			long_id = e
	# Radius larger than half the shortest departure on a 10 mm box edge.
	var made: String = doc.graph_add_fillet(fid, PackedStringArray([long_id]), 50.0)
	var err := str(doc.last_graph_error())
	check(made == "", "r=50 is refused")
	check(err.contains("limit "), "error contains limit (got %s)" % err)
	check(err.contains(" mm "), "error names a length (got %s)" % err)
	check(err.contains(" at ("), "error names a midpoint (got %s)" % err)
	# A tiny radius on one edge must still succeed and clear the error.
	var ok: String = doc.graph_add_fillet(fid, PackedStringArray([long_id]), 0.2)
	check(ok != "", "r=0.2 applies (err %s)" % str(doc.last_graph_error()))
	check(not str(doc.last_graph_error()).contains("fillet failed"), "success clears the fillet error")
	main.queue_free()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
