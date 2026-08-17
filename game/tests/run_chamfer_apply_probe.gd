extends SceneTree
var failures:=0
var checks:=0
func check(c:bool,w:String)->void:
	checks+=1
	if c: print("  ok - "+w)
	else: failures+=1; printerr("  FAIL - "+w)
func _init()->void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var view=main.view
	view.new_document()
	var id=view.insert_primitive("box", Vector3.ZERO, Vector3(50,50,5))
	view.select_entity(id,"")
	main._update_panel_visibility()
	await process_frame
	var ops=main.ops_panel
	ops._radius_spin.value=0.5
	ops._chamfer_all()
	print("pending after all=", ops._pending, " feats=", view.doc.graph_features().size())
	# Force arm
	ops._pending = ops.Pending.CHAMFER_EDGES
	ops._pending_body = id
	ops._pending_fid = view.feature_of_body(id)
	var lines=view.doc.get_edge_ids(id)
	print("edge count=", lines.size())
	var eid=str(lines[0])
	view.select_edge(id, eid)
	print("selected_edge=", view.selected_edge, " edges=", view.selected_edges)
	var targets=ops._round_targets()
	print("targets=", targets)
	var fid=view.feature_of_body(id)
	var cid=view.doc.graph_add_chamfer(fid, targets, 0.5)
	print("graph_add_chamfer=", cid)
	check(cid!="", "chamfer feature created")
	print("feats=", view.doc.graph_features())
	# Also try via commit
	view.new_document()
	id=view.insert_primitive("box", Vector3.ZERO, Vector3(50,50,5))
	view.select_entity(id,"")
	await process_frame
	ops._radius_spin.value=4.0
	ops._chamfer_all()
	check(ops._pending==ops.Pending.CHAMFER_EDGES, "armed after fail")
	lines=view.doc.get_edge_ids(id)
	view.select_edge(id, str(lines[0]))
	ops._radius_spin.value=0.5
	var ok=ops.try_commit_pending()
	print("try_commit=", ok, " pending=", ops._pending)
	var has_ch:=false
	for f in view.doc.graph_features():
		if str(f.get("type",""))=="chamfer": has_ch=true
	check(has_ch, "chamfer on timeline after Enter")
	print("%d checks %d failures"%[checks,failures])
	quit(1 if failures else 0)
