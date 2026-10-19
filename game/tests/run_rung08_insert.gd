# Rung 8 WP3 — New Assembly, multi-file Insert, Float/Fix.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const OUT := "/tmp/sx-rung08-insert"
const NEW_PART := "New — empty part, Top plane (XY). View ▸ Timeline to edit features"


func _init() -> void:
	print("rung08 insert / New Assembly")
	DirAccess.make_dir_recursive_absolute(OUT)
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	listen_status(ctx.main)
	var a := _stub_sxp(ctx, "box-a.sxp")
	var b := _stub_sxp(ctx, "box-b.sxp")
	await _new_assembly(ctx)
	await _insert_two(ctx, a, b)
	await _float_drag_fix(ctx)
	_empty_insert_refuses(ctx)
	_file_new_still_part(ctx)
	ctx.main.queue_free()
	finish()


func _stub_sxp(ctx: FilmContext, name: String) -> String:
	ctx.view.new_document()
	var body := ctx.view.doc.add_box(20.0, 20.0, 10.0, Vector3.ZERO)
	check(body != "", "stub body %s" % name)
	var path := OUT.path_join(name)
	check(ctx.view.save(path), "save %s" % name)
	return path


func _datums(doc: SxDocument) -> PackedStringArray:
	var names := PackedStringArray()
	for d in doc.datum_list():
		names.append(str(d.get("name", "")))
	return names


func _new_assembly(ctx: FilmContext) -> void:
	print("- New Assembly")
	var labels: Dictionary = ctx.main.file_menu_id_labels()
	check(str(labels.get(16, "")) == "New Assembly", "File menu has New Assembly")
	ctx.main._do_new_assembly()
	await process_frame
	await process_frame
	check(ctx.view.doc.kind() == "assembly", "kind is assembly")
	check(ctx.view.units == "mmgs", "units mmgs")
	check(ctx.view.doc.body_ids().is_empty(), "empty of bodies")
	var names := _datums(ctx.view.doc)
	check(names.has("Front") and names.has("Top") and names.has("Right"),
			"origin planes Front/Top/Right (got %s)" % str(names))
	check(str(ctx.main.status_label.text).contains("empty assembly"),
			"status New — empty assembly (got %s)" % ctx.main.status_label.text)


func _insert_two(ctx: FilmContext, path_a: String, path_b: String) -> void:
	print("- insert two .sxp")
	ctx.main._on_insert_menu(10)
	await process_frame
	check(ctx.main._file_action == ctx.main.FileAction.INSERT_SXP, "Insert arms INSERT_SXP")
	check(ctx.main.file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILES,
			"Components… is multi-file Open")
	if ctx.main.file_dialog.visible:
		ctx.main.file_dialog.hide()
	ctx.main._file_action = ctx.main.FileAction.NONE
	var n: int = ctx.main.insert_components_from_paths(PackedStringArray([path_a, path_b]))
	check(n == 2, "inserted two files (got %d)" % n)
	await process_frame
	ctx.main.assembly_panel.refresh_lists()
	var inst: Array = ctx.view.doc.instance_list()
	check(inst.size() == 2, "two instances (got %d)" % inst.size())
	if inst.size() < 1:
		return
	check(bool(inst[0].get("fixed", false)), "first instance is Fixed")
	var saw_f := false
	for row in ctx.main.assembly_panel._instances_list.get_children():
		for c in row.get_children():
			if c is Label and str(c.text).begins_with("(f)"):
				saw_f = true
	check(saw_f, "panel shows (f) on the fixed instance")


func _float_drag_fix(ctx: FilmContext) -> void:
	print("- Float, drag, Fix")
	var inst: Array = ctx.view.doc.instance_list()
	if inst.is_empty():
		check(false, "instances exist to float")
		return
	var iid := str(inst[0].get("id", ""))
	check(ctx.view.doc.set_instance_fixed(iid, false), "Float")
	ctx.main.assembly_panel.refresh_lists()
	var after_float: Dictionary = ctx.view.doc.instance_list()[0]
	check(not bool(after_float.get("fixed", true)), "first instance is floating")
	var before: Vector3 = after_float.get("translation", Vector3.ZERO)
	check(ctx.view.doc.set_instance_transform(iid, before + Vector3(40, 0, 0),
			Vector3(0, 0, 1), 0.0), "drag translation")
	ctx.view.refresh()
	await process_frame
	var moved: Dictionary = ctx.view.doc.instance_list()[0]
	var got: Vector3 = moved.get("translation", Vector3.ZERO)
	check(got.distance_to(before) > 1.0, "unfixed instance moved (delta %.1f)" % got.distance_to(before))
	check(ctx.view.doc.set_instance_fixed(iid, true), "Fix")
	ctx.main.assembly_panel.refresh_lists()
	check(bool(ctx.view.doc.instance_list()[0].get("fixed", false)), "fixed again")


func _empty_insert_refuses(ctx: FilmContext) -> void:
	print("- empty Insert refuses")
	var before := ctx.view.doc.instance_list().size()
	check(not ctx.main.insert_components_from(""), "empty path returns false")
	check(ctx.view.doc.instance_list().size() == before, "empty insert does not add instances")
	check(str(ctx.main.status_label.text).contains("Insert failed"),
			"empty insert status refuses (got %s)" % ctx.main.status_label.text)


func _file_new_still_part(ctx: FilmContext) -> void:
	print("- File → New still part")
	ctx.main._do_new()
	check(ctx.view.doc.kind() == "part", "File → New is a part")
	check(str(ctx.main.status_label.text) == NEW_PART, "pinned New part sentence")
	check(ctx.view.doc.body_ids().is_empty(), "File → New is empty")
	check(ctx.view.units == "mmgs", "part units mmgs")
