# sx-038 — Timeline clearance under the part chip row, dress-up panel
# hide on disarm, and a Modify column that does not change width.
# Real layout at 1920×1200 and 1280×800 (headless viewport).
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game \
#   --script tests/run_rung01_sx038_chrome.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ChromeDock = preload("res://scripts/chrome_dock.gd")
## Checklist N23 is ≥ 4 px on a 1280×800 frame. A 1920×1200 capture scaled
## to that frame needs ≥ 6 window px; the dock uses a larger fixed gap.
const CHIP_GAP := 6.0

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
	print("rung01 sx038 timeline gap / dress-up panel")
	FilmUI.reset_fail_count()
	await _test_size(Vector2i(1920, 1200), "1920x1200")
	await _test_size(Vector2i(1280, 800), "1280x800")
	await _test_wrap(Vector2i(900, 800))
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_size(win: Vector2i, tag: String) -> void:
	print("- %s layout, dress-up hide, stable Modify width" % tag)
	var ctx := await _boot(win)
	var main = ctx.main
	check(root.size == win, "%s root is %s (got %s)" % [tag, str(win), str(root.size)])
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 24, 12))
	await process_frame
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	main.show_timeline = true
	main._update_panel_visibility()
	for _i in 8:
		await process_frame
	var width_idle := _panel_width(main)
	var stack_idle := _stack_width(main)
	check(not _radius_visible(main), "%s Radius row hidden while Fillet is disarmed" % tag)
	var chip_x := _chip_x(main)
	_assert_timeline_gap(main, tag + " body selected")
	var name_rect := _label_rect(main, "NameLabel")
	check(name_rect.size.x > 2.0, "%s Name label is on screen" % tag)
	_assert_no_label_overlap(main, tag + " idle")

	main.ops_panel.arm_or_apply_fillet()
	for _i in 6:
		await process_frame
	check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "%s Fillet armed" % tag)
	check(_radius_visible(main), "%s Radius row visible while Fillet is armed" % tag)
	check(_radius_label(main) == "Radius", "%s armed label is Radius (got `%s`)" % [tag, _radius_label(main)])
	_assert_width(main, tag + " fillet armed", width_idle, stack_idle)
	_assert_chip_x(main, tag + " fillet armed", chip_x)
	_assert_no_label_overlap(main, tag + " fillet armed")
	_assert_timeline_gap(main, tag + " fillet armed")

	var vp: Viewport = main.get_viewport()
	_release_focus(vp)
	await _push_key(vp, KEY_ESCAPE)
	for _i in 6:
		await process_frame
	var status := str(main.status_label.text)
	check(status.contains("Edge pick cancelled"),
			"%s Esc status is Edge pick cancelled (got `%s`)" % [tag, status])
	check(main.ops_panel._pending == OpsPanel.Pending.NONE, "%s Esc disarms Fillet" % tag)
	check(not _radius_visible(main), "%s Radius row hidden after Esc" % tag)
	_assert_width(main, tag + " after Esc", width_idle, stack_idle)
	_assert_chip_x(main, tag + " after Esc", chip_x)
	_assert_no_label_overlap(main, tag + " after Esc")

	main.ops_panel.arm_or_apply_chamfer()
	for _i in 4:
		await process_frame
	check(_radius_visible(main), "%s Distance row visible while Chamfer is armed" % tag)
	check(_radius_label(main) == "Distance",
			"%s armed label is Distance (got `%s`)" % [tag, _radius_label(main)])
	_assert_width(main, tag + " chamfer armed", width_idle, stack_idle)
	_assert_chip_x(main, tag + " chamfer armed", chip_x)
	_release_focus(vp)
	await _push_key(vp, KEY_ESCAPE)
	for _i in 4:
		await process_frame
	check(not _radius_visible(main), "%s Distance row hidden after Chamfer Esc" % tag)
	_assert_width(main, tag + " chamfer disarmed", width_idle, stack_idle)

	main.ops_panel.arm_or_apply_fillet()
	await process_frame
	var edge := _one_vertical(ctx.view, body)
	check(edge != "", "%s found a vertical edge" % tag)
	if edge != "":
		ctx.view.select_edge(body, edge)
		var edges: Array[String] = [edge]
		ctx.view.selected_edges = edges
		ctx.view.selected_edge = edge
		await process_frame
		# Keep the edge pick; a focused Radius line would swallow Enter.
		ctx.view.selected_edges = edges
		ctx.view.selected_edge = edge
		if main.interaction.has_method("return_viewport_keys"):
			main.interaction.return_viewport_keys()
		await _push_key(vp, KEY_ENTER)
		for _i in 8:
			await process_frame
		var applied := str(main.status_label.text)
		check(applied.contains("Fillet") and applied.contains("applied") \
				and applied.contains("no longer armed"),
				"%s apply status says Fillet is no longer armed (got `%s`)" % [tag, applied])
		check(main.ops_panel._pending == OpsPanel.Pending.NONE, "%s apply disarms Fillet" % tag)
		check(not _radius_visible(main), "%s Radius row hidden after apply" % tag)
		# Apply clears the pick. Reselect the body and confirm Modify did not
		# keep the Radius row or a new column width.
		if ctx.view.doc.body_ids().has(body):
			ctx.view.select_entity(body, "")
			for _j in 6:
				await process_frame
			check(not _radius_visible(main), "%s Radius row stays hidden after reselect" % tag)
			_assert_width(main, tag + " reselect after apply", width_idle, stack_idle)
			_assert_chip_x(main, tag + " reselect after apply", chip_x)
			_assert_timeline_gap(main, tag + " reselect after apply")
	await _shutdown(ctx)


func _test_wrap(win: Vector2i) -> void:
	print("- %s wrapped chip row still clears the Timeline" % str(win))
	var ctx := await _boot(win)
	var main = ctx.main
	var body: String = ctx.view.insert_primitive("box", Vector3.ZERO, Vector3(40, 24, 12))
	await process_frame
	ctx.view.select_entity(body, "")
	await process_frame
	main.show_timeline = true
	main._update_panel_visibility()
	for _i in 8:
		await process_frame
	var rows := _chip_row_count(main)
	print("  wrap rows=%d" % rows)
	check(rows >= 2, "narrow window wraps the chip row onto %d lines" % rows)
	_assert_timeline_gap(main, "wrapped")
	await _shutdown(ctx)


func _chip_row_count(main) -> int:
	var row := _strip_row(main)
	if row == null:
		return 0
	var ys: Array[float] = []
	for child in row.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var y := c.get_global_rect().position.y
		if c.get_global_rect().size.y < 1.0:
			continue
		var known := false
		for prev in ys:
			if absf(prev - y) < 2.0:
				known = true
				break
		if not known:
			ys.append(y)
	return ys.size()


func _assert_timeline_gap(main, tag: String) -> void:
	var timeline: Control = main.timeline
	var vp: Viewport = main.get_viewport()
	var win: Rect2 = vp.get_visible_rect()
	check(timeline != null and timeline.visible, "%s Timeline visible" % tag)
	if timeline == null or not timeline.visible:
		return
	var tr: Rect2 = timeline.get_global_rect()
	var bottom: float = main.interaction.selection_strip_content_bottom()
	var strip: Rect2 = main.interaction.selection_strip_global_rect()
	print("  %s timeline=%s strip=%s content_bottom=%.1f gap=%.1f" % [
		tag, str(tr), str(strip), bottom, tr.position.y - bottom])
	check(bottom >= 0.0 and strip.size != Vector2.ZERO, "%s chip row is visible" % tag)
	check(tr.position.y + 0.5 >= bottom + CHIP_GAP,
			"%s Timeline top ≥ chip-row bottom + %.0f (y=%.1f bottom=%.1f)" % [
				tag, CHIP_GAP, tr.position.y, bottom])
	check(not tr.intersects(strip), "%s Timeline does not intersect the chip row" % tag)
	check(_inside(win, tr) and _inside(win, strip),
			"%s Timeline and chip row are inside the window" % tag)
	var row := _strip_row(main)
	if row == null:
		check(false, "%s chip row container exists" % tag)
		return
	var lowest := strip.position.y
	for child in row.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var cr := c.get_global_rect()
		if cr.size.y < 1.0:
			continue
		lowest = maxf(lowest, cr.end.y)
		check(not tr.intersects(cr),
				"%s chip %s is clear of the Timeline" % [tag, c.name])
		check(tr.position.y + 0.5 >= cr.end.y + CHIP_GAP,
				"%s Timeline clears %s by ≥ %.0f (y=%.1f chip_end=%.1f)" % [
					tag, c.name, CHIP_GAP, tr.position.y, cr.end.y])
	check(bottom + 0.5 >= lowest,
			"%s content bottom includes the lowest chip (bottom=%.1f chip=%.1f)" % [
				tag, bottom, lowest])


func _assert_width(main, tag: String, width_idle: float, stack_idle: float) -> void:
	var w := _panel_width(main)
	var s := _stack_width(main)
	print("  %s modify_w=%.1f stack_w=%.1f (idle %.1f / %.1f)" % [tag, w, s, width_idle, stack_idle])
	check(absf(w - width_idle) <= 0.5,
			"%s Modify width stable (now %.1f idle %.1f)" % [tag, w, width_idle])
	check(absf(s - stack_idle) <= 0.5,
			"%s left stack width stable (now %.1f idle %.1f)" % [tag, s, stack_idle])


func _assert_chip_x(main, tag: String, chip_x: float) -> void:
	var x := _chip_x(main)
	check(absf(x - chip_x) <= 1.0, "%s chip row x unchanged (now %.1f was %.1f)" % [tag, x, chip_x])


func _assert_no_label_overlap(main, tag: String) -> void:
	var ops: Control = main.ops_panel
	if ops == null:
		check(false, "%s Modify panel exists" % tag)
		return
	var labels: Array[Control] = []
	_collect_visible_labels(ops, labels)
	var hit := false
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			var a := labels[i].get_global_rect()
			var b := labels[j].get_global_rect()
			if a.size.x < 1.0 or b.size.x < 1.0:
				continue
			var overlap := a.intersection(b)
			if overlap.size.x > 1.0 and overlap.size.y > 1.0:
				hit = true
				printerr("  FAIL - %s labels overlap %s `%s` and %s `%s`" % [
					tag, labels[i].name, _ctrl_text(labels[i]),
					labels[j].name, _ctrl_text(labels[j])])
				failures += 1
				checks += 1
	if not hit:
		checks += 1
		print("  ok   - %s Modify labels do not overlap (%d labels)" % [tag, labels.size()])


func _collect_visible_labels(n: Node, out: Array[Control]) -> void:
	for child in n.get_children():
		var c := child as Control
		if c != null and c.visible and c is Label and c.is_visible_in_tree():
			out.append(c)
		if child.get_child_count() > 0:
			_collect_visible_labels(child, out)


func _ctrl_text(c: Control) -> String:
	if c is Label:
		return str((c as Label).text)
	return ""


func _panel_width(main) -> float:
	if main.ops_panel == null:
		return -1.0
	return main.ops_panel.get_global_rect().size.x


func _stack_width(main) -> float:
	if main.left_stack == null:
		return -1.0
	return main.left_stack.get_global_rect().size.x


func _chip_x(main) -> float:
	var strip: Rect2 = main.interaction.selection_strip_global_rect()
	return strip.position.x


func _radius_visible(main) -> bool:
	var row := main.ops_panel.find_child("DressupRadiusRow", true, false) as Control
	return row != null and row.is_visible_in_tree()


func _radius_label(main) -> String:
	var lbl := main.ops_panel.find_child("DressupRadiusLabel", true, false) as Label
	return "" if lbl == null else str(lbl.text)


func _label_rect(main, node_name: String) -> Rect2:
	var lbl := main.ops_panel.find_child(node_name, true, false) as Control
	if lbl == null or not lbl.is_visible_in_tree():
		return Rect2()
	return lbl.get_global_rect()


func _strip_row(main) -> Container:
	var strip: Control = main.interaction._selection_strip
	if strip == null:
		return null
	for child in strip.get_children():
		if child is Container:
			return child
	return null


func _one_vertical(view: DocumentView, body: String) -> String:
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) >= 8.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			return str(id)
	return ""


func _inside(window: Rect2, inner: Rect2) -> bool:
	if inner.size.x < 2.0 or inner.size.y < 2.0:
		return false
	return window.has_point(inner.position) and window.has_point(inner.end - Vector2(1, 1))


func _boot(win: Vector2i) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, win)
	return ctx


func _shutdown(ctx: FilmContext) -> void:
	if ctx.main != null and is_instance_valid(ctx.main):
		ctx.main.queue_free()
	await process_frame
	await process_frame


func _release_focus(vp: Viewport) -> void:
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _push_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	down.echo = false
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	up.echo = false
	vp.push_input(up)
	await process_frame
