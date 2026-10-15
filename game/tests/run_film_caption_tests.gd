# Run: tools/godot/godot --headless --path game --script tests/run_film_caption_tests.gd
extends SceneTree

const FilmCaptionMath := preload("res://tests/lib/film_caption_math.gd")

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
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
