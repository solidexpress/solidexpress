class_name CamRail
extends PanelContainer
## Cam mode rail — replaces Modify. Zig-zag pocket + G-code export.

signal status(text: String)

var view: DocumentView
var _depth: SpinBox
var _stepover: SpinBox
var _feed: SpinBox
var _path: PackedVector3Array = PackedVector3Array()
var _overlay: MeshInstance3D


func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Cam — 2.5D pocket"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_depth = SxUi.labeled_spin(vbox, "Depth", 0.1, 200.0, 0.5, 2.0)
	_stepover = SxUi.labeled_spin(vbox, "Stepover", 0.1, 50.0, 0.5, 2.0)
	_feed = SxUi.labeled_spin(vbox, "Feed", 10.0, 5000.0, 10.0, 400.0)
	var pocket := UIIcons.button("cut", "Pocket face", "Zig-zag pocket on the selected face bbox")
	pocket.pressed.connect(_pocket_selected_face)
	vbox.add_child(pocket)
	var export_btn := UIIcons.button("save", "Export G-code…", "Write LinuxCNC-ish G1 toolpath")
	export_btn.pressed.connect(_export_gcode)
	vbox.add_child(export_btn)


func attach_overlay(parent_3d: Node3D) -> void:
	if _overlay != null:
		return
	_overlay = MeshInstance3D.new()
	_overlay.name = "CamToolpath"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.1)
	_overlay.material_override = mat
	parent_3d.add_child(_overlay)


func clear_path() -> void:
	_path = PackedVector3Array()
	if _overlay != null:
		_overlay.mesh = null


func _pocket_selected_face() -> void:
	if view == null or view.doc == null:
		return
	var face := view.selected_face
	if face == "":
		status.emit("Cam: select a planar face")
		return
	var bb: Dictionary = view.doc.measure_bbox(face)
	if bb.is_empty():
		status.emit("Cam: face has no bbox")
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	_path = view.doc.cam_pocket(mn.x, mn.y, mx.x, mx.y, _depth.value, _stepover.value)
	_draw_path()
	status.emit("Cam pocket: %d points" % _path.size())


func _draw_path() -> void:
	if _overlay == null:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in _path:
		im.surface_add_vertex(p)
	im.surface_end()
	_overlay.mesh = im


func _export_gcode() -> void:
	if _path.is_empty():
		status.emit("Cam: generate a pocket first")
		return
	if not view.doc.has_method("cam_post_gcode"):
		status.emit("Cam: G-code binding missing")
		return
	var gcode: String = view.doc.cam_post_gcode(_path, _feed.value)
	var path := "user://cam_pocket.ngc"
	var abs_path := ProjectSettings.globalize_path(path)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		status.emit("Cam: could not write " + abs_path)
		return
	f.store_string(gcode)
	f.close()
	status.emit("Exported G-code → " + abs_path)
