# Headless tests for SketchMode ARC and POLYGON drawing tools.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_tools_tests.gd
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
	print("sketch tools tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_arc_tool(main)
	test_polygon_tool(main)
	test_polygon_sides_clamp(main)
	test_polygon_extrude(main)
	test_tool_switch_mid_arc(main)
	test_fillet_selected(main)
	test_offset_selected_circle(main)
	test_construction_binding()
	test_toggle_construction_selected(main)
	test_toggle_section(main)
	test_snap_endpoint(main)
	test_snap_midpoint(main)
	test_snap_circle_center(main)
	test_snap_axis_horizontal(main)
	test_snap_perpendicular(main)
	test_snap_disabled(main)
	test_auto_close_line_chain(main)
	test_profile_is_closed()
	test_dimension_distance_label(main)
	test_dimension_radius_label(main)
	test_dimensions_visible_toggle(main)
	test_dimension_labels_cleared_on_exit(main)
	test_trim_end_segment(main)
	test_trim_interior_split(main)
	test_trim_empty_space(main)
	test_trim_prunes_dimension_label(main)
	test_typed_length_line(main)
	test_typed_radius_circle(main)
	test_dim_blank_ignores_mouse_while_editing(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_arc_tool(main) -> void:
	print("- arc tool: three clicks")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.ARC)

	var center := Vector2(0, 0)
	var start_pt := Vector2(10, 0)
	var end_pt := Vector2(0, 10)
	sm.click(center)
	sm.click(start_pt)
	sm.click(end_pt)

	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 1, "arc tool created exactly 1 entity")
	var info: Dictionary = sm.sketch.entity_info(ids[0])
	check(info.get("type", "") == "arc", "entity is an arc")
	var expected_r := center.distance_to(start_pt)
	var expected_start := (start_pt - center).angle()
	var expected_end := (end_pt - center).angle()
	check(absf(info["radius"] - expected_r) < 1e-4, "arc radius matches (%.6f)" % info["radius"])
	check(absf(info["start_angle"] - expected_start) < 1e-4,
		"arc start_angle matches (%.6f)" % info["start_angle"])
	check(absf(info["end_angle"] - expected_end) < 1e-4,
		"arc end_angle matches (%.6f)" % info["end_angle"])
	sm.cancel()


func test_polygon_tool(main) -> void:
	print("- polygon tool: hexagon")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.polygon_sides = 6
	sm.set_tool(SketchMode.Tool.POLYGON)

	var center := Vector2(0, 0)
	var vertex := Vector2(20, 0)
	sm.click(center)
	sm.click(vertex)

	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 6, "hexagon created 6 line entities")

	var r := center.distance_to(vertex)
	var ends: Array[Vector2] = []
	for id in ids:
		var info: Dictionary = sm.sketch.entity_info(id)
		check(info.get("type", "") == "line", "polygon entity is a line")
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		check(absf(s.distance_to(center) - r) < 1e-4, "start vertex on circle")
		check(absf(e.distance_to(center) - r) < 1e-4, "end vertex on circle")
		ends.append(s)
		ends.append(e)

	# Consecutive lines share endpoints: each endpoint appears exactly twice.
	var unmatched := 0
	for i in range(ends.size()):
		var matches := 0
		for j in range(ends.size()):
			if i != j and ends[i].distance_to(ends[j]) < 1e-4:
				matches += 1
		if matches != 1:
			unmatched += 1
	check(unmatched == 0, "consecutive lines share endpoints (closed chain)")
	sm.cancel()


func test_polygon_sides_clamp(main) -> void:
	print("- polygon_sides clamp")
	var sm: SketchMode = main.sketch_mode
	sm.polygon_sides = 2
	check(sm.polygon_sides == 3, "polygon_sides=2 clamps to 3")
	sm.polygon_sides = 6


func test_polygon_extrude(main) -> void:
	print("- polygon extrude volume")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	view.clear_selection()
	main._start_sketch()
	sm.polygon_sides = 6
	sm.set_tool(SketchMode.Tool.POLYGON)

	var center := Vector2(0, 0)
	var r := 10.0
	sm.click(center)
	sm.click(Vector2(r, 0))

	var n := 6
	var expected := 0.5 * float(n) * r * r * sin(TAU / float(n)) * 10.0
	var count0: int = view.doc.body_ids().size()
	sm.finish_extrude(10.0, "new")
	check(view.doc.body_ids().size() == count0 + 1, "polygon extrude created a body")
	var body: String = view.selected_body
	check(body != "", "extruded body selected")
	var vol: float = view.doc.body_volume(body)
	check(absf(vol - expected) / expected < 0.01,
		"hexagon prism volume within 1%% (%.3f vs %.3f)" % [vol, expected])


func test_tool_switch_mid_arc(main) -> void:
	print("- tool switch mid-arc leaves no stray entities")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.ARC)
	sm.click(Vector2(5, 5))
	check(sm.sketch.entity_ids().size() == 0, "no entity after first arc click")
	sm.set_tool(SketchMode.Tool.LINE)
	check(sm.sketch.entity_ids().size() == 0, "no entity after switching away")
	sm.set_tool(SketchMode.Tool.ARC)
	check(sm.sketch.entity_ids().size() == 0, "no entity after switching back to arc")
	check(sm._tool_points.is_empty(), "tool points cleared on switch")
	sm.cancel()


func test_fillet_selected(main) -> void:
	print("- fillet_selected on perpendicular L")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)

	var la: String = sm.sketch.add_line(0, 0, 10, 0)
	var lb: String = sm.sketch.add_line(10, 0, 10, 10)
	var n_before: int = sm.sketch.entity_ids().size()
	sm._set_selected([la, lb])

	var arc_id: String = sm.fillet_selected(2.0)
	check(arc_id != "", "fillet_selected returned non-empty arc id")
	check(sm.sketch.entity_ids().size() == n_before + 1, "fillet grew entity count by 1")
	var info: Dictionary = sm.sketch.entity_info(arc_id)
	check(info.get("type", "") == "arc", "fillet entity is an arc")
	check(absf(info["radius"] - 2.0) < 1e-4, "fillet arc radius is 2")
	sm.cancel()


func test_offset_selected_circle(main) -> void:
	print("- offset_selected on a circle")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)

	var cid: String = sm.sketch.add_circle(0, 0, 10)
	var n_before: int = sm.sketch.entity_ids().size()
	sm._set_selected([cid])

	var dist := 3.0
	var new_ids: Array = sm.offset_selected(dist)
	check(new_ids.size() == 1, "offset_selected returned 1 new id")
	check(sm.sketch.entity_ids().size() == n_before + 1, "offset grew entity count by 1")
	var info: Dictionary = sm.sketch.entity_info(new_ids[0])
	check(info.get("type", "") == "circle", "offset entity is a circle")
	check(absf(info["radius"] - (10.0 + dist)) < 1e-4,
		"offset circle radius differs by distance (%.6f)" % info["radius"])
	sm.cancel()


func test_construction_binding() -> void:
	print("- SxSketch set_construction / is_construction round-trip")
	var sk := SxSketch.new()
	var lid: String = sk.add_line(0, 0, 10, 0)
	var cid: String = sk.add_circle(0, 0, 5)
	check(not sk.is_construction(lid), "line not construction by default")
	check(not sk.is_construction(cid), "circle not construction by default")
	sk.set_construction(lid, true)
	check(sk.is_construction(lid), "line is_construction after set true")
	check(not sk.is_construction(cid), "circle unchanged when sibling toggled")
	check(sk.entity_info(lid).get("construction", false) == true,
		"entity_info.construction reflects flag")
	sk.set_construction(lid, false)
	check(not sk.is_construction(lid), "line is_construction after set false")


func test_toggle_construction_selected(main) -> void:
	print("- toggle_construction_selected flips selected entities")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var a: String = sm.sketch.add_line(0, 0, 5, 0)
	var b: String = sm.sketch.add_line(0, 5, 5, 5)
	sm._set_selected([a, b])
	check(not sm.sketch.is_construction(a), "a not construction before toggle")
	check(not sm.sketch.is_construction(b), "b not construction before toggle")
	sm.toggle_construction_selected()
	check(sm.sketch.is_construction(a), "a construction after first toggle")
	check(sm.sketch.is_construction(b), "b construction after first toggle")
	sm.toggle_construction_selected()
	check(not sm.sketch.is_construction(a), "a cleared after second toggle")
	check(not sm.sketch.is_construction(b), "b cleared after second toggle")
	sm.cancel()


func test_toggle_section(main) -> void:
	print("- toggle_section flips section_enabled")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.clear_selection()
	if view.section_enabled:
		view.clear_section_plane()
	var body: String = view.insert_primitive("box", Vector3(50, 50, 0))
	check(body != "", "box inserted for section test")
	check(not view.section_enabled, "section off before toggle")
	vi.toggle_section()
	check(view.section_enabled, "section_enabled true after first toggle")
	vi.toggle_section()
	check(not view.section_enabled, "section_enabled false after second toggle")


func test_snap_endpoint(main) -> void:
	print("- snap to existing line endpoint")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	var a := Vector2(0, 0)
	var b := Vector2(40, 0)
	sm.click(a)
	sm.click(b)
	sm.end_chain()
	# Start a second line near the first line's end endpoint (within SNAP_RADIUS 1.25).
	var near_end := b + Vector2(0.8, 0.6)
	sm.click(near_end)
	sm.click(Vector2(40, 30))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "endpoint snap: two lines created")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	check(info["start"].distance_to(b) < 1e-6,
		"second line start snaps to first line endpoint")
	# ~2 mm away must not snap (radius is 1.25).
	sm.end_chain()
	var far := b + Vector2(2.0, 0.0)
	check(sm.snap_point(far).distance_to(far) < 1e-9,
		"point 2 mm from endpoint does not snap")
	sm.cancel()


func test_snap_midpoint(main) -> void:
	print("- snap to line midpoint")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	sm.sketch.add_line(0, 0, 20, 0)
	var mid := Vector2(10, 0)
	var near_mid := mid + Vector2(0.5, 0.8)
	var snapped: Vector2 = sm.snap_point(near_mid)
	check(snapped.distance_to(mid) < 1e-6, "snap_point hits exact midpoint")
	sm.click(near_mid)
	sm.click(Vector2(10, 25))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "midpoint snap: line from midpoint created")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	check(info["start"].distance_to(mid) < 1e-6, "new line starts at midpoint")
	sm.cancel()


func test_snap_circle_center(main) -> void:
	print("- snap to circle center")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	var center := Vector2(15, 15)
	sm.sketch.add_circle(center.x, center.y, 10.0)
	var near_c := center + Vector2(0.7, -0.5)
	var snapped: Vector2 = sm.snap_point(near_c)
	check(snapped.distance_to(center) < 1e-6, "snap_point hits circle center")
	sm.click(near_c)
	sm.click(Vector2(40, 15))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "center snap: circle + line")
	var line_info: Dictionary = {}
	for id in ids:
		var info: Dictionary = sm.sketch.entity_info(id)
		if info.get("type", "") == "line":
			line_info = info
			break
	check(not line_info.is_empty(), "found line after center snap click")
	check(line_info["start"].distance_to(center) < 1e-6, "line starts at circle center")
	sm.cancel()


func test_snap_axis_horizontal(main) -> void:
	print("- snap axis: almost-horizontal second click")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	var p0 := Vector2(0, 10)
	sm.click(p0)
	# y offset within SNAP_RADIUS (1.25) → should snap to same y (exact horizontal)
	sm.click(Vector2(50, 10 + 0.9))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 1, "axis snap created one line")
	var info: Dictionary = sm.sketch.entity_info(ids[0])
	check(absf(info["start"].y - info["end"].y) < 1e-6, "line is exactly horizontal")
	check(absf(info["end"].y - p0.y) < 1e-6, "end y matches first point y")
	check(absf(info["end"].x - 50.0) < 1e-6, "end x kept (not snapped away)")
	sm.cancel()


func test_snap_perpendicular(main) -> void:
	print("- snap perpendicular to previous diagonal segment")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_auto_close(false)
	sm.set_tool(SketchMode.Tool.LINE)
	# Diagonal first segment (45°).
	sm.click(Vector2(0, 0))
	sm.click(Vector2(30, 30))
	# Cursor nearly perpendicular to previous (perp to (1,1) is (-1,1)).
	var last := Vector2(30, 30)
	var perp_dir := Vector2(-1, 1).normalized()
	var along_err := Vector2(1, 1).normalized() * 0.8  # within SNAP_RADIUS
	var near_perp: Vector2 = last + perp_dir * 40.0 + along_err
	var snapped: Vector2 = sm.snap_point(near_perp)
	var got := snapped - last
	check(absf(Vector2(1, 1).normalized().dot(got.normalized())) < 0.05,
		"snap_point is perpendicular to previous segment")
	sm.click(near_perp)
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "perpendicular snap created second line")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	var d: Vector2 = info["end"] - info["start"]
	var prev := Vector2(30, 30)
	check(absf(prev.normalized().dot(d.normalized())) < 0.05,
		"committed second line is perpendicular")
	sm.cancel()


func test_snap_disabled(main) -> void:
	print("- set_snap(false) passes raw positions")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.LINE)
	sm.sketch.add_line(0, 0, 40, 0)
	sm.set_snap(false)
	var raw := Vector2(40 + 0.8, 0.6)
	var out: Vector2 = sm.snap_point(raw)
	check(out.distance_to(raw) < 1e-9, "snap_point returns raw when disabled")
	sm.click(raw)
	sm.click(Vector2(40, 30))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "disabled snap: two lines")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	check(info["start"].distance_to(raw) < 1e-6, "new line start stays at raw click")
	check(info["start"].distance_to(Vector2(40, 0)) > 1e-3, "did not snap to endpoint")
	sm.set_snap(true)
	sm.cancel()


func test_auto_close_line_chain(main) -> void:
	print("- auto-close adds closing segment on end_chain")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(false)
	sm.set_auto_close(true)
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(20, 0))
	sm.click(Vector2(20, 15))
	# Open U — three points / two segments.
	check(sm.sketch.entity_ids().size() == 2, "two segments before close")
	sm.end_chain()
	check(sm.sketch.entity_ids().size() == 3, "auto-close added third segment")
	check(SketchMode.profile_is_closed(sm.sketch), "closed triangle profile")
	# Toggle off: leave open.
	sm.cancel()
	main._start_sketch()
	sm.set_snap(false)
	sm.set_auto_close(false)
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(10, 0))
	sm.click(Vector2(10, 8))
	sm.end_chain()
	check(sm.sketch.entity_ids().size() == 2, "auto-close off leaves chain open")
	check(not SketchMode.profile_is_closed(sm.sketch), "open chain is not closed")
	sm.set_auto_close(true)
	sm.cancel()


func test_profile_is_closed() -> void:
	print("- profile_is_closed helper")
	var open_sk := SxSketch.new()
	open_sk.add_line(0, 0, 10, 0)
	open_sk.add_line(10, 0, 10, 8)
	check(not SketchMode.profile_is_closed(open_sk), "open L is not closed")
	var closed_sk := SxSketch.new()
	closed_sk.add_line(0, 0, 10, 0)
	closed_sk.add_line(10, 0, 10, 8)
	closed_sk.add_line(10, 8, 0, 0)
	check(SketchMode.profile_is_closed(closed_sk), "triangle is closed")
	var circ := SxSketch.new()
	circ.add_circle(0, 0, 5)
	check(SketchMode.profile_is_closed(circ), "circle is closed")
	var rect := SxSketch.new()
	rect.add_line(0, 0, 20, 0)
	rect.add_line(20, 0, 20, 10)
	rect.add_line(20, 10, 0, 10)
	rect.add_line(0, 10, 0, 0)
	check(SketchMode.profile_is_closed(rect), "rectangle is closed")


func _dimension_label_texts(sm: SketchMode) -> Array[String]:
	var texts: Array[String] = []
	if sm._dimension_labels == null:
		return texts
	for child in sm._dimension_labels.get_children():
		if child is Label3D:
			texts.append((child as Label3D).text)
	return texts


func test_dimension_distance_label(main) -> void:
	print("- distance dimension creates Label3D")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0, 0, 40, 0)
	sm._set_selected([lid])
	check(sm.constrain("distance", 50.0) == "success", "distance constraint solves")
	check(sm.dimensions.size() == 1, "dimensions array has one entry")
	check(sm.dimensions[0]["type"] == "distance", "stored type is distance")
	var texts := _dimension_label_texts(sm)
	check(texts.size() == 1, "one Label3D under dimension labels")
	var expected := sm._format_dimension(50.0)
	check(texts[0] == expected, "distance label text is '%s' (got '%s')" % [expected, texts[0]])
	sm.cancel()


func test_dimension_radius_label(main) -> void:
	print("- radius dimension creates Label3D")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var cid: String = sm.sketch.add_circle(0, 0, 10)
	sm._set_selected([cid])
	check(sm.constrain("radius", 15.0) == "success", "radius constraint solves")
	check(sm.dimensions.size() == 1, "dimensions array has one radius entry")
	var texts := _dimension_label_texts(sm)
	check(texts.size() == 1, "one Label3D for radius dimension")
	var expected := sm._format_dimension(15.0)
	check(texts[0] == expected, "radius label text is '%s' (got '%s')" % [expected, texts[0]])
	sm.cancel()


func test_dimensions_visible_toggle(main) -> void:
	print("- set_dimensions_visible hides label container")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0, 0, 20, 0)
	sm._set_selected([lid])
	sm.constrain("distance", 25.0)
	check(sm._dimension_labels.visible, "dimension labels visible by default")
	sm.set_dimensions_visible(false)
	check(not sm.dimensions_visible, "dimensions_visible flag false")
	check(not sm._dimension_labels.visible, "label container hidden")
	sm.set_dimensions_visible(true)
	check(sm._dimension_labels.visible, "label container shown again")
	sm.cancel()


func test_dimension_labels_cleared_on_exit(main) -> void:
	print("- leaving sketch mode frees dimension labels")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0, 0, 30, 0)
	sm._set_selected([lid])
	sm.constrain("distance", 30.0)
	check(_dimension_label_texts(sm).size() == 1, "label present before exit")
	check(sm.dimensions.size() == 1, "dimensions stored before exit")
	sm.cancel()
	check(sm.dimensions.is_empty(), "dimensions cleared on cancel")
	check(sm._dimension_labels.get_child_count() == 0, "label nodes freed on cancel")


func test_trim_end_segment(main) -> void:
	print("- TRIM end-segment shortens line at cross")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	var h: String = sm.sketch.add_line(0, 0, 10, 0)
	sm.sketch.add_line(5, -5, 5, 5)
	var n_before: int = sm.sketch.entity_ids().size()
	sm.set_tool(SketchMode.Tool.TRIM)
	sm.click(Vector2(8, 0))
	check(sm.sketch.entity_ids().size() == n_before, "end trim: entity count unchanged")
	check(not sm.sketch.entity_info(h).is_empty(), "end trim: original line id kept")
	var info: Dictionary = sm.sketch.entity_info(h)
	check(info["start"].distance_to(Vector2(0, 0)) < 1e-6, "end trim: start unchanged")
	check(info["end"].distance_to(Vector2(5, 0)) < 1e-6,
		"end trim: end moved to intersection")
	sm.cancel()


func test_trim_interior_split(main) -> void:
	print("- TRIM interior between two crossers splits line")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	var h: String = sm.sketch.add_line(0, 0, 10, 0)
	sm.sketch.add_line(3, -2, 3, 2)
	sm.sketch.add_line(7, -2, 7, 2)
	var n_before: int = sm.sketch.entity_ids().size()
	sm.set_tool(SketchMode.Tool.TRIM)
	sm.click(Vector2(5, 0))
	check(sm.sketch.entity_ids().size() == n_before + 1,
		"interior trim: entity count +1")
	check(sm.sketch.entity_info(h).is_empty(), "interior trim: original line removed")
	sm.cancel()


func test_trim_empty_space(main) -> void:
	print("- TRIM click on empty space fails without change")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.sketch.add_line(0, 0, 10, 0)
	sm.sketch.add_line(5, -5, 5, 5)
	var n_before: int = sm.sketch.entity_ids().size()
	var ids_before: PackedStringArray = sm.sketch.entity_ids()
	sm.set_tool(SketchMode.Tool.TRIM)
	var ok: bool = sm.trim_at(Vector2(100, 100))
	check(not ok, "empty-space trim returns false")
	check(sm.sketch.entity_ids().size() == n_before, "empty-space trim: count unchanged")
	var ids_after: PackedStringArray = sm.sketch.entity_ids()
	var same := ids_before.size() == ids_after.size()
	if same:
		for i in range(ids_before.size()):
			if ids_before[i] != ids_after[i]:
				same = false
				break
	check(same, "empty-space trim: entity ids unchanged")
	sm.cancel()


func test_trim_prunes_dimension_label(main) -> void:
	print("- TRIM interior replaces line and prunes its dimension label")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	var h: String = sm.sketch.add_line(0, 0, 10, 0)
	sm.sketch.add_line(3, -2, 3, 2)
	sm.sketch.add_line(7, -2, 7, 2)
	sm.dimensions.append({"type": "distance", "ids": [h], "value": 10.0})
	sm._redraw()
	check(sm.dimensions.size() == 1, "dimension stored before trim")
	check(_dimension_label_texts(sm).size() == 1, "label present before trim")
	sm.set_tool(SketchMode.Tool.TRIM)
	sm.click(Vector2(5, 0))
	check(sm.sketch.entity_info(h).is_empty(), "replaced line gone after interior trim")
	check(sm.dimensions.is_empty(), "orphan dimension pruned from array")
	check(_dimension_label_texts(sm).size() == 0, "dimension label no longer shown")
	sm.cancel()


func test_typed_length_line(main) -> void:
	print("- typed length locks line segment distance")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	if sm.active:
		sm.cancel()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.hover(Vector2(30, 0))
	check(sm.has_single_dof_preview(), "line rubber-band is single-DOF")
	check(absf(sm.preview_distance() - 30.0) < 1e-4, "mouse sets preview distance")
	check(sm.commit_at_length(12.5), "commit_at_length succeeds")
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 1, "typed length created one line")
	var info: Dictionary = sm.sketch.entity_info(ids[0])
	var a: Vector2 = info["start"]
	var b: Vector2 = info["end"]
	check(absf(a.distance_to(b) - 12.5) < 1e-4, "line length is typed 12.5")
	check(absf(b.y) < 1e-4, "direction followed mouse (horizontal)")
	sm.cancel()


func test_typed_radius_circle(main) -> void:
	print("- typed radius locks center-circle")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	if sm.active:
		sm.cancel()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.CIRCLE)
	sm.click(Vector2(0, 0))
	sm.hover(Vector2(8, 0))
	check(sm.has_single_dof_preview(), "circle radius step is single-DOF")
	sm.set_length_override(7.0)
	check(absf(sm.effective_hover().distance_to(Vector2(0, 0)) - 7.0) < 1e-4,
		"override locks radius while mouse steers")
	sm.hover(Vector2(0, 20))
	check(absf(sm.effective_hover().x) < 1e-4, "direction follows mouse after override")
	check(absf(sm.effective_hover().y - 7.0) < 1e-4, "radius stays at override")
	check(sm.commit_at_length(7.0), "commit typed radius")
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 1, "circle created")
	var info: Dictionary = sm.sketch.entity_info(ids[0])
	check(info.get("type", "") == "circle", "entity is circle")
	check(absf(info["radius"] - 7.0) < 1e-4, "circle radius is typed 7")
	sm.cancel()


func test_dim_blank_ignores_mouse_while_editing(main) -> void:
	print("- finish-bar dim blank ignores mouse sync while focused")
	var chrome: SketchContextChrome = main.sketch_chrome
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	if sm.active:
		sm.cancel()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0))
	sm.hover(Vector2(10, 0))
	chrome.set_dim_value(10.0)
	check(absf(chrome.dim_value() - 10.0) < 1e-4, "blank tracks mouse when idle")
	chrome.focus_dim_for_typing("4")
	check(chrome.dim_is_editing(), "blank is editing after focus")
	chrome.set_dim_value(99.0)
	check(absf(chrome.dim_value() - 4.0) < 1e-4, "mouse sync skipped while typing")
	chrome.release_dim_focus()
	sm.cancel()
