class_name MirrorFeatures
extends RefCounted
## Feature Mirror command: plane face + timeline feature list + OK.
## Empty collector is a refuse; body-mode Mirror stays on the one-click path.

## Arm, plane pick, add, and commit ids. Kinds the collector accepts.
const SPEC := {
	"arm_id": "mirror:Features",
	"plane_id": "mirror:Plane",
	"add_id": "mirror:Add",
	"ok_id": "mirror:Ok",
	"kinds": ["extrude", "shell", "revolve", "fillet", "chamfer", "hole"],
}

const REFUSALS := {
	"empty": "Mirror: pick features to mirror",
	"plane": "Mirror: pick a planar face or origin plane",
	"body": "Mirror: select a body",
}

const HINTS := {
	"arm": "Mirror: click a planar face or origin plane",
	"features": "Mirror: Shift+click features, then OK",
	"ready": "Mirror — OK to create",
}

const APPLIED := "Mirrored feature"

var body_id := ""
var plane_point := Vector3.ZERO
var plane_normal := Vector3.UP
var has_plane := false
var feature_ids: PackedStringArray = PackedStringArray()
var panel: PanelContainer
var apply: Callable
var status: Callable
var add_current: Callable
var on_plane_arm: Callable
## True when the collector is live. Timeline uses this to skip the property editor.
var on_live: Callable

var _live := false
var _plane_btn: Button
var _add_btn: Button
var _ok: Button


func collecting() -> bool:
	return _live


func sources() -> PackedStringArray:
	return feature_ids.duplicate()


func build(parent: Node) -> void:
	if panel != null:
		return
	panel = PanelContainer.new()
	panel.name = "MirrorFeaturesPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 24
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_plane_btn = _chip(box, "MirrorPlane", "Plane", str(SPEC["plane_id"]))
	_plane_btn.pressed.connect(func() -> void:
		if on_plane_arm.is_valid():
			on_plane_arm.call()
		_say(HINTS["arm"]))
	_add_btn = _chip(box, "MirrorAdd", "Add", str(SPEC["add_id"]))
	_add_btn.pressed.connect(_on_add)
	_ok = _chip(box, "MirrorOk", "Apply", str(SPEC["ok_id"]))
	_ok.toggle_mode = false
	_ok.pressed.connect(ok)
	panel.position = Vector2(320, 44)


func arm(body: String) -> void:
	body_id = body
	has_plane = false
	feature_ids = PackedStringArray()
	_set_live(true)
	_place()
	_sync()
	_say(HINTS["arm"])


func set_plane(point: Vector3, normal: Vector3) -> void:
	if not _live:
		return
	plane_point = point
	plane_normal = normal
	has_plane = true
	_sync()
	if feature_ids.is_empty():
		_say(HINTS["features"])
	else:
		_say(HINTS["ready"])


## Origin Front / Top / Right. Point is the part origin; normal from BASIS.
func set_origin_plane(name: String) -> bool:
	var found: Dictionary = OriginPlanes.row(name)
	if found.is_empty():
		return false
	set_plane(Vector3.ZERO, (found["normal"] as Vector3).normalized())
	return has_plane


func add(fid: String) -> void:
	if not _live or fid == "":
		return
	if feature_ids.has(fid):
		_sync()
		return
	feature_ids.append(fid)
	_sync()
	if has_plane:
		_say(HINTS["ready"])
	else:
		_say(HINTS["arm"])


func ok() -> void:
	if not _live:
		return
	if not has_plane:
		_say(REFUSALS["plane"])
		return
	if feature_ids.is_empty():
		_say(REFUSALS["empty"])
		return
	var body := body_id
	var pt := plane_point
	var n := plane_normal
	var src := feature_ids.duplicate()
	_finish()
	if apply.is_valid():
		apply.call(body, pt, n, src)


func cancel() -> bool:
	if not _live and (panel == null or not panel.visible):
		return false
	_finish()
	_say("Cancelled")
	return true


func _on_add() -> void:
	if add_current.is_valid():
		add_current.call()
	_sync()


func _finish() -> void:
	_set_live(false)
	has_plane = false
	feature_ids = PackedStringArray()
	if panel != null:
		panel.visible = false
	_sync()


func _set_live(live: bool) -> void:
	_live = live
	if on_live.is_valid():
		on_live.call(live)


func _place() -> void:
	if panel == null:
		return
	panel.visible = true
	panel.reset_size()
	var want := panel.get_combined_minimum_size()
	if want.x < 8.0 or want.y < 8.0:
		want = Vector2(280, 36)
	panel.size = want
	panel.position = Vector2(320, 44)
	panel.move_to_front()


func _sync() -> void:
	if _plane_btn != null:
		_plane_btn.text = "Plane ✓" if has_plane else "Plane"
	if _add_btn != null:
		_add_btn.text = "Add (%d)" % feature_ids.size() if not feature_ids.is_empty() else "Add"


func _chip(box: Node, node_name: String, label: String, auto_id: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_CLICK
	b.custom_minimum_size = Vector2(UiScale.px(64), 0)
	b.set_meta("sx_auto", auto_id)
	box.add_child(b)
	return b


func _say(text: String) -> void:
	if status.is_valid():
		status.call(text)
