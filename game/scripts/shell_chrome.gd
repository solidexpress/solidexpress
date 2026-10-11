class_name ShellChrome
extends Node
## Shell chip, thickness field, and the apply rule (hint, limit, feature name).
## The selection strip and the face-ops button only ask this to show or apply.

signal status(text: String)

## One row of chrome data: ids, label, default thickness.
const SPEC := {
	"chip_id": "strip:shell",
	"label": "Shell",
	"field_id": "finish:Thickness",
	"ok_id": "finish:Ok",
	"default_mm": 5.0,
}

const _NO_FACE := "Shell needs a planar face — nothing added"
const _LIMIT := "Shell thickness %.4f mm is at least half the %.4f mm extent (limit) — nothing added"

var _chip: Button
var _panel: PanelContainer
var _field: LineEdit
var _ok: Button


func build(row: Node, overlay: Control) -> void:
	_chip = Button.new()
	_chip.name = "StripShell"
	_chip.text = str(SPEC["label"])
	_chip.tooltip_text = "Hollow the body, removing the selected face"
	_chip.visible = false
	_chip.focus_mode = Control.FOCUS_CLICK
	_chip.set_meta("sx_auto", str(SPEC["chip_id"]))
	_chip.pressed.connect(_on_chip)
	row.add_child(_chip)

	_panel = PanelContainer.new()
	_panel.name = "ShellPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 20
	overlay.add_child(_panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var lbl := Label.new()
	lbl.text = "Thickness"
	box.add_child(lbl)
	_field = LineEdit.new()
	_field.name = "ThicknessLineEdit"
	_field.text = _default_text()
	_field.custom_minimum_size = Vector2(88, 0)
	_field.set_meta("sx_auto", str(SPEC["field_id"]))
	_field.text_submitted.connect(func(t: String) -> void: apply_mm(_parse_mm(t)))
	_field.focus_entered.connect(func() -> void: _field.call_deferred("select_all"))
	box.add_child(_field)
	_ok = Button.new()
	_ok.name = "ShellOk"
	_ok.text = "Apply"
	_ok.set_meta("sx_auto", str(SPEC["ok_id"]))
	_ok.pressed.connect(func() -> void: apply_mm(_parse_mm(_field.text)))
	box.add_child(_ok)


func panel() -> Control:
	return _panel


func sync() -> void:
	if _chip == null:
		return
	_chip.visible = _planar_face_selected()


func cancel() -> bool:
	if _panel == null or not _panel.visible:
		return false
	_panel.visible = false
	return true


func apply_mm(mm: float) -> void:
	var view := _view()
	if view == null:
		return
	var faces := _selected_faces(view)
	if faces.is_empty():
		status.emit(_NO_FACE)
		return
	var body := view.selected_body
	var extent := _min_extent(view, body)
	if extent > 0.0 and mm >= extent * 0.5 - 1e-9:
		_field.text = _default_text()
		status.emit(_LIMIT % [mm, extent])
		return
	if mm <= 0.0:
		_field.text = _default_text()
		status.emit(_NO_FACE)
		return
	var fid := view.feature_of_body(body)
	var added := ""
	if fid != "":
		added = view.doc.graph_add_shell(fid, faces, mm)
		if added != "":
			view.doc.graph_rename_no_undo(added, feature_title(mm))
	elif view.doc.shell_body(faces, mm):
		added = "body"
	if added == "":
		var err := str(view.doc.last_graph_error())
		status.emit("Shell failed" if err == "" else "Shell failed (%s)" % err)
		return
	_panel.visible = false
	view.graph_changed()
	status.emit("%s applied" % feature_title(mm))


static func feature_title(mm: float) -> String:
	return "Shell %.4f mm" % mm


func _on_chip() -> void:
	_field.text = _default_text()
	_panel.visible = true
	var want := _panel.get_combined_minimum_size()
	_panel.size = want
	var r := _chip.get_global_rect()
	var vp := get_viewport().get_visible_rect().size
	var pos := Vector2(r.position.x, r.end.y + 4.0)
	if pos.x + want.x > vp.x - 4.0:
		pos.x = maxf(4.0, vp.x - want.x - 4.0)
	if pos.y + want.y > vp.y - 4.0:
		pos.y = maxf(4.0, r.position.y - want.y - 4.0)
	_panel.global_position = pos
	_field.grab_focus()
	_field.call_deferred("select_all")


func _planar_face_selected() -> bool:
	var ix = get_parent()
	if ix == null or ix.view == null:
		return false
	if ix.sketch_mode != null and ix.sketch_mode.active:
		return false
	var face: String = ix.view.selected_face
	var body: String = ix.view.selected_body
	if face == "" or body == "":
		return false
	return _face_is_planar(ix.view, body, face)


func _face_is_planar(view: DocumentView, body: String, face: String) -> bool:
	var bb: Dictionary = view.doc.measure_bbox(face)
	if not bb.is_empty():
		var ext: Vector3 = bb["max"] - bb["min"]
		var mx := maxf(ext.x, maxf(ext.y, ext.z))
		var mn := minf(ext.x, minf(ext.y, ext.z))
		if mx > 1e-6 and mn <= maxf(1e-4, mx * 0.02):
			return true
	var node := view.body_node(body)
	var ids: PackedStringArray = view.doc.get_face_ids(body)
	var idx := ids.find(face)
	if node == null or node.mesh == null or idx < 0 or idx >= node.mesh.get_surface_count():
		return false
	var arrays: Array = node.mesh.surface_get_arrays(idx)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if normals.is_empty():
		return false
	var n0 := normals[0].normalized()
	for i in normals.size():
		if absf(normals[i].normalized().dot(n0)) < 0.999:
			return false
	return true


func _selected_faces(view: DocumentView) -> PackedStringArray:
	var faces := PackedStringArray(view.selected_faces)
	if faces.is_empty() and view.selected_face != "":
		faces = PackedStringArray([view.selected_face])
	return faces


func _min_extent(view: DocumentView, body: String) -> float:
	if body == "":
		return 0.0
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return 0.0
	var ext: Vector3 = bb["max"] - bb["min"]
	return minf(ext.x, minf(ext.y, ext.z))


func _view() -> DocumentView:
	var ix = get_parent()
	if ix == null:
		return null
	return ix.view


func _parse_mm(text: String) -> float:
	return float(text.strip_edges())


func _default_text() -> String:
	return str(int(SPEC["default_mm"]))
