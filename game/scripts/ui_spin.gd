class_name SxUi
extends RefCounted
## Shared UI helpers. SpinBoxes use a fine step so typed values are not snapped
## to min+k*step (Godot Range default); arrows still move by `arrow_step`.

static func configure_spin(spin: SpinBox, min_v: float, max_v: float, arrow_step: float,
		value: float, as_int := false) -> SpinBox:
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1.0 if as_int else 0.001
	spin.custom_arrow_step = arrow_step
	spin.rounded = as_int
	spin.value = value
	# Focus selects the digits so a typed replacement (and Ctrl+A) edits the
	# number instead of appending, and instead of selecting scene bodies.
	spin.select_all_on_focus = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


static func labeled_spin(parent: Container, text: String, min_v: float, max_v: float,
		arrow_step: float, value: float, as_int := false) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(64, 0)
	lbl.add_theme_font_size_override("font_size", UiScale.body())
	row.add_child(lbl)
	var spin := SpinBox.new()
	configure_spin(spin, min_v, max_v, arrow_step, value, as_int)
	row.add_child(spin)
	return spin


## Compact number for a SpinBox LineEdit: "10" / "1.5" / "0.05", never
## "10.000" which clips to look like "0.0 mm" in a narrow field.
static func compact_number(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	var s := "%.4f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


## Write the committed value into the LineEdit and pin the caret at the start
## so the leading digits stay visible (suffix "mm" must not scroll "10.0 mm"
## into a tail that reads "0.0 mm").
static func reveal_committed_spin(spin: SpinBox, v: float = NAN) -> void:
	if spin == null:
		return
	if is_nan(v):
		v = spin.value
	v = clampf(v, spin.min_value, spin.max_value)
	spin.set_value_no_signal(v)
	var le := spin.get_line_edit()
	if le == null:
		return
	var shown := compact_number(v)
	var suffix := str(spin.suffix)
	if suffix != "":
		shown += " " + suffix
	le.text = shown
	pin_line_start(le)
	pin_line_start.call_deferred(le)


static func pin_line_start(le: LineEdit) -> void:
	if le == null or not is_instance_valid(le):
		return
	le.caret_column = 0
	# SpinBoxLineEdit has no scroll_horizontal (Godot 4.7). caret_column 0 is
	# the public way to keep the leading digits in view.


## True when a LineEdit / SpinBox / TextEdit currently owns keyboard focus —
## view keys (1/2/3/7/W/H/D/…) must not fire.
static func numeric_field_focused(vp: Viewport) -> bool:
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is SpinBox \
			or (f != null and f.get_parent() is SpinBox)


## Opt-in: after Enter / an arrow click, give the viewport the keys back.
## Does not change `configure_spin` — property panels, dim blanks, and Extrude
## Distance keep today's keep-focus behaviour.
static func release_focus_on_commit(spin: SpinBox) -> void:
	if spin == null:
		return
	if spin.has_meta("_sx_release_focus_on_commit"):
		return
	spin.set_meta("_sx_release_focus_on_commit", true)
	var line := spin.get_line_edit()
	if line != null:
		line.text_submitted.connect(func(_t: String) -> void:
			# One frame later so Enter-commits-the-fillet / strip commit run first.
			_deferred_release_line.call_deferred(line))
		line.gui_input.connect(func(event: InputEvent) -> void:
			_note_arrow_press(spin, line, event))
	spin.gui_input.connect(func(event: InputEvent) -> void:
		_note_arrow_press(spin, line, event))
	spin.value_changed.connect(func(_v: float) -> void:
		if not _is_arrow_commit(spin, line):
			return
		if line != null:
			_deferred_release_line.call_deferred(line)
		else:
			spin.release_focus.call_deferred())


static func _note_arrow_press(spin: SpinBox, line: LineEdit, event: InputEvent) -> void:
	if spin == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# gui_input.position is local to the control that received it.
	var local := mb.position
	if line != null:
		# A press on the LineEdit is typing, not an arrow.
		var lr: Rect2 = line.get_global_rect()
		var at := mb.global_position
		if at == Vector2.ZERO:
			at = line.get_global_rect().position + local
		if lr.has_point(at) and local.x < line.size.x:
			return
	var on_arrow := local.x > spin.size.x * 0.68 and local.x <= spin.size.x + 2.0 \
			and local.y >= 0.0 and local.y <= spin.size.y
	if not on_arrow:
		return
	spin.set_meta("_sx_arrow_press", true)
	# SpinBox::_gui_input emits value_changed before this signal, so the
	# value_changed handler cannot see the meta yet. Viewport.push_input
	# also does not update get_global_mouse_position. Release from here.
	if line != null:
		_deferred_release_line.call_deferred(line)
	else:
		spin.release_focus.call_deferred()


static func _is_arrow_commit(spin: SpinBox, line: LineEdit) -> bool:
	if spin == null:
		return false
	var marked := bool(spin.get_meta("_sx_arrow_press", false))
	if marked:
		spin.set_meta("_sx_arrow_press", false)
		return true
	# Typing: caret in the line and the text is not the committed value.
	if line != null and line.has_focus() and _line_mismatches_value(spin, line):
		return false
	var mouse_at := spin.get_global_mouse_position()
	var r: Rect2 = spin.get_global_rect()
	if not r.has_point(mouse_at):
		return false
	# Arrow gutter: right of the field. LMB-down is the real click; a parked
	# pointer over the arrows after a synthetic press still counts.
	return mouse_at.x >= r.position.x + r.size.x * 0.68


static func _line_mismatches_value(spin: SpinBox, line: LineEdit) -> bool:
	var raw := line.text.strip_edges().replace("mm", "").replace("MM", "").strip_edges()
	if not raw.is_valid_float():
		return true
	return not is_equal_approx(float(raw), spin.value)


static func _deferred_release_line(line: LineEdit) -> void:
	if line != null and is_instance_valid(line) and line.has_focus():
		line.release_focus()
