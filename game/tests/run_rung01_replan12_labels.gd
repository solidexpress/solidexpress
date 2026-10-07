# Rung 1 replan 12 WP2 — one click on the first or last glyph of a dimension label opens
# the editor, with the label text drawn at 18 px and stacked on screen.
# Real events: Viewport.push_input (motion, press, release), never ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_labels.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)

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
	print("rung01 replan12 WP2 label glyph clicks")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _jaw_dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(45.3))


func _jaw_across() -> Vector2:
	var d := _jaw_dir()
	return Vector2(-d.y, d.x)


func _build_jaw(sm: SketchMode, offset: float) -> void:
	var sk = sm.sketch
	var jaw_dir := _jaw_dir()
	var jaw_across := _jaw_across()
	sk.add_circle(0.0, 0.0, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - jaw_dir * 30.0 - jaw_across * 10.0
	var p1 := HEAD + jaw_dir * 30.0 - jaw_across * 10.0
	var p2 := HEAD + jaw_dir * 30.0 + jaw_across * 10.0
	var p3 := HEAD - jaw_dir * 30.0 + jaw_across * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + jaw_dir * offset
	var c0 := cc - jaw_across * 25.0
	var c1 := cc + jaw_across * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()


func _dim_index(sm: SketchMode, type: String) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == type:
			return i
	return -1


## Screen px per font px of a fixed_size Label3D with pixel_size 0.004.
func _k(cam: Camera3D) -> float:
	var k := 0.004 * float(cam.get_viewport().get_visible_rect().size.y) * 0.5
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		k /= tan(deg_to_rad(cam.fov) * 0.5)
	return k


## Screen rect of the drawn text, from the numbers the plan fixes (font 18, stack 28).
func _text_rect(ctx: FilmContext, sm: SketchMode, i: int) -> Rect2:
	var dim: Dictionary = sm.dimensions[i]
	var anchor: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(dim["label_pos"] as Vector2))
	var k := _k(ctx.main.camera)
	var font: Font = ThemeDB.fallback_font
	var text := str(dim.get("label_text", ""))
	var size := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x,
			font.get_height(18)) * k
	# Label3D.offset is screen pixels when fixed_size is set — do not scale
	# the stack by k (same as SketchMode._dimension_label_rect).
	var centre := anchor - Vector2(0.0, float(dim.get("label_stack", 0)) * 28.0)
	return Rect2(centre - size * 0.5, size)


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
	await process_frame


## Sketch view centred on the jaw head, about 90 mm across (the walk's _zoom).
func _frame_head(ctx: FilmContext, sm: SketchMode) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var ms: Node3D = ctx.main.model_space
	cam.sketch_orientation_locked = true
	cam.pivot = ms.to_global(sm.to_model(HEAD)) if ms != null else sm.to_model(HEAD)
	cam.distance = 90.0 / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame


func _popup_up(ix: ViewportInteraction) -> bool:
	return ix._dim_edit_popup != null and ix._dim_edit_popup.visible


func _reset(ix: ViewportInteraction, sm: SketchMode) -> void:
	if ix._dim_edit_popup != null:
		ix._dim_edit_popup.hide()
	sm._set_selected([] as Array[String])
	sm.set_tool(SketchMode.Tool.SELECT)
	await process_frame


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
	_build_jaw(sm, 12.0)
	sm.trim_at(HEAD + _jaw_dir() * 3.0 + _jaw_across() * 8.0)
	sm.set_tool(SketchMode.Tool.SELECT)
	sm._rebuild_dimension_labels()
	await _frame_head(ctx, sm)

	var wi := _dim_index(sm, "distance")
	var ai := _dim_index(sm, "angle")
	check(wi >= 0 and ai >= 0, "jaw has a width label and an angle label (w=%d a=%d)" % [wi, ai])
	if wi < 0 or ai < 0:
		main.queue_free()
		await process_frame
		return
	var font_sizes := []
	for child in sm._dimension_labels.get_children():
		if child is Label3D:
			font_sizes.append((child as Label3D).font_size)
	check(font_sizes.size() >= 2 and font_sizes.all(func(f): return f == 18),
			"labels are drawn at font size 18 (got %s)" % str(font_sizes))

	var rw := _text_rect(ctx, sm, wi)
	var ra := _text_rect(ctx, sm, ai)
	check(not rw.intersects(ra),
			"width and angle text rectangles do not overlap on screen (%s vs %s)" % [str(rw), str(ra)])

	await _glyph_clicks(ctx, sm, ix, wi, ai, "perspective")
	main.camera.toggle_projection()
	await _frame_head(ctx, sm)
	await _glyph_clicks(ctx, sm, ix, wi, ai, "orthographic")
	main.queue_free()
	await process_frame
	await process_frame


func _glyph_clicks(ctx: FilmContext, sm: SketchMode, ix: ViewportInteraction, wi: int, ai: int,
		mode: String) -> void:
	for pair in [["width", wi], ["angle", ai]]:
		var name: String = pair[0]
		var i: int = pair[1]
		var r := _text_rect(ctx, sm, i)
		var on_screen := Rect2(Vector2.ZERO, Vector2(ROOT_SIZE)).encloses(r)
		check(on_screen, "%s %s label is on screen (%s)" % [mode, name, str(r)])
		if not on_screen:
			continue
		var y := r.get_center().y
		for glyph in [["first glyph", r.position.x + 4.0], ["last glyph", r.end.x - 4.0]]:
			await _reset(ix, sm)
			await _push_click(Vector2(float(glyph[1]), y))
			check(_popup_up(ix), "%s: one click on the %s of the %s label opens the editor" % [
					mode, glyph[0], name])
		await _reset(ix, sm)
		await _push_click(Vector2(r.end.x + 40.0, y))
		check(not _popup_up(ix), "%s: a click 40 px right of the %s label does not" % [mode, name])
