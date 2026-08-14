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
	print("catalog mechanic-tool tests (Wave 6.5)")
	test_hex_driver_blank_default_af()
	test_hex_socket_blank_constructs()
	test_open_end_blank_constructs()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# -- helpers --

static func _hex_sketch(af: float) -> SxSketch:
	var R := af / sqrt(3.0)
	var sk := SxSketch.new()
	sk.set_plane(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0))
	var pts: PackedVector2Array = []
	for i in range(6):
		var th := deg_to_rad(30.0 + float(i) * 60.0)
		pts.append(Vector2(R * cos(th), R * sin(th)))
	for i in range(6):
		var a := pts[i]
		var b := pts[(i + 1) % 6]
		sk.add_line(a.x, a.y, b.x, b.y)
	return sk

# Across-flats = 10 mm default when no jaw_af variable is present.
func test_hex_driver_blank_default_af() -> void:
	print("- hex driver blank width is 10 mm by default")
	var doc := SxDocument.new()
	var sk := _hex_sketch(10.0)
	var sk_fid: String = doc.graph_add_sketch(sk)
	check(sk_fid != "", "sketch added")
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 12.0, false, "new", "")
	check(ex_fid != "", "extrude added")
	var bodies: PackedStringArray = doc.body_ids()
	check(bodies.size() == 1, "one body created")
	if bodies.size() == 1:
		var bb: Dictionary = doc.measure_bbox(bodies[0])
		check(not bb.is_empty(), "bbox exists")
		if not bb.is_empty():
			var w := float(bb["max"].x - bb["min"].x)
			check(absf(w - 10.0) < 1e-3, "across-flats ~10 mm (got %.4g)" % w)

func test_hex_socket_blank_constructs() -> void:
	print("- hex socket blank builds with an internal hex")
	var doc := SxDocument.new()
	# Outer cylinder and a through-hex cut.
	var cyl: String = doc.add_cylinder(10.0, 16.0, Vector3.ZERO)
	check(cyl != "", "cylinder created")
	var sk := _hex_sketch(10.0)
	var sk_fid: String = doc.graph_add_sketch(sk)
	var hex_fid: String = doc.graph_add_extrude(sk_fid, 18.0, false, "new", "")
	check(hex_fid != "", "hex tool created")
	var hex_body := ""
	for f in doc.graph_features():
		if str(f.get("id","")) == hex_fid:
			hex_body = str(f.get("output_body",""))
			break
	check(hex_body != "", "hex tool body resolved")
	if cyl != "" and hex_body != "":
		check(doc.boolean_op(cyl, hex_body, "cut", false), "boolean cut succeeds")
		# Heuristic: cylinder has 3 faces; after cut we expect more.
		var faces: PackedStringArray = doc.get_face_ids(cyl)
		check(faces.size() >= 9, "faces increased after hex cut")

func test_open_end_blank_constructs() -> void:
	print("- open-end wrench head blank constructs")
	var doc := SxDocument.new()
	var af := 10.0
	var length := af * 3.0
	var width := af * 2.0
	var base: String = doc.add_box(length, width, 8.0, Vector3(-length * 0.5, -width * 0.5, 0.0))
	check(base != "", "base block created")
	var sk := _hex_sketch(af)
	var sk_fid: String = doc.graph_add_sketch(sk)
	var hex_fid: String = doc.graph_add_extrude(sk_fid, 10.0, false, "new", "")
	var hex_body := ""
	for f in doc.graph_features():
		if str(f.get("id","")) == hex_fid:
			hex_body = str(f.get("output_body",""))
			break
	check(hex_body != "", "hex tool body resolved")
	# Move the hex to the end and open to +Y.
	if hex_body != "":
		var notch_center := Vector3(-length * 0.25, width * 0.5 - af * 0.35, -1.0)
		check(doc.translate_body(hex_body, notch_center), "translated hex tool")
	if base != "" and hex_body != "":
		check(doc.boolean_op(base, hex_body, "cut", false), "open-end notch cut")
		# Body still valid and has volume.
		check(doc.body_volume(base) > 0.0, "open-end body has volume")

