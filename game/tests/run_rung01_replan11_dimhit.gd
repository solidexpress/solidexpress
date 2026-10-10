# Rung 1 replan 11 — dimension_hit must use world coords (to_global(to_model)).
# A Top-view Select click 70+ mm from a label in the same screen column must
# not open DimEditPopup; a click on the label itself still must.
# Do not call _look_along or write camera yaw/pitch/basis.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_dimhit.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)



func _init() -> void:
	print("rung01 replan11 dimhit world-space unproject")
	FilmUI.reset_fail_count()
	await _run()
	finish()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	var ix: ViewportInteraction = main.interaction
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0.0, 0.0, 80.0, 0.0)
	var sel: Array[String] = []
	sel.append(lid)
	sm._set_selected(sel)
	sm.constrain("distance", 80.0)
	sm._redraw()
	await process_frame
	await process_frame

	var dim_i := -1
	var lp: Variant = null
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "distance":
			dim_i = i
			lp = sm.dimensions[i].get("label_pos", null)
			if lp == null:
				lp = sm._dimension_label_pos2(sm.dimensions[i])
			break
	check(dim_i >= 0 and lp != null, "sketch has a distance label (i=%d lp=%s)" % [
			dim_i, str(lp)])
	if lp == null:
		main.queue_free()
		await process_frame
		return
	var label: Vector2 = lp
	var far := Vector2(label.x, label.y + 80.0)
	if far.distance_to(label) < 70.0:
		far = Vector2(label.x, label.y - 80.0)
	var label_scr: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(label))
	var far_scr: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(far))
	check(absf(far_scr.x - label_scr.x) < 12.0 and far.distance_to(label) >= 70.0,
			"far click is 70+ mm away in the same screen column (dmm=%.1f dpx_x=%.1f)" % [
				far.distance_to(label), absf(far_scr.x - label_scr.x)])

	sel.clear()
	sel.append(lid)
	sm._set_selected(sel)
	if ix._dim_edit_popup != null:
		ix._dim_edit_popup.hide()
	sm.set_tool(SketchMode.Tool.SELECT)
	sm.click(far)
	await process_frame
	await process_frame
	var popup_up := ix._dim_edit_popup != null and ix._dim_edit_popup.visible
	check(not popup_up,
			"Select click 70+ mm from the label does not open DimEditPopup")
	check(sm.selected.is_empty(),
			"Select click on empty canvas clears the sketch selection (got %d)" % sm.selected.size())

	sm.click(label)
	await process_frame
	await process_frame
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"a click on the label itself still opens DimEditPopup")
	main.queue_free()
	await process_frame
	await process_frame
