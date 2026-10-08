# Rung 1 replan 16 WP2 — a plain click never opens a sketch, an unchanged
# Exit Sketch does not dirty the document, and the first fillet click selects
# the face unless the pointer is inside the 12 px first-pick band. The
# interior sample sits outside that band.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib \
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan16_picks.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const NEW_SENTENCE := "New — empty part, Top plane (XY). View ▸ Timeline to edit features"
const REFUSAL := "exceeds the 1.250 mm limit set by the 150.000 mm line edge"
const SAVE_PATH := "/tmp/sx-replan16-picks.sxp"

var failures := 0
var checks := 0
var _status_log: Array[String] = []
var _all_status: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan16 WP2 picks, clean exit, first fillet click")
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	var built := await _setup_shaft_slot(ctx)
	if built:
		await _phase_p1(ctx)
		await _phase_p2(ctx)
		await _phase_p4(ctx)
		await _phase_p3(ctx)
		await _phase_p5()
	else:
		check(false, "setup built the shaft and the slot")
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
		await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	quit(1 if failures > 0 else 0)


func _phase_p1(ctx: FilmContext) -> void:
	print("- P1 plain clicks do not open a sketch")
	await _leave_sketch(ctx)
	await _top_view(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_model(ctx, Vector3(93.5, 0.0, 7.5), false)
	_capture(ctx)
	_dump("P1 slot floor")
	check(not sm.active, "P1: slot-floor click leaves sketch inactive (active=%s)" % str(sm.active))
	check(not _status_has("Editing sketch"),
			"P1: slot-floor click never says Editing sketch (log=%s)" % str(_status_log))
	var floor_status := str(ctx.main.status_label.text)
	check(floor_status.begins_with("Selected "),
			"P1: slot-floor status begins with Selected  (got `%s`)" % floor_status)
	await _leave_sketch(ctx)
	_status_log.clear()
	await _click_model(ctx, Vector3(50.0, 16.0, 0.0), false)
	_capture(ctx)
	_dump("P1 empty ground")
	check(not sm.active, "P1: empty-ground click leaves sketch inactive (active=%s)" % str(sm.active))
	check(not _status_has("Editing sketch"),
			"P1: empty-ground click never says Editing sketch (log=%s)" % str(_status_log))
	await _leave_sketch(ctx)
	await _top_view(ctx)
	_status_log.clear()
	await _click_model(ctx, Vector3(200.0, 0.0, 10.0), false)
	_capture(ctx)
	check(not sm.active, "P1: head click selects instead of editing (active=%s log=%s)" % [
			str(sm.active), str(_status_log)])
	await _leave_sketch(ctx)
	if ctx.view.selected_body == "":
		await _click_model(ctx, Vector3(200.0, 0.0, 10.0), false)
		_capture(ctx)
		await _leave_sketch(ctx)
	ctx.main.ops_panel.arm_or_apply_fillet()
	await process_frame
	_status_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	_capture(ctx)
	check(_status_has("Edge pick cancelled") or str(ctx.main.status_label.text).contains("Edge pick cancelled"),
			"P1: Esc after an armed fillet says Edge pick cancelled (got `%s`)" % ctx.main.status_label.text)
	var chip: Button = ctx.main.interaction._strip_fillet
	check(chip != null and chip.is_visible_in_tree(), "P1: Fillet chip is visible")
	_status_log.clear()
	if chip != null:
		await _click_screen(ctx.main.get_viewport(), chip.get_global_rect().get_center(), false)
		await process_frame
	_capture(ctx)
	_dump("P1 fillet chip")
	var chip_status := str(ctx.main.status_label.text)
	check(not sm.active and not _status_has("Editing sketch"),
			"P1: Fillet chip never opens a sketch (active=%s log=%s)" % [str(sm.active), str(_status_log)])
	check(chip_status.contains("Fillet r=") or _status_has("Fillet r="),
			"P1: Fillet chip arms Fillet r= (got `%s`)" % chip_status)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await _leave_sketch(ctx)


func _phase_p2(ctx: FilmContext) -> void:
	print("- P2 Ctrl+click, rail Sketch, timeline pencil")
	await _leave_sketch(ctx)
	await _top_view(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	await _click_screen(ctx.main.get_viewport(), Vector2(40.0, 740.0), false)
	_capture(ctx)
	await _leave_sketch(ctx)
	_status_log.clear()
	await _click_model(ctx, Vector3(93.5, 5.3, 10.0), true)
	_capture(ctx)
	_dump("P2 ctrl pad")
	var merge := str(ctx.main.status_label.text)
	check(not sm.active, "P2: Ctrl+click leaves sketch inactive")
	check(merge.contains("1 sketch pad(s) selected — Merge sketches") or _status_has("1 sketch pad(s) selected — Merge sketches"),
			"P2: Ctrl+click status is the merge sentence (got `%s` log=%s)" % [merge, str(_status_log)])
	await _click_screen(ctx.main.get_viewport(), Vector2(40.0, 740.0), false)
	await _leave_sketch(ctx)
	var sketch_btn: Button = ctx.main.find_child("PaletteSketch", true, false) as Button
	check(sketch_btn != null and sketch_btn.is_visible_in_tree(), "P2: rail Sketch button is visible")
	_status_log.clear()
	if sketch_btn != null:
		await _x11_click(sketch_btn)
		await process_frame
	_capture(ctx)
	var prompt := str(ctx.main.status_label.text)
	check(prompt.contains("Select a face or existing sketch (Esc to cancel)") or _status_has("Select a face or existing sketch (Esc to cancel)"),
			"P2: rail Sketch asks for a face or pad (got `%s`)" % prompt)
	_status_log.clear()
	await _click_model(ctx, Vector3(93.5, 5.3, 10.0), false)
	_capture(ctx)
	_dump("P2 rail ink")
	check(sm.active and (_status_has("Editing sketch") or str(ctx.main.status_label.text).contains("Editing sketch")),
			"P2: click on pad ink while picking a host edits the sketch (active=%s log=%s)" % [
				str(sm.active), str(_status_log)])
	await _leave_sketch(ctx)
	await _show_timeline(ctx)
	var fid := _last_feature_id(ctx, "sketch")
	var row := _row_for_fid(ctx, fid)
	var pencil := _row_edit_btn(row)
	check(pencil != null and pencil.is_visible_in_tree(), "P2: timeline pencil is visible")
	_status_log.clear()
	if pencil != null:
		await _x11_click(pencil)
		await process_frame
		await process_frame
	_capture(ctx)
	check(sm.active and (_status_has("Editing sketch") or str(ctx.main.status_label.text).contains("Editing sketch")),
			"P2: timeline pencil edits the sketch (active=%s got `%s`)" % [
				str(sm.active), ctx.main.status_label.text])
	await _leave_sketch(ctx)


func _phase_p4(ctx: FilmContext) -> void:
	print("- P4 first fillet click selects the face unless the pointer is on an edge")
	await _leave_sketch(ctx)
	await _top_view(ctx)
	var body := _body(ctx)
	check(body != "", "P4: body exists")
	if body == "":
		return
	await _click_model(ctx, Vector3(200.0, 0.0, 10.0), false)
	_capture(ctx)
	await _leave_sketch(ctx)
	if ctx.view.selected_body == "":
		check(false, "P4: body is selected before arming Fillet (status `%s`)" % ctx.main.status_label.text)
		return
	var zoomed: Dictionary = await _frame_face_and_edge(ctx, body)
	var face_pt: Vector3 = zoomed["face"]
	var edge_pt: Vector3 = zoomed["edge"]
	print("  P4 face pt %s mm=%.2f px=%.1f" % [
			str(face_pt), float(zoomed["face_mm"]), float(zoomed["face_px"])])
	print("  P4 edge pt %s mm=%.2f px=%.1f" % [
			str(edge_pt), float(zoomed["edge_mm"]), float(zoomed["edge_px"])])
	check(float(zoomed["face_px"]) >= 14.0, "P4: interior sample is at least 14 px from every edge")
	check(float(zoomed["edge_px"]) <= 3.0, "P4: edge sample is at most 3 px from an edge")
	ctx.main.ops_panel.arm_or_apply_fillet()
	ctx.main.ops_panel.set_dressup_radius(1.0)
	await process_frame
	_status_log.clear()
	await _click_model(ctx, edge_pt, false)
	_capture(ctx)
	_dump("P4 near edge")
	var near := str(ctx.main.status_label.text)
	check(near.contains("Fillet: 1 edge(s)") or _status_has("Fillet: 1 edge(s)"),
			"P4: click within 3 px selects one edge (got `%s`)" % near)
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	await process_frame
	ctx.main.ops_panel.arm_or_apply_fillet()
	ctx.main.ops_panel.set_dressup_radius(1.0)
	await process_frame
	_status_log.clear()
	await _click_model(ctx, face_pt, false)
	_capture(ctx)
	_dump("P4 face interior")
	var face_status := str(ctx.main.status_label.text)
	var n := _fillet_edge_count(face_status)
	check(face_status.begins_with("Fillet: "),
			"P4: interior click status begins with Fillet:  (got `%s`)" % face_status)
	check(n >= 6, "P4: interior click selects at least 6 edges (got %d, `%s`)" % [n, face_status])
	check(not _mentions_zero_length_edge(face_status) and not _log_mentions_zero_length_edge(),
			"P4: interior status has no 0.0 mm line (got `%s`)" % face_status)
	_release_focus(ctx.main.get_viewport())
	ctx.main.interaction.grab_focus()
	await process_frame
	_status_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, false, false)
	await process_frame
	await process_frame
	_capture(ctx)
	var applied := str(ctx.main.status_label.text)
	check(_status_has("Fillet %d edges 1.00 applied" % n) or applied.contains("Fillet %d edges 1.00 applied" % n),
			"P4: Enter applies Fillet %d edges 1.00 (got `%s` log=%s)" % [n, applied, str(_status_log)])
	check(_closed_shell(ctx, body), "P4: closed-shell export after the fillet")


func _phase_p3(ctx: FilmContext) -> void:
	print("- P3 unchanged Exit Sketch stays clean; L7 does not ask to discard")
	await _leave_sketch(ctx)
	# P4 already applied a fillet on the slot edges. A later dimension edit
	# rebuilds those edges and the kernel rolls the sketch back, so drop that
	# fillet through the document undo stack before this phase saves.
	for _i in 3:
		var feats: Array = ctx.view.doc.graph_features()
		if feats.is_empty() or typeof(feats[feats.size() - 1]) != TYPE_DICTIONARY:
			break
		if str((feats[feats.size() - 1] as Dictionary).get("type", "")) != "fillet":
			break
		if not ctx.view.undo():
			break
		await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	ctx.main.current_path = SAVE_PATH
	ctx.main._save_current()
	await process_frame
	await process_frame
	check(FileAccess.file_exists(SAVE_PATH), "P3: save wrote the part")
	check(not ctx.main._document_is_dirty(), "P3: save leaves the document clean")
	var rev: int = ctx.view.doc.revision()
	await _show_timeline(ctx)
	var fid := _last_feature_id(ctx, "sketch")
	var pencil := _row_edit_btn(_row_for_fid(ctx, fid))
	check(pencil != null, "P3: pencil exists for the no-edit exit")
	_status_log.clear()
	if pencil != null:
		await _x11_click(pencil)
		await process_frame
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "P3: pencil reopens the sketch")
	var before_snap := ""
	if sm.sketch != null and sm.sketch.has_method("snapshot"):
		before_snap = sm.sketch.snapshot()
	await _exit_sketch_button(ctx)
	_capture(ctx)
	var saved := str(ctx.main.status_label.text)
	check(saved == "Sketch saved" or _status_has("Sketch saved"),
			"P3: unchanged Exit Sketch says Sketch saved (got `%s`)" % saved)
	check(ctx.view.doc.revision() == rev,
			"P3: unchanged exit keeps revision %d (got %d)" % [rev, ctx.view.doc.revision()])
	check(not ctx.main._document_is_dirty(), "P3: unchanged exit leaves the document clean")
	pencil = _row_edit_btn(_row_for_fid(ctx, fid))
	if pencil != null:
		await _x11_click(pencil)
		await process_frame
		await process_frame
	check(sm.active, "P3: pencil reopens the sketch for the edit")
	var edited := await _move_a_dimension(ctx)
	check(edited, "P3: a dimension value changed")
	await _exit_sketch_button(ctx)
	_capture(ctx)
	check(ctx.main._document_is_dirty(), "P3: a real dimension edit dirties the document")
	# The edit moved the 150 mm slot edge. set_dimension_value and Exit
	# Sketch each push a graph snapshot, so two undos restore that edge
	# before the refused fillet below.
	ctx.view.undo()
	await process_frame
	ctx.view.undo()
	await process_frame
	ctx.main._save_current()
	await process_frame
	await process_frame
	check(not ctx.main._document_is_dirty(), "P3: L7 save is clean before the refused fillet")
	await _top_view(ctx)
	await _click_model(ctx, Vector3(200.0, 0.0, 10.0), false)
	await _leave_sketch(ctx)
	ctx.main.ops_panel.arm_or_apply_fillet()
	ctx.main.ops_panel.set_dressup_radius(1.5)
	await process_frame
	_status_log.clear()
	await _click_model(ctx, Vector3(93.5, 0.0, 7.5), false)
	_capture(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, false, false)
	for _i in 4:
		await process_frame
	_capture(ctx)
	_dump("P3 slot floor R1.5")
	var refused := str(ctx.main.status_label.text)
	var err := str(ctx.view.doc.last_graph_error())
	check(refused.contains(REFUSAL) or _status_has(REFUSAL),
			"P3: R1.5 on the slot floor is refused (status=`%s` err=`%s`)" % [refused, err])
	_status_log.clear()
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, false, false)
	_capture(ctx)
	check(_status_has("Edge pick cancelled") or str(ctx.main.status_label.text).contains("Edge pick cancelled"),
			"P3: Esc says Edge pick cancelled (got `%s`)" % ctx.main.status_label.text)
	var opened: bool = await _click_menu_item(ctx, "File", 0, "File → New")
	check(opened, "P3: File → New item was clicked")
	await process_frame
	await process_frame
	_capture(ctx)
	check(ctx.main.confirm_dialog != null and not ctx.main.confirm_dialog.visible,
			"P3: File → New shows no Discard dialog (visible=%s)" % str(
				ctx.main.confirm_dialog.visible if ctx.main.confirm_dialog != null else "null"))
	var neu := str(ctx.main.status_label.text)
	check(neu == NEW_SENTENCE or _status_has(NEW_SENTENCE),
			"P3: File → New status is the empty-part sentence (got `%s`)" % neu)


func _phase_p5() -> void:
	print("- P5 no loft status")
	var hit := ""
	for s in _all_status:
		if s.to_lower().contains("loft"):
			hit = s
			break
	check(hit == "", "P5: no status contains loft (got `%s`)" % hit)


func _setup_shaft_slot(ctx: FilmContext) -> bool:
	print("- setup shaft and slot")
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active or sm.sketch == null:
		check(false, "setup: ground sketch is active")
		return false
	var sk: SxSketch = sm.sketch
	sk.add_circle(0.0, 0.0, 10.0)
	sk.add_circle(200.0, 0.0, 22.5)
	var tangent_x := 200.0 - sqrt(22.5 * 22.5 - 100.0)
	sk.add_line(0.0, 10.0, tangent_x, 10.0)
	sk.add_line(0.0, -10.0, tangent_x, -10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	if ctx.view.doc.body_ids().is_empty():
		check(false, "setup: blank extruded a body")
		return false
	var body := str(ctx.view.doc.body_ids()[0])
	var top := _top_face(ctx, body)
	check(top != "", "setup: blank has a top face")
	if top == "":
		return false
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	if sm == null or not sm.active:
		check(false, "setup: slot sketch is active")
		return false
	sm._add_slot(Vector2(18.5, 0.0), Vector2(168.5, 0.0), 5.0)
	sm.finish_extrude(2.5, "cut", "blind")
	await process_frame
	await process_frame
	if ctx.view.doc.body_ids().is_empty():
		check(false, "setup: slot cut kept a body")
		return false
	body = str(ctx.view.doc.body_ids()[0])
	ctx.view.refresh_sketch_pads("")
	await process_frame
	var mesh_ok := _closed_shell(ctx, body)
	check(mesh_ok, "setup: shaft and slot export as a closed shell")
	return mesh_ok


func _frame_face_and_edge(ctx: FilmContext, body: String) -> Dictionary:
	var face_pt := Vector3(40.0, 8.2, 10.0)
	var edge_pt := Vector3(40.0, 9.92, 10.0)
	var face_px := 0.0
	var edge_px := 99.0
	for _i in 24:
		face_px = _nearest_edge_px(ctx, body, face_pt)
		edge_px = _nearest_edge_px(ctx, body, edge_pt)
		if face_px >= 14.0 and edge_px <= 3.0:
			break
		if face_px < 14.0:
			await _wheel(ctx, face_pt, true)
		elif edge_px > 3.0:
			edge_pt.y = minf(edge_pt.y + 0.03, 9.99)
	return {
		"face": face_pt,
		"edge": edge_pt,
		"face_mm": _nearest_edge_mm(ctx, body, face_pt),
		"edge_mm": _nearest_edge_mm(ctx, body, edge_pt),
		"face_px": face_px,
		"edge_px": edge_px,
	}


func _move_a_dimension(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return false
	var before := ""
	if sm.sketch != null and sm.sketch.has_method("snapshot"):
		before = sm.sketch.snapshot()
	await _zoom(ctx, sm.to_model(Vector2(93.5, 0.0)), 220.0)
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var sel := FilmUI.find_sketch_tool_button(ctx.main, "Select")
	if sel != null:
		await _x11_click(sel)
		await process_frame
	var rects: Array = sm.dimension_label_screen_rects() if sm.has_method("dimension_label_screen_rects") else []
	var hit := Vector2.INF
	var label := ""
	for rec in rects:
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var text := str(rec.get("text", ""))
		if not text.contains("150"):
			continue
		hit = (rec["rect"] as Rect2).get_center()
		label = text
		break
	if hit == Vector2.INF and not rects.is_empty() and typeof(rects[0]) == TYPE_DICTIONARY:
		hit = (rects[0]["rect"] as Rect2).get_center()
		label = str(rects[0].get("text", ""))
	check(hit != Vector2.INF, "P3: a dimension label is on screen (n=%d)" % rects.size())
	if hit == Vector2.INF:
		return false
	print("  P3 dimension label `%s` at %s" % [label, str(hit)])
	var vp: Viewport = ctx.main.get_viewport()
	await _click_screen(vp, hit, false)
	await process_frame
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	if ix != null and ix.has_method("_dim_edit_owns_keys") and not ix._dim_edit_owns_keys():
		await _click_screen(vp, hit, false)
		await process_frame
	if ix != null and ix._dim_edit_line != null and not ix._dim_edit_line.has_focus():
		ix._dim_edit_line.grab_focus()
		await process_frame
	await _push_key(vp, KEY_A, true, false)
	await _type_text(vp, "140")
	await _push_key(vp, KEY_ENTER, false, false)
	await process_frame
	await process_frame
	var changed := false
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) == "distance" and absf(float(dim.get("value", 0.0)) - 150.0) > 0.05:
			changed = true
	if sm.sketch != null and before != "" and sm.sketch.has_method("snapshot"):
		check(sm.sketch.snapshot() != before, "P3: the edit changed the sketch snapshot")
		if sm.sketch.snapshot() != before:
			changed = true
	return changed


func _mentions_zero_length_edge(status: String) -> bool:
	# Lengths print as "150.0 mm line". A raw substring search matches the
	# tail of that token; a zero-length edge is its own "0.0 mm line".
	var re := RegEx.new()
	re.compile("(^|[^0-9.])0\\.0 mm line")
	return re.search(status) != null


func _log_mentions_zero_length_edge() -> bool:
	for s in _status_log:
		if _mentions_zero_length_edge(s):
			return true
	return false


func _fillet_edge_count(status: String) -> int:
	var re := RegEx.new()
	re.compile("Fillet: (\\d+) edge")
	var m := re.search(status)
	if m == null:
		return -1
	return int(m.get_string(1))


func _nearest_edge_mm(ctx: FilmContext, body: String, point: Vector3) -> float:
	var best := INF
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for eid in lines:
		var pts: PackedVector3Array = lines[eid]
		for i in range(pts.size() - 1):
			best = minf(best, _seg_dist3(point, pts[i], pts[i + 1]))
	return best


func _nearest_edge_px(ctx: FilmContext, body: String, point: Vector3) -> float:
	var cam: Camera3D = ctx.main.camera
	var screen := FilmUI.model_to_screen(ctx, point)
	var best := INF
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for eid in lines:
		var pts: PackedVector3Array = lines[eid]
		var prev := Vector2.INF
		var have := false
		for p in pts:
			var world: Vector3 = ctx.main.model_space.to_global(p) if ctx.main.model_space != null else p
			if cam.is_position_behind(world):
				have = false
				continue
			var s: Vector2 = cam.unproject_position(world)
			if have:
				best = minf(best, _seg_dist2(screen, prev, s))
			prev = s
			have = true
	return best


func _seg_dist3(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 1e-12 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _seg_dist2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 1e-12 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _top_face(ctx: FilmContext, body: String) -> String:
	var best := ""
	var best_z := -1.0e30
	for f in ctx.view.doc.get_face_ids(body):
		var mid: Variant = ctx.view.doc.face_midpoint(str(f))
		if not (mid is Vector3):
			continue
		var n: Vector3 = ctx.view.face_normal(body, str(f))
		if n.z < 0.9:
			continue
		if (mid as Vector3).z > best_z:
			best_z = (mid as Vector3).z
			best = str(f)
	return best


func _body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return str(ids[0])


func _closed_shell(ctx: FilmContext, body: String) -> bool:
	var path := "/tmp/sx-replan16-picks-shell.3mf"
	return bool(ctx.view.doc.export_3mf_for_body(body, path))


func _last_feature_id(ctx: FilmContext, kind: String) -> String:
	var last := ""
	for f in ctx.view.doc.graph_features():
		if typeof(f) == TYPE_DICTIONARY and str(f.get("type", "")) == kind:
			last = str(f.get("id", ""))
	return last


func _show_timeline(ctx: FilmContext) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame
	await process_frame


func _row_for_fid(ctx: FilmContext, fid: String) -> HBoxContainer:
	if fid == "" or ctx.main.timeline == null:
		return null
	var rows: Dictionary = ctx.main.timeline._rows
	if rows.has(fid):
		return rows[fid] as HBoxContainer
	return null


func _row_edit_btn(row: Control) -> Button:
	if row == null:
		return null
	var named := row.get_node_or_null("RowEdit") as Button
	if named != null:
		return named
	return null


func _leave_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return
	await _exit_sketch_button(ctx)


func _exit_sketch_button(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return
	if ctx.main.has_method("_update_left_rail"):
		ctx.main._update_left_rail()
		await process_frame
	var btn: Button = ctx.main.find_child("ExitSketch", true, false) as Button
	if btn != null and btn.is_visible_in_tree():
		await _x11_click(btn)
		await process_frame
		await process_frame
	if sm.active:
		var vp: Viewport = ctx.main.get_viewport()
		_release_focus(vp)
		await _push_key(vp, KEY_ESCAPE, false, false)
		await _push_key(vp, KEY_ESCAPE, false, false)
		await process_frame


func _top_view(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await _leave_sketch(ctx)
	_release_focus(ctx.main.get_viewport())
	await _zoom_model(ctx, Vector3(110.0, 0.0, 5.0), 320.0)


func _wheel(ctx: FilmContext, model_pt: Vector3, zoom_in: bool) -> void:
	var vp: Viewport = ctx.main.get_viewport()
	var pos := FilmUI.model_to_screen(ctx, model_pt)
	await _motion(vp, pos)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = pos
	wheel.global_position = pos
	vp.push_input(wheel)
	await process_frame


func _click_model(ctx: FilmContext, pt: Vector3, ctrl: bool) -> void:
	var screen := FilmUI.model_to_screen(ctx, pt)
	check(FilmUI.require_on_screen(ctx, screen, "model click"), "model click on screen at %s" % str(pt))
	await _click_screen(ctx.main.get_viewport(), screen, ctrl)
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
	_status_log.clear()
	_all_status.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	if main.ops_panel != null and main.ops_panel.has_signal("status"):
		main.ops_panel.status.connect(_on_status)
	if main.timeline != null and main.timeline.has_signal("status"):
		main.timeline.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	if text == "":
		return
	_all_status.append(text)
	if _status_log.is_empty() or _status_log[_status_log.size() - 1] != text:
		_status_log.append(text)


func _capture(ctx: FilmContext) -> void:
	if ctx.main == null or ctx.main.status_label == null:
		return
	_on_status(str(ctx.main.status_label.text))


func _status_has(needle: String) -> bool:
	if needle == "":
		return false
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _dump(tag: String) -> void:
	print("STATUS-LOG %s" % tag)
	if _status_log.is_empty():
		print("  | (empty)")
	for s in _status_log:
		print("  | %s" % s)


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _click_screen(vp: Viewport, pos: Vector2, ctrl: bool) -> void:
	await _motion(vp, pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.ctrl_pressed = ctrl
	down.meta_pressed = false
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	up.ctrl_pressed = ctrl
	vp.push_input(up)
	await process_frame


func _motion(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame


func _x11_click(ctrl: Control) -> void:
	if ctrl == null:
		check(false, "control to click exists")
		return
	await _click_screen(ctrl.get_viewport(), ctrl.get_global_rect().get_center(), false)


func _push_key(vp: Viewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	vp.push_input(up)
	await process_frame


func _type_text(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
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


func _zoom_model(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.sketch_orientation_locked = false
	cam.yaw = 0.0
	cam.pitch = deg_to_rad(89.0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


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


func _menu_button(main, title: String) -> MenuButton:
	var bar: Node = main.get_node_or_null("UI/TopChrome/FileMenu")
	if bar == null:
		return null
	for c in bar.find_children("*", "MenuButton", true, false):
		var btn := c as MenuButton
		if btn != null and str(btn.text) == title:
			return btn
	return null


func _popup_row_height(popup: PopupMenu, index: int, font_h: int, v_sep: int) -> float:
	if popup.is_item_separator(index):
		var sep_h := 0.0
		if popup.has_theme_stylebox("separator"):
			var sb: StyleBox = popup.get_theme_stylebox("separator")
			if sb != null:
				sep_h = sb.get_minimum_size().y
		return sep_h + float(v_sep)
	return float(font_h + v_sep)


func _item_local_y(popup: PopupMenu, index: int) -> float:
	var font: Font = popup.get_theme_font("font")
	var fs: int = popup.get_theme_font_size("font_size")
	var font_h: float = float(fs)
	if font != null:
		font_h = float(font.get_height(fs))
	var v_sep: int = popup.get_theme_constant("v_separation")
	var y := 0.0
	if popup.has_theme_stylebox("panel"):
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		if panel != null:
			y += panel.get_margin(SIDE_TOP)
	for i in range(index):
		y += _popup_row_height(popup, i, int(font_h), v_sep)
	y += _popup_row_height(popup, index, int(font_h), v_sep) * 0.5
	return y


func _click_popup_item(popup: PopupMenu, id: int, desc: String) -> bool:
	var idx := popup.get_item_index(id)
	if idx < 0:
		check(false, "popup has item id %d (%s)" % [id, desc])
		return false
	if popup.has_method("scroll_to_item"):
		popup.scroll_to_item(idx)
	popup.reset_size()
	await process_frame
	var screen := Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, _item_local_y(popup, idx))
	var got: Array = [-1]
	var cb := func(pressed_id: int) -> void:
		got[0] = pressed_id
	popup.id_pressed.connect(cb)
	await _click_screen(root.get_viewport(), screen, false)
	await process_frame
	await process_frame
	if popup.id_pressed.is_connected(cb):
		popup.id_pressed.disconnect(cb)
	return got[0] == id


func _click_menu_item(ctx: FilmContext, title: String, id: int, desc: String) -> bool:
	var btn := _menu_button(ctx.main, title)
	if btn == null or not btn.is_visible_in_tree():
		check(false, "%s menu button is visible for %s" % [title, desc])
		return false
	await _x11_click(btn)
	btn.show_popup()
	await process_frame
	await process_frame
	var popup: PopupMenu = btn.get_popup()
	var t0 := Time.get_ticks_msec()
	while popup != null and not popup.visible and Time.get_ticks_msec() - t0 < 450:
		await process_frame
	if popup == null or not popup.visible:
		check(false, "%s popup is visible after click (%s)" % [title, desc])
		return false
	return await _click_popup_item(popup, id, desc)
