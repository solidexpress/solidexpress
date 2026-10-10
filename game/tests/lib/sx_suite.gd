extends SceneTree

const SxInput = preload("res://tests/lib/sx_input.gd")

var checks := 0
var failures := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func finish() -> void:
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	await SxInput.push_key(vp, keycode, unicode)


func _push_mouse(vp: Viewport, pos: Vector2, pressed: bool) -> void:
	await SxInput.push_mouse(vp, pos, pressed)


func _x11_click_screen(vp: Viewport, pos: Vector2, double_click: bool = false) -> void:
	await SxInput.x11_click_screen(vp, pos, double_click)


func _x11_click(ctrl: Control) -> void:
	await SxInput.x11_click(ctrl)


func _type_text(vp: Viewport, text: String) -> void:
	await SxInput.type_text(vp, text)


func _keycode_for_char(ch: String) -> Key:
	return SxInput.keycode_for_char(ch)


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	await SxInput.click_uv(self, ctx, vp, uv)


func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
	await SxInput.hover_uv(ctx, uv)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	await SxInput.zoom(ctx, model_pivot, size_mm)
