class_name VoiceExecutor
extends RefCounted
## Turns a voice transcript + current selection into constraints, modeling
## commands, view changes, or spoken answers. Uses SxVoice (kernel interpreter).
## Unmatched utterances are appended to user://voice/unmatched.jsonl for the
## future AI-first solver.


signal status(text: String)
signal intent_parsed(intent: Dictionary)

var view: DocumentView
var camera: OrbitCamera
var sketch_mode: SketchMode
var interaction: ViewportInteraction

var _voice := SxVoice.new()
var _stt := SxVoiceStt.new()
var _pending: Dictionary = {}  # needs confirm


func selection_dict() -> Dictionary:
	var d := {
		"bodies": view.selected_bodies.duplicate() if view != null else PackedStringArray(),
		"faces": view.selected_faces.duplicate() if view != null else PackedStringArray(),
		"edges": view.selected_edges.duplicate() if view != null else PackedStringArray(),
		"sketch_entities": PackedStringArray(),
		"sketch_active": false,
	}
	if sketch_mode != null and sketch_mode.active:
		d["sketch_active"] = true
		if sketch_mode.has_method("selected_ids"):
			d["sketch_entities"] = sketch_mode.selected_ids()
		elif "selected" in sketch_mode:
			var arr := PackedStringArray()
			for id in sketch_mode.selected:
				arr.append(id)
			d["sketch_entities"] = arr
	return d


## Primary entry: free-text path (used by inject_utterance and tests).
func handle_text(text: String) -> Dictionary:
	if text.strip_edges() == "":
		status.emit("I didn't catch that — hold V and try again")
		return {}
	var intent: Dictionary = _voice.interpret(text, selection_dict())
	intent_parsed.emit(intent)
	return _dispatch(intent)


## WAV path from VoiceCapture.end_listen. Uses STT when available; otherwise
## status explains the stub.
func handle_wav(path: String) -> Dictionary:
	if path == "":
		status.emit("No audio captured — try typing via the test hook, or check the mic")
		return {}
	if not _stt.available():
		status.emit("Voice STT not built yet — inject text for now (whisper optional)")
		return {}
	var tr: Dictionary = _stt.transcribe_wav(path)
	var err: String = str(tr.get("error", ""))
	if err != "":
		status.emit(err)
		return {}
	var spoken: String = str(tr.get("text", "")).strip_edges()
	if spoken == "":
		status.emit("I didn't catch that — hold V and try again")
		return {}
	status.emit("Heard: “%s”" % spoken)
	return handle_text(spoken)


func confirm_pending() -> Dictionary:
	if _pending.is_empty():
		return {}
	var intent := _pending.duplicate(true)
	_pending.clear()
	intent["needs_confirm"] = false
	return _dispatch(intent)


func cancel_pending() -> void:
	_pending.clear()
	status.emit("Cancelled")


func _dispatch(intent: Dictionary) -> Dictionary:
	var kind: String = str(intent.get("kind", "unmatched"))
	var verb: String = str(intent.get("verb", ""))
	var prompt: String = str(intent.get("prompt", ""))

	if kind == "unmatched":
		_log_unmatched(intent)
		status.emit(prompt if prompt != "" else "I don't know that command yet")
		return intent

	if prompt != "":
		status.emit(prompt)
		return intent

	if bool(intent.get("needs_confirm", false)):
		_pending = intent.duplicate(true)
		status.emit("Confirm: %s %s — say “okay” or cancel" % [kind, verb])
		return intent

	match kind:
		"constraint":
			_do_constraint(intent)
		"model":
			_do_model(intent)
		"view":
			_do_view(intent)
		"app":
			_do_app(intent)
		"variable":
			_do_variable(intent)
		"query":
			_do_query(intent)
		_:
			status.emit("Unhandled intent kind: %s" % kind)
	return intent


func _do_constraint(intent: Dictionary) -> void:
	if sketch_mode == null or not sketch_mode.active or sketch_mode.sketch == null:
		status.emit("Enter a sketch first, then ask again")
		return
	var verb: String = intent["verb"]
	var ids: Array = []
	if "selected" in sketch_mode:
		ids = sketch_mode.selected.duplicate()
	if ids.is_empty():
		status.emit("Select sketch geometry, then ask again")
		return
	var sk = sketch_mode.sketch
	var value = intent.get("value", null)
	match verb:
		"horizontal":
			sk.add_constraint("horizontal", [{"entity": ids[0], "role": "self"}], 0.0)
		"vertical":
			sk.add_constraint("vertical", [{"entity": ids[0], "role": "self"}], 0.0)
		"parallel":
			if ids.size() < 2:
				status.emit("Select two lines, then ask again")
				return
			sk.add_constraint("parallel", [
				{"entity": ids[0], "role": "self"},
				{"entity": ids[1], "role": "self"}], 0.0)
		"perpendicular":
			if ids.size() < 2:
				status.emit("Select two lines, then ask again")
				return
			sk.add_constraint("perpendicular", [
				{"entity": ids[0], "role": "self"},
				{"entity": ids[1], "role": "self"}], 0.0)
		"equal":
			if ids.size() < 2:
				status.emit("Select two entities, then ask again")
				return
			sk.add_constraint("equal", [
				{"entity": ids[0], "role": "self"},
				{"entity": ids[1], "role": "self"}], 0.0)
		"tangent":
			if ids.size() < 2:
				status.emit("Select a line and a circle, then ask again")
				return
			sk.add_constraint("tangent", [
				{"entity": ids[0], "role": "self"},
				{"entity": ids[1], "role": "self"}], 0.0)
		"coincident":
			if ids.size() < 2:
				status.emit("Select two points, then ask again")
				return
			sk.add_constraint("coincident", [
				{"entity": ids[0], "role": "self"},
				{"entity": ids[1], "role": "self"}], 0.0)
		"distance", "radius", "angle":
			if value == null:
				status.emit("Say a number too — e.g. “dimension this to 40”")
				return
			var v := float(value)
			if verb == "angle":
				v = deg_to_rad(v)
			var refs: Array = [{"entity": ids[0], "role": "self"}]
			if verb == "distance" and ids.size() >= 2:
				refs = [
					{"entity": ids[0], "role": "start"},
					{"entity": ids[0], "role": "end"}]
				if ids.size() >= 2:
					refs = [
						{"entity": ids[0], "role": "self"},
						{"entity": ids[1], "role": "self"}]
			sk.add_constraint(verb, refs, v)
		"fix":
			# Approximate "lock" as a pair of fixed dimensions isn't available —
			# horizontal+vertical on a line is the closest lightweight fix.
			sk.add_constraint("horizontal", [{"entity": ids[0], "role": "self"}], 0.0)
		_:
			status.emit("Constraint “%s” not wired yet" % verb)
			return
	sketch_mode.run_solve()
	sketch_mode._redraw()
	status.emit("Constrained: %s — Ctrl+Z in sketch is still via cancel/edit" % verb)


func _do_model(intent: Dictionary) -> void:
	var verb: String = intent["verb"]
	var value = intent.get("value", null)
	var v := float(value) if value != null else 1.0
	match verb:
		"fasten", "flush":
			var faces: PackedStringArray = PackedStringArray()
			for f in view.selected_faces:
				faces.append(f)
			if view.selected_face != "" and not faces.has(view.selected_face):
				faces.append(view.selected_face)
			if faces.size() < 2:
				status.emit("Select two faces, then ask again")
				return
			var inst := ""
			for row in view.doc.instance_list():
				inst = str(row.get("id", ""))
				if inst != "":
					break
			if inst == "":
				status.emit("Place an instance first, then make them flush")
				return
			var mid: String = view.doc.add_mate("fastened", "", faces[0], inst, faces[1], 0.0, false, "Flush")
			if mid != "":
				view.doc.solve_mates()
				view.refresh()
				status.emit("Fastened — offset 0")
			else:
				status.emit("Could not fasten those faces")
		"fillet":
			var edges: PackedStringArray = _edge_targets()
			if edges.is_empty():
				status.emit("Select an edge, then ask again")
				return
			var ffid := view.feature_of_body(view.selected_body)
			var fok: bool
			if ffid != "":
				fok = view.doc.graph_add_fillet(ffid, edges, v) != ""
			else:
				fok = view.doc.fillet_edges(edges, v)
			if fok:
				view.graph_changed()
				status.emit("Fillet %.2f applied — Ctrl+Z to undo" % v)
			else:
				status.emit("Fillet failed — try a smaller radius")
		"chamfer":
			var edges2: PackedStringArray = _edge_targets()
			if edges2.is_empty():
				status.emit("Select an edge, then ask again")
				return
			var cfid := view.feature_of_body(view.selected_body)
			var cok: bool
			if cfid != "":
				cok = view.doc.graph_add_chamfer(cfid, edges2, v) != ""
			else:
				cok = view.doc.chamfer_edges(edges2, v)
			if cok:
				view.graph_changed()
				status.emit("Chamfer %.2f applied — Ctrl+Z to undo" % v)
			else:
				status.emit("Chamfer failed — try a smaller distance")
		"shell":
			var faces: PackedStringArray = PackedStringArray()
			for f in view.selected_faces:
				faces.append(f)
			if faces.is_empty() and view.selected_face != "":
				faces.append(view.selected_face)
			if faces.is_empty():
				status.emit("Select a face to open, then ask again")
				return
			var sfid := view.feature_of_body(view.selected_body)
			var sok: bool
			if sfid != "":
				sok = view.doc.graph_add_shell(sfid, faces, v) != ""
			else:
				sok = view.doc.shell_body(faces, v)
			if sok:
				view.graph_changed()
				status.emit("Shell thickness %.2f — Ctrl+Z to undo" % v)
			else:
				status.emit("Shell failed — try a thinner wall")
		"hide":
			if view.selected_body == "":
				status.emit("Select a body, then ask again")
				return
			view.set_body_hidden(view.selected_body, true)
			status.emit("Hidden — say “show all” to restore")
		"isolate":
			if view.selected_bodies.is_empty() and view.selected_body == "":
				status.emit("Select a body, then ask again")
				return
			var ids: Array = []
			if not view.selected_bodies.is_empty():
				ids = view.selected_bodies.duplicate()
			else:
				ids = [view.selected_body]
			view.isolate(ids)
			status.emit("Isolated — say “show all” to restore")
		"show_all":
			view.unhide_all()
			status.emit("All bodies shown")
		"delete":
			if view.selected_body == "":
				status.emit("Select a body, then ask again")
				return
			view.delete_selected()
			status.emit("Deleted — Ctrl+Z to undo")
		"extrude":
			if sketch_mode != null and sketch_mode.active:
				sketch_mode.finish_extrude(v if value != null else 10.0, "new")
				status.emit("Extruded %.2f — Ctrl+Z to undo" % v)
			else:
				status.emit("Start a sketch first, then say “extrude 10”")
		"mirror", "hole", "revolve":
			status.emit("“%s” needs the matching UI tool for now — try the ops panel" % verb)
		_:
			status.emit("Model “%s” not wired yet" % verb)


func _edge_targets() -> PackedStringArray:
	var edges := PackedStringArray()
	for e in view.selected_edges:
		edges.append(e)
	if edges.is_empty() and view.selected_edge != "":
		edges.append(view.selected_edge)
	return edges


func _do_view(intent: Dictionary) -> void:
	if camera == null:
		return
	var verb: String = intent["verb"]
	match verb:
		"front":
			camera.apply_standard_view(deg_to_rad(0.0), deg_to_rad(0.0), true)
			status.emit("Front view")
		"right":
			camera.apply_standard_view(deg_to_rad(90.0), deg_to_rad(0.0), true)
			status.emit("Right view")
		"left":
			camera.apply_standard_view(deg_to_rad(-90.0), deg_to_rad(0.0), true)
			status.emit("Left view")
		"top":
			camera.apply_standard_view(deg_to_rad(0.0), deg_to_rad(89.0), true)
			status.emit("Top view")
		"bottom":
			camera.apply_standard_view(deg_to_rad(0.0), deg_to_rad(-89.0), true)
			status.emit("Bottom view")
		"back":
			camera.apply_standard_view(deg_to_rad(180.0), deg_to_rad(0.0), true)
			status.emit("Back view")
		"iso":
			camera.apply_standard_view(deg_to_rad(-35.0), deg_to_rad(40.0), true)
			status.emit("Isometric view")
		"zoom_fit":
			camera.frame_contents()
			status.emit("Zoomed to fit")
		"ortho":
			if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
				camera.toggle_projection()
			status.emit("Orthographic")
		"perspective":
			if camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
				camera.toggle_projection()
			status.emit("Perspective")
		"section":
			if interaction != null and interaction.has_method("toggle_section"):
				interaction.toggle_section()
			elif view != null and view.has_method("toggle_section"):
				view.toggle_section()
			status.emit("Section view toggled")
		_:
			status.emit("View “%s” not wired yet" % verb)


func _do_app(intent: Dictionary) -> void:
	var verb: String = intent["verb"]
	match verb:
		"undo":
			if view.undo():
				status.emit("Undone")
			else:
				status.emit("Nothing to undo")
		"redo":
			if view.redo():
				status.emit("Redone")
			else:
				status.emit("Nothing to redo")
		"ok":
			if not _pending.is_empty():
				confirm_pending()
			else:
				status.emit("Nothing pending to confirm")
		"cancel":
			cancel_pending()
		"save":
			status.emit("Use Ctrl+S to save (voice save hooks File menu next)")
		_:
			status.emit("App “%s” not wired yet" % verb)


func _do_variable(intent: Dictionary) -> void:
	var name: String = str(intent.get("name", ""))
	if name == "":
		status.emit("Say the variable name — e.g. “set width to 55”")
		return
	var verb: String = intent["verb"]
	var expr := ""
	if verb == "set_var":
		var value = intent.get("value", null)
		if value == null:
			status.emit("Say a number — e.g. “set width to 55”")
			return
		expr = str(value)
	else:
		expr = str(intent.get("expression", ""))
	if expr == "":
		status.emit("Missing expression for %s" % name)
		return
	if view.doc.set_variable(name, expr):
		view.graph_changed()
		status.emit("Set %s = %s — Ctrl+Z where supported" % [name, expr])
	else:
		status.emit("Couldn't set variable %s" % name)


func _do_query(intent: Dictionary) -> void:
	var verb: String = intent["verb"]
	match verb:
		"mass":
			if view.selected_body == "":
				status.emit("Select a body, then ask again")
				return
			var mp: Dictionary = view.doc.measure_mass(view.selected_body)
			status.emit("Mass ≈ %.2f g (volume %.2f mm³)" % [
				float(mp.get("mass_g", 0.0)), float(mp.get("volume", 0.0))])
		"volume":
			if view.selected_body == "":
				status.emit("Select a body, then ask again")
				return
			var mp2: Dictionary = view.doc.measure_mass(view.selected_body)
			status.emit("Volume ≈ %.2f mm³" % float(mp2.get("volume", 0.0)))
		"area":
			if view.selected_face == "":
				status.emit("Select a face, then ask again")
				return
			var area: float = view.doc.measure_face_area(view.selected_face)
			status.emit("Face area ≈ %.2f mm²" % area)
		"distance_between":
			status.emit("Pick two things, then use Measure in the ops panel for now")
		"help":
			status.emit("Try: “fillet this 3”, “make this horizontal”, “how heavy is this”, “look at the front”")
		_:
			status.emit("Query “%s” not wired yet" % verb)


func _log_unmatched(intent: Dictionary) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if not dir.dir_exists("voice"):
		dir.make_dir("voice")
	var path := "user://voice/unmatched.jsonl"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var row := {
		"raw_text": intent.get("raw_text", ""),
		"selection": selection_dict(),
		"ts": Time.get_unix_time_from_system(),
	}
	f.store_line(JSON.stringify(row))
	f.close()
