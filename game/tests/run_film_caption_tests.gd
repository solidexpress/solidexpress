# Run: tools/godot/godot --headless --path game --script tests/run_film_caption_tests.gd
extends SceneTree

const FilmCaptionMath := preload("res://tests/lib/film_caption_math.gd")
const FilmPresentation := preload("res://tests/lib/film_presentation.gd")
const FilmOutroStrategy := preload("res://tests/lib/film_outro_strategy.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film caption tests")
	# choose_dock: when a target lies inside the bottom band, hop TOP
	var cap_bottom := Rect2(Vector2(100, 800), Vector2(800, 60))
	var near_bottom := Rect2(Vector2(200, 820), Vector2(60, 40))
	var far_mid := Rect2(Vector2(400, 400), Vector2(50, 50))
	check(FilmCaptionMath.choose_dock(cap_bottom, near_bottom, 10.0) == FilmCaptionMath.Dock.TOP, "choose TOP near bottom")
	check(FilmCaptionMath.choose_dock(cap_bottom, far_mid, 10.0) == FilmCaptionMath.Dock.BOTTOM, "choose BOTTOM when clear")
	# margin respected
	var edge_touch := Rect2(Vector2(180, 859), Vector2(20, 10)) # barely touches when grown by 10
	check(FilmCaptionMath.choose_dock(cap_bottom, edge_touch, 10.0) == FilmCaptionMath.Dock.TOP, "margin respected")
	var vp := Vector2(1600, 900)
	var cap := Vector2(840, 52)
	var bottom := FilmCaptionMath.rect_for_dock(vp, cap, FilmCaptionMath.Dock.BOTTOM, 48.0)
	var top := FilmCaptionMath.rect_for_dock(vp, cap, FilmCaptionMath.Dock.TOP, 48.0)
	check(is_equal_approx(bottom.position.y, 900.0 - 52.0 - 48.0), "bottom dock y from anchors")
	check(is_equal_approx(top.position.y, 48.0), "top dock y from anchors")
	check(is_equal_approx(bottom.position.x, (1600.0 - 840.0) * 0.5), "center x")
	# Toast at top: hop still prefers TOP when bottom covers the click, and the
	# top rect is pushed below the toast so they do not share pixels.
	var toast := Rect2(Vector2(400, 100), Vector2(720, 52))
	var click_low := Rect2(Vector2(760, 820), Vector2(72, 72))
	var top_below_toast := FilmCaptionMath.rect_for_dock(vp, cap, FilmCaptionMath.Dock.TOP, 100.0 + 52.0 + 12.0)
	check(not top_below_toast.intersects(toast), "top dock clears toast")
	check(FilmCaptionMath.pick_dock(bottom, top_below_toast, [click_low, toast], 12.0) == FilmCaptionMath.Dock.TOP,
			"hop TOP considering toast + click")
	check(is_equal_approx(FilmPresentation.INTRO_SEC, 2.0), "title card 2 s")
	check(is_equal_approx(FilmPresentation.BEAT_HOLD_SEC, 0.8), "beat hold 0.8 s")
	check(is_equal_approx(FilmPresentation.OUTRO_SEC, 4.0), "outro orbit 4 s")
	check(is_equal_approx(FilmPresentation.DRAWING_HOLD_SEC, 1.5), "drawing hold 1.5 s")
	check(is_equal_approx(FilmPresentation.OUTRO_FILL_FRAC, 0.70), "outro fill 70%")
	check(FilmOutroStrategy.kind(true, false) == FilmOutroStrategy.Kind.SOLID, "solid body → orbit")
	check(FilmOutroStrategy.kind(false, false) == FilmOutroStrategy.Kind.SKETCH, "no body → sketch top-down")
	check(FilmOutroStrategy.kind(true, true) == FilmOutroStrategy.Kind.DRAWING, "drawing sheet wins")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
