class_name SimRail
extends PanelContainer
## Sim mode rail — replaces Modify. Closed-form cantilever tip deflection.

signal status(text: String)

var view: DocumentView
var _force: SpinBox
var _e_mpa: SpinBox
var _width: SpinBox
var _thickness: SpinBox
var _result: Label


func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Sim — cantilever"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_force = SxUi.labeled_spin(vbox, "Force N", 0.1, 1e6, 1.0, 100.0)
	_e_mpa = SxUi.labeled_spin(vbox, "E MPa", 100.0, 5e5, 100.0, 200000.0)
	_width = SxUi.labeled_spin(vbox, "Width", 0.1, 500.0, 0.5, 10.0)
	_thickness = SxUi.labeled_spin(vbox, "Thick", 0.1, 500.0, 0.5, 5.0)
	var hint := Label.new()
	hint.text = "Uses body bbox length as the beam span"
	hint.add_theme_font_size_override("font_size", UiScale.body())
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)
	var solve := UIIcons.button("solve", "Solve", "Tip deflection δ = F L³ / (3 E I)")
	solve.pressed.connect(_solve)
	vbox.add_child(solve)
	_result = Label.new()
	_result.name = "SimResult"
	_result.text = "δ = —"
	_result.add_theme_font_size_override("font_size", UiScale.body())
	vbox.add_child(_result)


func _solve() -> void:
	if view == null or view.doc == null:
		return
	var body := view.selected_body
	if body == "":
		var ids: PackedStringArray = view.doc.body_ids()
		if ids.is_empty():
			status.emit("Sim: select a body")
			return
		body = ids[0]
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		status.emit("Sim: no bbox")
		return
	var size: Vector3 = bb["max"] - bb["min"]
	var length := maxf(size.x, maxf(size.y, size.z))
	# Prefer material E when the body has one (steel ≈ 200 GPa default above).
	var mat_name: String = view.doc.body_material(body) if view.doc.has_method("body_material") else ""
	if mat_name != "":
		for m in view.doc.material_list():
			if str(m.get("name", "")) == mat_name and m.has("young_mpa"):
				_e_mpa.value = float(m["young_mpa"])
				break
	var delta: float = view.doc.fea_cantilever(
			_force.value, length, _e_mpa.value, _width.value, _thickness.value)
	_result.text = "δ = %.3f mm  (L=%.1f)" % [delta, length]
	status.emit("Sim cantilever tip deflection %.3f mm" % delta)
