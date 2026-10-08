# sx-038 N4 — first canvas press after a rail Polygon / Circle / Slot arm
# places the centre in a face sketch. The AF blank is not the spin minimum
# 0.01, and the next typed digits replace it.
# Setup may use the sketch API. The rail press and the one canvas press are
# real Viewport.push_input mouse buttons.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_sx038_polypress.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("sx-038 first rail-armed centre press on a face sketch")
	FilmUI.reset_fail_count()
	await test_face_sketch_first_press()
	check(FilmUI.fail_count == 0, "FilmUI path stayed clean (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_face_sketch_first_press() -> void:
	var ctx := await _boot()
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	await process_frame
	var face := _top_face(ctx.view, body)
	check(face != "", "top face of the extruded blank")
	if face == "":
		await _shutdown(ctx)
		return
	ctx.main._start_sketch_on_face(face, body)
	await process_frame
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(sm != null and sm.active, "face sketch is active")
	var msg := str(ctx.main.status_label.text)
	check(msg.contains("Sketch on face (plane +Z @ origin 0.0,0.0,10.0)"),
			"plane message is top face z=10 (got '%s')" % msg)
	var end: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	check(end != null and end.get_item_text(end.selected) == "Blind",
			"finish bar end is Blind")
	check(op != null and op.get_item_text(op.selected) == "New",
			"finish bar op is New")
	var dist := _distance_text(chrome)
	check(dist.contains("20"), "finish bar distance shows 20 (got '%s')" % dist)
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return

	await _arm_and_centre(ctx, sm, chrome, "Polygon", Vector2(0, 0), true)
	await _arm_and_centre(ctx, sm, chrome, "Circle", Vector2(14, -4), false)
	await _arm_and_centre(ctx, sm, chrome, "Slot", Vector2(-12, 6), false)
	await _shutdown(ctx)


func _arm_and_centre(ctx: FilmContext, sm: SketchMode, chrome: SketchContextChrome,
		label: String, uv: Vector2, type_size: bool) -> void:
	print("- %s first centre press" % label)
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null and btn.is_visible_in_tree(), "%s rail button is visible" % label)
	if btn == null:
		return
	var rail_at := FilmUI.ensure_control_visible(btn)
	await process_frame
	await _x11_click_screen(ctx.main.get_viewport(), rail_at)
	await process_frame
	await process_frame
	check(sm.tool == _tool_for(label), "%s rail press arms the tool (got %s)" % [
		label, str(sm.tool)])
	check(sm._tool_points.is_empty(), "%s rail press does not place a centre" % label)
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, label + " centre"),
			"%s centre is on screen at %s" % [label, str(uv)])
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	await process_frame
	var pts: int = sm._tool_points.size()
	if pts != 1:
		_dump_miss(ctx, chrome, screen, label)
	check(pts == 1, "%s first canvas press sets the centre (points %d, disposition '%s')" % [
		label, pts, str(ctx.main.interaction.last_click_disposition)])
	var dim := _dim_edit(chrome)
	var text := dim.text if dim != null else ""
	check(not _is_spin_minimum(text),
			"%s size field is not 0.01 after the centre (got '%s')" % [label, text])
	if label == "Polygon":
		var hint := str(ctx.main.status_label.text)
		check(hint.contains("Polygon — click the centre, then a vertex"),
				"polygon centre keeps the arm hint until the pointer moves (got '%s')" % hint)
	if type_size and dim != null:
		check(dim.has_focus(), "polygon centre focuses the AF field")
		await _push_char(ctx, "2")
		dim = _dim_edit(chrome)
		check(_digits(dim) == "2", "first AF key is '2' (got '%s')" % _digits(dim))
		await _push_char(ctx, "0")
		dim = _dim_edit(chrome)
		check(_digits(dim) == "20", "AF reads '20' (got '%s')" % _digits(dim))


func _tool_for(label: String) -> int:
	match label:
		"Circle":
			return SketchMode.Tool.CIRCLE
		"Slot":
			return SketchMode.Tool.SLOT
		_:
			return SketchMode.Tool.POLYGON


func _is_spin_minimum(text: String) -> bool:
	var raw := text.strip_edges()
	if raw == "0.01" or raw.begins_with("0.01"):
		return true
	return false


func _dump_miss(ctx: FilmContext, chrome: SketchContextChrome, screen: Vector2, label: String) -> void:
	var ix: ViewportInteraction = ctx.main.interaction
	var who := ""
	if ix.has_method("_over_chrome_who"):
		who = str(ix._over_chrome_who(screen))
	var blocker := ""
	if ix.has_method("_press_blocker_name"):
		blocker = str(ix._press_blocker_name(screen))
	var hover: Control = ctx.main.get_viewport().gui_get_hovered_control()
	var focus: Control = ctx.main.get_viewport().gui_get_focus_owner()
	var shield: Control = ix.get("_finish_click_shield") as Control
	print("  miss %s screen=%s disposition=%s chrome=%s blocker=%s hover=%s focus=%s shield=%s dim='%s'" % [
		label, str(screen), str(ix.last_click_disposition), who, blocker,
		str(hover.name) if hover != null else "",
		str(focus.name) if focus != null else "",
		str(shield.visible) if shield != null else "none",
		_dim_edit(chrome).text if _dim_edit(chrome) != null else ""])


func _top_face(view: DocumentView, body: String) -> String:
	var best := ""
	var best_z := -INF
	if view.doc == null or not view.doc.has_method("get_face_ids"):
		return ""
	for fid in view.doc.get_face_ids(body):
		var mid: Variant = view.doc.face_midpoint(str(fid))
		if mid is Vector3 and (mid as Vector3).z > best_z:
			best_z = (mid as Vector3).z
			best = str(fid)
	return best


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	var spin: SpinBox = chrome.get("_dim_spin") as SpinBox
	if spin == null:
		return null
	return spin.get_line_edit()


func _distance_text(chrome: SketchContextChrome) -> String:
	var spin: SpinBox = chrome.get("_extrude_spin") as SpinBox
	if spin == null:
		return ""
	var edit := spin.get_line_edit()
	return edit.text if edit != null else ""


func _digits(edit: LineEdit) -> String:
	if edit == null:
		return ""
	var text := edit.text.strip_edges()
	if text.ends_with(" AF"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	return text.strip_edges()


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
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
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
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _push_char(ctx: FilmContext, ch: String) -> void:
	var unicode := ch.unicode_at(0)
	var code := (KEY_0 + (unicode - 48)) as Key
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
