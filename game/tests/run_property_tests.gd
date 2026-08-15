# Headless tests for the schema-driven feature PropertyPanel: typed fields,
# live preview via graph_set_params, OK/Cancel semantics.
# Run: tools/godot/godot --headless --path game --script tests/run_property_tests.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("property panel tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_open_and_fields(main)
	test_live_preview_and_ok(main)
	test_cancel_restores(main)
	test_expression_field(main)
	test_json_editor_still_works(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _panel(main) -> PropertyPanel:
	return main.timeline.property_panel


func _spin_for(panel: PropertyPanel, label: String) -> SpinBox:
	for row in panel._fields.get_children():
		var lbl := row.get_child(0) as Label
		if lbl != null and lbl.text == label and row.get_child_count() > 1:
			return row.get_child(1) as SpinBox
	return null


func test_open_and_fields(main) -> void:
	print("- open builds typed fields")
	var view: DocumentView = main.view
	view.new_document()
	var fid: String = view.doc.graph_add_primitive("box", 40, 30, 20, Vector3.ZERO)
	view.graph_changed()
	var panel := _panel(main)
	main.timeline._select_feature(fid)
	check(panel.visible, "panel opens for primitive")
	check(_spin_for(panel, "W") != null, "W field built")
	check(_spin_for(panel, "W").value == 40.0, "field shows current value")
	check(PropertyPanel.has_schema("extrude"), "extrude has schema")
	check(not PropertyPanel.has_schema("sketch"), "sketch has no schema")


func test_live_preview_and_ok(main) -> void:
	print("- live preview + OK keeps edits")
	var view: DocumentView = main.view
	view.new_document()
	var fid: String = view.doc.graph_add_primitive("box", 40, 30, 20, Vector3.ZERO)
	view.graph_changed()
	var body := view.body_of_feature(fid)
	var panel := _panel(main)
	main.timeline._select_feature(fid)
	var spin := _spin_for(panel, "W")
	spin.value = 80.0  # value_changed fires -> live regen
	check(absf(view.doc.body_volume(body) - 48000.0) < 1.0,
		"live preview regenerated (80x30x20)")
	panel.commit()
	check(not panel.visible, "panel closes on OK")
	check(absf(view.doc.body_volume(body) - 48000.0) < 1.0, "OK keeps the edit")


func test_cancel_restores(main) -> void:
	print("- cancel undoes previewed edits")
	var view: DocumentView = main.view
	view.new_document()
	var fid: String = view.doc.graph_add_primitive("box", 40, 30, 20, Vector3.ZERO)
	view.graph_changed()
	var body := view.body_of_feature(fid)
	var panel := _panel(main)
	main.timeline._select_feature(fid)
	var spin := _spin_for(panel, "W")
	spin.value = 100.0
	spin.value = 120.0
	check(absf(view.doc.body_volume(body) - 72000.0) < 1.0, "two previews applied")
	panel.cancel_edits()
	check(not panel.visible, "panel closes on cancel")
	check(absf(view.doc.body_volume(body) - 24000.0) < 1.0,
		"cancel restored original 40x30x20 (vol %.0f)" % view.doc.body_volume(body))


func test_expression_field(main) -> void:
	print("- expression params edit as text")
	var view: DocumentView = main.view
	view.new_document()
	check(view.doc.set_variable("w", "50"), "variable w set")
	var fid: String = view.doc.graph_add_primitive("box", 40, 30, 20, Vector3.ZERO)
	view.doc.graph_set_params(fid, JSON.stringify(
		{"kind": "box", "a": "=w", "b": 30, "c": 20, "origin": [0, 0, 0]}))
	view.graph_changed()
	var body := view.body_of_feature(fid)
	check(absf(view.doc.body_volume(body) - 30000.0) < 1.0, "=w drives size (50x30x20)")
	var panel := _panel(main)
	main.timeline._select_feature(fid)
	# The 'a' row must be a LineEdit (expression), not a SpinBox.
	var found_expr := false
	for row in panel._fields.get_children():
		var lbl := row.get_child(0) as Label
		if lbl != null and lbl.text.begins_with("W") and row.get_child(1) is LineEdit:
			found_expr = true
			var edit: LineEdit = row.get_child(1)
			check(edit.text == "=w", "expression text preserved")
	check(found_expr, "expression field rendered as LineEdit")
	panel.cancel_edits()


func test_json_editor_still_works(main) -> void:
	print("- advanced JSON editor still applies")
	var view: DocumentView = main.view
	view.new_document()
	var fid: String = view.doc.graph_add_primitive("box", 10, 10, 10, Vector3.ZERO)
	view.graph_changed()
	var body := view.body_of_feature(fid)
	var tl = main.timeline
	tl._select_feature(fid)
	check(tl._editor_box.visible, "JSON editor box visible")
	var params: Dictionary = JSON.parse_string(tl._params_edit.text)
	params["a"] = 20
	tl._params_edit.text = JSON.stringify(params)
	tl._apply_params()
	check(absf(view.doc.body_volume(body) - 2000.0) < 1.0, "JSON apply regenerated")
	_panel(main).cancel_edits()
