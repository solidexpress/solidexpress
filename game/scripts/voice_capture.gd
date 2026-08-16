class_name VoiceCapture
extends Control
## Hold-to-talk voice capture overlay. Press/hold V to listen; release to stop
## and emit a WAV path (best-effort). Headless / no-mic environments degrade
## gracefully: methods stay callable, end_listen() returns "", and status is
## friendly. Recognition / intent execution are out of scope — connect
## utterance_ready / partial_text from a future VoiceAsk / VoiceExecutor.


signal status(text: String)
signal utterance_ready(wav_path: String)
signal partial_text(text: String)

const BUS_NAME := "VoiceRecord"
const VOICE_DIR := "user://voice/"

## When false, KEY_V hold-to-talk is ignored (API still works).
var enabled := true

## Optional future hook: VoiceAsk / VoiceExecutor may register a callable that
## receives pending transcript text. Not required for capture itself.
var _transcript_provider: Callable = Callable()

var _listening := false
var _effect: AudioEffectRecord
var _mic_player: AudioStreamPlayer
var _bus_ready := false
var _mic_ok := false

var _panel: PanelContainer
var _mic_rect: TextureRect
var _label: Label
var _pulse_t := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_build_overlay()
	_setup_audio_best_effort()


func is_listening() -> bool:
	return _listening


## Optional: register a callable(text: String) for future transcript routing.
func set_transcript_provider(callable: Callable) -> void:
	_transcript_provider = callable


## Test / stub hook: simulate recognized text without microphone audio.
## Emits partial_text + status; does not write a WAV.
func inject_utterance(text: String) -> void:
	status.emit(text)
	partial_text.emit(text)
	if _transcript_provider.is_valid():
		_transcript_provider.call(text)


func begin_listen() -> void:
	if _listening:
		return
	_listening = true
	_pulse_t = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_label.text = "Listening…"
	status.emit("Listening…")

	if not _mic_capture_available():
		_label.text = "Listening… (no mic)"
		status.emit("Microphone unavailable — release V to cancel")
		return

	if not _ensure_audio():
		_label.text = "Listening… (no mic)"
		status.emit("Microphone unavailable — release V to cancel")
		return

	if _effect != null:
		_effect.set_recording_active(true)
	if _mic_player != null and not _mic_player.playing:
		_mic_player.play()


## Stop recording, write WAV under user://voice/, return path or "" on failure.
func end_listen() -> String:
	if not _listening:
		return ""
	_listening = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_panel.scale = Vector2.ONE
	_panel.modulate = Color.WHITE

	var path := ""
	# Only touch AudioEffectRecord when we actually armed capture; otherwise
	# get_recording() ERR_FAIL-spams on empty buffers (headless / no mic).
	if _effect != null and _effect.is_recording_active():
		_effect.set_recording_active(false)
		var recording: AudioStreamWAV = _effect.get_recording()
		if recording != null and recording.data.size() > 0:
			path = _write_wav(recording)
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()

	if path != "":
		status.emit("Voice captured")
		utterance_ready.emit(path)
	else:
		status.emit("No audio captured")
		utterance_ready.emit("")
	return path


func _build_overlay() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(160, 120)
	# Anchor center: offset so the panel is truly centered.
	_panel.offset_left = -80
	_panel.offset_top = -60
	_panel.offset_right = 80
	_panel.offset_bottom = 60
	_panel.pivot_offset = Vector2(80, 60)
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	_mic_rect = TextureRect.new()
	_mic_rect.texture = UIIcons.get_icon("mic", 28)
	_mic_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mic_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mic_rect.custom_minimum_size = Vector2(36, 36)
	_mic_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_mic_rect)

	_label = Label.new()
	_label.text = "Listening…"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", UiScale.font(14))
	_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
	root.add_child(_label)


func _process(delta: float) -> void:
	if not _listening:
		return
	_pulse_t += delta
	var pulse := 0.5 + 0.5 * sin(_pulse_t * TAU * 1.4)
	var s := 1.0 + 0.06 * pulse
	_panel.scale = Vector2(s, s)
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.82 + 0.18 * pulse)
	if _mic_rect != null:
		_mic_rect.modulate = Color(0.75 + 0.25 * pulse, 0.82 + 0.18 * pulse, 1.0)


## Self-contained hold-to-talk: V pressed → begin, V released → end.
## Shortcuts TABLE documents this; the registry itself does not dispatch holds.
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.keycode != KEY_V or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if key.pressed:
		begin_listen()
		get_viewport().set_input_as_handled()
	elif _listening:
		end_listen()
		get_viewport().set_input_as_handled()


func _setup_audio_best_effort() -> void:
	# Soft-enable mic input; harmless if unsupported in headless/CI.
	if ProjectSettings.has_setting("audio/driver/enable_input"):
		ProjectSettings.set_setting("audio/driver/enable_input", true)
	_bus_ready = _ensure_record_bus()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicPlayer"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = BUS_NAME if _bus_ready else "Master"
	_mic_player.autoplay = false
	add_child(_mic_player)
	_mic_ok = _bus_ready and _effect != null


## True when a real display + audio path can capture mic input.
## Headless / CI always returns false so tests never need a microphone.
func _mic_capture_available() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return true


func _ensure_audio() -> bool:
	if not _mic_capture_available():
		_mic_ok = false
		return false
	if _effect == null:
		_bus_ready = _ensure_record_bus()
	_mic_ok = _bus_ready and _effect != null and _mic_player != null
	return _mic_ok


func _ensure_record_bus() -> bool:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		# Keep captured mic off the speakers.
		AudioServer.set_bus_mute(idx, true)
	# Find or attach AudioEffectRecord on this bus.
	_effect = null
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var fx := AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectRecord:
			_effect = fx as AudioEffectRecord
			break
	if _effect == null:
		_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(idx, _effect)
	return _effect != null


func _write_wav(recording: AudioStreamWAV) -> String:
	var dir := DirAccess.open("user://")
	if dir == null:
		return ""
	if not dir.dir_exists("voice"):
		dir.make_dir("voice")
	var stamp := Time.get_unix_time_from_system()
	var path := "%sutt_%d.wav" % [VOICE_DIR, int(stamp)]
	# save_to_wav appends .wav if missing; keep path explicit.
	var err := recording.save_to_wav(path)
	if err != OK:
		status.emit("Failed to write voice WAV")
		return ""
	return path
