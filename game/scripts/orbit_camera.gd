class_name OrbitCamera
extends Camera3D
## Turntable orbit camera with CAD-familiar presets (SolidWorks / Fusion /
## SolidExpress).
##
## Mouse: empty / RMB / Alt / middle per nav preset; wheel zooms at cursor;
## Shift+wheel pans; Alt+wheel yaws; Ctrl/Cmd+wheel zooms harder.
## Trackpad: two-finger orbit, Shift+two-finger pan, pinch / Ctrl+two-finger zoom.
## Touch: one-finger follows mouse emulation (empty-drag orbit); two-finger
## pans + pinch-zooms via ScreenTouch/ScreenDrag.
## Keyboard: arrows pan (Shift+arrows orbit); Alt+WASD pan; +/- and PageUp/Down
## zoom; F / Home zoom-extents; 1/2/3/7 views; 5 ortho. Wheel / pan over
## ScrollContainers are left alone. Plain WASD is reserved for modeling tools.

## Fired after yaw/pitch/distance/pivot/projection update the camera transform.
## Overlay gizmos connect so they redraw only when the view actually moves.
signal view_changed

enum NavPreset { SOLIDEXPRESS, SOLIDWORKS, FUSION }

var pivot := Vector3.ZERO
## Empty-scene start: close enough that 0.1 mm grid cells resolve on screen.
var distance := DEFAULT_DISTANCE
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(40.0)
## Set by main; used by frame_contents (F) to fit all bodies.
var view: DocumentView
var model_space: Node3D
## Mouse binding preset for middle-drag (and Shift+middle). Fusion-only in UI.
var nav_preset := NavPreset.FUSION

## ~15 mm puts ≈4 px on a 0.1 mm cell at 900p / 75° FOV.
const DEFAULT_DISTANCE := 15.0
const MIN_DISTANCE := 1.0
const MAX_DISTANCE := 20000.0
## Fraction of half-frustum height to aim above the orbit pivot so the axis
## origin sits near the bottom of the screen (0 = centered, 1 ≈ bottom edge).
## Disabled while framing content (`_look_at_content`) so zoom-extents faces
## the objects dead-center — the usual CAD “fit” expectation.
const VIEW_PIVOT_Y_BIAS := 0.72
## Padding applied when frustum-fitting an AABB (CAD zoom-extents margin).
const FRAME_PADDING := 1.2
## Zoom-out past this multiple of fit-distance starts pulling the pivot back.
const ZOOM_OUT_RECENTER_START := 1.5
## Soft cap on how far past fit-distance a wheel zoom-out may go.
const ZOOM_OUT_MAX_FIT_MULT := 10.0
const ORBIT_SPEED := 0.008
## Two-finger orbit sensitivity (trackpad PanGesture). Kept modest — libinput
## already sends large per-frame deltas on a normal swipe.
const PAN_GESTURE_SCALE := 0.02
## Map pan-gesture deltas into `_pan_by` pixel units (Shift+two-finger / sketch pan).
const PAN_GESTURE_MOVE_SCALE := 2.4
## Amplify near-1.0 MagnifyGesture deltas (Wayland/libinput often sends tiny factors).
## Kept low so a pinch does not leap through the scene.
const MAGNIFY_GAIN := 2.0
## Ctrl/Cmd + two-finger drag vertical → zoom (fallback when MagnifyGesture is absent).
const PAN_ZOOM_SCALE := 0.008
## Keyboard / Shift+wheel pan step in `_pan_by` pixel units.
const KEY_PAN_PX := 28.0
const WHEEL_PAN_PX := 28.0
## Keyboard / Alt+wheel orbit step in `_orbit_by` pixel units.
const KEY_ORBIT_PX := 22.0
const WHEEL_ORBIT_PX := 24.0
## Discrete keyboard / PageUp-Down zoom factor (< 1 = in).
const KEY_ZOOM_FACTOR := 0.9
const MIN_PITCH := deg_to_rad(-89.0)
const MAX_PITCH := deg_to_rad(89.0)
const VIEWS_CFG := "user://views.cfg"

## name -> {yaw, pitch, distance, pivot, projection}
var _named_views: Dictionary = {}
var _view_tween: Tween
## When true, orientation changes (orbit / view snaps / ortho toggle) are blocked;
## pan and zoom still work. Set by sketch enter/leave.
var sketch_orientation_locked := false
## World-space camera-up while sketch-locked so plane +X/+Y map to screen right/up.
## (Default Vector3.UP is degenerate when looking along world +Y / model +Z.)
var _sketch_view_up := Vector3.UP
## In-memory pose captured before entering sketch view (not persisted).
var _sketch_pose: Dictionary = {}
## After zoom-extents / look-at, look directly at the pivot (no empty-scene
## Y bias) so framed objects stay centered on screen.
var _look_at_content := false
## Active finger index → screen position (multi-touch pan / pinch).
var _touches: Dictionary = {}
## Previous two-finger midpoint / separation for pinch+pan.
var _pinch_prev_mid := Vector2.ZERO
var _pinch_prev_dist := 0.0


func _ready() -> void:
	far = 100000.0
	_load_named_views()
	_update_transform()


func _orbit_by(dx: float, dy: float) -> void:
	if sketch_orientation_locked:
		return
	yaw -= dx * ORBIT_SPEED
	pitch = clampf(pitch + dy * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
	_update_transform()


func _pan_by(dx: float, dy: float) -> void:
	var pan_scale := distance * 0.0012
	pivot += global_transform.basis.x * (-dx * pan_scale)
	pivot += global_transform.basis.y * (dy * pan_scale)
	_update_transform()


## True when the pointer is over a control that should consume wheel / two-finger
## scroll (ScrollContainer, TextEdit, etc.) instead of the 3D camera.
static func pointer_over_scrollable_ui() -> bool:
	var vp := Engine.get_main_loop() as SceneTree
	if vp == null or vp.root == null:
		return false
	var hovered: Control = vp.root.get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is ScrollContainer:
			return true
		if hovered is TextEdit or hovered is CodeEdit:
			return true
		if hovered is ItemList or hovered is Tree:
			return true
		if hovered is RichTextLabel and (hovered as RichTextLabel).scroll_active:
			return true
		hovered = hovered.get_parent() as Control
	return false


## True when this event should drive the camera (middle, Alt+left, pan gesture,
## wheel, multi-touch, keyboard nav). Pass `allow_scroll_gestures=false` when the
## pointer is over a scrolling UI panel. Pinch-zoom (MagnifyGesture) is never
## gated — docks don't use pinch. Caller must still block keyboard nav while a
## text field has focus or sketch length-entry is consuming digits.
func is_nav_event(event: InputEvent, allow_scroll_gestures := true) -> bool:
	if event is InputEventMagnifyGesture:
		return true
	# Multi-touch pan/pinch only. Single-finger uses mouse emulation → empty-drag.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			return _touches.size() >= 1 and not _touches.has(st.index)
		return _touches.size() >= 2 or (_touches.has(st.index) and _touches.size() >= 2)
	if event is InputEventScreenDrag:
		return _touches.size() >= 2 or (
				_touches.has((event as InputEventScreenDrag).index) and _touches.size() >= 2)
	if event is InputEventPanGesture:
		# Ctrl/Cmd+pan is treated as pinch-zoom and always available.
		if event.ctrl_pressed or event.meta_pressed:
			return true
		return allow_scroll_gestures
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP \
				or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Ctrl+wheel is pinch-zoom on many Linux trackpads — never gate it.
			# Shift/Alt wheel are camera pan/orbit — also never leave to docks.
			if mb.ctrl_pressed or mb.meta_pressed or mb.shift_pressed or mb.alt_pressed:
				return true
			return allow_scroll_gestures
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			return true
		# Consume Alt+LMB press/release so place/select don't also fire.
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed:
			return true
		# Two-finger click on many trackpads = middle; some emit left+ctrl/meta.
		if mb.button_index == MOUSE_BUTTON_LEFT and (mb.ctrl_pressed or mb.meta_pressed) \
				and mb.alt_pressed:
			return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			return true
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and mm.alt_pressed:
			return true
	if event is InputEventKey:
		return _is_nav_key(event as InputEventKey)
	return false


## Feed every screen-touch so two-finger nav can see the first finger. Returns
## true when the event was consumed as multi-touch camera nav (caller should
## mark handled). Single-finger never consumes — mouse emulation owns it.
func note_screen_touch(st: InputEventScreenTouch) -> bool:
	if st.pressed:
		_touches[st.index] = st.position
		if _touches.size() == 2:
			_pinch_reset()
		return _touches.size() >= 2
	var was_multi := _touches.size() >= 2
	_touches.erase(st.index)
	if _touches.size() < 2:
		_pinch_prev_dist = 0.0
	elif _touches.size() == 2:
		_pinch_reset()
	return was_multi


## Keys owned by the camera. Number-row views are claimed here; Interaction
## suppresses them while sketch length-entry / text fields are active.
func _is_nav_key(k: InputEventKey) -> bool:
	if not k.pressed or k.ctrl_pressed or k.meta_pressed:
		return false
	match k.keycode:
		KEY_F, KEY_HOME:
			return true
		KEY_1, KEY_2, KEY_3, KEY_5, KEY_7:
			return not k.alt_pressed
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			return true
		KEY_PAGEUP, KEY_PAGEDOWN:
			return true
		KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT:
			return true
		# Alt+WASD pans — plain WASD stays with display / sketch / select tools.
		KEY_W, KEY_A, KEY_S, KEY_D:
			return k.alt_pressed
	return false


func handle_input(event: InputEvent, allow_scroll_gestures := true) -> bool:
	# Pinch always zooms (never defer to dock scroll — ScrollContainers don't pinch).
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		# factor > 1 = pinch out = zoom in. Gain helps tiny Wayland deltas.
		var boosted := 1.0 + (mg.factor - 1.0) * MAGNIFY_GAIN
		var factor := 1.0 / maxf(boosted, 0.01)
		factor = clampf(factor, 0.5, 2.0)
		var vp := get_viewport()
		var pos := vp.get_mouse_position() if vp != null else Vector2.ZERO
		zoom_at(pos, factor)
		return true
	if event is InputEventScreenTouch:
		return note_screen_touch(event as InputEventScreenTouch)
	if event is InputEventScreenDrag:
		return _handle_screen_drag(event as InputEventScreenDrag)
	if event is InputEventPanGesture and (event.ctrl_pressed or event.meta_pressed):
		# Ctrl+two-finger drag → zoom (Linux fallback when MagnifyGesture is missing).
		var pg_zoom := event as InputEventPanGesture
		var vp2 := get_viewport()
		var pos2 := vp2.get_mouse_position() if vp2 != null else Vector2.ZERO
		# Finger move up (negative Y delta) → zoom in (distance shrinks).
		var zfactor := exp(pg_zoom.delta.y * PAN_ZOOM_SCALE)
		zoom_at(pos2, clampf(zfactor, 0.5, 2.0))
		return true
	if not allow_scroll_gestures and (
			event is InputEventPanGesture
			or (event is InputEventMouseButton and (
				(event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP
				or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN)
				and not (event as InputEventMouseButton).ctrl_pressed
				and not (event as InputEventMouseButton).meta_pressed
				and not (event as InputEventMouseButton).shift_pressed
				and not (event as InputEventMouseButton).alt_pressed)):
		return false
	if event is InputEventPanGesture:
		# Two-finger drag orbits. Shift+two-finger pans. A 3-finger grip
		# (middle-click on clickfinger trackpads) follows the nav preset.
		var pg := event as InputEventPanGesture
		var middle_grip := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		var do_pan := false
		if middle_grip:
			do_pan = _want_pan(pg.shift_pressed)
		elif pg.shift_pressed:
			do_pan = true
		if do_pan:
			_pan_by(pg.delta.x * PAN_GESTURE_MOVE_SCALE, pg.delta.y * PAN_GESTURE_MOVE_SCALE)
			return true
		if sketch_orientation_locked:
			# Locked sketch view: treat two-finger as pan instead of orbit.
			_pan_by(pg.delta.x * PAN_GESTURE_MOVE_SCALE, pg.delta.y * PAN_GESTURE_MOVE_SCALE)
			return true
		var scale := PAN_GESTURE_SCALE
		# Left-click held under the fingers → slightly snappier turn.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			scale *= 1.15
		yaw -= pg.delta.x * scale
		pitch = clampf(pitch + pg.delta.y * scale, MIN_PITCH, MAX_PITCH)
		_update_transform()
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			return _handle_wheel(mb, true)
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			return _handle_wheel(mb, false)
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			# SolidWorks muscle memory: double-middle = zoom to fit.
			if mb.pressed and mb.double_click:
				frame_selection_or_all(false)
				return true
			return true  # claim press/release so LMB paths ignore them
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed:
			return true  # Alt+LMB orbit/pan — do not place/select
		return false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var middle := (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
		var alt_left := (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and mm.alt_pressed
		if not middle and not alt_left:
			return false
		# Middle / 3-finger uses the nav preset. Alt stays orbit-first under SX
		# so trackpads keep a reliable orbit chord when middle is rebound to pan.
		var pan := _want_pan(mm.shift_pressed) if middle else _want_alt_pan(mm.shift_pressed)
		if pan:
			_pan_by(mm.relative.x, mm.relative.y)
		else:
			_orbit_by(mm.relative.x, mm.relative.y)
		return true
	elif event is InputEventKey:
		return _handle_nav_key(event as InputEventKey)
	return false


## Wheel: zoom (Ctrl = stronger). Shift = vertical pan; Alt = yaw; Shift+Alt =
## horizontal pan — common CAD / DCC modifiers when the middle button is scarce.
## Honors `factor` so high-rate trackpad scroll ticks stay small.
func _handle_wheel(mb: InputEventMouseButton, wheel_up: bool) -> bool:
	var amount := maxf(mb.factor, 0.05)
	var sign := -1.0 if wheel_up else 1.0
	if mb.shift_pressed and mb.alt_pressed:
		_pan_by(sign * WHEEL_PAN_PX * amount, 0.0)
		return true
	if mb.shift_pressed:
		_pan_by(0.0, sign * WHEEL_PAN_PX * amount)
		return true
	if mb.alt_pressed:
		if sketch_orientation_locked:
			_pan_by(sign * WHEEL_PAN_PX * amount, 0.0)
		else:
			_orbit_by(sign * WHEEL_ORBIT_PX * amount, 0.0)
		return true
	# Per-notch scale (< 1 = zoom in). Milder than the old 0.9 so a trackpad
	# flurry of notches does not leap through the model.
	var unit := 0.88 if (mb.ctrl_pressed or mb.meta_pressed) else 0.94
	var step := pow(unit, amount)
	if wheel_up:
		zoom_at(mb.position, step)
	else:
		zoom_at(mb.position, 1.0 / step)
	return true


func _handle_screen_drag(sd: InputEventScreenDrag) -> bool:
	if not _touches.has(sd.index):
		_touches[sd.index] = sd.position
	else:
		_touches[sd.index] = sd.position
	if _touches.size() < 2:
		return false
	# Two-finger: midpoint motion pans; separation change pinch-zooms.
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return false
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var mid := (a + b) * 0.5
	var dist := a.distance_to(b)
	if _pinch_prev_dist > 1.0 and dist > 1.0:
		var mid_delta := mid - _pinch_prev_mid
		_pan_by(mid_delta.x, mid_delta.y)
		var zfactor := clampf(_pinch_prev_dist / dist, 0.5, 2.0)
		if absf(zfactor - 1.0) > 0.002:
			zoom_at(mid, zfactor)
	_pinch_prev_mid = mid
	_pinch_prev_dist = dist
	return true


func _pinch_reset() -> void:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		_pinch_prev_dist = 0.0
		return
	_pinch_prev_mid = (pts[0] + pts[1]) * 0.5
	_pinch_prev_dist = pts[0].distance_to(pts[1])


func _handle_nav_key(k: InputEventKey) -> bool:
	if not k.pressed or k.ctrl_pressed or k.meta_pressed:
		return false
	match k.keycode:
		KEY_F, KEY_HOME:
			# F / Home → selection (or all); Shift+F / Shift+Home → always all.
			frame_selection_or_all(k.shift_pressed)
			return true
		KEY_1:  # front: looking along -Y in model space (Z-up kernel)
			apply_standard_view(deg_to_rad(0.0), deg_to_rad(0.0))
			return true
		KEY_2:  # right: looking along -X
			apply_standard_view(deg_to_rad(90.0), deg_to_rad(0.0))
			return true
		KEY_3:  # top: looking down model +Z (world +Y)
			apply_standard_view(deg_to_rad(0.0), deg_to_rad(89.0))
			return true
		KEY_7:  # isometric
			apply_standard_view(deg_to_rad(-35.0), deg_to_rad(40.0))
			return true
		KEY_5:
			if sketch_orientation_locked:
				return true
			toggle_projection()
			return true
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			return _handle_arrow_key(k)
		KEY_W, KEY_A, KEY_S, KEY_D:
			if not k.alt_pressed:
				return false
			return _handle_wasd_pan(k.keycode)
		KEY_PAGEUP, KEY_EQUAL, KEY_KP_ADD:
			_zoom_at_view_center(KEY_ZOOM_FACTOR)
			return true
		KEY_PAGEDOWN, KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_at_view_center(1.0 / KEY_ZOOM_FACTOR)
			return true
	return false


func _handle_arrow_key(k: InputEventKey) -> bool:
	var dx := 0.0
	var dy := 0.0
	match k.keycode:
		KEY_LEFT:
			dx = -1.0
		KEY_RIGHT:
			dx = 1.0
		KEY_UP:
			dy = -1.0
		KEY_DOWN:
			dy = 1.0
	if k.shift_pressed:
		if sketch_orientation_locked:
			_pan_by(dx * KEY_PAN_PX, dy * KEY_PAN_PX)
		else:
			# Arrow-left turns the view left (same feel as dragging right).
			_orbit_by(-dx * KEY_ORBIT_PX, dy * KEY_ORBIT_PX)
		return true
	_pan_by(dx * KEY_PAN_PX, dy * KEY_PAN_PX)
	return true


func _handle_wasd_pan(keycode: int) -> bool:
	var dx := 0.0
	var dy := 0.0
	match keycode:
		KEY_A:
			dx = -1.0
		KEY_D:
			dx = 1.0
		KEY_W:
			dy = -1.0
		KEY_S:
			dy = 1.0
	_pan_by(dx * KEY_PAN_PX, dy * KEY_PAN_PX)
	return true


func _zoom_at_view_center(factor: float) -> void:
	var vp := get_viewport()
	var center := Vector2.ZERO
	if vp != null:
		center = vp.get_visible_rect().size * 0.5
	zoom_at(center, factor)


## SX / Fusion: middle (3-finger grip on clickfinger trackpads) pans,
## Shift+middle orbits. SolidWorks: middle orbits, Shift+middle pans.
func _want_pan(shift_held: bool) -> bool:
	if nav_preset == NavPreset.FUSION or nav_preset == NavPreset.SOLIDEXPRESS:
		return not shift_held
	return shift_held


## Alt+left: Fusion mirrors middle (pan). SX/SW keep Alt as orbit so a
## touchpad always has an orbit chord even when middle/3-finger pans.
func _want_alt_pan(shift_held: bool) -> bool:
	if nav_preset == NavPreset.FUSION:
		return not shift_held
	return shift_held


## Zoom by `factor` (< 1 in, > 1 out) keeping the point under `screen_pos`
## approximately fixed: intersect the cursor ray with the plane through the
## pivot perpendicular to the view axis, then shift the pivot by (1 - factor)
## of that pivot→anchor vector (in-plane).
## Zoom-out past ~fit distance gently pulls the pivot toward visible content
## so a stray cursor-anchored zoom cannot leave the scene off-screen.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var anchor := _zoom_anchor(screen_pos)
	var basis := global_transform.basis if is_inside_tree() else transform.basis
	var forward := -basis.z
	var to_anchor := anchor - pivot
	# Project onto the view plane (numerical safety; anchor should already lie on it).
	var plane_delta := to_anchor - forward * to_anchor.dot(forward)
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	pivot += (1.0 - factor) * plane_delta
	if factor > 1.0:
		_nudge_pivot_on_zoom_out(factor)
	_update_transform()


func _zoom_anchor(screen_pos: Vector2) -> Vector3:
	var vp := get_viewport()
	if vp == null:
		return pivot
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return pivot
	var ray_origin := project_ray_origin(screen_pos)
	var ray_dir := project_ray_normal(screen_pos)
	var basis := global_transform.basis if is_inside_tree() else transform.basis
	var forward := -basis.z
	var denom := ray_dir.dot(forward)
	if absf(denom) < 1e-12:
		return pivot
	var t := (pivot - ray_origin).dot(forward) / denom
	return ray_origin + ray_dir * t


## Switch between perspective and orthographic, keeping apparent size:
## the ortho frustum height matches what the perspective fov sees at the pivot.
func toggle_projection() -> void:
	if projection == PROJECTION_PERSPECTIVE:
		projection = PROJECTION_ORTHOGONAL
	else:
		projection = PROJECTION_PERSPECTIVE
	_update_transform()


func set_view(new_yaw: float, new_pitch: float, animated := false) -> void:
	if animated:
		animate_to(new_yaw, new_pitch)
		return
	yaw = new_yaw
	pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	_update_transform()


## Standard view (Front / Right / Top / Iso): set orientation, then zoom-extents
## so the objects stay framed. No-op while sketch orientation is locked.
func apply_standard_view(
		new_yaw: float, new_pitch: float, animated := false, fit := true) -> void:
	if sketch_orientation_locked:
		return
	var from := capture_pose()
	yaw = new_yaw
	pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	_update_transform()
	if fit:
		frame_selection_or_all(false)
	if animated and is_inside_tree():
		var to := capture_pose()
		apply_pose(from)
		_animate_pose(to)


## Smoothly tween yaw/pitch to the target (shortest angular path for yaw).
func animate_to(new_yaw: float, new_pitch: float, duration := 0.25) -> void:
	new_pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
		_view_tween = null
	if duration <= 0.0 or not is_inside_tree():
		yaw = new_yaw
		pitch = new_pitch
		_update_transform()
		return
	var start_yaw := yaw
	var start_pitch := pitch
	var yaw_delta := wrapf(new_yaw - start_yaw, -PI, PI)
	var target_yaw := start_yaw + yaw_delta
	_view_tween = create_tween()
	_view_tween.tween_method(
		func(t: float) -> void:
			yaw = lerpf(start_yaw, target_yaw, t)
			pitch = lerpf(start_pitch, new_pitch, t)
			_update_transform(),
		0.0, 1.0, duration
	)


## Tween a full pose (orientation + zoom/pivot/projection). Used by named-view
## restore and animated standard views.
func _animate_pose(to: Dictionary, duration := 0.25) -> void:
	if to.is_empty():
		return
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
		_view_tween = null
	var end_yaw := float(to.get("yaw", yaw))
	var end_pitch := clampf(float(to.get("pitch", pitch)), MIN_PITCH, MAX_PITCH)
	var end_dist := float(to.get("distance", distance))
	var end_pivot: Vector3 = to.get("pivot", pivot) as Vector3
	var end_proj := int(to.get("projection", projection)) as ProjectionType
	var end_look := bool(to.get("look_at_content", _look_at_content))
	if duration <= 0.0 or not is_inside_tree():
		yaw = end_yaw
		pitch = end_pitch
		distance = end_dist
		pivot = end_pivot
		projection = end_proj
		_look_at_content = end_look
		_update_transform()
		return
	var start_yaw := yaw
	var start_pitch := pitch
	var start_dist := distance
	var start_pivot := pivot
	var yaw_delta := wrapf(end_yaw - start_yaw, -PI, PI)
	var target_yaw := start_yaw + yaw_delta
	# Projection snaps at the end (ortho size tracks distance during the tween).
	_view_tween = create_tween()
	_view_tween.tween_method(
		func(t: float) -> void:
			yaw = lerpf(start_yaw, target_yaw, t)
			pitch = lerpf(start_pitch, end_pitch, t)
			distance = lerpf(start_dist, end_dist, t)
			pivot = start_pivot.lerp(end_pivot, t)
			_look_at_content = end_look
			_update_transform(),
		0.0, 1.0, duration
	)
	_view_tween.finished.connect(func() -> void:
		projection = end_proj
		_look_at_content = end_look
		_update_transform(),
		CONNECT_ONE_SHOT)


## Frame selection when anything is selected; otherwise all bodies.
## Pass `force_all=true` for Shift+F / “fit whole model”.
func frame_selection_or_all(force_all := false) -> void:
	if not force_all and view != null and view.selected_body != "":
		if frame_selection():
			return
	frame_contents()


## Frames the current selection AABB (model → world). Returns false if empty.
func frame_selection() -> bool:
	if view == null:
		return false
	var bb: Dictionary = view.selection_bbox()
	if bb.is_empty():
		return false
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
		Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
		Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
	]
	var united := AABB()
	var first := true
	for c in corners:
		var w: Vector3 = model_space.to_global(c) if model_space != null else c
		var a := AABB(w, Vector3.ZERO)
		united = a if first else united.merge(a)
		first = false
	_frame_world_aabb(united)
	return true


## Frames all visible bodies (world-space AABB union); origin fallback when empty.
func frame_contents() -> void:
	if not _has_visible_body():
		_look_at_content = false
		pivot = Vector3.ZERO
		distance = DEFAULT_DISTANCE
		_update_transform()
		return
	_frame_world_aabb(_visible_contents_aabb())


func _has_visible_body() -> bool:
	if view == null:
		return false
	for id in view.doc.body_ids():
		if view.hidden_bodies.has(id):
			continue
		if view.body_node(id) != null:
			return true
	return false


## World-space AABB of non-hidden body meshes. Caller must ensure visible bodies exist.
func _visible_contents_aabb() -> AABB:
	var united := AABB()
	var first := true
	for id in view.doc.body_ids():
		if view.hidden_bodies.has(id):
			continue
		var node := view.body_node(id)
		if node == null:
			continue
		var aabb := node.get_aabb()
		var world_aabb: AABB = node.global_transform * aabb
		united = world_aabb if first else united.merge(world_aabb)
		first = false
	return united


## CAD zoom-extents: pivot on the AABB center, look straight at it, and set
## distance so every corner fits the current frustum (aspect-aware).
func _frame_world_aabb(united: AABB) -> void:
	_look_at_content = true
	pivot = united.get_center()
	distance = _fit_distance_for_world_aabb(united)
	_update_transform()


## Minimum orbit distance so `united` fills the view with FRAME_PADDING margin.
func _fit_distance_for_world_aabb(united: AABB) -> float:
	var center := united.get_center()
	var cam_dir := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	).normalized()
	var up_ref := _view_up()
	var right := cam_dir.cross(up_ref)
	if right.length_squared() < 1e-10:
		right = cam_dir.cross(Vector3.RIGHT)
	if right.length_squared() < 1e-10:
		right = cam_dir.cross(Vector3.FORWARD)
	right = right.normalized()
	var view_up := right.cross(cam_dir).normalized()

	var half_v := tan(deg_to_rad(fov) * 0.5)
	var aspect := 1.0
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect().size
		if r.y > 0.0:
			aspect = r.x / r.y
	var half_h := half_v * maxf(aspect, 1e-6)

	var corners: Array[Vector3] = [
		united.position,
		united.position + Vector3(united.size.x, 0, 0),
		united.position + Vector3(0, united.size.y, 0),
		united.position + Vector3(0, 0, united.size.z),
		united.position + Vector3(united.size.x, united.size.y, 0),
		united.position + Vector3(united.size.x, 0, united.size.z),
		united.position + Vector3(0, united.size.y, united.size.z),
		united.position + united.size,
	]
	var d_needed := MIN_DISTANCE
	for c in corners:
		var p: Vector3 = c - center
		# Camera at center+cam_dir*d looking toward center: depth of p is d - p·cam_dir.
		var x := absf(p.dot(right))
		var y := absf(p.dot(view_up))
		var z_off := p.dot(cam_dir)
		d_needed = maxf(d_needed, x / half_h + z_off)
		d_needed = maxf(d_needed, y / half_v + z_off)
	# Degenerate / tiny AABB fallback (sphere).
	if d_needed <= MIN_DISTANCE + 1e-6:
		var radius: float = united.size.length() * 0.5
		d_needed = radius / maxf(half_v, 1e-6)
	return clampf(d_needed * FRAME_PADDING, MIN_DISTANCE, MAX_DISTANCE)


## When zooming out past fit, blend the pivot toward content and soft-cap distance.
func _nudge_pivot_on_zoom_out(factor: float) -> void:
	if not _has_visible_body():
		return
	var united := _visible_contents_aabb()
	if united.size.length_squared() < 1e-12:
		return
	var center := united.get_center()
	var fit_d := _fit_distance_for_world_aabb(united)
	if fit_d < 1e-6:
		return
	var ratio := distance / fit_d
	if ratio > ZOOM_OUT_MAX_FIT_MULT:
		distance = fit_d * ZOOM_OUT_MAX_FIT_MULT
		ratio = ZOOM_OUT_MAX_FIT_MULT
	if ratio <= ZOOM_OUT_RECENTER_START:
		return
	# Stronger pull the farther past fit we are; scale by this zoom step size.
	var over := (ratio - ZOOM_OUT_RECENTER_START) / (ZOOM_OUT_MAX_FIT_MULT - ZOOM_OUT_RECENTER_START)
	var t := clampf(over * (factor - 1.0) * 10.0, 0.0, 0.4)
	pivot = pivot.lerp(center, t)


## Orient the camera to look along -normal (face “normal to” / look-at).
func look_along_model_normal(normal: Vector3) -> void:
	var n := normal.normalized()
	if n.length_squared() < 1e-8:
		return
	# Model Z-up: yaw around Z, pitch from XY plane.
	var yaw_n := atan2(n.x, -n.y)
	var pitch_n := asin(clampf(n.z, -1.0, 1.0))
	animate_to(yaw_n, pitch_n)
	if view != null and view.selected_body != "":
		frame_selection()
	else:
		_look_at_content = true


## Capture current pose into an in-memory dict (not written to views.cfg).
func capture_pose() -> Dictionary:
	return {
		"yaw": yaw,
		"pitch": pitch,
		"distance": distance,
		"pivot": pivot,
		"projection": projection,
		"look_at_content": _look_at_content,
	}


## Apply a pose dict from capture_pose / enter_sketch_view.
func apply_pose(pose: Dictionary) -> void:
	if pose.is_empty():
		return
	yaw = float(pose.get("yaw", yaw))
	pitch = float(pose.get("pitch", pitch))
	distance = float(pose.get("distance", distance))
	pivot = pose.get("pivot", pivot) as Vector3
	projection = int(pose.get("projection", projection)) as ProjectionType
	_look_at_content = bool(pose.get("look_at_content", _look_at_content))
	_update_transform()


## Enter locked sketch view: save pose, force ortho, look along normal, frame.
## `normal` / `frame_center` / `model_up` are kernel/model (Z-up) space.
## Pass `model_up` = sketch plane +Y so screen axes match the plane (not world UP).
func enter_sketch_view(
		normal: Vector3, frame_center: Vector3, frame_radius: float,
		model_up: Vector3 = Vector3.ZERO) -> void:
	_sketch_pose = capture_pose()
	sketch_orientation_locked = true
	projection = PROJECTION_ORTHOGONAL
	var n := normal.normalized()
	if n.length_squared() > 1e-8:
		yaw = atan2(n.x, -n.y)
		pitch = asin(clampf(n.z, -1.0, 1.0))
	# Pivot is stored in Godot world space (same as orbit / frame_selection).
	if model_space != null:
		pivot = model_space.to_global(frame_center)
	else:
		pivot = frame_center
	if model_up.length_squared() > 1e-8:
		var up_w: Vector3 = (
			model_space.global_transform.basis * model_up if model_space != null
			else model_up)
		if up_w.length_squared() > 1e-8:
			_sketch_view_up = up_w.normalized()
		else:
			_sketch_view_up = Vector3.UP
	else:
		_sketch_view_up = Vector3.UP
	var r := maxf(frame_radius, 5.0)
	distance = clampf(r / tan(deg_to_rad(fov) / 2.0) * 1.35, MIN_DISTANCE, MAX_DISTANCE)
	_look_at_content = true
	_update_transform()


## Leave sketch view: unlock orientation and restore the pre-entry pose.
func leave_sketch_view() -> void:
	sketch_orientation_locked = false
	_sketch_view_up = Vector3.UP
	if not _sketch_pose.is_empty():
		apply_pose(_sketch_pose)
		_sketch_pose.clear()
	else:
		_update_transform()


func save_named_view(view_name: String) -> void:
	_named_views[view_name] = {
		"yaw": yaw,
		"pitch": pitch,
		"distance": distance,
		"pivot": pivot,
		"projection": projection,
		"look_at_content": _look_at_content,
	}
	_save_named_views()


func restore_named_view(view_name: String, animated := false) -> bool:
	if not _named_views.has(view_name):
		return false
	if sketch_orientation_locked:
		return false
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
		_view_tween = null
	var v: Dictionary = _named_views[view_name]
	var to := {
		"yaw": float(v["yaw"]),
		"pitch": float(v["pitch"]),
		"distance": float(v["distance"]),
		"pivot": v["pivot"] as Vector3,
		"projection": int(v["projection"]) as ProjectionType,
		"look_at_content": bool(v.get("look_at_content", true)),
	}
	if animated and is_inside_tree():
		_animate_pose(to)
	else:
		yaw = float(to["yaw"])
		pitch = float(to["pitch"])
		distance = float(to["distance"])
		pivot = to["pivot"] as Vector3
		projection = int(to["projection"]) as ProjectionType
		_look_at_content = bool(to["look_at_content"])
		_update_transform()
	return true


func named_view_list() -> PackedStringArray:
	var keys := PackedStringArray()
	for k in _named_views.keys():
		keys.append(str(k))
	keys.sort()
	return keys


func remove_named_view(view_name: String) -> bool:
	if not _named_views.has(view_name):
		return false
	_named_views.erase(view_name)
	_save_named_views()
	return true


func _save_named_views() -> void:
	var cfg := ConfigFile.new()
	for view_name in _named_views:
		var v: Dictionary = _named_views[view_name]
		cfg.set_value(view_name, "yaw", v["yaw"])
		cfg.set_value(view_name, "pitch", v["pitch"])
		cfg.set_value(view_name, "distance", v["distance"])
		cfg.set_value(view_name, "pivot", v["pivot"])
		cfg.set_value(view_name, "projection", v["projection"])
		cfg.set_value(view_name, "look_at_content", v.get("look_at_content", true))
	cfg.save(VIEWS_CFG)


func _load_named_views() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(VIEWS_CFG) != OK:
		return
	_named_views.clear()
	for section in cfg.get_sections():
		_named_views[section] = {
			"yaw": cfg.get_value(section, "yaw", 0.0),
			"pitch": cfg.get_value(section, "pitch", 0.0),
			"distance": cfg.get_value(section, "distance", DEFAULT_DISTANCE),
			"pivot": cfg.get_value(section, "pivot", Vector3.ZERO),
			"projection": cfg.get_value(section, "projection", PROJECTION_PERSPECTIVE),
			"look_at_content": cfg.get_value(section, "look_at_content", true),
		}


func _view_up() -> Vector3:
	if sketch_orientation_locked and _sketch_view_up.length_squared() > 1e-8:
		return _sketch_view_up
	return Vector3.UP


func _update_transform() -> void:
	if projection == PROJECTION_ORTHOGONAL:
		# Keep apparent size consistent with perspective: frustum height at the
		# pivot for the current fov. Wheel zoom then works in ortho too.
		size = 2.0 * distance * tan(deg_to_rad(fov) / 2.0)
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance
	var pos := pivot + offset
	var look_target := _look_target_for(pos)
	var up := _view_up()
	if is_inside_tree():
		global_position = pos
		look_at(look_target, up)
	else:
		# Headless / orphan nodes (e.g. unit tests) cannot use look_at().
		look_at_from_position(pos, look_target, up)
	view_changed.emit()


## Aim above the orbit pivot along camera-up so the pivot projects low on screen
## (empty-scene / grid aesthetic). Framing content disables this so zoom-extents
## faces the objects dead-center.
func _look_target_for(camera_pos: Vector3) -> Vector3:
	if _look_at_content or VIEW_PIVOT_Y_BIAS <= 0.0:
		return pivot
	var to_pivot := pivot - camera_pos
	if to_pivot.length_squared() < 1e-12:
		return pivot
	var forward := to_pivot.normalized()
	var up_ref := _view_up()
	var right := forward.cross(up_ref)
	if right.length_squared() < 1e-10:
		right = forward.cross(Vector3.RIGHT)
	if right.length_squared() < 1e-10:
		right = forward.cross(Vector3.FORWARD)
	right = right.normalized()
	var view_up := right.cross(forward).normalized()
	var half_height := distance * tan(deg_to_rad(fov) * 0.5)
	return pivot + view_up * (half_height * VIEW_PIVOT_Y_BIAS)
