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
	await howto_mounting_block(main)

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
	# Same as Done / Esc / right-click in the UI.
	sk.end_chain()
	check(not sk.has_open_chain(), "S chain ended")
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
	check(not sk.has_open_chain(), "outer A chain ended")
	# Inner triangular counter
	var inner: Array[Vector2] = [
		Vector2(20, 28), Vector2(30, 28), Vector2(25, 42), Vector2(20, 28),
	]
	for p in inner:
		sk.click(p)
	sk.end_chain()
	check(not sk.has_open_chain(), "inner A chain ended")
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


## docs/howto/mounting-block.md — box + Apply hole via O (Depth 0 = through).
func howto_mounting_block(main) -> void:
	print("- howto_mounting_block")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	var ix: ViewportInteraction = main.interaction
	view.new_document()

	# 1–3. Sized box on the ground.
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(100, 60, 30))
	check(body != "", "box placed")
	check(view.doc.body_ids().size() == 1, "one body")
	var vol0: float = view.doc.body_volume(body)
	check(absf(vol0 - 180000.0) < 1.0, "box volume 180000 (got %.0f)" % vol0)

	# 4. Select top face (+Z).
	var top_face := ""
	for face_id in view.doc.get_face_ids(body):
		var mid: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid.z - 30.0) < 0.5:
			top_face = face_id
			break
	check(top_face != "", "top face found")
	view.select_entity(body, top_face)
	ix._refresh_selection_strip()
	check(ix._strip_hole != null and ix._strip_hole.visible, "Hole strip visible with face")

	# 5. Ø20; Depth 0 (through). Apply via O shortcut (keyboard path).
	ops._hole_diameter.value = 20.0
	ops._hole_depth.value = 0.0
	var key := InputEventKey.new()
	key.keycode = KEY_O
	key.pressed = true
	check(ix._gui_key(key), "O applies hole")
	check(view.doc.body_ids().size() == 1, "still one body after hole")
	var expected: float = 180000.0 - PI * 100.0 * 30.0
	var vol: float = view.doc.body_volume(body)
	check(absf(vol - expected) < expected * 0.02,
		"through-hole volume ~%.0f (got %.0f)" % [expected, vol])

	# Strip button path also works (click path parity).
	view.new_document()
	body = view.insert_primitive("box", Vector3.ZERO, Vector3(100, 60, 30))
	top_face = ""
	for face_id in view.doc.get_face_ids(body):
		var mid2: Vector3 = view.doc.face_midpoint(face_id)
		if absf(mid2.z - 30.0) < 0.5:
			top_face = face_id
			break
	view.select_entity(body, top_face)
	ops._hole_diameter.value = 20.0
	ops._hole_depth.value = 0.0
	ix._ctx_apply_hole()
	vol = view.doc.body_volume(body)
	check(absf(vol - expected) < expected * 0.02,
		"strip Apply hole volume ~%.0f (got %.0f)" % [expected, vol])
	await process_frame
