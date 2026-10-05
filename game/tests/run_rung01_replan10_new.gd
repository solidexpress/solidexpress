# Rung 1 replan 10 WP4 — File > New puts the finish bar back to New / Blind / no Up To Surface face.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_new.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan10 WP4 File > New resets the finish bar")
	FilmUI.reset_fail_count()
	await test_new_resets_finish_bar()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_new_resets_finish_bar() -> void:
	var ctx := await _boot()
	var main = ctx.main
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	var chrome: SketchContextChrome = main.sketch_chrome
	var op := chrome.find_child("FinishOp", true, false) as OptionButton
	var end := chrome.find_child("FinishEnd", true, false) as OptionButton
	var thin := chrome.find_child("ThinFeature", true, false) as CheckButton
	var flip := chrome.find_child("FlipSide", true, false) as CheckButton
	var face_box := chrome.find_child("UpToFaceBox", true, false) as Control
	check(op != null and end != null and thin != null and flip != null and face_box != null, "finish bar controls exist")
	check(op.get_item_text(op.selected) == "New" and chrome.get_finish_end() == "blind", "a fresh session starts at New / Blind")

	op.select(1)
	end.select(3)
	chrome._on_finish_end_selected(3)
	thin.button_pressed = true
	flip.button_pressed = true
	check(op.get_item_text(op.selected) == "Cut", "the walker's Op is now Cut")
	check(chrome.get_finish_end() == "to_face", "the walker's End is now Up To Surface")
	check(face_box.visible, "the Up To Surface face box is showing")

	sm.sketch.add_circle(0.0, 0.0, 10.0)
	op.select(0)
	end.select(0)
	chrome._on_finish_end_selected(0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	check(main.view.doc.body_ids().size() == 1, "one body exists before File > New")
	op.select(1)
	end.select(3)
	chrome._on_finish_end_selected(3)
	chrome.up_to_face_id = "stale-face-id"

	main._on_file_menu(0)
	await process_frame
	await process_frame
	check(main.confirm_dialog.visible, "File > New asks to discard the unsaved body")
	main._on_discard_confirmed()
	await process_frame
	await process_frame
	check(main.view.doc.body_ids().is_empty(), "File > New gives an empty part")
	check(op.get_item_text(op.selected) == "New", "File > New resets Op to New (got %s)" % op.get_item_text(op.selected))
	check(chrome.get_finish_end() == "blind", "File > New resets End to Blind (got %s)" % chrome.get_finish_end())
	check(str(chrome.up_to_face_id) == "", "File > New clears the Up To Surface face id")
	check(not thin.button_pressed, "File > New turns Thin feature off")
	check(not flip.button_pressed, "File > New turns Flip off")
	check(not face_box.visible, "File > New hides the Up To Surface face box")

	await FilmUI.enter_sketch(ctx)
	check(main.sketch_mode.active, "a sketch opens on the new part")
	check(op.get_item_text(op.selected) == "New" and chrome.get_finish_end() == "blind",
			"the next sketch's finish bar reads New / Blind")
	var extrude_btn := chrome.extrude_button()
	check(extrude_btn != null and not extrude_btn.disabled, "Extrude is enabled on the new part's first sketch")
	await _shutdown(ctx)

func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
