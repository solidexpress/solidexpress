class_name TimelinePanel
extends PanelContainer
## Feature timeline (parametric history). One row per feature: type icon,
## suppress checkbox, name (inline rename), failure badge, drag/button
## reorder, delete. A draggable rollback bar (SolidWorks-style) skips
## regeneration of everything below it. Selecting a row highlights its body
## and opens a universal JSON param editor (v0 — structured data by design,
## so the same editor works for every feature type and for AI round-trips).

signal status(text: String)
signal feature_selected(fid: String, ftype: String)

var view: DocumentView

var _list: VBoxContainer
var _rows := {}  # feature id -> row control
var _selected_fid := ""
var _editor_box: VBoxContainer
var _params_edit: TextEdit
var _json_toggle: CheckButton
var _refreshing := false
var _renaming_fid := ""
var property_panel: PropertyPanel
var rollback_bar: Control


func selected_feature_id() -> String:
	return _selected_fid

## Feature type -> UIIcons glyph. Primitives resolve their kind from params.
const TYPE_ICONS := {
	"sketch": "sketch", "extrude": "extrude", "revolve": "revolve",
	"fillet": "fillet", "chamfer": "chamfer", "hole": "hole",
	"mirror": "mirror", "linear_pattern": "linear_pattern",
	"circular_pattern": "circular_pattern", "shell": "shell",
	"offset": "offset", "sweep": "arc", "loft": "area",
	"helix_sweep": "revolve", "thread": "cylinder", "import_step": "box",
	"import_stl": "box",
}


func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var outer := VBoxContainer.new()
	outer.name = "TimelineOuter"
	add_child(outer)
	var title := Label.new()
	title.text = "Timeline"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.name = "TimelineScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(250, 120)
	outer.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	# Structured property editor (typed fields, live preview). The raw JSON
	# editor below stays available behind an "advanced" toggle.
	property_panel = PropertyPanel.new()
	property_panel.view = view
	property_panel.status.connect(func(t: String) -> void: status.emit(t))
	outer.add_child(property_panel)

	_editor_box = VBoxContainer.new()
	_editor_box.visible = false
	outer.add_child(_editor_box)
	_json_toggle = CheckButton.new()
	_json_toggle.text = "Params (JSON, advanced)"
	_json_toggle.add_theme_font_size_override("font_size", 11)
	_json_toggle.toggled.connect(func(on: bool) -> void:
		_params_edit.visible = on
		_params_edit.get_parent().get_node("ApplyJson").visible = on)
	_editor_box.add_child(_json_toggle)
	_params_edit = TextEdit.new()
	_params_edit.custom_minimum_size = Vector2(250, 70)
	_params_edit.add_theme_font_size_override("font_size", 11)
	_params_edit.visible = false
	_editor_box.add_child(_params_edit)
	var apply_btn := UIIcons.button("ok", "Apply", "Apply the edited JSON parameters")
	apply_btn.name = "ApplyJson"
	apply_btn.visible = false
	apply_btn.pressed.connect(_apply_params)
	_editor_box.add_child(apply_btn)

	view.document_changed.connect(refresh)
	if get_viewport() != null:
		get_viewport().size_changed.connect(_clamp_height)
	refresh()
	_clamp_height()


var _scroll: ScrollContainer


func _clamp_height() -> void:
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var budget := vp.get_visible_rect().size.y - 42.0 - 12.0  # status bar + pad
	# Stay above the status bar; grow upward from the bottom-left anchor.
	var want := get_combined_minimum_size().y
	custom_minimum_size = Vector2(260, minf(want, maxf(160.0, budget * 0.55)))
	offset_top = -custom_minimum_size.y - 12.0
	offset_bottom = -42.0
	reset_size()
	if property_panel != null and property_panel.visible and _scroll != null:
		# Keep the property panel in view when it opens.
		await get_tree().process_frame
		if is_instance_valid(property_panel) and is_instance_valid(_scroll):
			_scroll.ensure_control_visible(property_panel)


func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	_renaming_fid = ""
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	rollback_bar = null
	var feats: Array = view.doc.graph_features()
	var n := feats.size()
	var rollback: int = view.doc.graph_rollback()
	for i in n:
		if rollback >= 0 and i == rollback:
			_add_rollback_bar()
		var row := _make_row(feats[i], i, n)
		if rollback >= 0 and i >= rollback:
			row.modulate = Color(1, 1, 1, 0.4)
		_list.add_child(row)
	# Bar sits at the end when rolled to end (or past the last feature).
	if rollback_bar == null and n > 0:
		_add_rollback_bar()
	if _selected_fid != "" and not _has_feature(feats, _selected_fid):
		_selected_fid = ""
		_editor_box.visible = false
	_refreshing = false


## Draggable rollback bar. Drop it onto a row to roll back before that
## feature; double-click rolls to the end of the timeline.
func _add_rollback_bar() -> void:
	rollback_bar = Button.new()
	rollback_bar.text = "═══ rollback ═══"
	rollback_bar.flat = true
	rollback_bar.add_theme_font_size_override("font_size", 10)
	rollback_bar.modulate = Color(0.55, 0.75, 1.0)
	rollback_bar.tooltip_text = "Rollback bar — drag onto a feature to roll back; double-click to roll to end"
	rollback_bar.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	var bar := rollback_bar
	var get_data := func(_pos: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = "═══ rollback ═══"
		bar.set_drag_preview(preview)
		return {"rollback_bar": true}
	var no_drop := func(_pos: Vector2, _data: Variant) -> bool:
		return false
	var drop_noop := func(_pos: Vector2, _data: Variant) -> void:
		pass
	rollback_bar.set_drag_forwarding(get_data, no_drop, drop_noop)
	rollback_bar.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.double_click \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			set_rollback(-1)
	)
	_list.add_child(rollback_bar)


func set_rollback(index: int) -> void:
	if view.doc.graph_set_rollback(index):
		view.graph_changed()
		status.emit("Rolled to end" if index < 0 else "Rolled back before feature %d" % (index + 1))
	else:
		status.emit("Rollback failed")


func _has_feature(feats: Array, fid: String) -> bool:
	for f in feats:
		if f["id"] == fid:
			return true
	return false


## UIIcons glyph for a feature row (primitives use their kind's shape glyph,
## booleans their op glyph).
static func _row_icon(f: Dictionary) -> String:
	var type := str(f["type"])
	var params_raw = JSON.parse_string(str(f.get("params", "{}")))
	var params: Dictionary = params_raw if params_raw is Dictionary else {}
	if type == "primitive":
		var kind := str(params.get("kind", "box"))
		return kind if UIIcons.GLYPHS.has(kind) else "box"
	if type == "boolean":
		var op := str(params.get("op", "fuse"))
		return op if UIIcons.GLYPHS.has(op) else "fuse"
	return TYPE_ICONS.get(type, "box")


func _make_row(f: Dictionary, index: int, count: int) -> Control:
	var fid: String = f["id"]
	var row := HBoxContainer.new()
	_rows[fid] = row

	var suppress := CheckBox.new()
	suppress.button_pressed = not f["suppressed"]
	suppress.tooltip_text = "Suppress/unsuppress"
	suppress.toggled.connect(func(on: bool) -> void: _set_suppressed(fid, not on))
	row.add_child(suppress)

	var name_btn := Button.new()
	name_btn.text = f["name"]
	name_btn.icon = UIIcons.get_icon(_row_icon(f), 14)
	name_btn.tooltip_text = "Select feature (click again to rename) · drag to reorder"
	name_btn.flat = true
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if f["suppressed"]:
		name_btn.modulate = Color(1, 1, 1, 0.45)
	name_btn.pressed.connect(_select_feature.bind(fid))
	name_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.double_click \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			_begin_rename(fid, row, name_btn)
	)
	row.add_child(name_btn)

	# Failure badge: regenerate stopped at this feature (tooltip = why).
	if f.get("failed", false):
		var badge := Label.new()
		badge.name = "FailBadge"
		badge.text = "!"
		badge.tooltip_text = str(f.get("error", "Regeneration failed"))
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
		badge.add_theme_font_size_override("font_size", 16)
		badge.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_show_whats_wrong(fid)
		)
		row.add_child(badge)
		name_btn.modulate = Color(1.0, 0.55, 0.5)

	if f.get("context_stale", false):
		var upd := Button.new()
		upd.name = "UpdateContext"
		upd.text = "Update Context"
		upd.tooltip_text = "Neighbor changed — click to recapture and regenerate this feature"
		upd.pressed.connect(func() -> void:
			view.doc.update_context(str(f.get("context_id", "")))
			view.graph_changed()
			status.emit("Context updated")
		)
		row.add_child(upd)

	# Drag reorder: rows are both drag sources (feature) and drop targets
	# (feature reorder, or the rollback bar landing before this feature).
	var get_data := func(_pos: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = str(f["name"])
		name_btn.set_drag_preview(preview)
		return {"timeline_fid": fid}
	var can_drop := func(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data.has("timeline_fid") or data.has("rollback_bar"))
	var drop := func(_pos: Vector2, data: Variant) -> void:
		if data.has("rollback_bar"):
			set_rollback(index)
		elif str(data["timeline_fid"]) != fid:
			_move_feature(str(data["timeline_fid"]), index)
	name_btn.set_drag_forwarding(get_data, can_drop, drop)

	var edit_btn := UIIcons.button("rename", "", "Rename feature")
	edit_btn.pressed.connect(func() -> void: _begin_rename(fid, row, name_btn))
	row.add_child(edit_btn)

	if PropertyPanel.has_schema(str(f["type"])):
		var params_btn := UIIcons.button("dimension", "", "Edit this feature's parameters")
		params_btn.pressed.connect(func() -> void: _select_feature(fid))
		row.add_child(params_btn)

	var up := UIIcons.button("up", "", "Move up the timeline")
	up.disabled = index <= 0
	up.pressed.connect(func() -> void: _move_feature(fid, index - 1))
	row.add_child(up)

	var down := UIIcons.button("down", "", "Move down the timeline")
	down.disabled = index >= count - 1
	down.pressed.connect(func() -> void: _move_feature(fid, index + 1))
	row.add_child(down)

	var del := UIIcons.button("delete", "", "Delete feature")
	del.pressed.connect(_delete_feature.bind(fid))
	row.add_child(del)
	return row


func _begin_rename(fid: String, row: HBoxContainer, name_btn: Button) -> void:
	if _renaming_fid != "":
		return
	_renaming_fid = fid
	var edit := LineEdit.new()
	edit.text = name_btn.text
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := name_btn.get_index()
	name_btn.visible = false
	row.add_child(edit)
	row.move_child(edit, idx)
	edit.grab_focus()
	edit.select_all()
	var finish := func(commit: bool) -> void:
		if _renaming_fid != fid:
			return
		var new_name := edit.text.strip_edges()
		_renaming_fid = ""
		if edit.get_parent() == row:
			row.remove_child(edit)
			edit.queue_free()
		name_btn.visible = true
		if commit and new_name != "" and new_name != name_btn.text:
			if view.doc.graph_rename(fid, new_name):
				view.graph_changed()
				status.emit("Feature renamed")
			else:
				status.emit("Rename failed")
	edit.text_submitted.connect(func(_t: String) -> void: finish.call(true))
	edit.focus_exited.connect(func() -> void: finish.call(true))
	edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			finish.call(false)
			edit.accept_event()
	)


func _move_feature(fid: String, new_index: int) -> void:
	if view.doc.graph_move(fid, new_index):
		view.graph_changed()
		status.emit("Feature moved")
	else:
		status.emit("Cannot move: would break feature dependencies")
		_flash_row(fid)


## Brief red flash on a row (dependency-blocked drop feedback).
func _flash_row(fid: String) -> void:
	var row: Control = _rows.get(fid)
	if row == null or not is_instance_valid(row):
		return
	row.modulate = Color(1.0, 0.4, 0.35)
	var tw := row.create_tween()
	tw.tween_property(row, "modulate", Color.WHITE, 0.6)


func _select_feature(fid: String) -> void:
	_selected_fid = fid
	for f in view.doc.graph_features():
		if f["id"] != fid:
			continue
		feature_selected.emit(fid, str(f.get("type", "")))
		_params_edit.text = _pretty_json(f["params"])
		_editor_box.visible = true
		# Typed property editor when the feature type has a schema; the JSON
		# editor stays available behind the advanced toggle either way.
		if PropertyPanel.has_schema(f["type"]):
			property_panel.open(fid)
			_clamp_height()
		else:
			property_panel.visible = false
		var body: String = f["output_body"]
		if body != "":
			view.select_entity(body, "")
		return


func _pretty_json(raw: String) -> String:
	var parsed = JSON.parse_string(raw)
	return JSON.stringify(parsed, "  ") if parsed != null else raw


func _apply_params() -> void:
	if _selected_fid == "":
		return
	if JSON.parse_string(_params_edit.text) == null:
		status.emit("Invalid JSON in params")
		return
	if view.doc.graph_set_params(_selected_fid, _params_edit.text):
		view.graph_changed()
		status.emit("Feature updated")
	else:
		status.emit("Regenerate FAILED — params reverted? check values")


func _set_suppressed(fid: String, suppressed: bool) -> void:
	if view.doc.graph_set_suppressed(fid, suppressed):
		view.graph_changed()


func _delete_feature(fid: String) -> void:
	if view.doc.graph_remove(fid):
		view.graph_changed()
		status.emit("Feature deleted")
	else:
		status.emit("Cannot delete: later features depend on it")


func _show_whats_wrong(fid: String) -> void:
	var diag: Dictionary = view.doc.diagnose_feature(fid)
	var pop := PopupPanel.new()
	pop.name = "WhatsWrong"
	var col := VBoxContainer.new()
	pop.add_child(col)
	var title := Label.new()
	title.text = "What's wrong — " + str(diag.get("name", fid))
	col.add_child(title)
	var err := Label.new()
	err.text = str(diag.get("error", ""))
	err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(err)
	for r in diag.get("repairs", []):
		var chip := Button.new()
		chip.text = str(r)
		chip.pressed.connect(func() -> void:
			status.emit(str(r))
			pop.hide()
			pop.queue_free()
		)
		col.add_child(chip)
	add_child(pop)
	pop.popup_centered(Vector2(320, 160))
