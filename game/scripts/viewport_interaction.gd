class_name ViewportInteraction
extends Control
## Full-window overlay owning all 3D interaction: selection clicks, body
## drag-move on the ground plane, face push/pull drag, palette drops, and
## click-to-place for palette button clicks.

signal status(text: String)
## Emitted when click-to-place arms or disarms (main swaps left-rail chrome).
signal place_changed(active: bool)
## Request sketch-on-selection (main owns SketchMode.begin).
signal sketch_requested
## Open Paste Special dialog (main owns the offset UI).
signal paste_special_requested

var view: DocumentView
var camera: OrbitCamera
var model_space: Node3D  # kernel Z-up frame
var sketch_mode: SketchMode  # optional; when active, input goes to sketching
var sketch_chrome: SketchContextChrome  # finish-bar dim blank while sketching
var world_gizmos: WorldGizmos
var measure_overlay: MeasureOverlay
var transform_hud: TransformHud
var ops_panel: OpsPanel

enum DragMode { NONE, MOVE_BODY, ROTATE_BODY, PUSH_PULL, BOX_SELECT, ORBIT_VIEW, RESIZE_BODY, MOVE_INSTANCE }
var _drag_mode := DragMode.NONE
var _drag_start_mouse := Vector2.ZERO
var _drag_start_point := Vector3.ZERO   # model-space hit point at drag start
var _drag_normal := Vector3.ZERO        # model-space face normal (push/pull)
var _drag_accum := Vector3.ZERO         # applied translation so far (move)
var _drag_pp_applied := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false
var _last_drag_pos := Vector2.ZERO
## Move drag: pre-drag selection center + body node transform for live preview.
var _move_start_center := Vector3.ZERO
var _move_start_node_xform := Transform3D.IDENTITY
var _move_delta_base := Vector3.ZERO  # last kernel-committed Δ from start center
## Blender-style axis lock during a body move: tap X/Y/Z to toggle (-1 = free).
const AXIS_X := 0
const AXIS_Y := 1
const AXIS_Z := 2
var _move_axis_lock := -1
## Rotate drag about a principal axis through the selection center.
var _rotate_axis := Vector3.ZERO
var _rotate_center := Vector3.ZERO
var _rotate_start_angle := 0.0
var _rotate_angle := 0.0
var _rotate_start_node_xform := Transform3D.IDENTITY
## True when the LMB press landed on empty space (orbit / box-select candidate).
var _press_empty := false
## Screen travel accumulated during the current press (for soft click detection).
var _press_travel := 0.0
## Screen-space rubber-band rect while in BOX_SELECT (drawn via _draw).
var _box_rect := Rect2()
## Ctrl held on the last LMB press: empty-drag becomes rubber-band box select.
var _box_drag := false
## Shift or Ctrl held on press: additive select; empty click will not clear.
var _additive_click := false
## SELECT-tool drag-to-edit in sketch mode (begin/update/end_drag).
var _sketch_dragging := false
var _sketch_drag_moved := false
## Push/pull preview distance (wire badge while dragging).
var _pp_preview_dist := 0.0
var _pp_badge_screen := Vector2.ZERO
## Selection-aware chrome.
var _context_menu: PopupMenu
var _selection_strip: PanelContainer
var _strip_fillet: Button
var _strip_hide: Button
var _strip_delete: Button
var _strip_sketch: Button
var _strip_look: Button
var _strip_plane: Button
var _strip_fuse: Button
var _strip_cut: Button
var _strip_common: Button
var _strip_hole: Button
var _strip_hole_wizard: Button
var _strip_clash: Button
var _strip_triball: Button
var connector_overlay: ConnectorOverlay
var triball: TriBallGizmo
var marking_menu: MarkingMenu
## RMB: click = context menu, drag = orbit (peer FreeCAD / SW-like).
var _rmb_pressed := false
var _rmb_press_pos := Vector2.ZERO
var _rmb_orbiting := false
## LMB on selected body: wait for travel before arming move (avoids nudge).
var _pending_body_move := false
var _pending_move_point := Vector3.ZERO
## LMB on a component instance: deferred ground-plane drag; on release the
## transform commits and mates re-solve (peer "drag then snap home" feel).
var _pending_instance_move := false
var _drag_instance_id := ""
var _instance_start_xform := Transform3D.IDENTITY
var _instance_grab_point := Vector3.ZERO
## Snap-on-drop: the connector face under the cursor mid-drag (magnet target),
## and the face of the dragged part that will seat onto it.
var _snap_target_face := ""
var _snap_source_face := ""
## Spacebar orientation / named-view popup (SW Spacebar / Onshape S lite).
var _orient_popup: PopupPanel
## Click-a-dimension in-viewport editor (sketch SELECT tool).
var _dim_edit_popup: PopupPanel
var _dim_edit_line: LineEdit
var _dim_edit_index := -1
var _last_hover_key := ""

## Armed click-to-place kind, or "" when idle.
var _place_kind := ""
var _place_ghost: MeshInstance3D = null
## Sizes used for the place ghost / commit (W×H×D mm; see DocumentView mapping).
var place_size := Vector3(
		DocumentView.DEFAULT_PRIMITIVE_MM,
		DocumentView.DEFAULT_PRIMITIVE_MM,
		DocumentView.DEFAULT_PRIMITIVE_MM)
## After a place commit, skip the matching LMB release select (avoids clear-on-miss).
var _ignore_select_release := false
## Snap-to-grid dock (always visible; parents into `top_chrome` beside File menu).
var place_snap_enabled := true
var place_snap_mm := 0.1
## Host HBox from Main (File/Insert/View); snap bar docks as the next child.
var top_chrome: Control
var _place_snap_panel: PanelContainer
var _place_snap_check: CheckBox
var _place_snap_spin: SpinBox
## Body-move magnets: active snap guide, hover-preferred target, start AABB.
var _move_snap_active: Dictionary = {}
var _move_snap_hover_body := ""
var _move_start_bb: Dictionary = {}
## Active move plane (default = world XY). Body drag stays on this plane; the
## yellow lift grip moves along its normal. Set via View menu pick or face RMB.
var active_plane_origin := Vector3.ZERO
var active_plane_normal := Vector3(0, 0, 1)
var _active_plane_custom := false
## One-shot: next face click sets the active plane (View → Set Active Plane…).
var _picking_active_plane := false
## One-shot: next face / pad / ground click starts or reopens a sketch.
var _picking_sketch_host := false

signal sketch_host_picked(kind: String, face_id: String, body_id: String, pad_fid: String)
## `additive` is true for Ctrl/Cmd+click multi-select (from the pointer event).
signal sketch_pad_clicked(fid: String, additive: bool)

## Resize-drag state (AABB corner / face-center handles).
var _resize_min := Vector3.ZERO
var _resize_max := Vector3.ZERO
var _resize_start_min := Vector3.ZERO
var _resize_start_max := Vector3.ZERO
## Per-axis: -1 = moving min face, +1 = moving max face, 0 = fixed.
var _resize_signs := Vector3.ZERO
var _resize_distance := 0.0
var _resize_axis_hint := "Δ"
## Precision field: last committed resize distance / rotate degrees.
var _precision_base := 0.0
var _precision_signs := Vector3.ZERO
var _precision_min := Vector3.ZERO
var _precision_max := Vector3.ZERO
var _precision_kind := ""  # "resize" | "rotate"
var _precision_rotate_axis := Vector3.ZERO
var _precision_rotate_center := Vector3.ZERO

const CLICK_SLOP := 12.0
## Empty-drag travel below this is still treated as a deselect click (trackpad).
const ORBIT_CLICK_SLOP := 22.0
const HANDLE_PX := 22.0
const AXIS_HANDLE_PX := 26.0
const AXIS_LEN_FRAC := 0.35
## Grip arrows cap at this fraction of screen width (horizontal) or height (vertical).
const GRIP_SCREEN_FRAC := 0.10
## Screen-space magnet hold for grid / object snap during body move.
const SNAP_HOLD_PX := 6.0
## Tighter than approach: only when the cursor is this close (screen px) to a
## measure snap (corner / edge mid / surface mid) does the X relocate onto the
## near body. Larger misses keep the X pinned and dim to the perpendicular foot
## instead — so the perp cue appears earlier. Pixel distance scales with zoom
## and works for large models (no model-mm gate).
const MEASURE_RELOCATE_PX := 14.0
const GHOST_NAME := "PlaceGhost"
## Kernel primitive sizes used for sit-on-plane ghost offsets (half-heights).
const PLACE_HALF_Z := {
	"box": 2.5,
	"cylinder": 2.5,
	"cone": 2.5,
	"sphere": 2.5,
	"torus": 0.8,
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# anchors_and_offsets so we actually fill the viewport (preset alone can
	# leave size at 0 until a parent container lays us out — and we are not
	# in a container).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	_mount_world_gizmos()
	_mount_measure_overlay()
	_mount_wave0_chrome()
	_build_place_snap_ui()
	_build_transform_hud()
	_build_context_menu()
	_build_selection_strip()
	_build_orient_popup()
	_build_dim_edit_popup()
	if sketch_mode != null:
		sketch_mode.dimension_edit_requested.connect(_show_dim_edit)
		# Strip hides while sketching (modal); restore it when the sketch ends.
		sketch_mode.finished.connect(func(_id: String) -> void: _refresh_selection_strip())
		sketch_mode.cancelled.connect(_refresh_selection_strip)
	if view != null:
		view.selection_changed.connect(_on_view_selection_changed)
		view.document_changed.connect(_on_view_document_changed)
	if camera != null:
		camera.view_changed.connect(_on_camera_view_changed)
	resized.connect(queue_redraw)


func is_placing() -> bool:
	return _place_kind != ""


## Re-evaluate the selection strip (call after entering sketch mode, which
## has no start signal of its own).
func refresh_selection_chrome() -> void:
	_refresh_selection_strip()


func _on_camera_view_changed() -> void:
	# Gizmo screen projections only need a redraw when the camera moves.
	if view != null and view.selected_body != "" and _place_kind == "":
		queue_redraw()


func _build_transform_hud() -> void:
	transform_hud = TransformHud.new()
	transform_hud.name = "TransformHud"
	add_child(transform_hud)
	transform_hud.position_committed.connect(_on_hud_position)
	transform_hud.size_committed.connect(_on_hud_size)
	transform_hud.precision_committed.connect(_on_hud_precision)
	transform_hud.move_delta_committed.connect(_on_hud_move_delta)


func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "SelectionContext"
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id)
	UiScroll.soften_menu(_context_menu)


func _build_selection_strip() -> void:
	_selection_strip = PanelContainer.new()
	_selection_strip.name = "SelectionStrip"
	_selection_strip.visible = false
	_selection_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_selection_strip.offset_left = -420
	_selection_strip.offset_right = 420
	_selection_strip.offset_top = 8
	_selection_strip.offset_bottom = 44
	add_child(_selection_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_selection_strip.add_child(row)
	_strip_fuse = UIIcons.button("fuse", "Join", "Fuse selected bodies (primary receives the result)")
	_strip_fuse.pressed.connect(func() -> void: _ctx_boolean("fuse"))
	row.add_child(_strip_fuse)
	_strip_cut = UIIcons.button("cut", "Subtract", "Cut tool bodies from the primary selection")
	_strip_cut.pressed.connect(func() -> void: _ctx_boolean("cut"))
	row.add_child(_strip_cut)
	_strip_common = UIIcons.button("common", "Intersect", "Keep only the common volume of the selection")
	_strip_common.pressed.connect(func() -> void: _ctx_boolean("common"))
	row.add_child(_strip_common)
	_strip_hole = Button.new()
	_strip_hole.name = "StripHole"
	_strip_hole.text = "Hole"
	_strip_hole.tooltip_text = "M6 through-all on the selected face / sketch points"
	_strip_hole.pressed.connect(_ctx_hole_m6)
	row.add_child(_strip_hole)
	_strip_hole_wizard = Button.new()
	_strip_hole_wizard.name = "StripHoleWizard"
	_strip_hole_wizard.text = "Hole Wizard…"
	_strip_hole_wizard.tooltip_text = "Arm Hole Wizard to multi-place holes on a face"
	_strip_hole_wizard.pressed.connect(func() -> void:
		if ops_panel != null:
			ops_panel._arm_hole_wizard())
	row.add_child(_strip_hole_wizard)
	_strip_clash = Button.new()
	_strip_clash.name = "StripClash"
	_strip_clash.text = "Clash"
	_strip_clash.tooltip_text = "Interference volume of two selected bodies"
	_strip_clash.pressed.connect(_ctx_clash)
	row.add_child(_strip_clash)
	_strip_triball = Button.new()
	_strip_triball.name = "StripTriBall"
	_strip_triball.text = "TriBall"
	_strip_triball.tooltip_text = "Rotate-copy about a ring (primary handle)"
	_strip_triball.pressed.connect(_ctx_triball)
	row.add_child(_strip_triball)
	_strip_fillet = Button.new()
	_strip_fillet.text = "Fillet"
	_strip_fillet.pressed.connect(func() -> void: _ctx_fillet())
	row.add_child(_strip_fillet)
	_strip_sketch = Button.new()
	_strip_sketch.text = "Sketch"
	_strip_sketch.tooltip_text = "Sketch on the selected face (then Extrude from the sketch bar)"
	_strip_sketch.pressed.connect(func() -> void: sketch_requested.emit())
	row.add_child(_strip_sketch)
	_strip_look = Button.new()
	_strip_look.text = "Look at"
	_strip_look.tooltip_text = "Orient the camera normal to the selected face"
	_strip_look.pressed.connect(func() -> void: _ctx_look_at())
	row.add_child(_strip_look)
	_strip_plane = Button.new()
	_strip_plane.text = "Active plane"
	_strip_plane.tooltip_text = "Use the selected flat face as the body-move plane"
	_strip_plane.pressed.connect(func() -> void: _ctx_set_active_plane())
	row.add_child(_strip_plane)
	_strip_hide = Button.new()
	_strip_hide.text = "Hide"
	_strip_hide.pressed.connect(func() -> void: _ctx_hide())
	row.add_child(_strip_hide)
	_strip_delete = Button.new()
	_strip_delete.text = "Delete"
	_strip_delete.pressed.connect(func() -> void: _ctx_delete())
	row.add_child(_strip_delete)


func _build_orient_popup() -> void:
	_orient_popup = PopupPanel.new()
	_orient_popup.name = "OrientPopup"
	add_child(_orient_popup)
	var col := VBoxContainer.new()
	col.name = "OrientCol"
	col.add_theme_constant_override("separation", 4)
	_orient_popup.add_child(col)
	_rebuild_orient_popup()


func _rebuild_orient_popup() -> void:
	if _orient_popup == null:
		return
	var col: VBoxContainer = _orient_popup.get_node_or_null("OrientCol") as VBoxContainer
	if col == null:
		return
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "Orientation (Space)"
	col.add_child(title)
	for entry in [
		["Front", 1], ["Right", 2], ["Top", 3], ["Isometric", 7],
		["Frame selection", 20], ["Frame all", 21], ["Ortho/Persp", 5],
	]:
		var b := Button.new()
		b.text = str(entry[0])
		var id: int = int(entry[1])
		b.pressed.connect(func() -> void:
			_on_orient_id(id)
			_orient_popup.hide())
		col.add_child(b)
	if camera != null:
		var named := camera.named_view_list()
		if not named.is_empty():
			col.add_child(HSeparator.new())
			var saved_lbl := Label.new()
			saved_lbl.text = "Saved views"
			saved_lbl.add_theme_font_size_override("font_size", 11)
			col.add_child(saved_lbl)
			for view_name in named:
				var nb := Button.new()
				nb.text = "Restore “%s”" % view_name
				var n := str(view_name)
				nb.pressed.connect(func() -> void:
					if camera.restore_named_view(n):
						status.emit("Restored view “%s”" % n)
					_orient_popup.hide())
				col.add_child(nb)
	# Offer a one-click path to create while palettes may be hidden (e.g. Form).
	col.add_child(HSeparator.new())
	var create_lbl := Label.new()
	create_lbl.text = "Create"
	create_lbl.add_theme_font_size_override("font_size", 11)
	col.add_child(create_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for entry in ["box", "cylinder", "sphere", "cone", "torus"]:
		var b := Button.new()
		b.text = entry.capitalize()
		var kind := String(entry)
		b.pressed.connect(func() -> void:
			_arm_place(kind)
			_orient_popup.hide())
		row.add_child(b)


func _build_dim_edit_popup() -> void:
	_dim_edit_popup = PopupPanel.new()
	_dim_edit_popup.name = "DimEditPopup"
	add_child(_dim_edit_popup)
	var row := HBoxContainer.new()
	_dim_edit_popup.add_child(row)
	var lbl := Label.new()
	lbl.text = "Dim:"
	row.add_child(lbl)
	_dim_edit_line = LineEdit.new()
	_dim_edit_line.custom_minimum_size = Vector2(90, 0)
	_dim_edit_line.select_all_on_focus = true
	_dim_edit_line.text_submitted.connect(_apply_dim_edit)
	row.add_child(_dim_edit_line)


## Open the in-viewport dimension editor for dimensions[index] (SELECT click
## on the label). Enter commits + re-solves; Esc / clicking away cancels.
func _show_dim_edit(index: int) -> void:
	if sketch_mode == null or _dim_edit_popup == null:
		return
	if index < 0 or index >= sketch_mode.dimensions.size():
		return
	_dim_edit_index = index
	var dim: Dictionary = sketch_mode.dimensions[index]
	_dim_edit_line.text = String.num(sketch_mode._dimension_display_value(dim), 3)
	var at := Vector2i(get_viewport().get_mouse_position()) + Vector2i(8, 8)
	_dim_edit_popup.popup(Rect2i(at, Vector2i(150, 40)))
	_dim_edit_line.grab_focus()


func _apply_dim_edit(text: String) -> void:
	_dim_edit_popup.hide()
	if sketch_mode == null or _dim_edit_index < 0:
		return
	var v := text.to_float()
	if v <= 0.0:
		status.emit("Dimension must be a positive number")
		return
	var result: String = sketch_mode.set_dimension_value(_dim_edit_index, v)
	_dim_edit_index = -1
	if result == "failed":
		status.emit("Dimension rejected — constraints could not be satisfied")
	elif result != "":
		status.emit("Dimension updated")


func _build_place_snap_ui() -> void:
	# Compact bar: docks immediately right of File/Insert/View in Main's TopChrome.
	_place_snap_panel = PanelContainer.new()
	_place_snap_panel.name = "PlaceSnapBar"
	_place_snap_panel.visible = true
	_place_snap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if top_chrome != null:
		top_chrome.add_child(_place_snap_panel)
	else:
		_place_snap_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_place_snap_panel.position = Vector2(168, 8)
		add_child(_place_snap_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_place_snap_panel.add_child(row)
	_place_snap_check = CheckBox.new()
	_place_snap_check.text = "Snap"
	_place_snap_check.tooltip_text = "Snap place / move to grid"
	_place_snap_check.add_theme_font_size_override("font_size", 11)
	_place_snap_check.button_pressed = place_snap_enabled
	_place_snap_check.toggled.connect(func(on: bool) -> void:
		place_snap_enabled = on)
	row.add_child(_place_snap_check)
	_place_snap_spin = SpinBox.new()
	_place_snap_spin.min_value = 0.01
	_place_snap_spin.max_value = 100.0
	_place_snap_spin.step = 0.01
	_place_snap_spin.value = place_snap_mm
	_place_snap_spin.suffix = "mm"
	_place_snap_spin.tooltip_text = "Grid snap resolution"
	_place_snap_spin.custom_minimum_size = Vector2(72, 0)
	_place_snap_spin.value_changed.connect(func(v: float) -> void:
		place_snap_mm = maxf(v, 0.01))
	row.add_child(_place_snap_spin)


func _snap_point(p: Vector3) -> Vector3:
	# World-axis snap (legacy / move magnets). Place uses `_snap_on_active_plane`.
	if not place_snap_enabled:
		return p
	var s := maxf(place_snap_mm, 0.01)
	return Vector3(snappedf(p.x, s), snappedf(p.y, s), snappedf(p.z, s))


## Snap in the active plane's UV, keeping the point on that plane.
func _snap_on_active_plane(p: Vector3) -> Vector3:
	var n := _active_plane_n()
	var o := active_plane_origin
	var x := _active_plane_x()
	var y := n.cross(x).normalized()
	p = p - n * (p - o).dot(n)
	if not place_snap_enabled:
		return p
	var s := maxf(place_snap_mm, 0.01)
	var u := snappedf((p - o).dot(x), s)
	var v := snappedf((p - o).dot(y), s)
	return o + x * u + y * v


## In-plane +X for the active plane (matches the white grid axes).
func _active_plane_x() -> Vector3:
	var n := _active_plane_n()
	var x := n.cross(Vector3(0, 0, 1))
	if x.length_squared() < 1e-12:
		x = Vector3.RIGHT
	else:
		x = x.normalized()
	return x


## Active-plane normal flipped so +N points toward the camera ("my side").
func _place_sit_normal() -> Vector3:
	var n := _active_plane_n()
	if camera == null or model_space == null:
		return n
	var inv: Transform3D = model_space.global_transform.affine_inverse()
	var cam_pos: Vector3 = inv * camera.global_position
	if (cam_pos - active_plane_origin).dot(n) < 0.0:
		return -n
	return n


## Half-extent along sit normal for the place ghost / insert floor offset.
func _place_half_height(kind: String) -> float:
	match kind:
		"box", "cylinder", "cone":
			return place_size.z * 0.5
		"sphere":
			return place_size.x * 0.5
		"torus":
			return place_size.y * 0.5
		_:
			return float(PLACE_HALF_Z.get(kind, 25.0))


func _show_snap_bar() -> void:
	# Dock is always visible; keep checkbox / spin in sync with state.
	if _place_snap_panel == null:
		return
	_place_snap_check.button_pressed = place_snap_enabled
	_place_snap_spin.value = place_snap_mm


func _hide_snap_bar_unless_placing() -> void:
	# Snap dock stays up; callers still invoke this after move release.
	pass


## Normalize a kernel bbox ({min,max}) to include center/size.
func _bb_with_center(bb: Dictionary) -> Dictionary:
	if bb.is_empty() or not bb.has("min") or not bb.has("max"):
		return {}
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	return {
		"min": mn,
		"max": mx,
		"center": (mn + mx) * 0.5,
		"size": mx - mn,
	}


## Center + 6 AABB face midpoints for snap matching. When `body_id` is set,
## also append real B-rep face (surface) midpoints as kind "surface".
func _aabb_snap_anchors(bb: Dictionary, body_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var full := _bb_with_center(bb)
	if full.is_empty():
		return out
	var mn: Vector3 = full["min"]
	var mx: Vector3 = full["max"]
	var c: Vector3 = full["center"]
	out.append({"point": c, "kind": "center", "axis": -1, "sign": 0})
	out.append({"point": Vector3(mx.x, c.y, c.z), "kind": "face", "axis": 0, "sign": 1})
	out.append({"point": Vector3(mn.x, c.y, c.z), "kind": "face", "axis": 0, "sign": -1})
	out.append({"point": Vector3(c.x, mx.y, c.z), "kind": "face", "axis": 1, "sign": 1})
	out.append({"point": Vector3(c.x, mn.y, c.z), "kind": "face", "axis": 1, "sign": -1})
	out.append({"point": Vector3(c.x, c.y, mx.z), "kind": "face", "axis": 2, "sign": 1})
	out.append({"point": Vector3(c.x, c.y, mn.z), "kind": "face", "axis": 2, "sign": -1})
	if body_id != "" and view != null and view.doc != null:
		for face_id in view.doc.get_face_ids(body_id):
			var mid: Vector3 = view.doc.face_midpoint(face_id)
			out.append({"point": mid, "kind": "surface", "axis": -1, "sign": 0})
	return out


func _snap_kind_priority(src_kind: String, dst_kind: String, src_axis: int, dst_axis: int) -> int:
	if src_kind == "center" and dst_kind == "center":
		return 0
	if src_kind == "surface" and dst_kind == "surface":
		return 1
	if src_kind == "face" and dst_kind == "face" and src_axis == dst_axis and src_axis >= 0:
		return 1
	if src_kind == "surface" or dst_kind == "surface":
		return 2
	if src_kind == "center" or dst_kind == "center":
		return 2
	return 3


## Constrain a snap candidate to the active move axis lock (Blender-style).
func _apply_axis_lock_to_snap(cand: Vector3, raw: Vector3) -> Vector3:
	match _move_axis_lock:
		AXIS_X:
			return Vector3(cand.x, 0.0, raw.z)
		AXIS_Y:
			return Vector3(0.0, cand.y, raw.z)
		AXIS_Z:
			return Vector3(raw.x, raw.y, cand.z)
		_:
			return Vector3(cand.x, cand.y, raw.z)


func _screen_delta_px(a: Vector3, b: Vector3) -> float:
	if camera == null:
		return 1e9
	var wa: Vector3 = model_space.to_global(a)
	var wb: Vector3 = model_space.to_global(b)
	if camera.is_position_behind(wa) or camera.is_position_behind(wb):
		return 1e9
	return camera.unproject_position(wa).distance_to(camera.unproject_position(wb))


## Closest AABB surface pair along `axis` (0=X,1=Y,2=Z). Returns gap segment + mm.
func _closest_surface_gap(sel_bb: Dictionary, other_bb: Dictionary, axis: int) -> Dictionary:
	var empty := {"gap_a": Vector3.ZERO, "gap_b": Vector3.ZERO, "gap_mm": 0.0}
	if sel_bb.is_empty() or other_bb.is_empty() or axis < 0 or axis > 2:
		return empty
	var smn: Vector3 = sel_bb["min"]
	var smx: Vector3 = sel_bb["max"]
	var omn: Vector3 = other_bb["min"]
	var omx: Vector3 = other_bb["max"]
	var sc: Vector3 = sel_bb["center"]
	var oc: Vector3 = other_bb["center"]
	# Lateral mid in the other two axes (overlap slab mid, else average of centers).
	var mid := Vector3(
			(sc.x + oc.x) * 0.5, (sc.y + oc.y) * 0.5, (sc.z + oc.z) * 0.5)
	for a in [0, 1, 2]:
		if a == axis:
			continue
		var s0 := smn[a]
		var s1 := smx[a]
		var o0 := omn[a]
		var o1 := omx[a]
		var lo := maxf(s0, o0)
		var hi := minf(s1, o1)
		if hi >= lo:
			mid[a] = (lo + hi) * 0.5
		else:
			mid[a] = (sc[a] + oc[a]) * 0.5
	var a_pt := mid
	var b_pt := mid
	var gap := 0.0
	if smx[axis] <= omn[axis]:
		gap = omn[axis] - smx[axis]
		a_pt[axis] = smx[axis]
		b_pt[axis] = omn[axis]
	elif omx[axis] <= smn[axis]:
		gap = smn[axis] - omx[axis]
		a_pt[axis] = omx[axis]
		b_pt[axis] = smn[axis]
	else:
		# Overlap / flush: align through shared plane at contact mid.
		var plane := (minf(smx[axis], omx[axis]) + maxf(smn[axis], omn[axis])) * 0.5
		a_pt[axis] = plane
		b_pt[axis] = plane
		gap = 0.0
	return {"gap_a": a_pt, "gap_b": b_pt, "gap_mm": gap}


func _move_snap_target_body(live_center: Vector3) -> String:
	var selected := _selected_body_ids()
	if _move_snap_hover_body != "" and not selected.has(_move_snap_hover_body):
		var hbb := _bb_with_center(view.doc.measure_bbox(_move_snap_hover_body))
		if not hbb.is_empty():
			return _move_snap_hover_body
	var best_id := ""
	var best_d := INF
	for id in view.doc.body_ids():
		if selected.has(id):
			continue
		var bb := _bb_with_center(view.doc.measure_bbox(id))
		if bb.is_empty():
			continue
		var d: float = live_center.distance_squared_to(bb["center"])
		if d < best_d:
			best_d = d
			best_id = id
	return best_id


## Primary selected body id while moving (for real face-mid snap anchors).
func _move_body_id_for_snap() -> String:
	if view == null:
		return ""
	if view.selected_body != "":
		return view.selected_body
	var ids := _selected_body_ids()
	return str(ids[0]) if not ids.is_empty() else ""


func _update_move_snap_hover(screen_pos: Vector2) -> void:
	_move_snap_hover_body = ""
	var ray := _model_ray(screen_pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if hit.is_empty():
		return
	var body := str(hit.get("body", ""))
	if body == "" or _selected_body_ids().has(body):
		return
	_move_snap_hover_body = body


## Resolve object / grid snap for a free move delta. Returns {delta, ...guide} or {}.
func _resolve_move_snap(raw_delta: Vector3) -> Dictionary:
	_move_snap_active = {}
	if _move_start_bb.is_empty():
		return {}
	var raw_center := _move_start_center + raw_delta
	var target_id := _move_snap_target_body(raw_center)
	var best: Dictionary = {}
	var best_pri := 99
	var best_err := SNAP_HOLD_PX + 1.0
	if target_id != "":
		var other_bb := _bb_with_center(view.doc.measure_bbox(target_id))
		if not other_bb.is_empty():
			var srcs := _aabb_snap_anchors(_move_start_bb, _move_body_id_for_snap())
			var dsts := _aabb_snap_anchors(other_bb, target_id)
			for src in srcs:
				for dst in dsts:
					var cand: Vector3 = dst["point"] - src["point"]
					cand = _apply_axis_lock_to_snap(cand, raw_delta)
					var err := _screen_delta_px(raw_center, _move_start_center + cand)
					if err > SNAP_HOLD_PX:
						continue
					var pri := _snap_kind_priority(
							str(src["kind"]), str(dst["kind"]),
							int(src["axis"]), int(dst["axis"]))
					if pri > best_pri or (pri == best_pri and err >= best_err):
						continue
					best_pri = pri
					best_err = err
					var gap_axis := int(dst["axis"]) if int(dst["axis"]) >= 0 \
							else (int(src["axis"]) if int(src["axis"]) >= 0 else -1)
					var live_bb := {
						"min": _move_start_bb["min"] + cand,
						"max": _move_start_bb["max"] + cand,
						"center": _move_start_bb["center"] + cand,
						"size": _move_start_bb["size"],
					}
					if gap_axis < 0:
						var sep: Vector3 = other_bb["center"] - live_bb["center"]
						if absf(sep.x) >= absf(sep.y) and absf(sep.x) >= absf(sep.z):
							gap_axis = 0
						elif absf(sep.y) >= absf(sep.z):
							gap_axis = 1
						else:
							gap_axis = 2
						# Coincident centers: pick axis with largest face-to-face gap.
						if sep.length_squared() < 1e-10:
							var best_gap := -1.0
							for ax in [0, 1, 2]:
								var g := _closest_surface_gap(live_bb, other_bb, ax)
								if float(g["gap_mm"]) > best_gap:
									best_gap = float(g["gap_mm"])
									gap_axis = ax
					var gap := _closest_surface_gap(live_bb, other_bb, gap_axis)
					best = {
						"kind": "%s→%s" % [src["kind"], dst["kind"]],
						"src": src["point"] + cand,
						"dst": dst["point"],
						"delta": cand,
						"gap_a": gap["gap_a"],
						"gap_b": gap["gap_b"],
						"gap_mm": gap["gap_mm"],
						"body": target_id,
						"priority": pri,
					}
	if not best.is_empty():
		_move_snap_active = best
		return best
	# Grid snap when no object magnet holds.
	if place_snap_enabled:
		var snapped_c := _snap_point(raw_center)
		var grid_delta := _apply_axis_lock_to_snap(snapped_c - _move_start_center, raw_delta)
		var gerr := _screen_delta_px(raw_center, _move_start_center + grid_delta)
		if gerr <= SNAP_HOLD_PX and grid_delta.distance_squared_to(raw_delta) > 1e-14:
			best = {
				"kind": "grid",
				"src": _move_start_center + grid_delta,
				"dst": _move_start_center + grid_delta,
				"delta": grid_delta,
				"gap_a": _move_start_center + grid_delta,
				"gap_b": _move_start_center + grid_delta,
				"gap_mm": 0.0,
				"body": "",
				"priority": 10,
			}
			_move_snap_active = best
			return best
	return {}


## Ground grid as a sibling of DocumentView under ModelSpace.
## (RGB origin sticks live on ViewHud / OriginTriadHud.)
func _mount_world_gizmos() -> void:
	if model_space == null:
		return
	if model_space.get_node_or_null("WorldGizmos") != null:
		world_gizmos = model_space.get_node("WorldGizmos") as WorldGizmos
		return
	world_gizmos = WorldGizmos.new()
	world_gizmos.name = "WorldGizmos"
	model_space.add_child(world_gizmos)


func _mount_wave0_chrome() -> void:
	if model_space != null and model_space.get_node_or_null("ConnectorOverlay") == null:
		connector_overlay = ConnectorOverlay.new()
		connector_overlay.name = "ConnectorOverlay"
		connector_overlay.view = view
		model_space.add_child(connector_overlay)
	elif model_space != null:
		connector_overlay = model_space.get_node("ConnectorOverlay") as ConnectorOverlay
		if connector_overlay != null:
			connector_overlay.view = view
	if model_space != null and model_space.get_node_or_null("TriBallGizmo") == null:
		triball = TriBallGizmo.new()
		triball.name = "TriBallGizmo"
		triball.view = view
		triball.status.connect(func(t: String) -> void: status.emit(t))
		triball.copy_committed.connect(_on_triball_copy)
		model_space.add_child(triball)
	elif model_space != null:
		triball = model_space.get_node("TriBallGizmo") as TriBallGizmo
	if get_node_or_null("MarkingMenu") == null:
		marking_menu = MarkingMenu.new()
		marking_menu.name = "MarkingMenu"
		add_child(marking_menu)
		marking_menu.verb_picked.connect(_on_marking_verb)
		marking_menu.pick_chosen.connect(_on_marking_pick)
	else:
		marking_menu = get_node("MarkingMenu") as MarkingMenu


func _ctx_hole_m6() -> void:
	if view == null or view.selected_body == "":
		status.emit("Hole: select a body")
		return
	var info: Dictionary = view.feature_info(view.selected_body)
	var target := str(info.get("id", ""))
	if target == "":
		status.emit("Hole: body is not on the timeline")
		return
	var pos := Vector3(20, 20, 8)
	if view.selected_face != "":
		var mid: Variant = view.doc.face_midpoint(view.selected_face)
		if mid is Vector3:
			pos = mid
	var positions := PackedVector3Array()
	positions.append(pos)
	var hid := view.doc.graph_add_holes(target, "simple", positions, Vector3(0, 0, -1), 6.0, 0.0)
	status.emit("M6 hole" if hid != "" else "Hole failed")
	view._after_mutation()


func _ctx_clash() -> void:
	if view == null or view.selected_bodies.size() < 2:
		status.emit("Clash: select two bodies")
		return
	var v: float = view.doc.interference_volume(view.selected_bodies[0], view.selected_bodies[1])
	if v < 0.0:
		status.emit("Clash: not solids")
		return
	status.emit("Interference %.1f mm³" % v)


func _ctx_triball() -> void:
	if view == null or view.selected_body == "" or triball == null:
		status.emit("TriBall: select a body")
		return
	var bb: Dictionary = view.doc.measure_bbox(view.selected_body)
	var mn: Vector3 = bb.get("min", Vector3.ZERO)
	var mx: Vector3 = bb.get("max", Vector3.ONE)
	var mid := (mn + mx) * 0.5
	triball.begin(mid, Vector3.UP, 6)
	status.emit("TriBall — drag the ring, then click TriBall again to commit")


## A rib follows a sketch profile, so it needs one: the most recent sketch on
## the timeline, which is the sketch the user just drew and left.
func _ctx_rib() -> void:
	if view == null or view.selected_body == "":
		status.emit("Rib: select a body")
		return
	var info: Dictionary = view.feature_info(view.selected_body)
	var target := str(info.get("id", ""))
	if target == "":
		status.emit("Rib: body is not on the timeline")
		return
	var sketch := ""
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			sketch = str(f.get("id", ""))
	if sketch == "":
		status.emit("Rib: draw an open profile with Sketch first")
		return
	var hid := view.doc.graph_add_rib(target, sketch, 2.0, 8.0)
	status.emit("Rib along the sketch" if hid != "" else "Rib failed")
	view._after_mutation()


func _ctx_in_context() -> void:
	if view == null or view.selected_body == "":
		status.emit("In-context: select the neighbor body")
		return
	var ctx: String = view.doc.capture_context(view.selected_body, "Neighbor")
	if ctx == "":
		status.emit("In-context: capture failed")
		return
	var fid: String = view.doc.graph_add_in_context(ctx, 20.0, 20.0)
	status.emit("In-context pad from the neighbor" if fid != "" else "In-context pad failed")
	view._after_mutation()


func _ctx_convert_sheet() -> void:
	if view == null or view.selected_body == "":
		status.emit("Convert sheet: select a thin solid")
		return
	var info: Dictionary = view.feature_info(view.selected_body)
	var target := str(info.get("id", ""))
	if target == "":
		status.emit("Convert sheet: body is not on the timeline")
		return
	var fid: String = view.doc.graph_add_convert_sheet(target)
	status.emit("Converted to sheet metal" if fid != "" else "Convert sheet failed — not thin enough")
	view._after_mutation()


func _ctx_weld() -> void:
	if view == null or view.selected_edge == "":
		status.emit("Weld: select an edge")
		return
	var id: String = view.doc.add_weld(view.selected_edge, "fillet", 3.0)
	status.emit("Weld symbol on the sheet" if id != "" else "Weld failed")
	view._after_mutation()


func _on_triball_copy(count: int, angle_rad: float) -> void:
	if view == null or view.selected_body == "" or count < 2:
		return
	var info: Dictionary = view.feature_info(view.selected_body)
	var target := str(info.get("id", ""))
	if target == "":
		return
	var bb: Dictionary = view.doc.measure_bbox(view.selected_body)
	var mn: Vector3 = bb.get("min", Vector3.ZERO)
	var mx: Vector3 = bb.get("max", Vector3.ONE)
	var mid := (mn + mx) * 0.5
	var total := angle_rad if absf(angle_rad) > 1e-3 else TAU
	if view.doc.has_method("circular_pattern"):
		view.doc.circular_pattern(view.selected_body, mid, Vector3.UP, count, total)
	status.emit("TriBall copied %d" % count)
	view._after_mutation()


func _on_marking_verb(verb: String) -> void:
	match verb:
		"Fillet":
			_ctx_fillet()
		"Hole":
			_ctx_hole_m6()
		"Clash":
			_ctx_clash()
		"TriBall":
			_ctx_triball()
		"Rib":
			_ctx_rib()
		"In-context pad":
			_ctx_in_context()
		"Convert sheet":
			_ctx_convert_sheet()
		"Weld":
			_ctx_weld()
		"Look at":
			_ctx_look_at()
		"Print check":
			_ctx_print_check()
		_:
			status.emit(verb)


func _on_marking_pick(entity_id: String) -> void:
	if view == null or entity_id == "":
		return
	view.select_entity(entity_id, "")
	status.emit("Picked " + entity_id.substr(0, 8))


func _open_marking_menu(screen_pos: Vector2) -> void:
	if marking_menu == null:
		return
	var verbs := PackedStringArray(["Fillet", "Hole", "TriBall", "Rib", "In-context pad", "Convert sheet", "Weld", "Print check", "Look at"])
	if view != null and view.selected_bodies.size() >= 2:
		verbs.append("Clash")
	var picks: Array = []
	if view != null and view.selected_face != "" and view.selected_body != "":
		picks.append({"id": view.selected_face, "label": "Face " + view.selected_face.substr(0, 8)})
		picks.append({"id": view.selected_body, "label": "Body " + view.selected_body.substr(0, 8)})
	marking_menu.show_for(screen_pos, verbs, picks)


func _mount_measure_overlay() -> void:
	# Lives on this Control (not ModelSpace) — drawn in screen space on top.
	if get_node_or_null("MeasureOverlay") != null:
		measure_overlay = get_node("MeasureOverlay") as MeasureOverlay
	else:
		measure_overlay = MeasureOverlay.new()
		measure_overlay.name = "MeasureOverlay"
		add_child(measure_overlay)
	measure_overlay.view = view
	measure_overlay.sketch_mode = sketch_mode
	if not measure_overlay.changed.is_connected(_on_measure_overlay_changed):
		measure_overlay.changed.connect(_on_measure_overlay_changed)
	measure_overlay.refresh_bounds()


func _on_measure_overlay_changed() -> void:
	queue_redraw()


func _model_ray(screen_pos: Vector2) -> Array:
	# Returns [origin, direction] in model (kernel Z-up) space.
	var world_origin := camera.project_ray_origin(screen_pos)
	var world_dir := camera.project_ray_normal(screen_pos)
	var inv: Transform3D = model_space.global_transform.affine_inverse()
	return [inv * world_origin, inv.basis * world_dir]


## Intersection of the screen ray with the model XY (ground) plane.
func ground_point(screen_pos: Vector2) -> Variant:
	return _horizontal_plane_point(screen_pos, 0.0)


## Intersection with a horizontal plane at model height `z`.
func _horizontal_plane_point(screen_pos: Vector2, z: float) -> Variant:
	return _plane_point(screen_pos, Vector3(0, 0, z), Vector3(0, 0, 1))


## Ray ∩ plane through `origin` with unit-ish `normal` (model space). Null if
## parallel or behind the camera.
func _plane_point(screen_pos: Vector2, origin: Vector3, normal: Vector3) -> Variant:
	var n := normal.normalized()
	if n.length_squared() < 1e-12:
		return null
	var ray := _model_ray(screen_pos)
	var o: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var denom := dir.dot(n)
	if absf(denom) < 1e-9:
		return null
	var t := (origin - o).dot(n) / denom
	return null if t < 0 else o + dir * t


func active_plane_is_custom() -> bool:
	return _active_plane_custom


func reset_active_plane() -> void:
	_active_plane_custom = false
	active_plane_origin = Vector3.ZERO
	active_plane_normal = Vector3(0, 0, 1)
	_picking_active_plane = false
	_sync_grid_to_active_plane()
	status.emit("Active plane: ground (XY)")
	queue_redraw()


## Arm one-shot face pick (View → Set Active Plane…). Esc / RMB cancels.
func arm_pick_active_plane() -> void:
	if _place_kind != "":
		_disarm_place(false)
	_picking_sketch_host = false
	_picking_active_plane = true
	grab_focus()
	status.emit("Click a flat face to set the active plane (Esc to cancel)")


func cancel_pick_active_plane() -> void:
	if not _picking_active_plane:
		return
	_picking_active_plane = false
	status.emit("Set active plane cancelled")


## Arm one-shot pick for sketch host (face, yellow pad, or ground).
func arm_pick_sketch_host() -> void:
	if sketch_mode != null and sketch_mode.active:
		return
	if _place_kind != "":
		_disarm_place(false)
	_picking_active_plane = false
	_picking_sketch_host = true
	grab_focus()
	status.emit("Select a face or existing sketch (Esc to cancel)")


func cancel_pick_sketch_host() -> void:
	if not _picking_sketch_host:
		return
	_picking_sketch_host = false
	status.emit("Sketch pick cancelled")


func _commit_pick_sketch_host(screen_pos: Vector2) -> void:
	var ray := _model_ray(screen_pos)
	# Prefer yellow sketch pads.
	if view.sketch_pads != null:
		var pad_fid: String = view.sketch_pads.pick_pad(ray[0], ray[1])
		if pad_fid != "":
			_picking_sketch_host = false
			sketch_host_picked.emit("pad", "", "", pad_fid)
			return
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if not hit.is_empty() and str(hit.get("face", "")) != "":
		var face_id := str(hit["face"])
		var body_id := str(hit.get("body", ""))
		view.select_entity(body_id, face_id)
		_picking_sketch_host = false
		sketch_host_picked.emit("face", face_id, body_id, "")
		return
	# Empty ground → XY sketch.
	if hit.is_empty() and ground_point(screen_pos) != null:
		_picking_sketch_host = false
		sketch_host_picked.emit("ground", "", "", "")
		return
	status.emit("Click a face, yellow sketch pad, or empty ground")


func _commit_pick_active_plane(screen_pos: Vector2) -> void:
	var ray := _model_ray(screen_pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if not hit.is_empty() and str(hit.get("face", "")) != "":
		var face_id := str(hit["face"])
		var body_id := str(hit.get("body", ""))
		view.select_entity(body_id, face_id)
		_set_active_plane_from_face(face_id, body_id)
		return
	# Empty ground click → back to world XY.
	if hit.is_empty() and ground_point(screen_pos) != null:
		reset_active_plane()
		return
	status.emit("Click a flat face (or empty ground) to set the active plane")


## Set the move plane from the current face selection (axis-aligned flat faces).
func set_active_plane_from_selection() -> bool:
	if view == null or view.selected_face == "" or view.selected_body == "":
		status.emit("Select a flat face first")
		return false
	return _set_active_plane_from_face(view.selected_face, view.selected_body)


func _set_active_plane_from_face(face_id: String, body_id: String) -> bool:
	var plane: Dictionary = SketchMode.derive_face_plane(
		view.doc, face_id, body_id, view.face_normal(body_id, face_id))
	if not bool(plane.get("ok", false)):
		status.emit(str(plane.get("message", "Face is not a flat axis-aligned plane")))
		return false
	_active_plane_custom = true
	active_plane_origin = plane["origin"]
	active_plane_normal = (plane["normal"] as Vector3).normalized()
	_picking_active_plane = false
	_sync_grid_to_active_plane()
	status.emit("Active plane set — " + str(plane.get("message", "")))
	queue_redraw()
	return true


func _active_plane_n() -> Vector3:
	var n := active_plane_normal.normalized()
	return n if n.length_squared() > 1e-12 else Vector3(0, 0, 1)


## Keep the white WorldGizmos grid on the active move plane.
func _sync_grid_to_active_plane() -> void:
	if world_gizmos == null:
		return
	world_gizmos.set_active_plane(active_plane_origin, _active_plane_n())


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("sx_primitive")


func _drop_data(at: Vector2, data: Variant) -> void:
	var target := _place_target(at)
	var kind: String = str(data["sx_primitive"])
	view.insert_primitive(kind, target["point"], DocumentView.default_primitive_size(kind),
			_place_sit_normal(), _active_plane_x())
	_ignore_select_release = true
	if target.get("stacked", false):
		status.emit("Stacked " + kind + " — Alt-drag or two-finger drag to orbit")
	else:
		status.emit("Inserted " + kind + " — Alt-drag or two-finger drag to orbit")
	if target.get("need_frame", false):
		camera.frame_contents()
	_refresh_transform_hud()


## Arm click-to-place for `kind` (palette button click). Does not insert yet.
func insert_at_center(kind: String) -> void:
	_arm_place(kind)


func _screen_center() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size * 0.5
	return get_viewport().get_visible_rect().size * 0.5


## Offset from floor point to centered ghost along the place sit normal.
func _ghost_sit_offset(kind: String) -> Vector3:
	return _place_sit_normal() * _place_half_height(kind)


## Basis mapping model Z-up local (+X,+Y,+Z) onto the active place frame.
func _place_basis() -> Basis:
	var n := _place_sit_normal()
	var x := _active_plane_x()
	x = (x - n * x.dot(n)).normalized()
	if x.length_squared() < 1e-12:
		x = Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3(0, 0, -1)
		x = (x - n * x.dot(n)).normalized()
	var y := n.cross(x).normalized()
	return Basis(x, y, n)


## Mesh-local basis so Godot primitives (cylinder Y-up) become model Z-up.
func _ghost_mesh_basis(kind: String) -> Basis:
	if kind == "cylinder" or kind == "cone":
		# Rx(90°): mesh +Y (height) → model +Z.
		return Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
	return Basis.IDENTITY


## Resolve place floor: body hit → sit there; else ray ∩ active plane.
func _place_target(screen_pos: Vector2) -> Dictionary:
	var ray := _model_ray(screen_pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if not hit.is_empty() and hit.has("point"):
		var pt: Vector3 = hit["point"]
		# Ground-plane stacking: soft-snap to the hit body's top face.
		if not _active_plane_custom:
			var body: String = str(hit.get("body", ""))
			if body != "":
				var bb: Dictionary = view.doc.measure_bbox(body)
				if not bb.is_empty():
					var mx: Vector3 = bb["max"]
					if pt.z >= float(mx.z) - 2.0:
						pt = Vector3(pt.x, pt.y, float(mx.z))
		pt = _snap_on_active_plane(pt)
		return {"point": pt, "stacked": true, "need_frame": false}
	var gp = _plane_point(screen_pos, active_plane_origin, _active_plane_n())
	if gp == null:
		return {"point": active_plane_origin, "stacked": false, "need_frame": true}
	return {"point": _snap_on_active_plane(gp), "stacked": false, "need_frame": false}


func _arm_place(kind: String) -> void:
	_free_ghost()
	view.clear_selection()
	view.clear_hover()
	_place_kind = kind
	place_size = DocumentView.default_primitive_size(kind)
	grab_focus()
	_show_snap_bar()
	var plane_hint := "active plane" if _active_plane_custom else "ground"
	status.emit("Click %s or a face to place %s (Esc to cancel)" % [plane_hint, kind])
	_place_ghost = _make_ghost(kind)
	model_space.add_child(_place_ghost)
	_update_ghost(_screen_center())
	_refresh_transform_hud()
	place_changed.emit(true)


func _make_ghost(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = GHOST_NAME
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_ghost_mesh(mi, kind, place_size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45, 0.7, 1.0, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


func _apply_ghost_mesh(mi: MeshInstance3D, kind: String, s: Vector3) -> void:
	# Mesh stays unrotated; `_ghost_world_xform` applies mesh→Z-up→active plane.
	mi.transform = Transform3D.IDENTITY
	var mesh: Mesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = Vector3(s.x, s.y, s.z)
			mesh = bm
		"cylinder", "cone":
			var cm := CylinderMesh.new()
			cm.top_radius = s.y * 0.5 if kind == "cone" else s.x * 0.5
			cm.bottom_radius = s.x * 0.5
			cm.height = s.z
			mesh = cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = s.x * 0.5
			sm.height = s.x
			mesh = sm
		"torus":
			var tm := SphereMesh.new()
			tm.radius = s.y * 0.5
			tm.height = s.y
			mesh = tm
		_:
			var fallback := BoxMesh.new()
			fallback.size = s
			mesh = fallback
	mi.mesh = mesh


func _ghost_world_xform(kind: String, floor_pt: Vector3) -> Transform3D:
	var basis := _place_basis() * _ghost_mesh_basis(kind)
	return Transform3D(basis, floor_pt + _ghost_sit_offset(kind))


func _update_ghost(screen_pos: Vector2) -> void:
	if _place_ghost == null:
		return
	var target := _place_target(screen_pos)
	var floor_pt: Vector3 = target["point"]
	_place_ghost.visible = true
	_place_ghost.transform = _ghost_world_xform(_place_kind, floor_pt)
	# Don't clobber typed values while a HUD SpinBox has focus.
	if transform_hud != null and not _hud_editing():
		transform_hud.show_dims(floor_pt, place_size, true)
	_update_transport_measure(screen_pos)


## Eight corners of an AABB in model space.
func _aabb_corners(mn: Vector3, mx: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [mn.x, mx.x]:
		for y in [mn.y, mx.y]:
			for z in [mn.z, mx.z]:
				out.append(Vector3(x, y, z))
	return out


## Eight corners of the place ghost AABB in model space (active-plane frame).
func _ghost_corners() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _place_ghost == null:
		return out
	var center: Vector3 = _place_ghost.position
	var half := place_size * 0.5
	var B := _place_basis()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out.append(center + B * Vector3(sx * half.x, sy * half.y, sz * half.z))
	return out


## Subject being placed or moved — corners used as the measure B end.
func _transport_subject_corners() -> Array[Vector3]:
	if _place_kind != "" and _place_ghost != null:
		return _ghost_corners()
	if _drag_mode == DragMode.MOVE_BODY and not _move_start_bb.is_empty():
		var mn: Vector3 = _move_start_bb["min"] + _drag_accum
		var mx: Vector3 = _move_start_bb["max"] + _drag_accum
		return _aabb_corners(mn, mx)
	# Idle selection (about to move): current bbox corners.
	if view != null and view.selected_body != "" and view.selection_size() >= 1 \
			and _drag_mode == DragMode.NONE and _place_kind == "":
		var bb := view.selection_bbox()
		if not bb.is_empty():
			return _aabb_corners(bb["min"], bb["max"])
	return []


## Bodies the measure X must not plant on (the thing being moved / selected).
func _transport_skip_bodies() -> Dictionary:
	var skip := {}
	if view == null:
		return skip
	if _drag_mode == DragMode.MOVE_BODY and view.selected_body != "":
		skip[view.selected_body] = true
	elif _place_kind == "" and view.selected_body != "":
		for b in view.selected_bodies:
			skip[str(b)] = true
		if view.selected_body != "":
			skip[view.selected_body] = true
	return skip


## Pick a solid under the cursor, skipping `skip` body ids (and hidden).
func _pick_measure_target(screen_pos: Vector2, skip: Dictionary) -> Dictionary:
	if view == null:
		return {}
	var ray := _model_ray(screen_pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	if d.length_squared() < 1e-12:
		return {}
	d = d.normalized()
	for _i in range(32):
		var hit: Dictionary = view.doc.pick(o, d)
		if hit.is_empty():
			return {}
		var body := str(hit.get("body", ""))
		if body != "" and not skip.has(body) and not view.hidden_bodies.has(body):
			return hit
		var pt: Vector3 = hit.get("point", o)
		o = pt + d * 0.05
	return {}


func _closest_corner_of(corners: Array[Vector3], from: Vector3) -> Variant:
	var best: Variant = null
	var best_d := INF
	for c in corners:
		var d := from.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best


## True when `hit` is within MEASURE_RELOCATE_PX of `snap` on screen — the
## measure X relocates; otherwise dim the perpendicular foot.
func _near_measure_snap(hit: Vector3, snap: Vector3) -> bool:
	return _screen_delta_px(hit, snap) <= MEASURE_RELOCATE_PX


## Place / move / selected-body transport measure: approach another solid to
## dim the perpendicular foot from X (appears first); only when the cursor is
## within MEASURE_RELOCATE_PX of a snap (corner / mid / surface mid) does the
## X relocate onto that body.
func _update_transport_measure(screen_pos: Vector2 = Vector2.INF) -> void:
	if measure_overlay == null or view == null:
		return
	var pos := screen_pos
	if not pos.is_finite():
		pos = get_local_mouse_position()
	var skip := _transport_skip_bodies()
	var hit := _pick_measure_target(pos, skip)
	if not hit.is_empty():
		var body := str(hit.get("body", ""))
		var hit_pt: Vector3 = hit.get("point", Vector3.ZERO)
		var snap := view.closest_measure_snap(body, hit_pt)
		var near_snap := _near_measure_snap(hit_pt, snap)
		if near_snap or not measure_overlay.has_anchor():
			measure_overlay.relocate_anchor(body, snap)
			view.set_hover(body, str(hit.get("face", "")), str(hit.get("edge", "")))
			if _place_kind != "":
				status.emit("Measure X on target — move ghost to compare · click places")
			elif _drag_mode == DragMode.MOVE_BODY:
				status.emit("Measure X on target — drag to compare · release commits move")
			else:
				status.emit("Measure X on target — drag body to compare")
			return
		# X stays; dim to the perpendicular foot on the near body (earlier cue).
		view.set_hover(body, str(hit.get("face", "")), str(hit.get("edge", "")))
		var foot := view.closest_surface_point(
				body, measure_overlay.anchor_point as Vector3)
		measure_overlay.set_live_target(foot)
		status.emit("Measure — perpendicular to near body · approach snap to move X")
		return
	view.clear_hover()
	if not measure_overlay.has_anchor():
		return
	var corners := _transport_subject_corners()
	if corners.is_empty():
		measure_overlay.clear_live_target()
		return
	# Live place/move ghost: dim to nearest subject corner (kernel shape lags).
	# Idle selection: prefer the true perpendicular foot onto the subject.
	var live_pose := _place_kind != "" or _drag_mode == DragMode.MOVE_BODY
	if not live_pose:
		var subj := _transport_subject_body()
		if subj != "":
			var foot2 := view.closest_surface_point(
					subj, measure_overlay.anchor_point as Vector3)
			measure_overlay.set_live_target(foot2)
			return
	var corner = _closest_corner_of(corners, measure_overlay.anchor_point as Vector3)
	if corner == null:
		measure_overlay.clear_live_target()
		return
	measure_overlay.set_live_target(corner as Vector3)


## Body id for the place ghost / move / selection subject, or "".
func _transport_subject_body() -> String:
	if _place_kind != "":
		return ""
	if view == null:
		return ""
	return view.selected_body


## @deprecated name kept for call sites — forwards to transport measure.
func _update_place_measure(screen_pos: Vector2 = Vector2.INF) -> void:
	_update_transport_measure(screen_pos)


func _closest_ghost_corner(from: Vector3) -> Variant:
	return _closest_corner_of(_ghost_corners(), from)


func _hud_editing() -> bool:
	if transform_hud == null:
		return false
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and transform_hud.is_ancestor_of(focused)


func _free_ghost() -> void:
	if _place_ghost != null and is_instance_valid(_place_ghost):
		_place_ghost.queue_free()
	_place_ghost = null


func _disarm_place(emit_cancel: bool) -> void:
	_free_ghost()
	_place_kind = ""
	if measure_overlay != null:
		measure_overlay.clear_live_target()
	if emit_cancel:
		status.emit("Placement cancelled")
	_refresh_transform_hud()
	place_changed.emit(false)


func _commit_place(screen_pos: Vector2) -> void:
	var kind := _place_kind
	var target := _place_target(screen_pos)
	_free_ghost()
	_place_kind = ""
	if measure_overlay != null:
		measure_overlay.clear_live_target()
	_ignore_select_release = true
	view.insert_primitive(kind, target["point"], place_size,
			_place_sit_normal(), _active_plane_x())
	if target.get("stacked", false):
		status.emit("Stacked %s on face — drag empty space or Alt-drag to orbit" % kind)
	else:
		status.emit("Inserted %s — drag empty space or Alt-drag to orbit" % kind)
	if target.get("need_frame", false):
		camera.frame_contents()
	_refresh_transform_hud()
	place_changed.emit(false)


func _place_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_ghost((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			# Swallow the release that paired with a place-commit press.
			if _ignore_select_release and mb.button_index == MOUSE_BUTTON_LEFT:
				_ignore_select_release = false
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_commit_place(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_disarm_place(true)
			accept_event()


func _gui_input(event: InputEvent) -> void:
	# Prefer `_input` for model pointers (works when this Control is not the
	# hovered target). Keep `_gui_input` as a fallback for headless tests and
	# for sketch which historically used Control-local events.
	var allow_scroll := not OrbitCamera.pointer_over_scrollable_ui()
	if camera != null and camera.is_nav_event(event, allow_scroll):
		if camera.handle_input(event, allow_scroll):
			accept_event()
		return
	# Place is owned entirely by `_input` — do not swallow `_gui_input` here.
	if _place_kind != "" or _picking_active_plane:
		return
	if sketch_mode != null and sketch_mode.active:
		_sketch_input(event)
		return
	if _handle_model_pointer(event):
		accept_event()


## True when a LineEdit / TextEdit / SpinBox editor has focus — sketch hotkeys
## must not steal keystrokes from extrude distance / dimension fields.
func _sketch_keys_blocked() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var focus: Control = vp.gui_get_focus_owner()
	if focus == null:
		return false
	if focus is LineEdit or focus is TextEdit:
		return true
	# SpinBox focuses its internal LineEdit; also treat the SpinBox itself.
	var p: Node = focus
	while p != null:
		if p is SpinBox:
			return true
		p = p.get_parent()
	return false


## True when model LMB/motion should run from `_input`, not blocked by chrome/docks.
func _viewport_owns_pointer(event_pos: Vector2 = Vector2.INF) -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var h: Control = vp.gui_get_hovered_control()
	if h == null:
		# Nothing under the cursor (or Interaction size not hit-tested) → allow
		# viewport gestures from `_input`.
		return true
	if h == self:
		return true
	# TransformHud / SelectionStrip / PlaceSnapBar are our children with STOP.
	# Stale hover or oversized rects must not swallow empty-space clicks — only
	# block when the event is actually over chrome (`_over_chrome`).
	if is_ancestor_of(h):
		if event_pos == Vector2.INF:
			return true
		return not _over_chrome(event_pos)
	# Sibling docks / palette buttons / menus own their GUI clicks. Stealing
	# them via `_input` + set_input_as_handled breaks "click Box to place".
	# Camera nav is handled earlier in `_input` and still works over docks.
	return false


## Shared LMB / motion path for select, empty-orbit, and handle drags.
## Returns true when the event was consumed.
func _handle_model_pointer(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# RMB click = context menu; RMB drag = orbit (FreeCAD / peer-friendly).
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_pressed = true
				_rmb_press_pos = mb.position
				_rmb_orbiting = false
				_last_drag_pos = mb.position
			else:
				if _rmb_pressed and not _rmb_orbiting:
					_open_context_menu(_rmb_press_pos)
				_rmb_pressed = false
				_rmb_orbiting = false
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_box_drag = mb.ctrl_pressed
				_additive_click = mb.shift_pressed or mb.ctrl_pressed
				_on_press(mb.position)
			else:
				# After place/drop, suppress the select-on-release click — but still
				# finish a real drag (empty-orbit, move, box select, push/pull).
				if _ignore_select_release and _drag_mode == DragMode.NONE:
					_ignore_select_release = false
					_pressed = false
					return true
				_ignore_select_release = false
				_on_release(mb.position)
			return true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rmb_pressed:
			if not _rmb_orbiting and mm.position.distance_to(_rmb_press_pos) >= CLICK_SLOP:
				_rmb_orbiting = true
				_last_drag_pos = _rmb_press_pos
				status.emit("Orbit (right-drag) — release without drag for context menu")
			if _rmb_orbiting and camera != null:
				var rel := mm.position - _last_drag_pos
				_last_drag_pos = mm.position
				if Input.is_key_pressed(KEY_SHIFT):
					camera._pan_by(rel.x, rel.y)
				else:
					camera._orbit_by(rel.x, rel.y)
			return true
		if _pressed:
			_on_drag(mm.position)
			return true
		_update_hover(mm.position)
		return false
	return false


func _over_chrome(global_mouse: Vector2) -> bool:
	# Ignore absurd chrome rects (headless / layout-before-size can make
	# CENTER_BOTTOM HUD cover most of a tiny viewport and freeze place/select).
	var vp := get_viewport()
	var vp_area := 1.0
	if vp != null:
		var s := vp.get_visible_rect().size
		vp_area = maxf(s.x * s.y, 1.0)
	var max_area := vp_area * 0.25
	for ctrl in [_place_snap_panel, transform_hud, _selection_strip]:
		if ctrl == null or not ctrl.visible:
			continue
		if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var r: Rect2 = ctrl.get_global_rect()
		if r.get_area() < 4.0 or r.get_area() > max_area:
			continue
		if r.has_point(global_mouse):
			return true
	return false


func _update_hover(screen_pos: Vector2) -> void:
	if view == null or _place_kind != "" or (_drag_mode != DragMode.NONE):
		return
	if sketch_mode != null and sketch_mode.active:
		return
	if OrbitCamera.pointer_over_scrollable_ui():
		view.clear_hover()
		_last_hover_key = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_measure_hover_miss()
		_update_connector_hover("")
		return
	# Selected body (about to move): same marks as place — touch others to
	# plant X; otherwise dim to the selection's nearest corner.
	if view.selected_body != "" and view.selection_size() >= 1:
		_update_transport_measure(screen_pos)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
				if view.hovered_body != "" else Control.CURSOR_ARROW
		return
	var ray := _model_ray(screen_pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if hit.is_empty():
		view.clear_hover()
		_measure_hover_miss()
		_update_connector_hover("")
		if _last_hover_key != "":
			_last_hover_key = ""
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	var body := str(hit.get("body", ""))
	var face := str(hit.get("face", ""))
	var edge := str(hit.get("edge", ""))
	var hit_pt: Vector3 = hit.get("point", Vector3.ZERO)
	view.set_hover(body, face, edge)
	_update_measure_hover(body, hit_pt)
	_update_connector_hover(face)
	var key := "%s|%s|%s|%.3f,%.3f,%.3f" % [body, face, edge, hit_pt.x, hit_pt.y, hit_pt.z]
	if key == _last_hover_key:
		return
	_last_hover_key = key
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if measure_overlay != null and measure_overlay.has_anchor() and not measure_overlay.following:
		status.emit("Measure — Δ to perpendicular on near body · approach snap to move X · Esc clears")
	elif edge != "":
		status.emit("Edge — click to select · Ctrl/Shift+click adds")
	elif face != "":
		status.emit("Face — click selects body first, click again for face · then Pull arrow")
	else:
		status.emit("Body — click to select · drag empty space / Alt / two-finger to orbit")


## Face of the dragged part that will seat on the drop target: the connector
## face nearest where the user grabbed it.
func _grabbed_connector_face(instance_id: String, grab_point: Vector3) -> String:
	if view == null:
		return ""
	var source := ""
	for inst in view.doc.instance_list():
		if str(inst.get("id", "")) == instance_id:
			source = str(inst.get("source_body", ""))
	if source == "":
		return ""
	var best := ""
	var best_d := 1e30
	for f in view.doc.get_face_ids(source):
		var c: Dictionary = view.doc.implicit_connector(instance_id, f)
		if c.is_empty():
			continue
		var d: float = (c.get("origin", Vector3.ZERO) as Vector3).distance_to(grab_point)
		if d < best_d:
			best_d = d
			best = f
	return best


## Light the connector under the cursor while dragging a part over it.
func _update_snap_target(pos: Vector2) -> void:
	_snap_target_face = ""
	if view == null or _snap_source_face == "":
		_update_connector_hover("")
		return
	var ray := _model_ray(pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	var face := str(hit.get("face", ""))
	if face == "" or face == _snap_source_face:
		_update_connector_hover("")
		return
	if view.doc.implicit_connector("", face).is_empty():
		_update_connector_hover("")
		return
	_snap_target_face = face
	_update_connector_hover(face)


## Release over a connector: fasten the dragged part to it, the way dropping a
## bolt into a hole should behave. Returns false when there was no target.
func _snap_on_drop() -> bool:
	if _snap_target_face == "" or _snap_source_face == "" or _drag_instance_id == "":
		return false
	var mid: String = view.doc.add_mate("fastened", "", _snap_target_face, _drag_instance_id,
			_snap_source_face, 0.0, false, "Snap")
	_snap_target_face = ""
	_update_connector_hover("")
	if mid == "":
		return false
	var solved: bool = view.doc.solve_mates()
	view.refresh()
	status.emit("Snapped — fastened to the connector" if solved
			else "Snapped — solve FAILED")
	return true


## The joint driving `instance_id`, or {} when the part is free.
func _joint_for_instance(instance_id: String) -> Dictionary:
	if view == null or instance_id == "":
		return {}
	for j in view.doc.joint_list():
		if str(j.get("instance_b", "")) == instance_id:
			return j
	return {}


## Convert an instance drag into the joint's one free value: mm along the axis
## for sliders, degrees about it for revolutes. Returns false when the part has
## no joint, so the caller falls back to a free move.
func _drive_joint_from_drag(pos: Vector2) -> bool:
	var joint := _joint_for_instance(_drag_instance_id)
	if joint.is_empty():
		return false
	var frame: Dictionary = view.doc.implicit_connector("", str(joint.get("face_a", "")))
	if frame.is_empty():
		return false
	var origin: Vector3 = frame.get("origin", Vector3.ZERO)
	var axis: Vector3 = (frame.get("z_dir", Vector3.UP) as Vector3).normalized()
	# Measure the gesture against the axis as drawn on screen, so a vertical
	# slider reads a vertical drag and a hinge reads a sweep around its pin.
	var pivot := _model_to_screen(origin)
	var axis_screen := _model_to_screen(origin + axis) - pivot
	var unit := str(joint.get("unit", "mm"))
	var value := float(joint.get("value", 0.0))
	if unit == "mm":
		if axis_screen.length() < 0.5:
			return false  # axis points at the camera: nothing to drag along
		var mm_per_px := 1.0 / axis_screen.length()
		value += (pos - _press_pos).dot(axis_screen.normalized()) * mm_per_px
	else:
		var from := _press_pos - pivot
		var to := pos - pivot
		if from.length() < 4.0 or to.length() < 4.0:
			return false  # too close to the pin to read an angle
		var swept := from.angle_to(to)
		# Screen Y grows downward, and a receding axis sweeps the other way.
		if axis.dot(-camera.global_transform.basis.z) > 0.0:
			swept = -swept
		value += swept
	if not view.doc.set_joint_value(str(joint.get("id", "")), value):
		return false
	view.refresh()
	var shown := rad_to_deg(value) if unit == "deg" else value
	status.emit("%s %.1f %s" % [str(joint.get("name", "Joint")), shown, unit])
	return true


## Onshape-style: the mate frame appears on the face under the cursor, so mates
## and joints are picked from geometry rather than from a list of frames.
func _update_connector_hover(face_id: String, instance_id := "") -> void:
	if connector_overlay == null:
		return
	if face_id == "":
		connector_overlay.clear_hover()
		return
	connector_overlay.set_hover(instance_id, face_id)


func _update_measure_hover(body: String, hit_point: Vector3) -> void:
	if measure_overlay == null or view == null:
		return
	if body == "":
		measure_overlay.update_hover("", Vector3.ZERO)
		return
	# First body / still on A: X follows corner / edge mid / surface mid.
	if measure_overlay.anchor_body == "" or body == measure_overlay.anchor_body \
			or not measure_overlay.has_anchor():
		measure_overlay.update_hover(body, view.closest_measure_snap(body, hit_point))
		return
	# Approaching B: perpendicular foot from X appears first; only when the
	# cursor is within relocate tolerance of a snap does the X move onto B.
	var snap := view.closest_measure_snap(body, hit_point)
	if _near_measure_snap(hit_point, snap):
		measure_overlay.relocate_anchor(body, snap)
		return
	var foot := view.closest_surface_point(
			body, measure_overlay.anchor_point as Vector3)
	measure_overlay.update_hover(body, foot)


func _measure_hover_miss() -> void:
	if measure_overlay == null:
		return
	# With a selection, miss still dims to the selection corners (place-like).
	if view != null and view.selected_body != "" and view.selection_size() >= 1 \
			and _drag_mode == DragMode.NONE and _place_kind == "":
		_update_transport_measure(Vector2.INF)
		return
	measure_overlay.update_hover("", Vector3.ZERO)


## Collect pierce points where body edges meet the active sketch plane.
func refresh_sketch_intersections() -> void:
	if sketch_mode == null or not sketch_mode.active or view == null:
		return
	var pts: Array[Vector2] = []
	var origin := sketch_mode.plane_origin
	var n := sketch_mode.plane_normal()
	var px := sketch_mode.plane_x
	var py := sketch_mode.plane_y
	const TOL := 0.15
	for body_id in view.doc.body_ids():
		var edges: Dictionary = view.doc.get_edge_lines(body_id)
		for edge_id in edges:
			var poly: PackedVector3Array = edges[edge_id]
			for i in range(poly.size() - 1):
				var a: Vector3 = poly[i]
				var b: Vector3 = poly[i + 1]
				var da := (a - origin).dot(n)
				var db := (b - origin).dot(n)
				if absf(da) <= TOL:
					var la := a - origin
					pts.append(Vector2(la.dot(px), la.dot(py)))
				if absf(db) <= TOL:
					var lb := b - origin
					pts.append(Vector2(lb.dot(px), lb.dot(py)))
				if da * db < 0.0 and absf(da - db) > 1e-9:
					var t := da / (da - db)
					var hit: Vector3 = a.lerp(b, t)
					var lh := hit - origin
					pts.append(Vector2(lh.dot(px), lh.dot(py)))
	sketch_mode.intersection_points = pts


func _sketch_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var ray := _model_ray(mb.position)
			var p2 = sketch_mode.ray_to_sketch(ray[0], ray[1])
			if p2 != null:
				if sketch_mode.tool == SketchMode.Tool.TRIM:
					sketch_mode.begin_trim_drag(p2)
					_sketch_dragging = true
				elif sketch_mode.tool == SketchMode.Tool.SELECT \
						and sketch_mode.constraint_hit(p2) == "" \
						and sketch_mode.dimension_hit(p2) < 0 \
						and not sketch_mode.drag_hit(p2).is_empty():
					sketch_mode.begin_drag(p2)
					_sketch_dragging = true
				else:
					sketch_mode.click(p2)
			accept_event()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _sketch_dragging:
			var ray_up := _model_ray(mb.position)
			var p2_up = sketch_mode.ray_to_sketch(ray_up[0], ray_up[1])
			if sketch_mode.tool == SketchMode.Tool.TRIM:
				sketch_mode.end_trim_drag()
			elif not _sketch_drag_moved and p2_up != null:
				sketch_mode.end_drag()
				sketch_mode.click(p2_up)
			else:
				sketch_mode.end_drag()
			_sketch_dragging = false
			_sketch_drag_moved = false
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			sketch_mode.end_chain()
			accept_event()
	elif event is InputEventMouseMotion:
		var ray := _model_ray(event.position)
		var p2 = sketch_mode.ray_to_sketch(ray[0], ray[1])
		if p2 != null:
			if _sketch_dragging:
				_sketch_drag_moved = true
				if sketch_mode.tool == SketchMode.Tool.TRIM:
					sketch_mode.update_trim_drag(p2)
				else:
					sketch_mode.update_drag(p2)
			else:
				sketch_mode.hover(p2)
				_update_sketch_measure(p2)
		else:
			if measure_overlay != null:
				measure_overlay.update_sketch_hover("", Vector3.ZERO)
	elif event is InputEventKey and event.pressed and event.ctrl_pressed:
		var ke := event as InputEventKey
		match ke.keycode:
			KEY_A:
				var n := sketch_mode.select_all_entities()
				status.emit("Selected %d sketch entities" % n if n > 0 else "No sketch entities")
				accept_event()
			KEY_C:
				var nc := sketch_mode.copy_selected_entities()
				status.emit("Copied %d sketch entities" % nc if nc > 0 else "Nothing to copy")
				accept_event()
			KEY_X:
				var nx := sketch_mode.cut_selected_entities()
				status.emit("Cut %d sketch entities" % nx if nx > 0 else "Nothing to cut")
				accept_event()
			KEY_V:
				var made: Array = sketch_mode.paste_entities()
				status.emit("Pasted %d sketch entities" % made.size() if not made.is_empty() else "Clipboard empty")
				accept_event()
	elif event is InputEventKey and event.pressed and not event.ctrl_pressed:
		var ke := event as InputEventKey
		# Digits / decimal while rubber-banding → type into the distance blank.
		if sketch_mode.has_single_dof_preview() and _is_length_type_key(ke):
			var seed := _length_type_seed(ke)
			if sketch_chrome != null:
				sketch_chrome.focus_dim_for_typing(seed)
			accept_event()
			return
		match ke.keycode:
			KEY_S: sketch_mode.set_tool(SketchMode.Tool.SELECT)
			KEY_L: sketch_mode.set_tool(SketchMode.Tool.LINE)
			KEY_R: sketch_mode.set_tool(SketchMode.Tool.RECT)
			KEY_C: sketch_mode.set_tool(SketchMode.Tool.CIRCLE)
			KEY_A: sketch_mode.set_tool(SketchMode.Tool.ARC)
			KEY_T: sketch_mode.set_tool(SketchMode.Tool.TRIM)
			KEY_D: sketch_mode.set_tool(SketchMode.Tool.SMART_DIM)
			KEY_E: sketch_mode.set_tool(SketchMode.Tool.EXTEND)
			KEY_X: sketch_mode.toggle_construction_selected()
			KEY_DELETE, KEY_BACKSPACE:
				if not sketch_mode.delete_selected_constraint():
					if sketch_mode.delete_selected_entities() == 0:
						status.emit("Nothing to delete")
			KEY_ESCAPE:
				if measure_overlay != null and measure_overlay.has_anchor():
					measure_overlay.clear_pair()
					status.emit("Measure cleared")
				elif sketch_mode.has_length_override():
					sketch_mode.clear_length_override()
					status.emit("Length unlock")
				else:
					sketch_mode.cancel()
		accept_event()


func _is_length_type_key(ke: InputEventKey) -> bool:
	match ke.keycode:
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			return true
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, \
				KEY_KP_7, KEY_KP_8, KEY_KP_9:
			return true
		KEY_PERIOD, KEY_KP_PERIOD:
			return true
		_:
			return false


func _length_type_seed(ke: InputEventKey) -> String:
	match ke.keycode:
		KEY_0, KEY_KP_0: return "0"
		KEY_1, KEY_KP_1: return "1"
		KEY_2, KEY_KP_2: return "2"
		KEY_3, KEY_KP_3: return "3"
		KEY_4, KEY_KP_4: return "4"
		KEY_5, KEY_KP_5: return "5"
		KEY_6, KEY_KP_6: return "6"
		KEY_7, KEY_KP_7: return "7"
		KEY_8, KEY_KP_8: return "8"
		KEY_9, KEY_KP_9: return "9"
		KEY_PERIOD, KEY_KP_PERIOD: return "."
		_: return ""


func _update_sketch_measure(pos2: Vector2) -> void:
	if measure_overlay == null or sketch_mode == null:
		return
	var eid: String = sketch_mode._nearest_entity_at(pos2)
	if eid == "":
		# Also try pierce points as measure anchors.
		var best_d := SketchMode.PICK_TOLERANCE
		var best_pt: Variant = null
		for ip in sketch_mode.intersection_points:
			var d: float = pos2.distance_to(ip)
			if d < best_d:
				best_d = d
				best_pt = ip
		if best_pt != null:
			measure_overlay.update_sketch_hover("pierce", sketch_mode.to_model(best_pt))
		else:
			measure_overlay.update_sketch_hover("", Vector3.ZERO)
		return
	var snap2 := sketch_mode.snap_point(pos2)
	# Prefer nearest endpoint of the hovered entity for the ✕ mark.
	var mark2 := snap2
	var eps: Array = sketch_mode._snap_endpoints(eid)
	if not eps.is_empty():
		var bd := INF
		for ep in eps:
			var d2: float = pos2.distance_to(ep)
			if d2 < bd:
				bd = d2
				mark2 = ep
	measure_overlay.update_sketch_hover(eid, sketch_mode.to_model(mark2))


func _on_press(pos: Vector2) -> void:
	_pressed = true
	_press_pos = pos
	_last_drag_pos = pos
	_press_travel = 0.0
	_drag_mode = DragMode.NONE
	_box_rect = Rect2()
	_pp_preview_dist = 0.0
	_pending_body_move = false
	_pending_instance_move = false
	_move_axis_lock = -1
	grab_focus()
	view.clear_hover()

	var ray := _model_ray(pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	_press_empty = hit.is_empty()

	# Shift/Ctrl+click is additive selection only — never arms a move/push drag.
	# Ctrl+empty-drag becomes a rubber-band box select in _on_drag.
	if _additive_click:
		return

	# Component instances aren't in the kernel pick — prefer whichever is
	# closer along the ray so an instance in front of a body is grabbable.
	var ihit: Dictionary = view.pick_instance(ray[0], ray[1])
	if not ihit.is_empty() \
			and (hit.is_empty() or float(ihit["distance"]) < float(hit["distance"])):
		var iid: String = ihit["id"]
		if view.selected_instance != iid:
			view.select_instance(iid)
		# Fixed restraint (SolidWorks Fix): select but do not arm a drag.
		var inst_fixed := false
		for inst in view.doc.instance_list():
			if str(inst.get("id", "")) == iid:
				inst_fixed = bool(inst.get("fixed", false))
				break
		if not inst_fixed:
			_pending_instance_move = true
			_drag_instance_id = iid
			_instance_grab_point = ihit["point"]
			_snap_source_face = _grabbed_connector_face(iid, ihit["point"])
			_snap_target_face = ""
			var inode := view.instance_node(iid)
			_instance_start_xform = inode.transform if inode != null else Transform3D.IDENTITY
		_press_empty = false
		return

	var hit_selected := (not hit.is_empty() and view.selected_body != ""
			and str(hit.get("body", "")) == view.selected_body)

	# Body mesh itself is the move grip. Defer MOVE until past CLICK_SLOP so a
	# tiny press still drill-selects (face/edge) instead of nudging. Face drag
	# starts push/pull immediately. Stretch / rotate grips when ray misses body.
	if hit_selected:
		_drag_start_mouse = pos
		_drag_start_point = hit["point"]
		_press_empty = false
		if view.selected_face != "" and hit["face"] == view.selected_face:
			_drag_mode = DragMode.PUSH_PULL
			_drag_normal = view.selected_face_normal()
			_drag_pp_applied = 0.0
			queue_redraw()
		else:
			_pending_body_move = true
			_pending_move_point = hit["point"]
			queue_redraw()
		return

	var rotate_handle := _pick_rotate_grip(pos)
	if not rotate_handle.is_empty():
		_begin_rotate(rotate_handle, pos)
		_press_empty = false
		return
	var pp_handle := _pick_push_pull_handle(pos)
	if not pp_handle.is_empty():
		_drag_mode = DragMode.PUSH_PULL
		_drag_normal = pp_handle["normal"]
		_drag_pp_applied = 0.0
		_drag_start_mouse = pos
		_drag_start_point = pp_handle["point"]
		_press_empty = false
		queue_redraw()
		return
	# Leave/approach-plane lift (all bodies) — before face stretch so the
	# tip wins over the outward face arrow on primitives.
	var z_grip := _pick_z_move_grip(pos)
	if not z_grip.is_empty():
		_begin_move_body(pos, z_grip["point"])
		_move_axis_lock = AXIS_Z
		_press_empty = false
		status.emit("Move lift — drag to leave / approach the active plane")
		return
	var resize_handle := _pick_resize_handle(pos)
	if not resize_handle.is_empty():
		_begin_resize(resize_handle, pos)
		_press_empty = false
		return

	# Empty space: drag will orbit the camera (plain click clears selection).
	if _press_empty:
		return


func _begin_move_body(pos: Vector2, hit_point: Vector3) -> void:
	_drag_mode = DragMode.MOVE_BODY
	_drag_accum = Vector3.ZERO
	_move_delta_base = Vector3.ZERO
	_move_snap_active = {}
	_move_snap_hover_body = ""
	_drag_start_mouse = pos
	_drag_start_point = hit_point
	var bb := view.selection_bbox()
	_move_start_bb = _bb_with_center(bb) if not bb.is_empty() else {}
	_move_start_center = _move_start_bb["center"] if not _move_start_bb.is_empty() else hit_point
	var node := view.body_node(view.selected_body)
	_move_start_node_xform = node.transform if node != null else Transform3D.IDENTITY
	_show_snap_bar()
	if transform_hud != null:
		transform_hud.hide_precision()
		transform_hud.set_move_delta(Vector3.ZERO)
	queue_redraw()


func _begin_rotate(handle: Dictionary, pos: Vector2) -> void:
	_drag_mode = DragMode.ROTATE_BODY
	_rotate_axis = handle["axis"]
	_rotate_center = handle["center"]
	_rotate_angle = 0.0
	_rotate_start_angle = _angle_about_axis(pos, _rotate_axis, _rotate_center)
	var node := view.body_node(view.selected_body)
	_rotate_start_node_xform = node.transform if node != null else Transform3D.IDENTITY
	_drag_start_mouse = pos
	if transform_hud != null:
		transform_hud.hide_move_delta()
		transform_hud.hide_precision()
	queue_redraw()


func _begin_resize(handle: Dictionary, pos: Vector2) -> void:
	_drag_mode = DragMode.RESIZE_BODY
	_drag_start_mouse = pos
	_drag_start_point = handle["point"]
	_resize_signs = handle["signs"]
	_resize_start_min = handle["min"]
	_resize_start_max = handle["max"]
	_resize_min = _resize_start_min
	_resize_max = _resize_start_max
	_resize_distance = 0.0
	_resize_axis_hint = str(handle.get("hint", "Δ"))
	# Radial grips on cyl/cone/sphere grow Ø about the axis — not a one-sided AABB slide.
	if _coupled_resize_axes(_resize_signs).size() >= 2:
		_resize_axis_hint = "ΔØ"
	if transform_hud != null:
		transform_hud.hide_move_delta()
		transform_hud.hide_precision()
	queue_redraw()


func _on_drag(pos: Vector2) -> void:
	_press_travel = maxf(_press_travel, pos.distance_to(_press_pos))
	if pos.distance_to(_press_pos) < CLICK_SLOP:
		return
	# Deferred body move after travel threshold.
	if _pending_body_move and _drag_mode == DragMode.NONE:
		_pending_body_move = false
		_begin_move_body(_press_pos, _pending_move_point)
	if _pending_instance_move and _drag_mode == DragMode.NONE:
		_pending_instance_move = false
		_drag_mode = DragMode.MOVE_INSTANCE
	# Empty-space drag: orbit (or pan when sketch orientation is locked).
	# Ctrl+empty-drag: rubber-band box select.
	if _drag_mode == DragMode.NONE and _press_empty and _place_kind == "":
		_drag_mode = DragMode.BOX_SELECT if _box_drag else DragMode.ORBIT_VIEW
		# Orbit from the press origin so the first post-slop frame applies real delta.
		_last_drag_pos = _press_pos
	match _drag_mode:
		DragMode.ORBIT_VIEW:
			var rel := pos - _last_drag_pos
			_last_drag_pos = pos
			if camera != null and rel.length_squared() > 0.0:
				if Input.is_key_pressed(KEY_SHIFT) or camera.sketch_orientation_locked:
					camera._pan_by(rel.x, rel.y)
					if camera.sketch_orientation_locked:
						status.emit("Pan (sketch view locked) — zoom with wheel")
					else:
						status.emit("Pan — release Shift to orbit")
				else:
					camera._orbit_by(rel.x, rel.y)
					status.emit("Orbit (empty drag) — two-finger drag or Alt-drag also orbit")
		DragMode.BOX_SELECT:
			_box_rect = Rect2(_press_pos, pos - _press_pos).abs()
			queue_redraw()
		DragMode.MOVE_BODY:
			# Drag on the active plane; Z-lock (lift grip or tap Z) moves along
			# the plane normal; typed HUD can still hop off-plane otherwise.
			_last_drag_pos = pos
			var target: Vector3
			var plane_n := _active_plane_n()
			if _move_axis_lock == AXIS_Z:
				var ray := _model_ray(pos)
				var o: Vector3 = ray[0]
				var d: Vector3 = ray[1]
				var cross_dn := d.cross(plane_n)
				var denom := cross_dn.length_squared()
				if denom < 1e-12:
					return
				var dist := (o - _drag_start_point).dot(cross_dn.cross(d)) / denom
				var planar := _drag_accum - plane_n * _drag_accum.dot(plane_n)
				target = planar + plane_n * dist
			else:
				var gp = _plane_point(pos, _drag_start_point, plane_n)
				var gp0 = _plane_point(_drag_start_mouse, _drag_start_point, plane_n)
				if gp == null or gp0 == null:
					return
				target = gp - gp0
				match _move_axis_lock:
					AXIS_X: target.y = 0.0
					AXIS_Y: target.x = 0.0
				# Preserve typed / prior hop along the plane normal.
				var along := _drag_accum.dot(plane_n)
				target = target - plane_n * target.dot(plane_n) + plane_n * along
			_update_move_snap_hover(pos)
			var snap := _resolve_move_snap(target)
			if not snap.is_empty():
				target = snap["delta"]
			else:
				_move_snap_active = {}
			_apply_live_move(target)
			_update_transport_measure(pos)
			var lock_hint := ""
			match _move_axis_lock:
				AXIS_X: lock_hint = " [X locked]"
				AXIS_Y: lock_hint = " [Y locked]"
				AXIS_Z: lock_hint = " [lift locked]"
			var snap_hint := ""
			if not _move_snap_active.is_empty():
				snap_hint = " [snap %s]" % str(_move_snap_active.get("kind", ""))
			if measure_overlay == null or not measure_overlay.is_showing_pair():
				status.emit("Move Δ (%.2f, %.2f, %.2f)%s%s — tap X/Y/Z to lock axis" \
						% [target.x, target.y, target.z, lock_hint, snap_hint])
			queue_redraw()
		DragMode.ROTATE_BODY:
			var ang := _angle_about_axis(pos, _rotate_axis, _rotate_center)
			_rotate_angle = wrapf(ang - _rotate_start_angle, -PI, PI)
			_apply_live_rotate(_rotate_angle)
			status.emit("Rotate %s: %.1f°" % [_axis_label(_rotate_axis),
					rad_to_deg(_rotate_angle)])
			queue_redraw()
		DragMode.PUSH_PULL:
			var d := _push_pull_distance(pos)
			_pp_preview_dist = d
			var tip := _drag_start_point + _drag_normal * d
			_pp_badge_screen = _model_to_screen(tip)
			status.emit("Push/pull: %.1f mm (release to apply)" % d)
			queue_redraw()
		DragMode.RESIZE_BODY:
			_update_resize_drag(pos)
			queue_redraw()
		DragMode.MOVE_INSTANCE:
			# Live preview on the grabbed instance's horizontal plane.
			var plane_z := _instance_grab_point.z
			var gp = _horizontal_plane_point(pos, plane_z)
			var gp0 = _horizontal_plane_point(_press_pos, plane_z)
			if gp == null or gp0 == null:
				return
			var delta: Vector3 = gp - gp0
			var inode := view.instance_node(_drag_instance_id)
			if inode != null:
				inode.transform = Transform3D(_instance_start_xform.basis,
						_instance_start_xform.origin + delta)
			# Magnet: a connector under the cursor lights up and claims the drop.
			_update_snap_target(pos)
			if _snap_target_face != "":
				status.emit("Release to fasten onto the highlighted connector")
			else:
				status.emit("Move instance Δ (%.1f, %.1f) — release re-solves mates"
						% [delta.x, delta.y])


func _draw() -> void:
	if _drag_mode == DragMode.BOX_SELECT and _box_rect.size != Vector2.ZERO:
		draw_rect(_box_rect, Color(0.35, 0.6, 0.95, 0.18), true)
		draw_rect(_box_rect, Color(0.35, 0.6, 0.95, 0.85), false, 1.0)
	_draw_selection_gizmos()
	if _drag_mode == DragMode.PUSH_PULL and absf(_pp_preview_dist) > 1e-3:
		_draw_push_pull_preview()
	# Measure chrome last so it sits above other 2D/3D viewport chrome.
	_draw_measure_overlay()


## True while a body/face mod or camera drag is active.
func _is_modifying() -> bool:
	return _drag_mode != DragMode.NONE or _pending_body_move or _pending_instance_move


## Measure chrome stays up during place and body move (same marks); other mods hide it.
func _hide_measure_chrome() -> bool:
	if _place_kind != "":
		return false
	if _drag_mode == DragMode.MOVE_BODY or _pending_body_move:
		return false
	if _drag_mode != DragMode.NONE or _pending_instance_move:
		return true
	return false


## Screen-space measure dims: fixed size (~1/40 viewport height), always on top.
## Hidden during stretch/rotate/pull/orbit; kept during place and body move.
func _draw_measure_overlay() -> void:
	if measure_overlay == null or camera == null or model_space == null:
		return
	if _hide_measure_chrome():
		return
	var font_px := maxi(int(round(size.y * MeasureOverlay.SCREEN_FRAC)), 10)
	var mark_half := float(font_px) * 0.45
	var tick := float(font_px) * 0.28
	var line_w := maxf(font_px * 0.08, 1.25)
	var font := ThemeDB.fallback_font

	for seg in measure_overlay.segments:
		var a := _model_to_screen(seg["a"])
		var b := _model_to_screen(seg["b"])
		var col: Color = seg["color"]
		if camera.is_position_behind(model_space.to_global(seg["a"])) \
				and camera.is_position_behind(model_space.to_global(seg["b"])):
			continue
		draw_line(a, b, col, line_w, true)
		var ab := b - a
		if ab.length_squared() > 1.0:
			var n := Vector2(-ab.y, ab.x).normalized() * tick
			draw_line(a - n, a + n, col, line_w, true)
			draw_line(b - n, b + n, col, line_w, true)

	for m in measure_overlay.marks:
		var p: Vector3 = m["p"]
		if camera.is_position_behind(model_space.to_global(p)):
			continue
		var s := _model_to_screen(p)
		var col2: Color = m["color"]
		draw_line(s + Vector2(-mark_half, -mark_half), s + Vector2(mark_half, mark_half),
				col2, line_w * 1.35, true)
		draw_line(s + Vector2(-mark_half, mark_half), s + Vector2(mark_half, -mark_half),
				col2, line_w * 1.35, true)

	# Project labels, then push overlapping plates apart in screen space.
	var plates: Array = []  # {rect, text, color}
	for lab in measure_overlay.labels:
		var lp: Vector3 = lab["p"]
		if camera.is_position_behind(model_space.to_global(lp)):
			continue
		var sp := _model_to_screen(lp)
		var text: String = lab["text"]
		var col3: Color = lab["color"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		var pad := Vector2(font_px * 0.22, font_px * 0.12)
		var rect := Rect2(sp - Vector2(tw.x * 0.5, tw.y * 0.65) - pad, tw + pad * 2.0)
		# Prefer a stable order (diagonal first, then Δx/Δy/Δz) so nudges are predictable.
		var rank: int = int(lab.get("rank", 9))
		plates.append({"rect": rect, "text": text, "color": col3, "rank": rank})
	plates.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	var placed: Array[Rect2] = []
	var step := float(font_px) * 0.95
	for plate in plates:
		var rect: Rect2 = plate["rect"]
		for _i in range(16):
			var clash := false
			for other in placed:
				if rect.grow(3.0).intersects(other):
					clash = true
					break
			if not clash:
				break
			rect.position.y += step
			# Alternate sideways after a few vertical steps so stacks fan out.
			if _i == 4 or _i == 9:
				rect.position.x += step * (1.0 if (_i % 2) == 0 else -1.0)
		placed.append(rect)
		draw_rect(rect, Color(0.06, 0.07, 0.09, 0.72), true)
		draw_string(font, rect.position + Vector2(rect.size.x * 0.5 - font.get_string_size(
				plate["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x * 0.5,
				font_px * 0.78),
				plate["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, plate["color"])


func _clear_box_band() -> void:
	_box_rect = Rect2()
	if _drag_mode == DragMode.BOX_SELECT:
		_drag_mode = DragMode.NONE
	queue_redraw()


## Stored rotation of an instance as [axis: Vector3, angle_deg: float].
func _instance_rotation(instance_id: String) -> Array:
	for inst in view.doc.instance_list():
		if str(inst["id"]) == instance_id:
			return [inst["rotation_axis"], inst["rotation_angle_deg"]]
	return [Vector3(0, 0, 1), 0.0]


func _push_pull_distance(pos: Vector2) -> float:
	# Distance along the face normal: closest approach between the screen ray
	# and the line (start_point, normal).
	var ray := _model_ray(pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	var p := _drag_start_point
	var n := _drag_normal
	var cross_dn := d.cross(n)
	var denom := cross_dn.length_squared()
	if denom < 1e-12:
		return 0.0
	return (o - p).dot(cross_dn.cross(d)) / denom


func _on_release(pos: Vector2) -> void:
	_pressed = false
	_press_travel = maxf(_press_travel, pos.distance_to(_press_pos))
	# Trackpads often jitter past a few pixels during a "click". Treat small travel
	# as a click for select / deselect; real empty-orbit needs more motion.
	var was_click := _press_travel < CLICK_SLOP
	match _drag_mode:
		DragMode.ORBIT_VIEW:
			_drag_mode = DragMode.NONE
			var keep_additive := _additive_click
			_box_drag = false
			_additive_click = false
			_press_empty = false
			# Empty-space travel below ORBIT_CLICK_SLOP is still a deselect
			# click (trackpad jitter); a real tumble keeps selection like peers.
			if _press_travel < ORBIT_CLICK_SLOP and not keep_additive:
				view.clear_selection()
				status.emit("")
			_press_travel = 0.0
			return
		DragMode.BOX_SELECT:
			_box_rect = Rect2(_press_pos, pos - _press_pos).abs()
			view.select_in_rect(_box_rect, camera, model_space, _additive_click)
			if view.selection_size() > 1:
				status.emit("%d selected" % view.selection_size())
			elif view.selection_size() == 1:
				status.emit("Selected " + view.selected_body.left(8))
			else:
				status.emit("")
			_clear_box_band()
			_box_drag = false
			_additive_click = false
			_press_travel = 0.0
			return
		DragMode.MOVE_BODY:
			if not was_click and _drag_accum.length() > 1e-6:
				# Reset live preview, then commit absolute Δ from pre-drag pose.
				var node := view.body_node(view.selected_body)
				if node != null:
					node.transform = _move_start_node_xform
				if view.move_selected(_drag_accum):
					_move_delta_base = _drag_accum
					status.emit("Moved body")
					if transform_hud != null:
						transform_hud.show_move_delta(_drag_accum)
				else:
					status.emit("Move failed")
			elif view.selected_body != "":
				view.refresh()
				if transform_hud != null:
					transform_hud.hide_move_delta()
			_drag_mode = DragMode.NONE
			_move_snap_active = {}
			_move_snap_hover_body = ""
			_move_start_bb = {}
			_hide_snap_bar_unless_placing()
			_box_drag = false
			_additive_click = false
			_refresh_transform_hud()
			# Resume idle transport measure against the committed pose.
			if measure_overlay != null:
				_update_transport_measure(pos)
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.ROTATE_BODY:
			if not was_click and absf(_rotate_angle) > 1e-4:
				var node_r := view.body_node(view.selected_body)
				if node_r != null:
					node_r.transform = _rotate_start_node_xform
				if view.rotate_selected(_rotate_center, _rotate_axis, _rotate_angle):
					status.emit("Rotated %.1f° about %s" % [
							rad_to_deg(_rotate_angle), _axis_label(_rotate_axis)])
					_precision_kind = "rotate"
					_precision_rotate_axis = _rotate_axis
					_precision_rotate_center = _rotate_center
					_show_precision_after_drag(rad_to_deg(_rotate_angle),
							"Δ° %s" % _axis_label(_rotate_axis), "°")
				else:
					status.emit("Rotate failed")
			elif view.selected_body != "":
				view.refresh()
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			_refresh_transform_hud()
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.PUSH_PULL:
			if not was_click:
				var dist := _push_pull_distance(pos)
				if absf(dist) > 1e-3:
					if view.push_pull_selected(dist):
						status.emit("Push/pull %.1f mm applied" % dist)
						_show_precision_after_drag(dist, "Δ push")
					else:
						status.emit("Push/pull failed (planar faces only for now)")
			_pp_preview_dist = 0.0
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			_refresh_transform_hud()
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.RESIZE_BODY:
			if not was_click and absf(_resize_distance) > 1e-3:
				_commit_resize()
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.MOVE_INSTANCE:
			var inode := view.instance_node(_drag_instance_id)
			# Dropped on a connector: fasten there instead of leaving it loose.
			if not was_click and inode != null and _snap_on_drop():
				_drag_mode = DragMode.NONE
				_drag_instance_id = ""
				_box_drag = false
				_additive_click = false
				_press_travel = 0.0
				return
			# A jointed part has one degree of freedom; the drag drives it.
			if not was_click and inode != null and _drive_joint_from_drag(pos):
				_drag_mode = DragMode.NONE
				_drag_instance_id = ""
				_box_drag = false
				_additive_click = false
				_press_travel = 0.0
				return
			if not was_click and inode != null:
				var rot := _instance_rotation(_drag_instance_id)
				if view.doc.set_instance_transform(_drag_instance_id,
						inode.transform.origin, rot[0], rot[1]):
					# Peer feel: drop the instance, then mates pull it home.
					var had_mates: bool = view.doc.mate_list().size() > 0
					var solved: bool = view.doc.solve_mates() if had_mates else true
					view.refresh()
					if had_mates:
						status.emit("Instance moved — mates re-solved" if solved
								else "Instance moved — mate solve FAILED")
					else:
						status.emit("Instance moved")
				else:
					inode.transform = _instance_start_xform
					status.emit("Move instance failed")
			_drag_mode = DragMode.NONE
			_drag_instance_id = ""
			_box_drag = false
			_additive_click = false
			_press_travel = 0.0
			return
	# Press landed on an instance but never travelled: keep it selected.
	if _pending_instance_move:
		_pending_instance_move = false
		_drag_mode = DragMode.NONE
		_box_drag = false
		_additive_click = false
		_press_empty = false
		_press_travel = 0.0
		status.emit("Instance selected — drag to move (mates re-solve on release)")
		return
	# No drag gesture was armed (or pending move never started): resolve selection.
	_pending_body_move = false
	_drag_mode = DragMode.NONE
	# Pads sit on faces — prefer a pad hit even when the body ray is non-empty,
	# otherwise face-hosted pads are unclickable under the solid.
	if was_click and view.sketch_pads != null and (sketch_mode == null or not sketch_mode.active):
		var pad_ray := _model_ray(_press_pos)
		var pad_fid: String = view.sketch_pads.pick_pad(pad_ray[0], pad_ray[1])
		if pad_fid != "":
			sketch_pad_clicked.emit(pad_fid, _additive_click)
			_box_drag = false
			_additive_click = false
			_press_empty = false
			_press_travel = 0.0
			return
	if _press_empty:
		if not _additive_click:
			view.clear_selection()
			status.emit("")
			_box_drag = false
			_additive_click = false
			_press_empty = false
			_press_travel = 0.0
			return
	# Prefer the press ray so a tiny slide off the body still selects it.
	var ray := _model_ray(_press_pos)
	if view.select_ray(ray[0], ray[1], _additive_click):
		if view.selection_size() > 1:
			status.emit("%d selected" % view.selection_size())
		else:
			status.emit("Selected " + (view.selected_face if view.selected_face != "" else view.selected_body).left(8))
	elif not _additive_click:
		status.emit("")
	_box_drag = false
	_additive_click = false
	_press_empty = false
	_press_travel = 0.0


func _gui_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	match event.keycode:
		KEY_ESCAPE:
			# Sketch Esc is handled in _sketch_input; do not steal it.
			if sketch_mode != null and sketch_mode.active:
				return false
			# Dismiss overlapping panels/popups first to avoid undismissable stacks.
			if transform_hud != null and transform_hud.visible:
				transform_hud.dismiss()
				return true
			if _orient_popup != null and _orient_popup.visible:
				_orient_popup.hide()
				return true
			if _drag_mode == DragMode.BOX_SELECT or (_pressed and _press_empty and _box_rect.size != Vector2.ZERO):
				_pressed = false
				_clear_box_band()
				_box_drag = false
				_additive_click = false
				_press_empty = false
				status.emit("")
				return true
			if _place_kind != "":
				_disarm_place(true)
				return true
			if _picking_active_plane:
				cancel_pick_active_plane()
				return true
			if measure_overlay != null and measure_overlay.has_anchor():
				measure_overlay.clear_pair()
				status.emit("")
				return true
			view.clear_selection()
			status.emit("")
			return true
		KEY_DELETE, KEY_BACKSPACE:
			return _delete_selection()
		KEY_C:
			if event.ctrl_pressed:
				var n := view.copy_selection()
				if n > 0:
					status.emit("Copied %d" % n if n > 1 else "Copied")
				else:
					status.emit("Nothing to copy")
				return true
		KEY_X:
			if event.ctrl_pressed:
				var n := view.cut_selection()
				if n > 0:
					status.emit("Cut %d" % n if n > 1 else "Cut")
				else:
					status.emit("Nothing to cut")
				_refresh_transform_hud()
				_refresh_selection_strip()
				return true
		KEY_A:
			if event.ctrl_pressed:
				return _select_all()
		KEY_V:
			if event.ctrl_pressed:
				if event.shift_pressed:
					paste_special_requested.emit()
					return true
				var made: Array = view.paste_clipboard()
				if made.is_empty():
					status.emit("Clipboard empty")
				else:
					status.emit("Pasted %d" % made.size() if made.size() > 1 else "Pasted")
				_refresh_transform_hud()
				_refresh_selection_strip()
				return true
		KEY_Z:
			if event.ctrl_pressed:
				if event.shift_pressed:
					view.redo()
				else:
					view.undo()
				status.emit("Undo/redo")
				return true
		KEY_Y:
			if event.ctrl_pressed:
				view.redo()
				status.emit("Redo")
				return true
		KEY_W:
			if not event.ctrl_pressed:
				var mode: int = view.cycle_display_mode()
				status.emit("Display: " + ["Shaded", "Shaded + Edges", "Wireframe"][mode])
				return true
		KEY_K:
			if not event.ctrl_pressed:
				toggle_section()
				return true
		KEY_G:
			if not event.ctrl_pressed and world_gizmos != null:
				world_gizmos.set_gizmos_visible(not world_gizmos.gizmos_visible)
				status.emit("Gizmos " + ("on" if world_gizmos.gizmos_visible else "off"))
				return true
		KEY_H:
			if not event.ctrl_pressed:
				if event.shift_pressed:
					view.unhide_all()
					status.emit("All shown")
				else:
					var ids := _selected_body_ids()
					for id in ids:
						view.set_body_hidden(id, true)
					status.emit("%d hidden" % ids.size())
				return true
		KEY_I:
			if not event.ctrl_pressed:
				var ids := _selected_body_ids()
				view.isolate(ids)
				status.emit("All shown" if ids.is_empty() else "Isolated")
				return true
		KEY_S:
			if not event.ctrl_pressed and _place_kind == "" \
					and (sketch_mode == null or not sketch_mode.active):
				_open_marking_menu(get_global_mouse_position())
				return true
		KEY_SPACE:
			# SolidWorks Spacebar / Onshape S-lite: orientation + named views.
			if not event.ctrl_pressed and _place_kind == "" \
					and (sketch_mode == null or not sketch_mode.active):
				_show_orient_popup()
				return true
	return false


## Unique body ids from the current selection (bodies / face+edge owners).
func _selected_body_ids() -> Array:
	var ids: Array = []
	for b in view.selected_bodies:
		if not ids.has(b):
			ids.append(b)
	if view.selected_body != "" and not ids.has(view.selected_body):
		ids.append(view.selected_body)
	return ids


## Ctrl+A: select all faces on the primary body (one big surface selection),
## or every body when nothing is selected. Import meshes stay one body selection
## (scale stays available) — that *is* "select all" for an STL drop.
func _select_all() -> bool:
	if sketch_mode != null and sketch_mode.active:
		var n := sketch_mode.select_all_entities()
		status.emit("Selected %d sketch entities" % n if n > 0 else "No sketch entities")
		return true
	if view.selected_body != "":
		if view.is_import_body(view.selected_body):
			view.select_entity(view.selected_body, "")
			status.emit("Selected imported body")
			_refresh_transform_hud()
			_refresh_selection_strip()
			return true
		var n := view.select_all_faces(view.selected_body)
		if n > 0:
			status.emit("Selected all %d faces" % n)
			_refresh_transform_hud()
			_refresh_selection_strip()
			return true
		view.select_entity(view.selected_body, "")
		status.emit("Selected body")
		_refresh_transform_hud()
		return true
	var n2 := view.select_all_bodies()
	status.emit("Selected %d bodies" % n2 if n2 > 0 else "Nothing to select")
	_refresh_transform_hud()
	_refresh_selection_strip()
	return true


func _on_view_selection_changed(_body: String, _face: String) -> void:
	_refresh_transform_hud()
	_refresh_selection_strip()
	if measure_overlay != null:
		measure_overlay.refresh_bounds()
	queue_redraw()


func _on_view_document_changed() -> void:
	_refresh_transform_hud()
	_refresh_selection_strip()
	if measure_overlay != null:
		measure_overlay.clear_all()
		measure_overlay.refresh_bounds()
	queue_redraw()


func _apply_live_move(delta: Vector3) -> void:
	_drag_accum = delta
	var node := view.body_node(view.selected_body)
	if node != null:
		node.transform = _move_start_node_xform.translated(delta)
	if transform_hud != null:
		transform_hud.set_move_delta(delta)


func _apply_live_rotate(angle: float) -> void:
	var node := view.body_node(view.selected_body)
	if node == null:
		return
	var R := Basis(_rotate_axis.normalized(), angle)
	var c := _rotate_center
	var origin0: Vector3 = _rotate_start_node_xform.origin
	var basis0: Basis = _rotate_start_node_xform.basis
	node.transform = Transform3D(R * basis0, c + R * (origin0 - c))


func _refresh_transform_hud() -> void:
	if transform_hud == null:
		return
	if _place_kind != "":
		var center := _screen_center()
		var target := _place_target(center)
		# Place keeps absolute X/Y/Z + W×H×D blanks for typed fine-tune.
		transform_hud.show_dims(target["point"], place_size, true)
		return
	# Idle selection: clear the bottom band. Move/stretch blanks stay up on their own.
	# Import bodies keep W×H×D visible so scale is one typed edit away after drop.
	if view.selected_body == "" or view.selection_size() != 1:
		transform_hud.hide_dims()
		transform_hud.hide_precision()
		transform_hud.hide_move_delta()
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		transform_hud.hide_dims()
		return
	if view.is_import_body(view.selected_body):
		transform_hud.show_dims(bb["center"], bb["size"], true)
		return
	transform_hud.hide_dims()
	transform_hud.set_values(bb["center"], bb["size"], view.is_primitive_body(view.selected_body))


func _on_hud_position(pos: Vector3) -> void:
	if _place_kind != "":
		# Jump the ghost floor to the typed position (on the active plane).
		if _place_ghost != null:
			_place_ghost.transform = _ghost_world_xform(_place_kind, _snap_on_active_plane(pos))
			_update_place_measure(_screen_center())
		return
	if view.selected_body == "":
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var delta: Vector3 = pos - bb["center"]
	if delta.length() < 1e-6:
		return
	view.move_selected(delta)
	_refresh_transform_hud()


func _on_hud_size(size: Vector3) -> void:
	if _place_kind != "":
		# Keep the ghost's floor contact while rebuilding the mesh.
		var floor_pt := active_plane_origin
		if _place_ghost != null:
			floor_pt = _place_ghost.position - _ghost_sit_offset(_place_kind)
		place_size = size
		if _place_ghost != null:
			_apply_ghost_mesh(_place_ghost, _place_kind, place_size)
			_place_ghost.transform = _ghost_world_xform(_place_kind, floor_pt)
			_update_place_measure(_screen_center())
		return
	if view.selected_body == "":
		return
	if view.is_import_body(view.selected_body):
		_apply_import_hud_size(size)
		return
	if not view.is_primitive_body(view.selected_body):
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	size = _equalize_hud_size_for_primitive(view.selected_body, size)
	var center: Vector3 = bb["center"]
	var half := size * 0.5
	if view.resize_primitive_aabb(view.selected_body, center - half, center + half):
		status.emit("Size → %.1f × %.1f × %.1f" % [size.x, size.y, size.z])
	_refresh_transform_hud()


## Map a HUD size edit onto uniform import scale (max-extent ratio).
func _apply_import_hud_size(size: Vector3) -> void:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var old: Vector3 = bb["size"]
	var old_ext := maxf(old.x, maxf(old.y, old.z))
	var new_ext := maxf(size.x, maxf(size.y, size.z))
	if old_ext < 1e-6 or new_ext < 1e-6:
		return
	var params := view.feature_params(view.selected_body)
	var cur := float(params.get("scale", 1.0))
	var next := cur * (new_ext / old_ext)
	if absf(next - cur) < 1e-9:
		return
	if view.set_import_scale(view.selected_body, next):
		status.emit("Scale → %.4g" % next)
	_refresh_transform_hud()


## Cylinder/cone need equal radial AABB sides; sphere is isotropic.
func _equalize_hud_size_for_primitive(body_id: String, size: Vector3) -> Vector3:
	var params := view.feature_params(body_id)
	var kind := str(params.get("kind", "box"))
	if kind == "sphere":
		var d := maxf(size.x, maxf(size.y, size.z))
		return Vector3(d, d, d)
	if kind != "cylinder" and kind != "cone":
		return size
	var z := DocumentView._param_vec3(params, "z_dir", Vector3(0, 0, 1))
	var axis := DocumentView._dominant_axis(z)
	var a := (axis + 1) % 3
	var b := (axis + 2) % 3
	var diam := maxf(size[a], size[b])
	size[a] = diam
	size[b] = diam
	return size


func _on_hud_move_delta(delta: Vector3) -> void:
	if view.selected_body == "":
		return
	if _drag_mode == DragMode.MOVE_BODY:
		# Typed ΔZ hops off-plane while mouse still drives XY.
		_apply_live_move(delta)
		return
	# Post-drag refine: apply correction past the last committed Δ.
	var corr := delta - _move_delta_base
	if corr.length() < 1e-6:
		return
	if view.move_selected(corr):
		_move_delta_base = delta
		status.emit("Move Δ → (%.2f, %.2f, %.2f)" % [delta.x, delta.y, delta.z])
	_refresh_transform_hud()
	if transform_hud != null:
		transform_hud.set_move_delta(delta)


func _on_hud_precision(distance: float) -> void:
	if view.selected_body == "":
		return
	if _precision_kind == "rotate":
		var wanted := deg_to_rad(distance)
		var corr := wanted - deg_to_rad(_precision_base)
		if absf(corr) < 1e-6:
			return
		if view.rotate_selected(_precision_rotate_center, _precision_rotate_axis, corr):
			_precision_base = distance
			status.emit("Rotated to %.2f°" % distance)
		_refresh_transform_hud()
		return
	if not view.is_primitive_body(view.selected_body):
		return
	_apply_precision_resize(distance)


func _apply_precision_resize(distance: float) -> void:
	_resize_start_min = _precision_min
	_resize_start_max = _precision_max
	_resize_signs = _precision_signs
	_apply_resize_delta(distance)
	var mn := _resize_min
	var mx := _resize_max
	for axis in range(3):
		if mx[axis] - mn[axis] < 0.1:
			status.emit("Size too small")
			return
	if view.resize_primitive_aabb(view.selected_body, mn, mx):
		_precision_base = distance
		status.emit("Resized to Δ %.2f mm" % distance)
	_refresh_transform_hud()


func _show_precision_after_drag(distance: float, hint: String, unit := "mm") -> void:
	_precision_base = distance
	if transform_hud == null:
		return
	transform_hud.show_precision(distance, hint, unit)


func _model_to_screen(model_pt: Vector3) -> Vector2:
	var world: Vector3 = model_space.to_global(model_pt)
	return camera.unproject_position(world)


## Pick an AABB face stretch handle near `screen_pos` (primitives only).
## Pick points sit just outside each face so a grab can miss the mesh
## (body hits always XY-move — see `_on_press`).
func _pick_resize_handle(screen_pos: Vector2) -> Dictionary:
	if view.selected_body == "" or not view.is_primitive_body(view.selected_body):
		return {}
	if view.selection_size() != 1:
		return {}
	var bb := view.selection_bbox()
	if bb.is_empty():
		return {}
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var pad := maxf(maxf(bb["size"].x, bb["size"].y), bb["size"].z) * 0.06 + 2.0
	var best := {}
	var best_d := HANDLE_PX
	var face_handles := [
		{"point": Vector3(mx.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5),
			"signs": Vector3(1, 0, 0), "hint": "ΔX"},
		{"point": Vector3(mn.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5),
			"signs": Vector3(-1, 0, 0), "hint": "ΔX"},
		{"point": Vector3((mn.x + mx.x) * 0.5, mx.y, (mn.z + mx.z) * 0.5),
			"signs": Vector3(0, 1, 0), "hint": "ΔY"},
		{"point": Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5),
			"signs": Vector3(0, -1, 0), "hint": "ΔY"},
		{"point": Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z),
			"signs": Vector3(0, 0, 1), "hint": "ΔZ"},
		{"point": Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z),
			"signs": Vector3(0, 0, -1), "hint": "ΔZ"},
	]
	for h in face_handles:
		var signs: Vector3 = h["signs"]
		var tip_guess: Vector3 = h["point"] + signs * maxf(pad * 3.0, 8.0)
		var pick_pt: Vector3 = _screen_capped_tip(h["point"], tip_guess)
		var d: float = _model_to_screen(pick_pt).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = h
	if best.is_empty():
		return {}
	best["min"] = mn
	best["max"] = mx
	return best


## Lift grip along the active-plane normal. Base is inset into the solid so
## the yellow elevator clears the blue outward stretch chevron on that face.
## Tip length is screen-capped so the grip never dwarfs the selection.
func _z_move_grip_anchor() -> Dictionary:
	if view == null or view.selected_body == "" or view.selection_size() != 1:
		return {}
	if view.selected_face != "" or view.selected_instance != "":
		return {}
	var bb := view.selection_bbox()
	if bb.is_empty():
		return {}
	var c: Vector3 = bb["center"]
	var half: Vector3 = bb["size"] * 0.5
	var n := _active_plane_n()
	# AABB support distance along ±n (L1 of |half| weighted by |n|).
	var extent_n := absf(half.x * n.x) + absf(half.y * n.y) + absf(half.z * n.z)
	# Sit ~45% of the way from center to the outer face — inside the solid.
	var inset_from_face := extent_n * 0.55
	var base := c + n * (extent_n - inset_from_face)
	var tip_guess := base + n * maxf(_axis_len() * 0.9, 18.0)
	var tip := _screen_capped_tip(base, tip_guess)
	return {"point": tip, "center": c, "base": base, "normal": n}


func _pick_z_move_grip(screen_pos: Vector2) -> Dictionary:
	var h := _z_move_grip_anchor()
	if h.is_empty():
		return {}
	# Prefer tip, but also accept the mid “lift” plate so a short grip is easy.
	var tip_d: float = _model_to_screen(h["point"]).distance_to(screen_pos)
	var mid: Vector3 = (h["base"] as Vector3).lerp(h["point"], 0.55)
	var mid_d: float = _model_to_screen(mid).distance_to(screen_pos)
	if minf(tip_d, mid_d) > AXIS_HANDLE_PX:
		return {}
	return h


## Shorten `tip` along base→tip so screen length ≤ GRIP_SCREEN_FRAC of the
## viewport dimension matching the arrow's dominant screen direction.
func _screen_capped_tip(base_m: Vector3, tip_m: Vector3) -> Vector3:
	if camera == null or model_space == null:
		return tip_m
	var base_s := _model_to_screen(base_m)
	var tip_s := _model_to_screen(tip_m)
	var delta_s := tip_s - base_s
	var len_s := delta_s.length()
	if len_s < 1.0:
		return tip_m
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		vp = size if size.x > 2.0 else Vector2(1280, 720)
	# Direction they point: vertical → screen height; horizontal → screen width.
	var limit := GRIP_SCREEN_FRAC * (vp.y if absf(delta_s.y) >= absf(delta_s.x) else vp.x)
	if len_s <= limit:
		return tip_m
	return base_m.lerp(tip_m, limit / len_s)


## AABB axes that must grow, together, when `signs` is a radial/sphere grip.
## Empty → ordinary one-sided face stretch (boxes, cylinder length, etc.).
func _coupled_resize_axes(signs: Vector3) -> PackedInt32Array:
	if view == null or view.selected_body == "" or not view.is_primitive_body(view.selected_body):
		return PackedInt32Array()
	var params := view.feature_params(view.selected_body)
	var kind := str(params.get("kind", "box"))
	if kind == "sphere":
		return PackedInt32Array([0, 1, 2])
	if kind != "cylinder" and kind != "cone":
		return PackedInt32Array()
	var z := DocumentView._param_vec3(params, "z_dir", Vector3(0, 0, 1))
	var height_axis := DocumentView._dominant_axis(z)
	var drag_axis := -1
	for i in range(3):
		if absf(signs[i]) > 0.5:
			drag_axis = i
			break
	if drag_axis < 0 or drag_axis == height_axis:
		return PackedInt32Array()
	var out := PackedInt32Array()
	for i in range(3):
		if i != height_axis:
			out.append(i)
	return out


## Apply outward face travel `dist` (mm) onto `_resize_min`/`_resize_max`.
## Radial cyl/cone/sphere grips expand diameter about the start center.
func _apply_resize_delta(dist: float) -> void:
	_resize_distance = dist
	_resize_min = _resize_start_min
	_resize_max = _resize_start_max
	var coupled := _coupled_resize_axes(_resize_signs)
	if coupled.size() >= 2:
		var center := (_resize_start_min + _resize_start_max) * 0.5
		var start_size := _resize_start_max - _resize_start_min
		var start_diam := start_size[coupled[0]]
		for i in range(1, coupled.size()):
			start_diam = maxf(start_diam, start_size[coupled[i]])
		var new_diam := maxf(0.1, start_diam + dist)
		for ai in coupled:
			_resize_min[ai] = center[ai] - new_diam * 0.5
			_resize_max[ai] = center[ai] + new_diam * 0.5
		return
	var signs := _resize_signs
	var axis := Vector3(signs.x, signs.y, signs.z).normalized()
	var delta_vec := axis * dist
	for ai in range(3):
		var s: float = signs[ai]
		if absf(s) < 0.5:
			continue
		if s > 0.0:
			_resize_max[ai] = _resize_start_max[ai] + delta_vec[ai]
		else:
			_resize_min[ai] = _resize_start_min[ai] + delta_vec[ai]
		if _resize_max[ai] - _resize_min[ai] < 0.1:
			if s > 0.0:
				_resize_max[ai] = _resize_min[ai] + 0.1
			else:
				_resize_min[ai] = _resize_max[ai] - 0.1


func _update_resize_drag(screen_pos: Vector2) -> void:
	var ray := _model_ray(screen_pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	# Face stretch is always single-axis (outward normal).
	var signs := _resize_signs
	var axis := Vector3(signs.x, signs.y, signs.z).normalized()
	var cross_dn := d.cross(axis)
	var denom := cross_dn.length_squared()
	if denom < 1e-12:
		return
	var dist := (o - _drag_start_point).dot(cross_dn.cross(d)) / denom
	_apply_resize_delta(dist)
	if transform_hud != null:
		transform_hud.set_precision(_resize_distance, _resize_axis_hint)
	status.emit("Resize: %.1f mm" % _resize_distance)


func _commit_resize() -> void:
	var body := view.selected_body
	if body == "" or not view.is_primitive_body(body):
		status.emit("Resize needs a primitive body")
		return
	_precision_min = _resize_start_min
	_precision_max = _resize_start_max
	_precision_signs = _resize_signs
	_precision_kind = "resize"
	if view.resize_primitive_aabb(body, _resize_min, _resize_max):
		status.emit("Resized %.1f mm" % _resize_distance)
		_show_precision_after_drag(_resize_distance, _resize_axis_hint)
	else:
		status.emit("Resize failed")
	_refresh_transform_hud()


## Midpoint of all bodies' combined AABB (model space), or ZERO if empty.
func _bodies_aabb_center() -> Vector3:
	var first := true
	var united_min := Vector3.ZERO
	var united_max := Vector3.ZERO
	for id in view.doc.body_ids():
		var bb: Dictionary = view.doc.measure_bbox(id)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if first:
			united_min = mn
			united_max = mx
			first = false
		else:
			united_min = united_min.min(mn)
			united_max = united_max.max(mx)
	if first:
		return Vector3.ZERO
	return (united_min + united_max) * 0.5


## Toggle section-view clipping through the combined body AABB center (+X).
func toggle_section() -> void:
	if view.section_enabled:
		view.clear_section_plane()
		status.emit("Section view off")
	else:
		var center := _bodies_aabb_center()
		view.set_section_plane(center, Vector3(1, 0, 0))
		status.emit("Section view on")


func _input(event: InputEvent) -> void:
	# Camera first — before Control STOP panels so orbit works over docks, and
	# before place so Alt+drag / two-finger pan don't commit a solid.
	# Never steal wheel / two-finger pan from ScrollContainers; pinch always zooms.
	var allow_scroll := not OrbitCamera.pointer_over_scrollable_ui()
	# Magnify must never fall through place/sketch even if scroll gating diffs.
	if event is InputEventMagnifyGesture and camera != null:
		if camera.handle_input(event, true):
			get_viewport().set_input_as_handled()
			return
	# Suppress camera nav keys while a text edit control owns focus so digits
	# (1/2/3/7) type into numeric fields (e.g. TransformHud / PropertyPanel).
	if camera != null:
		var block_nav := false
		if event is InputEventKey:
			block_nav = _text_field_has_focus() or _sketch_keys_blocked()
		if not block_nav and camera.is_nav_event(event, allow_scroll):
			if camera.handle_input(event, allow_scroll):
				get_viewport().set_input_as_handled()
				return
	# Place mode uses viewport mouse coords so ghost/commit work even when the
	# cursor is "over" a sibling Control or Interaction fails hit-tests.
	if _place_kind != "" and sketch_mode != null and sketch_mode.active:
		_disarm_place(false)
	# One-shot: click a flat face to set the active move plane.
	if _picking_active_plane:
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			var mouse_pos := (event as InputEventMouse).position
			if _over_chrome(mouse_pos):
				return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if not mb.pressed:
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed:
				_commit_pick_active_plane(mb.position)
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				cancel_pick_active_plane()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				cancel_pick_active_plane()
				get_viewport().set_input_as_handled()
				return
		return
	# One-shot: pick face / yellow pad / ground to start or reopen a sketch.
	if _picking_sketch_host:
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			var mouse_pos2 := (event as InputEventMouse).position
			if _over_chrome(mouse_pos2):
				return
		if event is InputEventMouseButton:
			var mb2 := event as InputEventMouseButton
			if not mb2.pressed:
				get_viewport().set_input_as_handled()
				return
			if mb2.button_index == MOUSE_BUTTON_LEFT and not mb2.alt_pressed:
				_commit_pick_sketch_host(mb2.position)
				get_viewport().set_input_as_handled()
				return
			if mb2.button_index == MOUSE_BUTTON_RIGHT:
				cancel_pick_sketch_host()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				cancel_pick_sketch_host()
				get_viewport().set_input_as_handled()
				return
		return
	if _place_kind != "":
		# Don't steal clicks aimed at the snap / transform chrome.
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			var mouse_pos := (event as InputEventMouse).position
			if _over_chrome(mouse_pos):
				return
		if event is InputEventMouseMotion:
			# event.position is viewport coords in _input (not Control-local).
			_update_ghost((event as InputEventMouseMotion).position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if not mb.pressed:
				if _ignore_select_release and mb.button_index == MOUSE_BUTTON_LEFT:
					_ignore_select_release = false
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed:
				_commit_place(mb.position)
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_disarm_place(true)
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				_disarm_place(true)
				get_viewport().set_input_as_handled()
				return
		return

	# Sketch: same `_input` ownership so it works if Interaction isn't hovered.
	# Do not steal clicks aimed at the sketch toolbar / docks / spinboxes —
	# Fusion/Onshape chrome owns the pointer there.
	if sketch_mode != null and sketch_mode.active:
		if event is InputEventMouse:
			var mouse_pos := (event as InputEventMouse).position
			if not _viewport_owns_pointer(mouse_pos):
				return
			_sketch_input(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed:
			if _sketch_keys_blocked():
				return
			_sketch_input(event)
			get_viewport().set_input_as_handled()
			return

	# Select / empty-orbit / handles — also via `_input` so they work when
	# Interaction has size 0 or is under another Control for hit-testing.
	# Keep capturing motion/release after a press even if the cursor drifts
	# over a dock edge.
	var event_pos := Vector2.INF
	if event is InputEventMouse:
		event_pos = (event as InputEventMouse).position
	if _pressed or _viewport_owns_pointer(event_pos):
		if _handle_model_pointer(event):
			get_viewport().set_input_as_handled()
			return

	# Tap X / Y / Z mid body-move to lock the drag to that axis (tap again to free).
	# Handled here (not _gui_key) so it works regardless of Control focus.
	# Plain Z only — Ctrl+Z still reaches undo via _gui_key when not dragging.
	if event is InputEventKey and event.pressed and not event.echo \
			and not event.ctrl_pressed and _drag_mode == DragMode.MOVE_BODY:
		var kc := (event as InputEventKey).keycode
		var axis := -1
		match kc:
			KEY_X: axis = AXIS_X
			KEY_Y: axis = AXIS_Y
			KEY_Z: axis = AXIS_Z
		if axis >= 0:
			_move_axis_lock = -1 if _move_axis_lock == axis else axis
			_on_drag(_last_drag_pos)  # re-apply preview under the new lock
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		# Del/Backspace must work without Interaction focus (focus often sits on
		# docks after placing). Never steal keystrokes from live text fields.
		if (ke.keycode == KEY_DELETE or ke.keycode == KEY_BACKSPACE) \
				and not _text_field_has_focus():
			if _gui_key(ke):
				get_viewport().set_input_as_handled()
				return
		if has_focus() and _gui_key(ke):
			get_viewport().set_input_as_handled()


## True when a LineEdit / TextEdit (incl. SpinBox inner edit) owns focus.
func _text_field_has_focus() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is CodeEdit


## Delete selected bodies / instance. Returns false when there was nothing to delete.
func _delete_selection() -> bool:
	if view == null:
		return false
	if view.selected_instance != "":
		if view.doc.remove_instance(view.selected_instance):
			view.refresh()
			status.emit("Instance removed")
			return true
		return false
	var n := view.selection_size()
	if n <= 0 and view.selected_body == "":
		return false
	if view.delete_selected():
		status.emit("Deleted %d" % n if n > 1 else "Deleted body")
		return true
	status.emit("Cannot delete (later features depend on it)")
	return false


# --- selection chrome (strip + RMB) ---

func _refresh_selection_strip() -> void:
	if _selection_strip == null:
		return
	var has_instance := view != null and view.selected_instance != ""
	var has := (view != null and view.selected_body != "") or has_instance
	# Sketch mode is modal: its toolbar takes the top-center slot, and the
	# strip's body verbs don't apply while sketching.
	var sketching := sketch_mode != null and sketch_mode.active
	_selection_strip.visible = has and _place_kind == "" and not sketching
	_selection_strip.mouse_filter = Control.MOUSE_FILTER_STOP if _selection_strip.visible \
			else Control.MOUSE_FILTER_IGNORE
	if not has:
		return
	# Instances get a slim strip: Delete only (modeling ops act on bodies).
	var multi_body := not has_instance and view.selected_bodies.size() >= 2 \
			and view.selected_face == ""
	_strip_fuse.visible = multi_body
	_strip_cut.visible = multi_body
	_strip_common.visible = multi_body
	_strip_fillet.visible = not has_instance
	_strip_hole.visible = not has_instance
	_strip_hole_wizard.visible = not has_instance
	_strip_clash.visible = multi_body
	_strip_triball.visible = not has_instance
	_strip_sketch.visible = not has_instance and view.selected_face != ""
	_strip_look.visible = not has_instance and view.selected_face != ""
	_strip_plane.visible = not has_instance and view.selected_face != ""
	_strip_hide.visible = not has_instance
	_strip_delete.visible = true


func _open_context_menu(screen_pos: Vector2) -> void:
	if _context_menu == null:
		return
	_context_menu.clear()
	var has := view != null and view.selected_body != ""
	if has:
		_context_menu.add_item("Fillet", 1)
		if view.selected_face != "":
			_context_menu.add_item("Sketch on face…", 2)
			_context_menu.add_item("Set as active plane", 8)
			_context_menu.add_item("Look at face", 6)
			_context_menu.add_item("Push/Pull (drag orange arrow)", 7)
		_context_menu.add_item("Hide", 3)
		_context_menu.add_item("Isolate", 4)
		_context_menu.add_separator()
		_context_menu.add_item("Cut", 20)
		_context_menu.add_item("Copy", 21)
		_context_menu.add_item("Paste", 22)
		_context_menu.add_item("Paste Special…", 23)
		_context_menu.add_separator()
		_context_menu.add_item("Delete", 5)
		_context_menu.add_item("Fit selection", 12)
	else:
		_context_menu.add_item("Set Active Plane… (click face)", 14)
		if _active_plane_custom:
			_context_menu.add_item("Reset Active Plane (ground)", 15)
		if view.has_clipboard():
			_context_menu.add_item("Paste", 22)
			_context_menu.add_item("Paste Special…", 23)
			_context_menu.add_separator()
		_context_menu.add_item("Fit all", 10)
		_context_menu.add_item("Unhide all", 11)
		_context_menu.add_item("Orientation… (Space)", 13)
	var global_pos := get_global_transform_with_canvas() * screen_pos
	_context_menu.position = Vector2i(global_pos)
	_context_menu.popup()


func _on_context_id(id: int) -> void:
	match id:
		1: _ctx_fillet()
		2: sketch_requested.emit()
		3: _ctx_hide()
		4: _ctx_isolate()
		5: _ctx_delete()
		6: _ctx_look_at()
		7:
			status.emit("Drag the orange Pull arrow on the face to push/pull")
		8: _ctx_set_active_plane()
		10:
			if camera != null:
				camera.frame_contents()
		11:
			view.unhide_all()
			status.emit("All shown")
		12:
			if camera != null:
				camera.frame_selection_or_all(false)
		20:
			var n := view.cut_selection()
			status.emit("Cut %d" % n if n > 1 else ("Cut" if n == 1 else "Nothing to cut"))
			_refresh_transform_hud()
			_refresh_selection_strip()
		21:
			var nc := view.copy_selection()
			status.emit("Copied %d" % nc if nc > 1 else ("Copied" if nc == 1 else "Nothing to copy"))
		22:
			var made: Array = view.paste_clipboard()
			status.emit("Pasted %d" % made.size() if made.size() > 1 else ("Pasted" if not made.is_empty() else "Clipboard empty"))
			_refresh_transform_hud()
			_refresh_selection_strip()
		23:
			paste_special_requested.emit()
		13:
			_show_orient_popup()
		14:
			arm_pick_active_plane()
		15:
			reset_active_plane()


func _ctx_set_active_plane() -> void:
	set_active_plane_from_selection()


func _ctx_fillet() -> void:
	if ops_panel != null:
		ops_panel._fillet_all()
	else:
		status.emit("Fillet: open Modify panel")


## Instant pairwise boolean: primary keeps the result; other selected bodies
## are tools (consumed). Chains left→right when more than two are selected.
func _ctx_boolean(op: String) -> void:
	if view == null or view.selected_bodies.size() < 2:
		status.emit("%s needs two or more bodies selected" % op.capitalize())
		return
	var primary: String = view.selected_body
	if primary == "":
		primary = str(view.selected_bodies[view.selected_bodies.size() - 1])
	var tools: Array = []
	for id in view.selected_bodies:
		if str(id) != primary:
			tools.append(str(id))
	var ok_count := 0
	for tool in tools:
		if view.boolean_bodies(primary, tool, op):
			ok_count += 1
		else:
			status.emit("Boolean %s failed on tool %s" % [op, str(tool).left(8)])
			view.select_entity(primary, "")
			return
	view.select_entity(primary, "")
	status.emit("Boolean %s applied (%d tool%s)" % [
			op, ok_count, "" if ok_count == 1 else "s"])


func _ctx_hide() -> void:
	var ids := _selected_body_ids()
	for id in ids:
		view.set_body_hidden(id, true)
	status.emit("%d hidden" % ids.size())


func _ctx_isolate() -> void:
	view.isolate(_selected_body_ids())
	status.emit("Isolated")


func _ctx_delete() -> void:
	_delete_selection()


func _ctx_print_check() -> void:
	if view == null or view.doc == null:
		status.emit("Print check: no document")
		return
	var r: Dictionary = view.doc.print_analyze(view.selected_body)
	status.emit(str(r.get("digest", "Print check")))


func _ctx_look_at() -> void:
	if camera == null or view == null or view.selected_face == "":
		status.emit("Select a face first")
		return
	var n := view.selected_face_normal()
	camera.look_along_model_normal(n)
	status.emit("Look at face")


func _show_orient_popup() -> void:
	if _orient_popup == null:
		return
	_rebuild_orient_popup()
	var center := get_viewport().get_visible_rect().get_center()
	_orient_popup.popup(Rect2i(Vector2i(center) - Vector2i(80, 120), Vector2i(180, 320)))


func _on_orient_id(id: int) -> void:
	if camera == null:
		return
	match id:
		1:
			camera.set_view(deg_to_rad(0.0), deg_to_rad(0.0), true)
		2:
			camera.set_view(deg_to_rad(90.0), deg_to_rad(0.0), true)
		3:
			camera.set_view(deg_to_rad(0.0), deg_to_rad(89.0), true)
		7:
			camera.set_view(deg_to_rad(-35.0), deg_to_rad(40.0), true)
		5:
			camera.toggle_projection()
			status.emit("Projection toggled")
		20:
			camera.frame_selection_or_all(false)
			status.emit("Framed selection")
		21:
			camera.frame_contents()
			status.emit("Framed all")


# --- on-canvas gizmos ---

func _axis_label(axis: Vector3) -> String:
	if absf(axis.x) > 0.5:
		return "X"
	if absf(axis.y) > 0.5:
		return "Y"
	return "Z"


func _selection_center() -> Vector3:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return Vector3.ZERO
	return bb["center"]


func _axis_len() -> float:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return 40.0
	var s: Vector3 = bb["size"]
	return maxf(maxf(s.x, s.y), s.z) * AXIS_LEN_FRAC + 12.0


## Radius that clears the selection AABB corners with a small pad (not _axis_len —
## that includes a large fixed offset meant for lift/stretch grips).
func _rotate_radius() -> float:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return 20.0
	var s: Vector3 = bb["size"]
	# Half-diagonal of the AABB — rings sit just outside the solid.
	return maxf(s.length() * 0.5 * 1.08, 2.0)


## Rotation grips: three arcs about principal axes through the selection center.
func _rotate_grips() -> Array:
	if view == null or view.selected_body == "" or view.selected_face != "":
		return []
	if view.selection_size() != 1:
		return []
	var c := _selection_center()
	var r := _rotate_radius()
	return [
		{"axis": Vector3.RIGHT, "center": c, "radius": r, "color": Color(0.9, 0.25, 0.2)},
		{"axis": Vector3.UP, "center": c, "radius": r, "color": Color(0.25, 0.85, 0.3)},
		{"axis": Vector3(0, 0, 1), "center": c, "radius": r, "color": Color(0.3, 0.55, 1.0)},
	]


func _circle_frame(axis: Vector3) -> Array:
	# Orthonormal u,v spanning the plane perpendicular to axis.
	var a := axis.normalized()
	var u := a.cross(Vector3.UP)
	if u.length_squared() < 1e-8:
		u = a.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := a.cross(u).normalized()
	return [u, v]


func _angle_about_axis(screen_pos: Vector2, axis: Vector3, center: Vector3) -> float:
	var hit = _plane_point_along_axis(screen_pos, axis, center)
	if hit == null:
		return 0.0
	var frame: Array = _circle_frame(axis)
	var d: Vector3 = hit - center
	return atan2(d.dot(frame[1]), d.dot(frame[0]))


func _plane_point_along_axis(screen_pos: Vector2, axis: Vector3, center: Vector3) -> Variant:
	var ray := _model_ray(screen_pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	var n := axis.normalized()
	var denom := d.dot(n)
	if absf(denom) < 1e-9:
		return null
	var t := (center - o).dot(n) / denom
	if t < 0.0:
		return null
	return o + d * t


## Screen-space pick targets: the four angle ticks on each rotate ring
## (not the whole arc — full-circle sampling stole empty-space clicks).
func _rotate_tick_points(g: Dictionary) -> Array:
	var frame: Array = _circle_frame(g["axis"])
	var u: Vector3 = frame[0]
	var v: Vector3 = frame[1]
	var c: Vector3 = g["center"]
	var r: float = g["radius"]
	var pts: Array = []
	for i in range(4):
		var ang := TAU * 0.25 * float(i)
		pts.append(c + (u * cos(ang) + v * sin(ang)) * r)
	return pts


func _pick_rotate_grip(screen_pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := AXIS_HANDLE_PX
	for g in _rotate_grips():
		for pt in _rotate_tick_points(g):
			var d: float = _model_to_screen(pt).distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = g
	return best


func _face_pull_anchor() -> Dictionary:
	if view == null or view.selected_face == "" or view.selected_body == "":
		return {}
	var n := view.selected_face_normal()
	if n.length_squared() < 1e-8:
		return {}
	n = n.normalized()
	var bb := view.selection_bbox()
	if bb.is_empty():
		return {}
	var c: Vector3 = bb["center"]
	var half: Vector3 = bb["size"] * 0.5
	var anchor := c + Vector3(
		n.x * half.x if absf(n.x) > 0.5 else 0.0,
		n.y * half.y if absf(n.y) > 0.5 else 0.0,
		n.z * half.z if absf(n.z) > 0.5 else 0.0)
	var tip := _screen_capped_tip(anchor, anchor + n * maxf(_axis_len() * 0.8, 20.0))
	return {"point": tip, "anchor": anchor, "normal": n}


func _pick_push_pull_handle(screen_pos: Vector2) -> Dictionary:
	var h := _face_pull_anchor()
	if h.is_empty():
		return {}
	if _model_to_screen(h["point"]).distance_to(screen_pos) > AXIS_HANDLE_PX:
		return {}
	return h


func _draw_selection_gizmos() -> void:
	if view == null or view.selected_body == "" or _place_kind != "":
		return
	if camera == null or model_space == null:
		return
	# Orbit / box-select: no mod chrome.
	if _drag_mode == DragMode.ORBIT_VIEW or _drag_mode == DragMode.BOX_SELECT:
		return

	# Active mod: only that mod's controls (minimalism).
	match _drag_mode:
		DragMode.RESIZE_BODY:
			_draw_active_stretch_only()
			return
		DragMode.ROTATE_BODY:
			for g in _rotate_grips():
				if (g["axis"] as Vector3).distance_squared_to(_rotate_axis) < 1e-8:
					_draw_rotate_arc(g)
			return
		DragMode.MOVE_BODY, DragMode.MOVE_INSTANCE:
			_draw_move_feedback()
			return
		DragMode.PUSH_PULL:
			_draw_pull_handle()
			return

	# Idle: full affordance set for the current selection.
	_draw_idle_stretch_grips()
	var z_grip := _z_move_grip_anchor()
	if not z_grip.is_empty():
		_draw_lift_grip(_model_to_screen(z_grip["base"]), _model_to_screen(z_grip["point"]))
	if _active_plane_custom and view.selection_size() >= 1:
		_draw_active_plane_hint()
	for g in _rotate_grips():
		_draw_rotate_arc(g)
	_draw_pull_handle()


func _draw_idle_stretch_grips() -> void:
	if not view.is_primitive_body(view.selected_body) or view.selection_size() != 1:
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var pad := maxf(maxf(bb["size"].x, bb["size"].y), bb["size"].z) * 0.06 + 2.0
	var faces: Array[Dictionary] = [
		{"p": Vector3(mx.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5), "n": Vector3(1, 0, 0)},
		{"p": Vector3(mn.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5), "n": Vector3(-1, 0, 0)},
		{"p": Vector3((mn.x + mx.x) * 0.5, mx.y, (mn.z + mx.z) * 0.5), "n": Vector3(0, 1, 0)},
		{"p": Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5), "n": Vector3(0, -1, 0)},
		{"p": Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z), "n": Vector3(0, 0, 1)},
		{"p": Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z), "n": Vector3(0, 0, -1)},
	]
	var stretch_col := Color(0.25, 0.75, 1.0, 0.95)
	for f in faces:
		var tip_m := _screen_capped_tip(f["p"], f["p"] + f["n"] * maxf(pad * 3.0, 8.0))
		_draw_stretch_arrow(_model_to_screen(f["p"]), _model_to_screen(tip_m), stretch_col)


## Only the stretch face being dragged (hides rotate / other stretches / pull).
func _draw_active_stretch_only() -> void:
	if not view.is_primitive_body(view.selected_body):
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var pad := maxf(maxf(bb["size"].x, bb["size"].y), bb["size"].z) * 0.06 + 2.0
	var s := _resize_signs
	var p := Vector3(
		mx.x if s.x > 0.0 else (mn.x if s.x < 0.0 else (mn.x + mx.x) * 0.5),
		mx.y if s.y > 0.0 else (mn.y if s.y < 0.0 else (mn.y + mx.y) * 0.5),
		mx.z if s.z > 0.0 else (mn.z if s.z < 0.0 else (mn.z + mx.z) * 0.5))
	var n := Vector3(signf(s.x), signf(s.y), signf(s.z))
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	var tip_m := _screen_capped_tip(p, p + n * maxf(pad * 3.0, 8.0))
	_draw_stretch_arrow(_model_to_screen(p), _model_to_screen(tip_m), Color(0.25, 0.75, 1.0, 0.95))


func _draw_move_feedback() -> void:
	if _drag_mode != DragMode.MOVE_BODY:
		return
	if _drag_accum.length() > 1e-4:
		var old_s := _model_to_screen(_move_start_center)
		var new_s := _model_to_screen(_move_start_center + _drag_accum)
		draw_line(old_s, new_s, Color(1.0, 0.85, 0.2, 0.9), 1.5)
		_draw_center_mark(old_s, Color(0.85, 0.85, 0.9, 0.95))
		_draw_center_mark(new_s, Color(1.0, 0.75, 0.15, 0.95))
		draw_string(ThemeDB.fallback_font, old_s + Vector2(8, -8), "old",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))
		draw_string(ThemeDB.fallback_font, new_s + Vector2(8, -8), "new",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.75, 0.15))
	if not _move_snap_active.is_empty():
		_draw_move_snap_guide()
	if _move_axis_lock >= 0:
		_draw_move_lock_axis()


func _draw_pull_handle() -> void:
	var pull := _face_pull_anchor()
	if pull.is_empty():
		return
	var a: Vector2 = _model_to_screen(pull["anchor"])
	var t: Vector2 = _model_to_screen(pull["point"])
	var col2 := Color(1.0, 0.62, 0.15, 0.95)
	_draw_stretch_arrow(a, t, col2)
	draw_string(ThemeDB.fallback_font, t + Vector2(8, -8), "Pull", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col2)


## Stretch / pull: single chevron pointing away from the face.
func _draw_stretch_arrow(base: Vector2, tip: Vector2, color: Color) -> void:
	var delta := tip - base
	if delta.length_squared() < 9.0:
		draw_circle(tip, 4.0, color)
		return
	var dir := delta.normalized()
	var shaft_end := tip - dir * 7.0
	draw_line(base, shaft_end, color, 2.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - dir * 8.0 + perp * 5.0, tip - dir * 8.0 - perp * 5.0,
	]), color)


## Lift / approach plane: double-headed along the shaft with a mid “floor plate”.
## Visually distinct from stretch chevrons.
func _draw_lift_grip(base: Vector2, tip: Vector2) -> void:
	var col := Color(1.0, 0.82, 0.2, 0.95)
	var delta := tip - base
	if delta.length_squared() < 16.0:
		tip = base + Vector2(0, -28)
		delta = tip - base
	var dir := delta.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var mid := base.lerp(tip, 0.55)
	# Shaft
	draw_line(base + dir * 6.0, tip - dir * 6.0, col, 2.5)
	# Up and down heads
	draw_colored_polygon(PackedVector2Array([
		tip, tip - dir * 9.0 + perp * 5.5, tip - dir * 9.0 - perp * 5.5,
	]), col)
	draw_colored_polygon(PackedVector2Array([
		base, base + dir * 9.0 + perp * 5.5, base + dir * 9.0 - perp * 5.5,
	]), col)
	# Mid plate = “active plane” cue (horizontal bar + small square).
	var plate := 9.0
	draw_line(mid - perp * plate, mid + perp * plate, Color(0.95, 0.95, 0.98, 0.95), 2.5)
	draw_rect(Rect2(mid - Vector2(4, 4), Vector2(8, 8)), col, false, 1.5)
	draw_string(ThemeDB.fallback_font, tip + perp * 8.0 + Vector2(2, -4), "lift",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## Screen-space outline of the active move plane near the selection.
func _draw_active_plane_hint() -> void:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var c: Vector3 = bb["center"]
	var n := _active_plane_n()
	# Project center onto the plane (keeps the hint on the chosen face height).
	var origin := active_plane_origin
	c = c - n * (c - origin).dot(n)
	var x := n.cross(Vector3(0, 0, 1))
	if x.length_squared() < 1e-12:
		x = Vector3(1, 0, 0)
	else:
		x = x.normalized()
	var y := n.cross(x).normalized()
	var half := maxf(maxf(bb["size"].x, bb["size"].y), bb["size"].z) * 0.55 + 4.0
	var corners: Array[Vector3] = [
		c + (x + y) * half,
		c + (x - y) * half,
		c + (-x - y) * half,
		c + (-x + y) * half,
	]
	var col := Color(1.0, 0.82, 0.25, 0.55)
	for i in range(4):
		var a := _model_to_screen(corners[i])
		var b := _model_to_screen(corners[(i + 1) % 4])
		draw_dashed_line(a, b, col, 1.5, 6.0, true)


func _draw_center_mark(screen: Vector2, color: Color) -> void:
	draw_circle(screen, 4.0, color)
	draw_line(screen + Vector2(-8, 0), screen + Vector2(8, 0), color, 1.5)
	draw_line(screen + Vector2(0, -8), screen + Vector2(0, 8), color, 1.5)


## Dotted snap guide: source→target anchors + gap length between closest surfaces.
func _draw_move_snap_guide() -> void:
	if _move_snap_active.is_empty():
		return
	var col := Color(0.35, 0.9, 0.85, 0.95)
	var src: Vector3 = _move_snap_active["src"]
	var dst: Vector3 = _move_snap_active["dst"]
	var a := _model_to_screen(src)
	var b := _model_to_screen(dst)
	if a.distance_squared_to(b) > 1.0:
		draw_dashed_line(a, b, col, 1.5, 5.0, true)
	else:
		draw_circle(a, 3.5, col)
	_draw_center_mark(a, col)
	_draw_center_mark(b, col)
	var gap_a: Vector3 = _move_snap_active.get("gap_a", src)
	var gap_b: Vector3 = _move_snap_active.get("gap_b", dst)
	var gap_mm: float = float(_move_snap_active.get("gap_mm", 0.0))
	var ga := _model_to_screen(gap_a)
	var gb := _model_to_screen(gap_b)
	if gap_mm > 1e-3 and ga.distance_squared_to(gb) > 1.0:
		var gap_col := Color(0.95, 0.85, 0.35, 0.95)
		draw_dashed_line(ga, gb, gap_col, 1.25, 4.0, true)
		var mid := ga.lerp(gb, 0.5)
		draw_string(ThemeDB.fallback_font, mid + Vector2(6, -6),
				"%.2f mm" % gap_mm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gap_col)
	elif str(_move_snap_active.get("kind", "")) != "grid":
		var mid2 := a.lerp(b, 0.5)
		var label := "0 mm" if gap_mm <= 1e-3 else ("%.2f mm" % gap_mm)
		draw_string(ThemeDB.fallback_font, mid2 + Vector2(6, -6), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## Highlight the locked principal axis (or active-plane normal for lift) through
## the live move center.
func _draw_move_lock_axis() -> void:
	var dir := Vector3.ZERO
	var col := Color(1, 1, 1, 0.95)
	match _move_axis_lock:
		AXIS_X:
			dir = Vector3(1, 0, 0)
			col = Color(0.95, 0.25, 0.22, 0.95)
		AXIS_Y:
			dir = Vector3(0, 1, 0)
			col = Color(0.3, 0.85, 0.3, 0.95)
		AXIS_Z:
			dir = _active_plane_n()
			col = Color(1.0, 0.82, 0.2, 0.95)
		_:
			return
	var c := _move_start_center + _drag_accum
	var half := maxf(_axis_len() * 1.2, 25.0)
	var a := _model_to_screen(c - dir * half)
	var b := _model_to_screen(c + dir * half)
	draw_line(a, b, col, 2.5)
	_draw_center_mark(_model_to_screen(c), col)


func _draw_rotate_arc(g: Dictionary) -> void:
	var frame: Array = _circle_frame(g["axis"])
	var u: Vector3 = frame[0]
	var v: Vector3 = frame[1]
	var c: Vector3 = g["center"]
	var r: float = g["radius"]
	var col: Color = g["color"]
	const SEGS := 48
	var prev := Vector2.ZERO
	for i in range(SEGS + 1):
		var ang := TAU * float(i) / float(SEGS)
		var pt: Vector3 = c + (u * cos(ang) + v * sin(ang)) * r
		var sp := _model_to_screen(pt)
		if i > 0:
			draw_line(prev, sp, col, 2.0)
		prev = sp
	# Grip ticks at 90° intervals.
	for i in range(4):
		var ang2 := TAU * 0.25 * float(i)
		var tick: Vector3 = c + (u * cos(ang2) + v * sin(ang2)) * r
		var ts := _model_to_screen(tick)
		draw_circle(ts, 4.0, col)
		draw_circle(ts, 4.0, Color(1, 1, 1, 0.65))


func _draw_push_pull_preview() -> void:
	var tip := _drag_start_point + _drag_normal * _pp_preview_dist
	var a := _model_to_screen(_drag_start_point)
	var t := _model_to_screen(tip)
	draw_line(a, t, Color(1.0, 0.72, 0.2, 0.95), 2.5)
	draw_circle(t, 5.0, Color(1.0, 0.72, 0.2))
	var label := "%.1f mm" % _pp_preview_dist
	var pos := _pp_badge_screen + Vector2(10, -18)
	draw_rect(Rect2(pos - Vector2(4, 2), Vector2(70, 18)), Color(0.12, 0.14, 0.18, 0.85), true)
	draw_string(ThemeDB.fallback_font, pos + Vector2(2, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.6))
