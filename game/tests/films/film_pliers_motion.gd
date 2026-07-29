extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Demo: needle-nose pliers MVP — two jaws + pin, mates leave a revolute DOF,
## drag opens the pliers. Geometry/mates match run_pliers_motion_tests.gd;
## pacing uses wait_frames so Movie Maker (--fixed-fps) records full length.


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


func _planar_face_z(doc: SxDocument, body: String, z: float) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if bb.is_empty():
			continue
		if absf(bb["min"].z - z) < 0.2 and absf(bb["max"].z - z) < 0.2:
			return fid
	return ""


func _hold(ctx: FilmContext, caption: String, frames: int) -> void:
	if ctx.chrome != null:
		ctx.chrome.show_caption(caption)
	await FilmUI.wait_frames(ctx.tree, maxi(frames, 1))


func _apply_revolute(view: DocumentView, vi: ViewportInteraction, jaw_id: String,
		start_xform: Transform3D, axis_pt: Vector3, axis_dir: Vector3, deg: float) -> void:
	var inode = view.instance_node(jaw_id)
	if inode == null:
		return
	var ang := deg_to_rad(deg)
	inode.transform = Transform3D(
		Basis(Quaternion(axis_dir, ang)) * start_xform.basis,
		vi._rotate_point_about_axis(start_xform.origin, axis_pt, axis_dir, ang))
	var rot: Array = vi._instance_rotation_from_xform(inode.transform)
	view.doc.set_instance_transform(jaw_id, inode.transform.origin, rot[0], rot[1])
	view.doc.solve_mates()
	view.refresh()


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var vi: ViewportInteraction = ctx.main.interaction
	var doc: SxDocument = view.doc
	var cam = ctx.main.camera

	await ctx.movie_toast("Needle-nose pliers — mate jaws to a pin, then drag to open", 0.05)
	await _hold(ctx, "Needle-nose pliers — mate jaws to a pin, then drag to open", 100)

	await _hold(ctx, "Pin + jaw blank with a through-bore", 36)
	view.new_document()
	doc = view.doc
	var pin: String = doc.add_cylinder(3, 24, Vector3.ZERO)
	var jaw: String = doc.add_box(50, 14, 8, Vector3(120, 0, 0))
	var bore: String = doc.add_cylinder(3.2, 20, Vector3(120, 0, -5))
	if not doc.boolean_op(jaw, bore, "cut", false):
		FilmUI._fail("jaw bore failed")
		await _hold(ctx, "Jaw bore failed", 60)
		return
	view.refresh()
	await FilmUI.wait_frames(ctx.tree, 4)
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(60, 0, 4)
		cam.distance = 160.0
		cam.set_view(deg_to_rad(-28.0), deg_to_rad(40.0), false)
	await _hold(ctx, "Pin and bored jaw ready", 48)

	await _hold(ctx, "Instance both jaws on the pin", 40)
	var jaw_a: String = doc.add_instance(jaw, Vector3(30, 0, 4), Vector3(0, 0, 1), -12.0, "Jaw-A")
	var jaw_b: String = doc.add_instance(jaw, Vector3(30, 0, 4), Vector3(0, 0, 1), 12.0, "Jaw-B")
	view.refresh()
	await FilmUI.wait_frames(ctx.tree, 4)
	var pin_face := _cyl_face(doc, pin)
	var hole_face := _cyl_face(doc, jaw)
	var jaw_bottom := _planar_face_z(doc, jaw, 0.0)
	var jaw_top := _planar_face_z(doc, jaw, 8.0)
	if pin_face == "" or hole_face == "" or jaw_bottom == "" or jaw_top == "":
		FilmUI._fail("missing faces for pliers mates")
		await _hold(ctx, "Mate faces missing", 60)
		return

	await _hold(ctx, "Concentric + coincident mates leave a revolute DOF", 50)
	# Radial tolerance 0.2 mm (hole − pin); axial face gap 0.5 mm (no kissing jaws).
	if doc.add_mate("concentric", "", pin_face, jaw_a, hole_face, 0.2, false, "A-pin") == "":
		FilmUI._fail("concentric A failed")
		return
	if doc.add_mate("concentric", "", pin_face, jaw_b, hole_face, 0.2, false, "B-pin") == "":
		FilmUI._fail("concentric B failed")
		return
	if doc.add_mate("plane_coincident", jaw_a, jaw_top, jaw_b, jaw_bottom, 0.5, false, "faces") == "":
		FilmUI._fail("plane_coincident failed")
		return
	if not doc.solve_mates():
		FilmUI._fail("solve_mates failed")
		return
	view.refresh()
	await FilmUI.wait_frames(ctx.tree, 4)

	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(20, 0, 4)
		cam.distance = 110.0
		cam.set_view(deg_to_rad(-32.0), deg_to_rad(48.0), false)
		await FilmUI.wait_frames(ctx.tree, 4)

	var ax_b: Dictionary = doc.instance_revolute_axis(jaw_b)
	if not bool(ax_b.get("ok", false)):
		FilmUI._fail("Jaw-B has no revolute axis")
		await _hold(ctx, "No revolute DOF", 60)
		return

	await _hold(ctx, "Drag a jaw — it rotates about the pin", 40)
	var inode = view.instance_node(jaw_b)
	if inode == null:
		FilmUI._fail("Jaw-B node missing")
		return
	var start_xform: Transform3D = inode.transform
	var axis_pt: Vector3 = ax_b["point"]
	var axis_dir: Vector3 = (ax_b["dir"] as Vector3).normalized()
	var tip_local := Vector3(45, 0, 4)

	var tip0: Vector3 = start_xform * tip_local
	var screen0 := FilmUI.model_to_screen(ctx, tip0)
	if ctx.chrome != null and FilmUI.is_on_screen(ctx, screen0):
		await ctx.chrome.animate_pointer_click(screen0, "Drag", "Open Jaw-B about the pin")

	for step in 48:
		var t: float = float(step) / 47.0
		var deg: float = lerpf(0.0, 50.0, t)
		_apply_revolute(view, vi, jaw_b, start_xform, axis_pt, axis_dir, deg)
		await FilmUI.wait_frames(ctx.tree, 2)

	await _hold(ctx, "Open — mates hold the pin axis", 48)

	await _hold(ctx, "Close again", 30)
	inode = view.instance_node(jaw_b)
	if inode != null:
		start_xform = inode.transform
		ax_b = doc.instance_revolute_axis(jaw_b)
		axis_pt = ax_b["point"]
		axis_dir = (ax_b["dir"] as Vector3).normalized()
		for step in 36:
			var t2: float = float(step) / 35.0
			var deg2: float = lerpf(0.0, -32.0, t2)
			_apply_revolute(view, vi, jaw_b, start_xform, axis_pt, axis_dir, deg2)
			await FilmUI.wait_frames(ctx.tree, 2)

	await _hold(ctx, "Assemblies with motion — pliers demo", 50)
	if cam != null and cam.has_method("set_view"):
		cam.pivot = Vector3(18, 0, 4)
		cam.distance = 100.0
	# Frame-based orbit (avoid tween timers under Movie Maker).
	if cam != null:
		var yaw0: float = cam.yaw
		for step in 90:
			var t3: float = float(step) / 89.0
			cam.yaw = yaw0 + deg_to_rad(lerpf(0.0, 55.0, t3))
			cam.pitch = deg_to_rad(lerpf(-32.0, -34.0, t3))
			if cam.has_method("_update_transform"):
				cam._update_transform()
			await FilmUI.wait_frames(ctx.tree, 1)
