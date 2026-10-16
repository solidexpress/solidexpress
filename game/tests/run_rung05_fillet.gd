# Rung 5 WP7 — Fillet R5 on both flange outer faces (four circular edges).
# Kernel-built reshell stage, then Fillet chip, z=260, Shift+ z=−260, Enter.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung05_fillet.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const APPLIED := "Fillet 4 edges 5.00 applied"
const PITCH := 94.0
const HOLE_R := 5.0
## Outward normals. plane= is FacePick.plane_offset (n·pick): 260 at both rims.
const FACES: Array = [
	{"normal": Vector3(0, 0, 1), "plane": 260.0, "view": KEY_3, "shift": false, "edges": 2, "pivot": Vector3(0, 0, 260)},
	{"normal": Vector3(0, 0, -1), "plane": 260.0, "view": KEY_8, "shift": true, "edges": 4, "pivot": Vector3(0, 0, -260)},
]


func _init() -> void:
	status_echo = true
	print("rung05 fillet")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	if ctx == null or ctx.main == null:
		return
	var ext := _build_reshelled(ctx.view.doc)
	check(ext != "", "reshelled pipe on the document")
	if ext == "":
		ctx.main.queue_free()
		return
	ctx.view.graph_changed()
	for _i in 12:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after reshell")
	await _fillet_rims(ctx)
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


func _build_reshelled(doc: SxDocument) -> String:
	var ext := _build_mirrored(doc)
	if ext == "":
		return ""
	var body := _output_body(doc, ext)
	var remove := PackedStringArray()
	remove.append_array(_planar_at_z(doc, body, -260.0))
	remove.append_array(_planar_at_z(doc, body, 0.0))
	if remove.is_empty():
		return ""
	var sh := doc.graph_add_shell(ext, remove, 10.0)
	if sh == "":
		return ""
	return ext


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


func _fillet_rims(ctx: FilmContext) -> void:
	var body := FilmSteps.only_body(ctx)
	check(body != "", "one body to fillet")
	if body == "":
		return
	ctx.view.select_entity(body, "")
	await process_frame
	if not await _arm_fillet(ctx, 5.0):
		return
	for row in FACES:
		await _pick_row(ctx, row)
		if failures > 0 or FilmUI.fail_count > 0:
			return
	check(ctx.view.selected_edges.size() == 4, "four circular rims (got %d)" % ctx.view.selected_edges.size())
	var before := _feature_count(ctx)
	var fillets0 := _fillet_count(ctx)
	await _refuse_radius(ctx, 30.0, before)
	if failures > 0:
		return
	await _type_radius(ctx, 5.0)
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	for _i in 16:
		await process_frame
	check(_fillet_count(ctx) == fillets0 + 1, "one fillet feature")
	check(_feature_count(ctx) == before + 1, "one new feature")
	var applied := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	check(applied.contains(APPLIED), "status 4 edges 5.00 (got '%s')" % applied)
	var tmp := "user://rung05_fillet.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(not path.begins_with("user://") and not path.begins_with("res://"),
			"export path is globalized")
	check(ctx.view.doc.export_3mf(path), "export_3mf final")
	var result := SxChecker.run("rung05", ["final", path])
	check(int(result["code"]) == 0,
			"check_rung05.py final exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])


func _pick_row(ctx: FilmContext, row: Dictionary) -> void:
	var focus = ctx.main.get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		(focus as LineEdit).release_focus()
	await SxInput.push_key(ctx.main.get_viewport(), row["view"] as Key)
	await FilmUI.wait_frames(ctx.tree, 6)
	await _zoom(ctx, row["pivot"] as Vector3, 280.0)
	if bool(row["shift"]):
		await FilmSteps.shift_click_face(ctx, row["normal"] as Vector3, float(row["plane"]))
	else:
		await FilmSteps.click_face(ctx, row["normal"] as Vector3, float(row["plane"]))
	await process_frame
	var n := ctx.view.selected_edges.size()
	check(n == int(row["edges"]), "edges after pick %d (got %d)" % [int(row["edges"]), n])


func _arm_fillet(ctx: FilmContext, radius: float) -> bool:
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Fillet") if strip != null else null
	check(chip != null and chip.is_visible_in_tree(), "Fillet chip visible")
	if chip == null:
		return false
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Fillet", "Fillet"))
	await process_frame
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet armed")
	if not await _type_radius(ctx, radius):
		return false
	var st := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	check(st.contains("r=" + ("%.2f" % radius)), "status shows r=%.2f (got '%s')" % [radius, st])
	check(not st.contains("applied"), "field Enter does not apply (got '%s')" % st)
	return ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES


func _type_radius(ctx: FilmContext, radius: float) -> bool:
	var spin: SpinBox = ctx.main.find_child("StripRadius", true, false)
	check(spin != null and spin.is_visible_in_tree(), "StripRadius visible")
	if spin == null:
		return false
	var line := spin.get_line_edit()
	await _x11_click_screen(ctx.main.get_viewport(), line.get_global_rect().get_center())
	await process_frame
	await SxInput.push_key(ctx.main.get_viewport(), KEY_A, 0, KEY_MASK_CTRL)
	var text := str(int(round(radius)))
	await _type_text(ctx.main.get_viewport(), text)
	for _i in 4:
		await process_frame
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	for _i in 4:
		await process_frame
	check(is_equal_approx(ctx.main.ops_panel.dressup_radius(), radius),
			"typed %s is dressup radius (got %s)" % [text, str(ctx.main.ops_panel.dressup_radius())])
	return is_equal_approx(ctx.main.ops_panel.dressup_radius(), radius)


func _refuse_radius(ctx: FilmContext, radius: float, timeline_n: int) -> void:
	var picks := ctx.view.selected_edges.size()
	if not await _type_radius(ctx, radius):
		return
	await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	for _i in 8:
		await process_frame
	var st := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	check(not st.contains("applied"), "radius %s refused (got '%s')" % [str(radius), st])
	check(_feature_count(ctx) == timeline_n, "timeline unchanged on r=%s" % str(radius))
	check(ctx.view.selected_edges.size() == picks, "picks kept (got %d)" % ctx.view.selected_edges.size())
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "still armed after refuse")


func _planar_at_z(doc: SxDocument, body: String, z: float) -> PackedStringArray:
	var out := PackedStringArray()
	if body == "":
		return out
	for fid in doc.get_face_ids(body):
		var pick: Vector3 = doc.face_pick_point(str(fid))
		if absf(pick.z - z) > 0.5:
			continue
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.z <= 0.5 and ext.x > 10.0 and ext.y > 10.0:
			out.append(str(fid))
	return out


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


func _fillet_count(ctx: FilmContext) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


func _feature_count(ctx: FilmContext) -> int:
	return ctx.view.doc.graph_features().size()
