extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("S-key marking menu names both overlapping picks", 1.6)

	await ctx.beat("Place a box and select it", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var body: String = doc.body_ids()[0] if doc.body_ids().size() > 0 else ""
	var face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	if body != "":
		ctx.view.select_entity(body, face)
	await ctx.after_regen()

	await ctx.beat("Open the marking menu", 0.45)
	var ix = ctx.main.interaction
	if ix != null:
		ix._open_marking_menu(ix._screen_center() if ix.has_method("_screen_center") else Vector2(400, 300))
		await FilmUI.wait_frames(ctx.tree, 4)
		var menu: MarkingMenu = ix.marking_menu
		if menu != null and menu.visible:
			var named := 0
			for c in menu.find_children("*", "Button", true, false):
				var t := str((c as Button).text)
				if t.begins_with("Face") or t.begins_with("Body"):
					named += 1
			await ctx.beat("Popup names %d overlapping picks" % named, 0.8)
			menu.hide()
		else:
			await ctx.beat("Marking menu available on S", 0.6)
	await ctx.camera.showcase_smooth(1.0, 24.0)
