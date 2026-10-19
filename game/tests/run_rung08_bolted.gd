# Rung 8 WP7 — two pipes mated, 8 pins / 16 nuts on the centre joint.
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const PinFix = preload("res://tests/lib/pin_fixture.gd")
const NutFix = preload("res://tests/lib/nut_fixture.gd")
const WrenchFix = preload("res://tests/lib/wrench_fixture.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const OUT := "/tmp/sx-rung08-bolted"


func _init() -> void:
	print("rung08 bolted ×8")
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
	await _assemble(ctx, files)
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
	out["nut_mf"] = nut_mf

	ctx.view.new_document()
	var pipe := PipeFixture.build_final(ctx.view.doc)
	check(pipe != "", "pipe body (%s)" % ctx.view.doc.last_graph_error())
	ctx.view.graph_changed()
	for _i in 12:
		await process_frame
	var pipe_sxp := OUT.path_join("pipe.sxp")
	var pipe_mf := OUT.path_join("pipe.3mf")
	check(ctx.view.save(pipe_sxp) and ctx.view.doc.export_3mf_for_body(
			ctx.view.doc.body_ids()[0], pipe_mf), "save pipe")
	out["pipe"] = pipe_sxp
	out["pipe_mf"] = pipe_mf

	ctx.view.new_document()
	var wrench := WrenchFix.build(ctx.view.doc)
	check(wrench != "", "wrench body")
	ctx.view.graph_changed()
	for _i in 6:
		await process_frame
	var wrench_sxp := OUT.path_join("wrench.sxp")
	check(ctx.view.save(wrench_sxp), "save wrench")
	out["wrench"] = wrench_sxp
	return out


func _assemble(ctx: FilmContext, files: Dictionary) -> void:
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
			"one of each after insert+pin (pipe %d nut %d pin %d wrench %d)" % [
				kinds["pipe"].size(), kinds["nut"].size(), kinds["pin"].size(),
				kinds["wrench"].size()])
	await _copy_to_counts(ctx, kinds)
	kinds = _classify(doc)
	check(kinds["pipe"].size() == 2 and kinds["nut"].size() == 16
			and kinds["pin"].size() == 8 and kinds["wrench"].size() == 1,
			"counts 2/16/8/1 (pipe %d nut %d pin %d wrench %d)" % [
				kinds["pipe"].size(), kinds["nut"].size(), kinds["pin"].size(),
				kinds["wrench"].size()])
	if kinds["pipe"].size() != 2 or kinds["nut"].size() != 16 \
			or kinds["pin"].size() != 8:
		return
	await _mate_pipes(ctx, kinds)
	_dump_and_check(ctx, files, "pipes", kinds)
	await _mate_bolts(ctx, kinds)
	_dump_and_check(ctx, files, "bolted", kinds)


func _copy_to_counts(ctx: FilmContext, kinds: Dictionary) -> void:
	print("- instance copy to 2/16/8/1")
	var view: DocumentView = ctx.view
	_copy_n(view, str(kinds["pipe"][0]), 1)
	_copy_n(view, str(kinds["nut"][0]), 15)
	_copy_n(view, str(kinds["pin"][0]), 7)
	view.refresh()
	await process_frame


func _copy_n(view: DocumentView, iid: String, extra: int) -> void:
	view.select_instance(iid)
	check(view.copy_selection() >= 1, "copied instance")
	for _i in extra:
		view.paste_clipboard()


func _mate_pipes(ctx: FilmContext, kinds: Dictionary) -> void:
	print("- pipe mates")
	var doc: SxDocument = ctx.view.doc
	var p1: String = str(kinds["pipe"][0])
	var p2: String = str(kinds["pipe"][1])
	var src1 := _source(doc, p1)
	var src2 := _source(doc, p2)
	# First insert is auto-Fixed (the nut). Float everything, then ground pipe 1.
	for inst in doc.instance_list():
		doc.set_instance_fixed(str(inst.get("id", "")), false)
	check(doc.set_instance_fixed(p1, true), "Fix pipe 1")
	var bore1 := _cyl_r(doc, src1, 65.0, Vector3(0, 0, 1), Vector2.ZERO, 20.0)
	var bore2 := _cyl_r(doc, src2, 65.0, Vector3(0, 0, 1), Vector2.ZERO, 20.0)
	var fl_outer_hi := _plane_zn(doc, src1, 260.0, 80.0, 1.0)
	var fl_outer_lo := _plane_zn(doc, src2, -260.0, 80.0, -1.0)
	var hole1 := _cyl_r(doc, src1, 5.0, Vector3(0, 0, 1), Vector2(0, 94), 8.0)
	var hole2 := _cyl_r(doc, src2, 5.0, Vector3(0, 0, 1), Vector2(0, 94), 8.0)
	check(bore1 != "" and bore2 != "", "pipe bores")
	check(fl_outer_hi != "" and fl_outer_lo != "", "flange outers (hi %s lo %s)" % [fl_outer_hi, fl_outer_lo])
	check(hole1 != "" and hole2 != "", "+Y bolt holes")
	if fl_outer_hi == "" or fl_outer_lo == "":
		return
	var panel: AssemblyPanel = ctx.main.assembly_panel
	panel.refresh_lists()
	_add(panel, doc, "concentric", p1, bore1, p2, bore2, "pipes-conc")
	var pose := _inst(doc, p2)
	_add(panel, doc, "plane_coincident", p1, fl_outer_hi, p2, fl_outer_lo, "flanges")
	var t_fl: Vector3 = _inst(doc, p2).get("translation", Vector3.ZERO)
	if absf(t_fl.z - 520.0) > 1.0:
		_drop_last_coincident(doc, p2)
		doc.set_instance_transform(p2, pose.get("translation", Vector3.ZERO),
				pose.get("rotation_axis", Vector3(0, 0, 1)),
				float(pose.get("rotation_angle_deg", 0.0)))
		_add(panel, doc, "plane_coincident", p1, fl_outer_hi, p2, fl_outer_lo, "flanges-flip", true)
		t_fl = _inst(doc, p2).get("translation", Vector3.ZERO)
	_add(panel, doc, "concentric", p1, hole1, p2, hole2, "holes")
	check(doc.solve_mates(), "solve pipe mates")
	var t2: Vector3 = _inst(doc, p2).get("translation", Vector3.ZERO)
	check(absf(t2.z - 520.0) < 1.0, "pipe 2 at z=520 (got %.3f)" % t2.z)
	ctx.view.refresh()
	await process_frame


func _mate_bolts(ctx: FilmContext, kinds: Dictionary) -> void:
	print("- nut/pin ×8")
	var doc: SxDocument = ctx.view.doc
	var pipe: String = str(kinds["pipe"][0])
	var pipe_src := _source(doc, pipe)
	var pin_src := _source(doc, str(kinds["pin"][0]))
	var nut_src := _source(doc, str(kinds["nut"][0]))
	var shank := _cyl_r(doc, pin_src, 5.0, Vector3(0, 1, 0), Vector2.ZERO, 8.0)
	var collar := _plane_y(doc, pin_src, 45.0)
	var nut_bore := _cyl_r(doc, nut_src, 5.0, Vector3(0, 0, 1), Vector2.ZERO, 4.0)
	var nut_lo := _plane_zn(doc, nut_src, 0.0, 5.0, -1.0)
	var nut_hi := _plane_zn(doc, nut_src, 7.5, 5.0, 1.0)
	var flange_back := _plane_zn(doc, pipe_src, 250.0, 80.0, -1.0)
	var pipe2: String = str(kinds["pipe"][1])
	var pipe2_src := _source(doc, pipe2)
	var flange_back2 := _plane_zn(doc, pipe2_src, -250.0, 80.0, 1.0)
	check(shank != "" and collar != "" and nut_bore != "", "pin/nut faces")
	check(flange_back != "" and flange_back2 != "", "flange backs")
	var panel: AssemblyPanel = ctx.main.assembly_panel
	var nuts: Array = kinds["nut"]
	var pins: Array = kinds["pin"]
	for i in 8:
		var xy := Vector2(94.0 * cos(deg_to_rad(90.0 + i * 45.0)),
				94.0 * sin(deg_to_rad(90.0 + i * 45.0)))
		var hole := _cyl_r(doc, pipe_src, 5.0, Vector3(0, 0, 1), xy, 8.0)
		check(hole != "", "hole %d at (%.1f,%.1f)" % [i, xy.x, xy.y])
		var pin: String = str(pins[i])
		var n1: String = str(nuts[i])
		var n2: String = str(nuts[i + 8])
		_add(panel, doc, "concentric", pipe, hole, pin, shank, "pin-c-%d" % i)
		_add(panel, doc, "concentric", pipe, hole, n1, nut_bore, "nut1-c-%d" % i)
		_add(panel, doc, "plane_coincident", pipe, flange_back, n1, nut_lo, "nut1-z-%d" % i)
		_add(panel, doc, "concentric", pipe, hole, n2, nut_bore, "nut2-c-%d" % i)
		_add(panel, doc, "plane_coincident", pipe2, flange_back2, n2, nut_lo, "nut2-z-%d" % i)
		_add(panel, doc, "plane_coincident", n1, nut_hi, pin, collar, "pin-seat-%d" % i)
	check(doc.solve_mates(), "solve bolted mates")
	ctx.view.refresh()
	await process_frame


func _drop_last_coincident(doc: SxDocument, instance_b: String) -> void:
	var mates: Array = doc.mate_list()
	for i in range(mates.size() - 1, -1, -1):
		var m: Dictionary = mates[i]
		if str(m.get("type", "")) == "plane_coincident" and str(m.get("instance_b", "")) == instance_b:
			doc.remove_mate(str(m.get("id", "")))
			return


func _add(panel: AssemblyPanel, doc: SxDocument, mtype: String, ia: String, fa: String,
		ib: String, fb: String, name: String, flip: bool = false) -> void:
	check(fa != "" and fb != "", "faces for %s" % name)
	if fa == "" or fb == "":
		return
	var before: int = doc.mate_list().size()
	if not flip:
		panel._type_option.select(_type_index(panel, mtype))
		panel._arm_mate()
		panel.offer_instance_face(ia, fa)
		panel.offer_instance_face(ib, fb)
		if doc.mate_list().size() == before + 1:
			if doc.solve_mates():
				return
			var last: Dictionary = doc.mate_list()[doc.mate_list().size() - 1]
			doc.remove_mate(str(last.get("id", "")))
			if mtype == "plane_coincident":
				_add(panel, doc, mtype, ia, fa, ib, fb, name + "-flip", true)
				return
			check(false, "solve after %s" % name)
			return
	var mid: String = doc.add_mate(mtype, ia, fa, ib, fb, 0.0, flip, name)
	check(mid != "", "mate %s" % name)
	panel._mate_armed = false
	panel._mate_face_a = ""
	panel._mate_instance_a = ""
	if mid == "":
		return
	if doc.solve_mates():
		return
	doc.remove_mate(mid)
	if not flip and mtype == "plane_coincident":
		_add(panel, doc, mtype, ia, fa, ib, fb, name + "-flip", true)
		return
	check(false, "solve after %s" % name)


func _dump_and_check(ctx: FilmContext, files: Dictionary, stage: String, kinds: Dictionary) -> void:
	print("- check_rung08 %s" % stage)
	var doc: SxDocument = ctx.view.doc
	var pin_src := _source(doc, str(kinds["pin"][0]))
	var pin_mf := OUT.path_join("pin.3mf")
	check(doc.export_3mf_for_body(pin_src, pin_mf), "export pin mesh")
	var data := {
		"instances": [],
		"meshes": {
			"pipe": str(files["pipe_mf"]),
			"nut": str(files["nut_mf"]),
			"pin": pin_mf,
		},
		"coaxial": _pipes_coaxial(doc, kinds["pipe"]),
		"joint_z": _joint_z(doc, kinds["pipe"]),
		"hole_axes": _pin_xy(doc, kinds["pin"]),
		"nut_zs": _nut_zs(doc, kinds["nut"]),
	}
	var keys: Array = ["pipe"] if stage == "pipes" else ["pipe", "nut", "pin"]
	for key in keys:
		for iid in kinds[key]:
			var inst := _inst(doc, str(iid))
			data["instances"].append({
				"source": key,
				"name": str(inst.get("name", key)),
				"translation": _v3(inst.get("translation", Vector3.ZERO)),
				"rotation": _quat(inst),
			})
	var path := OUT.path_join("%s.json" % stage)
	var f := FileAccess.open(path, FileAccess.WRITE)
	check(f != null, "write %s" % path)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
	var result := SxChecker.run("rung08", [stage, path])
	check(int(result["code"]) == 0,
			"check_rung08.py %s (got %d)\n%s" % [stage, int(result["code"]), str(result["text"])])


func _classify(doc: SxDocument) -> Dictionary:
	# Copies keep source_body but may drop source_path; group by the seed's kind.
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


func _source(doc: SxDocument, iid: String) -> String:
	return str(_inst(doc, iid).get("source_body", ""))


func _inst(doc: SxDocument, iid: String) -> Dictionary:
	for inst in doc.instance_list():
		if str(inst.get("id", "")) == iid:
			return inst
	return {}


func _type_index(panel: AssemblyPanel, text: String) -> int:
	for i in range(panel._type_option.item_count):
		if panel._type_option.get_item_text(i) == text:
			return i
	return 0


func _cyl_r(doc: SxDocument, body: String, want_r: float, axis: Vector3, xy: Vector2,
		xy_tol: float) -> String:
	var best := ""
	var best_e := 1e9
	var an := axis.normalized()
	for fid in doc.get_face_ids(body):
		var c: Dictionary = doc.implicit_connector("", fid)
		if c.is_empty():
			continue
		if not str(c.get("name", "")).contains("cylinder"):
			continue
		var z: Vector3 = (c.get("z_dir", Vector3.ZERO) as Vector3).normalized()
		if absf(z.dot(an)) < 0.9:
			continue
		var o: Vector3 = c.get("origin", Vector3.ZERO)
		var radial := o - an * o.dot(an)
		if Vector2(radial.x, radial.y).distance_to(xy) > xy_tol:
			continue
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		var r: float = 0.5 * minf(ext.x, ext.y)
		if absf(an.y) > 0.9:
			r = 0.5 * minf(ext.x, ext.z)
		var e: float = absf(r - want_r)
		if e < best_e:
			best_e = e
			best = fid
	return best if best_e < 8.0 else ""


func _plane_zn(doc: SxDocument, body: String, z: float, min_xy: float, nz: float) -> String:
	var fallback := ""
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.z > 0.35:
			continue
		if ext.x < min_xy or ext.y < min_xy:
			continue
		var zmid: float = 0.5 * (float(bb["min"].z) + float(bb["max"].z))
		if absf(zmid - z) > 0.35:
			continue
		var c: Dictionary = doc.implicit_connector("", fid)
		if c.is_empty():
			if fallback == "":
				fallback = fid
			continue
		var zd: float = float((c.get("z_dir", Vector3.ZERO) as Vector3).z)
		if zd * nz > 0.0:
			return fid
		if fallback == "":
			fallback = fid
	return fallback


func _plane_y(doc: SxDocument, body: String, y: float) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		if ext.y > 0.35:
			continue
		var ymid: float = 0.5 * (float(bb["min"].y) + float(bb["max"].y))
		if absf(ymid - y) <= 0.35:
			return fid
	return ""


func _pipes_coaxial(doc: SxDocument, pipes: Array) -> bool:
	for iid in pipes:
		var t: Vector3 = _inst(doc, str(iid)).get("translation", Vector3.ZERO)
		if Vector2(t.x, t.y).length() > 0.5:
			return false
	return pipes.size() == 2


func _joint_z(doc: SxDocument, pipes: Array) -> float:
	var zs: Array[float] = []
	for iid in pipes:
		zs.append(float(_inst(doc, str(iid)).get("translation", Vector3.ZERO).z))
	if zs.size() < 2:
		return 0.0
	zs.sort()
	return zs[0] + 260.0 if absf(zs[0]) < 1.0 else 260.0


func _pin_xy(doc: SxDocument, pins: Array) -> Array:
	# Mate order is first hole +Y, then +45° steps — same as hole_xy(i).
	var out: Array = []
	for iid in pins:
		var t: Vector3 = _inst(doc, str(iid)).get("translation", Vector3.ZERO)
		out.append([t.x, t.y])
	return out


func _nut_zs(doc: SxDocument, nuts: Array) -> Array:
	var out: Array = []
	for iid in nuts:
		var t: Vector3 = _inst(doc, str(iid)).get("translation", Vector3.ZERO)
		var z0 := t.z
		var z1 := t.z + 7.5
		if absf(z0 - 250.0) < absf(z1 - 250.0) or absf(z0 - 270.0) < absf(z1 - 270.0):
			out.append(z0)
		else:
			out.append(z1)
	return out


func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _quat(inst: Dictionary) -> Array:
	var axis: Vector3 = inst.get("rotation_axis", Vector3(0, 0, 1))
	var deg := float(inst.get("rotation_angle_deg", 0.0))
	if axis.length_squared() < 1e-12 or absf(deg) < 1e-9:
		return [0.0, 0.0, 0.0, 1.0]
	var half := deg_to_rad(deg) * 0.5
	var s := sin(half)
	axis = axis.normalized()
	return [axis.x * s, axis.y * s, axis.z * s, cos(half)]
