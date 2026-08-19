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


## True when a LineEdit / SpinBox / TextEdit currently owns keyboard focus —
## view keys (1/2/3/7/W/H/D/…) must not fire.
static func numeric_field_focused(vp: Viewport) -> bool:
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is SpinBox \
			or (f != null and f.get_parent() is SpinBox)
