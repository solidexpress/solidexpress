# Rung 1 replan 13 WP6 — sketch measure ✕ only while measuring; squash and glyph probes.
# Template: run_measure_overlay_tests.gd (overlay API) + run_rung01_replan12_rail.gd (pushed events).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_measure.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const WIDE_SIZE := Vector2i(1920, 1080)
const FIRST_DROP := "First point dropped — Esc again exits the sketch"

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan13 WP6 sketch measure marks only while measuring")
	FilmUI.reset_fail_count()
	await test_circle_must_not_plant()
	await test_select_plants_and_shaft_clears()
	await test_delete_clears_on_next_motion()
	await test_jaw_circle_leaves_no_marks()
	await test_esc_ladder()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_circle_must_not_plant() -> void:
	print("- 1. Circle hover on Ø45 rim must not plant a measure ✕")
	var ctx := await _boot_a3()
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	check(sm.tool == SketchMode.Tool.CIRCLE, "Circle tool is armed")
	var rim45 := _circle_rim(sm, 22.5)
	await _hover_uv_local(ctx, vp, rim45)
	print("  after Circle hover uv=%s nearest=%s has_anchor=%s marks=%d labels=%d" % [
			str(rim45), sm._nearest_entity_at(rim45), str(mo.has_anchor()),
			mo.marks.size(), mo.labels.size()])
	check(not mo.has_anchor(), "Circle hover on the Ø45 rim does not plant a measure anchor")
	await _assert_sketch_exit_clears(ctx, vp, mo)
	await _shutdown(ctx)


func test_select_plants_and_shaft_clears() -> void:
	print("- 2/3/6/7. Select plants; Shaft Lines clears; squash and glyph probes")
	var ctx := await _boot_a3()
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	check(sm.tool == SketchMode.Tool.SELECT, "Select tool is armed")
	var rim45 := _circle_rim(sm, 22.5)
	await _hover_uv_local(ctx, vp, rim45)
	print("  after Select hover uv=%s nearest=%s has_anchor=%s marks=%d" % [
			str(rim45), sm._nearest_entity_at(rim45), str(mo.has_anchor()),
			mo.marks.size()])
	check(mo.has_anchor(), "Select hover on the Ø45 rim plants the inspector ✕")

	var circs: Array[String] = []
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			circs.append(str(id))
	check(circs.size() >= 2, "A3 geometry still has two circles")
	if circs.size() >= 2:
		sm._set_selected([circs[0], circs[1]])
	await process_frame
	await process_frame
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "Shaft Lines chip is visible")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shaft Lines", "Shaft Lines"))
	await process_frame
	await process_frame
	print("  after Shaft Lines: has_anchor=%s marks=%d labels=%d status=%s" % [
			str(mo.has_anchor()), mo.marks.size(), mo.labels.size(), _last_status()])
	check(not mo.has_anchor(), "Shaft Lines clears the planted measure anchor")
	check(mo.marks.is_empty(), "Shaft Lines leaves measure_overlay.marks empty")

	_probe_glyphs(sm)
	await _probe_squash(ctx, sm)
	await _assert_sketch_exit_clears(ctx, vp, mo)
	await _shutdown(ctx)


func test_delete_clears_on_next_motion() -> void:
	print("- 4. Deleting the hovered entity clears the anchor on the next motion")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 80.0)
	var cid: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	check(cid != "", "a Ø20 exists to delete")
	sm._redraw()
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _hover_uv_local(ctx, vp, Vector2(0.0, 10.0))
	check(mo.has_anchor(), "Select hover plants an anchor on the circle")
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	check(sm.selected.has(cid) or sm.selected.size() == 1, "the hovered circle is selected")
	await _push_key_local(vp, KEY_DELETE)
	await process_frame
	check(not sm.sketch.entity_ids().has(cid), "the hovered entity was deleted")
	await _hover_uv_local(ctx, vp, Vector2(8.0, 8.0))
	print("  after delete + motion: has_anchor=%s marks=%d" % [str(mo.has_anchor()), mo.marks.size()])
	check(not mo.has_anchor(), "the next motion after delete drops the dead anchor")
	await _shutdown(ctx)


func test_jaw_circle_leaves_no_marks() -> void:
	print("- 5. Circle tool over jaw/shaft geometry leaves no marks or Δ labels")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(40, 0, 0), 160.0)
	# A3 shaft pair plus replan-12 A8 jaw (three-click Jaw).
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(80.0, 0.0, 22.5)
	sm._redraw()
	await process_frame
	var circs: Array[String] = []
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			circs.append(str(id))
	if circs.size() >= 2:
		sm._set_selected([circs[0], circs[1]])
		await process_frame
		var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
		if chip != null and chip.is_visible_in_tree():
			await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shaft Lines", "Shaft Lines"))
			await process_frame
	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT, "Jaw is the active tool (A8)")
	await _click_uv(ctx, vp, Vector2(40.0, 40.0))
	await _click_uv(ctx, vp, Vector2(60.0, 40.0))
	await _click_uv(ctx, vp, Vector2(40.0, 50.0))
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	check(sm.tool == SketchMode.Tool.CIRCLE, "Circle is armed over the jaw sketch")
	var spots: Array[Vector2] = [
		Vector2(0.0, 10.0), Vector2(80.0, 22.5), Vector2(0.0, -10.0),
		Vector2(80.0, -22.5), Vector2(40.0, 10.0), Vector2(40.0, -10.0),
		Vector2(40.0, 40.0), Vector2(60.0, 40.0), Vector2(40.0, 50.0),
		Vector2(50.0, 45.0),
	]
	for uv in spots:
		await _hover_uv_local(ctx, vp, uv)
	print("  after 10 Circle motions: marks=%d labels=%d has_anchor=%s" % [
			mo.marks.size(), mo.labels.size(), str(mo.has_anchor())])
	check(mo.marks.size() == 0, "ten Circle motions leave marks.size() == 0 (got %d)" % mo.marks.size())
	check(mo.labels.size() == 0, "ten Circle motions leave labels.size() == 0 (got %d)" % mo.labels.size())
	await _shutdown(ctx)


func test_esc_ladder() -> void:
	print("- 8. Esc ladder: Circle first-point is two presses; Select ✕ says Measure cleared")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var mo: MeasureOverlay = ctx.main.interaction.measure_overlay
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await process_frame
	check(sm.has_pending_draw_point(), "Circle has a first point down")
	_status_log.clear()
	await _push_esc(vp)
	check(_last_status() == FIRST_DROP, "first Esc drops the first point (got '%s')" % _last_status())
	check(not _status_has("Measure cleared"), "no Measure cleared between the two Esc presses")
	check(sm.active, "sketch is still open after the first Esc")
	await _push_esc(vp)
	check(not sm.active, "second Esc exits the sketch")
	check(not _status_has("Measure cleared"), "Esc ladder never printed Measure cleared")
	await _shutdown(ctx)

	ctx = await _boot()
	await FilmUI.enter_sketch(ctx)
	sm = ctx.main.sketch_mode
	mo = ctx.main.interaction.measure_overlay
	vp = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 80.0)
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm._redraw()
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _hover_uv_local(ctx, vp, Vector2(0.0, 10.0))
	check(mo.has_anchor(), "Select planted a ✕")
	_status_log.clear()
	await _push_esc(vp)
	check(_status_has("Measure cleared"), "Select with a planted ✕: one Esc says Measure cleared (log: %s)" % str(_status_log))
	check(not mo.has_anchor(), "Esc cleared the planted ✕")
	check(sm.active, "Measure cleared keeps the sketch open")
	await _shutdown(ctx)


func _probe_glyphs(sm: SketchMode) -> void:
	print("- 7. constraint glyph colours after Shaft Lines")
	check(sm.last_conflicting.is_empty(), "last_conflicting is empty (got %s)" % str(sm.last_conflicting))
	check(sm.last_redundant.is_empty(), "last_redundant is empty (got %s)" % str(sm.last_redundant))
	check(sm.selected_constraint == "", "selected_constraint is empty (got '%s')" % sm.selected_constraint)
	var glyphs: Node3D = sm._constraint_glyphs
	check(glyphs != null, "constraint glyph node exists")
	if glyphs == null:
		return
	print("  glyph count %d  last_solve=%s  dofs=%d" % [
			glyphs.get_child_count(), sm.last_solve_status, sm.last_dofs])
	for child in glyphs.get_children():
		var lab := child as Label3D
		if lab == null:
			continue
		print("  glyph '%s' modulate=%s" % [lab.text, str(lab.modulate)])
		check(lab.modulate.is_equal_approx(SketchMode.COLOR_GLYPH),
				"glyph '%s' is COLOR_GLYPH (got %s)" % [lab.text, str(lab.modulate)])


func _probe_squash(ctx: FilmContext, sm: SketchMode) -> void:
	print("- 6. squash probe: projected Ø45 diameters")
	var cam = ctx.main.camera
	var c := Vector2(200.0, 0.0)
	var r := 22.5
	for size in [ROOT_SIZE, WIDE_SIZE]:
		await FilmUI.ensure_test_viewport(ctx, size)
		await process_frame
		await process_frame
		var left := _unproject_uv(ctx, sm, cam, c + Vector2(-r, 0.0))
		var right := _unproject_uv(ctx, sm, cam, c + Vector2(r, 0.0))
		var down := _unproject_uv(ctx, sm, cam, c + Vector2(0.0, -r))
		var up := _unproject_uv(ctx, sm, cam, c + Vector2(0.0, r))
		var dx: float = absf(right.x - left.x)
		var dy: float = absf(up.y - down.y)
		var denom := maxf(maxf(dx, dy), 1e-6)
		var ratio: float = absf(dx - dy) / denom
		print("  squash %dx%d  |Δx|=%.4f |Δy|=%.4f ratio=%.5f (%.3f%%)" % [
				size.x, size.y, dx, dy, ratio, ratio * 100.0])
		check(ratio <= 0.005,
				"Ø45 projected |Δx| and |Δy| within 0.5%% at %dx%d (ratio %.5f)" % [
				size.x, size.y, ratio])
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)


func _unproject_uv(ctx: FilmContext, sm: SketchMode, cam: Camera3D, uv: Vector2) -> Vector2:
	var world: Vector3 = sm.to_model(uv)
	var ms: Node3D = ctx.main.model_space
	if ms != null:
		world = ms.to_global(world)
	return cam.unproject_position(world)


func _assert_sketch_exit_clears(ctx: FilmContext, vp: Viewport, mo: MeasureOverlay) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if not sm.active:
		return
	# Drain any leftover measure / first-point / tool rungs, then exit.
	for _i in range(6):
		if not sm.active:
			break
		await _push_esc(vp)
	check(not sm.active, "sketch session ended")
	check(not mo.has_anchor() and mo.marks.is_empty(),
			"sketch exit clears the measure overlay")


func _boot_a3() -> FilmContext:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "blank sketch is active")
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	check(a != "" and b != "", "Ø20 at the origin and Ø45 at (200, 0)")
	sm._smart_dim_between({"entity": a, "role": "center"}, {"entity": b, "role": "center"})
	sm._redraw()
	await process_frame
	# The helper opens the dim editor; a walker dismisses it after reading 200.
	var popup: PopupPanel = ctx.main.interaction._dim_edit_popup
	if popup != null:
		popup.hide()
	await process_frame
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			print("  circle %s c=%s r=%.3f" % [id, str(info["center"]), float(info["radius"])])
	# Frame the Ø45 so a rim hover lands on Interaction, not a right-hand dock.
	await _zoom(ctx, Vector3(200, 0, 0), 120.0)
	return ctx


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _uv_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	return FilmUI.model_to_screen(ctx, sm.to_model(uv))


func _circle_rim(sm: SketchMode, want_r: float) -> Vector2:
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if absf(float(info["radius"]) - want_r) < 0.2:
			var c: Vector2 = info["center"]
			return c + Vector2(0.0, float(info["radius"]))
	return Vector2(200.0, 22.5)


func _hover_uv_local(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var ix: ViewportInteraction = ctx.main.interaction
	ix.grab_focus()
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, "sketch hover"), "hover on screen at %s" % str(uv))
	# First pointer move after a click is sometimes dropped (soft-GL rule 12).
	for _i in range(2):
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		motion.global_position = screen
		vp.push_input(motion)
		await process_frame
	var ray: Array = ix._model_ray(screen)
	var back = sm.ray_to_sketch(ray[0], ray[1])
	var nearest := sm._nearest_entity_at(uv) if back == null else sm._nearest_entity_at(back)
	print("  hover uv=%s screen=%s back=%s nearest=%s" % [
			str(uv), str(screen), str(back), nearest])
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var screen := _uv_screen(ctx, uv)
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		check(false, "click target is present")
		return
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)
	# Chip / rail buttons still need the pressed signal (same as FilmUI.click_control).


func _push_esc(vp: Viewport) -> void:
	await _push_key_local(vp, KEY_ESCAPE)


func _push_key_local(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.echo = false
	vp.push_input(up)
	await process_frame
