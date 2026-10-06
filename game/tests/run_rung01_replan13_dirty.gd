extends SceneTree
## Rung 1 replan 13 WP4. Validation: a refused fillet does not dirty the document.
## Run:
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan13_dirty.gd

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan13 WP4 refused edit leaves the document clean")
	FilmUI.reset_fail_count()
	await _case_refuse_stays_clean()
	await _case_real_edit_is_dirty()
	await _case_refuse_twice_then_esc()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _fresh() -> Dictionary:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	var view: DocumentView = main.view
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 10, 10))
	await process_frame
	return {"main": main, "view": view, "doc": view.doc, "body": body}


func _save_as(main, doc: SxDocument) -> int:
	var save_path := ProjectSettings.globalize_path("user://replan13_wp4.sxp")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	main.current_path = save_path
	main._save_current()
	await process_frame
	check(FileAccess.file_exists(save_path), "Save As wrote %s" % save_path)
	check(not main._document_is_dirty(), "Save As marks the document clean")
	return doc.revision()


func _top_face(doc: SxDocument, body: String) -> String:
	var best := ""
	var best_z := -1e9
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if mx.z - mn.z > 0.1:
			continue
		if mx.z > best_z:
			best_z = mx.z
			best = str(fid)
	return best


func _select_top_edges(view: DocumentView, body: String) -> PackedStringArray:
	view.select_entity(body, "")
	var edges: PackedStringArray = view.doc.edges_of_face(_top_face(view.doc, body))
	view.selected_edges.clear()
	for e in edges:
		view.selected_edges.append(str(e))
	return view.selected_edges


func _refuse_fillet(main, view: DocumentView, body: String, radius: float) -> void:
	var ops = main.ops_panel
	_select_top_edges(view, body)
	ops.set_dressup_radius(radius)
	if ops._pending != OpsPanel.Pending.FILLET_EDGES:
		ops.arm_or_apply_fillet()
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame


func _push_esc(vp: Viewport) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		vp.push_input(ev)
		await process_frame
	await process_frame


func _file_new(main) -> void:
	main._on_file_menu(0)
	await process_frame
	await process_frame


func _shutdown(c: Dictionary) -> void:
	var save_path := ProjectSettings.globalize_path("user://replan13_wp4.sxp")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	(c["main"] as Node).queue_free()
	await process_frame
	await process_frame


func _case_refuse_stays_clean() -> void:
	print("- refused fillet does not dirty; File → New does not prompt")
	var c := await _fresh()
	var main = c["main"]
	var doc: SxDocument = c["doc"]
	var view: DocumentView = c["view"]
	var body := str(c["body"])
	var saved: int = await _save_as(main, doc)
	await _refuse_fillet(main, view, body, 50.0)
	var status: String = str(main.status_label.text)
	check(status.contains("exceeds the") or status.contains("fillet the R10 neck first"),
			"refusal text appears (got %s)" % status)
	check(str(doc.last_graph_error()).contains("limit "),
			"last_graph_error still names the limit (got %s)" % str(doc.last_graph_error()))
	check(not main._document_is_dirty(), "refused fillet leaves the document clean")
	check(doc.revision() == saved, "revision equals the saved revision (got %d want %d)" % [
			doc.revision(), saved])
	await _file_new(main)
	check(not main.confirm_dialog.visible, "File → New does not pop Discard after a refusal")
	# Direct fillet_edges fallback must not bump either when it returns false.
	var edges := _select_top_edges(view, body)
	var rev_direct: int = doc.revision()
	check(not doc.fillet_edges(edges, 50.0), "fillet_edges r=50 is refused")
	check(doc.revision() == rev_direct, "fillet_edges refusal does not bump revision")
	await _shutdown(c)


func _case_real_edit_is_dirty() -> void:
	print("- a real edit after a refusal is dirty and File → New prompts")
	var c := await _fresh()
	var main = c["main"]
	var doc: SxDocument = c["doc"]
	var view: DocumentView = c["view"]
	var body := str(c["body"])
	await _save_as(main, doc)
	await _refuse_fillet(main, view, body, 50.0)
	check(not main._document_is_dirty(), "still clean after the refusal")
	check(doc.set_body_color(body, Color(1.0, 0.2, 0.1)), "colour change applies")
	check(main._document_is_dirty(), "a colour change after a refusal is dirty")
	await _file_new(main)
	check(main.confirm_dialog.visible, "File → New prompts after a real edit")
	main.confirm_dialog.hide()
	await process_frame
	await _shutdown(c)


func _case_refuse_twice_then_esc() -> void:
	print("- refuse twice, then Esc: still clean")
	var c := await _fresh()
	var main = c["main"]
	var doc: SxDocument = c["doc"]
	var view: DocumentView = c["view"]
	var body := str(c["body"])
	var saved: int = await _save_as(main, doc)
	await _refuse_fillet(main, view, body, 50.0)
	await _refuse_fillet(main, view, body, 50.0)
	await _push_esc(main.get_viewport())
	check(not main._document_is_dirty(), "two refusals then Esc leave the document clean")
	check(doc.revision() == saved, "revision still equals the saved revision after two refusals")
	await _file_new(main)
	check(not main.confirm_dialog.visible, "File → New does not prompt after two refusals and Esc")
	await _shutdown(c)
