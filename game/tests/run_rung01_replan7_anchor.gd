# Rung 1 replan 7 WP2 — Smart Dimension between two circles keeps the origin circle at the origin.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan7_anchor.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var origin_id: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var head_id: String = sm.sketch.add_circle(17.6, 0.0, 22.5)
	sm._smart_dim_between({"entity": origin_id, "role": "center"}, {"entity": head_id, "role": "center"})
	var idx := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "distance":
			idx = i
	check(idx >= 0, "centre distance dimension exists")
	sm.set_dimension_value(idx, "200")
	var oc: Vector2 = sm.sketch.entity_info(origin_id)["center"]
	var hc: Vector2 = sm.sketch.entity_info(head_id)["center"]
	print("  origin circle %s head circle %s" % [str(oc), str(hc)])
	check(oc.length() < 1e-3, "origin circle stays at (0, 0) (got %s)" % str(oc))
	check(absf(hc.x - 200.0) < 1e-3 and absf(hc.y) < 1e-3, "head circle is at (200, 0) (got %s)" % str(hc))

	var far_id: String = sm.sketch.add_circle(-60.0, 40.0, 8.0)
	var near_id: String = sm.sketch.add_circle(-20.0, 40.0, 6.0)
	sm._smart_dim_between({"entity": far_id, "role": "center"}, {"entity": near_id, "role": "center"})
	var fc: Vector2 = sm.sketch.entity_info(far_id)["center"]
	check(fc.distance_to(Vector2(-60.0, 40.0)) < 1e-6, "circles away from the origin are not pinned (got %s)" % str(fc))
	sm._set_selected([origin_id])
	sm.constrain("diameter", 24.0)
	var rr := float(sm.sketch.entity_info(origin_id)["radius"])
	check(absf(rr - 12.0) < 1e-3, "a diameter dimension still resizes the pinned circle (radius %.3f)" % rr)
	finish()
