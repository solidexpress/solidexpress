extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Linear static beam — tip deflection scales with L³", 1.5)
	var d1: float = doc.fea_cantilever(100.0, 50.0, 210000.0, 20.0, 4.0)
	var d2: float = doc.fea_cantilever(100.0, 100.0, 210000.0, 20.0, 4.0)
	await ctx.beat("δ(50)=%.4f  δ(100)=%.4f mm  (×8)" % [d1, d2], 0.9)
	await ctx.camera.showcase_smooth(0.8, 16.0)
