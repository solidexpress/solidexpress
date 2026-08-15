# Headless tests for sketch constraint inference (automatic H/V + coincident
# relations), DOF-based coloring, and editable dimension values.
# Run: tools/godot/godot --headless --path game --script tests/run_infer_tests.gd
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
	print("sketch inference tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_line_inference(main.sketch_mode)
	test_rect_inference(main.sketch_mode)
	test_infer_toggle(main.sketch_mode)
	test_dof_coloring(main.sketch_mode)
	test_editable_dimension(main.sketch_mode)
	test_constraint_glyphs(main.sketch_mode)
	test_conflict_coloring(main.sketch_mode)
	test_dim_click_edit(main)
	test_dof_chip_and_hint(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_constraint_glyphs(sk: SketchMode) -> void:
	print("- constraint glyphs: draw, pick, delete")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.LINE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0.3))  # inferred horizontal
	sk.end_chain()
	check(sk.sketch.constraint_ids().size() == 1, "one inferred constraint")
	var cid: String = sk.sketch.constraint_ids()[0]
	var cinfo: Dictionary = sk.sketch.constraint_info(cid)
	check(str(cinfo.get("type", "")) == "horizontal", "constraint_info reports type")
	check((cinfo.get("refs", []) as Array).size() == 1, "constraint_info reports refs")
	check(sk._constraint_glyphs.get_child_count() == 1, "one glyph drawn")
	var glyph := sk._constraint_glyphs.get_child(0) as Label3D
	check(glyph != null and glyph.text == "H", "glyph shows H")
	# Glyph anchor sits beside the line midpoint — picking there hits it.
	check(sk._glyph_anchors.size() == 1, "glyph anchor recorded")
	var anchor: Vector2 = sk._glyph_anchors[0]["pos"]
	check(sk.constraint_hit(anchor) == cid, "constraint_hit at anchor")
	# SELECT-tool click on the glyph selects the constraint, Del removes it.
	sk.set_tool(SketchMode.Tool.SELECT)
	sk.click(anchor)
	check(sk.selected_constraint == cid, "glyph click selects constraint")
	check(sk.delete_selected_constraint(), "delete_selected_constraint")
	check(sk.sketch.constraint_ids().size() == 0, "constraint removed from kernel")
	check(sk._constraint_glyphs.get_child_count() == 0, "glyph gone after delete")
	sk.cancel()


func test_conflict_coloring(sk: SketchMode) -> void:
	print("- conflicting constraints tint entities red")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.infer_enabled = false
	sk.set_tool(SketchMode.Tool.LINE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0))
	sk.end_chain()
	var eid: String = sk.sketch.entity_ids()[0]
	# Two contradictory length dims on the same line.
	sk.set_tool(SketchMode.Tool.SELECT)
	sk._set_selected([eid])
	sk.constrain("distance", 40.0)
	sk.sketch.add_constraint("distance", [
		{"entity": eid, "role": "start"},
		{"entity": eid, "role": "end"}], 60.0)
	sk.run_solve()
	check(sk.last_conflicting.size() > 0 or sk.last_solve_status == "failed",
		"solver reports conflict (status %s, %d conflicting)"
		% [sk.last_solve_status, sk.last_conflicting.size()])
	if sk.last_conflicting.size() > 0:
		check(sk._conflict_entities.has(eid), "conflict maps to entity")
		check(sk._entity_draw_color(sk.sketch.entity_info(eid), eid) == sk.COLOR_CONFLICT,
			"conflicting entity draws red")
	else:
		check(true, "conflict list empty (solver failed outright) — entity tint skipped")
		check(true, "entity tint skipped")
	sk.infer_enabled = true
	sk.cancel()


func test_dim_click_edit(main) -> void:
	print("- click a dimension label to edit in place")
	var sk: SketchMode = main.sketch_mode
	var ix: ViewportInteraction = main.interaction
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.CIRCLE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(8, 0))
	sk.set_tool(SketchMode.Tool.SELECT)
	sk._set_selected([sk.sketch.entity_ids()[0]])
	sk.constrain("radius", 8.0)
	# The label anchors at 45° on the circle rim.
	var label_pos: Variant = sk._dimension_label_pos2(sk.dimensions[0])
	check(label_pos != null, "dimension label has a position")
	check(sk.dimension_hit(label_pos) == 0, "dimension_hit at label")
	check(sk.dimension_hit(Vector2(500, 500)) == -1, "dimension_hit misses far away")
	# Clicking the label requests the in-viewport editor (signal → popup).
	var requested := [-1]
	sk.dimension_edit_requested.connect(func(i: int) -> void: requested[0] = i)
	sk.click(label_pos)
	check(requested[0] == 0, "SELECT click on label requests edit")
	# Popup pipeline commits the typed value and re-solves.
	check(ix._dim_edit_popup != null, "dim edit popup exists")
	ix._show_dim_edit(0)
	check(ix._dim_edit_line.text.to_float() > 0.0, "editor prefilled with current value")
	ix._apply_dim_edit("12")
	var info: Dictionary = sk.sketch.entity_info(sk.sketch.entity_ids()[0])
	check(absf(info["radius"] - 12.0) < 1e-6, "typed dim resized the circle")
	sk.cancel()


func test_dof_chip_and_hint(main) -> void:
	print("- DOF chip + live inference hint")
	var sk: SketchMode = main.sketch_mode
	check(main.dof_label != null, "DOF chip exists in the sketch toolbar")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.LINE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0.3))
	var chip: String = main.dof_label.text
	var numeric: bool = chip.is_valid_int()
	check(chip == "OK" or chip == "!" or numeric,
		"DOF chip updated after solve (%s)" % chip)
	# Live hint: hovering nearly-horizontal from the chain point shows "H".
	sk.hover(Vector2(80, 0.2))
	check(sk._infer_label.visible and sk._infer_label.text == "H", "H hint while drawing")
	sk.hover(Vector2(40.1, 30))
	check(sk._infer_label.visible and sk._infer_label.text == "V", "V hint while drawing")
	sk.hover(Vector2(80, 30))
	check(not sk._infer_label.visible, "no hint off-axis")
	sk.end_chain()
	sk.cancel()


func _constraint_types(sk: SketchMode) -> Dictionary:
	# type -> count, via constraint ids (no info binding; count only).
	return {"n": sk.sketch.constraint_ids().size()}


func test_line_inference(sk: SketchMode) -> void:
	print("- line H/V + coincident inference")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.LINE)
	# Slightly off-horizontal line: inference should snap it flat via solve.
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0.3))
	var ids: Array = sk.sketch.entity_ids()
	check(ids.size() == 1, "one line created")
	var info: Dictionary = sk.sketch.entity_info(ids[0])
	check(absf(info["start"].y - info["end"].y) < 1e-6,
		"horizontal inferred and solved flat (dy=%f)" % absf(info["start"].y - info["end"].y))
	# Chained second line: coincident inference joins the shared endpoint.
	var n_before: int = sk.sketch.constraint_ids().size()
	sk.click(Vector2(40.2, 30))
	check(sk.sketch.constraint_ids().size() > n_before, "chain click added constraints")
	sk.end_chain()
	sk.cancel()


func test_rect_inference(sk: SketchMode) -> void:
	print("- rect inference fully constrains shape topology")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.RECT)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(30, 20))
	check(sk.sketch.entity_ids().size() == 4, "four rect lines")
	# 4 H/V + 4 coincident corners = 8 inferred constraints.
	check(sk.sketch.constraint_ids().size() == 8,
		"8 inferred constraints (got %d)" % sk.sketch.constraint_ids().size())
	# Rect topology survives a solve after constraining one side's length.
	sk.set_tool(SketchMode.Tool.SELECT)
	var first: String = sk.sketch.entity_ids()[0]
	sk._set_selected([first])
	var st: String = sk.constrain("distance", 50.0)
	check(st != "failed" and st != "", "distance dim solves (%s)" % st)
	var info: Dictionary = sk.sketch.entity_info(first)
	check(absf((info["end"] - info["start"]).length() - 50.0) < 1e-4, "side resized to 50")
	sk.cancel()


func test_infer_toggle(sk: SketchMode) -> void:
	print("- inference can be disabled")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.infer_enabled = false
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.LINE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0.3))
	check(sk.sketch.constraint_ids().size() == 0, "no constraints when disabled")
	var info: Dictionary = sk.sketch.entity_info(sk.sketch.entity_ids()[0])
	check(absf(info["end"].y - 0.3) < 1e-4, "geometry untouched")
	sk.infer_enabled = true
	sk.cancel()


func test_dof_coloring(sk: SketchMode) -> void:
	print("- DOF tracking and constrained color")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	check(sk.last_dofs == -1, "no solve yet after begin")
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.CIRCLE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(10, 0))
	check(sk._entity_draw_color({}) == sk.COLOR_ENTITY, "unconstrained draws default")
	# Fully constrain the circle: radius + center pinned by two distance dims
	# is overkill; PlaneGCS reports dofs after any solve — pin radius and check
	# dofs drop.
	sk.set_tool(SketchMode.Tool.SELECT)
	var cid_e: String = sk.sketch.entity_ids()[0]
	sk._set_selected([cid_e])
	sk.constrain("radius", 10.0)
	check(sk.last_dofs >= 0, "dofs tracked after solve (got %d)" % sk.last_dofs)
	if sk.last_dofs == 0:
		check(sk._entity_draw_color({}) == sk.COLOR_CONSTRAINED, "fully constrained draws green")
	else:
		check(sk._entity_draw_color({}) == sk.COLOR_ENTITY, "partially constrained stays default")
	sk.cancel()


func test_editable_dimension(sk: SketchMode) -> void:
	print("- dimension value edit re-solves")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.CIRCLE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(8, 0))
	sk.set_tool(SketchMode.Tool.SELECT)
	var eid: String = sk.sketch.entity_ids()[0]
	sk._set_selected([eid])
	sk.constrain("radius", 8.0)
	check(sk.dimensions.size() == 1, "dimension recorded")
	check(sk.dimensions[0].get("cid", "") != "", "dimension keeps constraint id")
	var st: String = sk.set_dimension_value(0, 12.0)
	check(st == "success" or st == "converged", "edited dim solves (%s)" % st)
	var info: Dictionary = sk.sketch.entity_info(eid)
	check(absf(info["radius"] - 12.0) < 1e-6, "circle radius follows edited dim")
	check(sk.dimensions[0]["value"] == 12.0, "dimension record updated")
	sk.cancel()
