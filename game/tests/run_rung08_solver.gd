# Rung 8 WP5 — multi-mate solver: concentric + coincident in either order.
extends "res://tests/lib/sx_suite.gd"

const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung08 multi-mate solver")
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	_order(ctx, true)
	_order(ctx, false)
	ctx.main.queue_free()
	finish()


func _cyl_face(doc: SxDocument, body: String) -> String:
	for fid in doc.get_face_ids(body):
		var c: Dictionary = doc.implicit_connector("", fid)
		if c.is_empty():
			continue
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
		# Planar faces are flat in one axis; a cylinder wall spans all three.
		if ext.x > 1.0 and ext.y > 1.0 and ext.z > 1.0:
			return fid
	return ""


func _z_face(doc: SxDocument, body: String, z: float) -> String:
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


func _order(ctx: FilmContext, concentric_first: bool) -> void:
	var label := "concentric then coincident" if concentric_first else "coincident then concentric"
	print("- solver %s" % label)
	ctx.view.new_document()
	var doc: SxDocument = ctx.view.doc
	var plate: String = doc.add_box(80, 80, 10, Vector3.ZERO)
	var drill: String = doc.add_cylinder(6, 10, Vector3(40, 40, 0))
	check(doc.boolean_op(plate, drill, "cut", false), "bore plate (%s)" % label)
	var disc: String = doc.add_cylinder(12, 5, Vector3.ZERO)
	var bore: String = doc.add_cylinder(6, 5, Vector3.ZERO)
	check(doc.boolean_op(disc, bore, "cut", false), "bore washer (%s)" % label)
	var iid: String = doc.add_instance(disc, Vector3(200, 40, 50), Vector3(0, 0, 1), 0.0, "W-1")
	check(iid != "", "washer instanced")
	var hole := _cyl_face(doc, plate)
	var inner := _cyl_face(doc, disc)
	var top := _z_face(doc, plate, 10.0)
	var bot := _z_face(doc, disc, 0.0)
	check(hole != "" and inner != "" and top != "" and bot != "", "faces (%s)" % label)
	var conc: String = doc.add_mate("concentric", "", hole, iid, inner, 0.0, false, "axis")
	var coinc: String = doc.add_mate("plane_coincident", "", top, iid, bot, 0.0, false, "seat")
	if not concentric_first:
		doc.remove_mate(conc)
		doc.remove_mate(coinc)
		coinc = doc.add_mate("plane_coincident", "", top, iid, bot, 0.0, false, "seat")
		conc = doc.add_mate("concentric", "", hole, iid, inner, 0.0, false, "axis")
	check(conc != "" and coinc != "", "both mates added (%s)" % label)
	check(doc.solve_mates(), "solve (%s)" % label)
	var ca: Dictionary = doc.implicit_connector("", hole)
	var cb: Dictionary = doc.implicit_connector(iid, inner)
	var za: Vector3 = (ca.get("z_dir", Vector3.UP) as Vector3).normalized()
	var ab: Vector3 = (cb.get("origin", Vector3.ZERO) as Vector3) \
			- (ca.get("origin", Vector3.ZERO) as Vector3)
	var radial: float = (ab - za * ab.dot(za)).length()
	check(radial < 0.2, "axis through hole (%s, radial %.4f)" % [label, radial])
	var t: Vector3 = Vector3.ZERO
	for inst in doc.instance_list():
		if str(inst.get("id", "")) == iid:
			t = inst.get("translation", Vector3.ZERO)
	# Washer source bottom is at local z=50; after coincident the world bottom is z=10
	# so translation.z should be 10 - 50 = -40 if the source wasn't moved, OR
	# the instance transform puts the bottom plane on z=10.
	var cbot: Dictionary = doc.implicit_connector(iid, bot)
	check(absf(float(cbot.get("origin", Vector3.ZERO).z) - 10.0) < 0.2,
			"washer on plate (z %.2f, tz %s) %s" % [float(cbot.get("origin", Vector3.ZERO).z), str(t), label])
