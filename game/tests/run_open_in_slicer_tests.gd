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
	print("open-in-slicer tests")
	test_open_in_slicer_per_body_and_mm()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _write_cfg(exec_path: String, args: PackedStringArray) -> void:
	var ok := SlicerSettings.save_settings(exec_path, args)
	check(ok, "saved slicer settings")

func _mm_in_3mf(path: String) -> bool:
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return false
	var data: PackedByteArray = z.read_file("3D/3dmodel.model")
	z.close()
	if data.size() == 0:
		return false
	var s := data.get_string_from_utf8()
	return s.find("unit=\"millimeter\"") >= 0

func test_open_in_slicer_per_body_and_mm() -> void:
	var doc := SxDocument.new()
	doc.add_box(10, 10, 10, Vector3.ZERO)
	doc.add_box(5, 5, 5, Vector3(30, 0, 0))
	_write_cfg("/usr/bin/echo", PackedStringArray(["--open"]))
	var res: Dictionary = OpenInSlicer.open_in_slicer(doc, true)
	var files: PackedStringArray = res.get("files", PackedStringArray())
	check(files.size() == 2, "one 3MF per body")
	if files.size() > 0:
		check(_mm_in_3mf(files[0]), "3MF uses millimeter units")
	var rec_path := res.get("record_path", "")
	check(rec_path != "", "record path returned")
	if rec_path != "":
		var r := FileAccess.open(rec_path, FileAccess.READ)
		var txt := ""
		if r:
			txt = r.get_as_text()
		check(txt.find("/usr/bin/echo") >= 0, "recorded command contains exec path")
		check(txt.find(".3mf") >= 0, "recorded command includes 3MF path")

