class_name SketchContextChrome
extends Control
## On-canvas chips for sketch tool variants and selection actions.
## Sits above the 3D view; positions follow the pointer or selection.

signal variant_chosen(kind: String, variant: String)
signal action_chosen(action: String)
signal finish_requested(op: String, distance: float, end: String,
		thin_thickness: float, thin_type: String, flip_side: bool,
		selected_contours: Array)
## Enter in the dim blank while drawing: typed length/radius commit.
signal dim_submitted(value: float)
## Blank text did not parse. WP4 wires this to the status line.
signal dim_rejected(raw: String)
## Extrude pressed (or distance read) while the Distance text does not parse.
signal distance_rejected(raw: String)

const CHIP_H := 28
const CHIP_PAD := 6
## Visible action chips stay this wide at most; leftover verbs go in … More.
## A full-viewport HBox under the finish bar ate the wrench walk's empty-canvas
## click at the view centre (sx-033 A1 follow-up).
const ACTION_ROW_CAP := 420.0


func _chip_h() -> int:
	return int(round(UiScale.px(CHIP_H)))

var sketch_mode: SketchMode
var _variant_bar: HBoxContainer
var _action_bar: VBoxContainer
## Verbs currently shown on `_action_bar`. Chips that do not fit between the
## rail and the viewport edge go in a … More menu. Empty when the bar is hidden.
var _action_verbs: Array = []
var _action_wrap_width := -1.0
var _action_dock_to_rail := false
var _finish_bar: VBoxContainer
var _finish_dim_row: HBoxContainer
var _finish_end_row: HBoxContainer
## Sketch feature id the Op/End/distance belong to. Empty = a new sketch.
var _finish_owner := ""
## Process-frame when the bar was last hidden. Save As hide+show is same-frame.
var _finish_hidden_frame := -1
var _extrude_spin: SpinBox
var _finish_op: OptionButton
var _finish_end: OptionButton
var _thin_spin: SpinBox
var _thin_type: OptionButton
var _flip_side: CheckButton
var _contour_bar: HBoxContainer
var _selected_contours: Array = []  # int indices; empty = all
var _dim_spin: SpinBox
var _extrude_btn: Button
var _distance_label: Label
var _extrude_readout: Label
var _dim_cue: Label
var _radius_label: Label
var _thin_label: Label
var _thin_feature: CheckButton
var _thin_badge: Label
var _face_panel: PanelContainer
var _face_label: Label
## One-shot: the next model-face click is the Up To Surface target.
var _face_pick_armed := false
## True only after Pick face. Choosing the End condition arms the row
## without stealing Circle / Line / Jaw clicks.
var _face_pick_explicit := false
var _active_kind := ""
## True while the dim LineEdit has focus — mouse must not overwrite typed digits.
var _dim_editing := false
var _dim_syncing := false
## True while the dim blank is intentionally empty (no number of its own).
var _dim_blank_empty := false
## Last numeric_field_key applied to the dim blank.
var _shown_numeric_key := ""
## SpinBox's deferred submit treats "23.22.5" as 23.22. Hold the previous value.
var _dim_rejecting := false
## Last value written by a rubber-band sync or a successful Enter. A rejected
## string must restore this, not the spin value typing already truncated.
var _dim_last_good := -1.0
## Distance LineEdit: ignore our own value/text writes, and hold the spin
## value from focus-in so an unparseable string cannot leave a truncated .value.
var _distance_syncing := false
var _distance_rejecting := false
var _distance_origin := 20.0
## Bumped on click and on typed text so a pending next-frame select_all cannot
## re-select the first digit and let the second key replace it.
var _distance_select_gen := 0
## Bumped when Distance is replaced outright (File → New / Open). A deferred
## reassert of the previous document's "5" must not land after that reset.
var _distance_line_gen := 0
## Same generation gate for the dim blank (it previously only deferred
## select_all, so a late select re-selected the first digit).
var _dim_select_gen := 0
## Next digit / '.' / (Distance) '-' replaces the whole line. Set on focus and
## every left click so a caret click that clears select_all still replaces.
var _dim_replace_next := false
## True while Circle armed the radius blank itself. A tool key (S/L/…) must
## leave that blank. A click or a typed character clears it so an expression
## can keep the letters.
var _dim_focus_from_tool := false
## Bumped when an unfocused key seed writes the line, so a late focus_entered
## does not arm replace and select_all the seed (first digit dropped).
var _dim_seed_gen := 0
var _dim_seed_seen := 0
var _distance_replace_next := false
## True while the Distance line is not one float. Survives SpinBox apply on
## focus exit, which would otherwise to_float "20.07.5" into 20 and Extrude.
var _distance_line_invalid := false
var _distance_invalid_raw := ""
## Set from Distance gui_input so a SpinBox apply text_changed cannot clear
## _distance_line_invalid as if the user had typed a valid number.
var _distance_user_key := false
## Face id for an Up To Surface end. The finish signal does not carry it;
## finish_extrude reads this after the extrude feature exists.
var up_to_face_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_variant_bar = _make_bar()
	_variant_bar.name = "VariantBar"
	# The row's box used to be STOP. A wide rect (padding past the chips, or a
	# layout pass that had not shrunk yet) then ate the first canvas press
	# after a rail Polygon / Circle / Slot click. Buttons still block.
	_variant_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_bar = VBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.add_theme_constant_override("separation", 4)
	_action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_bar)
	_finish_bar = VBoxContainer.new()
	_finish_bar.name = "FinishBar"
	_finish_bar.add_theme_constant_override("separation", 4)
	_finish_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_finish_bar)
	_finish_dim_row = _make_hbox()
	_finish_dim_row.name = "FinishDimRow"
	_finish_end_row = _make_hbox()
	_finish_end_row.name = "FinishEndRow"
	_finish_bar.add_child(_finish_dim_row)
	_finish_bar.add_child(_finish_end_row)
	_contour_bar = _make_bar()
	_build_finish_bar()
	_finish_bar.visible = false
	_contour_bar.visible = false
	_variant_bar.visible = false
	_action_bar.visible = false


func _make_bar() -> HBoxContainer:
	var bar := _make_hbox()
	add_child(bar)
	return bar


func _make_hbox() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	return bar


func _fit_spin(spin: SpinBox) -> void:
	# Floor is UiScale.px(140). The line edit is wider than UiScale.px(110)
	# after the arrow buttons, so "20.0 mm" and " AF" stay readable.
	spin.custom_minimum_size = Vector2(UiScale.px(200), _chip_h())
	var edit := spin.get_line_edit()
	if edit != null:
		edit.custom_minimum_size = Vector2(UiScale.px(140), 0)


func _build_finish_bar() -> void:
	_dim_spin = SpinBox.new()
	_dim_spin.name = "DimSpin"
	_dim_spin.min_value = 0.01
	_dim_spin.max_value = 10000
	_dim_spin.step = 0.01
	_dim_spin.value = 10
	_dim_spin.suffix = "mm"
	# Select comes from arm_replace_on_focus. The built-in mouse-up select
	# lands a frame late under soft GL and turns the first typed "10" into "0".
	_dim_spin.select_all_on_focus = false
	# true so a trailing "." is kept. The dim key handler owns the string so
	# SpinBox cannot park the caret at column 0.
	_dim_spin.update_on_text_changed = true
	_dim_spin.tooltip_text = "Distance / radius — tracks the rubber-band while drawing; type to lock, Enter commits"
	_fit_spin(_dim_spin)
	_radius_label = Label.new()
	_radius_label.name = "RadiusLabel"
	_radius_label.text = "Radius"
	_radius_label.visible = false
	_radius_label.custom_minimum_size = Vector2(UiScale.px(56), _chip_h())
	_radius_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_radius_label.tooltip_text = "Circle radius (mm). The number in the blank is the radius, not the diameter."
	_dim_cue = Label.new()
	_dim_cue.name = "DimRadiusCue"
	_dim_cue.text = "r"
	_dim_cue.visible = false
	_dim_cue.custom_minimum_size = Vector2(UiScale.px(16), _chip_h())
	_dim_cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dim_cue.tooltip_text = "Circle radius (mm). The r label is the radius; diameter is 2× this number"
	_finish_dim_row.add_child(_radius_label)
	_finish_dim_row.add_child(_dim_cue)
	_finish_dim_row.add_child(_dim_spin)
	var dim_edit := _dim_spin.get_line_edit()
	dim_edit.name = "DimLineEdit"
	SxUi.use_armed_replace_select(dim_edit)
	dim_edit.focus_entered.connect(_on_dim_focus_entered)
	dim_edit.focus_exited.connect(_on_dim_focus_exited)
	dim_edit.text_submitted.connect(_on_dim_text_submitted)
	dim_edit.text_changed.connect(_on_dim_text_changed)
	dim_edit.gui_input.connect(_on_dim_edit_gui_input)
	_dim_spin.value_changed.connect(_on_dim_value_changed)
	var dim_btn := Button.new()
	dim_btn.text = "Dim"
	dim_btn.custom_minimum_size = Vector2(44, _chip_h())
	dim_btn.tooltip_text = "Apply driving dimension to the selection"
	dim_btn.pressed.connect(func() -> void: action_chosen.emit("dimension"))
	_finish_dim_row.add_child(dim_btn)
	var spin_gap := Control.new()
	spin_gap.name = "DimDistanceGap"
	spin_gap.custom_minimum_size = Vector2(UiScale.px(24), _chip_h())
	spin_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish_dim_row.add_child(spin_gap)
	_distance_label = Label.new()
	_distance_label.name = "DistanceLabel"
	_distance_label.text = "D"
	_distance_label.visible = false
	_distance_label.custom_minimum_size = Vector2(0, 0)
	_distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finish_dim_row.add_child(_distance_label)
	var extrude_lbl := Label.new()
	extrude_lbl.name = "ExtrudeLabel"
	extrude_lbl.text = "Extrude"
	extrude_lbl.custom_minimum_size = Vector2(UiScale.px(56), _chip_h())
	extrude_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extrude_lbl.tooltip_text = "Blind extrude distance (mm)"
	_finish_dim_row.add_child(extrude_lbl)
	_extrude_spin = SpinBox.new()
	_extrude_spin.name = "DistanceSpin"
	_extrude_spin.min_value = -1000
	_extrude_spin.max_value = 1000
	_extrude_spin.step = 0.5
	_extrude_spin.value = 20
	_extrude_spin.suffix = "mm"
	# A click that focuses D selects the digits, same as the dim blank, so
	# typing 7.5 replaces 20.0 instead of appending. The select is armed
	# from focus / click and cancelled once a digit lands. Built-in
	# select_all_on_focus waits for mouse-up and can select that first digit.
	_extrude_spin.select_all_on_focus = false
	_extrude_spin.tooltip_text = "Blind distance (ignored for Through All cuts)"
	_fit_spin(_extrude_spin)
	var dist_edit := _extrude_spin.get_line_edit()
	dist_edit.name = "DistanceLineEdit"
	SxUi.use_armed_replace_select(dist_edit)
	SxUi.keep_editing_on_submit(dist_edit)
	dist_edit.gui_input.connect(_on_distance_edit_gui_input)
	dist_edit.text_changed.connect(_on_distance_text_changed)
	dist_edit.text_submitted.connect(_on_distance_text_submitted)
	dist_edit.focus_entered.connect(_on_distance_focus_entered)
	dist_edit.focus_exited.connect(_on_distance_focus_exited)
	_finish_dim_row.add_child(_extrude_spin)
	_extrude_readout = Label.new()
	_extrude_readout.name = "ExtrudeReadout"
	_extrude_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Wide enough for "Extrude 20 mm" and "Extrude 7.5 mm" without clipping.
	_extrude_readout.custom_minimum_size = Vector2(UiScale.px(128), _chip_h())
	_extrude_readout.clip_text = false
	_extrude_readout.tooltip_text = "Distance the next Extrude will send"
	_finish_dim_row.add_child(_extrude_readout)
	_refresh_extrude_readout(_extrude_spin.value)
	_finish_end = OptionButton.new()
	_finish_end.name = "FinishEnd"
	_finish_end.tooltip_text = "Extrude end: Blind / Through All / Midplane / Up To Surface"
	for n in ["Blind", "Through All", "Midplane", "Up To Surface"]:
		_finish_end.add_item(n)
	_finish_end.item_selected.connect(_on_finish_end_selected)
	_finish_end.custom_minimum_size = Vector2(100, _chip_h())
	_finish_end_row.add_child(_finish_end)
	_face_panel = PanelContainer.new()
	_face_panel.name = "UpToFaceBox"
	_face_panel.visible = false
	_face_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var face_row := HBoxContainer.new()
	face_row.name = "UpToFaceRow"
	face_row.add_theme_constant_override("separation", 4)
	face_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_face_label = Label.new()
	_face_label.name = "UpToFaceLabel"
	_face_label.text = "Face: none"
	_face_label.custom_minimum_size = Vector2(UiScale.px(72), _chip_h())
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face_row.add_child(_face_label)
	var opp := Button.new()
	opp.name = "OppositeFaceButton"
	opp.text = "Opposite face"
	opp.custom_minimum_size = Vector2(0, _chip_h())
	opp.tooltip_text = "Use the target-body face farthest along the negative sketch normal"
	opp.pressed.connect(_on_opposite_face_pressed)
	face_row.add_child(opp)
	_face_panel.add_child(face_row)
	_finish_end_row.add_child(_face_panel)
	_finish_op = OptionButton.new()
	_finish_op.name = "FinishOp"
	for n in ["New", "Cut", "Fuse"]:
		_finish_op.add_item(n)
	_finish_op.custom_minimum_size = Vector2(64, _chip_h())
	# Cut must not auto-select Through All; that silently drops Up To Surface.
	_finish_end_row.add_child(_finish_op)
	_thin_feature = CheckButton.new()
	_thin_feature.name = "ThinFeature"
	_thin_feature.text = "Thin feature"
	_thin_feature.button_pressed = false
	_thin_feature.custom_minimum_size = Vector2(UiScale.px(120), _chip_h())
	_thin_feature.tooltip_text = "Thin wall. Off extrudes a solid (thin thickness 0)."
	_thin_feature.toggled.connect(func(_on: bool) -> void: _apply_thin_visibility())
	_finish_end_row.add_child(_thin_feature)
	_thin_badge = Label.new()
	_thin_badge.name = "ThinBadge"
	_thin_badge.visible = false
	_thin_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thin_badge.custom_minimum_size = Vector2(UiScale.px(90), _chip_h())
	_finish_end_row.add_child(_thin_badge)
	_thin_label = Label.new()
	_thin_label.name = "ThinLabel"
	_thin_label.text = "Thin"
	_thin_label.custom_minimum_size = Vector2(UiScale.px(36), _chip_h())
	_thin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finish_end_row.add_child(_thin_label)
	_thin_spin = SpinBox.new()
	_thin_spin.name = "ThinSpin"
	_thin_spin.min_value = 0
	_thin_spin.max_value = 1000
	_thin_spin.step = 0.5
	_thin_spin.value = 0
	_thin_spin.suffix = "mm"
	_thin_spin.tooltip_text = "Thin wall (0 = solid closed profile)"
	_fit_spin(_thin_spin)
	_thin_spin.value_changed.connect(func(_v: float) -> void: _refresh_thin_badge())
	_finish_end_row.add_child(_thin_spin)
	_thin_type = OptionButton.new()
	_thin_type.name = "ThinType"
	_thin_type.tooltip_text = "Thin wall offset: One Side / Midplane"
	for n in ["One Side", "Midplane"]:
		_thin_type.add_item(n)
	_thin_type.custom_minimum_size = Vector2(88, _chip_h())
	_finish_end_row.add_child(_thin_type)
	_flip_side = CheckButton.new()
	_flip_side.name = "FlipSide"
	_flip_side.text = "Flip"
	_flip_side.custom_minimum_size = Vector2(56, _chip_h())
	_flip_side.tooltip_text = (
		"Thin wall side, or Extruded Cut Flip Side to Cut on an open profile")
	_finish_end_row.add_child(_flip_side)
	_apply_thin_visibility()
	var ex := Button.new()
	ex.name = "ExtrudeButton"
	ex.text = "Extrude"
	ex.custom_minimum_size = Vector2(72, _chip_h())
	ex.pressed.connect(_emit_finish_requested)
	_finish_dim_row.add_child(ex)
	_extrude_btn = ex
	var rv := Button.new()
	rv.name = "RevolveButton"
	rv.text = "Revolve"
	rv.custom_minimum_size = Vector2(72, _chip_h())
	rv.pressed.connect(func() -> void: action_chosen.emit("revolve"))
	_finish_end_row.add_child(rv)
	var done := Button.new()
	done.name = "DoneButton"
	done.text = "Done"
	done.custom_minimum_size = Vector2(56, _chip_h())
	done.tooltip_text = "End line / spline chain (Esc · right-click · double-click)"
	done.pressed.connect(func() -> void: action_chosen.emit("done"))
	_finish_end_row.add_child(done)


func dim_value() -> float:
	return _dim_spin.value if _dim_spin else 10.0


## Parse the Distance LineEdit first. On success store it on the spin and
## return it so Extrude without Enter still sends the typed number. On
## failure return the previous spin value and emit distance_rejected.
func extrude_distance() -> float:
	var prev := _extrude_spin.value if _extrude_spin else 20.0
	var parsed: Variant = _commit_distance_text()
	if parsed == null:
		var raw := _distance_invalid_raw if _distance_invalid_raw != "" else _distance_raw_text()
		distance_rejected.emit(raw)
		return prev
	return float(parsed)


## True when the Distance LineEdit is one float after prefix/suffix stripping.
func distance_line_parses() -> bool:
	if _distance_line_invalid:
		return false
	return _parse_spin_text(_extrude_spin, _distance_raw_text()) != null


## Focus the Distance LineEdit for typed blind distance. Optional seed digit
## or decimal replaces the text (WP2 unfocused burst). A parsed seed is stored
## on the spin and on ExtrudeReadout.
func focus_distance_for_typing(seed: String = "") -> void:
	if _extrude_spin == null:
		return
	var edit := _extrude_spin.get_line_edit()
	if edit == null:
		return
	_distance_origin = _extrude_spin.value
	edit.grab_focus()
	if seed != "":
		# grab_focus armed replace-on-next-key. The seed is the whole burst.
		_distance_replace_next = false
		_distance_select_gen += 1
		edit.set_meta("_sx_replace_armed", false)
		edit.set_meta("_sx_select_gen", int(edit.get_meta("_sx_select_gen", 0)) + 1)
	if seed != "" and seed.is_valid_float():
		var v := float(seed)
		_distance_line_invalid = false
		_distance_invalid_raw = ""
		_write_extrude_spin(v, seed)
		# Origin is the seeded value, not the spin's previous number, so
		# Escape restores this session's start instead of the last burst.
		_distance_origin = v
		edit.caret_column = seed.length()
		edit.deselect()
		edit.deselect.call_deferred()
	elif seed != "":
		_distance_syncing = true
		edit.text = seed
		_distance_syncing = false
		edit.caret_column = seed.length()
		edit.deselect()
		edit.deselect.call_deferred()
		var parsed: Variant = _parse_spin_text(_extrude_spin, seed)
		if parsed != null:
			_distance_line_invalid = false
			_distance_invalid_raw = ""
			_write_extrude_spin(float(parsed), seed)
			_distance_origin = float(parsed)
		else:
			_distance_line_invalid = true
			_distance_invalid_raw = seed
			_write_extrude_spin(_distance_origin, seed)
		# The burst is a real edit. Until Enter, S / redo must not treat the
		# field as idle, and Enter itself must reach this LineEdit.
		SxUi.mark_mid_entry(edit, true)
	else:
		_select_distance_all()
		_select_distance_all_if_gen.call_deferred(_distance_select_gen)
		_select_distance_all_next_frame.call_deferred(_distance_select_gen)


## Parsed dim LineEdit number while that text is a single float, else null.
func typed_dim_value() -> Variant:
	if _dim_spin == null:
		return null
	var edit := _dim_spin.get_line_edit()
	if edit == null:
		return null
	return _parse_spin_text(_dim_spin, edit.text)


## Sync from mouse rubber-band. Skipped while the user is typing in the blank.
func set_dim_value(v: float) -> void:
	if _dim_spin == null or _dim_editing:
		return
	_dim_blank_empty = false
	_dim_last_good = v
	_apply_slot_radius(v)
	_dim_syncing = true
	_dim_spin.value = v
	_dim_syncing = false
	_sync_dim_affordance()


## No number of this tool's own. The suffix stays so an AF blank still reads AF.
func clear_dim_blank() -> void:
	if _dim_spin == null:
		return
	_dim_blank_empty = true
	_dim_syncing = true
	_dim_spin.set_value_no_signal(_dim_spin.min_value)
	_dim_last_good = -1.0
	var edit := _dim_spin.get_line_edit()
	if edit != null:
		edit.text = _empty_dim_text()
		# The previous tool's digits still count as "typed since intent" on
		# this same LineEdit, so the empty-blank reassert bailed and focus
		# left the spin minimum ("0.01") on screen.
		edit.set_meta("_sx_typed", "")
		SxUi.note_focus_intent(edit)
		SxUi.mark_mid_entry(edit, false)
	_dim_syncing = false


func _empty_dim_text() -> String:
	if _dim_spin == null:
		return ""
	return str(_dim_spin.prefix) + str(_dim_spin.suffix)


## Slot has no single-DOF preview until the first centre is down, so the blank
## is the radius. After that click the blank is the centre distance.
func _apply_slot_radius(v: float) -> void:
	if sketch_mode == null or sketch_mode.tool != SketchMode.Tool.SLOT:
		return
	if sketch_mode.has_single_dof_preview():
		return
	sketch_mode.slot_radius = maxf(v, 0.01)


## Store the face, disarm the one-shot pick, label from the face midpoint z,
## and enable Extrude when the id is non-empty.
func set_up_to_face(id: String) -> void:
	up_to_face_id = id.strip_edges()
	_face_pick_armed = false
	_face_pick_explicit = false
	_sync_face_box()
	if up_to_face_id != "" and _extrude_btn != null:
		_extrude_btn.disabled = false


## Remember that the next model-face click is the target. Does not clear the id.
## This is the explicit Pick face arm: canvas clicks are eaten until one lands.
func arm_face_pick() -> void:
	_face_pick_armed = true
	_face_pick_explicit = true
	if up_to_face_id == "" and _face_label != null:
		_face_label.text = "Face: none"
	if _face_panel != null:
		_face_panel.visible = true


func wants_face_pick() -> bool:
	return _face_pick_armed


## True after Pick face. The End = Up To Surface row alone is not explicit.
func face_pick_explicit() -> bool:
	return _face_pick_explicit


## Drop a pending Up To Surface pick. A face id already stored stays so Save
## can put it back; only the one-shot that Esc would cancel is cleared.
func disarm_face_pick() -> void:
	_face_pick_armed = false
	_face_pick_explicit = false


## Empty id, Face: none, and disable Extrude while End is Up To Surface.
func clear_up_to_face() -> void:
	up_to_face_id = ""
	_face_pick_armed = false
	_face_pick_explicit = false
	if _face_label != null:
		_face_label.text = "Face: none"
	_sync_face_box()


func _on_finish_end_selected(idx: int) -> void:
	# OptionButton.select does not emit this. Do not copy view.selected_face.
	if idx == 3:
		clear_up_to_face()
		# Show the face row and keep wants_face_pick true, but do not eat
		# sketch-tool clicks until the user presses Pick face.
		_face_pick_armed = true
		_face_pick_explicit = false
		if _face_label != null:
			_face_label.text = "Face: none"
		if _face_panel != null:
			_face_panel.visible = true
		if _extrude_btn != null:
			_extrude_btn.disabled = true
	else:
		clear_up_to_face()
		if _face_panel != null:
			_face_panel.visible = false
		if _extrude_btn != null:
			_extrude_btn.disabled = false


func _sync_face_box() -> void:
	if _face_label != null:
		if up_to_face_id == "":
			_face_label.text = "Face: none"
		else:
			_face_label.text = _face_z_text(up_to_face_id)
	if _face_panel != null:
		_face_panel.visible = get_finish_end() == "to_face" or _face_pick_armed
	# Blind readout is unused for Up To Surface. Hiding it keeps Extrude
	# on a 1280-wide finish bar after Opposite face appears.
	if _extrude_readout != null:
		_extrude_readout.visible = get_finish_end() != "to_face"
	if _finish_bar != null and _finish_bar.visible:
		_place_finish_session()
	_refresh_extrude_enabled()


func _refresh_extrude_enabled() -> void:
	if _extrude_btn == null:
		return
	_extrude_btn.disabled = get_finish_end() == "to_face" and up_to_face_id == ""


func _face_z_text(id: String) -> String:
	var z := _face_midpoint_z(id)
	if is_nan(z):
		return "Face: " + id.left(8)
	return "Face: z %s mm" % String.num(z, 1)


func _face_midpoint_z(id: String) -> float:
	if id == "" or sketch_mode == null or sketch_mode.view == null:
		return NAN
	var doc = sketch_mode.view.doc
	if doc == null or not doc.has_method("face_midpoint"):
		return NAN
	var mid: Variant = doc.face_midpoint(id)
	if mid is Vector3:
		return (mid as Vector3).z
	return NAN


## Target-body face farthest along −sketch normal (bottom of a top-face sketch).
func _on_opposite_face_pressed() -> void:
	var face_id := _opposite_face_id()
	if face_id == "":
		return
	set_up_to_face(face_id)


func _opposite_face_id() -> String:
	if sketch_mode == null or not sketch_mode.active:
		return ""
	var view = sketch_mode.view
	if view == null or view.doc == null:
		return ""
	var body := _up_to_target_body(view)
	if body == "":
		return ""
	if not view.doc.has_method("get_face_ids") or not view.doc.has_method("face_midpoint"):
		return ""
	var n: Vector3 = sketch_mode.plane_normal()
	if n.length_squared() < 1e-12:
		return ""
	n = n.normalized()
	var origin: Vector3 = sketch_mode.plane_origin
	var best_id := ""
	var best_along := -INF
	for face_id in view.doc.get_face_ids(body):
		var mid: Variant = view.doc.face_midpoint(face_id)
		if not (mid is Vector3):
			continue
		# Farthest along −n. The sketch-host face sits near 0 and loses.
		var along := -((mid as Vector3) - origin).dot(n)
		if along > best_along:
			best_along = along
			best_id = str(face_id)
	return best_id


func _up_to_target_body(view) -> String:
	if sketch_mode != null and str(sketch_mode.target_fid) != "":
		if view.has_method("body_of_feature"):
			var from_target := str(view.body_of_feature(sketch_mode.target_fid))
			if from_target != "":
				return from_target
	if view.selected_body != "":
		return str(view.selected_body)
	if view.doc != null and view.doc.has_method("body_ids"):
		var ids: PackedStringArray = view.doc.body_ids()
		if ids.size() == 1:
			return str(ids[0])
	return ""


func _apply_thin_visibility() -> void:
	var on := _thin_feature != null and _thin_feature.button_pressed
	if _thin_label != null:
		_thin_label.visible = on
	if _thin_spin != null:
		_thin_spin.visible = on
	if _thin_type != null:
		_thin_type.visible = on
	if _flip_side != null:
		_flip_side.visible = on
	_refresh_thin_badge()


func _refresh_thin_badge() -> void:
	if _thin_badge == null or _thin_feature == null or _thin_spin == null:
		return
	var show := _thin_feature.button_pressed and _thin_spin.value > 0.0
	_thin_badge.visible = show
	if show:
		_thin_badge.text = "Thin %s mm" % _plain_num(_thin_spin.value)


## Digits plus the Distance prefix/suffix, so a reset replaces a leftover "5".
func _format_distance_text(v: float) -> String:
	var text := _plain_num(v)
	if _extrude_spin == null:
		return text
	var prefix := str(_extrude_spin.prefix)
	var suffix := str(_extrude_spin.suffix)
	if prefix != "":
		text = prefix + " " + text
	if suffix != "":
		text += " " + suffix
	return text


func _plain_num(v: float) -> String:
	var s := String.num(v, 4)
	if s.contains("."):
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
	return s


func _emit_finish_requested() -> void:
	var parsed: Variant = _commit_distance_text()
	if parsed == null:
		var raw := _distance_invalid_raw if _distance_invalid_raw != "" else _distance_raw_text()
		distance_rejected.emit(raw)
		return
	var dist := float(parsed)
	var thin := 0.0
	if _thin_feature != null and _thin_feature.button_pressed and _thin_spin != null:
		thin = _thin_spin.value
	finish_requested.emit(
		["new", "cut", "fuse"][_finish_op.selected],
		dist,
		["blind", "through_all", "midplane", "to_face"][_finish_end.selected],
		thin,
		["one_side", "midplane"][_thin_type.selected],
		_flip_side.button_pressed,
		_selected_contours.duplicate())


func _distance_raw_text() -> String:
	if _extrude_spin == null:
		return ""
	var edit := _extrude_spin.get_line_edit()
	if edit == null:
		return ""
	return edit.text


## Store a parsed Distance value on the spin. Null when the LineEdit is not a
## single float (for example "20.07.5"). Does not emit distance_rejected.
func _commit_distance_text() -> Variant:
	if _extrude_spin == null:
		return null
	if _distance_line_invalid:
		return null
	var parsed: Variant = _parse_spin_text(_extrude_spin, _distance_raw_text())
	if parsed == null:
		return null
	_write_extrude_spin(float(parsed))
	_distance_origin = float(parsed)
	return parsed


## Write Distance onto the spin and ExtrudeReadout. keep_text restores the
## LineEdit so setting .value cannot replace in-progress digits with "7.0".
func _write_extrude_spin(v: float, keep_text: String = "") -> void:
	if _extrude_spin == null:
		return
	var edit := _extrude_spin.get_line_edit()
	var text := keep_text
	var caret := 0
	var had_sel := false
	var sel_from := 0
	var sel_to := 0
	if edit != null:
		if text == "":
			text = edit.text
		caret = edit.caret_column
		had_sel = edit.has_selection()
		if had_sel:
			sel_from = edit.get_selection_from_column()
			sel_to = edit.get_selection_to_column()
	_distance_line_gen += 1
	var gen := _distance_line_gen
	_distance_syncing = true
	_extrude_spin.value = v
	_apply_distance_line(edit, text, caret, had_sel, sel_from, sel_to)
	_distance_syncing = false
	_refresh_extrude_readout(v)
	# SpinBox formats the line on a deferred update ("7" → "7.0"). Re-assert
	# the typed string so the next key can still make 7.5.
	if text != "":
		_reassert_distance_line.call_deferred(gen, text, caret, had_sel, sel_from, sel_to)


func _apply_distance_line(edit: LineEdit, text: String, caret: int, had_sel: bool,
		sel_from: int, sel_to: int) -> void:
	if edit == null:
		return
	if edit.text != text:
		edit.text = text
	edit.caret_column = caret
	if had_sel:
		edit.select(sel_from, sel_to)


func _reassert_distance_line(gen: int, text: String, caret: int, had_sel: bool,
		sel_from: int, sel_to: int) -> void:
	if gen != _distance_line_gen or _extrude_spin == null:
		return
	var edit := _extrude_spin.get_line_edit()
	# A digit typed in the same turn already replaced the committed string.
	# Putting the old text back would drop that digit ("10" → "0" / "1").
	if edit != null:
		var typed := str(edit.get_meta("_sx_typed", ""))
		if typed != "" and typed != text and not SxUi.replace_armed(edit):
			return
	# Ctrl+A / focus-replace can land before this deferred restore. Putting
	# the old caret back would drop that selection and the next burst appends.
	var keep_replace := edit != null and (_distance_replace_next \
			or SxUi.replace_armed(edit) or edit.has_selection())
	_distance_syncing = true
	_apply_distance_line(edit, text, caret, had_sel, sel_from, sel_to)
	if keep_replace and edit != null:
		edit.select_all()
	_distance_syncing = false


func _select_distance_all() -> void:
	if _extrude_spin == null:
		return
	var edit := _extrude_spin.get_line_edit()
	if edit != null:
		edit.select_all()


func _select_distance_all_if_gen(gen: int) -> void:
	if gen != _distance_select_gen:
		return
	# A digit already replaced the committed text. Selecting now would
	# highlight that digit so the next key turns "10" into "0".
	var edit := _extrude_spin.get_line_edit() if _extrude_spin != null else null
	if edit == null:
		return
	if SxUi.select_type_stale(edit):
		return
	if not edit.has_focus():
		return
	if not _distance_replace_next and not SxUi.replace_armed(edit):
		return
	if not edit.is_editing():
		edit.edit()
	_select_distance_all()


func _select_distance_all_next_frame(gen: int = -1) -> void:
	if gen < 0:
		gen = _distance_select_gen
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	_select_distance_all_if_gen(gen)


func _select_dim_all() -> void:
	if _dim_spin == null:
		return
	var edit := _dim_spin.get_line_edit()
	if edit != null:
		edit.select_all()


func _select_dim_all_if_gen(gen: int) -> void:
	if gen != _dim_select_gen:
		return
	var edit := _dim_spin.get_line_edit() if _dim_spin != null else null
	if edit == null:
		return
	if SxUi.select_type_stale(edit):
		return
	if not edit.has_focus():
		return
	if not _dim_replace_next and not SxUi.replace_armed(edit):
		return
	if not edit.is_editing():
		edit.edit()
	_select_dim_all()


func _select_dim_all_next_frame(gen: int = -1) -> void:
	if gen < 0:
		gen = _dim_select_gen
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	_select_dim_all_if_gen(gen)


## Digit, keypad digit, '.', and optionally '-' — the keys that start a length.
func _is_numeric_replace_key(k: InputEventKey, allow_minus: bool) -> bool:
	var code := k.keycode
	if code >= KEY_0 and code <= KEY_9:
		return true
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return true
	if code == KEY_PERIOD or code == KEY_KP_PERIOD:
		return true
	if allow_minus and (code == KEY_MINUS or code == KEY_KP_SUBTRACT):
		return true
	var ch := k.unicode
	if ch >= 48 and ch <= 57:
		return true
	if ch == 46:
		return true
	if allow_minus and ch == 45:
		return true
	return false


func _numeric_key_char(k: InputEventKey) -> String:
	return SxUi.numeric_key_char(k)


func _restore_rejected_distance(keep: float, keep_text: String = "") -> void:
	# SpinBox applies a truncated parse on a deferred text_submitted / focus
	# exit. Wait one frame so this write wins, then restore the junk string
	# so Extrude still sees an unparseable line.
	var gen := _distance_line_gen
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	if gen != _distance_line_gen:
		return
	_distance_rejecting = false
	var raw := keep_text if keep_text != "" else _distance_raw_text()
	_write_extrude_spin(keep, raw)


func _refresh_extrude_readout(v: float) -> void:
	if _extrude_readout == null:
		return
	_extrude_readout.text = "Extrude %s mm" % _plain_num(v)


func _on_distance_text_changed(new_text: String) -> void:
	if _distance_syncing:
		return
	# A pending deferred / next-frame select_all from the focusing click must
	# not win over the first typed digit (7 then . would become ".5").
	_distance_select_gen += 1
	# Step 0.5 rewrites "2" as "2.0". A native "." / "5" then splices in and
	# the field reads "2.05" (a second burst appends, "2.052.5"). The typed
	# snapshot is the value; put it back and do not commit the padded text.
	var owned_edit := _extrude_spin.get_line_edit() if _extrude_spin != null else null
	var owned := str(owned_edit.get_meta("_sx_typed", "")) if owned_edit != null else ""
	if owned_edit != null and owned != "" and new_text != owned \
			and SxUi.mid_entry(owned_edit) and not _distance_replace_next \
			and not SxUi.replace_armed(owned_edit):
		_distance_syncing = true
		owned_edit.text = owned
		owned_edit.caret_column = owned.length()
		owned_edit.deselect()
		_distance_syncing = false
		return
	if _distance_rejecting:
		return
	var parsed: Variant = _parse_spin_text(_extrude_spin, new_text)
	var from_user := _distance_user_key
	_distance_user_key = false
	if parsed == null:
		# Leave .value at the last good parse. "7." is a prefix of 7.5; do not
		# snap the spin back to the focus-in 20 while the user is still typing.
		_distance_line_invalid = true
		_distance_invalid_raw = new_text
		return
	if _distance_line_invalid and not from_user:
		# SpinBox apply turned "20.07.5" into a truncated 20. Keep the reject
		# so Extrude cannot succeed at the snapped step value.
		return
	_distance_line_invalid = false
	_distance_invalid_raw = ""
	_write_extrude_spin(float(parsed), new_text)


func _on_distance_text_submitted(raw: String) -> void:
	if _distance_syncing:
		return
	var parsed: Variant = _parse_spin_text(_extrude_spin, raw)
	if parsed == null:
		_distance_line_invalid = true
		_distance_invalid_raw = raw
		_distance_rejecting = true
		distance_rejected.emit(raw)
		_restore_rejected_distance(_distance_origin, raw)
		return
	_distance_line_invalid = false
	_distance_invalid_raw = ""
	_write_extrude_spin(float(parsed))
	_distance_origin = float(parsed)
	# Enter commits and gives the next key to the viewport. Keeping focus
	# here swallowed tool shortcuts and sketch redo (#200, sx-038 L10).
	_distance_replace_next = false
	var committed := _extrude_spin.get_line_edit() if _extrude_spin != null else null
	SxUi.release_line_now(committed)
	_hand_keys_to_viewport()


func _on_distance_focus_entered() -> void:
	if _extrude_spin != null:
		_distance_origin = _extrude_spin.value
	_distance_replace_next = true
	var edit := _extrude_spin.get_line_edit() if _extrude_spin != null else null
	if edit != null:
		SxUi.arm_replace_on_focus(edit)
	# Do not select_all / grab_focus here. That re-enters the root Window
	# focus_entered / tree_exited connections. Mouse clicks already defer
	# select from gui_input; keyboard focus uses one deferred select.
	if _extrude_spin == null or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_distance_select_gen += 1
	_select_distance_all_if_gen.call_deferred(_distance_select_gen)


func _on_distance_focus_exited() -> void:
	_distance_replace_next = false
	if _extrude_spin != null:
		var edit := _extrude_spin.get_line_edit()
		SxUi.disarm_replace(edit)
		if edit != null:
			edit.set_meta("_sx_typed", "")
	var ix := _host_interaction()
	if ix != null and ix.has_method("note_distance_focus_released"):
		ix.note_distance_focus_released()
	if _distance_syncing or _distance_rejecting:
		return
	var raw := _distance_raw_text()
	if _distance_line_invalid:
		var keep := _distance_invalid_raw if _distance_invalid_raw != "" else raw
		_restore_rejected_distance(_distance_origin, keep)
		return
	var parsed: Variant = _parse_spin_text(_extrude_spin, raw)
	if parsed == null:
		_distance_line_invalid = true
		_distance_invalid_raw = raw
		_restore_rejected_distance(_distance_origin, raw)
		return
	_write_extrude_spin(float(parsed))
	_distance_origin = float(parsed)


func _on_dim_focus_entered() -> void:
	_dim_editing = true
	# A seed write bumped the generation before grab_focus. Do not arm replace
	# or the deferred select_all eats that first digit ("20" reads back "0").
	if _dim_seed_seen != _dim_seed_gen:
		_dim_seed_seen = _dim_seed_gen
		_dim_replace_next = false
		return
	_dim_replace_next = true
	# Deferred select only. Synchronous select_all here re-enters Window
	# focus_entered / tree_exited. Mouse-down used to skip the select entirely,
	# so the caret stayed at column 0 and the next digit was inserted in front.
	if _dim_spin == null:
		return
	SxUi.arm_replace_on_focus(_dim_spin.get_line_edit())


func _on_dim_focus_exited() -> void:
	_dim_editing = false
	_dim_replace_next = false
	if _dim_spin != null:
		SxUi.disarm_replace(_dim_spin.get_line_edit())
	var ix := _host_interaction()
	if ix != null and ix.has_method("note_dim_focus_released"):
		ix.note_dim_focus_released()


func _on_dim_text_submitted(raw: String) -> void:
	var parsed: Variant = _parse_dim_text(raw)
	if parsed == null:
		# Do not call apply() and do not emit dim_submitted. SpinBox still
		# parses the same signal on a deferred connection and would store a
		# truncated number; put the previous value back after that.
		var keep := _dim_last_good if _dim_last_good >= 0.0 else (
				_dim_spin.value if _dim_spin != null else 0.0)
		_dim_rejecting = true
		dim_rejected.emit(raw)
		_restore_rejected_dim.call_deferred(keep)
		return
	if _dim_spin == null:
		return
	_dim_last_good = float(parsed)
	_dim_syncing = true
	_dim_spin.value = float(parsed)
	_dim_syncing = false
	# value_changed is skipped while syncing, and the slot radius is the blank
	# before the first centre (no single-DOF preview yet).
	_apply_slot_radius(float(parsed))
	dim_submitted.emit(_dim_spin.value)
	release_dim_focus()
	_hand_keys_to_viewport()


func _restore_rejected_dim(keep: float) -> void:
	_dim_rejecting = false
	if _dim_spin == null:
		return
	_dim_syncing = true
	_dim_spin.value = keep
	_dim_syncing = false


## Number in the blank, after Godot's "prefix + space" / "space + suffix" chrome.
## Null when the raw string is not a single float (for example "23.22.5").
func _parse_dim_text(raw: String) -> Variant:
	return _parse_spin_text(_dim_spin, raw)


func _parse_spin_text(spin: SpinBox, raw: String) -> Variant:
	var text := raw.strip_edges()
	if text.is_empty() or spin == null:
		return null
	var prefix := str(spin.prefix)
	var suffix := str(spin.suffix)
	if prefix != "":
		var spaced := prefix + " "
		if text.begins_with(spaced):
			text = text.substr(spaced.length())
		elif text.begins_with(prefix):
			text = text.substr(prefix.length())
	if suffix != "":
		var spaced := " " + suffix
		if text.ends_with(spaced):
			text = text.substr(0, text.length() - spaced.length())
		elif text.ends_with(suffix):
			text = text.substr(0, text.length() - suffix.length())
	text = text.strip_edges().replace(",", ".")
	if not text.is_valid_float():
		return null
	var v := float(text)
	if is_nan(v) or is_inf(v):
		return null
	return v


## Across-flats reads the typed length as AF. Circle keeps a radius number; the
## r cue is a label, not a prefix glued to the digits. Slot is radius until the
## first centre, then the blank is the centre-to-centre length.
func _sync_dim_affordance() -> void:
	if _dim_spin == null:
		return
	var suffix := "mm"
	var prefix := ""
	var tip := "Distance / radius — tracks the rubber-band while drawing; type to lock, Enter commits"
	var show_label := false
	var show_cue := false
	var label_text := "Radius"
	var cue_text := "r"
	if sketch_mode != null and sketch_mode.tool == SketchMode.Tool.POLYGON \
			and sketch_mode.tool_variant == "across_flats":
		suffix = " AF"
		tip = "Across flats — typed length is the AF, not the circumradius"
	elif sketch_mode != null and sketch_mode.tool == SketchMode.Tool.CIRCLE:
		show_label = true
		show_cue = true
		tip = "Circle radius (mm). The r label is the radius; diameter is 2× this number"
	elif sketch_mode != null and sketch_mode.tool == SketchMode.Tool.SLOT:
		show_label = true
		if sketch_mode.has_single_dof_preview():
			label_text = "c-c"
			show_cue = false
			tip = "Slot centre-to-centre length (mm). Type the length, or click the second centre"
		else:
			show_cue = true
			label_text = "Radius"
			tip = "Slot radius (mm) until the first centre is down; then the centre distance"
			# After a typed c-c commit the blank still holds the length. Put
			# the radius back so the Radius label does not sit over 150 mm.
			if not _dim_editing and _dim_spin != null \
					and not is_equal_approx(_dim_spin.value, sketch_mode.slot_radius):
				_dim_blank_empty = false
				_dim_syncing = true
				_dim_spin.value = sketch_mode.slot_radius
				_dim_syncing = false
	var was_syncing := _dim_syncing
	_dim_syncing = true
	if _dim_spin.suffix != suffix:
		_dim_spin.suffix = suffix
	if str(_dim_spin.prefix) != prefix:
		_dim_spin.prefix = prefix
	_dim_spin.tooltip_text = tip
	_dim_syncing = was_syncing
	if _dim_cue != null:
		_dim_cue.visible = show_cue
		_dim_cue.text = cue_text
	if _radius_label != null:
		_radius_label.visible = show_label
		_radius_label.text = label_text
		_radius_label.tooltip_text = tip
	_apply_field_numeric()
	_reassert_empty_dim()


## Switching tools, or Slot radius → c-c, shows that field's own number.
## A missing number is an empty blank, never the previous field's digits.
func _apply_field_numeric() -> void:
	if sketch_mode == null or _dim_spin == null:
		return
	if not sketch_mode.has_method("numeric_field_key"):
		return
	var key := str(sketch_mode.numeric_field_key())
	if key == _shown_numeric_key:
		return
	_shown_numeric_key = key
	var was := _dim_editing
	_dim_editing = false
	var own := float(sketch_mode.own_numeric()) if sketch_mode.has_method("own_numeric") else -1.0
	if own >= 0.0:
		set_dim_value(own)
	else:
		clear_dim_blank()
	_dim_editing = was


func _reassert_empty_dim() -> void:
	if not _dim_blank_empty or _dim_spin == null:
		return
	var edit := _dim_spin.get_line_edit()
	if edit == null:
		return
	if SxUi.typed_since_intent(edit):
		return
	var want := _empty_dim_text()
	# Focus makes SpinBox paint its minimum (0.01). That is not a typed AF.
	if edit.text != want:
		_dim_syncing = true
		edit.text = want
		_dim_syncing = false
	if _dim_editing and edit.has_focus() \
			and (_dim_replace_next or SxUi.replace_armed(edit)):
		edit.select_all()


func _reassert_empty_dim_if_gen(gen: int) -> void:
	var edit := _dim_spin.get_line_edit() if _dim_spin != null else null
	if edit != null and SxUi.type_gen(edit) != gen:
		return
	_reassert_empty_dim()


func _schedule_reassert_empty_dim() -> void:
	var edit := _dim_spin.get_line_edit() if _dim_spin != null else null
	_reassert_empty_dim_if_gen.call_deferred(SxUi.type_gen(edit))


func _reassert_empty_dim_next_frame() -> void:
	var edit := _dim_spin.get_line_edit() if _dim_spin != null else null
	var gen := SxUi.type_gen(edit)
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	_reassert_empty_dim_if_gen(gen)


## True when `raw` is only the spin minimum (the focused-blank echo).
func _is_spin_minimum_text(raw: String) -> bool:
	if _dim_spin == null:
		return false
	var parsed: Variant = _parse_spin_text(_dim_spin, raw)
	if parsed == null:
		return false
	return is_equal_approx(float(parsed), _dim_spin.min_value)


func dim_is_editing() -> bool:
	return _dim_editing


## Focus the blank for typed length (optional seed digit / decimal).
func focus_dim_for_typing(seed := "") -> void:
	_dim_focus_from_tool = false
	if _dim_spin == null:
		return
	# Slot radius / c-c must not leave digits in Extrude if Distance was
	# still the focus owner from a previous burst.
	_release_distance_focus()
	var edit := _dim_spin.get_line_edit()
	if seed != "":
		_dim_seed_gen += 1
	edit.grab_focus()
	_dim_editing = true
	if seed != "":
		_dim_blank_empty = false
		# Unfocused burst writes the whole seed. Do not replace the next key.
		_dim_replace_next = false
		_dim_select_gen += 1
		SxUi.write_typed_text(edit, seed)
		if seed.is_valid_float():
			_dim_syncing = true
			_dim_spin.set_value_no_signal(float(seed))
			_dim_syncing = false
			# set_value rewrites the line and parks the caret at column 0.
			SxUi.write_typed_text(edit, seed)
			_apply_slot_radius(float(seed))
			if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
				sketch_mode.set_length_override(float(seed))
	else:
		_dim_replace_next = true
		SxUi.arm_replace_on_focus(edit)


## Focus the dim blank with its current (or `shown`) value selected so the
## next digit replaces it. Canvas centre clicks use this so Radius / AF do
## not keep a stale Slot value and do not leave Extrude focused.
func arm_dim_replace(shown: float = -1.0) -> void:
	if _dim_spin == null:
		return
	_release_distance_focus()
	if shown > 0.0:
		var was := _dim_editing
		_dim_editing = false
		set_dim_value(shown)
		_dim_editing = was
	else:
		# No rubber-band size yet. Leave the placeholder (" AF" / "mm"), never
		# the spin minimum 0.01 that focus would otherwise display.
		clear_dim_blank()
	_dim_editing = true
	_dim_replace_next = true
	var edit := _dim_spin.get_line_edit()
	if edit == null:
		return
	edit.grab_focus()
	if _dim_blank_empty:
		_reassert_empty_dim()
		_schedule_reassert_empty_dim()
		_reassert_empty_dim_next_frame()
	SxUi.arm_replace_on_focus(edit)


## First key after arm replaces the whole blank. Later keys append.
## Returns false when the line is not focused or replace is not armed.
func replace_dim_with_char(ch: String) -> bool:
	if _dim_spin == null or ch == "":
		return false
	var edit := _dim_spin.get_line_edit()
	if edit == null or not edit.has_focus():
		return false
	if not _dim_replace_next and not SxUi.replace_armed(edit):
		return false
	# Set before the text write so a preview echo cannot put the old value back.
	_dim_editing = true
	_dim_blank_empty = false
	_dim_replace_next = false
	_dim_select_gen += 1
	SxUi.write_typed_text(edit, ch)
	var parsed: Variant = _parse_spin_text(_dim_spin, ch)
	if parsed != null:
		_apply_slot_radius(float(parsed))
		if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
			sketch_mode.set_length_override(float(parsed))
	return true


func release_dim_focus() -> void:
	_dim_focus_from_tool = false
	if _dim_spin == null:
		return
	var edit := _dim_spin.get_line_edit()
	if edit.has_focus():
		edit.release_focus()
	_dim_editing = false
	_dim_replace_next = false


## Circle's own radius claim, still focused, and the user has not clicked or
## typed into it. Tool hotkeys may take the keyboard back.
func tool_claimed_dim_focus() -> bool:
	if not _dim_focus_from_tool or _dim_spin == null:
		return false
	var edit := _dim_spin.get_line_edit()
	return edit != null and edit.has_focus()


func release_distance_focus() -> void:
	_release_distance_focus()


func _release_distance_focus() -> void:
	if _extrude_spin == null:
		return
	var edit := _extrude_spin.get_line_edit()
	if edit != null and edit.has_focus():
		edit.release_focus()
	_distance_replace_next = false


func _on_dim_value_changed(v: float) -> void:
	if _dim_syncing or _dim_rejecting or not _dim_editing:
		return
	# Focusing an empty blank echoes min_value. That is not a typed length.
	if _dim_blank_empty and _dim_spin != null and is_equal_approx(v, _dim_spin.min_value):
		_reassert_empty_dim()
		return
	_apply_slot_radius(v)
	# Live lock rubber-band while digits change (Enter still commits via signal).
	if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
		sketch_mode.set_length_override(v)


func _on_dim_text_changed(new_text: String) -> void:
	if _dim_syncing:
		return
	if _dim_rejecting:
		return
	# SpinBox rewrites an empty focused blank to "0.01" (its minimum). Put the
	# placeholder back and do not lock that as the polygon / slot length.
	# That echo is not typing, so Circle's tool-claimed focus stays.
	if _dim_blank_empty and _is_spin_minimum_text(new_text):
		_reassert_empty_dim()
		return
	_dim_focus_from_tool = false
	# Cancel a pending deferred / next-frame select_all once typing starts.
	_dim_select_gen += 1
	var parsed: Variant = _parse_spin_text(_dim_spin, new_text)
	if parsed == null:
		return
	_dim_blank_empty = false
	_apply_slot_radius(float(parsed))
	if sketch_mode != null and sketch_mode.active and sketch_mode.has_single_dof_preview():
		sketch_mode.set_length_override(float(parsed))


## Ctrl+A and the next digit both replace. LineEdit eats Ctrl+A while editing,
## so the viewport path calls this before the line sees the key.
func note_distance_select_all() -> void:
	_distance_replace_next = true
	var edit := _extrude_spin.get_line_edit() if _extrude_spin != null else null
	if edit == null:
		return
	if edit.has_focus() and not edit.is_editing():
		edit.edit()
	edit.select_all()
	edit.set_meta("_sx_replace_armed", true)


## One numeric key in Extrude Distance. Click, Tab, and Ctrl+A replace the
## whole value; later keys append to the typed snapshot, not to a step-padded
## "2.0" (that splice is how 2.5 becomes 2.05).
func apply_distance_typed_char(ch: String) -> void:
	if _extrude_spin == null or ch == "":
		return
	var line := _extrude_spin.get_line_edit()
	if line == null:
		return
	_distance_user_key = true
	var replace := _distance_replace_next or SxUi.replace_armed(line) or line.has_selection()
	var next := ch
	if not replace:
		var owned := str(line.get_meta("_sx_typed", ""))
		if owned != "":
			next = owned + ch
		else:
			next = SxUi.compose_typed_char(line, ch)
	_distance_replace_next = false
	_distance_select_gen += 1
	SxUi.write_typed_text(line, next)
	var parsed: Variant = _parse_spin_text(_extrude_spin, next)
	if parsed != null:
		_distance_line_invalid = false
		_distance_invalid_raw = ""
		_write_extrude_spin(float(parsed), next)
	else:
		_distance_line_invalid = true
		_distance_invalid_raw = next


func _on_distance_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Every left click, including the one that finds the field already
		# focused. Deferred so it runs after LineEdit places the caret, and
		# again next frame so the caret cannot win. Both are gen-gated so a
		# first typed character cancels them.
		if mb.button_index == MOUSE_BUTTON_LEFT and _extrude_spin != null:
			_distance_replace_next = true
			_distance_select_gen += 1
			var gen := _distance_select_gen
			var line := _extrude_spin.get_line_edit()
			if line != null:
				SxUi.claim_keyboard_focus(line)
				SxUi.capture_select_type_gen(line)
			_select_distance_all_if_gen.call_deferred(gen)
			_select_distance_all_next_frame(gen)
	if SxUi.swallow_rejected_echo(event):
		accept_event()
		return
	if SxUi.press_accepted(event):
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			# Enter commits even when the line is not yet editing. A fast
			# burst can land before the deferred edit(), and LineEdit then
			# drops the key.
			var enter_line := _extrude_spin.get_line_edit() if _extrude_spin != null else null
			var entered := enter_line.text if enter_line != null else _distance_raw_text()
			_on_distance_text_submitted(entered)
			accept_event()
			return
		if k.keycode == KEY_ESCAPE:
			_distance_line_invalid = false
			_distance_invalid_raw = ""
			_write_extrude_spin(_distance_origin, _plain_num(_distance_origin))
			if _extrude_spin != null:
				var line := _extrude_spin.get_line_edit()
				if line != null and line.has_focus():
					line.release_focus()
			# After a refusal the Distance field must not spend this Esc on
			# blur alone. Same ladder the canvas uses.
			var ix := _host_interaction()
			if ix != null and ix.has_method("consume_refusal_exit_ladder"):
				ix.consume_refusal_exit_ladder()
			accept_event()
			return
		if (k.ctrl_pressed or k.meta_pressed) and not k.alt_pressed \
				and k.keycode == KEY_A:
			note_distance_select_all()
			accept_event()
			return
		if not _is_numeric_replace_key(k, true):
			return
		var ch := SxUi.numeric_key_char(k)
		if ch == "":
			return
		# Fallback when the key was not already owned in Viewport._input.
		# While the line is editing, LineEdit accepts the key first and this
		# signal does not run — the viewport path is the one that sees it.
		apply_distance_typed_char(ch)
		accept_event()
		return


func _on_dim_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Every left click, including the one that finds the field already
		# focused. Deferred so it runs after LineEdit places the caret.
		if mb.button_index == MOUSE_BUTTON_LEFT and _dim_spin != null:
			_dim_focus_from_tool = false
			_dim_replace_next = true
			_dim_select_gen += 1
			var gen := _dim_select_gen
			var dim_line := _dim_spin.get_line_edit()
			if dim_line != null:
				SxUi.claim_keyboard_focus(dim_line)
				SxUi.capture_select_type_gen(dim_line)
			_select_dim_all_if_gen.call_deferred(gen)
			_select_dim_all_next_frame(gen)
	if SxUi.swallow_rejected_echo(event):
		accept_event()
		return
	if SxUi.press_accepted(event):
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			var dim_line := _dim_spin.get_line_edit() if _dim_spin != null else null
			var entered := dim_line.text if dim_line != null else ""
			_on_dim_text_submitted(entered)
			accept_event()
			return
		if k.keycode == KEY_ESCAPE:
			if sketch_mode != null:
				sketch_mode.clear_length_override()
			release_dim_focus()
			var ix := _host_interaction()
			if ix != null and ix.has_method("drop_pending_draw_esc"):
				ix.drop_pending_draw_esc()
			accept_event()
			return
		if (k.ctrl_pressed or k.meta_pressed) and not k.alt_pressed \
				and k.keycode == KEY_A:
			if _dim_spin != null:
				var edit := _dim_spin.get_line_edit()
				if edit != null:
					edit.select_all()
			accept_event()
			return
		if _is_numeric_replace_key(k, false) and _dim_spin != null:
			var dim_line := _dim_spin.get_line_edit()
			var ch := _numeric_key_char(k)
			if ch != "" and dim_line != null:
				# Own every key. Native LineEdit insert plus a deferred
				# reassert of the first character drops the rest of a fast
				# "22.5" when the keys share one frame.
				if not dim_line.has_focus():
					dim_line.grab_focus()
				if _dim_replace_next or SxUi.replace_armed(dim_line):
					replace_dim_with_char(ch)
				else:
					_dim_editing = true
					_dim_blank_empty = false
					_dim_select_gen += 1
					var next := SxUi.compose_typed_char(dim_line, ch)
					SxUi.write_typed_text(dim_line, next)
					var parsed: Variant = _parse_spin_text(_dim_spin, next)
					if parsed != null:
						_apply_slot_radius(float(parsed))
						if sketch_mode != null and sketch_mode.active \
								and sketch_mode.has_single_dof_preview():
							sketch_mode.set_length_override(float(parsed))
				accept_event()
				return


func _hand_keys_to_viewport() -> void:
	var ix := _host_interaction()
	if ix != null and ix.has_method("return_viewport_keys"):
		ix.return_viewport_keys()


func _host_interaction() -> ViewportInteraction:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.find_child("Interaction", true, false) as ViewportInteraction


func set_extrude_distance(v: float) -> void:
	if _extrude_spin:
		_distance_line_invalid = false
		_distance_invalid_raw = ""
		_write_extrude_spin(v, "%s mm" % _plain_num(v))
		_distance_origin = v


func set_finish_op(op: String) -> void:
	if _finish_op == null:
		return
	var map := {"new": 0, "cut": 1, "fuse": 2}
	if map.has(op):
		_finish_op.select(map[op])


func set_finish_end(end: String) -> void:
	if _finish_end == null:
		return
	var map := {"blind": 0, "through_all": 1, "midplane": 2, "to_face": 3}
	if map.has(end):
		_finish_end.select(map[end])


func get_finish_end() -> String:
	if _finish_end == null:
		return "blind"
	var opts := ["blind", "through_all", "midplane", "to_face"]
	var i := clampi(_finish_end.selected, 0, opts.size() - 1)
	return opts[i]


func finish_owner() -> String:
	return _finish_owner


## File > New starts the finish bar from its defaults. Without this a Cut / Up
## To Surface from the last part is still selected for the next part's blank.
func reset_finish_defaults() -> void:
	_finish_owner = ""
	if _finish_op != null:
		_finish_op.select(0)
	if _finish_end != null:
		_finish_end.select(0)
	if _thin_feature != null:
		_thin_feature.set_pressed_no_signal(false)
	if _thin_spin != null:
		_thin_spin.value = 0
	if _thin_type != null:
		_thin_type.select(0)
	if _flip_side != null:
		_flip_side.set_pressed_no_signal(false)
	_apply_thin_visibility()
	clear_up_to_face()
	# Distance and the dim blank are per document. A Cut of 5 mm must not be
	# the next part's Extrude field, and the dim key must re-read defaults.
	_shown_numeric_key = ""
	_dim_blank_empty = false
	_distance_line_invalid = false
	_distance_invalid_raw = ""
	_distance_line_gen += 1
	if _extrude_spin != null:
		_distance_syncing = true
		_extrude_spin.value = 20
		var dist_edit := _extrude_spin.get_line_edit()
		if dist_edit != null:
			var parsed: Variant = _parse_spin_text(_extrude_spin, dist_edit.text)
			if typeof(parsed) != TYPE_FLOAT or not is_equal_approx(float(parsed), 20.0):
				# Setting .value does not replace a LineEdit that still shows the
				# previous document's digits. Write the same "20.0" form SpinBox
				# uses for step 0.5, and keep prefix/suffix.
				var text := "20.0"
				var prefix := str(_extrude_spin.prefix)
				var suffix := str(_extrude_spin.suffix)
				if prefix != "":
					text = prefix + " " + text
				if suffix != "":
					text += " " + suffix
				dist_edit.text = text
		_distance_syncing = false
		_distance_origin = 20.0
		_refresh_extrude_readout(20)
	if _dim_spin != null:
		_dim_syncing = true
		_dim_spin.value = 10
		_dim_syncing = false


## New face/plane sketch (not File > New, not begin_edit): Blind, New, default D.
func reset_finish_for_new_sketch() -> void:
	reset_finish_defaults()
	if _extrude_spin != null:
		_distance_syncing = true
		_extrude_spin.value = 20
		_distance_syncing = false
		_refresh_extrude_readout(20)
	if _dim_spin != null:
		_dim_syncing = true
		_dim_spin.value = 10
		_dim_syncing = false


## Finish bar state Save must put back after exit_sketch / begin_edit.
## Always returns the keys, including when no contour is selected.
func finish_snapshot() -> Dictionary:
	var dist_text := ""
	var dist_v := 0.0
	if _extrude_spin != null:
		dist_v = _extrude_spin.value
		dist_text = _distance_raw_text()
	return {
		"op": _finish_op.selected if _finish_op != null else 0,
		"end": get_finish_end(),
		"distance": dist_v,
		"distance_text": dist_text,
		"thin_on": _thin_feature.button_pressed if _thin_feature != null else false,
		"thin": _thin_spin.value if _thin_spin != null else 0.0,
		"thin_type": _thin_type.selected if _thin_type != null else 0,
		"flip": _flip_side.button_pressed if _flip_side != null else false,
		"up_to_face_id": up_to_face_id,
		"contours": _selected_contours.duplicate(),
	}


## Put a finish_snapshot() back after show_for_session has reset the bar.
func finish_restore(d: Dictionary) -> void:
	if d.is_empty():
		return
	var ops := ["new", "cut", "fuse"]
	var oi := clampi(int(d.get("op", 0)), 0, ops.size() - 1)
	set_finish_op(ops[oi])
	set_finish_end(str(d.get("end", "blind")))
	if _thin_feature != null:
		_thin_feature.set_pressed_no_signal(bool(d.get("thin_on", false)))
	if _thin_spin != null:
		_thin_spin.set_value_no_signal(float(d.get("thin", 0.0)))
	if _thin_type != null:
		_thin_type.select(clampi(int(d.get("thin_type", 0)), 0, 1))
	if _flip_side != null:
		_flip_side.set_pressed_no_signal(bool(d.get("flip", false)))
	_apply_thin_visibility()
	var face := str(d.get("up_to_face_id", ""))
	if face != "":
		set_up_to_face(face)
	_restore_contour_selection(d.get("contours", []))
	var dist_text := str(d.get("distance_text", ""))
	_write_extrude_spin(float(d.get("distance", 20.0)), dist_text)
	_sync_face_box()


func _restore_contour_selection(ids: Variant) -> void:
	var want: Array = ids if ids is Array else []
	_selected_contours = want.duplicate()
	if _contour_bar == null:
		return
	var i := 0
	for c in _contour_bar.get_children():
		if c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(_selected_contours.has(i))
			i += 1
	if sketch_mode != null:
		sketch_mode.set_contour_highlight(_selected_contours, -1)


func _claim_dim_keyboard() -> void:
	if _dim_spin == null:
		return
	if sketch_mode == null or sketch_mode.tool != SketchMode.Tool.CIRCLE:
		return
	if sketch_mode.has_single_dof_preview():
		return
	_release_distance_focus()
	var edit := _dim_spin.get_line_edit()
	if edit != null:
		_dim_focus_from_tool = true
		SxUi.claim_keyboard_focus(edit)


func sync_for_tool() -> void:
	_sync_dim_affordance()
	if sketch_mode == null:
		return
	# Select does not take keyboard focus. Release a blank left over from
	# Circle / Polygon / Slot so F / Shift+F / Esc are not stuck in that
	# LineEdit and the hover measure can clear.
	if sketch_mode.tool != SketchMode.Tool.CIRCLE:
		release_dim_focus()
	if _dim_editing:
		return
	# c-c (and any in-progress rubber-band) is not the radius field.
	if sketch_mode.has_single_dof_preview():
		return
	if not sketch_mode.has_method("own_numeric"):
		return
	var own := float(sketch_mode.own_numeric())
	if own >= 0.0:
		set_dim_value(own)
	else:
		clear_dim_blank()
	# Circle's radius blank owns the keyboard as soon as the tool is armed
	# (a digit is Radius, not Extrude). The grab must not eat the next canvas
	# press. Tool hotkeys still switch tools until the user types: the claim
	# is not mid-entry, and a tool key releases it.
	if sketch_mode.tool != SketchMode.Tool.CIRCLE:
		return
	_release_distance_focus()
	var edit := _dim_spin.get_line_edit() if _dim_spin != null else null
	if edit != null:
		_dim_focus_from_tool = true
		SxUi.claim_keyboard_focus(edit)
		_claim_dim_keyboard.call_deferred()


func set_flip_side(on: bool) -> void:
	if _flip_side:
		_flip_side.button_pressed = on


func flip_side_button() -> CheckButton:
	return _flip_side


## Refresh Selected Contours chips from the live sketch (SW multi-region pick).
func refresh_contours(sketch: SxSketch) -> void:
	_clear_bar(_contour_bar)
	_selected_contours.clear()
	if sketch == null or not sketch.has_method("contour_count"):
		_contour_bar.visible = false
		if sketch_mode != null:
			sketch_mode.set_contour_highlight([], -1)
		return
	var n: int = int(sketch.contour_count())
	if n <= 1:
		_contour_bar.visible = false
		if sketch_mode != null:
			sketch_mode.set_contour_highlight([], -1)
		return
	var lbl := Label.new()
	lbl.text = "Contours"
	lbl.add_theme_font_size_override("font_size", UiScale.body())
	_contour_bar.add_child(lbl)
	for i in n:
		_selected_contours.append(i)
		var b := CheckButton.new()
		b.text = str(i + 1)
		b.button_pressed = true
		b.custom_minimum_size = Vector2(40, _chip_h())
		b.tooltip_text = "Selected Contours — include region %d" % (i + 1)
		var idx := i
		b.toggled.connect(func(on: bool) -> void:
			if on:
				if not _selected_contours.has(idx):
					_selected_contours.append(idx)
					_selected_contours.sort()
			else:
				_selected_contours.erase(idx)
			if sketch_mode != null:
				sketch_mode.set_contour_highlight(_selected_contours, idx)
				sketch_mode.status.emit(sketch_mode.contour_label(idx) + (
						" — included" if on else " — skipped"))
		)
		b.mouse_entered.connect(func() -> void:
			if sketch_mode != null:
				sketch_mode.set_contour_highlight(_selected_contours, idx))
		b.mouse_exited.connect(func() -> void:
			if sketch_mode != null:
				sketch_mode.set_contour_highlight(_selected_contours, -1))
		b.focus_entered.connect(func() -> void:
			if sketch_mode != null:
				sketch_mode.set_contour_highlight(_selected_contours, idx))
		b.focus_exited.connect(func() -> void:
			if sketch_mode != null:
				sketch_mode.set_contour_highlight(_selected_contours, -1))
		_contour_bar.add_child(b)
	_contour_bar.visible = true
	_stack_sketch_rows()
	if sketch_mode != null:
		sketch_mode.set_contour_highlight(_selected_contours, -1)


func extrude_button() -> Button:
	return find_child("ExtrudeButton", true, false) as Button


func opposite_face_button() -> Button:
	return find_child("OppositeFaceButton", true, false) as Button


func revolve_button() -> Button:
	return find_child("RevolveButton", true, false) as Button


func done_button() -> Button:
	return find_child("DoneButton", true, false) as Button


func show_for_session(on: bool, fid: String = "") -> void:
	_finish_bar.visible = on
	if on:
		if fid != "" and fid == _finish_owner:
			# Same owner (Save As of an already-saved sketch): keep Op/End/D.
			pass
		elif fid != "" and _finish_owner == "" \
				and _finish_hidden_frame == Engine.get_process_frames():
			# Save As of a brand-new sketch: hide+show is the same frame; adopt
			# the new feature id without wiping Cut / Up To Surface / distance.
			_finish_owner = fid
		else:
			# New sketch, or begin_edit of a different existing sketch.
			reset_finish_for_new_sketch()
			_finish_owner = fid
			# New session only. Same-owner Save As keeps Distance focus if the
			# walker is still in that field. main._on_sketch_session_started is
			# not the place for this: that function is shared with every
			# re-entry, including Save.
			release_distance_focus()
		clear_up_to_face()
		# Sit to the right of the SketchTools rail (Exit Sketch), under the top row.
		_place_finish_session()
		_sync_dim_affordance()
		if _extrude_spin != null:
			_refresh_extrude_readout(_extrude_spin.value)
		if sketch_mode != null and sketch_mode.sketch != null:
			refresh_contours(sketch_mode.sketch)
	else:
		_finish_hidden_frame = Engine.get_process_frames()
		# Hide must not leave the one-shot armed. Part-mode Esc would otherwise
		# print "Up To Surface face pick cancelled" after the sketch is gone.
		disarm_face_pick()
		_variant_bar.visible = false
		hide_selection_actions()
		_contour_bar.visible = false
		_selected_contours.clear()
		if sketch_mode != null:
			sketch_mode.set_contour_highlight([], -1)
		_dim_editing = false


func show_variants(kind: String, variants: Array, screen_pos: Vector2) -> void:
	_active_kind = kind
	_clear_bar(_variant_bar)
	for v in variants:
		var label: String = str(v)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.custom_minimum_size = Vector2(0, _chip_h())
		b.toggle_mode = true
		b.set_meta("variant", label)
		b.add_theme_stylebox_override("pressed", _active_chip_style())
		b.add_theme_stylebox_override("hover_pressed", _active_chip_style())
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.pressed.connect(func() -> void:
			variant_chosen.emit(kind, label)
			sync_variant_highlight())
		_variant_bar.add_child(b)
	sync_variant_highlight()
	_variant_bar.visible = not variants.is_empty()
	# Ignore a caller Y that would pull the chips up into the finish bar.
	if _variant_bar.visible:
		place_variant_row(screen_pos.x)


## Variant chip that matches what SketchMode is doing right now.
func _active_variant() -> String:
	if sketch_mode == null:
		return ""
	if _active_kind == "line":
		return "centerline" if sketch_mode.tool == SketchMode.Tool.CENTERLINE else "line"
	return sketch_mode.tool_variant


## Exactly one chip is pressed: the active variant. A toggle chip pressed twice
## would un-press itself, so every press re-syncs.
func sync_variant_highlight() -> void:
	if _variant_bar == null:
		return
	var active := _active_variant()
	for c in _variant_bar.get_children():
		var b := c as Button
		if b != null and b.has_meta("variant"):
			b.set_pressed_no_signal(str(b.get_meta("variant")) == active)


func _active_chip_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("2d5f93")
	s.border_color = Color("6ab0f3")
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 4.0
	s.content_margin_right = 4.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


## Stack variant chips on the next row under the finish bar. Caller Y is not
## used; rail_x is the left edge. WP4 calls this instead of show_variants(y=80).
func place_variant_row(rail_x: float) -> void:
	if _variant_bar == null:
		return
	if _variant_bar.get_child_count() > 0:
		_variant_bar.visible = true
	if not _variant_bar.visible:
		return
	_stack_sketch_rows()


func _stack_sketch_rows() -> void:
	var x := _finish_session_pos().x
	var y := _finish_bar_bottom() + 4.0
	if _contour_bar != null and _contour_bar.visible:
		_place_bar(_contour_bar, Vector2(x, y))
		_contour_bar.reset_size()
		var h := maxf(_contour_bar.size.y, _contour_bar.get_combined_minimum_size().y)
		if h < 1.0:
			h = float(_chip_h())
		y += h + 4.0
	if _variant_bar != null and _variant_bar.visible:
		_place_bar(_variant_bar, Vector2(x, y))
		_variant_bar.reset_size()
		var vh := maxf(_variant_bar.size.y, float(_chip_h()))
		y = _variant_bar.position.y + vh + 4.0
	if _action_bar != null and _action_bar.visible:
		# Sit to the right of the finish bar, not in a band under it across
		# the canvas (that covered the wrench empty-canvas click).
		_relayout_action_bar(_action_bar_anchor())


func _finish_bar_bottom() -> float:
	if _finish_bar == null:
		return 42.0 + float(_chip_h())
	_finish_bar.reset_size()
	var top := _finish_bar.position.y
	if _finish_bar.visible and _finish_bar.size.y <= 0.0:
		top = 42.0
	var h := maxf(_finish_bar.size.y, _finish_bar.get_combined_minimum_size().y)
	if h <= 0.0:
		h = float(_chip_h())
	return top + h


func _keep_variant_below_finish() -> void:
	if _variant_bar == null or _finish_bar == null:
		return
	if not _variant_bar.visible or not _finish_bar.visible:
		return
	var fr := _finish_bar.get_global_rect()
	var need_y := fr.position.y + fr.size.y + float(CHIP_PAD)
	if _variant_bar.global_position.y < need_y:
		_variant_bar.global_position.y = need_y


func hide_variants() -> void:
	_variant_bar.visible = false
	_active_kind = ""


func show_selection_actions(actions: Array, screen_pos: Vector2) -> void:
	_action_verbs = actions.duplicate()
	_action_wrap_width = -1.0
	_action_dock_to_rail = _finish_bar != null and _finish_bar.visible
	_action_bar.visible = not actions.is_empty()
	if not _action_bar.visible:
		_clear_bar(_action_bar)
		return
	if _action_dock_to_rail:
		# Always sit to the right of the SketchTools rail / finish bar, never
		# on the pointer. A long HBox used to clamp to x=8 and paint over the
		# rail (sx-033 A1). Overflow goes in … More so the row stays one line.
		_stack_sketch_rows()
	else:
		_relayout_action_bar(screen_pos + Vector2(12, CHIP_PAD))


func hide_selection_actions() -> void:
	_action_bar.visible = false
	_action_verbs.clear()
	_action_wrap_width = -1.0
	_clear_bar(_action_bar)


## Merge-sketches option strip (2+ pads selected outside sketch mode).
func show_merge_menu(screen_pos: Vector2) -> void:
	show_selection_actions(
			["merge_join", "merge_spline", "merge_composite", "merge_clear"], screen_pos)


## Multi-sketch → 3D workflow (SolidWorks-style chips from pad selection).
func show_sketch_to_3d_menu(actions: Array, screen_pos: Vector2) -> void:
	show_selection_actions(actions, screen_pos)


func _clear_bar(bar: Control) -> void:
	while bar.get_child_count() > 0:
		var c := bar.get_child(0)
		bar.remove_child(c)
		c.queue_free()


func _process(_delta: float) -> void:
	if _finish_bar != null and _finish_bar.visible:
		_sync_dim_affordance()
		_place_finish_session()
		_stack_sketch_rows()


func _sketch_tools_rail() -> Control:
	var tree := get_tree()
	if tree == null:
		return null
	var n := tree.root.find_child("SketchTools", true, false)
	if n is Control:
		return n as Control
	return null


func _finish_session_pos() -> Vector2:
	var x := 60.0
	var y := 42.0
	var rail := _sketch_tools_rail()
	if rail != null and rail.is_visible_in_tree():
		rail.reset_size()
		var r := rail.get_global_rect()
		x = r.end.x + 8.0 - global_position.x
	return Vector2(x, y)


## Local origin for selection chips: right of the finish session (or the rail
## when that bar is hidden) so the row cannot run over Arc/Point or the canvas.
func _action_bar_anchor() -> Vector2:
	var pos := _finish_session_pos()
	if _finish_bar == null or not _finish_bar.visible:
		return pos
	_finish_bar.reset_size()
	var fr := _finish_bar.get_global_rect()
	var gp := global_position
	return Vector2(maxf(pos.x, fr.end.x + 8.0 - gp.x), fr.position.y - gp.y)


func _place_finish_session() -> void:
	if _finish_bar == null:
		return
	var pos := _finish_session_pos()
	_finish_bar.reset_size()
	var sz := _finish_bar.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	# Do not slide left of the SketchTools gap: that is the Exit Sketch overlap.
	var y := clampf(pos.y, 8.0, maxf(8.0, vp.y - sz.y - 8.0))
	_finish_bar.position = Vector2(pos.x, y)


func _place_bar(bar: Control, pos: Vector2) -> void:
	bar.reset_size()
	var sz := bar.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	bar.position = Vector2(
		clampf(pos.x, 8, maxf(8, vp.x - sz.x - 8)),
		clampf(pos.y, 8, maxf(8, vp.y - sz.y - 8)))


## Available width from a local X to the viewport's right margin, capped so
## leftover chips go in … More instead of a band across the sketch.
func _chip_row_max_width(local_x: float) -> float:
	var vp := get_viewport_rect().size
	var room := maxf(96.0, vp.x - local_x - 8.0)
	return minf(room, ACTION_ROW_CAP)


func _make_action_chip(verb: String) -> Button:
	var b := Button.new()
	b.text = verb.capitalize().replace("_", " ")
	b.tooltip_text = verb
	b.custom_minimum_size = Vector2(0, _chip_h())
	b.pressed.connect(func() -> void: action_chosen.emit(verb))
	return b


func _new_chip_row() -> HBoxContainer:
	var row := _make_hbox()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _chip_min_width(b: Button) -> float:
	var ms := b.get_combined_minimum_size().x
	if ms >= 8.0:
		return ms
	var font: Font = b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	if font == null:
		font = ThemeDB.fallback_font
	if fs <= 0:
		fs = UiScale.body()
	var pad := 20.0
	var style := b.get_theme_stylebox("normal")
	if style != null:
		pad = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) + 8.0
	return font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad


func _make_more_chip(verbs: Array) -> MenuButton:
	var more := MenuButton.new()
	more.text = "… More"
	more.tooltip_text = "More sketch actions"
	more.custom_minimum_size = Vector2(0, _chip_h())
	more.flat = false
	var popup := more.get_popup()
	for i in verbs.size():
		var verb := str(verbs[i])
		popup.add_item(verb.capitalize().replace("_", " "))
		popup.set_item_metadata(i, verb)
	popup.id_pressed.connect(func(id: int) -> void:
		var v: Variant = popup.get_item_metadata(id)
		if v != null:
			action_chosen.emit(str(v)))
	return more


func _rebuild_wrapped_chips(max_w: float) -> void:
	if absf(max_w - _action_wrap_width) < 0.5 and _action_bar.get_child_count() > 0:
		return
	_action_wrap_width = max_w
	_clear_bar(_action_bar)
	if _action_verbs.is_empty():
		return
	var chips: Array[Button] = []
	var widths: Array[float] = []
	var measure := _new_chip_row()
	measure.visible = false
	_action_bar.add_child(measure)
	for a in _action_verbs:
		var b := _make_action_chip(str(a))
		measure.add_child(b)
		chips.append(b)
	var more_probe := _make_more_chip(["block"])
	measure.add_child(more_probe)
	measure.reset_size()
	var more_w := more_probe.get_combined_minimum_size().x
	if more_w < 8.0:
		more_w = _chip_min_width(more_probe)
	measure.remove_child(more_probe)
	more_probe.queue_free()
	for b in chips:
		var w := b.get_combined_minimum_size().x
		if w < 8.0:
			w = _chip_min_width(b)
		widths.append(w)
		measure.remove_child(b)
	_action_bar.remove_child(measure)
	measure.queue_free()
	var row := _new_chip_row()
	_action_bar.add_child(row)
	var used := 0.0
	var sep := 4.0
	var shown := 0
	for i in chips.size():
		var b: Button = chips[i]
		var bw: float = widths[i]
		var last := i == chips.size() - 1
		var reserve := 0.0 if last else sep + more_w
		if row.get_child_count() > 0 and used + sep + bw + reserve > max_w:
			break
		row.add_child(b)
		shown += 1
		used += bw if row.get_child_count() == 1 else sep + bw
	for i in range(shown, chips.size()):
		chips[i].queue_free()
	if shown < _action_verbs.size():
		var overflow: Array = _action_verbs.slice(shown)
		row.add_child(_make_more_chip(overflow))
	_action_bar.reset_size()


## Dock the action chips at `pos` (local). Never slides left of the live
## SketchTools / finish-bar right edge: leftover verbs go in … More instead
## of painting over Arc/Point (sx-033 A1).
func _relayout_action_bar(pos: Vector2) -> void:
	if _action_bar == null or not _action_bar.visible:
		return
	var x := maxf(pos.x, _action_bar_anchor().x)
	var max_w := _chip_row_max_width(x)
	_rebuild_wrapped_chips(max_w)
	_action_bar.reset_size()
	var vp := get_viewport_rect().size
	var sz := _action_bar.get_combined_minimum_size()
	var h := maxf(sz.y, _action_bar.size.y)
	if h < 1.0:
		h = float(_chip_h())
	var y := clampf(pos.y, 8.0, maxf(8.0, vp.y - h - 8.0))
	_action_bar.position = Vector2(x, y)
