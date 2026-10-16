class_name FilmActor
extends RefCounted

## Director for UI films: every click, hover, and field edit travels the
## pointer first, then injects, then dwells. One pacing model (FilmPresentation).

const _Pres := preload("res://tests/lib/film_presentation.gd")
const _SxInput := preload("res://tests/lib/sx_input.gd")
const SLACK_PX := 8.0

var ctx: FilmContext
## Ordered events: pointer_move, click, edit. Positions are screen pixels.
var action_log: Array[Dictionary] = []


func bind(host: FilmContext) -> void:
	ctx = host
	action_log.clear()


static func of(host: FilmContext) -> FilmActor:
	if host == null:
		var orphan := FilmActor.new()
		return orphan
	if host.actor != null:
		return host.actor
	var actor := FilmActor.new()
	actor.bind(host)
	host.actor = actor
	return actor


func move_to(screen_pos: Vector2, cue: Dictionary = {}) -> bool:
	if ctx == null or ctx.tree == null:
		return false
	var why := str(cue.get("desc", cue.get("keys", "click")))
	if not FilmUI.require_on_screen(ctx, screen_pos, why):
		return false
	if ctx.chrome != null:
		var keys := str(cue.get("keys", "Move"))
		var desc := str(cue.get("desc", ""))
		if ctx.chrome.has_method("travel_to"):
			await ctx.chrome.travel_to(screen_pos, keys, desc)
		else:
			await ctx.chrome.travel_and_flash(screen_pos, keys, desc)
	_log("pointer_move", screen_pos, cue)
	return true


func aim(screen_pos: Vector2, cue: Dictionary = {}) -> bool:
	if ctx == null or ctx.tree == null:
		return false
	var why := str(cue.get("desc", cue.get("keys", "click")))
	if not FilmUI.require_on_screen(ctx, screen_pos, why):
		return false
	if ctx.chrome != null:
		var keys := str(cue.get("keys", "Click"))
		var desc := str(cue.get("desc", ""))
		await ctx.chrome.travel_and_flash(screen_pos, keys, desc)
	_log("pointer_move", screen_pos, cue)
	return true


func click_screen(
		screen_pos: Vector2,
		cue: Dictionary,
		ctrl: bool = false,
		button_index: int = MOUSE_BUTTON_LEFT,
		shift: bool = false
) -> bool:
	if not await aim(screen_pos, cue):
		return false
	var ix = ctx.main.interaction if ctx.main != null else null
	if ix == null:
		FilmUI._fail("interaction missing for viewport click")
		return false
	if ctrl:
		FilmUI._set_ctrl_held(true)
	if shift:
		FilmUI._set_shift_held(true)
	if ctrl or shift:
		await _frames(1)
	var down := InputEventMouseButton.new()
	down.button_index = button_index
	down.pressed = true
	down.position = screen_pos
	down.ctrl_pressed = ctrl
	down.meta_pressed = ctrl
	down.shift_pressed = shift
	ix._input(down)
	await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = button_index
	up.pressed = false
	up.position = screen_pos
	up.ctrl_pressed = ctrl
	up.meta_pressed = ctrl
	up.shift_pressed = shift
	ix._input(up)
	_log("click", screen_pos, cue)
	if ctrl:
		FilmUI._set_ctrl_held(false)
	if shift:
		FilmUI._set_shift_held(false)
	await dwell()
	return true


func tap_x11(screen_pos: Vector2, cue: Dictionary, double_click: bool = false) -> bool:
	if not await aim(screen_pos, cue):
		return false
	var vp: Viewport = ctx.main.get_viewport() if ctx.main != null else ctx.tree.root.get_viewport()
	if double_click:
		await _SxInput.x11_click_screen(vp, screen_pos, false)
		await _frames(2)
	await _SxInput.x11_click_screen(vp, screen_pos, double_click)
	_log("click", screen_pos, cue)
	await dwell()
	return true


func press(button: BaseButton, cue: Dictionary) -> bool:
	if button == null or not button.is_visible_in_tree():
		FilmUI._fail("clickable control missing or hidden (%s)" % str(cue.get("desc", cue.get("keys", "?"))))
		return false
	var center := FilmUI.ensure_control_visible(button)
	await _frames(1)
	center = FilmUI.control_screen_center(button)
	if not FilmUI.is_on_screen(ctx, center):
		center = FilmUI.ensure_control_visible(button)
		await _frames(1)
		center = FilmUI.control_screen_center(button)
	if not await aim(center, cue):
		return false
	if button is PaletteButton:
		(button as PaletteButton)._pressed()
	elif button.toggle_mode:
		button.button_pressed = not button.button_pressed
		button.pressed.emit()
	else:
		button.pressed.emit()
	_log("click", center, cue)
	await dwell()
	return true


func hover(screen_pos: Vector2, cue: Dictionary = {}) -> bool:
	var c := cue if not cue.is_empty() else {"keys": "Move", "desc": "Hover"}
	if not await move_to(screen_pos, c):
		return false
	var vp: Viewport = ctx.main.get_viewport() if ctx.main != null else null
	if vp != null:
		var motion := InputEventMouseMotion.new()
		motion.position = screen_pos
		motion.global_position = screen_pos
		vp.push_input(motion)
	await dwell()
	return true


func pick_popup_row(popup: PopupMenu, index: int, cue: Dictionary) -> bool:
	if popup == null or not popup.visible:
		FilmUI._fail("popup missing or hidden (%s)" % str(cue.get("desc", "?")))
		return false
	if index < 0 or index >= popup.item_count:
		FilmUI._fail("popup row %d missing (%s)" % [index, str(cue.get("desc", "?"))])
		return false
	var pos := _SxInput.popup_item_screen(popup, index)
	return await tap_x11(pos, cue)


func pick_popup_label(popup: PopupMenu, label: String, cue: Dictionary) -> bool:
	if popup == null or not popup.visible:
		FilmUI._fail("popup missing or hidden (%s)" % label)
		return false
	var idx := -1
	for i in popup.item_count:
		if popup.get_item_text(i) == label:
			idx = i
			break
	if idx < 0:
		FilmUI._fail("popup has no '%s'" % label)
		return false
	return await pick_popup_row(popup, idx, cue)


## Pointer travels to the row, then the menu id fires (native popups miss X11).
func choose_popup_id(popup: PopupMenu, id: int, cue: Dictionary) -> bool:
	if popup == null or not popup.visible:
		FilmUI._fail("popup missing or hidden (%s)" % str(cue.get("desc", "?")))
		return false
	var idx := -1
	for i in popup.item_count:
		if popup.get_item_id(i) == id:
			idx = i
			break
	if idx < 0:
		FilmUI._fail("popup has no id %d (%s)" % [id, str(cue.get("desc", "?"))])
		return false
	var pos := _SxInput.popup_item_screen(popup, idx)
	if not await aim(pos, cue):
		return false
	popup.id_pressed.emit(id)
	_log("click", pos, cue)
	await dwell()
	return true


func drag_screen(
		from: Vector2,
		to: Vector2,
		cue: Dictionary,
		steps: int = 6,
		button_index: int = MOUSE_BUTTON_LEFT,
		shift: bool = false
) -> bool:
	if not await aim(from, cue):
		return false
	var ix = ctx.main.interaction if ctx.main != null else null
	if ix == null:
		FilmUI._fail("interaction missing for viewport drag")
		return false
	if shift:
		FilmUI._set_shift_held(true)
		await _frames(1)
	var down := InputEventMouseButton.new()
	down.button_index = button_index
	down.pressed = true
	down.position = from
	down.shift_pressed = shift
	ix._input(down)
	_log("click", from, cue)
	await _frames(1)
	var n := maxi(steps, 1)
	for i in range(1, n + 1):
		var pt := from.lerp(to, float(i) / float(n))
		if ctx.chrome != null:
			ctx.chrome.set_pointer_center(pt)
		var mm := InputEventMouseMotion.new()
		mm.button_mask = 1 << (button_index - 1)
		mm.position = pt
		mm.shift_pressed = shift
		ix._input(mm)
		await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = button_index
	up.pressed = false
	up.position = to
	up.shift_pressed = shift
	ix._input(up)
	if shift:
		FilmUI._set_shift_held(false)
	await dwell()
	return true


func edit_field(control: Control, text: String, desc: String = "") -> bool:
	if control == null or not control.is_visible_in_tree():
		FilmUI._fail("field missing or hidden (%s)" % (desc if desc != "" else text))
		return false
	FilmUI.ensure_control_visible(control)
	await _frames(1)
	var edit := _line_edit_of(control)
	var target: Control = edit if edit != null else control
	var local_center := target.get_global_rect().get_center()
	var screen_center := FilmUI.control_screen_center(target)
	var cue := {"keys": "Type", "desc": desc if desc != "" else "Type %s" % text}
	if not await aim(screen_center, cue):
		return false
	var vp := target.get_viewport()
	await _SxInput.x11_click_screen(vp, local_center)
	_log("click", screen_center, cue)
	if edit != null:
		edit.grab_focus()
		edit.select_all()
	await _type_paced(vp, text)
	await _SxInput.push_key(vp, KEY_ENTER)
	_log("edit", screen_center, cue, text)
	await dwell()
	return true


func dwell() -> void:
	if ctx == null or ctx.chrome == null:
		await _frames(1)
		return
	await wait_sec(_Pres.ACTION_DWELL_SEC)


func result_pause() -> void:
	if ctx == null or ctx.chrome == null:
		await _frames(2)
		return
	await wait_sec(_Pres.RESULT_PAUSE_SEC)


func wait_sec(sec: float) -> void:
	await _frames(_sec_frames(sec))


func log_click(screen_pos: Vector2, cue: Dictionary = {}) -> void:
	_log("click", screen_pos, cue)


func dump_log(path: String = "") -> void:
	var dest := path if path != "" else str(OS.get_environment("SX_FILM_ACTION_LOG"))
	if dest.is_empty():
		return
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(action_log, "\t"))


static func pointer_gaps(log: Array, slack_px: float = SLACK_PX) -> PackedStringArray:
	var errs := PackedStringArray()
	var last_move := Vector2(INF, INF)
	var i := 0
	for ev in log:
		i += 1
		if typeof(ev) != TYPE_DICTIONARY:
			errs.append("entry %d is not a dictionary" % i)
			continue
		var kind := str(ev.get("kind", ""))
		var pos := Vector2(float(ev.get("x", INF)), float(ev.get("y", INF)))
		if kind == "pointer_move":
			last_move = pos
			continue
		if kind != "click" and kind != "edit":
			continue
		if last_move.x == INF:
			errs.append("%s at (%.1f, %.1f) has no preceding pointer_move" % [kind, pos.x, pos.y])
			continue
		var d := last_move.distance_to(pos)
		if d > slack_px:
			errs.append("%s at (%.1f, %.1f) is %.1f px from pointer_move (%.1f, %.1f)" % [
				kind, pos.x, pos.y, d, last_move.x, last_move.y])
	return errs


static func format_typed(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(value)


func _type_paced(vp: Viewport, text: String) -> void:
	var gap := _sec_frames(1.0 / maxf(_Pres.TYPING_CPS, 1.0))
	for i in text.length():
		var ch := text.substr(i, 1)
		await _SxInput.push_key(vp, _SxInput.keycode_for_char(ch), ch.unicode_at(0))
		await _frames(gap)


func _line_edit_of(control: Control) -> LineEdit:
	if control is LineEdit:
		return control as LineEdit
	if control is SpinBox:
		return (control as SpinBox).get_line_edit()
	if control is TextEdit:
		return null
	for c in control.find_children("*", "LineEdit", true, false):
		return c as LineEdit
	return null


func _log(kind: String, pos: Vector2, cue: Dictionary = {}, text: String = "") -> void:
	var row := {
		"kind": kind,
		"x": pos.x,
		"y": pos.y,
		"frame": Engine.get_frames_drawn(),
		"keys": str(cue.get("keys", "")),
		"desc": str(cue.get("desc", "")),
	}
	if text != "":
		row["text"] = text
	action_log.append(row)


func _sec_frames(sec: float) -> int:
	return maxi(1, int(round(maxf(sec, 0.0) * _Pres.FPS)))


func _frames(n: int) -> void:
	if ctx == null or ctx.tree == null:
		return
	for _i in maxi(n, 1):
		await ctx.tree.process_frame
