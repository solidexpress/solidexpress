class_name ViewHud
extends PanelContainer
## Compact view controls (bottom-right): RGB origin sticks, display mode,
## section, frame, and a View strip ([View][▼][Save]).

signal display_cycle_requested
signal section_toggle_requested
signal explode_toggle_requested(on: bool)
signal zebra_toggle_requested(on: bool)
signal fit_requested
signal save_view_requested(view_name: String)
signal view_restore_requested(view_name: String)
signal view_delete_requested(view_name: String)
signal default_view_requested(view_id: String)

## Built-in orientations (not deletable).
const DEFAULT_VIEWS := [
	{"id": "front", "label": "Front"},
	{"id": "right", "label": "Right"},
	{"id": "top", "label": "Top"},
	{"id": "iso", "label": "Isometric"},
]

var _display_btn: Button
var _section_btn: Button
## Exploded view lives here beside Section: both are ways of seeing, not docks.
var _explode_btn: Button
var _zebra_btn: Button
var _fit_btn: Button
var _save_view_btn: Button
var _views_drop_btn: Button
var _views_popup: PopupPanel
var _views_list: VBoxContainer
var _rename_popup: PopupPanel
var _rename_edit: LineEdit
var _user_view_names: PackedStringArray = PackedStringArray()
var origin_triad: OriginTriadHud


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Transparent shell so the RGB sticks float without a panel backdrop.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	# Tiny RGB sticks above Shade/Section/Frame — width tracks this menu.
	origin_triad = OriginTriadHud.new()
	origin_triad.name = "OriginTriad"
	col.add_child(origin_triad)
	var controls := PanelContainer.new()
	controls.name = "Controls"
	col.add_child(controls)
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 4)
	controls.add_child(btn_col)
	_display_btn = Button.new()
	_display_btn.text = "Shade"
	_display_btn.tooltip_text = "Cycle display mode (Shift+W)"
	_display_btn.pressed.connect(func() -> void: display_cycle_requested.emit())
	btn_col.add_child(_display_btn)
	_section_btn = Button.new()
	_section_btn.text = "Section"
	_section_btn.toggle_mode = true
	_section_btn.tooltip_text = "Toggle section view (K)"
	_section_btn.toggled.connect(func(_on: bool) -> void: section_toggle_requested.emit())
	btn_col.add_child(_section_btn)
	_explode_btn = Button.new()
	_explode_btn.name = "ExplodeToggle"
	_explode_btn.text = "Explode"
	_explode_btn.toggle_mode = true
	_explode_btn.visible = false  # only meaningful once the document has parts
	_explode_btn.tooltip_text = "Separate components along their joints, and collapse them back"
	_explode_btn.toggled.connect(func(on: bool) -> void: explode_toggle_requested.emit(on))
	btn_col.add_child(_explode_btn)
	_zebra_btn = Button.new()
	_zebra_btn.name = "ZebraToggle"
	_zebra_btn.text = "Zebra"
	_zebra_btn.toggle_mode = true
	_zebra_btn.tooltip_text = "Zebra stripes — continuity across a knit or a cylinder"
	_zebra_btn.toggled.connect(func(on: bool) -> void: zebra_toggle_requested.emit(on))
	btn_col.add_child(_zebra_btn)
	_fit_btn = Button.new()
	_fit_btn.text = "Frame"
	_fit_btn.tooltip_text = (
		"Zoom extents — frame the selection (or the whole model) centered "
		+ "in view. Shortcut: F. Shift+F always frames everything."
	)
	_fit_btn.pressed.connect(func() -> void: fit_requested.emit())
	btn_col.add_child(_fit_btn)

	# One strip: [ View ] [ ▼ ] [ Save ] — same type size as Shade/Section/Frame.
	var view_strip := PanelContainer.new()
	view_strip.name = "ViewStrip"
	var strip_style := StyleBoxEmpty.new()
	view_strip.add_theme_stylebox_override("panel", strip_style)
	btn_col.add_child(view_strip)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 0)
	view_strip.add_child(strip_row)
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(8, 0)
	strip_row.add_child(left_pad)
	var view_lbl := Label.new()
	view_lbl.text = "View"
	# No font_size override — matches Shade / Section / Frame button text.
	strip_row.add_child(view_lbl)
	_views_drop_btn = Button.new()
	# Use an icon for the dropdown rather than a cryptic text glyph.
	_views_drop_btn.text = ""
	_views_drop_btn.icon = UIIcons.get_icon("down", 14)
	_views_drop_btn.tooltip_text = "Show default and saved views"
	_views_drop_btn.custom_minimum_size = Vector2(22, 0)
	_compact_icon_btn(_views_drop_btn)
	_views_drop_btn.pressed.connect(_toggle_views_popup)
	strip_row.add_child(_views_drop_btn)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(1, 0)
	strip_row.add_child(gap)
	_save_view_btn = UIIcons.button("save", "", "Save current view — orientation, zoom, and target (name it, then Enter)")
	_save_view_btn.icon = UIIcons.get_icon("save", 14)
	_save_view_btn.custom_minimum_size = Vector2(22, 22)
	_compact_icon_btn(_save_view_btn)
	_save_view_btn.pressed.connect(_begin_save_rename)
	strip_row.add_child(_save_view_btn)

	_views_popup = PopupPanel.new()
	_views_popup.name = "ViewsPopup"
	add_child(_views_popup)
	_views_list = VBoxContainer.new()
	_views_list.name = "ViewsList"
	_views_list.add_theme_constant_override("separation", 2)
	_views_list.custom_minimum_size = Vector2(160, 0)
	_views_popup.add_child(_views_list)
	_rebuild_views_popup()

	_rename_popup = PopupPanel.new()
	_rename_popup.name = "ViewRenamePopup"
	add_child(_rename_popup)
	var rename_row := HBoxContainer.new()
	_rename_popup.add_child(rename_row)
	_rename_edit = LineEdit.new()
	_rename_edit.name = "ViewRenameEdit"
	_rename_edit.placeholder_text = "View name"
	_rename_edit.custom_minimum_size = Vector2(140, 0)
	_rename_edit.clear_button_enabled = true
	_rename_edit.text_submitted.connect(_commit_save_rename)
	_rename_edit.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			_rename_popup.hide()
			_rename_edit.accept_event())
	rename_row.add_child(_rename_edit)


func set_camera(cam: OrbitCamera) -> void:
	if origin_triad != null:
		origin_triad.set_camera(cam)


func sync_from_view(view: DocumentView) -> void:
	if view == null:
		return
	var labels := ["Shade", "Edges", "Wire"]
	var i: int = clampi(int(view.display_mode), 0, 2)
	_display_btn.text = labels[i]
	_section_btn.set_pressed_no_signal(view.section_enabled)
	# Explode only appears when there is an assembly to explode.
	_explode_btn.visible = view.doc.instance_list().size() > 0
	_explode_btn.set_pressed_no_signal(view.doc.is_exploded())
	_zebra_btn.set_pressed_no_signal(view.zebra_enabled)


## Flatten button chrome so icon / ▼ sit tight next to the View label.
func _compact_icon_btn(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for kind in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(kind, empty)
	b.add_theme_constant_override("h_separation", 0)
	b.add_theme_constant_override("outline_size", 0)
	b.flat = true


## Refresh the ▼ menu contents (defaults always; user names from camera).
func sync_named_views(names: PackedStringArray) -> void:
	_user_view_names = names.duplicate()
	_rebuild_views_popup()


func _begin_save_rename() -> void:
	if _views_popup.visible:
		_views_popup.hide()
	_rename_edit.text = ""
	var anchor := _save_view_btn.get_global_rect()
	var popup_h := 36
	_rename_popup.popup(Rect2i(
		_popup_pos(anchor, 160, popup_h),
		Vector2i(160, popup_h)))
	_rename_edit.grab_focus()


func _commit_save_rename(text: String) -> void:
	var view_name := text.strip_edges()
	_rename_popup.hide()
	if view_name == "":
		return
	for entry in DEFAULT_VIEWS:
		if view_name.to_lower() == str(entry["label"]).to_lower():
			# Don't shadow built-in orientation names.
			return
	save_view_requested.emit(view_name)


func _toggle_views_popup() -> void:
	if _views_popup.visible:
		_views_popup.hide()
		return
	_rebuild_views_popup()
	var anchor := _views_drop_btn.get_global_rect()
	var sz := _views_list.get_combined_minimum_size()
	var w := maxf(160.0, sz.x + 16.0)
	var h := maxf(40.0, sz.y + 16.0)
	var pos := _popup_pos(anchor, int(w), int(h))
	# Align the menu's right edge with the ▼ button (opens leftward).
	pos.x = int(anchor.end.x - w)
	_views_popup.popup(Rect2i(pos, Vector2i(int(w), int(h))))


## Place a popup below the anchor when there is room; otherwise above
## (ViewHud docks bottom-right above the status bar).
func _popup_pos(anchor: Rect2, w: int, h: int) -> Vector2i:
	var vp := get_viewport().get_visible_rect()
	var below := Vector2i(int(anchor.position.x), int(anchor.end.y + 2))
	if float(below.y + h) <= vp.end.y - 4.0:
		return below
	return Vector2i(int(anchor.position.x), int(anchor.position.y - float(h) - 2.0))


func _rebuild_views_popup() -> void:
	if _views_list == null:
		return
	for c in _views_list.get_children():
		_views_list.remove_child(c)
		c.queue_free()
	var def_lbl := Label.new()
	def_lbl.text = "Default"
	def_lbl.add_theme_font_size_override("font_size", UiScale.caption())
	def_lbl.modulate = Color(1, 1, 1, 0.6)
	_views_list.add_child(def_lbl)
	for entry in DEFAULT_VIEWS:
		var go := Button.new()
		go.text = str(entry["label"])
		go.alignment = HORIZONTAL_ALIGNMENT_LEFT
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vid := str(entry["id"])
		go.pressed.connect(func() -> void:
			default_view_requested.emit(vid)
			_views_popup.hide())
		_views_list.add_child(go)
	_views_list.add_child(HSeparator.new())
	var user_lbl := Label.new()
	user_lbl.text = "Saved"
	user_lbl.add_theme_font_size_override("font_size", UiScale.caption())
	user_lbl.modulate = Color(1, 1, 1, 0.6)
	_views_list.add_child(user_lbl)
	if _user_view_names.is_empty():
		var empty := Label.new()
		empty.text = "(none yet — use Save)"
		empty.add_theme_font_size_override("font_size", UiScale.caption())
		empty.modulate = Color(1, 1, 1, 0.5)
		_views_list.add_child(empty)
		return
	for view_name in _user_view_names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_views_list.add_child(row)
		var go := Button.new()
		go.text = str(view_name)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.tooltip_text = "Restore “%s” — orientation + zoom" % view_name
		go.alignment = HORIZONTAL_ALIGNMENT_LEFT
		go.add_theme_font_size_override("font_size", UiScale.body())
		var n := str(view_name)
		go.pressed.connect(func() -> void:
			view_restore_requested.emit(n)
			_views_popup.hide())
		row.add_child(go)
		var del := Button.new()
		del.name = "Delete_%s" % view_name
		del.text = "×"
		del.tooltip_text = "Delete saved view “%s”" % view_name
		del.custom_minimum_size = Vector2(24, 0)
		del.pressed.connect(func() -> void:
			view_delete_requested.emit(n)
			# Keep popup open so the user can delete more; rebuild happens via sync.
			)
		row.add_child(del)
