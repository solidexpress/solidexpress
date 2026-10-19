extends SceneTree
## Headless nut/pipe/wrench .sxp + 3MF into SX_RUNG08_FIXTURE_DIR.

const NutFix = preload("res://tests/lib/nut_fixture.gd")
const WrenchFix = preload("res://tests/lib/wrench_fixture.gd")


func _init() -> void:
	var out := OS.get_environment("SX_RUNG08_FIXTURE_DIR")
	if out == "":
		out = "/tmp/sx-rung08-fixtures"
	DirAccess.make_dir_recursive_absolute(out)
	var doc := SxDocument.new()
	var nut := NutFix.build(doc)
	if nut == "":
		push_error("nut fixture failed: %s" % doc.last_graph_error())
		quit(1)
		return
	if not doc.save(out.path_join("nut.sxp")) or not doc.export_3mf_for_body(nut, out.path_join("nut.3mf")):
		push_error("save nut failed")
		quit(1)
		return

	doc = SxDocument.new()
	var pipe := PipeFixture.build_final(doc)
	if pipe == "":
		push_error("pipe fixture failed: %s" % doc.last_graph_error())
		quit(1)
		return
	var pipe_body := doc.body_ids()[0] if not doc.body_ids().is_empty() else pipe
	if not doc.save(out.path_join("pipe.sxp")) or not doc.export_3mf_for_body(pipe_body, out.path_join("pipe.3mf")):
		push_error("save pipe failed")
		quit(1)
		return

	doc = SxDocument.new()
	var wrench := WrenchFix.build(doc)
	if wrench == "":
		push_error("wrench fixture failed: %s" % doc.last_graph_error())
		quit(1)
		return
	if not doc.save(out.path_join("wrench.sxp")) or not doc.export_3mf(out.path_join("wrench.3mf")):
		push_error("save wrench failed")
		quit(1)
		return
	print("rung08 fixtures %s" % out)
	quit(0)
