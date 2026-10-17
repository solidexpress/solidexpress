## The kernel-built UBC pipe the rung-5 suites share.
## Boot, PART millimetres, mirrored / reshelled builders. Each suite keeps its checks.
class_name PipeFixture
extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxInput = preload("res://tests/lib/sx_input.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")

static var _part: Dictionary = {}


static func part() -> Dictionary:
	if not _part.is_empty():
		return _part
	var result := SxChecker.run("rung05", ["params"])
	var parsed = JSON.parse_string(str(result["text"]))
	if typeof(parsed) == TYPE_DICTIONARY:
		_part = parsed
	return _part


static func mm(key: String) -> float:
	var table: Variant = part().get("PART", {})
	if typeof(table) != TYPE_DICTIONARY:
		return 0.0
	return float(table.get(key, 0.0))


static func boot(tree: SceneTree, viewport: Vector2i, on_status: Callable = Callable(),
		sources: Array = []) -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = tree
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, viewport)
	if on_status.is_valid():
		for source in sources:
			var node: Node = main.get(str(source))
			if node != null and node.has_signal("status") and not node.status.is_connected(on_status):
				node.status.connect(on_status)
	return ctx


static func find_auto(node: Node, id: String) -> Node:
	if node == null:
		return null
	if str(node.get_meta("sx_auto", "")) == id:
		return node
	for c in node.get_children():
		var hit := find_auto(c, id)
		if hit != null:
			return hit
	return null


static func output_body(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("output_body", ""))
	return ""


static func z_faces(doc: SxDocument, body: String) -> PackedStringArray:
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


static func planar_at_z(doc: SxDocument, body: String, z: float) -> PackedStringArray:
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


static func build_mirrored(doc: SxDocument) -> String:
	var od_r := mm("OD") * 0.5
	var id_r := mm("ID") * 0.5
	var l0 := mm("L0")
	var wall := mm("WALL")
	var flange_r := mm("FLANGE_D") * 0.5
	var flange_t := mm("FLANGE_T")
	var pcd := mm("PCD")
	var hole_r := mm("HOLE_D") * 0.5
	var n_holes := int(mm("N_HOLES"))
	var sk := SxSketch.new()
	sk.add_circle(0, 0, od_r)
	var sk_fid := doc.graph_add_sketch(sk)
	if sk_fid == "":
		return ""
	var ext := doc.graph_add_extrude(sk_fid, l0, false, "new", "")
	if ext == "":
		return ""
	var body := output_body(doc, ext)
	var ends := z_faces(doc, body)
	if ends.size() != 2:
		return ""
	var sh := doc.graph_add_shell(ext, ends, wall)
	if sh == "":
		return ""
	var fl_sk := SxSketch.new()
	fl_sk.set_plane(Vector3(0, 0, l0), Vector3(1, 0, 0), Vector3(0, 1, 0))
	fl_sk.add_circle(0, 0, flange_r)
	var fl_sk_fid := doc.graph_add_sketch(fl_sk)
	var flange := doc.graph_add_extrude(fl_sk_fid, flange_t, false, "fuse", ext)
	if flange == "":
		return ""
	var cut_sk := SxSketch.new()
	cut_sk.set_plane(Vector3(0, 0, l0 + flange_t), Vector3(1, 0, 0), Vector3(0, 1, 0))
	cut_sk.add_circle(0, 0, id_r)
	for k in n_holes:
		var ang := float(k) * TAU / float(n_holes)
		cut_sk.add_circle(pcd * sin(ang), pcd * cos(ang), hole_r)
	var cut_sk_fid := doc.graph_add_sketch(cut_sk)
	var cut := doc.graph_add_extrude(cut_sk_fid, -flange_t, false, "cut", ext)
	if cut == "":
		return ""
	var sources := PackedStringArray([ext, sh, flange, cut])
	var mir := doc.graph_add_mirror(ext, Vector3.ZERO, Vector3(0, 0, 1), sources)
	if mir == "":
		return ""
	return ext


static func build_reshelled(doc: SxDocument) -> String:
	var ext := build_mirrored(doc)
	if ext == "":
		return ""
	var body := output_body(doc, ext)
	var remove := PackedStringArray()
	remove.append_array(planar_at_z(doc, body, -mm("L0") - mm("FLANGE_T")))
	remove.append_array(planar_at_z(doc, body, 0.0))
	if remove.is_empty():
		return ""
	var sh := doc.graph_add_shell(ext, remove, mm("WALL"))
	if sh == "":
		return ""
	return ext


static func click_front(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await ctx.tree.process_frame
	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
	if not await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch()):
		return
	await ctx.tree.process_frame
	var pt: Vector3 = OriginPlanes.pick_point("Front")
	var screen := FilmUI.model_to_screen(ctx, pt)
	if not FilmUI.require_on_screen(ctx, screen, "Front"):
		return
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click("Front"))
	await FilmUI.wait_frames(ctx.tree, 4)


static func extrude_blind(ctx: FilmContext, distance: String, op: int) -> void:
	await FilmSteps.pick_finish(ctx, op, 0)
	if FilmUI.fail_count > 0:
		return
	if distance != "":
		await FilmSteps.type_distance(ctx, distance)
		await SxInput.push_key(ctx.main.get_viewport(), KEY_ENTER)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var ex: Button = chrome.extrude_button() if chrome != null else null
	if not await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Extrude")):
		return
	await ctx.after_regen()
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)


static func dim_diameter(ctx: FilmContext, rim: Vector2, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, rim, "Ø%s rim" % text, 280.0)
	await _type_last_label(ctx, text)


static func _type_last_label(ctx: FilmContext, text: String) -> void:
	await FilmUI.wait_frames(ctx.tree, 3)
	var sm: SketchMode = ctx.main.sketch_mode
	var rects: Array = sm.dimension_label_screen_rects() if sm != null else []
	var hit: Dictionary = {}
	for i in range(rects.size() - 1, -1, -1):
		var row: Dictionary = rects[i]
		if not str(row.get("text", "")).ends_with("°"):
			hit = row
			break
	if hit.is_empty():
		FilmUI._fail("no dimension label to set %s" % text)
		return
	var center: Vector2 = (hit["rect"] as Rect2).get_center()
	if not FilmUI.require_on_screen(ctx, center, "dimension %s" % text):
		return
	await FilmUI.viewport_click(ctx, center, FilmUICues.alert("Click", "Dimension %s" % text))
	await FilmUI.wait_frames(ctx.tree, 4)
	var line := ctx.main.find_child("DimEditLine", true, false) as LineEdit
	if line == null or not line.is_visible_in_tree():
		FilmUI._fail("dimension editor did not open for %s" % text)
		return
	await SxInput.x11_click(line)
	line.select_all()
	await SxInput.type_text(line.get_viewport(), text)
	await SxInput.push_key(line.get_viewport(), KEY_ENTER)
	await FilmUI.wait_frames(ctx.tree, 3)


static func dim_distance(ctx: FilmContext, a: Vector2, b: Vector2, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(40, 40), "Clear selection", 220.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, a, "Dim first", 220.0)
	await FilmSteps.click_uv(ctx, b, "Dim second", 220.0)
	await _type_last_label(ctx, text)


static func vertical_centres(ctx: FilmContext, a: Vector2, b: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(40, 40), "Clear selection", 220.0)
	await FilmSteps.click_uv(ctx, a, "First centre", 160.0)
	await FilmSteps.click_uv(ctx, b, "Second centre", 160.0)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var btn := FilmUI.find_button(chrome, "Vertical")
	if btn != null and btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, btn, FilmUICues.alert("Vertical", "Vertical"))
		return
	var more := FilmUI.find_button(chrome, "… More")
	if more is MenuButton:
		var popup := (more as MenuButton).get_popup()
		for i in popup.item_count:
			if popup.get_item_text(i) == "Vertical":
				await FilmUI.activate_menu_id(ctx, more as MenuButton, popup.get_item_id(i),
						FilmUICues.alert("Vertical", "Vertical"))
				return
	FilmUI._fail("Vertical is hidden")


static func select_seed(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var pcd := mm("PCD")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmSteps.click_uv(ctx, Vector2(40, 40), "Clear selection", 220.0)
	await FilmSteps.click_uv(ctx, Vector2(0, pcd), "Ø10 seed", 160.0)


static func show_timeline(ctx: FilmContext) -> void:
	if ctx.main.timeline != null and ctx.main.timeline.visible:
		return
	var view_btn := FilmUI.find_button(ctx.main, "View") as MenuButton
	if view_btn == null or not view_btn.is_visible_in_tree():
		FilmUI._fail("View menu is hidden")
		return
	await FilmUI.activate_menu_id(ctx, view_btn, 4, FilmUICues.alert("View", "Timeline"))
	await FilmUI.wait_frames(ctx.tree, 4)
	if ctx.main.timeline == null or not ctx.main.timeline.visible:
		FilmUI._fail("Timeline is hidden")


static func source_names(doc: SxDocument) -> Array:
	var extrudes: Array = []
	var shells: Array = []
	for f in doc.graph_features():
		var t := str(f.get("type", ""))
		var n := str(f.get("name", ""))
		if t == "extrude":
			extrudes.append(n)
		elif t == "shell":
			shells.append(n)
	var names: Array = []
	if extrudes.size() >= 1:
		names.append(extrudes[0])
	if shells.size() >= 1:
		names.append(shells[0])
	if extrudes.size() >= 2:
		names.append(extrudes[1])
	if extrudes.size() >= 3:
		names.append(extrudes[2])
	return names
