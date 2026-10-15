class_name SweepBoss
extends RefCounted
## Swept Boss command: profile sketch, path sketch, OK.
## Closed non-construction loops are profiles; open chains are rails.


const REFUSED := "Select a profile sketch and a path sketch"
const PICK_PROFILE := "Swept Boss — pick the profile sketch"
const PICK_PATH := "Swept Boss — pick the path sketch"
const READY := "Swept Boss — OK to create the solid"

enum Slot { NONE, PROFILE, PATH }

var profile_fid := ""
var path_fid := ""
var slot := Slot.NONE
var panel: PanelContainer
var apply: Callable
var status: Callable

var _profile_btn: Button
var _path_btn: Button
var _ok: Button


## Ignore construction. A closed loop is a profile; an open chain is a rail.
static func role(sk) -> String:
	if sk == null:
		return "unknown"
	if sk.has_method("contour_count") and int(sk.contour_count()) >= 1:
		return "profile"
	for id in sk.entity_ids():
		var info: Dictionary = sk.entity_info(id)
		if bool(info.get("construction", false)):
			continue
		match str(info.get("type", "")):
			"line", "arc", "spline":
				return "rail"
	return "unknown"


func build(parent: Node) -> void:
	panel = PanelContainer.new()
	panel.name = "SweepBossPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 24
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_profile_btn = _chip(box, "SweepProfile", "Profile", "sweep:Profile")
	_profile_btn.pressed.connect(func() -> void: _arm_slot(Slot.PROFILE))
	_path_btn = _chip(box, "SweepPathPick", "Path", "sweep:Path")
	_path_btn.pressed.connect(func() -> void: _arm_slot(Slot.PATH))
	_ok = _chip(box, "SweepOk", "OK", "sweep:Ok")
	_ok.toggle_mode = false
	_ok.pressed.connect(ok)
	panel.position = Vector2(320, 44)


func armed() -> bool:
	return slot != Slot.NONE


func one_shot_ready(pads: Array, role_of: Callable) -> bool:
	var profiles := 0
	var rails := 0
	for fid in pads:
		match str(role_of.call(fid)):
			"profile":
				profiles += 1
			"rail":
				rails += 1
	return profiles == 1 and rails >= 1


func arm() -> void:
	profile_fid = ""
	path_fid = ""
	_arm_slot(Slot.PROFILE)
	if panel != null:
		panel.visible = true
	_sync_chips()
	_say(PICK_PROFILE)


func cancel() -> bool:
	if not armed() and (panel == null or not panel.visible):
		return false
	slot = Slot.NONE
	profile_fid = ""
	path_fid = ""
	if panel != null:
		panel.visible = false
	_sync_chips()
	_say("Swept Boss cancelled")
	return true


func consume_pad(fid: String, role_name: String) -> bool:
	if not armed():
		return false
	if fid == "":
		return true
	if slot == Slot.PROFILE:
		return _take_profile(fid, role_name)
	if slot == Slot.PATH:
		return _take_path(fid, role_name)
	return false


func ok() -> void:
	if profile_fid == "" or path_fid == "":
		_say(REFUSED)
		return
	if apply.is_valid():
		apply.call(profile_fid, path_fid)
	slot = Slot.NONE
	if panel != null:
		panel.visible = false
	_sync_chips()


func _take_profile(fid: String, role_name: String) -> bool:
	if role_name != "profile":
		_say("Swept Boss — that sketch is not a profile")
		return true
	profile_fid = fid
	_sync_chips()
	if path_fid == "":
		_arm_slot(Slot.PATH)
		_say(PICK_PATH)
	else:
		_say(READY)
	return true


func _take_path(fid: String, role_name: String) -> bool:
	if role_name != "rail":
		_say("Swept Boss — that sketch is not a path")
		return true
	path_fid = fid
	_sync_chips()
	_say(READY)
	return true


func _arm_slot(next: Slot) -> void:
	slot = next
	if panel != null:
		panel.visible = true
	_sync_chips()
	if next == Slot.PROFILE:
		_say(PICK_PROFILE)
	elif next == Slot.PATH:
		_say(PICK_PATH)


func _sync_chips() -> void:
	if _profile_btn != null:
		_profile_btn.button_pressed = slot == Slot.PROFILE
		_profile_btn.text = "Profile" if profile_fid == "" else "Profile ✓"
	if _path_btn != null:
		_path_btn.button_pressed = slot == Slot.PATH
		_path_btn.text = "Path" if path_fid == "" else "Path ✓"


func _chip(box: Node, node_name: String, label: String, auto_id: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_CLICK
	b.set_meta("sx_auto", auto_id)
	box.add_child(b)
	return b


func _say(text: String) -> void:
	if status.is_valid():
		status.call(text)
