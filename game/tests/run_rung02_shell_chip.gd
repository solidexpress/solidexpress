# Rung 2 WP4 — Shell chip on a selected planar face.
# Click-built 100×60×50 box, R10 on the four Z edges (the plan's no_hole volume),
# then strip:shell → thickness 5 → Enter.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung02_shell_chip.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)
# no_hole(60): rounded(60) − inner(60). inner(60) = 201534.3.
const NO_HOLE_60 := 94173.7

var _status_log: Array[String] = []


func _init() -> void:
	print("rung02 shell chip")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	await _build_box(ctx)
	if failures > 0:
		ctx.main.queue_free()
		return
	_fillet_z_edges(ctx)
	if failures > 0:
		ctx.main.queue_free()
		return
	var before := _feature_count(ctx)
	check(_find_auto(ctx.main, "strip:shell") == null or not (_find_auto(ctx.main, "strip:shell") as CanvasItem).is_visible_in_tree(),
			"Shell chip absent with nothing selected")
	await _select_top(ctx)
	var chip := _find_auto(ctx.main, "strip:shell") as Control
	check(chip != null and chip.is_visible_in_tree(), "strip:shell is visible on the top face")
	if chip == null or not chip.is_visible_in_tree():
		ctx.main.queue_free()
		return
	var rect := chip.get_global_rect()
	var window := Rect2(Vector2.ZERO, Vector2(ROOT_SIZE))
	check(rect.size.x > 8.0 and rect.size.y > 8.0 and window.encloses(rect),
			"strip:shell is inside 1280×800 (%s)" % str(rect))
	check(str(chip.text) == "Shell", "Shell chip label is Shell (got '%s')" % chip.text)
	var bb0 := _bbox_size(ctx)
	await _open_shell(ctx, chip)
	var field := _find_auto(ctx.main, "finish:Thickness") as LineEdit
	var ok_btn := _find_auto(ctx.main, "finish:Ok") as Button
	check(field != null and field.is_visible_in_tree(), "finish:Thickness is visible")
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "finish:Ok is visible")
	check(field != null and field.text == "5", "thickness default is 5 (got '%s')" % (field.text if field != null else ""))
	if field == null:
		ctx.main.queue_free()
		return
	await _type_thickness(ctx, field, "30")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	for _i in 6:
		await process_frame
	_note_status(ctx)
	check(_feature_count(ctx) == before, "thickness 30 adds no feature (%d → %d)" % [before, _feature_count(ctx)])
	check(_bbox_size(ctx).distance_to(bb0) < 0.2, "bbox unchanged after a refused shell")
	var refused := str(ctx.main.status_label.text)
	print("  refused status: " + refused)
	check(refused == "Shell thickness 30.0000 mm is at least half the 50.0000 mm extent (limit) — nothing added",
			"thickness past half the extent is refused (got '%s')" % refused)
	check(field.text == "5", "field returns to 5 after refusal (got '%s')" % field.text)
	await _type_thickness(ctx, field, "5")
	await _push_key(ctx.main.get_viewport(), KEY_ENTER, 0)
	for _i in 12:
		await process_frame
	_note_status(ctx)
	var applied := str(ctx.main.status_label.text)
	print("  applied status: " + applied)
	var names := _feature_names(ctx)
	print("  timeline: " + ", ".join(names))
	check(_has_shell(names) and applied == "Shell 5.0000 mm applied",
			"timeline has a Shell feature (%s; %s)" % [", ".join(names), applied])
	var bb1 := _bbox_size(ctx)
	print("  bbox %s → %s" % [str(bb0), str(bb1)])
	check(bb1.distance_to(bb0) < 0.2, "bbox unchanged after shell (got %s)" % str(bb1))
	var vol := _volume(ctx)
	print("  volume %.4f (want %.1f ± 0.5%%)" % [vol, NO_HOLE_60])
	check(absf(vol - NO_HOLE_60) <= NO_HOLE_60 * 0.005, "volume no_hole(60) (got %.4f)" % vol)
	var chip_after := _find_auto(ctx.main, "strip:shell") as CanvasItem
	var nothing := ctx.view.selected_body == "" and ctx.view.selected_face == ""
	check(nothing, "nothing selected after shell")
	check(chip_after == null or not chip_after.is_visible_in_tree(),
			"Shell chip absent with nothing selected")
	await _hint_without_face(ctx)
	await _edit_thickness_from_timeline(ctx)
	ctx.main.queue_free()


func _hint_without_face(ctx: FilmContext) -> void:
	# The open top is gone; a side wall is still a planar face.
	await _select_normal(ctx, Vector3(1, 0, 0), Vector3(100, 30, 25), false)
	var chip := _find_auto(ctx.main, "strip:shell") as Control
	if chip == null or not chip.is_visible_in_tree():
		check(false, "strip:shell returns for the hint case")
		return
	var before := _feature_count(ctx)
	await _open_shell(ctx, chip)
	# Drop the face, then apply from the still-open panel.
	var empty := Vector2(24, 760)
	await _x11_click_screen(ctx.main.get_viewport(), empty)
	await process_frame
	await process_frame
	var ok_btn := _find_auto(ctx.main, "finish:Ok") as Button
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "finish:Ok stays up with no face")
	if ok_btn == null:
		return
	await _x11_click(ok_btn)
	for _i in 4:
		await process_frame
	_note_status(ctx)
	var hint := str(ctx.main.status_label.text)
	print("  no-face status: " + hint)
	check(_feature_count(ctx) == before, "no face adds no feature")
	check(hint == "Shell needs a planar face — nothing added",
			"no-face shell shows a hint (got '%s')" % hint)


func _edit_thickness_from_timeline(ctx: FilmContext) -> void:
	ctx.main.show_timeline = true
	ctx.main._update_panel_visibility()
	var tl: TimelinePanel = ctx.main.timeline
	tl.refresh()
	await process_frame
	await process_frame
	var btn := _shell_row_button(ctx)
	check(btn != null and btn.is_visible_in_tree(), "Shell timeline row is visible")
	if btn == null:
		return
	await FilmUI.click_control(ctx, btn, FilmUICues.alert("Shell", "Edit thickness"))
	await _x11_click_screen(ctx.main.get_viewport(), btn.get_global_rect().get_center(), true)
	for _i in 4:
		await process_frame
	var spin := tl.property_panel.find_child("Param_thickness", true, false) as SpinBox
	check(tl.property_panel.visible and spin != null and spin.is_visible_in_tree(),
			"double-click opens Shell thickness")
	if spin == null:
		return
	print("  timeline thickness %.4f" % spin.value)


func _build_box(ctx: FilmContext) -> void:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(50, 30, 0), 160.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(100, 60))
	await process_frame
	var dist := _distance_edit(ctx)
	check(dist != null and dist.is_visible_in_tree(), "Distance field is visible")
	if dist != null:
		await _x11_click(dist)
		await _type_text(dist.get_viewport(), "50")
		await process_frame
	var ex: Button = ctx.main.sketch_chrome.extrude_button() if ctx.main.sketch_chrome != null else null
	check(ex != null and ex.is_visible_in_tree(), "Extrude button is visible")
	if ex != null:
		await _x11_click(ex)
	for _i in 8:
		await process_frame
	_note_status(ctx)
	var body := _only_body(ctx)
	check(body != "", "extrude made one body")
	if body == "":
		return
	var sz := _bbox_size(ctx)
	check(sz.distance_to(Vector3(100, 60, 50)) < 0.2, "box is 100×60×50 (got %s)" % str(sz))


## The plan's 94173.7 is the filleted shell. The four Z edges are the PDF fillet
## that sits under Shell; the chip test starts from that solid.
func _fillet_z_edges(ctx: FilmContext) -> void:
	var body := _only_body(ctx)
	var fid := ctx.view.feature_of_body(body)
	var edges := PackedStringArray()
	var lines: Dictionary = ctx.view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) > 5.0 and absf(d.x) < 0.5 and absf(d.y) < 0.5:
			edges.append(str(id))
	check(edges.size() == 4, "four Z edges to fillet (got %d)" % edges.size())
	if edges.size() != 4 or fid == "":
		return
	var added := ctx.view.doc.graph_add_fillet(fid, edges, 10.0)
	check(added != "", "fillet feature added (%s)" % ctx.view.doc.last_graph_error())
	ctx.view.graph_changed()
	await process_frame
	await process_frame


func _select_top(ctx: FilmContext) -> void:
	await _select_normal(ctx, Vector3(0, 0, 1), Vector3(50, 30, 50))


func _select_normal(ctx: FilmContext, normal: Vector3, fallback: Vector3, exact: bool = true) -> void:
	var body := _only_body(ctx)
	var face := FilmUI.find_face_by_normal(ctx.view, body, normal)
	var tag := str(normal)
	check(face != "", "%s face exists" % tag)
	if face == "":
		return
	var pick_pt: Vector3 = FilmUI.face_pick_point(ctx.view, body, face)
	if pick_pt == Vector3.INF:
		pick_pt = fallback
	var screen := FilmUI.model_to_screen(ctx, pick_pt)
	check(FilmUI.require_on_screen(ctx, screen, tag), "%s face point is on screen" % tag)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Select %s face" % tag))
	await process_frame
	if ctx.view.selected_face != face:
		await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("Click", "Drill %s face" % tag))
		await process_frame
	if exact:
		check(ctx.view.selected_face == face, "%s face selected" % tag)
	else:
		check(ctx.view.selected_face != "", "a face is selected for Shell")


func _open_shell(ctx: FilmContext, chip: Control) -> void:
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shell", "Open shell"))
	for _i in 3:
		await process_frame


func _type_thickness(ctx: FilmContext, field: LineEdit, text: String) -> void:
	await _x11_click(field)
	await process_frame
	field.select_all()
	await _type_text(ctx.main.get_viewport(), text)
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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	if main.sketch_mode != null:
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null:
		main.interaction.status.connect(_on_status)
	if main.ops_panel != null:
		main.ops_panel.status.connect(_on_status)
	return ctx


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


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


func _bbox_size(ctx: FilmContext) -> Vector3:
	var body := _only_body(ctx)
	if body == "":
		return Vector3.ZERO
	var bb: Dictionary = ctx.view.doc.measure_bbox(body)
	if bb.is_empty():
		return Vector3.ZERO
	return bb["max"] - bb["min"]


func _volume(ctx: FilmContext) -> float:
	var body := _only_body(ctx)
	if body == "":
		return -1.0
	return ctx.view.doc.body_volume(body)


func _feature_names(ctx: FilmContext) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ctx.view.doc.graph_features():
		out.append(str(f.get("name", "")))
	return out


func _feature_count(ctx: FilmContext) -> int:
	return ctx.view.doc.graph_features().size()


func _has_shell(names: PackedStringArray) -> bool:
	for n in names:
		if str(n).begins_with("Shell"):
			return true
	return false


func _shell_row_button(ctx: FilmContext) -> Button:
	var rows: Node = ctx.main.find_child("TimelineRows", true, false)
	if rows == null:
		return null
	for row in rows.get_children():
		for c in row.get_children():
			if c is Button and str((c as Button).text).begins_with("Shell"):
				return c
	return null


func _distance_edit(ctx: FilmContext) -> LineEdit:
	var chrome = ctx.main.sketch_chrome
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit


func _on_status(text: String) -> void:
	if text == "":
		return
	_status_log.append(text)
	print("  status: " + text)


func _note_status(ctx: FilmContext) -> void:
	if ctx.main != null and ctx.main.status_label != null:
		var text := str(ctx.main.status_label.text)
		if text != "" and (_status_log.is_empty() or _status_log[_status_log.size() - 1] != text):
			_status_log.append(text)
			print("  status: " + text)
