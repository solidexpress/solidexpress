extends "res://tests/lib/sx_suite.gd"
## Proves SX_AUTOMATION injects real viewport input.
## Run: tools/godot/godot --headless --path game --script tests/run_automation_bridge_tests.gd

const FilmUI = preload("res://tests/lib/film_ui.gd")
const _ToolSpec = preload("res://scripts/sketch_tool_spec.gd")
const PORT := 47341
const ROOT_SIZE := Vector2i(1280, 800)

var _peer: StreamPeerTCP
var _buf := ""
var _rpc_id := 1


func _init() -> void:
	print("automation bridge")
	_check_tool_names()
	await _case_off()
	await _case_real_input()
	await _case_face_identity()
	finish()


func _case_off() -> void:
	print("- bridge is off unless SX_AUTOMATION=1")
	OS.set_environment("SX_AUTOMATION", "")
	OS.set_environment("SX_AUTOMATION_PORT", str(PORT))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	check(main.get_node_or_null("AutomationBridge") == null, "no AutomationBridge child")
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", PORT)
	for _i in 4:
		peer.poll()
		await process_frame
	check(peer.get_status() != StreamPeerTCP.STATUS_CONNECTED, "port %d is closed" % PORT)
	peer.disconnect_from_host()
	main.queue_free()
	for _i in 4:
		await process_frame


func _check_tool_names() -> void:
	var expect := PackedStringArray([
		"None", "Line", "Rect", "Circle", "Arc", "Polygon", "Select", "Trim",
		"Extend", "Smart Dim", "Convert", "Mirror", "Pattern", "Spline", "Point",
		"Centerline", "Ellipse", "Slot", "Chamfer",
	])
	var got: PackedStringArray = _ToolSpec.tool_names()
	var same := got.size() == expect.size()
	if same:
		for i in expect.size():
			if got[i] != expect[i]:
				same = false
				break
	check(same, "tool names None..Chamfer")


func _case_real_input() -> void:
	print("- real input: focus, extrude shield, jaw label")
	var main: Node = await _boot()
	if main == null:
		return
	check(await _connect(), "client connected")
	var ping := await _rpc({"cmd": "ping"})
	check(bool(ping.get("ok", false)), "ping ok (%s)" % str(ping.get("error", "")))
	var closed := await _rpc({"cmd": "dialog_commit"})
	check(not bool(closed.get("ok", true)), "dialog_commit refuses a closed file dialog")
	var dismissed := await _rpc({"cmd": "dialog_dismiss"})
	check(bool(dismissed.get("ok", false)), "dialog_dismiss with nothing open (%s)" % str(dismissed.get("error", "")))
	var dialogs := await _state(["dialogs"])
	check(dialogs.has("dialogs") and not bool((dialogs["dialogs"] as Dictionary).get("file_visible", true)), "state.dialogs reports the file dialog closed")

	var sketch := await _rpc({"cmd": "click", "target": "rail:Sketch"})
	check(bool(sketch.get("ok", false)), "Sketch rail click (%s)" % str(sketch.get("error", "")))
	var ground := await _rpc({"cmd": "click", "screen": [900, 450]})
	check(bool(ground.get("ok", false)), "ground click (%s)" % str(ground.get("error", "")))
	var st := await _state(["status", "sketch", "focus"])
	check(str(st.get("status", "")).contains("Sketch"), "sketch opened (%s)" % st.get("status", ""))

	var field := await _rpc({"cmd": "click", "target": "finish:Distance"})
	check(bool(field.get("ok", false)), "Distance field click (%s)" % str(field.get("error", "")))
	var typed := await _rpc({"cmd": "type", "text": "8"})
	check(bool(typed.get("ok", false)), "type into Distance (%s)" % str(typed.get("error", "")))
	var entered := await _rpc({"cmd": "key", "combo": "enter"})
	check(bool(entered.get("ok", false)), "Enter (%s)" % str(entered.get("error", "")))
	var focus := str(entered.get("focus", ""))
	check(not focus.contains("DistanceLineEdit"), "Enter released the Distance field (focus %s)" % focus)

	var circle := await _rpc({"cmd": "click", "target": "rail:Circle"})
	check(bool(circle.get("ok", false)), "Circle tool (%s)" % str(circle.get("error", "")))
	var centre := await _rpc({"cmd": "click", "sketch": [0, 0]})
	check(bool(centre.get("ok", false)), "circle centre (%s)" % str(centre.get("error", "")))
	await _rpc({"cmd": "type", "text": "10"})
	await _rpc({"cmd": "key", "combo": "enter"})
	var extruded := await _rpc({"cmd": "click", "target": "finish:Extrude", "frames": 8})
	check(bool(extruded.get("ok", false)), "Extrude click (%s status %s)" % [str(extruded.get("error", "")), str(extruded.get("status", ""))])
	var again_at: Array = extruded.get("at", [0, 0])
	var again := await _rpc({"cmd": "click", "screen": again_at, "frames": 4})
	check(str(again.get("disposition", "")) == "drop:shield",
			"second Extrude press is drop:shield (got %s status %s)" % [again.get("disposition", ""), again.get("status", "")])

	await _rpc({"cmd": "click", "target": "menu:File"})
	var newer := await _rpc({"cmd": "click", "target": "popup:New"})
	check(bool(newer.get("ok", false)), "File → New (%s)" % str(newer.get("error", "")))
	var pop := await _state(["popups", "status"])
	if _popup_open(pop):
		await _rpc({"cmd": "click", "target": "dialog:DiscardOk"})
	await _rpc({"cmd": "click", "target": "rail:Sketch"})
	await _rpc({"cmd": "click", "screen": [900, 450]})
	var jaw_open := await _state(["status", "sketch"])
	check(bool(jaw_open.get("sketch", {}).get("active", false)), "new sketch for the jaw (%s)" % jaw_open.get("status", ""))
	await _rpc({"cmd": "click", "target": "rail:Jaw"})
	await _rpc({"cmd": "click", "sketch": [0, 0]})
	await _rpc({"cmd": "click", "sketch": [30, 0]})
	var committed := await _rpc({"cmd": "click", "sketch": [30, -12], "frames": 4})
	check(str(committed.get("status", "")).contains("Jaw committed"),
			"jaw committed (%s)" % committed.get("status", ""))
	var dims_state := await _state(["dims", "status"])
	var angle := _angle_dim(dims_state.get("dims", []))
	check(not angle.is_empty(), "a drawn angle label exists (%s)" % str(dims_state.get("dims", [])))
	if not angle.is_empty():
		var hit := await _rpc({
			"cmd": "click",
			"dim": str(angle.get("text", "")),
			"glyph": "first",
		})
		check(bool(hit.get("ok", false)), "angle label click (%s)" % str(hit.get("error", "")))
		var rect: Array = angle.get("rect", [])
		var at: Array = hit.get("at", [])
		if rect.size() >= 4 and at.size() >= 2:
			var inside := float(at[0]) >= float(rect[0]) - 2.0 and float(at[0]) <= float(rect[0]) + float(rect[2]) + 2.0 \
					and float(at[1]) >= float(rect[1]) - 2.0 and float(at[1]) <= float(rect[1]) + float(rect[3]) + 2.0
			check(inside, "click landed in the drawn label rect %s at %s" % [rect, at])
		await _rpc({"cmd": "type", "text": "45"})
		var edited := await _rpc({"cmd": "key", "combo": "enter", "frames": 6})
		var after := await _state(["dims", "status"])
		var texts := _dim_texts(after.get("dims", []))
		check(str(edited.get("status", "")).contains("Dimension updated") or _has_45(texts),
				"angle edited toward 45 (status %s labels %s)" % [edited.get("status", ""), texts])
		check(_has_45(texts), "drawn label reads 45° (%s)" % texts)
	await _shutdown(main)


## Face id stays the same face after the camera moves, and face_normal picks +X.
func _case_face_identity() -> void:
	print("- face identity survives a camera move")
	var main: Node = await _boot()
	if main == null:
		return
	check(await _connect(), "face client connected")
	if not await _extrude_box():
		await _shutdown(main)
		return
	await _rpc({"cmd": "key", "combo": "f", "frames": 8})
	var st := await _state(["faces", "bodies", "selection"])
	var faces: Array = st.get("faces", [])
	check(faces.size() >= 6, "box exposes its faces (%d)" % faces.size())
	if faces.is_empty():
		await _shutdown(main)
		return
	var sample: Dictionary = faces[0]
	check(sample.has("normal") and sample.has("centre") and sample.has("area") and sample.has("screen"),
			"face record has normal, centre, area, screen (keys %s)" % str(sample.keys()))
	var face := _face_at(faces, 0, 100.0)
	var fid := str(face.get("id", ""))
	check(fid != "", "plus-X face id")
	if fid == "":
		await _shutdown(main)
		return
	var first := await _drill_face(fid)
	var normal_before: Array = first.get("normal", [])
	print("  first pick normal=%s at=%s" % [str(normal_before), str(first.get("at", []))])
	await _rpc({"cmd": "key", "combo": "2", "frames": 8})
	await _clear_selection()
	var centre: Array = _face_centre(face)
	var live := await _rpc({"cmd": "project", "model": centre})
	var second := await _drill_face(fid)
	var sel2 := await _state(["selection", "faces"])
	var selected2 := str((sel2.get("selection", {}) as Dictionary).get("face", ""))
	var normal_after: Array = second.get("normal", [])
	var listed := _face_by_id(sel2.get("faces", []), fid)
	print("  second pick face=%s normal=%s at=%s live=%s listed=%s" % [selected2, str(normal_after), str(second.get("at", [])), str(live.get("screen", [])), str(listed.get("screen", []))])
	check(_screen_near(second.get("at", []), live.get("screen", []), 4.0),
			"second pick uses the camera now (at %s live %s)" % [second.get("at", []), live.get("screen", [])])
	check(_screen_near(listed.get("screen", []), live.get("screen", []), 4.0),
			"face screen follows the camera (%s vs %s)" % [listed.get("screen", []), live.get("screen", [])])
	check(selected2 == fid, "second pick selects the same face (got %s)" % selected2)
	check(normal_before.size() == 3 and _vec_near(normal_before, normal_after, 0.02),
			"second pick reports the same normal (%s vs %s)" % [normal_before, normal_after])
	await _clear_selection()
	var by_normal := await _drill_face_normal([1, 0, 0])
	var sel3 := await _state(["selection", "faces"])
	var picked := str((sel3.get("selection", {}) as Dictionary).get("face", ""))
	var rec := _face_by_id(sel3.get("faces", []), picked)
	var got_n: Array = by_normal.get("normal", [])
	var got_c: Array = _face_centre(rec)
	print("  face_normal pick face=%s normal=%s centre=%s" % [picked, str(got_n), str(got_c)])
	check(got_c.size() == 3 and absf(float(got_c[0]) - 100.0) < 0.5,
			"face_normal [1,0,0] selects the x=100 face (centre %s)" % str(got_c))
	check(_vec_near(got_n, [1, 0, 0], 0.02), "face_normal pick reports +X (got %s)" % str(got_n))
	await _shutdown(main)


func _extrude_box() -> bool:
	var sketch := await _rpc({"cmd": "click", "target": "rail:Sketch"})
	check(bool(sketch.get("ok", false)), "Sketch rail (%s)" % str(sketch.get("error", "")))
	var ground := await _rpc({"cmd": "click", "screen": [900, 450]})
	check(bool(ground.get("ok", false)), "ground plane (%s)" % str(ground.get("error", "")))
	var rect := await _rpc({"cmd": "click", "target": "rail:Rect"})
	check(bool(rect.get("ok", false)), "Rect tool (%s)" % str(rect.get("error", "")))
	var a := await _rpc({"cmd": "click", "sketch": [0, 0]})
	var b := await _rpc({"cmd": "click", "sketch": [100, 60]})
	check(bool(a.get("ok", false)) and bool(b.get("ok", false)), "rectangle corners")
	var field := await _rpc({"cmd": "click", "target": "finish:Distance"})
	check(bool(field.get("ok", false)), "Distance field (%s)" % str(field.get("error", "")))
	await _rpc({"cmd": "type", "text": "50"})
	await _rpc({"cmd": "key", "combo": "enter"})
	var extruded := await _rpc({"cmd": "click", "target": "finish:Extrude", "frames": 10})
	check(bool(extruded.get("ok", false)), "Extrude (%s status %s)" % [str(extruded.get("error", "")), str(extruded.get("status", ""))])
	var bodies := await _state(["bodies"])
	var n := (bodies.get("bodies", []) as Array).size()
	check(n == 1, "one box body (%d)" % n)
	return n == 1


func _clear_selection() -> void:
	var off := await _rpc({"cmd": "project", "model": [-40, -40, 90]})
	var screen: Array = off.get("screen", [24, 760])
	await _rpc({"cmd": "click", "screen": screen, "frames": 3})


func _drill_face(id: String) -> Dictionary:
	await _rpc({"cmd": "click", "face": id, "frames": 3})
	return await _rpc({"cmd": "click", "face": id, "frames": 3})


func _drill_face_normal(normal: Array) -> Dictionary:
	await _rpc({"cmd": "click", "face_normal": normal, "frames": 3})
	return await _rpc({"cmd": "click", "face_normal": normal, "frames": 3})


func _face_at(faces: Array, axis: int, coord: float) -> Dictionary:
	var best := {}
	var best_d := 1.0e9
	for f in faces:
		if not (f is Dictionary):
			continue
		var p := _face_centre(f)
		if p.size() < 3:
			continue
		var d := absf(float(p[axis]) - coord)
		if d < best_d:
			best_d = d
			best = f
	return best


func _face_by_id(faces: Array, id: String) -> Dictionary:
	for f in faces:
		if f is Dictionary and str(f.get("id", "")) == id:
			return f
	return {}


func _face_centre(face: Dictionary) -> Array:
	var c: Variant = face.get("centre", face.get("mid", []))
	return c if c is Array else []


func _screen_near(a: Variant, b: Variant, tol: float) -> bool:
	if not (a is Array) or not (b is Array) or (a as Array).size() < 2 or (b as Array).size() < 2:
		return false
	return Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1]))) <= tol


func _vec_near(a: Variant, b: Variant, tol: float) -> bool:
	if not (a is Array) or not (b is Array) or (a as Array).size() < 3 or (b as Array).size() < 3:
		return false
	return Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(Vector3(float(b[0]), float(b[1]), float(b[2]))) <= tol


func _angle_dim(dims: Array) -> Dictionary:
	for d in dims:
		if d is Dictionary and str(d.get("text", "")).contains("°"):
			return d
	return {}


func _dim_texts(dims: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for d in dims:
		if d is Dictionary:
			out.append(str(d.get("text", "")))
	return out


func _has_45(texts: PackedStringArray) -> bool:
	for t in texts:
		if t.contains("45"):
			return true
	return false


func _popup_open(st: Dictionary) -> bool:
	for p in st.get("popups", []):
		if p is Dictionary and (str(p.get("text", "")).contains("Discard") or str(p.get("id", "")).contains("Discard")):
			return true
	return false


func _state(keys: PackedStringArray) -> Dictionary:
	var res := await _rpc({"cmd": "state", "filter": keys})
	var st: Variant = res.get("state", {})
	return st if st is Dictionary else {}


func _boot():
	OS.set_environment("SX_AUTOMATION", "1")
	OS.set_environment("SX_AUTOMATION_PORT", str(PORT))
	OS.set_environment("SX_INPUT_TRACE", "1")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var guard := 0
	while main.get_node_or_null("AutomationBridge") == null and guard < 180:
		await process_frame
		guard += 1
	check(main.get_node_or_null("AutomationBridge") != null, "bridge node started")
	if main.get_node_or_null("AutomationBridge") == null:
		main.queue_free()
		await process_frame
		return null
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	return main


func _connect() -> bool:
	_peer = StreamPeerTCP.new()
	var err := _peer.connect_to_host("127.0.0.1", PORT)
	if err != OK:
		return false
	for _i in 40:
		_peer.poll()
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return true
		if _peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			return false
		await process_frame
	return false


func _rpc(req: Dictionary) -> Dictionary:
	req["id"] = _rpc_id
	_rpc_id += 1
	_peer.put_data((JSON.stringify(req) + "\n").to_utf8_buffer())
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		_peer.poll()
		var n := _peer.get_available_bytes()
		if n > 0:
			_buf += _peer.get_utf8_string(n)
		var nl := _buf.find("\n")
		if nl >= 0:
			var line := _buf.substr(0, nl)
			_buf = _buf.substr(nl + 1)
			var data: Variant = JSON.parse_string(line)
			if data is Dictionary:
				return data
			return {"ok": false, "error": "reply was not an object"}
		await process_frame
	return {"ok": false, "error": "timed out waiting for %s" % str(req.get("cmd", ""))}


func _shutdown(main: Node) -> void:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	if main != null:
		main.queue_free()
	for _i in 4:
		await process_frame
