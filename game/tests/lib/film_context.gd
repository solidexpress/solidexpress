class_name FilmContext
extends RefCounted

const MovieToast = preload("res://tests/lib/movie_toast.gd")
const _Pres = preload("res://tests/lib/film_presentation.gd")

var main
var view: DocumentView
var camera: FilmCamera
var chrome: FilmChrome
var clock: FilmClock
var tree: SceneTree


## Top-level film intent banner (shown at start of each demo).
func movie_toast(text: String, hold_sec: float = 2.0) -> void:
	MovieToast.show_on(chrome, text)
	await tree.process_frame
	await clock.wait_sec(tree, hold_sec)
	MovieToast.dismiss_on(chrome)


## Advance the narrative: closed caption + film hold + a beat of reading time.
func beat(caption: String, hold_sec: float = 0.75) -> void:
	if chrome != null:
		chrome.show_caption(caption)
	await tree.process_frame
	var total := maxf(0.0, hold_sec) + _Pres.BEAT_HOLD_SEC
	var frames := maxi(1, int(round(total * _Pres.FPS)))
	for i in frames:
		if chrome != null and chrome.has_method("tick_unique"):
			chrome.tick_unique(i)
		await tree.process_frame


func after_regen() -> void:
	if view != null:
		view.refresh()
	if main != null and main.has_method("_on_document_changed"):
		main._on_document_changed()
	await tree.process_frame
	await tree.process_frame
