class_name FilmPresentation
extends RefCounted

## One place to define how UI films look and record.
##
## Keep these values stable so renders are consistent across films and CI.

const WIDTH := 1600
const HEIGHT := 900
const RESOLUTION := Vector2i(WIDTH, HEIGHT)

## Movie frame rate. scripts/sx-movies must match this constant.
const FPS := 30.0

## Caption look-and-feel
const CAPTION_FONT_SIZE := 22
const CAPTION_TEXT := Color(1, 1, 1, 1)
const CAPTION_BG := Color(0.0, 0.0, 0.0, 0.72)
const CAPTION_CORNER_RADIUS := 4
const CAPTION_MARGIN_H := 18
const CAPTION_MARGIN_V := 10
const CAPTION_MIN_WIDTH := 640.0
## Status bar is 30 px; dock sits above it.
const STATUS_BAR_H := 30.0

## Spacing to UI chrome when docked (top/bottom). Bottom dock clears the status bar.
const DOCK_MARGIN := 48.0

## When a click target would be covered by the caption, hop to the other dock.
const HOP_MARGIN := 12.0
const HOP_DURATION_SEC := 0.18

## One pacing model for every film action. Pointer travel is a speed so a
## canvas pick takes longer than a neighbouring chip; dwell is constant.
## Wrench website demo aims at ~2 minutes including intro/outro.
const POINTER_PX_PER_SEC := 1200.0
const POINTER_MIN_MOVE_SEC := 0.20
const POINTER_MAX_MOVE_SEC := 0.80
const POINTER_FLASH_SEC := 0.12
## Kept for FilmChrome field init; travel duration is computed from distance.
const POINTER_MOVE_SEC := 0.28
const POINTER_AFTER_CLICK_SEC := 0.0
const ACTION_DWELL_SEC := 0.42
const TYPING_CPS := 6.0
const RESULT_PAUSE_SEC := 0.90
const VIEW_ANIM_SEC := 0.55
## Scroll zoom: brisk, short settle.
const WHEEL_ANIM_SEC := 0.35
const WHEEL_DWELL_SEC := 0.15
## Hold a typed value on screen before Enter so it can be read.
const TYPED_READ_SEC := 0.2
const POINTER_START := Vector2(88, 56)

## Empty-scene iso: pull back past DATUM_PLANE_HALF so the camera is not inside the quads.
const OPEN_ISO_YAW_DEG := -35.0
const OPEN_ISO_PITCH_DEG := 40.0
const OPEN_ISO_DISTANCE := 72.0

## Website-film timing (title + caption hold + outro). Target 10–25 s total.
const INTRO_SEC := 2.0
const BEAT_HOLD_SEC := 0.8
const OUTRO_SEC := 4.0
const DRAWING_HOLD_SEC := 1.5
const OUTRO_ORBIT_DEG := 36.0
## Finished solid: AABB height as a fraction of the frame (oblique 3/4).
const OUTRO_FILL_FRAC := 0.70

## Readable film part look (presentation-only; app defaults stay put).
const KEY_LIGHT_ENERGY := 1.65
const PART_ALBEDO := Color(0.78, 0.84, 0.92)
const PART_EMISSION := 0.16

## Flat clear color used by main._sync_world_background (title card matches it).
const FLAT_BG := Color(0.16, 0.17, 0.20)


static func apply(ctx: FilmContext) -> void:
	if ctx == null:
		return
	# Enforce a consistent viewport size for movies and smoke runs.
	await FilmUI.ensure_test_viewport(ctx, RESOLUTION)
	var main = ctx.main
	if main != null and main.has_method("apply_film_presentation"):
		main.apply_film_presentation()
	elif main != null:
		if "presentation_lock" in main:
			main.presentation_lock = true
		if "show_scenic_bg" in main:
			main.show_scenic_bg = false
		if main.has_method("_sync_world_background"):
			main._sync_world_background()
	if main != null and main.has_method("apply_film_look"):
		main.apply_film_look(KEY_LIGHT_ENERGY, PART_ALBEDO, PART_EMISSION)
	_apply_opening_camera(ctx)
	if ctx.actor != null and ctx.actor.has_method("credit_pose"):
		ctx.actor.credit_pose()
	if ctx.chrome != null:
		if "pointer_move_sec" in ctx.chrome:
			ctx.chrome.pointer_move_sec = POINTER_MOVE_SEC
			ctx.chrome.pointer_after_click_sec = POINTER_AFTER_CLICK_SEC
			ctx.chrome.pointer_flash_sec = POINTER_FLASH_SEC
		if ctx.chrome.has_method("layout_caption"):
			ctx.chrome.layout_caption()


static func _apply_opening_camera(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	var cam = ctx.main.camera
	if cam == null:
		return
	# Centre the workplane (disable the empty-scene bottom bias) and pull back
	# past the origin-plane half-extent so the camera is never inside the quads.
	if "sketch_orientation_locked" in cam:
		cam.sketch_orientation_locked = false
	if "_look_at_content" in cam:
		cam._look_at_content = true
	cam.pivot = Vector3.ZERO
	cam.distance = OPEN_ISO_DISTANCE
	if cam.has_method("set_view"):
		cam.set_view(deg_to_rad(OPEN_ISO_YAW_DEG), deg_to_rad(OPEN_ISO_PITCH_DEG), false)
	else:
		cam.yaw = deg_to_rad(OPEN_ISO_YAW_DEG)
		cam.pitch = deg_to_rad(OPEN_ISO_PITCH_DEG)
		if cam.has_method("_update_transform"):
			cam._update_transform()


static func scenic_is_flat(main) -> bool:
	if main == null:
		return false
	if bool(main.get("show_scenic_bg")):
		return false
	var env = main.get("_world_env")
	if env == null or env.environment == null:
		return true
	var e: Environment = env.environment
	if e.background_mode != Environment.BG_COLOR:
		return false
	return e.background_color.is_equal_approx(FLAT_BG) \
			or e.background_color.is_equal_approx(Color(0.16, 0.17, 0.20))
