class_name HelpOverlay
extends PanelContainer
## F1 cheat sheet: lists CommandRegistry.entries() (via by_context) in a
## centered semi-transparent panel. Hidden by default; toggle() flips
## visibility. Any key or mouse click while visible closes it.


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(0, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	# Keep total width modest (~560px): keys + gap + wrapped desc.
	root.custom_minimum_size = Vector2(0, 0)
	add_child(root)

	var title := Label.new()
	title.text = "Keyboard shortcuts"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# Group CommandRegistry.entries() by context (same order as TABLE).
	var grouped: Dictionary = {}
	for entry in CommandRegistry.entries():
		var ctx: String = entry["context"]
		if not grouped.has(ctx):
			grouped[ctx] = [] as Array
		(grouped[ctx] as Array).append(entry)
	# Preserve TABLE order: View, Model, Sketch, Timeline, File.
	for ctx in ["View", "Model", "Sketch", "Timeline", "File"]:
		if not grouped.has(ctx):
			continue
		var section := Label.new()
		section.text = ctx
		var section_settings := LabelSettings.new()
		section_settings.font_size = 13
		section_settings.font_color = Color(0.95, 0.96, 0.98)
		var bold_font := SystemFont.new()
		bold_font.font_weight = 700
		section_settings.font = bold_font
		section.label_settings = section_settings
		root.add_child(section)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 4)
		root.add_child(grid)

		for entry in grouped[ctx]:
			var keys_lbl := Label.new()
			keys_lbl.text = entry["keys"]
			keys_lbl.add_theme_font_size_override("font_size", 12)
			keys_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
			grid.add_child(keys_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = entry["desc"]
			desc_lbl.add_theme_font_size_override("font_size", 12)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.custom_minimum_size = Vector2(320, 0)
			grid.add_child(desc_lbl)


func toggle() -> void:
	visible = not visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var should_close := false
	if event is InputEventKey and event.pressed:
		should_close = true
	elif event is InputEventMouseButton and event.pressed:
		should_close = true
	if should_close:
		visible = false
		accept_event()
