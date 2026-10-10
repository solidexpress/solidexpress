# re-PLAN 19 WP2 — Extrude shield survives the File / View menu.
# A menu press must not drop the chip row onto the Extrude pixel.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game \
#   --script tests/run_rung01_replan19_shield.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan19 shield")
	FilmUI.reset_fail_count()
	await _case_file_menu()
	await _case_view_menu()
	await _case_hud_view()
	await _case_fillet_chip()
	await _case_canvas_ends_shield()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case_file_menu() -> void:
	print("- File menu leaves the chip row and the second click is drop:shield")
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var y0 := _strip_top(ctx)
	var row := _strip(ctx)
	check(row != null, "chip row exists after Extrude")
	check(not _row_covers(row, pos), "chip row is not on the Extrude pixel (y %.1f pos %s)" % [y0, pos])
	var file_btn := _menu_button(ctx, "File")
	check(file_btn != null, "File menu button exists")
	if file_btn != null:
		_press_release(ctx.main.get_viewport(), file_btn.get_global_rect().get_center())
		await process_frame
		_push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await process_frame
		await process_frame
	var y1 := _strip_top(ctx)
	check(absf(y1 - y0) <= 1.0, "chip row y unchanged after File (%.1f -> %.1f)" % [y0, y1])
	check(not _row_covers(_strip(ctx), pos), "chip row still clear of the Extrude pixel")
	_status_log.clear()
	ctx.main.interaction.last_click_disposition = ""
	_press_release(ctx.main.get_viewport(), pos)
	await process_frame
	await process_frame
	check(ctx.main.interaction.last_click_disposition == "drop:shield",
			"second Extrude press is drop:shield (got '%s')" % ctx.main.interaction.last_click_disposition)
	var types := _feature_types(ctx)
	check(types == "sketch,extrude", "features stay sketch, extrude (got '%s')" % types)
	check(not _status_blob().contains("hidden"), "no hidden status (got '%s')" % _status_blob())
	check(not _status_blob().contains("Chamfer") and not _status_blob().contains("Fillet"),
			"no Chamfer / Fillet status (got '%s')" % _status_blob())
	await _shutdown(ctx)


func _case_view_menu() -> void:
	print("- View menu leaves the chip row")
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var y0 := _strip_top(ctx)
	var view_btn := _menu_button(ctx, "View")
	check(view_btn != null, "View menu button exists")
	if view_btn != null:
		_press_release(ctx.main.get_viewport(), view_btn.get_global_rect().get_center())
		await process_frame
		_push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await process_frame
	var y1 := _strip_top(ctx)
	check(absf(y1 - y0) <= 1.0, "chip row y unchanged after View (%.1f -> %.1f)" % [y0, y1])
	check(not _row_covers(_strip(ctx), pos), "View menu did not park the row on Extrude")
	ctx.main.interaction.last_click_disposition = ""
	_press_release(ctx.main.get_viewport(), pos)
	await process_frame
	check(ctx.main.interaction.last_click_disposition == "drop:shield",
			"Extrude pixel after View is drop:shield (got '%s')" % ctx.main.interaction.last_click_disposition)
	await _shutdown(ctx)


func _case_hud_view() -> void:
	print("- HUD View ▼ leaves the chip row")
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var y0 := _strip_top(ctx)
	var drop := ctx.main.find_child("ViewsDrop", true, false) as Control
	check(drop != null and drop.is_visible_in_tree(), "HUD View ▼ is visible")
	if drop != null:
		_press_release(ctx.main.get_viewport(), drop.get_global_rect().get_center())
		await process_frame
		_push_key(ctx.main.get_viewport(), KEY_ESCAPE)
		await process_frame
	var y1 := _strip_top(ctx)
	check(absf(y1 - y0) <= 1.0, "chip row y unchanged after HUD View (%.1f -> %.1f)" % [y0, y1])
	check(not _row_covers(_strip(ctx), pos), "HUD View did not park the row on Extrude")
	await _shutdown(ctx)


func _case_fillet_chip() -> void:
	print("- motion onto Fillet ends the shield")
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var fillet := ctx.main.interaction.find_child("StripFillet", true, false) as Button
	check(fillet != null and fillet.is_visible_in_tree(), "Fillet chip is visible")
	if fillet == null:
		await _shutdown(ctx)
		return
	var y0 := _strip_top(ctx)
	_status_log.clear()
	var vp: Viewport = ctx.main.get_viewport()
	_motion(vp, fillet.get_global_rect().get_center())
	_press_release(vp, fillet.get_global_rect().get_center())
	await process_frame
	await process_frame
	var blob := _status_blob()
	var label := str(ctx.main.status_label.text)
	check(blob.begins_with("Fillet r=") or label.begins_with("Fillet r="),
			"Fillet chip status begins Fillet r= (status '%s' label '%s')" % [blob, label])
	check(absf(_strip_top(ctx) - y0) <= 1.0, "Fillet press did not move the chip row")
	ctx.main.interaction.last_click_disposition = ""
	_press_release(vp, pos)
	await process_frame
	check(ctx.main.interaction.last_click_disposition != "drop:shield",
			"Extrude pixel after Fillet is not drop:shield (got '%s')" % ctx.main.interaction.last_click_disposition)
	await _shutdown(ctx)


func _case_canvas_ends_shield() -> void:
	print("- canvas press ends the shield")
	var ctx := await _boot()
	var pos := await _extrude_ready(ctx)
	if pos == Vector2.INF:
		await _shutdown(ctx)
		return
	var vp: Viewport = ctx.main.get_viewport()
	var ground := Vector2(700, 500)
	_press_release(vp, ground)
	await process_frame
	await process_frame
	ctx.main.interaction.last_click_disposition = ""
	_press_release(vp, pos)
	await process_frame
	await process_frame
	check(ctx.main.interaction.last_click_disposition == "model-click",
			"Extrude pixel after canvas press is model-click (got '%s')" % ctx.main.interaction.last_click_disposition)
	await _shutdown(ctx)


func _extrude_ready(ctx: FilmContext) -> Vector2:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_line(0, 0, 40, 0)
	sm.sketch.add_line(40, 0, 40, 20)
	sm.sketch.add_line(40, 20, 0, 20)
	sm.sketch.add_line(0, 20, 0, 0)
	sm.run_solve()
	await process_frame
	var btn: Button = ctx.main.sketch_chrome.extrude_button()
	check(btn != null and btn.is_visible_in_tree(), "Extrude button is visible")
	if btn == null:
		return Vector2.INF
	var edit := ctx.main.sketch_chrome.find_child("DistanceLineEdit", true, false) as LineEdit
	if edit != null:
		_press_release(edit.get_viewport(), edit.get_global_rect().get_center())
		await process_frame
		for ch in [49, 48]:
			await _push_char(edit.get_viewport(), ch)
		await _push_key_await(edit.get_viewport(), KEY_ENTER)
	var rect := btn.get_global_rect()
	var pos := rect.position + Vector2(6.0, rect.size.y * 0.5)
	_press_release(ctx.main.get_viewport(), pos)
	await process_frame
	await process_frame
	await process_frame
	return pos


func _strip(ctx: FilmContext) -> Control:
	return ctx.main.interaction.find_child("SelectionStrip", true, false) as Control


func _strip_top(ctx: FilmContext) -> float:
	var row := _strip(ctx)
	if row == null:
		return -1.0
	return row.get_global_rect().position.y


func _row_covers(row: Control, pos: Vector2) -> bool:
	if row == null or not row.visible:
		return false
	return row.get_global_rect().has_point(pos)


func _menu_button(ctx: FilmContext, text: String) -> MenuButton:
	var bar: Node = ctx.main.find_child("FileMenu", true, false)
	if bar == null:
		return null
	for child in bar.find_children("*", "MenuButton", true, false):
		var b := child as MenuButton
		if b != null and b.text == text:
			return b
	return null


func _feature_types(ctx: FilmContext) -> String:
	var parts: PackedStringArray = []
	for f in ctx.view.doc.graph_features():
		parts.append(str(f.get("type", "")))
	return ",".join(parts)


func _status_blob() -> String:
	return " | ".join(_status_log)


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
	check(root.size == ROOT_SIZE, "root is %s (got %s)" % [ROOT_SIZE, root.size])
	_status_log.clear()
	main.interaction.status.connect(_on_status)
	if main.ops_panel != null and main.ops_panel.has_signal("status"):
		main.ops_panel.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	if ctx != null and ctx.main != null:
		ctx.main.queue_free()
	await process_frame
	await process_frame


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


func _press_release(vp: Viewport, pos: Vector2) -> void:
	_motion(vp, pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	vp.push_input(up)


func _push_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	vp.push_input(up)


func _push_key_await(vp: Viewport, keycode: Key) -> void:
	_push_key(vp, keycode)
	await process_frame


func _push_char(vp: Viewport, unicode: int) -> void:
	var code := (KEY_0 + (unicode - 48)) as Key
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.unicode = unicode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	up.unicode = 0
	vp.push_input(up)
	await process_frame
