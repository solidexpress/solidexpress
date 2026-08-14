# Application composition root: 3D world (camera, light, grid, DocumentView)
# inside a Z-up ModelSpace) plus the 2D UI shell (palette, card panel, status
# bar). Phase 1 drag-and-drop experience.
extends Node3D

const _PrintStrip := preload("res://scripts/print_strip.gd")

var model_space: Node3D
var view: DocumentView
var camera: OrbitCamera
var interaction: ViewportInteraction
## Canyon HDRI world env; section mode swaps to a flat clear color.
var _world_env: WorldEnvironment
var card_panel: RichTextLabel
var card_box: PanelContainer
var status_label: Label
var show_variables := false  # View-menu override while the table is empty
var autosave_timer: Timer
var sketch_mode: SketchMode
var sketch_toolbar: PanelContainer
var sketch_chrome: SketchContextChrome
## Multi-selected sketch pad feature ids (Ctrl+click outside sketch mode).
var selected_sketch_pads: Array[String] = []
## Timeline-selected Path feature (for sweep-along-path UI).
var selected_path_fid := ""
var timeline: TimelinePanel
var help_overlay: HelpOverlay
var voice_capture: VoiceCapture
var voice_executor: VoiceExecutor
var variables_panel: VariablesPanel
var ops_panel: OpsPanel
var assembly_panel: AssemblyPanel
var view_hud: ViewHud
var drawing_sheet: DrawingSheet
var sheet_metal_view: SheetMetalView
var print_strip
var palette: PanelContainer
var dim_value: SpinBox
var finish_op: OptionButton
var dof_label: Label
var alias_edit: LineEdit
var notes_edit: TextEdit
var file_dialog: FileDialog
var confirm_dialog: ConfirmationDialog
var current_path := ""
enum FileAction { NONE, OPEN, SAVE_AS, IMPORT_STEP, IMPORT_STL, EXPORT_STEP, EXPORT_STL, EXPORT_CONTEXT, EXPORT_DRAWING, INSERT_SXP, IMPORT_DXF, EXPORT_3MF, EXPORT_GLTF, EXPORT_DRAWING_DXF, EXPORT_DRAWING_PDF }
var _file_action: FileAction = FileAction.NONE
var _pending_discard: Callable = Callable()
var _file_popup: PopupMenu
var _mode_popup: PopupMenu
var _work_mode := "Model"
var _edit_popup: PopupMenu
var _recent_menu: PopupMenu
var _paste_special_dialog: ConfirmationDialog
var _paste_ox: SpinBox
var _paste_oy: SpinBox
var _paste_oz: SpinBox
var _paste_in_place: CheckBox
var _recent: Array = []  # paths, most recent first (max 8)
const _RECENT_CLEAR_ID := 100
const _RECENT_CFG := "user://recent.cfg"
## Top + left chrome margins (tight dock under File/Insert/View + snap).
const _CHROME_PAD := 8.0
const _RAIL_TOP := 42.0
const _RAIL_ICON_W := 44.0
const _CARD_W := 280.0
const _CARD_H := 180.0
## Keep the left stack (rail + card) clear of the bottom timeline.
const _LEFT_STACK_LIMIT := 470.0
## Ops panel docks into the left palette slot while a body is selected.
const _OPS_LEFT := {"offset_left": 8.0, "offset_right": 248.0, "offset_top": 42.0}
const _OPS_RIGHT := {"offset_left": -320.0, "offset_right": -12.0, "offset_top": 480.0}


func _finish_op_name() -> String:
	return ["new", "cut", "fuse"][finish_op.selected]
var extrude_distance: SpinBox
var _last_saved_revision := 0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_build_world()
	_build_ui()
	_build_autosave()
	# OS file drops (STL / SVG / STEP / .sxp) onto the viewport.
	get_window().files_dropped.connect(_on_files_dropped)
	# Keyboard cheat sheet on F1, above everything else.
	help_overlay = HelpOverlay.new()
	add_child(help_overlay)
	# Hold-V push-to-talk → STT (optional) → SxVoice interpreter → actions.
	voice_capture = VoiceCapture.new()
	voice_capture.name = "VoiceCapture"
	voice_capture.status.connect(_on_status)
	add_child(voice_capture)
	voice_executor = VoiceExecutor.new()
	voice_executor.view = view
	voice_executor.camera = camera
	voice_executor.sketch_mode = sketch_mode
	voice_executor.interaction = interaction
	voice_executor.status.connect(_on_status)
	voice_capture.set_transcript_provider(voice_executor.handle_text)
	voice_capture.utterance_ready.connect(func(path: String) -> void:
		if path != "":
			voice_executor.handle_wav(path))


func _build_world() -> void:
	camera = OrbitCamera.new()
	camera.name = "Camera"
	add_child(camera)
	# view/model_space wired after they exist (end of _build_world).

	# Soft key light for crisp shadows; canyon HDRI supplies most illumination
	# and the specular/reflection content metals need.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = _make_canyon_environment()
	add_child(_world_env)

	# Kernel is Z-up; Godot is Y-up. ModelSpace maps kernel +Z to world +Y.
	model_space = Node3D.new()
	model_space.name = "ModelSpace"
	model_space.basis = Basis(Vector3.RIGHT, -PI / 2.0)
	add_child(model_space)

	view = DocumentView.new()
	view.name = "DocumentView"
	view.section_changed.connect(_on_section_changed)
	model_space.add_child(view)

	sketch_mode = SketchMode.new()
	sketch_mode.name = "SketchMode"
	sketch_mode.view = view
	sketch_mode.camera = camera
	model_space.add_child(sketch_mode)

	# Grid (+ origin plate) comes from WorldGizmos (mounted by ViewportInteraction).
	# RGB origin sticks live on ViewHud as OriginTriadHud.
	camera.view = view
	camera.model_space = model_space


## Section cuts / sketch ortho reveal the infinite sky through the workplane;
## a flat clear color reads better than the canyon panorama in those modes.
func _on_section_changed(_enabled: bool) -> void:
	_sync_world_background()


## Flat clear color while sectioning or sketching; canyon HDRI otherwise.
## IBL/ambient keep using the sky — only the visible background swaps.
func _sync_world_background() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var e := _world_env.environment
	var flat := (view != null and view.section_enabled) \
			or (sketch_mode != null and sketch_mode.active)
	if flat:
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.16, 0.17, 0.20)
	elif e.sky != null:
		e.background_mode = Environment.BG_SKY
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.16, 0.17, 0.20)


## Canyon HDRI as infinite background + IBL. The sky shader pins the workplane
## to the bottom of the panorama so scenic detail sits above the active plane.
func _make_canyon_environment() -> Environment:
	var panorama: Texture2D = load("res://canyon_hdri/textures/canyon_lighting_4k.hdr") as Texture2D
	var sky_shader: Shader = load("res://canyon_hdri/resources/canyon_floor_sky.gdshader") as Shader
	if panorama == null or sky_shader == null:
		push_warning("Canyon HDRI assets missing — falling back to flat ambient")
		var fallback := Environment.new()
		fallback.background_mode = Environment.BG_COLOR
		fallback.background_color = Color(0.16, 0.17, 0.20)
		fallback.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		fallback.ambient_light_color = Color(0.55, 0.57, 0.62)
		fallback.ambient_light_energy = 0.7
		return fallback

	var mat := ShaderMaterial.new()
	mat.shader = sky_shader
	mat.set_shader_parameter("source_panorama", panorama)
	mat.set_shader_parameter("energy_multiplier", 1.0)
	# Keep the polar-stretched nadir under the workplane (not on the horizon).
	mat.set_shader_parameter("underside_v_frac", 0.32)

	var sky := Sky.new()
	sky.sky_material = mat
	# Match the pack defaults (radiance_size = 5 → 1024, quality process).
	sky.radiance_size = Sky.RADIANCE_SIZE_1024
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.background_energy_multiplier = 1.0
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.ssr_enabled = true
	return e


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# Top-left dock row: File/Insert/View, then PlaceSnapBar (from Interaction).
	var top_chrome := HBoxContainer.new()
	top_chrome.name = "TopChrome"
	top_chrome.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_chrome.position = Vector2(_CHROME_PAD, _CHROME_PAD)
	top_chrome.add_theme_constant_override("separation", 8)

	var menu_bar := PanelContainer.new()
	menu_bar.name = "FileMenu"
	top_chrome.add_child(menu_bar)
	var file_btn := MenuButton.new()
	file_btn.text = "File"
	file_btn.flat = false
	var menu_row := HBoxContainer.new()
	menu_bar.add_child(menu_row)
	menu_row.add_child(file_btn)
	_file_popup = file_btn.get_popup()
	_file_popup.add_item("New", 0)
	_file_popup.add_item("Open...", 1)
	_file_popup.add_item("Save", 2)
	_file_popup.add_item("Save As...", 3)
	_file_popup.add_separator()
	_file_popup.add_item("Import STEP...", 4)
	_file_popup.add_item("Import STL...", 9)
	_file_popup.add_item("Import DXF...", 10)
	_file_popup.add_item("Export STEP...", 5)
	_file_popup.add_item("Export STL...", 6)
	_file_popup.add_item("Export 3MF...", 11)
	_file_popup.add_item("Export glTF...", 12)
	_file_popup.add_separator()
	_file_popup.add_item("Export AI Context...", 7)
	_file_popup.add_item("Export Drawing (SVG)...", 8)
	_file_popup.add_item("Export Drawing (DXF)...", 13)
	_file_popup.add_item("Export Drawing (PDF)...", 14)
	_file_popup.add_separator()
	_recent_menu = PopupMenu.new()
	_recent_menu.name = "RecentMenu"
	_file_popup.add_child(_recent_menu)
	_file_popup.add_submenu_node_item("Recent", _recent_menu)
	_recent_menu.id_pressed.connect(_on_recent_menu)
	_file_popup.id_pressed.connect(_on_file_menu)
	_load_recent()
	_rebuild_recent_menu()

	# Edit menu: undo/redo + clipboard for bodies (and sketch entities).
	var edit_btn := MenuButton.new()
	edit_btn.text = "Edit"
	edit_btn.flat = false
	menu_row.add_child(edit_btn)
	_edit_popup = edit_btn.get_popup()
	_edit_popup.add_item("Undo", 0)
	_edit_popup.add_item("Redo", 1)
	_edit_popup.add_separator()
	_edit_popup.add_item("Cut", 2)
	_edit_popup.add_item("Copy", 3)
	_edit_popup.add_item("Paste", 4)
	_edit_popup.add_item("Paste Special…", 5)
	_edit_popup.add_separator()
	_edit_popup.add_item("Select All", 6)
	_edit_popup.add_item("Delete", 7)
	_edit_popup.id_pressed.connect(_on_edit_menu)
	_edit_popup.about_to_popup.connect(_refresh_edit_menu)
	_build_paste_special_dialog(ui)

	# Insert menu: components (multi-doc .sxp) + reference geometry.
	var insert_btn := MenuButton.new()
	insert_btn.name = "InsertMenu"
	insert_btn.text = "Insert"
	insert_btn.flat = false
	menu_row.add_child(insert_btn)
	var insert_popup := insert_btn.get_popup()
	insert_popup.add_item("Components…", 10)
	insert_popup.add_separator()
	insert_popup.add_item("Datum Plane XY", 0)
	insert_popup.add_item("Datum Plane XZ", 1)
	insert_popup.add_item("Datum Plane YZ", 2)
	insert_popup.add_separator()
	insert_popup.add_item("Datum Axis X", 3)
	insert_popup.add_item("Datum Axis Y", 4)
	insert_popup.add_item("Datum Axis Z", 5)
	insert_popup.add_separator()
	insert_popup.add_item("Datum Point at Origin", 6)
	insert_popup.id_pressed.connect(_on_insert_menu)

	var mode_btn := MenuButton.new()
	mode_btn.name = "ModeRail"
	mode_btn.text = "Mode"
	mode_btn.flat = false
	mode_btn.tooltip_text = "Draw / Sheet / Cam / Sim / Form — one rail, replaces Modify"
	menu_row.add_child(mode_btn)
	_mode_popup = mode_btn.get_popup()
	_mode_popup.add_item("Model", 0)
	_mode_popup.add_item("Draw", 1)
	_mode_popup.add_item("Sheet", 2)
	_mode_popup.add_item("Cam", 3)
	_mode_popup.add_item("Sim", 4)
	_mode_popup.add_item("Form", 5)
	_mode_popup.id_pressed.connect(_on_mode_menu)

	# View menu: entry points for panels that auto-hide when they have no data,
	# plus active-plane pick / reset.
	var view_btn := MenuButton.new()
	view_btn.text = "View"
	view_btn.flat = false
	menu_row.add_child(view_btn)
	var view_popup := view_btn.get_popup()
	view_popup.add_check_item("Variables Panel", 0)
	view_popup.add_separator()
	view_popup.add_item("Set Active Plane…", 1)
	view_popup.add_item("Reset Active Plane (ground)", 2)
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			show_variables = not show_variables
			view_popup.set_item_checked(view_popup.get_item_index(0), show_variables)
			_update_panel_visibility()
		elif id == 1:
			interaction.arm_pick_active_plane()
		elif id == 2:
			interaction.reset_active_plane())

	print_strip = _PrintStrip.new()
	print_strip.name = "PrintStrip"
	print_strip.visible = false
	top_chrome.add_child(print_strip)
	print_strip.analyze_requested.connect(_on_print_analyze)
	print_strip.orient_requested.connect(_on_print_orient)

	# Interaction overlay under chrome (full-rect input); snap bar joins TopChrome.
	interaction = ViewportInteraction.new()
	interaction.name = "Interaction"
	interaction.view = view
	interaction.camera = camera
	interaction.model_space = model_space
	interaction.sketch_mode = sketch_mode
	interaction.top_chrome = top_chrome
	ui.add_child(interaction)
	ui.add_child(top_chrome)

	# Mode overlays sit under chrome and stay hidden in Model (layout suite).
	drawing_sheet = DrawingSheet.new()
	ui.add_child(drawing_sheet)
	sheet_metal_view = SheetMetalView.new()
	ui.add_child(sheet_metal_view)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.min_size = Vector2i(700, 460)
	file_dialog.file_selected.connect(_on_file_selected)
	ui.add_child(file_dialog)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Discard unsaved changes?"
	confirm_dialog.confirmed.connect(_on_discard_confirmed)
	ui.add_child(confirm_dialog)

	# Left icon rail: primitives (swaps for Modify / Sketch tools).
	palette = PanelContainer.new()
	palette.name = "Palette"
	palette.set_anchors_preset(Control.PRESET_TOP_LEFT)
	palette.position = Vector2(_CHROME_PAD, _RAIL_TOP)
	ui.add_child(palette)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	palette.add_child(vbox)
	for entry in [["box", "Box"], ["cylinder", "Cylinder"], ["sphere", "Sphere"],
			["cone", "Cone"], ["torus", "Torus"]]:
		var btn := PaletteButton.new(entry[0], entry[1])
		btn.insert_requested.connect(interaction.insert_at_center)
		vbox.add_child(btn)
	vbox.add_child(HSeparator.new())
	var sketch_btn := UIIcons.button("sketch", "",
		"Sketch: select a face or existing sketch to enter sketch mode")
	sketch_btn.pressed.connect(_request_sketch)
	vbox.add_child(sketch_btn)

	# Selection properties card — docks under the left rail when shown.
	card_box = PanelContainer.new()
	card_box.name = "CardPanel"
	card_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_box.offset_left = _CHROME_PAD
	card_box.offset_right = _CHROME_PAD + _CARD_W
	card_box.offset_top = _RAIL_TOP + 200.0
	card_box.offset_bottom = _RAIL_TOP + 200.0 + _CARD_H
	card_box.grow_horizontal = Control.GROW_DIRECTION_END
	ui.add_child(card_box)
	var card_vbox := VBoxContainer.new()
	card_box.add_child(card_vbox)
	var card_title := Label.new()
	card_title.text = "Selection"
	card_vbox.add_child(card_title)
	card_panel = RichTextLabel.new()
	card_panel.fit_content = false
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(260, 80)
	card_panel.add_theme_font_size_override("normal_font_size", 12)
	card_vbox.add_child(card_panel)

	# Editable semantic-card free text: aliases (one line) and notes.
	var alias_label := Label.new()
	alias_label.text = "Aliases (what you'd call this)"
	alias_label.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(alias_label)
	alias_edit = LineEdit.new()
	alias_edit.placeholder_text = "e.g. the mounting face"
	alias_edit.text_submitted.connect(func(t: String) -> void: _save_card_text(t, notes_edit.text))
	card_vbox.add_child(alias_edit)
	var notes_label := Label.new()
	notes_label.text = "Notes (intent, constraints, context)"
	notes_label.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(notes_label)
	notes_edit = TextEdit.new()
	notes_edit.custom_minimum_size = Vector2(260, 40)
	notes_edit.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(notes_edit)
	var save_card := UIIcons.button("save", "Save card text",
		"Save the aliases and notes onto the selection's semantic card")
	save_card.pressed.connect(func() -> void: _save_card_text(alias_edit.text, notes_edit.text))
	card_vbox.add_child(save_card)

	# Right, below card panel: context operations for the selection.
	ops_panel = OpsPanel.new()
	ops_panel.name = "OpsPanel"
	ops_panel.view = view
	ops_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ops_panel.anchor_left = 1.0
	ops_panel.anchor_right = 1.0
	ops_panel.offset_left = -320
	ops_panel.offset_right = -12
	ops_panel.offset_top = 480
	ops_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(ops_panel)
	ops_panel.status.connect(_on_status)
	interaction.ops_panel = ops_panel

	# Right, second column: assembly browser (auto-hides when no instances).
	assembly_panel = AssemblyPanel.new()
	assembly_panel.name = "AssemblyPanel"
	assembly_panel.view = view
	assembly_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	assembly_panel.anchor_left = 1.0
	assembly_panel.anchor_right = 1.0
	assembly_panel.offset_left = -652
	assembly_panel.offset_right = -332
	assembly_panel.offset_top = 480
	assembly_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(assembly_panel)
	assembly_panel.status.connect(_on_status)
	assembly_panel.instance_selected.connect(func(id: String) -> void:
		var node := view.instance_node(id)
		if node != null:
			camera.pivot = model_space.to_global(node.position)
			camera._update_transform()
			_on_status("Instance focused"))

	# Far bottom-right (above the status bar; same chrome pad as File/Insert/View).
	view_hud = ViewHud.new()
	view_hud.name = "ViewHud"
	view_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	view_hud.anchor_left = 1.0
	view_hud.anchor_right = 1.0
	view_hud.anchor_top = 1.0
	view_hud.anchor_bottom = 1.0
	# Zero-width at the right pad; grow left/up so content sets size.
	view_hud.offset_left = -_CHROME_PAD
	view_hud.offset_right = -_CHROME_PAD
	# Status bar is 30 px tall — sit just above it with chrome pad.
	view_hud.offset_top = -(30.0 + _CHROME_PAD)
	view_hud.offset_bottom = -(30.0 + _CHROME_PAD)
	view_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	view_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(view_hud)
	view_hud.set_camera(camera)
	view_hud.display_cycle_requested.connect(func() -> void:
		var mode: int = view.cycle_display_mode()
		_on_status("Display: " + ["Shaded", "Shaded + Edges", "Wireframe"][mode])
		view_hud.sync_from_view(view))
	view_hud.section_toggle_requested.connect(func() -> void:
		interaction.toggle_section()
		view_hud.sync_from_view(view))
	view_hud.zebra_toggle_requested.connect(func(on: bool) -> void:
		view.set_zebra(on)
		view_hud.sync_from_view(view)
		_on_status("Zebra on" if on else "Zebra off"))
	view_hud.explode_toggle_requested.connect(func(on: bool) -> void:
		var moved: int = view.doc.explode_assembly(0.8 if on else 0.0)
		view.refresh()
		view_hud.sync_from_view(view)
		if moved == 0:
			_on_status("Nothing to explode")
		else:
			_on_status("Exploded %d part(s)" % moved if on else "Collapsed to assembled"))
	view_hud.fit_requested.connect(func() -> void:
		camera.frame_selection_or_all(false)
		_on_status("Framed selection" if view.selected_body != "" else "Framed all"))
	view_hud.save_view_requested.connect(_on_save_named_view)
	view_hud.view_restore_requested.connect(func(view_name: String) -> void:
		if camera.restore_named_view(view_name):
			_on_status("Restored view “%s”" % view_name)
		else:
			_on_status("No saved view “%s”" % view_name))
	view_hud.view_delete_requested.connect(func(view_name: String) -> void:
		if camera.remove_named_view(view_name):
			view_hud.sync_named_views(camera.named_view_list())
			_on_status("Deleted view “%s”" % view_name)
		else:
			_on_status("No saved view “%s”" % view_name))
	view_hud.default_view_requested.connect(_on_default_view)
	# Fusion mouse bindings are the only supported preset (no menu).
	camera.nav_preset = OrbitCamera.NavPreset.FUSION
	view_hud.sync_from_view(view)
	view_hud.sync_named_views(camera.named_view_list())

	# Left, below palette: feature timeline + variables.
	timeline = TimelinePanel.new()
	timeline.name = "Timeline"
	timeline.view = view
	timeline.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	timeline.anchor_top = 1.0
	timeline.offset_left = 12
	timeline.offset_top = -420
	timeline.offset_bottom = -42
	ui.add_child(timeline)
	timeline.status.connect(_on_status)
	timeline.feature_selected.connect(_on_timeline_feature_selected)

	variables_panel = VariablesPanel.new()
	variables_panel.name = "Variables"
	variables_panel.view = view
	variables_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	variables_panel.anchor_top = 1.0
	variables_panel.offset_left = 280
	variables_panel.offset_right = 540
	variables_panel.offset_top = -420
	# Ends above the bottom status bar (+ occasional transform fine-tune blanks).
	variables_panel.offset_bottom = -140
	ui.add_child(variables_panel)
	variables_panel.status.connect(_on_status)

	# Bottom: status bar.
	var status_bar := PanelContainer.new()
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.anchor_top = 1.0
	status_bar.offset_top = -30
	ui.add_child(status_bar)
	status_label = Label.new()
	status_label.text = "empty-drag / Alt-drag / two-finger orbit · middle / 3-finger pan · wheel zoom · F fit · 1/2/3/7 views · click select · drag to move · drag face to push/pull · Del delete · Ctrl+Z/Y undo · Ctrl+S save"
	status_label.add_theme_font_size_override("font_size", 12)
	status_bar.add_child(status_label)

	# Compact left-rail sketch primaries (icons only); variants live on-canvas.
	sketch_toolbar = PanelContainer.new()
	sketch_toolbar.name = "SketchTools"
	sketch_toolbar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sketch_toolbar.position = Vector2(_CHROME_PAD, _RAIL_TOP)
	sketch_toolbar.custom_minimum_size = Vector2(_RAIL_ICON_W, 0)
	sketch_toolbar.visible = false
	ui.add_child(sketch_toolbar)
	var sk_scroll := ScrollContainer.new()
	sk_scroll.custom_minimum_size = Vector2(_RAIL_ICON_W, 560)
	sk_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sketch_toolbar.add_child(sk_scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sk_scroll.add_child(rows)
	var exit_btn := UIIcons.button("cancel", "",
		"Exit Sketch: save and return to the previous view")
	exit_btn.pressed.connect(func() -> void: sketch_mode.exit_sketch())
	rows.add_child(exit_btn)
	rows.add_child(HSeparator.new())
	for entry in [
			[SketchMode.Tool.SELECT, "select", "Select (S)"],
			[SketchMode.Tool.LINE, "line", "Line / centerline (L)"],
			[SketchMode.Tool.ARC, "arc", "Arc tool (A)"],
			[SketchMode.Tool.CIRCLE, "circle", "Circle (C)"],
			[SketchMode.Tool.RECT, "rect", "Rectangle (R)"],
			[SketchMode.Tool.POLYGON, "polygon", "Polygon"],
			[SketchMode.Tool.ELLIPSE, "circle", "Ellipse (approx)"],
			[SketchMode.Tool.SLOT, "rect", "Straight slot"],
			[SketchMode.Tool.SPLINE, "spline", "Fit spline"],
			[SketchMode.Tool.POINT, "point", "Sketch point"],
			[SketchMode.Tool.TRIM, "trim", "Power Trim (T)"],
			[SketchMode.Tool.EXTEND, "extend", "Extend to next"],
			[SketchMode.Tool.SMART_DIM, "dimension", "Smart Dimension (D)"],
			[SketchMode.Tool.CONVERT, "convert", "Convert entities"],
			[SketchMode.Tool.MIRROR, "mirror", "Mirror selection"],
			[SketchMode.Tool.PATTERN, "pattern", "Linear / circular pattern"],
			]:
		var b := UIIcons.button(entry[1], "", entry[2])
		b.pressed.connect(sketch_mode.set_tool.bind(entry[0]))
		rows.add_child(b)
	# Icon-only like the rest of the rail — a text label widens the 44px
	# column into the finish-bar dim blank (layout suite).
	var auto_def := UIIcons.button("dimension", "",
		"Auto-define — promote weak dims until DOF 0")
	auto_def.name = "AutoDefine"
	auto_def.pressed.connect(func() -> void: sketch_mode.auto_define())
	rows.add_child(auto_def)
	rows.add_child(HSeparator.new())
	dof_label = Label.new()
	dof_label.text = "—"
	dof_label.tooltip_text = "Sketch degrees of freedom (0 = fully constrained)"
	dof_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dof_label.add_theme_font_size_override("font_size", 10)
	rows.add_child(dof_label)
	var snap_toggle := CheckBox.new()
	snap_toggle.text = ""
	snap_toggle.tooltip_text = "Snap to grid / endpoints"
	snap_toggle.button_pressed = sketch_mode.snap_enabled
	snap_toggle.toggled.connect(sketch_mode.set_snap)
	rows.add_child(snap_toggle)
	var infer_toggle := CheckBox.new()
	infer_toggle.text = ""
	infer_toggle.tooltip_text = "Infer constraints while drawing"
	infer_toggle.button_pressed = sketch_mode.infer_enabled
	infer_toggle.toggled.connect(sketch_mode.set_infer)
	rows.add_child(infer_toggle)
	# Kept for tests / voice that still read these nodes.
	dim_value = SpinBox.new()
	dim_value.visible = false
	dim_value.min_value = 0.01
	dim_value.max_value = 10000
	dim_value.step = 0.5
	dim_value.value = 10
	rows.add_child(dim_value)
	extrude_distance = SpinBox.new()
	extrude_distance.visible = false
	extrude_distance.min_value = -1000
	extrude_distance.max_value = 1000
	extrude_distance.step = 1
	extrude_distance.value = 20
	rows.add_child(extrude_distance)
	finish_op = OptionButton.new()
	finish_op.visible = false
	for op_name in ["New", "Cut", "Fuse"]:
		finish_op.add_item(op_name)
	rows.add_child(finish_op)

	# On-canvas sketch chips (variants, selection actions, finish).
	sketch_chrome = SketchContextChrome.new()
	sketch_chrome.name = "SketchContextChrome"
	sketch_chrome.sketch_mode = sketch_mode
	sketch_chrome.visible = false
	ui.add_child(sketch_chrome)
	sketch_chrome.variant_chosen.connect(_on_sketch_variant)
	sketch_chrome.action_chosen.connect(_on_sketch_action)
	sketch_chrome.finish_requested.connect(_on_sketch_finish)
	sketch_chrome.dim_submitted.connect(_on_sketch_dim_submitted)
	sketch_mode.preview_distance_changed.connect(_on_sketch_preview_distance)
	interaction.sketch_chrome = sketch_chrome

	view.selection_changed.connect(_on_selection_changed)
	view.document_changed.connect(_on_document_changed)
	interaction.place_changed.connect(func(_active: bool) -> void: _update_left_rail())
	interaction.sketch_requested.connect(_request_sketch)
	interaction.sketch_host_picked.connect(_on_sketch_host_picked)
	interaction.sketch_pad_clicked.connect(_on_sketch_pad_clicked)
	interaction.paste_special_requested.connect(edit_paste_special)
	_update_panel_visibility()
	interaction.status.connect(_on_status)
	sketch_mode.status.connect(_on_status)
	sketch_mode.finished.connect(func(_id: String) -> void: _on_sketch_session_ended())
	sketch_mode.cancelled.connect(func() -> void: _on_sketch_session_ended())
	sketch_mode.selection_changed.connect(_on_sketch_selection)
	sketch_mode.solve_updated.connect(_on_sketch_solve)

	# Tone down wheel/trackpad jumps on docks and PopupMenus (~45% slower).
	UiScroll.soften_tree(ui)


func _on_default_view(view_id: String) -> void:
	# Immediate apply (no tween) so UI / tests see the pose right away.
	match view_id:
		"front":
			camera.set_view(deg_to_rad(0.0), deg_to_rad(0.0), false)
			_on_status("Front view")
		"right":
			camera.set_view(deg_to_rad(90.0), deg_to_rad(0.0), false)
			_on_status("Right view")
		"top":
			camera.set_view(deg_to_rad(0.0), deg_to_rad(89.0), false)
			_on_status("Top view")
		"iso":
			camera.set_view(deg_to_rad(-35.0), deg_to_rad(40.0), false)
			_on_status("Isometric view")
		_:
			_on_status("Unknown view “%s”" % view_id)


func _on_save_named_view(view_name: String) -> void:
	view_name = view_name.strip_edges()
	if view_name == "":
		return
	camera.save_named_view(view_name)
	view_hud.sync_named_views(camera.named_view_list())
	_on_status("Saved view “%s” — pick it under Views to restore" % view_name)


func _on_sketch_solve(dofs: int, solve_status: String, conflicts: int) -> void:
	if dof_label == null:
		return
	if conflicts > 0 or solve_status == "failed":
		dof_label.text = "!"
		dof_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
	elif dofs == 0:
		dof_label.text = "OK"
		dof_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	else:
		dof_label.text = "%d" % dofs
		dof_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	_on_sketch_selection_chips()


func _apply_constraint(type: String, value: float) -> void:
	var result := sketch_mode.constrain(type, value)
	if result == "":
		_on_status("Select entities with the Sel tool first (%s)" % type)
	else:
		_on_status("%s: %s" % [type, result])


func _apply_dimension() -> void:
	var kind := "distance"
	if sketch_mode.selected.size() == 1:
		var t: String = sketch_mode.sketch.entity_info(sketch_mode.selected[0]).get("type", "")
		if t == "circle" or t == "arc":
			kind = "radius"
	_apply_constraint(kind, dim_value.value)


func _on_sketch_selection(ids: Array) -> void:
	var v := sketch_mode.measured_value()
	if v > 0.0:
		dim_value.value = v
	if ids.is_empty():
		_on_status("Sketch selection cleared")
	else:
		_on_status("%d sketch entities selected" % ids.size())


func _build_autosave() -> void:
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_autosave)
	add_child(autosave_timer)


func _autosave() -> void:
	if view.doc.revision() == _last_saved_revision:
		return
	var path := ProjectSettings.globalize_path("user://autosave.sxp")
	if view.save(path):
		_last_saved_revision = view.doc.revision()


func _request_sketch() -> void:
	# Fast path: face already selected → start immediately; else arm pick mode.
	if sketch_mode.active:
		return
	if view.selected_face != "":
		_start_sketch_on_face(view.selected_face, view.selected_body)
		return
	interaction.arm_pick_sketch_host()


## Compatibility entry for tests / callers that skip the pick-host step.
func _start_sketch() -> void:
	if sketch_mode.active:
		return
	if view.selected_face != "":
		_start_sketch_on_face(view.selected_face, view.selected_body)
	else:
		_start_sketch_on_ground()


## Explicit plane (films / path legs) — same chrome as ground/face entry.
func _start_sketch_on_plane(origin: Vector3, x_dir: Vector3, y_dir: Vector3) -> void:
	if sketch_mode.active:
		return
	if sketch_mode.begin_on_plane(origin, x_dir, y_dir):
		_on_sketch_session_started("Sketch on plane")


func _on_sketch_host_picked(kind: String, face_id: String, body_id: String, pad_fid: String) -> void:
	if kind == "pad" and pad_fid != "":
		_on_sketch_pad_clicked(pad_fid, false)
	elif kind == "face":
		_start_sketch_on_face(face_id, body_id)
	else:
		_start_sketch_on_ground()


func _on_sketch_pad_clicked(fid: String, additive: bool = false) -> void:
	if sketch_mode.active:
		return
	# Ctrl/Cmd+click accumulates pads for Merge sketches… (SW 3D-sketch substitute).
	var multi := additive or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if multi:
		if fid in selected_sketch_pads:
			selected_sketch_pads.erase(fid)
		else:
			selected_sketch_pads.append(fid)
		_refresh_merge_chrome()
		_on_status("%d sketch pad(s) selected — Merge sketches…" % selected_sketch_pads.size())
		return
	selected_sketch_pads.clear()
	if sketch_chrome != null:
		sketch_chrome.hide_selection_actions()
	if sketch_mode.begin_edit(fid):
		_on_sketch_session_started("Editing sketch")
		view.refresh_sketch_pads(sketch_mode.editing_fid)


func _refresh_merge_chrome() -> void:
	if sketch_chrome == null:
		return
	var actions := _sketch_to_3d_actions()
	if actions.is_empty():
		sketch_chrome.hide_selection_actions()
		if not sketch_mode.active:
			sketch_chrome.visible = false
		return
	sketch_chrome.visible = true
	sketch_chrome.show_sketch_to_3d_menu(actions, get_viewport().get_mouse_position())


## Classify a committed sketch pad for multi-sketch → 3D workflows.
func _sketch_pad_role(fid: String) -> String:
	var sk: SxSketch = view.doc.graph_get_sketch(fid)
	if sk == null:
		return "unknown"
	var has_circle := false
	var line_count := 0
	for id in sk.entity_ids():
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"circle":
				has_circle = true
			"line", "arc":
				line_count += 1
	if has_circle:
		return "profile"
	if line_count >= 1:
		return "rail"
	return "unknown"


func _latest_path_fid() -> String:
	var feats: Array = view.doc.graph_features()
	for i in range(feats.size() - 1, -1, -1):
		if str(feats[i].get("type", "")) == "path":
			return str(feats[i].get("id", ""))
	return ""


func _sketch_to_3d_actions() -> Array:
	var actions: Array = []
	var n := selected_sketch_pads.size()
	if n == 0:
		return actions
	var profiles := 0
	var rails := 0
	for fid in selected_sketch_pads:
		match _sketch_pad_role(fid):
			"profile":
				profiles += 1
			"rail":
				rails += 1
	if n >= 2 and rails >= 1:
		actions.append("merge_join")
		actions.append("merge_spline")
		actions.append("merge_composite")
	if n >= 2 and profiles >= 2 and rails == 0:
		actions.append("loft_ruled")
		actions.append("loft_smooth")
	if n == 1 and profiles == 1:
		var path_fid := selected_path_fid if selected_path_fid != "" else _latest_path_fid()
		if path_fid != "":
			actions.append("sweep_path")
	if actions.is_empty() and n >= 2:
		# Mixed or unknown — offer everything.
		actions.append("merge_join")
		actions.append("merge_spline")
		actions.append("loft_ruled")
	if not actions.is_empty():
		actions.append("merge_clear")
	return actions


func _on_timeline_feature_selected(fid: String, ftype: String) -> void:
	if ftype == "path":
		selected_path_fid = fid
		_on_status("Path selected — Ctrl+click a profile pad, then Sweep along path")
	else:
		selected_path_fid = ""
	_refresh_merge_chrome()


func _loft_selected_sketches(ruled: bool) -> void:
	if selected_sketch_pads.size() < 2:
		_on_status("Select 2+ closed profile pads (Ctrl+click) to loft")
		return
	var fids := PackedStringArray()
	for fid in selected_sketch_pads:
		fids.append(fid)
	var loft_fid: String = view.doc.graph_add_loft(fids, ruled)
	if loft_fid == "":
		_on_status("Loft failed — need closed profiles on separate planes")
		return
	selected_sketch_pads.clear()
	selected_path_fid = ""
	_refresh_merge_chrome()
	_on_status("Loft solid created (%s)" % ("ruled" if ruled else "smooth"))
	view.refresh()
	_on_document_changed()


func _sweep_profile_along_path() -> void:
	if selected_sketch_pads.size() != 1:
		_on_status("Ctrl+click exactly one profile pad, then Sweep along path")
		return
	var prof_fid: String = selected_sketch_pads[0]
	if _sketch_pad_role(prof_fid) != "profile":
		_on_status("Selected pad is not a closed profile (try a circle)")
		return
	var path_fid := selected_path_fid if selected_path_fid != "" else _latest_path_fid()
	if path_fid == "":
		_on_status("Create a Path first (merge open rails) or select a Path row on the timeline")
		return
	var sw_fid: String = view.doc.graph_add_sweep_along_path(prof_fid, path_fid)
	if sw_fid == "":
		_on_status("Sweep along path failed")
		return
	selected_sketch_pads.clear()
	_refresh_merge_chrome()
	_on_status("Sweep solid created along path")
	view.refresh()
	_on_document_changed()


func _merge_selected_sketches(mode: String) -> void:
	if selected_sketch_pads.size() < 2:
		_on_status("Select 2+ sketch pads (Ctrl+click) to merge")
		return
	var fids := PackedStringArray()
	for fid in selected_sketch_pads:
		fids.append(fid)
	var path_fid: String = view.doc.graph_add_path(fids, mode)
	if path_fid == "":
		_on_status("Merge sketches failed")
		return
	selected_sketch_pads.clear()
	selected_path_fid = path_fid
	_refresh_merge_chrome()
	_on_status("Path created — Ctrl+click profile pad, then Sweep along path")
	view.refresh()
	_on_document_changed()


func _on_sketch_action(action: String) -> void:
	match action:
		"merge_join":
			_merge_selected_sketches("join_endpoints")
			return
		"merge_spline":
			_merge_selected_sketches("bridge_spline")
			return
		"merge_composite":
			_merge_selected_sketches("composite")
			return
		"merge_clear":
			selected_sketch_pads.clear()
			_refresh_merge_chrome()
			return
		"loft_ruled":
			_loft_selected_sketches(true)
			return
		"loft_smooth":
			_loft_selected_sketches(false)
			return
		"sweep_path":
			_sweep_profile_along_path()
			return
		"fillet":
			sketch_mode.fillet_selected(sketch_chrome.dim_value() if sketch_chrome else 2.0)
		"chamfer":
			sketch_mode.chamfer_selected(sketch_chrome.dim_value() if sketch_chrome else 2.0)
		"offset":
			sketch_mode.offset_selected(sketch_chrome.dim_value() if sketch_chrome else 2.0)
		"construction":
			sketch_mode.toggle_construction_selected()
		"delete":
			sketch_mode.delete_selected_entities()
		"split":
			if not sketch_mode.selected.is_empty():
				var info: Dictionary = sketch_mode.sketch.entity_info(sketch_mode.selected[0])
				if info.get("type") == "line":
					var mid: Vector2 = (info["start"] + info["end"]) * 0.5
					sketch_mode.split_at(mid)
		"pattern":
			sketch_mode.pattern_selected(10.0, 0.0, 3)
		"mirror":
			sketch_mode.mirror_selected()
		"block":
			sketch_mode.create_block("Block%d" % (sketch_mode.blocks.size() + 1))
		"dimension":
			_apply_dimension_from_chrome()
		"revolve":
			sketch_mode.finish_revolve(TAU, _finish_op_name())
		"horizontal", "vertical", "parallel", "perpendicular", "equal", "coincident", \
		"tangent", "midpoint", "symmetric", "concentric", "collinear":
			_apply_constraint(action, 0.0)
		"parallel?", "perpendicular?", "equal?":
			var verb := action.trim_suffix("?")
			var cid := sketch_mode.promote_propose(verb)
			_on_status("Proposed %s" % verb if cid != "" else "Nothing to propose")
		_:
			_on_status("Sketch action: %s" % action)


func _start_sketch_on_face(face_id: String, body_id: String) -> void:
	var origin := Vector3.ZERO
	var normal := Vector3(0, 0, 1)
	var plane_msg := "Sketch on ground (XY)"
	sketch_mode.target_fid = ""
	if face_id != "" and body_id != "":
		sketch_mode.target_fid = view.feature_of_body(body_id)
		var fn := view.face_normal(body_id, face_id)
		var plane: Dictionary = SketchMode.derive_face_plane(
			view.doc, face_id, body_id, fn)
		plane_msg = plane["message"]
		if plane["ok"]:
			origin = plane["origin"]
			normal = plane["normal"]
	sketch_mode.begin(origin, normal)
	_on_sketch_session_started(plane_msg)


func _start_sketch_on_ground() -> void:
	sketch_mode.target_fid = ""
	sketch_mode.begin(Vector3.ZERO, Vector3(0, 0, 1))
	_on_sketch_session_started("Sketch on ground (XY)")


func _on_sketch_session_started(msg: String) -> void:
	_update_panel_visibility()
	_sync_world_background()
	interaction.refresh_selection_chrome()
	interaction.refresh_sketch_intersections()
	if dof_label != null:
		dof_label.text = "— DOF"
		dof_label.remove_theme_color_override("font_color")
	view.refresh_sketch_pads(sketch_mode.editing_fid if sketch_mode.editing_fid != "" else "_active")
	if sketch_chrome != null:
		sketch_chrome.visible = true
		sketch_chrome.show_for_session(true)
	if not sketch_mode.tool_changed.is_connected(_on_sketch_tool_changed):
		sketch_mode.tool_changed.connect(_on_sketch_tool_changed)
	if not sketch_mode.selection_actions_needed.is_connected(_on_sketch_selection_chips):
		sketch_mode.selection_actions_needed.connect(_on_sketch_selection_chips)
	_on_status(msg)


func _on_sketch_session_ended() -> void:
	_update_panel_visibility()
	_sync_world_background()
	interaction.refresh_selection_chrome()
	view.refresh_sketch_pads("")
	if sketch_chrome != null:
		sketch_chrome.show_for_session(false)
		sketch_chrome.hide_variants()
		sketch_chrome.hide_selection_actions()
		sketch_chrome.visible = false


func _on_sketch_tool_changed(tool: int) -> void:
	if sketch_chrome == null:
		return
	var variants: Array = sketch_mode.variants_for_tool(tool as SketchMode.Tool)
	if variants.is_empty():
		sketch_chrome.hide_variants()
	else:
		var mouse := get_viewport().get_mouse_position()
		sketch_chrome.show_variants(_variant_kind_for(tool), variants, mouse)


func _variant_kind_for(tool: int) -> String:
	match tool as SketchMode.Tool:
		SketchMode.Tool.RECT: return "rect"
		SketchMode.Tool.CIRCLE: return "circle"
		SketchMode.Tool.ARC: return "arc"
		SketchMode.Tool.PATTERN: return "pattern"
		SketchMode.Tool.LINE, SketchMode.Tool.CENTERLINE: return "line"
		_: return ""


func _on_sketch_selection_chips() -> void:
	if sketch_chrome == null or not sketch_mode.active:
		return
	var acts: Array = sketch_mode.selection_actions()
	for verb in sketch_mode.propose_verbs():
		if verb not in acts:
			acts.append(verb)
	if acts.is_empty():
		sketch_chrome.hide_selection_actions()
	else:
		# Keep chips off the 44px icon rail and the finish bar at (60, 42).
		var mouse := get_viewport().get_mouse_position()
		var pos := mouse if mouse.x > 56.0 else Vector2(60, 80)
		sketch_chrome.show_selection_actions(acts, pos)


func _on_sketch_variant(kind: String, variant: String) -> void:
	if kind == "line":
		if variant == "centerline":
			sketch_mode.set_tool(SketchMode.Tool.CENTERLINE)
		else:
			sketch_mode.set_tool(SketchMode.Tool.LINE)
		return
	sketch_mode.set_tool_variant(variant)


func _apply_dimension_from_chrome() -> void:
	var v: float = sketch_chrome.dim_value() if sketch_chrome else dim_value.value
	dim_value.value = v
	_apply_dimension()


func _on_sketch_preview_distance(distance: float) -> void:
	if sketch_chrome == null or distance <= 0.0:
		return
	sketch_chrome.set_dim_value(distance)
	dim_value.value = distance


func _on_sketch_dim_submitted(value: float) -> void:
	dim_value.value = value
	if sketch_mode != null and sketch_mode.active \
			and sketch_mode.has_single_dof_preview():
		if sketch_mode.commit_at_length(value):
			_on_status("Length %.4g mm" % value)
			if sketch_chrome != null:
				sketch_chrome.release_dim_focus()
			return
	_apply_dimension()


func _on_sketch_finish(op: String, distance: float) -> void:
	extrude_distance.value = distance
	match op:
		"cut": finish_op.selected = 1
		"fuse": finish_op.selected = 2
		_: finish_op.selected = 0
	sketch_mode.finish_extrude(distance, op)


func _selected_entity() -> String:
	return view.selected_face if view.selected_face != "" else view.selected_body


func _save_card_text(alias_text: String, notes_text: String) -> void:
	var target := _selected_entity()
	if target == "":
		return
	view.doc.set_card_alias(target, alias_text)
	view.doc.set_card_notes(target, notes_text)
	card_panel.text = view.selection_card()
	_on_status("Card text saved")


func _on_selection_changed(_body: String, _face: String) -> void:
	var md := view.selection_card()
	card_panel.text = md if md != "" else "[i]nothing selected[/i]"
	var target := _selected_entity()
	alias_edit.text = view.doc.get_card_alias(target) if target != "" else ""
	notes_edit.text = view.doc.get_card_notes(target) if target != "" else ""
	alias_edit.editable = target != ""
	notes_edit.editable = target != ""
	_update_panel_visibility()
	if view_hud != null:
		view_hud.sync_from_view(view)


func _on_document_changed() -> void:
	_on_selection_changed(view.selected_body, view.selected_face)


## Context panels only occupy screen space while they have content: the
## selection card follows the selection, the timeline appears with the first
## feature, and the variables table shows once a variable exists (or is
## forced on from the View menu so there's an entry point to create one).
## The left rail swaps Primitives ↔ Modify tools so create chrome hides while
## a body is selected (place mode keeps the palette so you can still create).
func _update_panel_visibility() -> void:
	var sketching := sketch_mode != null and sketch_mode.active
	card_box.visible = _selected_entity() != "" and not sketching
	timeline.visible = view.doc.graph_features().size() > 0 and not sketching
	variables_panel.visible = (show_variables or view.doc.list_variables().size() > 0) and not sketching
	# Keep the variables table flush against whatever is to its left.
	variables_panel.offset_left = 280 if timeline.visible else 12
	variables_panel.offset_right = variables_panel.offset_left + 260
	_update_left_rail()
	_schedule_card_dock()


func _on_mode_menu(id: int) -> void:
	var names := ["Model", "Draw", "Sheet", "Cam", "Sim", "Form"]
	if id < 0 or id >= names.size():
		return
	_work_mode = names[id]
	_on_status(_work_mode + " mode")
	_update_left_rail()
	_update_mode_overlays()


func _print_target() -> String:
	if view != null and view.selected_body != "":
		return view.selected_body
	if view != null and view.doc != null:
		var ids: PackedStringArray = view.doc.body_ids()
		if ids.size() > 0:
			return ids[0]
	return ""


func _on_print_analyze() -> void:
	if view == null or view.doc == null:
		return
	var r: Dictionary = view.doc.print_analyze(_print_target())
	var digest := str(r.get("digest", ""))
	if print_strip != null:
		print_strip.set_digest(digest)
	_on_status(digest if digest != "" else "Print check: nothing to analyze")
	if view.selected_body != "":
		card_panel.text = view.selection_card() + "\n\n" + digest


func _on_print_orient() -> void:
	if view == null or view.doc == null:
		return
	var r: Dictionary = view.doc.print_orient(_print_target())
	var digest := str(r.get("digest", ""))
	if print_strip != null:
		print_strip.set_digest(digest)
	_on_status("Oriented — " + digest)
	view.refresh()


func _update_left_rail() -> void:
	if palette == null or ops_panel == null:
		return
	var sketching := sketch_mode != null and sketch_mode.active
	if sketch_toolbar != null:
		sketch_toolbar.visible = sketching
	if sketching:
		palette.visible = false
		ops_panel.visible = false
		return
	var placing := interaction != null and interaction.is_placing()
	var has_body := view.selected_body != ""
	# OpsPanel shows itself only when something is selected (same rule as before).
	ops_panel.visible = has_body
	# Selected body → Modify tools occupy the left palette slot.
	# Idle / place-armed → Primitives palette; OpsPanel stays on the right
	# (and hides itself when there is no selection).
	if _work_mode != "Model":
		# Specialized rails replace Modify — they do not stack a second dock.
		palette.visible = false
		ops_panel.visible = false
		return
	if has_body and not placing:
		palette.visible = false
		_dock_ops_left()
	else:
		palette.visible = true
		_dock_ops_right()


func _update_mode_overlays() -> void:
	if drawing_sheet != null:
		if _work_mode == "Draw" and view != null and view.doc != null:
			view.doc.ensure_drawing_sheet()
			view.doc.refresh_drawing_dims()
			drawing_sheet.set_preview(view.doc.drawing_preview())
		drawing_sheet.show_sheet(_work_mode == "Draw")
	if sheet_metal_view != null:
		var flat := 0.0
		if view != null and view.doc != null:
			flat = view.doc.sheet_flat_length(30.0, 30.0, 1.5, 0.44, 1.5)
		sheet_metal_view.show_split(_work_mode == "Sheet", flat, 0.44)
	if print_strip != null:
		print_strip.visible = _work_mode == "Form"


## Selection card sits under the visible left rail (palette / modify / sketch).
func _schedule_card_dock() -> void:
	# OpsPanel clamps height one frame after dock; wait so we measure the final rail.
	await get_tree().process_frame
	await get_tree().process_frame
	_dock_card_below_rail()


func _dock_card_below_rail() -> void:
	if card_box == null or not is_instance_valid(card_box):
		return
	var rail: Control = null
	if sketch_toolbar != null and sketch_toolbar.visible:
		rail = sketch_toolbar
	elif ops_panel != null and ops_panel.visible and ops_panel.anchor_left < 0.5:
		rail = ops_panel
	elif palette != null and palette.visible:
		rail = palette
	var top := _RAIL_TOP
	var width := _CARD_W
	if rail != null:
		rail.reset_size()
		var h := maxf(rail.size.y, rail.get_combined_minimum_size().y)
		top = rail.position.y + h + 6.0
		width = maxf(_CARD_W, rail.get_combined_minimum_size().x)
	var card_h := minf(_CARD_H, maxf(100.0, _LEFT_STACK_LIMIT - top))
	card_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_box.anchor_left = 0.0
	card_box.anchor_right = 0.0
	card_box.offset_left = _CHROME_PAD
	card_box.offset_right = _CHROME_PAD + width
	card_box.offset_top = top
	card_box.offset_bottom = top + card_h
	card_box.grow_horizontal = Control.GROW_DIRECTION_END


func _dock_ops_left() -> void:
	ops_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ops_panel.anchor_left = 0.0
	ops_panel.anchor_right = 0.0
	ops_panel.offset_left = _OPS_LEFT.offset_left
	ops_panel.offset_right = _OPS_LEFT.offset_right
	ops_panel.offset_top = _OPS_LEFT.offset_top
	ops_panel.grow_horizontal = Control.GROW_DIRECTION_END


func _dock_ops_right() -> void:
	ops_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ops_panel.anchor_left = 1.0
	ops_panel.anchor_right = 1.0
	ops_panel.offset_left = _OPS_RIGHT.offset_left
	ops_panel.offset_right = _OPS_RIGHT.offset_right
	ops_panel.offset_top = _OPS_RIGHT.offset_top
	ops_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _on_status(text: String) -> void:
	if text != "":
		status_label.text = text


func _build_paste_special_dialog(parent: Node) -> void:
	_paste_special_dialog = ConfirmationDialog.new()
	_paste_special_dialog.title = "Paste Special"
	_paste_special_dialog.ok_button_text = "Paste"
	_paste_special_dialog.dialog_hide_on_ok = true
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_paste_special_dialog.add_child(body)
	_paste_in_place = CheckBox.new()
	_paste_in_place.text = "In place (zero offset)"
	body.add_child(_paste_in_place)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	_paste_ox = _paste_spin(row, "ΔX", 0.0)
	_paste_oy = _paste_spin(row, "ΔY", 0.0)
	_paste_oz = _paste_spin(row, "ΔZ", 0.0)
	_paste_in_place.toggled.connect(func(on: bool) -> void:
		_paste_ox.editable = not on
		_paste_oy.editable = not on
		_paste_oz.editable = not on)
	_paste_special_dialog.confirmed.connect(_on_paste_special_confirmed)
	parent.add_child(_paste_special_dialog)


func _paste_spin(parent: Container, label: String, value: float) -> SpinBox:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var lbl := Label.new()
	lbl.text = label
	box.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = -1e6
	spin.max_value = 1e6
	spin.step = 0.1
	spin.value = value
	spin.suffix = "mm"
	spin.custom_minimum_size = Vector2(96, 0)
	box.add_child(spin)
	return spin


func _refresh_edit_menu() -> void:
	if _edit_popup == null:
		return
	var sketching := sketch_mode != null and sketch_mode.active
	var has_sel := false
	var has_clip := false
	if sketching:
		has_sel = not sketch_mode.selected.is_empty()
		has_clip = sketch_mode.has_entity_clipboard()
	else:
		has_sel = view != null and view.selection_size() > 0
		has_clip = view != null and view.has_clipboard()
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(0), view == null or not view.doc.can_undo())
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(1), view == null or not view.doc.can_redo())
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(2), not has_sel)
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(3), not has_sel)
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(4), not has_clip)
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(5), not has_clip or sketching)
	_edit_popup.set_item_disabled(_edit_popup.get_item_index(7), not has_sel)


func _on_edit_menu(id: int) -> void:
	match id:
		0: edit_undo()
		1: edit_redo()
		2: edit_cut()
		3: edit_copy()
		4: edit_paste()
		5: edit_paste_special()
		6: edit_select_all()
		7: edit_delete()


func edit_undo() -> void:
	if view == null:
		return
	view.undo()
	_on_status("Undo")
	if interaction != null:
		interaction._refresh_transform_hud()
		interaction._refresh_selection_strip()


func edit_redo() -> void:
	if view == null:
		return
	view.redo()
	_on_status("Redo")
	if interaction != null:
		interaction._refresh_transform_hud()
		interaction._refresh_selection_strip()


func edit_cut() -> void:
	if sketch_mode != null and sketch_mode.active:
		var n := sketch_mode.cut_selected_entities()
		_on_status("Cut %d sketch entities" % n if n > 0 else "Nothing to cut")
		return
	if view == null:
		return
	var n2 := view.cut_selection()
	_on_status("Cut %d" % n2 if n2 > 1 else ("Cut" if n2 == 1 else "Nothing to cut"))
	if interaction != null:
		interaction._refresh_transform_hud()
		interaction._refresh_selection_strip()


func edit_copy() -> void:
	if sketch_mode != null and sketch_mode.active:
		var n := sketch_mode.copy_selected_entities()
		_on_status("Copied %d sketch entities" % n if n > 0 else "Nothing to copy")
		return
	if view == null:
		return
	var n2 := view.copy_selection()
	_on_status("Copied %d" % n2 if n2 > 1 else ("Copied" if n2 == 1 else "Nothing to copy"))


func edit_paste() -> void:
	if sketch_mode != null and sketch_mode.active:
		var made: Array = sketch_mode.paste_entities()
		_on_status("Pasted %d sketch entities" % made.size() if not made.is_empty() else "Clipboard empty")
		return
	if view == null:
		return
	var created: Array = view.paste_clipboard()
	if created.is_empty():
		_on_status("Clipboard empty")
	else:
		_on_status("Pasted %d" % created.size() if created.size() > 1 else "Pasted")
	if interaction != null:
		interaction._refresh_transform_hud()
		interaction._refresh_selection_strip()


func edit_paste_special() -> void:
	if sketch_mode != null and sketch_mode.active:
		_on_status("Paste Special is for model bodies")
		return
	if view == null or not view.has_clipboard():
		_on_status("Clipboard empty")
		return
	var step := view.clipboard_paste_step()
	_paste_in_place.button_pressed = false
	_paste_ox.editable = true
	_paste_oy.editable = true
	_paste_oz.editable = true
	_paste_ox.value = step.x
	_paste_oy.value = step.y
	_paste_oz.value = step.z
	_paste_special_dialog.popup_centered()


func _on_paste_special_confirmed() -> void:
	if view == null:
		return
	var offset := Vector3.ZERO
	if not _paste_in_place.button_pressed:
		offset = Vector3(_paste_ox.value, _paste_oy.value, _paste_oz.value)
	var created: Array = view.paste_clipboard(offset)
	if created.is_empty():
		_on_status("Clipboard empty")
	else:
		_on_status("Paste Special → %d" % created.size() if created.size() > 1 else "Paste Special")
	if interaction != null:
		interaction._refresh_transform_hud()
		interaction._refresh_selection_strip()


func edit_select_all() -> void:
	if interaction != null:
		interaction._select_all()
	elif sketch_mode != null and sketch_mode.active:
		var n := sketch_mode.select_all_entities()
		_on_status("Selected %d sketch entities" % n if n > 0 else "No sketch entities")


func edit_delete() -> void:
	if sketch_mode != null and sketch_mode.active:
		if not sketch_mode.delete_selected_constraint():
			var n := sketch_mode.delete_selected_entities()
			_on_status("Deleted %d" % n if n > 0 else "Nothing to delete")
		return
	if interaction != null:
		interaction._delete_selection()


func _on_file_menu(id: int) -> void:
	match id:
		0:  # New
			_confirm_discard(_do_new)
		1:
			_confirm_discard(_do_open_dialog)
		2:
			_save_current()
		3:
			_show_file_dialog(FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
		4:
			_show_file_dialog(FileAction.IMPORT_STEP, FileDialog.FILE_MODE_OPEN_FILE, "*.step, *.stp ; STEP")
		9:
			_show_file_dialog(FileAction.IMPORT_STL, FileDialog.FILE_MODE_OPEN_FILE, "*.stl ; STL")
		5:
			_show_file_dialog(FileAction.EXPORT_STEP, FileDialog.FILE_MODE_SAVE_FILE, "*.step, *.stp ; STEP")
		6:
			_show_file_dialog(FileAction.EXPORT_STL, FileDialog.FILE_MODE_SAVE_FILE, "*.stl ; STL")
		7:
			_show_file_dialog(FileAction.EXPORT_CONTEXT, FileDialog.FILE_MODE_SAVE_FILE, "*.md ; Markdown")
		8:
			_show_file_dialog(FileAction.EXPORT_DRAWING, FileDialog.FILE_MODE_SAVE_FILE, "*.svg ; SVG drawing")
		10:
			_show_file_dialog(FileAction.IMPORT_DXF, FileDialog.FILE_MODE_OPEN_FILE, "*.dxf ; DXF")
		11:
			_show_file_dialog(FileAction.EXPORT_3MF, FileDialog.FILE_MODE_SAVE_FILE, "*.3mf ; 3MF")
		12:
			_show_file_dialog(FileAction.EXPORT_GLTF, FileDialog.FILE_MODE_SAVE_FILE, "*.gltf ; glTF")
		13:
			_show_file_dialog(FileAction.EXPORT_DRAWING_DXF, FileDialog.FILE_MODE_SAVE_FILE, "*.dxf ; DXF drawing")
		14:
			_show_file_dialog(FileAction.EXPORT_DRAWING_PDF, FileDialog.FILE_MODE_SAVE_FILE, "*.pdf ; PDF drawing")


func _do_new() -> void:
	view.new_document()
	current_path = ""
	_last_saved_revision = view.doc.revision()
	_on_status("New document")


func _do_open_dialog() -> void:
	_show_file_dialog(FileAction.OPEN, FileDialog.FILE_MODE_OPEN_FILE, "*.sxp ; SolidExpress")


func _document_is_dirty() -> bool:
	if view.doc.revision() == _last_saved_revision:
		return false
	return view.doc.body_ids().size() > 0 or view.doc.graph_features().size() > 0


func _confirm_discard(action: Callable) -> void:
	if not _document_is_dirty():
		action.call()
		return
	_pending_discard = action
	confirm_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	var action := _pending_discard
	_pending_discard = Callable()
	if action.is_valid():
		action.call()


func _load_recent() -> void:
	_recent.clear()
	var cfg := ConfigFile.new()
	if cfg.load(_RECENT_CFG) != OK:
		return
	var files: Variant = cfg.get_value("recent", "files", [])
	if files is Array:
		for p in files:
			if typeof(p) == TYPE_STRING and str(p) != "":
				_recent.append(str(p))
		if _recent.size() > 8:
			_recent.resize(8)


func _save_recent() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("recent", "files", _recent)
	cfg.save(_RECENT_CFG)


func _push_recent(path: String) -> void:
	if path == "":
		return
	_recent.erase(path)
	_recent.push_front(path)
	while _recent.size() > 8:
		_recent.pop_back()
	_save_recent()
	_rebuild_recent_menu()


func _rebuild_recent_menu() -> void:
	if _recent_menu == null:
		return
	_recent_menu.clear()
	for i in range(_recent.size()):
		_recent_menu.add_item(str(_recent[i]), i)
	if _recent.size() > 0:
		_recent_menu.add_separator()
	_recent_menu.add_item("Clear Recent", _RECENT_CLEAR_ID)


func _on_recent_menu(id: int) -> void:
	if id == _RECENT_CLEAR_ID:
		_recent.clear()
		_save_recent()
		_rebuild_recent_menu()
		return
	if id < 0 or id >= _recent.size():
		return
	var path: String = str(_recent[id])
	if not FileAccess.file_exists(path):
		_recent.remove_at(id)
		_save_recent()
		_rebuild_recent_menu()
		_on_status("Missing file removed from recent: " + path)
		return
	_confirm_discard(func() -> void: _open_document(path))


func _open_document(path: String) -> void:
	if view.load_from(path):
		current_path = path
		_last_saved_revision = view.doc.revision()
		_push_recent(path)
		_on_status("Opened " + path)
	else:
		_on_status("Open failed: " + path)


func _on_insert_menu(id: int) -> void:
	if id == 10:
		_show_file_dialog(FileAction.INSERT_SXP, FileDialog.FILE_MODE_OPEN_FILE,
			"*.sxp ; SolidExpress")
		return
	var did := ""
	match id:
		0: did = view.doc.add_datum_plane(Vector3.ZERO, Vector3(0, 0, 1))
		1: did = view.doc.add_datum_plane(Vector3.ZERO, Vector3(0, 1, 0))
		2: did = view.doc.add_datum_plane(Vector3.ZERO, Vector3(1, 0, 0))
		3: did = view.doc.add_datum_axis(Vector3.ZERO, Vector3(1, 0, 0))
		4: did = view.doc.add_datum_axis(Vector3.ZERO, Vector3(0, 1, 0))
		5: did = view.doc.add_datum_axis(Vector3.ZERO, Vector3(0, 0, 1))
		6: did = view.doc.add_datum_point(Vector3.ZERO)
	if did != "":
		view.graph_changed()
		_on_status("Datum added")
	else:
		_on_status("Datum creation failed")


## Insert Components (multi-doc .sxp): copy bodies + place instances; hide the
## embedded source bodies so only the placed components show (SolidWorks-like).
func insert_components_from(path: String, translation := Vector3.ZERO) -> bool:
	var result: Dictionary = view.doc.insert_sxp(path, translation)
	if not bool(result.get("ok", false)):
		_on_status("Insert failed: " + str(result.get("error", path)))
		return false
	var bodies: PackedStringArray = result.get("body_ids", PackedStringArray())
	for bid in bodies:
		view.set_body_hidden(str(bid), true)
	view.refresh()
	view.graph_changed()
	var n: int = result.get("instance_ids", PackedStringArray()).size()
	_on_status("Inserted %d component(s) from %s" % [n, path.get_file()])
	return true


func _show_file_dialog(action: FileAction, mode: FileDialog.FileMode, filter: String) -> void:
	_file_action = action
	file_dialog.file_mode = mode
	file_dialog.filters = PackedStringArray([filter])
	file_dialog.popup_centered()


func _save_current() -> void:
	if current_path == "":
		_show_file_dialog(FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
		return
	if view.save(current_path):
		_last_saved_revision = view.doc.revision()
		_push_recent(current_path)
		_on_status("Saved " + current_path)
	else:
		_on_status("Save FAILED: " + current_path)


func _on_file_selected(path: String) -> void:
	var action := _file_action
	_file_action = FileAction.NONE
	match action:
		FileAction.OPEN:
			_open_document(path)
		FileAction.SAVE_AS:
			if not path.ends_with(".sxp"):
				path += ".sxp"
			current_path = path
			_save_current()
		FileAction.IMPORT_STEP:
			_import_step_file(path)
		FileAction.IMPORT_STL:
			_import_stl_file(path)
		FileAction.EXPORT_STEP:
			_on_status("Exported STEP" if view.doc.export_step(path) else "STEP export failed")
		FileAction.EXPORT_STL:
			_on_status("Exported STL" if view.doc.export_stl(path, true) else "STL export failed")
		FileAction.EXPORT_CONTEXT:
			if not path.ends_with(".md"):
				path += ".md"
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(view.doc.export_context())
				f.close()
				_on_status("Exported AI context: " + path)
			else:
				_on_status("Context export failed: " + path)
		FileAction.EXPORT_DRAWING:
			if not path.ends_with(".svg"):
				path += ".svg"
			if view.doc.export_drawing_svg(path, 1.0):
				_on_status("Exported drawing: " + path)
			else:
				_on_status("Drawing export failed (empty document?)")
		FileAction.INSERT_SXP:
			insert_components_from(path)
		FileAction.IMPORT_DXF:
			var fid: String = view.doc.import_dxf(path)
			if fid == "":
				_on_status("DXF import failed")
			else:
				view.graph_changed()
				_on_status("Imported DXF sketch")
		FileAction.EXPORT_3MF:
			_on_status("Exported 3MF" if view.doc.export_3mf(path) else "3MF export failed")
		FileAction.EXPORT_GLTF:
			_on_status("Exported glTF" if view.doc.export_gltf(path) else "glTF export failed")
		FileAction.EXPORT_DRAWING_DXF:
			if not path.ends_with(".dxf"):
				path += ".dxf"
			_on_status("Exported DXF" if view.doc.export_drawing_dxf(path) else "DXF export failed")
		FileAction.EXPORT_DRAWING_PDF:
			if not path.ends_with(".pdf"):
				path += ".pdf"
			_on_status("Exported PDF" if view.doc.export_drawing_pdf(path) else "PDF export failed")


## OS drag-and-drop onto the window (STL / SVG / STEP / .sxp).
func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	# Prefer the first recognized file; multi-drop imports STL/STEP in order.
	var handled := 0
	for path in files:
		var lower := path.to_lower()
		if lower.ends_with(".sxp"):
			_confirm_discard(func() -> void: _open_document(path))
			return
		if lower.ends_with(".stl"):
			if _import_stl_file(path):
				handled += 1
		elif lower.ends_with(".step") or lower.ends_with(".stp"):
			if _import_step_file(path):
				handled += 1
		elif lower.ends_with(".svg"):
			if _import_svg_to_surface(path):
				handled += 1
		elif lower.ends_with(".dxf"):
			if view.doc.import_dxf(path) != "":
				view.graph_changed()
				handled += 1
				_on_status("Imported DXF")
		else:
			_on_status("Unsupported drop: " + path.get_file())
	if handled == 0 and files.size() > 0:
		pass  # status already set per-file / unsupported
	elif handled > 1:
		_on_status("Imported %d files" % handled)


func _import_step_file(path: String) -> bool:
	var fid: String = view.doc.graph_add_import_step(path, 1.0)
	if fid == "":
		# Fallback: direct import when graph add fails.
		var ids: PackedStringArray = view.doc.import_step(path)
		view.graph_changed()
		if ids.is_empty():
			_on_status("STEP import failed")
			return false
		view.select_entity(ids[0], "")
		_after_import_select(ids[0], "")
		_on_status("Imported STEP (%d bodies)" % ids.size())
		return true
	view.graph_changed()
	var body := view.body_of_feature(fid)
	_after_import_select(body, fid)
	_on_status("Imported STEP — adjust Scale in the HUD / properties")
	return body != ""


func _import_stl_file(path: String) -> bool:
	var fid: String = view.doc.graph_add_import_stl(path, 1.0)
	if fid == "":
		var ids: PackedStringArray = view.doc.import_stl(path)
		view.graph_changed()
		if ids.is_empty():
			_on_status("STL import failed")
			return false
		_after_import_select(ids[0], "")
		_on_status("Imported STL mesh")
		return true
	view.graph_changed()
	var body := view.body_of_feature(fid)
	_after_import_select(body, fid)
	_on_status("Imported STL — one body selected; edit Scale to fit")
	return body != ""


## After mesh/STEP import: select the whole body (one selection) and surface scale UI.
func _after_import_select(body: String, fid: String) -> void:
	if body != "":
		view.select_entity(body, "")
		camera.frame_selection()
	if fid != "" and timeline != null and timeline.property_panel != null:
		timeline.property_panel.open(fid)


## Drop SVG onto a face under the cursor (or ground) as a sketch picture underlay.
func _import_svg_to_surface(path: String) -> bool:
	var tex := _load_svg_texture(path)
	if tex == null:
		_on_status("SVG load failed: " + path.get_file())
		return false
	var face := ""
	var body := ""
	if interaction != null:
		var hit := _pick_under_cursor()
		face = str(hit.get("face", ""))
		body = str(hit.get("body", ""))
	if sketch_mode.active:
		# Already sketching — replace underlay on the current plane.
		var sz := _svg_size_for_current_surface(face, body, tex)
		sketch_mode.set_sketch_picture(tex, sz)
		_on_status("SVG underlay on sketch (%.0f × %.0f mm) — scale via picture size" % [sz.x, sz.y])
		return true
	if face != "" and body != "":
		_start_sketch_on_face(face, body)
	else:
		_start_sketch_on_ground()
	var size := _svg_size_for_current_surface(face, body, tex)
	sketch_mode.set_sketch_picture(tex, size)
	_on_status("SVG on surface (%.0f × %.0f mm) — edit size to scale" % [size.x, size.y])
	return true


func _pick_under_cursor() -> Dictionary:
	if interaction == null or view == null:
		return {}
	var screen := get_viewport().get_mouse_position()
	var ray: Array = interaction._model_ray(screen)
	if ray.size() < 2:
		return {}
	return view.doc.pick(ray[0], ray[1])


func _load_svg_texture(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var svg := f.get_as_text()
	f.close()
	if svg.is_empty():
		return null
	var img := Image.new()
	# Rasterize large enough for crisp underlay at typical sketch scales.
	if img.load_svg_from_string(svg, 4.0) != OK:
		return null
	return ImageTexture.create_from_image(img)


## Fit SVG underlay to ~80% of the host face AABB (or a 100 mm default on ground).
func _svg_size_for_current_surface(face: String, body: String, tex: Texture2D) -> Vector2:
	var aspect := 1.0
	if tex != null and tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var base := 100.0
	if face != "" and body != "":
		var bb: Dictionary = view.doc.measure_bbox(body)
		if not bb.is_empty():
			var s: Vector3 = bb["max"] - bb["min"]
			base = maxf(10.0, minf(s.x, minf(s.y, s.z)) * 0.8)
	var w := base
	var h := base
	if aspect >= 1.0:
		h = base / aspect
	else:
		w = base * aspect
	return Vector2(w, h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_discard(func() -> void: get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				_save_current()
			KEY_O:
				_confirm_discard(_do_open_dialog)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		help_overlay.toggle()
		get_viewport().set_input_as_handled()
