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
var _view_of: Callable
var _sketching: Callable
## Last thickness that actually shelled. Refusals restore this, not the
## SPEC default, so a 1 mm part does not snap back to 5. build() seeds it.
var _last_mm := 5.0


func bind(view: Callable, sketching: Callable) -> void:
	_view_of = view
	_sketching = sketching


func build(row: Node, overlay: Control) -> void:
	_last_mm = float(SPEC["default_mm"])
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
	_release_field()
	return true


func apply_mm(mm: float) -> void:
	var view := _view()
	if view == null:
		return
	var faces := _selected_faces(view)
	if faces.is_empty():
		_refuse(_NO_FACE)
		return
	var body := view.selected_body
	var extent := _min_extent(view, body)
	if extent > 0.0 and mm >= extent * 0.5 - 1e-9:
		_refuse(_LIMIT % [mm, extent])
		return
	if mm <= 0.0:
		_refuse(_NO_FACE)
		return
	var fid := view.feature_of_body(body)
	var added := ""
	if fid != "":
		added = view.doc.graph_add_shell(fid, faces, mm)
		if added != "":
			view.doc.graph_rename_no_undo(added, unique_title(view, mm, added))
	elif view.doc.shell_body(faces, mm):
		added = "body"
	if added == "":
		var err := str(view.doc.last_graph_error())
		_refuse("Shell failed" if err == "" else "Shell failed (%s)" % err)
		return
	_last_mm = mm
	_panel.visible = false
	_release_field()
	view.graph_changed()
	status.emit("%s applied" % feature_title(mm))


static func feature_title(mm: float) -> String:
	return "Shell %.4f mm" % mm


static func unique_title(view, mm: float, skip_id: String = "") -> String:
	var title := feature_title(mm)
	if view == null or view.doc == null:
		return title
	var used := {}
	for f in view.doc.graph_features():
		if skip_id != "" and str(f.get("id", "")) == skip_id:
			continue
		used[str(f.get("name", ""))] = true
	if not used.has(title):
		return title
	var n := 2
	while used.has("%s %d" % [title, n]):
		n += 1
	return "%s %d" % [title, n]


func _on_chip() -> void:
	_field.text = _mm_text(_last_mm)
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
	var view := _view()
	if view == null:
		return false
	if _sketching.is_valid() and bool(_sketching.call()):
		return false
	var face: String = view.selected_face
	var body: String = view.selected_body
	if face == "" or body == "":
		return false
	return view.face_is_planar(body, face)


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
	if not _view_of.is_valid():
		return null
	return _view_of.call()


func _parse_mm(text: String) -> float:
	return float(text.strip_edges())


func _default_text() -> String:
	return _mm_text(float(SPEC["default_mm"]))


func _mm_text(mm: float) -> String:
	if absf(mm - round(mm)) < 1e-6:
		return str(int(round(mm)))
	return str(mm)


## Every refusal puts the last legal thickness back. The field must not
## keep a number the kernel rejected.
func _refuse(message: String) -> void:
	if _field != null and is_instance_valid(_field):
		_field.text = _mm_text(_last_mm)
	status.emit(message)
	_release_field()


## A focused thickness LineEdit swallows KEY_K before section toggle.
## Same deferred release as a property-panel LineEdit.
func _release_field() -> void:
	if _field == null or not is_instance_valid(_field):
		return
	if _field.has_focus():
		_field.release_focus()
	var tree := get_tree()
	if tree == null:
		if _field.has_focus():
			_field.release_focus()
		return
	tree.process_frame.connect(func() -> void:
		if _field != null and is_instance_valid(_field) and _field.has_focus():
			_field.release_focus()
		if tree.root == null:
			return
		var ix := tree.root.find_child("Interaction", true, false)
		if ix != null and ix.has_method("return_viewport_keys"):
			ix.return_viewport_keys()
	, CONNECT_ONE_SHOT)
