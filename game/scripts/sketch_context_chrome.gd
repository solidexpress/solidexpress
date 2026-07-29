class_name SketchContextChrome
extends Control
## On-canvas chips for sketch tool variants and selection actions.
## Sits above the 3D view; positions follow the pointer or selection.

signal variant_chosen(kind: String, variant: String)
signal action_chosen(action: String)
signal finish_requested(op: String, distance: float, end: String)
## Enter in the dim blank while drawing: typed length/radius commit.
signal dim_submitted(value: float)

const CHIP_H := 28
const CHIP_PAD := 6

var sketch_mode: SketchMode
var _variant_bar: HBoxContainer
var _action_bar: HBoxContainer
var _finish_bar: HBoxContainer
var _extrude_spin: SpinBox
var _finish_op: OptionButton
var _finish_end: OptionButton
var _dim_spin: SpinBox
var _active_kind := ""
## True while the dim LineEdit has focus — mouse must not overwrite typed digits.
var _dim_editing := false
var _dim_syncing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_variant_bar = _make_bar()
	_action_bar = _make_bar()
	_finish_bar = _make_bar()
	_build_finish_bar()
	_finish_bar.visible = false
	_variant_bar.visible = false
	_action_bar.visible = false


func _make_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	return bar


func _build_finish_bar() -> void:
	_dim_spin = SpinBox.new()
	_dim_spin.min_value = 0.01
	_dim_spin.max_value = 10000
	_dim_spin.step = 0.01
	_dim_spin.value = 10
	_dim_spin.suffix = "mm"
	_dim_spin.select_all_on_focus = true
	_dim_spin.custom_minimum_size = Vector2(88, CHIP_H)
	_dim_spin.tooltip_text = "Distance / radius — tracks the rubber-band while drawing; type to lock, Enter commits"
	_finish_bar.add_child(_dim_spin)
	var dim_edit := _dim_spin.get_line_edit()
	dim_edit.focus_entered.connect(func() -> void: _dim_editing = true)
	dim_edit.focus_exited.connect(func() -> void: _dim_editing = false)
	dim_edit.text_submitted.connect(func(_t: String) -> void:
		_dim_spin.apply()
		dim_submitted.emit(_dim_spin.value))
	dim_edit.gui_input.connect(_on_dim_edit_gui_input)
	_dim_spin.value_changed.connect(_on_dim_value_changed)
	var dim_btn := Button.new()
	dim_btn.text = "Dim"
	dim_btn.custom_minimum_size = Vector2(44, CHIP_H)
	dim_btn.tooltip_text = "Apply driving dimension to the selection"
	dim_btn.pressed.connect(func() -> void: action_chosen.emit("dimension"))
	_finish_bar.add_child(dim_btn)
	_extrude_spin = SpinBox.new()
	_extrude_spin.min_value = -1000
	_extrude_spin.max_value = 1000
	_extrude_spin.step = 1
	_extrude_spin.value = 20
	_extrude_spin.suffix = "mm"
	_extrude_spin.custom_minimum_size = Vector2(88, CHIP_H)
	_extrude_spin.tooltip_text = "Blind distance (ignored for Through All cuts)"
	_finish_bar.add_child(_extrude_spin)
	_finish_end = OptionButton.new()
	_finish_end.tooltip_text = "Extrude end: Blind / Through All / Midplane"
	for n in ["Blind", "Through All", "Midplane"]:
		_finish_end.add_item(n)
	_finish_end.custom_minimum_size = Vector2(100, CHIP_H)
	_finish_bar.add_child(_finish_end)
	_finish_op = OptionButton.new()
	for n in ["New", "Cut", "Fuse"]:
		_finish_op.add_item(n)
	_finish_op.custom_minimum_size = Vector2(64, CHIP_H)
	_finish_bar.add_child(_finish_op)
	var ex := Button.new()
	ex.text = "Extrude"
	ex.custom_minimum_size = Vector2(72, CHIP_H)
	ex.pressed.connect(func() -> void:
		finish_requested.emit(
			["new", "cut", "fuse"][_finish_op.selected],
			_extrude_spin.value,
			["blind", "through_all", "midplane"][_finish_end.selected]))
	_finish_bar.add_child(ex)
	var rv := Button.new()
	rv.text = "Revolve"
	rv.custom_minimum_size = Vector2(72, CHIP_H)
	rv.pressed.connect(func() -> void: action_chosen.emit("revolve"))
	_finish_bar.add_child(rv)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(56, CHIP_H)
	done.tooltip_text = "End line / spline chain (Esc · right-click · double-click)"
	done.pressed.connect(func() -> void: action_chosen.emit("done"))
	_finish_bar.add_child(done)


func dim_value() -> float:
	return _dim_spin.value if _dim_spin else 10.0


## Sync from mouse rubber-band. Skipped while the user is typing in the blank.
func set_dim_value(v: float) -> void:
	if _dim_spin == null or _dim_editing:
		return
	_dim_syncing = true
	_dim_spin.value = v
	_dim_syncing = false


func dim_is_editing() -> bool:
	return _dim_editing


## Focus the blank for typed length (optional seed digit / decimal).
func focus_dim_for_typing(seed := "") -> void:
	if _dim_spin == null:
		return
	var edit := _dim_spin.get_line_edit()
	edit.grab_focus()
	_dim_editing = true
	if seed != "" and seed.is_valid_float():
		var v := float(seed)
		_dim_spin.value = v
		edit.text = seed
		edit.caret_column = seed.length()
		if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
			sketch_mode.set_length_override(v)
	elif seed != "":
		edit.text = seed
		edit.caret_column = seed.length()
	else:
		edit.select_all()


func release_dim_focus() -> void:
	if _dim_spin == null:
		return
	var edit := _dim_spin.get_line_edit()
	if edit.has_focus():
		edit.release_focus()
	_dim_editing = false


func _on_dim_value_changed(v: float) -> void:
	if _dim_syncing or not _dim_editing:
		return
	# Live lock rubber-band while digits change (Enter still commits via signal).
	if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
		sketch_mode.set_length_override(v)


func _on_dim_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			if sketch_mode != null:
				sketch_mode.clear_length_override()
			release_dim_focus()
			accept_event()


func set_extrude_distance(v: float) -> void:
	if _extrude_spin:
		_extrude_spin.value = v


func extrude_button() -> Button:
	for c in _finish_bar.get_children():
		if c is Button and str(c.text) == "Extrude":
			return c as Button
	return null


func revolve_button() -> Button:
	for c in _finish_bar.get_children():
		if c is Button and str(c.text) == "Revolve":
			return c as Button
	return null


func done_button() -> Button:
	for c in _finish_bar.get_children():
		if c is Button and str(c.text) == "Done":
			return c as Button
	return null


func show_for_session(on: bool) -> void:
	_finish_bar.visible = on
	if on:
		# Sit to the right of the icon sketch rail, under the top chrome row.
		_place_bar(_finish_bar, Vector2(60, 42))
	else:
		_variant_bar.visible = false
		_action_bar.visible = false
		_dim_editing = false


func show_variants(kind: String, variants: Array, screen_pos: Vector2) -> void:
	_active_kind = kind
	_clear_bar(_variant_bar)
	for v in variants:
		var label: String = str(v)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.custom_minimum_size = Vector2(0, CHIP_H)
		b.pressed.connect(func() -> void: variant_chosen.emit(kind, label))
		_variant_bar.add_child(b)
	_variant_bar.visible = not variants.is_empty()
	_place_bar(_variant_bar, screen_pos + Vector2(12, -CHIP_H - CHIP_PAD))


func hide_variants() -> void:
	_variant_bar.visible = false
	_active_kind = ""


func show_selection_actions(actions: Array, screen_pos: Vector2) -> void:
	_clear_bar(_action_bar)
	for a in actions:
		var label: String = str(a)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.custom_minimum_size = Vector2(0, CHIP_H)
		b.pressed.connect(func() -> void: action_chosen.emit(label))
		_action_bar.add_child(b)
	_action_bar.visible = not actions.is_empty()
	_place_bar(_action_bar, screen_pos + Vector2(12, CHIP_PAD))


func hide_selection_actions() -> void:
	_action_bar.visible = false


## Merge-sketches option strip (2+ pads selected outside sketch mode).
func show_merge_menu(screen_pos: Vector2) -> void:
	show_selection_actions(
			["merge_join", "merge_spline", "merge_composite", "merge_clear"], screen_pos)


## Multi-sketch → 3D workflow (SolidWorks-style chips from pad selection).
func show_sketch_to_3d_menu(actions: Array, screen_pos: Vector2) -> void:
	show_selection_actions(actions, screen_pos)


func _clear_bar(bar: HBoxContainer) -> void:
	while bar.get_child_count() > 0:
		var c := bar.get_child(0)
		bar.remove_child(c)
		c.queue_free()


func _place_bar(bar: Control, pos: Vector2) -> void:
	bar.reset_size()
	var sz := bar.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	bar.position = Vector2(
		clampf(pos.x, 8, maxf(8, vp.x - sz.x - 8)),
		clampf(pos.y, 8, maxf(8, vp.y - sz.y - 8)))
