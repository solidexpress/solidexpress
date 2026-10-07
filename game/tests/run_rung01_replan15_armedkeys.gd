# Rung 1 replan 15 WP1 — Enter in a Radius field keeps Fillet / Chamfer armed.
# Leftover 9 (sx-035 N2). Setup may place a box and select it; every click and
# key under test is a real Viewport.push_input event. The Fillet / Chamfer
# strip buttons are armed with FilmUI.click_control (same helper as focuskeys).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan15_armedkeys.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOP_PITCH := deg_to_rad(89.0)
const BACK_PITCH := 0.0
const BOTTOM_PITCH := deg_to_rad(-89.0)
const VIEW_EPS := 0.01
const ARMED_ENTER := "Fillet r=10.00 — edit Radius, click edges, Enter"
const CANCELLED := "No edges selected — cancelled"
const EDGE_PICK_CANCELLED := "Edge pick cancelled"

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
	print("rung01 replan15 WP1 Enter in Radius keeps Fillet armed")
	FilmUI.reset_fail_count()
	await _row_a1()
	await _row_a2()
	await _row_a3()
	await _row_a4()
	await _row_b1()
	await _row_b2()
	await _row_c1()
	await _row_c2()
	await _row_c3()
	await _row_d1()
	await _row_d2()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _st(main) -> String:
	return str(main.status_label.text)


func _strip(main) -> SpinBox:
	return main.interaction.find_child("StripRadius", true, false) as SpinBox


func _strip_text(main) -> String:
	var spin := _strip(main)
	if spin == null:
		return ""
	var le: LineEdit = spin.get_line_edit()
	return le.text if le != null else ""


func _panel_spin(main) -> SpinBox:
	return main.ops_panel._radius_spin as SpinBox


func _panel_text(main) -> String:
	var spin := _panel_spin(main)
	if spin == null:
		return ""
	var le: LineEdit = spin.get_line_edit()
	return le.text if le != null else ""


func _text_radius(text: String) -> float:
	var t := text.strip_edges().replace("mm", "").replace("MM", "").strip_edges()
	if t.is_valid_float():
		return float(t)
	return NAN


func _parses_to(text: String, want: float) -> bool:
	var got := _text_radius(text)
	return not is_nan(got) and is_equal_approx(got, want)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _push_key(vp: Viewport, code: int, unicode: int = 0, ctrl := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode if pressed else 0
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		ev.echo = false
		vp.push_input(ev)
		await process_frame
	await process_frame


func _click_at(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _spin_arrow_pos(spin: SpinBox, up: bool) -> Vector2:
	var r: Rect2 = spin.get_global_rect()
	var le: LineEdit = spin.get_line_edit()
	var x := r.position.x + r.size.x - 8.0
	if le != null:
		var lr: Rect2 = le.get_global_rect()
		x = maxf(lr.position.x + lr.size.x + 6.0, r.position.x + r.size.x - 10.0)
		x = minf(x, r.position.x + r.size.x - 4.0)
	var y := r.position.y + r.size.y * (0.22 if up else 0.78)
	return Vector2(x, y)


func _spin_text_pos(spin: SpinBox) -> Vector2:
	var r: Rect2 = spin.get_global_rect()
	return Vector2(r.position.x + minf(r.size.x * 0.35, r.size.x - 24.0), r.get_center().y)


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
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	if main.ops_panel != null and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _place_box(ctx: FilmContext) -> String:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	await process_frame
	if ctx.main.has_method("_update_panel_visibility"):
		ctx.main._update_panel_visibility()
	await process_frame
	return body


func _arm_fillet_strip(ctx: FilmContext) -> void:
	var fillet: Button = ctx.main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "StripFillet is visible")
	if fillet == null:
		return
	await FilmUI.click_control(ctx, fillet, FilmUICues.alert("Fillet", "Arm Fillet"))
	await process_frame
	await process_frame
	await process_frame


func _arm_chamfer_strip(ctx: FilmContext) -> void:
	var chamfer: Button = ctx.main.interaction.find_child("StripChamfer", true, false)
	check(chamfer != null and chamfer.is_visible_in_tree(), "StripChamfer is visible")
	if chamfer == null:
		return
	await FilmUI.click_control(ctx, chamfer, FilmUICues.alert("Chamfer", "Arm Chamfer"))
	await process_frame
	await process_frame
	await process_frame


func _assert_view(cam: OrbitCamera, pitch: float, status_needle: String, tag: String) -> void:
	check(absf(cam.pitch - pitch) < VIEW_EPS,
			"%s: camera pitch %.4f want %.4f" % [tag, cam.pitch, pitch])
	check(_status_has(status_needle),
			"%s: status log has %s (log_tail=`%s`)" % [tag, status_needle, _last_status()])


func _armed(main, pending: int, tag: String) -> void:
	check(main.ops_panel._pending == pending,
			"%s: pending is %s (got %s, status `%s`)" % [
				tag, str(pending), str(main.ops_panel._pending), _st(main)])
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "%s: strip R is visible" % tag)


func _type_replace(vp: Viewport, spin: SpinBox, digits: String) -> void:
	await _click_at(vp, _spin_text_pos(spin))
	await process_frame
	await _push_key(vp, KEY_A, 0, true)
	for i in digits.length():
		var ch := digits.unicode_at(i)
		var code := KEY_0 + (ch - 48)
		await _push_key(vp, code, ch)


func _fillet_count(view: DocumentView) -> int:
	var n := 0
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


func _top_edge_mid(view: DocumentView, body: String) -> Vector3:
	var lines: Dictionary = view.doc.get_edge_lines(body)
	var best := Vector3.ZERO
	var best_len := -1.0
	var best_z := -1e30
	var found := false
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) > 0.3:
			continue
		var mid: Vector3 = (pts[0] + pts[pts.size() - 1]) * 0.5
		var length := d.length()
		if not found or mid.z > best_z + 0.05 or (absf(mid.z - best_z) <= 0.05 and length > best_len):
			found = true
			best = mid
			best_z = mid.z
			best_len = length
	return best


func _fresh(tag: String) -> FilmContext:
	print("- %s" % tag)
	var ctx := await _boot()
	var body := await _place_box(ctx)
	check(body != "", "%s: box placed" % tag)
	return ctx


func _row_a1() -> void:
	var ctx := await _fresh("A1 arm strip Fillet, key 3 is Top, still armed")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "A1 after arm")
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_assert_view(main.camera, TOP_PITCH, "Top view", "A1")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "A1 after 3")
	await _shutdown(ctx)


func _row_a2() -> void:
	var ctx := await _fresh("A2 strip arrows then key 3")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "A2: strip R visible")
	if spin == null:
		await _shutdown(ctx)
		return
	await _click_at(vp, _spin_arrow_pos(spin, true))
	await process_frame
	await process_frame
	await _click_at(vp, _spin_arrow_pos(spin, false))
	await process_frame
	await process_frame
	await process_frame
	var after_arrows := _strip_text(main)
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_assert_view(main.camera, TOP_PITCH, "Top view", "A2")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "A2 after 3")
	check(_strip_text(main) == after_arrows,
			"A2: key 3 left the field text unchanged (before `%s` after `%s`)" % [
				after_arrows, _strip_text(main)])
	check(not _strip_text(main).contains("3"),
			"A2: no stray 3 in the strip (got `%s`)" % _strip_text(main))
	await _shutdown(ctx)


func _row_a3() -> void:
	var ctx := await _fresh("A3 strip type 10 Enter then key 4")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "A3: strip R visible")
	if spin == null:
		await _shutdown(ctx)
		return
	_status_log.clear()
	await _type_replace(vp, spin, "10")
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	var after_enter := _last_status()
	print("  A3 status after Enter: `%s` pending=%s strip=`%s`" % [
		after_enter, str(main.ops_panel._pending), _strip_text(main)])
	check(after_enter == ARMED_ENTER,
			"A3: status after Enter is `%s` (got `%s`)" % [ARMED_ENTER, after_enter])
	check(not _status_has("No edges selected"),
			"A3: No edges selected never appears before key 4 (log=%s)" % str(_status_log))
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "A3 after Enter")
	check(_strip_text(main).strip_edges().begins_with("10"),
			"A3: strip text starts with 10 (got `%s`)" % _strip_text(main))
	check(_parses_to(_panel_text(main), 10.0),
			"A3: panel parses to 10 (got `%s`)" % _panel_text(main))
	_status_log.clear()
	await _push_key(vp, KEY_4, 52)
	await process_frame
	await process_frame
	_assert_view(main.camera, BACK_PITCH, "Back view", "A3")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "A3 after 4")
	check(not _status_has("No edges selected"),
			"A3: No edges selected never appears (log=%s)" % str(_status_log))
	await _shutdown(ctx)


func _row_a4() -> void:
	var ctx := await _fresh("A4 strip type 10 Tab then key 4")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "A4: strip R visible")
	if spin == null:
		await _shutdown(ctx)
		return
	await _type_replace(vp, spin, "10")
	await _push_key(vp, KEY_TAB)
	await process_frame
	await process_frame
	await process_frame
	_status_log.clear()
	await _push_key(vp, KEY_4, 52)
	await process_frame
	await process_frame
	_assert_view(main.camera, BACK_PITCH, "Back view", "A4")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "A4 after Tab + 4")
	check(_strip_text(main).strip_edges().begins_with("10"),
			"A4: strip text starts with 10 (got `%s`)" % _strip_text(main))
	await _shutdown(ctx)


func _row_b1() -> void:
	var ctx := await _fresh("B1 panel Radius arrows then key 3")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var panel := _panel_spin(main)
	check(panel != null, "B1: panel Radius exists")
	if panel == null:
		await _shutdown(ctx)
		return
	FilmUI.ensure_control_visible(panel)
	await process_frame
	await process_frame
	await _click_at(vp, _spin_arrow_pos(panel, true))
	await process_frame
	await process_frame
	await _click_at(vp, _spin_arrow_pos(panel, false))
	await process_frame
	await process_frame
	await process_frame
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_assert_view(main.camera, TOP_PITCH, "Top view", "B1")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "B1 after 3")
	check(not _panel_text(main).contains("3"),
			"B1: panel has no stray 3 (got `%s`)" % _panel_text(main))
	await _shutdown(ctx)


func _row_b2() -> void:
	var ctx := await _fresh("B2 panel type 10 Enter then 4, 8, 3")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var panel := _panel_spin(main)
	check(panel != null, "B2: panel Radius exists")
	if panel == null:
		await _shutdown(ctx)
		return
	FilmUI.ensure_control_visible(panel)
	await process_frame
	await process_frame
	_status_log.clear()
	await _type_replace(vp, panel, "10")
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	var after_enter := _last_status()
	print("  B2 status after Enter: `%s` pending=%s panel=`%s` strip=`%s`" % [
		after_enter, str(main.ops_panel._pending), _panel_text(main), _strip_text(main)])
	check(after_enter == ARMED_ENTER,
			"B2: status after Enter is `%s` (got `%s`)" % [ARMED_ENTER, after_enter])
	check(not _status_has("No edges selected"),
			"B2: No edges selected never appears (log=%s)" % str(_status_log))
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "B2 after Enter")
	check(_parses_to(_strip_text(main), 10.0),
			"B2: strip parses to 10 (got `%s`)" % _strip_text(main))
	check(_parses_to(_panel_text(main), 10.0),
			"B2: panel parses to 10 (got `%s`)" % _panel_text(main))
	_status_log.clear()
	await _push_key(vp, KEY_4, 52)
	await process_frame
	await process_frame
	_assert_view(main.camera, BACK_PITCH, "Back view", "B2")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "B2 after 4")
	await _push_key(vp, KEY_8, 56)
	await process_frame
	await process_frame
	_assert_view(main.camera, BOTTOM_PITCH, "Bottom view", "B2")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "B2 after 8")
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_assert_view(main.camera, TOP_PITCH, "Top view", "B2")
	_armed(main, OpsPanel.Pending.FILLET_EDGES, "B2 after 3")
	check(_parses_to(_strip_text(main), 10.0) and _parses_to(_panel_text(main), 10.0),
			"B2: strip and panel still parse 10 (strip `%s` panel `%s`)" % [
				_strip_text(main), _panel_text(main)])
	await _shutdown(ctx)


func _row_c1() -> void:
	var ctx := await _fresh("C1 Enter applies when an edge is picked")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var view: DocumentView = ctx.view
	await _arm_fillet_strip(ctx)
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_assert_view(main.camera, TOP_PITCH, "Top view", "C1")
	var body := str(view.selected_body)
	var mid := _top_edge_mid(view, body)
	var screen := FilmUI.model_to_screen(ctx, mid)
	check(FilmUI.require_on_screen(ctx, screen, "top edge midpoint"),
			"C1: top-edge midpoint is on screen (%s)" % str(screen))
	var before := _fillet_count(view)
	await _click_at(vp, screen)
	await process_frame
	await process_frame
	check(not view.selected_edges.is_empty() or view.selected_edge != "",
			"C1: click armed an edge (edges %s edge `%s`)" % [
				str(view.selected_edges), view.selected_edge])
	var spin := _strip(main)
	if spin != null:
		_status_log.clear()
		await _type_replace(vp, spin, "1")
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
		await process_frame
	var applied := false
	for s in _status_log:
		if s.begins_with("Fillet edge 1.00 applied") or s.begins_with("Fillet 1 edges 1.00 applied"):
			applied = true
	print("  C1 status after Enter: `%s` pending=%s log=%s" % [
		_last_status(), str(main.ops_panel._pending), str(_status_log)])
	check(applied, "C1: status starts Fillet edge/1 edges 1.00 applied (log=%s)" % str(_status_log))
	check(_fillet_count(view) == before + 1,
			"C1: one fillet feature added (before %d after %d)" % [before, _fillet_count(view)])
	check(main.ops_panel._pending == OpsPanel.Pending.NONE,
			"C1: apply disarms (pending %s)" % str(main.ops_panel._pending))
	await _shutdown(ctx)


func _row_c2() -> void:
	var ctx := await _fresh("C2 viewport Enter with nothing picked still cancels")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	# Top-right y=110 used to land on the wrapped selection strip (AF chips made
	# it two rows). Without those chips the pixel is on the solid. The status
	# bar is chrome, so the click focuses nothing and picks no edge.
	var empty := Vector2(400.0, float(ROOT_SIZE.y) - 12.0)
	await _click_at(vp, empty)
	await process_frame
	await process_frame
	check(main.view.selected_edges.is_empty() and main.view.selected_edge == "",
			"C2: empty canvas picked no edge (edges %s)" % str(main.view.selected_edges))
	_status_log.clear()
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	print("  C2 status after viewport Enter: `%s` pending=%s" % [
		_last_status(), str(main.ops_panel._pending)])
	check(main.ops_panel._pending == OpsPanel.Pending.NONE,
			"C2: viewport Enter disarms (pending %s)" % str(main.ops_panel._pending))
	check(_last_status() == CANCELLED or _status_has(CANCELLED),
			"C2: status is `%s` (got `%s` log=%s)" % [CANCELLED, _last_status(), str(_status_log)])
	await _shutdown(ctx)


func _row_c3() -> void:
	var ctx := await _fresh("C3 Chamfer strip type 2 Enter then key 3")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_chamfer_strip(ctx)
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "C3: strip R visible")
	if spin == null:
		await _shutdown(ctx)
		return
	await _type_replace(vp, spin, "2")
	await _push_key(vp, KEY_ENTER)
	await process_frame
	await process_frame
	await process_frame
	print("  C3 status after Enter: `%s` pending=%s" % [
		_last_status(), str(main.ops_panel._pending)])
	_armed(main, OpsPanel.Pending.CHAMFER_EDGES, "C3 after Enter")
	_status_log.clear()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	_assert_view(main.camera, TOP_PITCH, "Top view", "C3")
	_armed(main, OpsPanel.Pending.CHAMFER_EDGES, "C3 after 3")
	await _shutdown(ctx)


func _row_d1() -> void:
	var ctx := await _fresh("D1 second Fillet press after a Radius Enter still cancels")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var spin := _strip(main)
	if spin != null:
		await _type_replace(vp, spin, "10")
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
		await process_frame
	print("  D1 before second press: pending=%s status=`%s`" % [
		str(main.ops_panel._pending), _last_status()])
	var fillet: Button = main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "D1: StripFillet visible for the second press")
	if fillet != null:
		_status_log.clear()
		await _click_at(vp, fillet.get_global_rect().get_center())
		await process_frame
		await process_frame
		await process_frame
	print("  D1 after second press: pending=%s status=`%s`" % [
		str(main.ops_panel._pending), _last_status()])
	check(main.ops_panel._pending == OpsPanel.Pending.NONE,
			"D1: second Fillet press disarms (pending %s)" % str(main.ops_panel._pending))
	check(_last_status() == CANCELLED or _status_has(CANCELLED),
			"D1: status is `%s` (got `%s` log=%s)" % [CANCELLED, _last_status(), str(_status_log)])
	await _shutdown(ctx)


func _row_d2() -> void:
	var ctx := await _fresh("D2 Esc with the Radius field focused clears the armed fillet")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	await _arm_fillet_strip(ctx)
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "D2: strip R visible")
	if spin != null:
		await _type_replace(vp, spin, "10")
		await _push_key(vp, KEY_ENTER)
		await process_frame
		await process_frame
		await _click_at(vp, _spin_text_pos(spin))
		await process_frame
	print("  D2 before Esc: pending=%s focus=%s" % [
		str(main.ops_panel._pending), str(vp.gui_get_focus_owner())])
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE)
	await process_frame
	await process_frame
	if main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES:
		await _push_key(vp, KEY_ESCAPE)
		await process_frame
		await process_frame
	print("  D2 after Esc: pending=%s status=`%s`" % [
		str(main.ops_panel._pending), _last_status()])
	check(main.ops_panel._pending == OpsPanel.Pending.NONE,
			"D2: Esc cleared the armed fillet within two presses (pending %s)" % str(main.ops_panel._pending))
	check(_status_has(EDGE_PICK_CANCELLED),
			"D2: status is Edge pick cancelled (log=%s label=`%s`)" % [str(_status_log), _st(main)])
	await _shutdown(ctx)
