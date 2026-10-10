# sx-038 L7(b) and N14. Builds the rung-1 wrench with the replan17 walk
# helpers, re-edits the base extrude 10 → 14, and clicks the slot floor at
# R1.5. The refusal must name the 1.250 mm limit on the 150 mm line (the
# same sentence as the T=10 part; slot depth is still 2.5). Then opens
# blank.sxp, sketches a circle plus a loose line, and checks that leaving
# the sketch clears the host face and its frozen hover.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1 \
#   tools/godot/godot --headless --path game --script tests/run_rung01_sx038_regress.gd
extends "res://tests/run_rung01_replan17_walk.gd"

const LIMIT := "Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius"


func _init() -> void:
	print("rung01 sx-038 fillet limit and host face")
	_uuid = RegEx.new()
	_uuid.compile(UUID_RE)
	DirAccess.make_dir_recursive_absolute(OUT)
	FilmUI.reset_fail_count()
	var ctx := await _boot()
	await _stage_s1(ctx)
	if _first_red == "":
		await _stage_s2(ctx)
	if _first_red == "":
		await _stage_s3(ctx)
	if _first_red == "":
		await _stage_s4(ctx)
	if _first_red == "":
		await _stage_s5(ctx)
	if _first_red == "":
		await _l7b_exact_limit(ctx)
	if _first_red == "":
		await _n14_host_face(ctx)
	finish()


func _l7b_exact_limit(ctx: FilmContext) -> void:
	_begin("L7b")
	await _show_timeline(ctx)
	var boss := _boss_extrude_id(ctx)
	check(boss != "", "base extrude is on the timeline")
	if boss == "":
		return
	await _type_timeline_distance(ctx, boss, "14")
	await _click_screen(ctx.main.get_viewport(), Vector2(1240, 220))
	await process_frame
	await process_frame
	check(absf(_feature_distance(ctx, boss) - 14.0) < 0.05, "base extrude distance is 14")
	var slot := _cut_sketch_id(ctx)
	check(slot != "", "slot sketch is on the timeline")
	if slot != "":
		var pencil := _row_edit(ctx, slot)
		check(pencil != null, "slot sketch pencil is visible")
		_allow_editing = true
		_status_log.clear()
		if pencil != null:
			await _x11_click(pencil)
			await process_frame
			await process_frame
		_grab()
		var editing := false
		for s in _status_log:
			if s.contains("Editing sketch"):
				editing = true
		check(editing, "pencil reopens the slot sketch (`%s`)" % _grab())
		_allow_editing = false
		var exit_btn := ctx.main.find_child("ExitSketch", true, false) as Button
		check(exit_btn != null and exit_btn.is_visible_in_tree(), "Exit Sketch is visible")
		if exit_btn != null:
			await _x11_click(exit_btn)
			await process_frame
			await process_frame
		_grab()
		check(_grab() == "Sketch saved", "no-edit Exit saves the slot sketch (`%s`)" % _grab())
	var body := _only_body(ctx)
	await _select_body(ctx, body)
	await _arm_fillet(ctx)
	await _type_strip(ctx, "1.5")
	await _release_focus(ctx)
	await _key(ctx, KEY_3)
	_status_log.clear()
	await _zoom_slot_pick(ctx, body, Vector3(93.5, 0.0, 11.5))
	await _click_model(ctx, Vector3(93.5, 0.0, 11.5))
	await _key(ctx, KEY_ENTER)
	await process_frame
	await process_frame
	var got := _grab()
	check(got == LIMIT, "T=14 slot floor R1.5 status is the 1.250 sentence (got `%s`)" % got)
	await _key(ctx, KEY_ESCAPE)
	_grab()
	check(_saw("Edge pick cancelled"), "Esc cancels the edge pick (`%s`)" % _grab())


func _n14_host_face(ctx: FilmContext) -> void:
	_begin("N14")
	# Thickness edit dirties the wrench. Save so Open is not blocked by Discard.
	await _save_shortcut(ctx)
	_grab()
	check(_grab().begins_with("Saved"), "wrench saved before opening blank (`%s`)" % _grab())
	var path := _blank_sxp if _blank_sxp != "" else OUT.path_join("blank.sxp")
	await _open_sxp(ctx, path)
	_grab()
	check(_grab().begins_with("Opened ") and _grab().contains("blank.sxp"),
			"Open blank (`%s`)" % _grab())
	var body := _only_body(ctx)
	check(body != "", "blank has one body")
	if body == "":
		return
	await _sketch_on_top(ctx, body, 10.0)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "rail Sketch opened on the top face")
	if sm == null or not sm.active:
		return
	var host := str(sm.host_face_id)
	check(host != "" and ctx.view.selected_face == host,
			"host face is selected while sketching (face=%s host=%s)" % [ctx.view.selected_face, host])
	await _draw_circle(ctx, Vector2(40.0, 0.0), "5")
	await _press_rail(ctx, "Line")
	await _click_uv(ctx, Vector2(70.0, 12.0), "loose line start")
	await _click_uv(ctx, Vector2(88.0, 18.0), "loose line end")
	await process_frame
	check(sm.has_open_chain(), "the loose line leaves the chain open")
	await _pick_op(_finish_op(ctx), 1)
	await _pick_end(_finish_end(ctx), 0)
	await _type_distance(ctx, "2.5")
	_status_log.clear()
	await _press_extrude(ctx)
	var refused := _grab()
	check(sm.active, "refusal keeps the sketch open")
	check(refused.contains("breaks the chain") and refused.contains("delete or trim it"),
			"refusal names the open line (got `%s`)" % refused)
	check(_uuid.search(refused) == null, "refusal status has no uuid (got `%s`)" % refused)
	await _release_focus(ctx)
	_status_log.clear()
	await _key(ctx, KEY_ESCAPE)
	var ladder := _grab()
	check(sm.active, "first Esc after refusal stays in the sketch")
	check(ladder.contains("— Esc again exits the sketch"),
			"first Esc is the exit ladder (got `%s`)" % ladder)
	await _key(ctx, KEY_ESCAPE)
	await process_frame
	await process_frame
	check(not sm.active, "second Esc leaves the sketch")
	check(_grab() == "Sketch saved", "second Esc is Sketch saved (got `%s`)" % _grab())
	check(sm.host_face_id == "", "remembered host face is cleared")
	check(ctx.view.selected_face == "" and ctx.view.selected_faces.is_empty(),
			"host face is not left selected (face=%s faces=%s)" % [
				ctx.view.selected_face, str(ctx.view.selected_faces)])
	check(ctx.view.selected_face != host, "selection is not the host face")
	check(ctx.view.hovered_face == "" or ctx.view.hovered_face != host,
			"frozen host-face hover is cleared (hover=%s)" % ctx.view.hovered_face)
	var card: Control = ctx.main.card_box
	check(card == null or not card.visible, "selection card is hidden")
	await _click_menu_item(ctx, "File", 0, "File → New")
	await process_frame
	check(ctx.main.confirm_dialog != null and ctx.main.confirm_dialog.visible,
			"File → New shows Discard after the sketch edit")


func _cut_sketch_id(ctx: FilmContext) -> String:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("op", "")) != "cut":
			continue
		return str(parsed.get("sketch", ""))
	return ""
