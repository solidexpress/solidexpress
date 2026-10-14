# Rung 3 WP5 — Offset Entities: rail tool, Reverse inward, chip path kept.
# Click-built boss. On main there is no rail:Offset and chip Offset is free.
# Run: LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot --headless --path game --script tests/run_rung03_offset.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")
const FilmSteps = preload("res://tests/lib/film_steps.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var _status_log: Array[String] = []


func _init() -> void:
	print("rung03 offset")
	FilmUI.reset_fail_count()
	await _run()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	finish()


func _run() -> void:
	var ctx := await _boot()
	if not await _build_boss(ctx):
		ctx.main.queue_free()
		return
	if not await _open_z_face(ctx, 55.0):
		ctx.main.queue_free()
		return
	await _offset_rim(ctx)
	await _chip_offset_still_works(ctx)
	ctx.main.queue_free()


func _control_rect(controls: Array, id: String) -> Array:
	for c in controls:
		if str(c.get("id", "")) == id:
			return c.get("rect", [])
	return []


## Walk L3 covered(): a smaller visible control contains this rect's centre.
## Skips the three offset ids, matching rows03_chunk3.py.
func _covered_by(controls: Array, rect: Array) -> String:
	if rect.size() < 4:
		return "missing rect"
	var cx := float(rect[0]) + float(rect[2]) * 0.5
	var cy := float(rect[1]) + float(rect[3]) * 0.5
	var skip := ["offset:Distance", "offset:Reverse", "offset:Ok"]
	for c in controls:
		if str(c.get("id", "")) in skip:
			continue
		if c.get("blocks_mouse", true) == false:
			continue
		var other: Array = c.get("rect", [])
		if other.size() < 4:
			continue
		if float(other[0]) <= cx and cx <= float(other[0]) + float(other[2]) \
				and float(other[1]) <= cy and cy <= float(other[1]) + float(other[3]):
			if float(other[2]) * float(other[3]) < float(rect[2]) * float(rect[3]):
				return "%s id=%s rect=%s" % [str(c.get("path", "")), str(c.get("id", "")), str(other)]
	return ""


func _build_boss(ctx: FilmContext) -> bool:
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	if sm == null or not sm.active:
		return false
	await _zoom(ctx, Vector3.ZERO, 280.0)
	if not await _arm_rect_center(ctx):
		return false
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(60, 60))
	await process_frame
	if not await _extrude(ctx, "30", 0):
		return false
	if not await _open_z_face(ctx, 30.0):
		return false
	sm = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(0, 0))
	await _click_uv(ctx, ctx.main.get_viewport(), Vector2(35, 0))
	await process_frame
	if not await _extrude(ctx, "25", 2):
		return false
	var boss := _volume(ctx)
	check(absf(boss - 528211.3) < 5.0, "boss volume 528211 (got %s)" % str(boss))
	return absf(boss - 528211.3) < 5.0


func _offset_rim(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	check(absf(sm.plane_origin.z - 55.0) < 0.5, "sketch is on z=55")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.OFFSET)
	check(sm.tool == SketchMode.Tool.OFFSET, "rail Offset is armed")
	var panel: Control = ctx.main.find_child("OffsetPanel", true, false)
	check(panel != null and panel.is_visible_in_tree(), "Offset panel is visible")
	var dist: SpinBox = ctx.main.find_child("OffsetDistance", true, false)
	var rev: CheckButton = ctx.main.find_child("OffsetReverse", true, false)
	var ok: Button = ctx.main.find_child("OffsetOk", true, false)
	check(dist != null and rev != null and ok != null, "offset:Distance/Reverse/Ok exist")
	if dist == null or rev == null or ok == null:
		return
	for ctrl in [dist as Control, rev as Control, ok as Control]:
		var r: Rect2 = ctrl.get_global_rect()
		check(r.position.x >= -1.0 and r.position.y >= -1.0
				and r.end.x <= float(ROOT_SIZE.x) + 1.0
				and r.end.y <= float(ROOT_SIZE.y) + 1.0,
				"%s inside 1280×800 (%s)" % [ctrl.name, str(r)])
	var bridge = load("res://scripts/automation_bridge.gd").new()
	ctx.main.add_child(bridge)
	var controls: Array = bridge._controls()
	bridge.queue_free()
	for cid in ["offset:Distance", "offset:Reverse", "offset:Ok"]:
		var mine := _control_rect(controls, cid)
		var cover := _covered_by(controls, mine)
		print("  %s rect %s cover %s" % [cid, str(mine), cover])
		check(cover == "", "%s is not covered (by %s)" % [cid, cover])
	check(str(rev.text).contains("Reverse"), "Reverse has a visible label")
	check(str(ok.text).contains("Apply"), "Apply has a visible label")
	# Distance 0 refused.
	dist.value = 0.0
	var before := _entity_count(sm)
	var mark := _status_log.size()
	await _click_model(ctx, Vector3(35, 0, 55), "rim at distance 0")
	check(_entity_count(sm) == before, "distance 0 adds no entity")
	check(_status_since(mark).contains("distance must be greater than 0"),
			"distance 0 refused (got '%s')" % _status_since(mark))
	# Happy path: 5, Reverse, click rim.
	dist.value = 5.0
	if not rev.button_pressed:
		await FilmUI.click_control(ctx, rev, FilmUICues.alert("Reverse", "Offset Reverse"))
	check(rev.button_pressed, "Reverse is on")
	mark = _status_log.size()
	await _click_model(ctx, Vector3(35, 0, 55), "boss rim")
	var added := _status_since(mark)
	print("  offset status: %s" % added)
	var profile := _profile_circles(sm)
	var external := _external_circles(sm)
	print("  profile %d external %d" % [profile.size(), external.size()])
	check(added.contains("Offset: circle r = 30"),
			"offset status names r=30 (got '%s')" % added)
	check(profile.size() == 1, "one profile circle (got %d)" % profile.size())
	check(external.size() == 1, "one external circle (got %d)" % external.size())
	if profile.size() == 1:
		check((profile[0]["center"] as Vector2).distance_to(Vector2.ZERO) <= 0.05,
				"profile centre at origin")
		check(absf(float(profile[0]["radius"]) - 30.0) <= 0.05,
				"profile r = 30 (got %s)" % str(profile[0]["radius"]))
	if external.size() == 1:
		check(absf(float(external[0]["radius"]) - 35.0) <= 0.05,
				"external r = 35 (got %s)" % str(external[0]["radius"]))
	await process_frame
	var dof := _dof(ctx)
	print("  dof %s label '%s'" % [str(dof), "" if ctx.main.dof_label == null else str(ctx.main.dof_label.text)])
	check(dof == 0, "DOF chip is 0 after offset (got %s)" % str(dof))
	# Empty space refused; Esc disarms.
	before = _entity_count(sm)
	mark = _status_log.size()
	var empty_uv := Vector2(80, 80)
	var empty_screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(empty_uv))
	await FilmUI.viewport_click(ctx, empty_screen, FilmUICues.sketch_click("empty"))
	await process_frame
	check(_entity_count(sm) == before, "empty click adds no entity")
	check(_status_since(mark).contains("nothing there"),
			"empty click refused (got '%s')" % _status_since(mark))
	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
	await process_frame
	check(sm.tool != SketchMode.Tool.OFFSET, "Esc disarms Offset (got %s)" % str(sm.tool))
	check(panel == null or not panel.visible, "Offset panel hidden after Esc")
	# Ok closes the panel when re-armed (walk A14).
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.OFFSET)
	check(panel != null and panel.visible, "panel returns when Offset re-armed")
	await FilmUI.click_control(ctx, ok, FilmUICues.alert("OK", "Offset OK"))
	check(not panel.visible, "offset:Ok closes the panel")
	check(sm.tool == SketchMode.Tool.OFFSET, "Ok keeps Offset armed")
	check(_entity_count(sm) == before, "Ok does not change entities")


func _chip_offset_still_works(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	var ext := _external_circles(sm)
	check(not ext.is_empty(), "external circle still present for chip path")
	if ext.is_empty():
		return
	sm._set_selected([str(ext[0]["id"])])
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	chrome.show_selection_actions(sm.selection_actions(), Vector2(200, 120))
	await process_frame
	var bar: Node = chrome.find_child("ActionBar", true, false)
	var chip: Button = FilmUI.find_button(bar, "Offset") if bar != null else null
	check(chip != null and chip.is_visible_in_tree(), "chip:Offset is visible")
	if chip == null:
		return
	chrome.set_dim_value(0.01)
	var before := _entity_count(sm)
	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Offset", "chip Offset"))
	await process_frame
	check(_entity_count(sm) == before + 1, "chip Offset still produces a circle")


func _profile_circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) != "circle":
			continue
		if sm.sketch.is_external(id) or sm.sketch.is_construction(id):
			continue
		info["id"] = str(id)
		out.append(info)
	return out


func _external_circles(sm: SketchMode) -> Array:
	var out: Array = []
	if sm.sketch == null:
		return out
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if sm.sketch.is_external(id) and str(info.get("type", "")) == "circle":
			info["id"] = str(id)
			out.append(info)
	return out


func _dof(ctx: FilmContext) -> int:
	var lbl: Label = ctx.main.dof_label
	if lbl == null:
		return -1
	var t := str(lbl.text).strip_edges()
	# A solved sketch prints OK, not the digit 0.
	if t == "OK":
		return 0
	if t.is_valid_int():
		return int(t)
	for part in t.split(" "):
		if str(part).is_valid_int():
			return int(part)
	return -1


func _extrude(ctx: FilmContext, distance: String, op_index: int) -> bool:
	await FilmSteps.type_distance(ctx, distance)
	await FilmSteps.pick_finish(ctx, op_index, 0)
	var ex: Button = ctx.main.sketch_chrome.extrude_button() if ctx.main.sketch_chrome != null else null
	check(ex != null and ex.is_visible_in_tree(), "Extrude button is visible")
	if ex == null:
		return false
	await _x11_click(ex)
	for _i in 10:
		await process_frame
	var text := "" if ctx.main.status_label == null else str(ctx.main.status_label.text)
	check(text.contains("Extrude"), "extrude status (got '%s')" % text)
	return text.contains("Extrude")


func _open_z_face(ctx: FilmContext, z: float) -> bool:
	if ctx.main.sketch_mode != null and ctx.main.sketch_mode.active:
		await FilmUI.exit_sketch(ctx)
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	await process_frame
	var body := _only_body(ctx)
	check(body != "", "one body before the z=%.0f sketch" % z)
	if body == "":
		return false
	var face := _face_at_z(ctx, body, z)
	check(face != "", "face at z=%.0f" % z)
	if face == "":
		return false
	var pick := FacePick.point(ctx.view.doc, face)
	if ctx.view.selected_bodies.is_empty() and ctx.view.selected_face == "":
		await _click_model(ctx, Vector3(50, 0, 15), "select body")
	await _click_model(ctx, pick, "select z=%.0f face" % z)
	if ctx.view.selected_face != face:
		await _click_model(ctx, pick, "drill z=%.0f face" % z)
	check(ctx.view.selected_face == face, "z=%.0f face selected" % z)
	if ctx.view.selected_face != face:
		return false
	await _push_key(ctx.main.get_viewport(), KEY_3, 0)
	await process_frame
	var strip: Node = ctx.main.find_child("SelectionStrip", true, false)
	var chip := FilmUI.find_button(strip, "Sketch") if strip != null else null
	check(chip != null and chip.is_visible_in_tree(), "Sketch chip is visible")
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.toolbar_sketch()):
		return false
	for _i in 4:
		await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm.active, "face sketch is active")
	return sm.active and sm.sketch != null


func _face_at_z(ctx: FilmContext, body: String, z: float) -> String:
	var best := ""
	var best_gap := 1.0
	var want := Vector3(0, 0, 1)
	for face_id in ctx.view.doc.get_face_ids(body):
		var fid := str(face_id)
		var n := ctx.view.face_normal(body, fid)
		if n.length_squared() < 1e-8 or n.normalized().dot(want) < 0.99:
			continue
		var off := FacePick.plane_offset(n, FacePick.point(ctx.view.doc, fid))
		var gap := absf(off - z)
		if gap < best_gap:
			best_gap = gap
			best = fid
	return best


func _arm_rect_center(ctx: FilmContext) -> bool:
	var sm: SketchMode = ctx.main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	var bar: Node = ctx.main.sketch_chrome.find_child("VariantBar", true, false)
	var chip: Button = null
	if bar != null:
		for c in bar.get_children():
			var b := c as Button
			if b != null and b.text == "Center":
				chip = b
	check(chip != null and chip.is_visible_in_tree(), "Center variant chip is visible")
	if chip == null or not await FilmUI.click_control(ctx, chip, FilmUICues.alert("Center", "Center")):
		return false
	return sm.tool_variant == "center"


func _click_model(ctx: FilmContext, model: Vector3, desc: String) -> void:
	var screen := FilmUI.model_to_screen(ctx, model)
	check(FilmUI.require_on_screen(ctx, screen, desc), "%s is on screen" % desc)
	await FilmUI.viewport_click(ctx, screen, FilmUICues.sketch_click(desc))
	await process_frame


func _entity_count(sm: SketchMode) -> int:
	if sm.sketch == null:
		return 0
	return sm.sketch.entity_ids().size()


func _only_body(ctx: FilmContext) -> String:
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(ids[0])


func _volume(ctx: FilmContext) -> float:
	var body := _only_body(ctx)
	if body == "":
		return -1.0
	return float(ctx.view.doc.measure_mass(body).get("volume", -1.0))


func _status_since(mark: int) -> String:
	if mark >= _status_log.size():
		return ""
	return " | ".join(_status_log.slice(mark))


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800")
	if main.sketch_mode != null:
		main.sketch_mode.status.connect(_on_status_local)
	if main.interaction != null:
		main.interaction.status.connect(_on_status_local)
	return ctx


func _on_status_local(text: String) -> void:
	if text == "":
		return
	_status_log.append(text)
	print("  status: " + text)
