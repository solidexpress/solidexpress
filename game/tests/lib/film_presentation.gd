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

## Spacing to UI chrome when docked (top/bottom)
const DOCK_MARGIN := 48.0

## When a click target would be covered by the caption, hop to the other dock.
const HOP_MARGIN := 12.0
const HOP_DURATION_SEC := 0.18

static func apply(ctx: FilmContext) -> void:
	if ctx == null:
		return
	# Enforce a consistent viewport size for movies and smoke runs.
	await FilmUI.ensure_test_viewport(ctx, RESOLUTION)
	# Flatten the background (no scenic canyon).
	var main = ctx.main
	if main != null:
		if main.has_method("set_show_scenic_bg"):
			main.set_show_scenic_bg(false)
		elif "show_scenic_bg" in main:
			main.show_scenic_bg = false
		if main.has_method("_sync_world_background"):
			main._sync_world_background()

