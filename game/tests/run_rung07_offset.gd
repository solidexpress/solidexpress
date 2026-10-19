# Rung 7 WP6 — Convert circular arcs + Offset Arc, Cut Blind 1.
# Stub racetrack (two lines + two R30 arcs), then named Convert / Offset / Cut.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung07_offset.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SpannerFixture = preload("res://tests/lib/spanner_fixture.gd")

const HALF := 30.0
const SPAN := 180.0


func _init() -> void:
	print("rung07 offset")
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
	_add_racetrack(sm)
	await process_frame
	sm.finish_extrude(SpannerFixture.mm("HANDLE_T"), "new", "midplane")
	for _i in 12:
		await process_frame
	check(not sm.active, "racetrack extruded")
	check(ctx.view.doc.body_ids().size() == 1, "one body after pad")
	var body := SpannerFixture.only_body(ctx)
	var z_top := SpannerFixture.mm("HANDLE_T") * 0.5
	var face := SpannerFixture.face_by_normal(ctx.view, body, Vector3(0, 0, 1), z_top)
	check(face != "", "handle-top face at z=%.1f" % z_top)
	if face == "":
		return
	await FilmUI.enter_sketch_on_face(ctx, body, face)
	sm = ctx.main.sketch_mode
	check(sm.active, "face sketch is active")
	await _zoom(ctx, Vector3(SPAN * 0.5, 0.0, z_top), 280.0)
	var mark := status_log.size()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	for uv in _edge_uvs(sm):
		await SpannerFixture.click(ctx, uv, "Convert edge")
		await process_frame
	var converted := _converted(sm)
	print("  convert status: %s" % _since(mark))
	print("  converted: %s" % converted)
	check(_since(mark).contains("Convert: external arc"), "Convert names an arc")
	check(int(converted.get("line", 0)) >= 2, "two converted lines (got %s)" % str(converted))
	check(int(converted.get("arc", 0)) >= 2, "two converted arcs (got %s)" % str(converted))
	var ids := _kind_ids(sm, ["line", "arc"])
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.OFFSET)
	var dist: SpinBox = ctx.main.find_child("OffsetDistance", true, false)
	var rev: CheckButton = ctx.main.find_child("OffsetReverse", true, false)
	check(dist != null and rev != null, "offset Distance / Reverse exist")
	if dist == null:
		return
	dist.value = 0.0
	var before := sm.sketch.entity_ids().size()
	mark = status_log.size()
	await SpannerFixture.click(ctx, _edge_uvs(sm)[0], "Offset 0")
	check(sm.sketch.entity_ids().size() == before, "offset 0 adds nothing")
	check(_since(mark).contains("distance must be greater than 0"),
			"offset 0 refused (got '%s')" % _since(mark))
	dist.value = SpannerFixture.mm("OFFSET")
	if rev != null and not rev.button_pressed:
		await FilmUI.click_control(ctx, rev, FilmUICues.alert("Reverse", "inward"))
	check(rev != null and rev.button_pressed, "Reverse is on")
	sm.selected.clear()
	for id in ids:
		sm.selected.append(id)
	mark = status_log.size()
	await SpannerFixture.click(ctx, _edge_uvs(sm)[0], "Offset chain")
	await process_frame
	print("  offset status: %s" % _since(mark))
	var dumped := SpannerFixture.dump_contours(sm)
	print("  contours: %s" % dumped)
	check(sm.sketch.contour_count() >= 1, "offset closed a region %s" % dumped)
	var area := _largest_area(sm)
	print("  offset area %.1f" % area)
	check(area > 100.0, "offset region has area (got %.1f)" % area)
	sm.finish_extrude(SpannerFixture.mm("CUT_D"), "cut", "blind")
	for _i in 12:
		await process_frame
	check(not sm.active, "cut closed the sketch")
	check(ctx.view.doc.body_ids().size() == 1, "one body after cut (got %d)" %
			ctx.view.doc.body_ids().size())


func _add_racetrack(sm: SketchMode) -> void:
	var x1 := SPAN
	sm.sketch.add_line(0.0, HALF, x1, HALF)
	sm.sketch.add_line(x1, -HALF, 0.0, -HALF)
	sm.sketch.add_arc(0.0, 0.0, HALF, PI * 0.5, PI * 1.5)
	sm.sketch.add_arc(x1, 0.0, HALF, -PI * 0.5, PI * 0.5)


func _edge_uvs(sm: SketchMode) -> Array[Vector2]:
	var z := SpannerFixture.mm("HANDLE_T") * 0.5
	var worlds: Array[Vector3] = [
		Vector3(SPAN * 0.5, HALF, z),
		Vector3(SPAN + HALF, 0.0, z),
		Vector3(SPAN * 0.5, -HALF, z),
		Vector3(-HALF, 0.0, z),
	]
	var out: Array[Vector2] = []
	for p in worlds:
		if sm.plane != null:
			out.append(sm.plane.to_uv(p))
		else:
			out.append(Vector2(p.x, p.y))
	return out


func _converted(sm: SketchMode) -> Dictionary:
	var out := {"line": 0, "arc": 0, "circle": 0}
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_external(id):
			continue
		var kind := str(sm.sketch.entity_info(id).get("type", ""))
		out[kind] = int(out.get(kind, 0)) + 1
	return out


func _kind_ids(sm: SketchMode, kinds: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) in kinds:
			out.append(str(id))
	return out


func _largest_area(sm: SketchMode) -> float:
	var best := 0.0
	if sm.sketch == null or not sm.sketch.has_method("contour_outlines"):
		return best
	for row in sm.sketch.contour_outlines():
		best = maxf(best, absf(float(row.get("area", 0.0))))
	return best


func _since(mark: int) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for i in range(mark, status_log.size()):
		bits.append(str(status_log[i]))
	return " | ".join(bits)
