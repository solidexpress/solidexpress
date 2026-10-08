extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	await ctx.movie_toast("Two near-parallel lines — one click makes them parallel", 1.5)
	await ctx.camera.frame_all_smooth(0.0)
	await FilmUI.enter_sketch(ctx)
	var sm = ctx.main.sketch_mode
	await FilmUI.draw_line(ctx, sm, Vector2(18, 18), Vector2(36, 18.4))
	await FilmUI.draw_line(ctx, sm, Vector2(18, 26), Vector2(36, 26.8))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await FilmUI.click_sketch(ctx, sm, Vector2(27, 18.2), "Select the first line")
	await FilmUI.click_sketch(ctx, sm, Vector2(27, 26.4), "Select the second line")
	await FilmUI.wait_frames(ctx.tree, 2)
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Parallel?")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUI.FilmUICues.alert("S", "Propose parallel"))
	else:
		var more := FilmUI.find_button(ctx.main.sketch_chrome, "… More") as MenuButton
		var item_id := -1
		if more != null:
			var popup := more.get_popup()
			for i in popup.item_count:
				if str(popup.get_item_text(i)) == "Parallel?":
					item_id = i
					break
		if item_id >= 0:
			await FilmUI.activate_menu_id(ctx, more, item_id, FilmUI.FilmUICues.alert("S", "Propose parallel"))
		else:
			await FilmUI.click_button(ctx, "parallel?")
	await ctx.beat("Proposed parallel", 0.8)
	await ctx.camera.showcase_smooth(0.7, 14.0)
