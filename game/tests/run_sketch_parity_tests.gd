# SolidWorks sketch parity smoke tests (chrome, extend/pattern, path merge).
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_parity_tests.gd
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
	print("sketch parity tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_compact_rail(main)
	await test_chrome_exists(main)
	await test_variants_and_extend(main)
	await test_pattern_and_mirror(main)
	await test_split_chamfer_smart_dim(main)
	await test_blocks_and_spline(main)
	test_path_merge(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_compact_rail(main) -> void:
	print("-- compact rail")
	main._start_sketch()
	await process_frame
	check(main.sketch_toolbar.visible, "sketch toolbar visible")
	var tips: Array = []
	for c in main.sketch_toolbar.find_children("*", "Button", true, false):
		tips.append(str(c.tooltip_text))
	check(_tip_has(tips, "Exit Sketch"), "Exit Sketch on rail")
	check(_tip_has(tips, "Line chain") or _tip_has(tips, "Line"), "Line on rail")
	check(_tip_has(tips, "Arc"), "Arc on rail")
	check(_tip_has(tips, "Polygon"), "Polygon on rail")
	check(_tip_has(tips, "Power Trim") or _tip_has(tips, "Trim"), "Trim on rail")
	check(_tip_has(tips, "Extend"), "Extend on rail")
	check(_tip_has(tips, "Smart Dimension") or _tip_has(tips, "Smart Dim"),
		"Smart Dim on rail")
	main.sketch_mode.exit_sketch()
	await process_frame


func _tip_has(tips: Array, prefix: String) -> bool:
	for t in tips:
		if str(t).begins_with(prefix):
			return true
	return false


func test_chrome_exists(main) -> void:
	print("-- sketch chrome")
	check(main.sketch_chrome != null, "SketchContextChrome present")
	main._start_sketch()
	await process_frame
	check(main.sketch_chrome.visible, "chrome visible in session")
	var done: Button = main.sketch_chrome.done_button()
	check(done != null and done.is_visible_in_tree(), "Done chip on finish bar")
	var variants: Array = main.sketch_mode.variants_for_tool(SketchMode.Tool.RECT)
	check(variants.has("corner") and variants.has("center"), "rect variants")
	main.sketch_mode.set_tool(SketchMode.Tool.RECT)
	await process_frame
	main.sketch_mode.exit_sketch()


func test_variants_and_extend(main) -> void:
	print("-- extend binding")
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var a: String = sm.sketch.add_line(0, 0, 10, 0)
	var _b: String = sm.sketch.add_line(20, -5, 20, 5)
	check(a != "", "seed lines")
	sm.set_tool(SketchMode.Tool.EXTEND)
	check(sm.extend_at(Vector2(9, 0)), "extend toward vertical")
	var info: Dictionary = sm.sketch.entity_info(a)
	var end_x: float = float(info["end"].x)
	check(end_x > 10.0 - 1e-3, "line extended past 10")
	sm.exit_sketch()


func test_pattern_and_mirror(main) -> void:
	print("-- pattern + mirror")
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var lid: String = sm.sketch.add_line(0, 0, 5, 0)
	sm._set_selected([lid])
	sm.tool_variant = "linear"
	var ids: Array = sm.pattern_selected(8.0, 0.0, 3)
	check(ids.size() >= 2, "linear pattern copies")
	var axis: String = sm.sketch.add_line(0, -10, 0, 10)
	var geo: String = sm.sketch.add_line(5, 0, 10, 0)
	sm._set_selected([axis, geo])
	var mir: Array = sm.mirror_selected()
	check(mir.size() >= 1, "mirror produced copy")
	sm.exit_sketch()


func test_split_chamfer_smart_dim(main) -> void:
	print("-- split / chamfer / smart dim")
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var _l1: String = sm.sketch.add_line(0, 0, 20, 0)
	check(sm.split_at(Vector2(10, 0)), "split line")
	check(sm.sketch.entity_ids().size() >= 2, "split added segment")
	var a: String = sm.sketch.add_line(0, 10, 10, 10)
	var b: String = sm.sketch.add_line(10, 10, 10, 0)
	sm._set_selected([a, b])
	var ch: String = sm.chamfer_selected(2.0)
	check(ch != "", "chamfer created")
	sm.set_tool(SketchMode.Tool.SMART_DIM)
	sm.click(Vector2(5, 0))
	sm.exit_sketch()


func test_blocks_and_spline(main) -> void:
	print("-- blocks + spline")
	main._start_sketch()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var a: String = sm.sketch.add_line(0, 0, 5, 0)
	sm._set_selected([a])
	check(sm.create_block("Blk1"), "create block")
	var placed: Array = sm.place_block("Blk1", Vector2(0, 10))
	check(placed.size() >= 1, "place block")
	sm.set_tool(SketchMode.Tool.SPLINE)
	sm.click(Vector2(0, 20))
	sm.click(Vector2(5, 25))
	sm.click(Vector2(10, 20))
	sm.end_chain()
	var has_spline := false
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "spline":
			has_spline = true
			break
	check(has_spline, "spline tool commits kernel spline entity")
	sm.exit_sketch()


func test_path_merge(main) -> void:
	print("-- path merge")
	var sk_a := SxSketch.new()
	sk_a.add_line(0, 0, 20, 0)
	var fid_a: String = main.view.doc.graph_add_sketch(sk_a)
	var sk_b := SxSketch.new()
	sk_b.add_line(0, 0, 0, 30)
	var fid_b: String = main.view.doc.graph_add_sketch(sk_b)
	check(fid_a != "" and fid_b != "", "two sketch features")
	var fids := PackedStringArray([fid_a, fid_b])
	var path_fid: String = main.view.doc.graph_add_path(fids, "join_endpoints")
	check(path_fid != "", "graph_add_path")
	var feats: Array = main.view.doc.graph_features()
	var found := false
	for f in feats:
		if str(f.get("id", "")) == path_fid:
			found = true
			check(str(f.get("type", "")) == "path", "feature type path")
	check(found, "path in timeline")
	var profile := SxSketch.new()
	profile.add_circle(0, 0, 2)
	var prof_fid: String = main.view.doc.graph_add_sketch(profile)
	var sw: String = main.view.doc.graph_add_sweep_along_path(prof_fid, path_fid)
	check(sw != "", "sweep along path feature")
	var body := ""
	for f in main.view.doc.graph_features():
		if str(f.get("id", "")) == sw:
			body = str(f.get("output_body", ""))
	check(body != "", "sweep along path output_body")
	check(main.view.doc.body_volume(body) > 0.0, "sweep along path solid volume")
