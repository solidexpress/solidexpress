# Rung 7 WP5 — boss + neck: named-tool Front sketch, Mid Plane 10 / 6, R30/R20.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung07_boss.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")


func _init() -> void:
	print("rung07 boss + neck")
	FilmUI.reset_fail_count()
	var ctx := await SpannerFixture.boot(self, Vector2i(1280, 800))
	listen_status(ctx.main)
	status_echo = true
	await _case(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _case(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	var _warm := SpannerFixture.mm("HEAD_T")
	await _zoom(ctx, Vector3(120, 0, 0), 320.0)
	await _sketch_c(ctx)
	print("  sketched C")
	await _sketch_ring(ctx)
	print("  sketched ring")
	await _sketch_handle(ctx)
	print("  sketched handle")
	var dumped := SpannerFixture.dump_contours(sm)
	print("  contours: %s" % dumped)
	check(sm.sketch.contour_count() == 3, "three closed regions (got %d) %s" % [
			sm.sketch.contour_count(), dumped])
	var c_idx := SpannerFixture.contour_by_area(sm, SpannerFixture.mm("A_C"), 20.0)
	var disc_idx := SpannerFixture.contour_by_area(sm,
			PI * pow(SpannerFixture.mm("RING_D") * 0.5, 2.0), 40.0)
	var handle_idx := SpannerFixture.contour_by_area(sm, SpannerFixture.mm("A_H"), 20.0)
	check(c_idx >= 0, "C contour ~1496 (got %d) %s" % [c_idx, dumped])
	check(disc_idx >= 0 and disc_idx != c_idx, "Ø33 disc (got %d) %s" % [disc_idx, dumped])
	check(handle_idx >= 0 and handle_idx != c_idx and handle_idx != disc_idx,
			"handle contour ~3999 (got %d) %s" % [handle_idx, dumped])
	if c_idx < 0 or disc_idx < 0 or handle_idx < 0:
		return
	print("  heads contours: %s" % dumped)
	sm.finish_extrude(SpannerFixture.mm("HEAD_T"), "new", "midplane", 0.0, "one_side", false,
			[c_idx, disc_idx])
	for _i in 12:
		await process_frame
	check(not sm.active, "heads extrude closed the sketch")
	check(ctx.view.doc.body_ids().size() >= 1, "body after heads (got %d)" % ctx.view.doc.body_ids().size())
	var heads_vol := -1.0
	if ctx.view.doc.body_ids().size() == 1:
		heads_vol = float(ctx.view.doc.measure_mass(str(ctx.view.doc.body_ids()[0])).get("volume", -1.0))
	print("  heads volume %.1f  last=%s" % [heads_vol, _last_status()])
	if sm.active:
		return
	var sk_fid := SpannerFixture.first_sketch(ctx.view.doc)
	check(sk_fid != "", "Sketch1 in the graph")
	check(sm.begin_edit(sk_fid), "pencil reopens Sketch1")
	await process_frame
	sm = ctx.main.sketch_mode
	dumped = SpannerFixture.dump_contours(sm)
	print("  reopened contours: %s" % dumped)
	handle_idx = SpannerFixture.contour_by_area(sm, SpannerFixture.mm("A_H"), 40.0)
	check(handle_idx >= 0, "handle contour after reopen (got %d) %s" % [handle_idx, dumped])
	if handle_idx < 0:
		return
	sm.finish_extrude(SpannerFixture.mm("HANDLE_T"), "fuse", "midplane", 0.0, "one_side", false,
			[handle_idx])
	for _i in 16:
		await process_frame
	check(not sm.active, "handle extrude closed the sketch")
	check(ctx.view.doc.body_ids().size() == 1, "one body after merge (got %d)" % ctx.view.doc.body_ids().size())
	print("  fused last=%s" % _last_status())
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active, "Front sketch for 12-point cut")
	SpannerFixture.add_twelve_point(sm, Vector2(SpannerFixture.mm("CENTER"), 0.0),
			SpannerFixture.mm("HEX_AF"))
	await process_frame
	sm.finish_extrude(SpannerFixture.mm("HEAD_T"), "cut", "midplane")
	for _i in 12:
		await process_frame
	check(not sm.active, "12-point cut closed the sketch")
	check(ctx.view.doc.body_ids().size() == 1, "one body after 12-point cut")
	var boss_path := ProjectSettings.globalize_path("user://rung07_boss.3mf")
	check(ctx.view.doc.export_3mf(boss_path), "export boss.3mf")
	var boss := SxChecker.run("rung07", ["boss", boss_path])
	check(int(boss["code"]) == 0, "check_rung07.py boss exit 0\n%s" % str(boss["text"]))
	if int(boss["code"]) != 0:
		return
	var body := SpannerFixture.only_body(ctx)
	var host := ctx.view.feature_of_body(body)
	check(host != "", "feature of the fused body")
	var open_xy := [_handle_hit(true), _handle_hit(false)]
	var box_xy := [Vector2(226.876, 10.0), Vector2(226.876, -10.0)]
	var r30 := _collect_edges(ctx.view.doc, body, open_xy, SpannerFixture.mm("HANDLE_T"))
	check(r30.size() >= 2, "open-end neck Z-edges (got %d)" % r30.size())
	var f30 := ctx.view.doc.graph_add_fillet(host, r30, SpannerFixture.mm("R30"))
	check(f30 != "", "Fillet R30")
	await process_frame
	body = SpannerFixture.only_body(ctx)
	host = ctx.view.feature_of_body(body)
	var r20 := _collect_edges(ctx.view.doc, body, box_xy, SpannerFixture.mm("HANDLE_T"))
	check(r20.size() >= 2, "box-end neck Z-edges (got %d)" % r20.size())
	var f20 := ctx.view.doc.graph_add_fillet(host, r20, SpannerFixture.mm("R20"))
	check(f20 != "", "Fillet R20")
	for _i in 8:
		await process_frame
	check(ctx.view.doc.body_ids().size() == 1, "one body after neck fillets")
	var neck_path := ProjectSettings.globalize_path("user://rung07_neck.3mf")
	check(ctx.view.doc.export_3mf(neck_path), "export neck.3mf")
	var neck := SxChecker.run("rung07", ["neck", neck_path])
	check(int(neck["code"]) == 0, "check_rung07.py neck exit 0\n%s" % str(neck["text"]))


func _sketch_c(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var xj := SpannerFixture.x_jaw()
	var off := SpannerFixture.mm("JAW_OFF")
	var jlen := SpannerFixture.mm("JAW_LEN")
	var r15 := SpannerFixture.mm("R15")
	var o_hi := SpannerFixture.world(xj, off)
	var o_lo := SpannerFixture.world(xj, -off)
	var i_hi := SpannerFixture.world(xj + jlen, off)
	var i_lo := SpannerFixture.world(xj + jlen, -off)
	var cx_local := (xj + jlen) - sqrt(r15 * r15 - off * off)
	var throat := SpannerFixture.world(cx_local + r15, 0.0)
	var pick := SpannerFixture.world(-24.73, 4.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.ELLIPSE)
	await SpannerFixture.click(ctx, Vector2.ZERO, "Ellipse centre")
	await SpannerFixture.click(ctx, SpannerFixture.world(0.0, SpannerFixture.mm("ELLIPSE_MAJ") * 0.5),
			"Ellipse major")
	await SpannerFixture.click(ctx, SpannerFixture.world(SpannerFixture.mm("ELLIPSE_MIN") * 0.5, 0.0),
			"Ellipse minor")
	await process_frame
	await FilmSteps.press_rail(ctx, "Line")
	if FilmUI.fail_count == 0:
		await FilmSteps.pick_variant(ctx, "Centerline")
	await SpannerFixture.click(ctx, Vector2(-40, 0), "CL start")
	await SpannerFixture.click(ctx, Vector2(80, 0), "CL +X")
	await FilmUI.end_line_chain(ctx)
	await FilmSteps.press_rail(ctx, "Line")
	if FilmUI.fail_count == 0:
		await FilmSteps.pick_variant(ctx, "Centerline")
	await SpannerFixture.click(ctx, Vector2.ZERO, "17° origin")
	await SpannerFixture.click(ctx, SpannerFixture.world(40.0, 0.0), "17° handle")
	await FilmUI.end_line_chain(ctx)
	await FilmSteps._snap_off_if_visible(ctx)
	await SpannerFixture.line(ctx, o_hi, i_hi, "upper jaw")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await SpannerFixture.click(ctx, SpannerFixture.world(20.0, 0.0), "17° axis")
	await SpannerFixture.shift_click_uv(ctx, (o_hi + i_hi) * 0.5, "jaw")
	await SpannerFixture.confirm_mirror(ctx, Vector2(5, 8))
	await process_frame
	await FilmSteps.three_point_arc(ctx, i_lo, throat, i_hi, 0.0)
	await process_frame
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	await SpannerFixture.click(ctx, pick, "Trim opening")
	await process_frame
	check(_count_type(sm, "ellipse") == 0, "no full ellipse left")
	check(_count_type(sm, "elliptical_arc") == 1, "C is an elliptical arc")


func _sketch_ring(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var ctr := Vector2(SpannerFixture.mm("CENTER"), 0.0)
	var rad := SpannerFixture.mm("RING_D") * 0.5
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await SpannerFixture.click(ctx, ctr, "Ø33 centre")
	await SpannerFixture.click(ctx, ctr + Vector2(rad, 0.0), "Ø33 rim")
	await process_frame


func _sketch_handle(ctx: FilmContext) -> void:
	var hi := _handle_hit(true)
	var circ := Vector2(226.876, SpannerFixture.mm("HANDLE_HALF"))
	await SpannerFixture.line(ctx, hi, circ, "handle")
	var lo := _handle_hit(false)
	var circ_lo := Vector2(226.876, -SpannerFixture.mm("HANDLE_HALF"))
	await SpannerFixture.line(ctx, lo, circ_lo, "handle copy")
	await process_frame


func _last_status() -> String:
	if status_log.is_empty():
		return ""
	return str(status_log[status_log.size() - 1])


func _handle_hit(upper: bool) -> Vector2:
	if upper:
		return Vector2(22.944, SpannerFixture.mm("HANDLE_HALF"))
	return Vector2(23.929, -SpannerFixture.mm("HANDLE_HALF"))


func _collect_edges(doc: SxDocument, body: String, xys: Array, want_len: float) -> PackedStringArray:
	var seen := {}
	var out: PackedStringArray = PackedStringArray()
	for xy in xys:
		for eid in SpannerFixture.z_edges_near(doc, body, xy, want_len):
			if seen.has(eid):
				continue
			seen[eid] = true
			out.append(eid)
	return out


func _count_type(sm: SketchMode, kind: String) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		if str(sm.sketch.entity_info(id).get("type", "")) == kind:
			n += 1
	return n
