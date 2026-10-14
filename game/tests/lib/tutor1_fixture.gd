## The click-built Tutor1 boss the rung-3 suites share.
## Boot, the centre-rect boss, and the face helpers. Each suite keeps its own checks.
class_name Tutor1Fixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")


static func note(log: Array, text: String) -> void:
	if text == "":
		return
	log.append(text)
	print("  status: " + text)


static func status_since(log: Array, mark: int) -> String:
	if mark >= log.size():
		return ""
	return " | ".join(log.slice(mark))


static func boot(tree: SceneTree, viewport: Vector2i, on_status: Callable, sources: Array) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = tree
	await FilmUI.ensure_test_viewport(ctx, viewport)
	for source in sources:
		var node: Node = main.get(str(source))
		if node != null and node.has_signal("status"):
			node.status.connect(on_status)
	return ctx


static func only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


static func volume(ctx: FilmContext) -> float:
	var body := only_body(ctx)
	if body == "":
		return -1.0
	return float(ctx.view.doc.measure_mass(body).get("volume", -1.0))


static func face_at_z(ctx: FilmContext, body: String, z: float) -> String:
	var best := ""
	var best_gap := 1.0
	var want := Vector3(0, 0, 1)
	for face_id in ctx.view.doc.get_face_ids(body):
		var fid := str(face_id)
		var n: Vector3 = ctx.view.face_normal(body, fid)
		if n.length_squared() < 1e-8 or n.normalized().dot(want) < 0.99:
			continue
		var off := FacePick.plane_offset(n, FacePick.point(ctx.view.doc, fid))
		var gap := absf(off - z)
		if gap < best_gap:
			best_gap = gap
			best = fid
	return best


static func click_model(suite: Object, ctx: FilmContext, model: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, model)
	suite.check(FilmUI.require_on_screen(ctx, screen, desc), "%s is on screen" % desc)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))
	await ctx.tree.process_frame


static func build_boss(suite: Object, ctx: FilmContext, after_plate: Callable = Callable()) -> bool:
	var part := _part()
	var half := float(part["SIDE"]) * 0.5
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	suite.check(sm != null and sm.active, "ground sketch is open")
	if sm == null or not sm.active:
		return false
	await suite._zoom(ctx, Vector3.ZERO, 280.0)
	if not await _arm_center(suite, ctx):
		return false
	await suite._click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await suite._click_uv(ctx, ctx.main.get_viewport(), Vector2(half, half))
	await ctx.tree.process_frame
	if not await suite._extrude(ctx, str(int(part["H0"])), 0):
		return false
	if after_plate.is_valid() and not await after_plate.call(ctx):
		return false
	if not await suite._open_z_face(ctx, float(part["H0"])):
		return false
	sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	var radius := float(part["BOSS_D"]) * 0.5
	await suite._click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await suite._click_uv(ctx, ctx.main.get_viewport(), Vector2(radius, 0))
	await ctx.tree.process_frame
	if not await suite._extrude(ctx, str(int(part["BOSS_H"])), 2):
		return false
	var boss := volume(ctx)
	print("  boss volume %s" % str(boss))
	var want := float(_volumes()["boss"])
	suite.check(absf(boss - want) < 5.0, "boss volume 528211 (got %s)" % str(boss))
	return absf(boss - want) < 5.0


static func _arm_center(suite: Object, ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	var chip: Button = null
	if bar != null:
		for c in bar.get_children():
			var b := c as Button
			if b != null and b.text == "Center":
				chip = b
	suite.check(chip != null and chip.is_visible_in_tree(), "Center variant chip is visible")
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center", "Center")):
		return false
	return sm.tool_variant == "center"


static func _params() -> Dictionary:
	var result: Dictionary = SxChecker.run("rung03", ["params"])
	var parsed: Variant = JSON.parse_string(str(result.get("text", "")))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _part() -> Dictionary:
	return _params().get("PART", {})


static func _volumes() -> Dictionary:
	return _params().get("VOLUMES", {})
