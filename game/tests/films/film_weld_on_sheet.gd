extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A weld bead gets a symbol on the drawing", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await ctx.camera.frame_all_smooth(0.0)
	var bodies: PackedStringArray = doc.body_ids()
	if not bodies.is_empty():
		var edges: PackedStringArray = doc.get_edge_ids(bodies[0])
		if edges.is_empty():
			doc.add_weld(bodies[0], "fillet", 3.0)
		else:
			ctx.view.select_entity(bodies[0], edges[0])
			var ix = ctx.main.interaction
			if ix != null and ix.has_method("_open_marking_menu"):
				ix._open_marking_menu(ix._screen_center() if ix.has_method("_screen_center") else Vector2(400, 300))
				await FilmUI.wait_frames(ctx.tree, 3)
				var menu: MarkingMenu = ix.marking_menu
				if menu != null and menu.visible:
					var b := FilmUI.find_button(menu, "Weld")
					if b != null:
						await FilmUI.click_control(ctx, b, FilmUI.FilmUICues.alert("S", "Weld from the marking menu"))
					else:
						await FilmUI.marking_verb(ctx, "Weld")
				else:
					await FilmUI.marking_verb(ctx, "Weld")
			else:
				await FilmUI.marking_verb(ctx, "Weld")
	var n: int = doc.weld_list().size()
	var mode := ctx.main.find_child("ModeRail", true, false) as MenuButton
	if mode != null:
		mode.get_popup().id_pressed.emit(1)
	await FilmUI.wait_frames(ctx.tree, 2)
	await ctx.beat("%d weld symbol(s) on the sheet" % n, 0.8)
	await ctx.camera.showcase_smooth(0.8, 16.0)
