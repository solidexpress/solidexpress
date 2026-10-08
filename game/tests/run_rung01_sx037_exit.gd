# sx-037 A6 / N4 / N14 — leaving a sketch (cancel or save) ends a pending Up To
# Surface face pick and does not leave the sketch host face selected. After
# Extrude refuses, the next Esc is the exit ladder and the one after saves.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_sx037_exit.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const FIRST_DROP := "First point dropped — Esc again exits the sketch"
const FACE_PICK_CANCEL := "Up To Surface face pick cancelled"
const SEL_CLEARED := "Selection cleared"

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
	print("rung01 sx-037 sketch exit drops host face and Up To Surface pick")
	FilmUI.reset_fail_count()
	await test_cancel_drops_host_and_face_pick()
	await test_save_drops_host_and_face_pick()
	await test_extrude_refusal_esc_ladder()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_cancel_drops_host_and_face_pick() -> void:
	print("- A6 cancel: host face and Up To Surface pick do not survive")
	var ctx := await _boot()
	var body := await _box_body(ctx)
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	if top == "" or body == "":
		await _shutdown(ctx)
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(sm.active, "face sketch is open")
	check(ctx.view.selected_face == top, "host face is selected while sketching")
	await _zoom(ctx, sm.to_model(Vector2(8, 8)), 80.0)
	_arm_cut_up_to_surface(chrome)
	await process_frame
	check(chrome.get_finish_end() == "to_face", "End is Up To Surface")
	check(chrome.wants_face_pick() and not chrome.face_pick_explicit(),
			"Up To Surface arms a pending face pick")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2(8, 8))
	check(sm.has_pending_draw_point(), "circle centre is pending")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE, false, false)
	check(sm.active, "first Esc keeps the sketch")
	check(_status_has(FIRST_DROP) or str(ctx.main.status_label.text) == FIRST_DROP,
			"first Esc drops the point (got `%s`)" % ctx.main.status_label.text)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	await process_frame
	check(not sm.active, "second Esc cancels the sketch")
	check(str(ctx.main.status_label.text) == "Sketch cancelled",
			"status is Sketch cancelled (got `%s`)" % ctx.main.status_label.text)
	_assert_part_mode_clean(ctx, top, "cancel")
	_status_log.clear()
	_release_focus(vp)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	check(str(ctx.main.status_label.text) == "Sketch cancelled",
			"part-mode Esc with nothing selected leaves the status (got `%s`)" % ctx.main.status_label.text)
	check(not _status_has(FACE_PICK_CANCEL) and not _status_has(SEL_CLEARED),
			"part-mode Esc did not cancel a face pick or clear a selection (log: %s)" % str(_status_log))
	ctx.view.select_entity(body, top)
	await process_frame
	check(ctx.view.selected_face == top, "a later click can select the host face again")
	_status_log.clear()
	_release_focus(vp)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	check(ctx.view.selected_face == "" and ctx.view.selected_body == "",
			"Esc clears the face the user selected after the sketch")
	check(_status_has(SEL_CLEARED) or str(ctx.main.status_label.text) == SEL_CLEARED,
			"that Esc says Selection cleared (got `%s`)" % ctx.main.status_label.text)
	check(not _status_has(FACE_PICK_CANCEL) and str(ctx.main.status_label.text) != FACE_PICK_CANCEL,
			"that Esc is not a leftover Up To Surface cancel")
	await _shutdown(ctx)


func test_save_drops_host_and_face_pick() -> void:
	print("- N4 save: host face and Up To Surface pick do not survive")
	var ctx := await _boot()
	var body := await _box_body(ctx)
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	if top == "" or body == "":
		await _shutdown(ctx)
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(sm.active, "face sketch is open")
	check(ctx.view.selected_face == top, "host face is selected while sketching")
	await _zoom(ctx, sm.to_model(Vector2(10, 6)), 90.0)
	_arm_cut_up_to_surface(chrome)
	await process_frame
	check(chrome.wants_face_pick(), "Up To Surface is armed before the save exit")
	var before := _count_type(ctx, "sketch")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv(ctx, vp, Vector2(4, 4))
	await _click_uv(ctx, vp, Vector2(18, 4))
	await process_frame
	check(sm.sketch != null and not sm.sketch.entity_ids().is_empty(),
			"line is committed geometry")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2(8, 12))
	check(sm.has_pending_draw_point(), "circle centre is pending on the saved sketch")
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE, false, false)
	check(sm.active, "first Esc keeps the sketch")
	check(_status_has(FIRST_DROP) or str(ctx.main.status_label.text) == FIRST_DROP,
			"first Esc drops the point (got `%s`)" % ctx.main.status_label.text)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	await process_frame
	check(not sm.active, "second Esc leaves the sketch")
	check(str(ctx.main.status_label.text) == "Sketch saved",
			"status is Sketch saved (got `%s`)" % ctx.main.status_label.text)
	check(_count_type(ctx, "sketch") == before + 1, "save added the sketch feature")
	_assert_part_mode_clean(ctx, top, "save")
	_status_log.clear()
	_release_focus(vp)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	check(str(ctx.main.status_label.text) == "Sketch saved",
			"part-mode Esc with nothing selected leaves Sketch saved (got `%s`)" % ctx.main.status_label.text)
	check(not _status_has(FACE_PICK_CANCEL) and not _status_has(SEL_CLEARED),
			"part-mode Esc did not cancel a face pick or clear a selection (log: %s)" % str(_status_log))
	await _shutdown(ctx)


func test_extrude_refusal_esc_ladder() -> void:
	print("- N14 refusal: first Esc is the exit ladder, then Sketch saved")
	var ctx := await _boot()
	var body := await _box_body(ctx)
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	if top == "" or body == "":
		await _shutdown(ctx)
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	check(sm.active and ctx.view.selected_face == top, "face sketch is open on the host face")
	await _zoom(ctx, sm.to_model(Vector2(20, 8)), 100.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2(8, 8))
	await _click_uv(ctx, vp, Vector2(13, 8))
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await _click_uv(ctx, vp, Vector2(25, 4))
	await _click_uv(ctx, vp, Vector2(36, 9))
	await process_frame
	check(sm.has_open_chain(), "the loose line leaves the chain open")
	check(sm.sketch != null and sm.sketch.entity_ids().size() >= 2,
			"circle and line are in the sketch")
	_arm_cut_blind(chrome, 2.5)
	await process_frame
	var extrude := chrome.extrude_button()
	check(extrude != null and extrude.is_visible_in_tree(), "Extrude button is visible")
	_status_log.clear()
	if extrude != null:
		await FilmUI.click_control(ctx, extrude, FilmUICues.alert("Click", "Extrude"))
	await process_frame
	await process_frame
	var refused := str(ctx.main.status_label.text)
	check(sm.active, "refusal keeps the sketch open")
	check(refused.contains("breaks the chain") and refused.contains("delete or trim it"),
			"refusal names the open line (got `%s`)" % refused)
	check(not _looks_like_uuid(refused), "refusal status has no uuid (got `%s`)" % refused)
	_release_focus(vp)
	_status_log.clear()
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	var ladder := str(ctx.main.status_label.text)
	check(sm.active, "first Esc after refusal stays in the sketch")
	check(ladder.contains("— Esc again exits the sketch"),
			"first Esc is the exit ladder (got `%s`)" % ladder)
	check(not ladder.contains("Chain ended"),
			"first Esc is not Chain ended (got `%s`)" % ladder)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	await process_frame
	check(not sm.active, "second Esc leaves the sketch")
	check(str(ctx.main.status_label.text) == "Sketch saved",
			"second Esc is Sketch saved (got `%s`)" % ctx.main.status_label.text)
	_assert_part_mode_clean(ctx, top, "refusal save")
	_status_log.clear()
	_release_focus(vp)
	await _push_key(vp, KEY_ESCAPE, false, false)
	await process_frame
	check(str(ctx.main.status_label.text) == "Sketch saved",
			"part-mode Esc after the refusal save changes nothing (got `%s`)" % ctx.main.status_label.text)
	check(not _status_has(FACE_PICK_CANCEL) and not _status_has(SEL_CLEARED),
			"that Esc is not a leftover face pick or a selection clear (log: %s)" % str(_status_log))
	await _shutdown(ctx)


func _arm_cut_blind(chrome: SketchContextChrome, distance: float) -> void:
	if chrome == null:
		return
	var op: OptionButton = chrome.find_child("FinishOp", true, false)
	var end: OptionButton = chrome.find_child("FinishEnd", true, false)
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	if op != null:
		op.select(1)
		op.item_selected.emit(1)
	if end != null:
		end.select(0)
		end.item_selected.emit(0)
	if dist != null:
		dist.value = distance


func _looks_like_uuid(text: String) -> bool:
	var re := RegEx.new()
	re.compile("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
	return re.search(text) != null


func _assert_part_mode_clean(ctx: FilmContext, host_face: String, label: String) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.host_face_id == "", "%s cleared the remembered host face" % label)
	check(ctx.view.selected_face == "" and ctx.view.selected_body == "",
			"%s did not leave the host face selected (face=%s body=%s)" % [
				label, ctx.view.selected_face, ctx.view.selected_body])
	check(ctx.view.selected_face != host_face, "%s host face is not the selection" % label)
	check(not chrome.wants_face_pick() and not chrome.face_pick_explicit(),
			"%s ended the Up To Surface face pick" % label)
	var card: Control = ctx.main.card_box
	check(card == null or not card.visible, "%s selection card is hidden" % label)
	var rail: Button = ctx.main.find_child("PaletteSketch", true, false) as Button
	check(rail != null and rail.is_visible_in_tree(), "%s rail Sketch is visible" % label)
	if rail != null and card != null and card.visible:
		check(not card.get_global_rect().intersects(rail.get_global_rect()),
				"%s selection card does not cover rail Sketch" % label)


func _arm_cut_up_to_surface(chrome: SketchContextChrome) -> void:
	if chrome == null:
		return
	var op: OptionButton = chrome.find_child("FinishOp", true, false)
	var end: OptionButton = chrome.find_child("FinishEnd", true, false)
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	if op != null:
		op.select(1)
		op.item_selected.emit(1)
	if end != null:
		end.select(3)
		end.item_selected.emit(3)
	if dist != null:
		dist.value = 7.0


func _box_body(ctx: FilmContext) -> String:
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		check(false, "box body exists")
		return ""
	return str(ids[0])


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	if body == "" or ctx.view == null:
		return ""
	for f in ctx.view.doc.get_face_ids(body):
		var mid: Variant = ctx.view.doc.face_midpoint(str(f))
		if not (mid is Vector3):
			continue
		var z := (mid as Vector3).z
		if (z_sign > 0 and z > best_z) or (z_sign < 0 and z < best_z):
			best_z = z
			best = str(f)
	return best


func _count_type(ctx: FilmContext, kind: String) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("type", "")) == kind:
			n += 1
	return n


func _status_has(needle: String) -> bool:
	if needle == "":
		return false
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


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
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _click_screen(vp, screen)


func _click_screen(vp: Viewport, pos: Vector2) -> void:
	await _motion(vp, pos)
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


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _push_key(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	vp.push_input(up)
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
