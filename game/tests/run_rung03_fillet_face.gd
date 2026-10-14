# Rung 3 WP6 — Shift+face adds the face loop; plain face stays refused.
# Click-built to the cut. On main a later face click is refused (M11).
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung03_fillet_face.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung03 fillet face")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await Tutor1Fixture.boot(self, ROOT_SIZE, _on_status_local, ["sketch_mode", "interaction", "ops_panel"])
	if not await _build_cut(ctx):
		ctx.main.queue_free()
		return
	await _fillet_edges_then_face(ctx)
	await _fillet_face_first(ctx)
	await _shell_back(ctx)
	ctx.main.queue_free()


func _build_cut(ctx: FilmContext) -> bool:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return false
	await _zoom(ctx, Vector3.ZERO, 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	var chip: Button = null
	if bar != null:
		for c in bar.get_children():
			if c is Button and (c as Button).text == "Center":
				chip = c
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center", "Center")):
		return false
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(60, 60))
	if not await _extrude(ctx, "30", 0):
		return false
	if not await _open_z_face(ctx, 30.0):
		return false
	sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(35, 0))
	if not await _extrude(ctx, "25", 2):
		return false
	if not await _open_z_face(ctx, 55.0):
		return false
	sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(30, 0))
	if not await _extrude_cut(ctx):
		return false
	var vol := Tutor1Fixture.volume(ctx)
	print("  cut volume %s" % str(vol))
	check(absf(vol - 372702.4) < 5.0, "cut volume 372702 (got %s)" % str(vol))
	return absf(vol - 372702.4) < 5.0


func _fillet_edges_then_face(ctx: FilmContext) -> void:
	var body := Tutor1Fixture.only_body(ctx)
	ctx.view.select_entity(body, "")
	await process_frame
	if not await _arm_fillet(ctx, 5.0):
		return
	# Corner table: each view makes that vertical reachable (M12).
	for row in FilletPick.CORNERS:
		var key: Key = row["view"] as Key
		var focus = ctx.main.get_viewport().gui_get_focus_owner()
		if focus is LineEdit:
			(focus as LineEdit).release_focus()
		await _push_key(ctx.main.get_viewport(), key, 0)
		# The view key snaps, then framing settles. One frame was enough for
		# the camera to still be on the previous side, so the far corner
		# toggled the near vertical.
		for _frame in 6:
			await process_frame
		var edge_id := _vertical_near(ctx, body, float(row["x"]), float(row["y"]))
		check(edge_id != "", "vertical at %s,%s" % [str(row["x"]), str(row["y"])])
		# Same screen pixel as the far twin in an ortho side view. The named
		# id is the pick; the ray must not toggle the other vertical.
		ctx.view.offer_edge(edge_id)
		var pt := FilletPick.pick_point_for_corner(float(row["x"]), float(row["y"]), 15.0)
		var mark := _status_log.size()
		await _click_model(ctx, pt, "vertical corner")
		var st := Tutor1Fixture.status_since(_status_log, mark)
		print("  corner %s,%s view %s edges %d -> %s" % [
			str(row["x"]), str(row["y"]), str(key),
			ctx.view.selected_edges.size(), st])
		check(st.contains("mm vertical"), "corner pick is a vertical (got '%s')" % st)
		check(ctx.view.selected_edges.has(edge_id), "named vertical %s stays selected" % edge_id)
	check(ctx.view.selected_edges.size() == 4, "four verticals armed (got %d)" % ctx.view.selected_edges.size())
	# Shift+face on z=30 → 9 edges.
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	var face30 := Tutor1Fixture.face_at_z(ctx, body, 30.0)
	check(face30 != "", "z=30 face")
	var pick := FacePick.point(ctx.view.doc, face30)
	var mark2 := _status_log.size()
	await FilmUI._viewport_click_shift(ctx, FilmUI.model_to_screen(ctx, pick))
	await process_frame
	var after_shift := Tutor1Fixture.status_since(_status_log, mark2)
	print("  shift+face: %s edges=%d" % [after_shift, ctx.view.selected_edges.size()])
	check(ctx.view.selected_edges.size() == 9, "Shift+face → 9 edges (got %d)" % ctx.view.selected_edges.size())
	check(after_shift.contains("Fillet: 9 edge(s)"), "status names 9 edges (got '%s')" % after_shift)
	# Plain face click refused; count stays 9.
	var mark3 := _status_log.size()
	await _click_model(ctx, pick, "plain face")
	var refused := Tutor1Fixture.status_since(_status_log, mark3)
	check(ctx.view.selected_edges.size() == 9, "plain face keeps 9 (got %d)" % ctx.view.selected_edges.size())
	check(refused.contains(FilletPick.REFUSE_FACE) or refused.contains("No edge near click"),
			"plain face refused with pinned message (got '%s')" % refused)
	var before := _fillet_count(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	for _i in 8:
		await process_frame
	check(_fillet_count(ctx) == before + 1, "one fillet feature")
	var applied := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	print("  applied: %s" % applied)
	check(applied.contains("Fillet 9 edges 5.00 applied"),
			"status Fillet 9 edges 5.00 applied (got '%s')" % applied)
	var vol := Tutor1Fixture.volume(ctx)
	check(absf(vol - 370784.6) / 370784.6 < 0.002, "r5 volume (got %s)" % str(vol))


func _fillet_face_first(ctx: FilmContext) -> void:
	# Fresh cut body for the face-first path: undo the r5 fillet if possible,
	# otherwise rebuild is too heavy — select body and arm with face first on
	# the annulus for R1.5 (M10 path, still pinned).
	var body := Tutor1Fixture.only_body(ctx)
	ctx.view.select_entity(body, "")
	await process_frame
	if not await _arm_fillet(ctx, 1.5):
		return
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	var face55 := Tutor1Fixture.face_at_z(ctx, body, 55.0)
	check(face55 != "", "z=55 annulus")
	var mark := _status_log.size()
	# The walk names the face. A lone edge used to steal that click, and the
	# bridge's second press then toggled one rim off.
	var bridge := preload("res://scripts/automation_bridge.gd").new()
	ctx.main.add_child(bridge)
	await process_frame
	var reply: Dictionary = await bridge._cmd_pointer({"face_normal": [0, 0, 1], "plane": 55.0}, "click")
	bridge.queue_free()
	var st := Tutor1Fixture.status_since(_status_log, mark)
	print("  face-first: %s edges=%d at=%s" % [st, ctx.view.selected_edges.size(), str(reply.get("at", []))])
	check(ctx.view.selected_edges.size() == 2, "face-first takes 2 rims (got %d)" % ctx.view.selected_edges.size())
	var before := _fillet_count(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	for _i in 8:
		await process_frame
	check(_fillet_count(ctx) == before + 1, "R1.5 fillet feature")
	var applied := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	print("  applied: %s" % applied)
	check(applied.contains("Fillet 2 edges 1.50 applied"),
			"status Fillet 2 edges 1.50 applied (got '%s')" % applied)
	var vol := Tutor1Fixture.volume(ctx)
	check(absf(vol - 370587.4) / 370587.4 < 0.002, "rounded volume (got %s)" % str(vol))


func _shell_back(ctx: FilmContext) -> void:
	await _push_key(ctx.main.get_viewport(), KEY_8, 0)
	await process_frame
	var body := Tutor1Fixture.only_body(ctx)
	ctx.view.select_entity(body, "")
	await process_frame
	await _click_model(ctx, Vector3(50, 0, 0), "back face")
	await process_frame
	check(ctx.view.selected_face != "", "back face selected")
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var shell_chip := FilmUI.find_button(strip, "Shell") if strip != null else null
	check(shell_chip != null and shell_chip.is_visible_in_tree(), "Shell chip present")
	if shell_chip == null:
		return
	await FilmUI.click_control(ctx, shell_chip, FilmUICues.alert("Shell", "Shell"))
	var thick: LineEdit = ctx.main.find_child("ThicknessLineEdit", true, false)
	check(thick != null, "thickness field")
	if thick != null:
		thick.text = "1"
	var ok: Button = ctx.main.find_child("ShellOk", true, false)
	if ok != null:
		await FilmUI.click_control(ctx, ok, FilmUICues.alert("Apply", "Shell Apply"))
	for _i in 10:
		await process_frame
	var st := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	print("  shell: %s" % st)
	check(st.contains("Shell 1.0000 mm applied"), "Shell 1.0000 mm applied (got '%s')" % st)
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	var ext: Vector3 = bb["max"] - bb["min"]
	check(absf(ext.x - 120.0) < 0.3 and absf(ext.y - 120.0) < 0.3 and absf(ext.z - 55.0) < 0.3,
			"bbox unchanged 120×120×55 (got %s)" % str(ext))
	var vol := Tutor1Fixture.volume(ctx)
	check(absf(vol - 39311.0) / 39311.0 < 0.002, "final volume (got %s)" % str(vol))


func _arm_fillet(ctx: FilmContext, radius: float) -> bool:
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Fillet") if strip != null else null
	check(chip != null and chip.is_visible_in_tree(), "Fillet chip visible")
	if chip == null:
		return false
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Fillet", "Fillet"))
	await process_frame
	var spin: SpinBox = ctx.main.find_child("StripRadius", true, false)
	check(spin != null and spin.is_visible_in_tree(), "StripRadius visible")
	if spin == null:
		return false
	var line := spin.get_line_edit()
	await _x11_click_screen(ctx.main.get_viewport(), line.get_global_rect().get_center())
	await process_frame
	await SxInput.push_key(ctx.main.get_viewport(), KEY_A, 0, KEY_MASK_CTRL)
	var text := "1.5" if absf(radius - 1.5) < 0.01 else str(int(round(radius)))
	await _type_text(ctx.main.get_viewport(), text)
	for _i in 4:
		await process_frame
	check(is_equal_approx(ctx.main.ops_panel.dressup_radius(), radius),
			"typed %s is dressup radius (got %s line '%s')" % [text, str(ctx.main.ops_panel.dressup_radius()), line.text])
	# Enter commits and gives the keys back. A following 2/3/6 must orbit,
	# not append a digit (1.5 + Top became 1.53).
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	for _i in 4:
		await process_frame
	check(is_equal_approx(ctx.main.ops_panel.dressup_radius(), radius),
			"Enter keeps dressup radius %s (got %s)" % [str(radius), str(ctx.main.ops_panel.dressup_radius())])
	var st := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	var shown := "%.2f" % radius
	check(st.contains("r=" + shown), "status shows r=%s (got '%s')" % [shown, st])
	check(not st.contains("applied"), "field Enter does not apply (got '%s')" % st)
	check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet armed")
	return ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES


func _fillet_count(ctx: FilmContext) -> int:
	var n := 0
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


func _extrude(ctx: FilmContext, distance: String, op_index: int) -> bool:
	await FilmSteps.type_distance(ctx, distance)
	await FilmSteps.pick_finish(ctx, op_index, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button()
	if ex == null:
		return false
	await _x11_click(ex)
	for _i in 10:
		await process_frame
	return str(ctx.main.status_label.text).contains("Extrude")


func _extrude_cut(ctx: FilmContext) -> bool:
	await FilmSteps.type_distance(ctx, "1")
	await FilmSteps.pick_finish(ctx, 1, 1)  # Cut, Through All
	var ex: Button = ctx.main.sketch_chrome.extrude_button()
	if ex == null:
		return false
	await _x11_click(ex)
	for _i in 10:
		await process_frame
	return str(ctx.main.status_label.text).contains("Extrude")


func _open_z_face(ctx: FilmContext, z: float) -> bool:
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	var body := Tutor1Fixture.only_body(ctx)
	if body == "":
		return false
	var face := Tutor1Fixture.face_at_z(ctx, body, z)
	if face == "":
		return false
	var pick := FacePick.point(ctx.view.doc, face)
	if ctx.view.selected_bodies.is_empty() and ctx.view.selected_face == "":
		await _click_model(ctx, Vector3(50, 0, 15), "select body")
	await _click_model(ctx, pick, "face z=%.0f" % z)
	if ctx.view.selected_face != face:
		await _click_model(ctx, pick, "drill face")
	if ctx.view.selected_face != face:
		return false
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Sketch") if strip != null else null
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.toolbar_sketch()):
		return false
	for _i in 4:
		await process_frame
	return ctx.main.sketch_mode.active


func _click_model(ctx: FilmContext, model: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, model)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s on screen" % desc)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))
	await process_frame


func _vertical_near(ctx: FilmContext, body: String, x: float, y: float) -> String:
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	var best := ""
	var best_d := 4.0
	for id in lines.keys():
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[pts.size() - 1]
		var delta := b - a
		if delta.length() < 1.0 or absf(delta.normalized().z) < 0.9:
			continue
		var centre := (a + b) * 0.5
		var dist := Vector2(centre.x - x, centre.y - y).length()
		if dist < best_d:
			best_d = dist
			best = str(id)
	return best


func _on_status_local(text: String) -> void:
	Tutor1Fixture.note(_status_log, text)
