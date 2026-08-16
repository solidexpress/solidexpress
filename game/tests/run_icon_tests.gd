# Visual-language regression: clickable things carry icons + mouseover
# tooltips; plain text is informational only.
# Rules enforced over the whole UI tree:
#   1. Every UIIcons glyph rasterizes.
#   2. No Button may be blank (no text AND no icon).
#   3. Icon-only Buttons must have a tooltip (the mouseover carries meaning).
#   4. No cryptic Buttons: text of 1-2 chars without an icon is forbidden.
# Run: tools/godot/godot --headless --path game --script tests/run_icon_tests.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("icon / visual-language tests")
	test_all_glyphs_render()

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# Populate the busiest state so every panel builds its buttons: a body
	# with a feature (timeline rows), a variable (variables rows), a selection
	# (ops panel), and the sketch toolbar.
	var body: String = main.view.insert_primitive("box", Vector3.ZERO)
	main.view.doc.set_variable("w", "20")
	main.view.graph_changed()
	main.view.select_entity(body, "")
	main.sketch_toolbar.visible = true
	main.timeline.refresh()
	main.variables_panel.refresh()
	await process_frame
	await process_frame

	test_button_language(main)
	test_key_buttons_have_icons(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_all_glyphs_render() -> void:
	print("- every glyph in the library rasterizes")
	var bad := 0
	for icon_name in UIIcons.GLYPHS:
		if UIIcons.get_icon(icon_name) == null:
			bad += 1
			printerr("    glyph failed: " + str(icon_name))
	check(UIIcons.GLYPHS.size() >= 40, "library has %d glyphs" % UIIcons.GLYPHS.size())
	check(bad == 0, "all glyphs rasterize (%d failed)" % bad)


func test_button_language(main) -> void:
	print("- every button is legible: icon and/or text, tooltip on icon-only")
	var buttons: Array = []
	_collect_buttons(main.get_node("UI"), buttons)
	check(buttons.size() > 30, "collected %d buttons" % buttons.size())
	var blank := 0
	var mute_icons := 0
	var cryptic := 0
	for b in buttons:
		var has_icon: bool = b.icon != null
		var text: String = str(b.text)
		# Self-representing controls (swatch, checkbox, dropdown) are exempt
		# from the icon/text rule but must still explain themselves on hover.
		if b is ColorPickerButton or b is CheckBox or b is OptionButton or b is CheckButton:
			if str(b.tooltip_text).strip_edges() == "" and text.strip_edges() == "" \
					and not (b is OptionButton and b.item_count > 0):
				mute_icons += 1
				printerr("    control without tooltip: " + str(b.get_path()))
			continue
		if not has_icon and text.strip_edges() == "":
			blank += 1
			printerr("    blank button: " + str(b.get_path()))
		if has_icon and text.strip_edges() == "" and str(b.tooltip_text).strip_edges() == "":
			mute_icons += 1
			printerr("    icon button without tooltip: " + str(b.get_path()))
		if not has_icon and text.strip_edges().length() > 0 \
				and text.strip_edges().length() <= 2:
			cryptic += 1
			printerr("    cryptic text button '%s': %s" % [text, b.get_path()])
	check(blank == 0, "no blank buttons (%d found)" % blank)
	check(mute_icons == 0, "icon-only buttons all have tooltips (%d without)" % mute_icons)
	check(cryptic == 0, "no cryptic 1-2 char buttons without icons (%d found)" % cryptic)


func test_key_buttons_have_icons(main) -> void:
	print("- action hotspots use icon buttons")
	var palette: Node = main.get_node("UI/LeftStack/Palette")
	var palette_buttons: Array = []
	_collect_buttons(palette, palette_buttons)
	var no_icon := 0
	for b in palette_buttons:
		if b.icon == null:
			no_icon += 1
	check(palette_buttons.size() >= 6, "palette has %d buttons" % palette_buttons.size())
	check(no_icon == 0, "all palette buttons have icons (%d without)" % no_icon)

	var toolbar_buttons: Array = []
	_collect_buttons(main.sketch_toolbar, toolbar_buttons)
	no_icon = 0
	for b in toolbar_buttons:
		if b is OptionButton:
			continue  # dropdowns carry their selection as text
		if b is CheckBox:
			continue  # toggles carry a check indicator + label
		if b.icon == null:
			no_icon += 1
			printerr("    toolbar button without icon: " + str(b.get_path()))
	check(toolbar_buttons.size() >= 12, "sketch toolbar has %d buttons" % toolbar_buttons.size())
	check(no_icon == 0, "all sketch toolbar buttons have icons (%d without)" % no_icon)

	var ops_buttons: Array = []
	_collect_buttons(main.ops_panel, ops_buttons)
	var without := []
	for b in ops_buttons:
		if b is OptionButton or b is ColorPickerButton:
			continue
		if b.icon == null:
			without.append(str(b.text))
	check(ops_buttons.size() >= 10, "ops panel has %d buttons" % ops_buttons.size())
	check(without.is_empty(), "all ops panel action buttons have icons (missing: %s)" % str(without))

	# Tooltips everywhere in the ops panel (mouseover explains the op).
	var no_tip := 0
	for b in ops_buttons:
		if b is OptionButton or b is ColorPickerButton:
			continue
		if str(b.tooltip_text).strip_edges() == "":
			no_tip += 1
	check(no_tip == 0, "all ops panel buttons have tooltips (%d without)" % no_tip)


func _collect_buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)
