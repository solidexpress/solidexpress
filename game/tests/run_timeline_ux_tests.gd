# Headless tests for timeline UX: rollback bar (kernel skip + UI), failure
# badges on regen errors, feature-type icons, and rollback persistence.
# Run: tools/godot/godot --headless --path game --script tests/run_timeline_ux_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("timeline UX tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_rollback(main)
	await test_failure_badge(main)
	await test_icons_and_reorder(main)
	await test_rollback_persistence(main)

	finish()


func _row_name_button(row: Control) -> Button:
	# Row layout: [suppress CheckBox, name Button, ...].
	return row.get_child(1) as Button


func test_rollback(main) -> void:
	print("- rollback bar skips features and is undoable")
	var view: DocumentView = main.view
	var timeline: TimelinePanel = main.timeline
	view.new_document()
	view.insert_primitive("box", Vector3.ZERO)
	view.insert_primitive("cylinder", Vector3(100, 0, 0))
	check(view.doc.body_ids().size() == 2, "two bodies before rollback")
	check(view.doc.graph_rollback() == -1, "rollback defaults to end")

	# Roll back before the second feature: its body disappears.
	check(view.doc.graph_set_rollback(1), "graph_set_rollback(1)")
	view.refresh()
	check(view.doc.body_ids().size() == 1, "rolled-back body removed")
	check(view.doc.graph_rollback() == 1, "graph_rollback reports index")

	# UI: bar exists, rows past the bar render dimmed.
	timeline.refresh()
	await process_frame
	check(timeline.rollback_bar != null, "rollback bar in the timeline")
	var dimmed := 0
	for fid in timeline._rows:
		if timeline._rows[fid].modulate.a < 0.9:
			dimmed += 1
	check(dimmed == 1, "one row dimmed past the bar (got %d)" % dimmed)

	# Undo restores the pre-rollback graph (bodies regenerate).
	check(view.doc.undo(), "undo rollback")
	view.refresh()
	check(view.doc.graph_rollback() == -1, "undo restored rollback to end")
	check(view.doc.body_ids().size() == 2, "undo restored both bodies")

	# Panel helper: roll back, then double-click semantics (roll to end).
	timeline.set_rollback(1)
	check(view.doc.graph_rollback() == 1, "panel set_rollback applies")
	timeline.set_rollback(-1)
	check(view.doc.graph_rollback() == -1, "panel rolls to end")
	check(view.doc.body_ids().size() == 2, "all bodies back after roll to end")


func test_failure_badge(main) -> void:
	print("- failed regenerate badges the offending row")
	var view: DocumentView = main.view
	var timeline: TimelinePanel = main.timeline
	view.new_document()
	var body: String = view.insert_primitive("box", Vector3.ZERO)
	check(body != "", "box on the timeline")
	var fid: String = view.feature_of_body(body)

	# Invalid primitive kind: regenerate fails, graph reverts, feature blamed.
	check(not view.doc.graph_set_params(fid, JSON.stringify({"kind": "nope"})),
		"bad params rejected")
	var feats: Array = view.doc.graph_features()
	check(feats.size() == 1, "feature still on the timeline")
	check(feats[0].get("failed", false), "feature flagged as failed")
	check(str(feats[0].get("error", "")) != "", "failure carries a message")

	timeline.refresh()
	await process_frame
	var row: Control = timeline._rows[fid]
	check(row.get_node_or_null("FailBadge") != null, "red badge on the row")

	# A successful edit clears the flag.
	check(view.doc.graph_set_params(fid, JSON.stringify(
		{"kind": "box", "a": 20.0, "b": 20.0, "c": 20.0, "origin": [0, 0, 0]})),
		"good params accepted")
	feats = view.doc.graph_features()
	check(not feats[0].get("failed", false), "failed flag cleared on success")
	timeline.refresh()
	await process_frame
	row = timeline._rows[fid]
	check(row.get_node_or_null("FailBadge") == null, "badge gone after fix")


func test_icons_and_reorder(main) -> void:
	print("- feature icons + dependency-safe reorder")
	var view: DocumentView = main.view
	var timeline: TimelinePanel = main.timeline
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.insert_primitive("sphere", Vector3(100, 0, 0))
	view.select_entity(a, "")
	# Fillet all edges of the box → third feature depends on the first.
	main.ops_panel._radius_spin.value = 1.0
	main.ops_panel._fillet_all()
	timeline.refresh()
	await process_frame

	var feats: Array = view.doc.graph_features()
	check(feats.size() == 3, "three timeline features")
	for f in feats:
		var btn := _row_name_button(timeline._rows[f["id"]])
		check(btn != null and btn.icon != null, "row has a type icon (%s)" % f["type"])

	# Reorder helper: dependency-blocked move refuses (fillet before its box).
	var fillet_fid := ""
	for f in feats:
		if f["type"] == "fillet":
			fillet_fid = f["id"]
	timeline._move_feature(fillet_fid, 0)
	check(view.doc.graph_features()[0]["id"] != fillet_fid, "dependency-blocked move refused")
	# Legal move: sphere (independent) to the front.
	var sphere_fid: String = feats[1]["id"]
	timeline._move_feature(sphere_fid, 0)
	check(view.doc.graph_features()[0]["id"] == sphere_fid, "legal drag/move reorders")


func test_rollback_persistence(main) -> void:
	print("- rollback survives save/load")
	var view: DocumentView = main.view
	view.new_document()
	view.insert_primitive("box", Vector3.ZERO)
	view.insert_primitive("cylinder", Vector3(100, 0, 0))
	check(view.doc.graph_set_rollback(1), "rollback set")
	var path := "/tmp/sx_timeline_rollback.sxp"
	check(view.save(path), "saved with rollback")
	view.new_document()
	check(view.load_from(path), "reloaded")
	check(view.doc.graph_rollback() == 1, "rollback persisted")
	check(view.doc.body_ids().size() == 1, "reloaded doc honors rollback")
	check(view.doc.graph_set_rollback(-1), "roll to end after load")
	check(view.doc.body_ids().size() == 2, "all features regenerate")
	DirAccess.remove_absolute(path)
