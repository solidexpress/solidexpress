class_name VariablesPanel
extends PanelContainer
## Global equations table. One row per variable: name, expression (editable),
## computed value, delete. Add row at the bottom. Refresh on document revision
## (same document_changed hook the timeline uses).

signal status(text: String)

var view: DocumentView

var _list: VBoxContainer
var _rows := {}  # name -> row control
var _name_edit: LineEdit
var _expr_edit: LineEdit
var _config_option: OptionButton
var _config_name: LineEdit
var _refreshing := false


func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Variables"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var add_row := HBoxContainer.new()
	vbox.add_child(add_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "name"
	_name_edit.custom_minimum_size = Vector2(70, 0)
	add_row.add_child(_name_edit)
	_expr_edit = LineEdit.new()
	_expr_edit.placeholder_text = "expression"
	_expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expr_edit.text_submitted.connect(func(_t: String) -> void: _on_add())
	add_row.add_child(_expr_edit)
	var add_btn := UIIcons.button("add", "", "Add the variable")
	add_btn.pressed.connect(_on_add)
	add_row.add_child(add_btn)

	# Configurations: named snapshots of this table. Selecting one activates
	# it (regenerating the model); Save captures the current values.
	vbox.add_child(HSeparator.new())
	var cfg_row := HBoxContainer.new()
	vbox.add_child(cfg_row)
	var cfg_lbl := Label.new()
	cfg_lbl.text = "Config"
	cfg_lbl.add_theme_font_size_override("font_size", 11)
	cfg_row.add_child(cfg_lbl)
	_config_option = OptionButton.new()
	_config_option.tooltip_text = "Switch configuration (regenerates the model)"
	_config_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_config_option.item_selected.connect(_on_config_selected)
	cfg_row.add_child(_config_option)
	var cfg_del := UIIcons.button("delete", "", "Delete the selected configuration")
	cfg_del.pressed.connect(_on_config_delete)
	cfg_row.add_child(cfg_del)
	var save_row := HBoxContainer.new()
	vbox.add_child(save_row)
	_config_name = LineEdit.new()
	_config_name.placeholder_text = "config name"
	_config_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_config_name.text_submitted.connect(func(_t: String) -> void: _on_config_save())
	save_row.add_child(_config_name)
	var cfg_save := UIIcons.button("save", "", "Snapshot current variables under this name")
	cfg_save.pressed.connect(_on_config_save)
	save_row.add_child(cfg_save)

	# Wave 6.2: Quick configs for jaw_af 10 / 12 / 14.
	var quick_row := HBoxContainer.new()
	vbox.add_child(quick_row)
	var qlbl := Label.new()
	qlbl.text = "Jaw AF"
	qlbl.add_theme_font_size_override("font_size", 11)
	quick_row.add_child(qlbl)
	for size in [10, 12, 14]:
		var btn := Button.new()
		btn.text = str(size)
		btn.custom_minimum_size = Vector2(36, 0)
		btn.tooltip_text = "Set jaw_af and activate config " + str(size)
		btn.pressed.connect(func() -> void: _on_quick_jaw(size))
		quick_row.add_child(btn)

	view.document_changed.connect(refresh)
	refresh()


func _refresh_configs() -> void:
	_config_option.clear()
	var active: String = view.doc.active_configuration()
	var configs: Array = view.doc.configuration_list()
	for i in range(configs.size()):
		var config_name: String = configs[i]["name"]
		_config_option.add_item(config_name, i)
		if config_name == active:
			_config_option.select(i)
	if active == "" and configs.size() > 0:
		_config_option.select(-1)


func _on_config_save() -> void:
	var config_name := _config_name.text.strip_edges()
	if config_name == "":
		config_name = str(view.doc.active_configuration())
	if config_name == "":
		status.emit("Enter a configuration name")
		return
	if view.doc.save_configuration(config_name):
		_config_name.text = ""
		refresh()
		status.emit("Configuration saved: " + config_name)


func _on_config_selected(index: int) -> void:
	if _refreshing or index < 0:
		return
	var config_name := _config_option.get_item_text(index)
	if view.doc.activate_configuration(config_name):
		# Binding already regenerated; rebuild meshes and notify panels.
		view.refresh()
		view.document_changed.emit()
		status.emit("Configuration: " + config_name)
	else:
		status.emit("Failed to activate " + config_name)


func _on_quick_jaw(size: int) -> void:
	# Set jaw_af, snapshot/activate a config named by the size.
	if not view.doc.set_variable("jaw_af", str(size)):
		status.emit("Failed to set jaw_af")
		return
	if not view.doc.save_configuration(str(size)):
		status.emit("Failed to save configuration " + str(size))
		return
	if not view.doc.activate_configuration(str(size)):
		status.emit("Failed to activate configuration " + str(size))
		return
	view.refresh()
	view.document_changed.emit()
	status.emit("jaw_af = %d (config %d)" % [size, size])


func _on_config_delete() -> void:
	var index := _config_option.selected
	if index < 0:
		status.emit("No configuration selected")
		return
	var config_name := _config_option.get_item_text(index)
	if view.doc.remove_configuration(config_name):
		refresh()
		status.emit("Configuration deleted: " + config_name)


func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	for entry in view.doc.list_variables():
		_list.add_child(_make_row(entry))
	_refresh_configs()
	_refreshing = false


func add_variable(name: String, expr: String) -> bool:
	if name.strip_edges() == "" or expr.strip_edges() == "":
		return false
	if view.doc.set_variable(name.strip_edges(), expr.strip_edges()):
		view.graph_changed()
		status.emit("Variable %s = %s" % [name.strip_edges(), expr.strip_edges()])
		return true
	status.emit("Failed to set variable %s" % name)
	return false


func edit_variable(name: String, expr: String) -> bool:
	if view.doc.set_variable(name, expr):
		view.graph_changed()
		status.emit("Updated %s" % name)
		return true
	status.emit("Failed to update %s" % name)
	return false


func delete_variable(name: String) -> bool:
	if view.doc.remove_variable(name):
		view.graph_changed()
		status.emit("Removed %s" % name)
		return true
	status.emit("Cannot remove %s" % name)
	return false


func _on_add() -> void:
	if add_variable(_name_edit.text, _expr_edit.text):
		_name_edit.text = ""
		_expr_edit.text = ""


func _make_row(entry: Dictionary) -> Control:
	var name: String = entry["name"]
	var row := HBoxContainer.new()
	_rows[name] = row

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.custom_minimum_size = Vector2(70, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(name_lbl)

	var expr_edit := LineEdit.new()
	expr_edit.text = str(entry["expr"])
	expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expr_edit.add_theme_font_size_override("font_size", 12)
	expr_edit.text_submitted.connect(func(t: String) -> void: edit_variable(name, t))
	row.add_child(expr_edit)

	var val_lbl := Label.new()
	var err: String = entry.get("error", "")
	var val = entry.get("value", null)
	if err != "" or val == null or (val is float and is_nan(val)):
		val_lbl.text = "?"
		val_lbl.modulate = Color(1, 0.45, 0.4)
		if err != "":
			val_lbl.tooltip_text = err
	else:
		val_lbl.text = _fmt_value(float(val))
	val_lbl.custom_minimum_size = Vector2(48, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	var del := UIIcons.button("delete", "", "Delete variable " + name)
	del.pressed.connect(func() -> void: delete_variable(name))
	row.add_child(del)
	return row


func _fmt_value(v: float) -> String:
	if absf(v - roundf(v)) < 1e-9:
		return str(int(roundf(v)))
	var s := String.num(v, 4)
	# Trim trailing zeros and decimal point for a compact display similar to %.4g
	while s.ends_with("0"):
		s = s.left(s.length() - 1)
	if s.ends_with("."):
		s = s.left(s.length() - 1)
	return s
