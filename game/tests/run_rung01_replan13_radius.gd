# Rung 1 replan 13 WP3 — Fillet Radius in the selection strip and the Modify
# panel are one value. Validation suite: box via insert_primitive, select_entity,
# arm through ops_panel.arm_or_apply_fillet(); every key under test is a real
# pushed event. L3: Tab (not Enter) after typing 10 in the panel, 1.5 in the
# strip, and 10 in the strip, keeps strip, panel, and status `r=` on the same
# number. Strip text for 10 must start with "10" (not a scrolled "0.0 mm").
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script res://tests/run_rung01_replan13_radius.gd
extends SceneTree

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
	print("rung01 replan13 WP3 fillet radius strip/panel")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _st(main) -> String:
	return str(main.status_label.text)


func _strip(main) -> SpinBox:
	return main.interaction.find_child("StripRadius", true, false) as SpinBox


func _observe(main, tag: String) -> void:
	var spin := _strip(main)
	var text := ""
	if spin != null:
		var le: LineEdit = spin.get_line_edit()
		text = le.text if le != null else ""
	var panel_text := ""
	if main.ops_panel._radius_spin != null:
		var ple: LineEdit = main.ops_panel._radius_spin.get_line_edit()
		panel_text = ple.text if ple != null else ""
	print("  observed %s: strip.value=%s strip.text=`%s` panel.value=%s panel.text=`%s` status=`%s`" % [
		tag, str(spin.value) if spin != null else "?", text,
		str(main.ops_panel.dressup_radius()), panel_text, _st(main)])


func _text_radius(text: String) -> float:
	var t := text.strip_edges().replace("mm", "").replace("MM", "").strip_edges()
	if t.is_valid_float():
		return float(t)
	return NAN


func _parses_to(text: String, want: float) -> bool:
	var got := _text_radius(text)
	return not is_nan(got) and is_equal_approx(got, want)


func _agree(main, want: float, tag: String) -> void:
	var spin := _strip(main)
	var text := ""
	if spin != null:
		var le: LineEdit = spin.get_line_edit()
		text = le.text if le != null else ""
	check(spin != null, "%s: StripRadius exists" % tag)
	if spin == null:
		return
	check(is_equal_approx(spin.value, want),
			"%s: strip.value == %s (got %s, text `%s`)" % [tag, str(want), str(spin.value), text])
	check(is_equal_approx(main.ops_panel.dressup_radius(), want),
			"%s: panel Radius == %s (got %s)" % [tag, str(want), str(main.ops_panel.dressup_radius())])
	check(_parses_to(text, want),
			"%s: strip text parses to %s (got `%s`)" % [tag, str(want), text])
	if is_equal_approx(want, 10.0):
		check(text.strip_edges().begins_with("10"),
				"%s: strip text starts with 10, not a clipped 0.0 (got `%s`)" % [tag, text])
		if spin != null:
			var sle: LineEdit = spin.get_line_edit()
			if sle != null:
				check(sle.caret_column == 0,
						"%s: strip caret is at the start (column %s)" % [
							tag, str(sle.caret_column)])


func _agree_armed(main, want: float, tag: String) -> void:
	_agree(main, want, tag)
	var panel_le: LineEdit = main.ops_panel._radius_spin.get_line_edit()
	var panel_text := panel_le.text if panel_le != null else ""
	check(_parses_to(panel_text, want),
			"%s: panel text parses to %s (got `%s`)" % [tag, str(want), panel_text])
	var st := _st(main)
	var needle := "r=%.2f" % want
	check(st.contains(needle),
			"%s: status contains %s (got `%s`)" % [tag, needle, st])
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES,
			"%s: Fillet still armed" % tag)


func _vertical_edges(view: DocumentView, body: String) -> Array:
	var out := []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) >= 5.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			out.append(str(id))
	return out


func _select_two_verticals(view: DocumentView, body: String) -> PackedStringArray:
	var verts := _vertical_edges(view, body)
	if verts.size() < 2:
		return PackedStringArray()
	# Opposite corners so R10 on two edges does not consume a 20 mm face.
	var best_a := str(verts[0])
	var best_b := str(verts[1])
	var best_d := -1.0
	for i in verts.size():
		var pa: PackedVector3Array = view.doc.get_edge_lines(body)[verts[i]]
		var ma := (pa[0] + pa[pa.size() - 1]) * 0.5
		for j in range(i + 1, verts.size()):
			var pb: PackedVector3Array = view.doc.get_edge_lines(body)[verts[j]]
			var mb := (pb[0] + pb[pb.size() - 1]) * 0.5
			var d := Vector2(ma.x - mb.x, ma.y - mb.y).length()
			if d > best_d:
				best_d = d
				best_a = str(verts[i])
				best_b = str(verts[j])
	view.select_edge(body, best_a)
	var edges: Array[String] = [best_a, best_b]
	view.selected_edges = edges
	view.selected_edge = best_a
	return PackedStringArray(edges)


func _fillet_params_radius(view: DocumentView, fid: String) -> float:
	for f in view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			return float((parsed as Dictionary).get("radius", -1.0))
	return -1.0


func _last_fillet_fid(view: DocumentView) -> String:
	var fid := ""
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			fid = str(f.get("id", ""))
	return fid


func _push_key(code: int, unicode: int = 0, ctrl := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode if pressed else 0
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _type_text(text: String) -> void:
	for i in text.length():
		var ch := text.substr(i, 1)
		await _push_key(_keycode_for_char(ch), ch.unicode_at(0))


func _keycode_for_char(ch: String) -> Key:
	if ch == ".":
		return KEY_PERIOD
	var c := ch.unicode_at(0)
	if c >= 48 and c <= 57:
		return (KEY_0 + (c - 48)) as Key
	return KEY_NONE


func _focus_select_all(edit: LineEdit) -> void:
	edit.grab_focus()
	await process_frame
	await _push_key(KEY_A, 0, true)
	await process_frame


func _type_into_spin(spin: SpinBox, digits: String) -> void:
	var edit: LineEdit = spin.get_line_edit()
	await _focus_select_all(edit)
	await _type_text(digits)
	await process_frame


func _run() -> void:
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
	var ops = main.ops_panel
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	view.select_entity(body, "")
	await process_frame
	await process_frame

	print("- 1. panel Radius 10 is the strip value (assignment and LineEdit Enter)")
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet is armed")
	var spin := _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "StripRadius is visible while armed")
	ops._radius_spin.value = 10
	await process_frame
	await process_frame
	_observe(main, "after panel.value=10")
	_agree(main, 10.0, "1a assignment")

	var panel_le: LineEdit = ops._radius_spin.get_line_edit()
	await _type_into_spin(ops._radius_spin, "10")
	panel_le.grab_focus()
	await process_frame
	await _push_key(KEY_ENTER)
	await process_frame
	await process_frame
	_observe(main, "after panel LineEdit typed 10 Enter")
	# Do not re-arm before this assert: arm/refresh already copies the panel
	# into the strip. The leftover is that a panel edit while armed (or an
	# Enter that only commits the number) leaves the strip on its last value.
	_agree(main, 10.0, "1b LineEdit Enter")

	print("- 7. L3: type 10 in panel (intermediate 0), Tab; strip, panel, status agree")
	view.select_entity(body, "")
	await process_frame
	if ops._pending != OpsPanel.Pending.FILLET_EDGES:
		ops.arm_or_apply_fillet()
		await process_frame
		await process_frame
	ops.set_dressup_radius(1.0)
	await process_frame
	await process_frame
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "7: Fillet armed at 1")
	_observe(main, "7 armed at 1")
	_agree_armed(main, 1.0, "7 start")
	panel_le = ops._radius_spin.get_line_edit()
	await _focus_select_all(panel_le)
	await _type_text("0")
	await process_frame
	_observe(main, "7 intermediate 0")
	# Walk: strip latched the partial 0 and never caught up. Plant that stale
	# LineEdit so Tab-commit of 10 must overwrite it, not keep 0.0 mm.
	var strip0 := _strip(main)
	if strip0 != null:
		var sle0: LineEdit = strip0.get_line_edit()
		if sle0 != null and not sle0.has_focus():
			sle0.text = "0.0 mm"
	await _focus_select_all(panel_le)
	await _type_text("10")
	await process_frame
	_observe(main, "7 panel typed 10 before Tab")
	panel_le.grab_focus()
	await process_frame
	await _push_key(KEY_TAB)
	await process_frame
	await process_frame
	await process_frame
	_observe(main, "7 after panel Tab")
	_agree_armed(main, 10.0, "7 panel Tab 10")

	print("- 8. L3: type 1.5 in the strip, Tab; strip, panel, status agree")
	if ops._pending != OpsPanel.Pending.FILLET_EDGES:
		view.select_entity(body, "")
		await process_frame
		ops.arm_or_apply_fillet()
		await process_frame
		await process_frame
	spin = _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "8: StripRadius visible")
	await _type_into_spin(spin, "1.5")
	await process_frame
	_observe(main, "8 strip typed 1.5 before Tab")
	await _push_key(KEY_TAB)
	await process_frame
	await process_frame
	await process_frame
	_observe(main, "8 after strip Tab")
	_agree_armed(main, 1.5, "8 strip Tab 1.5")

	print("- 9. L3: type 10 in the strip, Tab; display is 10 not 0.0; KEY_3 is Top")
	if ops._pending != OpsPanel.Pending.FILLET_EDGES:
		view.select_entity(body, "")
		await process_frame
		ops.arm_or_apply_fillet()
		await process_frame
		await process_frame
	ops.set_dressup_radius(1.0)
	await process_frame
	await process_frame
	spin = _strip(main)
	check(spin != null and spin.is_visible_in_tree(), "9: StripRadius visible")
	check(spin.custom_minimum_size.x >= UiScale.px(110) - 0.5,
			"9: strip R is wide enough (got %s, floor %s)" % [
				str(spin.custom_minimum_size.x), str(UiScale.px(110))])
	await _type_into_spin(spin, "10")
	await process_frame
	_observe(main, "9 strip typed 10 before Tab")
	await _push_key(KEY_TAB)
	await process_frame
	await process_frame
	await process_frame
	_observe(main, "9 after strip Tab")
	_agree_armed(main, 10.0, "9 strip Tab 10")
	var focus_owner: Control = root.gui_get_focus_owner()
	var focus_name := "" if focus_owner == null else str(focus_owner.name)
	check(focus_name != "StripJaw10",
			"9: Tab did not land on AF 10 (owner `%s`)" % focus_name)
	check(not (focus_owner is LineEdit),
			"9: Tab did not leave caret in a LineEdit (owner `%s`)" % [
				"null" if focus_owner == null else focus_owner.get_class()])
	var cam: OrbitCamera = main.camera
	var pitch_before := cam.pitch if cam != null else 0.0
	await _push_key(KEY_3, 51)
	await process_frame
	await process_frame
	check(cam != null and absf(cam.pitch - deg_to_rad(89.0)) < 0.05,
			"9: KEY_3 after strip Tab is Top (pitch %s was %s)" % [
				str(cam.pitch) if cam != null else "?", str(pitch_before)])
	check(_st(main).contains("Top view") or absf(cam.pitch - deg_to_rad(89.0)) < 0.05,
			"9: view key reached the camera (status `%s`)" % _st(main))
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES,
			"9: Fillet still armed after KEY_3")
	check(_parses_to(_strip(main).get_line_edit().text, 10.0),
			"9: KEY_3 did not append a digit (strip `%s`)" % _strip(main).get_line_edit().text)

	print("- 2. type 1.5 in the strip; Enter applies 1.50")
	if ops._pending != OpsPanel.Pending.FILLET_EDGES:
		ops.arm_or_apply_fillet()
		await process_frame
		await process_frame
	var picked := _select_two_verticals(view, body)
	check(picked.size() == 2, "two vertical edges selected (got %d)" % picked.size())
	await process_frame
	spin = _strip(main)
	await _type_into_spin(spin, "1.5")
	await process_frame
	await _push_key(KEY_ENTER)
	await process_frame
	await process_frame
	_observe(main, "after strip typed 1.5 Enter")
	check(is_equal_approx(ops.dressup_radius(), 1.5),
			"2: panel Radius is 1.5 after typing in the strip (got %s)" % str(ops.dressup_radius()))
	check(_st(main).contains("1.50 applied"),
			"2: applied status names 1.50 (got `%s`)" % _st(main))

	print("- 3. Esc cancels the pick; re-arm, strip and panel still 1.5")
	view.select_entity(body, "")
	await process_frame
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame
	await _push_key(KEY_ESCAPE)
	await process_frame
	await process_frame
	check(_st(main).contains("Edge pick cancelled"),
			"3: Esc says Edge pick cancelled (got `%s`)" % _st(main))
	view.select_entity(body, "")
	await process_frame
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame
	_observe(main, "after Esc and re-arm")
	_agree(main, 1.5, "3 re-arm")

	print("- 4. Chamfer shares the value; 0.05 and 100 do not diverge")
	if ops._pending != OpsPanel.Pending.NONE:
		ops.cancel_pending_pick()
		await process_frame
	view.select_entity(body, "")
	await process_frame
	ops.arm_or_apply_chamfer()
	await process_frame
	await process_frame
	check(ops._pending == OpsPanel.Pending.CHAMFER_EDGES, "Chamfer is armed")
	_observe(main, "chamfer armed")
	check(is_equal_approx(_strip(main).value, ops.dressup_radius()),
			"4: chamfer strip and panel agree (strip %s panel %s)" % [
				str(_strip(main).value), str(ops.dressup_radius())])
	var strip_le: LineEdit = _strip(main).get_line_edit()
	if strip_le != null and strip_le.has_focus():
		strip_le.release_focus()
		await process_frame
	ops.set_dressup_radius(0.05)
	await process_frame
	await process_frame
	_observe(main, "set_dressup_radius(0.05)")
	_agree(main, 0.05, "4a min 0.05")
	ops.set_dressup_radius(100)
	await process_frame
	await process_frame
	_observe(main, "set_dressup_radius(100)")
	_agree(main, 100.0, "4b max 100")

	print("- 5. panel edit does not overwrite a focused strip; focus-exit syncs")
	if ops._pending != OpsPanel.Pending.NONE:
		ops.cancel_pending_pick()
		await process_frame
	view.select_entity(body, "")
	await process_frame
	ops.set_dressup_radius(3.0)
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame
	spin = _strip(main)
	strip_le = spin.get_line_edit()
	strip_le.grab_focus()
	await process_frame
	var mid_text := "7"
	strip_le.text = mid_text
	strip_le.caret_column = mid_text.length()
	await process_frame
	check(strip_le.has_focus(), "5: strip LineEdit has focus")
	ops._radius_spin.value = 12
	await process_frame
	await process_frame
	_observe(main, "panel set to 12 while strip focused")
	check(strip_le.text == mid_text,
			"5: focused strip text is not overwritten (got `%s`)" % strip_le.text)
	strip_le.release_focus()
	await process_frame
	await process_frame
	_observe(main, "after strip focus-exit")
	_agree(main, 12.0, "5 focus-exit")

	print("- 6. Fillet 2 edges 10.00 applied; strip, panel, timeline radius are 10")
	if ops._pending != OpsPanel.Pending.NONE:
		ops.cancel_pending_pick()
		await process_frame
	var body2: String = view.insert_primitive("box", Vector3(80, 0, 0), Vector3(80, 80, 40))
	await process_frame
	view.select_entity(body2, "")
	await process_frame
	ops.set_dressup_radius(10.0)
	ops.arm_or_apply_fillet()
	await process_frame
	await process_frame
	spin = _strip(main)
	strip_le = spin.get_line_edit()
	if strip_le != null and strip_le.has_focus():
		strip_le.release_focus()
		await process_frame
	picked = _select_two_verticals(view, body2)
	check(picked.size() == 2, "6: two vertical edges on the second box")
	await process_frame
	await _push_key(KEY_ENTER)
	await process_frame
	await process_frame
	_observe(main, "after viewport Enter at 10")
	check(_st(main).contains("Fillet 2 edges 10.00 applied"),
			"6: status is Fillet 2 edges 10.00 applied (got `%s`)" % _st(main))
	check(is_equal_approx(ops.dressup_radius(), 10.0),
			"6: panel still 10 after apply (got %s)" % str(ops.dressup_radius()))
	check(is_equal_approx(_strip(main).value, 10.0),
			"6: strip still 10 after apply (got %s text `%s`)" % [
				str(_strip(main).value), _strip(main).get_line_edit().text])
	var fid := _last_fillet_fid(view)
	var timeline_r := _fillet_params_radius(view, fid)
	check(is_equal_approx(timeline_r, 10.0),
			"6: timeline fillet radius param is 10 (got %s, fid %s)" % [str(timeline_r), fid])

	main.queue_free()
	await process_frame
	await process_frame
