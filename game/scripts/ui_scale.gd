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
		s = DisplayServer.screen_get_scale()
		# Some Linux setups report scale 1.0 while DPI is clearly HiDPI.
		if is_equal_approx(s, 1.0):
			var dpi := DisplayServer.screen_get_dpi()
			if dpi > 144:
				s = float(dpi) / 96.0
	_factor = clampf(s, 1.0, 2.5)


static func font(base: int = REF_FONT) -> int:
	return maxi(11, int(round(float(base) * factor())))


static func px(base: float) -> float:
	return base * factor()
