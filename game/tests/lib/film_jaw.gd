extends RefCounted
## Shared jaw-label helpers for re-PLAN 20. Reads the drawn Label3D nodes.
## Not a suite: lint_rung01_e2e.py does not scan this file.

const FilmUI = preload("res://tests/lib/film_ui.gd")


static func drawn_labels(sm: SketchMode) -> Array:
	var out: Array = []
	if sm == null or sm._dimension_labels == null:
		return out
	var cam := sm.get_viewport().get_camera_3d() if sm.is_inside_tree() else null
	if cam == null:
		return out
	for child in sm._dimension_labels.get_children():
		var lab := child as Label3D
		if lab == null:
			continue
		out.append({
			"node": lab,
			"text": str(lab.text),
			"visible": lab.visible,
			"rect": rect_of(sm, lab, cam),
		})
	return out


static func rect_of(sm: SketchMode, lab: Label3D, cam: Camera3D = null) -> Rect2:
	if cam == null:
		cam = sm.get_viewport().get_camera_3d()
	var anchor := cam.unproject_position(lab.global_position)
	var k: float = sm._label_px_scale(cam)
	var size := sm._dimension_label_size_px(str(lab.text)) * k
	var off := lab.offset
	var centre := anchor + Vector2(off.x * k, -off.y * k)
	return Rect2(centre - size * 0.5, size)


static func first_glyph(sm: SketchMode, lab: Label3D) -> Vector2:
	var rect := rect_of(sm, lab)
	var text := str(lab.text)
	var cam := sm.get_viewport().get_camera_3d()
	var k: float = sm._label_px_scale(cam)
	var glyph := text.substr(0, 1) if text.length() > 0 else "0"
	var one: Vector2 = sm._dimension_label_size_px(glyph) * k
	return Vector2(rect.position.x + one.x * 0.5, rect.get_center().y)


static func find_label(sm: SketchMode, want_degree: bool) -> Dictionary:
	var want_type := "angle" if want_degree else "distance"
	var rows: Array = sm.dimension_label_screen_rects()
	for entry in drawn_labels(sm):
		if not bool(entry.get("visible", false)):
			continue
		var text := str(entry.get("text", ""))
		if text.contains("°") != want_degree:
			continue
		var rect: Rect2 = entry.get("rect", Rect2())
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var idx := int(row.get("index", -1))
			if idx < 0 or idx >= sm.dimensions.size():
				continue
			if str(sm.dimensions[idx].get("type", "")) != want_type:
				continue
			var hit: Rect2 = row.get("rect", Rect2())
			if rect.get_center().distance_to(hit.get_center()) <= 8.0:
				return entry
	return {}


## Failures, empty when every dimension has a visible Label3D inside the
## canvas, clear of the rail and of the other labels, and within 3 px of
## dimension_label_screen_rects().
static func assert_all_dimensions_drawn(sm: SketchMode, rail: Control) -> PackedStringArray:
	var errs := PackedStringArray()
	if sm == null:
		errs.append("no sketch mode")
		return errs
	var labels := drawn_labels(sm)
	var visible: Array = []
	for entry in labels:
		if bool(entry.get("visible", false)):
			visible.append(entry)
		else:
			errs.append("hidden label '%s'" % str(entry.get("text", "")))
	if visible.size() != sm.dimensions.size():
		errs.append("visible labels %d != dimensions %d" % [visible.size(), sm.dimensions.size()])
	var cam: Camera3D = sm.camera if sm.camera != null else sm.get_viewport().get_camera_3d()
	var canvas := Rect2()
	if cam != null and cam.has_method("sketch_fit_canvas_rect"):
		canvas = cam.sketch_fit_canvas_rect()
	else:
		errs.append("no sketch canvas rect")
	var rail_rect := Rect2()
	if rail != null and rail.is_visible_in_tree():
		rail_rect = rail.get_global_rect()
	var hit_rows: Array = sm.dimension_label_screen_rects()
	for entry in visible:
		var rect: Rect2 = entry.get("rect", Rect2())
		var text := str(entry.get("text", ""))
		if canvas.size.x > 1.0 and not canvas.encloses(rect):
			errs.append("'%s' outside canvas %s rect %s" % [text, str(canvas), str(rect)])
		if rail_rect.size.x > 1.0 and rect.intersects(rail_rect):
			errs.append("'%s' overlaps the rail" % text)
		var matched := false
		for row in hit_rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if str(row.get("text", "")) != text:
				continue
			var hit: Rect2 = row.get("rect", Rect2())
			if rect.position.distance_to(hit.position) <= 3.0 and rect.size.distance_to(hit.size) <= 3.0:
				matched = true
				break
		if not matched:
			errs.append("'%s' rect drifts from dimension_label_screen_rects" % text)
	for i in range(visible.size()):
		var a: Rect2 = visible[i].get("rect", Rect2())
		for j in range(i + 1, visible.size()):
			var b: Rect2 = visible[j].get("rect", Rect2())
			if not a.intersects(b):
				continue
			var overlap := a.intersection(b)
			if overlap.size.x > 0.5 and overlap.size.y > 0.5:
				errs.append("labels overlap '%s' and '%s'" % [
					str(visible[i].get("text", "")), str(visible[j].get("text", ""))])
	return errs


static func push_click(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)


static func click_label_first_glyph(vp: Viewport, sm: SketchMode, want_degree: bool) -> Vector2:
	var entry := find_label(sm, want_degree)
	if entry.is_empty():
		return Vector2.INF
	var lab: Label3D = entry.get("node")
	var pos := first_glyph(sm, lab)
	push_click(vp, pos)
	return pos


## Three jaw clicks in sketch UV: centre, on-axis long side, half-width.
## The caller arms Jaw and awaits a frame around this.
static func draw_on_axis(ctx: FilmContext, center: Vector2, along_mm: float, across_mm: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var pts: Array[Vector2] = [
		center,
		center + Vector2(along_mm, 0.0),
		center + Vector2(along_mm, across_mm),
	]
	for uv in pts:
		var screen: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(uv))
		push_click(vp, screen)
		await ctx.tree.process_frame
		await ctx.tree.process_frame
