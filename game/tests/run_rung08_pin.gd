# Rung 8 WP6 — Insert → New Part, Front revolve pin, Edit Component.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const PinFix = preload("res://tests/lib/pin_fixture.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const OUT := "/tmp/sx-rung08-pin"


func _init() -> void:
	print("rung08 in-context pin")
	DirAccess.make_dir_recursive_absolute(OUT)
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	listen_status(ctx.main)
	await _new_part_menu(ctx)
	await _sketch_and_revolve(ctx)
	await _finalize_and_check(ctx)
	await _part_revolve_still_ground(ctx)
	ctx.main.queue_free()
	finish()


func _insert_popup(main) -> PopupMenu:
	var insert_btn: MenuButton = main.find_child("InsertMenu", true, false)
	if insert_btn == null:
		return null
	return insert_btn.get_popup()


func _new_part_menu(ctx: FilmContext) -> void:
	print("- Insert → New Part")
	ctx.main._do_new_assembly()
	await process_frame
	var popup := _insert_popup(ctx.main)
	check(popup != null, "Insert menu exists")
	var found := false
	for i in popup.item_count:
		if popup.get_item_id(i) == 11 and str(popup.get_item_text(i)) == "New Part":
			found = true
			break
	check(found, "Insert menu has New Part id=11 next to Components")
	var insert_btn: MenuButton = ctx.main.find_child("InsertMenu", true, false)
	await FilmUI.click_control(ctx, insert_btn, {"keys": "Click", "desc": "Open Insert menu"})
	popup.id_pressed.emit(11)
	await process_frame
	var ec = ctx.main.edit_component
	check(ec != null and bool(ec.active), "Edit Component is on")
	check(ec.pending, "New Part is pending a solid")
	check(ec.panel != null and ec.panel.visible, "Edit Component banner visible")
	var has_pad := false
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "in_context":
			has_pad = true
	check(not has_pad, "not the 20×20 in-context pad")
	check(str(ctx.main.status_label.text).contains("Edit Component"),
			"status Edit Component (got %s)" % ctx.main.status_label.text)


func _sketch_and_revolve(ctx: FilmContext) -> void:
	print("- Front sketch + revolve 360")
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch is active")
	var n: Vector3 = sm.plane.x.cross(sm.plane.y).normalized()
	check(n.dot(Vector3(0, 0, 1)) > 0.99, "Front normal +Z")
	check(sm.plane.x.dot(Vector3(1, 0, 0)) > 0.99, "Front x = +X")
	check(sm.plane.y.dot(Vector3(0, 1, 0)) > 0.99, "Front y = +Y")
	PinFix.add_profile(sm.sketch)
	sm.run_solve()
	var types := PackedStringArray()
	for id in sm.sketch.entity_ids():
		types.append(str(sm.sketch.entity_info(id).get("type", "")))
	check(types.has("line") and types.has("arc"), "profile is lines+arcs, not a polyline")
	sm.finish_revolve(TAU, "new")
	await process_frame
	await process_frame
	await process_frame
	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	check(bodies.size() >= 1, "revolve produced a body (got %d)" % bodies.size())
	var pin := ""
	if ctx.main.edit_component != null:
		pin = str(ctx.main.edit_component.source_body)
	if pin == "" and not bodies.is_empty():
		pin = bodies[bodies.size() - 1]
	check(pin != "", "pin source body")
	var bb: Dictionary = ctx.view.doc.measure_bbox(pin)
	var mn: Vector3 = bb.get("min", Vector3.ZERO)
	var mx: Vector3 = bb.get("max", Vector3.ZERO)
	var ext: Vector3 = mx - mn
	check(absf(ext.x - 20.0) <= 0.2 and absf(ext.y - 55.0) <= 0.2 and absf(ext.z - 20.0) <= 0.2,
			"bbox 20×55×20 (got %.3f×%.3f×%.3f)" % [ext.x, ext.y, ext.z])
	check(absf(mn.y) <= 0.2, "min Y at tail pole (got %.3f)" % mn.y)
	var vol: float = ctx.view.doc.body_volume(pin)
	check(absf(vol - 6938.0) <= 6938.0 * 0.005,
			"volume 6938 ±0.5%% (got %.3f)" % vol)
	var inst: Array = ctx.view.doc.instance_list()
	check(inst.size() == 1, "one pin instance (got %d)" % inst.size())
	check(ctx.view.hidden_bodies.has(pin), "pin source hidden; the instance is the component")


func _finalize_and_check(ctx: FilmContext) -> void:
	print("- unselect Edit Component, export pin")
	var toggle: CheckButton = ctx.main.find_child("EditComponentToggle", true, false)
	check(toggle != null, "Edit Component toggle exists")
	await FilmUI.click_control(ctx, toggle, {"keys": "Click", "desc": "Unselect Edit Component"})
	await process_frame
	check(ctx.main.edit_component == null or not ctx.main.edit_component.active,
			"Edit Component off")
	check(ctx.view.doc.instance_list().size() == 1, "pin stays an instance")
	var pin := str(ctx.view.doc.instance_list()[0].get("source_body", ""))
	var mf := OUT.path_join("pin.3mf")
	check(ctx.view.doc.export_3mf_for_body(pin, mf), "export pin.3mf")
	var result := SxChecker.run("rung08", ["pin", mf])
	check(int(result["code"]) == 0,
			"check_rung08.py pin exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])
	var sxp := OUT.path_join("pin.sxp")
	check(ctx.view.save(sxp), "save pin.sxp")
	var has_pad := false
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "in_context":
			has_pad = true
	check(not has_pad, "still no in-context pad after finalize")


func _part_revolve_still_ground(ctx: FilmContext) -> void:
	print("- File → New part revolve is still a ground body")
	ctx.main._do_new()
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "part Front sketch")
	sm.sketch.add_line(10.0, 0.0, 14.0, 0.0)
	sm.sketch.add_line(14.0, 0.0, 14.0, 4.0)
	sm.sketch.add_line(14.0, 4.0, 10.0, 4.0)
	sm.sketch.add_line(10.0, 4.0, 10.0, 0.0)
	sm.run_solve()
	sm.finish_revolve(TAU, "new")
	await process_frame
	check(ctx.view.doc.instance_list().is_empty(), "part revolve is not instanced")
	check(ctx.view.doc.body_ids().size() == 1, "one ground body")
	check(ctx.main.edit_component == null or not ctx.main.edit_component.active,
			"Edit Component stays off for a part")
