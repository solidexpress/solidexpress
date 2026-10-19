# Rung 8 WP9 — File → Export 3MF of instances; save/reopen assembly.sxp.
extends "res://tests/lib/sx_suite.gd"

const SxChecker = preload("res://tests/lib/sx_checker.gd")
const PinFix = preload("res://tests/lib/pin_fixture.gd")
const NutFix = preload("res://tests/lib/nut_fixture.gd")
const WrenchFix = preload("res://tests/lib/wrench_fixture.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const OUT := "/tmp/sx-rung08-export"


func _init() -> void:
	print("rung08 instance 3MF + save/reopen")
	DirAccess.make_dir_recursive_absolute(OUT)
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	listen_status(ctx.main)
	var files := await _write_fixtures(ctx)
	if files.is_empty():
		ctx.main.queue_free()
		finish()
		return
	await _assemble_place_and_export(ctx, files)
	ctx.main.queue_free()
	finish()


func _write_fixtures(ctx: FilmContext) -> Dictionary:
	print("- fixtures")
	var out := {}
	ctx.view.new_document()
	var nut := NutFix.build(ctx.view.doc)
	check(nut != "", "nut body")
	ctx.view.graph_changed()
	for _i in 6:
		await process_frame
	var nut_sxp := OUT.path_join("nut.sxp")
	var nut_mf := OUT.path_join("nut.3mf")
	check(ctx.view.save(nut_sxp) and ctx.view.doc.export_3mf_for_body(nut, nut_mf), "save nut")
	out["nut"] = nut_sxp

	ctx.view.new_document()
	var pipe := PipeFixture.build_final(ctx.view.doc)
	check(pipe != "", "pipe body (%s)" % ctx.view.doc.last_graph_error())
	ctx.view.graph_changed()
	for _i in 12:
		await process_frame
	var pipe_sxp := OUT.path_join("pipe.sxp")
	check(ctx.view.save(pipe_sxp), "save pipe")
	out["pipe"] = pipe_sxp

	ctx.view.new_document()
	var wrench := WrenchFix.build(ctx.view.doc)
	check(wrench != "", "wrench body")
	ctx.view.graph_changed()
	for _i in 6:
		await process_frame
	var wrench_sxp := OUT.path_join("wrench.sxp")
	var wrench_mf := OUT.path_join("wrench.3mf")
	check(ctx.view.save(wrench_sxp) and ctx.view.doc.export_3mf(wrench_mf), "save wrench")
	out["wrench"] = wrench_sxp
	var wrench_chk := SxChecker.run("rung01", ["wrench", wrench_mf])
	check(int(wrench_chk["code"]) == 0, "part wrench 3MF unchanged")
	return out


func _assemble_place_and_export(ctx: FilmContext, files: Dictionary) -> void:
	print("- New Assembly + insert + pin")
	ctx.main._do_new_assembly()
	await process_frame
	var n: int = ctx.main.insert_components_from_paths(PackedStringArray([
		str(files["nut"]), str(files["pipe"]), str(files["wrench"])]))
	check(n == 3, "inserted three .sxp (got %d)" % n)
	await process_frame
	ctx.main._on_insert_menu(11)
	await process_frame
	OriginPlanes.begin(ctx.main, "Front")
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front sketch on New Part")
	PinFix.add_profile(sm.sketch)
	sm.run_solve()
	sm.finish_revolve(TAU, "new")
	await process_frame
	await process_frame
	await process_frame
	if ctx.main.edit_component != null and ctx.main.edit_component.active:
		ctx.main._toggle_edit_component()
	await process_frame
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc
	var kinds := _classify(doc)
	check(kinds["pipe"].size() == 1 and kinds["nut"].size() == 1
			and kinds["pin"].size() == 1 and kinds["wrench"].size() == 1,
			"one of each after insert+pin")
	_copy_n(view, str(kinds["pipe"][0]), 1)
	_copy_n(view, str(kinds["nut"][0]), 15)
	_copy_n(view, str(kinds["pin"][0]), 7)
	view.refresh()
	await process_frame
	kinds = _classify(doc)
	check(kinds["pipe"].size() == 2 and kinds["nut"].size() == 16
			and kinds["pin"].size() == 8 and kinds["wrench"].size() == 1,
			"counts 2/16/8/1 (pipe %d nut %d pin %d wrench %d)" % [
				kinds["pipe"].size(), kinds["nut"].size(), kinds["pin"].size(),
				kinds["wrench"].size()])
	if kinds["pipe"].size() != 2:
		return
	_place_pass_bar(doc, kinds)
	view.refresh()
	await process_frame
	var sxp := OUT.path_join("assembly.sxp")
	check(view.save(sxp), "save assembly.sxp")
	await _export_and_check(doc, kinds, "assembly.3mf")
	await _reopen_and_reexport(ctx, sxp)


func _place_pass_bar(doc: SxDocument, kinds: Dictionary) -> void:
	print("- place at pass-bar transforms")
	for inst in doc.instance_list():
		doc.set_instance_fixed(str(inst.get("id", "")), false)
	var p1: String = str(kinds["pipe"][0])
	var p2: String = str(kinds["pipe"][1])
	check(doc.set_instance_transform(p1, Vector3.ZERO, Vector3(0, 0, 1), 0.0), "pipe 1 identity")
	check(doc.set_instance_transform(p2, Vector3(0, 0, 520), Vector3(0, 0, 1), 0.0), "pipe 2 +520")
	var nuts: Array = kinds["nut"]
	var pins: Array = kinds["pin"]
	for i in 8:
		var xy := Vector2(94.0 * cos(deg_to_rad(90.0 + i * 45.0)),
				94.0 * sin(deg_to_rad(90.0 + i * 45.0)))
		check(doc.set_instance_transform(str(nuts[i]), Vector3(xy.x, xy.y, 242.5),
				Vector3(0, 0, 1), 0.0), "nut lo %d" % i)
		check(doc.set_instance_transform(str(nuts[i + 8]), Vector3(xy.x, xy.y, 270.0),
				Vector3(0, 0, 1), 0.0), "nut hi %d" % i)
		check(doc.set_instance_transform(str(pins[i]), Vector3(xy.x, xy.y, 287.5),
				Vector3(1, 0, 0), -90.0), "pin %d" % i)
	var wrench: String = str(kinds["wrench"][0])
	check(doc.set_instance_transform(wrench, Vector3(200, 94, 250), Vector3(0, 1, 0), 180.0),
			"wrench 180 Y at (200,94,250)")


func _export_and_check(doc: SxDocument, kinds: Dictionary, name: String) -> void:
	print("- export %s" % name)
	var mf := OUT.path_join(name)
	check(doc.export_3mf(mf), "export_3mf instances")
	_write_sidecar(kinds, mf.get_basename() + ".json")
	var result := SxChecker.run("rung08", ["final", mf])
	check(int(result["code"]) == 0,
			"check_rung08.py final (got %d)\n%s" % [int(result["code"]), str(result["text"])])


func _reopen_and_reexport(ctx: FilmContext, sxp: String) -> void:
	print("- File → New Assembly, Open")
	ctx.main._do_new_assembly()
	await process_frame
	check(ctx.view.doc.kind() == "assembly", "new document is assembly")
	check(ctx.view.load_from(sxp), "open assembly.sxp")
	await process_frame
	var doc: SxDocument = ctx.view.doc
	check(doc.kind() == "assembly", "reopened kind is assembly")
	var kinds := _classify(doc)
	check(kinds["pipe"].size() == 2 and kinds["nut"].size() == 16
			and kinds["pin"].size() == 8 and kinds["wrench"].size() == 1,
			"reopened counts 2/16/8/1 (pipe %d nut %d pin %d wrench %d)" % [
				kinds["pipe"].size(), kinds["nut"].size(), kinds["pin"].size(),
				kinds["wrench"].size()])
	check(doc.instance_list().size() == 27, "27 instances (got %d)" % doc.instance_list().size())
	await _export_and_check(doc, kinds, "assembly-reopen.3mf")


func _write_sidecar(kinds: Dictionary, path: String) -> void:
	var hole_axes: Array = []
	var nut_zs: Array = []
	for i in 8:
		var xy := Vector2(94.0 * cos(deg_to_rad(90.0 + i * 45.0)),
				94.0 * sin(deg_to_rad(90.0 + i * 45.0)))
		hole_axes.append([xy.x, xy.y])
		nut_zs.append(250.0)
	for _i in 8:
		nut_zs.append(270.0)
	var data := {
		"instances": [],
		"coaxial": true,
		"joint_z": 260.0,
		"hole_axes": hole_axes,
		"nut_zs": nut_zs,
		"wrench": {
			"flange_z": 250.0,
			"jaw": 20.0,
			"gap": 20.0,
			"tangent": true,
			"handle_plus_x": true,
		},
	}
	for key in ["pipe", "nut", "pin", "wrench"]:
		for iid in kinds[key]:
			data["instances"].append({"source": key, "name": key, "id": str(iid)})
	var f := FileAccess.open(path, FileAccess.WRITE)
	check(f != null, "write sidecar %s" % path)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func _copy_n(view: DocumentView, iid: String, extra: int) -> void:
	view.select_instance(iid)
	check(view.copy_selection() >= 1, "copied instance")
	for _i in extra:
		view.paste_clipboard()


func _classify(doc: SxDocument) -> Dictionary:
	var kind_of_source := {}
	for inst in doc.instance_list():
		var path := str(inst.get("source_path", "")).to_lower()
		var name := str(inst.get("name", "")).to_lower()
		var src := str(inst.get("source_body", ""))
		var kind := ""
		if path.contains("pipe") or name.contains("pipe"):
			kind = "pipe"
		elif path.contains("nut") or name.contains("nut") or name.contains("hex"):
			kind = "nut"
		elif path.contains("wrench") or name.contains("wrench"):
			kind = "wrench"
		if kind != "" and src != "":
			kind_of_source[src] = kind
	var out := {"pipe": [], "nut": [], "pin": [], "wrench": []}
	for inst in doc.instance_list():
		var src := str(inst.get("source_body", ""))
		var id := str(inst.get("id", ""))
		var kind: String = str(kind_of_source.get(src, "pin"))
		out[kind].append(id)
	return out
