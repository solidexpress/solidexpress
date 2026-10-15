# Rung 4 WP2 — a new part is millimetres, and New keeps the pinned sentence.
# Click-built. File → New, then the bridge reads state.units.
# Run: tools/godot/godot --headless --path game --script tests/run_rung04_units.gd
extends "res://tests/lib/sx_suite.gd"

const FilmUI = preload("res://tests/lib/film_ui.gd")
const NEW_SENTENCE := "New — empty part, Top plane (XY). View ▸ Timeline to edit features"
const PORT := 47344
const ROOT_SIZE := Vector2i(1280, 800)

var _peer: StreamPeerTCP
var _buf := ""
var _rpc_id := 1


func _init() -> void:
	print("rung04 units")
	await _run()
	finish()


func _run() -> void:
	var main: Node = await _boot()
	if main == null:
		return
	check(await _connect(), "client connected")
	var opened := await _rpc({"cmd": "click", "target": "menu:File"})
	check(bool(opened.get("ok", false)), "File menu (%s)" % str(opened.get("error", "")))
	var newer := await _rpc({"cmd": "click", "target": "popup:New"})
	check(bool(newer.get("ok", false)), "File → New (%s)" % str(newer.get("error", "")))
	var st := await _state(["units", "status", "dialogs"])
	check(str(st.get("units", "")) == "mmgs", "state.units is mmgs (got %s)" % str(st.get("units", "")))
	check(str(st.get("status", "")) == NEW_SENTENCE, "status is the pinned New sentence (got %s)" % str(st.get("status", "")))
	var dialogs: Variant = st.get("dialogs", {})
	var file_open := dialogs is Dictionary and bool((dialogs as Dictionary).get("file_visible", false))
	check(not file_open, "New opens no dialog")
	await _shutdown(main)


func _state(keys: PackedStringArray) -> Dictionary:
	var res := await _rpc({"cmd": "state", "filter": keys})
	var st: Variant = res.get("state", {})
	return st if st is Dictionary else {}


func _boot():
	OS.set_environment("SX_AUTOMATION", "1")
	OS.set_environment("SX_AUTOMATION_PORT", str(PORT))
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
