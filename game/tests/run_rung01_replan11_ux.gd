# Rung 1 replan 11 WP10 — strip, timeline, save, and dimension UX.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_ux.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const RECT_HINT := "Rect — click 1 first corner, click 2 the opposite corner"

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
	print("rung01 replan11 WP10 strip timeline save dim UX")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var ctx := await _boot()
	var main = ctx.main
	var sm: SketchMode = main.sketch_mode
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	var pp = main.timeline.property_panel

	sm.set_tool(SketchMode.Tool.RECT)
	check(_last_status() == RECT_HINT,
			"set_tool(RECT) status is exactly the Rect sentence (got `%s`)" % _last_status())

	sm.start_jaw_tool()
	check(_last_status() == SketchMode.JAW_HINT,
			"start_jaw_tool status is JAW_HINT (got `%s`)" % _last_status())

	await FilmUI.enter_sketch(ctx)
	var c0: String = sm.sketch.add_circle(0.0, 0.0, 5.0)
	var c1: String = sm.sketch.add_circle(30.0, 0.4, 8.0)
	sm._smart_dim_between(
			{"entity": c0, "role": "center"},
			{"entity": c1, "role": "center"})
	sm.run_solve()
	var y0: float = float(sm.sketch.entity_info(c0)["center"].y)
	var y1: float = float(sm.sketch.entity_info(c1)["center"].y)
	check(absf(y1 - y0) <= 0.05 and _horiz_between(sm, c0, c1) >= 1,
			"near-X centres get a two-centre horizontal (dy=%.4f horiz=%d)" % [y1 - y0, _horiz_between(sm, c0, c1)])

	var horiz_before := _horiz_total(sm)
	var c2: String = sm.sketch.add_circle(30.0, 20.0, 4.0)
	sm._smart_dim_between(
			{"entity": c0, "role": "center"},
			{"entity": c2, "role": "center"})
	sm.run_solve()
	check(_horiz_total(sm) == horiz_before,
			"20° centre pair does not add a horizontal constraint (before=%d after=%d)" % [
				horiz_before, _horiz_total(sm)])

	var lid: String = sm.sketch.add_line(0.0, 40.0, 12.0, 40.0)
	var sel: Array[String] = []
	sel.append(lid)
	sm._set_selected(sel)
	_status_log.clear()
	await _sketch_key(ix, KEY_DELETE)
	var deleted_status := _last_status()
	_status_log.clear()
	await _sketch_key(ix, KEY_DELETE)
	check(deleted_status == "Deleted 1" and _last_status() == "Nothing to delete",
			"Delete of one line is Deleted 1, then Nothing to delete (got `%s` then `%s`)" % [
				deleted_status, _last_status()])

	if sm.active:
		sm.cancel()
		await process_frame
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 10, 10))
	await process_frame
	view.select_entity(body, "")
	var ops = main.ops_panel
	ops.set_dressup_radius(1.0)
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame
	var le: LineEdit = ix._strip_radius.get_line_edit()
	le.text = "0.0"
	ix._sync_strip_dressup_radius()
	check(le.text.contains("mm") and le.text != "0.0",
			"strip radius line edit contains mm and is not 0.0 (got `%s`)" % le.text)

	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	var prim_fid: String = view.feature_of_body(body)
	var prim_params = JSON.parse_string(_feature_params(view.doc, prim_fid))
	if typeof(prim_params) == TYPE_DICTIONARY and not (prim_params as Dictionary).has("distance"):
		pp.open(prim_fid)
		await process_frame
	await FilmUI.enter_sketch(ctx)
	sm.sketch.add_circle(0.0, 0.0, 8.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	var ex_fid := _first_fid(view.doc, "extrude")
	pp.open(ex_fid)
	await process_frame
	await process_frame
	var dist_spin: SpinBox = pp._spin_for_key("distance")
	var dist_edit: LineEdit = null if dist_spin == null else dist_spin.get_line_edit()
	var sel_len := 0 if dist_edit == null else dist_edit.get_selected_text().length()
	check(sel_len > 0,
			"extrude Distance line edit has a selection after two frames (len=%d)" % sel_len)

	var vp: Viewport = main.get_viewport()
	if dist_edit != null:
		dist_edit.grab_focus()
	await _push_esc(vp)
	if pp.visible:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		esc.echo = false
		pp._unhandled_input(esc)
		await process_frame
	check(not pp.visible, "Esc while Distance is focused hides the property panel")

	pp.open(ex_fid)
	await process_frame
	dist_spin = pp._spin_for_key("distance")
	if dist_spin != null:
		dist_spin.value = 14.0
	await process_frame
	var previewed := 14.0 if dist_spin == null else float(dist_spin.value)
	ix._commit_property_panel_on_deselect()
	await process_frame
	var kept := _param_float(view.doc, ex_fid, "distance")
	check(not pp.visible and absf(kept - previewed) < 0.05,
			"deselect hides the panel and keeps the previewed distance (vis=%s dist=%.3f want=%.3f)" % [
				str(pp.visible), kept, previewed])

	await FilmUI.enter_sketch(ctx)
	_status_log.clear()
	sm.cancel()
	await process_frame
	check(str(main.status_label.text) == "Sketch cancelled" and not sm.active,
			"cancel status is Sketch cancelled and session is inactive (got `%s` active=%s)" % [
				str(main.status_label.text), str(sm.active)])

	await FilmUI.enter_sketch(ctx)
	sm.sketch.add_line(0.0, 0.0, 10.0, 0.0)
	var save_path := "/tmp/rung01_wp10_save.sxp"
	main.current_path = save_path
	_status_log.clear()
	main._save_current()
	await process_frame
	var saved := _sxp_text(save_path)
	check((saved.contains("\"type\": \"sketch\"") or saved.contains("sketch")) and sm.active,
			"save of an open sketch writes a sketch feature and keeps the session (active=%s has_sketch=%s)" % [
				str(sm.active), str(saved.contains("sketch"))])
	if sm.active:
		sm.cancel()
		await process_frame
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	await FilmUI.enter_sketch(ctx)
	sm.sketch.add_line(0.0, 0.0, 10.0, 0.0)
	_status_log.clear()
	sm.exit_sketch()
	await process_frame
	check(_status_has("Sketch saved") and not _status_has("Sketch cancelled"),
			"exit_sketch on a drawn sketch emits Sketch saved and not Sketch cancelled (log: %s)" % str(_status_log))

	await _shutdown(ctx)


func _sxp_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var zr := ZIPReader.new()
	if zr.open(path) == OK:
		var raw: PackedByteArray = zr.read_file("features.json")
		zr.close()
		var unzipped := raw.get_string_from_utf8()
		if unzipped.contains("sketch") or unzipped.contains("type"):
			return unzipped
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	return txt


func _horiz_total(sm: SketchMode) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(str(cid))
		if str(info.get("type", "")) == "horizontal":
			n += 1
	return n


func _horiz_between(sm: SketchMode, ida: String, idb: String) -> int:
	var n := 0
	for cid in sm.sketch.constraint_ids():
		var info: Dictionary = sm.sketch.constraint_info(str(cid))
		if str(info.get("type", "")) != "horizontal":
			continue
		var refs: Array = info.get("refs", [])
		if refs.size() < 2:
			continue
		var a := str(refs[0].get("entity", ""))
		var b := str(refs[1].get("entity", ""))
		if (a == ida and b == idb) or (a == idb and b == ida):
			n += 1
	return n


func _first_fid(doc, type: String) -> String:
	for f in doc.graph_features():
		if str(f.get("type", "")) == type:
			return str(f.get("id", ""))
	return ""


func _feature_params(doc, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("params", "{}"))
	return "{}"


func _param_float(doc, fid: String, key: String) -> float:
	var parsed = JSON.parse_string(_feature_params(doc, fid))
	if typeof(parsed) != TYPE_DICTIONARY:
		return NAN
	return float((parsed as Dictionary).get(key, NAN))


func _last_status() -> String:
	if _status_log.is_empty():
		return ""
	return _status_log[_status_log.size() - 1]


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


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
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _sketch_key(ix: ViewportInteraction, keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	ix._sketch_input(down)
	await process_frame


func _push_esc(vp: Viewport) -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.physical_keycode = KEY_ESCAPE
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	up.echo = false
	vp.push_input(up)
	await process_frame
	await process_frame


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame
