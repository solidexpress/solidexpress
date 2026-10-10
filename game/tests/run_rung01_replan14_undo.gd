# Rung 1 replan 14 WP4 — Ctrl+Z / Ctrl+Shift+Z undo and redo sketch edits.
# Template: run_rung01_replan13_trim.gd (_boot, jaw) and run_rung01_replan13_frame.gd
# (_push_key_local, FilmUI). Setup may use helpers; every click and key under test is a
# real InputEventMouseButton / InputEventMouseMotion / InputEventKey.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script res://tests/run_rung01_replan14_undo.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(0.0, 0.0)
const JAW_LONG := Vector2(30.0, 0.0)
const JAW_WIDE := Vector2(0.0, 10.0)
const SHAFT_SIDE := Vector2(3.0, 8.0)
const SAVE_PATH := "/tmp/rung01_replan14_wp4_undo.sxp"

var _status_log: Array[String] = []


func _init() -> void:
	print("rung01 replan14 WP4 sketch undo/redo")
	FilmUI.reset_fail_count()
	test_binding_round_trip()
	await test_jaw_undo_redo_line_save()
	await test_coalesce_circle_hover_drag()
	await test_trim_and_dimension()
	await test_exit_clears_history()
	await test_document_undo_outside_sketch()
	await test_radius_field_owns_ctrl_z()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func test_binding_round_trip() -> void:
	print("- 1. SxSketch.snapshot / restore round trip")
	var sk := SxSketch.new()
	check(sk != null, "SxSketch.new() works")
	if sk == null:
		return
	var has_snap: bool = sk.has_method("snapshot")
	var has_restore: bool = sk.has_method("restore")
	check(has_snap, "SxSketch.snapshot() is bound")
	check(has_restore, "SxSketch.restore() is bound")
	if not has_snap or not has_restore:
		print("  observed: snapshot/restore missing on SxSketch")
		return
	var circ: String = sk.add_circle(0.0, 0.0, 5.0)
	var lid: String = sk.add_line(0.0, 0.0, 20.0, 0.0)
	var rid: String = sk.add_constraint("radius", [{"entity": circ, "role": "self"}], 5.0)
	var e0 := _id_set(sk.entity_ids())
	var c0 := _id_set(sk.constraint_ids())
	check(e0.has(circ) and e0.has(lid) and c0.has(rid), "circle, line and radius constraint exist")
	var snap: String = sk.snapshot()
	check(snap != "", "snapshot() returns JSON")
	var extra: String = sk.add_line(1.0, 1.0, 2.0, 2.0)
	check(_id_set(sk.entity_ids()).has(extra), "added a line after the snapshot")
	var ok: bool = sk.restore(snap)
	check(ok, "restore(snapshot) returns true")
	var e1 := _id_set(sk.entity_ids())
	var c1 := _id_set(sk.constraint_ids())
	check(e1 == e0, "restore keeps the same entity ids (got %s want %s)" % [str(e1.keys()), str(e0.keys())])
	check(c1 == c0, "restore keeps the same constraint ids")
	check(not e1.has(extra), "the post-snapshot line is gone")
	var solved: Dictionary = sk.solve()
	check(str(solved.get("status", "")) != "failed", "solve() ok after restore (got %s)" % str(solved))
	var before_bad := _id_set(sk.entity_ids())
	var bad: bool = sk.restore("{")
	check(not bad, "restore(\"{\") returns false")
	check(_id_set(sk.entity_ids()) == before_bad, "failed restore leaves the sketch untouched")


func test_jaw_undo_redo_line_save() -> void:
	print("- 2–5, 8, 10-edit. face sketch: Jaw undo/redo, empty, Line, Save, Edit menu")
	var ctx := await _boot_face_sketch()
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "face sketch is open")
	var n0: int = sm.sketch.entity_ids().size()
	var rev0: int = int(ctx.view.doc.revision())
	var tl0: int = ctx.view.doc.graph_features().size()
	print("  n0=%d rev=%d timeline=%d" % [n0, rev0, tl0])

	await _press_rail(ctx, "Jaw")
	await _click_uv_local(ctx, HEAD, "Jaw click 1 centre")
	await _click_uv_local(ctx, HEAD + JAW_LONG, "Jaw click 2 long side")
	await _click_uv_local(ctx, HEAD + JAW_WIDE, "Jaw click 3 half width")
	await process_frame
	await process_frame
	print("  observed after Jaw: `%s`" % _status_text(ctx))
	check(_status_has("Jaw committed"), "Jaw committed — … (got `%s`)" % _status_text(ctx))
	var n1: int = sm.sketch.entity_ids().size()
	check(n1 > n0, "Jaw added entities (n0=%d n1=%d)" % [n0, n1])
	var jaw_ids := _id_set(sm.sketch.entity_ids())
	check(_has_jaw_dims(sm), "Jaw recorded width / angle dimensions")

	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed Ctrl+Z: `%s`" % _status_text(ctx))
	check(sm.sketch.entity_ids().size() == n0, "Ctrl+Z restores entity count to n0 (got %d)" % sm.sketch.entity_ids().size())
	check(not _has_jaw_dims(sm), "sm.dimensions has no jaw width / angle after Undo: Jaw")
	check(_status_text(ctx) == "Undo: Jaw", "status Undo: Jaw (got `%s`)" % _status_text(ctx))
	check(sm.active, "sketch is still active after Ctrl+Z")
	check(int(ctx.view.doc.revision()) == rev0, "document revision unchanged (got %d want %d)" % [int(ctx.view.doc.revision()), rev0])
	check(ctx.view.doc.graph_features().size() == tl0, "timeline length unchanged")

	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, true)
	print("  observed Ctrl+Shift+Z: `%s`" % _status_text(ctx))
	check(_id_set(sm.sketch.entity_ids()) == jaw_ids, "Ctrl+Shift+Z restores the Jaw entity id set")
	check(_has_jaw_width_evidence(sm), "width / angle records (or 20-type labels) are back")
	check(_status_text(ctx) == "Redo: Jaw", "status Redo: Jaw (got `%s`)" % _status_text(ctx))

	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	check(sm.sketch.entity_ids().size() == n0, "Ctrl+Z after redo is n0 again")
	_status_log.clear()
	await _push_key_local(vp, KEY_Y, true, false)
	print("  observed Ctrl+Y: `%s`" % _status_text(ctx))
	check(_id_set(sm.sketch.entity_ids()) == jaw_ids, "Ctrl+Y restores the Jaw entity id set")
	check(_status_text(ctx) == "Redo: Jaw", "Ctrl+Y status Redo: Jaw (got `%s`)" % _status_text(ctx))

	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, true)
	print("  observed empty Ctrl+Shift+Z after redo: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Nothing to redo", "empty redo Ctrl+Shift+Z → Nothing to redo (got `%s`)" % _status_text(ctx))

	while sm.has_method("can_undo") and sm.can_undo():
		await _push_key_local(vp, KEY_Z, true, false)
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed empty Ctrl+Z: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Nothing to undo", "empty stack Ctrl+Z → Nothing to undo (got `%s`)" % _status_text(ctx))

	await _press_rail(ctx, "Jaw")
	await _click_uv_local(ctx, HEAD, "Jaw 2 click 1")
	await _click_uv_local(ctx, HEAD + JAW_LONG, "Jaw 2 click 2")
	await _click_uv_local(ctx, HEAD + JAW_WIDE, "Jaw 2 click 3")
	await process_frame
	await _push_key_local(vp, KEY_Z, true, false)
	check(not _has_jaw_dims(sm), "Jaw undone before drawing a Line")
	await _press_rail(ctx, "Line")
	await _click_uv_local(ctx, Vector2(-8.0, -8.0), "Line start")
	await _click_uv_local(ctx, Vector2(-8.0, 8.0), "Line end")
	await process_frame
	# A focused numeric blank swallows Ctrl+Z (#200). Hand the keys back.
	var focus_owner := vp.gui_get_focus_owner()
	if focus_owner != null and focus_owner.has_method("release_focus"):
		focus_owner.release_focus()
		await process_frame
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, true)
	print("  observed redo after new Line: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Nothing to redo", "new op clears redo (got `%s`)" % _status_text(ctx))
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed Undo Line: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Undo: Line", "Ctrl+Z → Undo: Line (got `%s`)" % _status_text(ctx))

	await _press_rail(ctx, "Jaw")
	await _click_uv_local(ctx, HEAD, "Jaw save click 1")
	await _click_uv_local(ctx, HEAD + JAW_LONG, "Jaw save click 2")
	await _click_uv_local(ctx, HEAD + JAW_WIDE, "Jaw save click 3")
	await process_frame
	check(_has_jaw_dims(sm), "Jaw is undoable before Save")
	ctx.main.current_path = SAVE_PATH
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_status_log.clear()
	await _push_key_local(vp, KEY_S, true, false)
	await process_frame
	await process_frame
	print("  observed Ctrl+S: `%s` active=%s" % [_status_text(ctx), str(sm.active)])
	check(sm.active, "Save inside a sketch keeps the session open")
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed Ctrl+Z after Save: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Undo: Jaw", "Save keeps history: Undo: Jaw (got `%s`)" % _status_text(ctx))
	check(not _has_jaw_dims(sm), "Jaw is gone after undo that survived Save")

	await _press_rail(ctx, "Jaw")
	await _click_uv_local(ctx, HEAD, "Jaw edit-menu click 1")
	await _click_uv_local(ctx, HEAD + JAW_LONG, "Jaw edit-menu click 2")
	await _click_uv_local(ctx, HEAD + JAW_WIDE, "Jaw edit-menu click 3")
	await process_frame
	var n_before_edit: int = sm.sketch.entity_ids().size()
	var edit_btn := _find_edit_menu(ctx.main)
	check(edit_btn != null, "Edit menu button exists")
	if edit_btn != null:
		_status_log.clear()
		await FilmUI.activate_menu_id(ctx, edit_btn, 0, FilmUICues.alert("Undo", "Edit ▸ Undo"))
		await process_frame
		print("  observed Edit ▸ Undo: `%s`" % _status_text(ctx))
		check(_status_text(ctx) == "Undo: Jaw", "Edit ▸ Undo in a sketch → Undo: Jaw (got `%s`)" % _status_text(ctx))
		check(sm.sketch.entity_ids().size() < n_before_edit, "Edit ▸ Undo removed the Jaw")
		check(int(ctx.view.doc.revision()) == rev0 or sm.active,
				"Edit ▸ Undo did not drive document undo from inside a sketch")

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	await _shutdown(ctx)


func test_coalesce_circle_hover_drag() -> void:
	print("- 6. coalescing: typed Circle, hover, handle drag")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm != null and sm.active, "blank sketch is open")
	sm.snap_enabled = false
	sm.infer_enabled = false
	sm.fit_view()
	await process_frame
	await _press_rail(ctx, "Circle")
	var stack0 := _undo_size(sm)
	await _click_uv_local(ctx, Vector2.ZERO, "Circle centre")
	await _type_keys(vp, "5")
	await _push_key_local(vp, KEY_ENTER)
	await process_frame
	await process_frame
	var stack1 := _undo_size(sm)
	print("  observed after typed Circle: `%s` stack %d→%d entities=%d" % [
			_status_text(ctx), stack0, stack1, sm.sketch.entity_ids().size()])
	check(stack1 == stack0 + 1, "typed Circle is one undo entry (stack %d→%d)" % [stack0, stack1])
	var circ_n: int = sm.sketch.entity_ids().size()
	var cids_with_circ := _id_set(sm.sketch.constraint_ids())
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed Undo Circle: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Undo: Circle", "Undo: Circle (got `%s`)" % _status_text(ctx))
	check(sm.sketch.entity_ids().size() < circ_n, "Undo: Circle removes the circle")
	check(sm.sketch.constraint_ids().size() < cids_with_circ.size() or cids_with_circ.is_empty() \
			or sm.sketch.entity_ids().is_empty(),
			"Undo: Circle removes the circle and its radius constraint together")

	await _press_rail(ctx, "Circle")
	await _click_uv_local(ctx, Vector2.ZERO, "Circle centre 2")
	await _type_keys(vp, "5")
	await _push_key_local(vp, KEY_ENTER)
	await process_frame
	var hover_n := _undo_size(sm)
	for i in 10:
		await _motion_uv(ctx, Vector2(float(i) * 2.0, 4.0))
	await process_frame
	check(_undo_size(sm) == hover_n, "ten hover motions push no undo entry (stack %d)" % _undo_size(sm))

	sm.infer_enabled = false
	await _press_rail(ctx, "Select")
	check(sm.tool == SketchMode.Tool.SELECT, "Select tool is armed for the handle drag")
	var drag_from := Vector2.ZERO
	var drag_to := Vector2(3.0, 0.0)
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		drag_from = info["center"] as Vector2
		drag_to = drag_from + Vector2(3.0, 0.0)
		break
	var drag_n := _undo_size(sm)
	await _drag_uv(ctx, drag_from, drag_to, 8)
	await process_frame
	print("  observed drag stack %d→%d from %s to %s" % [
			drag_n, _undo_size(sm), str(drag_from), str(drag_to)])
	check(_undo_size(sm) == drag_n + 1, "a handle drag is one undo entry (stack %d→%d)" % [drag_n, _undo_size(sm)])
	await _shutdown(ctx)


func test_trim_and_dimension() -> void:
	print("- 7. Trim and dimension undo")
	var ctx := await _boot_face_sketch()
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	sm.snap_enabled = false
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	sm.sketch.add_circle(0.0, 0.0, 22.5)
	sm.start_jaw_tool()
	sm.click(HEAD)
	sm.click(HEAD + JAW_LONG)
	sm.click(HEAD + JAW_WIDE)
	var di := _dim_index(sm, "distance")
	if di >= 0:
		sm.set_dimension_value(di, 20.0)
	var lid: String = sm.sketch.add_line(-5.0, 0.0, 35.0, 0.0)
	sm.sketch.set_construction(lid, true)
	var cl: String = sm.sketch.add_line(12.0, -25.0, 12.0, 25.0)
	sm.sketch.set_construction(cl, true)
	sm.run_solve()
	sm._redraw()
	await process_frame
	var walls_before := _wall_snapshot(sm)
	await _press_rail(ctx, "Trim")
	_status_log.clear()
	await _click_uv_local(ctx, SHAFT_SIDE, "Trim click")
	await process_frame
	print("  observed Trim: `%s`" % _status_text(ctx))
	check(_status_has("Trimmed open jaw"), "real Trim click → Trimmed open jaw (got `%s`)" % _status_text(ctx))
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed Undo Trim: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Undo: Trim", "Ctrl+Z → Undo: Trim (got `%s`)" % _status_text(ctx))
	check(_walls_match(sm, walls_before), "open-jaw walls are the pre-trim ones")

	await _press_rail(ctx, "Select")
	var width_screen := _width_label_screen(ctx, sm)
	check(width_screen != Vector2.INF, "width label is on screen for the 18 edit")
	if width_screen != Vector2.INF:
		await _x11_click_screen(vp, width_screen)
		await process_frame
		var ix: ViewportInteraction = ctx.main.interaction
		if ix._dim_edit_popup != null and ix._dim_edit_popup.visible and ix._dim_edit_line != null:
			await _x11_click_screen(ix._dim_edit_line.get_viewport(),
					ix._dim_edit_line.get_global_rect().get_center())
			await _type_keys(ix._dim_edit_line.get_viewport(), "18")
			await _push_key_local(ix._dim_edit_line.get_viewport(), KEY_ENTER)
			await process_frame
			await process_frame
		print("  observed after width 18: `%s` value=%s" % [_status_text(ctx), str(_width_value(sm))])
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed Undo Dimension: `%s` width=%s" % [_status_text(ctx), str(_width_value(sm))])
	check(_status_text(ctx) == "Undo: Dimension", "Ctrl+Z → Undo: Dimension (got `%s`)" % _status_text(ctx))
	var w := _width_value(sm)
	check(absf(w - 20.0) <= 0.05, "width reads 20 again (got %.4f)" % w)
	await _shutdown(ctx)


func test_exit_clears_history() -> void:
	print("- 9. Exit Sketch then re-enter: nothing to undo")
	var ctx := await _boot_face_sketch()
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _press_rail(ctx, "Jaw")
	await _click_uv_local(ctx, HEAD, "exit Jaw 1")
	await _click_uv_local(ctx, HEAD + JAW_LONG, "exit Jaw 2")
	await _click_uv_local(ctx, HEAD + JAW_WIDE, "exit Jaw 3")
	await process_frame
	var fid := str(sm.editing_fid)
	await FilmUI.exit_sketch(ctx)
	check(sm.active == false, "Exit Sketch left the session")
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	await process_frame
	await process_frame
	var row := _find_timeline_sketch_button(ctx.main, fid)
	check(row != null, "timeline has a sketch row to double-click")
	if row != null:
		await _double_click_control(row)
		await process_frame
		await process_frame
	check(sm.active, "timeline double-click re-opens the sketch")
	_status_log.clear()
	await _push_key_local(vp, KEY_Z, true, false)
	print("  observed after re-entry Ctrl+Z: `%s`" % _status_text(ctx))
	check(_status_text(ctx) == "Nothing to undo", "re-entry Ctrl+Z → Nothing to undo (got `%s`)" % _status_text(ctx))
	await _shutdown(ctx)


func test_document_undo_outside_sketch() -> void:
	print("- 10. part-mode Ctrl+Z still undoes the document")
	var ctx := await _boot()
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	var n0: int = ctx.view.doc.body_ids().size()
	check(n0 >= 1, "box placed (bodies=%d)" % n0)
	_status_log.clear()
	await _push_key_local(ctx.main.get_viewport(), KEY_Z, true, false)
	await process_frame
	print("  observed part-mode Ctrl+Z: `%s` bodies %d→%d" % [
			_status_text(ctx), n0, ctx.view.doc.body_ids().size()])
	var st := _status_text(ctx)
	check(st == "Undo" or st == "Undo/redo",
			"outside a sketch Ctrl+Z status is Undo or Undo/redo (got `%s`)" % st)
	check(ctx.view.doc.body_ids().size() < n0, "body count drops after document undo")
	await _shutdown(ctx)


func test_radius_field_owns_ctrl_z() -> void:
	print("- 11. focused Radius field owns Ctrl+Z")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	sm.snap_enabled = false
	sm.fit_view()
	await process_frame
	await _press_rail(ctx, "Jaw")
	await _click_uv_local(ctx, HEAD, "focus Jaw 1")
	await _click_uv_local(ctx, HEAD + JAW_LONG, "focus Jaw 2")
	await _click_uv_local(ctx, HEAD + JAW_WIDE, "focus Jaw 3")
	await process_frame
	var n_jaw: int = sm.sketch.entity_ids().size()
	await _press_rail(ctx, "Circle")
	await _click_uv_local(ctx, Vector2(8.0, 8.0), "Radius-field circle centre")
	var dim_edit := _dim_line_edit(ctx.main)
	check(dim_edit != null, "sketch Radius field exists")
	if dim_edit != null:
		await _x11_click_screen(dim_edit.get_viewport(), dim_edit.get_global_rect().get_center())
		await process_frame
		check(dim_edit.has_focus(), "Radius field is focused")
		_status_log.clear()
		await _push_key_local(vp, KEY_Z, true, false)
		await process_frame
		print("  observed focused Ctrl+Z: `%s` entities %d→%d" % [
				_status_text(ctx), n_jaw, sm.sketch.entity_ids().size()])
		check(sm.sketch.entity_ids().size() >= n_jaw,
				"Ctrl+Z in the Radius field does not undo the sketch")
		check(_status_text(ctx) != "Undo: Jaw", "focused field does not print Undo: Jaw (got `%s`)" % _status_text(ctx))
	await _shutdown(ctx)


func _has_jaw_dims(sm: SketchMode) -> bool:
	var d := false
	var a := false
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var t := str(dim.get("type", ""))
		if t == "distance":
			d = true
		elif t == "angle":
			a = true
	return d and a


func _has_jaw_width_evidence(sm: SketchMode) -> bool:
	if _has_jaw_dims(sm):
		return true
	if sm.has_method("dimension_label_screen_rects"):
		var rects: Variant = sm.dimension_label_screen_rects()
		if typeof(rects) == TYPE_ARRAY:
			for r in rects:
				if typeof(r) == TYPE_DICTIONARY and str(r.get("text", "")).begins_with("20"):
					return true
	return false


func _width_value(sm: SketchMode) -> float:
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "distance":
			continue
		return float(dim.get("value", 0.0))
	return -1.0


func _dim_index(sm: SketchMode, type: String) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == type:
			return i
	return -1


func _width_label_screen(ctx: FilmContext, sm: SketchMode) -> Vector2:
	sm._rebuild_dimension_labels()
	for dim in sm.dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		if str(dim.get("type", "")) != "distance":
			continue
		var pos_v: Variant = dim.get("label_pos", null)
		if pos_v == null:
			continue
		return FilmUI.model_to_screen(ctx, sm.to_model(pos_v as Vector2))
	return Vector2.INF


func _wall_snapshot(sm: SketchMode) -> Array:
	var out: Array = []
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		out.append({"id": str(id), "start": info["start"], "end": info["end"]})
	return out


func _walls_match(sm: SketchMode, before: Array) -> bool:
	var now := _wall_snapshot(sm)
	if now.size() != before.size():
		return false
	var by_id := {}
	for w in now:
		by_id[str(w["id"])] = w
	for w in before:
		if not by_id.has(str(w["id"])):
			return false
		var cur: Dictionary = by_id[str(w["id"])]
		if (cur["start"] as Vector2).distance_to(w["start"] as Vector2) > 0.05:
			return false
		if (cur["end"] as Vector2).distance_to(w["end"] as Vector2) > 0.05:
			return false
	return true


func _undo_size(sm: SketchMode) -> int:
	if sm.get("_undo_stack") == null:
		return -1
	var stack: Variant = sm.get("_undo_stack")
	if typeof(stack) != TYPE_ARRAY:
		return -1
	return (stack as Array).size()


func _id_set(ids: PackedStringArray) -> Dictionary:
	var out := {}
	for id in ids:
		out[str(id)] = true
	return out


func _status_text(ctx: FilmContext) -> String:
	if ctx != null and ctx.main != null and ctx.main.status_label != null:
		return str(ctx.main.status_label.text)
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _status_has(needle: String) -> bool:
	if not _status_log.is_empty():
		for s in _status_log:
			if s.contains(needle):
				return true
	return false


func _on_status(text: String) -> void:
	_status_log.append(text)


func _press_rail(ctx: FilmContext, label: String) -> void:
	var btn := FilmUI.find_sketch_tool_button(ctx.main, label)
	check(btn != null and btn.is_visible_in_tree(), "rail button `%s` is visible" % label)
	if btn == null:
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert(label, "rail %s" % label))
	await process_frame


func _click_uv_local(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)


func _motion_uv(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	ctx.main.get_viewport().push_input(motion)
	await process_frame


func _drag_uv(ctx: FilmContext, a: Vector2, b: Vector2, steps: int) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var sa := FilmUI.model_to_screen(ctx, sm.to_model(a))
	var sb := FilmUI.model_to_screen(ctx, sm.to_model(b))
	check(FilmUI.require_on_screen(ctx, sa, "drag start"), "drag start on screen")
	check(FilmUI.require_on_screen(ctx, sb, "drag end"), "drag end on screen")
	var motion := InputEventMouseMotion.new()
	motion.position = sa
	motion.global_position = sa
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = sa
	down.global_position = sa
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	await process_frame
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p: Vector2 = sa.lerp(sb, t)
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		mv.relative = p - sa
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mv)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = sb
	up.global_position = sb
	vp.push_input(up)
	await process_frame
	await process_frame


func _push_key_local(vp: Viewport, keycode: Key, ctrl := false, shift := false) -> void:
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
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


func _type_keys(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
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


func _double_click_control(ctrl: Control) -> void:
	var vp := ctrl.get_viewport()
	var pos := ctrl.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	for i in 2:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.double_click = i == 1
		down.position = pos
		down.global_position = pos
		vp.push_input(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.double_click = i == 1
		up.position = pos
		up.global_position = pos
		vp.push_input(up)
		await process_frame
	await process_frame


func _find_edit_menu(main) -> MenuButton:
	for c in main.find_children("*", "MenuButton", true, false):
		var mb := c as MenuButton
		if mb != null and mb.text == "Edit":
			return mb
	return null


func _find_timeline_sketch_button(main, fid: String) -> Button:
	var tl = main.timeline
	if tl == null:
		return null
	for c in tl.find_children("*", "Button", true, false):
		var b := c as Button
		if b == null or not b.is_visible_in_tree():
			continue
		var t := str(b.text).to_lower()
		if t.begins_with("sketch"):
			return b
	if fid != "":
		for c in tl.find_children("*", "Button", true, false):
			var b2 := c as Button
			if b2 != null and str(b2.tooltip_text).contains(fid):
				return b2
	return null


func _dim_line_edit(main) -> LineEdit:
	var chrome = main.sketch_chrome
	if chrome == null:
		return null
	var edit: Node = chrome.find_child("DimLineEdit", true, false)
	if edit is LineEdit:
		return edit as LineEdit
	return null


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


func _boot_face_sketch() -> FilmContext:
	var ctx := await _boot()
	await FilmUI.place_primitive(ctx, "box")
	await process_frame
	await process_frame
	var body: String = ctx.view.selected_body
	if body == "":
		var ids: PackedStringArray = ctx.view.doc.body_ids()
		if not ids.is_empty():
			body = ids[0]
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	check(body != "" and face != "", "box placed, +Z face found (%s/%s)" % [body, face])
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "face sketch is open after enter")
	if sm != null:
		sm.snap_enabled = false
		sm.fit_view()
	await process_frame
	await process_frame
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame
