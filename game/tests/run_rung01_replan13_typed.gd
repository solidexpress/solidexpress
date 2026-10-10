# Rung 1 replan 13 WP8 — polygon preview follows the pointer; Distance never flashes.
# Real events: Viewport.push_input (motion, keys). Preview verts from
# sm._preview_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_typed.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan13 WP8 polygon preview / Distance flash")
	FilmUI.reset_fail_count()
	await _run()
	finish()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	check(sm.active, "sketch session is open")
	sm.status.connect(_on_status)
	sm.snap_enabled = false

	await test_part_a_polygon_preview(ctx)
	await test_part_b_distance_flash(ctx)

	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	main.queue_free()
	await process_frame
	await process_frame


func test_part_a_polygon_preview(ctx: FilmContext) -> void:
	print("-- Part A: polygon preview follows the pointer")
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.POLYGON)
	sm.set_tool(SketchMode.Tool.POLYGON)
	check(sm.tool == SketchMode.Tool.POLYGON, "Polygon tool is active")
	check(sm.tool_variant == "across_flats",
			"polygon variant is across_flats (got %s)" % sm.tool_variant)
	await _zoom_uv(ctx, Vector2.ZERO, 80.0)

	await _click_uv(ctx, Vector2.ZERO, "Polygon centre")
	await process_frame
	check(sm.has_single_dof_preview() and sm._tool_points.size() == 1,
			"centre click left a single-DOF polygon preview (points=%d)" % sm._tool_points.size())
	var dim_edit := _dim_edit(ctx.main.sketch_chrome)
	print("  probe after centre: hover=%s points=%s dim_focus=%s dim_editing=%s" % [
			str(sm._hover), str(sm._tool_points),
			str(dim_edit != null and dim_edit.has_focus()),
			str(ctx.main.sketch_chrome.dim_is_editing() if ctx.main.sketch_chrome else false)])

	var tips: Array[Vector2] = [Vector2(14, 6), Vector2(10, 12), Vector2(-12, 9)]
	var last_preview: Array[Vector2] = []
	for tip in tips:
		await _motion_uv(ctx, tip)
		await process_frame
		var hex := _preview_hex_uvs(sm)
		var r := _circumradius(hex, Vector2.ZERO)
		var expect_r := tip.length()
		print("  probe motion %s: hover=%s verts=%d r=%.6f expect=%.6f focus=%s" % [
				str(tip), str(sm._hover), hex.size(), r, expect_r,
				str(root.gui_get_focus_owner())])
		check(hex.size() > 0,
				"preview vertices are non-zero after motion %s (got %d)" % [str(tip), hex.size()])
		check(absf(r - expect_r) <= 1e-3,
				"preview circumradius follows |tip| at %s (got %.6f want %.6f)" % [
					str(tip), r, expect_r])
		last_preview = hex
	print("  probe last steered preview verts=%d %s" % [last_preview.size(), str(last_preview)])

	# Duplicate session: click(tip) on a second polygon (helpers are allowed
	# for the comparison session; the follow check above used push_input).
	print("-- Part A: pointer-steered preview equals click(tip) commit")
	var steered_tip := tips[tips.size() - 1]
	var before_commit: PackedStringArray = sm.sketch.entity_ids()
	var dup_c := Vector2(22.0, 12.0)
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.click(dup_c)
	sm.hover(dup_c + steered_tip)
	await process_frame
	var dup_preview := _preview_hex_uvs(sm)
	sm.click(dup_c + steered_tip)
	await process_frame
	var committed := _committed_hex_uvs(sm, before_commit)
	print("  probe commit: preview=%d committed=%d last_commit='%s'" % [
			dup_preview.size(), committed.size(), sm.last_commit_text()])
	check(_verts_match(dup_preview, committed, 1e-4),
			"pointer-steered preview equals click(tip) commit (preview %s commit %s)" % [
				str(dup_preview), str(committed)])

	# Typed AF 20 on a fresh centre, pointer off-axis, real keys into the AF blank.
	print("-- Part A: type AF 20, flats horizontal")
	_status_log.clear()
	sm.set_tool(SketchMode.Tool.POLYGON)
	await _click_uv(ctx, Vector2.ZERO, "Typed hex centre")
	await _motion_uv(ctx, steered_tip)
	await process_frame
	if dim_edit != null:
		await _click_control(dim_edit)
		await _click_control(dim_edit)
	await _type_keys(ctx.main.get_viewport(), "20")
	await process_frame
	var typed_preview := _preview_hex_uvs(sm)
	var typed_r := _circumradius(typed_preview, Vector2.ZERO)
	var typed_af_r := 20.0 / sqrt(3.0)
	check(absf(typed_r - typed_af_r) <= 1e-3,
			"typed AF 20 preview radius is 20/√3 (got %.6f want %.6f)" % [typed_r, typed_af_r])
	check(_flats_horizontal_at(typed_preview, 10.0),
			"typed AF 20 preview is flats horizontal at |y|=10")
	var before_typed: PackedStringArray = sm.sketch.entity_ids()
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	await process_frame
	await process_frame
	var typed_commit := _committed_hex_uvs(sm, before_typed)
	var typed_status := _joined_status()
	check(typed_status.contains("Polygon AF 20.0000 — flats horizontal"),
			"Enter commits Polygon AF 20.0000 — flats horizontal (log: %s)" % typed_status)
	check(_verts_match(typed_preview, typed_commit, 1e-4),
			"Enter commits the same vertex set as the typed preview")
	check(_flats_horizontal_at(typed_commit, 10.0),
			"committed hexagon has horizontal flats at y = ±10")

	# Vertex variant: preview equals commit, no behaviour change.
	print("-- Part A: vertex variant preview equals commit")
	sm.set_tool_variant("vertex")
	check(sm.tool_variant == "vertex", "vertex variant is armed")
	var vtx_c := Vector2(-22.0, 12.0)
	var vtx_tip := vtx_c + Vector2(14, 6)
	var before_vtx: PackedStringArray = sm.sketch.entity_ids()
	sm.set_tool(SketchMode.Tool.POLYGON)
	sm.click(vtx_c)
	sm.hover(vtx_tip)
	await process_frame
	var vtx_preview := _preview_hex_uvs(sm)
	sm.click(vtx_tip)
	await process_frame
	var vtx_commit := _committed_hex_uvs(sm, before_vtx)
	check(vtx_preview.size() > 0, "vertex variant preview has vertices")
	check(_verts_match(vtx_preview, vtx_commit, 1e-4),
			"vertex variant preview equals commit")
	sm.set_tool_variant("across_flats")


func test_part_b_distance_flash(ctx: FilmContext) -> void:
	print("-- Part B: Distance field never flashes the old value")
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist: SpinBox = chrome.find_child("DistanceSpin", true, false)
	check(dist != null, "DistanceSpin exists")
	if dist == null:
		return
	var edit := dist.get_line_edit()
	var readout: Label = chrome.find_child("ExtrudeReadout", true, false)
	check(edit != null and readout != null, "Distance LineEdit and ExtrudeReadout exist")

	chrome.focus_distance_for_typing("20")
	await process_frame
	await process_frame
	check(is_equal_approx(dist.value, 20.0), "Distance starts at 20")

	print("-- Part B: focused keys 1, 4, Enter")
	await _click_control(edit)
	await _click_control(edit)
	check(edit.has_focus(), "Distance is focused (E-focus / click path)")
	var focused_samples: Array[Dictionary] = []
	await _type_and_spy(edit, readout, "1", focused_samples)
	await _type_and_spy(edit, readout, "4", focused_samples)
	await _push_key(edit.get_viewport(), KEY_ENTER, 0)
	for i in 5:
		await process_frame
		focused_samples.append(_spy_sample(edit, readout, "enter_frame_%d" % i))
	_print_spy("focused 14", focused_samples)
	_assert_no_old_value(focused_samples, "20", "focused 1/4/Enter")
	check(_last_parses_to(focused_samples, 14.0),
			"last focused sample parses to 14 (got %s)" % str(focused_samples[focused_samples.size() - 1]))
	_assert_readout_matches_field(focused_samples, "focused 1/4/Enter")

	print("-- Part B: unfocused burst focus_distance_for_typing(\"14\")")
	chrome.focus_distance_for_typing("20")
	await process_frame
	await process_frame
	var burst_samples: Array[Dictionary] = []
	burst_samples.append(_spy_sample(edit, readout, "before_burst"))
	chrome.focus_distance_for_typing("14")
	burst_samples.append(_spy_sample(edit, readout, "burst_immediate"))
	for i in 5:
		await process_frame
		burst_samples.append(_spy_sample(edit, readout, "burst_frame_%d" % i))
	_print_spy("burst 14", burst_samples)
	# The sample taken before the burst is allowed to show 20.
	var after_burst: Array[Dictionary] = []
	for i in range(1, burst_samples.size()):
		after_burst.append(burst_samples[i])
	_assert_no_old_value(after_burst, "20", "unfocused burst")
	check(_last_parses_to(after_burst, 14.0),
			"last burst sample parses to 14 (got %s)" % str(after_burst[after_burst.size() - 1]))
	_assert_readout_matches_field(after_burst, "unfocused burst")

	print("-- Part B: Escape restores distance_origin 20")
	chrome.focus_distance_for_typing("20")
	await process_frame
	await process_frame
	await _click_control(edit)
	await _click_control(edit)
	await _type_keys(edit.get_viewport(), "14")
	await process_frame
	var esc_samples: Array[Dictionary] = []
	print("  probe before Escape: origin=%s text='%s' focus=%s" % [
			str(chrome._distance_origin), edit.text, str(edit.has_focus())])
	esc_samples.append(_spy_sample(edit, readout, "before_esc"))
	await _push_key(edit.get_viewport(), KEY_ESCAPE, 0)
	esc_samples.append(_spy_sample(edit, readout, "esc_immediate"))
	for i in 5:
		await process_frame
		esc_samples.append(_spy_sample(edit, readout, "esc_frame_%d" % i))
	_print_spy("escape restore", esc_samples)
	var last_esc: Dictionary = esc_samples[esc_samples.size() - 1]
	check(_sample_parses_to(last_esc, 20.0),
			"Escape restores distance_origin 20 (last sample %s)" % str(last_esc))
	var third := false
	for s in esc_samples:
		var n: Variant = _parse_first_float(str(s.get("text", "")))
		if n != null and not is_equal_approx(float(n), 14.0) and not is_equal_approx(float(n), 20.0):
			third = true
	check(not third, "Escape never shows an intermediate third value (samples %s)" % str(esc_samples))


func _assert_no_old_value(samples: Array[Dictionary], old: String, label: String) -> void:
	var saw := false
	for s in samples:
		var t := str(s.get("text", ""))
		if t.contains(old):
			saw = true
			printerr("  spy %s saw old value in %s" % [label, str(s)])
	check(not saw, "%s: no sample contains %s after the first key" % [label, old])


func _assert_readout_matches_field(samples: Array[Dictionary], label: String) -> void:
	var mismatch := false
	for s in samples:
		var field_n: Variant = _parse_first_float(str(s.get("text", "")))
		var read_n: Variant = _parse_first_float(str(s.get("readout", "")))
		if field_n == null or read_n == null:
			continue
		if not is_equal_approx(float(field_n), float(read_n)):
			mismatch = true
			printerr("  spy %s readout != field at %s" % [label, str(s)])
	check(not mismatch, "%s: ExtrudeReadout equals the field on every parsable sample" % label)


func _last_parses_to(samples: Array[Dictionary], v: float) -> bool:
	if samples.is_empty():
		return false
	return _sample_parses_to(samples[samples.size() - 1], v)


func _sample_parses_to(s: Dictionary, v: float) -> bool:
	var n: Variant = _parse_first_float(str(s.get("text", "")))
	return n != null and is_equal_approx(float(n), v)


func _spy_sample(edit: LineEdit, readout: Label, tag: String) -> Dictionary:
	return {
		"tag": tag,
		"text": "" if edit == null else str(edit.text),
		"readout": "" if readout == null else str(readout.text),
	}


func _print_spy(label: String, samples: Array[Dictionary]) -> void:
	print("  spy %s (%d samples):" % [label, samples.size()])
	for s in samples:
		print("    %s text='%s' readout='%s'" % [
			str(s.get("tag", "")), str(s.get("text", "")), str(s.get("readout", ""))])


func _type_and_spy(edit: LineEdit, readout: Label, ch: String, samples: Array[Dictionary]) -> void:
	var code := KEY_PERIOD if ch == "." else ((KEY_0 + (ch.unicode_at(0) - 48)) as Key)
	await _push_key(edit.get_viewport(), code, ch.unicode_at(0))
	samples.append(_spy_sample(edit, readout, "key_%s" % ch))


func _preview_hex_uvs(sm: SketchMode) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if sm == null or sm._preview_node == null or sm._preview_node.mesh == null:
		return out
	var mesh: Mesh = sm._preview_node.mesh
	if mesh.get_surface_count() < 1:
		return out
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return out
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return out
	# Circle preview is 48 segments (96 verts); the hex edges are appended after.
	var start := maxi(0, verts.size() - 12)
	for i in range(start, verts.size()):
		var uv := _uv_from_model(sm, verts[i])
		var dup := false
		for p in out:
			if p.distance_to(uv) <= 1e-5:
				dup = true
				break
		if not dup:
			out.append(uv)
	return out


func _committed_hex_uvs(sm: SketchMode, skip: PackedStringArray) -> Array[Vector2]:
	var skip_set := {}
	for id in skip:
		skip_set[id] = true
	var out: Array[Vector2] = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		if skip_set.has(id):
			continue
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		for key in ["start", "end"]:
			var v: Vector2 = info[key]
			var dup := false
			for p in out:
				if p.distance_to(v) <= 1e-5:
					dup = true
					break
			if not dup:
				out.append(v)
	return out


func _circumradius(verts: Array[Vector2], c: Vector2) -> float:
	var best := 0.0
	for p in verts:
		best = maxf(best, p.distance_to(c))
	return best


func _flats_horizontal_at(verts: Array[Vector2], half_af: float) -> bool:
	if verts.size() < 6:
		return false
	var plus := false
	var minus := false
	# Unique-vertex order is not edge order; scan every pair.
	for i in verts.size():
		for j in range(i + 1, verts.size()):
			var a2: Vector2 = verts[i]
			var b2: Vector2 = verts[j]
			if absf(a2.y - b2.y) > 1e-3:
				continue
			if a2.distance_to(b2) < 1.0:
				continue
			if absf(a2.y - half_af) <= 0.05:
				plus = true
			if absf(a2.y + half_af) <= 0.05:
				minus = true
	return plus and minus


func _verts_match(a: Array[Vector2], b: Array[Vector2], tol: float) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	var used: Array[bool] = []
	used.resize(b.size())
	used.fill(false)
	for p in a:
		var found := false
		for i in b.size():
			if used[i]:
				continue
			if p.distance_to(b[i]) <= tol:
				used[i] = true
				found = true
				break
		if not found:
			return false
	return true


func _uv_from_model(sm: SketchMode, p: Vector3) -> Vector2:
	var d := p - sm.plane_origin
	return Vector2(d.dot(sm.plane_x), d.dot(sm.plane_y))


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	var spin: SpinBox = chrome.find_child("DimSpin", true, false)
	if spin == null:
		return null
	return spin.get_line_edit()


func _parse_first_float(raw: String) -> Variant:
	var text := raw.strip_edges()
	var buf := ""
	var seen := false
	for i in text.length():
		var ch := text.substr(i, 1)
		var ok := (ch >= "0" and ch <= "9") or ch == "." or (ch == "-" and not seen)
		if ok:
			buf += ch
			seen = true
		elif seen:
			break
	if buf.is_empty() or not buf.is_valid_float():
		return null
	return float(buf)


func _click_control(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _click_at(ctrl.get_viewport(), pos)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "on screen: %s" % desc)
	await _click_at(ctx.main.get_viewport(), screen)


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)


func _click_at(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _type_keys(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_PERIOD if ch == 46 else ((KEY_0 + (ch - 48)) as Key)
		await _push_key(vp, code, ch)


func _push_key(vp: Viewport, keycode: Key, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	await process_frame
	var rel := InputEventKey.new()
	rel.keycode = keycode
	rel.physical_keycode = keycode
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await _zoom_model(ctx, sm.to_model(uv), size_mm)


func _zoom_model(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
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


func _joined_status() -> String:
	if _status_log.is_empty():
		return ""
	return " | ".join(_status_log)


func _on_status(text: String) -> void:
	_status_log.append(text)
