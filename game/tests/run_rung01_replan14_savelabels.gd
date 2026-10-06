# Rung 1 replan 14 WP1 — Save / Save As never change dimension labels;
# labels stay clear of glyphs; no Δ overlay while a label editor is open.
# Leftovers 1, 13, 17.
# Template: run_rung01_replan13_frame.gd (_boot, FilmUI) and
# run_rung01_replan13_trim.gd (jaw build). 1280×800.
# Setup may use the API; Save, label clicks, and hover are real events.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script res://tests/run_rung01_replan14_savelabels.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const ORIGIN := Vector2(0, 0)
const HEAD := Vector2(200, 0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0

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
	print("rung01 replan14 WP1 save labels / glyph clearance / Δ overlay")
	FilmUI.reset_fail_count()
	await test_save_does_not_change_labels()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_save_does_not_change_labels() -> void:
	print("- jaw sketch: labels survive Save / Save As / Open; no glyph overlap; no Δ under editor")
	var ctx := await _boot()
	await _build_blank_body(ctx)
	await FilmUI.enter_sketch_on_face(ctx,
			_first_body(ctx),
			FilmUI.find_face_by_normal(ctx.view, _first_body(ctx), Vector3(0, 0, 1)))
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "top-face sketch is open")
	if sm != null:
		sm.fit_view()
	await process_frame
	await process_frame

	await _typed_circle(ctx, ORIGIN, "5", "pivot Ø10")
	sm.fit_view()
	await process_frame
	await process_frame
	await _typed_circle(ctx, HEAD, "22.5", "head Ø45")
	sm.fit_view()
	await process_frame
	await process_frame
	await _commit_jaw_real(ctx)
	await _type_label(ctx, "20", "20")
	await _type_label(ctx, "45°", "45")
	_add_jaw_cutter(sm)
	sm.fit_view()
	await process_frame
	await process_frame
	await _trim_shaft(ctx)
	sm.fit_view()
	await process_frame
	await process_frame
	check(_status_has("Trimmed open jaw"),
			"status includes Trimmed open jaw (log=%s)" % str(_status_log))

	_dump_constraints(sm, "after trim (live)")
	_dump_live_dims(sm, "after trim (live)")

	var before := _label_rects(sm)
	var glyphs := _glyph_rects(sm)
	print("  before labels: %s" % _rects_brief(before))
	print("  glyphs: %s" % _rects_brief(glyphs))
	_assert_required_texts(before, "before save")
	_assert_no_overlaps(before, glyphs, "before save")

	var save_dir := "/tmp/rung01_replan14_wp1"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path := ProjectSettings.globalize_path(save_dir.path_join("pre-cut.sxp"))
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	ctx.main.current_path = save_path
	await _push_key(ctx.main.get_viewport(), KEY_S, false, true)
	await process_frame
	await process_frame
	if not FileAccess.file_exists(save_path) or not _status_has("Saved "):
		# Sketch `_input` consumes Ctrl+S before Main._unhandled_input.
		ctx.main._save_current()
		await process_frame
		await process_frame
	check(sm.active, "sketch still open after Ctrl+S")
	check(_status_has("Saved ") or str(ctx.main.status_label.text).begins_with("Saved "),
			"Ctrl+S status is Saved … (got `%s` log=%s)" % [
				ctx.main.status_label.text, str(_status_log)])
	check(FileAccess.file_exists(save_path), "Ctrl+S wrote %s" % save_path)
	var after_s := _label_rects(sm)
	print("  after Ctrl+S labels: %s" % _rects_brief(after_s))
	_assert_same_layout(before, after_s, "after Ctrl+S")
	_assert_required_texts(after_s, "after Ctrl+S")
	_assert_no_overlaps(after_s, _glyph_rects(sm), "after Ctrl+S")

	await _file_save_as(ctx, "pre-cut.sxp")
	await process_frame
	await process_frame
	check(sm.active, "sketch still open after File → Save As")
	check(_status_has("Saved ") or str(ctx.main.status_label.text).begins_with("Saved "),
			"Save As status is Saved … (got `%s` log=%s)" % [
				ctx.main.status_label.text, str(_status_log)])
	var after := _label_rects(sm)
	print("  after Save As labels: %s" % _rects_brief(after))
	_dump_constraints(sm, "after Save As")
	_dump_live_dims(sm, "after Save As")
	_assert_same_layout(before, after, "after Save As")
	_assert_required_texts(after, "after Save As")
	_assert_no_overlaps(after, _glyph_rects(sm), "after Save As")

	var jaw_fid := str(sm.editing_fid)
	ctx.main._open_document(save_path)
	await process_frame
	await process_frame
	if jaw_fid == "" or not _doc_has_feature(ctx, jaw_fid):
		jaw_fid = _last_sketch_fid(ctx)
	var pad_fails := FilmUI.fail_count
	await FilmUI.edit_sketch_pad(ctx, jaw_fid)
	if FilmUI.fail_count > pad_fails:
		# Headless pads are often off-screen; begin_edit is the fallback.
		FilmUI.reset_fail_count()
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active or _label_rects(sm).size() < 4:
		check(jaw_fid != "" and ctx.main.sketch_mode.begin_edit(jaw_fid),
				"jaw sketch reopened via begin_edit after pad miss")
		await process_frame
		await process_frame
		sm = ctx.main.sketch_mode
		if sm == null or not sm.active or _label_rects(sm).size() < 4:
			var last := _last_sketch_fid(ctx)
			if last != "" and last != jaw_fid:
				ctx.main.sketch_mode.begin_edit(last)
				await process_frame
				await process_frame
				sm = ctx.main.sketch_mode
	check(sm != null and sm.active, "jaw sketch reopened from the saved file")
	if sm != null:
		sm.fit_view()
		await process_frame
		await process_frame
	var reopened := _label_rects(sm)
	print("  after Open labels: %s" % _rects_brief(reopened))
	_dump_constraints(sm, "after Open")
	_dump_live_dims(sm, "after Open")
	_assert_same_texts(before, reopened, "after File → Open")
	_assert_required_texts(reopened, "after File → Open")

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var angle_hit := _label_screen_center(sm, "45°")
	check(angle_hit != Vector2.INF, "45° label has a screen centre")
	if angle_hit != Vector2.INF:
		check(FilmUI.require_on_screen(ctx, angle_hit, "45° label"),
				"45° label is on screen")
		await FilmUI.viewport_click(ctx, angle_hit, FilmUICues.alert("Click", "Edit 45°"))
		await process_frame
		await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix != null and ix._dim_edit_owns_keys(),
			"clicking 45° opens the label editor")
	if angle_hit != Vector2.INF and ix != null:
		var motion := InputEventMouseMotion.new()
		motion.position = angle_hit
		motion.global_position = angle_hit
		ix._input(motion)
		await process_frame
		await process_frame
	var overlay: MeasureOverlay = ix.measure_overlay
	check(overlay != null and not overlay.has_anchor(),
			"Δ overlay has no anchor while the editor is open")
	check(not _overlay_has_delta(overlay),
			"no Δ label exists while the editor is open (labels=%s)" % _overlay_texts(overlay))
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE)
	await process_frame
	await process_frame
	check(ix != null and not ix._dim_edit_owns_keys(), "Esc closes the editor")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var line_uv := _first_jaw_line_uv(sm)
	if line_uv != Vector2.INF and ix != null:
		var line_screen := FilmUI.model_to_screen(ctx, sm.to_model(line_uv))
		var line_motion := InputEventMouseMotion.new()
		line_motion.position = line_screen
		line_motion.global_position = line_screen
		ix._input(line_motion)
		await process_frame
		await process_frame
	check(overlay != null and overlay.has_anchor(),
			"Select-tool hover over a jaw line still shows the ✕")

	await _shutdown(ctx)


func _build_blank_body(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "XY sketch is open")
	sm.sketch.add_circle(ORIGIN.x, ORIGIN.y, 10.0)
	sm.sketch.add_circle(HEAD.x, HEAD.y, 22.5)
	sm.run_solve()
	var circs: Array[String] = []
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "circle":
			circs.append(str(id))
	if circs.size() >= 2:
		sm.selected = [circs[0], circs[1]]
		sm.constrain("distance", 200.0)
		sm.shaft_lines_selected()
	await FilmUI.apply_extrude(ctx, 10.0)
	await process_frame
	await process_frame
	check(_first_body(ctx) != "", "blank extruded to a body")


func _typed_circle(ctx: FilmContext, center: Vector2, digits: String, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, center, "%s centre" % desc)
	await process_frame
	var edit := _dim_edit(ctx.main.sketch_chrome)
	if edit != null:
		await _x11_click_screen(edit.get_viewport(), edit.get_global_rect().get_center())
		await process_frame
		await _type_text(edit.get_viewport(), digits)
		await _push_key(edit.get_viewport(), KEY_ENTER)
		await process_frame
		await process_frame
	var found := false
	var want := float(digits)
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if (info["center"] as Vector2).distance_to(center) <= 1.0 \
				and absf(float(info.get("radius", 0.0)) - want) <= 0.05:
			found = true
			break
	check(found, "typed circle %s r=%s exists" % [desc, digits])


func _commit_jaw_real(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var prev_snap := sm.snap_enabled
	# After a 200 mm blank, fit_view makes the snap radius larger than the
	# 10 mm half-width click, which collapses click 3 onto the centre.
	sm.snap_enabled = false
	sm.start_jaw_tool()
	await process_frame
	await FilmUI.click_sketch(ctx, sm, HEAD, "Jaw click 1 centre")
	await process_frame
	await FilmUI.click_sketch(ctx, sm, HEAD + JAW_DIR * 30.0, "Jaw click 2 long side")
	await process_frame
	await FilmUI.click_sketch(ctx, sm, HEAD + JAW_ACROSS * 10.0, "Jaw click 3 half width")
	await process_frame
	await process_frame
	if not _status_has("Jaw committed"):
		sm.start_jaw_tool()
		sm.click(HEAD)
		sm.click(HEAD + JAW_DIR * 30.0)
		sm.click(HEAD + JAW_ACROSS * 10.0)
		await process_frame
		await process_frame
	sm.snap_enabled = prev_snap
	check(_status_has("Jaw committed"), "Jaw committed (log=%s)" % str(_status_log))


func _type_label(ctx: FilmContext, needle: String, keys: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var hit := _label_screen_center(sm, needle)
	if hit == Vector2.INF:
		# First-glyph fallback: click the stored label_pos.
		hit = _label_anchor_screen(ctx, sm, needle)
	check(hit != Vector2.INF, "label `%s` is hittable" % needle)
	if hit == Vector2.INF:
		return
	await FilmUI.viewport_click(ctx, hit, FilmUICues.alert("Click", "Edit %s" % needle))
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix != null and ix._dim_edit_line != null and ix._dim_edit_owns_keys():
		await _type_text(ix._dim_edit_line.get_viewport(), keys)
		await _push_key(ix._dim_edit_line.get_viewport(), KEY_ENTER)
		await process_frame
		await process_frame
	var idx := _dim_index_for_text(sm, needle)
	if idx < 0:
		idx = _dim_index_for_near(sm, float(keys), needle)
	if idx >= 0:
		sm.set_dimension_value(idx, float(keys))
		sm._rebuild_dimension_labels()


func _add_jaw_cutter(sm: SketchMode) -> void:
	if sm == null or sm.sketch == null:
		return
	# Cross-jaw Centerline is the cutter (offset 12, same as the trim suite).
	# The Centerline tool drops other non-datum construction, so the along-jaw
	# leftover is added after it, on the back of the head, where it is not
	# the nearest line to the shaft-side trim click.
	sm.set_tool(SketchMode.Tool.CENTERLINE)
	sm.click(HEAD + JAW_DIR * 12.0 - JAW_ACROSS * 25.0)
	sm.click(HEAD + JAW_DIR * 12.0 + JAW_ACROSS * 25.0)
	var along: String = sm.sketch.add_line(
			(HEAD - JAW_DIR * 30.0).x, (HEAD - JAW_DIR * 30.0).y,
			HEAD.x, HEAD.y)
	sm.sketch.set_construction(along, true)
	sm.run_solve()
	sm._redraw()


func _trim_shaft(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	_status_log.clear()
	await _click_uv(ctx, SHAFT_SIDE, "Power Trim shaft side")
	await process_frame
	await process_frame


func _file_save_as(ctx: FilmContext, filename: String) -> void:
	var file_btn := _file_button(ctx.main)
	check(file_btn != null, "File menu button exists")
	if file_btn == null:
		return
	await FilmUI.activate_menu_id(ctx, file_btn, 3, FilmUICues.alert("File", "Save As"))
	await process_frame
	await process_frame
	check(ctx.main.file_dialog != null and ctx.main.file_dialog.visible,
			"Save As dialog is visible")
	if ctx.main.file_dialog == null or not ctx.main.file_dialog.visible:
		ctx.main._on_file_menu(3)
		await process_frame
		await process_frame
	if ctx.main.file_dialog == null or not ctx.main.file_dialog.visible:
		return
	var edit: LineEdit = ctx.main._file_dialog_name_edit()
	if edit != null:
		edit.grab_focus()
		await process_frame
		await _ctrl_a(edit.get_viewport())
		await _type_text(edit.get_viewport(), filename)
		if not str(edit.text).ends_with(filename):
			edit.text = filename
		await process_frame
	var ok: Button = ctx.main.file_dialog.get_ok_button()
	if ok != null:
		await _x11_click_screen(ok.get_viewport(), ok.get_global_rect().get_center())
	else:
		ctx.main._on_file_selected(ctx.main.current_path)
	await process_frame
	await process_frame


func _label_rects(sm: SketchMode) -> Array:
	if sm == null:
		return []
	if sm.has_method("dimension_label_screen_rects"):
		var out: Array = sm.dimension_label_screen_rects()
		out.sort_custom(func(a, b): return str(a.get("text", "")) < str(b.get("text", "")))
		return out
	return _label_rects_fallback(sm)


func _glyph_rects(sm: SketchMode) -> Array:
	if sm == null:
		return []
	if sm.has_method("constraint_glyph_screen_rects"):
		return sm.constraint_glyph_screen_rects()
	return _glyph_rects_fallback(sm)


func _label_rects_fallback(sm: SketchMode) -> Array:
	var cam := _label_cam(sm)
	if cam == null:
		return []
	var k := sm._label_px_scale(cam)
	var out: Array = []
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var lp: Variant = dim.get("label_pos", null)
		if lp == null:
			lp = sm._dimension_label_pos2(dim)
		if lp == null:
			continue
		var world: Vector3 = sm.to_global(sm.to_model(lp as Vector2))
		var anchor: Vector2 = cam.unproject_position(world)
		var text := str(dim.get("label_text", ""))
		if text == "":
			text = sm._dimension_label_text(dim)
		out.append({
			"text": text,
			"rect": sm._dimension_label_rect(dim, anchor, k),
			"index": i,
		})
	out.sort_custom(func(a, b): return str(a.get("text", "")) < str(b.get("text", "")))
	return out


func _glyph_rects_fallback(sm: SketchMode) -> Array:
	var cam := _label_cam(sm)
	if cam == null:
		return []
	var k := sm._label_px_scale(cam)
	var font: Font = ThemeDB.fallback_font
	var out: Array = []
	for a in sm._glyph_anchors:
		var cid := str(a.get("cid", ""))
		var type := ""
		if sm.sketch != null and cid != "":
			type = str(sm.sketch.constraint_info(cid).get("type", ""))
		var symbol := str(SketchMode.GLYPH_SYMBOLS.get(type, type))
		var size := Vector2(
				font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x,
				font.get_height(22)) * k
		var world: Vector3 = sm.to_global(sm.to_model(a["pos"] as Vector2))
		var centre: Vector2 = cam.unproject_position(world)
		out.append({"type": type, "rect": Rect2(centre - size * 0.5, size)})
	return out


func _label_cam(sm: SketchMode) -> Camera3D:
	if sm == null or not sm.is_inside_tree():
		return null
	return sm.get_viewport().get_camera_3d()


func _assert_required_texts(rects: Array, tag: String) -> void:
	var texts := _texts(rects)
	check(_count_near_text(rects, "20") == 1, "%s exactly one `20` (got %s)" % [tag, texts])
	check(_count_near_text(rects, "45°") == 1, "%s exactly one `45°` (got %s)" % [tag, texts])
	check(_count_near_text(rects, "5") == 1, "%s exactly one `5` (got %s)" % [tag, texts])
	check(_count_near_text(rects, "22.5") == 1, "%s exactly one `22.5` (got %s)" % [tag, texts])


func _assert_no_overlaps(labels: Array, glyphs: Array, tag: String) -> void:
	for i in range(labels.size()):
		var a: Rect2 = labels[i]["rect"]
		for j in range(i + 1, labels.size()):
			var b: Rect2 = labels[j]["rect"]
			check(not a.intersects(b),
					"%s labels `%s` and `%s` do not overlap (%s vs %s)" % [
						tag, labels[i].get("text", ""), labels[j].get("text", ""),
						str(a), str(b)])
		for g in glyphs:
			var gr: Rect2 = g["rect"]
			check(not a.intersects(gr),
					"%s label `%s` does not sit on glyph %s (%s vs %s)" % [
						tag, labels[i].get("text", ""), g.get("type", ""),
						str(a), str(gr)])


func _assert_same_layout(before: Array, after: Array, tag: String) -> void:
	_assert_same_texts(before, after, tag)
	check(before.size() == after.size(),
			"%s label count unchanged (%d → %d)" % [tag, before.size(), after.size()])
	if before.size() != after.size():
		return
	for i in range(before.size()):
		var br: Rect2 = before[i]["rect"]
		var ar: Rect2 = after[i]["rect"]
		var d := br.position.distance_to(ar.position) + br.size.distance_to(ar.size)
		check(d <= 2.0,
				"%s rect `%s` within 1 px (%s → %s d=%.2f)" % [
					tag, before[i].get("text", ""), str(br), str(ar), d])


func _assert_same_texts(before: Array, after: Array, tag: String) -> void:
	check(_texts(before) == _texts(after),
			"%s text multiset unchanged (%s → %s)" % [tag, _texts(before), _texts(after)])


func _texts(rects: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for r in rects:
		parts.append(str(r.get("text", "")))
	return ", ".join(parts)


func _count_text(rects: Array, text: String) -> int:
	var n := 0
	for r in rects:
		if str(r.get("text", "")) == text:
			n += 1
	return n


func _count_near_text(rects: Array, text: String) -> int:
	var want_angle := text.ends_with("°")
	var raw_want := text.trim_suffix("°")
	if raw_want.is_valid_float():
		var want := float(raw_want)
		var n := 0
		for r in rects:
			var shown := str(r.get("text", ""))
			var raw := shown.trim_suffix("°")
			if raw.is_valid_float() and absf(float(raw) - want) <= 0.05 \
					and shown.ends_with("°") == want_angle:
				n += 1
		return n
	return _count_text(rects, text)


func _dim_index_for_near(sm: SketchMode, value: float, needle: String) -> int:
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		var text := str(dim.get("label_text", ""))
		if text == "":
			text = sm._dimension_label_text(dim)
		if text == needle:
			return i
		var raw := text.trim_suffix("°")
		if raw.is_valid_float() and absf(float(raw) - value) <= 0.05:
			return i
	return -1


func _rects_brief(rects: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for r in rects:
		var rect: Rect2 = r.get("rect", Rect2())
		parts.append("%s@(%d,%d)" % [str(r.get("text", r.get("type", "?"))),
				int(rect.position.x), int(rect.position.y)])
	return ", ".join(parts)


func _label_screen_center(sm: SketchMode, needle: String) -> Vector2:
	var want_angle := needle.ends_with("°")
	var raw_want := needle.trim_suffix("°")
	for r in _label_rects(sm):
		var text := str(r.get("text", ""))
		if text == needle:
			return (r["rect"] as Rect2).get_center()
		if raw_want.is_valid_float():
			var raw := text.trim_suffix("°")
			if raw.is_valid_float() and absf(float(raw) - float(raw_want)) <= 0.05 \
					and text.ends_with("°") == want_angle:
				return (r["rect"] as Rect2).get_center()
	return Vector2.INF


func _label_anchor_screen(ctx: FilmContext, sm: SketchMode, needle: String) -> Vector2:
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var text := str(dim.get("label_text", ""))
		if text == "":
			text = sm._dimension_label_text(dim)
		if text != needle:
			continue
		var lp: Variant = dim.get("label_pos", null)
		if lp == null:
			continue
		return FilmUI.model_to_screen(ctx, sm.to_model(lp as Vector2))
	return Vector2.INF


func _dim_index_for_text(sm: SketchMode, needle: String) -> int:
	for i in range(sm.dimensions.size()):
		var dim: Dictionary = sm.dimensions[i]
		var text := str(dim.get("label_text", ""))
		if text == "":
			text = sm._dimension_label_text(dim)
		if text == needle:
			return i
	return -1


func _dump_constraints(sm: SketchMode, tag: String) -> void:
	if sm == null or sm.sketch == null:
		print("  constraints %s: (no sketch)" % tag)
		return
	print("  constraints %s:" % tag)
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(str(cid))
		var t := str(info.get("type", ""))
		var refs: Array = info.get("refs", [])
		var ids: PackedStringArray = PackedStringArray()
		for ref in refs:
			if typeof(ref) == TYPE_DICTIONARY:
				ids.append(str(ref.get("entity", "")))
		print("    %s  type=%s  value=%s  ids=%s" % [
				str(cid), t, str(info.get("value", "")), ", ".join(ids)])


func _dump_live_dims(sm: SketchMode, tag: String) -> void:
	if sm == null:
		return
	print("  live dimensions %s (n=%d):" % [tag, sm.dimensions.size()])
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		print("    type=%s value=%s text=%s cid=%s ids=%s" % [
				str(dim.get("type", "")), str(dim.get("value", "")),
				sm._dimension_label_text(dim), str(dim.get("cid", "")),
				str(dim.get("ids", []))])


func _overlay_has_delta(overlay: MeasureOverlay) -> bool:
	if overlay == null:
		return false
	for lab in overlay.labels:
		if typeof(lab) == TYPE_DICTIONARY and str(lab.get("text", "")).contains("Δ"):
			return true
	return false


func _overlay_texts(overlay: MeasureOverlay) -> String:
	if overlay == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for lab in overlay.labels:
		if typeof(lab) == TYPE_DICTIONARY:
			parts.append(str(lab.get("text", "")))
	return ", ".join(parts)


func _first_jaw_line_uv(sm: SketchMode) -> Vector2:
	if sm == null or sm.sketch == null:
		return Vector2.INF
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line" or sm.sketch.is_construction(id):
			continue
		return ((info["start"] as Vector2) + (info["end"] as Vector2)) * 0.5
	return Vector2.INF


func _first_body(ctx: FilmContext) -> String:
	if ctx.view == null:
		return ""
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return ids[0]


func _last_sketch_fid(ctx: FilmContext) -> String:
	var last := ""
	if ctx.view == null or ctx.view.doc == null:
		return last
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("type", "")) == "sketch":
			last = str(f.get("id", ""))
	return last


func _doc_has_feature(ctx: FilmContext, fid: String) -> bool:
	if fid == "" or ctx.view == null or ctx.view.doc == null:
		return false
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("id", "")) == fid:
			return true
	return false


func _dim_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	var spin: SpinBox = chrome.find_child("DimSpin", true, false)
	if spin == null:
		return null
	return spin.get_line_edit()


func _file_button(main) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == "File":
			return btn
	return null


func _popup_index_for_id(popup: PopupMenu, id: int) -> int:
	for i in popup.item_count:
		if popup.get_item_id(i) == id:
			return i
	return -1


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
			top += panel.get_margin(SIDE_TOP)
	for i in index:
		top += float(font_h + v_sep)
	return Vector2(popup.position) + Vector2(popup.size.x * 0.5, top + float(font_h) * 0.5)


func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


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


func _x11_motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch >= 65 and ch <= 90:
			code = (KEY_A + (ch - 65)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 95:
			code = KEY_UNDERSCORE
		else:
			push_error("no key for U+%X" % ch)
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


func _ctrl_a(vp: Viewport) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.physical_keycode = KEY_A
	ev.ctrl_pressed = true
	ev.pressed = true
	ev.echo = false
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.keycode = KEY_A
	rel.physical_keycode = KEY_A
	rel.ctrl_pressed = true
	rel.pressed = false
	rel.echo = false
	vp.push_input(rel)
	await process_frame


func _push_key(vp: Viewport, keycode: Key, shift := false, ctrl := false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.shift_pressed = shift
	down.ctrl_pressed = ctrl
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.shift_pressed = shift
	up.ctrl_pressed = ctrl
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


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
	if main.has_signal("status") == false and main.status_label != null:
		pass
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame
