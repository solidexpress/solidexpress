# Rung 1 replan 15 WP6 — chain-break status, view key 0, `applied` wording,
# Jaw-armed label click. Setup may use the sketch / document API and FilmUI.
# Every key and click under test is a real Viewport.push_input event.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan15_strings.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const VIEW_EPS := 0.0001
const NO_VIEW := "No view for key 0 — use 1 2 3 4 6 7 8"
const LINE_AT := "^Line at \\(-?\\d+\\.\\d, -?\\d+\\.\\d\\) breaks the chain — delete or trim it$"
const ARC_AT := "^Arc at \\(-?\\d+\\.\\d, -?\\d+\\.\\d\\) breaks the chain — delete or trim it$"
const UUID_RE := "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-"
const FILLET_APPLIED := "^Fillet \\d+ edges? 1\\.00 applied"
const CHAMFER_APPLIED := "^Chamfer \\d+ edges? 1\\.00 applied"

var _status_log: Array[String] = []
var _line_re := RegEx.new()
var _arc_re := RegEx.new()
var _uuid_re := RegEx.new()
var _fillet_re := RegEx.new()
var _chamfer_re := RegEx.new()


func _init() -> void:
	print("rung01 replan15 WP6 strings")
	_line_re.compile(LINE_AT)
	_arc_re.compile(ARC_AT)
	_uuid_re.compile(UUID_RE)
	_fillet_re.compile(FILLET_APPLIED)
	_chamfer_re.compile(CHAMFER_APPLIED)
	await _row_s1a()
	await _row_s1b()
	await _row_s1d()
	await _row_s2()
	await _row_s3a()
	await _row_s3b()
	await _row_s3c()
	await _row_s4()
	finish()


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


func _capture(main) -> void:
	if main == null or main.status_label == null:
		return
	var t := str(main.status_label.text).strip_edges()
	if t == "" or t.begins_with("empty-drag"):
		return
	if not _status_log.has(t):
		_status_log.append(t)


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _dump(tag: String) -> void:
	print("  %s status log (%d):" % [tag, _status_log.size()])
	for s in _status_log:
		print("    | " + s)


func _log_matches(re: RegEx) -> bool:
	for s in _status_log:
		if re.search(s) != null:
			return true
	return false


func _log_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _log_since_has(start: int, needle: String) -> bool:
	for i in range(start, _status_log.size()):
		if _status_log[i].contains(needle):
			return true
	return false


func _count_type(doc, type_name: String) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == type_name:
			n += 1
	return n


func _top_face(doc, body: String) -> String:
	var best := ""
	var best_z := -1.0e9
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = bb["max"] - bb["min"]
		if ext.z > 0.05:
			continue
		var z: float = (bb["max"] as Vector3).z
		if z > best_z:
			best_z = z
			best = str(fid)
	return best


func _place_box(ctx: FilmContext) -> String:
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	await process_frame
	return body


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
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


func _click_control(vp: Viewport, ctrl: Control) -> void:
	if ctrl == null:
		return
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(vp, pos)
	await process_frame


func _click_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _push_key(vp: Viewport, code: int, unicode: int = 0, ctrl := false, alt := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.unicode = unicode if pressed else 0
		ev.ctrl_pressed = ctrl
		ev.alt_pressed = alt
		ev.pressed = pressed
		ev.echo = false
		vp.push_input(ev)
		await process_frame
	await process_frame


func _type_distance_2(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var edit: LineEdit = chrome.find_child("DistanceLineEdit", true, false)
	check(edit != null, "DistanceLineEdit exists")
	if edit == null:
		return
	await _click_control(edit.get_viewport(), edit)
	await process_frame
	await process_frame
	await _push_key(edit.get_viewport(), KEY_2, 50)
	await process_frame
	_capture(ctx.main)
	print("  distance field `%s` spin %.4f" % [edit.text, chrome.extrude_distance()])


func _arm_cut_blind(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.set_finish_op("cut")
	chrome.set_finish_end("blind")
	await _type_distance_2(ctx)


func _press_extrude(ctx: FilmContext) -> void:
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	check(btn != null and btn.is_visible_in_tree(), "Extrude button is visible")
	if btn == null:
		return
	_status_log.clear()
	await _click_control(btn.get_viewport(), btn)
	await process_frame
	await process_frame
	await process_frame
	_capture(ctx.main)


func _open_face_sketch(ctx: FilmContext, body: String) -> SketchMode:
	var top := _top_face(ctx.view.doc, body)
	check(top != "", "top face found")
	if top == "":
		return null
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "face sketch is active")
	return sm


func _row_s1a() -> void:
	print("- S1a open line chain, Cut, real Extrude click")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	check(body != "", "S1a box placed")
	var sm := await _open_face_sketch(ctx, body)
	if sm == null or sm.sketch == null:
		await _shutdown(ctx)
		return
	var before := _count_type(ctx.view.doc, "extrude")
	sm.sketch.add_line(-8.0, -4.0, 8.0, -4.0)
	sm.sketch.add_line(8.0, -4.0, 8.0, 4.0)
	sm.sketch.add_line(8.0, 4.0, -8.0, 4.0)
	await _arm_cut_blind(ctx)
	await _press_extrude(ctx)
	_dump("S1a")
	check(_log_matches(_line_re),
			"S1a status is Line at (x, y) breaks the chain — delete or trim it (log above)")
	check(not _log_matches(_uuid_re), "S1a no UUID in the status log")
	check(sm.active, "S1a sketch stays open")
	check(_count_type(ctx.view.doc, "extrude") == before, "S1a no new extrude")
	await _shutdown(ctx)


func _row_s1b() -> void:
	print("- S1b open arc chain, Cut, real Extrude click")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	var sm := await _open_face_sketch(ctx, body)
	if sm == null or sm.sketch == null:
		await _shutdown(ctx)
		return
	var before := _count_type(ctx.view.doc, "extrude")
	sm.sketch.add_arc(0.0, 0.0, 8.0, 0.0, PI * 0.5)
	sm.sketch.add_line(0.0, 8.0, 0.0, 14.0)
	await _arm_cut_blind(ctx)
	await _press_extrude(ctx)
	_dump("S1b")
	check(_log_matches(_arc_re),
			"S1b status is Arc at (x, y) breaks the chain — delete or trim it (log above)")
	check(not _log_matches(_uuid_re), "S1b no UUID in the status log")
	check(sm.active, "S1b sketch stays open")
	check(_count_type(ctx.view.doc, "extrude") == before, "S1b no new extrude")
	await _shutdown(ctx)


func _row_s1d() -> void:
	print("- S1d closed profile Cut commits")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	var sm := await _open_face_sketch(ctx, body)
	if sm == null or sm.sketch == null:
		await _shutdown(ctx)
		return
	var before := _count_type(ctx.view.doc, "extrude")
	sm.sketch.add_line(-8.0, -4.0, 8.0, -4.0)
	sm.sketch.add_line(8.0, -4.0, 8.0, 4.0)
	sm.sketch.add_line(8.0, 4.0, -8.0, 4.0)
	sm.sketch.add_line(-8.0, 4.0, -8.0, -4.0)
	check(SketchMode.profile_is_closed(sm.sketch), "S1d profile is closed")
	await _arm_cut_blind(ctx)
	await _press_extrude(ctx)
	_dump("S1d")
	check(not _log_has("breaks the chain"), "S1d no chain-break status")
	check(_log_has("Extrude Blind 2.0000 mm"),
			"S1d status is Extrude Blind 2.0000 mm")
	check(not sm.active, "S1d sketch closed")
	check(_count_type(ctx.view.doc, "extrude") == before + 1, "S1d one new extrude")
	await _shutdown(ctx)


func _row_s2() -> void:
	print("- S2 key 0")
	var ctx := await _boot()
	var body := await _place_box(ctx)
	check(body != "", "S2 box placed")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var cam: OrbitCamera = main.camera
	check(main.sketch_mode == null or not main.sketch_mode.active, "S2a sketch inactive")
	var owner := vp.gui_get_focus_owner()
	check(not (owner is LineEdit), "S2a nothing focused in a LineEdit")
	var yaw0 := cam.yaw
	var pitch0 := cam.pitch
	var n0 := _status_log.size()
	await _push_key(vp, KEY_0, 48)
	_capture(main)
	_dump("S2a")
	check(_log_since_has(n0, NO_VIEW), "S2a status is `%s`" % NO_VIEW)
	check(absf(cam.yaw - yaw0) < VIEW_EPS and absf(cam.pitch - pitch0) < VIEW_EPS,
			"S2a camera yaw/pitch unchanged (dyaw %.6f dpitch %.6f)" % [
				cam.yaw - yaw0, cam.pitch - pitch0])
	var n3 := _status_log.size()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	_capture(main)
	check(_log_since_has(n3, "Top view"), "S2b status is Top view")
	var nmod := _status_log.size()
	await _push_key(vp, KEY_0, 48, true, false)
	await _push_key(vp, KEY_0, 48, false, true)
	_capture(main)
	check(not _log_since_has(nmod, NO_VIEW), "S2e Ctrl+0 and Alt+0 do not print the key 0 status")
	await _row_s2c(ctx)
	await _shutdown(ctx)
	await _row_s2d()


func _row_s2c(ctx: FilmContext) -> void:
	print("- S2c key 0 into a focused numeric field")
	var main = ctx.main
	var vp: Viewport = main.get_viewport()
	var fillet: Button = main.interaction.find_child("StripFillet", true, false)
	check(fillet != null and fillet.is_visible_in_tree(), "S2c StripFillet is visible")
	if fillet == null:
		return
	await _click_control(vp, fillet)
	await process_frame
	var spin: SpinBox = main.interaction.find_child("StripRadius", true, false)
	check(spin != null and spin.is_visible_in_tree(), "S2c StripRadius is visible")
	if spin == null:
		return
	var edit := spin.get_line_edit()
	await _click_control(vp, edit)
	await process_frame
	await _push_key(vp, KEY_A, 0, true, false)
	var before := edit.text
	var n := _status_log.size()
	await _push_key(vp, KEY_0, 48)
	_capture(main)
	print("  S2c field before `%s` after `%s`" % [before, edit.text])
	check(not _log_since_has(n, NO_VIEW), "S2c no key 0 view status")
	check(edit.text.contains("0") and edit.text != before, "S2c the digit 0 appears in the field (`%s`)" % edit.text)


func _row_s2d() -> void:
	print("- S2d sketch circle rubber-band keys 1 and 0")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "S2d sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	var circle: Button = ctx.main.find_child("ToolCircle", true, false)
	check(circle != null, "S2d Circle tool button exists")
	if circle != null:
		await _click_control(circle.get_viewport(), circle)
		await process_frame
	check(sm.tool == SketchMode.Tool.CIRCLE, "S2d Circle tool is armed")
	await _click_uv(ctx, Vector2.ZERO)
	await process_frame
	await process_frame
	check(sm.has_single_dof_preview(), "S2d circle centre is placed (rubber-band)")
	var n := _status_log.size()
	var vp: Viewport = ctx.main.get_viewport()
	await _push_key(vp, KEY_1, 49)
	await _push_key(vp, KEY_0, 48)
	await process_frame
	_capture(ctx.main)
	var dim: LineEdit = ctx.main.sketch_chrome.find_child("DimLineEdit", true, false)
	var shown := dim.text if dim != null else ""
	print("  S2d dim blank `%s`" % shown)
	_dump("S2d")
	check(shown.contains("10"), "S2d dim blank shows 10 (got `%s`)" % shown)
	check(not _log_since_has(n, NO_VIEW), "S2d no key 0 view status")
	var wording := _log_since_has(n, "Circle r=10") or _log_has("Circle — centre set") \
			or _log_has("Circle r=")
	check(wording, "S2d status is Circle r=10 or the existing circle wording")
	await _shutdown(ctx)


func _arm_strip(ctx: FilmContext, which: String) -> void:
	var btn: Button = ctx.main.interaction.find_child(which, true, false)
	check(btn != null and btn.is_visible_in_tree(), "%s is visible" % which)
	if btn == null:
		return
	await _click_control(btn.get_viewport(), btn)
	await process_frame
	await process_frame


func _dressup_face(kind: String, button_name: String, re: RegEx, feat: String) -> void:
	print("- %s" % kind)
	var ctx_ok := await _boot()
	var body := await _place_box(ctx_ok)
	check(body != "", "%s box placed" % kind)
	await _arm_strip(ctx_ok, button_name)
	var vp: Viewport = ctx_ok.main.get_viewport()
	await _push_key(vp, KEY_3, 51)
	await process_frame
	await process_frame
	var hit := FilmUI.model_to_screen(ctx_ok, Vector3(0, 0, 10))
	print("  %s top-face screen %s" % [kind, str(hit)])
	var before := _count_type(ctx_ok.view.doc, feat)
	await _x11_click_screen(vp, hit)
	await process_frame
	await process_frame
	var spin: SpinBox = ctx_ok.main.interaction.find_child("StripRadius", true, false)
	check(spin != null and spin.is_visible_in_tree(), "%s StripRadius visible" % kind)
	if spin != null:
		var edit := spin.get_line_edit()
		await _click_control(vp, edit)
		await process_frame
		await _push_key(vp, KEY_A, 0, true, false)
		await _push_key(vp, KEY_1, 49)
		await process_frame
		print("  %s radius field `%s`" % [kind, edit.text])
		_status_log.clear()
		await _push_key(vp, KEY_ENTER, 0)
		await process_frame
		await process_frame
		# Field Enter commits the radius. A second Enter, viewport focused, applies.
		if ctx_ok.main.ops_panel._pending != OpsPanel.Pending.NONE:
			ctx_ok.main.interaction.return_viewport_keys()
			await process_frame
			await _push_key(vp, KEY_ENTER, 0)
		for _i in 12:
			await process_frame
		_capture(ctx_ok.main)
	_dump(kind)
	check(_log_matches(re), "%s status matches applied 1.00 (log above)" % kind)
	check(not _log_has("Feature created"), "%s never says Feature created" % kind)
	check(_count_type(ctx_ok.view.doc, feat) == before + 1, "%s one %s feature" % [kind, feat])
	await _shutdown(ctx_ok)


func _row_s3a() -> void:
	await _dressup_face("S3a", "StripFillet", _fillet_re, "fillet")


func _row_s3b() -> void:
	await _dressup_face("S3b", "StripChamfer", _chamfer_re, "chamfer")


func _row_s3c() -> void:
	print("- S3c ground rectangle extrude is not applied")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active and sm.sketch != null, "S3c ground sketch")
	if sm == null or sm.sketch == null:
		await _shutdown(ctx)
		return
	sm.sketch.add_line(-10.0, -6.0, 10.0, -6.0)
	sm.sketch.add_line(10.0, -6.0, 10.0, 6.0)
	sm.sketch.add_line(10.0, 6.0, -10.0, 6.0)
	sm.sketch.add_line(-10.0, 6.0, -10.0, -6.0)
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	check(btn != null, "S3c Extrude button exists")
	if btn != null:
		_status_log.clear()
		await _click_control(btn.get_viewport(), btn)
		await process_frame
		await process_frame
		await process_frame
		_capture(ctx.main)
	_dump("S3c")
	check(_log_has("Extrude Blind") and _log_has(" mm"), "S3c status is Extrude Blind … mm")
	check(not _log_has("applied"), "S3c status does not say applied")
	await _shutdown(ctx)


func _label_rects(sm: SketchMode) -> Array:
	if sm != null and sm.has_method("dimension_label_screen_rects"):
		return sm.dimension_label_screen_rects()
	return []


func _label_matches(text: String, needle: String) -> bool:
	if text == needle:
		return true
	var raw := text.trim_suffix("°")
	var want := needle.trim_suffix("°")
	return want.is_valid_float() and raw.is_valid_float() \
			and absf(float(raw) - float(want)) <= 0.05 \
			and text.ends_with("°") == needle.ends_with("°")


func _label_first_glyph(sm: SketchMode, needle: String) -> Vector2:
	for r in _label_rects(sm):
		if not _label_matches(str(r.get("text", "")), needle):
			continue
		var rect: Rect2 = r["rect"]
		return Vector2(rect.position.x + minf(6.0, rect.size.x * 0.25), rect.get_center().y)
	return Vector2.INF


func _on_screen(p: Vector2) -> bool:
	return p.x >= 4.0 and p.y >= 4.0 and p.x <= float(ROOT_SIZE.x) - 4.0 \
			and p.y <= float(ROOT_SIZE.y) - 4.0


func _hits_any_label(sm: SketchMode, screen: Vector2) -> bool:
	for r in _label_rects(sm):
		var rect: Rect2 = r["rect"]
		if rect.grow(4.0).has_point(screen):
			return true
	return false


func _editor_near(line: LineEdit, want: float) -> bool:
	if line == null:
		return false
	var t := str(line.text).strip_edges().trim_suffix("°")
	return t.is_valid_float() and absf(float(t) - want) <= 0.05


func _row_s4() -> void:
	print("- S4 Jaw armed, label click opens the editor")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "S4 ground sketch is active")
	if sm == null or not sm.active:
		await _shutdown(ctx)
		return
	sm.snap_enabled = false
	var jaw: Button = ctx.main.find_child("JawTool", true, false)
	check(jaw != null and jaw.is_visible_in_tree(), "S4 Jaw tool button is visible")
	if jaw == null:
		await _shutdown(ctx)
		return
	await _click_control(jaw.get_viewport(), jaw)
	await process_frame
	check(sm.is_jaw_armed(), "S4 Jaw is armed")
	var dir := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var ctr := Vector2.ZERO
	await _click_uv(ctx, ctr)
	await process_frame
	await _click_uv(ctx, ctr + dir * 30.0)
	await process_frame
	await _click_uv(ctx, ctr + Vector2(-dir.y, dir.x) * 10.0)
	await process_frame
	await process_frame
	_capture(ctx.main)
	_dump("S4 commit")
	check(_log_has("Jaw committed"), "S4 commit status is Jaw committed (log above)")
	var n_ent := sm.sketch.entity_ids().size()
	var ix: ViewportInteraction = ctx.main.interaction
	await _assert_label_edit(ctx, sm, ix, "20", 20.0, n_ent)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	check(ix == null or not ix._dim_edit_owns_keys(), "S4 Esc closes the width editor")
	await _assert_label_edit(ctx, sm, ix, "45°", 45.0, n_ent)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	check(ix == null or not ix._dim_edit_owns_keys(), "S4 Esc closes the angle editor")
	check(sm.is_jaw_armed(), "S4 Jaw is still armed")
	var n4 := _status_log.size()
	var away := await _click_away_from_labels(ctx, sm)
	_capture(ctx.main)
	_dump("S4 fourth")
	var started := false
	for i in range(n4, _status_log.size()):
		if _status_log[i].begins_with("Jaw — centre set"):
			started = true
	check(away and started, "S4 fourth click starts a new Jaw (Jaw — centre set)")
	await _shutdown(ctx)


func _assert_label_edit(ctx: FilmContext, sm: SketchMode, ix: ViewportInteraction,
		needle: String, want: float, n_ent: int) -> void:
	var hit := _label_first_glyph(sm, needle)
	print("  S4 glyph `%s` at %s" % [needle, str(hit)])
	check(hit != Vector2.INF and _on_screen(hit), "S4 first glyph of `%s` is on screen" % needle)
	if hit == Vector2.INF or not _on_screen(hit):
		return
	var n := _status_log.size()
	await _x11_click_screen(ctx.main.get_viewport(), hit)
	await process_frame
	await process_frame
	await process_frame
	_capture(ctx.main)
	var popup_up := ix != null and ix._dim_edit_popup != null and ix._dim_edit_popup.visible
	var line: LineEdit = ix._dim_edit_line if ix != null else null
	var shown := line.text if line != null else ""
	print("  S4 editor `%s` visible=%s" % [shown, str(popup_up)])
	check(popup_up, "S4 click on `%s` opens the dimension editor" % needle)
	check(_editor_near(line, want), "S4 editor line shows %s (got `%s`)" % [needle, shown])
	check(sm.sketch.entity_ids().size() == n_ent, "S4 entity count unchanged after `%s`" % needle)
	var started := false
	for i in range(n, _status_log.size()):
		if _status_log[i].begins_with("Jaw — centre set"):
			started = true
	check(not started, "S4 `%s` click does not start a new Jaw" % needle)


func _click_away_from_labels(ctx: FilmContext, sm: SketchMode) -> bool:
	# Near the committed jaw, on the same plane the three commit clicks hit,
	# and clear of every label rect.
	var spots: Array[Vector2] = [
		Vector2(40, -25), Vector2(-30, 20), Vector2(0, -30), Vector2(35, 35),
	]
	for uv in spots:
		var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
		print("  S4 away uv %s screen %s" % [str(uv), str(screen)])
		if not _on_screen(screen) or _hits_any_label(sm, screen):
			continue
		var n := _status_log.size()
		await _x11_click_screen(ctx.main.get_viewport(), screen)
		await process_frame
		await process_frame
		_capture(ctx.main)
		for i in range(n, _status_log.size()):
			if _status_log[i].begins_with("Jaw — centre set"):
				return true
	return false
