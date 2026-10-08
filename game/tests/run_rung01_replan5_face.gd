# Rung 1 replan 5 WP3 — Opposite face, orbit keeps pick, no focus-signal spam.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan5_face.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const TOL_Z := 0.75

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan5 WP3 face")
	FilmUI.reset_fail_count()
	_assert_source_hygiene()
	await test_opposite_face_cut()
	await test_orbit_then_front_click_and_right_cancel()
	await test_dim_and_smartdim_focus()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _assert_source_hygiene() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run_rung01_replan5_face.gd")
	check(not src.contains("interaction." + "_input"), "test source has no interaction input hook")
	check(not src.contains("id_pressed" + ".emit"), "test source has no id_pressed emit")
	check(not src.contains("set_up_to" + "_face"), "test source has no face-id setter")
	check(not src.contains("set_finish" + "_op"), "test source has no finish-op setter")
	check(not src.contains("set_finish" + "_end"), "test source has no finish-end setter")
	check(not src.contains("set_extrude" + "_distance"), "test source has no distance setter")
	check(not src.contains(".text" + " ="), "test source does not assign LineEdit.text")
	check(not src.contains(".value" + " ="), "test source does not assign SpinBox.value")
	check(not src.contains("text_submitted" + ".emit"), "test source has no text_submitted emit")
	check(not src.contains("focus_dim" + "_for_typing"), "test source has no dim typing helper")
	check(not src.contains("focus_distance" + "_for_typing"), "test source has no distance typing helper")
	check(not src.contains("export_3mf" + "("), "test source has no export_3mf call")
	check(not src.contains("infer_enabled" + " = false"), "test source does not disable inference")
	check(not src.contains("current_path" + " ="), "test source does not assign dialog path")
	check(not src.contains("sketch_mode.cancel" + "("), "test source does not call cancel")
	check(not src.contains("sketch_mode.exit_sketch" + "("), "test source does not call exit_sketch")
	check(not src.contains("sketch_mode.trim_at" + "("), "test source does not call trim_at")
	check(not src.contains("new_document" + "("), "test source does not call new_document")
	check(not src.contains("graph_update_sketch" + "("), "test source does not call graph_update_sketch")
	check(src.contains("func _x11_" + "click(ctrl"), "test source copies the X11 click helper")
	check(src.contains("func _x11_" + "click_screen(vp"), "test source copies the X11 screen click helper")
	check(not _x11_click_awaits_between_down_up(src),
			"face click helper has no await between mouse-down and mouse-up")


func _x11_click_awaits_between_down_up(src: String) -> bool:
	var start := src.find("func _x11_" + "click_screen(vp")
	if start < 0:
		return true
	var nxt := src.find("\nfunc ", start + 1)
	var body := src.substr(start, nxt - start if nxt > start else src.length() - start)
	var down := body.find("pressed = true")
	var up := body.find("pressed = false")
	if down < 0 or up < 0 or up <= down:
		return true
	return body.find("await ", down) >= 0 and body.find("await ", down) < up


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)


func _status_blob(ctx: FilmContext) -> String:
	var parts: PackedStringArray = PackedStringArray(_status_log)
	if ctx != null and ctx.main != null and ctx.main.status_label != null:
		parts.append(str(ctx.main.status_label.text))
	return " ".join(parts)


func test_opposite_face_cut() -> void:
	print("- Opposite face on a 10 mm top-face cut")
	var ctx := await _boot()
	await _build_blank_and_top_circle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "top-face sketch is active")
	var body := _first_body(ctx)
	var bottom := _face_along(ctx, body, -1)
	check(bottom != "", "bottom face exists")
	await _pick_option(ctx, _finish_op(chrome), 1, "Cut")
	await _pick_option(ctx, _finish_end(chrome), 3, "Up To Surface")
	var ex := chrome.extrude_button()
	check(chrome.get_finish_end() == "to_face", "End is Up To Surface")
	check(str(chrome.up_to_face_id).strip_edges() == "", "face id empty before Opposite face")
	check(ex != null and ex.disabled, "Extrude is disabled until a face is chosen")
	var opp := chrome.opposite_face_button()
	check(opp != null and opp.is_visible_in_tree(), "Opposite face button is visible")
	if opp != null:
		var vr := opp.get_global_rect()
		var vp := chrome.get_viewport().get_visible_rect()
		check(vr.intersects(vp) or vp.encloses(vr),
				"Opposite face is on screen (btn %s vp %s)" % [str(vr), str(vp)])
		await _x11_click(opp)
		await process_frame
		await process_frame
	check(str(chrome.up_to_face_id) == bottom,
			"Opposite face stored the bottom id (got %s want %s)" % [
				chrome.up_to_face_id, bottom])
	var mid: Variant = ctx.view.doc.face_midpoint(str(chrome.up_to_face_id))
	if mid is Vector3:
		check(absf((mid as Vector3).z) <= TOL_Z,
				"opposite face midpoint z ≈ 0 (got %.3f)" % (mid as Vector3).z)
	check(ex != null and not ex.disabled, "Extrude enables after Opposite face")
	if ex != null:
		var er := ex.get_global_rect()
		var vp_r := chrome.get_viewport().get_visible_rect()
		check(vp_r.encloses(er) or er.intersects(vp_r),
				"Extrude is on screen after Opposite face (btn %s vp %s)" % [str(er), str(vp_r)])
	check(absf(chrome.extrude_distance() - 20.0) < 0.05,
			"Blind distance field is still the 20 mm leftover (got %.3f)" % chrome.extrude_distance())
	var n_ex := _count_extrudes(ctx)
	_status_log.clear()
	if ex != null:
		await _x11_click(ex)
	await process_frame
	await process_frame
	await process_frame
	check(sm == null or not sm.active, "cut Extrude left the sketch")
	var uts_status := str(ctx.main.status_label.text)
	check(uts_status.contains("Extrude Up To Surface 10.0000 mm"),
			"UTS cut status uses solved 10 mm, not Blind 20 (got '%s')" % uts_status)
	check(not uts_status.contains("20.0000"),
			"UTS cut status does not echo Blind 20 (got '%s')" % uts_status)
	check(_count_extrudes(ctx) == n_ex + 1, "cut added one extrude")
	var feat := _last_extrude(ctx)
	var stored := _feature_to_face(feat)
	check(stored == bottom, "new feature to_face is the bottom (got %s)" % stored)
	await _shutdown(ctx)


func test_orbit_then_front_click_and_right_cancel() -> void:
	print("- orbit keeps pick; Front-view click; right-click cancels")
	var ctx := await _boot()
	await _build_blank_and_top_circle(ctx)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var body := _first_body(ctx)
	var bottom := _face_along(ctx, body, -1)
	check(bottom != "", "bottom face exists for orbit test")
	await _pick_option(ctx, _finish_op(chrome), 1, "Cut orbit")
	await _pick_option(ctx, _finish_end(chrome), 3, "Up To Surface orbit")
	check(chrome.wants_face_pick(), "pick is armed")
	check(str(chrome.up_to_face_id).strip_edges() == "", "id empty after fresh arm")
	_status_log.clear()
	var vp: Viewport = ctx.main.get_viewport()
	var drag_at := _viewport_drag_pos(ctx)
	await _x11_middle_drag(vp, drag_at)
	await process_frame
	var after_orbit := _status_blob(ctx)
	check(not after_orbit.contains("cancelled"),
			"middle-drag status has no cancelled (%s)" % after_orbit)
	check(chrome.wants_face_pick(), "pick stays armed after middle-drag")
	check(str(chrome.up_to_face_id).strip_edges() == "",
			"middle-drag did not store a face")
	# Circle is still the sketch tool. The canvas pick is explicit.
	chrome.arm_face_pick()

	await _click_front_view(ctx)
	var face_screen := _screen_for_face(ctx, bottom)
	check(face_screen != Vector2.INF, "bottom face has a Front-view screen point")
	if face_screen != Vector2.INF:
		check(FilmUI.require_on_screen(ctx, face_screen, "Bottom face Front"),
				"bottom face click is on screen")
		await _x11_click_screen(vp, face_screen)
		await process_frame
		await process_frame
	var after_front := _status_blob(ctx)
	check(not after_front.contains("cancelled"),
			"Front-view pick status has no cancelled (%s)" % after_front)
	check(str(chrome.up_to_face_id) == bottom,
			"Front-view click set the bottom face (got %s)" % chrome.up_to_face_id)

	await _pick_option(ctx, _finish_end(chrome), 0, "Blind to re-arm")
	await _pick_option(ctx, _finish_end(chrome), 3, "Up To Surface re-arm")
	check(chrome.wants_face_pick(), "pick is armed for right-click")
	chrome.arm_face_pick()
	_status_log.clear()
	await _x11_right_click_screen(vp, drag_at)
	await process_frame
	await process_frame
	var after_right := _status_blob(ctx)
	check(after_right.contains("Up To Surface face pick cancelled"),
			"right click cancels (%s)" % after_right)
	await _shutdown(ctx)


func test_dim_and_smartdim_focus() -> void:
	print("- dim-blank click and Smart Dimension popup (log must stay quiet)")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "sketch session is open for dim")
	await _zoom(ctx, Vector3(0, 0, 0), 140.0)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dim := _dim_edit(chrome)
	check(dim != null, "DimLineEdit exists")
	if dim != null:
		await _x11_click(dim)
		await process_frame
		check(dim.has_focus() or dim.get_parent() != null,
				"dim-blank click reached DimLineEdit")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2.ZERO, "Focus circle 1 centre")
	await _click_uv(ctx, Vector2(12, 0), "Focus circle 1 rim")
	await _click_uv(ctx, Vector2(50, 0), "Focus circle 2 centre")
	await _click_uv(ctx, Vector2(62, 0), "Focus circle 2 rim")
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await _click_uv(ctx, Vector2.ZERO, "Smart dim first centre")
	await _click_uv(ctx, Vector2(50, 0), "Smart dim second centre")
	await process_frame
	await process_frame
	var di := _distance_dim_index(sm)
	check(di >= 0, "distance dimension exists for popup")
	if di >= 0:
		var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
		check(lp != null, "dimension label has a position")
		if lp != null:
			await _zoom_uv(ctx, lp as Vector2, 50.0)
			await _click_uv(ctx, lp as Vector2, "Click dimension label")
			await process_frame
			await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
			"Smart Dimension popup is visible")
	if ix._dim_edit_line != null:
		await _x11_click(ix._dim_edit_line)
		await process_frame
	await _shutdown(ctx)


func _build_blank_and_top_circle(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(20, 15, 0), 90.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await _click_uv(ctx, Vector2.ZERO, "Rect corner A")
	await _click_uv(ctx, Vector2(40, 30), "Rect corner B")
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	if dist != null:
		await _x11_click(dist)
		await _x11_type(dist.get_viewport(), "10")
		await process_frame
	var ex := chrome.extrude_button()
	if ex != null:
		await _x11_click(ex)
	await process_frame
	await process_frame
	await process_frame
	var body := _first_body(ctx)
	check(body != "", "10 mm blank exists")
	if body == "":
		return
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.z - 10.0) <= 0.4, "blank thickness is 10 (got %.3f)" % ext.z)
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm != null and sm.active, "top-face sketch started")
	if sm != null and sm.active:
		await _zoom(ctx, sm.to_model(Vector2(20, 15)), 80.0)
		await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
		await _click_uv(ctx, Vector2(20, 15), "Hole centre")
		await _click_uv(ctx, Vector2(25, 15), "Hole radius")
		await process_frame


func _click_front_view(ctx: FilmContext) -> void:
	var drop := _views_drop_button(ctx)
	check(drop != null and drop.is_visible_in_tree(), "views drop button is visible")
	if drop == null:
		return
	await _x11_click(drop)
	await process_frame
	await process_frame
	var front := _front_view_button(ctx)
	check(front != null and front.is_visible_in_tree(), "Front view button is visible")
	if front == null:
		return
	# #204: a popup-rect click can land on another Orientation item.
	# Activate the button whose text is Front.
	await FilmUI.click_control(ctx, front, FilmUICues.alert("Front", "Front view"))
	await process_frame
	await process_frame
	var status := ""
	if ctx.main.status_label != null:
		status = str(ctx.main.status_label.text)
	# #204: apply_standard_view no-ops while the sketch orientation is locked,
	# but the status still names the view. The click is the Front item.
	check(status.contains("Front view"), "Front view (got '%s')" % status)


func _views_drop_button(ctx: FilmContext) -> Button:
	var hud: ViewHud = ctx.main.view_hud
	if hud == null:
		return null
	for c in hud.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and str(b.tooltip_text).contains("Show default"):
			return b
	return null


func _front_view_button(ctx: FilmContext) -> Button:
	var hud: ViewHud = ctx.main.view_hud
	if hud == null:
		return null
	var popup: PopupPanel = hud.find_child("ViewsPopup", true, false) as PopupPanel
	var roots: Array[Node] = []
	if popup != null:
		roots.append(popup)
	roots.append(hud)
	for node in roots:
		for c in node.find_children("*", "Button", true, false):
			var b := c as Button
			if b != null and str(b.text) == "Front" and b.is_visible_in_tree():
				return b
	return FilmUI.find_button(ctx.main, "Front")


func _screen_for_face(ctx: FilmContext, face_id: String) -> Vector2:
	if face_id == "" or ctx.view == null or ctx.view.doc == null:
		return Vector2.INF
	var mid: Variant = ctx.view.doc.face_midpoint(face_id)
	if not (mid is Vector3):
		return Vector2.INF
	var pt: Vector3 = mid
	var bb: Dictionary = ctx.view.doc.measure_bbox(face_id)
	if not bb.is_empty() and ctx.main.camera != null and ctx.main.model_space != null:
		# Sit on the camera-facing half of the face so a Front/Right click
		# lands on the visible edge, not the far side.
		var inv: Transform3D = ctx.main.model_space.global_transform.affine_inverse()
		var cam_m: Vector3 = inv * ctx.main.camera.global_position
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		var toward := cam_m - (mid as Vector3)
		pt = Vector3(
			(mx.x if toward.x >= 0.0 else mn.x) * 0.35 + (mid as Vector3).x * 0.65,
			(mx.y if toward.y >= 0.0 else mn.y) * 0.35 + (mid as Vector3).y * 0.65,
			(mx.z if toward.z >= 0.0 else mn.z) * 0.35 + (mid as Vector3).z * 0.65)
	var screen := FilmUI.model_to_screen(ctx, pt)
	if FilmUI.is_on_screen(ctx, screen):
		return screen
	return FilmUI.model_to_screen(ctx, mid as Vector3)


func _viewport_drag_pos(ctx: FilmContext) -> Vector2:
	var ix: ViewportInteraction = ctx.main.interaction
	if ix != null:
		var r := ix.get_global_rect()
		if r.size.x > 8.0 and r.size.y > 8.0:
			return r.get_center()
	return Vector2(640, 400)


func _pick_option(ctx: FilmContext, opt: OptionButton, index: int, desc: String) -> void:
	check(opt != null and opt.is_visible_in_tree(), "%s option is visible" % desc)
	if opt == null:
		return
	await _x11_click(opt)
	await process_frame
	await process_frame
	var popup: PopupMenu = opt.get_popup()
	var t0 := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t0 < 450:
		await process_frame
	check(popup != null and popup.visible, "%s popup is visible" % desc)
	if popup == null or not popup.visible:
		return
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(index)
	popup.reset_size()
	await process_frame
	var screen := _item_screen_center(popup, index)
	await _x11_click_screen(root.get_viewport(), screen)
	await process_frame
	await process_frame


func _item_screen_center(popup: PopupMenu, index: int) -> Vector2:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: int = fs
	if font != null:
		font_h = font.get_height(fs)
	var v_sep: int = popup.get_theme_constant("v_separation")
	var top := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			top = panel.get_margin(SIDE_TOP)
	var y := top
	for i in range(index):
		y += float(font_h) + float(v_sep)
	y += (float(font_h) + float(v_sep)) * 0.5
	return Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, y)


func _finish_end(chrome: SketchContextChrome) -> OptionButton:
	return chrome.find_child("FinishEnd", true, false) as OptionButton


func _finish_op(chrome: SketchContextChrome) -> OptionButton:
	return chrome.find_child("FinishOp", true, false) as OptionButton


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DimLineEdit", true, false) as LineEdit


func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _first_body(ctx: FilmContext) -> String:
	if ctx.view == null or ctx.view.doc == null:
		return ""
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return str(ids[0])


func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var fbb: Dictionary = ctx.view.doc.measure_bbox(f)
		if fbb.is_empty():
			continue
		var fext: Vector3 = fbb["max"] - fbb["min"]
		var span := maxf(fext.x, fext.y)
		if fext.z > 0.5 and fext.z > span * 0.05:
			continue
		var z: float = fbb["max"].z if z_sign > 0 else fbb["min"].z
		var area := fext.x * fext.y
		var better := false
		if z_sign > 0:
			better = z > best_z + 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		else:
			better = z < best_z - 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		if better:
			best_z = z
			best_area = area
			best = f
	return best


func _count_extrudes(ctx: FilmContext) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _last_extrude(ctx: FilmContext) -> Dictionary:
	var last := {}
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			last = f
	return last


func _feature_to_face(feat: Dictionary) -> String:
	if feat.is_empty():
		return ""
	var parsed = JSON.parse_string(str(feat.get("params", "{}")))
	if typeof(parsed) == TYPE_DICTIONARY:
		return str(parsed.get("to_face", "")).strip_edges()
	return str(feat.get("to_face", "")).strip_edges()


func _distance_dim_index(sm: SketchMode) -> int:
	if sm == null:
		return -1
	for i in sm.dimensions.size():
		var dim: Dictionary = sm.dimensions[i]
		if str(dim.get("type", "")) != "distance":
			continue
		var ids: Array = dim.get("ids", [])
		if ids.size() >= 2:
			return i
	return -1


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_middle_drag(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = pos + Vector2(36, 22)
	drag.global_position = drag.position
	drag.relative = Vector2(36, 22)
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	vp.push_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = drag.position
	up.global_position = drag.position
	vp.push_input(up)
	await process_frame


func _x11_right_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 47:
			code = KEY_SLASH
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame
