class_name FilmShots
extends RefCounted

## Intro/outro wrappers for curated website films.
## movie_maker_run_one calls these; films do not.

const TITLE_SIZE := 42
const FEATURE_SIZE := 22
const _Outro := preload("res://tests/lib/film_outro_strategy.gd")


static func intro(ctx, title: String, feature: String = "") -> void:
	if ctx == null:
		return
	var overlay := _title_card(str(title), str(feature))
	var host: Node = null
	if ctx.chrome != null and ctx.chrome.has_method("overlay_root"):
		host = ctx.chrome.overlay_root()
	if host == null:
		host = ctx.chrome if ctx.chrome != null else ctx.main
	if host == null:
		return
	host.add_child(overlay)
	# Unique-per-frame modulate so the MovieWriter's duplicate-frame skip cannot
	# collapse a static card to a single encoded frame.
	var frames := maxi(1, int(round(FilmPresentation.INTRO_SEC * FilmPresentation.FPS)))
	for i in frames:
		overlay.modulate.a = 0.992 + 0.008 * sin(float(i) * 0.37)
		if ctx.tree != null:
			await ctx.tree.process_frame
	overlay.queue_free()
	if ctx.tree != null:
		await ctx.tree.process_frame


static func outro(ctx) -> void:
	if ctx == null:
		return
	var kind := _Outro.choose(ctx)
	if ctx.chrome != null and ctx.chrome.has_method("hide_pointer"):
		ctx.chrome.hide_pointer()
	if ctx.main != null and ctx.main.has_method("film_prepare_outro"):
		ctx.main.film_prepare_outro()
	if ctx.tree != null:
		await ctx.tree.process_frame
		await ctx.tree.process_frame
	await _Outro.play(ctx, kind)


static func _title_card(title: String, feature: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 80
	var sb := StyleBoxFlat.new()
	sb.bg_color = FilmPresentation.FLAT_BG
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var feat := str(feature).strip_edges()
	var head := str(title).strip_edges()
	if not feat.is_empty() and feat.to_lower() != head.to_lower():
		var kicker := Label.new()
		kicker.text = feat
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kicker.add_theme_font_size_override("font_size", FEATURE_SIZE)
		kicker.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95, 0.92))
		kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(kicker)
	var label := Label.new()
	label.text = head if not head.is_empty() else feat
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)
	return panel
