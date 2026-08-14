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
## Kernel / validation scripts (`run_*_tests.gd`) may call those APIs directly.


static func wait_frames(tree: SceneTree, n: int = 1) -> void:
	for _i in n:
		await tree.process_frame


static func _fail(msg: String) -> void:
	push_error("FilmUI: " + msg)


static func find_button(root: Node, text: String) -> Button:
	return _find_button_match(root, text, true)


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
	for c in root.find_children("*", "PaletteButton", true, false):
		var pb := c as PaletteButton
		if pb == null:
			continue
		if not pb.is_visible_in_tree():
			continue
		if pb.kind == kind:
			return pb
	var needle := kind.to_lower()
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		var tip := str(b.tooltip_text).to_lower()
		if tip.begins_with("insert %s" % needle):
			return b
	return null


static func _cue_click(ctx: FilmContext, screen_pos: Vector2, cue: Dictionary) -> void:
	if ctx.chrome == null:
		await wait_frames(ctx.tree, 1)
		return
	var keys := str(cue.get("keys", "Click"))
	var desc := str(cue.get("desc", ""))
	await ctx.chrome.animate_pointer_click(screen_pos, keys, desc)


## Cue + activate a visible button. Returns false (and errors) if missing/hidden.
static func click_control(ctx: FilmContext, button: BaseButton, cue: Dictionary) -> bool:
	if button == null or not button.is_visible_in_tree():
		_fail("clickable control missing or hidden (%s)" % str(cue.get("desc", cue.get("keys", "?"))))
		return false
	await _cue_click(ctx, button.get_global_rect().get_center(), cue)
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


## Press S to raise the marking menu, then click one of its verbs. This is the
## overflow path for verbs that are not on the SelectionStrip.
static func marking_verb(ctx: FilmContext, verb: String) -> bool:
	var ix = ctx.main.interaction
	if ix == null:
		_fail("interaction missing for the marking menu")
		return false
	var key := InputEventKey.new()
	key.keycode = KEY_S
	key.physical_keycode = KEY_S
	key.pressed = true
	ix._input(key)
	await wait_frames(ctx.tree, 3)
	var menu: MarkingMenu = ix.marking_menu
	if menu == null or not menu.visible:
		_fail("marking menu did not open on S")
		return false
	var button := find_button(menu, verb)
	if button == null:
		menu.hide()
		_fail("marking menu has no %s verb" % verb)
		return false
	await click_control(ctx, button, FilmUICues.alert("S", "%s from the marking menu" % verb))
	await wait_frames(ctx.tree, 2)
	return true


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
	await _cue_click(ctx, screen_pos, cue)
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


## Press, travel, release through Interaction — the drag path a user takes.
static func viewport_drag(ctx: FilmContext, from: Vector2, to: Vector2, cue: Dictionary,
		steps: int = 6) -> void:
	var ix = ctx.main.interaction
	if ix == null:
		_fail("interaction missing for viewport drag")
		return
	await _cue_click(ctx, from, cue)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	ix._input(down)
	await wait_frames(ctx.tree, 1)
	for i in range(1, steps + 1):
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.position = from.lerp(to, float(i) / steps)
		ix._input(mm)
		await wait_frames(ctx.tree, 1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	ix._input(up)
	await wait_frames(ctx.tree, 3)


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
		_:
			_fail("no clickable sketch tool mapping for %s" % str(tool))
			return
	var b := find_sketch_tool_button(ctx.main, label)
	if not await click_control(ctx, b, FilmUICues.tool_keys(tool)):
		return
	if sm != null and sm.tool != tool:
		_fail("tool %s did not activate after clicking '%s'" % [str(tool), label])


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
	await ensure_create_rail(ctx)
	var b := find_palette_sketch_button(ctx.main)
	if not await click_control(ctx, b, FilmUICues.toolbar_sketch()):
		return
	await wait_frames(ctx.tree, 2)
	if sm != null and sm.active:
		return
	# No face pre-selected → Sketch arms host pick; click empty ground.
	var ground := model_to_screen(ctx, Vector3(0, 0, 0))
	await viewport_click(ctx, ground, FilmUICues.alert("Click", "Pick ground to start sketch"))
	await wait_frames(ctx.tree, 3)
	if sm == null or not sm.active:
		_fail("sketch session did not start after Sketch + ground click")


static func viewport_empty_click_pos(ctx: FilmContext) -> Vector2:
	var ix = ctx.main.interaction
	var center: Vector2
	if ix != null and ix.has_method("_screen_center"):
		center = ix._screen_center()
	else:
		center = ctx.tree.root.get_viewport().get_visible_rect().size * 0.5
	# Away from model origin / left rail so the click clears selection.
	return center + Vector2(280, -180)


## Sketch on an already-placed body's face (select face → Sketch on strip).
static func enter_sketch_on_face(ctx: FilmContext, body_id: String, face_id: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await exit_sketch(ctx)
	var pt := face_pick_point(ctx.view, body_id, face_id)
	if pt == Vector3.INF:
		_fail("could not resolve face pick point for %s/%s" % [body_id, face_id])
		return
	# Frame the face so the pick ray is not edge-on / behind the camera.
	var look_btn := find_button(ctx.main, "Look at")
	if ctx.view.selected_body != body_id or ctx.view.selected_face != face_id:
		await viewport_click(ctx, model_to_screen(ctx, pt),
				FilmUICues.alert("Click", "Select face for sketch host"))
		await wait_frames(ctx.tree, 2)
	if ctx.view.selected_face == face_id and look_btn != null and look_btn.is_visible_in_tree():
		await click_control(ctx, look_btn, FilmUICues.alert("Look at", "Orient camera to face"))
		await wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face_id:
		await viewport_click(ctx, model_to_screen(ctx, pt),
				FilmUICues.alert("Click", "Select face for sketch host"))
		await wait_frames(ctx.tree, 2)
	if ctx.view.selected_face != face_id:
		_fail("could not select face %s via click (got '%s')" % [face_id, ctx.view.selected_face])
		return
	var strip := find_button(ctx.main, "Sketch")
	if strip != null and strip.is_visible_in_tree():
		if not await click_control(ctx, strip, FilmUICues.toolbar_sketch()):
			return
	else:
		await viewport_click(ctx, viewport_empty_click_pos(ctx),
				FilmUICues.alert("Click", "Deselect to show Sketch"))
		var palette_btn := find_palette_sketch_button(ctx.main)
		if not await click_control(ctx, palette_btn, FilmUICues.toolbar_sketch()):
			return
		await viewport_click(ctx, model_to_screen(ctx, pt),
				FilmUICues.alert("Click", "Pick face as sketch host"))
	await wait_frames(ctx.tree, 4)
	if sm == null or not sm.active:
		_fail("sketch session did not start on face %s" % face_id)


## Removed as a film helper: arbitrary planes are not clickable in the UI yet.
## Validation tests may call SketchMode.begin_on_plane / main._start_sketch_on_plane.
static func enter_sketch_on_plane(_ctx: FilmContext, _origin: Vector3, _x_dir: Vector3, _y_dir: Vector3) -> void:
	_fail("enter_sketch_on_plane is not a user-clickable path — place a solid and use enter_sketch_on_face, or call begin_on_plane from a validation test")


static func exit_sketch(ctx: FilmContext) -> String:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return last_feature_id(ctx.view.doc, "sketch")
	var exit_btn := find_sketch_tool_button(ctx.main, "Exit Sketch")
	if not await click_control(ctx, exit_btn, FilmUICues.exit_sketch()):
		return ""
	await wait_frames(ctx.tree, 3)
	if sm.active:
		_fail("sketch still active after Exit Sketch click")
		return ""
	return last_feature_id(ctx.view.doc, "sketch")


static func merge_sketches_ui(ctx: FilmContext, mode: String) -> void:
	var action := "merge_join"
	match mode:
		"join_endpoints", "merge_join":
			action = "merge_join"
		"bridge_spline", "merge_spline":
			action = "merge_spline"
		"composite", "merge_composite":
			action = "merge_composite"
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
	var cam = ctx.main.camera
	if cam != null and cam.has_method("set_view"):
		# Stable three-quarter view; avoid frame_contents after Hide (empty AABB).
		cam.pivot = Vector3(0, 0, 2)
		cam.distance = 40.0
		cam.set_view(deg_to_rad(-45.0), deg_to_rad(30.0), false)
		await wait_frames(ctx.tree, 2)
	var screen_pos := pad_screen_center(ctx, feature_id)
	if screen_pos == Vector2.ZERO:
		_fail("could not project pad %s to screen" % feature_id)
		return
	var vp := ctx.tree.root.get_viewport().get_visible_rect()
	if not vp.has_point(screen_pos):
		_fail("pad %s projects off-viewport at %s (vp %s)" % [feature_id, str(screen_pos), str(vp)])
		return
	var ix = ctx.main.interaction
	if ix != null and ctx.view.sketch_pads != null and ix.has_method("_model_ray"):
		var ray: Array = ix._model_ray(screen_pos)
		var resolved: String = ctx.view.sketch_pads.pick_pad(ray[0], ray[1])
		if resolved != feature_id:
			_fail("pad ray at %s resolved to '%s' (want %s)" % [str(screen_pos), resolved, feature_id])
			return
	await viewport_click(ctx, screen_pos, FilmUICues.ctrl_pad(), true)
	if feature_id not in ctx.main.selected_sketch_pads:
		_fail("pad %s not in multi-selection after Ctrl+click (have %s)" \
				% [feature_id, str(ctx.main.selected_sketch_pads)])


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


static func draw_polyline(ctx: FilmContext, sm: SketchMode, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	await select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click_sketch(ctx, sm, points[0], "Line — start")
	for i in range(1, points.size()):
		await click_sketch(ctx, sm, points[i], "Line — next point")


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
	var sweep_btn := find_button(sk_chrome, "Sweep path")
	if not await click_control(ctx, sweep_btn, FilmUICues.alert("Sweep", "Sweep profile along path")):
		return
	await wait_frames(ctx.tree, 4)
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


static func ensure_create_rail(ctx: FilmContext) -> void:
	# After a place, the body stays selected and the palette hides. Click empty
	# viewport so the next create verb is visible — same path a user takes.
	var pal: CanvasItem = ctx.main.palette if ctx.main != null else null
	if pal != null and pal.is_visible_in_tree():
		return
	await viewport_click(ctx, viewport_empty_click_pos(ctx),
			FilmUICues.alert("Click", "Clear selection — show create rail"))
	if ctx.main != null and ctx.main.has_method("_update_panel_visibility"):
		ctx.main._update_panel_visibility()
	await wait_frames(ctx.tree, 2)


static func place_primitive(ctx: FilmContext, kind: String) -> void:
	await ensure_create_rail(ctx)
	var b := find_palette_button(ctx.main, kind)
	if not await click_control(ctx, b, FilmUICues.place_primitive(kind)):
		return
	await wait_frames(ctx.tree, 2)
	var ix = ctx.main.interaction
	if ix == null:
		_fail("interaction missing for place_primitive")
		return
	var center: Vector2
	if ix.has_method("_screen_center"):
		center = ix._screen_center()
	else:
		center = ctx.tree.root.get_viewport().get_visible_rect().size * 0.5
	await viewport_click(ctx, center, FilmUICues.place_click(kind))
	if ctx.chrome != null:
		ctx.chrome.clear_keys()


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
