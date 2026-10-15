# Rung 4 WP5 — Front, Top, Right on a new part. Front sketches like the ground.
# Click-built. Right uses the BASIS row, not the stored datum x_dir.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_planes.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")


func _init() -> void:
	print("rung04 planes")
	FilmUI.reset_fail_count()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	await FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))
	await _planes(ctx)
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _planes(ctx: FilmContext) -> void:
	ctx.view.new_document()
	await process_frame
	var names := _plane_names(ctx.view)
	check(names == ["Front", "Right", "Top"], "origin planes Front, Top, Right (got %s)" % str(names))
	var origin_hit := OriginPlanes.ray_hit(ctx.view, Vector3(40, 40, 40), Vector3(-1, -1, -1))
	check(origin_hit == "", "origin ray is a miss, not a datum (got %s)" % origin_hit)
	var right_hit := OriginPlanes.ray_hit(ctx.view, Vector3(40, 10, 10), Vector3(-1, 0, 0))
	check(right_hit == "Right", "unique Right quad (got %s)" % right_hit)
	var top_hit := OriginPlanes.ray_hit(ctx.view, Vector3(10, 40, 10), Vector3(0, -1, 0))
	check(top_hit == "Top", "unique Top quad (got %s)" % top_hit)
	await _click_datum(ctx, "Front", "front")
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "Front click started a sketch")
	check(str(ctx.main.status_label.text) == "Sketch on ground (XY)",
			"Front uses the ground status (%s)" % ctx.main.status_label.text)
	check(not str(ctx.main.status_label.text).contains("Sketch on plane"),
			"Front is not a plane-sketch status")
	await _exit(ctx)
	await _click_datum(ctx, "Right", "right")
	sm = ctx.main.sketch_mode
	check(sm.active, "Right click started a sketch")
	var p37: Vector3 = sm.to_model(Vector2(37, 0))
	var p94: Vector3 = sm.to_model(Vector2(0, 94))
	check(p37.distance_to(Vector3(0, 0, 37)) <= 0.01,
			"UV (37,0) is world (0,0,37) (got %s)" % str(p37))
	check(p94.distance_to(Vector3(0, 94, 0)) <= 0.01,
			"UV (0,94) is world (0,94,0) (got %s)" % str(p94))
	await _exit(ctx)
	ctx.main.camera.apply_standard_view_id("top")
	await process_frame
	ctx.main.interaction.arm_pick_sketch_host()
	await FilmUI.viewport_click(ctx, Vector2(1100, 700), FilmUICues.sketch_click("Miss the quads"))
	sm = ctx.main.sketch_mode
	check(sm.active, "a miss still starts a sketch")
	check(str(ctx.main.status_label.text) == "Sketch on ground (XY)",
			"a miss starts the ground sketch (%s)" % ctx.main.status_label.text)


func _click_datum(ctx: FilmContext, plane_name: String, view_id: String) -> void:
	ctx.main.camera.apply_standard_view_id(view_id)
	await process_frame
	ctx.main.interaction.arm_pick_sketch_host()
	var pt: Vector3 = OriginPlanes.pick_point(plane_name)
	await _click_world(ctx, pt, plane_name)
	await process_frame


func _click_world(ctx: FilmContext, pt: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, pt)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))


func _exit(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if not sm.active:
		return
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	if exit_btn != null:
		await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
		await process_frame
	var dlg: ConfirmationDialog = ctx.main._empty_sketch_dialog
	if dlg != null and dlg.visible:
		await FilmUI.click_control(ctx, dlg.get_ok_button(), FilmUICues.alert("OK", "Discard empty sketch"))
		await process_frame
		await process_frame


func _plane_names(view: DocumentView) -> Array:
	var names: Array[String] = []
	for d in view.doc.datum_list():
		if str(d.get("kind", "")) == "plane":
			names.append(str(d.get("name", "")))
	names.sort()
	return names
