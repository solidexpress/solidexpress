extends "res://tests/lib/sx_suite.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("ui scroll soften")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(120, 80)
	var content := Control.new()
	content.custom_minimum_size = Vector2(100, 800)
	scroll.add_child(content)
	root.add_child(scroll)
	await process_frame
	await process_frame

	UiScroll.soften(scroll)
	check(scroll.has_meta("_sx_soft_scroll"), "soften sets meta")

	var bar := scroll.get_v_scroll_bar()
	check(bar != null and bar.visible, "v scroll bar visible for tall content")
	scroll.scroll_vertical = 0
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_WHEEL_DOWN
	mb.pressed = true
	mb.factor = 1.0
	scroll.gui_input.emit(mb)
	await process_frame
	var stepped: int = scroll.scroll_vertical
	var page := float(bar.page)
	var engine_default := page / 8.0
	check(stepped > 0, "soft wheel moved scroll (got %d)" % stepped)
	check(float(stepped) < engine_default * 0.9,
			"soft step < engine default (%d < %.1f)" % [stepped, engine_default])

	var pm := PopupMenu.new()
	root.add_child(pm)
	UiScroll.soften_menu(pm)
	check(pm.has_meta("_sx_soft_menu"), "soften_menu sets meta")

	finish()
