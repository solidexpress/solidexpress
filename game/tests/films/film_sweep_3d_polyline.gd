extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Sweep a circle along a 3D polyline", 1.5)
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(20, 0, 10), Vector3(40, 15, 25)])
	var sid: String = doc.add_sketch3d(pts)
	await ctx.beat("3D sketch %s — three non-planar points" % ("ready" if sid != "" else "missing"), 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
