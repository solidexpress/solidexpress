# Rung 5 WP6 — re-shell the mirrored half through strip:shell.
# Kernel-built mirror stage, then Bottom view, z=−260, thickness 10.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung05_reshell.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const APPLIED := "Shell 10.0000 mm applied"
const PITCH := 94.0
const HOLE_R := 5.0


func _init() -> void:
	status_echo = true
	print("rung05 reshell")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	if ctx == null or ctx.main == null:
		return
	var ext := _build_mirrored(ctx.view.doc)
	check(ext != "", "mirrored pipe on the document")
	if ext == "":
		ctx.main.queue_free()
		return
	ctx.view.graph_changed()
	for _i in 12:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after mirror")
	check(_shell_count(ctx) == 1, "one Shell feature before re-shell")
	await _reshell_chip(ctx)
	ctx.main.queue_free()


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	listen_status(main)
	if main.ops_panel != null and not main.ops_panel.status.is_connected(_on_status):
		main.ops_panel.status.connect(_on_status)
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	return ctx


func _build_mirrored(doc: SxDocument) -> String:
	var sk := SxSketch.new()
	sk.add_circle(0, 0, 75)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	var ext := doc.graph_add_extrude(sk_fid, 250.0, false, "new", "")
	if ext == "":
		return ""
	var body := _output_body(doc, ext)
	var ends := _z_faces(doc, body)
	if ends.size() != 2:
		return ""
	var sh := doc.graph_add_shell(ext, ends, 10.0)
	if sh == "":
		return ""
	var fl_sk := SxSketch.new()
	fl_sk.set_plane(Vector3(0, 0, 250), Vector3(1, 0, 0), Vector3(0, 1, 0))
	fl_sk.add_circle(0, 0, 112.5)
	var fl_sk_fid := doc.graph_add_sketch(fl_sk)
	var flange := doc.graph_add_extrude(fl_sk_fid, 10.0, false, "fuse", ext)
	if flange == "":
		return ""
	var cut_sk := SxSketch.new()
	cut_sk.set_plane(Vector3(0, 0, 260), Vector3(1, 0, 0), Vector3(0, 1, 0))
	cut_sk.add_circle(0, 0, 65)
	for k in 8:
		var ang := float(k) * PI / 4.0
		cut_sk.add_circle(PITCH * sin(ang), PITCH * cos(ang), HOLE_R)
	var cut_sk_fid := doc.graph_add_sketch(cut_sk)
	var cut := doc.graph_add_extrude(cut_sk_fid, -10.0, false, "cut", ext)
	if cut == "":
		return ""
	var sources := PackedStringArray([ext, sh, flange, cut])
	var mir := doc.graph_add_mirror(ext, Vector3.ZERO, Vector3(0, 0, 1), sources)
	if mir == "":
		return ""
	return ext


func _reshell_chip(ctx: FilmContext) -> void:
	await SxInput.push_key(ctx.main.get_viewport(), KEY_8)
	await FilmUI.wait_frames(ctx.tree, 6)
	await _zoom(ctx, Vector3(0, 0, -260), 280.0)
	# Bottom view, outward −Z. FacePick.plane_offset is n·pick = 260 at z=−260.
	await FilmSteps.click_face(ctx, Vector3(0, 0, -1), 260.0)
	check(ctx.view.selected_face != "", "face selected at z=−260")
	var chip := _find_auto(ctx.main, "strip:shell") as Control
	check(chip != null and chip.is_visible_in_tree(), "strip:shell is visible")
	if chip == null or not chip.is_visible_in_tree():
		return
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shell", "Open re-shell"))
	for _i in 3:
		await process_frame
	var field := _find_auto(ctx.main, "finish:Thickness") as LineEdit
	var ok_btn := _find_auto(ctx.main, "finish:Ok") as Button
	check(field != null and field.is_visible_in_tree(), "finish:Thickness is visible")
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "finish:Ok is visible")
	if field == null or ok_btn == null:
		return
	await _x11_click(field)
	await process_frame
	field.select_all()
	await _type_text(ctx.main.get_viewport(), "10")
	await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("OK", "Shell 10"))
	for _i in 16:
		await process_frame
	check(str(ctx.main.status_label.text) == APPLIED,
			"status Shell 10 (got '%s')" % ctx.main.status_label.text)
	check(ctx.view.doc.body_ids().size() == 1, "one body after re-shell")
	check(_shell_count(ctx) == 2, "second Shell feature after the mirror")
	var tmp := "user://rung05_reshell.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(not path.begins_with("user://") and not path.begins_with("res://"),
			"export path is globalized")
	check(ctx.view.doc.export_3mf(path), "export_3mf reshell")
	var result := SxChecker.run("rung05", ["reshell", path])
	check(int(result["code"]) == 0,
			"check_rung05.py reshell exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])
	check(str(result["text"]).contains("wall"),
			"checker reports wall at z=+125")


func _z_faces(doc: SxDocument, body: String) -> PackedStringArray:
	var out := PackedStringArray()
	if body == "":
		return out
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.z <= 0.2 and ext.x > 10.0 and ext.y > 10.0:
			out.append(str(fid))
	return out


func _output_body(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("output_body", ""))
	return ""


func _shell_count(ctx: FilmContext) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "shell":
			n += 1
	return n


func _find_auto(node: Node, id: String) -> Node:
	if node == null:
		return null
	if str(node.get_meta("sx_auto", "")) == id:
		return node
	for c in node.get_children():
		var hit := _find_auto(c, id)
		if hit != null:
			return hit
	return null
