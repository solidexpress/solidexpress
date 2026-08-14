extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Four frame members — cut lengths from the path", 1.5)
	var paths := [
		[Vector3(0, 0, 0), Vector3(80, 0, 0)],
		[Vector3(80, 0, 0), Vector3(80, 80, 0)],
		[Vector3(80, 80, 0), Vector3(0, 80, 0)],
		[Vector3(0, 80, 0), Vector3(0, 0, 0)],
	]
	var total := 0.0
	for p in paths:
		var arr := PackedVector3Array()
		arr.append(p[0])
		arr.append(p[1])
		doc.graph_add_frame(arr, 20.0, 20.0)
		total += (p[1] as Vector3).distance_to(p[0] as Vector3)
	await ctx.after_regen()
	await ctx.beat("Cut list total %.0f mm — 4 members" % total, 0.8)
	await ctx.camera.showcase_smooth(1.1, 30.0)
