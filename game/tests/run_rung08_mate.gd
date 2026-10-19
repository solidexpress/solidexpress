# Rung 8 WP4 — instance↔instance mates, Concentric offset 0.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung08 instance mates / concentric 0")
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	listen_status(ctx.main)
	await _concentric_two_instances(ctx)
	_empty_second_pick_refuses(ctx)
	_offset_zero_two_still_adds(ctx)
	ctx.main.queue_free()
	finish()


func _type_index(panel: AssemblyPanel, text: String) -> int:
	for i in range(panel._type_option.item_count):
		if panel._type_option.get_item_text(i) == text:
			return i
	return 0


func _cyl_face(doc: SxDocument, body: String) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var sx: float = absf(bb["max"].x - bb["min"].x)
		var sy: float = absf(bb["max"].y - bb["min"].y)
		var sz: float = absf(bb["max"].z - bb["min"].z)
		if absf(sx - sy) < 0.2 and sz > sx * 0.5:
			return fid
	return ""


func _end_face(doc: SxDocument, body: String, z: float) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.z > 0.2:
			continue
		var zmid: float = 0.5 * (float(bb["min"].z) + float(bb["max"].z))
		if absf(zmid - z) < 0.2:
			return fid
	return ""


func _inst(doc: SxDocument, id: String) -> Dictionary:
	for inst in doc.instance_list():
		if str(inst.get("id", "")) == id:
			return inst
	return {}


func _radial_gap(ca: Dictionary, cb: Dictionary) -> float:
	var za: Vector3 = (ca.get("z_dir", Vector3.UP) as Vector3).normalized()
	var ab: Vector3 = (cb.get("origin", Vector3.ZERO) as Vector3) \
			- (ca.get("origin", Vector3.ZERO) as Vector3)
	return (ab - za * ab.dot(za)).length()


func _two_cyls(ctx: FilmContext) -> Dictionary:
	ctx.main._do_new_assembly()
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc
	var src: String = doc.add_cylinder(10.0, 40.0, Vector3.ZERO)
	check(src != "", "cylinder source")
	view.set_body_hidden(src, true)
	var ia: String = doc.add_instance(src, Vector3(0, 0, 0), Vector3(0, 0, 1), 0.0, "Cyl-1")
	var ib: String = doc.add_instance(src, Vector3(80, 20, 0), Vector3(0, 0, 1), 0.0, "Cyl-2")
	check(ia != "" and ib != "", "two instances of one source")
	check(doc.set_instance_fixed(ia, true), "Fix first instance")
	view.refresh()
	var panel: AssemblyPanel = ctx.main.assembly_panel
	panel.refresh_lists()
	var face := _cyl_face(doc, src)
	check(face != "", "cylindrical face")
	return {"src": src, "ia": ia, "ib": ib, "face": face, "panel": panel, "doc": doc, "view": view}


func _concentric_two_instances(ctx: FilmContext) -> void:
	print("- Concentric 0, two instances of one cylinder")
	var setup := _two_cyls(ctx)
	var doc: SxDocument = setup["doc"]
	var view: DocumentView = setup["view"]
	var panel: AssemblyPanel = setup["panel"]
	var ia: String = setup["ia"]
	var ib: String = setup["ib"]
	var face: String = setup["face"]
	if face == "" or ia == "" or ib == "":
		return

	var hit_a: Dictionary = view.pick_instance(Vector3(50, 0, 20), Vector3(-1, 0, 0))
	check(str(hit_a.get("id", "")) == ia, "pick_instance hits instance A")
	check(str(hit_a.get("face", "")) != "", "pick_instance returns a face on A")
	var hit_b: Dictionary = view.pick_instance(Vector3(120, 20, 20), Vector3(-1, 0, 0))
	check(str(hit_b.get("id", "")) == ib, "pick_instance hits instance B (same source)")
	check(str(hit_b.get("face", "")) != "", "pick_instance returns a face on B")
	check(str(hit_a.get("id", "")) != str(hit_b.get("id", "")),
			"A and B are distinguishable")

	panel._type_option.select(_type_index(panel, "concentric"))
	check(is_equal_approx(panel._offset_spin.value, 0.0), "offset spin defaults to 0")
	await process_frame
	var add_btn := FilmUI.find_button(panel, "Add mate")
	check(add_btn != null and add_btn.is_visible_in_tree(), "Add mate is visible")
	await FilmUI.click_control(ctx, add_btn, FilmUICues.alert("Add mate", "Arm two-face mate"))
	check(panel.mate_armed(), "Add mate arms the two-face flow")
	check(str(ctx.main.status_label.text).contains("click two faces"),
			"status Mate: click two faces (got %s)" % ctx.main.status_label.text)

	# Mate-armed instance press is a face pick, not a drag (even on a floater).
	root.size = ROOT_SIZE
	ctx.main.interaction.size = Vector2(ROOT_SIZE)
	ctx.main.camera.frame_contents()
	await process_frame
	await process_frame
	var world_b: Vector3 = ctx.main.model_space.to_global(Vector3(90, 20, 20))
	var screen_b: Vector2 = ctx.main.camera.unproject_position(world_b)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_b
	ctx.main.interaction._input(press)
	check(not ctx.main.interaction._pending_instance_move,
			"mate-armed instance press does not arm a drag")
	panel._mate_armed = false
	panel._mate_face_a = ""
	panel._mate_instance_a = ""
	view.mate_anchor_face = ""
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_b
	ctx.main.interaction._input(release)

	var before_n := doc.mate_list().size()
	panel._arm_mate()
	panel.offer_instance_face(ia, face)
	panel.offer_instance_face(ib, face)
	var mates: Array = doc.mate_list()
	check(mates.size() == before_n + 1, "concentric mate added (got %d, before %d)" % [mates.size(), before_n])
	if mates.size() >= 1:
		var last: Dictionary = mates[mates.size() - 1]
		check(str(last.get("instance_a", "")) == ia, "instance_a is first pick")
		check(str(last.get("instance_b", "")) == ib, "instance_b is second pick")
		check(is_equal_approx(float(last.get("offset", -1.0)), 0.0),
				"stored offset is 0")

	var ca: Dictionary = doc.implicit_connector(ia, face)
	var cb: Dictionary = doc.implicit_connector(ib, face)
	check(not ca.is_empty() and not cb.is_empty(), "connectors after concentric")
	var za: Vector3 = (ca.get("z_dir", Vector3.ZERO) as Vector3).normalized()
	var zb: Vector3 = (cb.get("z_dir", Vector3.ZERO) as Vector3).normalized()
	check(absf(absf(za.dot(zb)) - 1.0) < 1e-3, "axes parallel")
	var gap := _radial_gap(ca, cb)
	check(gap < 0.2, "axes colinear ± 0.2 (radial %.4f)" % gap)

	# Axial slide stays free.
	var t0: Vector3 = _inst(doc, ib).get("translation", Vector3.ZERO)
	check(doc.set_instance_transform(ib, t0 + Vector3(0, 0, 15), Vector3(0, 0, 1), 0.0),
			"nudge B along +Z")
	check(doc.solve_mates(), "solve after axial nudge")
	var t1: Vector3 = _inst(doc, ib).get("translation", Vector3.ZERO)
	check(absf(t1.z - (t0.z + 15.0)) < 0.2, "axial slide free (z %.2f → %.2f)" % [t0.z, t1.z])
	cb = doc.implicit_connector(ib, face)
	check(_radial_gap(ca, cb) < 0.2, "still colinear after axial slide")

	# Coincident of end planes locks the gap.
	var top := _end_face(doc, setup["src"], 40.0)
	var bottom := _end_face(doc, setup["src"], 0.0)
	check(top != "" and bottom != "", "cylinder end faces")
	var before_co := doc.mate_list().size()
	panel._type_option.select(_type_index(panel, "plane_coincident"))
	panel._arm_mate()
	panel.offer_instance_face(ia, top)
	panel.offer_instance_face(ib, bottom)
	check(doc.mate_list().size() == before_co + 1,
			"coincident added (got %d, before %d)" % [doc.mate_list().size(), before_co])
	var tz: float = _inst(doc, ib).get("translation", Vector3.ZERO).z
	check(absf(tz - 40.0) < 0.2, "B bottom on A top (tz %.2f)" % tz)
	check(doc.set_instance_transform(ib, t1 + Vector3(0, 0, 20), Vector3(0, 0, 1), 0.0),
			"nudge B after coincident")
	check(doc.solve_mates(), "solve coincident after nudge")
	var tz2: float = _inst(doc, ib).get("translation", Vector3.ZERO).z
	check(absf(tz2 - 40.0) < 0.2, "coincident locks the gap (tz %.2f)" % tz2)


func _empty_second_pick_refuses(ctx: FilmContext) -> void:
	print("- empty second pick refuses")
	var setup := _two_cyls(ctx)
	var doc: SxDocument = setup["doc"]
	var panel: AssemblyPanel = setup["panel"]
	var face: String = setup["face"]
	panel._type_option.select(_type_index(panel, "concentric"))
	panel._arm_mate()
	panel.offer_instance_face(setup["ia"], face)
	var before := doc.mate_list().size()
	panel.offer_instance_face(setup["ib"], "")
	check(doc.mate_list().size() == before, "empty face_b does not add a mate")
	check(panel.mate_armed(), "flow stays armed after empty second pick")


func _offset_zero_two_still_adds(ctx: FilmContext) -> void:
	print("- concentric offset 0.2 still adds")
	var setup := _two_cyls(ctx)
	var doc: SxDocument = setup["doc"]
	check(doc.add_mate("concentric", setup["ia"], setup["face"], setup["ib"], setup["face"],
			0.2, false, "clearance") != "", "offset 0.2 concentric accepted")
	check(doc.solve_mates(), "offset 0.2 solves")
