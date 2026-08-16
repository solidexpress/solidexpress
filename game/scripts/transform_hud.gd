class_name TransformHud
extends PanelContainer
## Compact fine-tune blanks for place / move / stretch. Idle selection keeps the
## bottom of the viewport clear; adjustment rows surface only while useful.

signal position_committed(pos: Vector3)
signal size_committed(size: Vector3)
## Shown after a resize/rotate drag; user can refine the travelled value.
signal precision_committed(distance: float)
## Live or post-drag move Δ from the pre-drag center (mm).
signal move_delta_committed(delta: Vector3)

var _dims_row: HBoxContainer
var _pos_x: SpinBox
var _pos_y: SpinBox
var _pos_z: SpinBox
var _size_w: SpinBox
var _size_h: SpinBox
var _size_d: SpinBox
var _precision_row: HBoxContainer
var _precision_spin: SpinBox
var _precision_label: Label
var _move_panel: PanelContainer
var _move_row: HBoxContainer
var _delta_x: SpinBox
var _delta_y: SpinBox
var _delta_z: SpinBox
var _syncing := false
var _size_editable := true


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -280
	offset_right = 280
	offset_top = -56
	offset_bottom = -16
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# Place-mode only: absolute position + size.
	_dims_row = HBoxContainer.new()
	_dims_row.visible = false
	_dims_row.add_theme_constant_override("separation", 6)
	root.add_child(_dims_row)
	_pos_x = _spin(_dims_row, "X", -1e6, 1e6, 0.1, 0.0)
	_pos_y = _spin(_dims_row, "Y", -1e6, 1e6, 0.1, 0.0)
	_pos_z = _spin(_dims_row, "Z", -1e6, 1e6, 0.1, 0.0)
	_dims_row.add_child(VSeparator.new())
	_size_w = _spin(_dims_row, "W", 0.1, 1e6, 0.1, 5.0)
	_size_h = _spin(_dims_row, "H", 0.1, 1e6, 0.1, 5.0)
	_size_d = _spin(_dims_row, "D", 0.1, 1e6, 0.1, 5.0)
	for s in [_pos_x, _pos_y, _pos_z]:
		s.value_changed.connect(_on_pos_changed)
		s.get_line_edit().text_submitted.connect(func(_t: String) -> void:
			s.apply()
			if not _syncing:
				position_committed.emit(current_position()))
	for s in [_size_w, _size_h, _size_d]:
		s.value_changed.connect(_on_size_changed)
		s.get_line_edit().text_submitted.connect(func(t: String) -> void:
			_apply_typed_spin(s, t)
			if not _syncing and _size_editable:
				size_committed.emit(current_size()))

	# Own panel so Main can dock it in LeftStack (does not cover the viewport).
	_move_panel = PanelContainer.new()
	_move_panel.name = "MoveDelta"
	_move_panel.visible = false
	_move_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_move_row = HBoxContainer.new()
	_move_row.add_theme_constant_override("separation", 6)
	_move_panel.add_child(_move_row)
	add_child(_move_panel)
	_move_panel.gui_input.connect(_gui_input)
	var move_lbl := Label.new()
	move_lbl.text = "Δ move"
	move_lbl.add_theme_font_size_override("font_size", UiScale.body())
	_move_row.add_child(move_lbl)
	_delta_x = _spin(_move_row, "ΔX", -1e6, 1e6, 0.1, 0.0)
	_delta_y = _spin(_move_row, "ΔY", -1e6, 1e6, 0.1, 0.0)
	_delta_z = _spin(_move_row, "ΔZ", -1e6, 1e6, 0.1, 0.0)
	for s in [_delta_x, _delta_y, _delta_z]:
		s.value_changed.connect(_on_move_delta_changed)
		s.get_line_edit().text_submitted.connect(func(_t: String) -> void:
			s.apply()
			if not _syncing:
				move_delta_committed.emit(current_move_delta()))
	var z_hint := Label.new()
	z_hint.text = "ΔZ typed only (drag stays on plane)"
	z_hint.add_theme_font_size_override("font_size", UiScale.caption())
	z_hint.modulate = Color(1, 1, 1, 0.55)
	_move_row.add_child(z_hint)

	_precision_row = HBoxContainer.new()
	_precision_row.visible = false
	_precision_row.add_theme_constant_override("separation", 8)
	root.add_child(_precision_row)
	_precision_label = Label.new()
	_precision_label.text = "Δ"
	_precision_label.add_theme_font_size_override("font_size", UiScale.body())
	_precision_row.add_child(_precision_label)
	_precision_spin = SpinBox.new()
	_precision_spin.min_value = -1e6
	_precision_spin.max_value = 1e6
	_precision_spin.step = 0.01
	_precision_spin.suffix = "mm"
	_precision_spin.custom_minimum_size = Vector2(120, 0)
	_precision_spin.value_changed.connect(_on_precision_changed)
	_precision_row.add_child(_precision_spin)
	_precision_spin.get_line_edit().text_submitted.connect(
		func(_t: String) -> void: _commit_precision_ui(true))
	var hint := Label.new()
	hint.text = "Enter confirms · Esc dismisses"
	hint.add_theme_font_size_override("font_size", UiScale.caption())
	hint.modulate = Color(1, 1, 1, 0.55)
	_precision_row.add_child(hint)


## Parse typed text before Range.apply() so "1.2" is not lost to step snap.
func _apply_typed_spin(spin: SpinBox, typed: String) -> void:
	var t := typed.strip_edges()
	if t.is_valid_float():
		var was := _syncing
		_syncing = true
		spin.value = clampf(float(t), spin.min_value, spin.max_value)
		_syncing = was
	else:
		spin.apply()


func _spin(parent: Container, label: String, mn: float, mx: float, step: float,
		value: float) -> SpinBox:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", UiScale.body())
	box.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	# Fine step so typed values (1.2) are not snapped to 1.1 by Range.
	# Arrows still move by the ergonomic `step` passed in.
	spin.step = 0.001
	spin.custom_arrow_step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(72, 0)
	spin.select_all_on_focus = true
	box.add_child(spin)
	return spin


## Sync cached numbers without forcing the dims row on (idle selection stays clear).
func set_values(pos: Vector3, size: Vector3, size_editable := true) -> void:
	_syncing = true
	_pos_x.value = pos.x
	_pos_y.value = pos.y
	_pos_z.value = pos.z
	_size_w.value = size.x
	_size_h.value = size.y
	_size_d.value = size.z
	_size_editable = size_editable
	_size_w.editable = size_editable
	_size_h.editable = size_editable
	_size_d.editable = size_editable
	_syncing = false


## Place mode: surface absolute X/Y/Z + W×H×D blanks.
func show_dims(pos: Vector3, size: Vector3, size_editable := true) -> void:
	set_values(pos, size, size_editable)
	_dims_row.visible = true
	_refresh_panel()


func hide_dims() -> void:
	_dims_row.visible = false
	_refresh_panel()


func current_position() -> Vector3:
	return Vector3(_pos_x.value, _pos_y.value, _pos_z.value)


func current_size() -> Vector3:
	return Vector3(_size_w.value, _size_h.value, _size_d.value)


func current_move_delta() -> Vector3:
	return Vector3(_delta_x.value, _delta_y.value, _delta_z.value)


func move_delta_panel() -> Control:
	return _move_panel


func is_move_delta_visible() -> bool:
	return _move_panel != null and _move_panel.visible


## Live update during planar move (does not steal focus).
func set_move_delta(delta: Vector3) -> void:
	if _move_panel != null:
		_move_panel.visible = true
	_move_row.visible = true
	_syncing = true
	_delta_x.value = delta.x
	_delta_y.value = delta.y
	_delta_z.value = delta.z
	_syncing = false
	_refresh_panel()


## Show this gesture's Δ. Do not grab focus — that steals the next body pick.
func show_move_delta(delta: Vector3, _focus_axis := "x") -> void:
	set_move_delta(delta)


func hide_move_delta() -> void:
	if _move_panel != null:
		_move_panel.visible = false
	_move_row.visible = false
	_refresh_panel()


## Live stretch/rotate readout (no focus steal).
func set_precision(distance: float, axis_hint := "Δ", unit := "mm") -> void:
	_precision_row.visible = true
	_precision_label.text = axis_hint
	_precision_spin.suffix = unit
	_syncing = true
	_precision_spin.value = distance
	_syncing = false
	_refresh_panel()


func show_precision(distance: float, axis_hint := "Δ", unit := "mm") -> void:
	set_precision(distance, axis_hint, unit)
	await get_tree().process_frame
	_precision_spin.get_line_edit().grab_focus()
	_precision_spin.get_line_edit().select_all()


func hide_precision() -> void:
	_precision_row.visible = false
	_refresh_panel()


func dismiss() -> void:
	_dims_row.visible = false
	hide_move_delta()
	_precision_row.visible = false
	_refresh_panel()


func is_pointer_over(global_pos: Vector2) -> bool:
	if _move_panel != null and _move_panel.visible \
			and _move_panel.get_global_rect().has_point(global_pos):
		return true
	return visible and get_global_rect().has_point(global_pos)


func _refresh_panel() -> void:
	# Move Δ lives in LeftStack; this panel is only place dims / precision.
	var any := _dims_row.visible or _precision_row.visible
	visible = any
	mouse_filter = Control.MOUSE_FILTER_STOP if any else Control.MOUSE_FILTER_IGNORE
	offset_top = -56
	offset_bottom = -16
	if int(_dims_row.visible) + int(_precision_row.visible) > 1:
		offset_top = -96


func _on_pos_changed(_v: float) -> void:
	if _syncing:
		return
	position_committed.emit(current_position())


func _on_size_changed(_v: float) -> void:
	if _syncing or not _size_editable:
		return
	size_committed.emit(current_size())


func _on_move_delta_changed(_v: float) -> void:
	if _syncing:
		return
	move_delta_committed.emit(current_move_delta())


func _on_precision_changed(_v: float) -> void:
	if _syncing:
		return
	precision_committed.emit(_precision_spin.value)


func _commit_precision_ui(hide_after: bool) -> void:
	if not _precision_row.visible:
		return
	_precision_spin.apply()
	if not _syncing:
		precision_committed.emit(_precision_spin.value)
	if hide_after:
		hide_precision()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			if _precision_row.visible:
				hide_precision()
				accept_event()
			elif _move_row.visible:
				hide_move_delta()
				accept_event()
			# Persistent W/H/D: do not consume Esc — Interaction cancels
			# place or clears the selection (which hides this row).
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if _precision_row.visible:
				_commit_precision_ui(true)
				accept_event()
			elif _move_row.visible:
				_delta_x.apply()
				_delta_y.apply()
				_delta_z.apply()
				if not _syncing:
					move_delta_committed.emit(current_move_delta())
				hide_move_delta()
				accept_event()
			elif _dims_row.visible:
				_apply_typed_spin(_size_w, _size_w.get_line_edit().text)
				_apply_typed_spin(_size_h, _size_h.get_line_edit().text)
				_apply_typed_spin(_size_d, _size_d.get_line_edit().text)
				_apply_typed_spin(_pos_x, _pos_x.get_line_edit().text)
				_apply_typed_spin(_pos_y, _pos_y.get_line_edit().text)
				_apply_typed_spin(_pos_z, _pos_z.get_line_edit().text)
				if not _syncing and _size_editable:
					size_committed.emit(current_size())
				accept_event()
