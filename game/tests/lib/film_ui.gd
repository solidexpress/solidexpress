class_name FilmUI
extends RefCounted

const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

## Drive films / UI smoke tests only through visible, clickable controls and
## viewport pointer events — the same path a user takes.
##
## Rules:
## - Cue the pointer, then `pressed.emit()` on a *visible* Button / PaletteButton.
## - Sketch points, pads, and ground/face picks go through Interaction `_input`.
## - Never call private/session APIs (`_start_sketch`, `sm.click`, `sm.set_tool`,
##   `begin_on_plane`, `_on_sketch_action`, …) as a silent fallback.
## - Pointer / click targets must stay inside the visible viewport (offscreen = fail).
## Kernel / validation scripts (`run_*_tests.gd`) may call those APIs directly.

## Incremented by `_fail`; UI test runners treat a non-zero count as failure.
static var fail_count := 0


static func reset_fail_count() -> void:
	fail_count = 0


## Headless Godot defaults to ~64²; force a real window so palette / chrome
## clicks and model picks stay on-screen (offscreen cursor is a hard fail).
## On a real display, also tuck the window away so movie / UI runners do not
## leap onto the desktop or record the operator's mouse.
static func ensure_test_viewport(ctx: FilmContext, size: Vector2i = Vector2i(1280, 720)) -> void:
	if ctx == null or ctx.tree == null:
		return
	ctx.tree.root.size = size
	var ix = ctx.main.interaction if ctx.main != null else null
	if ix != null and ix is Control:
		(ix as Control).size = Vector2(size)
	await wait_frames(ctx.tree, 2)
	isolate_background_window(ctx.tree)


## Keep the Godot window from stealing the operator's desktop during films /
## non-headless UI runners, without stopping per-frame presents.
## Synthetic FilmUI input still works (injected events; focus not required).
## No-op under the headless display server. Set env SX_TEST_WINDOW=onscreen to keep
## the window visible while debugging a film.
##
## Important: do **not** minimize during Movie Maker capture. A minimized window
## often skips DisplayServer presents while fixed-fps process/tweens still run,
## so MovieWriter sees stale textures and pointer/camera motion looks teleported.
static func isolate_background_window(tree: SceneTree) -> void:
	if tree == null:
		return
	if str(OS.get_environment("SX_TEST_WINDOW")).to_lower() in ["onscreen", "1", "show", "visible"]:
		return
	# Headless display has no real window manager surface to steal focus.
	var driver := DisplayServer.get_name()
	if driver.is_empty() or driver.to_lower().contains("headless"):
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var win_id := DisplayServer.MAIN_WINDOW_ID
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, win_id)
	# Stay windowed so Vulkan/X11 keep presenting every fixed-fps tick.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, win_id)
	if tree.root != null:
		tree.root.size = Vector2i(1600, 900)
	# Park off-screen instead of minimizing (still composited/drawn on typical GPUs).
	DisplayServer.window_set_position(Vector2i(-4200, -4200), win_id)


static func wait_frames(tree: SceneTree, n: int = 1) -> void:
	for _i in n:
		await tree.process_frame


static func _fail(msg: String) -> void:
	fail_count += 1
	push_error("FilmUI: " + msg)


## True if `screen_pos` lies inside the visible viewport (with a small inset).
static func is_on_screen(ctx: FilmContext, screen_pos: Vector2, inset: float = 2.0) -> bool:
	if ctx == null or ctx.tree == null:
		return false
	var vp := ctx.tree.root.get_viewport().get_visible_rect()
	if inset > 0.0:
		vp = vp.grow(-inset)
	return vp.has_point(screen_pos)


## Fail (and return false) when a click/pointer target is offscreen.
static func require_on_screen(ctx: FilmContext, screen_pos: Vector2, why: String) -> bool:
	if is_on_screen(ctx, screen_pos):
		return true
	var vp := Rect2()
	if ctx != null and ctx.tree != null:
		vp = ctx.tree.root.get_viewport().get_visible_rect()
	_fail("cursor offscreen for %s at %s (vp %s)" % [why, str(screen_pos), str(vp)])
	return false


## Clamp a screen point into the visible viewport (for box-select corners, etc.).
static func clamp_to_screen(ctx: FilmContext, screen_pos: Vector2, inset: float = 4.0) -> Vector2:
	if ctx == null or ctx.tree == null:
		return screen_pos
	var vp := ctx.tree.root.get_viewport().get_visible_rect().grow(-inset)
	return Vector2(
		clampf(screen_pos.x, vp.position.x, vp.position.x + vp.size.x),
		clampf(screen_pos.y, vp.position.y, vp.position.y + vp.size.y))


## Scroll parent ScrollContainers so `control` is visible, then return its center.
static func ensure_control_visible(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	var n: Node = control.get_parent()
	while n != null:
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible(control)
		n = n.get_parent()
	return control.get_global_rect().get_center()


static func find_button(root: Node, text: String) -> Button:
	return _find_button_match(root, text, true)


## CheckBox match by tooltip (timeline suppress, etc.).
static func find_checkbox(root: Node, tip_substr: String) -> CheckBox:
	if root == null:
		return null
	var needle := tip_substr.to_lower()
	for c in root.find_children("*", "CheckBox", true, false):
		var cb := c as CheckBox
		if cb == null:
			continue
		if not cb.is_visible_in_tree():
			continue
		if str(cb.tooltip_text).to_lower().find(needle) >= 0:
			return cb
	return null


## Cue + set checkbox state (emits toggled). pressed.emit alone does not toggle.
static func set_checkbox(ctx: FilmContext, cb: CheckBox, pressed: bool, cue: Dictionary) -> bool:
	if cb == null or not cb.is_visible_in_tree():
		_fail("checkbox missing or hidden (%s)" % str(cue.get("desc", cue.get("keys", "?"))))
		return false
	var center := ensure_control_visible(cb)
	await wait_frames(ctx.tree, 2)
	center = cb.get_global_rect().get_center()
	if not await _cue_click(ctx, center, cue):
		return false
	if cb.button_pressed != pressed:
		cb.button_pressed = pressed
	await wait_frames(ctx.tree, 2)
	return true


## Activate a MenuButton popup item by id (File Save, Edit Undo, …).
static func activate_menu_id(ctx: FilmContext, menu_btn: MenuButton, id: int, cue: Dictionary) -> bool:
	if menu_btn == null or not menu_btn.is_visible_in_tree():
		_fail("menu button missing (%s)" % str(cue.get("desc", "?")))
		return false
	var center := ensure_control_visible(menu_btn)
	if not await _cue_click(ctx, center, cue):
		return false
	var popup := menu_btn.get_popup()
	if popup == null:
		_fail("menu popup missing (%s)" % str(cue.get("desc", "?")))
		return false
	popup.id_pressed.emit(id)
	await wait_frames(ctx.tree, 2)
	return true


## Click the rollback bar, then apply the same set_rollback drop-landing uses.
static func timeline_rollback_before(ctx: FilmContext, feature_index: int) -> bool:
	var tl = ctx.main.timeline
	if tl == null or tl.rollback_bar == null:
		_fail("timeline rollback bar missing")
		return false
	var bar: Button = tl.rollback_bar as Button
	if not await click_control(ctx, bar, FilmUICues.alert("Rollback", "Grab history bar")):
		return false
	tl.set_rollback(feature_index)
	await wait_frames(ctx.tree, 2)
	return true


## Double-click the rollback bar to roll to end of history.
static func timeline_rollback_to_end(ctx: FilmContext) -> bool:
	var tl = ctx.main.timeline
	if tl == null or tl.rollback_bar == null:
		_fail("timeline rollback bar missing")
		return false
	var bar: Control = tl.rollback_bar
	var center := ensure_control_visible(bar)
	if not await _cue_click(ctx, center, FilmUICues.alert("Rollback end", "Double-click bar")):
		return false
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	ev.position = Vector2.ZERO
	bar.gui_input.emit(ev)
	await wait_frames(ctx.tree, 2)
	return true


static func _find_button_match(root: Node, text: String, require_visible: bool) -> Button:
	var tip_hit: Button = null
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null:
			continue
		if require_visible and not b.is_visible_in_tree():
			continue
		if str(b.text) == text:
			return b
		if str(b.text).to_lower() == text.to_lower():
			return b
		if tip_hit == null:
			var tip := str(b.tooltip_text)
			if tip == text or tip.begins_with(text) or tip.findn(text) >= 0:
				tip_hit = b
	return tip_hit


## Palette Sketch control — never the hidden SelectionStrip "Sketch" button.
static func find_palette_sketch_button(root: Node) -> Button:
	var palette := root.find_child("Palette", true, false)
	if palette == null:
		return null
	return _find_button_match(palette, "Sketch", true)


## Prefer the left-rail SketchTools icons over on-canvas variant chips.
static func find_sketch_tool_button(root: Node, label: String) -> Button:
	var rail := root.find_child("SketchTools", true, false)
	if rail == null or not (rail as CanvasItem).is_visible_in_tree():
		return null
	return _find_button_match(rail, label, true)


static func find_palette_button(root: Node, kind: String) -> Button:
	var needle := kind.to_lower()
	var fallback: Button = null
	for c in root.find_children("*", "PaletteButton", true, false):
		var pb := c as PaletteButton
		if pb == null:
			continue
		if pb.kind.to_lower() != needle:
			continue
		if pb.is_visible_in_tree():
			return pb
		fallback = pb
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null:
			continue
		var tip := str(b.tooltip_text).to_lower()
		if tip.begins_with("insert %s" % needle):
			if b.is_visible_in_tree():
				return b
			if fallback == null:
				fallback = b
	return fallback


static func _cue_click(ctx: FilmContext, screen_pos: Vector2, cue: Dictionary) -> bool:
	var why := str(cue.get("desc", cue.get("keys", "click")))
	if not require_on_screen(ctx, screen_pos, why):
		return false
	if ctx.chrome == null:
		await wait_frames(ctx.tree, 1)
		return true
	var keys := str(cue.get("keys", "Click"))
	var desc := str(cue.get("desc", ""))
	await ctx.chrome.animate_pointer_click(screen_pos, keys, desc)
	return true


## Cue + activate a visible button. Returns false (and errors) if missing/hidden.
static func click_control(ctx: FilmContext, button: BaseButton, cue: Dictionary) -> bool:
	if button == null or not button.is_visible_in_tree():
		_fail("clickable control missing or hidden (%s)" % str(cue.get("desc", cue.get("keys", "?"))))
		return false
	var center := ensure_control_visible(button)
	await wait_frames(ctx.tree, 2)
	center = button.get_global_rect().get_center()
	if not is_on_screen(ctx, center):
		# One more scroll pass after layout settles.
		center = ensure_control_visible(button)
		await wait_frames(ctx.tree, 2)
		center = button.get_global_rect().get_center()
	if not await _cue_click(ctx, center, cue):
		return false
	# PaletteButton hooks `_pressed()` (not the pressed signal) for insert_requested.
	if button is PaletteButton:
		(button as PaletteButton)._pressed()
	else:
		button.pressed.emit()
	await wait_frames(ctx.tree, 2)
	return true


static func click_button(ctx: FilmContext, text: String, cue: Dictionary = {}) -> void:
	var b := find_button(ctx.main, text)
	var c := cue if not cue.is_empty() else FilmUICues.alert(text, text)
	await click_control(ctx, b, c)


## Shift+drag a window/crossing box that covers the given pads (multi-select).
## Uses Shift+right-drag crossing mode so partial pad capture counts.
static func select_sketch_pads_box_ui(ctx: FilmContext, feature_ids: Array) -> void:
	if feature_ids.is_empty():
		_fail("box-select: no feature ids")
		return
	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(0, 0, 2)
		cam.distance = 55.0
		cam.set_view(deg_to_rad(-45.0), deg_to_rad(35.0), false)
		await wait_frames(ctx.tree, 3)
	if ctx.view != null:
		ctx.view.refresh_sketch_pads("")
		await wait_frames(ctx.tree, 2)
	var union := Rect2()
	var have := false
	for fid in feature_ids:
		var id := str(fid)
		var r := Rect2()
		if ctx.view.sketch_pads != null and ctx.view.sketch_pads.has_method("pad_screen_aabb"):
			r = ctx.view.sketch_pads.pad_screen_aabb(id, cam, ctx.main.model_space)
		if r.size.x < 1.0 or r.size.y < 1.0:
			var c := pad_screen_center(ctx, id)
			if c == Vector2.ZERO:
				_fail("box-select: pad %s has no screen center" % id)
				return
			r = Rect2(c - Vector2(40, 40), Vector2(80, 80))
		r = r.grow(16.0)
		if not have:
			union = r
			have = true
		else:
			union = union.merge(r)
	if not have:
		return
	# Start just outside the pad union but still on-screen (offscreen cursor = fail).
	var a := clamp_to_screen(ctx, union.position - Vector2(24, 24))
	var b := clamp_to_screen(ctx, union.position + union.size + Vector2(24, 24))
	if a.distance_to(b) < 8.0:
		b = clamp_to_screen(ctx, a + Vector2(48, 48))
	await _cue_click(ctx, a, FilmUICues.alert("Shift+RMB Drag", "Crossing-box select sketch pads"))
	_set_shift_held(true)
	await wait_frames(ctx.tree, 1)
	var ix = ctx.main.interaction
	if ix == null:
		_set_shift_held(false)
		_fail("interaction missing for box select")
		return
	# Shift+RMB drag → crossing box select (viewport_interaction RMB path).
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = a
	down.shift_pressed = true
	ix._input(down)
	await wait_frames(ctx.tree, 1)
	var mid := (a + b) * 0.5
	for pt in [mid, b]:
		var move := InputEventMouseMotion.new()
		move.position = pt
		move.relative = Vector2(20, 20)
		move.shift_pressed = true
		ix._input(move)
		await wait_frames(ctx.tree, 1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = b
	up.shift_pressed = true
	ix._input(up)
	await wait_frames(ctx.tree, 4)
	_set_shift_held(false)
	await wait_frames(ctx.tree, 2)
	var selected: Array = ctx.main.selected_sketch_pads
	if selected.size() < feature_ids.size():
		_fail("box-select got %d pads, want %d (have %s)" \
				% [selected.size(), feature_ids.size(), str(selected)])
		return
	for fid in feature_ids:
		if str(fid) not in selected:
			_fail("box-select missed pad %s (have %s)" % [str(fid), str(selected)])
			return


static func _set_shift_held(held: bool) -> void:
	var ke := InputEventKey.new()
	ke.keycode = KEY_SHIFT
	ke.physical_keycode = KEY_SHIFT
	ke.pressed = held
	ke.shift_pressed = held
	Input.parse_input_event(ke)


## Hold/release Ctrl so Input.is_key_pressed matches a real modifier chord.
static func _set_ctrl_held(held: bool) -> void:
	var ke := InputEventKey.new()
	ke.keycode = KEY_CTRL
	ke.physical_keycode = KEY_CTRL
	ke.pressed = held
	ke.ctrl_pressed = held
	Input.parse_input_event(ke)


## Inject a real viewport mouse button through Interaction (user click path).
static func viewport_click(
		ctx: FilmContext,
		screen_pos: Vector2,
		cue: Dictionary,
		ctrl: bool = false,
		button_index: int = MOUSE_BUTTON_LEFT
) -> void:
	var ix = ctx.main.interaction
	if ix == null:
		_fail("interaction missing for viewport click")
		return
	if not await _cue_click(ctx, screen_pos, cue):
		return
	if ctrl:
		_set_ctrl_held(true)
		await wait_frames(ctx.tree, 1)
	var down := InputEventMouseButton.new()
	down.button_index = button_index
	down.pressed = true
	down.position = screen_pos
	down.ctrl_pressed = ctrl
	down.meta_pressed = ctrl
	ix._input(down)
	await wait_frames(ctx.tree, 1)
	var up := InputEventMouseButton.new()
	up.button_index = button_index
	up.pressed = false
	up.position = screen_pos
	up.ctrl_pressed = ctrl
	up.meta_pressed = ctrl
	ix._input(up)
	await wait_frames(ctx.tree, 2)
	if ctrl:
		_set_ctrl_held(false)
	await wait_frames(ctx.tree, 2)


static func model_to_screen(ctx: FilmContext, model_pt: Vector3) -> Vector2:
	var ix = ctx.main.interaction
	if ix != null and ix.has_method("_model_to_screen"):
		return ix._model_to_screen(model_pt)
	var cam = ctx.main.camera
	if cam == null:
		return Vector2.ZERO
	var ms: Node3D = ctx.main.model_space
	var world: Vector3 = ms.to_global(model_pt) if ms != null else model_pt
	return cam.unproject_position(world)


static func select_sketch_tool(ctx: FilmContext, sm: SketchMode, tool: int) -> void:
	var label := ""
	match tool:
		SketchMode.Tool.LINE:
			label = "Line"
		SketchMode.Tool.CIRCLE:
			label = "Circle"
		SketchMode.Tool.SPLINE:
			label = "Spline"
		SketchMode.Tool.SMART_DIM:
			label = "Smart Dimension"
		SketchMode.Tool.EXTEND:
			label = "Extend"
		SketchMode.Tool.SELECT:
			label = "Select"
		SketchMode.Tool.RECT:
			label = "Rectangle"
		SketchMode.Tool.ARC:
			label = "Arc"
		SketchMode.Tool.POLYGON:
			label = "Polygon"
		SketchMode.Tool.TRIM:
			label = "Trim"
		SketchMode.Tool.MIRROR:
			label = "Mirror"
		SketchMode.Tool.PATTERN:
			label = "Pattern"
		SketchMode.Tool.POINT:
			label = "Point"
		SketchMode.Tool.CONVERT:
			label = "Convert"
		SketchMode.Tool.ELLIPSE:
			label = "Ellipse"
		SketchMode.Tool.SLOT:
			label = "Slot"
		_:
			_fail("no clickable sketch tool mapping for %s" % str(tool))
			return
	var b := find_sketch_tool_button(ctx.main, label)
	if not await click_control(ctx, b, FilmUICues.tool_keys(tool)):
		return
	if sm != null and sm.tool != tool:
		_fail("sketch tool click did not activate %s (got %s)" % [label, str(sm.tool)])
	await wait_frames(ctx.tree, 1)


static func click_sketch(ctx: FilmContext, _sm: SketchMode, uv: Vector2, desc: String = "Place sketch point") -> void:
	var screen := sketch_uv_to_screen(ctx, uv)
	if screen == Vector2.ZERO:
		_fail("could not project sketch UV %s to screen" % str(uv))
		return
	await viewport_click(ctx, screen, FilmUICues.sketch_click(desc))


static func set_sketch_dim(ctx: FilmContext, value: float) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null or not chrome.visible:
		_fail("sketch chrome not visible for dimension")
		return
	# Drive the on-canvas SpinBox (user can type the same value).
	if chrome.has_method("set_dim_value"):
		chrome.set_dim_value(value)
	var dim_btn := find_button(chrome, "Dim")
	await click_control(ctx, dim_btn, FilmUICues.dim_value(value))


static func enter_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await wait_frames(ctx.tree, 2)
		return
	# Clear face selection so Sketch does not immediately start on a solid face.
	if ctx.view != null:
		ctx.view.select_entity("", "")
	await wait_frames(ctx.tree, 1)
	var b := find_palette_sketch_button(ctx.main)
	if not await click_control(ctx, b, FilmUICues.toolbar_sketch()):
		return
	await wait_frames(ctx.tree, 2)
	if sm != null and sm.active:
		# Auto-started (e.g. residual face) — only OK if this is a fresh sketch.
		if sm.editing_fid == "" and sm.sketch != null and sm.sketch.entity_ids().is_empty():
			return
		sm.cancel()
		await wait_frames(ctx.tree, 2)
		if ctx.view != null:
			ctx.view.select_entity("", "")
		if not await click_control(ctx, b, FilmUICues.toolbar_sketch()):
			return
		await wait_frames(ctx.tree, 2)
	# Prefer empty ground near origin so the click stays on-screen in headless
	# (64²) and movie (1600×900) viewports; far world points often project off.
	var candidates: Array[Vector3] = [
		Vector3(22, 18, 0), Vector3(-18, 20, 0), Vector3(20, -16, 0), Vector3(-14, -14, 0),
		Vector3(12, 0, 0), Vector3(0, 12, 0),
	]
	var started := false
	for world in candidates:
		var ground := model_to_screen(ctx, world)
		if not is_on_screen(ctx, ground):
			continue
		await viewport_click(ctx, ground,
				FilmUICues.alert("Click", "Pick empty ground to start sketch"))
		await wait_frames(ctx.tree, 3)
		if sm == null or not sm.active:
			continue
		if sm.editing_fid != "":
			# Hit an existing yellow pad — discard and try another point.
			sm.cancel()
			await wait_frames(ctx.tree, 2)
			if ctx.view != null:
				ctx.view.select_entity("", "")
			b = find_palette_sketch_button(ctx.main)
			if not await click_control(ctx, b, FilmUICues.toolbar_sketch()):
				return
			await wait_frames(ctx.tree, 2)
			continue
		started = true
		break
	if not started:
		var fallback := viewport_empty_click_pos(ctx)
		await viewport_click(ctx, fallback,
				FilmUICues.alert("Click", "Pick empty ground to start sketch"))
		await wait_frames(ctx.tree, 3)
	if sm == null or not sm.active:
		_fail("sketch session did not start after Sketch + ground click")
	elif sm.editing_fid != "":
		_fail("ground sketch reopened existing pad %s" % sm.editing_fid)


static func exit_sketch(ctx: FilmContext) -> String:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		# Do not return a stale last-feature id — that hides failed sketch starts.
		return ""
	var before := last_feature_id(ctx.view.doc, "sketch")
	var editing := sm.editing_fid
	var exit_btn := find_sketch_tool_button(ctx.main, "Exit Sketch")
	if not await click_control(ctx, exit_btn, FilmUICues.exit_sketch()):
		return ""
	await wait_frames(ctx.tree, 3)
	if sm.active:
		_fail("sketch still active after Exit Sketch click")
		return ""
	var after := last_feature_id(ctx.view.doc, "sketch")
	if editing != "":
		return editing
	# New sketch: only return a feature id if the graph actually grew.
	if after != "" and after != before:
		return after
	return ""


static func viewport_empty_click_pos(ctx: FilmContext) -> Vector2:
	var vp := ctx.tree.root.get_viewport().get_visible_rect()
	var ix = ctx.main.interaction
	var center: Vector2
	if ix != null and ix.has_method("_screen_center"):
		center = ix._screen_center()
	else:
		center = vp.get_center()
	# Stay inside the viewport: a fixed +280,-180 offset flies off headless 64²
	# and small film windows. Use a fractional nudge, then clamp.
	var nudge := Vector2(vp.size.x * 0.22, -vp.size.y * 0.18)
	return clamp_to_screen(ctx, center + nudge, 8.0)


## Sketch on an already-placed body's face (select face → Sketch on strip).
static func enter_sketch_on_face(ctx: FilmContext, body_id: String, face_id: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await exit_sketch(ctx)
	var pt := face_pick_point(ctx.view, body_id, face_id)
	if pt == Vector3.INF:
		_fail("could not resolve face pick point for %s/%s" % [body_id, face_id])
		return
	# Hide yellow pads so nearby rails/profiles cannot steal the face pick ray.
	var pads = ctx.view.sketch_pads if ctx.view != null else null
	var pads_was_visible := false
	if pads != null:
		pads_was_visible = pads.visible
		pads.visible = false
	# Frame the face so the pick ray is not edge-on / behind the camera.
	var look_btn := find_button(ctx.main, "Look at")
	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		cam.pivot = pt
		cam.distance = maxf(cam.distance, 35.0)
		cam.set_view(deg_to_rad(-40.0), deg_to_rad(28.0), false)
		await wait_frames(ctx.tree, 2)
	var face_screen := model_to_screen(ctx, pt)
	if is_on_screen(ctx, face_screen):
		if ctx.view.selected_body != body_id or ctx.view.selected_face != face_id:
			await viewport_click(ctx, face_screen,
					FilmUICues.alert("Click", "Select face for sketch host"))
			await wait_frames(ctx.tree, 2)
		if ctx.view.selected_face == face_id and look_btn != null and look_btn.is_visible_in_tree():
			await click_control(ctx, look_btn, FilmUICues.alert("Look at", "Orient camera to face"))
			await wait_frames(ctx.tree, 2)
		if ctx.view.selected_face != face_id:
			face_screen = model_to_screen(ctx, pt)
			if is_on_screen(ctx, face_screen):
				await viewport_click(ctx, face_screen,
						FilmUICues.alert("Click", "Select face for sketch host"))
				await wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face_id:
		# Headless / tight framing: select the known face, then Sketch strip (UI).
		ctx.view.select_entity(body_id, face_id)
		await wait_frames(ctx.tree, 1)
	if ctx.view.selected_face != face_id:
		if pads != null:
			pads.visible = pads_was_visible
		_fail("could not select face %s via click (got '%s')" % [face_id, ctx.view.selected_face])
		return
	if look_btn != null and look_btn.is_visible_in_tree() and ctx.view.selected_face == face_id:
		await click_control(ctx, look_btn, FilmUICues.alert("Look at", "Orient camera to face"))
		await wait_frames(ctx.tree, 2)
	var strip := find_button(ctx.main, "Sketch")
	if strip != null and strip.is_visible_in_tree():
		if not await click_control(ctx, strip, FilmUICues.toolbar_sketch()):
			if pads != null:
				pads.visible = pads_was_visible
			return
	else:
		await viewport_click(ctx, viewport_empty_click_pos(ctx),
				FilmUICues.alert("Click", "Deselect to show Sketch"))
		var palette_btn := find_palette_sketch_button(ctx.main)
		if not await click_control(ctx, palette_btn, FilmUICues.toolbar_sketch()):
			if pads != null:
				pads.visible = pads_was_visible
			return
		await viewport_click(ctx, model_to_screen(ctx, pt),
				FilmUICues.alert("Click", "Pick face as sketch host"))
	await wait_frames(ctx.tree, 4)
	if pads != null:
		pads.visible = pads_was_visible
	if sm == null or not sm.active:
		_fail("sketch session did not start on face %s" % face_id)
	elif sm.editing_fid != "":
		_fail("face sketch reopened pad %s instead of new face sketch" % sm.editing_fid)


## Removed as a film helper: arbitrary planes are not clickable in the UI yet.
## Validation tests may call SketchMode.begin_on_plane / main._start_sketch_on_plane.
static func enter_sketch_on_plane(_ctx: FilmContext, _origin: Vector3, _x_dir: Vector3, _y_dir: Vector3) -> void:
	_fail("enter_sketch_on_plane is not a user-clickable path — place a solid and use enter_sketch_on_face, or call begin_on_plane from a validation test")


static func merge_sketches_ui(ctx: FilmContext, mode: String) -> void:
	var action := "merge_join"
	match mode:
		"join_endpoints", "merge_join":
			action = "merge_join"
		"bridge_spline", "merge_spline":
			action = "merge_spline"
		"composite", "merge_composite":
			action = "merge_composite"
		"use_as_path":
			action = "use_as_path"
	var chip_label := action.capitalize().replace("_", " ")
	var sk_chrome: SketchContextChrome = ctx.main.sketch_chrome
	if sk_chrome == null or not sk_chrome.visible:
		_fail("sketch chrome not visible for merge chips")
		return
	var merge_btn := find_button(sk_chrome, chip_label)
	if not await click_control(ctx, merge_btn, FilmUICues.merge_join()):
		return
	await wait_frames(ctx.tree, 4)
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func select_sketch_pad_ctrl(ctx: FilmContext, feature_id: String) -> void:
	if feature_id.is_empty():
		return
	# Pad multi-select only works outside an active sketch session.
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await exit_sketch(ctx)
		await wait_frames(ctx.tree, 2)
	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		# Stable three-quarter view; avoid frame_contents after Hide (empty AABB).
		cam.pivot = Vector3(0, 0, 2)
		cam.distance = 40.0
		cam.set_view(deg_to_rad(-45.0), deg_to_rad(30.0), false)
		await wait_frames(ctx.tree, 2)
	if ctx.view != null:
		ctx.view.refresh_sketch_pads("")
		await wait_frames(ctx.tree, 1)
	var screen_pos := pad_screen_center(ctx, feature_id)
	if screen_pos == Vector2.ZERO:
		_fail("could not project pad %s to screen" % feature_id)
		return
	if not require_on_screen(ctx, screen_pos, "pad %s" % feature_id):
		return
	var ix = ctx.main.interaction
	if ix != null and ctx.view.sketch_pads != null and ix.has_method("_model_ray"):
		var ray: Array = ix._model_ray(screen_pos)
		var resolved: String = ctx.view.sketch_pads.pick_pad(ray[0], ray[1])
		if resolved != feature_id:
			_fail("pad ray at %s resolved to '%s' (want %s)" % [str(screen_pos), resolved, feature_id])
			return
	await viewport_click(ctx, screen_pos, FilmUICues.ctrl_pad(), true)
	if feature_id in ctx.main.selected_sketch_pads:
		return
	await _viewport_click_shift(ctx, screen_pos)
	if feature_id in ctx.main.selected_sketch_pads:
		return
	# Prefer the Interaction signal (identical to a successful additive pad click).
	if ix != null and ix.has_signal("sketch_pad_clicked"):
		ix.sketch_pad_clicked.emit(feature_id, true)
		await wait_frames(ctx.tree, 2)
	if feature_id not in ctx.main.selected_sketch_pads and ctx.main.has_method("_on_sketch_pad_clicked"):
		ctx.main._on_sketch_pad_clicked(feature_id, true)
		await wait_frames(ctx.tree, 2)
	if feature_id not in ctx.main.selected_sketch_pads:
		_fail("pad %s not in multi-selection after Ctrl/Shift+click (have %s)" \
				% [feature_id, str(ctx.main.selected_sketch_pads)])


static func _viewport_click_shift(ctx: FilmContext, screen_pos: Vector2) -> void:
	var ix = ctx.main.interaction
	if ix == null:
		return
	await _cue_click(ctx, screen_pos, FilmUICues.alert("Shift+Click", "Add sketch pad to selection"))
	_set_shift_held(true)
	await wait_frames(ctx.tree, 1)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen_pos
	down.shift_pressed = true
	ix._input(down)
	await wait_frames(ctx.tree, 1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen_pos
	up.shift_pressed = true
	ix._input(up)
	await wait_frames(ctx.tree, 2)
	_set_shift_held(false)
	await wait_frames(ctx.tree, 2)


static func clear_pad_selection(ctx: FilmContext) -> void:
	# Prefer the on-canvas Clear chip when multi-select chrome is up.
	var sk_chrome: SketchContextChrome = ctx.main.sketch_chrome
	if sk_chrome != null and sk_chrome.visible:
		var clear_btn := find_button(sk_chrome, "Merge Clear")
		if clear_btn != null and clear_btn.is_visible_in_tree():
			await click_control(ctx, clear_btn, FilmUICues.alert("Clear", "Clear pad selection"))
			return
	# Otherwise pads are already empty (fresh session / after merge).


static func last_feature_id(doc: SxDocument, type_filter: String = "") -> String:
	var feats: Array = doc.graph_features()
	for i in range(feats.size() - 1, -1, -1):
		var f: Dictionary = feats[i]
		var ty := str(f.get("type", ""))
		if type_filter == "" or ty == type_filter:
			return str(f.get("id", ""))
	return ""


static func draw_line(ctx: FilmContext, sm: SketchMode, a: Vector2, b: Vector2) -> void:
	await select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click_sketch(ctx, sm, a, "Line — first point")
	await click_sketch(ctx, sm, b, "Line — second point")
	await end_line_chain(ctx)


## Multi-segment line chain (one Line arming). Ends with Done when available.
static func draw_polyline(ctx: FilmContext, sm: SketchMode, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	await select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click_sketch(ctx, sm, points[0], "Line — start")
	for i in range(1, points.size()):
		await click_sketch(ctx, sm, points[i], "Line — next point")
	await end_line_chain(ctx)


## Finish an open line / spline chain via the Done chip (Esc fallback).
static func end_line_chain(ctx: FilmContext) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var done: Button = null
	if chrome != null and chrome.visible and chrome.has_method("done_button"):
		done = chrome.done_button()
	if done != null and done.is_visible_in_tree():
		await click_control(ctx, done, FilmUICues.alert("Done", "End line chain"))
		return
	# Fallback when Done chrome is missing: Esc ends chain without discarding.
	if ctx.chrome != null:
		ctx.chrome.show_action_alert("Esc", "End line chain")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	ctx.main.interaction._input(esc)
	await wait_frames(ctx.tree, 2)
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func draw_spline_through(ctx: FilmContext, sm: SketchMode, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	await select_sketch_tool(ctx, sm, SketchMode.Tool.SPLINE)
	for i in range(points.size()):
		var hint := "Spline — point %d" % (i + 1)
		await click_sketch(ctx, sm, points[i], hint)
	# User ends a spline with right-click.
	var last_screen := sketch_uv_to_screen(ctx, points[points.size() - 1])
	await viewport_click(ctx, last_screen, FilmUICues.alert("RMB", "End spline chain"),
			false, MOUSE_BUTTON_RIGHT)
	await wait_frames(ctx.tree, 3)


static func draw_circle(ctx: FilmContext, sm: SketchMode, center: Vector2, rim: Vector2) -> void:
	await select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await click_sketch(ctx, sm, center, "Circle — center")
	await click_sketch(ctx, sm, rim, "Circle — radius")


static func apply_extrude(ctx: FilmContext, depth: float) -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null or not chrome.visible:
		_fail("sketch chrome not visible for Extrude")
		return
	if chrome.has_method("set_extrude_distance"):
		chrome.set_extrude_distance(depth)
	var ex := chrome.extrude_button() if chrome.has_method("extrude_button") else null
	if not await click_control(ctx, ex, FilmUICues.extrude(depth)):
		return
	await ctx.after_regen()
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func apply_revolve(ctx: FilmContext, angle: float = TAU, _op: String = "new") -> void:
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome == null or not chrome.visible:
		_fail("sketch chrome not visible for Revolve")
		return
	var rv := chrome.revolve_button() if chrome.has_method("revolve_button") else null
	if not await click_control(ctx, rv, FilmUICues.revolve(rad_to_deg(angle))):
		return
	await ctx.after_regen()
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func loft_profiles_ui(ctx: FilmContext, ruled: bool) -> void:
	var action := "loft_ruled" if ruled else "loft_smooth"
	var chip_label := action.capitalize().replace("_", " ")
	var sk_chrome: SketchContextChrome = ctx.main.sketch_chrome
	if sk_chrome == null or not sk_chrome.visible:
		_fail("sketch chrome not visible for loft chips")
		return
	var loft_btn := find_button(sk_chrome, chip_label)
	if not await click_control(ctx, loft_btn, FilmUICues.loft(ruled)):
		return
	await wait_frames(ctx.tree, 4)
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func sweep_along_path_ui(ctx: FilmContext) -> void:
	var sk_chrome: SketchContextChrome = ctx.main.sketch_chrome
	if sk_chrome == null or not sk_chrome.visible:
		_fail("sketch chrome not visible for sweep chip")
		return
	var sweep_btn := find_button(sk_chrome, "Sweep Path")
	if sweep_btn == null:
		sweep_btn = find_button(sk_chrome, "Sweep path")
	if not await click_control(ctx, sweep_btn, FilmUICues.alert("Sweep", "Sweep profile along path")):
		return
	await wait_frames(ctx.tree, 4)
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func place_primitive(ctx: FilmContext, kind: String) -> void:
	await place_primitive_at(ctx, kind, Vector3(15, 0, 0))


## SpinBox next to a Label with exact (or prefix) text in the same row.
static func find_labeled_spin(root: Node, label: String) -> SpinBox:
	if root == null or label.is_empty():
		return null
	for c in root.find_children("*", "Label", true, false):
		var lbl := c as Label
		if lbl == null:
			continue
		if not lbl.is_visible_in_tree():
			continue
		var t := str(lbl.text)
		if t != label and not t.begins_with(label):
			continue
		var row := lbl.get_parent()
		if row == null:
			continue
		for sibling in row.get_children():
			if sibling is SpinBox:
				return sibling as SpinBox
	return null


## Cue the labeled SpinBox, then set its value (same path as typing a number).
static func set_labeled_spin(
		ctx: FilmContext, root: Node, label: String, value: float, desc: String = ""
) -> bool:
	var spin := find_labeled_spin(root, label)
	if spin == null or not spin.is_visible_in_tree():
		_fail("labeled spin '%s' missing or hidden" % label)
		return false
	var center := ensure_control_visible(spin)
	await wait_frames(ctx.tree, 1)
	center = spin.get_global_rect().get_center()
	var cue_desc := desc if desc != "" else "Set %s to %.2f" % [label, value]
	if not await _cue_click(ctx, center, FilmUICues.alert(label, cue_desc)):
		return false
	spin.value = value
	await wait_frames(ctx.tree, 1)
	return true


## Place a palette primitive by clicking the palette button then a world drop point.
## Optional `size` (W,H,D mm) is typed into the place TransformHud before the drop.
static func place_primitive_at(
		ctx: FilmContext, kind: String, world: Vector3, size := Vector3.ZERO
) -> void:
	# A selected body swaps the left rail to Modify tools and hides the palette.
	if ctx.view != null and ctx.view.selected_body != "":
		ctx.view.clear_selection()
		if ctx.main.has_method("_update_left_rail"):
			ctx.main._update_left_rail()
		await wait_frames(ctx.tree, 1)
	var b := find_palette_button(ctx.main, kind)
	if not await click_control(ctx, b, FilmUICues.place_primitive(kind)):
		return
	await wait_frames(ctx.tree, 2)
	if size.x > 0.0:
		var hud: Node = null
		var ix_hud = ctx.main.interaction
		if ix_hud != null:
			hud = ix_hud.transform_hud
		if hud == null or not (hud as CanvasItem).visible:
			_fail("place TransformHud not visible for size")
			return
		if not await set_labeled_spin(ctx, hud, "W", size.x, "Plate width %.0f mm" % size.x):
			return
		if not await set_labeled_spin(ctx, hud, "H", size.y, "Plate depth %.0f mm" % size.y):
			return
		if not await set_labeled_spin(ctx, hud, "D", size.z, "Plate thickness %.0f mm" % size.z):
			return
		await wait_frames(ctx.tree, 1)
	var drop := model_to_screen(ctx, world)
	if not is_on_screen(ctx, drop):
		drop = model_to_screen(ctx, Vector3(8, 8, 0))
	if not is_on_screen(ctx, drop):
		var ix = ctx.main.interaction
		if ix != null and ix.has_method("_screen_center"):
			drop = ix._screen_center()
		else:
			drop = ctx.tree.root.get_viewport().get_visible_rect().get_center()
	drop = clamp_to_screen(ctx, drop)
	await viewport_click(ctx, drop, FilmUICues.place_click(kind))
	# Ensure place-mode is cleared so selection strip buttons can appear.
	var ix2 = ctx.main.interaction
	if ix2 != null and ix2.has_method("_disarm_place"):
		ix2._disarm_place(false)
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


## Select a body face via viewport click (frames the camera first).
static func select_face(ctx: FilmContext, body_id: String, face_id: String) -> void:
	if ctx.view == null or body_id == "" or face_id == "":
		_fail("select_face: missing body/face")
		return
	var pt := face_pick_point(ctx.view, body_id, face_id)
	if pt == Vector3.INF:
		_fail("select_face: no pick point for %s/%s" % [body_id, face_id])
		return
	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		cam.pivot = pt
		cam.distance = maxf(cam.distance, 90.0)
		cam.set_view(deg_to_rad(-35.0), deg_to_rad(40.0), false)
		await wait_frames(ctx.tree, 2)
	var screen := model_to_screen(ctx, pt)
	if not is_on_screen(ctx, screen):
		_fail("select_face: face not on screen")
		return
	await viewport_click(ctx, screen, FilmUICues.alert("Click", "Select face"))
	await wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face_id:
		# Retry once with a slightly higher camera.
		if cam != null and cam.has_method("set_view"):
			cam.distance = maxf(cam.distance, 120.0)
			cam.set_view(deg_to_rad(-55.0), deg_to_rad(20.0), false)
			await wait_frames(ctx.tree, 2)
		screen = model_to_screen(ctx, pt)
		if is_on_screen(ctx, screen):
			await viewport_click(ctx, screen, FilmUICues.alert("Click", "Select face"))
			await wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face_id:
		_fail("select_face: got '%s', want '%s'" % [ctx.view.selected_face, face_id])


static func edit_sketch_pad(ctx: FilmContext, fid: String) -> void:
	if fid.is_empty():
		return
	var screen_pos := pad_screen_center(ctx, fid)
	if screen_pos == Vector2.ZERO:
		_fail("could not project pad %s for edit" % fid)
		return
	await viewport_click(ctx, screen_pos, FilmUICues.edit_pad())
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		_fail("pad click did not reopen sketch %s" % fid)


static func face_pick_point(view: DocumentView, body_id: String, face_id: String) -> Vector3:
	if view == null or body_id == "" or face_id == "":
		return Vector3.INF
	var node: MeshInstance3D = view.body_node(body_id)
	var faces: PackedStringArray = view.doc.get_face_ids(body_id)
	var idx := faces.find(face_id)
	if node == null or node.mesh == null or idx < 0 or idx >= node.mesh.get_surface_count():
		return Vector3.INF
	var arrays: Array = node.mesh.surface_get_arrays(idx)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return Vector3.INF
	var acc := Vector3.ZERO
	for v in verts:
		acc += v
	return acc / float(verts.size())


## Face whose tessellated normal is closest to `want_normal` (model space).
static func find_face_by_normal(view: DocumentView, body_id: String, want_normal: Vector3) -> String:
	if view == null or body_id == "":
		return ""
	var best := ""
	var best_dot := -2.0
	var target := want_normal.normalized()
	for face_id in view.doc.get_face_ids(body_id):
		var n := view.face_normal(body_id, face_id)
		if n.length_squared() < 1e-12:
			continue
		var d := n.normalized().dot(target)
		if d > best_dot:
			best_dot = d
			best = face_id
	return best if best_dot > 0.7 else ""


static func pad_screen_center(ctx: FilmContext, fid: String) -> Vector2:
	var doc: SxDocument = ctx.view.doc
	if doc == null or fid.is_empty():
		return Vector2.ZERO
	var sk: SxSketch = doc.graph_get_sketch(fid)
	if sk == null:
		return Vector2.ZERO
	var pi: Dictionary = sk.plane_info()
	if pi.is_empty():
		return Vector2.ZERO
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in sk.entity_ids():
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				mn = mn.min(a).min(b)
				mx = mx.max(a).max(b)
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
			"point":
				var p: Vector2 = info["position"]
				mn = mn.min(p)
				mx = mx.max(p)
			"spline":
				var fits: Array = info.get("fit_points", [])
				for fp in fits:
					var pv: Vector2 = fp as Vector2
					mn = mn.min(pv)
					mx = mx.max(pv)
			_:
				pass
	if not is_finite(mn.x):
		return Vector2.ZERO
	var center2 := (mn + mx) * 0.5
	var origin: Vector3 = pi["origin"]
	var x_dir: Vector3 = (pi["x_dir"] as Vector3).normalized()
	var y_dir: Vector3 = (pi["y_dir"] as Vector3).normalized()
	var world := origin + x_dir * center2.x + y_dir * center2.y
	return model_to_screen(ctx, world)


static func sketch_uv_to_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		return model_to_screen(ctx, sm.to_model(uv))
	var r := ctx.tree.root.get_viewport().get_visible_rect()
	return Vector2(
		r.position.x + r.size.x * clampf(0.22 + uv.x / 50.0, 0.15, 0.85),
		r.position.y + r.size.y * clampf(0.30 + uv.y / 50.0, 0.15, 0.80)
	)


static func _sketch_uv_to_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	return sketch_uv_to_screen(ctx, uv)
