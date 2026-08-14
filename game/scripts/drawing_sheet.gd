class_name DrawingSheet
extends Control
## Draw mode: the sheet *is* the viewport. Live HLR views, associative dims,
## BOM table and weld symbols come from the drawing document — not a stateless
## SVG export. Hidden in Model (layout suite stays green).

var title := "SOLIDEXPRESS"
var scale_text := "1:1"
var preview: Dictionary = {}


func _ready() -> void:
	name = "DrawingSheet"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 80
	offset_top = 48
	offset_right = -80
	offset_bottom = -48


func show_sheet(on: bool) -> void:
	visible = on
	queue_redraw()


func set_preview(data: Dictionary) -> void:
	preview = data
	if data.has("title"):
		title = str(data["title"])
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.93, 0.93, 0.90, 0.92))
	draw_rect(r.grow(-8), Color(0.15, 0.15, 0.16), false, 1.5)
	var origin := Vector2(36, r.size.y - 72)
	var px := 2.2
	var views: Array = preview.get("views", [])
	for v in views:
		var ox: float = float(v.get("offset_x", 0.0)) * px
		var oy: float = float(v.get("offset_y", 0.0)) * px
		_draw_polylines(v.get("visible", []), origin + Vector2(ox, -oy), px, Color(0.12, 0.12, 0.14), 1.4)
		_draw_polylines(v.get("hidden", []), origin + Vector2(ox, -oy), px, Color(0.45, 0.45, 0.48), 1.0)
		_draw_polylines(v.get("hatch", []), origin + Vector2(ox, -oy), px, Color(0.25, 0.25, 0.28), 0.8)
		draw_string(ThemeDB.fallback_font, origin + Vector2(ox, -oy + 14), str(v.get("name", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.2, 0.22))
	var dims: Array = preview.get("dims", [])
	var dim_y := 28.0
	for d in dims:
		var txt := "%.1f" % float(d.get("value", 0.0))
		draw_string(ThemeDB.fallback_font, Vector2(24, dim_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.15, 0.2, 0.45))
		dim_y += 16.0
	var bom: Array = preview.get("bom", [])
	if not bom.is_empty():
		var by := r.size.y - 120.0
		draw_string(ThemeDB.fallback_font, Vector2(24, by), "BOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.1, 0.1, 0.12))
		by += 14.0
		for row in bom:
			draw_string(ThemeDB.fallback_font, Vector2(24, by),
					"%d  %s  ×%d" % [int(row.get("item", 0)), str(row.get("name", "")), int(row.get("qty", 0))],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.2, 0.22))
			by += 13.0
	var welds: Array = preview.get("welds", [])
	for w in welds:
		draw_string(ThemeDB.fallback_font, Vector2(r.size.x - 200, 36),
				"Weld %s %.1f" % [str(w.get("symbol", "")), float(w.get("size", 0.0))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.15, 0.1))
	var block := Rect2(r.size.x - 220, r.size.y - 56, 204, 40)
	draw_rect(block, Color(0.98, 0.98, 0.96))
	draw_rect(block, Color(0.2, 0.2, 0.22), false, 1.0)
	draw_string(ThemeDB.fallback_font, block.position + Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.1, 0.12))
	draw_string(ThemeDB.fallback_font, block.position + Vector2(8, 34), "SCALE " + scale_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.25, 0.25, 0.28))


func _draw_polylines(pls: Array, origin: Vector2, px: float, color: Color, width: float) -> void:
	for pl in pls:
		if pl is PackedVector2Array:
			var pts: PackedVector2Array = pl
			for i in range(1, pts.size()):
				var a := origin + Vector2(pts[i - 1].x * px, -pts[i - 1].y * px)
				var b := origin + Vector2(pts[i].x * px, -pts[i].y * px)
				draw_line(a, b, color, width)
