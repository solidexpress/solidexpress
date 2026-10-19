# Rung 8 WP5 — component copy: box-select instance, Ctrl+C / Ctrl+V.
extends "res://tests/lib/sx_suite.gd"

const ROOT_SIZE := Vector2i(1280, 800)


func _init() -> void:
	print("rung08 component copy")
	var ctx := await PipeFixture.boot(self, ROOT_SIZE)
	if ctx == null or ctx.main == null:
		check(false, "boot")
		finish()
		return
	listen_status(ctx.main)
	await _copy_to_eight(ctx)
	_empty_copy_refuses(ctx)
	_part_body_copy_unchanged(ctx)
	ctx.main.queue_free()
	finish()


func _copy_to_eight(ctx: FilmContext) -> void:
	print("- Ctrl+C/V seven times → 8 nuts")
	ctx.main._do_new_assembly()
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc
	var src: String = doc.add_cylinder(10, 8, Vector3.ZERO)
	view.set_body_hidden(src, true)
	var seed: String = doc.add_instance(src, Vector3(0, 0, 0), Vector3(0, 0, 1), 0.0, "Nut-1")
	check(seed != "", "seed instance")
	view.refresh()
	await process_frame
	view.select_instance(seed)
	root.size = ROOT_SIZE
	ctx.main.interaction.size = Vector2(ROOT_SIZE)
	ctx.main.camera.frame_contents()
	await process_frame

	var ke := InputEventKey.new()
	ke.keycode = KEY_C
	ke.ctrl_pressed = true
	ke.pressed = true
	check(ctx.main.interaction._gui_key(ke), "Ctrl+C handled")
	check(view.copy_selection() >= 1 or view.has_clipboard(), "clipboard has the instance")
	# First Ctrl+C already copied; keep the snapshot and paste seven times.
	for i in range(7):
		var pv := InputEventKey.new()
		pv.keycode = KEY_V
		pv.ctrl_pressed = true
		pv.pressed = true
		ctx.main.interaction._gui_key(pv)
	check(doc.instance_list().size() == 8, "8 instances after 7 pastes (got %d)" % doc.instance_list().size())
	var fixed_copies := 0
	for inst in doc.instance_list():
		if str(inst.get("id", "")) == seed:
			continue
		if bool(inst.get("fixed", false)):
			fixed_copies += 1
	check(fixed_copies == 0, "copies are not Fixed")
	check(doc.mate_list().is_empty(), "mates were not copied")

	# Box-select the copies. Frame the spread: Frame/F only sees bodies, so
	# pull the camera back onto the pasted row (0 … 210 mm).
	view.refresh()
	ctx.main.camera.pivot = Vector3(105, 0, 4)
	ctx.main.camera.distance = 280
	ctx.main.camera._update_transform()
	await process_frame
	var vp_r: Rect2 = ctx.main.get_viewport().get_visible_rect()
	view.select_in_rect(vp_r, ctx.main.camera, ctx.main.model_space, false, true)
	check(view.selected_instances.size() >= 2,
			"box-select names instances (got %d)" % view.selected_instances.size())


func _empty_copy_refuses(ctx: FilmContext) -> void:
	print("- empty copy refuses")
	ctx.view.clear_selection()
	var n: int = ctx.view.copy_selection()
	check(n == 0, "empty copy returns 0")
	var ke := InputEventKey.new()
	ke.keycode = KEY_C
	ke.ctrl_pressed = true
	ke.pressed = true
	ctx.main.interaction._gui_key(ke)
	check(str(ctx.main.status_label.text).contains("Copy needs a selection"),
			"status Copy needs a selection (got %s)" % ctx.main.status_label.text)


func _part_body_copy_unchanged(ctx: FilmContext) -> void:
	print("- part body Ctrl+C/V unchanged")
	ctx.view.new_document()
	var view: DocumentView = ctx.view
	var body: String = view.doc.add_box(20, 20, 10, Vector3.ZERO)
	view.refresh()
	view.select_entity(body, "")
	check(view.copy_selection() == 1, "copied one body")
	var made: Array = view.paste_clipboard()
	check(made.size() == 1, "pasted one body")
	check(view.doc.body_ids().size() == 2, "part now has two bodies")
	check(view.doc.instance_list().is_empty(), "part paste is not an instance")
