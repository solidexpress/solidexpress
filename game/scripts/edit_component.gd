class_name EditComponent
extends RefCounted
## Insert → New Part: an in-context component (source body + instance) with
## Edit Component on until the toggle is unselected. Not FeatureType::InContext.

signal changed

const PICK_PLANE := "Edit Component — pick a principle plane"
const NEW_PART := "New Part — Edit Component on"
const OFF := "Edit Component off"

var active := false
var pending := false
var editing_instance := ""
var source_body := ""
var panel: PanelContainer
var view: DocumentView
var status: Callable

var _toggle: CheckButton
var _syncing := false


func build(parent: Node) -> void:
	panel = PanelContainer.new()
	panel.name = "EditComponentBanner"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 24
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_toggle = CheckButton.new()
	_toggle.name = "EditComponentToggle"
	_toggle.text = "Edit Component"
	_toggle.tooltip_text = "Unselect to finalize the in-context part"
	_toggle.set_meta("sx_auto", "edit:Component")
	_toggle.toggled.connect(_on_toggle)
	box.add_child(_toggle)
	panel.position = Vector2(420, 8)


func snapshot() -> Dictionary:
	return {
		"on": active,
		"pending": pending,
		"instance": editing_instance,
		"source": source_body,
	}


func begin_new_part() -> void:
	active = true
	pending = true
	editing_instance = ""
	source_body = ""
	_show(true)
	_say(NEW_PART)


func adopt_body(body_id: String, name: String = "Part") -> String:
	if view == null or body_id == "":
		return ""
	var iid: String = view.adopt_as_component(body_id, name)
	if iid == "":
		return ""
	source_body = body_id
	editing_instance = iid
	pending = false
	active = true
	_show(true)
	changed.emit()
	return iid


func end() -> void:
	if not active and not pending:
		return
	if view != null and source_body != "":
		view.set_body_hidden(source_body, true)
		view.refresh()
	active = false
	pending = false
	editing_instance = ""
	_show(false)
	_say(OFF)
	changed.emit()


func reset() -> void:
	active = false
	pending = false
	editing_instance = ""
	source_body = ""
	_show(false)


func toggle() -> void:
	if active:
		end()
	else:
		_say("Edit Component — Insert → New Part first")


func _on_toggle(pressed: bool) -> void:
	if _syncing:
		return
	if pressed:
		if not active:
			_set_pressed(false)
			_say("Edit Component — Insert → New Part first")
		return
	if active:
		end()


func _show(on: bool) -> void:
	if panel != null:
		panel.visible = on
	_set_pressed(on and active)


func _set_pressed(on: bool) -> void:
	if _toggle == null:
		return
	_syncing = true
	_toggle.button_pressed = on
	_syncing = false


func _say(text: String) -> void:
	if status.is_valid():
		status.call(text)
