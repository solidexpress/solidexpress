class_name FilmCamera
extends RefCounted

const _Pres := preload("res://tests/lib/film_presentation.gd")

var _cam: OrbitCamera
## Outro iso; films of long parts set a beam-quarter so end profiles read.
var iso_yaw_deg := _Pres.OPEN_ISO_YAW_DEG
var iso_pitch_deg := _Pres.OPEN_ISO_PITCH_DEG


func _init(camera: OrbitCamera) -> void:
	_cam = camera


func frame_all_smooth(duration: float = 1.0) -> void:
	await showcase_smooth(duration, 0.0)


func orbit_smooth(delta_yaw_deg: float, duration: float = 1.2) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	var start_yaw := _cam.yaw
	var end_yaw := start_yaw + deg_to_rad(delta_yaw_deg)
	var tween := _cam.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_cam.yaw = lerpf(start_yaw, end_yaw, t)
			_cam._update_transform(),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Fitted 3/4 iso so the visible AABB fills `fill_frac` of frame height.
func fit_oblique_fill(fill_frac: float = 0.60) -> void:
	if _cam == null:
		return
	if _cam.sketch_orientation_locked:
		_cam.sketch_orientation_locked = false
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.yaw = deg_to_rad(iso_yaw_deg)
	_cam.pitch = deg_to_rad(iso_pitch_deg)
	_cam._look_at_content = true
	if _cam.has_method("frame_fill_frac"):
		_cam.frame_fill_frac(fill_frac)
	else:
		_cam.frame_contents(true)
		_cam._update_transform()


## Top-down ortho on committed sketch pads (no solid body).
func fit_sketch_top_down(ctx) -> void:
	if _cam == null:
		return
	if _cam.sketch_orientation_locked:
		_cam.sketch_orientation_locked = false
	var frame := _sketch_pad_frame(ctx)
	if frame.is_empty():
		if _cam.has_method("apply_standard_view_id"):
			_cam.apply_standard_view_id("top", false)
		return
	var origin: Vector3 = frame["origin"]
	var x_dir: Vector3 = frame["x"]
	var y_dir: Vector3 = frame["y"]
	var mn: Vector2 = frame["min2"]
	var mx: Vector2 = frame["max2"]
	var mid := (mn + mx) * 0.5
	var center: Vector3 = origin + x_dir * mid.x + y_dir * mid.y
	var half := (mx - mn) * 0.5
	var radius := maxf(maxf(half.x, half.y), 5.0)
	_cam.enter_sketch_view(frame["normal"], center, radius, y_dir)


func _sketch_pad_frame(ctx) -> Dictionary:
	if ctx == null or ctx.view == null:
		return {}
	var pads = ctx.view.sketch_pads
	if pads == null:
		return {}
	if not pads.has_method("pad_frames"):
		return {}
	var frames: Array = pads.pad_frames()
	if frames.is_empty():
		return {}
	var merged: Dictionary = frames[0].duplicate()
	var mn: Vector2 = merged["min2"]
	var mx: Vector2 = merged["max2"]
	for f in frames:
		mn = mn.min(f["min2"])
		mx = mx.max(f["max2"])
	merged["min2"] = mn
	merged["max2"] = mx
	return merged


## Single end shot: fit at 3/4 iso, optional orbit — avoids double jump.
func showcase_smooth(duration: float = 1.35, orbit_deg: float = 42.0) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	if _cam.sketch_orientation_locked:
		_cam.sketch_orientation_locked = false
	var start_p := _cam.pivot
	var start_d := _cam.distance
	var start_pitch := _cam.pitch
	var start_yaw := _cam.yaw
	fit_oblique_fill(_Pres.OUTRO_FILL_FRAC)
	var end_p := _cam.pivot
	var end_d := _cam.distance
	var end_pitch := _cam.pitch
	var end_yaw := _cam.yaw + deg_to_rad(orbit_deg)
	_cam.pivot = start_p
	_cam.distance = start_d
	_cam.pitch = start_pitch
	_cam.yaw = start_yaw
	_cam._update_transform()
	if duration <= 0.0:
		_cam.pivot = end_p
		_cam.distance = end_d
		_cam.pitch = end_pitch
		_cam.yaw = end_yaw
		_cam._update_transform()
		return
	var tween := _cam.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_cam, "pivot", end_p, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void:
			_cam.distance = lerpf(start_d, end_d, t)
			_cam.pitch = lerpf(start_pitch, end_pitch, t)
			_cam.yaw = lerpf(start_yaw, end_yaw, t)
			_cam._update_transform(),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
