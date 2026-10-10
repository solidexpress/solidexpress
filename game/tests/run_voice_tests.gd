# Headless tests for VoiceCapture hold-to-talk overlay.
# Run: tools/godot/godot --headless --path game --script tests/run_voice_tests.gd
# Does not require a real microphone.
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("voice bridge tests")
	await test_lifecycle()
	await test_inject_utterance()
	await test_shortcut_documented()
	await test_interpreter_and_executor()
	finish()


func test_lifecycle() -> void:
	print("- begin_listen / end_listen without mic")
	var vc := VoiceCapture.new()
	vc.name = "VoiceCaptureTest"
	root.add_child(vc)
	await process_frame
	await process_frame

	check(not vc.visible, "hidden by default")
	check(not vc.is_listening(), "not listening by default")

	vc.begin_listen()
	await process_frame
	check(vc.visible, "begin_listen shows overlay")
	check(vc.is_listening(), "is_listening after begin")

	var path: String = vc.end_listen()
	await process_frame
	# Headless / no mic: "" is expected; a path is also acceptable if audio works.
	check(path is String, "end_listen returns a String")
	check(not vc.visible, "end_listen hides overlay")
	check(not vc.is_listening(), "not listening after end")

	# Second cycle should not crash either.
	vc.begin_listen()
	var path2: String = vc.end_listen()
	check(path2 is String, "second end_listen returns a String")

	vc.queue_free()
	await process_frame


func test_inject_utterance() -> void:
	print("- inject_utterance stub signal path")
	var vc := VoiceCapture.new()
	root.add_child(vc)
	await process_frame

	var got_partial := [""]
	var got_status := [""]
	var got_provider := [""]
	vc.partial_text.connect(func(t: String) -> void: got_partial[0] = t)
	vc.status.connect(func(t: String) -> void: got_status[0] = t)
	vc.set_transcript_provider(func(t: String) -> void: got_provider[0] = t)

	vc.inject_utterance("extrude 10mm")
	await process_frame
	check(got_partial[0] == "extrude 10mm", "partial_text fired with text")
	check(got_status[0] == "extrude 10mm", "status fired with text")
	check(got_provider[0] == "extrude 10mm", "transcript provider called")

	# utterance_ready still works as a connectable signal (empty path ok).
	var got_wav := ["unset"]
	vc.utterance_ready.connect(func(p: String) -> void: got_wav[0] = p)
	vc.begin_listen()
	var wav: String = vc.end_listen()
	await process_frame
	check(got_wav[0] == wav, "utterance_ready emits end_listen path")

	vc.queue_free()
	await process_frame


func test_shortcut_documented() -> void:
	print("- Shortcuts registry documents V hold")
	var desc := Shortcuts.describe("V (hold)")
	check(desc != "", "describe(V (hold)) known")
	check(desc.to_lower().contains("voice") or desc.to_lower().contains("talk"),
		"describe(V (hold)) mentions voice/talk")
	check(UIIcons.get_icon("mic") != null, "mic glyph rasterizes")


func test_interpreter_and_executor() -> void:
	print("- SxVoice interpret + VoiceExecutor dispatch")
	var voice := SxVoice.new()
	var h: Dictionary = voice.interpret("make this horizontal", {
		"sketch_active": true,
		"sketch_entities": PackedStringArray(),
	})
	check(h.get("kind", "") == "constraint", "kind=constraint")
	check(h.get("verb", "") == "horizontal", "verb=horizontal")
	check(str(h.get("prompt", "")).contains("Select"), "prompt asks for selection")

	var mass: Dictionary = voice.interpret("how heavy is this", {
		"bodies": PackedStringArray(["x"]),
	})
	check(mass.get("verb", "") == "mass", "mass query")
	check(str(mass.get("prompt", "")) == "", "mass ready with body")

	var u: Dictionary = voice.interpret("make it feel organic", {})
	check(u.get("kind", "") == "unmatched", "unmatched kind")

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	check(main.voice_executor != null, "main mounts VoiceExecutor")
	check(main.voice_capture != null, "main mounts VoiceCapture")

	var got := [""]
	main.voice_executor.status.connect(func(t: String) -> void: got[0] = t)

	# View command — no selection required.
	var intent: Dictionary = main.voice_executor.handle_text("look at the front")
	check(intent.get("verb", "") == "front", "executor parsed front")
	check(got[0].to_lower().contains("front"), "status mentions front (got %s)" % got[0])

	# Query against a placed box.
	main.view.doc.add_box(20, 20, 20, Vector3.ZERO)
	main.view.refresh()
	await process_frame
	var bodies: Array = main.view.doc.body_ids()
	check(bodies.size() > 0, "box created for mass query")
	if bodies.size() > 0:
		main.view.selected_body = bodies[0]
		main.view.selected_bodies.clear()
		main.view.selected_bodies.append(bodies[0])
		var q: Dictionary = main.voice_executor.handle_text("how heavy is this")
		check(q.get("verb", "") == "mass", "mass intent from executor")
		check(got[0].to_lower().contains("mass") or got[0].to_lower().contains("g"),
			"mass answer in status (got %s)" % got[0])

	# inject_utterance routes through transcript provider → executor.
	got[0] = ""
	main.voice_capture.inject_utterance("zoom to fit")
	await process_frame
	check(got[0].to_lower().contains("fit") or got[0].to_lower().contains("zoom"),
		"inject_utterance executed zoom_fit (got %s)" % got[0])

	main.queue_free()
	await process_frame
