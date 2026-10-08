# sx-038 N12 — a second press on the Extrude button must not hide the body.
# Two real InputEventMouseButton presses at the Extrude rect, 0 frames apart
# and 2 frames apart. The follow-up is down+up with no motion in between, so
# it is the double-click that used to land on the part-mode Hide chip.
# Run: DISPLAY=:1 LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_sx038_extrude_dblclick.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const EXTRUDE_STATUS := "Extrude Blind 10.0000 mm"

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
	print("rung01 sx-038 extrude double-click")
	FilmUI.reset_fail_count()
	await _case_gap(0)
	await _case_gap(2)
	await _case_return_after_move()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _case_gap(gap_frames: int) -> void:
	print("-- two Extrude presses, %d frame(s) between" % gap_frames)
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var doc = ctx.view.doc
	var vp: Viewport = ctx.main.get_viewport()
	_status_log.clear()
	_press_release(vp, pos, true)
	var feats := _feature_count(doc)
	var bodies := doc.body_ids().size()
	var status := str(ctx.main.status_label.text)
	print("  after first press status='%s' features=%d bodies=%d" % [status, feats, bodies])
	check(status == EXTRUDE_STATUS, "first press status is %s (got '%s')" % [EXTRUDE_STATUS, status])
	check(feats >= 2, "first press created the sketch and the extrude (%d)" % feats)
	check(bodies == 1, "first press created one body (%d)" % bodies)
	check(_body_visible(ctx), "body is visible after the extrude")
	var hide := _hide_button(ctx)
	check(hide == null or not hide.is_visible_in_tree() or not hide.get_global_rect().has_point(pos),
			"Hide is not under the Extrude pixel %s (hide %s)" % [
				pos, hide.get_global_rect() if hide != null else Rect2()])
	for _i in gap_frames:
		await process_frame
	var log_n := _status_log.size()
	_press_release(vp, pos, false)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	print("  after second press status='%s' log=%s" % [ctx.main.status_label.text, str(_status_log)])
	_assert_unchanged(ctx, feats, bodies, status, log_n, "gap %d" % gap_frames)
	await _shutdown(ctx)


## Pointer leaves the button, then the same pixel is pressed again.
func _case_return_after_move() -> void:
	print("-- press Extrude, move away, press the same pixel")
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var doc = ctx.view.doc
	var vp: Viewport = ctx.main.get_viewport()
	_status_log.clear()
	_press_release(vp, pos, true)
	var feats := _feature_count(doc)
	var bodies := doc.body_ids().size()
	var status := str(ctx.main.status_label.text)
	check(status == EXTRUDE_STATUS, "move-away setup status is %s (got '%s')" % [EXTRUDE_STATUS, status])
	_motion(vp, Vector2(900, 500))
	await process_frame
	await process_frame
	var log_n := _status_log.size()
	_press_release(vp, pos, false)
	await process_frame
	await process_frame
	_capture_status(ctx.main)
	print("  after return press status='%s' log=%s" % [ctx.main.status_label.text, str(_status_log)])
	_assert_unchanged(ctx, feats, bodies, status, log_n, "return")
	await _shutdown(ctx)


func _assert_unchanged(ctx: FilmContext, feats: int, bodies: int, status: String, log_n: int, tag: String) -> void:
	var doc = ctx.view.doc
	check(_feature_count(doc) == feats, "%s feature count unchanged (%d -> %d)" % [
		tag, feats, _feature_count(doc)])
	check(doc.body_ids().size() == bodies, "%s body count unchanged" % tag)
	check(_body_visible(ctx), "%s body still visible" % tag)
	check(str(ctx.main.status_label.text) == status,
			"%s status unchanged (got '%s')" % [tag, ctx.main.status_label.text])
	check(not _log_grew(log_n, status), "%s no new status (log=%s)" % [tag, str(_status_log)])


func _extrude_ready(ctx: FilmContext) -> Vector2:
	await _ground_rectangle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := chrome.extrude_button()
	check(btn != null and btn.is_visible_in_tree(), "Extrude button is visible")
	if btn == null:
		return Vector2.INF
	await _type_distance(ctx, "10")
	var rect := btn.get_global_rect()
	check(rect.size.x > 8.0 and rect.size.y > 8.0, "Extrude rect has size %s" % rect)
	if rect.size.x < 8.0:
		return Vector2.INF
	# Left side of the button, not the centre. The old shield treated anything
	# more than 12 px from the centre as "the pointer left".
	return rect.position + Vector2(6.0, rect.size.y * 0.5)


func _body_visible(ctx: FilmContext) -> bool:
	if ctx.view.hidden_bodies.size() > 0:
		return false
	var ids = ctx.view.doc.body_ids()
	if ids.is_empty():
		return false
	var prefix := "Body_" + str(ids[0]).left(8)
	var node := ctx.view.find_child(prefix, true, false) as Node3D
	return node != null and node.visible


func _hide_button(ctx: FilmContext) -> Button:
	var strip := ctx.main.interaction.find_child("SelectionStrip", true, false) as Control
	if strip == null:
		return null
	for child in strip.find_children("*", "Button", true, false):
		var b := child as Button
		if b != null and b.visible and b.text == "Hide":
			return b
	return null


func _ground_rectangle(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.run_solve()
	await process_frame


func _type_distance(ctx: FilmContext, text: String) -> void:
	var edit := ctx.main.sketch_chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	check(edit != null and edit.is_visible_in_tree(), "Distance field is visible")
	if edit == null:
		return
	_press_release(edit.get_viewport(), edit.get_global_rect().get_center(), true)
	await process_frame
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := (KEY_0 + (ch - 48)) as Key
		await _push_key(edit.get_viewport(), code, ch)


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.unicode = unicode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


func _press_release(vp: Viewport, pos: Vector2, motion_first: bool) -> void:
	if motion_first:
		_motion(vp, pos)
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


func _feature_count(doc) -> int:
	return doc.graph_features().size()


func _log_grew(from_index: int, previous: String) -> bool:
	for i in range(from_index, _status_log.size()):
		if _status_log[i] != previous:
			return true
	return false


func _capture_status(main) -> void:
	if main == null or main.status_label == null:
		return
	var t := str(main.status_label.text)
	if t == "":
		return
	if _status_log.is_empty() or _status_log[_status_log.size() - 1] != t:
		_status_log.append(t)


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
	check(root.size == ROOT_SIZE, "root is %s (got %s)" % [ROOT_SIZE, root.size])
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx != null and ctx.main != null:
		ctx.main.queue_free()
	await process_frame
	await process_frame
