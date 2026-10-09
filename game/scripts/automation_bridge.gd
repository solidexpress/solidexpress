extends Node
## Localhost line-delimited JSON bridge. Created only when SX_AUTOMATION=1.
## Every pointer and key is a real InputEvent pushed through the viewport, so
## focus, shields, popups, hover and drop dispositions match a person at the UI.

const DEFAULT_PORT := 47321

var _server: TCPServer
var _peer: StreamPeerTCP
var _buf := ""
var _queue: Array[String] = []
var _busy := false
var _port := DEFAULT_PORT
var _mouse_down := false
var _mods := {"shift": false, "ctrl": false, "alt": false, "meta": false}
var _trace: PackedStringArray = PackedStringArray()
var _trace_marks := {}
var _edge_cache: Array = []
var _edge_cache_rev := -1
var _face_cache: Array = []
var _face_cache_rev := -1

const TOOL_NAMES: PackedStringArray = [
	"None", "Line", "Rect", "Circle", "Arc", "Polygon", "Select", "Trim",
	"Extend", "Smart Dim", "Convert", "Mirror", "Pattern", "Spline", "Point",
	"Centerline", "Ellipse", "Slot", "Chamfer",
]


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	OS.low_processor_usage_mode = false
	var raw := OS.get_environment("SX_AUTOMATION_PORT").strip_edges()
	if raw.is_valid_int():
		_port = int(raw)
	_server = TCPServer.new()
	var err := _server.listen(_port, "127.0.0.1")
	if err != OK:
		printerr("automation bridge failed to listen on 127.0.0.1:%d (%s)" % [_port, error_string(err)])
		_server = null
		return
	host.set_meta("sx_automation_port", _port)
	printerr("automation bridge listening 127.0.0.1:%d" % _port)


func _exit_tree() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	if _server != null:
		_server.stop()
		_server = null


func _process(_delta: float) -> void:
	if _server == null:
		return
	_accept()
	_read_lines()
	if not _busy and not _queue.is_empty():
		var line := str(_queue.pop_front())
		_busy = true
		_dispatch(line)


func _accept() -> void:
	if not _server.is_listening():
		return
	if not _server.is_connection_available():
		return
	var next := _server.take_connection()
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = next
	_buf = ""


func _read_lines() -> void:
	if _peer == null:
		return
	_peer.poll()
	var status := _peer.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			_peer = null
		return
	var n := _peer.get_available_bytes()
	if n <= 0:
		return
	_buf += _peer.get_utf8_string(n)
	while true:
		var nl := _buf.find("\n")
		if nl < 0:
			break
		var line := _buf.substr(0, nl).strip_edges()
		_buf = _buf.substr(nl + 1)
		if line != "":
			_queue.append(line)


func _dispatch(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	var id: Variant = null
	var res := {}
	if not (parsed is Dictionary):
		res = {"ok": false, "error": "expected one JSON object per line"}
	else:
		id = (parsed as Dictionary).get("id", null)
		res = await _run(parsed as Dictionary)
	if typeof(res) != TYPE_DICTIONARY:
		res = {"ok": false, "error": "command produced no result"}
	res["id"] = id
	if not res.has("ok"):
		res["ok"] = not res.has("error")
	_reply(res)
	_busy = false


func _reply(obj: Dictionary) -> void:
	if _peer == null:
		return
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var text := JSON.stringify(obj) + "\n"
	_peer.put_data(text.to_utf8_buffer())


func _run(req: Dictionary) -> Dictionary:
	var cmd := str(req.get("cmd", "")).strip_edges().to_lower().replace("-", "_")
	var res := {}
	match cmd:
		"ping":
			res = {"pong": true, "port": _port}
		"click", "double_click", "hover":
			res = await _cmd_pointer(req, cmd)
		"drag":
			res = await _cmd_drag(req)
		"key":
			res = _cmd_key(req)
		"type":
			res = await _cmd_type(req)
		"wheel":
			res = _cmd_wheel(req)
		"wait_idle":
			res = {}
		"state":
			res = {"state": _state(_as_filter(req.get("filter", [])))}
		"trace":
			_harvest_traces()
			res = _cmd_trace(req)
		"screenshot":
			res = await _cmd_screenshot(req)
		"pixels":
			res = await _cmd_pixels(req)
		"project":
			res = _cmd_project(req)
		"dialog_dir":
			res = _cmd_dialog_dir(req)
		"dialog_commit":
			res = await _cmd_dialog_commit(req)
		"dialog_dismiss":
			res = await _cmd_dialog_dismiss(req)
		_:
			return {"ok": false, "error": "unknown command '%s'" % cmd}
	if res.has("error"):
		res["ok"] = false
		return res
	var frames := int(req.get("frames", 1 if cmd in ["state", "trace", "ping", "project", "screenshot", "pixels", "dialog_dir"] else 2))
	var settled := await _wait_idle(frames)
	_harvest_traces()
	res["ok"] = true
	res["settled_frames"] = settled
	res["trace_cursor"] = _trace.size()
	if cmd in ["click", "double_click", "hover", "drag", "key", "type", "wheel", "wait_idle", "dialog_commit", "dialog_dismiss"]:
		var ix = _main().get("interaction")
		if ix != null:
			res["disposition"] = str(ix.last_click_disposition)
		res["focus"] = _focus_path()
		res["status"] = _status_text()
	return res


func _as_filter(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is String:
		for part in str(v).split(",", false):
			var s := part.strip_edges()
			if s != "":
				out.append(s)
	elif v is Array:
		for part in v:
			out.append(str(part))
	return out


func _main() -> Node:
	return get_parent()


func _wait_idle(frames: int) -> int:
	var n := maxi(frames, 1)
	for _i in n:
		if not is_inside_tree():
			return n
		await get_tree().process_frame
	var extra := 0
	while extra < 90 and _ui_busy():
		await get_tree().process_frame
		extra += 1
	return n + extra


func _ui_busy() -> bool:
	var cam = _main().get("camera")
	if cam == null:
		return false
	var tw: Variant = cam.get("_view_tween")
	return tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running()


# --- input -----------------------------------------------------------------

func _stamp(ev: InputEvent) -> void:
	if ev is InputEventWithModifiers:
		var m := ev as InputEventWithModifiers
		m.shift_pressed = m.shift_pressed or bool(_mods["shift"])
		m.ctrl_pressed = m.ctrl_pressed or bool(_mods["ctrl"])
		m.alt_pressed = m.alt_pressed or bool(_mods["alt"])
		m.meta_pressed = m.meta_pressed or bool(_mods["meta"])


func _deliver_pointer(vp: Viewport, ev: InputEventMouse) -> void:
	# PopupMenu activates from Window._input_from_window, which push_input
	# on the popup itself never calls. An embedded popup receives that path
	# when the embedder forwards the event (position is in the embedder).
	# A native popup receives it from Input.parse_input_event on its window id.
	var host: Viewport = vp
	var at := ev.position
	if vp is Window:
		var win := vp as Window
		if win != _main().get_window():
			if win.is_embedded():
				var parent := win.get_parent()
				if parent != null:
					host = parent.get_viewport()
					at = Vector2(win.position) + ev.position
					# A dialog parented to another dialog is embedded in the
					# root window. Its position is root-space, so a point that
					# falls outside the parent dialog is delivered there.
					var root := _main().get_window()
					if host is Window and host != root:
						var hw := host as Window
						if at.x < 0.0 or at.y < 0.0 or at.x > float(hw.size.x) or at.y > float(hw.size.y):
							host = root
			else:
				ev.position = at
				ev.global_position = at
				ev.window_id = win.get_window_id()
				_stamp(ev)
				Input.parse_input_event(ev)
				Input.flush_buffered_events()
				return
	ev.position = at
	ev.global_position = at
	_stamp(ev)
	host.push_input(ev)


func _motion(vp: Viewport, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	# PopupMenu ignores a motion whose relative is exactly zero.
	ev.relative = Vector2(0.2, 0.2)
	if _mouse_down:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_deliver_pointer(vp, ev)


func _click_at(vp: Viewport, pos: Vector2, as_double: bool) -> void:
	_motion(vp, pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.double_click = as_double
	down.position = pos
	down.global_position = pos
	_mouse_down = true
	_deliver_pointer(vp, down)
	# A popup item highlights on the press and activates on the release.
	# Same-frame release never sees the highlighted item.
	if is_inside_tree():
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	_stamp(up)
	_mouse_down = false
	_deliver_pointer(vp, up)


func _cmd_pointer(req: Dictionary, kind: String) -> Dictionary:
	var spec := _resolve_point(req)
	if spec.has("error"):
		return spec
	var vp: Viewport = spec["vp"]
	var pos: Vector2 = spec["pos"]
	if kind == "hover":
		_motion(vp, pos)
	elif kind == "double_click":
		await _click_at(vp, pos, false)
		await get_tree().process_frame
		await _click_at(vp, pos, true)
	else:
		await _click_at(vp, pos, false)
	var out := {"at": _v2(pos)}
	if spec.has("id"):
		out["target"] = spec["id"]
	if spec.has("occluded"):
		out["occluded"] = spec["occluded"]
	return out


func _cmd_drag(req: Dictionary) -> Dictionary:
	var src: Dictionary = req.get("from", {}) if req.get("from", null) is Dictionary else {}
	if src.is_empty():
		src = req
	var dst: Dictionary = req.get("to", {}) if req.get("to", null) is Dictionary else {}
	var a := _resolve_point(src)
	var b := _resolve_point(dst)
	if a.has("error"):
		return a
	if b.has("error"):
		return b
	var vp: Viewport = a["vp"]
	var p0: Vector2 = a["pos"]
	var p1: Vector2 = b["pos"]
	var steps := maxi(int(req.get("steps", 8)), 2)
	_motion(vp, p0)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p0
	down.global_position = p0
	_mouse_down = true
	_deliver_pointer(vp, down)
	var box := {}
	for i in steps:
		var t := float(i + 1) / float(steps)
		var p := p0.lerp(p1, t)
		_motion(vp, p)
		if i == steps / 2:
			await get_tree().process_frame
			box = _box_paint()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p1
	up.global_position = p1
	_mouse_down = false
	_deliver_pointer(vp, up)
	return {"from": _v2(p0), "to": _v2(p1), "box": box}


func _box_paint() -> Dictionary:
	var ix = _main().get("interaction")
	if ix == null:
		return {}
	var active := bool(ix.get("_sketch_box_active"))
	var crossing := bool(ix.get("_sketch_box_crossing"))
	var fill := Color(0.35, 0.6, 0.95, 0.18)
	var edge := Color(0.35, 0.6, 0.95, 0.85)
	if active and crossing:
		fill = Color(0.35, 0.85, 0.45, 0.18)
	var rect: Variant = ix.get("_box_rect")
	return {
		"active": active,
		"crossing": crossing,
		"fill": _color255(fill),
		"edge": _color255(edge),
		"rect": _rect(rect) if rect is Rect2 else [],
	}


func _cmd_wheel(req: Dictionary) -> Dictionary:
	var spec := _resolve_point(req)
	if spec.has("error"):
		return spec
	var notches := int(req.get("notches", req.get("notch", 1)))
	if notches == 0:
		notches = 1
	var vp: Viewport = spec["vp"]
	var pos: Vector2 = spec["pos"]
	_motion(vp, pos)
	var step := 1 if notches > 0 else -1
	for _i in absi(notches):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if step > 0 else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.factor = 1.0
		ev.position = pos
		ev.global_position = pos
		_deliver_pointer(vp, ev)
	return {"at": _v2(pos), "notches": notches}


func _cmd_key(req: Dictionary) -> Dictionary:
	var action := str(req.get("action", "tap")).to_lower()
	var combo := str(req.get("combo", req.get("key", ""))).strip_edges()
	if combo == "":
		return {"error": "key needs combo"}
	var parsed := _parse_combo(combo)
	var key: Key = parsed["key"]
	var key_is_mod := _is_pure_mod(key)
	if action == "down":
		if key_is_mod:
			_set_mod_for_key(key, true)
			_send_key(key, true, 0, parsed)
		else:
			_apply_mod_keys(parsed, true)
			if key != KEY_NONE:
				_send_key(key, true, 0, parsed)
		return {"combo": combo, "action": "down"}
	if action == "up":
		if key_is_mod:
			_send_key(key, false, 0, parsed)
			_set_mod_for_key(key, false)
		else:
			if key != KEY_NONE:
				_send_key(key, false, 0, parsed)
			_apply_mod_keys(parsed, false)
		return {"combo": combo, "action": "up"}
	if key_is_mod:
		_set_mod_for_key(key, true)
		_send_key(key, true, 0, parsed)
		_send_key(key, false, 0, parsed)
		_set_mod_for_key(key, false)
		return {"combo": combo, "action": "tap"}
	_apply_mod_keys(parsed, true)
	if key != KEY_NONE:
		_send_key(key, true, _unicode_for(key, parsed), parsed)
		_send_key(key, false, 0, parsed)
	_apply_mod_keys(parsed, false)
	return {"combo": combo, "action": "tap"}


func _apply_mod_keys(parsed: Dictionary, down: bool) -> void:
	if parsed["ctrl"]:
		_mods["ctrl"] = down
		_send_key(KEY_CTRL, down, 0, parsed)
	if parsed["shift"]:
		_mods["shift"] = down
		_send_key(KEY_SHIFT, down, 0, parsed)
	if parsed["alt"]:
		_mods["alt"] = down
		_send_key(KEY_ALT, down, 0, parsed)
	if parsed["meta"]:
		_mods["meta"] = down
		_send_key(KEY_META, down, 0, parsed)


func _set_mod_for_key(key: Key, down: bool) -> void:
	match key:
		KEY_SHIFT:
			_mods["shift"] = down
		KEY_CTRL:
			_mods["ctrl"] = down
		KEY_ALT:
			_mods["alt"] = down
		KEY_META:
			_mods["meta"] = down


func _is_pure_mod(key: Key) -> bool:
	return key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]


func _send_key(key: Key, pressed: bool, unicode: int, flags: Dictionary) -> void:
	if key == KEY_NONE and unicode == 0:
		return
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.unicode = unicode if pressed else 0
	ev.pressed = pressed
	ev.echo = false
	ev.shift_pressed = bool(flags.get("shift", false)) or bool(_mods["shift"])
	ev.ctrl_pressed = bool(flags.get("ctrl", false)) or bool(_mods["ctrl"])
	ev.alt_pressed = bool(flags.get("alt", false)) or bool(_mods["alt"])
	ev.meta_pressed = bool(flags.get("meta", false)) or bool(_mods["meta"])
	_key_viewport().push_input(ev)


func _unicode_for(key: Key, flags: Dictionary) -> int:
	if key >= KEY_A and key <= KEY_Z:
		var base := 97 + int(key - KEY_A)
		if flags.get("shift", false):
			return base - 32
		return base
	if key >= KEY_0 and key <= KEY_9:
		return 48 + int(key - KEY_0)
	if key == KEY_SPACE:
		return 32
	if key == KEY_PERIOD:
		return 46
	if key == KEY_MINUS:
		return 45
	return 0


func _parse_combo(combo: String) -> Dictionary:
	var parts := combo.strip_edges().split("+", false)
	var flags := {"ctrl": false, "shift": false, "alt": false, "meta": false, "key": KEY_NONE}
	if parts.is_empty():
		return flags
	for i in parts.size():
		var raw := parts[i].strip_edges()
		var low := raw.to_lower()
		var is_mod := low in ["ctrl", "control", "shift", "alt", "meta", "cmd", "super"]
		if is_mod and (i < parts.size() - 1 or parts.size() == 1):
			match low:
				"ctrl", "control":
					flags["ctrl"] = true
				"shift":
					flags["shift"] = true
				"alt":
					flags["alt"] = true
				"meta", "cmd", "super":
					flags["meta"] = true
			if parts.size() == 1:
				flags["key"] = _keycode_of(raw)
			continue
		flags["key"] = _keycode_of(raw)
	return flags


func _keycode_of(name: String) -> Key:
	var low := name.strip_edges().to_lower()
	if low == "":
		return KEY_NONE
	match low:
		"esc", "escape":
			return KEY_ESCAPE
		"enter", "return":
			return KEY_ENTER
		"tab":
			return KEY_TAB
		"space":
			return KEY_SPACE
		"backspace":
			return KEY_BACKSPACE
		"delete", "del":
			return KEY_DELETE
		"up":
			return KEY_UP
		"down":
			return KEY_DOWN
		"left":
			return KEY_LEFT
		"right":
			return KEY_RIGHT
		"shift":
			return KEY_SHIFT
		"ctrl", "control":
			return KEY_CTRL
		"alt":
			return KEY_ALT
		"meta", "cmd":
			return KEY_META
		"home":
			return KEY_HOME
		"end":
			return KEY_END
		"f2":
			return KEY_F2
	if low.length() == 1:
		var c := low.unicode_at(0)
		if c >= 97 and c <= 122:
			return (KEY_A + (c - 97)) as Key
		if c >= 48 and c <= 57:
			return (KEY_0 + (c - 48)) as Key
	return OS.find_keycode_from_string(name) as Key


func _cmd_type(req: Dictionary) -> Dictionary:
	var text := str(req.get("text", ""))
	var delay := int(req.get("delay_ms", 0))
	var flags := {"ctrl": false, "shift": false, "alt": false, "meta": false}
	for i in text.length():
		var ch := text.substr(i, 1)
		var code := ch.unicode_at(0)
		var key := KEY_NONE
		var shift := false
		if code >= 48 and code <= 57:
			key = (KEY_0 + (code - 48)) as Key
		elif code >= 97 and code <= 122:
			key = (KEY_A + (code - 97)) as Key
		elif code >= 65 and code <= 90:
			key = (KEY_A + (code - 65)) as Key
			shift = true
		elif code == 46:
			key = KEY_PERIOD
		elif code == 45:
			key = KEY_MINUS
		elif code == 32:
			key = KEY_SPACE
		flags["shift"] = shift
		_send_key(key, true, code, flags)
		_send_key(key, false, 0, flags)
		if delay > 0 and i + 1 < text.length():
			var frames := maxi(int(ceil(float(delay) / 16.0)), 1)
			for _f in frames:
				await get_tree().process_frame
	return {"text": text, "chars": text.length()}


func _key_viewport() -> Viewport:
	var owner := _focus_node()
	if owner != null:
		return owner.get_viewport()
	return _main().get_viewport()


func _focus_node() -> Node:
	var windows: Array = []
	var main_win := _main().get_window()
	if main_win != null:
		windows.append(main_win)
	for w in _main().find_children("*", "Window", true, false):
		if w is Window and (w as Window).visible:
			windows.append(w)
	for w in windows:
		var owner: Node = (w as Viewport).gui_get_focus_owner()
		if owner != null:
			return owner
	return null


func _focus_path() -> String:
	var owner := _focus_node()
	if owner == null:
		return ""
	return str(owner.get_path())


# --- targeting -------------------------------------------------------------

func _resolve_point(req: Dictionary) -> Dictionary:
	_refresh_ids()
	var offset := _offset_of(req)
	if req.has("screen"):
		var s := _vec2(req["screen"])
		return {"vp": _main().get_viewport(), "pos": s + offset}
	if req.has("sketch"):
		var uv := _vec2(req["sketch"])
		var sp := _sketch_to_screen(uv)
		if sp == Vector2.INF:
			return {"error": "sketch point is not on screen (no active sketch camera)"}
		return {"vp": _main().get_viewport(), "pos": sp + offset}
	if req.has("model") or req.has("world"):
		var mp := _vec3(req["model"] if req.has("model") else req["world"])
		return {"vp": _main().get_viewport(), "pos": _model_to_screen(mp) + offset}
	if req.has("edge"):
		var edge := _find_edge(str(req["edge"]))
		if edge.is_empty():
			return {"error": "edge not found: %s" % str(req["edge"])}
		var along := float(req.get("along", 0.5))
		var a := _vec3(edge["a"])
		var b := _vec3(edge["b"])
		var p := a.lerp(b, clampf(along, 0.0, 1.0))
		return {"vp": _main().get_viewport(), "pos": _model_to_screen(p) + offset, "id": str(req["edge"])}
	if req.has("face"):
		var face := _find_face(str(req["face"]))
		if face.is_empty():
			return {"error": "face not found: %s" % str(req["face"])}
		return {"vp": _main().get_viewport(), "pos": _vec2(face["screen"]) + offset, "id": str(req["face"])}
	if req.has("dim") or req.has("dim_id") or req.has("dim_index"):
		var dim := _find_dim(req)
		if dim.is_empty():
			return {"error": "dimension label not found: %s" % str(req.get("dim", req.get("dim_id", "")))}
		var rect := _rect2_from(dim["rect"])
		var pos := rect.get_center()
		if str(req.get("glyph", "center")) == "first":
			pos = Vector2(rect.position.x + minf(8.0, rect.size.x * 0.25), rect.position.y + rect.size.y * 0.5)
		return {
			"vp": _main().get_viewport(),
			"pos": pos + offset,
			"id": "dim:%s" % str(dim.get("text", "")),
			"occluded": bool(dim.get("occluded", false)),
		}
	_refresh_ids()
	var target := str(req.get("target", "")).strip_edges()
	if target == "":
		return {"error": "click needs a target, sketch point, screen point, or dimension"}
	if target.begins_with("popup:"):
		return _resolve_popup_item(target.substr(6).strip_edges(), offset)
	if target.begins_with("item:"):
		return _resolve_item(target.substr(5).strip_edges(), offset)
	var node := _find_auto(target)
	if node == null:
		return {"error": "control not found: %s" % target}
	if node is Control:
		var c := node as Control
		return {"vp": c.get_viewport(), "pos": _control_click_pos(c) + offset, "id": target}
	if node is Window:
		var w := node as Window
		return {"vp": w, "pos": Vector2(w.size) * 0.5 + offset, "id": target}
	return {"error": "control not found: %s" % target}


func _control_click_pos(c: Control) -> Vector2:
	var vp := c.get_viewport()
	# Inside an embedded Window, get_global_rect() is not window-local. The
	# canvas transform is. _deliver_pointer adds the window position on top.
	if vp is Window and vp != _main().get_window():
		var sz := c.size
		if sz.x < 1.0 or sz.y < 1.0:
			sz = c.get_combined_minimum_size()
		return c.get_global_transform_with_canvas() * (sz * 0.5)
	return c.get_global_rect().get_center()


func _offset_of(req: Dictionary) -> Vector2:
	if not req.has("offset"):
		return Vector2.ZERO
	return _vec2(req["offset"])


func _resolve_popup_item(label: String, offset: Vector2) -> Dictionary:
	var best: PopupMenu = null
	var best_rank := 99
	var best_idx := -1
	for popup in _visible_popups():
		var idx := _popup_item_index(popup, label)
		if idx < 0:
			continue
		var rank := 0 if popup.get_item_text(idx) == label else 1
		if rank < best_rank:
			best = popup
			best_rank = rank
			best_idx = idx
	if best == null:
		return {"error": "popup item not found: %s" % label}
	var pos := _popup_item_local(best, best_idx) + offset
	return {"vp": best, "pos": pos, "id": "popup:%s" % label}


func _visible_popups() -> Array[PopupMenu]:
	var out: Array[PopupMenu] = []
	for n in _main().find_children("*", "PopupMenu", true, false):
		var popup := n as PopupMenu
		if popup != null and popup.visible:
			out.append(popup)
	return out


func _popup_item_index(popup: PopupMenu, label: String) -> int:
	var want := label.strip_edges().to_lower()
	var loose := -1
	for i in popup.item_count:
		if popup.is_item_separator(i):
			continue
		var text := popup.get_item_text(i).strip_edges()
		var low := text.to_lower()
		if low == want or text == label:
			return i
		if loose < 0 and (low.begins_with(want) or want.begins_with(low) or low.contains(want)):
			loose = i
	return loose


func _popup_panel(popup: PopupMenu) -> Control:
	for c in popup.get_children(true):
		if c is PanelContainer:
			return c as Control
	return null


func _popup_item_local(popup: PopupMenu, idx: int) -> Vector2:
	# Window-local. The panel is inset by the menu shadow; a click in that
	# padding is the "shadow" click and closes the menu without activating.
	var panel := _popup_panel(popup)
	var origin := Vector2.ZERO
	var width := float(popup.size.x)
	if panel != null:
		origin = panel.position
		width = maxf(panel.size.x, 8.0)
	var style := popup.get_theme_stylebox("panel")
	var top := style.get_margin(SIDE_TOP) if style != null else 4.0
	var font := popup.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var fs := popup.get_theme_font_size("font_size")
	if fs <= 0:
		fs = 16
	var vsep := float(popup.get_theme_constant("v_separation"))
	var row := float(font.get_height(fs)) + vsep
	var y := origin.y + top
	for i in idx:
		var step := row
		if popup.is_item_separator(i):
			step = maxf(8.0, vsep + 4.0)
		y += step
	return Vector2(origin.x + width * 0.5, y + row * 0.35)


func _resolve_item(label: String, offset: Vector2) -> Dictionary:
	var want := label.strip_edges().to_lower()
	for n in _main().find_children("*", "ItemList", true, false):
		var list := n as ItemList
		if list == null or not list.is_visible_in_tree():
			continue
		for i in list.item_count:
			var text := list.get_item_text(i)
			if text.to_lower() == want or text.to_lower().contains(want):
				var r := list.get_item_rect(i)
				var pos := list.get_global_rect().position + r.position + r.size * 0.5 + offset
				return {"vp": list.get_viewport(), "pos": pos, "id": "item:%s" % text}
	return {"error": "list item not found: %s" % label}


func _find_auto(id: String) -> Node:
	var hits: Array[Node] = []
	_collect_auto(_main(), id, hits)
	var visible: Array[Node] = []
	for n in hits:
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			visible.append(n)
		elif n is Window and (n as Window).visible:
			visible.append(n)
	if visible.size() >= 1:
		return visible[0]
	if hits.size() >= 1:
		return hits[0]
	var loose := _find_loose(id)
	if loose != null:
		return loose
	if id.begins_with("/"):
		return _main().get_node_or_null(id)
	return null


func _find_loose(id: String) -> Node:
	var main := _main()
	if main == null:
		return null
	if id == "dialog:Ok" or id == "dialog:Cancel" or id == "dialog:Name":
		var file_dialog: FileDialog = main.get("file_dialog")
		if file_dialog != null:
			if id == "dialog:Ok":
				return file_dialog.get_ok_button()
			if id == "dialog:Cancel":
				return file_dialog.get_cancel_button()
			if main.has_method("_file_dialog_name_edit"):
				return main.call("_file_dialog_name_edit")
	var prefix := ""
	if id.begins_with("chip:") or id.begins_with("variant:") or id.begins_with("contour:"):
		prefix = id.get_slice(":", 0) + ":"
	if prefix == "":
		return null
	var want := id.substr(prefix.length()).strip_edges().to_lower()
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is BaseButton:
			var text := str((n as BaseButton).text).strip_edges()
			var low := text.to_lower()
			if low == want or (want.length() > 2 and low.contains(want)):
				if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
					return n
		for c in n.get_children(true):
			stack.append(c)
	return null


func _collect_auto(n: Node, id: String, hits: Array[Node]) -> void:
	if n == null:
		return
	if str(n.get_meta("sx_auto", "")) == id or str(n.get_path()) == id:
		hits.append(n)
	for c in n.get_children(true):
		_collect_auto(c, id, hits)


func _refresh_ids() -> void:
	var main := _main()
	if main == null:
		return
	_tag(main.get("dof_label"), "hud:Dof")
	_tag(main.get("status_label"), "hud:Status")
	_tag(main.get("file_dialog"), "dialog:File")
	_tag_dialog_buttons(main)
	var names := {
		"PaletteSketch": "rail:Sketch",
		"JawTool": "rail:Jaw",
		"ToolSelect": "rail:Select",
		"ToolLine": "rail:Line",
		"ToolArc": "rail:Arc",
		"ToolCircle": "rail:Circle",
		"ToolRect": "rail:Rect",
		"ToolPolygon": "rail:Polygon",
		"ToolEllipse": "rail:Ellipse",
		"ToolSlot": "rail:Slot",
		"ToolSpline": "rail:Spline",
		"ToolPoint": "rail:Point",
		"ToolTrim": "rail:Trim",
		"ToolExtend": "rail:Extend",
		"ToolSmartDim": "rail:SmartDim",
		"ToolConvert": "rail:Convert",
		"ToolMirror": "rail:Mirror",
		"ToolPattern": "rail:Pattern",
		"ExitSketch": "rail:ExitSketch",
		"AutoDefine": "rail:AutoDim",
		"SnapToggle": "rail:Snap",
		"InferToggle": "rail:Infer",
		"DistanceLineEdit": "finish:Distance",
		"DimLineEdit": "finish:Radius",
		"DimEditLine": "dim:Edit",
		"DimEditPopup": "dim:Popup",
		"FinishOp": "finish:Op",
		"FinishEnd": "finish:End",
		"ThinType": "finish:Thin",
		"ExtrudeButton": "finish:Extrude",
		"RevolveButton": "finish:Revolve",
		"DoneButton": "finish:Done",
		"OppositeFaceButton": "finish:OppositeFace",
		"ThinFeature": "finish:ThinCheck",
		"FlipSide": "finish:Flip",
		"Frame": "hud:Frame",
		"ViewsDrop": "hud:View",
		"TimelineTitle": "timeline:title",
	}
	for node_name in names.keys():
		var node := main.find_child(str(node_name), true, false)
		_tag(node, str(names[node_name]))
	var distance_spin := main.find_child("DistanceSpin", true, false) as SpinBox
	if distance_spin != null:
		_tag(distance_spin.get_line_edit(), "finish:Distance")
	var dim_spin := main.find_child("DimSpin", true, false) as SpinBox
	if dim_spin != null:
		_tag(dim_spin.get_line_edit(), "finish:Radius")
	var timeline := main.find_child("Timeline", true, false)
	_tag(timeline, "timeline:panel")
	var menu_bar := main.find_child("FileMenu", true, false)
	if menu_bar != null:
		for b in menu_bar.find_children("*", "MenuButton", true, false):
			var mb := b as MenuButton
			if mb == null or str(mb.text) == "":
				continue
			_tag(mb, "menu:%s" % mb.text)
			_tag(mb.get_popup(), "popup:%s" % mb.text)
	_tag_every_named(main, "SelectionStrip", "chip:")
	_tag_every_named(main, "ActionBar", "chip:")
	_tag_every_named(main, "VariantBar", "variant:")
	_tag_every_named(main, "ContourBar", "contour:")
	var rows := main.find_child("TimelineRows", true, false)
	if rows != null:
		for row in rows.get_children():
			var name_btn: Button = null
			for c in row.get_children():
				if c is Button and str(c.name) != "RowEdit" and str((c as Button).text) != "":
					name_btn = c
					break
			if name_btn != null:
				_tag(name_btn, "timeline:row:%s" % name_btn.text)
				var pencil := row.find_child("RowEdit", true, false)
				_tag(pencil, "timeline:pencil:%s" % name_btn.text)
	_tag_spin_edit(main.find_child("Param_distance", true, false), "finish:ParamDistance")
	_tag_spin_edit(main.find_child("Param_radius", true, false), "finish:ParamRadius")
	_tag_spin_edit(main.find_child("StripRadius", true, false), "finish:StripR")
	_tag_spin_edit(main.find_child("DressupRadius", true, false), "finish:PanelRadius")


func _tag(node: Node, id: String) -> void:
	if node == null or id == "":
		return
	node.set_meta("sx_auto", id)


func _tag_every_named(main: Node, node_name: String, prefix: String) -> void:
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if str(n.name) == node_name:
			_tag_buttons(n, prefix)
		for c in n.get_children(true):
			stack.append(c)


func _tag_buttons(root: Node, prefix: String) -> void:
	if root == null:
		return
	for n in root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b == null:
			continue
		var text := str(b.text).strip_edges()
		if text == "":
			continue
		_tag(b, prefix + text)


func _tag_spin_edit(node: Node, id: String) -> void:
	if node is SpinBox:
		var edit := (node as SpinBox).get_line_edit()
		_tag(edit, id)
	elif node is LineEdit:
		_tag(node, id)


func _tag_dialog_buttons(main: Node) -> void:
	var file_dialog: FileDialog = main.get("file_dialog")
	if file_dialog != null:
		if main.has_method("_file_dialog_name_edit"):
			_tag(main.call("_file_dialog_name_edit"), "dialog:Name")
		_tag(file_dialog.get_ok_button(), "dialog:Ok")
		_tag(file_dialog.get_cancel_button(), "dialog:Cancel")
	var discard: ConfirmationDialog = main.get("confirm_dialog")
	if discard != null:
		_tag(discard, "dialog:Discard")
		_tag(discard.get_ok_button(), "dialog:DiscardOk")
		_tag(discard.get_cancel_button(), "dialog:DiscardCancel")
	for n in main.find_children("*", "ConfirmationDialog", true, false):
		var dlg := n as ConfirmationDialog
		if dlg == null or dlg == discard or not dlg.visible:
			continue
		_tag(dlg.get_ok_button(), "dialog:ConfirmOk")
		_tag(dlg.get_cancel_button(), "dialog:ConfirmCancel")


func _sketch_to_screen(uv: Vector2) -> Vector2:
	var sm = _main().get("sketch_mode")
	if sm == null or not bool(sm.active):
		return Vector2.INF
	var cam := _main().get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.INF
	var world: Vector3 = sm.to_global(sm.to_model(uv))
	return cam.unproject_position(world)


func _model_to_screen(p: Vector3) -> Vector2:
	var ms = _main().get("model_space")
	var cam := _main().get_viewport().get_camera_3d()
	if ms == null or cam == null:
		return Vector2.ZERO
	return cam.unproject_position(ms.to_global(p))


func _cmd_dialog_dir(req: Dictionary) -> Dictionary:
	var dlg: FileDialog = _main().get("file_dialog")
	if dlg == null:
		return {"error": "no file dialog"}
	var path := str(req.get("path", ""))
	if path != "":
		dlg.current_dir = path
	return {"dir": dlg.current_dir, "file": dlg.current_file}


func _visible_accept_child(root: Node) -> AcceptDialog:
	if root == null:
		return null
	var stack: Array[Node] = []
	for c in root.get_children(true):
		stack.append(c)
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is AcceptDialog and (n as AcceptDialog).visible:
			return n as AcceptDialog
		for c in n.get_children(true):
			stack.append(c)
	return null


## Godot's overwrite prompt is an internal ConfirmationDialog of the FileDialog.
## find_children skips internal nodes, so a name search never sees it.
func _find_overwrite_dialog(file_dialog: FileDialog) -> AcceptDialog:
	var direct := _visible_accept_child(file_dialog)
	if direct != null:
		return direct
	var main := _main()
	var discard: Node = main.get("confirm_dialog")
	var stack: Array[Node] = []
	for c in main.get_children(true):
		stack.append(c)
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is AcceptDialog and n != file_dialog and n != discard and (n as AcceptDialog).visible:
			var text := str((n as AcceptDialog).dialog_text).to_lower()
			if text.contains("overwrite") or text.contains("already") or text.contains("exist"):
				return n as AcceptDialog
		for c in n.get_children(true):
			stack.append(c)
	return null


func _dialog_state() -> Dictionary:
	var main := _main()
	var dlg: FileDialog = main.get("file_dialog")
	var discard: ConfirmationDialog = main.get("confirm_dialog")
	var ow: AcceptDialog = null
	if dlg != null and dlg.visible:
		ow = _find_overwrite_dialog(dlg)
	return {
		"file_visible": dlg != null and dlg.visible,
		"overwrite_visible": ow != null,
		"overwrite_text": str(ow.dialog_text) if ow != null else "",
		"overwrite_name": str(ow.name) if ow != null else "",
		"discard_visible": discard != null and discard.visible,
		"file": dlg.current_file if dlg != null else "",
		"dir": dlg.current_dir if dlg != null else "",
	}


func _press_control(c: Control) -> void:
	var guard := 0
	while guard < 8 and (c.size.x < 1.0 or c.size.y < 1.0):
		if not is_inside_tree():
			return
		await get_tree().process_frame
		guard += 1
	await _click_at(c.get_viewport(), _control_click_pos(c), false)


func _cmd_dialog_commit(req: Dictionary) -> Dictionary:
	var dlg: FileDialog = _main().get("file_dialog")
	if dlg == null or not dlg.visible:
		return {"error": "file dialog is not open"}
	var path := str(req.get("path", ""))
	var filename := str(req.get("file", ""))
	if path != "":
		dlg.current_dir = path
	var edit: LineEdit = null
	if _main().has_method("_file_dialog_name_edit"):
		var got: Variant = _main().call("_file_dialog_name_edit")
		if got is LineEdit:
			edit = got
	if filename == "" and edit != null:
		filename = edit.text.strip_edges()
	if filename != "":
		dlg.current_file = filename
		if edit != null:
			edit.text = filename
			edit.caret_column = filename.length()
	if is_inside_tree():
		await get_tree().process_frame
	var ok: Button = dlg.get_ok_button()
	if ok == null:
		return {"error": "file dialog has no OK button"}
	await _press_control(ok)
	var confirmed := false
	var confirm_text := ""
	for _i in 24:
		if not is_inside_tree():
			break
		await get_tree().process_frame
		if not dlg.visible:
			break
		var ow := _find_overwrite_dialog(dlg)
		if ow == null:
			continue
		confirm_text = str(ow.dialog_text)
		var cok: Button = ow.get_ok_button()
		if cok == null:
			return {"error": "overwrite dialog has no OK button", "overwrite_text": confirm_text}
		await _press_control(cok)
		confirmed = true
		break
	if dlg.visible and not confirmed:
		await _press_control(ok)
		for _j in 24:
			if not is_inside_tree():
				break
			await get_tree().process_frame
			if not dlg.visible:
				break
			var ow2 := _find_overwrite_dialog(dlg)
			if ow2 == null:
				continue
			confirm_text = str(ow2.dialog_text)
			var cok2: Button = ow2.get_ok_button()
			if cok2 != null:
				await _press_control(cok2)
				confirmed = true
			break
	var waits := 0
	while waits < 45 and dlg.visible and is_inside_tree():
		await get_tree().process_frame
		waits += 1
	return {
		"visible": dlg.visible,
		"confirmed": confirmed,
		"overwrite_text": confirm_text,
		"status": _status_text(),
		"file": dlg.current_file,
		"dir": dlg.current_dir,
		"dialogs": _dialog_state(),
	}


func _cmd_dialog_dismiss(_req: Dictionary) -> Dictionary:
	var closed: PackedStringArray = []
	var main := _main()
	var dlg: FileDialog = main.get("file_dialog")
	if dlg != null and dlg.visible:
		var ow := _find_overwrite_dialog(dlg)
		if ow != null:
			var cancel: Button = ow.get_cancel_button()
			if cancel != null:
				await _press_control(cancel)
			else:
				ow.hide()
			closed.append("overwrite")
			if is_inside_tree():
				await get_tree().process_frame
	if dlg != null and dlg.visible:
		var cancel_file: Button = dlg.get_cancel_button()
		if cancel_file != null:
			await _press_control(cancel_file)
		closed.append("file")
		var waits := 0
		while waits < 12 and dlg.visible and is_inside_tree():
			await get_tree().process_frame
			waits += 1
		if dlg.visible:
			dlg.hide()
			closed.append("file-hide")
	var discard: ConfirmationDialog = main.get("confirm_dialog")
	if discard != null and discard.visible:
		var discard_cancel: Button = discard.get_cancel_button()
		if discard_cancel != null:
			await _press_control(discard_cancel)
		else:
			discard.hide()
		closed.append("discard")
	for n in main.find_children("*", "AcceptDialog", true, false):
		var ad := n as AcceptDialog
		if ad == null or ad == dlg or ad == discard or not ad.visible:
			continue
		var extra: Button = ad.get_cancel_button()
		if extra != null:
			await _press_control(extra)
		else:
			ad.hide()
		closed.append(str(ad.name))
	return {"closed": closed, "dialogs": _dialog_state(), "status": _status_text()}


func _cmd_project(req: Dictionary) -> Dictionary:
	var spec := _resolve_point(req)
	if spec.has("error"):
		return spec
	return {"screen": _v2(spec["pos"])}


# --- state -----------------------------------------------------------------

func _state(filt: PackedStringArray) -> Dictionary:
	_refresh_ids()
	_harvest_traces()
	var full := _state_full()
	if filt.is_empty():
		return full
	var out := {}
	for key in filt:
		if full.has(key):
			out[key] = full[key]
	return out


func _state_full() -> Dictionary:
	var main := _main()
	var sm = main.get("sketch_mode")
	var view = main.get("view")
	var cam = main.get("camera")
	var ix = main.get("interaction")
	return {
		"status": _status_text(),
		"focus": _focus_path(),
		"focus_text": _focus_text(),
		"tool": _tool_state(sm),
		"rail": _rail_state(main),
		"controls": _controls(),
		"popups": _popups(),
		"finish": _finish_state(main),
		"dof": _dof_text(main),
		"sketch": _sketch_state(sm),
		"timeline": _timeline_state(main),
		"undo": _undo_labels(sm, false),
		"redo": _undo_labels(sm, true),
		"doc_undo": _doc_labels(view, false),
		"doc_redo": _doc_labels(view, true),
		"selection": _selection_state(view, sm),
		"dims": _collect_dims(sm),
		"glyphs": _collect_glyphs(sm),
		"contours": _collect_contours(sm),
		"infer": _infer_state(sm),
		"measure": _measure_state(ix),
		"camera": _camera_state(cam),
		"bodies": _bodies_state(view),
		"faces": _faces_cached(view),
		"edges": _edges_cached(view),
		"features": _features_state(view),
		"card": _card_text(main),
		"window": _window_state(main),
		"last_click": str(ix.last_click_disposition) if ix != null else "",
		"trace_cursor": _trace.size(),
		"dialogs": _dialog_state(),
	}


func _status_text() -> String:
	var label = _main().get("status_label")
	if label == null:
		return ""
	return str(label.text)


func _dof_text(main: Node) -> String:
	var label = main.get("dof_label")
	if label == null:
		return ""
	return str(label.text)


func _focus_text() -> String:
	var owner := _focus_node()
	if owner is LineEdit:
		return str((owner as LineEdit).text)
	if owner is TextEdit:
		return str((owner as TextEdit).text)
	return ""


func _tool_state(sm) -> Dictionary:
	if sm == null:
		return {}
	var id := int(sm.tool)
	var name := TOOL_NAMES[id] if id >= 0 and id < TOOL_NAMES.size() else str(id)
	if bool(sm.get("_jaw_armed")):
		name = "Jaw"
	return {"id": id, "name": name, "variant": str(sm.tool_variant), "jaw": bool(sm.get("_jaw_armed"))}


func _rail_state(main: Node) -> Array:
	var out: Array = []
	var buttons: Array = main.get("_sketch_rail_buttons")
	for b in buttons:
		if b is Button:
			out.append(_button_record(b as Button))
	var jaw := main.find_child("JawTool", true, false) as Button
	if jaw != null:
		out.append(_button_record(jaw))
	return out


func _button_record(b: Button) -> Dictionary:
	return {
		"id": str(b.get_meta("sx_auto", "")),
		"text": str(b.text),
		"pressed": b.button_pressed,
		"lit": b.button_pressed,
		"disabled": b.disabled,
		"rect": _rect(b.get_global_rect()),
		"fill": _style_fill(b, "pressed" if b.button_pressed else "normal"),
		"hover_fill": _style_fill(b, "hover"),
	}


func _style_fill(b: Button, which: String) -> Array:
	var style := b.get_theme_stylebox(which)
	if style is StyleBoxFlat:
		return _color255((style as StyleBoxFlat).bg_color)
	return []


func _controls() -> Array:
	var out: Array = []
	_walk_controls(_main(), out)
	return out


func _walk_controls(n: Node, out: Array) -> void:
	if n is Control:
		var c := n as Control
		var tagged := str(c.get_meta("sx_auto", "")) != ""
		var sized := c.get_global_rect().size.x >= 1.0 and c.get_global_rect().size.y >= 1.0
		if c.is_visible_in_tree() and (tagged or sized):
			var rec := {
				"path": str(c.get_path()),
				"id": str(c.get_meta("sx_auto", "")),
				"rect": _rect(c.get_global_rect()),
				"text": _control_text(c),
				"visible": true,
				"disabled": bool(c.get("disabled")) if c is BaseButton else false,
			}
			if c is BaseButton:
				rec["pressed"] = (c as BaseButton).button_pressed
			out.append(rec)
	for child in n.get_children():
		_walk_controls(child, out)


func _control_text(c: Control) -> String:
	if c is OptionButton:
		var ob := c as OptionButton
		if ob.selected >= 0 and ob.selected < ob.item_count:
			return ob.get_item_text(ob.selected)
	if c is LineEdit:
		return str((c as LineEdit).text)
	if c is SpinBox:
		var edit := (c as SpinBox).get_line_edit()
		if edit != null:
			return str(edit.text)
		return str((c as SpinBox).value)
	if c is TextEdit:
		return str((c as TextEdit).text)
	if "text" in c:
		return str(c.get("text"))
	return ""


func _popups() -> Array:
	var out: Array = []
	for n in _main().find_children("*", "Window", true, false):
		var w := n as Window
		if w == null or not w.visible:
			continue
		out.append({
			"name": str(w.name),
			"id": str(w.get_meta("sx_auto", "")),
			"trace": str(w.get_meta("_sx_popup_trace_name", "")),
			"title": str(w.title) if "title" in w else "",
			"text": _window_text(w),
			"rect": [w.position.x, w.position.y, w.size.x, w.size.y],
		})
	return out


func _window_text(w: Window) -> String:
	if w is AcceptDialog:
		return str((w as AcceptDialog).dialog_text)
	if w is PopupMenu:
		var parts: PackedStringArray = []
		var popup := w as PopupMenu
		for i in popup.item_count:
			if not popup.is_item_separator(i):
				parts.append(popup.get_item_text(i))
		return ", ".join(parts)
	return ""


func _finish_state(main: Node) -> Dictionary:
	var fields: Array = []
	for id in ["finish:Distance", "finish:Radius", "finish:Op", "finish:End", "finish:Thin", "finish:StripR", "finish:PanelRadius", "finish:ParamDistance", "finish:ParamRadius"]:
		var node := _find_auto(id)
		if node is Control and (node as Control).is_visible_in_tree():
			fields.append({"id": id, "text": _control_text(node as Control), "rect": _rect((node as Control).get_global_rect())})
	return {"fields": fields}


func _sketch_state(sm) -> Dictionary:
	if sm == null:
		return {}
	var entities: Array = []
	if sm.sketch != null and bool(sm.active):
		for id in sm.sketch.entity_ids():
			var info: Dictionary = sm.sketch.entity_info(id)
			entities.append(_jsonify(info))
			if entities.size() >= 80:
				break
	return {
		"active": bool(sm.active),
		"editing": str(sm.editing_fid),
		"entity_count": entities.size() if sm.sketch == null or not bool(sm.active) else sm.sketch.entity_ids().size(),
		"entities": entities,
	}


func _timeline_state(main: Node) -> Array:
	var out: Array = []
	var rows := main.find_child("TimelineRows", true, false)
	var panel := main.find_child("Timeline", true, false) as Control
	var title := main.find_child("TimelineTitle", true, false) as Control
	if title != null:
		out.append({"kind": "title", "text": str(title.text), "rect": _rect(title.get_global_rect()), "visible": title.is_visible_in_tree()})
	if panel != null:
		out.append({"kind": "panel", "rect": _rect(panel.get_global_rect()), "visible": panel.visible and panel.is_visible_in_tree()})
	if rows == null:
		return out
	for row in rows.get_children():
		if not (row is Control):
			continue
		var name_btn: Button = null
		for c in row.get_children():
			if c is Button and str(c.name) != "RowEdit" and str((c as Button).text) != "":
				name_btn = c
				break
		var pencil := row.find_child("RowEdit", true, false) as Control
		out.append({
			"name": name_btn.text if name_btn != null else "",
			"id": str(name_btn.get_meta("sx_auto", "")) if name_btn != null else "",
			"rect": _rect(name_btn.get_global_rect()) if name_btn != null else [],
			"pencil": _rect(pencil.get_global_rect()) if pencil != null else [],
			"visible": (row as Control).is_visible_in_tree(),
		})
	return out


func _undo_labels(sm, redo: bool) -> Array:
	if sm == null:
		return []
	var stack: Array = sm.get("_redo_stack") if redo else sm.get("_undo_stack")
	var out: Array = []
	for entry in stack:
		if entry is Dictionary:
			out.append(str((entry as Dictionary).get("label", "")))
	return out


func _doc_labels(view, redo: bool) -> Array:
	if view == null or view.doc == null:
		return []
	var method := "redo_labels" if redo else "undo_labels"
	if not view.doc.has_method(method):
		return []
	var raw: Variant = view.doc.call(method)
	var out: Array = []
	if raw is PackedStringArray or raw is Array:
		for s in raw:
			out.append(str(s))
	return out


func _selection_state(view, sm) -> Dictionary:
	var out := {"bodies": [], "faces": [], "edges": [], "sketch": [], "constraint": ""}
	if view != null:
		out["body"] = str(view.selected_body)
		out["face"] = str(view.selected_face)
		out["faces"] = _string_list(view.selected_faces)
		out["edges"] = _string_list(view.selected_edges)
		if view.get("selected_bodies") != null:
			out["bodies"] = _string_list(view.selected_bodies)
	if sm != null:
		out["sketch"] = _string_list(sm.selected)
		out["constraint"] = str(sm.selected_constraint)
	return out


func _string_list(v: Variant) -> Array:
	var out: Array = []
	if v == null:
		return out
	for s in v:
		out.append(str(s))
	return out


func _collect_dims(sm) -> Array:
	var out: Array = []
	if sm == null or not sm.has_method("dimension_label_screen_rects"):
		return out
	var rects: Array = sm.dimension_label_screen_rects()
	var labels: Node = sm.get("_dimension_labels")
	for i in rects.size():
		var entry: Dictionary = rects[i]
		var hit: Rect2 = entry.get("rect", Rect2())
		var drawn := hit
		var visible := true
		var text := str(entry.get("text", ""))
		if labels != null and i < labels.get_child_count():
			var lab := labels.get_child(i) as Label3D
			if lab != null:
				visible = lab.visible and labels.visible
				text = lab.text if lab.text != "" else text
				var projected := _label3d_rect(lab)
				if projected.size.x > 1.0:
					drawn = projected
		var raw := {}
		if i < sm.dimensions.size() and sm.dimensions[i] is Dictionary:
			for k in (sm.dimensions[i] as Dictionary).keys():
				var val: Variant = (sm.dimensions[i] as Dictionary)[k]
				if typeof(val) in [TYPE_FLOAT, TYPE_INT, TYPE_STRING, TYPE_BOOL]:
					raw[str(k)] = val
		out.append({
			"id": int(entry.get("index", i)),
			"text": text,
			"rect": _rect(drawn),
			"hit_rect": _rect(hit),
			"visible": visible,
			"occluded": _occluded(drawn),
			"raw": raw,
		})
	return out


func _find_dim(req: Dictionary) -> Dictionary:
	var dims := _collect_dims(_main().get("sketch_mode"))
	if req.has("dim_id") or req.has("dim_index"):
		var want := int(req["dim_id"] if req.has("dim_id") else req["dim_index"])
		for d in dims:
			if int(d["id"]) == want:
				return d
	var text := str(req.get("dim", ""))
	if text == "":
		return {}
	for d in dims:
		if str(d["text"]) == text:
			return d
	for d in dims:
		if str(d["text"]).contains(text):
			return d
	return {}


func _label3d_rect(lab: Label3D) -> Rect2:
	var cam := lab.get_viewport().get_camera_3d() if lab.is_inside_tree() else null
	if cam == null:
		return Rect2()
	var centre: Vector2 = cam.unproject_position(lab.global_position) + lab.offset
	var fs := lab.font_size
	if fs <= 0:
		fs = 16
	var font := lab.font
	if font == null:
		font = ThemeDB.fallback_font
	var sz := font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var w := maxf(sz.x, 8.0)
	var h := float(fs)
	return Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))


func _occluded(rect: Rect2) -> bool:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return true
	var vp := _main().get_viewport().get_visible_rect()
	if not vp.intersects(rect):
		return true
	var centre := rect.get_center()
	for node_name in ["SketchTools", "Palette", "TopChrome"]:
		var chrome := _main().find_child(node_name, true, false) as Control
		if chrome != null and chrome.is_visible_in_tree() and chrome.get_global_rect().has_point(centre):
			return true
	return false


func _collect_glyphs(sm) -> Array:
	var out: Array = []
	if sm == null or not sm.has_method("constraint_glyph_screen_rects"):
		return out
	for g in sm.constraint_glyph_screen_rects():
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var rect: Rect2 = g.get("rect", Rect2())
		out.append({
			"type": str(g.get("type", "")),
			"rect": _rect(rect),
			"occluded": _occluded(rect),
		})
	return out


func _collect_contours(sm) -> Array:
	var out: Array = []
	if sm == null:
		return out
	var lab: Label3D = sm.get("_contour_tag")
	if lab != null and lab.visible:
		var rect := _label3d_rect(lab)
		out.append({
			"text": lab.text,
			"rect": _rect(rect),
			"visible": true,
			"leader": bool(sm.get("_contour_tag_leader")),
		})
	return out


func _infer_state(sm) -> Dictionary:
	if sm == null:
		return {}
	var lab: Label3D = sm.get("_infer_label")
	if lab == null:
		return {"visible": false, "text": ""}
	return {
		"visible": lab.visible,
		"text": lab.text,
		"rect": _rect(_label3d_rect(lab)) if lab.visible else [],
	}


func _measure_state(ix) -> Array:
	var out: Array = []
	if ix == null or ix.measure_overlay == null:
		return out
	for entry in ix.measure_overlay.labels:
		if entry is Dictionary:
			out.append({"text": str(entry.get("text", ""))})
	return out


func _camera_state(cam) -> Dictionary:
	if cam == null:
		return {}
	return {
		"distance": cam.distance,
		"yaw": cam.yaw,
		"pitch": cam.pitch,
		"ortho": cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"size": cam.size,
		"position": _v3(cam.global_position),
	}


func _bodies_state(view) -> Array:
	var out: Array = []
	if view == null or view.doc == null:
		return out
	for bid in view.doc.body_ids():
		var bb: Dictionary = view.doc.measure_bbox(bid)
		var rec := {"id": str(bid), "name": str(view.doc.body_name(bid))}
		if bb.has("min") and bb.has("max"):
			rec["min"] = _v3(bb["min"])
			rec["max"] = _v3(bb["max"])
			var mid: Vector3 = (bb["min"] + bb["max"]) * 0.5
			rec["screen"] = _v2(_model_to_screen(mid))
		out.append(rec)
	return out


func _faces_cached(view) -> Array:
	if view == null or view.doc == null:
		return []
	var rev := int(view.doc.revision()) if view.doc.has_method("revision") else -1
	if rev != _face_cache_rev:
		_face_cache = _build_faces(view)
		_face_cache_rev = rev
	return _face_cache


func _edges_cached(view) -> Array:
	if view == null or view.doc == null:
		return []
	var rev := int(view.doc.revision()) if view.doc.has_method("revision") else -1
	if rev != _edge_cache_rev:
		_edge_cache = _build_edges(view)
		_edge_cache_rev = rev
	return _edge_cache


func _build_faces(view) -> Array:
	var out: Array = []
	for bid in view.doc.body_ids():
		for fid in view.doc.get_face_ids(bid):
			var mid: Vector3 = view.doc.face_midpoint(fid)
			out.append({
				"id": str(fid),
				"body": str(bid),
				"mid": _v3(mid),
				"screen": _v2(_model_to_screen(mid)),
			})
	return out


func _build_edges(view) -> Array:
	var out: Array = []
	for bid in view.doc.body_ids():
		var lines: Dictionary = view.doc.get_edge_lines(bid)
		for eid in lines.keys():
			var pts: PackedVector3Array = lines[eid]
			if pts.size() < 2:
				continue
			var length := 0.0
			for i in range(1, pts.size()):
				length += pts[i - 1].distance_to(pts[i])
			var a := pts[0]
			var b := pts[pts.size() - 1]
			var dir := b - a
			if dir.length() > 1e-6:
				dir = dir.normalized()
			var mid := pts[int(pts.size() / 2)]
			out.append({
				"id": str(eid),
				"body": str(bid),
				"length": length,
				"mid": _v3(mid),
				"dir": _v3(dir),
				"a": _v3(a),
				"b": _v3(b),
				"screen": _v2(_model_to_screen(mid)),
			})
	return out


func _find_edge(id: String) -> Dictionary:
	for e in _edges_cached(_main().get("view")):
		if str(e["id"]) == id or str(e["id"]).begins_with(id):
			return e
	return {}


func _find_face(id: String) -> Dictionary:
	for f in _faces_cached(_main().get("view")):
		if str(f["id"]) == id or str(f["id"]).begins_with(id):
			return f
	return {}


func _features_state(view) -> Array:
	var out: Array = []
	if view == null or view.doc == null or not view.doc.has_method("graph_features"):
		return out
	for f in view.doc.graph_features():
		if f is Dictionary:
			var rec := {}
			for k in (f as Dictionary).keys():
				var val: Variant = (f as Dictionary)[k]
				if typeof(val) in [TYPE_FLOAT, TYPE_INT, TYPE_STRING, TYPE_BOOL]:
					rec[str(k)] = val
			out.append(rec)
	return out


func _card_text(main: Node) -> String:
	var card = main.get("card_panel")
	if card == null:
		return ""
	return str(card.text)


func _window_state(main: Node) -> Dictionary:
	var win := main.get_window()
	if win == null:
		return {}
	var screen := DisplayServer.screen_get_size()
	return {
		"size": [win.size.x, win.size.y],
		"position": [win.position.x, win.position.y],
		"mode": int(win.mode),
		"maximized": win.mode == Window.MODE_MAXIMIZED,
		"screen": [screen.x, screen.y],
	}


# --- trace / image ---------------------------------------------------------

func _harvest_traces() -> void:
	var main := _main()
	var ix = main.get("interaction")
	if ix != null:
		_take("press", ix.press_trace_log)
	_take("key", SxUi.key_trace_log)
	_take("status", main.status_trace_log)
	_take("popup", main.popup_trace_log)
	_take("hover", main.hover_trace_log)


func _take(name: String, arr: PackedStringArray) -> void:
	var prev := int(_trace_marks.get(name, 0))
	if arr.size() < prev:
		prev = 0
	for i in range(prev, arr.size()):
		_trace.append(arr[i])
	_trace_marks[name] = arr.size()


func _cmd_trace(req: Dictionary) -> Dictionary:
	var since := int(req.get("since", 0))
	if since < 0:
		since = 0
	var lines: Array = []
	for i in range(since, _trace.size()):
		lines.append(_trace[i])
	return {"lines": lines, "cursor": _trace.size()}


func _cmd_screenshot(req: Dictionary) -> Dictionary:
	var path := str(req.get("path", "")).strip_edges()
	if path == "":
		return {"error": "screenshot needs path"}
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path(path)
	await _present_frame()
	var img := _viewport_image()
	if img == null:
		return {"error": "viewport has no image"}
	var err := img.save_png(path)
	if err != OK:
		return {"error": "screenshot save failed (%s)" % error_string(err)}
	return {"path": path, "size": [img.get_width(), img.get_height()]}


func _cmd_pixels(req: Dictionary) -> Dictionary:
	await _present_frame()
	var img := _viewport_image()
	if img == null:
		return {"error": "viewport has no image"}
	var pts: Array = req.get("points", [])
	var out: Array = []
	for p in pts:
		var v := _vec2(p)
		var x := clampi(int(v.x), 0, img.get_width() - 1)
		var y := clampi(int(v.y), 0, img.get_height() - 1)
		out.append({"x": x, "y": y, "rgba": _color255(img.get_pixel(x, y))})
	return {"pixels": out}


func _present_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw


func _viewport_image() -> Image:
	var vp := _main().get_viewport()
	if vp == null:
		return null
	var tex := vp.get_texture()
	if tex == null:
		return null
	return tex.get_image()


# --- json helpers ----------------------------------------------------------

func _v2(v: Vector2) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]


func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _rect(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]


func _rect2_from(v: Variant) -> Rect2:
	if v is Rect2:
		return v
	if v is Array and (v as Array).size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()


func _color255(c: Color) -> Array:
	return [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0)), int(round(c.a * 255.0))]


func _vec2(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is String:
		var parts := str(v).split(",")
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO


func _vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is String:
		var parts := str(v).split(",")
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO


func _jsonify(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			return _v2(v)
		TYPE_VECTOR3:
			return _v3(v)
		TYPE_COLOR:
			return _color255(v)
		TYPE_DICTIONARY:
			var d := {}
			for k in (v as Dictionary).keys():
				d[str(k)] = _jsonify((v as Dictionary)[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var a: Array = []
			for e in v:
				a.append(_jsonify(e))
			return a
		TYPE_OBJECT:
			return str(v)
		_:
			return v
