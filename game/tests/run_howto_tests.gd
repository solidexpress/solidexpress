# Headless tests that mirror docs/howto/*.md steps and assert the goals.
# Run: tools/godot/godot --headless --path game --script tests/run_howto_tests.gd
extends SceneTree

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
	print("howto goal tests (mirrors docs/howto/)")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await howto_place_and_orbit(main)
	await howto_stack_three_blocks(main)
	await howto_extrude_s_shape(main)
	await howto_extrude_letter_a(main)
	await howto_horizontal_hole(main)
	await howto_landing_bindings(main)
	await howto_rib_follows_sketch(main)
	await howto_flange_unfolds(main)
	await howto_print_thin_wall(main)
	await howto_print_overhang_orient(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _center(ix: ViewportInteraction) -> Vector2:
	return ix._screen_center()


func _lmb(ix: ViewportInteraction, pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	ix._input(mb)


## docs/howto/place-and-orbit.md
func howto_place_and_orbit(main) -> void:
	print("- howto_place_and_orbit")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	var cam: OrbitCamera = main.camera
	view.new_document()

	# 1. Click Box on palette → arms place
	ix.insert_at_center("box")
	check(ix._place_kind == "box", "place armed")
	# 2. Move then click viewport ground → insert (via _input path)
	var center := _center(ix)
	var mm_move := InputEventMouseMotion.new()
	mm_move.position = center
	ix._input(mm_move)
	_lmb(ix, center, true)
	_lmb(ix, center, false)
	await process_frame
	check(view.doc.body_ids().size() == 1, "one body placed")
	check(view.selected_body != "", "body stays selected")
	main._update_panel_visibility()
	check(not main.palette.visible, "primitives hidden after select")
	check(main.ops_panel.offset_left == 8.0, "modify tools in left rail")
	check(not ix.transform_hud.visible, "transform HUD idle-hidden after place")
	var id: String = view.doc.body_ids()[0]
	var bb: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb["min"].z)) < 1e-2, "box sits on ground (z=0)")
	# 3. Alt+left-drag orbits (touchpad-friendly; works over docks)
	var yaw0: float = cam.yaw
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.alt_pressed = true
	mm.relative = Vector2(55, 0)
	mm.position = Vector2(1400, 420)
	ix._input(mm)
	check(absf(cam.yaw - yaw0) > 1e-4, "camera yaw changed after Alt-orbit")


## docs/howto/stack-three-blocks.md
func howto_stack_three_blocks(main) -> void:
	print("- howto_stack_three_blocks")
	var view: DocumentView = main.view
	view.new_document()

	var s := DocumentView.DEFAULT_PRIMITIVE_MM
	# Place first on ground, then each next on prior top.
	var a: String = view.insert_primitive("box", Vector3(0, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(0, 0, s))
	var c: String = view.insert_primitive("box", Vector3(0, 0, s * 2.0))
	check(a != "" and b != "" and c != "", "three boxes placed")
	check(view.doc.body_ids().size() == 3, "document has 3 bodies")

	var mn := 1e9
	var mx := -1e9
	for id in [a, b, c]:
		var bb: Dictionary = view.doc.measure_bbox(id)
		mn = minf(mn, float(bb["min"].z))
		mx = maxf(mx, float(bb["max"].z))
	check(absf(mn) < 1e-2, "stack starts at ground")
	check(absf(mx - s * 3.0) < 1e-2, "stack total height %.0f (got %s)" % [s * 3.0, mx])

	var ix: ViewportInteraction = main.interaction
	ix.insert_at_center("box")
	view.insert_primitive("box", Vector3(0, 0, s * 3.0))
	ix._disarm_place(false)
	await process_frame
	check(view.doc.body_ids().size() == 4, "optional fourth via same rule")


## docs/howto/extrude-s-shape.md
func howto_extrude_s_shape(main) -> void:
	print("- howto_extrude_s_shape")
	var view: DocumentView = main.view
	var sk: SketchMode = main.sketch_mode
	view.new_document()

	# Sketch closed S-channel polyline (matches howto coordinates).
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.infer_enabled = false
	sk.set_tool(SketchMode.Tool.LINE)
	var pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(20, 0), Vector2(20, 15), Vector2(5, 15),
		Vector2(5, 25), Vector2(20, 25), Vector2(20, 40), Vector2(0, 40),
		Vector2(0, 25), Vector2(15, 25), Vector2(15, 15), Vector2(0, 15),
		Vector2(0, 0),
	]
	for p in pts:
		sk.click(p)
	sk.end_chain()
	check(sk.sketch.entity_ids().size() >= 12, "S outline has many line entities")
	sk.finish_extrude(10.0, "new")
	await process_frame
	check(view.doc.body_ids().size() == 1, "one solid after S extrude")
	var id: String = view.doc.body_ids()[0]
	var mp: Dictionary = view.doc.measure_mass(id)
	var vol: float = float(mp.get("volume", 0.0))
	check(vol > 100.0, "S extrusion has substantial volume (got %s)" % vol)


## docs/howto/extrude-letter-a.md
func howto_extrude_letter_a(main) -> void:
	print("- howto_extrude_letter_a")
	var view: DocumentView = main.view
	var sk: SketchMode = main.sketch_mode
	view.new_document()

	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.infer_enabled = false
	sk.set_tool(SketchMode.Tool.LINE)
	# Outer A silhouette
	var outer: Array[Vector2] = [
		Vector2(0, 0), Vector2(12, 0), Vector2(18, 22), Vector2(32, 22),
		Vector2(38, 0), Vector2(50, 0), Vector2(30, 55), Vector2(20, 55),
		Vector2(0, 0),
	]
	for p in outer:
		sk.click(p)
	sk.end_chain()
	# Inner triangular counter
	var inner: Array[Vector2] = [
		Vector2(20, 28), Vector2(30, 28), Vector2(25, 42), Vector2(20, 28),
	]
	for p in inner:
		sk.click(p)
	sk.end_chain()
	check(sk.sketch.entity_ids().size() >= 10, "A outline has outer + inner lines")
	sk.finish_extrude(10.0, "new")
	await process_frame
	check(view.doc.body_ids().size() == 1, "one solid after A extrude")
	var id: String = view.doc.body_ids()[0]
	var mp: Dictionary = view.doc.measure_mass(id)
	var vol: float = float(mp.get("volume", 0.0))
	# Outer silhouette area is well above 1000 mm²; triangle hole ~70 mm²;
	# at 10 mm depth expect thousands of mm³, below a no-hole ceiling.
	check(vol > 5000.0, "A extrusion has substantial volume (got %s)" % vol)
	check(vol < 14000.0, "A volume reflects the counter hole (got %s)" % vol)


## docs/howto/horizontal-hole.md
func howto_horizontal_hole(main) -> void:
	print("- howto_horizontal_hole")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()

	# 1–2. Box + cylinder beside it (sizes match the howto).
	var box: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 20, 20))
	var cyl: String = view.insert_primitive("cylinder", Vector3(40, 0, 0), Vector3(8, 8, 10))
	check(box != "" and cyl != "", "box and cylinder placed")
	check(view.doc.body_ids().size() == 2, "two bodies before cut")

	# Upright stretch on flat (+Z) end lengthens without tilting.
	view.select_entity(cyl, "")
	var bb: Dictionary = view.doc.measure_bbox(cyl)
	var len0: float = float(bb["max"].z) - float(bb["min"].z)
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	mx.z += 6.0
	check(view.resize_primitive_aabb(cyl, mn, mx), "upright +Z stretch commits")
	bb = view.doc.measure_bbox(cyl)
	check(absf((float(bb["max"].z) - float(bb["min"].z)) - (len0 + 6.0)) < 1e-2,
		"upright stretch grew length by 6 (got %s)" % (bb["max"].z - bb["min"].z))
	check(absf(float(bb["max"].x) - float(bb["min"].x) - 8.0) < 1e-2,
		"upright stretch kept diameter")

	# 3. Rotate cylinder 90° about Y → axis horizontal (parametric: keeps z_dir).
	bb = view.doc.measure_bbox(cyl)
	var c: Vector3 = (bb["min"] + bb["max"]) * 0.5
	check(view.rotate_selected(c, Vector3(0, 1, 0), PI / 2.0), "rotate cylinder 90° about Y")
	bb = view.doc.measure_bbox(cyl)
	var size: Vector3 = bb["max"] - bb["min"]
	check(size.x > size.z - 1e-2, "after rotate, extent is longer in X than Z")
	var params: Dictionary = view.feature_params(cyl)
	var z_dir := DocumentView._param_vec3(params, "z_dir", Vector3.ZERO)
	check(z_dir.dot(Vector3(1, 0, 0)) > 0.99, "params z_dir along +X after rotate")

	# Flat-end stretch (+X) lengthens; must NOT snap upright / change rotation.
	var len_x0: float = float(bb["max"].x) - float(bb["min"].x)
	var diam_y0: float = float(bb["max"].y) - float(bb["min"].y)
	mn = bb["min"]
	mx = bb["max"]
	mx.x += 10.0
	check(view.resize_primitive_aabb(cyl, mn, mx), "horizontal +X stretch commits")
	bb = view.doc.measure_bbox(cyl)
	check(absf((float(bb["max"].x) - float(bb["min"].x)) - (len_x0 + 10.0)) < 1e-2,
		"flat-end stretch grew length along X by 10 (got %s)" % (bb["max"].x - bb["min"].x))
	check(absf((float(bb["max"].y) - float(bb["min"].y)) - diam_y0) < 1e-2,
		"flat-end stretch kept diameter")
	params = view.feature_params(cyl)
	z_dir = DocumentView._param_vec3(params, "z_dir", Vector3.ZERO)
	check(z_dir.dot(Vector3(1, 0, 0)) > 0.99, "stretch preserved position (still horizontal)")

	# Radial stretch (both Y and Z — diameter = min of the two) keeps axis horizontal.
	mn = bb["min"]
	mx = bb["max"]
	mx.y += 2.0
	mn.y -= 2.0
	mx.z += 2.0
	mn.z -= 2.0
	check(view.resize_primitive_aabb(cyl, mn, mx), "radial stretch commits")
	bb = view.doc.measure_bbox(cyl)
	check(absf((float(bb["max"].y) - float(bb["min"].y)) - (diam_y0 + 4.0)) < 1e-2,
		"radial stretch grew diameter")
	params = view.feature_params(cyl)
	z_dir = DocumentView._param_vec3(params, "z_dir", Vector3.ZERO)
	check(z_dir.dot(Vector3(1, 0, 0)) > 0.99, "radial stretch did not re-orient cylinder")

	# 4. Lengthen further via Pull on an end face (alternate path).
	c = (bb["min"] + bb["max"]) * 0.5
	var end_hit: Dictionary = view.doc.pick(
			Vector3(bb["max"].x + 50.0, c.y, c.z), Vector3(-1, 0, 0))
	check(not end_hit.is_empty() and end_hit["body"] == cyl, "picked cylinder end face")
	view.select_entity(cyl, end_hit["face"])
	var len_before_pull: float = float(bb["max"].x) - float(bb["min"].x)
	check(view.push_pull_selected(12.0), "lengthen cylinder via pull")
	bb = view.doc.measure_bbox(cyl)
	check(float(bb["max"].x) - float(bb["min"].x) > len_before_pull + 11.0,
		"pull grew length along X")
	check(float(bb["max"].x) - float(bb["min"].x) > 30.0, "cylinder longer than box width")

	# 5. Push through the box center.
	view.select_entity(cyl, "")
	bb = view.doc.measure_bbox(cyl)
	c = (bb["min"] + bb["max"]) * 0.5
	var box_bb: Dictionary = view.doc.measure_bbox(box)
	var box_c: Vector3 = (box_bb["min"] + box_bb["max"]) * 0.5
	check(view.move_selected(box_c - c), "move cylinder through box")
	bb = view.doc.measure_bbox(cyl)
	check(float(bb["min"].x) < float(box_bb["min"].x) - 1e-2
			and float(bb["max"].x) > float(box_bb["max"].x) + 1e-2,
		"cylinder sticks out both sides of the box")
	params = view.feature_params(cyl)
	z_dir = DocumentView._param_vec3(params, "z_dir", Vector3.ZERO)
	check(z_dir.dot(Vector3(1, 0, 0)) > 0.99, "move kept cylinder horizontal")

	# 6. Multi-select with box primary (last), then Subtract.
	view.select_entity(cyl, "")
	# Additive pick from a point that hits the box (cylinder already selected).
	check(view.select_ray(Vector3(box_c.x, box_c.y, 500.0), Vector3(0, 0, -1), true),
		"Shift-add box to selection")
	check(view.selected_bodies.size() == 2, "two bodies multi-selected")
	check(view.selected_body == box, "box is primary (last selected)")
	ix._refresh_selection_strip()
	check(ix._strip_cut.visible, "Subtract strip visible")
	var vol0: float = view.doc.body_volume(box)
	ix._ctx_boolean("cut")
	check(view.doc.body_ids().size() == 1, "cut leaves one body")
	var remaining: String = str(view.doc.body_ids()[0])
	check(remaining == box, "remaining body is the box")
	# Diameter was stretched +4 total (r≈6); through depth = box X = 20.
	var drop: float = vol0 - view.doc.body_volume(box)
	var r_final: float = (float(bb["max"].y) - float(bb["min"].y)) * 0.5
	var expected: float = PI * r_final * r_final * 20.0
	check(absf(drop - expected) < expected * 0.05,
		"horizontal hole volume drop ~%.0f (got %.0f)" % [expected, drop])
	# Cut stays: move/rotate mutate the live solid and must not resurrect tools
	# or rebuild the uncut primitives.
	var vol_cut: float = view.doc.body_volume(box)
	var bb_cut: Dictionary = view.doc.measure_bbox(box)
	view.select_entity(box, "")
	check(view.move_selected(Vector3(5, 0, 0)), "move cut result")
	check(view.doc.body_ids().size() == 1, "move after cut still one body")
	check(str(view.doc.body_ids()[0]) == box, "move after cut keeps the box id")
	check(absf(view.doc.body_volume(box) - vol_cut) < 1.0,
		"move after cut preserves holed volume (got %.0f vs %.0f)" % [
				view.doc.body_volume(box), vol_cut])
	var bb_moved: Dictionary = view.doc.measure_bbox(box)
	check(absf(float(bb_moved["min"].x) - float(bb_cut["min"].x) - 5.0) < 1e-2,
		"move shifted the holed solid (not a rebuilt stock box)")
	var c_cut: Vector3 = (bb_moved["min"] + bb_moved["max"]) * 0.5
	check(view.rotate_selected(c_cut, Vector3(0, 0, 1), PI / 6.0), "rotate cut result")
	check(view.doc.body_ids().size() == 1, "rotate after cut still one body")
	check(absf(view.doc.body_volume(box) - vol_cut) < 1.0,
		"rotate after cut preserves holed volume")
	var has_boolean := false
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "boolean":
			has_boolean = true
			break
	check(has_boolean, "Subtract recorded as a timeline boolean feature")
	await process_frame


## docs/howto/rib-and-wrap.md — the rib is swept from the sketch, so a longer
## profile adds more material. A fixed block would not care about the sketch.
func howto_rib_follows_sketch(main) -> void:
	print("- howto_rib_follows_sketch")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction

	var gains := []
	for legs in [1, 2]:
		view.new_document()
		var body: String = view.insert_primitive("box", Vector3.ZERO)
		await process_frame
		var before: float = float(view.doc.measure_mass(body).get("volume", 0.0))
		var bb: Dictionary = view.doc.measure_bbox(body)
		var top: float = float(bb["max"].z)

		var sk := SxSketch.new()
		sk.set_plane(Vector3(0, 0, top), Vector3(1, 0, 0), Vector3(0, 1, 0))
		sk.add_line(10, 25, 40, 25)
		if legs == 2:
			sk.add_line(40, 25, 40, 40)
		var sk_fid: String = view.doc.graph_add_sketch(sk)
		check(sk_fid != "", "open rib profile on the timeline (%d leg/s)" % legs)

		view.select_entity(body, "")
		ix._ctx_rib()
		await process_frame
		var has_rib := false
		for f in view.doc.graph_features():
			if str(f.get("type", "")) == "rib":
				has_rib = true
		check(has_rib, "S-menu Rib recorded a timeline feature (%d leg/s)" % legs)
		var after: float = float(view.doc.measure_mass(body).get("volume", 0.0))
		gains.append(after - before)

	check(gains[0] > 100.0, "one-leg rib adds material (%.0f mm³)" % gains[0])
	check(gains[1] > gains[0] * 1.3,
		"second leg adds more (%.0f vs %.0f mm³)" % [gains[1], gains[0]])


## docs/howto/flange-box-flat.md — a real bend, and a blank that weighs the same.
func howto_flange_unfolds(main) -> void:
	print("- howto_flange_unfolds")
	var view: DocumentView = main.view
	view.new_document()
	var fid: String = view.doc.graph_add_flange(30.0, 1.5, 0.44, 1.5, 40.0)
	check(fid != "", "flange on the timeline")
	await process_frame

	var flat := 0.0
	var body := ""
	for f in view.doc.graph_features():
		if str(f.get("id", "")) == fid:
			body = str(f.get("output_body", ""))
			var p: Variant = JSON.parse_string(str(f.get("params", "{}")))
			if p is Dictionary:
				flat = float(p.get("flat_length", 0.0))
	check(flat == view.doc.sheet_flat_length(30.0, 30.0, 1.5, 0.44, 1.5),
		"flat_length matches the bend-allowance formula (%.3f mm)" % flat)
	check(body != "", "flange made a body")
	var folded: float = float(view.doc.measure_mass(body).get("volume", 0.0))
	var blank: float = flat * 40.0 * 1.5
	check(absf(folded - blank) < blank * 0.01,
		"folded %.0f mm³ matches the %.0f mm³ blank" % [folded, blank])
	# A bend is curved; two fused boxes are not.
	var bb: Dictionary = view.doc.measure_bbox(body)
	check(float(bb["max"].z) > 25.0, "the flange leg stands up (%.1f mm)" % float(bb["max"].z))


## docs/howto/{crank-slider,flange-box-flat,catalog-fastener,fea-bracket}.md
func howto_landing_bindings(main) -> void:
	print("- howto_landing_bindings (W1–W4)")
	var view: DocumentView = main.view
	view.new_document()
	var x0: float = view.doc.crank_slider_x(20.0, 80.0, 0.0)
	check(absf(x0 - 100.0) < 1e-4, "crank-slider x(0)=100")
	var flat: float = view.doc.sheet_flat_length(30.0, 30.0, 1.5, 0.44, 1.5)
	check(flat > 30.0, "flange flat length > leg")
	var cat: Dictionary = view.doc.catalog_fastener("M6x20")
	check(str(cat.get("designation", "")) == "M6x20", "catalog M6x20")
	check(absf(float(cat.get("diameter", 0)) - 6.0) < 1e-6, "catalog Ø6")
	var d1: float = view.doc.fea_cantilever(100.0, 50.0, 210000.0, 20.0, 4.0)
	var d2: float = view.doc.fea_cantilever(100.0, 100.0, 210000.0, 20.0, 4.0)
	check(d1 > 0.0 and d2 / d1 > 7.5, "FEA L³ scale")
	var pts: PackedVector3Array = view.doc.cam_pocket(0, 0, 20, 10, 2.0, 2.0)
	check(pts.size() >= 8, "CAM pocket zig-zag")
	var mode := main.find_child("ModeRail", true, false) as MenuButton
	check(mode != null, "Mode rail on the top bar")
	check(main.drawing_sheet != null and not main.drawing_sheet.visible, "drawing sheet hidden in Model")
	check(main.sheet_metal_view != null and not main.sheet_metal_view.visible, "sheet split hidden in Model")
	check(main.print_strip != null and not main.print_strip.visible, "print strip hidden in Model")
	main._on_mode_menu(1)
	check(main.drawing_sheet.visible, "Draw mode shows the sheet")
	main._on_mode_menu(5)
	check(main.print_strip.visible, "Form mode shows the print strip")
	check(not main.drawing_sheet.visible, "Form hides the drawing sheet")
	main._on_mode_menu(0)
	check(not main.drawing_sheet.visible, "Model hides the sheet")
	check(not main.print_strip.visible, "Model hides the print strip")
	await process_frame


## docs/howto/print-thin-wall.md
func howto_print_thin_wall(main) -> void:
	print("- howto_print_thin_wall")
	var view: DocumentView = main.view
	view.new_document()
	view.doc.add_box(20, 20, 1.2, Vector3.ZERO)
	view.doc.set_print_min_wall(2.0)
	main._on_mode_menu(5)
	await process_frame
	check(main.print_strip != null and main.print_strip.visible, "Form strip visible")
	var analyze := main.find_child("PrintAnalyze", true, false) as Button
	check(analyze != null and analyze.is_visible_in_tree(), "Analyze chip is clickable")
	if analyze != null:
		analyze.pressed.emit()
		await process_frame
	var r: Dictionary = view.doc.print_analyze("")
	check(not bool(r.get("wall_ok", true)), "1.2 mm plate fails a 2 mm wall")
	check(str(r.get("digest", "")).findn("thin") >= 0, "digest names the thin wall")
	main._on_mode_menu(0)


## docs/howto/print-overhang-orient.md
func howto_print_overhang_orient(main) -> void:
	print("- howto_print_overhang_orient")
	var view: DocumentView = main.view
	view.new_document()
	view.doc.add_box(10, 10, 80, Vector3.ZERO)
	main._on_mode_menu(5)
	await process_frame
	var before: Dictionary = view.doc.print_analyze("")
	var orient := main.find_child("PrintOrient", true, false) as Button
	check(orient != null and orient.is_visible_in_tree(), "Orient chip is clickable")
	if orient != null:
		orient.pressed.emit()
		await process_frame
	var after: Dictionary = view.doc.print_analyze("")
	check(float(before.get("height", 0)) > 70.0, "tall box starts ~80 mm high")
	check(float(after.get("height", 99)) < 12.0, "Orient lays it down (~10 mm)")
	main._on_mode_menu(0)
