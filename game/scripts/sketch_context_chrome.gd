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
## Blank text did not parse. WP4 wires this to the status line.
signal dim_rejected(raw: String)

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
var _extrude_btn: Button
var _distance_label: Label
var _thin_label: Label
var _thin_feature: CheckButton
var _thin_badge: Label
var _face_panel: PanelContainer
var _face_label: Label
## One-shot: the next model-face click is the Up To Surface target.
var _face_pick_armed := false
var _active_kind := ""
## True while the dim LineEdit has focus — mouse must not overwrite typed digits.
var _dim_editing := false
var _dim_syncing := false
## SpinBox's deferred submit treats "23.22.5" as 23.22. Hold the previous value.
var _dim_rejecting := false
## Face id for an Up To Surface end. The finish signal does not carry it;
## finish_extrude reads this after the extrude feature exists.
var up_to_face_id := ""


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


func _fit_spin(spin: SpinBox) -> void:
	# Floor is UiScale.px(140). The line edit is wider than UiScale.px(110)
	# after the arrow buttons, so "20.0 mm" and " AF" stay readable.
	spin.custom_minimum_size = Vector2(UiScale.px(200), _chip_h())
	var edit := spin.get_line_edit()
	if edit != null:
		edit.custom_minimum_size = Vector2(UiScale.px(140), 0)


func _build_finish_bar() -> void:
	_dim_spin = SpinBox.new()
	_dim_spin.name = "DimSpin"
	_dim_spin.min_value = 0.01
	_dim_spin.max_value = 10000
	_dim_spin.step = 0.01
	_dim_spin.value = 10
	_dim_spin.suffix = "mm"
	_dim_spin.select_all_on_focus = true
	_dim_spin.tooltip_text = "Distance / radius — tracks the rubber-band while drawing; type to lock, Enter commits"
	_fit_spin(_dim_spin)
	_finish_bar.add_child(_dim_spin)
	var dim_edit := _dim_spin.get_line_edit()
	dim_edit.name = "DimLineEdit"
	dim_edit.focus_entered.connect(_on_dim_focus_entered)
	dim_edit.focus_exited.connect(func() -> void: _dim_editing = false)
	dim_edit.text_submitted.connect(_on_dim_text_submitted)
	dim_edit.gui_input.connect(_on_dim_edit_gui_input)
	_dim_spin.value_changed.connect(_on_dim_value_changed)
	var dim_btn := Button.new()
	dim_btn.text = "Dim"
	dim_btn.custom_minimum_size = Vector2(44, _chip_h())
	dim_btn.tooltip_text = "Apply driving dimension to the selection"
	dim_btn.pressed.connect(func() -> void: action_chosen.emit("dimension"))
	_finish_bar.add_child(dim_btn)
	_distance_label = Label.new()
	_distance_label.name = "DistanceLabel"
	_distance_label.text = "D"
	_distance_label.custom_minimum_size = Vector2(UiScale.px(16), _chip_h())
	_distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finish_bar.add_child(_distance_label)
	_extrude_spin = SpinBox.new()
	_extrude_spin.name = "DistanceSpin"
	_extrude_spin.min_value = -1000
	_extrude_spin.max_value = 1000
	_extrude_spin.step = 0.5
	_extrude_spin.value = 20
	_extrude_spin.suffix = "mm"
	# A click that focuses D selects the digits, same as the dim blank, so
	# typing 7.5 replaces 20.0 instead of appending. select_all_on_focus
	# runs on focus-in, then the click places a caret and clears it; the
	# deferred select below wins, matching the dim blank.
	_extrude_spin.select_all_on_focus = true
	_extrude_spin.tooltip_text = "Blind distance (ignored for Through All cuts)"
	_fit_spin(_extrude_spin)
	_extrude_spin.get_line_edit().gui_input.connect(_on_distance_edit_gui_input)
	_finish_bar.add_child(_extrude_spin)
	_finish_end = OptionButton.new()
	_finish_end.name = "FinishEnd"
	_finish_end.tooltip_text = "Extrude end: Blind / Through All / Midplane / Up To Surface"
	for n in ["Blind", "Through All", "Midplane", "Up To Surface"]:
		_finish_end.add_item(n)
	_finish_end.item_selected.connect(_on_finish_end_selected)
	_finish_end.custom_minimum_size = Vector2(100, _chip_h())
	_finish_bar.add_child(_finish_end)
	_face_panel = PanelContainer.new()
	_face_panel.name = "UpToFaceBox"
	_face_panel.visible = false
	_face_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_face_label = Label.new()
	_face_label.name = "UpToFaceLabel"
	_face_label.text = "Face: none"
	_face_label.custom_minimum_size = Vector2(UiScale.px(120), _chip_h())
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_panel.add_child(_face_label)
	_finish_bar.add_child(_face_panel)
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
	_thin_feature = CheckButton.new()
	_thin_feature.name = "ThinFeature"
	_thin_feature.text = "Thin feature"
	_thin_feature.button_pressed = false
	_thin_feature.custom_minimum_size = Vector2(UiScale.px(120), _chip_h())
	_thin_feature.tooltip_text = "Thin wall. Off extrudes a solid (thin thickness 0)."
	_thin_feature.toggled.connect(func(_on: bool) -> void: _apply_thin_visibility())
	_finish_bar.add_child(_thin_feature)
	_thin_badge = Label.new()
	_thin_badge.name = "ThinBadge"
	_thin_badge.visible = false
	_thin_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thin_badge.custom_minimum_size = Vector2(UiScale.px(90), _chip_h())
	_finish_bar.add_child(_thin_badge)
	_thin_label = Label.new()
	_thin_label.name = "ThinLabel"
	_thin_label.text = "Thin"
	_thin_label.custom_minimum_size = Vector2(UiScale.px(36), _chip_h())
	_thin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finish_bar.add_child(_thin_label)
	_thin_spin = SpinBox.new()
	_thin_spin.name = "ThinSpin"
	_thin_spin.min_value = 0
	_thin_spin.max_value = 1000
	_thin_spin.step = 0.5
	_thin_spin.value = 0
	_thin_spin.suffix = "mm"
	_thin_spin.tooltip_text = "Thin wall (0 = solid closed profile)"
	_fit_spin(_thin_spin)
	_thin_spin.value_changed.connect(func(_v: float) -> void: _refresh_thin_badge())
	_finish_bar.add_child(_thin_spin)
	_thin_type = OptionButton.new()
	_thin_type.name = "ThinType"
	_thin_type.tooltip_text = "Thin wall offset: One Side / Midplane"
	for n in ["One Side", "Midplane"]:
		_thin_type.add_item(n)
	_thin_type.custom_minimum_size = Vector2(88, _chip_h())
	_finish_bar.add_child(_thin_type)
	_flip_side = CheckButton.new()
	_flip_side.name = "FlipSide"
	_flip_side.text = "Flip"
	_flip_side.custom_minimum_size = Vector2(56, _chip_h())
	_flip_side.tooltip_text = (
		"Thin wall side, or Extruded Cut Flip Side to Cut on an open profile")
	_finish_bar.add_child(_flip_side)
	_apply_thin_visibility()
	var ex := Button.new()
	ex.name = "ExtrudeButton"
	ex.text = "Extrude"
	ex.custom_minimum_size = Vector2(72, _chip_h())
	ex.pressed.connect(_emit_finish_requested)
	_finish_bar.add_child(ex)
	_extrude_btn = ex
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
	_apply_slot_radius(v)
	_dim_syncing = true
	_dim_spin.value = v
	_dim_syncing = false
	_sync_dim_affordance()


## Slot has no single-DOF preview until the first centre is down, so the blank
## is the radius. After that click the blank is the centre distance.
func _apply_slot_radius(v: float) -> void:
	if sketch_mode == null or sketch_mode.tool != SketchMode.Tool.SLOT:
		return
	if sketch_mode.has_single_dof_preview():
		return
	sketch_mode.slot_radius = maxf(v, 0.01)


## Store the face, disarm the one-shot pick, label from the face midpoint z,
## and enable Extrude when the id is non-empty.
func set_up_to_face(id: String) -> void:
	up_to_face_id = id.strip_edges()
	_face_pick_armed = false
	_sync_face_box()
	if up_to_face_id != "" and _extrude_btn != null:
		_extrude_btn.disabled = false


## Remember that the next model-face click is the target. Does not clear the id.
func arm_face_pick() -> void:
	_face_pick_armed = true
	if up_to_face_id == "" and _face_label != null:
		_face_label.text = "Face: none"
	if _face_panel != null:
		_face_panel.visible = true


func wants_face_pick() -> bool:
	return _face_pick_armed


## Empty id, Face: none, and disable Extrude while End is Up To Surface.
func clear_up_to_face() -> void:
	up_to_face_id = ""
	_face_pick_armed = false
	if _face_label != null:
		_face_label.text = "Face: none"
	_sync_face_box()


func _on_finish_end_selected(idx: int) -> void:
	# OptionButton.select does not emit this. Do not copy view.selected_face.
	if idx == 3:
		clear_up_to_face()
		arm_face_pick()
		if _extrude_btn != null:
			_extrude_btn.disabled = true
	else:
		clear_up_to_face()
		if _face_panel != null:
			_face_panel.visible = false
		if _extrude_btn != null:
			_extrude_btn.disabled = false


func _sync_face_box() -> void:
	if _face_label != null:
		if up_to_face_id == "":
			_face_label.text = "Face: none"
		else:
			_face_label.text = _face_z_text(up_to_face_id)
	if _face_panel != null:
		_face_panel.visible = get_finish_end() == "to_face" or _face_pick_armed
	_refresh_extrude_enabled()


func _refresh_extrude_enabled() -> void:
	if _extrude_btn == null:
		return
	_extrude_btn.disabled = get_finish_end() == "to_face" and up_to_face_id == ""


func _face_z_text(id: String) -> String:
	var z := _face_midpoint_z(id)
	if is_nan(z):
		return "Face: " + id.left(8)
	return "Face: z %s mm" % String.num(z, 1)


func _face_midpoint_z(id: String) -> float:
	if id == "" or sketch_mode == null or sketch_mode.view == null:
		return NAN
	var doc = sketch_mode.view.doc
	if doc == null or not doc.has_method("face_midpoint"):
		return NAN
	var mid: Variant = doc.face_midpoint(id)
	if mid is Vector3:
		return (mid as Vector3).z
	return NAN


func _apply_thin_visibility() -> void:
	var on := _thin_feature != null and _thin_feature.button_pressed
	if _thin_label != null:
		_thin_label.visible = on
	if _thin_spin != null:
		_thin_spin.visible = on
	if _thin_type != null:
		_thin_type.visible = on
	if _flip_side != null:
		_flip_side.visible = on
	_refresh_thin_badge()


func _refresh_thin_badge() -> void:
	if _thin_badge == null or _thin_feature == null or _thin_spin == null:
		return
	var show := _thin_feature.button_pressed and _thin_spin.value > 0.0
	_thin_badge.visible = show
	if show:
		_thin_badge.text = "Thin %s mm" % _plain_num(_thin_spin.value)


func _plain_num(v: float) -> String:
	var s := String.num(v, 4)
	if s.contains("."):
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
	return s


func _emit_finish_requested() -> void:
	var thin := 0.0
	if _thin_feature != null and _thin_feature.button_pressed and _thin_spin != null:
		thin = _thin_spin.value
	finish_requested.emit(
		["new", "cut", "fuse"][_finish_op.selected],
		_extrude_spin.value,
		["blind", "through_all", "midplane", "to_face"][_finish_end.selected],
		thin,
		["one_side", "midplane"][_thin_type.selected],
		_flip_side.button_pressed,
		_selected_contours.duplicate())


func _on_dim_focus_entered() -> void:
	_dim_editing = true
	# Mouse clicks select-all from the release path so the caret click cannot
	# win. Keyboard focus (and a fresh preview grab) selects immediately.
	if _dim_spin == null or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_dim_spin.get_line_edit().select_all()


func _on_dim_text_submitted(raw: String) -> void:
	var parsed: Variant = _parse_dim_text(raw)
	if parsed == null:
		# Do not call apply() and do not emit dim_submitted. SpinBox still
		# parses the same signal on a deferred connection and would store a
		# truncated number; put the previous value back after that.
		var keep := _dim_spin.value if _dim_spin != null else 0.0
		_dim_rejecting = true
		dim_rejected.emit(raw)
		_restore_rejected_dim.call_deferred(keep)
		return
	if _dim_spin == null:
		return
	_dim_syncing = true
	_dim_spin.value = float(parsed)
	_dim_syncing = false
	# value_changed is skipped while syncing, and the slot radius is the blank
	# before the first centre (no single-DOF preview yet).
	_apply_slot_radius(float(parsed))
	dim_submitted.emit(_dim_spin.value)
	release_dim_focus()


func _restore_rejected_dim(keep: float) -> void:
	_dim_rejecting = false
	if _dim_spin == null:
		return
	_dim_syncing = true
	_dim_spin.value = keep
	_dim_syncing = false


## Number in the blank, after Godot's "prefix + space" / "space + suffix" chrome.
## Null when the raw string is not a single float (for example "23.22.5").
func _parse_dim_text(raw: String) -> Variant:
	var text := raw.strip_edges()
	if text.is_empty() or _dim_spin == null:
		return null
	var prefix := str(_dim_spin.prefix)
	var suffix := str(_dim_spin.suffix)
	if prefix != "":
		var spaced := prefix + " "
		if text.begins_with(spaced):
			text = text.substr(spaced.length())
		elif text.begins_with(prefix):
			text = text.substr(prefix.length())
	if suffix != "":
		var spaced := " " + suffix
		if text.ends_with(spaced):
			text = text.substr(0, text.length() - spaced.length())
		elif text.ends_with(suffix):
			text = text.substr(0, text.length() - suffix.length())
	text = text.strip_edges().replace(",", ".")
	if not text.is_valid_float():
		return null
	var v := float(text)
	if is_nan(v) or is_inf(v):
		return null
	return v


## Across-flats reads the typed length as AF. Circle keeps a radius number and
## shows Ø so the blank matches Smart Dimension's diameter.
func _sync_dim_affordance() -> void:
	if _dim_spin == null:
		return
	var suffix := "mm"
	var prefix := ""
	var tip := "Distance / radius — tracks the rubber-band while drawing; type to lock, Enter commits"
	if sketch_mode != null and sketch_mode.tool == SketchMode.Tool.POLYGON \
			and sketch_mode.tool_variant == "across_flats":
		suffix = " AF"
		tip = "Across flats — typed length is the AF, not the circumradius"
	elif sketch_mode != null and sketch_mode.tool == SketchMode.Tool.CIRCLE:
		prefix = "Ø"
		tip = "Circle radius (mm). Ø marks diameter; Smart Dimension drives Ø = 2× this radius"
	_dim_spin.suffix = suffix
	_dim_spin.prefix = prefix
	_dim_spin.tooltip_text = tip


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
	if _dim_syncing or _dim_rejecting or not _dim_editing:
		return
	_apply_slot_radius(v)
	# Live lock rubber-band while digits change (Enter still commits via signal).
	if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
		sketch_mode.set_length_override(v)


func _on_distance_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and _extrude_spin != null:
			_extrude_spin.get_line_edit().call_deferred("select_all")


func _on_dim_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Every left click, including the one that finds the field already
		# focused. Deferred so it runs after LineEdit places the caret.
		if mb.button_index == MOUSE_BUTTON_LEFT and _dim_spin != null:
			_dim_spin.get_line_edit().call_deferred("select_all")
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
	var map := {"blind": 0, "through_all": 1, "midplane": 2, "to_face": 3}
	if map.has(end):
		_finish_end.select(map[end])


func get_finish_end() -> String:
	if _finish_end == null:
		return "blind"
	var opts := ["blind", "through_all", "midplane", "to_face"]
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
		clear_up_to_face()
		# Sit to the right of the icon sketch rail, under the top chrome row.
		_place_bar(_finish_bar, Vector2(60, 42))
		_sync_dim_affordance()
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


func _process(_delta: float) -> void:
	if _finish_bar != null and _finish_bar.visible:
		_sync_dim_affordance()


func _place_bar(bar: Control, pos: Vector2) -> void:
	bar.reset_size()
	var sz := bar.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	bar.position = Vector2(
		clampf(pos.x, 8, maxf(8, vp.x - sz.x - 8)),
		clampf(pos.y, 8, maxf(8, vp.y - sz.y - 8)))
