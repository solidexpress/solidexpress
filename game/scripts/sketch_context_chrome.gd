class_name SketchContextChrome
extends Control
## On-canvas chips for sketch tool variants and selection actions.
## Sits above the 3D view; positions follow the pointer or selection.

signal variant_chosen(kind: String, variant: String)
signal action_chosen(action: String)
signal finish_requested(op: String, distance: float, end: String,
		thin_thickness: float, thin_type: String, flip_side: bool,
		selected_contours: Array)
## Enter in the dim blank while drawing: typed length/radius commit.
signal dim_submitted(value: float)

const CHIP_H := 28
const CHIP_PAD := 6


func _chip_h() -> int:
	return int(round(UiScale.px(CHIP_H)))

var sketch_mode: SketchMode
var _variant_bar: HBoxContainer
var _action_bar: HBoxContainer
var _finish_bar: HBoxContainer
var _extrude_spin: SpinBox
var _finish_op: OptionButton
var _finish_end: OptionButton
var _thin_spin: SpinBox
var _thin_type: OptionButton
var _flip_side: CheckButton
var _contour_bar: HBoxContainer
var _selected_contours: Array = []  # int indices; empty = all
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
	_contour_bar = _make_bar()
	_build_finish_bar()
	_finish_bar.visible = false
	_contour_bar.visible = false
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
	_dim_spin.custom_minimum_size = Vector2(88, _chip_h())
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
	dim_btn.custom_minimum_size = Vector2(44, _chip_h())
	dim_btn.tooltip_text = "Apply driving dimension to the selection"
	dim_btn.pressed.connect(func() -> void: action_chosen.emit("dimension"))
	_finish_bar.add_child(dim_btn)
	_extrude_spin = SpinBox.new()
	_extrude_spin.min_value = -1000
	_extrude_spin.max_value = 1000
	_extrude_spin.step = 1
	_extrude_spin.value = 20
	_extrude_spin.suffix = "mm"
	_extrude_spin.custom_minimum_size = Vector2(88, _chip_h())
	_extrude_spin.tooltip_text = "Blind distance (ignored for Through All cuts)"
	_finish_bar.add_child(_extrude_spin)
	_finish_end = OptionButton.new()
	_finish_end.name = "FinishEnd"
	_finish_end.tooltip_text = "Extrude end: Blind / Through All / Midplane"
	for n in ["Blind", "Through All", "Midplane"]:
		_finish_end.add_item(n)
	_finish_end.custom_minimum_size = Vector2(100, _chip_h())
	_finish_bar.add_child(_finish_end)
	_finish_op = OptionButton.new()
	_finish_op.name = "FinishOp"
	for n in ["New", "Cut", "Fuse"]:
		_finish_op.add_item(n)
	_finish_op.custom_minimum_size = Vector2(64, _chip_h())
	# Default for cuts: make through cuts go Through All unless the user overrides.
	_finish_op.item_selected.connect(func(_idx: int) -> void:
		if _finish_end != null and _finish_op.selected == 1:  # Cut
			set_finish_end("through_all"))
	_finish_bar.add_child(_finish_op)
	_thin_spin = SpinBox.new()
	_thin_spin.min_value = 0
	_thin_spin.max_value = 1000
	_thin_spin.step = 0.5
	_thin_spin.value = 0
	_thin_spin.suffix = "mm"
	_thin_spin.custom_minimum_size = Vector2(72, _chip_h())
	_thin_spin.tooltip_text = "Thin wall (0 = solid closed profile)"
	_finish_bar.add_child(_thin_spin)
	_thin_type = OptionButton.new()
	_thin_type.tooltip_text = "Thin wall offset: One Side / Midplane"
	for n in ["One Side", "Midplane"]:
		_thin_type.add_item(n)
	_thin_type.custom_minimum_size = Vector2(88, _chip_h())
	_finish_bar.add_child(_thin_type)
	_flip_side = CheckButton.new()
	_flip_side.text = "Flip"
	_flip_side.custom_minimum_size = Vector2(56, _chip_h())
	_flip_side.tooltip_text = (
		"Thin wall side, or Extruded Cut Flip Side to Cut on an open profile")
	_finish_bar.add_child(_flip_side)
	var ex := Button.new()
	ex.text = "Extrude"
	ex.custom_minimum_size = Vector2(72, _chip_h())
	ex.pressed.connect(func() -> void:
		finish_requested.emit(
			["new", "cut", "fuse"][_finish_op.selected],
			_extrude_spin.value,
			["blind", "through_all", "midplane"][_finish_end.selected],
			_thin_spin.value,
			["one_side", "midplane"][_thin_type.selected],
			_flip_side.button_pressed,
			_selected_contours.duplicate()))
	_finish_bar.add_child(ex)
	var rv := Button.new()
	rv.text = "Revolve"
	rv.custom_minimum_size = Vector2(72, _chip_h())
	rv.pressed.connect(func() -> void: action_chosen.emit("revolve"))
	_finish_bar.add_child(rv)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(56, _chip_h())
	done.tooltip_text = "End line / spline chain (Esc · right-click · double-click)"
	done.pressed.connect(func() -> void: action_chosen.emit("done"))
	_finish_bar.add_child(done)


func dim_value() -> float:
	return _dim_spin.value if _dim_spin else 10.0


func extrude_distance() -> float:
	return _extrude_spin.value if _extrude_spin else 20.0


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


func set_finish_op(op: String) -> void:
	if _finish_op == null:
		return
	var map := {"new": 0, "cut": 1, "fuse": 2}
	if map.has(op):
		_finish_op.select(map[op])


func set_finish_end(end: String) -> void:
	if _finish_end == null:
		return
	var map := {"blind": 0, "through_all": 1, "midplane": 2}
	if map.has(end):
		_finish_end.select(map[end])


func get_finish_end() -> String:
	if _finish_end == null:
		return "blind"
	var opts := ["blind", "through_all", "midplane"]
	var i := clampi(_finish_end.selected, 0, opts.size() - 1)
	return opts[i]


func set_flip_side(on: bool) -> void:
	if _flip_side:
		_flip_side.button_pressed = on


func flip_side_button() -> CheckButton:
	return _flip_side


## Refresh Selected Contours chips from the live sketch (SW multi-region pick).
func refresh_contours(sketch: SxSketch) -> void:
	_clear_bar(_contour_bar)
	_selected_contours.clear()
	if sketch == null or not sketch.has_method("contour_count"):
		_contour_bar.visible = false
		return
	var n: int = int(sketch.contour_count())
	if n <= 1:
		_contour_bar.visible = false
		return
	var lbl := Label.new()
	lbl.text = "Contours"
	lbl.add_theme_font_size_override("font_size", UiScale.body())
	_contour_bar.add_child(lbl)
	for i in n:
		_selected_contours.append(i)
		var b := CheckButton.new()
		b.text = str(i + 1)
		b.button_pressed = true
		b.custom_minimum_size = Vector2(40, _chip_h())
		b.tooltip_text = "Selected Contours — include region %d" % (i + 1)
		var idx := i
		b.toggled.connect(func(on: bool) -> void:
			if on:
				if not _selected_contours.has(idx):
					_selected_contours.append(idx)
					_selected_contours.sort()
			else:
				_selected_contours.erase(idx)
		)
		_contour_bar.add_child(b)
	_contour_bar.visible = true
	_place_bar(_contour_bar, Vector2(60, 42 + _chip_h() + 4))


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
		if sketch_mode != null and sketch_mode.sketch != null:
			refresh_contours(sketch_mode.sketch)
	else:
		_variant_bar.visible = false
		_action_bar.visible = false
		_contour_bar.visible = false
		_selected_contours.clear()
		_dim_editing = false


func show_variants(kind: String, variants: Array, screen_pos: Vector2) -> void:
	_active_kind = kind
	_clear_bar(_variant_bar)
	for v in variants:
		var label: String = str(v)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.custom_minimum_size = Vector2(0, _chip_h())
		b.pressed.connect(func() -> void: variant_chosen.emit(kind, label))
		_variant_bar.add_child(b)
	_variant_bar.visible = not variants.is_empty()
	_place_bar(_variant_bar, screen_pos + Vector2(12, -_chip_h() - CHIP_PAD))


func hide_variants() -> void:
	_variant_bar.visible = false
	_active_kind = ""


func show_selection_actions(actions: Array, screen_pos: Vector2) -> void:
	_clear_bar(_action_bar)
	for a in actions:
		var label: String = str(a)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.tooltip_text = label
		b.custom_minimum_size = Vector2(0, _chip_h())
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
