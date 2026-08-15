extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Two near-parallel lines — one click makes them parallel", 1.5)
	await ctx.camera.frame_all_smooth(0.0)
	await FilmUI.enter_sketch(ctx)
	var sm = ctx.main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(18, 18), Vector2(36, 18.4))
	await FilmUI.draw_line(ctx, sm, Vector2(18, 26), Vector2(36, 26.8))
	await FilmUI.wait_frames(ctx.tree, 2)
	var ix = ctx.main.interaction
	if ix != null and ix.has_method("_open_marking_menu"):
		ix._open_marking_menu(ix._screen_center() if ix.has_method("_screen_center") else Vector2(400, 300))
		await FilmUI.wait_frames(ctx.tree, 3)
		var menu: MarkingMenu = ix.marking_menu
		if menu != null and menu.visible:
			var b := FilmUI.find_button(menu, "parallel?")
			if b != null:
				await FilmUI.click_control(ctx, b, FilmUI.FilmUICues.alert("S", "Propose parallel"))
			else:
				await FilmUI.click_button(ctx, "parallel?")
		else:
			await FilmUI.click_button(ctx, "parallel?")
	else:
		await FilmUI.click_button(ctx, "parallel?")
	await ctx.beat("Proposed parallel", 0.8)
	await ctx.camera.showcase_smooth(0.7, 14.0)
