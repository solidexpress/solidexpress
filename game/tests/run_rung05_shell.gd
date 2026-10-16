# Rung 5 WP3 — Shell both planar ends through strip:shell, not ops_panel._shell().
# Click-built Ø150 × 250 cylinder. Thickness 80 is the half-extent refusal.
# Run: GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only rung05_shell.suite
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const SxChecker = preload("res://tests/lib/sx_checker.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const LIMIT := "Shell thickness 80.0000 mm is at least half the 150.0000 mm extent (limit) — nothing added"
const APPLIED := "Shell 10.0000 mm applied"
## z=250 outward +Z; z=0 outward −Z. View puts that face on screen.
const ENDS: Array = [
	{"normal": Vector3(0, 0, 1), "plane": 250.0, "view": KEY_3, "shift": false},
	{"normal": Vector3(0, 0, -1), "plane": 0.0, "view": KEY_8, "shift": true},
]


func _init() -> void:
	status_echo = true
	print("rung05 shell")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	if ctx == null or ctx.main == null:
		return
	await _cylinder(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		ctx.main.queue_free()
		return
	await _pick_ends(ctx)
	if failures > 0 or FilmUI.fail_count > 0:
		ctx.main.queue_free()
		return
	await _shell_chip(ctx)
	ctx.main.queue_free()


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()
	listen_status(main)
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	return ctx


func _cylinder(ctx: FilmContext) -> void:
	await _click_front(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "Front sketch is active")
	if sm == null or not sm.active:
		return
	await _zoom(ctx, Vector3.ZERO, 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await FilmSteps.click_uv(ctx, Vector2.ZERO, "circle centre", 280.0)
	await FilmSteps.click_uv(ctx, Vector2(75, 0), "Ø150 rim", 280.0)
	await process_frame
	var circles := FilmSteps.circles(sm)
	check(circles.size() == 1, "one circle (got %d)" % circles.size())
	if circles.size() == 1:
		check((circles[0]["center"] as Vector2).distance_to(Vector2.ZERO) <= 0.2,
				"circle centre is the origin")
	await _dim_diameter(ctx, Vector2(75, 0), "150")
	await FilmSteps.type_distance(ctx, "250")
	await FilmSteps.pick_finish(ctx, 0, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button()
	check(ex != null and ex.is_visible_in_tree(), "finish:Extrude is visible")
	if ex != null:
		await FilmUI.click_control(ctx, ex, FilmUICues.alert("OK", "Extrude Blind 250"))
	for _i in 12:
		await process_frame
	var bodies: PackedStringArray = ctx.view.doc.body_ids()
	check(bodies.size() == 1, "one body after Blind 250 (got %d)" % bodies.size())
	check(str(ctx.main.status_label.text).contains("250"),
			"status Blind 250 (got '%s')" % ctx.main.status_label.text)


func _click_front(ctx: FilmContext) -> void:
	ctx.main.camera.apply_standard_view_id("front")
	await process_frame
	ctx.main.interaction.arm_pick_sketch_host()
	var pt: Vector3 = OriginPlanes.pick_point("Front")
	var screen := FilmUI.model_to_screen(ctx, pt)
	check(FilmUI.require_on_screen(ctx, screen, "Front"), "Front datum is on screen")
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click("Front"))
	await process_frame


func _pick_ends(ctx: FilmContext) -> void:
	var body := FilmSteps.only_body(ctx)
	check(body != "", "one body to pick")
	if body == "":
		return
	await SxInput.push_key(ctx.main.get_viewport(), KEY_7)
	await process_frame
	await _zoom(ctx, Vector3(0, 0, 125), 420.0)
	var mid := FilmUI.model_to_screen(ctx, Vector3(0, 0, 125))
	check(FilmUI.require_on_screen(ctx, mid, "body"), "cylinder centre is on screen")
	await FilmUI.viewport_click(ctx, mid, FilmUICues.alert("Click", "Select body"))
	await process_frame
	check(ctx.view.selected_body == body or ctx.view.selected_bodies.has(body),
			"body selected before faces")
	for row in ENDS:
		await SxInput.push_key(ctx.main.get_viewport(), row["view"] as Key)
		await FilmUI.wait_frames(ctx.tree, 6)
		var n: Vector3 = row["normal"]
		await _zoom(ctx, n * float(row["plane"]), 220.0)
		if bool(row["shift"]):
			await FilmSteps.shift_click_face(ctx, n, float(row["plane"]))
		else:
			await FilmSteps.click_face(ctx, n, float(row["plane"]))
	check(ctx.view.selected_faces.size() == 2,
			"two faces in selected_faces (got %d)" % ctx.view.selected_faces.size())


func _shell_chip(ctx: FilmContext) -> void:
	var chip := _find_auto(ctx.main, "strip:shell") as Control
	check(chip != null and chip.is_visible_in_tree(),
			"strip:shell stays visible with two planar faces")
	if chip == null or not chip.is_visible_in_tree():
		return
	var before := _feature_count(ctx)
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shell", "Open shell"))
	for _i in 3:
		await process_frame
	var field := _find_auto(ctx.main, "finish:Thickness") as LineEdit
	var ok_btn := _find_auto(ctx.main, "finish:Ok") as Button
	check(field != null and field.is_visible_in_tree(), "finish:Thickness is visible")
	check(ok_btn != null and ok_btn.is_visible_in_tree(), "finish:Ok is visible")
	if field == null or ok_btn == null:
		return
	await _type_thickness(ctx, field, "80")
	await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("OK", "Shell 80 refused"))
	for _i in 6:
		await process_frame
	check(_feature_count(ctx) == before, "thickness 80 adds no feature")
	check(str(ctx.main.status_label.text) == LIMIT,
			"thickness 80 refused (got '%s')" % ctx.main.status_label.text)
	check(field.text == "5", "field returns to 5 after refusal (got '%s')" % field.text)
	await _type_thickness(ctx, field, "10")
	await FilmUI.click_control(ctx, ok_btn, FilmUICues.alert("OK", "Shell 10"))
	for _i in 12:
		await process_frame
	check(str(ctx.main.status_label.text) == APPLIED,
			"status Shell 10 (got '%s')" % ctx.main.status_label.text)
	check(ctx.view.doc.body_ids().size() == 1, "one body after shell")
	check(_shell_face_count(ctx) == 2, "shell feature has two faces")
	var tmp := "user://rung05_shelled.3mf"
	var path := ProjectSettings.globalize_path(tmp)
	check(not path.begins_with("user://") and not path.begins_with("res://"),
			"export path is globalized")
	check(ctx.view.doc.export_3mf(path), "export_3mf shelled")
	var result := SxChecker.run("rung05", ["shelled", path])
	check(int(result["code"]) == 0,
			"check_rung05.py shelled exit 0 (got %d)\n%s" % [int(result["code"]), str(result["text"])])


func _dim_diameter(ctx: FilmContext, rim: Vector2, text: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	await FilmSteps.click_uv(ctx, rim, "Ø%s rim" % text, 280.0)
	await process_frame
	await process_frame
	var di := -1
	for i in range(sm.dimensions.size() - 1, -1, -1):
		if str(sm.dimensions[i].get("type", "")) == "diameter":
			di = i
			break
	check(di >= 0, "diameter dimension exists")
	if di < 0:
		return
	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[di])
	if lp == null:
		return
	await FilmSteps.click_uv(ctx, lp as Vector2, "Ø label", 280.0)
	await process_frame
	var ix: ViewportInteraction = ctx.main.interaction
	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension popup is visible")
	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
		return
	var line: LineEdit = ix._dim_edit_line
	await _x11_click(line)
	await _type_text(line.get_viewport(), text)
	await _push_key(line.get_viewport(), KEY_ENTER, 0)
	await process_frame


func _type_thickness(ctx: FilmContext, field: LineEdit, text: String) -> void:
	await _x11_click(field)
	await process_frame
	field.select_all()
	await _type_text(ctx.main.get_viewport(), text)
	await process_frame


func _shell_face_count(ctx: FilmContext) -> int:
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) != "shell":
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) != TYPE_DICTIONARY:
			return 0
		var faces = parsed.get("faces", [])
		return (faces as Array).size() if faces is Array else 0
	return 0


func _feature_count(ctx: FilmContext) -> int:
	return ctx.view.doc.graph_features().size()


func _find_auto(node: Node, id: String) -> Node:
	if node == null:
		return null
	if str(node.get_meta("sx_auto", "")) == id:
		return node
	for c in node.get_children():
		var hit := _find_auto(c, id)
		if hit != null:
			return hit
	return null
