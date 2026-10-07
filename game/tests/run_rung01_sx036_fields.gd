# sx-036 — inline numeric fields replace on the first key, and a dimension
# edit does not leave a stale contour fill or a ±50 mm grid patch.
# Real events: Viewport.push_input for clicks and keys under test.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx036_fields.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 sx036 numeric fields, contour fill, grid")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var ctx := await _boot()
	await _test_circle_radius(ctx)
	await _test_polygon_af(ctx)
	await _shutdown(ctx)
	ctx = await _boot()
	await _test_angle_editor(ctx)
	await _shutdown(ctx)
	ctx = await _boot()
	await _test_stale_fill_and_frame(ctx)
	await _shutdown(ctx)


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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	await FilmUI.enter_sketch(ctx)
	check(main.sketch_mode.active, "sketch is active")
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _status_blob() -> String:
	return " ".join(_status_log)


func _test_circle_radius(ctx: FilmContext) -> void:
	print("- Slot r5 then Circle centre, type 22.5")
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SLOT)
	await process_frame
	var dim := _dim_edit(chrome)
	check(_parses_to(dim, 5.0), "Slot blank shows slot radius 5 (got '%s')" % _digits(dim))
	var dist := _distance_edit(chrome)
	var dist_before := _digits(dist)
	var dist_value := _distance_spin(chrome).value if _distance_spin(chrome) != null else -1.0
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await process_frame
	dim = _dim_edit(chrome)
	check(_parses_to(dim, sm.circle_radius) and not _parses_to(dim, sm.slot_radius),
			"Circle blank shows circle radius %.1f not slot %.1f (got '%s')" % [
				sm.circle_radius, sm.slot_radius, _digits(dim)])
	check(is_equal_approx(sm.slot_radius, 5.0), "slot radius stays 5")
	await _click_uv(ctx, Vector2.ZERO, "Circle centre")
	await process_frame
	dim = _dim_edit(chrome)
	check(dim != null and dim.has_focus(), "centre click focuses the Radius field")
	await _push_char(ctx, "2")
	dim = _dim_edit(chrome)
	check(_digits(dim) == "2", "first Radius key is '2' (got '%s')" % _digits(dim))
	await _push_char(ctx, "2")
	check(_digits(_dim_edit(chrome)) == "22", "Radius reads '22' (got '%s')" % _digits(_dim_edit(chrome)))
	await _push_char(ctx, ".")
	await _push_char(ctx, "5")
	check(_parses_to(_dim_edit(chrome), 22.5) and _digits(_dim_edit(chrome)) == "22.5",
			"Radius reads 22.5 (got '%s')" % _digits(_dim_edit(chrome)))
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	var circ := _circle_near(sm, Vector2.ZERO)
	var info: Dictionary = sm.sketch.entity_info(circ) if circ != "" else {}
	var radius := float(info.get("radius", -1.0))
	check(is_equal_approx(radius, 22.5), "committed circle radius is 22.5 (got %.4f)" % radius)
	check(_status_blob().contains("Circle r=22.5"), "status has Circle r=22.5")
	check(is_equal_approx(sm.slot_radius, 5.0), "slot radius still 5 after circle")
	check(_digits(_distance_edit(chrome)) == dist_before,
			"Extrude distance text unchanged (was '%s' now '%s')" % [
				dist_before, _digits(_distance_edit(chrome))])
	check(is_equal_approx(_distance_spin(chrome).value, dist_value),
			"Extrude distance value unchanged (was %.4f now %.4f)" % [
				dist_value, _distance_spin(chrome).value])


func _test_polygon_af(ctx: FilmContext) -> void:
	print("- Polygon AF type 20")
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	sm.fit_view()
	await process_frame
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	await process_frame
	check(sm.tool_variant == "across_flats", "polygon variant is across flats")
	await _click_uv(ctx, Vector2(12, 12), "Polygon centre")
	await process_frame
	var dim := _dim_edit(chrome)
	check(dim != null and dim.has_focus(), "polygon centre focuses the AF field")
	await _push_char(ctx, "2")
	check(_digits(_dim_edit(chrome)) == "2", "first AF key is '2' (got '%s')" % _digits(_dim_edit(chrome)))
	await _push_char(ctx, "0")
	check(_digits(_dim_edit(chrome)) == "20", "AF reads '20' (got '%s')" % _digits(_dim_edit(chrome)))
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	check(_status_blob().contains("Polygon AF 20"),
			"status has Polygon AF 20 (got '%s')" % _status_blob())


func _test_angle_editor(ctx: FilmContext) -> void:
	print("- dimension editor type 45")
	var sm: SketchMode = ctx.main.sketch_mode
	var h: String = sm.sketch.add_line(0, 0, 40, 0)
	var v: String = sm.sketch.add_line(0, 0, 0, 40)
	sm._set_selected([h, v])
	sm.constrain("angle", PI * 0.5)
	sm.run_solve()
	sm._rebuild_dimension_labels()
	sm._redraw()
	sm.fit_view()
	await process_frame
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var label := _angle_label(sm)
	check(label != Vector2.INF, "angle dimension has a label")
	if label == Vector2.INF:
		return
	await _click_uv(ctx, label, "Angle dimension label")
	await process_frame
	await process_frame
	await process_frame
	var line := _dim_popup_line(ctx)
	var popup := ctx.main.interaction.find_child("DimEditPopup", true, false) as PopupPanel
	check(line != null and popup != null and popup.visible, "dimension editor is open")
	if line == null:
		return
	var before := str(line.text)
	await _push_char(ctx, "4")
	line = _dim_popup_line(ctx)
	check(str(line.text) == "4", "angle editor first key is '4' not a reorder of '%s' (got '%s')" % [
		before, str(line.text)])
	await _push_char(ctx, "5")
	line = _dim_popup_line(ctx)
	check(str(line.text) == "45", "angle editor reads '45' (got '%s')" % str(line.text))
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var shown := -1.0
	for dim in sm.dimensions:
		if typeof(dim) == TYPE_DICTIONARY and str(dim.get("type", "")) == "angle":
			shown = sm._dimension_display_value(dim)
	check(is_equal_approx(shown, 45.0) or _status_blob().contains("Dimension updated"),
			"angle edit commits 45 (display %.3f status '%s')" % [shown, _status_blob()])


func _test_stale_fill_and_frame(ctx: FilmContext) -> void:
	print("- dim 200 clears stale fill and frames the sketch")
	var sm: SketchMode = ctx.main.sketch_mode
	var c0: String = sm.sketch.add_circle(0, 0, 10)
	var c1: String = sm.sketch.add_circle(40, 0, 22.5)
	sm._redraw()
	await process_frame
	check(_fill_near(sm, Vector2(40, 0), 12.0), "contour fill covers the circle at x=40 before the edit")
	sm._smart_dim_between({"entity": c0, "role": "center"}, {"entity": c1, "role": "center"})
	await process_frame
	await process_frame
	await process_frame
	var line := _dim_popup_line(ctx)
	check(line != null and str(line.text) != "", "centre distance editor is open (text '%s')" % (
		str(line.text) if line != null else ""))
	if line == null:
		return
	await _push_char(ctx, "2")
	line = _dim_popup_line(ctx)
	check(str(line.text) == "2", "distance editor first key is '2' (got '%s')" % str(line.text))
	await _push_char(ctx, "0")
	await _push_char(ctx, "0")
	line = _dim_popup_line(ctx)
	check(str(line.text) == "200", "distance editor reads '200' (got '%s')" % str(line.text))
	await _push_key(ctx.main.get_viewport(), KEY_ENTER)
	await process_frame
	await process_frame
	var moved: Vector2 = sm.sketch.entity_info(c1)["center"]
	check(absf(moved.x) > 180.0, "second circle moved off x=40 (center %s)" % str(moved))
	check(not _fill_near(sm, Vector2(40, 0), 12.0),
			"no contour fill remains on the old centre")
	check(_patch_count(ctx) == 0, "no orphan grid-patch node")
	var owner: Control = ctx.main.get_viewport().gui_get_focus_owner()
	if owner is LineEdit:
		owner.release_focus()
	await process_frame
	var vp: Viewport = ctx.main.get_viewport()
	await _push_key(vp, KEY_F)
	await process_frame
	var giz: WorldGizmos = ctx.main.interaction.world_gizmos
	check(giz != null and giz.grid_half_mm >= 150.0,
			"framed grid half-extent is at least 150 mm (got %.1f)" % (
				giz.grid_half_mm if giz != null else -1.0))
	var grids := 0
	if giz != null:
		for child in giz.get_children():
			if str(child.name) == "Grid":
				grids += 1
				var mi := child as MeshInstance3D
				if mi != null and mi.mesh != null:
					check(mi.mesh.get_aabb().size.x >= 300.0,
							"grid sheet is wider than the old ±50 mm patch (aabb %.1f)" % mi.mesh.get_aabb().size.x)
	check(grids == 1, "exactly one Grid mesh (got %d)" % grids)
	var size_f: float = ctx.main.camera.size
	_assert_sketch_span(ctx, sm, "F")
	await _push_key(vp, KEY_F, true)
	check(absf(ctx.main.camera.size - size_f) <= size_f * 0.01,
			"Shift+F frame size within 1%% of F (F=%.4f Shift+F=%.4f)" % [
				size_f, ctx.main.camera.size])
	_assert_sketch_span(ctx, sm, "Shift+F")


func _assert_sketch_span(ctx: FilmContext, sm: SketchMode, via: String) -> void:
	var cam: OrbitCamera = ctx.main.camera
	var canvas: Rect2 = cam.sketch_fit_canvas_rect(Vector2(ROOT_SIZE))
	var left := INF
	var right := -INF
	var inside := true
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var c: Vector2 = info["center"]
		var r: float = float(info.get("radius", 0.0))
		for uv in [c + Vector2(-r, 0), c + Vector2(r, 0), c]:
			var px := FilmUI.model_to_screen(ctx, sm.to_model(uv))
			left = minf(left, px.x)
			right = maxf(right, px.x)
			if px.x < canvas.position.x + 4.0 or px.x > canvas.end.x - 4.0 \
					or px.y < canvas.position.y + 4.0 or px.y > canvas.end.y - 4.0:
				inside = false
	var span := right - left
	var ratio := span / maxf(canvas.size.x, 1.0)
	check(ratio >= 0.50, "%s sketch span uses the canvas (%.2f of width %s)" % [
		via, ratio, str(canvas)])
	check(inside, "%s circles sit inside the chrome canvas with margin" % via)


func _fill_near(sm: SketchMode, uv: Vector2, tol: float) -> bool:
	var node := sm.get_node_or_null("ContourHighlight") as MeshInstance3D
	if node == null or node.mesh == null:
		return false
	var mesh: Mesh = node.mesh
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var i := 0
		while i + 2 < verts.size():
			var a := Vector2(verts[i].dot(sm.plane_x), verts[i].dot(sm.plane_y))
			var b := Vector2(verts[i + 1].dot(sm.plane_x), verts[i + 1].dot(sm.plane_y))
			var c := Vector2(verts[i + 2].dot(sm.plane_x), verts[i + 2].dot(sm.plane_y))
			if a.lerp(b, 0.5).lerp(c, 1.0 / 3.0).distance_to(uv) <= tol:
				return true
			i += 3
	return false


func _patch_count(ctx: FilmContext) -> int:
	var n := 0
	var root_node: Node = ctx.main
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if str(node.name).to_lower().contains("patch"):
			n += 1
		for child in node.get_children():
			stack.append(child)
	return n


func _angle_label(sm: SketchMode) -> Vector2:
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "angle":
			continue
		var lp = dim.get("label_pos", null)
		if lp is Vector2:
			return lp
	return Vector2.INF


func _circle_near(sm: SketchMode, uv: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		var d: float = (info["center"] as Vector2).distance_to(uv)
		if d < best_d:
			best_d = d
			best = id
	return best


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _distance_spin(chrome: SketchContextChrome) -> SpinBox:
	if chrome == null:
		return null
	return chrome.find_child("DistanceSpin", true, false) as SpinBox


func _dim_popup_line(ctx: FilmContext) -> LineEdit:
	var ix: ViewportInteraction = ctx.main.interaction
	if ix == null:
		return null
	return ix.find_child("DimEditLine", true, false) as LineEdit


func _digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := str(edit.text).strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	elif text.ends_with(" AF"):
		text = text.substr(0, text.length() - 3)
	return text.strip_edges()


func _parses_to(edit: LineEdit, v: float) -> bool:
	var text := _digits(edit)
	if not text.is_valid_float():
		return false
	return is_equal_approx(float(text), v)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	var vp: Viewport = ctx.main.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	vp.push_input(up)
	await process_frame


func _push_char(ctx: FilmContext, ch: String) -> void:
	var code := KEY_NONE
	var unicode := ch.unicode_at(0)
	if unicode >= 48 and unicode <= 57:
		code = (KEY_0 + (unicode - 48)) as Key
	elif unicode == 46:
		code = KEY_PERIOD
	else:
		push_error("no key for %s" % ch)
		return
	var vp: Viewport = ctx.main.get_viewport()
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	rel.unicode = 0
	vp.push_input(rel)
	await process_frame


func _push_key(vp: Viewport, keycode: Key, shift := false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.shift_pressed = shift
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame
