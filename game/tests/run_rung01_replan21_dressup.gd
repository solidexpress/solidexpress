# re-PLAN 21 WP6 — a lost fillet edge is a warning, not an error.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan21_dressup.gd
extends "res://tests/lib/sx_suite.gd"
const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const LOG_PATH := "/tmp/sx-replan21-dressup.log"

var _status: Array[String] = []


func _init() -> void:
	print("rung01 replan21 dressup")
	FilmUI.reset_fail_count()
	await _run()
	finish()


func _run() -> void:
	var ctx := await _boot()
	ctx.main.sketch_mode.status.connect(_on_status)
	ctx.main.timeline.status.connect(_on_status)
	var built := _box(ctx.view.doc)
	check(bool(built.get("ok", false)), "block built (%s)" % str(built.get("why", "")))
	if not bool(built.get("ok", false)):
		return
	ctx.view.graph_changed()
	await process_frame
	var doc: SxDocument = ctx.view.doc
	var edges: PackedStringArray = _top_edges(ctx.view, str(built["body"]))
	check(edges.size() >= 2, "block has top edges (%d)" % edges.size())
	var one := PackedStringArray()
	one.append(edges[0])
	var fil: String = doc.graph_add_fillet(str(built["extrude"]), one, 1.0)
	check(fil != "", "single-edge fillet added")
	ctx.view.graph_changed()
	await process_frame
	check(_warnings(doc).is_empty(), "a found fillet has no warning")
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
	if doc.has_method("set_kernel_log"):
		doc.set_kernel_log(LOG_PATH)
	_status.clear()
	await _edit_distance(ctx, str(built["extrude"]), "14")
	if doc.has_method("set_kernel_log"):
		doc.set_kernel_log("")
	var warns := _warnings(doc)
	var joined := " ".join(warns)
	check(joined.contains("all 1 edges lost on rebuild — it changes nothing now"), "warning names the lost edge (%s)" % joined)
	check(warns.size() == 1, "one warning row (got %d)" % warns.size())
	var log := _read_log()
	check(log.contains("[WARN]") and log.contains("fillet soft-skip"), "log warns fillet soft-skip")
	check(log.contains("fillet 3: fillet soft-skip: 1 edges lost on rebuild"), "log names fillet 3")
	check(not _error_soft(log), "no [ERROR] line mentions soft-skip")
	check(log.contains(": fillet soft-skip:"), "the warning is prefixed with the feature name")
	var preview := false
	for line in _status:
		if line.begins_with("Preview: distance = 14.0") and line.ends_with("it changes nothing now"):
			preview = true
	check(preview, "preview status ends with the warning and has the 14.0 prefix")
	var status_hit := false
	for line in _status:
		if line.contains("all 1 edges lost") or line.ends_with("it changes nothing now"):
			status_hit = true
	check(status_hit, "status after the edit ends with the warning (%s)" % str(_status))
	check(warns.size() == 1 and warns[0].begins_with("fillet 3:"), "warning starts with the feature name (%s)" % joined)
	var warn_lines := 0
	for line in log.split("\n"):
		if line.contains("[WARN]") and line.contains("soft-skip"):
			warn_lines += 1
	check(warn_lines == 1, "one WARN soft-skip line (got %d)" % warn_lines)
	var two := PackedStringArray()
	two.append(edges[0])
	two.append(edges[1])
	ctx.view.new_document()
	await process_frame
	built = _box(ctx.view.doc)
	doc = ctx.view.doc
	edges = _top_edges(ctx.view, str(built["body"]))
	two = PackedStringArray()
	two.append(edges[0])
	two.append(edges[1])
	var fil2: String = doc.graph_add_fillet(str(built["extrude"]), two, 1.0)
	check(fil2 != "", "two-edge fillet added")
	ctx.view.graph_changed()
	check(_warnings(doc).is_empty(), "both edges found, no warning")
	var params := _params_of(doc, fil2)
	var edge_list: Array = params.get("edges", [])
	if edge_list.size() >= 1:
		edge_list[edge_list.size() - 1] = "00000000-0000-4000-8000-000000000099"
		params["edges"] = edge_list
		params["face_cues"] = []
		doc.graph_set_params(fil2, JSON.stringify(params))
		ctx.view.graph_changed()
	var partial := " ".join(_warnings(doc))
	check(partial.contains("1 of 2 edges lost on rebuild"), "one of two edges lost (%s)" % partial)
	check(partial.begins_with("fillet 3:"), "partial warning names fillet 3 (%s)" % partial)
	check(not partial.contains("all 2 edges"), "a partial loss is not reported as every edge (%s)" % partial)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	ctx.main.queue_free()


func _warnings(doc: SxDocument) -> PackedStringArray:
	if doc.has_method("graph_warnings"):
		return doc.graph_warnings()
	return PackedStringArray()


func _error_soft(log: String) -> bool:
	for line in log.split("\n"):
		if line.contains("[ERROR]") and line.contains("soft-skip"):
			return true
	return false


func _read_log() -> String:
	if not FileAccess.file_exists(LOG_PATH):
		return ""
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func _edit_distance(ctx: FilmContext, fid: String, digits: String) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	var row: Control = tl._rows.get(fid) as Control
	var btn: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button and str(child.text) != "":
				btn = child
				break
	check(btn != null, "extrude row is visible")
	if btn == null:
		return
	var pos: Vector2 = btn.get_global_rect().get_center()
	_click(ctx.main.get_viewport(), pos)
	_click(ctx.main.get_viewport(), pos)
	await _frames(4)
	var spin := tl.property_panel.find_child("Param_distance", true, false) as SpinBox
	check(spin != null and tl.property_panel.visible, "Distance panel is open")
	if spin == null:
		return
	for ch in digits:
		var code := KEY_0 + int(ch)
		_push_key(ctx.main.get_viewport(), code as Key, false)
		await process_frame
	_push_key(ctx.main.get_viewport(), KEY_ENTER, false)
	await _frames(4)


func _box(doc: SxDocument) -> Dictionary:
	var sk := SxSketch.new()
	sk.add_line(-10, -10, 10, -10)
	sk.add_line(10, -10, 10, 10)
	sk.add_line(10, 10, -10, 10)
	sk.add_line(-10, 10, -10, -10)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return {"ok": false, "why": doc.last_graph_error()}
	var ex := doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	if ex == "":
		return {"ok": false, "why": doc.last_graph_error()}
	var body := ""
	for f in doc.graph_features():
		if str(f["id"]) == ex:
			body = str(f["output_body"])
	return {"ok": body != "", "body": body, "extrude": ex, "why": ""}


func _top_edges(view: DocumentView, body: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for eid in lines.keys():
		var pts: PackedVector3Array = lines[eid]
		if pts.size() < 2:
			continue
		var top := true
		for p in pts:
			if p.z < 9.5:
				top = false
		if top:
			out.append(str(eid))
	return out


func _params_of(doc: SxDocument, fid: String) -> Dictionary:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			var parsed = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed
	return {}


func _on_status(msg: String) -> void:
	_status.append(str(msg))


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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	return ctx


func _click(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)


func _push_key(vp: Viewport, code: Key, shift: bool) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = pressed
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = code if code >= KEY_0 and code <= KEY_9 else 0
		ev.shift_pressed = shift
		vp.push_input(ev)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
