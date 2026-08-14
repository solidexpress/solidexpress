extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A tube follows a 3D polyline", 1.4)
	var sid: String = doc.add_sketch3d(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, 0, 30), Vector3(20, 0, 40)]))
	await ctx.beat("Route path %s" % ("ready" if sid != "" else "missing"), 0.7)
	await ctx.camera.showcase_smooth(0.6, 12.0)
