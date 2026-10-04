# Rung 1 replan 2 WP1 — Distance parse, dim override, Cut vs Up To Surface.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan2_distance.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

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
	print("rung01 replan2 WP1 distance")
	FilmUI.reset_fail_count()
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan2_distance.gd")
	var banned := "set_extrude" + "_distance"
	check(not src.contains(banned), "test source has no distance setter")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx)
	main._file_popup.id_pressed.emit(0)
	await process_frame
	await process_frame
	await FilmUI.enter_sketch(ctx)
	await process_frame
	await process_frame
	check(main.sketch_mode.active, "sketch session is open")
	await test_typed_dim_override(ctx)
	await test_circle_has_no_diameter_prefix(ctx)
	await test_typed_distance_without_enter(main)
	await test_append_distance_rejected(main)
	await test_cut_does_not_clear_up_to_surface(main)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_typed_distance_without_enter(main) -> void:
	print("- typed 7.5 without Enter is the Extrude distance")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	check(dist != null, "DistanceSpin exists")
	check(readout != null, "ExtrudeReadout exists")
	check(readout != null and str(readout.text).contains("20"),
			"default readout contains 20 (%s)" % (readout.text if readout else ""))
	if dist == null:
		return
	var edit := dist.get_line_edit()
	await _click(edit)
	await _click(edit)
	check(edit.has_focus(), "second click leaves Distance focused")
	var sel := edit.get_selected_text()
	check(sel == edit.text and sel != "",
			"second click selects all (sel '%s' text '%s')" % [sel, edit.text])
	await _type(edit, "7.5")
	await process_frame
	check(readout != null and str(readout.text).contains("7.5"),
			"readout contains 7.5 after typing (%s)" % (readout.text if readout else ""))
	var got := {"dist": NAN, "fired": false, "rejected": false}
	var on_finish := func(_op: String, distance: float, _end: String, _thin: float,
			_thin_type: String, _flip: bool, _contours: Array) -> void:
		got["dist"] = distance
		got["fired"] = true
	var on_reject := func(_raw: String) -> void:
		got["rejected"] = true
	chrome.finish_requested.connect(on_finish)
	chrome.distance_rejected.connect(on_reject)
	var btn := chrome.extrude_button()
	check(btn != null, "Extrude button exists")
	if btn != null:
		btn.pressed.emit()
	await process_frame
	chrome.finish_requested.disconnect(on_finish)
	chrome.distance_rejected.disconnect(on_reject)
	check(bool(got["fired"]), "Extrude pressed emitted finish_requested")
	check(is_equal_approx(float(got["dist"]), 7.5),
			"finish_requested distance is 7.5 (got %s)" % str(got["dist"]))
	check(not bool(got["rejected"]), "typed 7.5 does not emit distance_rejected")
	check(readout != null and str(readout.text).contains("7.5"),
			"readout still contains 7.5 after Extrude (%s)" % (readout.text if readout else ""))
	check(is_equal_approx(chrome.extrude_distance(), 7.5), "extrude_distance() is 7.5")


func test_append_distance_rejected(main) -> void:
	print("- appended 20.07.5 emits distance_rejected")
	var chrome: SketchContextChrome = main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	if dist == null:
		return
	var edit := dist.get_line_edit()
	await _click(edit)
	await _click(edit)
	await _type(edit, "20.07.5")
	await process_frame
	var got := {"fired": false, "rejected": "", "count": 0}
	var on_finish := func(_op: String, _distance: float, _end: String, _thin: float,
			_thin_type: String, _flip: bool, _contours: Array) -> void:
		got["fired"] = true
	var on_reject := func(raw: String) -> void:
		got["rejected"] = raw
		got["count"] = int(got["count"]) + 1
	chrome.finish_requested.connect(on_finish)
	chrome.distance_rejected.connect(on_reject)
	var btn := chrome.extrude_button()
	if btn != null:
		btn.pressed.emit()
	await process_frame
	chrome.finish_requested.disconnect(on_finish)
	chrome.distance_rejected.disconnect(on_reject)
	check(not bool(got["fired"]), "append case does not emit finish_requested")
	check(int(got["count"]) == 1 and str(got["rejected"]).contains("20.07.5"),
			"append case emits distance_rejected (%s)" % str(got["rejected"]))


func test_typed_dim_override(ctx: FilmContext) -> void:
	print("- typed dim 20 sets typed_dim_value and length override")
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool == SketchMode.Tool.POLYGON, "polygon tool is active")
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats (got %s)" % sm.tool_variant)
	var dim: SpinBox = ctx.main.sketch_chrome.find_child("DimSpin", true, false)
	check(dim != null and str(dim.suffix).contains("AF"),
			"across-flats suffix stays AF (%s)" % (dim.suffix if dim else ""))
	if ctx.main.sketch_chrome != null:
		ctx.main.sketch_chrome.release_dim_focus()
	await _zoom(ctx, Vector3.ZERO, 80.0)
	await FilmUI.click_sketch(ctx, sm, Vector2.ZERO, "Hex centre")
	await _hover_uv(ctx, Vector2(8, 0))
	await process_frame
	await process_frame
	check(sm.has_single_dof_preview(),
			"polygon preview is active (tool=%s points=%d)" % [
				str(sm.tool), sm._tool_points.size() if sm else -1])
	if dim == null:
		return
	var edit := dim.get_line_edit()
	await _click(edit)
	await _click(edit)
	await _type(edit, "20")
	await process_frame
	var typed: Variant = ctx.main.sketch_chrome.typed_dim_value()
	check(typed != null and is_equal_approx(float(typed), 20.0),
			"typed_dim_value is 20 (got %s)" % str(typed))
	check(sm.has_length_override(), "preview has a length override from the dim blank")


func test_circle_has_no_diameter_prefix(ctx: FilmContext) -> void:
	print("- circle dim drops Ø prefix")
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dim: SpinBox = chrome.find_child("DimSpin", true, false)
	check(dim != null, "DimSpin exists for circle")
	if dim != null:
		check(not str(dim.prefix).contains("Ø"),
				"circle dim has no Ø prefix (%s)" % dim.prefix)
		check(not dim.get_line_edit().text.contains("Ø"),
				"circle dim text has no Ø (%s)" % dim.get_line_edit().text)
	var cue: Label = chrome.find_child("DimRadiusCue", true, false)
	check(cue != null and cue.visible and cue.text == "r",
			"circle r cue is a label (%s)" % (cue.text if cue else ""))


func test_cut_does_not_clear_up_to_surface(main) -> void:
	print("- Cut then Up To Surface; Cut after that keeps End")
	var chrome: SketchContextChrome = main.sketch_chrome
	var op: OptionButton = chrome.find_child("FinishOp", true, false)
	var end: OptionButton = chrome.find_child("FinishEnd", true, false)
	check(op != null and end != null, "FinishOp and FinishEnd exist")
	if op == null or end == null:
		return
	op.get_popup().index_pressed.emit(1)
	await process_frame
	end.get_popup().index_pressed.emit(3)
	await process_frame
	var btn := chrome.extrude_button()
	check(end.selected == 3 and chrome.get_finish_end() == "to_face",
			"Cut then Up To Surface leaves End on Up To Surface")
	check(btn != null and btn.disabled, "Extrude disabled until a face is picked")
	check(chrome.up_to_face_id == "", "face id empty after Cut then Up To Surface")
	end.get_popup().index_pressed.emit(0)
	await process_frame
	end.get_popup().index_pressed.emit(3)
	await process_frame
	op.get_popup().index_pressed.emit(1)
	await process_frame
	check(end.selected == 3 and chrome.get_finish_end() == "to_face",
			"Up To Surface then Cut leaves End on Up To Surface")


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	ctx.main.interaction._input(motion)
	await process_frame


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var hover := InputEventMouseMotion.new()
	hover.position = pos
	hover.global_position = pos
	vp.push_input(hover)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _type(edit: LineEdit, text: String) -> void:
	var vp := edit.get_viewport()
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = ch as Key
		elif ch == 46:
			code = KEY_PERIOD
		await _key(vp, code, ch)


func _key(vp: Viewport, code: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = code
	rel.physical_keycode = code
	rel.unicode = 0
	rel.pressed = false
	vp.push_input(rel)
	await process_frame
