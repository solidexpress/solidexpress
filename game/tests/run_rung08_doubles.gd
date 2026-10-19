# Rung 8 WP-L10 — doubles across the Godot boundary.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung08_doubles.suite
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("rung08 doubles")
	test_add_line_params()
	test_hole_66()
	test_mirror_normal()
	await test_drag_cancel()
	finish()


func test_add_line_params() -> void:
	print("- add_line bit-identical params")
	var sk := SxSketch.new()
	var x1 := 0.1
	var y1 := 1.0 / 3.0
	var x2 := 123.456789012
	var y2 := 7.0
	var id: String = sk.add_line(x1, y1, x2, y2)
	var info: Dictionary = sk.entity_info(id)
	var p: PackedFloat64Array = info.get("params", PackedFloat64Array())
	check(p.size() >= 4, "line params packed")
	if p.size() >= 4:
		check(p[0] == x1 and p[1] == y1 and p[2] == x2 and p[3] == y2,
				"add_line params bit-identical (got %s %s %s %s)" % [p[0], p[1], p[2], p[3]])


func test_hole_66() -> void:
	print("- hole Ø6.6")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 20.0, 20.0, 10.0, Vector3.ZERO)
	var hole_fid: String = doc.graph_add_hole(
		box_fid, "simple", Vector3(10, 10, 10), Vector3(0, 0, -1), 6.6, 0.0, 0.0, 0.0, 0.0, 90.0)
	check(hole_fid.length() == 36, "hole feature")
	var report_v: Variant = JSON.parse_string(doc.exactness_report())
	var diameter := NAN
	if typeof(report_v) == TYPE_DICTIONARY:
		for f in report_v.get("features", []):
			if String(f.get("type", "")) == "hole":
				var raw: Variant = f.get("params", {})
				var params: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
				if typeof(raw) == TYPE_STRING:
					var parsed: Variant = JSON.parse_string(raw)
					if typeof(parsed) == TYPE_DICTIONARY:
						params = parsed
				diameter = float(params.get("diameter", NAN))
	check(diameter == 6.6, "hole Ø6.6 as written (got %s)" % str(diameter))


func test_mirror_normal() -> void:
	print("- mirror plane normal")
	var doc := SxDocument.new()
	var box_fid: String = doc.graph_add_primitive("box", 10.0, 10.0, 10.0, Vector3.ZERO)
	var ny := 0.7071067811865476
	var plane := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, ny, ny])
	var mir: String = doc.graph_add_mirror(box_fid, Vector3.ZERO, Vector3(0, 1, 1),
			PackedStringArray(), plane)
	check(mir.length() == 36, "mirror feature")
	var report_v: Variant = JSON.parse_string(doc.exactness_report())
	var got_ny := NAN
	var got_nz := NAN
	if typeof(report_v) == TYPE_DICTIONARY:
		for f in report_v.get("features", []):
			if String(f.get("type", "")) == "mirror":
				var raw: Variant = f.get("params", {})
				var params: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
				if typeof(raw) == TYPE_STRING:
					var parsed: Variant = JSON.parse_string(raw)
					if typeof(parsed) == TYPE_DICTIONARY:
						params = parsed
				var n: Variant = params.get("plane_normal", [])
				if n is Array and n.size() >= 3:
					got_ny = float(n[1])
					got_nz = float(n[2])
	check(got_ny == ny and got_nz == ny,
			"mirror normal (0, 0.7071067811865476, 0.7071067811865476) (got %s %s)" % [
				str(got_ny), str(got_nz)])


func test_drag_cancel() -> void:
	print("- drag cancel snapshot")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var x1 := 0.1
	var y1 := 1.0 / 3.0
	var x2 := 123.456789012
	var y2 := 7.0
	var id: String = sm.sketch.add_line(x1, y1, x2, y2)
	var before: PackedFloat64Array = sm.sketch.entity_info(id).get("params")
	sm.set_tool(SketchMode.Tool.SELECT)
	sm._set_selected([id])
	sm.begin_drag(Vector2(x1, y1))
	if sm._drag.is_empty():
		sm._drag = {
			"id": id,
			"part": "start",
			"grab_pos": Vector2(x1, y1),
			"orig_info": sm.sketch.entity_info(id),
			"preview_info": sm.sketch.entity_info(id),
			"orig_snap": sm.sketch.snapshot(),
		}
	sm.update_drag(Vector2(8, 9))
	sm.cancel_drag()
	var after: PackedFloat64Array = sm.sketch.entity_info(id).get("params")
	check(after.size() >= 4 and before.size() >= 4, "params after cancel")
	if after.size() >= 4 and before.size() >= 4:
		check(after[0] == before[0] and after[1] == before[1]
				and after[2] == before[2] and after[3] == before[3],
				"drag cancel bit-identical")
	sm.exit_sketch()
	main.queue_free()
	await process_frame
