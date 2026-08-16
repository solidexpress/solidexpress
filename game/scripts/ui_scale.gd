class_name UiScale
extends Object
## Chrome / menu text scale is DPI-based and stable across window resizes.
## The 3D viewport still tracks the window pixel size 1:1 (no stretch mode).

const REF_FONT := 13
static var _factor := 0.0


static func factor() -> float:
	if _factor <= 0.0:
		refresh()
	return _factor


## Recompute from the current screen. Call on startup and when the window
## moves to another display — never from plain window resize.
static func refresh() -> void:
	var s := 1.0
	if DisplayServer.get_name() != "headless":
		# Use the scale of the screen that actually hosts our main window.
		# Defaulting to screen 0 can be wrong on multi-display setups
		# (e.g. non-Retina external + Retina internal on macOS).
		var win_id := DisplayServer.MAIN_WINDOW_ID
		var screen_id := DisplayServer.window_get_current_screen(win_id)
		s = DisplayServer.screen_get_scale(screen_id)
		# Some platforms/setups may still report 1.0 while physically HiDPI.
		# Fall back to DPI heuristic in that case.
		if is_equal_approx(s, 1.0):
			var dpi := DisplayServer.screen_get_dpi(screen_id)
			if dpi >= 144:
				s = float(dpi) / 96.0
	_factor = clampf(s, 1.0, 2.5)


static func font(base: int = REF_FONT) -> int:
	return maxi(11, int(round(float(base) * factor())))


## Body text — same size as the File menu (desktop-app default).
static func body() -> int:
	return font(REF_FONT)


## Caption / hint text. Never below a readable 12×scale.
static func caption() -> int:
	return font(12)


static func px(base: float) -> float:
	return base * factor()
