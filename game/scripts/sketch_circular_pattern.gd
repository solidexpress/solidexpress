class_name SketchCircularPattern
extends RefCounted
## Circular Sketch Pattern: copies of selected circles about a centre.
## Count includes the seed. Centre defaults to the sketch origin.


## Default count, total angle (degrees), centre rule, and entity kinds.
const SPEC := {
	"count": 8,
	"angle_deg": 360.0,
	"centre": "origin",
	"kinds": ["circle"],
}

const REFUSALS := {
	"count": "Pattern: count must be at least 2",
	"angle": "Pattern: angle must not be 0",
	"empty": "Pattern needs a selection",
	"failed": "Pattern failed",
}

const APPLIED := "Pattern: %d instances"


var count: int = SPEC["count"]
var angle_deg: float = SPEC["angle_deg"]
var centre := Vector2.ZERO
var panel: PanelContainer
var on_ok: Callable
var _count_spin: SpinBox
var _angle_spin: SpinBox
var _ok: Button


func build(parent: Control) -> void:
	panel = PanelContainer.new()
	panel.name = "PatternPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 20
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var count_lbl := Label.new()
	count_lbl.text = "Count"
	box.add_child(count_lbl)
	_count_spin = SpinBox.new()
	_count_spin.name = "PatternCount"
	_count_spin.min_value = 1
	_count_spin.max_value = 360
	_count_spin.step = 1
	_count_spin.value = count
	_count_spin.custom_minimum_size = Vector2(UiScale.px(80), 0)
	_count_spin.set_meta("sx_auto", "pattern:Count")
	_count_spin.value_changed.connect(_on_count)
	box.add_child(_count_spin)
	var ang_lbl := Label.new()
	ang_lbl.text = "Angle"
	box.add_child(ang_lbl)
	_angle_spin = SpinBox.new()
	_angle_spin.name = "PatternAngle"
	_angle_spin.min_value = 0
	_angle_spin.max_value = 360
	_angle_spin.step = 1
	_angle_spin.suffix = "°"
	_angle_spin.value = angle_deg
	_angle_spin.custom_minimum_size = Vector2(UiScale.px(100), 0)
	_angle_spin.set_meta("sx_auto", "pattern:Angle")
	_angle_spin.value_changed.connect(_on_angle)
	box.add_child(_angle_spin)
	_ok = Button.new()
	_ok.name = "PatternOk"
	_ok.text = "Apply"
	_ok.set_meta("sx_auto", "pattern:Ok")
	_ok.pressed.connect(_emit_ok)
	box.add_child(_ok)


func show_panel() -> void:
	if panel == null:
		return
	_count_spin.set_value_no_signal(count)
	_angle_spin.set_value_no_signal(angle_deg)
	panel.visible = true
	panel.reset_size()
	var want := panel.get_combined_minimum_size()
	panel.size = want
	var vp := panel.get_viewport().get_visible_rect().size
	var pos := Vector2(UiScale.px(56) + 8.0, UiScale.px(48))
	if pos.x + want.x > vp.x - 4.0:
		pos.x = maxf(4.0, vp.x - want.x - 4.0)
	if pos.y + want.y > vp.y - 4.0:
		pos.y = maxf(4.0, vp.y - want.y - 4.0)
	panel.global_position = pos


func hide_panel() -> void:
	if panel != null:
		panel.visible = false


func reset_centre() -> void:
	centre = Vector2.ZERO


func pull_fields() -> void:
	if _count_spin != null:
		var edit := _count_spin.get_line_edit()
		if edit != null:
			var typed := str(edit.text).strip_edges()
			if typed.is_valid_float():
				_count_spin.set_value_no_signal(float(typed))
		count = int(_count_spin.value)
	if _angle_spin != null:
		var aedit := _angle_spin.get_line_edit()
		if aedit != null:
			var atyped := str(aedit.text).strip_edges()
			if atyped.is_valid_float():
				_angle_spin.set_value_no_signal(float(atyped))
		angle_deg = float(_angle_spin.value)


func restore_count_default() -> void:
	count = int(SPEC["count"])
	if _count_spin != null:
		_count_spin.set_value_no_signal(count)


func pick_centre(sketch, uv: Vector2, tol: float) -> bool:
	if sketch == null:
		return false
	var best := Vector2.ZERO
	var best_d := tol
	var hit := false
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var kind := str(info.get("type", ""))
		var p := Vector2.ZERO
		if kind == "point":
			p = info.get("position", Vector2.ZERO)
		elif kind == "circle" or kind == "arc":
			p = info.get("center", Vector2.ZERO)
		else:
			continue
		var d := uv.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
			hit = true
	if hit:
		centre = best
	return hit


func kinds() -> Array:
	return SPEC["kinds"]


func _emit_ok() -> void:
	pull_fields()
	if on_ok.is_valid():
		on_ok.call()


func _on_count(v: float) -> void:
	count = int(v)


func _on_angle(v: float) -> void:
	angle_deg = v
