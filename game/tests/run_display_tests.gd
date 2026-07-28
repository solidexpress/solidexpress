# Headless tests for DocumentView display modes (shaded / edges / wireframe).
# Run: tools/godot/godot --headless --path game --script tests/run_display_tests.gd
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
	print("display mode tests")
	var view := DocumentView.new()
	root.add_child(view)
	await process_frame
	await process_frame

	test_default_mode(view)
	test_mode_visibilities(view)
	test_cycle_wraps(view)
	test_wireframe_selection(view)
	test_section_plane(view)
	test_backface_shader(view)
	test_selection_corners(view)
	await test_world_gizmos()

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _edges_of(view: DocumentView, body_id: String) -> MeshInstance3D:
	var node := view.body_node(body_id)
	return node.get_node("Edges") as MeshInstance3D


func _surface_mat(view: DocumentView, body_id: String) -> Material:
	var node := view.body_node(body_id)
	return node.get_surface_override_material(0)


func test_default_mode(view: DocumentView) -> void:
	print("- default display mode")
	check(view.display_mode == DocumentView.DisplayMode.SHADED_EDGES, "default is SHADED_EDGES")


func test_mode_visibilities(view: DocumentView) -> void:
	print("- set_display_mode visibility")
	var a: String = view.insert_primitive("box", Vector3(0, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	check(view.doc.body_ids().size() == 2, "two boxes in document")

	view.set_display_mode(DocumentView.DisplayMode.SHADED)
	check(view.display_mode == DocumentView.DisplayMode.SHADED, "mode is SHADED")
	for id in [a, b]:
		check(not _edges_of(view, id).visible, "SHADED hides edges for " + id.left(8))
		check(_surface_mat(view, id) != view._wireframe_hidden_material, "SHADED keeps body material for " + id.left(8))

	view.set_display_mode(DocumentView.DisplayMode.SHADED_EDGES)
	check(view.display_mode == DocumentView.DisplayMode.SHADED_EDGES, "mode is SHADED_EDGES")
	for id in [a, b]:
		check(_edges_of(view, id).visible, "SHADED_EDGES shows edges for " + id.left(8))
		check(_surface_mat(view, id) != view._wireframe_hidden_material, "SHADED_EDGES keeps body material for " + id.left(8))
		check(_edges_of(view, id).material_override == view._edge_material, "SHADED_EDGES uses edge material for " + id.left(8))

	view.set_display_mode(DocumentView.DisplayMode.WIREFRAME)
	check(view.display_mode == DocumentView.DisplayMode.WIREFRAME, "mode is WIREFRAME")
	for id in [a, b]:
		check(_edges_of(view, id).visible, "WIREFRAME shows edges for " + id.left(8))
		check(_surface_mat(view, id) == view._wireframe_hidden_material, "WIREFRAME hides body mesh for " + id.left(8))


func test_cycle_wraps(view: DocumentView) -> void:
	print("- cycle_display_mode")
	view.set_display_mode(DocumentView.DisplayMode.SHADED)
	check(view.cycle_display_mode() == DocumentView.DisplayMode.SHADED_EDGES, "cycle SHADED -> SHADED_EDGES")
	check(view.cycle_display_mode() == DocumentView.DisplayMode.WIREFRAME, "cycle SHADED_EDGES -> WIREFRAME")
	check(view.cycle_display_mode() == DocumentView.DisplayMode.SHADED, "cycle WIREFRAME -> SHADED")
	check(view.display_mode == DocumentView.DisplayMode.SHADED, "display_mode matches last cycle")


func test_wireframe_selection(view: DocumentView) -> void:
	print("- wireframe selection highlight")
	var ids: PackedStringArray = view.doc.body_ids()
	check(ids.size() == 2, "still two bodies")
	var a: String = ids[0]
	var b: String = ids[1]

	view.set_display_mode(DocumentView.DisplayMode.WIREFRAME)
	view.select_entity(a, "")
	check(view.selected_body == a, "body A selected")
	check(_edges_of(view, a).material_override == view._selected_edge_material, "selected body edges use selection color")
	check(_edges_of(view, b).material_override == view._edge_material, "unselected body edges stay dark")
	check(_surface_mat(view, a) == view._wireframe_hidden_material, "selected body mesh still hidden in wireframe")
	check(_surface_mat(view, b) == view._wireframe_hidden_material, "unselected body mesh still hidden in wireframe")

	# Selection highlight still works when returning to shaded modes.
	view.set_display_mode(DocumentView.DisplayMode.SHADED_EDGES)
	check(_surface_mat(view, a) == view._selected_body_material, "selected body tinted in SHADED_EDGES")
	check(_edges_of(view, a).visible, "edges visible again in SHADED_EDGES")
	check(_edges_of(view, a).material_override == view._edge_material, "edge tint cleared outside wireframe")


func test_section_plane(view: DocumentView) -> void:
	print("- section plane clipping")
	view.clear_selection()
	view.set_display_mode(DocumentView.DisplayMode.SHADED_EDGES)
	var ids: PackedStringArray = view.doc.body_ids()
	check(ids.size() == 2, "section test starts with two boxes")
	check(not view.section_enabled, "section disabled before set")

	view.set_section_plane(Vector3.ZERO, Vector3(1, 0, 0))
	check(view.section_enabled, "section_enabled after set_section_plane")
	for id in ids:
		var mat := _surface_mat(view, id)
		check(mat is ShaderMaterial, "section uses ShaderMaterial on " + id.left(8))
		if mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			check(
				sm.get_shader_parameter("section_normal").is_equal_approx(Vector3(1, 0, 0)),
				"section normal +X for " + id.left(8)
			)

	view.clear_section_plane()
	check(not view.section_enabled, "section_enabled false after clear")
	for id in ids:
		check(
			_surface_mat(view, id) is ShaderMaterial,
			"clear restores ShaderMaterial on " + id.left(8)
		)

	view.set_section_plane(Vector3.ZERO, Vector3(1, 0, 0))
	check(view.section_enabled, "section re-enabled")
	var c: String = view.insert_primitive("box", Vector3(200, 0, 0))
	check(c != "", "third box inserted while section active")
	check(_surface_mat(view, c) is ShaderMaterial, "new body gets section ShaderMaterial")
	for id in view.doc.body_ids():
		check(_surface_mat(view, id) is ShaderMaterial, "all bodies sectioned after rebuild " + id.left(8))

	# Display-mode cycling with section active must not error.
	view.cycle_display_mode()
	view.cycle_display_mode()
	view.cycle_display_mode()
	check(view.section_enabled, "section still enabled after display-mode cycles")
	for id in view.doc.body_ids():
		check(_surface_mat(view, id) is ShaderMaterial, "section material survives cycle on " + id.left(8))

	view.clear_section_plane()
	check(not view.section_enabled, "final clear disables section")
	for id in view.doc.body_ids():
		check(
			_surface_mat(view, id) is ShaderMaterial,
			"final clear restores ShaderMaterial on " + id.left(8)
		)


func test_backface_shader(view: DocumentView) -> void:
	print("- body shader darkens back faces while staying opaque")
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	var mat := _surface_mat(view, id)
	check(mat is ShaderMaterial, "body uses ShaderMaterial")
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		check(sm.shader != null, "body material has shader")
		check(sm.shader.code.contains("FRONT_FACING"), "shader branches on FRONT_FACING")
		# ALPHA writes put the solid in the transparent pass — a boolean hole
		# then orbits like a slideshow. Keep backfaces opaque + darkened.
		check(not sm.shader.code.contains("ALPHA"), "shader must not write ALPHA")
		check(sm.shader.code.contains("cull_disabled"), "both sides drawn for holes")


func test_selection_corners(view: DocumentView) -> void:
	print("- selection corner brackets")
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.clear_selection()
	check(view._selection_corners != null, "SelectionCorners node exists")
	check(view._selection_corners.mesh == null, "no corner mesh when unselected")
	view.select_entity(id, "")
	check(view._selection_corners.mesh != null, "corner mesh built on select")
	view.clear_selection()
	check(view._selection_corners.mesh == null, "corner mesh cleared on deselect")


func test_world_gizmos() -> void:
	print("- world gizmos (XY grid; origin sticks are on ViewHud)")
	var gizmos := WorldGizmos.new()
	gizmos.name = "WorldGizmos"
	root.add_child(gizmos)
	await process_frame

	var triad := gizmos.get_node_or_null("Triad") as Node3D
	var grid := gizmos.get_node_or_null("Grid") as MeshInstance3D
	check(triad == null, "no Triad on origin plate (sticks moved to ViewHud)")
	check(grid != null, "Grid child exists")
	check(gizmos.get_child_count() == 1, "WorldGizmos has Grid only")
	check(gizmos.gizmos_visible, "gizmos visible by default")
	check(grid != null and grid.visible, "Grid visible by default")

	# Grid lies on the model XY ground plane (thickness along Z ≈ 0).
	if grid != null and grid.mesh != null:
		var aabb: AABB = grid.get_aabb()
		check(absf(aabb.size.z) < 1e-4, "grid AABB thickness along Z ≈ 0 (XY plane)")
		check(aabb.size.x > WorldGizmos.GRID_HALF * 1.9 \
				and aabb.size.y > WorldGizmos.GRID_HALF * 1.9,
			"grid spans XY extent (±%.0f mm)" % WorldGizmos.GRID_HALF)
	else:
		check(false, "grid has mesh for AABB check")

	gizmos.set_gizmos_visible(false)
	check(not gizmos.gizmos_visible, "set_gizmos_visible(false) updates flag")
	check(grid != null and not grid.visible, "set_gizmos_visible(false) hides Grid")

	gizmos.set_gizmos_visible(true)
	check(gizmos.gizmos_visible and grid.visible, "set_gizmos_visible(true) restores")

	# Active plane relocates the grid.
	gizmos.set_active_plane(Vector3(0, 0, 10), Vector3(0, 0, 1))
	check(grid.position.is_equal_approx(Vector3(0, 0, 10)),
		"grid origin follows active plane (z=10)")
	gizmos.set_active_plane(Vector3(5, 0, 2.5), Vector3(1, 0, 0))
	var gx: Vector3 = grid.transform.basis.x
	var gz: Vector3 = grid.transform.basis.z
	check(absf(gz.x) > 0.9, "grid +Z maps to active normal (+X)")
	check(absf(gx.dot(gz)) < 1e-4, "grid basis stays orthonormal")
	gizmos.set_active_plane(Vector3.ZERO, Vector3(0, 0, 1))
	check(grid.transform.is_equal_approx(Transform3D.IDENTITY),
		"reset active plane restores grid at ground")

	# Zoom LOD: keep minor cells ≥ MIN_MINOR_PX; bump by decades when denser.
	check(is_equal_approx(WorldGizmos.pick_minor_step_mm(100.0), 0.1),
		"high px/mm keeps 0.1 mm minors (0.01 is sub-threshold)")
	check(is_equal_approx(WorldGizmos.pick_minor_step_mm(40.0), 0.1),
		"default-ish zoom (~4 px on 0.1 mm) keeps 0.1 mm minors")
	check(is_equal_approx(WorldGizmos.pick_minor_step_mm(20.0), 1.0),
		"zoomed out: 0.1 mm would be < 3.5 px → bump to 1 mm")
	check(is_equal_approx(WorldGizmos.pick_minor_step_mm(0.5), 10.0),
		"far zoom bumps to 10 mm minors")
	check(is_equal_approx(WorldGizmos.pick_minor_step_mm(500.0), 0.01),
		"close zoom allows 0.01 mm minors")

	gizmos.refresh_lod(20.0)
	check(is_equal_approx(gizmos.grid_step_mm, 1.0), "refresh_lod sets 1 mm minor")
	check(is_equal_approx(gizmos.grid_major_mm, 10.0), "major is 10× minor")
	check(gizmos.grid_half_mm >= 500.0 - 1e-3, "coarser LOD grows the sheet")
	if grid != null and grid.mesh != null:
		var aabb2: AABB = grid.get_aabb()
		check(aabb2.size.x > gizmos.grid_half_mm * 1.9,
			"rebuilt mesh spans the coarser half-extent")
