class_name FilmActor
extends RefCounted

## Director for UI films: every click, hover, and field edit travels the
## pointer first, then injects, then dwells. One pacing model (FilmPresentation).

const _Pres := preload("res://tests/lib/film_presentation.gd")
const _SxInput := preload("res://tests/lib/sx_input.gd")
const SLACK_PX := 8.0
const CAM_VIA := ["key", "wheel", "orbit", "pan", "look"]

var ctx: FilmContext
## Ordered events: pointer_move, click, edit, camera. Positions are screen pixels.
var action_log: Array[Dictionary] = []
var _credited_pose: Dictionary = {}
var _camera_gaps: PackedStringArray = []
var _guest_pointer: Node = null


func bind(host: FilmContext) -> void:
	ctx = host
	action_log.clear()
	_camera_gaps = PackedStringArray()
	credit_pose()


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
	audit_camera("before move")
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
	audit_camera("before aim")
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
	await _finish_action(cue)
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
	await _finish_action(cue)
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
	await _finish_action(cue)
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
	await _finish_action(cue)
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
	await _finish_action(cue)
	return true


func edit_field(control: Control, text: String, desc: String = "") -> bool:
	if control == null or not control.is_visible_in_tree():
		FilmUI._fail("field missing or hidden (%s)" % (desc if desc != "" else text))
		return false
	FilmUI.ensure_control_visible(control)
	await _frames(1)
	var edit := _line_edit_of(control)
	var target: Control = await _usable_field(edit if edit != null else control)
	var local_center := target.get_global_rect().get_center()
	var screen_center := FilmUI.control_screen_center(target)
	var cue := {"keys": "Type", "desc": desc if desc != "" else "Type %s" % text}
	if not await aim(screen_center, cue):
		return false
	var vp := target.get_viewport()
	_place_guest_pointer(target, local_center)
	await _SxInput.x11_click_screen(vp, local_center)
	_log("click", screen_center, cue)
	if edit != null:
		edit.grab_focus()
		edit.select_all()
	await _type_paced(vp, text)
	await _SxInput.push_key(vp, KEY_ENTER)
	_log("edit", screen_center, cue, text)
	await _finish_action(cue)
	return true


## Number-row standard view (1 Front, 2 Right, …). Key badge + camera lerp.
func view_key(code: Key, desc: String = "") -> bool:
	audit_camera("before view_key")
	var cam := _cam()
	if cam == null:
		FilmUI._fail("camera missing for view key")
		return false
	var spec: Dictionary = OrbitCamera.standard_view_for_key(code)
	if spec.is_empty():
		FilmUI._fail("no standard view for key %s" % str(code))
		return false
	var badge := _key_badge(code)
	var cue := {"keys": badge, "desc": desc if desc != "" else str(spec.get("label", badge)), "via": "key"}
	await _ensure_pointer_visible(cue)
	_show_badge(badge)
	if cam.sketch_orientation_locked:
		cam.sketch_orientation_locked = false
	var from: Dictionary = cam.capture_pose()
	cam.apply_standard_view_id(str(spec.get("id", "")), false)
	var to: Dictionary = cam.capture_pose()
	cam.apply_pose(from)
	await _lerp_pose(to, _Pres.VIEW_ANIM_SEC, cue)
	_show_badge("")
	await dwell()
	return true


## Animated sketch framing (replaces SxInput.zoom). Scroll badge + pointer nudge.
func zoom_to(center: Vector3, span: float, desc: String = "Zoom") -> bool:
	audit_camera("before zoom")
	var cam := _cam()
	if cam == null or ctx == null:
		return false
	var screen := FilmUI.model_to_screen(ctx, center)
	if not FilmUI.is_on_screen(ctx, screen):
		screen = _viewport_center()
	var cue := {"keys": "Wheel", "desc": desc, "via": "wheel"}
	await move_to(screen, cue)
	_show_badge("Wheel")
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var from: Dictionary = cam.capture_pose()
	_apply_zoom_target(cam, center, span)
	var to: Dictionary = cam.capture_pose()
	cam.apply_pose(from)
	var nudge := pointer_pos() + Vector2(0, 42)
	await _lerp_pose_and_pointer(to, nudge, _Pres.VIEW_ANIM_SEC, cue)
	_show_badge("")
	await dwell()
	return true


## RMB orbit: pointer drags across the viewport while yaw lerps.
func orbit_yaw(delta_deg: float, sec: float = -1.0, desc: String = "Orbit") -> bool:
	audit_camera("before orbit")
	var cam := _cam()
	if cam == null:
		return false
	if cam.sketch_orientation_locked:
		cam.sketch_orientation_locked = false
	var dur := sec if sec > 0.0 else _Pres.OUTRO_SEC
	var vp := _viewport_rect()
	var from_pt := vp.get_center() + Vector2(-minf(140.0, vp.size.x * 0.18), 8.0)
	var to_pt := vp.get_center() + Vector2(minf(140.0, vp.size.x * 0.18), 8.0)
	from_pt = FilmUI.clamp_to_screen(ctx, from_pt)
	to_pt = FilmUI.clamp_to_screen(ctx, to_pt)
	var cue := {"keys": "RMB", "desc": desc, "via": "orbit"}
	await move_to(from_pt, cue)
	_show_badge("RMB")
	var from: Dictionary = cam.capture_pose()
	var to: Dictionary = from.duplicate()
	to["yaw"] = float(from.get("yaw", 0.0)) + deg_to_rad(delta_deg)
	await _lerp_pose_and_pointer(to, to_pt, dur, cue)
	_show_badge("")
	await dwell()
	return true


func apply_pose_animated(to: Dictionary, desc: String, via: String = "look") -> bool:
	audit_camera("before pose")
	if _cam() == null or to.is_empty():
		return false
	var cue := {"keys": _nav_badge(via, via.capitalize()), "desc": desc, "via": via}
	await _ensure_pointer_visible(cue)
	_show_badge(str(cue.get("keys", "")))
	await _lerp_pose(to, _Pres.VIEW_ANIM_SEC, cue)
	_show_badge("")
	await dwell()
	return true


## Frame a world point (Look-at / face framing) — pointer then camera lerp.
func frame_look(world: Vector3, yaw_deg: float, pitch_deg: float, distance: float, desc: String = "Look") -> bool:
	audit_camera("before frame")
	var cam := _cam()
	if cam == null or ctx == null:
		return false
	if cam.sketch_orientation_locked:
		cam.sketch_orientation_locked = false
	var screen := FilmUI.model_to_screen(ctx, world)
	var cue := {"keys": "Look", "desc": desc, "via": "look"}
	if FilmUI.is_on_screen(ctx, screen):
		await move_to(screen, cue)
	else:
		await _ensure_pointer_visible(cue)
	_show_badge("Look")
	var ms: Node3D = ctx.main.model_space
	var pivot: Vector3 = ms.to_global(world) if ms != null else world
	var from: Dictionary = cam.capture_pose()
	var to: Dictionary = from.duplicate()
	to["yaw"] = deg_to_rad(yaw_deg)
	to["pitch"] = deg_to_rad(pitch_deg)
	to["distance"] = distance
	to["pivot"] = pivot
	to["look_at_content"] = true
	await _lerp_pose(to, _Pres.VIEW_ANIM_SEC, cue)
	_show_badge("")
	await dwell()
	return true


func pointer_pos() -> Vector2:
	if ctx != null and ctx.chrome != null and ctx.chrome.has_method("pointer_center"):
		return ctx.chrome.pointer_center()
	return _Pres.POINTER_START


func credit_pose() -> void:
	var cam := _cam()
	if cam != null and cam.has_method("capture_pose"):
		_credited_pose = cam.capture_pose()


func audit_camera(tag: String = "") -> void:
	var cam := _cam()
	if cam == null or _credited_pose.is_empty() or not cam.has_method("capture_pose"):
		return
	if _pose_drift(cam.capture_pose(), _credited_pose) > 0.04:
		_camera_gaps.append("%s: camera moved without Actor view action" % (tag if tag != "" else "camera"))
		credit_pose()


func camera_uncredited() -> PackedStringArray:
	return _camera_gaps


func _finish_action(cue: Dictionary = {}) -> void:
	await _playback_app_camera(cue)
	await dwell()


## If a click/edit made the app jump the camera, play that move with a badge.
func _playback_app_camera(cue: Dictionary) -> void:
	var cam := _cam()
	if cam == null or _credited_pose.is_empty() or not cam.has_method("capture_pose"):
		credit_pose()
		return
	# Let an app view tween (e.g. face-sketch auto-frame) land before we
	# capture its target; killing it mid-flight strands the camera.
	while cam._view_tween != null and cam._view_tween.is_valid() and cam._view_tween.is_running():
		await ctx.tree.process_frame
	var to: Dictionary = cam.capture_pose()
	if _pose_drift(to, _credited_pose) <= 0.04:
		credit_pose()
		return
	var from: Dictionary = _credited_pose.duplicate()
	cam.apply_pose(from)
	var play := cue.duplicate()
	if str(play.get("via", "")) == "":
		play["via"] = "look"
	if str(play.get("keys", "")) == "":
		play["keys"] = "Look"
	else:
		play["keys"] = _nav_badge(str(play.get("via", "look")), str(play.get("keys", "Look")))
	_show_badge(str(play.get("keys", "Look")))
	await _lerp_pose(to, _Pres.VIEW_ANIM_SEC, play)
	_show_badge("")


func _ensure_pointer_visible(cue: Dictionary) -> void:
	var pt := pointer_pos()
	if ctx == null or not FilmUI.is_on_screen(ctx, pt, 24.0):
		pt = _viewport_center()
	await move_to(pt, cue)


func _nav_badge(via: String, keys: String) -> String:
	match via:
		"wheel":
			return "Wheel"
		"orbit":
			return "RMB"
		"pan":
			return "MMB"
		"key":
			return keys if keys != "" else "1"
		_:
			if keys == "Wheel" or keys == "RMB" or keys == "MMB" or keys == "LMB":
				return keys
			return "Look" if keys == "" or keys == "Move" or keys == "Look" else keys


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


static func camera_gaps(log: Array, slack_px: float = SLACK_PX) -> PackedStringArray:
	var errs := PackedStringArray()
	var last_move := Vector2(INF, INF)
	var i := 0
	for ev in log:
		i += 1
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var kind := str(ev.get("kind", ""))
		var pos := Vector2(float(ev.get("x", INF)), float(ev.get("y", INF)))
		if kind == "pointer_move":
			last_move = pos
			continue
		if kind != "camera":
			continue
		var via := str(ev.get("via", ""))
		var keys := str(ev.get("keys", ""))
		if not CAM_VIA.has(via):
			errs.append("camera at entry %d has no via/badge (via='%s' keys='%s')" % [i, via, keys])
		if last_move.x == INF:
			errs.append("camera at entry %d has no preceding pointer_move" % i)
	return errs


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
	if cue.has("via"):
		row["via"] = str(cue.get("via", ""))
	action_log.append(row)


func _usable_field(control: Control) -> Control:
	var n: Control = control
	for _i in 12:
		if n == null:
			break
		var r := n.get_global_rect()
		if r.size.x >= 12.0 and r.size.y >= 10.0:
			return n
		await _frames(1)
	n = control
	while n != null:
		var r := n.get_global_rect()
		if r.size.x >= 12.0 and r.size.y >= 10.0:
			return n
		var p := n.get_parent()
		n = p as Control
	return control


func _place_guest_pointer(control: Control, local_center: Vector2) -> void:
	_clear_guest_pointer()
	if control == null or ctx == null or ctx.tree == null:
		return
	var win := control.get_window()
	var root: Window = ctx.tree.root
	if win == null or win == root:
		return
	var p := FilmPointer.new()
	p.name = "FilmGuestPointer"
	win.add_child(p)
	p.global_position = local_center - p.size * 0.5
	p.visible = true
	if p.has_method("set_flash"):
		p.set_flash(1.0)
	_guest_pointer = p


func _clear_guest_pointer() -> void:
	if _guest_pointer != null and is_instance_valid(_guest_pointer):
		_guest_pointer.queue_free()
	_guest_pointer = null


func _show_badge(text: String) -> void:
	if ctx != null and ctx.chrome != null and ctx.chrome.has_method("set_nav_badge"):
		ctx.chrome.set_nav_badge(text)


func _cam() -> OrbitCamera:
	if ctx == null or ctx.main == null:
		return null
	return ctx.main.camera as OrbitCamera


func _viewport_rect() -> Rect2:
	if ctx == null or ctx.tree == null:
		return Rect2(0, 0, 1600, 900)
	return ctx.tree.root.get_viewport().get_visible_rect()


func _viewport_center() -> Vector2:
	return _viewport_rect().get_center()


func _apply_zoom_target(cam: OrbitCamera, center: Vector3, span: float) -> void:
	var ms: Node3D = ctx.main.model_space if ctx != null and ctx.main != null else null
	var sm: SketchMode = ctx.main.sketch_mode if ctx != null and ctx.main != null else null
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
	cam.pivot = ms.to_global(center) if ms != null else center
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = span / (2.0 * half)
	cam._update_transform()


func _lerp_pose(to: Dictionary, sec: float, cue: Dictionary) -> void:
	await _lerp_pose_and_pointer(to, pointer_pos(), sec, cue)


func _lerp_pose_and_pointer(to: Dictionary, end_ptr: Vector2, sec: float, cue: Dictionary) -> void:
	var cam := _cam()
	if cam == null:
		return
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var from: Dictionary = cam.capture_pose()
	var start_ptr := pointer_pos()
	var frames := _sec_frames(sec)
	var start_yaw := float(from.get("yaw", 0.0))
	var end_yaw := start_yaw + wrapf(float(to.get("yaw", start_yaw)) - start_yaw, -PI, PI)
	var start_pitch := float(from.get("pitch", 0.0))
	var end_pitch := float(to.get("pitch", start_pitch))
	var start_dist := float(from.get("distance", 1.0))
	var end_dist := float(to.get("distance", start_dist))
	var start_pivot: Vector3 = from.get("pivot", Vector3.ZERO) as Vector3
	var end_pivot: Vector3 = to.get("pivot", start_pivot) as Vector3
	if ctx != null and ctx.chrome != null and ctx.chrome._pointer != null \
			and ctx.chrome._pointer.has_method("set_moving"):
		ctx.chrome._pointer.set_moving(true)
	for i in frames:
		var t := float(i + 1) / float(frames)
		t = t * t * (3.0 - 2.0 * t)
		cam.yaw = lerpf(start_yaw, end_yaw, t)
		cam.pitch = lerpf(start_pitch, end_pitch, t)
		cam.distance = lerpf(start_dist, end_dist, t)
		cam.pivot = start_pivot.lerp(end_pivot, t)
		if to.has("look_at_content"):
			cam._look_at_content = bool(to.get("look_at_content"))
		if t >= 0.5 and to.has("projection"):
			cam.projection = int(to.get("projection")) as Camera3D.ProjectionType
		cam._update_transform()
		if ctx != null and ctx.chrome != null:
			ctx.chrome.set_pointer_center(start_ptr.lerp(end_ptr, t))
			if ctx.chrome.has_method("tick_unique"):
				ctx.chrome.tick_unique(i)
		await _frames(1)
	cam.apply_pose(to)
	if ctx != null and ctx.chrome != null:
		ctx.chrome.set_pointer_center(end_ptr)
		if ctx.chrome._pointer != null and ctx.chrome._pointer.has_method("set_moving"):
			ctx.chrome._pointer.set_moving(false)
	_log("camera", end_ptr, cue)
	_log("pointer_move", end_ptr, cue)
	credit_pose()


func _pose_drift(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var yaw := absf(wrapf(float(a.get("yaw", 0.0)) - float(b.get("yaw", 0.0)), -PI, PI))
	var pitch := absf(float(a.get("pitch", 0.0)) - float(b.get("pitch", 0.0)))
	var dist := absf(float(a.get("distance", 0.0)) - float(b.get("distance", 0.0))) / maxf(float(b.get("distance", 1.0)), 1.0)
	var piv: Vector3 = (a.get("pivot", Vector3.ZERO) as Vector3) - (b.get("pivot", Vector3.ZERO) as Vector3)
	return maxf(maxf(yaw, pitch), maxf(dist, piv.length() / 40.0))


func _key_badge(code: Key) -> String:
	match code:
		KEY_1, KEY_KP_1:
			return "1"
		KEY_2, KEY_KP_2:
			return "2"
		KEY_3, KEY_KP_3:
			return "3"
		KEY_4, KEY_KP_4:
			return "4"
		KEY_5, KEY_KP_5:
			return "5"
		KEY_6, KEY_KP_6:
			return "6"
		KEY_7, KEY_KP_7:
			return "7"
		KEY_8, KEY_KP_8:
			return "8"
		KEY_0, KEY_KP_0:
			return "0"
		_:
			return OS.get_keycode_string(code)


func _sec_frames(sec: float) -> int:
	return maxi(1, int(round(maxf(sec, 0.0) * _Pres.FPS)))


func _frames(n: int) -> void:
	if ctx == null or ctx.tree == null:
		return
	for _i in maxi(n, 1):
		await ctx.tree.process_frame
